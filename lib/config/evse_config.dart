import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class EVSEConfig {

  /// ================= READ (DEVICE → APP) =================
  /// Firmware sends notifications / data here
  static final Uuid readServiceUuid =
  Uuid.parse('00001000-0000-1000-8000-00805f9b34fb');

  static final Uuid readCharUuid =
  Uuid.parse('00001001-0000-1000-8000-00805f9b34fb');


  /// ================= WRITE (APP → DEVICE) =================
  /// App sends JSON commands here
  static final Uuid writeServiceUuid =
  Uuid.parse('00002000-0000-1000-8000-00805f9b34fb');

  static final Uuid writeCharUuid =
  Uuid.parse('00002001-0000-1000-8000-00805f9b34fb');
}


