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

    await Future.delayed(const Duration(milliseconds: 700));

    await _ble.discoverAllServices(deviceId);

    final services = await _ble.getDiscoveredServices(deviceId);

    bool writeFound = false;
    bool readFound = false;

    for (final s in services) {
      if (s.id == EVSEConfig.writeServiceUuid) {
        for (final c in s.characteristics) {
          if (c.id == EVSEConfig.writeCharUuid) {
            writeFound = true;
          }
        }
      }

      if (s.id == EVSEConfig.readServiceUuid) {
        for (final c in s.characteristics) {
          if (c.id == EVSEConfig.readCharUuid) {
            readFound = true;
          }
        }
      }
    }

    if (!writeFound) {
      throw Exception("WRITE characteristic NOT FOUND");
    }

    if (!readFound) {
      throw Exception("READ characteristic NOT FOUND");
    }

    _gattReady[deviceId] = true;

    debugPrint("✅ GATT READY — DEVICE SAFE");
  }

  bool isGattReady(String deviceId) {
    return _gattReady[deviceId] == true;
  }

  // ================= WRITE =================
  Future<void> writeJson(
      String deviceId,
      Map<String, dynamic> json,
      ) async {

    if (!isGattReady(deviceId)) {
      throw Exception("BLE not ready");
    }

    final characteristic = QualifiedCharacteristic(
      serviceId: EVSEConfig.writeServiceUuid,
      characteristicId: EVSEConfig.writeCharUuid,
      deviceId: deviceId,
    );

    final jsonString = jsonEncode(json);
    final bytes = utf8.encode(jsonString);

    debugPrint("⬆️ WRITE: $jsonString");

    await Future.delayed(const Duration(milliseconds: 150));

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: bytes,
    );
  }

  // ================= ⭐ TRUE READ =================
  Future<Map<String, dynamic>> readJson(String deviceId) async {

    if (!isGattReady(deviceId)) {
      throw Exception("BLE not ready");
    }

    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.readServiceUuid,
      characteristicId: EVSEConfig.readCharUuid,
    );

    debugPrint("📥 Performing BLE READ...");

    final data = await _ble.readCharacteristic(characteristic);

    final jsonString = utf8.decode(data);

    debugPrint("✅ READ JSON: $jsonString");

    return jsonDecode(jsonString);
  }

  // ================= NOTIFY =================
  Stream<List<int>> subscribeToDevice(String deviceId) {

    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.readServiceUuid,
      characteristicId: EVSEConfig.readCharUuid,
    );

    debugPrint("👂 Listening for notifications");

    return _ble.subscribeToCharacteristic(characteristic);
  }

  // ================= DISCONNECT =================
  void disconnect(String deviceId) {
    debugPrint("🔌 Clearing BLE state");
    _gattReady.remove(deviceId);
  }
}