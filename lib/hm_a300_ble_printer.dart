import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../src/messages.g.dart';

class BlePrinterDevice {
  BlePrinterDevice({
    required this.name,
    required this.address,
    required this.rssi,
  });

  final String name;
  final String address;
  final int rssi;

  @override
  String toString() {
    return 'BlePrinterDevice{name: $name, address: $address, rssi: $rssi}';
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

  Future<String?> getHostInfo() async {
    return await HmA300BlePrinterHostApi().getHostInfo();
  }

  @override
  Future<String> getFlutterInfo() async {
    return "Dart ${Platform.version.split(" ").first}";
  }

  // ##########################################################################

  final _bleStateController = StreamController<int>.broadcast(
    onListen: () {
      HmA300BlePrinterHostApi().checkBleState();
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
    Duration timeout = const Duration(seconds: 15),
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
  Future<void> onBleStateChanged(Map<dynamic, dynamic> map) async {
    print('hm_a300_ble_printer.dart~onBleStateChanged: $map');
    final state = map['state'] ?? 0;
    _bleStateController.add(state);
  }

  @override
  Future<void> onFound(Map<dynamic, dynamic> map) async {
    print('hm_a300_ble_printer.dart~onFound: $map');
    final name = map['name'];
    final address = map['address'];
    final rssi = map['rssi'];
    final device = BlePrinterDevice(
      name: name,
      address: address,
      rssi: rssi,
    );
    _scanDevices.add(device);
    _scanResultController.add(device);
  }

  @override
  Future<void> onDiscoveryFinished(Map<dynamic, dynamic> map) async {
    print('hm_a300_ble_printer.dart~onDiscoveryFinished: $map');
    _isScanningController.add(false);
  }
}
