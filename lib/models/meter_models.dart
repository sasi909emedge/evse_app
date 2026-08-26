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

const List<String> acChannelNames = [
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
const List<String> dcChannelNames = ['Voltage', 'Current', 'Power', 'Energy'];

Map<String, ChannelPreset> fakeChannelSet(
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

final List<String> acMeterModelOrder = [
  'Selec EM4M',
  'Selec MFM384',
  'Elmeasure M30',
  'Elmeasure LG2XX0D',
  'Rishabh 3430',
  'Havells SDM630',
];

final List<String> dcMeterModelOrder = [
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
  for (int i = 0; i < acMeterModelOrder.length; i++)
    acMeterModelOrder[i]: fakeChannelSet(acChannelNames, i),
};

final Map<String, Map<String, ChannelPreset>> dcMeterChannelPresets = {
  for (int i = 0; i < dcMeterModelOrder.length; i++)
    dcMeterModelOrder[i]: fakeChannelSet(dcChannelNames, i),
};

const Map<int, String> meterDataTypeTokens = {
  0: "UINT16",
  1: "INT16",
  2: "UINT32",
  3: "INT32",
  4: "UINT64",
  5: "FLOAT32",
  6: "BCD16",
  7: "BCD32",
};
const Map<int, String> meterWordOrderTokens = {
  0: "AB",
  1: "BA",
  2: "ABCD",
  3: "BADC",
  4: "CDAB",
  5: "DCBA",
};

int parseHexAddress(dynamic v) {
  if (v == null) return 0;
  final s = v.toString();
  return s.toLowerCase().startsWith('0x')
      ? int.tryParse(s.substring(2), radix: 16) ?? 0
      : int.tryParse(s) ?? 0;
}

int reverseLookup(Map<int, String> map, dynamic val, int fallback) {
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
