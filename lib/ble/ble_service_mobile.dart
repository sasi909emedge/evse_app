import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../config/evse_config.dart';
import 'ble_service_base.dart';

// ================================================================
// MOBILE BLE SERVICE (Android + iOS)
// Uses flutter_reactive_ble
// ================================================================
class BleServiceMobile extends BleServiceBase {
  BleServiceMobile._internal();
  static final BleServiceMobile instance = BleServiceMobile._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  final Map<String, bool> _gattReady = {};
  final Map<String, DateTime> _readyTime = {};

  static const int _writeChunkSize = 180;

  Future<void> _operation = Future.value();
  StreamSubscription<List<int>>? _notifySubscription;

  Future<T> _queue<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _operation = _operation.then((_) async {
      try {
        final result = await task();
        completer.complete(result);
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  // ── Scan ────────────────────────────────────────────────────
  @override
  Stream<BleDevice> scanDevices() {
    return _ble.scanForDevices(
      withServices: const [],
      scanMode: ScanMode.lowLatency,
    ).map((d) => BleDevice(
          id: d.id,
          name: d.name,
          rssi: d.rssi,
        ));
  }

  // ── Connect ─────────────────────────────────────────────────
  @override
  Stream<BleConnectionState> connectToDevice(String deviceId) {
    debugPrint("🔵 Connecting to $deviceId");
    return _ble
        .connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 15),
    )
        .map((update) {
      switch (update.connectionState) {
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
    debugPrint("⏳ Waiting for ESP GATT to settle...");
    await Future.delayed(const Duration(milliseconds: 1500));

    debugPrint("🔍 Discovering services...");
    await _ble.discoverAllServices(deviceId);

    final services = await _ble.getDiscoveredServices(deviceId);
    for (final s in services) {
      debugPrint("📡 SERVICE: ${s.id}");
      for (final c in s.characteristics) {
        debugPrint("   └─ CHAR: ${c.id}");
      }
    }

    try {
      await _ble.requestMtu(deviceId: deviceId, mtu: 247);
      debugPrint("✅ MTU negotiated");
    } catch (_) {
      debugPrint("⚠️ MTU failed, using default");
    }

    await Future.delayed(const Duration(milliseconds: 500));

    _gattReady[deviceId] = true;
    _readyTime[deviceId] = DateTime.now();
    debugPrint("✅ GATT READY");
  }

  @override
  bool isGattReady(String deviceId) => _gattReady[deviceId] == true;

  // ── Write JSON ───────────────────────────────────────────────
  @override
  Future<void> writeJson(String deviceId, Map<String, dynamic> json) {
    return _queue(() async {
      final characteristic = QualifiedCharacteristic(
        serviceId: EVSEConfig.writeServiceUuid,
        characteristicId: EVSEConfig.writeCharUuid,
        deviceId: deviceId,
      );

      final bytes = utf8.encode(jsonEncode(json));
      final total = bytes.length;
      debugPrint("⬆️ WRITE: ${bytes.length} bytes");

      int offset = 0, idx = 0;
      while (offset < total) {
        final end = (offset + _writeChunkSize < total)
            ? offset + _writeChunkSize
            : total;
        final chunk = bytes.sublist(offset, end);

        await _ble.writeCharacteristicWithResponse(characteristic,
            value: chunk);

        debugPrint("✅ Chunk $idx ACK'd");
        offset = end;
        idx++;

        if (offset < total) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      debugPrint("✅ WRITE COMPLETE — $idx chunks");
    });
  }

  // ── Send Command ─────────────────────────────────────────────
  @override
  Future<void> sendCommand(String deviceId, String command) {
    return _queue(() async {
      final characteristic = QualifiedCharacteristic(
        serviceId: EVSEConfig.writeServiceUuid,
        characteristicId: EVSEConfig.writeCharUuid,
        deviceId: deviceId,
      );
      debugPrint("📤 COMMAND: $command");
      await _ble.writeCharacteristicWithResponse(
        characteristic,
        value: utf8.encode(command),
      );
      debugPrint("✅ COMMAND ACK'd");
    });
  }

  // ── Read JSON ────────────────────────────────────────────────
  @override
  Future<Map<String, dynamic>> readJson(String deviceId) {
    return _queue(() async {
      final completer = Completer<Map<String, dynamic>>();
      final buffer = StringBuffer();

      final notifyChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: EVSEConfig.serviceUuid,
        characteristicId: EVSEConfig.notifyCharUuid,
      );
      final readChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: EVSEConfig.serviceUuid,
        characteristicId: EVSEConfig.readCharUuid,
      );

      await _notifySubscription?.cancel();
      _notifySubscription = null;

      _notifySubscription =
          _ble.subscribeToCharacteristic(notifyChar).listen((data) {
        final text = utf8.decode(data);
        debugPrint("📥 CHUNK: $text");
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

          if (!completer.isCompleted) {
            try {
              completer.complete(jsonDecode(jsonText) as Map<String, dynamic>);
            } catch (e) {
              debugPrint("❌ PARSE FAILED: $e");
              completer.complete({});
            }
          }
        }
      }, onError: (e) {
        if (!completer.isCompleted) completer.complete({});
      });

      await Future.delayed(const Duration(milliseconds: 600));
      await _ble.readCharacteristic(readChar);

      final result = await completer.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => {},
      );

      await _notifySubscription?.cancel();
      _notifySubscription = null;
      return result;
    });
  }

  // ── Clear / Disconnect ───────────────────────────────────────
  @override
  void clearGattState(String deviceId) {
    _gattReady.remove(deviceId);
    _readyTime.remove(deviceId);
  }

  @override
  void disconnect(String deviceId) {
    debugPrint("🔌 Disconnecting $deviceId");
    _notifySubscription?.cancel();
    _notifySubscription = null;
    clearGattState(deviceId);
  }
}
