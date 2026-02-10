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
  final Map<String, StreamSubscription<List<int>>> _notifySubs = {};

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

    /// Android BLE stack needs breathing room
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

    debugPrint("✅ GATT READY — DEVICE IS SAFE");
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

    debugPrint("⬆️ WRITING JSON: $jsonString");

    /// Prevent Android race condition
    await Future.delayed(const Duration(milliseconds: 150));

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: bytes,
    );
  }

  // ================= READ / SUBSCRIBE =================
  Stream<List<int>> subscribeToDevice(String deviceId) {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.readServiceUuid,
      characteristicId: EVSEConfig.readCharUuid,
    );

    debugPrint("👂 Subscribing to notifications");

    final stream = _ble.subscribeToCharacteristic(characteristic);

    return stream;
  }

  // ================= CLEAN DISCONNECT =================
  void disconnect(String deviceId) {
    debugPrint("🔌 Cleaning BLE state");

    _notifySubs[deviceId]?.cancel();
    _notifySubs.remove(deviceId);

    _gattReady.remove(deviceId);
  }
}