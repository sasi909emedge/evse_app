import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../ble/ble_service_base.dart';
import '../ble/ble_service_selector.dart';
import 'evse_details_screen.dart';
import '../theme/app_colors.dart';
import '../main.dart';
import 'package:permission_handler/permission_handler.dart';

// EMEDGE devices are prioritized in the scan list
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
      _selected = null;
      _scanning = true;
    });
    _pulse.repeat(reverse: true);

    _scanSub = BleService.instance.scanDevices().listen((d) {
      if (d.name.isEmpty) return;
      if (_devices.any((x) => x.id == d.id)) return;
      if (mounted) {
        setState(() {
          _devices.add(d);
          // EMEDGE devices float to the top; others keep discovery order.
          _devices.sort((a, b) {
            final aE = a.name.toUpperCase().startsWith(_kAllowedPrefix);
            final bE = b.name.toUpperCase().startsWith(_kAllowedPrefix);
            if (aE == bE) return 0;
            return aE ? -1 : 1;
          });
        });
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

          // Check whether the connected device is an EMEDGE charger.
          if (!BleService.instance.isGattReady(id)) {
            debugPrint("❌ Selected device is not an EMEDGE charger");

            BleService.instance.disconnect(id);

            if (!mounted) return;
            Navigator.pop(context);
            _snack("Not an EMEDGE Charger", err: true);
            return;
          }

          if (!mounted) return;
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EvseDetailsScreen(deviceId: id),
            ),
          );
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
      backgroundColor: const Color(0xFF08141D),
      appBar: widget.fromMenu
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF08141D),
              elevation: 0,
              toolbarHeight: 72,
              automaticallyImplyLeading: false,
              titleSpacing: 18,
              title: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF112532),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.bluetooth_searching_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      "SCAN",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: const Color(0xFF1B3344),
                    child: Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF08141D),
              Color(0xFF0D1C26),
              Color(0xFF08141D),
            ],
          ),
        ),
        child: SafeArea(
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
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.12),
                              width: 1),
                        ),
                      ),
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.22),
                              width: 1.5),
                        ),
                      ),
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(.45),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
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
                  _scanning ? "Scanning for Chargers" : "Start BLE Scan",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  _scanning
                      ? "Looking for nearby BLE devices..."
                      : "Shows all nearby BLE devices",
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
                                  "${_devices.length} device"
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    disabledBackgroundColor: const Color(0xFF243544),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "CONNECT",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF132733) : const Color(0xFF101B24),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFF1F3443),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFF18303E),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.ev_station_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(device.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 2),
              Text(
                device.id,
                style: const TextStyle(
                  color: Color(0xFF90A0AD),
                  fontSize: 10,
                ),
              ),
            ]),
          ),
          Builder(builder: (_) {
            final isEmedge = device.name.toUpperCase().startsWith('EMEDGE');
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isEmedge
                    ? const Color(0xFF173A31)
                    : const Color(0xFF2A2F36),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isEmedge ? "EMEDGE" : "OTHER",
                style: TextStyle(
                  color: isEmedge
                      ? const Color(0xFF4BE47E)
                      : const Color(0xFFB0B8C1),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            );
          }),
          if (selected) ...[
            const SizedBox(width: 8),
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 18,
                color: Colors.white,
              ),
            ),
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
