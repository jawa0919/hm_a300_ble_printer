import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'hm_a300_ble_printer',
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/example/hm_a300_ble_printer/Messages.g.kt',
    kotlinOptions: KotlinOptions(),
    swiftOut: 'ios/Classes/Messages.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
// host-definitions#############################################################
@HostApi()
abstract class HmA300BlePrinterHostApi {
  // String? postToHost(String id, Map? map);
  // @async
  // Map? postToHostAsync(String id, Map? map);
  @async
  String getHostInfo();

  @async
  bool bluetoothEnabled();

  @async
  bool checkPermission();

  @async
  bool startScan();

  @async
  bool stopScan();
}

// flutter-definitions##########################################################
@FlutterApi()
abstract class HmA300BlePrinterFlutterApi {
  // Map? postToFlutter(String id, Map? map);
  String getFlutterInfo();

  void scanResult(Map bleDeviceData);
}
