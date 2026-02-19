import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class EVSEConfig {

  /// READ SERVICE
  static final Uuid readServiceUuid =
  Uuid.parse('fb349b5f-8000-0080-0010-000000100000');

  /// READ CHARACTERISTIC
  static final Uuid readCharUuid =
  Uuid.parse('fb349b5f-8000-0080-0010-000001100000');

  /// WRITE SERVICE
  static final Uuid writeServiceUuid =
  Uuid.parse('fb349b5f-8000-0080-0010-000000200000');

  /// WRITE CHARACTERISTIC
  static final Uuid writeCharUuid =
  Uuid.parse('fb349b5f-8000-0080-0010-000001200000');
}