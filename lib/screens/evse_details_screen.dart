import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ble/ble_service_selector.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import '../ble/ble_protocol.dart';

// ── Meter preset models ──────────────────────────────────────────
class ChannelPreset {
  final int address;
  final int registerCount;
  final int dataType;
  final int wordOrder;
  final int scaleExponent;
  const ChannelPreset({
    this.address = 0,
    this.registerCount = 1,
    this.dataType = 0,
    this.wordOrder = 0,
    this.scaleExponent = 0,
  });
}

// ⚠️ FAKE / PLACEHOLDER VALUES — NOT real hardware register maps.
// Generated with a simple deterministic pattern so each meter model produces
// distinct, non-zero values for testing purposes only. Replace each meter's
// entry with real datasheet values once available — no other code needs to
// change; just swap the generator call for a literal map per meter, e.g.:
//   'Selec EM4M': {
//     'VoltageV1N': ChannelPreset(address: 0x0131, registerCount: 1,
//         dataType: 0, wordOrder: 0, scaleExponent: -1),
//     ... (14 entries for AC, 4 for DC)
//   },

const List<String> _acChannelNames = [
  'VoltageV1N',
  'VoltageV2N',
  'VoltageV3N',
  'VoltageV12',
  'VoltageV23',
  'VoltageV31',
  'CurrentI1',
  'CurrentI2',
  'CurrentI3',
  'TotalKW',
  'AveragePF',
  'TotalKWh',
  'CumulativeKWh',
  'ResetCumulativeKWh',
];
const List<String> _dcChannelNames = ['Voltage', 'Current', 'Power', 'Energy'];

Map<String, ChannelPreset> _fakeChannelSet(
    List<String> channelNames, int meterIndex) {
  const dataTypeCycle = [
    0,
    1,
    2,
    3,
    5
  ]; // UINT16, INT16, UINT32, INT32, FLOAT32
  const wordOrderCycle = [0, 2, 4]; // AB, ABCD, CDAB
  final result = <String, ChannelPreset>{};
  for (int i = 0; i < channelNames.length; i++) {
    result[channelNames[i]] = ChannelPreset(
      address: 0x0100 + (meterIndex * 0x0050) + (i * 2),
      registerCount: (i % 3 == 0) ? 1 : 2,
      dataType: dataTypeCycle[i % dataTypeCycle.length],
      wordOrder: wordOrderCycle[i % wordOrderCycle.length],
      scaleExponent: -(i % 4),
    );
  }
  return result;
}

final List<String> _acMeterModelOrder = [
  'Selec EM4M',
  'Selec MFM384',
  'Elmeasure M30',
  'Elmeasure LG2XX0D',
  'Rishabh 3430',
  'Havells SDM630',
];

final List<String> _dcMeterModelOrder = [
  'Rishabh EM6000',
  'Rishabh EM6001',
  'Selec EM2M',
  'Elmeasure EDC2150D',
  'Elecnova PD195Z-CD31F',
  'Elecnova PD195Z-CD32F',
  'Pilot DCMSPM90',
  'IVY DC EM619002',
  'Yada DCM3366D-J2',
];

final Map<String, Map<String, ChannelPreset>> acMeterChannelPresets = {
  for (int i = 0; i < _acMeterModelOrder.length; i++)
    _acMeterModelOrder[i]: _fakeChannelSet(_acChannelNames, i),
};

final Map<String, Map<String, ChannelPreset>> dcMeterChannelPresets = {
  for (int i = 0; i < _dcMeterModelOrder.length; i++)
    _dcMeterModelOrder[i]: _fakeChannelSet(_dcChannelNames, i),
};

const Map<int, String> _meterDataTypeTokens = {
  0: "UINT16",
  1: "INT16",
  2: "UINT32",
  3: "INT32",
  4: "UINT64",
  5: "FLOAT32",
  6: "BCD16",
  7: "BCD32",
};
const Map<int, String> _meterWordOrderTokens = {
  0: "AB",
  1: "BA",
  2: "ABCD",
  3: "BADC",
  4: "CDAB",
  5: "DCBA",
};

int _parseHexAddress(dynamic v) {
  if (v == null) return 0;
  final s = v.toString();
  return s.toLowerCase().startsWith('0x')
      ? int.tryParse(s.substring(2), radix: 16) ?? 0
      : int.tryParse(s) ?? 0;
}

