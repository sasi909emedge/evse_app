import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import '../ble/ble_protocol.dart';
import '../ble/ble_service.dart';
import '../config/evse_config.dart';
import '../widgets/connector_settings.dart';
import '../widgets/connectivity_settings.dart';

class EvseDetailsScreen extends StatefulWidget {
  final String deviceId;
  const EvseDetailsScreen({super.key, required this.deviceId});

  @override
  State<EvseDetailsScreen> createState() => _EvseDetailsScreenState();
}

class _EvseDetailsScreenState extends State<EvseDetailsScreen>
    with SingleTickerProviderStateMixin {
  bool editMode = false;

  // Basic fields
  final serialCtrl = TextEditingController();
  final chargerNameCtrl = TextEditingController();
  final chargerTypeCtrl = TextEditingController();
  final connectorCountCtrl = TextEditingController(text: '1');

  // Derived display fields
  final powerCtrl = TextEditingController();
  final phaseCtrl = TextEditingController();
  final voltageCtrl = TextEditingController();
  final currentCtrl = TextEditingController();

  // Numeric fields for packet
  int overVoltage = 260;
  int underVoltage = 200;
  int overTemperature = 65;
  bool restoreSession = true;
  int restoreTimeout = 60;
  bool gfci = true;
  double ocC1 = 12.3;
  double ocC2 = 13.2;
  double ocC3 = 15.9;
  int lowCurrentTime = 20;
  double minLowCurrent = 0.25;
  int suspendedBehaviour = 0; // 0=StopCharging
  int suspendedTime = 100;
  bool phaseMgmt = false;
  bool loadMgmt = false;

  // Connectivity
  bool wifiEnable = false;
  bool gsmEnable = false;
  bool ethEnable = false;
  int wifiPriority = 1;
  int gsmPriority = 2;
  int ethPriority = 3;

  String chargingStatus = 'Idle';
  StreamSubscription<int>? _statusSub;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadLocal();
    _subscribeStatus();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    super.dispose();
  }

  void _subscribeStatus() {
    _statusSub = BleService.instance
        .subscribeStatus(widget.deviceId)
        .listen((status) {
      setState(() {
        chargingStatus = BleProtocol.statusToText(status);
      });
    });
  }

  void _applyChargerProfile(String type) {
    final power = BleProtocol.maxPowerKw[type] ?? 0;
    final phase = BleProtocol.phaseSupport[type] ?? 'Single';

    powerCtrl.text = '$power kW';
    phaseCtrl.text = phase;
    voltageCtrl.text = phase == 'Three' ? '415V' : '230V';
    currentCtrl.text = phase == 'Three' ? '32A' : '16A';
  }

  Future<void> _save() async {

    if (!BleService.instance.isGattReady(widget.deviceId)) {
      _showError('BLE not ready. Please reconnect to the charger.');
      return;
    }

    final errors = _validateAll();
    if (errors.isNotEmpty) {
      _showError(errors.join('\n'));
      return;
    }

    setState(() => _saving = true);

    try {
      // Write serial and charger name as UTF-8 string (concatenate with separator)
      final serialPayload = serialCtrl.text;
      await BleService.instance.writeStringCharacteristic(
        widget.deviceId,
        EVSEConfig.serialUuid,
        serialPayload,
      );

      // Build 32-byte packet
      final packet = BleProtocol.buildConfigPacket(
        chargerType: chargerTypeCtrl.text,
        connectorCount: int.parse(connectorCountCtrl.text),
        overVoltage: overVoltage,
        underVoltage: underVoltage,
        overTemperature: overTemperature,
        restoreSession: restoreSession,
        restoreTimeout: restoreTimeout,
        gfci: gfci,
        ocLimitC1: ocC1,
        ocLimitC2: ocC2,
        ocLimitC3: ocC3,
        lowCurrentTime: lowCurrentTime,
        minLowCurrent: minLowCurrent,
        suspendedBehaviour: suspendedBehaviour,
        suspendedTime: suspendedTime,
        phaseMgmt: phaseMgmt,
        loadMgmt: loadMgmt,
        wifiEnable: wifiEnable,
        gsmEnable: gsmEnable,
        ethEnable: ethEnable,
        wifiPriority: wifiPriority,
        gsmPriority: gsmPriority,
        ethPriority: ethPriority,
      );

      await BleService.instance.writeConfigPacket(widget.deviceId, packet);

      // Persist locally
      await _saveLocal();

      _showMessage('Configuration saved successfully');
    } catch (e) {
      _showError('Failed to save configuration: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _validateAll() {
    final List<String> errors = [];

    if (serialCtrl.text.trim().isEmpty) {
      errors.add('Serial is required.');
    }

    if (chargerTypeCtrl.text.isEmpty) {
      errors.add('Charger Type is required.');
    }

    if (overVoltage < 170 || overVoltage > 275) {
      errors.add('Over Voltage must be between 170 and 275 V.');
    }
    if (underVoltage < 170 || underVoltage > 275) {
      errors.add('Under Voltage must be between 170 and 275 V.');
    }
    if (underVoltage >= overVoltage) {
      errors.add('Under Voltage must be less than Over Voltage.');
    }
    if (overTemperature > 80) {
      errors.add('Over Temperature must be ≤ 80 °C.');
    }
    if (ocC1 > 16.0 && _isSocketConnector(1)) {
      errors.add('Connector 1 current cannot exceed 16.00 A for socket type.');
    }
    if (ocC2 > 16.0 && _isSocketConnector(2)) {
      errors.add('Connector 2 current cannot exceed 16.00 A for socket type.');
    }
    if (ocC3 > 16.0 && _isSocketConnector(3)) {
      errors.add('Connector 3 current cannot exceed 16.00 A for socket type.');
    }
    if (suspendedTime < 1 || suspendedTime > 1200) {
      errors.add('Suspended Time must be between 1 and 1200 seconds.');
    }
    if (lowCurrentTime <= 0) {
      errors.add('Low current time must be greater than 0.');
    }
    if (minLowCurrent <= 0) {
      errors.add('Minimum low current must be greater than 0 A.');
    }

    return errors;
  }

  bool _isSocketConnector(int index) {
    // Basic heuristic: if connector type is "16A/Domestic Socket" treat as socket
    // For now we assume connector 1 is socket if connectorCount==1 and chargerType is AC-7S
    if (index == 1 && chargerTypeCtrl.text == 'AC-7S') return true;
    return false;
  }

  Future<void> _loadLocal() async {
    final p = await SharedPreferences.getInstance();
    serialCtrl.text = p.getString('serial') ?? '';
    chargerNameCtrl.text = p.getString('chargerName') ?? '';
    chargerTypeCtrl.text = p.getString('chargerType') ?? '';
    connectorCountCtrl.text = p.getString('connectorCount') ?? '1';

    // Load numeric fields if present
    overVoltage = p.getInt('overVoltage') ?? overVoltage;
    underVoltage = p.getInt('underVoltage') ?? underVoltage;
    overTemperature = p.getInt('overTemperature') ?? overTemperature;
    restoreSession = p.getBool('restoreSession') ?? restoreSession;
    restoreTimeout = p.getInt('restoreTimeout') ?? restoreTimeout;
    gfci = p.getBool('gfci') ?? gfci;
    ocC1 = p.getDouble('ocC1') ?? ocC1;
    ocC2 = p.getDouble('ocC2') ?? ocC2;
    ocC3 = p.getDouble('ocC3') ?? ocC3;
    lowCurrentTime = p.getInt('lowCurrentTime') ?? lowCurrentTime;
    minLowCurrent = p.getDouble('minLowCurrent') ?? minLowCurrent;
    suspendedBehaviour = p.getInt('suspendedBehaviour') ?? suspendedBehaviour;
    suspendedTime = p.getInt('suspendedTime') ?? suspendedTime;
    phaseMgmt = p.getBool('phaseMgmt') ?? phaseMgmt;
    loadMgmt = p.getBool('loadMgmt') ?? loadMgmt;

    wifiEnable = p.getBool('wifiEnable') ?? wifiEnable;
    gsmEnable = p.getBool('gsmEnable') ?? gsmEnable;
    ethEnable = p.getBool('ethEnable') ?? ethEnable;
    wifiPriority = p.getInt('wifiPriority') ?? wifiPriority;
    gsmPriority = p.getInt('gsmPriority') ?? gsmPriority;
    ethPriority = p.getInt('ethPriority') ?? ethPriority;

    if (chargerTypeCtrl.text.isNotEmpty) {
      _applyChargerProfile(chargerTypeCtrl.text);
    }
    setState(() {});
  }

  Future<void> _saveLocal() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('serial', serialCtrl.text);
    await p.setString('chargerName', chargerNameCtrl.text);
    await p.setString('chargerType', chargerTypeCtrl.text);
    await p.setString('connectorCount', connectorCountCtrl.text);

    await p.setInt('overVoltage', overVoltage);
    await p.setInt('underVoltage', underVoltage);
    await p.setInt('overTemperature', overTemperature);
    await p.setBool('restoreSession', restoreSession);
    await p.setInt('restoreTimeout', restoreTimeout);
    await p.setBool('gfci', gfci);
    await p.setDouble('ocC1', ocC1);
    await p.setDouble('ocC2', ocC2);
    await p.setDouble('ocC3', ocC3);
    await p.setInt('lowCurrentTime', lowCurrentTime);
    await p.setDouble('minLowCurrent', minLowCurrent);
    await p.setInt('suspendedBehaviour', suspendedBehaviour);
    await p.setInt('suspendedTime', suspendedTime);
    await p.setBool('phaseMgmt', phaseMgmt);
    await p.setBool('loadMgmt', loadMgmt);

    await p.setBool('wifiEnable', wifiEnable);
    await p.setBool('gsmEnable', gsmEnable);
    await p.setBool('ethEnable', ethEnable);
    await p.setInt('wifiPriority', wifiPriority);
    await p.setInt('gsmPriority', gsmPriority);
    await p.setInt('ethPriority', ethPriority);
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Validation Error'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  Widget _field(String label, Widget child) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: ListTile(title: Text(label), subtitle: child),
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
      body: Stack(
        children: [
          ListView(
            children: [
              _field(
                'Status',
                Text(
                  chargingStatus,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: chargingStatus == 'Charging'
                        ? Colors.green
                        : chargingStatus == 'Fault'
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
              ),
              _field(
                'Serial',
                editMode
                    ? TextField(controller: serialCtrl)
                    : Text(serialCtrl.text.isEmpty ? '-' : serialCtrl.text),
              ),
              _field(
                'Charger Name',
                editMode
                    ? TextField(controller: chargerNameCtrl)
                    : Text(chargerNameCtrl.text.isEmpty ? '-' : chargerNameCtrl.text),
              ),
              _field(
                'Charger Type',
                editMode
                    ? DropdownButtonFormField<String>(
                  value: BleProtocol.chargerTypeEnum.keys.contains(chargerTypeCtrl.text)
                      ? chargerTypeCtrl.text
                      : null,
                  items: BleProtocol.chargerTypeEnum.keys
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      chargerTypeCtrl.text = v;
                      _applyChargerProfile(v);
                    });
                  },
                )
                    : Text(chargerTypeCtrl.text.isEmpty ? '-' : chargerTypeCtrl.text),
              ),
              _field(
                'Connector Count',
                editMode
                    ? DropdownButtonFormField<String>(
                  value: ['1', '2', '3'].contains(connectorCountCtrl.text)
                      ? connectorCountCtrl.text
                      : '1',
                  items: ['1', '2', '3']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => connectorCountCtrl.text = v);
                  },
                )
                    : Text(connectorCountCtrl.text),
              ),
              // Derived fields
              _field('Power', Text(powerCtrl.text.isEmpty ? '-' : powerCtrl.text)),
              _field('Phase', Text(phaseCtrl.text.isEmpty ? '-' : phaseCtrl.text)),
              _field('Voltage', Text(voltageCtrl.text.isEmpty ? '-' : voltageCtrl.text)),
              _field('Current', Text(currentCtrl.text.isEmpty ? '-' : currentCtrl.text)),
              // Connector settings widget (reusable)
              ConnectorSettings(
                editMode: editMode,
                connectorCount: int.parse(connectorCountCtrl.text),
                onValuesChanged: (c1, c2, c3) {
                  setState(() {
                    ocC1 = c1;
                    ocC2 = c2;
                    ocC3 = c3;
                  });
                },
                initialC1: ocC1,
                initialC2: ocC2,
                initialC3: ocC3,
              ),
              // General thresholds
              _field(
                'Over Voltage Threshold (V)',
                editMode
                    ? TextFormField(
                  initialValue: overVoltage.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => overVoltage = int.tryParse(v) ?? overVoltage,
                )
                    : Text('$overVoltage V'),
              ),
              _field(
                'Under Voltage Threshold (V)',
                editMode
                    ? TextFormField(
                  initialValue: underVoltage.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => underVoltage = int.tryParse(v) ?? underVoltage,
                )
                    : Text('$underVoltage V'),
              ),
              _field(
                'Over Temperature Threshold (°C)',
                editMode
                    ? TextFormField(
                  initialValue: overTemperature.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => overTemperature = int.tryParse(v) ?? overTemperature,
                )
                    : Text('$overTemperature °C'),
              ),
              // Restore session
              _field(
                'Restore Session from Fault',
                editMode
                    ? Switch(
                  value: restoreSession,
                  onChanged: (v) => setState(() => restoreSession = v),
                )
                    : Text(restoreSession ? 'Enabled' : 'Disabled'),
              ),
              _field(
                'Session Restore Timeout (s)',
                editMode
                    ? TextFormField(
                  initialValue: restoreTimeout.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => restoreTimeout = int.tryParse(v) ?? restoreTimeout,
                )
                    : Text('$restoreTimeout s'),
              ),
              _field(
                'GFCI',
                editMode
                    ? Switch(value: gfci, onChanged: (v) => setState(() => gfci = v))
                    : Text(gfci ? 'Enabled' : 'Disabled'),
              ),
              // Suspended behaviour/time
              _field(
                'Suspended State Behaviour',
                editMode
                    ? DropdownButtonFormField<int>(
                  value: suspendedBehaviour,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Stop Charging')),
                    DropdownMenuItem(value: 1, child: Text('Pause')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => suspendedBehaviour = v);
                  },
                )
                    : Text(suspendedBehaviour == 0 ? 'Stop Charging' : 'Pause'),
              ),
              _field(
                'Suspended Time Threshold (s)',
                editMode
                    ? TextFormField(
                  initialValue: suspendedTime.toString(),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => suspendedTime = int.tryParse(v) ?? suspendedTime,
                )
                    : Text('$suspendedTime s'),
              ),
              // Phase & Load management
              _field(
                'Phase Management Feature',
                editMode
                    ? Switch(value: phaseMgmt, onChanged: (v) => setState(() => phaseMgmt = v))
                    : Text(phaseMgmt ? 'Enabled' : 'Disabled'),
              ),
              _field(
                'Load Management Feature',
                editMode
                    ? Switch(value: loadMgmt, onChanged: (v) => setState(() => loadMgmt = v))
                    : Text(loadMgmt ? 'Enabled' : 'Disabled'),
              ),
              // Connectivity settings widget
              ConnectivitySettings(
                editMode: editMode,
                wifiEnable: wifiEnable,
                gsmEnable: gsmEnable,
                ethEnable: ethEnable,
                wifiPriority: wifiPriority,
                gsmPriority: gsmPriority,
                ethPriority: ethPriority,
                onChanged: (we, ge, ee, wp, gp, ep) {
                  setState(() {
                    wifiEnable = we;
                    gsmEnable = ge;
                    ethEnable = ee;
                    wifiPriority = wp;
                    gsmPriority = gp;
                    ethPriority = ep;
                  });
                },
              ),
              const SizedBox(height: 80),
            ],
          ),
          if (_saving)
            const Positioned.fill(
              child: ColoredBox(
                color: Color.fromARGB(120, 0, 0, 0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}