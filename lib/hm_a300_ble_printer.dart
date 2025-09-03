
import 'hm_a300_ble_printer_platform_interface.dart';

class HmA300BlePrinter {
  Future<String?> getPlatformVersion() {
    return HmA300BlePrinterPlatform.instance.getPlatformVersion();
  }
}
