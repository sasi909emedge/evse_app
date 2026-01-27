import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../config/evse_config.dart';

class BleService {
  BleService._internal();
  static final BleService instance = BleService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;

  // ================= SCAN =================
  Stream<DiscoveredDevice> scanDevices() {
    return _ble.scanForDevices(
      withServices: const[], // scan all, verify later
      scanMode: ScanMode.lowLatency,
    );
  }

  // ================= CONNECT (CRITICAL FIX) =================
  Stream<ConnectionStateUpdate> connectToDevice(String deviceId) {
    _connectionSub?.cancel();

    final stream = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    );

    // 🔒 KEEP CONNECTION ALIVE
    _connectionSub = stream.listen((_) {});

    return stream;
  }

  // ================= WRITE SERIAL =================
  Future<void> writeStringCharacteristic(
      String deviceId,
      Uuid characteristicUuid,
      String value,
      ) async {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.serviceUuid,
      characteristicId: characteristicUuid,
    );

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: value.codeUnits,
    );
  }

  // ================= WRITE CONFIG (BINARY) =================
  Future<void> writeConfigPacket(
      String deviceId,
      List<int> packet,
      ) async {
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