import 'package:flutter/material.dart';
import '../ble/ble_service.dart';
import '../theme/app_colors.dart';

class EvseDetailsScreen extends StatefulWidget {
  final String deviceId;

  const EvseDetailsScreen({super.key, required this.deviceId});

  @override
  State<EvseDetailsScreen> createState() => _EvseDetailsScreenState();
}

class _EvseDetailsScreenState extends State<EvseDetailsScreen> {

  final _scrollController = ScrollController();

  final serialCtrl = TextEditingController();
  final chargerNameCtrl = TextEditingController();
  final vendorCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final commissionedByCtrl = TextEditingController();
  final commissionedDateCtrl = TextEditingController();
  final wsUrlCtrl = TextEditingController();

  String serial = "";
  String chargerName = "";
  String vendor = "";
  String model = "";
  String commissionedBy = "";
  String commissionedDate = "";
  String webSocketURL = "";
  String chargerType = "AC1";

  bool _loading = true;
  bool _saving = false;
  bool editMode = false;
  bool _reading = false;

  final chargerTypes = ["AC1", "AC2", "AC3", "DC1", "DC2", "DC3"];

  // ================= LOAD =================
  Future<void> _loadDeviceState() async {
    if (_reading) return;
    _reading = true;

    try {
      debugPrint("⏳ Waiting for GATT ready...");

      // Wait until GATT is ready — up to 5 seconds
      int waited = 0;
      while (!BleService.instance.isGattReady(widget.deviceId) && waited < 5000) {
        await Future.delayed(const Duration(milliseconds: 200));
        waited += 200;
      }

      if (!BleService.instance.isGattReady(widget.deviceId)) {
        debugPrint("❌ GATT never became ready after ${waited}ms");
        if (mounted) setState(() => _loading = false);
        return;
      }

      debugPrint("✅ GATT ready after ${waited}ms, reading...");

      // Extra settle time after GATT ready (ESP32/NimBLE needs this)
      await Future.delayed(const Duration(milliseconds: 400));

      Map<String, dynamic> data = {};

      // First read attempt
      try {
        data = await BleService.instance.readJson(widget.deviceId);
      } catch (e) {
        debugPrint("⚠️ First read failed: $e");
      }

      // Retry if empty (common on NimBLE first read)
      if (data.isEmpty) {
        debugPrint("🔁 First read empty — retrying after delay...");
        await Future.delayed(const Duration(milliseconds: 600));
        try {
          data = await BleService.instance.readJson(widget.deviceId);
        } catch (e) {
          debugPrint("❌ Retry read failed: $e");
        }
      }

      if (!mounted) return;

      if (data.isEmpty) {
        debugPrint("❌ No data received after retry");
        setState(() => _loading = false);
        return;
      }

      debugPrint("✅ FINAL DATA: $data");

      setState(() {
        serial = data["serialNumber"]?.toString() ?? "";
        chargerName = data["chargerName"]?.toString() ?? "";
        vendor = data["chargePointVendor"]?.toString() ?? "";
        model = data["chargePointModel"]?.toString() ?? "";
        commissionedBy = data["commissionedBy"]?.toString() ?? "";
        commissionedDate = data["commissionedDate"]?.toString() ?? "";
        webSocketURL = data["webSocketURL"]?.toString() ?? "";
        chargerType = data["chargerType"]?.toString() ?? "AC1";

        serialCtrl.text = serial;
        chargerNameCtrl.text = chargerName;
        vendorCtrl.text = vendor;
        modelCtrl.text = model;
        commissionedByCtrl.text = commissionedBy;
        commissionedDateCtrl.text = commissionedDate;
        wsUrlCtrl.text = webSocketURL;

        _loading = false;
      });

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeviceState();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    serialCtrl.dispose();
    chargerNameCtrl.dispose();
    vendorCtrl.dispose();
    modelCtrl.dispose();
    commissionedByCtrl.dispose();
    commissionedDateCtrl.dispose();
    wsUrlCtrl.dispose();
    BleService.instance.disconnect(widget.deviceId);
    super.dispose();
  }

  // ================= SAVE =================
  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      await BleService.instance.writeJson(widget.deviceId, {
        "serialNumber": serialCtrl.text.trim(),
        "chargerName": chargerNameCtrl.text.trim(),
        "chargePointVendor": vendorCtrl.text.trim(),
        "chargePointModel": modelCtrl.text.trim(),
        "commissionedBy": commissionedByCtrl.text.trim(),
        "commissionedDate": commissionedDateCtrl.text.trim(),
        "webSocketURL": wsUrlCtrl.text.trim(),
        "chargerType": chargerType,
      });

      await _loadDeviceState();
    } catch (e) {
      debugPrint("❌ SAVE ERROR: $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ================= UI HELPERS =================
  Widget _row(String label, Widget value) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(flex: 6, child: value),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _valueText(String text) {
    return Text(
      text.isEmpty ? "--" : text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _editable(TextEditingController c) {
    return TextField(controller: c);
  }

  // ================= BUILD =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("EVSE Configuration"),
        actions: [
          if (!_loading)
            IconButton(
              icon: Icon(editMode ? Icons.save : Icons.edit),
              onPressed: _saving
                  ? null
                  : () async {
                if (editMode) {
                  await _save();
                }
                if (mounted) setState(() => editMode = !editMode);
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              controller: _scrollController,
              children: [
                _row(
                  "Serial Number",
                  editMode ? _editable(serialCtrl) : _valueText(serial),
                ),
                _row(
                  "Charger Name",
                  editMode ? _editable(chargerNameCtrl) : _valueText(chargerName),
                ),
                _row(
                  "Vendor",
                  editMode ? _editable(vendorCtrl) : _valueText(vendor),
                ),
                _row(
                  "Model",
                  editMode ? _editable(modelCtrl) : _valueText(model),
                ),
                _row(
                  "Commissioned By",
                  editMode
                      ? _editable(commissionedByCtrl)
                      : _valueText(commissionedBy),
                ),
                _row(
                  "Commissioned Date",
                  editMode
                      ? _editable(commissionedDateCtrl)
                      : _valueText(commissionedDate),
                ),
                _row(
                  "WebSocket URL",
                  editMode ? _editable(wsUrlCtrl) : _valueText(webSocketURL),
                ),
                _row(
                  "Charger Type",
                  editMode
                      ? DropdownButton<String>(
                    value: chargerType,
                    isExpanded: true,
                    items: chargerTypes
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ))
                        .toList(),
                    onChanged: (v) => setState(() => chargerType = v!),
                  )
                      : _valueText(chargerType),
                ),
              ],
            ),
          if (_saving)
            const ColoredBox(
              color: Color.fromARGB(120, 0, 0, 0),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
