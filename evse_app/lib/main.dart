import 'package:flutter/material.dart';
import 'screens/ble_scan_screen.dart';

void main() {
  runApp(const EVSEApp());
}

class EVSEApp extends StatelessWidget {
  const EVSEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EMEDGE MICROCONTROLLER',
      theme: ThemeData(useMaterial3: true),
      home: const BleScanScreen(),
    );
  }
}
