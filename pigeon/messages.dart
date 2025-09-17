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
  void checkBleState();
  @async
  bool startScan();
  @async
  bool stopScan();
  @async
  int connect(String address);
  @async
  bool disconnect(String address);
  @async
  bool sendCommand(String address, String cmd);
}

// flutter-definitions##########################################################
@FlutterApi()
abstract class HmA300BlePrinterFlutterApi {
  @async
  String getFlutterInfo();
  // ##########################################################################
  @async
  void onBleStateChanged(Map map);
  @async
  void onFound(Map map);
  @async
  void onDiscoveryFinished(Map map);
}