int _reverseLookup(Map<int, String> map, dynamic val, int fallback) {
  if (val == null) return fallback;
  final str = val.toString();
  for (final e in map.entries) {
    if (e.value == str) return e.key;
  }
  return fallback;
}

class MeterData {
  int param; // EnergyMeterParam: 1=Voltage,2=Current,3=Power,4=Energy
  int moduleAddress;
  int registerCount;
  int dataType; // EnergyMeterDataType
  int wordOrder; // EnergyMeterWordOrder
  int scaleExponent;
  int offsetAddress;

  MeterData({
    this.param = 1,
    this.moduleAddress = 0,
    this.registerCount = 1,
    this.dataType = 0,
    this.wordOrder = 0,
    this.scaleExponent = 0,
    this.offsetAddress = 0,
  });

  factory MeterData.fromMap(Map<String, dynamic> m) {
    final rawDataType = m["DataType"] as int? ?? 0;
    final rawWordOrder = m["WordOrder"] as int? ?? 0;
    return MeterData(
      moduleAddress: m["Address"] as int? ?? 0,
      registerCount: m["RegisterCount"] as int? ?? 1,
      dataType: (rawDataType >= 0 && rawDataType <= 7) ? rawDataType : 0,
      wordOrder: (rawWordOrder >= 0 && rawWordOrder <= 5) ? rawWordOrder : 0,
      scaleExponent: m["ScaleExponent"] as int? ?? 0,
    );
  }
}

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

  // ── Maps ─────────────────────────────────────────────────────
  final Map<int, String> chargerTypes = {
    1: "STANDALONE",
    2: "DISPENSER",
    3: "STACK"
  };
  final Map<int, String> boardModelOptions = {1: "V1", 2: "V2", 3: "V3"};
  final Map<int, String> networkModes = {
    0: "ONLINE",
    1: "OFFLINE",
    2: "ONLINE_OFFLINE",
    3: "PLUGNPLAY"
  };
  final Map<int, String> ethernetTypes = {0: "STATIC", 1: "DHCP"};
  final Map<int, String> dataTypes = {
    0: "UINT16",
    1: "INT16",
    2: "UINT32",
    3: "INT32",
    4: "UINT64",
    5: "FLOAT32",
    6: "BCD16",
    7: "BCD32"
  };
  final Map<int, String> wordOrders = {
    0: "AB",
    1: "BA",
    2: "ABCD",
    3: "BADC",
    4: "CDAB",
    5: "DCBA"
  };
  final List<String> acMeterOptions = [
    'Selec EM4M',
    'Selec MFM384',
    'Elmeasure M30',
    'Elmeasure LG2XX0D',
    'Rishabh 3430',
    'Havells SDM630',
    'User Defined',
  ];
  final List<String> dcMeterOptions = [
    'Rishabh EM6000',
    'Rishabh EM6001',
    'Selec EM2M',
    'Elmeasure EDC2150D',
    'Elecnova PD195Z-CD31F',
    'Elecnova PD195Z-CD32F',
    'Pilot DCMSPM90',
    'IVY DC EM619002',
    'Yada DCM3366D-J2',
    'User Defined',
  ];
  final Map<String, int> acMeterTypeEnum = {
    'User Defined': 0,
    'Selec EM4M': 1,
    'Selec MFM384': 2,
    'Elmeasure M30': 3,
    'Elmeasure LG2XX0D': 4,
    'Rishabh 3430': 5,
    'Havells SDM630': 6,
  };
  final Map<String, int> dcMeterTypeEnum = {
    'User Defined': 0,
    'Rishabh EM6000': 1,
    'Rishabh EM6001': 2,
    'Selec EM2M': 3,
    'Elmeasure EDC2150D': 4,
    'Elecnova PD195Z-CD31F': 5,
    'Elecnova PD195Z-CD32F': 6,
    'Pilot DCMSPM90': 7,
    'IVY DC EM619002': 8,
    'Yada DCM3366D-J2': 9,
  };

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
    final dcOverVoltList = d["DCoverVoltageThreshold"];
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
    final dcUnderVoltList = d["DCunderVoltageThreshold"];
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
    final dcOverCurrList = d["DCoverCurrentThreshold"];
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

  Map<String, dynamic> _buildSaveMap() => {
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
        "firmwareVersion": firmwareVersionCtrl.text.trim(),
        "slavefirmwareVersion": slaveFirmwareVersionCtrl.text.trim(),
        "smartCharging": smartCharging,
        "restoreSessionFromFault": restoreFromFault,
        "restoreSessionFromFaultTime":
            int.tryParse(restoreTimeCtrl.text.trim()) ?? 0,
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
        "NumberOfDisplays": int.tryParse(displaysCtrl.text.trim()) ?? 1,
        "NumberOfConnectors": int.tryParse(connectorsCtrl.text.trim()) ?? 1,
        "NumberOfPowerModules": int.tryParse(powerModulesCtrl.text.trim()) ?? 1,
        "DCoverVoltageThreshold": [
          double.tryParse(dcOverVoltCtrl1.text.trim()) ?? 0.0,
          if (_connectorCount >= 2)
            double.tryParse(dcOverVoltCtrl2.text.trim()) ?? 0.0,
        ],
        "ACoverVoltageThreshold":
            double.tryParse(acOverVoltCtrl.text.trim()) ?? 0.0,
        "DCunderVoltageThreshold": [
          double.tryParse(dcUnderVoltCtrl1.text.trim()) ?? 0.0,
          if (_connectorCount >= 2)
            double.tryParse(dcUnderVoltCtrl2.text.trim()) ?? 0.0,
        ],
        "ACunderVoltageThreshold":
            double.tryParse(acUnderVoltCtrl.text.trim()) ?? 0.0,
        "DCoverCurrentThreshold": [
          int.tryParse(dcOverCurrCtrl1.text.trim()) ?? 0,
          if (_connectorCount >= 2)
            int.tryParse(dcOverCurrCtrl2.text.trim()) ?? 0,
        ],
        "ACoverCurrentThreshold": int.tryParse(acOverCurrCtrl.text.trim()) ?? 0,
        "overTemperatureThreshold":
            double.tryParse(overTempCtrl.text.trim()) ?? 0.0,
        "acMeter": {
          "meterType": acMeterType,
          "voltageAddr": acVoltageAddr,
          "currentAddr": acCurrentAddr,
          "powerAddr": acPowerAddr,
          "dataType": acDataType,
          "wordOrder": acWordOrder,
          "scaleExp": acScaleExp,
          "offsetAddr": acOffsetAddr,
        },
        "dcMeter1": {
          "meterType": dcMeter1Type,
          "voltageAddr": dc1VoltageAddr,
          "currentAddr": dc1CurrentAddr,
          "powerAddr": dc1PowerAddr,
          "dataType": dc1DataType,
          "wordOrder": dc1WordOrder,
          "scaleExp": dc1ScaleExp,
          "offsetAddr": dc1OffsetAddr,
        },
        "dcMeter2": {
          "meterType": dcMeter2Type,
          "voltageAddr": dc2VoltageAddr,
          "currentAddr": dc2CurrentAddr,
          "powerAddr": dc2PowerAddr,
          "dataType": dc2DataType,
          "wordOrder": dc2WordOrder,
          "scaleExp": dc2ScaleExp,
          "offsetAddr": dc2OffsetAddr,
        },
        "OtaUrlFromCMSEnable": otaUrlFromCMS,
        "OtaURLConfig": otaURLCtrl.text.trim(),
        "DiagnosticServer": diagnosticServer,
        "DiagnosticServerUrl": diagnosticURLCtrl.text.trim(),
      };
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
        "DCunderVoltageThreshold": [
          double.tryParse(dcUnderVoltCtrl1.text.trim()) ?? 0.0,
          if (_connectorCount >= 2)
            double.tryParse(dcUnderVoltCtrl2.text.trim()) ?? 0.0,
        ],
        "DCoverVoltageThreshold": [
          double.tryParse(dcOverVoltCtrl1.text.trim()) ?? 0.0,
          if (_connectorCount >= 2)
            double.tryParse(dcOverVoltCtrl2.text.trim()) ?? 0.0,
        ],
        "DCoverCurrentThreshold": [
          int.tryParse(dcOverCurrCtrl1.text.trim()) ?? 0,
          if (_connectorCount >= 2)
            int.tryParse(dcOverCurrCtrl2.text.trim()) ?? 0,
        ],
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
        debugPrint("Has PowerModule1: ${data.containsKey("PowerModule1")}");
        debugPrint("PowerModule1 = ${jsonEncode(data["PowerModule1"])}");
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
  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 1.2)),
      );

  Widget _row(String label, String value) => Container(
        color: _surface,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(
                  flex: 4,
                  child: Text(label,
                      style: TextStyle(fontSize: 13, color: _textSecondary))),
              Expanded(
                  flex: 6,
                  child: Text(
                    value.isEmpty ? "--" : value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: value.isEmpty ? _textSecondary : _textPrimary),
                  )),
            ]),
          ),
          Divider(height: 1, color: _border),
        ]),
      );

  Widget _boolRow(String label, bool value) => Container(
        color: _surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: value
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.error.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      value ? "Available" : "Unavailable",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: value ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _border),
          ],
        ),
      );

  Widget _statusRow(String label, bool value) => Container(
        color: _surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: value
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.error.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      value ? "Enabled" : "Disabled",
                      style: TextStyle(
                        color: value ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _border),
          ],
        ),
      );

  Widget _pmStatusRow(bool value) => Container(
        color: _surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Status",
                      style: TextStyle(
                        fontSize: 13,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: value
                          ? AppColors.success.withOpacity(0.12)
                          : AppColors.error.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      value ? "Available" : "Unavailable",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: value ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: _border),
          ],
        ),
      );

  Widget _dropRow(String label, String value) => Container(
        color: _surface,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Expanded(
                  flex: 4,
                  child: Text(label,
                      style: TextStyle(fontSize: 13, color: _textSecondary))),
              Expanded(
                  flex: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                          child: Text(value,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary))),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          size: 18, color: _textSecondary),
                    ],
                  )),
            ]),
          ),
          Divider(height: 1, color: _border),
        ]),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    bool readOnly = false,
    TextInputAction action = TextInputAction.next,
  }) {
    final key = GlobalObjectKey(ctrl);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            onChanged: (_) {
              _markConfigChanged();
            },
            keyboardType: keyboard,
            obscureText: obscure,
            readOnly: readOnly,
            textInputAction: action,
            style: TextStyle(
                fontSize: 14, color: readOnly ? _textSecondary : _textPrimary),
            scrollPadding: const EdgeInsets.only(bottom: 400),
            onTap: readOnly
                ? null
                : () {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (key.currentContext != null) {
                        Scrollable.ensureVisible(key.currentContext!,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            alignment: 0.3);
                      }
                    });
                  },
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: readOnly
                  ? (_isDark ? AppColors.borderDark : AppColors.borderStrong)
                  : (_isDark
                      ? AppColors.surfaceVariantDark
                      : AppColors.surfaceVariant),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: readOnly ? _border : AppColors.primary,
                      width: 1.5)),
              suffixIcon: readOnly
                  ? Icon(Icons.lock_outline, size: 16, color: _textSecondary)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // Integer field (for meter addresses)
  Widget _intField(String label, int value, ValueChanged<int> onChanged,
      {bool readOnly = false}) {
    final ctrl = TextEditingController(text: value.toString());
    return _fieldRaw(label, ctrl,
        readOnly: readOnly, keyboard: TextInputType.number, onChanged: (v) {
      final n = int.tryParse(v);
      if (n != null) onChanged(n);
    });
  }

  Widget _fieldRaw(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboard = TextInputType.text,
    bool readOnly = false,
    ValueChanged<String>? onChanged,
  }) {
    final key = GlobalObjectKey(ctrl);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: keyboard,
            readOnly: readOnly,
            onChanged: onChanged,
            style: TextStyle(
                fontSize: 14, color: readOnly ? _textSecondary : _textPrimary),
            scrollPadding: const EdgeInsets.only(bottom: 400),
            onTap: readOnly
                ? null
                : () {
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (key.currentContext != null) {
                        Scrollable.ensureVisible(key.currentContext!,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            alignment: 0.3);
                      }
                    });
                  },
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: readOnly
                  ? (_isDark ? AppColors.borderDark : AppColors.borderStrong)
                  : (_isDark
                      ? AppColors.surfaceVariantDark
                      : AppColors.surfaceVariant),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: readOnly ? _border : AppColors.primary,
                      width: 1.5)),
              suffixIcon: readOnly
                  ? Icon(Icons.lock_outline, size: 16, color: _textSecondary)
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropEdit<T>(String label, T value, Map<T, String> opts,
          ValueChanged<T> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _textSecondary)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: _isDark
                  ? AppColors.surfaceVariantDark
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                dropdownColor: _surface,
                style: TextStyle(fontSize: 14, color: _textPrimary),
                items: opts.entries
                    .map((e) =>
                        DropdownMenuItem(value: e.key, child: Text(e.value)))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;

                  setState(() {
                    onChanged(v);
                  });

                  _markConfigChanged();
                },
              ),
            ),
          ),
        ]),
      );

  Widget _strDropEdit(String label, String value, List<String> opts,
          ValueChanged<String> onChanged) =>
      _dropEdit<String>(label, value, {for (final o in opts) o: o}, onChanged);

  Widget _toggle(String label, bool value, ValueChanged<bool> onChanged) =>
      Container(
        color: Colors.transparent,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 13, color: _textSecondary))),
              GestureDetector(
                onTap: _editMode
                    ? () {
                        setState(() {
                          onChanged(!value);
                        });

                        _markConfigChanged();
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: value
                        ? AppColors.success
                        : (_isDark
                            ? AppColors.borderDark
                            : AppColors.borderStrong),
                  ),
                  child: Stack(children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      left: value ? 26 : 2,
                      top: 2,
                      child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: Colors.white)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Text(value ? "ON" : "OFF",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: value ? AppColors.success : _textSecondary)),
            ]),
          ),
          Divider(height: 1, color: _border),
        ]),
      );

  Widget _checkEdit(String label, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, color: _textSecondary))),
          Checkbox(
            value: value,
            onChanged: _editMode
                ? (bool? v) {
                    if (v == null) return;
                    setState(() {
                      onChanged(v);
                    });
                    _markConfigChanged();
                  }
                : null,
            activeColor: AppColors.primary,
          ),
        ]),
      );

  Widget _actionBtn(
          String label, IconData icon, Color color, VoidCallback fn) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: OutlinedButton.icon(
          icon: Icon(icon, size: 18, color: color),
          label: Text(label, style: TextStyle(color: color)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: fn,
        ),
      );

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
            "DC Under Voltage",
            dcUnderVoltCtrl1,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            "DC Over Voltage",
            dcOverVoltCtrl1,
            keyboard: const TextInputType.numberWithOptions(decimal: true),
          ),
          _field(
            "DC Over Current",
            dcOverCurrCtrl1,
            keyboard: TextInputType.number,
          ),
          if (_connectorCount >= 2) ...[
            _section("Connector 2"),
            _field(
              "DC Under Voltage",
              dcUnderVoltCtrl2,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            _field(
              "DC Over Voltage",
              dcOverVoltCtrl2,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            _field(
              "DC Over Current",
              dcOverCurrCtrl2,
              keyboard: TextInputType.number,
            ),
          ],
          _section("Power Modules"),
          _field(
            "Number of Power Modules",
            powerModulesCtrl,
            keyboard: TextInputType.number,
          ),
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
          _actionBtn("Restart Charger", Icons.restart_alt_rounded, _textPrimary,
              _restart),
          _actionBtn("Factory Reset", Icons.restore_rounded, AppColors.error,
              _factoryReset),
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
      _row("DC Under Voltage", dcUnderVoltCtrl1.text),
      _row("DC Over Voltage", dcOverVoltCtrl1.text),
      _row("DC Over Current", dcOverCurrCtrl1.text),
      if (_connectorCount >= 2) ...[
        _section("Connector 2"),
        _row("DC Under Voltage", dcUnderVoltCtrl2.text),
        _row("DC Over Voltage", dcOverVoltCtrl2.text),
        _row("DC Over Current", dcOverCurrCtrl2.text),
      ],
      _section("Power Modules"),
      _row("Number of Power Modules", powerModulesCtrl.text),
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
          "Restart Charger", Icons.restart_alt_rounded, _textPrimary, _restart),
      _actionBtn("Factory Reset", Icons.restore_rounded, AppColors.error,
          _factoryReset),
    ]);
  }

  // ── Meter channel widget ──────────────────────────────────────
  Widget _meterChannel(String title, MeterData data, {bool readOnly = false}) {
    final bool ro = readOnly || !_editMode;

    if (!_editMode) {
      return Padding(
        padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          const SizedBox(height: 4),
          _row("Module Addr", data.moduleAddress.toString()),
          _row("Reg. Count", data.registerCount.toString()),
          _row("Data Type", dataTypes[data.dataType] ?? ""),
          _row("Word Order", wordOrders[data.wordOrder] ?? ""),
          _row("Scale Exp", data.scaleExponent.toString()),
        ]),
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

  Widget _miniIntField(String label, int value, ValueChanged<int> onChanged,
      {bool readOnly = false}) {
    final ctrl = TextEditingController(text: value.toString());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
            width: 72,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: _textSecondary))),
        Expanded(
          child: SizedBox(
            height: 32,
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              readOnly: readOnly,
              scrollPadding: const EdgeInsets.only(bottom: 400),
              style: TextStyle(
                  fontSize: 12,
                  color: readOnly ? _textSecondary : _textPrimary),
              onChanged: readOnly
                  ? null
                  : (v) {
                      final n = int.tryParse(v);
                      if (n != null) onChanged(n);
                    },
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: readOnly
                    ? (_isDark ? AppColors.borderDark : AppColors.borderStrong)
                    : _surface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                        color: readOnly ? _border : AppColors.primary,
                        width: 1.5)),
                suffixIcon: readOnly
                    ? Icon(Icons.lock_outline, size: 14, color: _textSecondary)
                    : null,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _miniFloatField(String label, TextEditingController ctrl) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style: TextStyle(fontSize: 11, color: _textSecondary))),
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: ctrl,
                onChanged: (_) {
                  _markPowerModuleChanged();
                },
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                scrollPadding: const EdgeInsets.only(bottom: 400),
                style: TextStyle(fontSize: 12, color: _textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: _surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _border)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5)),
                ),
              ),
            ),
          ),
        ]),
      );

  Widget _miniDropEdit<T>(
          String label, T value, Map<T, String> opts, ValueChanged<T> onChanged,
          {bool readOnly = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          SizedBox(
              width: 72,
              child: Text(label,
                  style: TextStyle(fontSize: 11, color: _textSecondary))),
          Expanded(
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: readOnly
                    ? (_isDark ? AppColors.borderDark : AppColors.borderStrong)
                    : _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  isExpanded: true,
                  isDense: true,
                  dropdownColor: _surface,
                  style: TextStyle(
                      fontSize: 12,
                      color: readOnly ? _textSecondary : _textPrimary),
                  items: opts.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value,
                              style: TextStyle(
                                  fontSize: 12, color: _textPrimary))))
                      .toList(),
                  onChanged: readOnly
                      ? null
                      : (v) {
                          if (v != null) onChanged(v);
                        },
                ),
              ),
            ),
          ),
        ]),
      );
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
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: _surface,
          leading: _editMode
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: _returnToInfoMode,
                )
              : null,
          // FIX: Use shorter title so it doesn't get truncated
          title: Column(children: [
            Text("EVSE Config",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary)),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.success)),
              const SizedBox(width: 4),
              Text("Connected",
                  style: TextStyle(fontSize: 10, color: _textSecondary)),
            ]),
          ]),
          actions: [
            // Theme toggle
            IconButton(
              icon: Icon(
                  _isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  size: 20,
                  color: _textSecondary),
              onPressed: () => EVSEApp.of(context)?.toggleTheme(),
            ),
            // Reset button
            IconButton(
              tooltip: "Reset to saved config",
              icon: Icon(Icons.history_rounded,
                  color: AppColors.warning, size: 22),
              onPressed: _resetToSaved,
            ),
            // Disconnect
            IconButton(
              tooltip: "Disconnect",
              icon: const Icon(Icons.bluetooth_disabled_rounded,
                  color: AppColors.error, size: 22),
              onPressed: _disconnecting ? null : _disconnect,
            ),
            // Edit / Save
            if (!_loading)
              IconButton(
                icon: Icon(
                  _editMode ? Icons.save_rounded : Icons.edit_rounded,
                  color: AppColors.primary,
                ),
                onPressed: _saving
                    ? null
                    : () async {
                        if (_editMode) {
                          // Save button — stays in edit mode
                          FocusScope.of(context).unfocus();
                          await Future.delayed(
                              const Duration(milliseconds: 200));
                          await _save();
                        } else {
                          // Pencil icon — enter edit mode
                          setState(() => _editMode = true);
                        }
                      },
              ),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text("Reading configuration...",
                  style: TextStyle(fontSize: 13, color: _textSecondary)),
            ]))
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
                  _comingSoon("Mux"),
                ],
              ),
            ),
          if (_saving)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                  child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                    color: _surface, borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text("Saving configuration...",
                      style: TextStyle(fontSize: 13, color: _textSecondary)),
                ]),
              )),
            ),
          if (_disconnecting)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                  child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                    color: _surface, borderRadius: BorderRadius.circular(20)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircularProgressIndicator(color: AppColors.error),
                  const SizedBox(height: 16),
                  Text("Disconnecting...",
                      style: TextStyle(fontSize: 13, color: _textSecondary)),
                ]),
              )),
            ),
        ]),
      ),
    );
  }
}
