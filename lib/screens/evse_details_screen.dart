import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../ble/ble_protocol.dart';
import '../ble/ble_service.dart';
import '../config/evse_config.dart';

class EvseDetailsScreen extends StatefulWidget {
  final String deviceId;
  const EvseDetailsScreen({super.key, required this.deviceId});

  @override
  State<EvseDetailsScreen> createState() => _EvseDetailsScreenState();
}

class _EvseDetailsScreenState extends State<EvseDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool editMode = false;

  // ---------------- IDENTIFICATION ----------------
  final serialCtrl = TextEditingController();

  // ---------------- CONFIG (INPUT) ----------------
  final chargerTypeCtrl = TextEditingController();
  final connectorCountCtrl = TextEditingController(text: '1');

  // ---------------- DISPLAY / DERIVED ----------------
  final powerCtrl = TextEditingController();
  final phaseCtrl = TextEditingController();
  final voltageCtrl = TextEditingController();
  final currentCtrl = TextEditingController();

  // ---------------- STATUS ----------------
  String chargingStatus = 'Unknown';
  StreamSubscription<List<int>>? _statusSub;
  late AnimationController _blinkCtrl;

  @override
  void initState() {
    super.initState();

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _loadLocal();
    _subscribeStatus();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _blinkCtrl.dispose();
    super.dispose();
  }

  // ================= STATUS SUBSCRIBE =================
  void _subscribeStatus() {
    _statusSub = BleService.instance
        .subscribeStatus(widget.deviceId)
        .listen((bytes) {
      final decoded = BleProtocol.decodeStatusPacket(bytes);
      if (decoded.isEmpty) return;

      setState(() {
        chargingStatus = decoded['statusText'] as String;
      });
    });
  }

  // ================= AUTO-MAPPING =================
  void _applyChargerProfile(String type) {
    final pwm = BleProtocol.pwmCapabilities[type] ?? [false, false, false];

    // Derived display (UI-only)
    if (type.contains('22')) {
      powerCtrl.text = '22 kW';
      phaseCtrl.text = 'Three';
      voltageCtrl.text = '415V';
      currentCtrl.text = '32A';
    } else if (type.contains('14')) {
      powerCtrl.text = '14 kW';
      phaseCtrl.text = 'Three';
      voltageCtrl.text = '415V';
      currentCtrl.text = '20A';
    } else {
      powerCtrl.text = '7–11 kW';
      phaseCtrl.text = 'Single';
      voltageCtrl.text = '230V';
      currentCtrl.text = '16A';
    }

    // PWM shown implicitly by charger type (no direct editing)
    debugPrint('PWM capability: $pwm');
  }

  // ================= VALIDATION =================
  bool _validateAll() {
    if (chargerTypeCtrl.text.isEmpty) {
      _err('Charger Type is required');
      return false;
    }
    if (connectorCountCtrl.text.isEmpty) {
      _err('Connector Count is required');
      return false;
    }
    return true;
  }

  void _err(String m) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invalid Configuration'),
        content: Text(m),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  // ================= SAVE =================
  Future<void> _save() async {
    if (!_validateAll()) return;

    // Identification (string write)
    await BleService.instance.writeStringCharacteristic(
      widget.deviceId,
      EVSEConfig.serialUuid,
      serialCtrl.text,
    );

    // CONFIG (single binary packet)
    final packet = BleProtocol.buildConfigPacket(
      chargerType: chargerTypeCtrl.text,
      connectorCount: int.parse(connectorCountCtrl.text),
    );

    await BleService.instance.writeConfigPacket(
      widget.deviceId,
      packet,
    );

    await _saveLocal();
  }

  // ================= STORAGE =================
  Future<void> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      serialCtrl.text = p.getString('serial') ?? '';
      chargerTypeCtrl.text = p.getString('chargerType') ?? '';
      connectorCountCtrl.text = p.getString('connectorCount') ?? '1';
    });

    if (chargerTypeCtrl.text.isNotEmpty) {
      _applyChargerProfile(chargerTypeCtrl.text);
    }
  }

  Future<void> _saveLocal() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('serial', serialCtrl.text);
    await p.setString('chargerType', chargerTypeCtrl.text);
    await p.setString('connectorCount', connectorCountCtrl.text);
  }

  // ================= UI HELPERS =================
  Color _statusColor() {
    switch (chargingStatus) {
      case 'Charging':
        return Colors.green;
      case 'Idle':
        return Colors.orange;
      case 'Fault':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _statusWidget() => AnimatedBuilder(
    animation: _blinkCtrl,
    builder: (_, __) => Text(
      chargingStatus,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: _statusColor().withOpacity(0.6 + 0.4 * _blinkCtrl.value),
      ),
    ),
  );

  Widget _card(String title, Widget child) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: ListTile(title: Text(title), subtitle: child),
  );

  Widget _field(String label, TextEditingController c) =>
      _card(label, editMode ? TextField(controller: c) : Text(c.text));

  Widget _dropdown(
      String label,
      TextEditingController c,
      List<String> options, {
        void Function(String)? onChanged,
      }) =>
      _card(
        label,
        DropdownButtonFormField<String>(
          value: options.contains(c.text) ? c.text : null,
          items: options
              .map((item) =>
              DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: editMode
              ? (value) {
            if (value == null) return;
            setState(() => c.text = value);
            if (onChanged != null) onChanged(value);
          }
              : null,
        ),
      );

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(
      t,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    ),
  );

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('EVSE Configuration'),
        actions: [
          IconButton(
            icon: Icon(editMode ? Icons.save : Icons.edit),
            onPressed: () async {
              if (!editMode) {
                setState(() => editMode = true);
                return;
              }
              setState(() => editMode = false);
              await _save();
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _section('Charging Status'),
          _card('Status', _statusWidget()),

          _section('Identification'),
          _field('Serial', serialCtrl),

          _section('Configuration'),
          _dropdown(
            'Charger Type',
            chargerTypeCtrl,
            BleProtocol.chargerTypeEnum.keys.toList(),
            onChanged: _applyChargerProfile,
          ),
          _dropdown('Connector Count', connectorCountCtrl, ['1', '2']),

          _section('Electrical (Derived)'),
          _field('Power', powerCtrl),
          _field('Phase', phaseCtrl),
          _field('Voltage', voltageCtrl),
          _field('Current', currentCtrl),
        ],
      ),
    );
  }
}
