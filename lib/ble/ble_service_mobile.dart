import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../config/evse_config.dart';
import 'ble_service_base.dart';
import 'ble_protocol.dart';

// ================================================================
// MOBILE BLE SERVICE — Android + iOS
// Company protocol:
//   - Single characteristic for write AND notify
//   - 10-byte header, little-endian
//   - Chunks 1-based
//   - Read characteristic NOT used
// ================================================================
class BleServiceMobile extends BleServiceBase {
  BleServiceMobile._internal();
  static final BleServiceMobile instance = BleServiceMobile._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  final Map<String, bool> _gattReady = {};

  Future<void> _operation = Future.value();
  StreamSubscription<List<int>>? _notifySub;

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
  Stream<BleDevice> scanDevices() => _ble.scanForDevices(
      withServices: const [],
      scanMode:
          ScanMode.lowLatency).map(
      (d) => BleDevice(id: d.id, name: d.name, rssi: d.rssi));

  // ── Connect ─────────────────────────────────────────────────
  @override
  Stream<BleConnectionState> connectToDevice(String deviceId) {
    debugPrint("🔵 Connecting to $deviceId");
    return _ble
        .connectToDevice(
            id: deviceId, connectionTimeout: const Duration(seconds: 15))
        .map((u) {
      switch (u.connectionState) {
        case DeviceConnectionState.connecting:
          return BleConnectionState.connecting;
        case DeviceConnectionState.connected:
          return BleConnectionState.connected;
        case DeviceConnectionState.disconnecting:
          return BleConnectionState.disconnecting;
        case DeviceConnectionState.disconnected:
          return BleConnectionState.disconnected;
      }
    });
  }

  // ── Discover ─────────────────────────────────────────────────
  @override
  Future<void> discoverServices(String deviceId) async {
    debugPrint("⏳ Settling...");
    await Future.delayed(const Duration(milliseconds: 1500));

    await _ble.discoverAllServices(deviceId);
    final services = await _ble.getDiscoveredServices(deviceId);
    for (final s in services) {
      debugPrint("📡 SERVICE: ${s.id}");
      for (final c in s.characteristics) {
        debugPrint("   └─ CHAR: ${c.id}");
      }
    }

    try {
      // 515 = 512 packet + 3 ATT overhead
      await _ble.requestMtu(deviceId: deviceId, mtu: 515);
      debugPrint("✅ MTU negotiated to 515");
    } catch (_) {
      debugPrint("⚠️ MTU failed — using default");
    }

    await Future.delayed(const Duration(milliseconds: 500));
    _gattReady[deviceId] = true;
    debugPrint("✅ GATT READY");
  }

  @override
  bool isGattReady(String deviceId) => _gattReady[deviceId] == true;

  // ── Write characteristic (used for both write AND notify) ────
  QualifiedCharacteristic _writeChar(String deviceId) =>
      QualifiedCharacteristic(
        serviceId: EVSEConfig.serviceUuid,
        characteristicId: EVSEConfig.writeCharUuid,
        deviceId: deviceId,
      );

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

      debugPrint("⬆️ WRITE ${bytes.length}B → ${packets.length} packet(s)");

