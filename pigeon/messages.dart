import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'hm_a300_ble_printer',
    dartOut: 'lib/src/messages.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/example/hm_a300_ble_printer/Messages.g.kt',
    kotlinOptions: KotlinOptions(),
    swiftOut:
        'ios/hm_a300_ble_printer/Sources/hm_a300_ble_printer/Messages.g.swift',
    swiftOptions: SwiftOptions(),
  ),
)
// flutter-definitions##########################################################
@FlutterApi()
abstract class HmA300BlePrinterFlutterApi {
  @async
  String getDartVersionAsync();
  // ##########################################################################
}

// host-definitions#############################################################
@HostApi()
abstract class HmA300BlePrinterHostApi {
  @async
  String getPlatformNameAsync();
  @async
  String getRunningInfoAsync();
  // ##########################################################################
}
