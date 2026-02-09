import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../config/evse_config.dart';

class BleService {
  BleService._internal();
  static final BleService instance = BleService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;

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
    _connectionSub?.cancel();
    _connectionSub = null;

    return _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    );
  }

  // ================= DISCOVER + VERIFY =================
  Future<void> discoverServices(String deviceId) async {
    debugPrint("🔍 Discovering services...");

    await _ble.discoverAllServices(deviceId);

    final services = await _ble.getDiscoveredServices(deviceId);

    if (services.isEmpty) {
      throw Exception("No GATT services discovered");
    }

    bool writeFound = false;
    bool readFound = false;

    for (final s in services) {
      if (s.deviceId == EVSEConfig.deviceWriteServiceUuid) {
        for (final c in s.characteristics) {
          if (c.characteristicId ==
              EVSEConfig.deviceWriteCharacteristicUuid) {
            writeFound = true;
          }
        }
      }

      if (s.deviceId == EVSEConfig.deviceReadServiceUuid) {
        for (final c in s.characteristics) {
          if (c.serviceId ==
              EVSEConfig.deviceReadCharacteristicUuid) {
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

    debugPrint("✅ GATT FULLY READY");
  }

  bool isGattReady(String deviceId) {
    return _gattReady[deviceId] == true;
  }

  // ================= WRITE JSON =================
  Future<void> writeJson(
      String deviceId,
      Map<String, dynamic> json,
      ) async {
    if (!isGattReady(deviceId)) {
      throw Exception("BLE not ready — services missing");
    }

    final characteristic = QualifiedCharacteristic(
      serviceId: EVSEConfig.deviceWriteServiceUuid,
      characteristicId: EVSEConfig.deviceWriteCharacteristicUuid,
      deviceId: deviceId,
    );

    final jsonString = jsonEncode(json);
    final bytes = utf8.encode(jsonString);

    debugPrint("⬆️ WRITING JSON: $jsonString");

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: bytes,
    );
  }

  // ================= READ / NOTIFY =================
  Stream<List<int>> subscribeToDevice(String deviceId) {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.deviceReadServiceUuid,
      characteristicId: EVSEConfig.deviceReadCharacteristicUuid,
    );

    debugPrint("👂 Listening for device updates...");

    return _ble.subscribeToCharacteristic(characteristic);
  }

  // ================= DISCONNECT =================
  void disconnect() {
    _connectionSub?.cancel();
    _connectionSub = null;
  }
}