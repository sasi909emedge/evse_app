import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class EVSEConfig {
  // Service and characteristic UUIDs (match firmware)
  static final Uuid serviceUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef0");

  static final Uuid serialUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcdef1");

  static final Uuid configUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcde22");

  static final Uuid chargingStatusUuid =
  Uuid.parse("12345678-1234-5678-1234-56789abcde07");

  // Packet constants
  static const int configPacketLength = 32;
  static const int packetHeader = 0xA5;
  static const int packetVersion = 0x01;
}

