import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/card_entry.dart';
import '../ble/ble_service_selector.dart';
import '../ble/ble_protocol.dart';
import '../theme/app_colors.dart';

// ================================================================
// CARD MANAGEMENT SCREEN — proof-of-concept
//
// ⚠️ This entire feature is a PLACEHOLDER / PROOF-OF-CONCEPT:
//   - IDs are app-generated fake values, not real printed card IDs.
//   - Selection.requestCardList / Selection.updateCardList are
//     placeholder BLE codes (see ble_protocol.dart) pending real
//     codes from the company.
//   - No cloud sync — local device storage only (SharedPreferences).
// Swap points for the real implementation are marked with "REAL:".
// ================================================================

const List<String> kCardTypes = [
  'RFID Card',
  'Display Card',
  'Dispenser Card',
  'Relay Card',
];

class CardManagementScreen extends StatefulWidget {
  final String deviceId;
  const CardManagementScreen({super.key, required this.deviceId});

  @override
  State<CardManagementScreen> createState() => _CardManagementScreenState();
}

class _CardManagementScreenState extends State<CardManagementScreen> {
  final List<CardEntry> _cards = [];
  bool _sending = false;

  String get _storageKey =>
      'card_list_${widget.deviceId.replaceAll(':', '')}';

  @override
  void initState() {
    super.initState();
    _loadLocally();
  }

  // ── Local storage ────────────────────────────────────────────
  Future<void> _loadLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((e) => CardEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _cards
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e) {
      debugPrint("❌ Card list load: $e");
    }
  }

  Future<void> _saveLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _storageKey, jsonEncode(_cards.map((c) => c.toJson()).toList()));
    } catch (e) {
      debugPrint("❌ Card list save: $e");
    }
  }

  // ── REAL: fake ID generation — replace with real printed-card
  // scanning once physical cards exist. For now this simulates
  // "manufacturing" a new card by generating a random QR + serial ID.
  String _generateFakeId(String cardType, String prefix) {
    final rand = Random();
    final suffix =
        List.generate(6, (_) => rand.nextInt(10)).join(); // 6-digit
    final typeCode = cardType.substring(0, 1).toUpperCase();
    return "EMEDGE-$prefix$typeCode-$suffix";
  }

  void _addGeneratedCard(String cardType) {
    final qrId = _generateFakeId(cardType, "QR-");
    final serialId = _generateFakeId(cardType, "SN-");
    setState(() {
      _cards.add(CardEntry(
        cardType: cardType,
        qrId: qrId,
        serialId: serialId,
        registeredAt: DateTime.now(),
      ));
    });
    _saveLocally();
  }

  void _removeCard(CardEntry entry) {
    setState(() => _cards.remove(entry));
    _saveLocally();
  }

  // ── Camera scan — proves the scan pipeline works end-to-end.
  // REAL: once physical cards exist, scanning replaces generation
  // as the way new entries get added (scan printed QR -> capture ID).
  Future<void> _scanQrCode(String cardType) async {
    final scanned = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanScreen()),
    );
    if (scanned == null || scanned.isEmpty) return;

    final serialId = _generateFakeId(cardType, "SN-");
    setState(() {
      _cards.add(CardEntry(
        cardType: cardType,
        qrId: scanned,
        serialId: serialId,
        registeredAt: DateTime.now(),
      ));
    });
    _saveLocally();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Scanned and added: $scanned"),
        backgroundColor: AppColors.success,
      ));
    }
  }

  void _showQr(CardEntry entry) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(entry.cardType),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: entry.qrId,
              size: 220,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            Text("QR ID: ${entry.qrId}",
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text("Serial ID: ${entry.serialId}",
                style: const TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close")),
        ],
      ),
    );
  }

  // ── Send list to Master Controller over BLE ────────────────────
  Future<void> _sendListToCharger() async {
    if (_cards.isEmpty) {
      _snack("No cards to send", ok: false);
      return;
    }
    setState(() => _sending = true);
    try {
      final payload = {
        "cards": _cards.map((c) => c.toJson()).toList(),
      };
      // ⚠️ PLACEHOLDER selection codes — see ble_protocol.dart
      await BleService.instance.writeTabJson(
        widget.deviceId,
        payload,
        Selection.updateCardList,
      );
      await Future.delayed(const Duration(milliseconds: 500));

      final readback = await BleService.instance
          .readJsonForSelection(widget.deviceId, Selection.requestCardList);

      if (readback.isNotEmpty) {
        _snack("Card list sent — charger acknowledged", ok: true);
      } else {
        _snack(
            "Sent, but charger did not confirm (expected — no real handler yet)",
            ok: false);
      }
    } catch (e) {
      debugPrint("❌ Send card list: $e");
      _snack("Failed to send card list", ok: false);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Card Management"),
        actions: [
          IconButton(
            icon: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_outlined),
            tooltip: "Send list to charger",
            onPressed: _sending ? null : _sendListToCharger,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning),
            ),
            child: const Text(
              "⚠️ Proof-of-concept: IDs shown here are app-generated "
              "placeholders, not real printed card IDs.",
              style: TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          for (final type in kCardTypes) _cardTypeSection(type),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _cardTypeSection(String cardType) {
    final entries = _cards.where((c) => c.cardType == cardType).toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(cardType,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: const Text("Scan"),
                  onPressed: () => _scanQrCode(cardType),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text("Generate"),
                  onPressed: () => _addGeneratedCard(cardType),
                ),
              ],
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text("No cards registered",
                    style: TextStyle(color: Colors.grey.shade600)),
              ),
            for (final entry in entries)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(entry.qrId,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("SN: ${entry.serialId}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code, size: 20),
                      onPressed: () => _showQr(entry),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: AppColors.error),
                      onPressed: () => _removeCard(entry),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Camera scan sub-screen ──────────────────────────────────────
class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Card QR Code")),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}