import 'dart:typed_data';
import '../config/evse_config.dart';

class BleProtocol {
  // Charger type enum (keep in sync with firmware)
  static const Map<String, int> chargerTypeEnum = {
    'AC-7S': 0,
    'AC-14T': 1,
    'AC-22T': 2,
  };

  static const Map<String, int> maxPowerKw = {
    'AC-7S': 7,
    'AC-14T': 14,
    'AC-22T': 22,
  };

  static const Map<String, String> phaseSupport = {
    'AC-7S': 'Single',
    'AC-14T': 'Three',
    'AC-22T': 'Three',
  };

  static String statusToText(int status) {
    switch (status) {
      case 0x00:
        return 'Idle';
      case 0x01:
        return 'Charging';
      case 0x02:
        return 'Fault';
      case 0x10:
        return 'ConfigApplied';
      default:
        return 'Unknown';
    }
  }

  // Helper: convert decimal amps to uint16 (amps * 100)
  static int ampsToUint16(double amps) {
    return (amps * 100).round().clamp(0, 0xFFFF);
  }

  static double uint16ToAmps(int v) => v / 100.0;

  // Build the 32-byte config packet (must match firmware)
  static List<int> buildConfigPacket({
    required String chargerType,
    required int connectorCount,
    required int overVoltage,
    required int underVoltage,
    required int overTemperature,
    required bool restoreSession,
    required int restoreTimeout,
    required bool gfci,
    required double ocLimitC1,
    required double ocLimitC2,
    required double ocLimitC3,
    required int lowCurrentTime,
    required double minLowCurrent,
    required int suspendedBehaviour,
    required int suspendedTime,
    required bool phaseMgmt,
    required bool loadMgmt,
    required bool wifiEnable,
    required bool gsmEnable,
    required bool ethEnable,
    required int wifiPriority,
    required int gsmPriority,
    required int ethPriority,
  }) {
    final packet = Uint8List(EVSEConfig.configPacketLength);
    final b = packet.buffer.asByteData();

    // Header & version
    b.setUint8(0, EVSEConfig.packetHeader);
    b.setUint8(1, EVSEConfig.packetVersion);

    // Charger type & connector count
    final type = chargerTypeEnum[chargerType] ?? 0;
    b.setUint8(2, type);
    b.setUint8(3, connectorCount.clamp(1, 3));

    // Over/Under voltage (uint16 little-endian)
    b.setUint16(4, overVoltage.clamp(0, 0xFFFF), Endian.little);
    b.setUint16(6, underVoltage.clamp(0, 0xFFFF), Endian.little);

    // Over temperature
    b.setUint8(8, overTemperature.clamp(0, 0xFF));

    // Restore session enable
    b.setUint8(9, restoreSession ? 1 : 0);

    // Restore timeout (seconds)
    b.setUint16(10, restoreTimeout.clamp(0, 0xFFFF), Endian.little);

    // GFCI
    b.setUint8(12, gfci ? 1 : 0);

    // Over current limits (amps * 100)
    b.setUint16(13, ampsToUint16(ocLimitC1), Endian.little);
    b.setUint16(15, ampsToUint16(ocLimitC2), Endian.little);
    b.setUint16(17, ampsToUint16(ocLimitC3), Endian.little);

    // Low current time
    b.setUint16(19, lowCurrentTime.clamp(0, 0xFFFF), Endian.little);

    // Minimum low current (amps * 100)
    b.setUint16(21, ampsToUint16(minLowCurrent), Endian.little);

    // Suspended behaviour & time
    b.setUint8(23, suspendedBehaviour & 0xFF);
    b.setUint16(24, suspendedTime.clamp(0, 0xFFFF), Endian.little);

    // Phase & load management
    b.setUint8(26, phaseMgmt ? 1 : 0);
    b.setUint8(27, loadMgmt ? 1 : 0);

    // Connectivity flags (bit0=WiFi, bit1=GSM, bit2=Ethernet)
    int flags = 0;
    if (wifiEnable) flags |= 0x01;
    if (gsmEnable) flags |= 0x02;
    if (ethEnable) flags |= 0x04;
    b.setUint8(28, flags);

    // Priorities
    b.setUint8(29, wifiPriority.clamp(1, 3));
    b.setUint8(30, gsmPriority.clamp(1, 3));

    // Checksum (simple XOR of bytes 0..30)
    int xor = 0;
    for (int i = 0; i < EVSEConfig.configPacketLength - 1; i++) {
      xor ^= packet[i];
    }
    b.setUint8(31, xor & 0xFF);

    return packet.toList();
  }
}
