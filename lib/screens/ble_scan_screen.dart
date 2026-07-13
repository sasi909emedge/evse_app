import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../ble/ble_service_base.dart';
import '../ble/ble_service_selector.dart';
import 'evse_details_screen.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import 'package:permission_handler/permission_handler.dart';

// Only EMEDGE chargers are allowed
const String _kAllowedPrefix = 'EMEDGE';

class BleScanScreen extends StatefulWidget {
  final bool fromMenu;
  const BleScanScreen({super.key, this.fromMenu = false});

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen>
    with SingleTickerProviderStateMixin {
  final List<BleDevice> _devices = [];
  int _hiddenCount = 0;

  StreamSubscription<BleDevice>? _scanSub;
  StreamSubscription<BleConnectionState>? _connSub;
  Timer? _scanTimer;
  Timer? _connTimer;
  bool _scanning = false;
  BleDevice? _selected;

  late AnimationController _pulse;
  late Animation<double> _anim;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? AppColors.backgroundDark : AppColors.background;
  Color get _surface => _isDark ? AppColors.surfaceDark : AppColors.surface;
  Color get _textPrimary =>
      _isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  Color get _textSecondary =>
      _isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  Color get _border => _isDark ? AppColors.borderDark : AppColors.border;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 1.0, end: 1.13)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    _scanTimer?.cancel();
    _connTimer?.cancel();
    _scanSub?.cancel();
    _connSub?.cancel();
    super.dispose();
  }

  Future<bool> _permissions() async {
    if (Platform.isWindows) return true;
    final s = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    return s.values.every((v) => v.isGranted);
  }

  Future<void> _scan() async {
    if (!await _permissions()) return;
    await _scanSub?.cancel();
    _scanTimer?.cancel();
    setState(() {
      _devices.clear();
      _hiddenCount = 0;
      _selected = null;
      _scanning = true;
    });
    _pulse.repeat(reverse: true);

    _scanSub = BleService.instance.scanDevices().listen((d) {
      if (d.name.isEmpty) return;
      final isEmedge = d.name.toUpperCase().startsWith(_kAllowedPrefix);
      if (isEmedge) {
        if (!_devices.any((x) => x.id == d.id)) {
          if (mounted) setState(() => _devices.add(d));
        }
      } else {
        if (mounted) setState(() => _hiddenCount++);
      }
    }, onError: (_) => _stopScan());

    _scanTimer = Timer(const Duration(seconds: 10), _stopScan);
  }

  void _stopScan() {
    _scanSub?.cancel();
    _pulse.stop();
    _pulse.reset();
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _connect() async {
    if (_selected == null) return;
    final id = _selected!.id;
    final name = _selected!.name;
    _stopScan();
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConnDialog(name: name),
    );

    await _connSub?.cancel();
    _connTimer?.cancel();
    _connTimer = Timer(const Duration(seconds: 15), () async {
      await _connSub?.cancel();
      BleService.instance.disconnect(id);
      if (!mounted) return;
      Navigator.pop(context);
      _snack("Connection timed out", err: true);
    });

    _connSub = BleService.instance.connectToDevice(id).listen((s) async {
      if (s == BleConnectionState.connected) {
        _connTimer?.cancel();
        try {
          await BleService.instance.discoverServices(id);
          if (!mounted) return;
          Navigator.pop(context);
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EvseDetailsScreen(deviceId: id)));
        } catch (e) {
          _connTimer?.cancel();
          await _connSub?.cancel();
          if (!mounted) return;
          Navigator.pop(context);
          _snack("Failed: $e", err: true);
        }
      } else if (s == BleConnectionState.disconnected) {
        _connTimer?.cancel();
        if (!mounted) return;
        Navigator.pop(context);
        _snack("Disconnected", err: true);
      }
    });
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: err ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: widget.fromMenu
          ? null
          : AppBar(
              backgroundColor: _surface,
              title: Column(children: [
                const Text("EMEDGE",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.5)),
                Text("MASTERCONTROLLER",
                    style: TextStyle(
                        fontSize: 9, color: _textSecondary, letterSpacing: 2)),
              ]),
              actions: [
                IconButton(
                  icon: Icon(
                      _isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      size: 20,
                      color: _textSecondary),
                  onPressed: () => EVSEApp.of(context)?.toggleTheme(),
                ),
              ],
            ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Column(children: [
              const SizedBox(height: 32),

              // Animated scan button
              GestureDetector(
                onTap: _scanning ? null : _scan,
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (_, child) => Transform.scale(
                      scale: _scanning ? _anim.value : 1.0, child: child),
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.12),
                            width: 1),
                      ),
                    ),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.22),
                            width: 1.5),
                      ),
                    ),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: AppColors.primary),
                      child: Icon(
                        _scanning
                            ? Icons.bluetooth_searching_rounded
                            : Icons.bluetooth_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 14),
              Text(
                _scanning ? "Scanning..." : "Tap to scan",
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    letterSpacing: 0.4),
              ),
              Text(
                _scanning
                    ? "Looking for EMEDGE chargers..."
                    : "Shows EMEDGE chargers only",
                style: TextStyle(fontSize: 11, color: _textSecondary),
              ),

              const SizedBox(height: 20),

              // Device list
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _devices.isEmpty
                      ? _empty()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                "${_devices.length} EMEDGE charger"
                                "${_devices.length > 1 ? 's' : ''} found",
                                style: TextStyle(
                                    fontSize: 11,
                                    color: _textSecondary,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _devices.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (_, i) => _Tile(
                                  device: _devices[i],
                                  selected: _selected?.id == _devices[i].id,
                                  onTap: () =>
                                      setState(() => _selected = _devices[i]),
                                ),
                              ),
                            ),
                            if (_hiddenCount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 13, color: _textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    "$_hiddenCount non-EMEDGE device"
                                    "${_hiddenCount > 1 ? 's' : ''} hidden",
                                    style: TextStyle(
                                        fontSize: 10, color: _textSecondary),
                                  ),
                                ]),
                              ),
                          ],
                        ),
                ),
              ),
            ]),
          ),

          // Connect button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _selected == null ? null : _connect,
                style: ElevatedButton.styleFrom(
                  disabledBackgroundColor:
                      _isDark ? AppColors.borderDark : AppColors.border,
                ),
                child: const Text("Connect"),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _empty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            _scanning
                ? Icons.bluetooth_searching_rounded
                : Icons.bluetooth_disabled_rounded,
            size: 48,
            color: _isDark ? AppColors.textHintDark : AppColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(_scanning ? "Searching..." : "No chargers found",
              style: TextStyle(fontSize: 14, color: _textSecondary)),
          const SizedBox(height: 4),
          Text(
            _scanning
                ? "Make sure charger is powered on"
                : "Tap the button above to scan",
            style: TextStyle(fontSize: 11, color: _textSecondary),
          ),
        ]),
      );
}

// ── Device Tile ───────────────────────────────────────────────────
class _Tile extends StatelessWidget {
  final BleDevice device;
  final bool selected;
  final VoidCallback onTap;
  const _Tile(
      {required this.device, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(isDark ? 0.12 : 0.07)
              : (isDark ? AppColors.surfaceDark : AppColors.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.border),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.ev_station_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(device.name,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(device.id,
                  style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text("EMEDGE",
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success)),
          ),
          if (selected) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded,
                color: AppColors.primary, size: 20),
          ],
        ]),
      ),
    );
  }
}

// ── Connecting Dialog ─────────────────────────────────────────────
class _ConnDialog extends StatelessWidget {
  final String name;
  const _ConnDialog({required this.name});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text("Connecting...",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(name,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
