import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

/// =====================================================
/// EVSE BLE UUID CONTRACT
/// -----------------------------------------------------
/// - MUST match ESP-IDF exactly
/// - ONLY Excel-backed + ESP-implemented UUIDs live here
/// - No simulator
/// - No unused characteristics
/// =====================================================

class EVSEConfig {
  /// ================= PRIMARY SERVICE =================
  /// EVSE Primary Service UUID
  static final Uuid serviceUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef0");

  /// ================= IDENTIFICATION =================
  /// Serial Number (Read / Write)
  static final Uuid serialUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef1");

  /// ================= CONFIGURATION =================
  /// Charger Type (Read / Write)
  static final Uuid chargerTypeUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcde22");

  /// Connector Count (Read / Write)
  static final Uuid connectorCountUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcde21");

  /// ================= LIVE STATUS =================
  /// Charging Status (Notify / Read)
  static final Uuid chargingStatusUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef7");
}

/// =====================================================
/// GLOBAL FLAGS
/// =====================================================

/// Simulator is permanently disabled.
/// Real ESP firmware is the only source of truth.
const bool BLE_SIMULATOR_MODE = false;

