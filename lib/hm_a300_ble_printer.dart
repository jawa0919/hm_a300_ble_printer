import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../src/messages.g.dart';

class BlePrinterDevice {
  BlePrinterDevice({
    required this.name,
    required this.address,
    required this.type,
    required this.bondState,
    required this.rssi,
  });

  final String name;
  final String address;

  /// public static final int DEVICE_TYPE_CLASSIC = 1;
  /// public static final int DEVICE_TYPE_DUAL = 3;
  /// public static final int DEVICE_TYPE_LE = 2;
  /// public static final int DEVICE_TYPE_UNKNOWN = 0;
  final int type;

  /// public static final int BOND_BONDED = 12;
  /// public static final int BOND_BONDING = 11;
  /// public static final int BOND_NONE = 10;
  final int bondState;
  final int rssi;

  bool get isBonded => bondState == 12;

  @override
  String toString() {
    return 'BlePrinterDevice{name: $name, address: $address, type: $type, bondState: $bondState, rssi: $rssi}';
  }

  /// | 值   | 描述                            |
  ///
  /// |: --- |: ------------------------------ |
  ///
  /// | 0    | 连接成功                        |
  ///
  /// | -1   | 连接超时                        |
  ///
  /// | -2   | 蓝牙地址格式错误                |
  ///
  /// | -3   | 打印机与SDK不匹配（握手不通过） |
  ///
  Future<int> connect() async {
    return await HmA300BlePrinterHostApi().connect(address);
  }

  Future<bool> disconnect() async {
    return await HmA300BlePrinterHostApi().disconnect(address);
  }

  Future<bool> sendCommand(String cmd) async {
    return await HmA300BlePrinterHostApi().sendCommand(address, cmd);
  }

  Future<int> encoding(String encoding) async {
    return await HmA300BlePrinterHostApi().printerEncoding(address, encoding);
  }

  Future<int> writeData(String data) async {
    return await HmA300BlePrinterHostApi().printerWriteData(address, data);
  }

  Future<int> line(List<String> data) async {
    return await HmA300BlePrinterHostApi().printerLine(address, data);
  }

  Future<int> printAreaSize(List<String> data) async {
    return await HmA300BlePrinterHostApi().printerPrintAreaSize(address, data);
  }

  Future<int> text(List<String> data) async {
    return await HmA300BlePrinterHostApi().printerText(address, data);
  }

  Future<int> form() async {
    return await HmA300BlePrinterHostApi().printerForm(address);
  }

  Future<int> print() async {
    return await HmA300BlePrinterHostApi().printerPrint(address);
  }
}

class HmA300BlePrinter extends HmA300BlePrinterFlutterApi {
  static const _channel = MethodChannel('hm_a300_ble_printer');

  Future<String?> getPlatformVersion() async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  HmA300BlePrinter._internal() {
    HmA300BlePrinterFlutterApi.setUp(this);
  }
  static final HmA300BlePrinter _singleton = HmA300BlePrinter._internal();

  factory HmA300BlePrinter() => _singleton;
  static HmA300BlePrinter get instance => _singleton;
  static HmA300BlePrinter getInstance() => _singleton;

  Future<String?> getHostInfo() {
    return HmA300BlePrinterHostApi().getHostInfo();
  }

  @override
  String getFlutterInfo() {
    return "Dart ${Platform.version.split(" ").first}";
  }

  // ##########################################################################

  final _bleStateController = StreamController<int>.broadcast(
    onListen: () {
      HmA300BlePrinterHostApi().checkState();
    },
  );

  /// case unknown = 0
  ///
  /// case resetting = 1
  ///
  /// case unsupported = 2
  ///
  /// case unauthorized = 3
  ///
  /// case poweredOff = 4
  ///
  /// case poweredOn = 5
  Stream<int> get bleState => _bleStateController.stream;

  final _isScanningController = StreamController<bool>.broadcast();
  Stream<bool> get isScanning => _isScanningController.stream;

  Future<bool> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _scanDevices.clear();
    _isScanningController.add(true);
    Future.delayed(timeout, stopScan);
    final s = await HmA300BlePrinterHostApi().startScan();
    return s;
  }

  Future<bool> stopScan() async {
    final s = await HmA300BlePrinterHostApi().stopScan();
    _isScanningController.add(false);
    return s;
  }

  final List<BlePrinterDevice> _scanDevices = [];
  List<BlePrinterDevice> get scanDevices => _scanDevices;
  final _scanResultController = StreamController<BlePrinterDevice>.broadcast();
  Stream<BlePrinterDevice> get scanResult => _scanResultController.stream;

  @override
  void onStateChanged(Map<dynamic, dynamic> map) {
    print('hm_a300_ble_printer.dart~onStateChanged: $map');
    final state = map['state'] ?? 0;
    _bleStateController.add(state);
  }

  @override
  void onFound(Map<dynamic, dynamic> map) {
    print('hm_a300_ble_printer.dart~onFound: $map');
    final name = map['name'];
    final address = map['address'];
    final type = map['type'] ?? 0;
    final bondState = map['bondState'] ?? 10;
    final rssi = map['rssi'];
    final device = BlePrinterDevice(
      name: name,
      address: address,
      type: type,
      bondState: bondState,
      rssi: rssi,
    );
    _scanDevices.add(device);
    _scanResultController.add(device);
  }

  @override
  void onDiscoveryFinished(Map<dynamic, dynamic> map) {
    print('hm_a300_ble_printer.dart~onDiscoveryFinished: $map');
    _isScanningController.add(false);
  }
}
