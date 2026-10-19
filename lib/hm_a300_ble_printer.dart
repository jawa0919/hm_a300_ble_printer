import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'src/messages.g.dart';

class HmA300BlePrinter extends HmA300BlePrinterFlutterApi {
  static const _channel = MethodChannel('hm_a300_ble_printer');
  Future<String?> getPlatformVersion() async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  Future<String> runningInfo() async {
    return await HmA300BlePrinterHostApi().getRunningInfoAsync();
  }

  @override
  Future<String> getDartVersionAsync() async {
    return "Dart ${Platform.version.split(" ").first}";
  }

  HmA300BlePrinter._internal() {
    HmA300BlePrinterFlutterApi.setUp(this);
  }
  static final HmA300BlePrinter _singleton = HmA300BlePrinter._internal();

  factory HmA300BlePrinter() => _singleton;
  static HmA300BlePrinter get instance => _singleton;
  static HmA300BlePrinter getInstance() => _singleton;
}
