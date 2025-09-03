import 'package:flutter_test/flutter_test.dart';
import 'package:hm_a300_ble_printer/hm_a300_ble_printer.dart';
import 'package:hm_a300_ble_printer/hm_a300_ble_printer_platform_interface.dart';
import 'package:hm_a300_ble_printer/hm_a300_ble_printer_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockHmA300BlePrinterPlatform
    with MockPlatformInterfaceMixin
    implements HmA300BlePrinterPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final HmA300BlePrinterPlatform initialPlatform = HmA300BlePrinterPlatform.instance;

  test('$MethodChannelHmA300BlePrinter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelHmA300BlePrinter>());
  });

  test('getPlatformVersion', () async {
    HmA300BlePrinter hmA300BlePrinterPlugin = HmA300BlePrinter();
    MockHmA300BlePrinterPlatform fakePlatform = MockHmA300BlePrinterPlatform();
    HmA300BlePrinterPlatform.instance = fakePlatform;

    expect(await hmA300BlePrinterPlugin.getPlatformVersion(), '42');
  });
}
