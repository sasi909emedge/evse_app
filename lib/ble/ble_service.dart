import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import '../config/evse_config.dart';

/// =====================================================
/// BLE SERVICE — TRANSPORT LAYER ONLY
/// -----------------------------------------------------
/// - No UI logic
/// - No Excel logic
/// - No simulator
/// - Scan → Verify → Communicate
/// =====================================================

class BleService {
  BleService._internal();
  static final BleService instance = BleService._internal();

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  StreamSubscription<ConnectionStateUpdate>? _connectionSub;

  // ================= SCAN =================
  /// Scans ONLY for EVSE devices (by service UUID)
  Stream<DiscoveredDevice> scanDevices() {
    return _ble.scanForDevices(
      withServices: const [], // ← no filter
      scanMode: ScanMode.lowLatency,
    );
  }

  // ================= CONNECT =================
  /// Connects and verifies EVSE service presence
  Stream<ConnectionStateUpdate> connectToDevice(String deviceId) {
    _connectionSub?.cancel();

    final stream = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    );

    _connectionSub = stream.listen((_) {});
    return stream;
  }

  Future<void> verifyEvse(String deviceId) async {
    // ---- First attempt ----
    var services = await _ble.discoverServices(deviceId);

    bool hasEvseService = services.any(
          (s) => s.serviceId == EVSEConfig.serviceUuid,
    );

    if (hasEvseService) return;

    // ---- Android BLE tolerance: wait and retry once ----
    await Future.delayed(const Duration(milliseconds: 700));

    services = await _ble.discoverServices(deviceId);

    hasEvseService = services.any(
          (s) => s.serviceId == EVSEConfig.serviceUuid,
    );

    if (!hasEvseService) {
      throw Exception('Not a valid EVSE device');
    }
  }

  // ================= WRITE CONFIG (BINARY) =================
  /// Writes a binary CONFIG packet to chargerType characteristic
  Future<void> writeConfigPacket(
      String deviceId,
      List<int> packet,
      ) async {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.serviceUuid,
      characteristicId: EVSEConfig.chargerTypeUuid,
    );

    await _ble.writeCharacteristicWithResponse(
      characteristic,
      value: packet,
    );
  }

  // ================= WRITE IDENTIFICATION =================
  /// Writes string identification fields (e.g., Serial)
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

  // ================= STATUS SUBSCRIBE =================
  /// Subscribes to EVSE live status (notify-only)
  Stream<List<int>> subscribeStatus(String deviceId) {
    final characteristic = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: EVSEConfig.serviceUuid,
      characteristicId: EVSEConfig.chargingStatusUuid,
    );

    return _ble.subscribeToCharacteristic(characteristic);
  }

  // ================= DISCONNECT =================
  void disconnect() {
    _connectionSub?.cancel();
    _connectionSub = null;
  }
}

