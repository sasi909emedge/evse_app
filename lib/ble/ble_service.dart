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

  /// ✅ SAFE SERIAL QUEUE
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

    try {
      await _ble.requestMtu(deviceId: deviceId, mtu: 247);
      debugPrint("✅ MTU requested");
    } catch (_) {}

    final services = await _ble.getDiscoveredServices(deviceId);

    bool writeFound = false;
    bool readFound = false;

    for (final s in services) {
      if (s.id == EVSEConfig.writeServiceUuid) {
        for (final c in s.characteristics) {
          if (c.id == EVSEConfig.writeCharUuid) writeFound = true;
        }
      }

      if (s.id == EVSEConfig.readServiceUuid) {
        for (final c in s.characteristics) {
          if (c.id == EVSEConfig.readCharUuid) readFound = true;
        }
      }
    }

    if (!writeFound || !readFound) {
      throw Exception("Required characteristics NOT FOUND");
    }

    _gattReady[deviceId] = true;

    debugPrint("✅ GATT READY — DEVICE SAFE");
  }

  bool isGattReady(String deviceId) =>
      _gattReady[deviceId] == true;

  // ================= WRITE =================
  Future<void> writeJson(
      String deviceId,
      Map<String, dynamic> json,
      ) {
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

      final data = await _ble.readCharacteristic(characteristic);

      final jsonString = utf8.decode(data);

      debugPrint("✅ READ JSON: $jsonString");

      return jsonDecode(jsonString);
    });
  }

  void disconnect(String deviceId) {
    debugPrint("🔌 Clearing BLE state");
    _gattReady.remove(deviceId);
  }
}
