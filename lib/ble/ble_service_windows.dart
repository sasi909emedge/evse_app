import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:win_ble/win_ble.dart';
import 'package:win_ble/win_file.dart';
import 'ble_service_base.dart' as base;

// ================================================================
// WINDOWS BLE SERVICE — win_ble 1.1.1
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
  StreamSubscription? _notifySubscription;
  Future<void> _operation = Future.value();
  static const int _writeChunkSize = 180;

  // Hardcoded UUIDs — exact strings from ESP discovery
  static const String _svcUuid = 'fb349b5f-8000-0080-0010-000000100000';
  static const String _readUuid = 'fb349b5f-8000-0080-0010-000000001000';
  static const String _writeUuid = 'fb349b5f-8000-0080-0010-000000002000';
  static const String _notifyUuid = 'fb349b5f-8000-0080-0010-000000003000';

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
    final controller = StreamController<base.BleConnectionState>.broadcast();
    controller.add(base.BleConnectionState.connecting);

    WinBle.connectionStreamOf(deviceId).listen((connected) {
      debugPrint("WinBLE connection: $connected");
      controller.add(connected
          ? base.BleConnectionState.connected
          : base.BleConnectionState.disconnected);
    });

    WinBle.connect(deviceId);
    return controller.stream;
  }

  // ── Discover ─────────────────────────────────────────────────
  @override
  Future<void> discoverServices(String deviceId) async {
    debugPrint("⏳ WinBLE: settling...");
    await Future.delayed(const Duration(milliseconds: 1500));

    debugPrint("🔍 WinBLE: discovering services...");
    final services = await WinBle.discoverServices(deviceId);
    for (final s in services) {
      debugPrint("📡 SERVICE: $s");
      try {
        final chars = await WinBle.discoverCharacteristics(
          address: deviceId,
          serviceId: s,
        );
        for (final c in chars) {
          debugPrint("   └─ CHAR: ${c.uuid}");
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
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(json)));
      final total = bytes.length;
      debugPrint("⬆️ WinBLE WRITE: $total bytes");

      int offset = 0, idx = 0;
      while (offset < total) {
        final end = (offset + _writeChunkSize < total)
            ? offset + _writeChunkSize
            : total;
        final chunk = Uint8List.fromList(bytes.sublist(offset, end));

        await WinBle.write(
          address: deviceId,
          service: _svcUuid,
          characteristic: _writeUuid,
          data: chunk,
          writeWithResponse: true,
        );

        debugPrint("✅ WinBLE chunk $idx ACK'd");
        offset = end;
        idx++;
        if (offset < total) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      debugPrint("✅ WinBLE WRITE COMPLETE — $idx chunks");
    });
  }

  // ── Send Command ─────────────────────────────────────────────
  @override
  Future<void> sendCommand(String deviceId, String command) {
    return _queue(() async {
      debugPrint("📤 WinBLE COMMAND: $command");
      await WinBle.write(
        address: deviceId,
        service: _svcUuid,
        characteristic: _writeUuid,
        data: Uint8List.fromList(utf8.encode(command)),
        writeWithResponse: true,
      );
      debugPrint("✅ WinBLE COMMAND ACK'd");
    });
  }

  // ── Read JSON ────────────────────────────────────────────────
  // HOW THIS WORKS:
  // 1. Subscribe to notify characteristic
  // 2. Write a single byte to the WRITE characteristic to trigger ESP
  //    (ESP sees a write starting with non-'{' so it ignores it as JSON,
  //     but we use a special trigger byte 0x01 that we handle in ESP)
  //
  // ACTUALLY: On our ESP, a READ on the read characteristic triggers notify.
  // win_ble read() returns data directly — it doesn't trigger notify.
  // So we use WinBle.read() to get the "OK" response, which also
  // tells ESP to send notify. The notify arrives on characteristicValueStream.
  @override
  Future<Map<String, dynamic>> readJson(String deviceId) {
    return _queue(() async {
      final completer = Completer<Map<String, dynamic>>();
      final buffer = StringBuffer();

      await _notifySubscription?.cancel();
      _notifySubscription = null;

      // Step 1: Subscribe to notify BEFORE triggering read
      debugPrint("📥 WinBLE: subscribing to notify...");
      try {
        await WinBle.subscribeToCharacteristic(
          address: deviceId,
          serviceId: _svcUuid,
          characteristicId: _notifyUuid,
        );
        debugPrint("📥 WinBLE: subscribed to notify ✅");
      } catch (e) {
        debugPrint("❌ WinBLE subscribe error: $e");
      }

      // Step 2: Listen to all characteristic value events
      _notifySubscription = WinBle.characteristicValueStream.listen((event) {
        debugPrint("📡 RAW EVENT: $event");

        final addr = (event["address"] ?? "").toString();
        final charId = (event["characteristicId"] ??
                event["characteristic"] ??
                event["uuid"] ??
                "")
            .toString()
            .toLowerCase();

        debugPrint("📡 addr=$addr charId=$charId");

        // Accept if address matches (case insensitive)
        if (addr.toLowerCase() != deviceId.toLowerCase()) {
          debugPrint("📡 skipping — address mismatch");
          return;
        }

        // Accept if charId matches notify OR if charId is empty (some versions)
        if (charId.isNotEmpty && charId != _notifyUuid) {
          debugPrint("📡 skipping — char mismatch ($charId != $_notifyUuid)");
          return;
        }

        final raw = event["value"];
        List<int> data = [];
        if (raw is List) {
          data = raw.cast<int>();
        } else if (raw is Uint8List) {
          data = raw.toList();
        }

        if (data.isEmpty) {
          debugPrint("📡 skipping — empty data");
          return;
        }

        final text = utf8.decode(data, allowMalformed: true);
        debugPrint("📥 WinBLE CHUNK: $text");
        buffer.write(text);

        final received = buffer.toString();
        if (received.contains("#END#") && received.contains("}")) {
          String jsonText = received.replaceAll("#END#", "").trim();
          final start = jsonText.indexOf('{');
          final end = jsonText.lastIndexOf('}');
          if (start >= 0 && end > start) {
            jsonText = jsonText.substring(start, end + 1);
          }
          jsonText = jsonText.replaceAll(RegExp(r',\s*}'), '}');
          debugPrint("✅ WinBLE FINAL JSON: $jsonText");

          if (!completer.isCompleted) {
            try {
              completer.complete(jsonDecode(jsonText) as Map<String, dynamic>);
            } catch (e) {
              debugPrint("❌ WinBLE PARSE FAILED: $e");
              completer.complete({});
            }
          }
        }
      });

      // Step 3: Wait for subscription to reach ESP
      await Future.delayed(const Duration(milliseconds: 800));

      // Step 4: Trigger ESP to send notify by reading the read characteristic
      // WinBle.read() sends a GATT Read Request → ESP receives READ_EVT
      // → ESP sends "OK" response + triggers send_json_notify()
      debugPrint("📤 WinBLE: triggering READ on $_readUuid...");
      try {
        final readResult = await WinBle.read(
          address: deviceId,
          serviceId: _svcUuid,
          characteristicId: _readUuid,
        );
        debugPrint("📤 WinBLE read response: $readResult");
      } catch (e) {
        debugPrint("❌ WinBLE read trigger error: $e");
        // Even if read fails, notify might still come
      }

      debugPrint("⏳ WinBLE: waiting for notify chunks...");

      // Step 5: Wait for all notify chunks
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint("⏰ WinBLE timeout — buffer: '${buffer.toString()}'");
          return {};
        },
      );

      // Step 6: Clean up
      await _notifySubscription?.cancel();
      _notifySubscription = null;

      try {
        await WinBle.unSubscribeFromCharacteristic(
          address: deviceId,
          serviceId: _svcUuid,
          characteristicId: _notifyUuid,
        );
      } catch (_) {}

      return result;
    });
  }

  // ── Clear / Disconnect ───────────────────────────────────────
  @override
  void clearGattState(String deviceId) => _gattReady.remove(deviceId);

  @override
  void disconnect(String deviceId) {
    debugPrint("🔌 WinBLE disconnecting $deviceId");
    _notifySubscription?.cancel();
    _notifySubscription = null;
    clearGattState(deviceId);
    WinBle.disconnect(deviceId);
  }
}
