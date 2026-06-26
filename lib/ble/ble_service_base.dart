import 'dart:async';

// ================================================================
// ABSTRACT BLE SERVICE
// All platform implementations must implement this interface.
// Screen code only talks to this — never to platform directly.
// ================================================================
abstract class BleServiceBase {
  // ── Scan ────────────────────────────────────────────────────
  // Emits discovered devices as [BleDevice] objects
  Stream<BleDevice> scanDevices();

  // ── Connect ─────────────────────────────────────────────────
  // Emits [BleConnectionState] updates
  Stream<BleConnectionState> connectToDevice(String deviceId);

  // ── Discover ─────────────────────────────────────────────────
  Future<void> discoverServices(String deviceId);

  // ── GATT Ready ───────────────────────────────────────────────
  bool isGattReady(String deviceId);

  // ── Read JSON ────────────────────────────────────────────────
  Future<Map<String, dynamic>> readJson(String deviceId);

  // ── Write JSON ───────────────────────────────────────────────
  Future<void> writeJson(String deviceId, Map<String, dynamic> json);

  // ── Send Command ─────────────────────────────────────────────
  Future<void> sendCommand(String deviceId, String command);

  // ── Disconnect ───────────────────────────────────────────────
  void disconnect(String deviceId);

  // ── Clear State ──────────────────────────────────────────────
  void clearGattState(String deviceId);
}

// ================================================================
// CROSS-PLATFORM DEVICE MODEL
// Replaces flutter_reactive_ble's DiscoveredDevice on all platforms
// ================================================================
class BleDevice {
  final String id;
  final String name;
  final int rssi;

  const BleDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });
}

// ================================================================
// CROSS-PLATFORM CONNECTION STATE
// ================================================================
enum BleConnectionState {
  connecting,
  connected,
  disconnecting,
  disconnected,
}
