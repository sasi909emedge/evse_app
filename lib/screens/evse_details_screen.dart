import 'dart:async';
import 'dart:convert';
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

  StreamSubscription<List<int>>? _deviceSub;

  final serialCtrl = TextEditingController();
  final tempCtrl = TextEditingController();

  String chargingStatus = "Waiting for device...";
  bool editMode = false;
  bool _saving = false;

  // ================= INIT =================
  @override
  void initState() {
    super.initState();

    _deviceSub = BleService.instance
        .subscribeToDevice(widget.deviceId)
        .listen((data) {

      try {
        final jsonString = utf8.decode(data);
        final decoded = jsonDecode(jsonString);

        debugPrint("✅ DEVICE JSON: $decoded");

        setState(() {
          serialCtrl.text = decoded['serialNumber']?.toString() ?? "";
          tempCtrl.text = decoded['temperature']?.toString() ?? "";

          chargingStatus =
          "Serial: ${serialCtrl.text}\nTemp: ${tempCtrl.text}°C";
        });

      } catch (e) {
        debugPrint("JSON parse error: $e");
      }
    });
  }

  // ================= DISPOSE =================
  @override
  void dispose() {
    _deviceSub?.cancel();
    BleService.instance.disconnect();
    super.dispose();
  }

  // ================= SAVE =================
  Future<void> _save() async {

    if (!BleService.instance.isGattReady(widget.deviceId)) {
      _showError("BLE not ready");
      return;
    }

    setState(() => _saving = true);

    try {

      await BleService.instance.writeJson(
        widget.deviceId,
        {
          "temperature": int.tryParse(tempCtrl.text) ?? 0,
          "serialNumber": serialCtrl.text,
        },
      );

      _showMessage("Device updated successfully");

    } catch (e) {
      _showError("Write failed: $e");
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ================= UI HELPERS =================
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"))
        ],
      ),
    );
  }

  Widget _field(String label, Widget child) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        title: Text(label),
        subtitle: child,
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text("EVSE Device"),
        actions: [
          IconButton(
            icon: Icon(editMode ? Icons.save : Icons.edit),
            onPressed: () async {
              if (editMode) {
                await _save();
              }
              setState(() => editMode = !editMode);
            },
          )
        ],
      ),
      body: Stack(
        children: [
          ListView(
            children: [

              _field(
                "Device Status",
                Text(
                  chargingStatus,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              _field(
                "Serial Number",
                editMode
                    ? TextField(controller: serialCtrl)
                    : Text(serialCtrl.text),
              ),

              _field(
                "Temperature",
                editMode
                    ? TextField(
                  controller: tempCtrl,
                  keyboardType: TextInputType.number,
                )
                    : Text("${tempCtrl.text} °C"),
              ),

              const SizedBox(height: 100),
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