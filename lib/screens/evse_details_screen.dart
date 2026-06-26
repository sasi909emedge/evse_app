import 'package:flutter/material.dart';
import '../ble/ble_service_selector.dart';
import '../theme/app_colors.dart';

class EvseDetailsScreen extends StatefulWidget {
  final String deviceId;
  const EvseDetailsScreen({super.key, required this.deviceId});

  @override
  State<EvseDetailsScreen> createState() => _EvseDetailsScreenState();
}

class _EvseDetailsScreenState extends State<EvseDetailsScreen> {
  final _scrollController = ScrollController();

  // ── Controllers ─────────────────────────────────────────────────────
  // Charger Info
  final serialCtrl = TextEditingController();
  final chargerNameCtrl = TextEditingController();
  final vendorCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final commissionedByCtrl = TextEditingController();
  final commissionedDateCtrl = TextEditingController();
  final firmwareVersionCtrl = TextEditingController();
  final slaveFirmwareVersionCtrl = TextEditingController();

  // WiFi
  final wifiSSIDCtrl = TextEditingController();
  final wifiPassCtrl = TextEditingController();
  final wifiPriorityCtrl = TextEditingController();

  // GSM
  final gsmAPNCtrl = TextEditingController();
  final gsmPriorityCtrl = TextEditingController();

  // Ethernet
  final ethIPCtrl = TextEditingController();
  final ethGWCtrl = TextEditingController();
  final ethSubnetCtrl = TextEditingController();
  final ethDNSCtrl = TextEditingController();
  final ethPriorityCtrl = TextEditingController();

  // OCPP
  final ocppURLCtrl = TextEditingController();
  final chargePointIDCtrl = TextEditingController();
  final heartbeatCtrl = TextEditingController();

  // Hardware
  final displaysCtrl = TextEditingController();
  final connectorsCtrl = TextEditingController();
  final powerModulesCtrl = TextEditingController();

  // ── State Variables ──────────────────────────────────────────────────
  int chargerType = 1;
  int chargerModel = 1;
  int boardModel = 1;

  String wifiEnable = "DISABLE";
  String gsmEnable = "DISABLE";
  String ethernetEnable = "DISABLE";
  String ethernetDHCP = "DHCP";
  String ocppEnable = "DISABLE";
  String batteryBackup = "DISABLE";

  // View-mode display strings (set from controllers on load/save)
  Map<String, String> _display = {};

  bool _loading = true;
  bool _saving = false;
  bool editMode = false;
  bool _reading = false;

  // Current tab
  int _tabIndex = 0;

  // ── Dropdown Maps ────────────────────────────────────────────────────
  final Map<int, String> chargerTypes = {
    1: "STANDALONE",
    2: "DISPENSER",
    3: "STACK",
  };
  final Map<int, String> chargerModels = {
    1: "DC30S",
    2: "DC60S",
    3: "DC120S",
    4: "DC180S",
    5: "DC240S",
    6: "DC60D",
    7: "DC120D",
  };
  final Map<int, String> boardModels = {
    1: "DC1",
    2: "DC2",
    3: "DC3",
  };
  final List<String> enableOptions = ["ENABLE", "DISABLE"];
  final List<String> dhcpOptions = ["DHCP", "STATIC"];

