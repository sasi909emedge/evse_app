import 'dart:async';
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

  final serialCtrl = TextEditingController();
  final chargerTypeCtrl = TextEditingController();
  final connectorCountCtrl = TextEditingController(text: '1');

  final powerCtrl = TextEditingController();
  final phaseCtrl = TextEditingController();
  final voltageCtrl = TextEditingController();
  final currentCtrl = TextEditingController();

  String chargingStatus = 'Idle';
  StreamSubscription<int>? _statusSub;
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

  // ================= STATUS =================
  void _subscribeStatus() {
    _statusSub = BleService.instance
        .subscribeStatus(widget.deviceId)
        .listen((status) {
      setState(() {
        chargingStatus = BleProtocol.statusToText(status);
      });
    });
  }

  // ================= AUTO MAP =================
  void _applyChargerProfile(String type) {
    final power = BleProtocol.maxPowerKw[type] ?? 0;
    final phase = BleProtocol.phaseSupport[type] ?? 'Single';

    powerCtrl.text = '$power kW';
    phaseCtrl.text = phase;
    voltageCtrl.text = phase == 'Three' ? '415V' : '230V';
    currentCtrl.text = phase == 'Three' ? '32A' : '16A';
  }

  // ================= SAVE =================
  Future<void> _save() async {
    await BleService.instance.writeStringCharacteristic(
      widget.deviceId,
      EVSEConfig.serialUuid,
      serialCtrl.text,
    );

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
    serialCtrl.text = p.getString('serial') ?? '';
    chargerTypeCtrl.text = p.getString('chargerType') ?? '';
    connectorCountCtrl.text = p.getString('connectorCount') ?? '1';

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

  // ================= UI =================
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

  Widget _card(String title, Widget child) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: ListTile(title: Text(title), subtitle: child),
  );

  Widget _field(String label, TextEditingController c) =>
      _card(label, editMode ? TextField(controller: c) : Text(c.text));

  Widget _dropdown(
      String label,
      TextEditingController c,
      List<String> options,
      void Function(String)? onChanged,
      ) =>
      _card(
        label,
        DropdownButtonFormField<String>(
          value: options.contains(c.text) ? c.text : null,
          items: options
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: editMode
              ? (v) {
            if (v == null) return;
            setState(() => c.text = v);
            onChanged?.call(v);
          }
              : null,
        ),
      );

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
              } else {
                setState(() => editMode = false);
                await _save();
              }
            },
          )
        ],
      ),
      body: ListView(
        children: [
          _card(
            'Status',
            Text(
              chargingStatus,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _statusColor(),
              ),
            ),
          ),
          _field('Serial', serialCtrl),
          _dropdown(
            'Charger Type',
            chargerTypeCtrl,
            BleProtocol.chargerTypeEnum.keys.toList(),
            _applyChargerProfile,
          ),
          _dropdown('Connector Count', connectorCountCtrl, ['1', '2'], null),
          _field('Power', powerCtrl),
          _field('Phase', phaseCtrl),
          _field('Voltage', voltageCtrl),
          _field('Current', currentCtrl),
        ],
      ),
    );
  }
}