      for (int i = 0; i < packets.length; i++) {
        await _ble.writeCharacteristicWithResponse(_writeChar(deviceId),
            value: packets[i]);
        debugPrint("✅ Packet ${i + 1}/${packets.length} ACK'd "
            "(${packets[i].length}B)");
        if (i < packets.length - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      debugPrint("✅ WRITE COMPLETE");
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
      debugPrint(
          "⬆️ WRITE tab sel=$selection ${bytes.length}B → ${packets.length} packet(s)");
      for (int i = 0; i < packets.length; i++) {
        await _ble.writeCharacteristicWithResponse(_writeChar(deviceId),
            value: packets[i]);
        debugPrint("✅ Packet ${i + 1}/${packets.length} ACK'd");
        if (i < packets.length - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
      debugPrint("✅ WRITE COMPLETE");
    });
  }

  // ── Send Command ─────────────────────────────────────────────
  @override
  Future<void> sendCommand(String deviceId, String command) {
    return writeJson(deviceId, {"command": command});
  }

  // ── Read JSON ────────────────────────────────────────────────
  // Company uses SAME write characteristic for notify
  // We subscribe to write char notify, then send a REQUEST packet
  // to trigger charger to send data back via notify
  @override
  Future<Map<String, dynamic>> readJson(String deviceId) {
    return _queue(() async {
      final mergedResult = <String, dynamic>{};
      final completer = Completer<Map<String, dynamic>>();

      // Per-blob state — reset every time one complete blob is assembled
      var chunks = <int, List<int>>{};
      int? totalChunks;
      int? totalLength;

      Timer? quietTimer;
      void resetQuietTimer() {
        quietTimer?.cancel();
        quietTimer = Timer(const Duration(milliseconds: 1500), () {
          if (!completer.isCompleted) {
            debugPrint(
                "✅ No more blobs — finishing with keys: ${mergedResult.keys.toList()}");
            completer.complete(mergedResult);
          }
        });
      }

      final notifyChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: EVSEConfig.serviceUuid,
        characteristicId: EVSEConfig.notifyCharUuid,
      );

      await _notifySub?.cancel();
      _notifySub = null;

      _notifySub = _ble.subscribeToCharacteristic(notifyChar).listen(
        (raw) {
          final packet = BleProtocol.parse(raw);
          if (packet == null) {
            debugPrint("❌ Invalid packet (${raw.length}B)");
            return;
          }

          // Starting a fresh blob, or the header disagrees with what
          // we're currently tracking — (re)start clean.
          if (chunks.isEmpty || packet.totalChunks != totalChunks) {
            chunks = {};
            totalLength = packet.totalLength;
            totalChunks = packet.totalChunks;
          }

          debugPrint("📥 $packet");
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
                "✅ Blob assembled (${trimmed.length}B / $totalChunks chunk(s))");

            try {
              final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
              mergedResult.addAll(decoded);
              debugPrint(
                  "🔗 Merged keys so far: ${mergedResult.keys.toList()}");
            } catch (e) {
              debugPrint("❌ Blob JSON parse failed: $e");
            }

            // Reset — ready for the next blob (meter, then PM, etc.)
            chunks = {};
            totalChunks = null;
            totalLength = null;
          }
        },
        onError: (e) {
          debugPrint("❌ Notify error: $e");
          if (!completer.isCompleted) completer.complete(mergedResult);
        },
      );

      await Future.delayed(const Duration(milliseconds: 600));

      debugPrint("📤 Sending REQUEST packet...");
      final requestPackets = BleProtocol.buildPackets(
        [],
        selection: Selection.request,
        format: DataFormat.json,
      );
      await _ble.writeCharacteristicWithResponse(_writeChar(deviceId),
          value: requestPackets[0]);
      debugPrint("📤 REQUEST sent — waiting for notify chunks...");

      final result = await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint(
              "⏰ Overall timeout — returning ${mergedResult.length} keys collected so far");
          return mergedResult;
        },
      );

      quietTimer?.cancel();
      await _notifySub?.cancel();
      _notifySub = null;
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

      final notifyChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: EVSEConfig.serviceUuid,
        characteristicId: EVSEConfig.notifyCharUuid,
      );

      await _notifySub?.cancel();
      _notifySub = null;

      _notifySub = _ble.subscribeToCharacteristic(notifyChar).listen(
        (raw) {
          final packet = BleProtocol.parse(raw);
          if (packet == null) return;

          if (chunks.isEmpty || packet.totalChunks != totalChunks) {
            totalLength = packet.totalLength;
            totalChunks = packet.totalChunks;
          }
          chunks[packet.chunkIndex] = packet.payload;
          debugPrint("📥 Targeted $packet");

          if (chunks.length == totalChunks) {
            final assembled = <int>[];
            for (int i = 1; i <= totalChunks!; i++) {
              assembled.addAll(chunks[i] ?? []);
            }
            final trimmed = assembled.length > (totalLength ?? 0)
                ? assembled.sublist(0, totalLength!)
                : assembled;
            final jsonStr = utf8.decode(trimmed, allowMalformed: true);
            debugPrint("✅ Targeted read assembled (${trimmed.length}B)");
            if (!completer.isCompleted) {
              try {
                completer.complete(jsonDecode(jsonStr) as Map<String, dynamic>);
              } catch (e) {
                debugPrint("❌ Targeted read parse failed: $e");
                completer.complete({});
              }
            }
          }
        },
        onError: (e) {
          debugPrint("❌ Targeted notify error: $e");
          if (!completer.isCompleted) completer.complete({});
        },
      );

      await Future.delayed(const Duration(milliseconds: 600));

      debugPrint("📤 Sending targeted REQUEST (selection=$selection)...");
      final requestPackets = BleProtocol.buildPackets(
        [],
        selection: selection,
        format: DataFormat.json,
      );
      await _ble.writeCharacteristicWithResponse(_writeChar(deviceId),
          value: requestPackets[0]);

      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint("⏰ Targeted read timeout (selection=$selection)");
          return {};
        },
      );

      await _notifySub?.cancel();
      _notifySub = null;
      return result;
    });
  }

  // ── Disconnect ───────────────────────────────────────────────
  @override
  void clearGattState(String deviceId) => _gattReady.remove(deviceId);

  @override
  void disconnect(String deviceId) {
    debugPrint("🔌 Disconnecting $deviceId");
    _notifySub?.cancel();
    _notifySub = null;
    clearGattState(deviceId);
  }
}
