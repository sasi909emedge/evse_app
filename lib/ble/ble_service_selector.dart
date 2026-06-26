import 'dart:io';
import 'ble_service_base.dart';
import 'ble_service_mobile.dart';
import 'ble_service_windows.dart';

// ================================================================
// BLE SERVICE SELECTOR
// Automatically picks the right implementation based on platform.
// All screens use this — they never import mobile or windows directly.
// ================================================================
class BleService {
  BleService._();

  static BleServiceBase? _instance;

  static BleServiceBase get instance {
    _instance ??= Platform.isWindows
        ? BleServiceWindows.instance
        : BleServiceMobile.instance;
    return _instance!;
  }

  // Call once in main() before runApp()
  static Future<void> initialize() async {
    if (Platform.isWindows) {
      await BleServiceWindows.initialize();
    }
    // Mobile needs no initialization
  }
}
