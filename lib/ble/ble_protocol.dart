/// =====================================================
/// BLE PROTOCOL — EXCEL MIRROR
/// -----------------------------------------------------
/// - NO BLE calls
/// - NO UI logic
/// - Defines packet structure only
/// - Must match ESP firmware exactly
/// =====================================================

class BleProtocol {
  // ================= VERSIONING =================
  static const int protocolVersion = 0x01;

  // ================= PACKET TYPES =================
  static const int pktTypeConfig = 0x01;
  static const int pktTypeStatus = 0x02;

  // ================= STATUS ENUM =================
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

  // ================= CHARGER TYPE ENUM =================
  /// Excel-defined charger types → numeric IDs
  static const Map<String, int> chargerTypeEnum = {
    'AC-7S': 1,
    'AC-10D': 2,
    'AC-11S': 3,
    'AC-14D': 4,
    'AC-22S': 5,
    'AC-22T': 6,
  };

  /// Reverse lookup (ESP → UI)
  static const Map<int, String> chargerTypeFromEnum = {
    1: 'AC-7S',
    2: 'AC-10D',
    3: 'AC-11S',
    4: 'AC-14D',
    5: 'AC-22S',
    6: 'AC-22T',
  };

  // ================= PWM CAPABILITIES =================
  /// Excel-defined PWM support per charger type
  static const Map<String, List<bool>> pwmCapabilities = {
    'AC-7S': [true, false, false],
    'AC-10D': [true, false, false],
    'AC-11S': [true, false, false],
    'AC-14D': [true, true, false],
    'AC-22S': [true, false, false],
    'AC-22T': [true, true, true],
  };

  // ================= CONFIG PACKET =================
  /// CONFIG PACKET FORMAT (FIXED)
  /// -------------------------------------------------
  /// Byte 0 : Protocol Version
  /// Byte 1 : Packet Type (CONFIG)
  /// Byte 2 : Charger Type (enum)
  /// Byte 3 : Connector Count
  /// Byte 4 : PWM1 Enable (0/1)
  /// Byte 5 : PWM2 Enable (0/1)
  /// Byte 6 : PWM3 Enable (0/1)
  /// Byte 7 : Checksum (sum of bytes 0..6 & 0xFF)
  /// -------------------------------------------------
  static List<int> buildConfigPacket({
    required String chargerType,
    required int connectorCount,
  }) {
    final typeId = chargerTypeEnum[chargerType] ?? 0;
    final pwm = pwmCapabilities[chargerType] ?? [false, false, false];

    final packet = <int>[
      protocolVersion,
      pktTypeConfig,
      typeId,
      connectorCount & 0xFF,
      pwm[0] ? 1 : 0,
      pwm[1] ? 1 : 0,
      pwm[2] ? 1 : 0,
    ];

    packet.add(_checksum(packet));
    return packet;
  }

  // ================= STATUS PACKET =================
  /// STATUS PACKET FORMAT (FIXED)
  /// -------------------------------------------------
  /// Byte 0 : Protocol Version
  /// Byte 1 : Packet Type (STATUS)
  /// Byte 2 : Status Code
  /// Byte 3 : Checksum (sum of bytes 0..2 & 0xFF)
  /// -------------------------------------------------
  static Map<String, dynamic> decodeStatusPacket(List<int> packet) {
    if (packet.length < 4) return {};

    final version = packet[0];
    final type = packet[1];
    final status = packet[2];
    final crc = packet[3];

    final calc = _checksum(packet.sublist(0, 3));
    if (version != protocolVersion || type != pktTypeStatus || crc != calc) {
      return {};
    }

    return {
      'status': status,
      'statusText': statusToText(status),
    };
  }

  // ================= CHECKSUM =================
  static int _checksum(List<int> data) {
    int sum = 0;
    for (final b in data) {
      sum = (sum + (b & 0xFF)) & 0xFF;
    }
    return sum;
  }
}
