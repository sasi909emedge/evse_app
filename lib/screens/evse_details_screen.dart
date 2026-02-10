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

  String chargingStatus = "Connecting to device...";
  bool editMode = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _startListening();
  }

  void _startListening() async {
    /// Wait until GATT is ready
    while (!BleService.instance.isGattReady(widget.deviceId)) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    _deviceSub = BleService.instance
        .subscribeToDevice(widget.deviceId)
        .listen((data) {
      try {
        final decoded = jsonDecode(utf8.decode(data));

        debugPrint("✅ DEVICE JSON: $decoded");

        if (!mounted) return;

        setState(() {
          serialCtrl.text = decoded['serialNumber']?.toString() ?? "";
          tempCtrl.text = decoded['temperature']?.toString() ?? "";

          chargingStatus = "Connected ✅";
        });

      } catch (e) {
        debugPrint("JSON parse error: $e");
      }
    });
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    BleService.instance.disconnect(widget.deviceId);
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      await BleService.instance.writeJson(
        widget.deviceId,
        {
          "temperature": int.tryParse(tempCtrl.text) ?? 0,
          "serialNumber": serialCtrl.text,
        },
      );

      _showMessage("Saved to device ✅");

    } catch (e) {
      _showError("Write failed: $e");
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

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
            child: const Text("OK"),
          )
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