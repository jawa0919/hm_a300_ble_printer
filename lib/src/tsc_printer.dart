class TscPrinter {
  static final TscPrinter _singleton = TscPrinter._internal();
  factory TscPrinter() => _singleton;
  static TscPrinter get instance => _singleton;
  static TscPrinter getInstance() => _singleton;
  TscPrinter._internal();
  void scanBle(
    Pattern matchAddress, [
    void Function()? matchCb,
    void Function()? finalCb,
  ]) async {}
  void stopScanBle() async {}
  void connectBle(String name, [String address = ""]) async {}
  void disconnectBle(String name) async {}
  void sendCommand(String macId, String cmd) async {}
  void dispose() {}
  void initCallback(
    void Function(List<String> list)? getDeviceList,
    void Function(String data)? getConnectedDeviceStatus,
    void Function(String data)? getCommandStatus,
    void Function(String data)? getCommandDone,
  ) {}
}
