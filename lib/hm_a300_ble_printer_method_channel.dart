import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hm_a300_ble_printer_platform_interface.dart';

/// An implementation of [HmA300BlePrinterPlatform] that uses method channels.
class MethodChannelHmA300BlePrinter extends HmA300BlePrinterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('hm_a300_ble_printer');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
