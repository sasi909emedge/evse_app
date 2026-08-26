import 'dart:convert';
import 'package:flutter/material.dart';
import 'card_management_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ble/ble_service_selector.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../ble/ble_protocol.dart';
import '../models/meter_models.dart';
import '../widgets/common/config_widgets.dart' as w;
import '../constants/evse_constants.dart';

class EvseDetailsScreen extends StatefulWidget {
  final String deviceId;
  final String loggedInUser;
  const EvseDetailsScreen({
    super.key,
    required this.deviceId,
    this.loggedInUser = 'emedge',
  });

  @override
  State<EvseDetailsScreen> createState() => _EvseDetailsScreenState();
}

class _EvseDetailsScreenState extends State<EvseDetailsScreen>
    with SingleTickerProviderStateMixin {
  // ── TAB 1: Charger ───────────────────────────────────────────
  bool defaultConfig = false;
  int chargerType = 1;
  int masterBoardModel = 1;
  int dispenserBoardModel = 1;
  int displayBoardModel = 1;
  int relayBoardModel = 1;
  final serialCtrl = TextEditingController();
  final chargerNameCtrl = TextEditingController();
  final vendorCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final commissionedByCtrl = TextEditingController();
  final commissionedDateCtrl = TextEditingController();
  final firmwareVersionCtrl = TextEditingController();
  final slaveFirmwareVersionCtrl = TextEditingController();
  bool smartCharging = false;
  bool restoreFromFault = false;
  final restoreTimeCtrl = TextEditingController();

  // ── TAB 2: Network ───────────────────────────────────────────
  int networkMode = 0;
  final webSocketURLCtrl = TextEditingController();
  bool wifiEnable = false;
  final wifiPriorityCtrl = TextEditingController();
  final wifiSSIDCtrl = TextEditingController();
  final wifiPassCtrl = TextEditingController();
  bool ethernetEnable = false;
  final ethernetPriorityCtrl = TextEditingController();
  int ethernetConfig = 1;
  final ipAddressCtrl = TextEditingController();
  final gatewayCtrl = TextEditingController();
  final dnsCtrl = TextEditingController();
  final subnetCtrl = TextEditingController();
  final macAddressCtrl = TextEditingController();
  bool gsmEnable = false;
  final gsmPriorityCtrl = TextEditingController();
  final gsmAPNCtrl = TextEditingController();
  final simIMEICtrl = TextEditingController();
  final simIMSICtrl = TextEditingController();

  // ── TAB 3: Hardware ──────────────────────────────────────────
  final displaysCtrl = TextEditingController();
  final connectorsCtrl = TextEditingController();
  final powerModulesCtrl = TextEditingController();
  final mergersCtrl = TextEditingController();
  final dcOverVoltCtrl1 = TextEditingController();
  final dcOverVoltCtrl2 = TextEditingController();
  final acOverVoltCtrl = TextEditingController();
  final dcUnderVoltCtrl1 = TextEditingController();
  final dcUnderVoltCtrl2 = TextEditingController();
  final acUnderVoltCtrl = TextEditingController();
  final dcOverCurrCtrl1 = TextEditingController();
  final dcOverCurrCtrl2 = TextEditingController();
  final acOverCurrCtrl = TextEditingController();
  final overTempCtrl = TextEditingController();
  final dcMinCurrCtrl1 = TextEditingController();
  final dcMinCurrCtrl2 = TextEditingController();
  final dcMaxPowerCtrl1 = TextEditingController();
  final dcMaxPowerCtrl2 = TextEditingController();
  final dcMaxEnergyCtrl1 = TextEditingController();
  final dcMaxEnergyCtrl2 = TextEditingController();
  // Commented out for now — uncomment when Max/Min Temperature is needed.
  // final dcMaxTempCtrl1 = TextEditingController();
  // final dcMaxTempCtrl2 = TextEditingController();
  // final dcMinTempCtrl1 = TextEditingController();
  // final dcMinTempCtrl2 = TextEditingController();

  // ── TAB 4: Meters ────────────────────────────────────────────
  // AC Meter
  String acMeterType = 'EM4M';
  int acVoltageAddr = 1;
  int acCurrentAddr = 2;
  int acPowerAddr = 3;
  int acDataType = 5;
  int acWordOrder = 2;
  int acScaleExp = 0;
  int acOffsetAddr = 40000;

  // DC Meter 1
  String dcMeter1Type = 'EM2M';
  int dc1VoltageAddr = 1;
  int dc1CurrentAddr = 2;
  int dc1PowerAddr = 3;
  int dc1DataType = 0;
  int dc1WordOrder = 0;
  int dc1ScaleExp = 0;
  int dc1OffsetAddr = 40000;

  // DC Meter 2
  String dcMeter2Type = 'EM2M';
  int dc2VoltageAddr = 1;
  int dc2CurrentAddr = 2;
  int dc2PowerAddr = 3;
  int dc2DataType = 0;
  int dc2WordOrder = 0;
  int dc2ScaleExp = 0;
  int dc2OffsetAddr = 40000;
  // ── Meter data model ─────────────────────────────────────────
// AC Meter channels
  late MeterData acV1N, acV2N, acV3N, acV12, acV23, acV31;
  late MeterData acI1, acI2, acI3;
  late MeterData acTotalKW, acAvgPF, acTotalKWh, acCumKWh, acResetCumKWh;

// DC Meter 1
  late MeterData dc1Voltage, dc1Current, dc1Power, dc1Energy;

// DC Meter 2
  late MeterData dc2Voltage, dc2Current, dc2Power, dc2Energy;

// Power modules (8 max)
  final List<bool> pmAvailable = List.filled(8, false);
  final List<TextEditingController> pmAddressCtrl =
      List.generate(8, (_) => TextEditingController());
  final List<TextEditingController> pmMaxVoltCtrl =
      List.generate(8, (_) => TextEditingController());
  final List<TextEditingController> pmMaxCurrCtrl =
      List.generate(8, (_) => TextEditingController());
  final List<TextEditingController> pmMinVoltCtrl =
      List.generate(8, (_) => TextEditingController());
  final List<TextEditingController> pmMinCurrCtrl =
      List.generate(8, (_) => TextEditingController());
  final List<TextEditingController> pmMaxPowerCtrl =
      List.generate(8, (_) => TextEditingController());
  final List<TextEditingController> pmMinPowerCtrl =
      List.generate(8, (_) => TextEditingController());
  final List<TextEditingController> pmMaxTempCtrl =
      List.generate(8, (_) => TextEditingController());
  final List<TextEditingController> pmMinTempCtrl =
      List.generate(8, (_) => TextEditingController());

  // ── TAB 5: OTA ───────────────────────────────────────────────
  bool otaUrlFromCMS = false;
  final otaURLCtrl = TextEditingController();
  bool diagnosticServer = false;
  final diagnosticURLCtrl = TextEditingController();

  // ── UI State ─────────────────────────────────────────────────
  bool _loading = true;
  bool _saving = false;
  bool _editMode = false;
  bool _reading = false;
  bool _disconnecting = false;
  bool _configDirty = false;
  bool _meterDirty = false;
  bool _powerModuleDirty = false;
  bool _connectorDirty = false;
  Map<String, dynamic> _originalConfig = {};
  Map<String, dynamic> _originalMeter = {};
  Map<String, dynamic> _originalPowerModule = {};
  Map<String, dynamic> _originalConnector = {};
  late TabController _tabCtrl;

  String _acMeterTypeFromEnum(dynamic raw) {
    final v = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
    for (final e in acMeterTypeEnum.entries) {
      if (e.value == v) return e.key;
    }
    return 'User Defined';
  }

  String _dcMeterTypeFromEnum(dynamic raw) {
    final v = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
    for (final e in dcMeterTypeEnum.entries) {
      if (e.value == v) return e.key;
    }
    return 'User Defined';
  }

  void _applyAcPreset(String meterType) {
    final channels = acMeterChannelPresets[meterType];
    if (channels == null) return; // 'User Defined' — leave editable, untouched
    void apply(MeterData d, ChannelPreset p) {
      d.moduleAddress = p.address;
      d.registerCount = p.registerCount;
      d.dataType = p.dataType;
      d.wordOrder = p.wordOrder;
      d.scaleExponent = p.scaleExponent;
    }

    apply(acV1N, channels['VoltageV1N']!);
    apply(acV2N, channels['VoltageV2N']!);
    apply(acV3N, channels['VoltageV3N']!);
    apply(acV12, channels['VoltageV12']!);
    apply(acV23, channels['VoltageV23']!);
    apply(acV31, channels['VoltageV31']!);
    apply(acI1, channels['CurrentI1']!);
    apply(acI2, channels['CurrentI2']!);
    apply(acI3, channels['CurrentI3']!);
    apply(acTotalKW, channels['TotalKW']!);
    apply(acAvgPF, channels['AveragePF']!);
    apply(acTotalKWh, channels['TotalKWh']!);
    apply(acCumKWh, channels['CumulativeKWh']!);
    apply(acResetCumKWh, channels['ResetCumulativeKWh']!);
  }

  void _applyDcPreset(String meterType, MeterData voltage, MeterData current,
      MeterData power, MeterData energy) {
    final channels = dcMeterChannelPresets[meterType];
    if (channels == null) return; // 'User Defined'
    void apply(MeterData d, ChannelPreset p) {
      d.moduleAddress = p.address;
      d.registerCount = p.registerCount;
      d.dataType = p.dataType;
      d.wordOrder = p.wordOrder;
      d.scaleExponent = p.scaleExponent;
    }

    apply(voltage, channels['Voltage']!);
    apply(current, channels['Current']!);
    apply(power, channels['Power']!);
    apply(energy, channels['Energy']!);
  }

  // ── Theme ─────────────────────────────────────────────────────
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? AppColors.backgroundDark : AppColors.background;
  Color get _surface => _isDark ? AppColors.surfaceDark : AppColors.surface;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  Color get _border => _isDark ? AppColors.borderDark : AppColors.border;

  int get _connectorCount => int.tryParse(connectorsCtrl.text) ?? 1;

  // ── NVS Key for this charger ──────────────────────────────────
  String get _storageKey =>
      'charger_config_${widget.deviceId.replaceAll(':', '')}';

  // ── Apply Data ────────────────────────────────────────────────
  void _applyData(Map<String, dynamic> d) {
    defaultConfig = _bool(d["defaultConfig"]);
    chargerType = _mapEnum(chargerTypes, d["ChargerType"], 1);
    masterBoardModel = _clampBoardModel(d["masterBoardModel"]);
    dispenserBoardModel = _clampBoardModel(d["dispenserBoardModel"]);
    displayBoardModel = _clampBoardModel(d["displayBoardModel"]);
    relayBoardModel = _clampBoardModel(d["relayBoardModel"]);
    serialCtrl.text = d["serialNumber"]?.toString() ?? "";
    chargerNameCtrl.text = d["chargerName"]?.toString() ?? "";
    vendorCtrl.text = d["chargePointVendor"]?.toString() ?? "";
    modelCtrl.text = d["chargePointModel"]?.toString() ?? "";
    commissionedByCtrl.text = widget.loggedInUser;
    commissionedDateCtrl.text = _today();
    firmwareVersionCtrl.text = d["firmwareVersion"]?.toString() ?? "";
    slaveFirmwareVersionCtrl.text = d["slavefirmwareVersion"]?.toString() ?? "";
    smartCharging = _bool(d["smartCharging"]);
    restoreFromFault = _bool(d["restoreSessionFromFault"]);
    restoreTimeCtrl.text = d["restoreSessionFromFaultTime"]?.toString() ?? "";
    networkMode = _mapEnum(networkModes, d["networkMode"], 0);
    webSocketURLCtrl.text = d["webSocketURL"]?.toString() ?? "";
    wifiEnable = _bool(d["wifiEnable"]);
    wifiPriorityCtrl.text = d["wifiPriority"]?.toString() ?? "";
    wifiSSIDCtrl.text = d["wifiSSID"]?.toString() ?? "";
    wifiPassCtrl.text = d["wifiPassword"]?.toString() ?? "";
    ethernetEnable = _bool(d["ethernetEnable"]);
    ethernetPriorityCtrl.text = d["ethernetPriority"]?.toString() ?? "";
    ethernetConfig = _mapEnum(ethernetTypes, d["ethernetConfig"], 1);
    ipAddressCtrl.text = d["ipAddress"]?.toString() ?? "";
    gatewayCtrl.text = d["gatewayAddress"]?.toString() ?? "";
    dnsCtrl.text = d["dnsAddress"]?.toString() ?? "";
    subnetCtrl.text = d["subnetMask"]?.toString() ?? "";
    macAddressCtrl.text = d["macAddress"]?.toString() ?? "";
    gsmEnable = _bool(d["gsmEnable"]);
    gsmPriorityCtrl.text = d["gsmPriority"]?.toString() ?? "";
    gsmAPNCtrl.text = d["gsmAPN"]?.toString() ?? "";
    simIMEICtrl.text = d["simIMEINumber"]?.toString() ?? "";
    simIMSICtrl.text = d["simIMSINumber"]?.toString() ?? "";
    displaysCtrl.text = d["NumberOfDisplays"]?.toString() ?? "";
    connectorsCtrl.text = d["NumberOfConnectors"]?.toString() ?? "";
    powerModulesCtrl.text = d["NumberOfPowerModules"]?.toString() ?? "";
    mergersCtrl.text = d["NumberOfMergers"]?.toString() ?? "";
    final dcOverVoltList = d["DCMaxVoltage"];
    if (dcOverVoltList is List) {
      dcOverVoltCtrl1.text =
          dcOverVoltList.isNotEmpty ? dcOverVoltList[0].toString() : "";
      dcOverVoltCtrl2.text =
          dcOverVoltList.length > 1 ? dcOverVoltList[1].toString() : "";
    } else {
      dcOverVoltCtrl1.text = dcOverVoltList?.toString() ?? "";
      dcOverVoltCtrl2.text = "";
    }
    acOverVoltCtrl.text = d["ACoverVoltageThreshold"]?.toString() ?? "";
    final dcUnderVoltList = d["DCMinVoltage"];
    if (dcUnderVoltList is List) {
      dcUnderVoltCtrl1.text =
          dcUnderVoltList.isNotEmpty ? dcUnderVoltList[0].toString() : "";
      dcUnderVoltCtrl2.text =
          dcUnderVoltList.length > 1 ? dcUnderVoltList[1].toString() : "";
    } else {
      dcUnderVoltCtrl1.text = dcUnderVoltList?.toString() ?? "";
      dcUnderVoltCtrl2.text = "";
    }
    acUnderVoltCtrl.text = d["ACunderVoltageThreshold"]?.toString() ?? "";
    final dcOverCurrList = d["DCMaxCurrent"];
    if (dcOverCurrList is List) {
      dcOverCurrCtrl1.text =
          dcOverCurrList.isNotEmpty ? dcOverCurrList[0].toString() : "";
      dcOverCurrCtrl2.text =
          dcOverCurrList.length > 1 ? dcOverCurrList[1].toString() : "";
    } else {
      // Fallback for old single-value format, if ever received
      dcOverCurrCtrl1.text = dcOverCurrList?.toString() ?? "";
      dcOverCurrCtrl2.text = "";
    }
    acOverCurrCtrl.text = d["ACoverCurrentThreshold"]?.toString() ?? "";
    overTempCtrl.text = d["overTemperatureThreshold"]?.toString() ?? "";
    final dcMinCurrList = d["DCMinCurrent"];
    if (dcMinCurrList is List) {
      dcMinCurrCtrl1.text =
          dcMinCurrList.isNotEmpty ? dcMinCurrList[0].toString() : "";
      dcMinCurrCtrl2.text =
          dcMinCurrList.length > 1 ? dcMinCurrList[1].toString() : "";
    } else {
      dcMinCurrCtrl1.text = dcMinCurrList?.toString() ?? "";
      dcMinCurrCtrl2.text = "";
    }
    final dcMaxPowerList = d["DCMaxPower"];
    if (dcMaxPowerList is List) {
      dcMaxPowerCtrl1.text =
          dcMaxPowerList.isNotEmpty ? dcMaxPowerList[0].toString() : "";
      dcMaxPowerCtrl2.text =
          dcMaxPowerList.length > 1 ? dcMaxPowerList[1].toString() : "";
    } else {
      dcMaxPowerCtrl1.text = dcMaxPowerList?.toString() ?? "";
      dcMaxPowerCtrl2.text = "";
    }
    final dcMaxEnergyList = d["DCMaxEnergy"];
    if (dcMaxEnergyList is List) {
      dcMaxEnergyCtrl1.text =
          dcMaxEnergyList.isNotEmpty ? dcMaxEnergyList[0].toString() : "";
      dcMaxEnergyCtrl2.text =
          dcMaxEnergyList.length > 1 ? dcMaxEnergyList[1].toString() : "";
    } else {
      dcMaxEnergyCtrl1.text = dcMaxEnergyList?.toString() ?? "";
      dcMaxEnergyCtrl2.text = "";
    }
    // Parse AC meter channels
    final acM = d["acMeter"] as Map<String, dynamic>? ?? {};
    acMeterType = _acMeterTypeFromEnum(acM["meterType"]);
    acV1N = MeterData.fromMap(acM["VoltageV1N"] as Map<String, dynamic>? ?? {});
    acV2N = MeterData.fromMap(acM["VoltageV2N"] as Map<String, dynamic>? ?? {});
    acV3N = MeterData.fromMap(acM["VoltageV3N"] as Map<String, dynamic>? ?? {});
    acV12 = MeterData.fromMap(acM["VoltageV12"] as Map<String, dynamic>? ?? {});
    acV23 = MeterData.fromMap(acM["VoltageV23"] as Map<String, dynamic>? ?? {});
    acV31 = MeterData.fromMap(acM["VoltageV31"] as Map<String, dynamic>? ?? {});
    acI1 = MeterData.fromMap(acM["CurrentI1"] as Map<String, dynamic>? ?? {});
    acI2 = MeterData.fromMap(acM["CurrentI2"] as Map<String, dynamic>? ?? {});
    acI3 = MeterData.fromMap(acM["CurrentI3"] as Map<String, dynamic>? ?? {});
    acTotalKW =
        MeterData.fromMap(acM["TotalKW"] as Map<String, dynamic>? ?? {});
    acAvgPF =
        MeterData.fromMap(acM["AveragePF"] as Map<String, dynamic>? ?? {});
    acTotalKWh =
        MeterData.fromMap(acM["TotalKWh"] as Map<String, dynamic>? ?? {});
    acCumKWh =
        MeterData.fromMap(acM["CumulativeKWh"] as Map<String, dynamic>? ?? {});
    acResetCumKWh = MeterData.fromMap(
        acM["ResetCumulativeKWh"] as Map<String, dynamic>? ?? {});

// Parse DC meter 1
    final dc1M = d["dcMeter1"] as Map<String, dynamic>? ?? {};
    dcMeter1Type = _dcMeterTypeFromEnum(dc1M["meterType"]);
    dc1Voltage =
        MeterData.fromMap(dc1M["Voltage"] as Map<String, dynamic>? ?? {});
    dc1Current =
        MeterData.fromMap(dc1M["Current"] as Map<String, dynamic>? ?? {});
    dc1Power = MeterData.fromMap(dc1M["Power"] as Map<String, dynamic>? ?? {});
    dc1Energy =
        MeterData.fromMap(dc1M["Energy"] as Map<String, dynamic>? ?? {});

// Parse DC meter 2
    final dc2M = d["dcMeter2"] as Map<String, dynamic>? ?? {};
    dcMeter2Type = _dcMeterTypeFromEnum(dc2M["meterType"]);
    dc2Voltage =
        MeterData.fromMap(dc2M["Voltage"] as Map<String, dynamic>? ?? {});
    dc2Current =
        MeterData.fromMap(dc2M["Current"] as Map<String, dynamic>? ?? {});
    dc2Power = MeterData.fromMap(dc2M["Power"] as Map<String, dynamic>? ?? {});
    dc2Energy =
        MeterData.fromMap(dc2M["Energy"] as Map<String, dynamic>? ?? {});

// Parse power modules
    for (int i = 0; i < 8; i++) {
      final pm = d["PowerModule${i + 1}"] as Map<String, dynamic>? ?? {};

      debugPrint(
          "PM${i + 1} raw isAvailable = ${pm["isAvailable"]} (${pm["isAvailable"].runtimeType})");

      pmAvailable[i] = _bool(pm["isAvailable"]);

      debugPrint("PM${i + 1}: parsed = ${pmAvailable[i]}");

      pmAddressCtrl[i].text = pm["moduleAddress"]?.toString() ?? "";
      pmMaxVoltCtrl[i].text = pm["MaxVoltage"]?.toString() ?? "";
      pmMaxCurrCtrl[i].text = pm["MaxCurrent"]?.toString() ?? "";
      pmMinVoltCtrl[i].text = pm["MinVoltage"]?.toString() ?? "";
      pmMinCurrCtrl[i].text = pm["MinCurrent"]?.toString() ?? "";
      pmMaxPowerCtrl[i].text = pm["MaxPower"]?.toString() ?? "";
      pmMinPowerCtrl[i].text = pm["MinPower"]?.toString() ?? "";
      pmMaxTempCtrl[i].text = pm["MaxTemperature"]?.toString() ?? "";
      pmMinTempCtrl[i].text = pm["MinTemperature"]?.toString() ?? "";
    }

    debugPrint("Final pmAvailable = $pmAvailable");
    acVoltageAddr = acM["voltageAddr"] as int? ?? 1;
    acCurrentAddr = acM["currentAddr"] as int? ?? 2;
    acPowerAddr = acM["powerAddr"] as int? ?? 3;
    acDataType = acM["dataType"] as int? ?? 5;
    acWordOrder = acM["wordOrder"] as int? ?? 2;
    acScaleExp = acM["scaleExp"] as int? ?? 0;
    acOffsetAddr = acM["OffsetAddress"] as int? ?? 40000;
    dc1VoltageAddr = dc1M["voltageAddr"] as int? ?? 1;
    dc1CurrentAddr = dc1M["currentAddr"] as int? ?? 2;
    dc1PowerAddr = dc1M["powerAddr"] as int? ?? 3;
    dc1DataType = dc1M["dataType"] as int? ?? 0;
    dc1WordOrder = dc1M["wordOrder"] as int? ?? 0;
    dc1ScaleExp = dc1M["scaleExp"] as int? ?? 0;
    dc1OffsetAddr = dc1M["offsetAddr"] as int? ?? 40000;
    dc2VoltageAddr = dc2M["voltageAddr"] as int? ?? 1;
    dc2CurrentAddr = dc2M["currentAddr"] as int? ?? 2;
    dc2PowerAddr = dc2M["powerAddr"] as int? ?? 3;
    dc2DataType = dc2M["dataType"] as int? ?? 0;
    dc2WordOrder = dc2M["wordOrder"] as int? ?? 0;
    dc2ScaleExp = dc2M["scaleExp"] as int? ?? 0;
    dc2OffsetAddr = dc2M["offsetAddr"] as int? ?? 40000;
    otaUrlFromCMS = _bool(d["OtaUrlFromCMSEnable"]);
    otaURLCtrl.text = d["OtaURLConfig"]?.toString() ?? "";
    diagnosticServer = _bool(d["DiagnosticServer"]);
    diagnosticURLCtrl.text = d["DiagnosticServerUrl"]?.toString() ?? "";
    // Save original charger values
    _originalConfig = Map<String, dynamic>.from(_currentConfigSnapshot());
    _originalMeter = Map<String, dynamic>.from(_currentMeterSnapshot());
    _originalPowerModule =
        Map<String, dynamic>.from(_currentPowerModuleSnapshot());
    _originalConnector = Map<String, dynamic>.from(_buildConnectorMap());

// Freshly loaded data is not dirty
    _configDirty = false;
    _meterDirty = false;
    _powerModuleDirty = false;
    _connectorDirty = false;
  }

  bool _bool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v == 1 || v == 1.0;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    return false;
  }

  void _updateDirtyFlags() {
    _configDirty = !_mapsEqual(_currentConfigSnapshot(), _originalConfig);

    final currentMeter = _currentMeterSnapshot();
    _meterDirty = !_mapsEqual(currentMeter, _originalMeter);
    if (_meterDirty) {
      _debugDiff("METER", _originalMeter, currentMeter);
    }

    _powerModuleDirty =
        !_mapsEqual(_currentPowerModuleSnapshot(), _originalPowerModule);

    _connectorDirty = !_mapsEqual(_buildConnectorMap(), _originalConnector);
  }

  void _markConfigChanged() {
    _updateDirtyFlags();
    if (mounted) setState(() {});
  }

  void _markMeterChanged() {
    _updateDirtyFlags();
    if (mounted) setState(() {});
  }

  void _markPowerModuleChanged() {
    _updateDirtyFlags();
    if (mounted) setState(() {});
  }

  bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    return _valuesMatch(a, b);
  }

  void _debugDiff(
      String label, Map<String, dynamic> a, Map<String, dynamic> b) {
    final allKeys = {...a.keys, ...b.keys};
    for (final k in allKeys) {
      if (jsonEncode(a[k]) != jsonEncode(b[k])) {
        debugPrint("🔍 $label diff on '$k':");
        debugPrint("    original: ${jsonEncode(a[k])}");
        debugPrint("    current : ${jsonEncode(b[k])}");
      }
    }
  }

  bool _verifyContains(
      Map<String, dynamic> readback, Map<String, dynamic> expectedSubset) {
    bool allMatch = true;
    for (final key in expectedSubset.keys) {
      if (!_valuesMatch(expectedSubset[key], readback[key])) {
        debugPrint(
            "⚠️ Mismatch on '$key': sent=${jsonEncode(expectedSubset[key])} "
            "charger=${jsonEncode(readback[key])}");
        allMatch = false;
      }
    }
    return allMatch;
  }

  int? _enumStringToInt(String s) {
    for (final map in [chargerTypes, networkModes, ethernetTypes]) {
      for (final e in map.entries) {
        if (e.value == s) return e.key;
      }
    }
    return null;
  }

  bool _valuesMatch(dynamic sent, dynamic got) {
    // Handle nulls
    if (sent == null || got == null) {
      return sent == got;
    }

    // Numbers (1000 == 1000.0)
    if (sent is num && got is num) {
      return (sent.toDouble() - got.toDouble()).abs() < 0.0001;
    }

    // Enum string ↔ int
    if (sent is String && got is num) {
      final asInt = _enumStringToInt(sent);
      if (asInt != null) return asInt == got;
    }

    if (sent is num && got is String) {
      final asInt = _enumStringToInt(got);
      if (asInt != null) return asInt == sent;
    }

    // Map comparison (recursive)
    if (sent is Map && got is Map) {
      if (sent.length != got.length) return false;

      for (final key in sent.keys) {
        if (!got.containsKey(key)) return false;

        if (!_valuesMatch(sent[key], got[key])) {
          return false;
        }
      }

      return true;
    }

    // List comparison
    if (sent is List && got is List) {
      if (sent.length != got.length) return false;

      for (int i = 0; i < sent.length; i++) {
        if (!_valuesMatch(sent[i], got[i])) {
          return false;
        }
      }

      return true;
    }

    return sent == got;
  }

  void _restoreOriginalValues() {
    final all = {
      ..._originalConfig,
      ..._originalMeter,
      ..._originalPowerModule,
      ..._originalConnector,
    };

    _applyData(all);

    setState(() {
      _configDirty = false;
      _meterDirty = false;
      _powerModuleDirty = false;
      _connectorDirty = false;
      _editMode = false;
    });
  }

  int _mapEnum(Map<int, String> map, dynamic val, int fallback) {
    if (val == null) return fallback;
    final str = val.toString();
    for (final e in map.entries) {
      if (e.value == str || e.key.toString() == str) return e.key;
    }
    return fallback;
  }

  int _clampBoardModel(dynamic raw) {
    final v = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 1;
    return (v >= 1 && v <= 3) ? v : 1;
  }

  Map<String, dynamic> _buildChargerMap() => {
        "defaultConfig": defaultConfig,
        "ChargerType": chargerTypes[chargerType],
        "masterBoardModel": masterBoardModel,
        "dispenserBoardModel": dispenserBoardModel,
        "displayBoardModel": displayBoardModel,
        "relayBoardModel": relayBoardModel,
        "serialNumber": serialCtrl.text.trim(),
        "chargerName": chargerNameCtrl.text.trim(),
        "chargePointVendor": vendorCtrl.text.trim(),
        "chargePointModel": modelCtrl.text.trim(),
        "commissionedBy": widget.loggedInUser,
        "commissionedDate": _today(),
        "smartCharging": smartCharging,
        "restoreSessionFromFault": restoreFromFault,
        "restoreSessionFromFaultTime":
            int.tryParse(restoreTimeCtrl.text.trim()) ?? 0,
      };

  Map<String, dynamic> _buildNetworkMap() => {
        "networkMode": networkModes[networkMode],
        "webSocketURL": webSocketURLCtrl.text.trim(),
        "wifiEnable": wifiEnable,
        "wifiPriority": int.tryParse(wifiPriorityCtrl.text.trim()) ?? 1,
        "wifiSSID": wifiSSIDCtrl.text.trim(),
        "wifiPassword": wifiPassCtrl.text.trim(),
        "ethernetEnable": ethernetEnable,
        "ethernetPriority": int.tryParse(ethernetPriorityCtrl.text.trim()) ?? 3,
        "ethernetConfig": ethernetTypes[ethernetConfig],
        "ipAddress": ipAddressCtrl.text.trim(),
        "gatewayAddress": gatewayCtrl.text.trim(),
        "dnsAddress": dnsCtrl.text.trim(),
        "subnetMask": subnetCtrl.text.trim(),
        "macAddress": macAddressCtrl.text.trim(),
        "gsmEnable": gsmEnable,
        "gsmPriority": int.tryParse(gsmPriorityCtrl.text.trim()) ?? 2,
        "gsmAPN": gsmAPNCtrl.text.trim(),
        "simIMEINumber": simIMEICtrl.text.trim(),
        "simIMSINumber": simIMSICtrl.text.trim(),
      };

  Map<String, dynamic> _buildHardwareMap() => {
        "NumberOfDisplays": int.tryParse(displaysCtrl.text.trim()) ?? 1,
        "NumberOfMergers": int.tryParse(mergersCtrl.text.trim()) ?? 0,
      };

  Map<String, dynamic> _buildConnectorMap() => {
        "overTemperatureThreshold":
            double.tryParse(overTempCtrl.text.trim()) ?? 0.0,
        "ACunderVoltageThreshold":
            double.tryParse(acUnderVoltCtrl.text.trim()) ?? 0.0,
        "ACoverVoltageThreshold":
            double.tryParse(acOverVoltCtrl.text.trim()) ?? 0.0,
        "ACoverCurrentThreshold": int.tryParse(acOverCurrCtrl.text.trim()) ?? 0,
        "NumberOfConnectors": int.tryParse(connectorsCtrl.text.trim()) ?? 1,
        "DCMaxVoltage": [
          double.tryParse(dcOverVoltCtrl1.text.trim()) ?? 0.0,
          if (_connectorCount >= 2)
            double.tryParse(dcOverVoltCtrl2.text.trim()) ?? 0.0,
        ],
        "DCMinVoltage": [
          double.tryParse(dcUnderVoltCtrl1.text.trim()) ?? 0.0,
          if (_connectorCount >= 2)
            double.tryParse(dcUnderVoltCtrl2.text.trim()) ?? 0.0,
        ],
        "DCMaxCurrent": [
          int.tryParse(dcOverCurrCtrl1.text.trim()) ?? 0,
          if (_connectorCount >= 2)
            int.tryParse(dcOverCurrCtrl2.text.trim()) ?? 0,
        ],
        "DCMinCurrent": [
          int.tryParse(dcMinCurrCtrl1.text.trim()) ?? 0,
          if (_connectorCount >= 2)
            int.tryParse(dcMinCurrCtrl2.text.trim()) ?? 0,
        ],
        "DCMaxPower": [
          double.tryParse(dcMaxPowerCtrl1.text.trim()) ?? 0.0,
          if (_connectorCount >= 2)
            double.tryParse(dcMaxPowerCtrl2.text.trim()) ?? 0.0,
        ],
        "DCMaxEnergy": [
          double.tryParse(dcMaxEnergyCtrl1.text.trim()) ?? 0.0,
          if (_connectorCount >= 2)
            double.tryParse(dcMaxEnergyCtrl2.text.trim()) ?? 0.0,
        ],
        // Commented out for now — uncomment when Max/Min Temperature is needed.
        // "DCMaxTemperature": [
        //   double.tryParse(dcMaxTempCtrl1.text.trim()) ?? 0.0,
        //   if (_connectorCount >= 2)
        //     double.tryParse(dcMaxTempCtrl2.text.trim()) ?? 0.0,
        // ],
        // "DCMinTemperature": [
        //   double.tryParse(dcMinTempCtrl1.text.trim()) ?? 0.0,
        //   if (_connectorCount >= 2)
        //     double.tryParse(dcMinTempCtrl2.text.trim()) ?? 0.0,
        // ],
      };

  Map<String, dynamic> _buildPowerModuleMap() => {
        "NumberOfPowerModules": int.tryParse(powerModulesCtrl.text.trim()) ?? 1,
        for (int i = 0; i < 8; i++)
          "PowerModule${i + 1}": {
            "isAvailable": pmAvailable[i],
            "moduleAddress": int.tryParse(pmAddressCtrl[i].text.trim()) ?? 0,
            "MaxVoltage": double.tryParse(pmMaxVoltCtrl[i].text.trim()) ?? 0.0,
            "MaxCurrent": double.tryParse(pmMaxCurrCtrl[i].text.trim()) ?? 0.0,
            "MinVoltage": double.tryParse(pmMinVoltCtrl[i].text.trim()) ?? 0.0,
            "MinCurrent": double.tryParse(pmMinCurrCtrl[i].text.trim()) ?? 0.0,
            "MaxPower": double.tryParse(pmMaxPowerCtrl[i].text.trim()) ?? 0.0,
            "MinPower": double.tryParse(pmMinPowerCtrl[i].text.trim()) ?? 0.0,
            "MaxTemperature":
                double.tryParse(pmMaxTempCtrl[i].text.trim()) ?? 0.0,
            "MinTemperature":
                double.tryParse(pmMinTempCtrl[i].text.trim()) ?? 0.0,
          },
      };

  Map<String, dynamic> _buildMeterMap() {
    final connectors = _connectorCount;
    final map = <String, dynamic>{
      "acMeter": {
        "meterType": acMeterTypeEnum[acMeterType] ?? 0,
        "OffsetAddress": acOffsetAddr,
        "VoltageV1N": _meterDataMap(1, acV1N),
        "VoltageV2N": _meterDataMap(1, acV2N),
        "VoltageV3N": _meterDataMap(1, acV3N),
        "VoltageV12": _meterDataMap(1, acV12),
        "VoltageV23": _meterDataMap(1, acV23),
        "VoltageV31": _meterDataMap(1, acV31),
        "CurrentI1": _meterDataMap(2, acI1),
        "CurrentI2": _meterDataMap(2, acI2),
        "CurrentI3": _meterDataMap(2, acI3),
        "TotalKW": _meterDataMap(3, acTotalKW),
        "AveragePF": _meterDataMap(3, acAvgPF),
        "TotalKWh": _meterDataMap(4, acTotalKWh),
        "CumulativeKWh": _meterDataMap(4, acCumKWh),
        "ResetCumulativeKWh": _meterDataMap(4, acResetCumKWh),
      },
    };

    if (connectors >= 1) {
      map["dcMeter1"] = {
        "meterType": dcMeterTypeEnum[dcMeter1Type] ?? 0,
        "assignedGun": 1,
        "OffsetAddress": dc1OffsetAddr,
        "Voltage": _meterDataMap(1, dc1Voltage),
        "Current": _meterDataMap(2, dc1Current),
        "Power": _meterDataMap(3, dc1Power),
        "Energy": _meterDataMap(4, dc1Energy),
      };
    }

    if (connectors >= 2) {
      map["dcMeter2"] = {
        "meterType": dcMeterTypeEnum[dcMeter2Type] ?? 0,
        "assignedGun": 2,
        "OffsetAddress": dc2OffsetAddr,
        "Voltage": _meterDataMap(1, dc2Voltage),
        "Current": _meterDataMap(2, dc2Current),
        "Power": _meterDataMap(3, dc2Power),
        "Energy": _meterDataMap(4, dc2Energy),
      };
    }

    return map;
  }

  Map<String, dynamic> _meterDataMap(int paramValue, MeterData m) => {
        "Param": paramValue,
        "Address": m.moduleAddress,
        "RegisterCount": m.registerCount,
        "DataType": m.dataType,
        "WordOrder": m.wordOrder,
        "ScaleExponent": m.scaleExponent,
      };

  Map<String, dynamic> _buildOtaMap() => {
        "OtaUrlFromCMSEnable": otaUrlFromCMS,
        "OtaURLConfig": otaURLCtrl.text.trim(),
        "DiagnosticServer": diagnosticServer,
        "DiagnosticServerUrl": diagnosticURLCtrl.text.trim(),
      };

  Map<String, dynamic> _currentConfigSnapshot() {
    return {
      ..._buildChargerMap(),
      ..._buildNetworkMap(),
      ..._buildHardwareMap(),
      ..._buildOtaMap(),
    };
  }

  Map<String, dynamic> _currentMeterSnapshot() {
    return _buildMeterMap();
  }

  Map<String, dynamic> _currentPowerModuleSnapshot() {
    return _buildPowerModuleMap();
  }

  String _today() {
    final n = DateTime.now();
    return "${n.day.toString().padLeft(2, '0')}-${n.month.toString().padLeft(2, '0')}-${n.year}";
  }

  // ── Local Storage ─────────────────────────────────────────────
  Future<void> _saveLocally(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(data));
      debugPrint("💾 Config saved locally for ${widget.deviceId}");
    } catch (e) {
      debugPrint("❌ Local save: $e");
    }
  }

  Future<Map<String, dynamic>> _loadLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_storageKey);
      if (str != null && str.isNotEmpty) {
        return jsonDecode(str) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("❌ Local load: $e");
    }
    return {};
  }

  // ── Reset — load locally saved config for THIS charger ────────
  Future<void> _resetToSaved() async {
    final ok = await _confirm(
      "Reset Configuration",
      "Load the last saved configuration for this charger (${widget.deviceId})?",
    );
    if (!ok) return;
    final local = await _loadLocally();
    if (local.isEmpty) {
      _snack("No saved config found for this charger", ok: false);
      return;
    }
    setState(() => _applyData(local));
    _snack("Restored saved configuration — press Save to write to charger");
  }

  // ── Load from charger ─────────────────────────────────────────
  Future<void> _load() async {
    if (_reading) return;
    _reading = true;
    try {
      int w = 0;
      while (!BleService.instance.isGattReady(widget.deviceId) && w < 5000) {
        await Future.delayed(const Duration(milliseconds: 200));
        w += 200;
      }
      if (!BleService.instance.isGattReady(widget.deviceId)) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      await Future.delayed(const Duration(milliseconds: 400));
      Map<String, dynamic> data = {};
      try {
        data = await BleService.instance.readJson(widget.deviceId);
      } catch (e) {
        debugPrint("❌ Read: $e");
      }
      if (data.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 600));
        try {
          data = await BleService.instance.readJson(widget.deviceId);
        } catch (e) {
          debugPrint("❌ Retry: $e");
        }
      }
      if (!mounted) return;
      if (data.isNotEmpty) {
        debugPrint("========== INITIAL LOAD ==========");
        debugPrint("NumberOfPowerModules = ${data["NumberOfPowerModules"]}");
        debugPrint("NumberOfConnectors = ${data["NumberOfConnectors"]}");
        debugPrint("NumberOfMergers = ${data["NumberOfMergers"]}");

        debugPrint("Has PowerModule1: ${data.containsKey("PowerModule1")}");
        debugPrint("PowerModule1 = ${jsonEncode(data["PowerModule1"])}");

        debugPrint("Has MergerMap: ${data.containsKey("MergerMap")}");
        debugPrint("MergerMap = ${jsonEncode(data["MergerMap"])}");

        debugPrint("Has mergerMap: ${data.containsKey("mergerMap")}");
        debugPrint("mergerMap = ${jsonEncode(data["mergerMap"])}");

        debugPrint("Has MuxMap: ${data.containsKey("MuxMap")}");
        debugPrint("MuxMap = ${jsonEncode(data["MuxMap"])}");

        debugPrint("Has muxMap: ${data.containsKey("muxMap")}");
        debugPrint("muxMap = ${jsonEncode(data["muxMap"])}");

        debugPrint("Configuration keys = ${data.keys.toList()}");
        debugPrint("================================");
        setState(() => _applyData(data));
        await _saveLocally(data); // Save to local storage
      }
      setState(() => _loading = false);
    } catch (e) {
      debugPrint("❌ Load: $e");
      if (mounted) setState(() => _loading = false);
    } finally {
      _reading = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
    // Initialize all meter data
    acV1N = MeterData(param: 1);
    acV2N = MeterData(param: 1);
    acV3N = MeterData(param: 1);
    acV12 = MeterData(param: 1);
    acV23 = MeterData(param: 1);
    acV31 = MeterData(param: 1);
    acI1 = MeterData(param: 2);
    acI2 = MeterData(param: 2);
    acI3 = MeterData(param: 2);
    acTotalKW = MeterData(param: 3);
    acAvgPF = MeterData(param: 3);
    acTotalKWh = MeterData(param: 4);
    acCumKWh = MeterData(param: 4);
    acResetCumKWh = MeterData(param: 4);
    dc1Voltage = MeterData(param: 1);
    dc1Current = MeterData(param: 2);
    dc1Power = MeterData(param: 3);
    dc1Energy = MeterData(param: 4);
    dc2Voltage = MeterData(param: 1);
    dc2Current = MeterData(param: 2);
    dc2Power = MeterData(param: 3);
    dc2Energy = MeterData(param: 4);
    commissionedByCtrl.text = widget.loggedInUser;
    commissionedDateCtrl.text = _today();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!BleService.instance.isGattReady(widget.deviceId)) {
        await BleService.instance.discoverServices(widget.deviceId);
      }
      await _load();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    for (final c in [
      serialCtrl,
      chargerNameCtrl,
      vendorCtrl,
      modelCtrl,
      commissionedByCtrl,
      commissionedDateCtrl,
      firmwareVersionCtrl,
      slaveFirmwareVersionCtrl,
      restoreTimeCtrl,
      webSocketURLCtrl,
      wifiPriorityCtrl,
      wifiSSIDCtrl,
      wifiPassCtrl,
      ethernetPriorityCtrl,
      ipAddressCtrl,
      gatewayCtrl,
      dnsCtrl,
      subnetCtrl,
      macAddressCtrl,
      gsmPriorityCtrl,
      gsmAPNCtrl,
      simIMEICtrl,
      simIMSICtrl,
      displaysCtrl,
      connectorsCtrl,
      powerModulesCtrl,
      mergersCtrl,
      dcOverVoltCtrl1,
      dcOverVoltCtrl2,
      acOverVoltCtrl,
      dcUnderVoltCtrl1,
      dcUnderVoltCtrl2,
      acUnderVoltCtrl,
      dcOverCurrCtrl1,
      dcOverCurrCtrl2,
      acOverCurrCtrl,
      overTempCtrl,
      dcMinCurrCtrl1,
      dcMinCurrCtrl2,
      dcMaxPowerCtrl1,
      dcMaxPowerCtrl2,
      dcMaxEnergyCtrl1,
      dcMaxEnergyCtrl2,
      // dcMaxTempCtrl1, dcMaxTempCtrl2, dcMinTempCtrl1, dcMinTempCtrl2,
      otaURLCtrl,
      diagnosticURLCtrl,
    ]) {
      c.dispose();
    }
    // Dispose PM controllers
    for (int i = 0; i < 8; i++) {
      pmAddressCtrl[i].dispose();
      pmMaxVoltCtrl[i].dispose();
      pmMaxCurrCtrl[i].dispose();
      pmMinVoltCtrl[i].dispose();
      pmMinCurrCtrl[i].dispose();
      pmMaxPowerCtrl[i].dispose();
      pmMinPowerCtrl[i].dispose();
      pmMaxTempCtrl[i].dispose();
      pmMinTempCtrl[i].dispose();
    }
    BleService.instance.disconnect(widget.deviceId);
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────
  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 150));

    _updateDirtyFlags();

    if (!_configDirty &&
        !_meterDirty &&
        !_powerModuleDirty &&
        !_connectorDirty) {
      if (mounted) _snack("No changes to save.", ok: true);
      return;
    }

    setState(() => _saving = true);
    bool anyFailed = false;

    try {
      // ----------------------------------------------------
      // CONFIG
      // ----------------------------------------------------
      if (_configDirty) {
        final configJson = {
          ..._buildChargerMap(),
          ..._buildNetworkMap(),
          ..._buildHardwareMap(),
          ..._buildOtaMap(),
        };
        await BleService.instance
            .writeTabJson(widget.deviceId, configJson, Selection.updateConfig);
        await Future.delayed(const Duration(milliseconds: 500));

        final readback = await BleService.instance
            .readJsonForSelection(widget.deviceId, Selection.requestConfig);

        // defaultConfig is a one-shot "load factory defaults" trigger —
        // the charger clears it back to false after processing, so it
        // will never echo back true. Exclude it from verification.
        final verifyTarget = Map<String, dynamic>.from(configJson)
          ..remove("defaultConfig");

        final ok =
            readback.isNotEmpty && _verifyContains(readback, verifyTarget);

        if (ok) {
          _originalConfig = Map<String, dynamic>.from(_currentConfigSnapshot());
          _configDirty = false;
        } else {
          anyFailed = true;
          if (mounted) {
            _snack(
                "Charger did not confirm the configuration update — please try Save again.",
                ok: false);
          }
        }
      }

      // ----------------------------------------------------
      // CONNECTOR
      // ----------------------------------------------------
      if (_connectorDirty) {
        final connectorJson = _buildConnectorMap();
        await BleService.instance.writeTabJson(
            widget.deviceId, connectorJson, Selection.updateConnectorConfig);
        await Future.delayed(const Duration(milliseconds: 500));

        final readback = await BleService.instance.readJsonForSelection(
            widget.deviceId, Selection.requestConnectorConfig);
        debugPrint("========== CONNECTOR SENT ==========");
        debugPrint(const JsonEncoder.withIndent('  ').convert(connectorJson));

        debugPrint("========== CONNECTOR READBACK ==========");
        debugPrint(const JsonEncoder.withIndent('  ').convert(readback));
        final ok =
            readback.isNotEmpty && _verifyContains(readback, connectorJson);

        if (ok) {
          _originalConnector = Map<String, dynamic>.from(connectorJson);
          _connectorDirty = false;
        } else {
          anyFailed = true;
          if (mounted) {
            _snack(
                "Charger did not confirm the connector update — please try Save again.",
                ok: false);
          }
        }
      }

      // ----------------------------------------------------
      // METERS
      // ----------------------------------------------------
      if (_meterDirty) {
        final meterJson = _buildMeterMap();
        debugPrint("📝 SENDING METER JSON: ${jsonEncode(meterJson)}");
        await BleService.instance.writeTabJson(
            widget.deviceId, meterJson, Selection.updateMeterConfig);
        await Future.delayed(const Duration(milliseconds: 800));

        final readback = await BleService.instance.readJsonForSelection(
            widget.deviceId, Selection.requestMeterConfig);
        debugPrint("========== SENT ==========");
        debugPrint(const JsonEncoder.withIndent('  ').convert(meterJson));

        debugPrint("========== READBACK ==========");
        debugPrint(const JsonEncoder.withIndent('  ').convert(readback));
        final ok = readback.isNotEmpty && _verifyContains(readback, meterJson);

        if (ok) {
          _originalMeter = Map<String, dynamic>.from(_currentMeterSnapshot());
          _meterDirty = false;
        } else {
          anyFailed = true;
          if (mounted) {
            _snack(
                "Charger did not confirm the meter update — please try Save again.",
                ok: false);
          }
        }
      }

      // ----------------------------------------------------
      // POWER MODULES
      // ----------------------------------------------------
      if (_powerModuleDirty) {
        final pmJson = _buildPowerModuleMap();
        await BleService.instance
            .writeTabJson(widget.deviceId, pmJson, Selection.updatePowerModule);
        await Future.delayed(const Duration(milliseconds: 500));

        final readback = await BleService.instance.readJsonForSelection(
            widget.deviceId, Selection.requestPowerModuleConfig);
        debugPrint("========== POWER MODULE SENT ==========");
        debugPrint(const JsonEncoder.withIndent('  ').convert(pmJson));

        debugPrint("========== POWER MODULE READBACK ==========");
        debugPrint(const JsonEncoder.withIndent('  ').convert(readback));
        final ok = readback.isNotEmpty && _verifyContains(readback, pmJson);

        if (ok) {
          _originalPowerModule =
              Map<String, dynamic>.from(_currentPowerModuleSnapshot());
          _powerModuleDirty = false;
        } else {
          anyFailed = true;
          if (mounted) {
            _snack(
                "Charger did not confirm the power module update — please try Save again.",
                ok: false);
          }
        }
      }

      // ----------------------------------------------------
      // LOCAL SAVE + FINAL MESSAGE — only if everything verified
      // ----------------------------------------------------
      if (!anyFailed) {
        final allData = {
          ..._currentConfigSnapshot(),
          ..._currentMeterSnapshot(),
          ..._currentPowerModuleSnapshot(),
          ..._buildConnectorMap(),
        };
        await _saveLocally(allData);
        if (mounted) _snack("Configuration Saved", ok: true);
      }
    } catch (e) {
      debugPrint(e.toString());
      if (mounted) _snack("Update failed — please retry", ok: false);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _snack(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _disconnect() async {
    final hasUnsaved = _configDirty || _meterDirty || _powerModuleDirty;
    final ok = await _confirm(
        "Disconnect",
        hasUnsaved
            ? "You have unsaved changes. Disconnect anyway and return to scan screen?"
            : "Disconnect from charger and return to scan screen?");
    if (!ok) return;
    setState(() => _disconnecting = true);
    await Future.delayed(const Duration(milliseconds: 300));
    BleService.instance.disconnect(widget.deviceId);
    if (mounted) Navigator.pop(context);
  }

  Future<bool?> _showSaveDiscardDialog() async {
    // Returns true = Save, false = Discard, null = Cancel (stay in edit mode)
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Unsaved Changes",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _textPrimary)),
        content: Text("You have unsaved changes. Save before leaving?",
            style: TextStyle(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Discard", style: TextStyle(color: AppColors.error))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text("Save", style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }

  Future<void> _returnToInfoMode() async {
    FocusScope.of(context).unfocus();
    _updateDirtyFlags();
    final hasChanges = _configDirty || _meterDirty || _powerModuleDirty;

    if (!hasChanges) {
      if (mounted) setState(() => _editMode = false);
      return;
    }

    final wantsSave = await _showSaveDiscardDialog();
    if (wantsSave == null) return; // Cancel — stay in edit mode

    if (wantsSave) {
      await _save(); // now stays in edit mode internally (see fix below)
      if (mounted) setState(() => _editMode = false);
    } else {
      _restoreOriginalValues(); // already sets _editMode = false
    }
  }

  Future<void> _factoryReset() async {
    final ok = await _confirm("Factory Reset",
        "This erases all saved config and restarts the charger.",
        destructive: true);
    if (!ok) return;
    try {
      await BleService.instance.sendCommand(widget.deviceId, "FACTORY_RESET");
      if (mounted) {
        _snack("Factory reset sent");
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("❌ $e");
    }
  }

  Future<void> _restart() async {
    final ok = await _confirm("Restart Charger", "Restart now?");
    if (!ok) return;
    try {
      await BleService.instance.sendCommand(widget.deviceId, "RESTART");
      if (mounted) {
        _snack("Restart sent");
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("❌ $e");
    }
  }

  Future<void> _startCharging() async {
    final ok =
        await _confirm("Start Charging", "Start the charging session now?");
    if (!ok) return;
    try {
      // ⚠️ Confirm exact command string with company — placeholder for now.
      await BleService.instance.sendCommand(widget.deviceId, "START_CHARGING");
      if (mounted) _snack("Start command sent");
    } catch (e) {
      debugPrint("❌ $e");
    }
  }

  Future<void> _stopCharging() async {
    final ok =
        await _confirm("Stop Charging", "Stop the charging session now?");
    if (!ok) return;
    try {
      // ⚠️ Confirm exact command string with company — placeholder for now.
      await BleService.instance.sendCommand(widget.deviceId, "STOP_CHARGING");
      if (mounted) _snack("Stop command sent");
    } catch (e) {
      debugPrint("❌ $e");
    }
  }

  Future<bool> _confirm(String title, String body,
      {bool destructive = false}) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: _surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary)),
            content: Text(body,
                style: TextStyle(fontSize: 13, color: _textSecondary)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel")),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(destructive ? "Reset" : "Confirm",
                    style: TextStyle(
                        color:
                            destructive ? AppColors.error : AppColors.primary)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ================================================================
  // UI HELPERS
  // ================================================================
  Widget _section(String title) => w.sectionHeader(title);

  Widget _row(String label, String value) => w.infoRow(label, value,
      surface: _surface,
      border: _border,
      textPrimary: _textPrimary,
      textSecondary: _textSecondary);

  Widget _boolRow(String label, bool value) => w.boolStatusChipRow(label, value,
      surface: _surface, border: _border, textSecondary: _textSecondary);

  Widget _statusRow(String label, bool value) =>
      w.boolStatusChipRow(label, value,
          surface: _surface,
          border: _border,
          textSecondary: _textSecondary,
          onLabel: "Enabled",
          offLabel: "Disabled");

  Widget _pmStatusRow(bool value) => w.boolStatusChipRow("Status", value,
      surface: _surface, border: _border, textSecondary: _textSecondary);

  Widget _dropRow(String label, String value) => w.dropRow(label, value,
      surface: _surface,
      border: _border,
      textPrimary: _textPrimary,
      textSecondary: _textSecondary);

  Widget _field(String label, TextEditingController ctrl,
          {TextInputType keyboard = TextInputType.text,
          bool obscure = false,
          bool readOnly = false,
          TextInputAction action = TextInputAction.next}) =>
      w.editableField(label, ctrl,
          isDark: _isDark,
          border: _border,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          onDirty: _markConfigChanged,
          keyboard: keyboard,
          obscure: obscure,
          readOnly: readOnly,
          action: action);

  Widget _intField(String label, int value, ValueChanged<int> onChanged,
          {bool readOnly = false}) =>
      w.intField(label, value, onChanged,
          isDark: _isDark,
          border: _border,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          readOnly: readOnly);

  Widget _fieldRaw(String label, TextEditingController ctrl,
          {TextInputType keyboard = TextInputType.text,
          bool readOnly = false,
          ValueChanged<String>? onChanged}) =>
      w.rawField(label, ctrl,
          isDark: _isDark,
          border: _border,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          keyboard: keyboard,
          readOnly: readOnly,
          onChanged: onChanged);

  Widget _dropEdit<T>(String label, T value, Map<T, String> opts,
          ValueChanged<T> onChanged) =>
      w.dropEdit<T>(label, value, opts, onChanged,
          isDark: _isDark,
          border: _border,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          surface: _surface,
          onDirty: _markConfigChanged);

  Widget _strDropEdit(String label, String value, List<String> opts,
          ValueChanged<String> onChanged) =>
      _dropEdit<String>(label, value, {for (final o in opts) o: o}, onChanged);

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      w.toggleRow(label, value, onChanged,
          editMode: _editMode,
          border: _border,
          textSecondary: _textSecondary,
          onDirty: _markConfigChanged);

  Widget _checkEdit(String label, bool value, ValueChanged<bool> onChanged) =>
      w.checkEditRow(label, value, onChanged,
          editMode: _editMode,
          textSecondary: _textSecondary,
          onDirty: _markConfigChanged);

  Widget _actionBtn(
          String label, IconData icon, Color color, VoidCallback fn) =>
      w.actionButton(label, icon, color, fn);

  Widget _miniIntField(String label, int value, ValueChanged<int> onChanged,
          {bool readOnly = false}) =>
      w.miniIntField(label, value, onChanged,
          isDark: _isDark,
          border: _border,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          surface: _surface,
          readOnly: readOnly);

  Widget _miniFloatField(String label, TextEditingController ctrl) =>
      w.miniFloatField(label, ctrl,
          border: _border,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          surface: _surface,
          onDirty: _markPowerModuleChanged);

  Widget _miniDropEdit<T>(
          String label, T value, Map<T, String> opts, ValueChanged<T> onChanged,
          {bool readOnly = false}) =>
      w.miniDropEdit<T>(label, value, opts, onChanged,
          isDark: _isDark,
          border: _border,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          surface: _surface,
          readOnly: readOnly);
  // ================================================================
  // TABS
  // ================================================================

  Widget _chargerTab() {
    if (_editMode) {
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 300),
        children: [
          _section("Device Information"),
          _checkEdit("Default Config", defaultConfig, (v) => defaultConfig = v),
          _dropEdit("Charger Type", chargerType, chargerTypes,
              (v) => chargerType = v),
          _dropEdit("Master Board Model", masterBoardModel, boardModelOptions,
              (v) => masterBoardModel = v),
          _dropEdit("Dispenser Board Model", dispenserBoardModel,
              boardModelOptions, (v) => dispenserBoardModel = v),
          _dropEdit("Display Board Model", displayBoardModel, boardModelOptions,
              (v) => displayBoardModel = v),
          _dropEdit("Relay Board Model", relayBoardModel, boardModelOptions,
              (v) => relayBoardModel = v),
          _field("Serial Number", serialCtrl),
          _field("Charger Name", chargerNameCtrl),
          _field("Charge Point Vendor", vendorCtrl),
          _field("Charge Point Model", modelCtrl),
          _field("Commissioned By", commissionedByCtrl, readOnly: true),
          _field("Commissioned Date", commissionedDateCtrl, readOnly: true),
          _field("Firmware Version", firmwareVersionCtrl, readOnly: true),
          _field("Slave Firmware Version", slaveFirmwareVersionCtrl,
              readOnly: true),
          _section("Charging Configuration"),
          _checkEdit("Smart Charging", smartCharging, (v) => smartCharging = v),
          _checkEdit("Restore Session From Fault", restoreFromFault,
              (v) => restoreFromFault = v),
          _field("Restore Fault Time (sec)", restoreTimeCtrl,
              keyboard: TextInputType.number, action: TextInputAction.done),
        ],
      );
    }
    return ListView(children: [
      _section("Device Information"),
      _boolRow("Default Config", defaultConfig),
      _row("Charger Type", chargerTypes[chargerType] ?? ""),
      _row("Master Board Model", boardModelOptions[masterBoardModel] ?? ""),
      _row("Dispenser Board Model",
          boardModelOptions[dispenserBoardModel] ?? ""),
      _row("Display Board Model", boardModelOptions[displayBoardModel] ?? ""),
      _row("Relay Board Model", boardModelOptions[relayBoardModel] ?? ""),
      _row("Serial Number", serialCtrl.text),
      _row("Charger Name", chargerNameCtrl.text),
      _row("Charge Point Vendor", vendorCtrl.text),
      _row("Charge Point Model", modelCtrl.text),
      _row("Commissioned By", commissionedByCtrl.text),
      _row("Commissioned Date", commissionedDateCtrl.text),
      _row("Firmware Version", firmwareVersionCtrl.text),
      _row("Slave Firmware Version", slaveFirmwareVersionCtrl.text),
      _section("Charging Configuration"),
      _statusRow("Smart Charging", smartCharging),
      _statusRow("Restore Session From Fault", restoreFromFault),
      _row("Restore Fault Time (sec)", restoreTimeCtrl.text),
    ]);
  }

  Widget _networkTab() {
    if (_editMode) {
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 300),
        children: [
          _section("Network Configuration"),
          _dropEdit("Network Mode", networkMode, networkModes,
              (v) => networkMode = v),
          _field("WebSocket URL", webSocketURLCtrl),
          _section("WiFi Settings"),
          _toggle("WiFi Enable", wifiEnable, (v) => wifiEnable = v),
          if (wifiEnable) ...[
            _field("WiFi Priority", wifiPriorityCtrl,
                keyboard: TextInputType.number),
            _field("WiFi SSID", wifiSSIDCtrl),
            _field("WiFi Password", wifiPassCtrl, obscure: true),
          ],
          _section("Ethernet Settings"),
          _toggle("Ethernet Enable", ethernetEnable, (v) => ethernetEnable = v),
          if (ethernetEnable) ...[
            _field("Ethernet Priority", ethernetPriorityCtrl,
                keyboard: TextInputType.number),
            _dropEdit("Ethernet Config", ethernetConfig, ethernetTypes,
                (v) => ethernetConfig = v),
            _field("IP Address", ipAddressCtrl),
            _field("Gateway", gatewayCtrl),
            _field("DNS Address", dnsCtrl),
            _field("Subnet Mask", subnetCtrl),
            _field("MAC Address", macAddressCtrl),
          ],
          _section("GSM Settings"),
          _toggle("GSM Enable", gsmEnable, (v) => gsmEnable = v),
          if (gsmEnable) ...[
            _field("GSM Priority", gsmPriorityCtrl,
                keyboard: TextInputType.number),
            _field("GSM APN", gsmAPNCtrl),
            _field("SIM IMEI Number", simIMEICtrl, readOnly: true),
            _field("SIM IMSI Number", simIMSICtrl,
                readOnly: true, action: TextInputAction.done),
          ],
        ],
      );
    }
    return ListView(children: [
      _section("Network Configuration"),
      _dropRow("Network Mode", networkModes[networkMode] ?? ""),
      _row("WebSocket URL", webSocketURLCtrl.text),
      _section("WiFi Settings"),
      _statusRow("WiFi Enable", wifiEnable),
      if (wifiEnable) ...[
        _row("WiFi Priority", wifiPriorityCtrl.text),
        _row("WiFi SSID", wifiSSIDCtrl.text),
        _row("WiFi Password", wifiPassCtrl.text.isEmpty ? "--" : "••••••••"),
      ],
      _section("Ethernet Settings"),
      _statusRow("Ethernet Enable", ethernetEnable),
      if (ethernetEnable) ...[
        _row("Ethernet Priority", ethernetPriorityCtrl.text),
        _dropRow("Ethernet Config", ethernetTypes[ethernetConfig] ?? ""),
        _row("IP Address", ipAddressCtrl.text),
        _row("Gateway", gatewayCtrl.text),
        _row("DNS Address", dnsCtrl.text),
        _row("Subnet Mask", subnetCtrl.text),
        _row("MAC Address", macAddressCtrl.text),
      ],
      _section("GSM Settings"),
      _statusRow("GSM Enable", gsmEnable),
      if (gsmEnable) ...[
        _row("GSM Priority", gsmPriorityCtrl.text),
        _row("GSM APN", gsmAPNCtrl.text),
        _row("SIM IMEI Number", simIMEICtrl.text),
        _row("SIM IMSI Number", simIMSICtrl.text),
      ],
    ]);
  }

  Widget _hardwareTab() {
    if (_editMode) {
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 300),
        children: [
          _section("Hardware Configuration"),
          _field(
            "Number of Displays",
            displaysCtrl,
            keyboard: TextInputType.number,
          ),
          _section("Temperature"),
          _field(
            "Over Temperature Threshold",
            overTempCtrl,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _section("AC Protection"),
          _field(
            "AC Under Voltage",
            acUnderVoltCtrl,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            "AC Over Voltage",
            acOverVoltCtrl,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            "AC Over Current",
            acOverCurrCtrl,
            keyboard: TextInputType.number,
          ),
          _section("Connector Configuration"),
          _field(
            "Number of Connectors",
            connectorsCtrl,
            keyboard: TextInputType.number,
          ),
          _section("Connector 1"),
          _field(
            "Max Voltage",
            dcOverVoltCtrl1,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            "Min Voltage",
            dcUnderVoltCtrl1,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            "Max Current",
            dcOverCurrCtrl1,
            keyboard: TextInputType.number,
          ),
          _field(
            "Min Current",
            dcMinCurrCtrl1,
            keyboard: TextInputType.number,
          ),
          _field(
            "Max Power",
            dcMaxPowerCtrl1,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            "Max Energy",
            dcMaxEnergyCtrl1,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          // Commented out for now — uncomment when Max/Min Temperature is needed.
          // _field(
          //   "Max Temperature",
          //   dcMaxTempCtrl1,
          //   keyboard: const TextInputType.numberWithOptions(decimal: true),
          // ),
          // _field(
          //   "Min Temperature",
          //   dcMinTempCtrl1,
          //   keyboard: const TextInputType.numberWithOptions(decimal: true),
          // ),
          if (_connectorCount >= 2) ...[
            _section("Connector 2"),
            _field(
              "Max Voltage",
              dcOverVoltCtrl2,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            _field(
              "Min Voltage",
              dcUnderVoltCtrl2,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            _field(
              "Max Current",
              dcOverCurrCtrl2,
              keyboard: TextInputType.number,
            ),
            _field(
              "Min Current",
              dcMinCurrCtrl2,
              keyboard: TextInputType.number,
            ),
            _field(
              "Max Power",
              dcMaxPowerCtrl2,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            _field(
              "Max Energy",
              dcMaxEnergyCtrl2,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            // Commented out for now — uncomment when Max/Min Temperature is needed.
            // _field(
            //   "Max Temperature",
            //   dcMaxTempCtrl2,
            //   keyboard: const TextInputType.numberWithOptions(decimal: true),
            // ),
            // _field(
            //   "Min Temperature",
            //   dcMinTempCtrl2,
            //   keyboard: const TextInputType.numberWithOptions(decimal: true),
            // ),
          ],
          _section("Power Modules"),
          _field("Number of Power Modules", powerModulesCtrl,
              keyboard: TextInputType.number),
          _field("Number of Mergers", mergersCtrl,
              keyboard: TextInputType.number, action: TextInputAction.done),
          ...List.generate(8, (i) {
            final pmNum = i + 1;
            final numPM = int.tryParse(powerModulesCtrl.text.trim()) ?? 0;
            if (i >= numPM) return const SizedBox.shrink();

            if (!_editMode) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text("PM$pmNum",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ),
                    _pmStatusRow(pmAvailable[i]),
                    if (pmAvailable[i]) ...[
                      _row("Module Address", pmAddressCtrl[i].text),
                      _row("Max Voltage", pmMaxVoltCtrl[i].text),
                      _row("Max Current", pmMaxCurrCtrl[i].text),
                      _row("Min Voltage", pmMinVoltCtrl[i].text),
                      _row("Min Current", pmMinCurrCtrl[i].text),
                      _row("Max Power", pmMaxPowerCtrl[i].text),
                      _row("Min Power", pmMinPowerCtrl[i].text),
                      _row("Max Temperature", pmMaxTempCtrl[i].text),
                      _row("Min Temperature", pmMinTempCtrl[i].text),
                    ],
                  ]);
            }

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text("PM$pmNum",
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                      const Spacer(),
                      Text(pmAvailable[i] ? "Available" : "Unavailable",
                          style:
                              TextStyle(fontSize: 12, color: _textSecondary)),
                      const SizedBox(width: 8),
                      IgnorePointer(
                        ignoring: i != 0,
                        child: Switch(
                          value: pmAvailable[i],
                          onChanged: (v) {
                            if (i != 0) return;

                            setState(() {
                              pmAvailable[i] = v;
                            });

                            _markPowerModuleChanged();
                          },
                          activeColor: AppColors.primary,
                        ),
                      ),
                    ]),
                    if (pmAvailable[i]) ...[
                      _miniIntField(
                          "Mod.Addr", int.tryParse(pmAddressCtrl[i].text) ?? 0,
                          (v) {
                        pmAddressCtrl[i].text = v.toString();
                        _markPowerModuleChanged();
                      }),
                      _miniFloatField("MaxVolt", pmMaxVoltCtrl[i]),
                      _miniFloatField("MaxCurr", pmMaxCurrCtrl[i]),
                      _miniFloatField("MinVolt", pmMinVoltCtrl[i]),
                      _miniFloatField("MinCurr", pmMinCurrCtrl[i]),
                      _miniFloatField("MaxPower", pmMaxPowerCtrl[i]),
                      _miniFloatField("MinPower", pmMinPowerCtrl[i]),
                      _miniFloatField("MaxTemp", pmMaxTempCtrl[i]),
                      _miniFloatField("MinTemp", pmMinTempCtrl[i]),
                    ],
                  ]),
            );
          }),
          _section("Actions"),
          _actionBtn(
            "Start Charging",
            Icons.play_arrow_rounded,
            AppColors.success,
            _startCharging,
          ),
          _actionBtn(
            "Stop Charging",
            Icons.stop_rounded,
            AppColors.warning,
            _stopCharging,
          ),
        ],
      );
    }
    return ListView(children: [
      _section("Hardware Configuration"),
      _row("Number of Displays", displaysCtrl.text),
      _section("Temperature"),
      _row("Over Temperature Threshold", overTempCtrl.text),
      _section("AC Protection"),
      _row("AC Under Voltage", acUnderVoltCtrl.text),
      _row("AC Over Voltage", acOverVoltCtrl.text),
      _row("AC Over Current", acOverCurrCtrl.text),
      _section("Connector Configuration"),
      _row("Number of Connectors", connectorsCtrl.text),
      _section("Connector 1"),
      _row("Max Voltage", dcOverVoltCtrl1.text),
      _row("Min Voltage", dcUnderVoltCtrl1.text),
      _row("Max Current", dcOverCurrCtrl1.text),
      _row("Min Current", dcMinCurrCtrl1.text),
      _row("Max Power", dcMaxPowerCtrl1.text),
      _row("Max Energy", dcMaxEnergyCtrl1.text),
      // Commented out for now — uncomment when Max/Min Temperature is needed.
      // _row("Max Temperature", dcMaxTempCtrl1.text),
      // _row("Min Temperature", dcMinTempCtrl1.text),
      if (_connectorCount >= 2) ...[
        _section("Connector 2"),
        _row("Max Voltage", dcOverVoltCtrl2.text),
        _row("Min Voltage", dcUnderVoltCtrl2.text),
        _row("Max Current", dcOverCurrCtrl2.text),
        _row("Min Current", dcMinCurrCtrl2.text),
        _row("Max Power", dcMaxPowerCtrl2.text),
        _row("Max Energy", dcMaxEnergyCtrl2.text),
        // Commented out for now — uncomment when Max/Min Temperature is needed.
        // _row("Max Temperature", dcMaxTempCtrl2.text),
        // _row("Min Temperature", dcMinTempCtrl2.text),
      ],
      _section("Power Modules"),
      _row("Number of Power Modules", powerModulesCtrl.text),
      _row("Number of Mergers", mergersCtrl.text),
      ...List.generate(
        int.tryParse(powerModulesCtrl.text.trim()) ?? 0,
        (i) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section("PM${i + 1}"),
            _statusRow("Status", pmAvailable[i]),
            if (pmAvailable[i]) ...[
              _row("Module Address", pmAddressCtrl[i].text),
              _row("Max Voltage", pmMaxVoltCtrl[i].text),
              _row("Max Current", pmMaxCurrCtrl[i].text),
              _row("Min Voltage", pmMinVoltCtrl[i].text),
              _row("Min Current", pmMinCurrCtrl[i].text),
              _row("Max Power", pmMaxPowerCtrl[i].text),
              _row("Min Power", pmMinPowerCtrl[i].text),
              _row("Max Temperature", pmMaxTempCtrl[i].text),
              _row("Min Temperature", pmMinTempCtrl[i].text),
            ],
          ],
        ),
      ),
      _section("Actions"),
      _actionBtn(
        "Start Charging",
        Icons.play_arrow_rounded,
        AppColors.success,
        _startCharging,
      ),
      _actionBtn(
        "Stop Charging",
        Icons.stop_rounded,
        AppColors.warning,
        _stopCharging,
      ),
    ]);
  }

  // ── Meter channel widget ──────────────────────────────────────
  Widget _meterChannel(String title, MeterData data, {bool readOnly = false}) {
    final bool ro = readOnly || !_editMode;

    if (!_editMode) {
      return Padding(
        padding: const EdgeInsets.only(
          top: 8,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            _row("Module Addr", data.moduleAddress.toString()),
            _row("Reg. Count", data.registerCount.toString()),
            _row("Data Type", dataTypes[data.dataType] ?? ""),
            _row("Word Order", wordOrders[data.wordOrder] ?? ""),
            _row("Scale Exp", data.scaleExponent.toString()),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(left: 8, right: 0, top: 4, bottom: 8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              _isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          const SizedBox(height: 8),
          _miniIntField("M.Addr", data.moduleAddress, (v) {
            setState(() => data.moduleAddress = v);
            _markMeterChanged();
          }, readOnly: ro),
          _miniIntField("Reg.Count", data.registerCount, (v) {
            setState(() => data.registerCount = v);
            _markMeterChanged();
          }, readOnly: ro),
          _miniDropEdit<int>("DataType", data.dataType, dataTypes, (v) {
            setState(() => data.dataType = v);
            _markMeterChanged();
          }, readOnly: ro),
          _miniDropEdit<int>("W.Order", data.wordOrder, wordOrders, (v) {
            setState(() => data.wordOrder = v);
            _markMeterChanged();
          }, readOnly: ro),
          _miniIntField("Exp", data.scaleExponent, (v) {
            setState(() => data.scaleExponent = v);
            _markMeterChanged();
          }, readOnly: ro),
        ]),
      ),
    );
  }

  Widget _metersTab() {
    final connectors = _connectorCount;
    final isUserAC = acMeterType == 'User Defined';
    final isUserDC1 = dcMeter1Type == 'User Defined';
    final isUserDC2 = dcMeter2Type == 'User Defined';

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 300),
      children: [
        // ── AC Meter ────────────────────────────────────────────
        _section("AC Meter"),
        if (_editMode)
          _strDropEdit("Meter Type", acMeterType, acMeterOptions, (v) {
            setState(() {
              acMeterType = v;
              _applyAcPreset(v);
            });

            _markMeterChanged();
          })
        else
          _dropRow("Meter Type", acMeterType),
        if (_editMode)
          _intField("Offset Address", acOffsetAddr, (v) {
            acOffsetAddr = v;
            _markMeterChanged();
          }, readOnly: !isUserAC)
        else
          _row("Offset Address", acOffsetAddr.toString()),

        _meterChannel("VoltageV1N", acV1N, readOnly: !isUserAC),
        _meterChannel("VoltageV2N", acV2N, readOnly: !isUserAC),
        _meterChannel("VoltageV3N", acV3N, readOnly: !isUserAC),
        _meterChannel("VoltageV12", acV12, readOnly: !isUserAC),
        _meterChannel("VoltageV23", acV23, readOnly: !isUserAC),
        _meterChannel("VoltageV31", acV31, readOnly: !isUserAC),
        _meterChannel("CurrentI1", acI1, readOnly: !isUserAC),
        _meterChannel("CurrentI2", acI2, readOnly: !isUserAC),
        _meterChannel("CurrentI3", acI3, readOnly: !isUserAC),
        _meterChannel("TotalKW", acTotalKW, readOnly: !isUserAC),
        _meterChannel("AveragePF", acAvgPF, readOnly: !isUserAC),
        _meterChannel("TotalKWh", acTotalKWh, readOnly: !isUserAC),
        _meterChannel("CumulativeKWh", acCumKWh, readOnly: !isUserAC),
        _meterChannel("ResetCumulativeKWh", acResetCumKWh, readOnly: !isUserAC),

        // ── DC Meter 1 ──────────────────────────────────────────
        if (connectors >= 1) ...[
          _section("DC Meter 1"),
          if (_editMode)
            _strDropEdit("Meter Type", dcMeter1Type, dcMeterOptions, (v) {
              setState(() {
                dcMeter1Type = v;
                _applyDcPreset(v, dc1Voltage, dc1Current, dc1Power, dc1Energy);
              });

              _markMeterChanged();
            })
          else
            _dropRow("Meter Type", dcMeter1Type),
          if (_editMode)
            _intField("Offset Address", dc1OffsetAddr, (v) {
              dc1OffsetAddr = v;
              _markMeterChanged();
            }, readOnly: !isUserDC1)
          else
            _row("Offset Address", dc1OffsetAddr.toString()),
          _row("Assigned Gun", "1"),
          _meterChannel("Voltage", dc1Voltage, readOnly: !isUserDC1),
          _meterChannel("Current", dc1Current, readOnly: !isUserDC1),
          _meterChannel("Power", dc1Power, readOnly: !isUserDC1),
          _meterChannel("Energy", dc1Energy, readOnly: !isUserDC1),
        ],

        // ── DC Meter 2 ──────────────────────────────────────────
        if (connectors >= 2) ...[
          _section("DC Meter 2"),
          if (_editMode)
            _strDropEdit("Meter Type", dcMeter2Type, dcMeterOptions, (v) {
              setState(() {
                dcMeter2Type = v;
                _applyDcPreset(v, dc2Voltage, dc2Current, dc2Power, dc2Energy);
              });

              _markMeterChanged();
            })
          else
            _dropRow("Meter Type", dcMeter2Type),
          if (_editMode)
            _intField("Offset Address", dc2OffsetAddr, (v) {
              dc2OffsetAddr = v;
              _markMeterChanged();
            }, readOnly: !isUserDC2)
          else
            _row("Offset Address", dc2OffsetAddr.toString()),
          _row("Assigned Gun", "2"),
          _meterChannel("Voltage", dc2Voltage, readOnly: !isUserDC2),
          _meterChannel("Current", dc2Current, readOnly: !isUserDC2),
          _meterChannel("Power", dc2Power, readOnly: !isUserDC2),
          _meterChannel("Energy", dc2Energy, readOnly: !isUserDC2),
        ],

        if (connectors == 0)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              "Set Number of Connectors in Hardware tab\nto see DC Meters",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _otaTab() {
    if (_editMode) {
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 300),
        children: [
          _section("OTA Configuration"),
          _checkEdit(
              "OTA URL From CMS", otaUrlFromCMS, (v) => otaUrlFromCMS = v),
          _field("OTA URL", otaURLCtrl),
          _section("Diagnostic Configuration"),
          _checkEdit("Diagnostic Server", diagnosticServer,
              (v) => diagnosticServer = v),
          _field("Diagnostic Server URL", diagnosticURLCtrl,
              action: TextInputAction.done),
        ],
      );
    }
    return ListView(children: [
      _section("OTA Configuration"),
      _statusRow("OTA URL From CMS", otaUrlFromCMS),
      _row("OTA URL", otaURLCtrl.text),
      _section("Diagnostic Configuration"),
      _statusRow("Diagnostic Server", diagnosticServer),
      _row("Diagnostic Server URL", diagnosticURLCtrl.text),
    ]);
  }

  // ── Merger wiring — fixed hardware map, per company's firmware code.
  // mergerMap[PM][Connector] -> merger index, or null = Direct Connected.
  // ⚠️ Only Connector 1 and 2 are defined (from company's C++ snippet).
  // Add more entries here once wiring data for additional connectors is given.
  static const Map<int, Map<int, int?>> _mergerWiring = {
    1: {
      1: null,
      2: null,
      3: 1,
      4: 1,
      5: 2,
      6: 2,
      7: 3,
      8: 3,
    },
    2: {
      1: 1,
      2: 1,
      3: 2,
      4: 2,
      5: 3,
      6: 3,
      7: null,
      8: null,
    },
  };

  Widget _muxTab() {
    final connectors = _connectorCount;
    final numPM = int.tryParse(powerModulesCtrl.text.trim()) ?? 8;

    if (connectors == 0) {
      return Center(
        child: Text(
          "Set Number of Connectors in Hardware tab\nto see Mux mapping",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: _textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _row("Power Modules", "8"),
        _row("Connectors", "2"),
        _row("Mergers", "3"),
        for (int c = 1; c <= connectors; c++) ...[
          _section("Connector $c"),
          if (!_mergerWiring.containsKey(c))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                "No wiring data available for Connector $c yet.",
                style: TextStyle(fontSize: 13, color: _textSecondary),
              ),
            )
          else
            for (int pm = 1; pm <= numPM; pm++)
              _row(
                "PM$pm",
                _mergerWiring[c]?[pm] == null
                    ? "Direct Connected"
                    : "Merger ${_mergerWiring[c]![pm]}",
              ),
        ],
      ],
    );
  }

  Widget _comingSoon(String name) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.construction_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text("$name — Coming Soon",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          const SizedBox(height: 8),
          Text("This section is under development",
              style: TextStyle(fontSize: 13, color: _textSecondary)),
        ]),
      );

  // ================================================================
  // BUILD
  // ================================================================
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (_editMode) {
          await _returnToInfoMode();
          return;
        }
        FocusScope.of(context).unfocus();
        final ok = await _confirm(
            "Disconnect", "Disconnect from charger and return to scan screen?");
        if (!ok) return;
        BleService.instance.disconnect(widget.deviceId);
        if (mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF08141D),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          iconTheme: const IconThemeData(
            color: Colors.white,
          ),
          backgroundColor: const Color(0xFF08141D),
          toolbarHeight: 78,
          centerTitle: false,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: _editMode
              ? IconButton(
                  splashRadius: 22,
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                  onPressed: _returnToInfoMode,
                )
              : null,
          // FIX: Use shorter title so it doesn't get truncated
          titleSpacing: 0,

          title: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "EVSE CONFIG",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Connected",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            // Theme
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
            ),
            // Edit / Save
            if (!_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: IconButton(
                  icon: Icon(
                    _editMode ? Icons.save_rounded : Icons.edit_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: _saving
                      ? null
                      : () async {
                          if (_editMode) {
                            FocusScope.of(context).unfocus();
                            await Future.delayed(
                              const Duration(milliseconds: 200),
                            );
                            await _save();
                          } else {
                            setState(() => _editMode = true);
                          }
                        },
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: _textSecondary,
                ),
                color: _surface,
                onSelected: (value) {
                  switch (value) {
                    case 'cards':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CardManagementScreen(
                            deviceId: widget.deviceId,
                          ),
                        ),
                      );
                      break;
                    case 'reset':
                      _resetToSaved();
                      break;

                    case 'disconnect':
                      _disconnect();
                      break;

                    case 'restart':
                      _restart();
                      break;

                    case 'factory':
                      _factoryReset();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'cards',
                    child: Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 18),
                        SizedBox(width: 10),
                        Text("Card Management"),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Reset Configuration'),
                  ),
                  const PopupMenuItem(
                    value: 'disconnect',
                    child: Text('Disconnect'),
                  ),
                  const PopupMenuItem(
                    value: 'restart',
                    child: Text('Restart Charger'),
                  ),
                  const PopupMenuItem(
                    value: 'factory',
                    child: Text('Factory Reset'),
                  ),
                ],
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            indicatorSize: TabBarIndicatorSize.tab,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(
                  icon: Icon(Icons.ev_station_rounded, size: 16),
                  text: "Charger"),
              Tab(icon: Icon(Icons.wifi_rounded, size: 16), text: "Network"),
              Tab(
                  icon: Icon(Icons.settings_rounded, size: 16),
                  text: "Hardware"),
              Tab(icon: Icon(Icons.speed_rounded, size: 16), text: "Meters"),
              Tab(
                  icon: Icon(Icons.system_update_rounded, size: 16),
                  text: "OTA"),
              Tab(icon: Icon(Icons.cloud_rounded, size: 16), text: "OCPP"),
              Tab(icon: Icon(Icons.device_hub_rounded, size: 16), text: "Mux"),
            ],
          ),
        ),
        body: Stack(children: [
          if (_loading)
            Center(
              child: Container(
                width: 260,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      "Reading Configuration",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please wait...",
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.translucent,
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _chargerTab(),
                  _networkTab(),
                  _hardwareTab(),
                  _metersTab(),
                  _otaTab(),
                  _comingSoon("OCPP"),
                  _muxTab(),
                ],
              ),
            ),
          if (_saving)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                  child: Container(
                width: 260,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      "Saving Configuration",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Writing settings to charger...",
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              )),
            ),
          if (_disconnecting)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                  child: Container(
                width: 260,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 42,
                      height: 42,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      "Disconnecting",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Closing BLE connection...",
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              )),
            ),
        ]),
      ),
    );
  }
}
