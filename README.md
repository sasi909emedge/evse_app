# EMEDGE Master Controller – EVSE BLE Application

## Overview
EMEDGE Master Controller is a Flutter-based mobile application developed for configuring and monitoring EVSE (Electric Vehicle Supply Equipment) devices using Bluetooth Low Energy (BLE).

The application connects directly to an EVSE controller powered by ESP32 NimBLE firmware and enables configuration management through JSON-based BLE communication.

---

## Project Goals
- Reliable BLE device discovery and connection
- Stable GATT service discovery
- JSON configuration read and write
- Modern and responsive configuration UI
- Production-ready BLE pipeline

---

## Implemented Features

### BLE Communication
- Device scanning using `flutter_reactive_ble`
- Direct BLE connection handling
- Automatic service discovery
- MTU negotiation (247 bytes)
- Serialized BLE operation queue (prevents collisions)
- Stable JSON read/write communication

---

### EVSE Configuration Management

The application reads and updates:

- Serial Number
- Charger Name
- Charge Point Vendor
- Charge Point Model
- Commissioned By
- Commissioned Date
- WebSocket URL
- Charger Type

---

### User Interface
- Tesla-inspired clean configuration layout
- Improved readability and spacing
- Two-line branded header UI
- Modern color theme implementation
- Stable navigation and loading handling

---

## Application Architecture

Flutter UI
↓
BleService (Queued BLE Operations)
↓
flutter_reactive_ble
↓
ESP32 NimBLE Firmware

yaml
Copy code

---

## BLE Services

### Device Read Service
Service UUID: fb349b5f-8000-0080-0010-000000100000
Characteristic UUID: fb349b5f-8000-0080-0010-000001100000

shell
Copy code

### Device Write Service
Service UUID: fb349b5f-8000-0080-0010-000000200000
Characteristic UUID: fb349b5f-8000-0080-0010-000001200000

yaml
Copy code

---

## Current Known Issue (Firmware Payload)

BLE communication and application pipeline are verified working.

Current firmware response returns:

{"temp":25.5}

pgsql
Copy code

instead of expected EVSE configuration JSON:

{
"serialNumber": "...",
"chargerName": "...",
...
}

yaml
Copy code

Because configuration fields are not present in the payload, values are not displayed in the application UI.

### Required Firmware Action
Firmware must restore configuration JSON response on the Device Read characteristic.

No application-side modification is required.

---

## Repository Structure

lib/
├── ble/
│ └── ble_service.dart
├── config/
│ └── evse_config.dart
├── screens/
│ ├── ble_scan_screen.dart
│ └── evse_details_screen.dart
└── theme/
└── app_colors.dart

yaml
Copy code

---

## Technology Stack
- Flutter
- Dart
- flutter_reactive_ble
- ESP32 NimBLE BLE Stack

---

## Project Status

✅ BLE pipeline completed  
✅ UI modernization completed  
✅ Stable configuration workflow implemented  
⚠ Awaiting firmware payload alignment

---

## Developed By
EMEDGE Systems Pvt. Ltd.


