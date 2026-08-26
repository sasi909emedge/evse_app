class CardEntry {
  final String cardType; // 'RFID Card', 'Display Card', 'Dispenser Card', 'Relay Card'
  final String qrId;
  final String serialId;
  final DateTime registeredAt;

  CardEntry({
    required this.cardType,
    required this.qrId,
    required this.serialId,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() => {
        "cardType": cardType,
        "qrId": qrId,
        "serialId": serialId,
        "registeredAt": registeredAt.toIso8601String(),
      };

  factory CardEntry.fromJson(Map<String, dynamic> j) => CardEntry(
        cardType: j["cardType"] ?? "",
        qrId: j["qrId"] ?? "",
        serialId: j["serialId"] ?? "",
        registeredAt:
            DateTime.tryParse(j["registeredAt"] ?? "") ?? DateTime.now(),
      );
}