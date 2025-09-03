import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hm_a300_ble_printer/hm_a300_ble_printer_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelHmA300BlePrinter platform = MethodChannelHmA300BlePrinter();
  const MethodChannel channel = MethodChannel('hm_a300_ble_printer');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