  // =====================================================================
  // APPLY DATA TO STATE
  // Single source of truth used by both load and save
  // =====================================================================
  void _applyDataToState(Map<String, dynamic> d) {
    // Charger info
    serialCtrl.text = d["serialNumber"]?.toString() ?? "";
    chargerNameCtrl.text = d["chargerName"]?.toString() ?? "";
    vendorCtrl.text = d["chargePointVendor"]?.toString() ?? "";
    modelCtrl.text = d["chargePointModel"]?.toString() ?? "";
    commissionedByCtrl.text = d["commissionedBy"]?.toString() ?? "";
    commissionedDateCtrl.text = d["commissionedDate"]?.toString() ?? "";
    firmwareVersionCtrl.text = d["firmwareVersion"]?.toString() ?? "";
    slaveFirmwareVersionCtrl.text = d["slaveFirmwareVersion"]?.toString() ?? "";

    chargerType = chargerTypes.entries
        .firstWhere((e) => e.value == d["chargerType"],
            orElse: () => const MapEntry(1, "STANDALONE"))
        .key;
    chargerModel = chargerModels.entries
        .firstWhere((e) => e.value == d["chargerModel"],
            orElse: () => const MapEntry(1, "DC30S"))
        .key;
    boardModel = boardModels.entries
        .firstWhere((e) => e.value == d["boardModel"],
            orElse: () => const MapEntry(1, "DC1"))
        .key;

    // WiFi
    wifiEnable = d["wifiEnable"]?.toString() ?? "DISABLE";
    wifiSSIDCtrl.text = d["wifiSSID"]?.toString() ?? "";
    wifiPassCtrl.text = d["wifiPassword"]?.toString() ?? "";
    wifiPriorityCtrl.text = d["wifiPriority"]?.toString() ?? "1";

    // GSM
    gsmEnable = d["gsmEnable"]?.toString() ?? "DISABLE";
    gsmAPNCtrl.text = d["gsmAPN"]?.toString() ?? "";
    gsmPriorityCtrl.text = d["gsmPriority"]?.toString() ?? "2";

    // Ethernet
    ethernetEnable = d["ethernetEnable"]?.toString() ?? "DISABLE";
    ethernetDHCP = d["ethernetDHCP"]?.toString() ?? "DHCP";
    ethIPCtrl.text = d["ethernetIP"]?.toString() ?? "";
    ethGWCtrl.text = d["ethernetGateway"]?.toString() ?? "";
    ethSubnetCtrl.text = d["ethernetSubnet"]?.toString() ?? "";
    ethDNSCtrl.text = d["ethernetDNS"]?.toString() ?? "";
    ethPriorityCtrl.text = d["ethernetPriority"]?.toString() ?? "3";

    // OCPP
    ocppEnable = d["ocppEnable"]?.toString() ?? "DISABLE";
    ocppURLCtrl.text = d["ocppURL"]?.toString() ?? "";
    chargePointIDCtrl.text = d["chargePointID"]?.toString() ?? "";
    heartbeatCtrl.text = d["heartbeatInterval"]?.toString() ?? "30";

    // Hardware
    displaysCtrl.text = d["numberOfDisplays"]?.toString() ?? "1";
    connectorsCtrl.text = d["numberOfConnectors"]?.toString() ?? "1";
    powerModulesCtrl.text = d["numberOfPowerModules"]?.toString() ?? "1";
    batteryBackup = d["batteryBackup"]?.toString() ?? "DISABLE";

    // Rebuild display map for view mode
    _display = {
      "Serial Number": serialCtrl.text,
      "Charger Name": chargerNameCtrl.text,
      "Charge Point Vendor": vendorCtrl.text,
      "Charge Point Model": modelCtrl.text,
      "Commissioned By": commissionedByCtrl.text,
      "Commissioned Date": commissionedDateCtrl.text,
      "Firmware Version": firmwareVersionCtrl.text,
      "Slave Firmware Version": slaveFirmwareVersionCtrl.text,
      "WiFi": wifiEnable,
      "SSID": wifiSSIDCtrl.text,
      "WiFi Priority": wifiPriorityCtrl.text,
      "GSM": gsmEnable,
      "APN": gsmAPNCtrl.text,
      "GSM Priority": gsmPriorityCtrl.text,
      "Ethernet": ethernetEnable,
      "DHCP/Static": ethernetDHCP,
      "IP Address": ethIPCtrl.text,
      "Gateway": ethGWCtrl.text,
      "Subnet": ethSubnetCtrl.text,
      "DNS": ethDNSCtrl.text,
      "Ethernet Priority": ethPriorityCtrl.text,
      "OCPP": ocppEnable,
      "Server URL": ocppURLCtrl.text,
      "Charge Point ID": chargePointIDCtrl.text,
      "Heartbeat Interval": heartbeatCtrl.text,
      "Displays": displaysCtrl.text,
      "Connectors": connectorsCtrl.text,
      "Power Modules": powerModulesCtrl.text,
      "Battery Backup": batteryBackup,
    };
  }

  // =====================================================================
  // LOAD
  // =====================================================================
  Future<void> _loadDeviceState() async {
    if (_reading) return;
    _reading = true;

    try {
      int waited = 0;
      while (
          !BleService.instance.isGattReady(widget.deviceId) && waited < 5000) {
        await Future.delayed(const Duration(milliseconds: 200));
        waited += 200;
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
        debugPrint("❌ Read error: $e");
      }

      if (data.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 600));
        try {
          data = await BleService.instance.readJson(widget.deviceId);
        } catch (e) {
          debugPrint("❌ Retry failed: $e");
        }
      }

