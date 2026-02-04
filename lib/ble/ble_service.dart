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

  // Keep last MTU value per device
  final Map<String, int> _deviceMtu = {};
  final Map<String, bool> _gattReady = {};

  // ================= SCAN =================
  Stream<DiscoveredDevice> scanDevices() {
    // No service filter: show all nearby BLE devices for debugging
    return _ble.scanForDevices(
      withServices: const [],            // required; empty = no filter
      scanMode: ScanMode.lowLatency,
    );
  }

  // ================= CONNECT =================
  Stream<ConnectionStateUpdate> connectToDevice(String deviceId) {
    // Cancel any previous internal subscription we may have kept
    _connectionSub?.cancel();
    _connectionSub = null;

    // Return the raw connection stream to the caller.
    // Do NOT call listen() here — let the caller subscribe once.
    final stream = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    );

    return stream;
  }

  Future<int> requestMtu(String deviceId, int mtu) async {
    try {
      final negotiated = await _ble.requestMtu(deviceId: deviceId, mtu: mtu);
      _deviceMtu[deviceId] = negotiated;
      return negotiated;
    } catch (e) {
      debugPrint('MTU request failed: $e');
      rethrow;
    }
  }

  // ================= DISCOVER SERVICES =================
  Future<void> discoverServices(String deviceId) async {
    await _ble.discoverAllServices(deviceId);

    final services = await _ble.getDiscoveredServices(deviceId);
    if (services.isEmpty) {
      throw Exception('No GATT services discovered');
    }

    _gattReady[deviceId] = true;
  }
  bool isGattReady(String deviceId) {
    return _gattReady[deviceId] == true;
  }

  // ================= WRITE STRING (UTF-8) =================
  Future<void> writeStringCharacteristic(
      String deviceId, Uuid characteristicUuid, String value) async {

    if (!isGattReady(deviceId)) {
      throw Exception('BLE GATT not ready');
    }
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.serviceUuid,
      characteristicId: characteristicUuid,
    );

    final bytes = utf8.encode(value);
    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: bytes,
    );
  }

  // ================= WRITE CONFIG (32 bytes) =================
  Future<void> writeConfigPacket(String deviceId, List<int> packet) async {

    if (!isGattReady(deviceId)) {
      throw Exception('BLE GATT not ready');
    }
    final mtu = _deviceMtu[deviceId] ?? 23; // defa ult ATT MTU 23
    // ATT payload = MTU - 3; ensure payload >= 32`
    final payloadSize = mtu - 3;
    if (payloadSize < EVSEConfig.configPacketLength) {
      // If MTU too small, still attempt write but warn caller
      // Caller (UI) should show an error; here we still attempt
    }

    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.serviceUuid,
      characteristicId: EVSEConfig.configUuid,
    );

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: packet,
    );
  }

  // ================= STATUS SUBSCRIBE =================
  Stream<int> subscribeStatus(String deviceId) {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.serviceUuid,
      characteristicId: EVSEConfig.chargingStatusUuid,
    );

    return _ble
        .subscribeToCharacteristic(characteristic)
        .where((data) => data.isNotEmpty)
        .map((data) => data.first);
  }

  // ================= DISCONNECT =================
  void disconnect() {
    _connectionSub?.cancel();
    _connectionSub = null;
  }
}