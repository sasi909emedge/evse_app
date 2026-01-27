import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ble/ble_service.dart';
import '../screens/evse_details_screen.dart';
import '../theme/app_colors.dart';

class BleScanScreen extends StatefulWidget {
  const BleScanScreen({super.key});

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen> {
  final List<DiscoveredDevice> _devices = [];
  StreamSubscription<DiscoveredDevice>? _scanSub;

  bool _isScanning = false;
  DiscoveredDevice? _selectedDevice;

  @override
  void dispose() {
    _scanSub?.cancel();
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

  // ================= BLE SCAN =================
  Future<void> _startScan() async {
    final granted = await _ensureBlePermissions();
    if (!granted) return;

    await _scanSub?.cancel();

    setState(() {
      _devices.clear();
      _selectedDevice = null;
      _isScanning = true;
    });

    _scanSub = BleService.instance.scanDevices().listen((device) {
      final exists = _devices.any((d) => d.id == device.id);
      if (!exists && mounted) {
        setState(() => _devices.add(device));
      }
    });
  }

  // ================= BLE CONNECT (FINAL FIX) =================
  Future<void> _connectSelectedDevice() async {
    if (_selectedDevice == null) return;

    final deviceId = _selectedDevice!.id;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final connectionStream =
      BleService.instance.connectToDevice(deviceId);

      // 🔑 WAIT FOR REAL CONNECTION
      await connectionStream.firstWhere(
            (update) =>
        update.connectionState == DeviceConnectionState.connected,
      );

      if (!mounted) return;
      Navigator.pop(context);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EvseDetailsScreen(deviceId: deviceId),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect')),
      );
    }
  }

  // ================= DEVICE TILE =================
  Widget _deviceTile(DiscoveredDevice d) {
    final selected = _selectedDevice?.id == d.id;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(
          Icons.bluetooth,
          color: selected ? AppColors.primary : Colors.blue,
        ),
        title: Text(
          d.name.isEmpty ? 'EVSE Device' : d.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(d.id),
        onTap: () => setState(() => _selectedDevice = d),
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'EMEDGE\nMASTERCONTROLLER',
          textAlign: TextAlign.center,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: Text(_isScanning ? 'Scanning…' : 'Scan BLE Devices'),
            onPressed: _isScanning ? null : _startScan,
          ),
          const Divider(),
          Expanded(
            child: _devices.isEmpty
                ? const Center(child: Text('No EVSE devices found'))
                : ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (_, i) => _deviceTile(_devices[i]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed:
              _selectedDevice == null ? null : _connectSelectedDevice,
              child: const Text('Connect to Selected Device'),
            ),
          ),
        ],
      ),
    );
  }
}