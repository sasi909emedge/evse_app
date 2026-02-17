import 'package:flutter/material.dart';
import '../ble/ble_service.dart';
import '../theme/app_colors.dart';

class EvseDetailsScreen extends StatefulWidget {
  final String deviceId;

  const EvseDetailsScreen({super.key, required this.deviceId});

  @override
  State<EvseDetailsScreen> createState() => _EvseDetailsScreenState();
}

class _EvseDetailsScreenState extends State<EvseDetailsScreen>
    with WidgetsBindingObserver {

  final _scrollController = ScrollController();

  // ================= CONTROLLERS =================
  final serialCtrl = TextEditingController();
  final chargerNameCtrl = TextEditingController();
  final vendorCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final commissionedByCtrl = TextEditingController();
  final commissionedDateCtrl = TextEditingController();
  final wsUrlCtrl = TextEditingController();

  // ================= DISPLAY STATE =================
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

  /// ⭐ CRITICAL — prevents multiple BLE reads
  bool _isLoadingFromBle = false;
  bool _initialLoadDone = false;

  final chargerTypes = [
    "AC1","AC2","AC3","DC1","DC2","DC3"
  ];

  // ================= SAFE LOAD =================
  Future<void> _loadDeviceState({bool force = false}) async {

    /// prevent duplicate reads
    if (_isLoadingFromBle) return;
    if (_initialLoadDone && !force) return;

    _isLoadingFromBle = true;

    try {

      while (!BleService.instance.isGattReady(widget.deviceId)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      final data =
      await BleService.instance.readJson(widget.deviceId);

      if (!mounted) return;

      setState(() {

        serial = data['serialNumber'] ?? "";
        chargerName = data['chargerName'] ?? "";
        vendor = data['chargePointVendor'] ?? "";
        model = data['chargePointModel'] ?? "";
        commissionedBy = data['commissionedBy'] ?? "";
        commissionedDate = data['commissionedDate'] ?? "";
        webSocketURL = data['webSocketURL'] ?? "";
        chargerType = data['chargerType'] ?? "AC1";

        /// sync editors
        serialCtrl.text = serial;
        chargerNameCtrl.text = chargerName;
        vendorCtrl.text = vendor;
        modelCtrl.text = model;
        commissionedByCtrl.text = commissionedBy;
        commissionedDateCtrl.text = commissionedDate;
        wsUrlCtrl.text = webSocketURL;

        _loading = false;
        _initialLoadDone = true;
      });

    } catch (e) {
      debugPrint("LOAD ERROR: $e");
      if (mounted) setState(() => _loading = false);
    } finally {
      _isLoadingFromBle = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    /// run AFTER first frame (stable BLE timing)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeviceState();
    });
  }

  // ================= KEYBOARD AUTO SCROLL =================
  @override
  void didChangeMetrics() {
    final bottomInset =
        WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;

    if (bottomInset > 0 && _scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 250), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    BleService.instance.disconnect(widget.deviceId);
    super.dispose();
  }

  // ================= SAVE =================
  Future<void> _save() async {

    setState(() => _saving = true);

    await BleService.instance.writeJson(
      widget.deviceId,
      {
        "serialNumber": serialCtrl.text.trim(),
        "chargerName": chargerNameCtrl.text.trim(),
        "chargePointVendor": vendorCtrl.text.trim(),
        "chargePointModel": modelCtrl.text.trim(),
        "commissionedBy": commissionedByCtrl.text.trim(),
        "commissionedDate": commissionedDateCtrl.text.trim(),
        "webSocketURL": wsUrlCtrl.text.trim(),
        "chargerType": chargerType,
      },
    );

    /// force single refresh after save
    await _loadDeviceState(force: true);

    if (!mounted) return;

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Configuration updated")),
    );
  }

  Widget _editable(TextEditingController c) =>
      TextField(controller: c);

  Widget _field(String label, Widget child) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text("EVSE Configuration"),
        actions: [
          IconButton(
            icon: Icon(editMode ? Icons.save : Icons.edit),
            onPressed: () async {
              if (editMode) await _save();
              setState(() => editMode = !editMode);
            },
          )
        ],
      ),

      body: Stack(
        children: [

          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                  12, 12, 12,
                  MediaQuery.of(context).viewInsets.bottom + 80),
              child: Column(
                children: [

                  _field("Serial Number",
                      editMode ? _editable(serialCtrl)
                          : Text(serial)),

                  _field("Charger Name",
                      editMode ? _editable(chargerNameCtrl)
                          : Text(chargerName)),

                  _field("Vendor",
                      editMode ? _editable(vendorCtrl)
                          : Text(vendor)),

                  _field("Model",
                      editMode ? _editable(modelCtrl)
                          : Text(model)),

                  _field("Commissioned By",
                      editMode ? _editable(commissionedByCtrl)
                          : Text(commissionedBy)),

                  _field("Commissioned Date",
                      editMode ? _editable(commissionedDateCtrl)
                          : Text(commissionedDate)),

                  _field("WebSocket URL",
                      editMode ? _editable(wsUrlCtrl)
                          : Text(webSocketURL)),

                  _field("Charger Type",
                      editMode
                          ? DropdownButton<String>(
                        value: chargerType,
                        isExpanded: true,
                        items: chargerTypes
                            .map((t) => DropdownMenuItem(
                            value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => chargerType = v!),
                      )
                          : Text(chargerType)),

                  const SizedBox(height: 120),
                ],
              ),
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