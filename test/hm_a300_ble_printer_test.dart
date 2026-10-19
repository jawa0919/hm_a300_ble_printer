import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hm_a300_ble_printer/hm_a300_ble_printer.dart';

void main() {
  const MethodChannel channel = MethodChannel('hm_a300_ble_printer');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await HmA300BlePrinter().getPlatformVersion(), '42');
  });
}
