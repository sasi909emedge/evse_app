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

  final serialCtrl = TextEditingController();
  final chargerNameCtrl = TextEditingController();
  final vendorCtrl = TextEditingController();
  final modelCtrl = TextEditingController();
  final commissionedByCtrl = TextEditingController();
  final commissionedDateCtrl = TextEditingController();
  final wsUrlCtrl = TextEditingController();

  String chargerType = "AC1";

  bool editMode = false;
  bool _saving = false;
  bool _loading = true;

  final List<String> chargerTypes = [
    "AC1","AC2","AC3","DC1","DC2","DC3"
  ];

  // ================= LOAD =================
  Future<void> _loadDeviceState() async {

    try {

      /// Wait until BLE is actually ready
      int retry = 0;

      while (!BleService.instance.isGattReady(widget.deviceId)) {
        await Future.delayed(const Duration(milliseconds: 250));
        retry++;

        if (retry > 12) {
          throw Exception("BLE not ready");
        }
      }

      final data =
      await BleService.instance.readJson(widget.deviceId);

      if (!mounted) return;

      setState(() {

        serialCtrl.text = data['serialNumber'] ?? "";
        chargerNameCtrl.text = data['chargerName'] ?? "";
        vendorCtrl.text = data['chargePointVendor'] ?? "";
        modelCtrl.text = data['chargePointModel'] ?? "";
        commissionedByCtrl.text = data['commissionedBy'] ?? "";
        commissionedDateCtrl.text = data['commissionedDate'] ?? "";
        wsUrlCtrl.text = data['webSocketURL'] ?? "";
        chargerType = data['chargerType'] ?? "AC1";

        _loading = false;
      });

    } catch (e) {

      debugPrint("READ failed: $e");

      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    /// Start immediately — no random delays
    _loadDeviceState();
  }

  @override
  void dispose() {

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

      await _loadDeviceState();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Configuration updated")),
      );

    } catch (e) {

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error"),
          content: Text("$e"),
        ),
      );

    } finally {

      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _field(String label, Widget child) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold)),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      /// Critical for keyboard
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

      body: Column(
        children: [

          /// Loader prevents blank UI
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 12,
                  bottom:
                  MediaQuery.of(context).viewInsets.bottom + 30,
                ),
                child: Column(
                  children: [

                    _field("Serial Number",
                        editMode
                            ? TextField(controller: serialCtrl)
                            : Text(serialCtrl.text)),

                    _field("Charger Name",
                        editMode
                            ? TextField(controller: chargerNameCtrl)
                            : Text(chargerNameCtrl.text)),

                    _field("Vendor",
                        editMode
                            ? TextField(controller: vendorCtrl)
                            : Text(vendorCtrl.text)),

                    _field("Model",
                        editMode
                            ? TextField(controller: modelCtrl)
                            : Text(modelCtrl.text)),

                    _field("Commissioned By",
                        editMode
                            ? TextField(controller: commissionedByCtrl)
                            : Text(commissionedByCtrl.text)),

                    _field("Commissioned Date",
                        editMode
                            ? TextField(controller: commissionedDateCtrl)
                            : Text(commissionedDateCtrl.text)),

                    _field("WebSocket URL",
                        editMode
                            ? TextField(controller: wsUrlCtrl)
                            : Text(wsUrlCtrl.text)),

                    _field("Charger Type",
                        editMode
                            ? DropdownButton<String>(
                          value: chargerType,
                          isExpanded: true,
                          items: chargerTypes
                              .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(t),
                          ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => chargerType = v!),
                        )
                            : Text(chargerType)),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

          /// Saving overlay
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