import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class EVSEConfig {

  /// ================= DEVICE → APP (READ / NOTIFY) =================
  /// Firmware UUID:
  /// FB349B5F-8000-0080-0010-000001100000
  static final Uuid readServiceUuid =
  Uuid.parse('fb349b5f-8000-0080-0010-000000100000');

  static final Uuid readCharUuid =
  Uuid.parse('fb349b5f-8000-0080-0010-000001100000');

  /// ================= APP → DEVICE (WRITE) =================
  /// Firmware UUID:
  /// FB349B5F-8000-0080-0010-000001200000
  static final Uuid writeServiceUuid =
  Uuid.parse('fb349b5f-8000-0080-0010-000000200000');

  static final Uuid writeCharUuid =
  Uuid.parse('fb349b5f-8000-0080-0010-000001200000');
}

