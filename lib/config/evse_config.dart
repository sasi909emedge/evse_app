import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class EVSEConfig {
  // ── Service UUID — 0x180A (16-bit, Device Information Service) ──
  static final Uuid serviceUuid =
      Uuid.parse('ed8ab937-571f-4dfd-a081-35b4f2243358');

  // ── Write + Notify Characteristic (SAME UUID) ───────────────────
  // Company uses one characteristic for both write and notify
  static final Uuid writeCharUuid =
      Uuid.parse('fb349b5f-8000-0080-0010-000000002000');

  // ── Read characteristic — NOT USED for now, kept for future ─────
  // static final Uuid readCharUuid =
  //     Uuid.parse('fb349b5f-8000-0080-0010-000000001000');

  // ── Notify — SAME as write characteristic ───────────────────────
  static Uuid get notifyCharUuid => writeCharUuid;

  // ── Service UUID helpers ─────────────────────────────────────────
  static Uuid get writeServiceUuid => serviceUuid;
  static Uuid get notifyServiceUuid => serviceUuid;
}
