import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class EVSEConfig {
  // ESP GATT SERVICE
  static final Uuid serviceUuid =
      Uuid.parse('fb349b5f-8000-0080-0010-000000100000');

  // READ CHARACTERISTIC
  static final Uuid readCharUuid =
      Uuid.parse('fb349b5f-8000-0080-0010-000000001000');

  // WRITE CHARACTERISTIC
  static final Uuid writeCharUuid =
      Uuid.parse('fb349b5f-8000-0080-0010-000000002000');

  /// NOTIFY CHARACTERISTIC
  static final Uuid notifyCharUuid =
      Uuid.parse('fb349b5f-8000-0080-0010-000000003000');

  static Uuid get readServiceUuid => serviceUuid;
  static Uuid get writeServiceUuid => serviceUuid;
}
