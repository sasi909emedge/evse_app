import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:win_ble/win_ble.dart';
import 'package:win_ble/win_file.dart';
import 'ble_service_base.dart' as base;
import 'ble_protocol.dart';
import '../config/evse_config.dart';

// ================================================================
// WINDOWS BLE SERVICE — Company Protocol
// ================================================================
class BleServiceWindows extends base.BleServiceBase {
  BleServiceWindows._internal();
  static final BleServiceWindows instance = BleServiceWindows._internal();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    await WinBle.initialize(serverPath: await WinServer.path());
    _initialized = true;
    debugPrint("✅ WinBLE initialized");
  }

  final Map<String, bool> _gattReady = {};
  StreamSubscription? _notifySub;
  Future<void> _operation = Future.value();

  // Service UUID — 0x180A little-endian 128-bit form
  static const String _svcUuid = 'ed8ab937-571f-4dfd-a081-35b4f2243358';
  // Write + Notify — same characteristic
  static const String _writeUuid = 'fb349b5f-8000-0080-0010-000000002000';

  Future<T> _queue<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _operation = _operation.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  // ── Scan ────────────────────────────────────────────────────
  @override
  Stream<base.BleDevice> scanDevices() {
    WinBle.startScanning();
    debugPrint("🔍 WinBLE scanning...");
    return WinBle.scanStream.map((d) => base.BleDevice(
          id: d.address,
          name: d.name,
          rssi: int.tryParse(d.rssi) ?? 0,
        ));
  }

  void stopScan() => WinBle.stopScanning();

  // ── Connect ─────────────────────────────────────────────────
  @override
  Stream<base.BleConnectionState> connectToDevice(String deviceId) {
    debugPrint("🔵 WinBLE connecting to $deviceId");
    final ctrl = StreamController<base.BleConnectionState>.broadcast();
    ctrl.add(base.BleConnectionState.connecting);

    WinBle.connectionStreamOf(deviceId).listen((connected) {
      debugPrint("WinBLE connection: $connected");
      ctrl.add(connected
          ? base.BleConnectionState.connected
          : base.BleConnectionState.disconnected);
    });

    WinBle.connect(deviceId);
    return ctrl.stream;
  }

  // ── Discover ─────────────────────────────────────────────────
  @override
  Future<void> discoverServices(String deviceId) async {
    debugPrint("⏳ WinBLE settling...");
    await Future.delayed(const Duration(milliseconds: 1500));

    final services = await WinBle.discoverServices(deviceId);
    for (final s in services) {
      debugPrint("📡 SERVICE: $s");
      try {
        final chars = await WinBle.discoverCharacteristics(
            address: deviceId, serviceId: s);
        for (final c in chars) {
          debugPrint("Characteristic: $c");
        }
      } catch (_) {}
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _gattReady[deviceId] = true;
    debugPrint("✅ WinBLE GATT READY");
  }

  @override
  bool isGattReady(String deviceId) => _gattReady[deviceId] == true;

  // ── Write JSON ───────────────────────────────────────────────
  @override
  Future<void> writeJson(String deviceId, Map<String, dynamic> json) {
    return _queue(() async {
      final bytes = utf8.encode(jsonEncode(json));
      final packets = BleProtocol.buildPackets(
        bytes,
        selection: Selection.updateConfig,
        format: DataFormat.json,
      );

      debugPrint("⬆️ WinBLE WRITE ${bytes.length}B "
          "→ ${packets.length} packet(s)");

      for (int i = 0; i < packets.length; i++) {
        await WinBle.write(
          address: deviceId,
          service: _svcUuid,
          characteristic: _writeUuid,
          data: packets[i],
          writeWithResponse: false, // Company uses write-without-response
        );
        debugPrint("✅ WinBLE packet ${i + 1}/${packets.length} ACK'd");
        if (i < packets.length - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      debugPrint("✅ WinBLE WRITE COMPLETE");
    });
  }

  Future<void> writeTabJson(
      String deviceId, Map<String, dynamic> json, int selection) {
    return _queue(() async {
      final bytes = utf8.encode(jsonEncode(json));
      final packets = BleProtocol.buildPackets(
        bytes,
        selection: selection,
        format: DataFormat.json,
      );
      debugPrint("⬆️ WinBLE WRITE tab sel=$selection ${bytes.length}B");
      for (int i = 0; i < packets.length; i++) {
        await WinBle.write(
          address: deviceId,
          service: _svcUuid,
          characteristic: _writeUuid,
          data: packets[i],
          writeWithResponse: true,
        );
        debugPrint("✅ WinBLE packet ${i + 1} ACK'd");
        if (i < packets.length - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    });
  }

  // ── Send Command ─────────────────────────────────────────────
  @override
  Future<void> sendCommand(String deviceId, String command) {
    return writeJson(deviceId, {"command": command});
  }

  // ── Read JSON ────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> readJson(String deviceId) {
    return _queue(() async {
      final mergedResult = <String, dynamic>{};
      final completer = Completer<Map<String, dynamic>>();

      var chunks = <int, List<int>>{};
      int? totalChunks;
      int? totalLength;

      Timer? quietTimer;
      void resetQuietTimer() {
        quietTimer?.cancel();
        quietTimer = Timer(const Duration(milliseconds: 6000), () {
          if (!completer.isCompleted) {
            debugPrint(
                "✅ WinBLE no more blobs — finishing with keys: ${mergedResult.keys.toList()}");
            completer.complete(mergedResult);
          }
        });
      }

      await _notifySub?.cancel();
      _notifySub = null;

      debugPrint("Service UUID: $_svcUuid");
      debugPrint("Write UUID: $_writeUuid");
      debugPrint("📥 WinBLE subscribing to notify...");
      try {
        await WinBle.subscribeToCharacteristic(
          address: deviceId,
          serviceId: _svcUuid,
          characteristicId: _writeUuid,
        );
        debugPrint("📥 WinBLE subscribed ✅");
      } catch (e) {
        debugPrint("⚠️ WinBLE subscribe: $e — continuing");
      }

      _notifySub = WinBle.characteristicValueStream.listen((event) {
        final addr = (event["address"] ?? "").toString();
        if (addr.toLowerCase() != deviceId.toLowerCase()) return;

        final raw = event["value"];
        List<int> data = [];
        if (raw is List) data = raw.cast<int>();
        if (raw is Uint8List) data = raw.toList();
        if (data.isEmpty) return;

        final packet = BleProtocol.parse(data);
        if (packet == null) {
          debugPrint("❌ WinBLE invalid packet");
          return;
        }

        // Starting a fresh blob, or header disagrees with what we're
        // currently tracking — (re)start clean.
        if (chunks.isEmpty || packet.totalChunks != totalChunks) {
          chunks = {};
          totalLength = packet.totalLength;
          totalChunks = packet.totalChunks;
        }

        debugPrint("📥 WinBLE $packet");
        chunks[packet.chunkIndex] = packet.payload;
        resetQuietTimer();

        if (chunks.length == totalChunks) {
          final assembled = <int>[];
          for (int i = 1; i <= totalChunks!; i++) {
            assembled.addAll(chunks[i] ?? []);
          }
          final trimmed = assembled.length > (totalLength ?? 0)
              ? assembled.sublist(0, totalLength!)
              : assembled;

          final jsonStr = utf8.decode(trimmed, allowMalformed: true);
          debugPrint(
              "✅ WinBLE blob assembled (${trimmed.length}B / $totalChunks chunk(s))");

          try {
            final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
            mergedResult.addAll(decoded);
            debugPrint(
                "🔗 WinBLE merged keys so far: ${mergedResult.keys.toList()}");
          } catch (e) {
            debugPrint("❌ WinBLE blob parse failed: $e");
          }

          // Reset — ready for the next blob (meter, then PM, etc.)
          chunks = {};
          totalChunks = null;
          totalLength = null;
        }
      });

      await Future.delayed(const Duration(milliseconds: 600));

      debugPrint("📤 WinBLE sending REQUEST packet...");
      final requestPackets = BleProtocol.buildPackets(
        [],
        selection: Selection.request,
        format: DataFormat.json,
      );
      try {
        await WinBle.write(
          address: deviceId,
          service: _svcUuid,
          characteristic: _writeUuid,
          data: requestPackets[0],
          writeWithResponse: false, // Company uses write-without-response
        );
        debugPrint("📤 WinBLE REQUEST sent");
      } catch (e) {
        debugPrint("⚠️ WinBLE request: $e");
      }

      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint(
              "⏰ WinBLE overall timeout — returning ${mergedResult.length} keys collected so far");
          return mergedResult;
        },
      );

      quietTimer?.cancel();
      await _notifySub?.cancel();
      _notifySub = null;

      try {
        await WinBle.unSubscribeFromCharacteristic(
          address: deviceId,
          serviceId: _svcUuid,
          characteristicId: _writeUuid,
        );
      } catch (_) {}

      return result;
    });
  }

  // ── Targeted Read — request ONE specific section only ─────────
  @override
  Future<Map<String, dynamic>> readJsonForSelection(
      String deviceId, int selection) {
    return _queue(() async {
      final completer = Completer<Map<String, dynamic>>();
      final chunks = <int, List<int>>{};
      int? totalChunks;
      int? totalLength;

      await _notifySub?.cancel();
      _notifySub = null;

      try {
        await WinBle.subscribeToCharacteristic(
          address: deviceId,
          serviceId: _svcUuid,
          characteristicId: _writeUuid,
        );
      } catch (e) {
        debugPrint("⚠️ WinBLE targeted subscribe: $e — continuing");
      }

      _notifySub = WinBle.characteristicValueStream.listen((event) {
        final addr = (event["address"] ?? "").toString();
        if (addr.toLowerCase() != deviceId.toLowerCase()) return;

        final raw = event["value"];
        List<int> data = [];
        if (raw is List) data = raw.cast<int>();
        if (raw is Uint8List) data = raw.toList();
        if (data.isEmpty) return;

        final packet = BleProtocol.parse(data);
        if (packet == null) return;

        if (chunks.isEmpty || packet.totalChunks != totalChunks) {
          totalLength = packet.totalLength;
          totalChunks = packet.totalChunks;
        }
        chunks[packet.chunkIndex] = packet.payload;
        debugPrint("📥 WinBLE targeted $packet");

        if (chunks.length == totalChunks) {
          final assembled = <int>[];
          for (int i = 1; i <= totalChunks!; i++) {
            assembled.addAll(chunks[i] ?? []);
          }
          final trimmed = assembled.length > (totalLength ?? 0)
              ? assembled.sublist(0, totalLength!)
              : assembled;
          final jsonStr = utf8.decode(trimmed, allowMalformed: true);
          debugPrint("✅ WinBLE targeted read assembled (${trimmed.length}B)");
          if (!completer.isCompleted) {
            try {
              completer.complete(jsonDecode(jsonStr) as Map<String, dynamic>);
            } catch (e) {
              debugPrint("❌ WinBLE targeted parse failed: $e");
              completer.complete({});
            }
          }
        }
      });

      await Future.delayed(const Duration(milliseconds: 600));

      debugPrint("📤 WinBLE targeted REQUEST (selection=$selection)...");
      final requestPackets = BleProtocol.buildPackets(
        [],
        selection: selection,
        format: DataFormat.json,
      );
      try {
        await WinBle.write(
          address: deviceId,
          service: _svcUuid,
          characteristic: _writeUuid,
          data: requestPackets[0],
          writeWithResponse: false,
        );
      } catch (e) {
        debugPrint("⚠️ WinBLE targeted request: $e");
      }

      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint("⏰ WinBLE targeted timeout (selection=$selection)");
          return {};
        },
      );

      await _notifySub?.cancel();
      _notifySub = null;

      try {
        await WinBle.unSubscribeFromCharacteristic(
          address: deviceId,
          serviceId: _svcUuid,
          characteristicId: _writeUuid,
        );
      } catch (_) {}

      return result;
    });
  }

  // ── Disconnect ───────────────────────────────────────────────
  @override
  void clearGattState(String deviceId) => _gattReady.remove(deviceId);

  @override
  void disconnect(String deviceId) {
    debugPrint("🔌 WinBLE disconnecting $deviceId");
    _notifySub?.cancel();
    _notifySub = null;
    clearGattState(deviceId);
    WinBle.disconnect(deviceId);
  }
}
