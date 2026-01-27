class BleProtocol {
  // ================= ENUMS =================
  static const Map<String, int> chargerTypeEnum = {
    'AC-7S': 0,
    'AC-14T': 1,
    'AC-22T': 2,
  };

  // ================= DERIVED DATA =================
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

  // ================= STATUS =================
  static String statusToText(int status) {
    switch (status) {
      case 0x00:
        return 'Idle';
      case 0x01:
        return 'Charging';
      case 0x02:
        return 'Fault';
      default:
        return 'Unknown';
    }
  }

  // ================= CONFIG PACKET =================
  static List<int> buildConfigPacket({
    required String chargerType,
    required int connectorCount,
  }) {
    final type = chargerTypeEnum[chargerType] ?? 0;

    // Packet format MUST match ESP expectation
    return [
      0xA5, // header
      0x01, // version
      type,
      connectorCount,
      0x00,
      0x00,
      0x00,
    ];
  }
}

