import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'hm_a300_ble_printer_method_channel.dart';

abstract class HmA300BlePrinterPlatform extends PlatformInterface {
  /// Constructs a HmA300BlePrinterPlatform.
  HmA300BlePrinterPlatform() : super(token: _token);

  static final Object _token = Object();

  static HmA300BlePrinterPlatform _instance = MethodChannelHmA300BlePrinter();

  /// The default instance of [HmA300BlePrinterPlatform] to use.
  ///
  /// Defaults to [MethodChannelHmA300BlePrinter].
  static HmA300BlePrinterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [HmA300BlePrinterPlatform] when
  /// they register themselves.
  static set instance(HmA300BlePrinterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
