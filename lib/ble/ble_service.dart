import 'dart:async';
import 'dart:convert';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../config/evse_config.dart';

class BleService {
  BleService._internal();
  static final BleService instance = BleService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  // 🔒 KEEP CONNECTION ALIVE (CRITICAL FIX)
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;

  // ================= SCAN =================
  Stream<DiscoveredDevice> scanDevices() {
    return _ble.scanForDevices(
      withServices: const [],
      scanMode: ScanMode.lowLatency,
    );
  }

  // ================= CONNECT (FIXED) =================
  Stream<ConnectionStateUpdate> connectToDevice(String deviceId) {
    // cancel any previous connection
    _connectionSub?.cancel();

    final stream = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    );

    // 🔑 KEEP LISTENING — DO NOT REMOVE
    _connectionSub = stream.listen((update) {
      // you can log if needed
      // print('[BLE] ${update.connectionState}');
    });

    return stream;
  }

  // ================= WRITE STRING =================
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

    final data = utf8.encode(value);

    // DEBUG (KEEP THIS)
    print(
      '[BLE WRITE] ${characteristicUuid.toString()} -> "$value" (${data.length} bytes)',
    );

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: data,
    );

    print('[BLE WRITE OK]');
  }

  // ================= RAW SUBSCRIBE =================
  Stream<List<int>> subscribeRawCharacteristic(
      String deviceId,
      Uuid characteristicUuid,
      ) {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.serviceUuid,
      characteristicId: characteristicUuid,
    );

    return _ble.subscribeToCharacteristic(characteristic);
  }

  // ================= STATUS SUBSCRIBE =================
  Stream<int> subscribeStatus(
      String deviceId,
      Uuid characteristicUuid,
      ) {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.serviceUuid,
      characteristicId: characteristicUuid,
    );

    return _ble
        .subscribeToCharacteristic(characteristic)
        .where((data) => data.isNotEmpty)
        .map((data) => data.first);
  }
}
