import 'dart:io';

import '../src/messages.g.dart';

class HmA300BlePrinter extends HmA300BlePrinterFlutterApi {
  HmA300BlePrinter._internal() {
    HmA300BlePrinterFlutterApi.setUp(this);
  }
  static final HmA300BlePrinter _singleton = HmA300BlePrinter._internal();
  factory HmA300BlePrinter() => _singleton;
  static HmA300BlePrinter get instance => _singleton;
  static HmA300BlePrinter getInstance() => _singleton;

  Future<String?> getPlatformVersion() {
    return HmA300BlePrinterHostApi().getPlatformVersion();
  }

  Future<String?> getAllVersions() {
    return HmA300BlePrinterHostApi().getAllVersions();
  }

  @override
  String getDartVersion() {
    return "Dart ${Platform.version.split(" ").first}";
  }
}
