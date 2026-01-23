import 'dart:async';
import 'ble_protocol.dart';

class BleSimulator {
  final StreamController<List<int>> _controller = StreamController<List<int>>.broadcast();
  Timer? _timer;

  Stream<List<int>> get stream => _controller.stream;

  void start() {
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      final packet = [
        BleProtocol.version,
        BleProtocol.typeStatus,
        BleProtocol.statusCharging,
        _checksum([
          BleProtocol.version,
          BleProtocol.typeStatus,
          BleProtocol.statusCharging,
        ]),
      ];
      _controller.add(packet);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  int _checksum(List<int> data) => data.reduce((a, b) => a + b) & 0xFF;
}