      if (!mounted) return;

      if (data.isNotEmpty) {
        setState(() => _applyDataToState(data));
      }

      setState(() => _loading = false);
    } catch (e) {
      debugPrint("❌ LOAD ERROR: $e");
      if (mounted) setState(() => _loading = false);
    } finally {
      _reading = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // discoverServices already called in ble_scan_screen before navigation
      // Only discover again if GATT not ready (e.g. direct navigation)
      if (!BleService.instance.isGattReady(widget.deviceId)) {
        await BleService.instance.discoverServices(widget.deviceId);
      }
      await _loadDeviceState();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final c in [
      serialCtrl,
      chargerNameCtrl,
      vendorCtrl,
      modelCtrl,
      commissionedByCtrl,
      commissionedDateCtrl,
      firmwareVersionCtrl,
      slaveFirmwareVersionCtrl,
      wifiSSIDCtrl,
      wifiPassCtrl,
      wifiPriorityCtrl,
      gsmAPNCtrl,
      gsmPriorityCtrl,
      ethIPCtrl,
      ethGWCtrl,
      ethSubnetCtrl,
      ethDNSCtrl,
      ethPriorityCtrl,
      ocppURLCtrl,
      chargePointIDCtrl,
      heartbeatCtrl,
      displaysCtrl,
      connectorsCtrl,
      powerModulesCtrl,
    ]) {
      c.dispose();
    }
    BleService.instance.disconnect(widget.deviceId);
    super.dispose();
  }

  // =====================================================================
  // SAVE
  // =====================================================================
  Future<void> _save() async {
    setState(() => _saving = true);

    final updatedData = <String, dynamic>{
      "chargerType": chargerTypes[chargerType],
      "chargerModel": chargerModels[chargerModel],
      "boardModel": boardModels[boardModel],
      "serialNumber": serialCtrl.text.trim(),
      "chargerName": chargerNameCtrl.text.trim(),
      "chargePointVendor": vendorCtrl.text.trim(),
      "chargePointModel": modelCtrl.text.trim(),
      "commissionedBy": commissionedByCtrl.text.trim(),
      "commissionedDate": commissionedDateCtrl.text.trim(),
      "firmwareVersion": firmwareVersionCtrl.text.trim(),
      "slaveFirmwareVersion": slaveFirmwareVersionCtrl.text.trim(),
      // WiFi
      "wifiEnable": wifiEnable,
      "wifiSSID": wifiSSIDCtrl.text.trim(),
      "wifiPassword": wifiPassCtrl.text.trim(),
      "wifiPriority": wifiPriorityCtrl.text.trim(),
      // GSM
      "gsmEnable": gsmEnable,
      "gsmAPN": gsmAPNCtrl.text.trim(),
      "gsmPriority": gsmPriorityCtrl.text.trim(),
      // Ethernet
      "ethernetEnable": ethernetEnable,
      "ethernetDHCP": ethernetDHCP,
      "ethernetIP": ethIPCtrl.text.trim(),
      "ethernetGateway": ethGWCtrl.text.trim(),
      "ethernetSubnet": ethSubnetCtrl.text.trim(),
      "ethernetDNS": ethDNSCtrl.text.trim(),
      "ethernetPriority": ethPriorityCtrl.text.trim(),
      // OCPP
      "ocppEnable": ocppEnable,
      "ocppURL": ocppURLCtrl.text.trim(),
      "chargePointID": chargePointIDCtrl.text.trim(),
      "heartbeatInterval": heartbeatCtrl.text.trim(),
      // Hardware
      "numberOfDisplays": displaysCtrl.text.trim(),
      "numberOfConnectors": connectorsCtrl.text.trim(),
      "numberOfPowerModules": powerModulesCtrl.text.trim(),
      "batteryBackup": batteryBackup,
    };

    try {
      await BleService.instance.writeJson(widget.deviceId, updatedData);

      // Update UI directly from what we sent — no re-read needed
      if (mounted) {
        setState(() => _applyDataToState(updatedData));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Configuration Saved Successfully"),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ SAVE ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ Save failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =====================================================================
  // FACTORY RESET
  // =====================================================================
  Future<void> _factoryReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Factory Reset"),
        content: const Text(
            "This will erase all saved configuration and restart the charger.\n\nAre you sure?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Reset", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await BleService.instance.sendCommand(widget.deviceId, "#FACTORY_RESET#");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Factory reset sent. Charger restarting...")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("❌ Factory reset error: $e");
    }
  }

  // =====================================================================
  // RESTART
  // =====================================================================
  Future<void> _restartCharger() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Restart Charger"),
        content: const Text("Restart the charger now?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Restart")),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await BleService.instance.sendCommand(widget.deviceId, "#RESTART#");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Restart command sent...")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("❌ Restart error: $e");
    }
  }

  // =====================================================================
  // UI HELPERS
  // =====================================================================
  Widget _row(String label, Widget value) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
          ),
          Expanded(flex: 6, child: value),
        ]),
      ),
      const Divider(height: 1),
    ]);
  }

  Widget _val(String key) {
    final v = _display[key] ?? "";
    return Text(
      v.isEmpty ? "--" : v,
      style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary),
    );
  }

  Widget _edit(
    TextEditingController c, {
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: const InputDecoration(isDense: true),
    );
  }

  Widget _dropdownStr(
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButton<String>(
      value: value,
      isExpanded: true,
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: editMode
          ? (v) {
              if (v != null) setState(() => onChanged(v));
            }
          : null,
    );
  }

  Widget _dropdownInt(
    int value,
    Map<int, String> options,
    ValueChanged<int> onChanged,
  ) {
    return DropdownButton<int>(
      value: value,
      isExpanded: true,
      items: options.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: editMode
          ? (v) {
              if (v != null) setState(() => onChanged(v));
            }
          : null,
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 1.1)),
    );
  }

  // =====================================================================
  // TAB: CHARGER INFO
  // =====================================================================
  Widget _buildChargerTab() {
    return ListView(children: [
      _sectionHeader("CHARGER IDENTITY"),
      _row("Charger Type",
          _dropdownInt(chargerType, chargerTypes, (v) => chargerType = v)),
      _row("Charger Model",
          _dropdownInt(chargerModel, chargerModels, (v) => chargerModel = v)),
      _row("Board Model",
          _dropdownInt(boardModel, boardModels, (v) => boardModel = v)),
      _row("Serial Number",
          editMode ? _edit(serialCtrl) : _val("Serial Number")),
      _row("Charger Name",
          editMode ? _edit(chargerNameCtrl) : _val("Charger Name")),
      _row("Charge Point Vendor",
          editMode ? _edit(vendorCtrl) : _val("Charge Point Vendor")),
      _row("Charge Point Model",
          editMode ? _edit(modelCtrl) : _val("Charge Point Model")),
      _row("Commissioned By",
          editMode ? _edit(commissionedByCtrl) : _val("Commissioned By")),
      _row("Commissioned Date",
          editMode ? _edit(commissionedDateCtrl) : _val("Commissioned Date")),
      _sectionHeader("FIRMWARE"),
      _row("Firmware Version",
          editMode ? _edit(firmwareVersionCtrl) : _val("Firmware Version")),
      _row(
          "Slave Firmware",
          editMode
              ? _edit(slaveFirmwareVersionCtrl)
              : _val("Slave Firmware Version")),
      const SizedBox(height: 20),
    ]);
  }

  // =====================================================================
  // TAB: COMMUNICATION
  // =====================================================================
  Widget _buildCommTab() {
    return ListView(children: [
      // ── WiFi ──
      _sectionHeader("WiFi"),
      _row("WiFi",
          _dropdownStr(wifiEnable, enableOptions, (v) => wifiEnable = v)),
      _row("SSID", editMode ? _edit(wifiSSIDCtrl) : _val("SSID")),
      _row(
          "Password",
          editMode
              ? _edit(wifiPassCtrl, obscure: true)
              : const Text("••••••••",
                  style: TextStyle(color: AppColors.textSecondary))),
      _row(
          "Priority",
          editMode
              ? _edit(wifiPriorityCtrl, keyboard: TextInputType.number)
              : _val("WiFi Priority")),

      // ── GSM ──
      _sectionHeader("GSM / SIM"),
      _row("GSM", _dropdownStr(gsmEnable, enableOptions, (v) => gsmEnable = v)),
      _row("APN", editMode ? _edit(gsmAPNCtrl) : _val("APN")),
      _row(
          "Priority",
          editMode
              ? _edit(gsmPriorityCtrl, keyboard: TextInputType.number)
              : _val("GSM Priority")),

      // ── Ethernet ──
      _sectionHeader("ETHERNET"),
      _row(
          "Ethernet",
          _dropdownStr(
              ethernetEnable, enableOptions, (v) => ethernetEnable = v)),
      _row("Mode",
          _dropdownStr(ethernetDHCP, dhcpOptions, (v) => ethernetDHCP = v)),
      _row("IP Address", editMode ? _edit(ethIPCtrl) : _val("IP Address")),
      _row("Gateway", editMode ? _edit(ethGWCtrl) : _val("Gateway")),
      _row("Subnet", editMode ? _edit(ethSubnetCtrl) : _val("Subnet")),
      _row("DNS", editMode ? _edit(ethDNSCtrl) : _val("DNS")),
      _row(
          "Priority",
          editMode
              ? _edit(ethPriorityCtrl, keyboard: TextInputType.number)
              : _val("Ethernet Priority")),

      const SizedBox(height: 20),
    ]);
  }

  // =====================================================================
  // TAB: OCPP
  // =====================================================================
  Widget _buildOcppTab() {
    return ListView(children: [
      _sectionHeader("OCPP SETTINGS"),
      _row("OCPP",
          _dropdownStr(ocppEnable, enableOptions, (v) => ocppEnable = v)),
      _row("Server URL", editMode ? _edit(ocppURLCtrl) : _val("Server URL")),
      _row("Charge Point ID",
          editMode ? _edit(chargePointIDCtrl) : _val("Charge Point ID")),
      _row(
          "Heartbeat (sec)",
          editMode
              ? _edit(heartbeatCtrl, keyboard: TextInputType.number)
              : _val("Heartbeat Interval")),
      const SizedBox(height: 20),
    ]);
  }

  // =====================================================================
  // TAB: HARDWARE
  // =====================================================================
  Widget _buildHardwareTab() {
    return ListView(children: [
      _sectionHeader("HARDWARE CONFIGURATION"),
      _row(
          "Displays",
          editMode
              ? _edit(displaysCtrl, keyboard: TextInputType.number)
              : _val("Displays")),
      _row(
          "Connectors",
          editMode
              ? _edit(connectorsCtrl, keyboard: TextInputType.number)
              : _val("Connectors")),
      _row(
          "Power Modules",
          editMode
              ? _edit(powerModulesCtrl, keyboard: TextInputType.number)
              : _val("Power Modules")),
      _row("Battery Backup",
          _dropdownStr(batteryBackup, enableOptions, (v) => batteryBackup = v)),
      _sectionHeader("CHARGER ACTIONS"),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.restart_alt),
          label: const Text("Restart Charger"),
          onPressed: _restartCharger,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.restore, color: Colors.red),
          label:
              const Text("Factory Reset", style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red)),
          onPressed: _factoryReset,
        ),
      ),
      const SizedBox(height: 20),
    ]);
  }

  // =====================================================================
  // BUILD
  // =====================================================================
  static const _tabs = [
    Tab(icon: Icon(Icons.ev_station), text: "Charger"),
    Tab(icon: Icon(Icons.wifi), text: "Comms"),
    Tab(icon: Icon(Icons.cloud), text: "OCPP"),
    Tab(icon: Icon(Icons.settings), text: "Hardware"),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("EVSE Configuration"),
          bottom: TabBar(
            tabs: _tabs,
            onTap: (i) => setState(() => _tabIndex = i),
          ),
          actions: [
            if (!_loading)
              IconButton(
                icon: Icon(editMode ? Icons.save : Icons.edit),
                onPressed: _saving
                    ? null
                    : () async {
                        if (editMode) await _save();
                        if (mounted) setState(() => editMode = !editMode);
                      },
              ),
          ],
        ),
        body: Stack(children: [
          if (_loading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Reading charger configuration..."),
                ],
              ),
            )
          else
            TabBarView(children: [
              _buildChargerTab(),
              _buildCommTab(),
              _buildOcppTab(),
              _buildHardwareTab(),
            ]),
          if (_saving)
            const ColoredBox(
              color: Color.fromARGB(140, 0, 0, 0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text("Saving configuration...",
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
