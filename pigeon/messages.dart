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
  @async
  String getHostInfo();
  // ##########################################################################
  @async
  bool bleEnabled();

  @async
  bool blePermission();

  @async
  bool startScan();

  @async
  bool stopScan();
}

// flutter-definitions##########################################################
@FlutterApi()
abstract class HmA300BlePrinterFlutterApi {
  String getFlutterInfo();
  // ##########################################################################

  void onScanResult(Map map);
  // void onReceivedData(Map map);
}
