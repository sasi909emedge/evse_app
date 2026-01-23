import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../ble/ble_protocol.dart';
import '../ble/ble_service.dart';
import '../config/evse_config.dart';

/// ================== SIMULATOR SWITCH ==================
const bool useSimulator = false;

class EvseDetailsScreen extends StatefulWidget {
  final String deviceId;
  const EvseDetailsScreen({super.key, required this.deviceId});

  @override
  State<EvseDetailsScreen> createState() => _EvseDetailsScreenState();
}

class _EvseDetailsScreenState extends State<EvseDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool editMode = false;

  // 🔒 protects serial after Save
  String? _pendingSerialSave;

  // ---------------- OPTION A – IDENTIFICATION ----------------
  final serialCtrl = TextEditingController();
  final vendorCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final commissionedByCtrl = TextEditingController();
  final commissionedDateCtrl = TextEditingController();
  final locationCtrl = TextEditingController();

  // ---------------- OPTION 1 – CHARGER TYPE ----------------
  final chargerTypeCtrl = TextEditingController();
  final chargerModeCtrl = TextEditingController(text: 'AC');
  final connectorCountCtrl = TextEditingController(text: '1');

  // ---------------- OPTION B – ELECTRICAL ----------------
  final voltageCtrl = TextEditingController();
  final currentCtrl = TextEditingController();
  final powerCtrl = TextEditingController();
  final phaseCtrl = TextEditingController();
  final supplyCtrl = TextEditingController(text: 'AC');
  final freqCtrl = TextEditingController(text: '50');

  // ---------------- OPTION C – CONNECTOR ----------------
  final connectorTypeCtrl = TextEditingController();
  final maxPowerCtrl = TextEditingController();
  final maxCurrentCtrl = TextEditingController();

  // ---------------- PWM ----------------
  final pwm1Ctrl = TextEditingController(text: 'Enable');
  final pwm2Ctrl = TextEditingController(text: 'Disable');
  final pwm3Ctrl = TextEditingController(text: 'Disable');

  // ---------------- STATUS / RX ----------------
  String chargingStatus = 'Idle';
  late AnimationController _blinkCtrl;
  Timer? _simTimer;

  @override
  void initState() {
    super.initState();

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    // ================= STEP 4.5 =================
    // BLE IS SOURCE OF TRUTH — SUBSCRIBE FIRST

    // ---------- STATUS NOTIFY ----------
    BleService.instance
        .subscribeRawCharacteristic(
      widget.deviceId,
      EVSEConfig.chargingStatusUuid,
    )
        .listen((bytes) {
      if (editMode) return;
      setState(() {
        chargingStatus = BleProtocol.statusToText(bytes as int);
      });
    });

    // ---------- SERIAL NOTIFY (SAFE) ----------
    BleService.instance
        .subscribeRawCharacteristic(
      widget.deviceId,
      EVSEConfig.serialUuid,
    )
        .listen((bytes) {
      if (editMode) return;

      final value = utf8.decode(bytes);

      // 🔒 prevent overwrite right after Save
      if (_pendingSerialSave != null && value != _pendingSerialSave) {
        return;
      }

      setState(() {
        serialCtrl.text = value;
        _pendingSerialSave = null;
      });
    });

    // ---------- LOAD LOCAL ONLY AS FALLBACK ----------
    _loadLocal();

    if (useSimulator) _startSimulator();
  }

  @override
  void dispose() {
    _blinkCtrl.dispose();
    _simTimer?.cancel();
    super.dispose();
  }

  // ================= SIMULATOR RX =================
  void _startSimulator() {
    const states = ['Idle', 'Charging', 'Fault', 'Finished'];
    int idx = 0;
    _simTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (editMode) return;
      setState(() {
        chargingStatus = states[idx % states.length];
        idx++;
      });
    });
  }

  // ================= AUTO-MAPPING LOGIC =================
  void _applyChargerProfile(String type) {
    final power = BleProtocol.maxPowerKw[type] ?? 0;
    final phase = BleProtocol.phaseSupport[type] ?? 'Single';

    chargerTypeCtrl.text = type;
    powerCtrl.text = '$power kW';
    maxPowerCtrl.text = '$power kW';
    phaseCtrl.text = phase;

    voltageCtrl.text = phase == 'Three' ? '415V' : '230V';
    currentCtrl.text = phase == 'Three' ? '32A' : '16A';

    final pwm = BleProtocol.pwmCapabilities[type] ?? [false, false, false];
    pwm1Ctrl.text = pwm[0] ? 'Enable' : 'Disable';
    pwm2Ctrl.text = pwm[1] ? 'Enable' : 'Disable';
    pwm3Ctrl.text = pwm[2] ? 'Enable' : 'Disable';
  }

  // ================= VALIDATION =================
  bool _validateAll() {
    if (chargerTypeCtrl.text.isEmpty) return true;

    if (supplyCtrl.text == 'AC' &&
        connectorTypeCtrl.text.isNotEmpty &&
        connectorTypeCtrl.text != 'Type2') {
      _err('AC chargers support only Type2');
      return false;
    }

    final pwm = BleProtocol.pwmCapabilities[chargerTypeCtrl.text] ?? [];
    if (supplyCtrl.text != 'AC' && pwm.contains(true)) {
      _err('PWM outputs allowed only for AC chargers');
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

  // ================= CONFIG TX =================
  void _sendConfig() {
    final packet = BleProtocol.buildConfigPacket(
      chargerType: chargerTypeCtrl.text,
      connectorCount: int.parse(connectorCountCtrl.text),
    );

    debugPrint('CONFIG PACKET: $packet');
    debugPrint(
      packet.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' '),
    );
  }

  // ================= STORAGE =================
  Future<void> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    serialCtrl.text = p.getString('serial') ?? '';
    vendorCtrl.text = p.getString('vendor') ?? '';
    nameCtrl.text = p.getString('name') ?? '';
    modelCtrl.text = p.getString('model') ?? '';
    commissionedByCtrl.text = p.getString('cby') ?? '';
    commissionedDateCtrl.text = p.getString('cdate') ?? '';
    locationCtrl.text = p.getString('location') ?? '';
  }

  Future<void> _saveLocal() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('serial', serialCtrl.text);
    await p.setString('vendor', vendorCtrl.text);
    await p.setString('name', nameCtrl.text);
    await p.setString('model', modelCtrl.text);
    await p.setString('cby', commissionedByCtrl.text);
    await p.setString('cdate', commissionedDateCtrl.text);
    await p.setString('location', locationCtrl.text);
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
          onChanged: (value) {
            if (value == null) return;
            setState(() => c.text = value);
            if (onChanged != null) onChanged(value);
          },
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

              if (!_validateAll()) return;

              _pendingSerialSave = serialCtrl.text;
              setState(() => editMode = false);

              await BleService.instance.writeStringCharacteristic(
                widget.deviceId,
                EVSEConfig.serialUuid,
                serialCtrl.text,
              );

              if (chargerTypeCtrl.text.isNotEmpty) {
                await BleService.instance.writeStringCharacteristic(
                  widget.deviceId,
                  EVSEConfig.chargerTypeUuid,
                  chargerTypeCtrl.text,
                );
              }

              if (connectorCountCtrl.text.isNotEmpty) {
                await BleService.instance.writeStringCharacteristic(
                  widget.deviceId,
                  EVSEConfig.connectorCountUuid,
                  connectorCountCtrl.text,
                );
              }

              await _saveLocal();

              if (chargerTypeCtrl.text.isNotEmpty) {
                _sendConfig();
              }
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          _section('Charging Status'),
          _card('Status', _statusWidget()),
          _section('Option A – Identification'),
          _field('Serial', serialCtrl),
          _field('Vendor', vendorCtrl),
          _field('Name', nameCtrl),
          _field('Model', modelCtrl),
          _field('Commissioned By', commissionedByCtrl),
          _field('Commissioned Date', commissionedDateCtrl),
          _field('Location', locationCtrl),
          _section('Option 1 – Charger Type'),
          _dropdown(
            'Charger Type',
            chargerTypeCtrl,
            BleProtocol.chargerTypeEnum.keys.toList(),
            onChanged: _applyChargerProfile,
          ),
          _section('Option B – Electrical'),
          _field('Voltage', voltageCtrl),
          _field('Current', currentCtrl),
          _field('Power', powerCtrl),
          _dropdown('Phase', phaseCtrl, ['Single', 'Three']),
          _dropdown('Supply', supplyCtrl, ['AC']),
          _dropdown('Frequency', freqCtrl, ['50', '60']),
          _section('Option C – Connector'),
          _dropdown('Connector Type', connectorTypeCtrl, ['Type2']),
          _dropdown('Connector Count', connectorCountCtrl, ['1', '2']),
          _field('Max Power', maxPowerCtrl),
          _field('Max Current', maxCurrentCtrl),
          _section('PWM Outputs'),
          _dropdown('PWM-1', pwm1Ctrl, ['Enable', 'Disable']),
          _dropdown('PWM-2', pwm2Ctrl, ['Enable', 'Disable']),
          _dropdown('PWM-3', pwm3Ctrl, ['Enable', 'Disable']),
        ],
      ),
    );
  }
}