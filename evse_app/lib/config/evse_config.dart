import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class EVSEConfig {
  // ================= PRIMARY SERVICE =================
  static final Uuid serviceUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef0");

  // ================= IDENTIFICATION =================
  static final Uuid serialUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef1");
  static final Uuid nameUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef2");
  static final Uuid vendorUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef3");
  static final Uuid modelUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef4");
  static final Uuid commissionedByUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef5");
  static final Uuid commissionedDateUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef6");
  static final Uuid locationUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef8");

  // ================= LIVE STATUS =================
  static final Uuid chargingStatusUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef7");

  // ================= CONNECTOR / CHARGER =================
  static final Uuid connectorCountUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcde21");

  // 🔒 IMPORTANT: Charger Type (MATCHES ESP + EXCEL)
  static final Uuid chargerTypeUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcde22");
}

const bool BLE_SIMULATOR_MODE = false;
