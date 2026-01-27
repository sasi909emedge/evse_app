import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class EVSEConfig {
  // ================= SERVICE =================
  static final Uuid serviceUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef0");

  // ================= CHARACTERISTICS =================
  static final Uuid serialUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef1");

  static final Uuid configUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcde22"); // ✅ CONFIG (BINARY)

  static final Uuid chargingStatusUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcde07");
}

