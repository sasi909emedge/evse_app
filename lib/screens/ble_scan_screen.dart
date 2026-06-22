import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ble/ble_service.dart';
import '../config/evse_config.dart';
import 'evse_details_screen.dart';
import '../theme/app_colors.dart';

class BleScanScreen extends StatefulWidget {
  const BleScanScreen({super.key});

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen> {
  final List<DiscoveredDevice> _devices = [];
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connSub;
  Timer? _scanTimer;
  Timer? _connectionTimer;
  bool _isScanning = false;
  DiscoveredDevice? _selectedDevice;

  // ================= CLEANUP =================
  @override
  void dispose() {
    _scanTimer?.cancel();
    _connectionTimer?.cancel();
    _scanSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  // ================= PERMISSIONS =================
  Future<bool> _ensureBlePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((s) => s.isGranted);
  }

  // ================= SCAN =================
  Future<void> _startScan() async {
    final granted = await _ensureBlePermissions();
    if (!granted) return;

    await _scanSub?.cancel();
    _scanTimer?.cancel();

    setState(() {
      _devices.clear();
      _selectedDevice = null;
      _isScanning = true;
    });

    _scanSub = BleService.instance.scanDevices().listen(
      (device) {
        if (!_devices.any((d) => d.id == device.id)) {
          if (mounted) {
            setState(() {
              _devices.add(device);
            });
          }
        }
      },
      onError: (e) {
        debugPrint("BLE scan error $e");

        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      },
    );

    _scanTimer = Timer(
      const Duration(seconds: 10),
      () async {
        await _scanSub?.cancel();

        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      },
    );
  }

  // ================= CONNECT =================
  Future<void> _connectSelectedDevice() async {
    if (_selectedDevice == null) return;

    final deviceId = _selectedDevice!.id;

    await _scanSub?.cancel();

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    await _connSub?.cancel();

    _connectionTimer?.cancel();
    _connectionTimer = Timer(
      const Duration(seconds: 10),
      () async {
        await _connSub?.cancel();

        BleService.instance.disconnect(deviceId);

        if (!mounted) return;

        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Connection Timeout",
            ),
          ),
        );
      },
    );

    _connSub =
        BleService.instance.connectToDevice(deviceId).listen((update) async {
      if (update.connectionState == DeviceConnectionState.connected) {
        _connectionTimer?.cancel();

        try {
          await Future.delayed(
            const Duration(milliseconds: 500),
          );

          await BleService.instance.discoverServices(deviceId);

          final services = await FlutterReactiveBle().getDiscoveredServices(
            deviceId,
          );

          final validDevice = services.any(
            (s) =>
                s.id == EVSEConfig.readServiceUuid ||
                s.id == EVSEConfig.writeServiceUuid,
          );

          if (!validDevice) {
            await _connSub?.cancel();

            BleService.instance.disconnect(deviceId);

            if (!mounted) return;

            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Not an EMC Charger Device",
                ),
              ),
            );

            return;
          }

          if (!mounted) return;

          Navigator.pop(context);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EvseDetailsScreen(
                deviceId: deviceId,
              ),
            ),
          );
        } catch (e) {
          _connectionTimer?.cancel();

          await _connSub?.cancel();

          if (!mounted) return;

          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Connection failed: $e",
              ),
            ),
          );
        }
      }
    });
  }

  // ================= DEVICE TILE =================
  Widget _deviceTile(DiscoveredDevice d) {
    final selected = _selectedDevice?.id == d.id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: Icon(
            Icons.ev_station_rounded,
            size: 28,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          title: Text(
            d.name.isEmpty ? "Unknown Device" : d.name,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            d.id,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          trailing: selected
              ? const Icon(Icons.check_circle, color: AppColors.primary)
              : null,
          onTap: () => setState(() => _selectedDevice = d),
        ),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "EMEDGE",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "MASTERCONTROLLER",
              style: TextStyle(
                fontSize: 13,
                letterSpacing: 1.2,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          // ===== SCAN BUTTON =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.search),
                label: Text(
                  _isScanning ? "Scanning..." : "Scan Devices",
                ),
                onPressed: _isScanning ? null : _startScan,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ===== DEVICE LIST =====
          Expanded(
            child: _devices.isEmpty
                ? const Center(
                    child: Text(
                      "No EVSE devices found",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (_, i) => _deviceTile(_devices[i]),
                  ),
          ),

          // ===== CONNECT BUTTON =====
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _selectedDevice == null ? null : _connectSelectedDevice,
                child: const Text("Connect"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
