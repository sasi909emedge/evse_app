// ── Charger / Board constants ──────────────────────────────────
final Map<int, String> chargerTypes = {
  1: "STANDALONE",
  2: "DISPENSER",
  3: "STACK",
};

final Map<int, String> boardModelOptions = {1: "V1", 2: "V2", 3: "V3"};

// ── Network constants ───────────────────────────────────────────
final Map<int, String> networkModes = {
  0: "ONLINE",
  1: "OFFLINE",
  2: "ONLINE_OFFLINE",
  3: "PLUGNPLAY",
};

final Map<int, String> ethernetTypes = {0: "STATIC", 1: "DHCP"};

// ── Meter register constants ────────────────────────────────────
final Map<int, String> dataTypes = {
  0: "UINT16",
  1: "INT16",
  2: "UINT32",
  3: "INT32",
  4: "UINT64",
  5: "FLOAT32",
  6: "BCD16",
  7: "BCD32",
};

final Map<int, String> wordOrders = {
  0: "AB",
  1: "BA",
  2: "ABCD",
  3: "BADC",
  4: "CDAB",
  5: "DCBA",
};

// ── Meter type options ───────────────────────────────────────────
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
