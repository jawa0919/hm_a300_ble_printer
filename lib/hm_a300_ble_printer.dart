import 'package:flutter/services.dart';

class HmA300BlePrinter {
  static const _channel = MethodChannel('hm_a300_ble_printer');
  Future<String?> getPlatformVersion() async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
