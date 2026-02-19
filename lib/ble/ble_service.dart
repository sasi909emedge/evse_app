import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../config/evse_config.dart';

class BleService {
  BleService._internal();
  static final BleService instance = BleService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  final Map<String, bool> _gattReady = {};
  final Map<String, DateTime> _readyTime = {};

  Future<void> _operation = Future.value();

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

  // ================= SCAN =================
  Stream<DiscoveredDevice> scanDevices() {
    return _ble.scanForDevices(
      withServices: const [],
      scanMode: ScanMode.lowLatency,
    );
  }

  // ================= CONNECT =================
  Stream<ConnectionStateUpdate> connectToDevice(String deviceId) {
    debugPrint("🔵 Connecting to $deviceId");
    return _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 15),
    );
  }

  // ================= DISCOVER =================
  Future<void> discoverServices(String deviceId) async {
    debugPrint("🔍 Discovering services...");
    await _ble.discoverAllServices(deviceId);

    final services = await _ble.getDiscoveredServices(deviceId);
    for (final service in services) {
      debugPrint("📡 SERVICE: ${service.id}");
      for (final char in service.characteristics) {
        debugPrint("   └─ CHAR: ${char.id}");
      }
    }

    try {
      await _ble.requestMtu(deviceId: deviceId, mtu: 247);
    } catch (_) {}

    _gattReady[deviceId] = true;
    _readyTime[deviceId] = DateTime.now();
    debugPrint("✅ GATT READY");
  }

  bool isGattReady(String deviceId) => _gattReady[deviceId] == true;

  // ================= WRITE =================
  Future<void> writeJson(String deviceId, Map<String, dynamic> json) {
    return _queue(() async {
      final characteristic = QualifiedCharacteristic(
        serviceId: EVSEConfig.writeServiceUuid,
        characteristicId: EVSEConfig.writeCharUuid,
        deviceId: deviceId,
      );

      final jsonString = jsonEncode(json);
      debugPrint("⬆️ WRITE: $jsonString");

      await _ble.writeCharacteristicWithResponse(
        characteristic,
        value: utf8.encode(jsonString),
      );
    });
  }

  // ================= READ =================
  Future<Map<String, dynamic>> readJson(String deviceId) {
    return _queue(() async {
      final characteristic = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: EVSEConfig.readServiceUuid,
        characteristicId: EVSEConfig.readCharUuid,
      );

      debugPrint("📥 Performing BLE READ");
      debugPrint("   serviceId:  ${EVSEConfig.readServiceUuid}");
      debugPrint("   charUuid:   ${EVSEConfig.readCharUuid}");

      final raw = await _ble.readCharacteristic(characteristic);

      debugPrint("📦 RAW BYTES (${raw.length}): $raw");

      // Remove NULL padding
      final cleanedBytes = raw.where((b) => b != 0).toList();
      final decoded = utf8.decode(cleanedBytes);

      debugPrint("📝 DECODED STRING: $decoded");

      final start = decoded.indexOf('{');
      final end = decoded.lastIndexOf('}');

      if (start == -1 || end == -1) {
        debugPrint("❌ Invalid JSON frame: $decoded");
        return {};
      }

      final jsonString = decoded.substring(start, end + 1);
      debugPrint("✅ CLEAN JSON: $jsonString");
      debugPrint("✅ JSON LENGTH: ${jsonString.length}");

      try {
        final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
        debugPrint("✅ PARSED KEYS: ${parsed.keys.toList()}");
        return parsed;
      } catch (e) {
        debugPrint("❌ JSON PARSE ERROR: $e");
        return {};
      }
    });
  }

  // ================= CLEAR GATT STATE =================
  void clearGattState(String deviceId) {
    _gattReady.remove(deviceId);
    _readyTime.remove(deviceId);
  }

  // ================= DISCONNECT =================
  void disconnect(String deviceId) {
    debugPrint("🔌 Clearing BLE state for $deviceId");
    clearGattState(deviceId);
  }
}