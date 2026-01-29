/// ================== PROTOCOL CONSTANTS ==================
class BleProtocol {
  // ================= BASIC =================
  static const int version = 0x01;

  static const int typeStatus = 0x01;
  static const int typeConfig = 0x04;

  // ================= STATUS =================
  static const int statusIdle = 0x00;
  static const int statusCharging = 0x01;
  static const int statusFault = 0x02;
  static const int statusFinished = 0x03;

  static String statusToText(int s) {
    switch (s) {
      case statusIdle:
        return 'Idle';
      case statusCharging:
        return 'Charging';
      case statusFault:
        return 'Fault';
      case statusFinished:
        return 'Finished';
      default:
        return 'Unknown';
    }
  }

  // ================= CHARGER TYPES =================
  static const Map<String, int> chargerTypeEnum = {
    'AC-7S': 1,
    'AC-10D': 2,
    'AC-11S': 3,
    'AC-14D': 4,
    'AC-22S': 5,
    'AC-22T': 6,
  };

  static const Map<String, int> maxPowerKw = {
    'AC-7S': 7,
    'AC-10D': 10,
    'AC-11S': 11,
    'AC-14D': 14,
    'AC-22S': 22,
    'AC-22T': 22,
  };

  static const Map<String, String> phaseSupport = {
    'AC-7S': 'Single',
    'AC-10D': 'Single',
    'AC-11S': 'Single',
    'AC-14D': 'Three',
    'AC-22S': 'Single',
    'AC-22T': 'Three',
  };

  static const Map<String, List<bool>> pwmCapabilities = {
    'AC-7S': [true, false, false],
    'AC-10D': [true, false, false],
    'AC-11S': [true, false, false],
    'AC-14D': [true, true, false],
    'AC-22S': [true, false, false],
    'AC-22T': [true, true, true],
  };

  // ================= CONFIG PACKET =================
  static List<int> buildConfigPacket({
    required String chargerType,
    required int connectorCount,
  }) {
    final pwm = pwmCapabilities[chargerType] ?? [false, false, false];

    return [
      version,
      typeConfig,
      chargerTypeEnum[chargerType] ?? 0,
      connectorCount,
      pwm[0] ? 1 : 0,
      pwm[1] ? 1 : 0,
      pwm[2] ? 1 : 0,
    ];
  }

  // ================= STATUS PACKET (SIM / LEGACY) =================
  static Map<String, dynamic> decodeStatusPacket(List<int> packet) {
    if (packet.length < 3) return {};
    return {'status': packet[2]};
  }
}
