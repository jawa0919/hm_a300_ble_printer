import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../src/messages.g.dart';

class BlePrinter {
  BlePrinter({
    required this.name,
    required this.address,
    required this.rssi,
  });

  final String name;
  final String address;
  final int rssi;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlePrinter &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          address == other.address;

  @override
  int get hashCode => name.hashCode ^ address.hashCode;

  factory BlePrinter.fromJson(Map<String, dynamic> json) {
    return BlePrinter(
      name: json['name'],
      address: json['address'],
      rssi: json['rssi'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'rssi': rssi,
    };
  }

  @override
  String toString() {
    return toJson().toString();
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
  final _bleStateController = StreamController<int>.broadcast(
    onListen: () {
      HmA300BlePrinterHostApi().checkBleState();
    },
  );

  Stream<bool> get isScanning => _isScanningController.stream;
  final _isScanningController = StreamController<bool>.broadcast();

  Future<bool> startScan() async {
    _scanDevices.clear();
    _isScanningController.add(true);
    final s = await HmA300BlePrinterHostApi().startScan();
    return s;
  }

  Future<bool> stopScan() async {
    final s = await HmA300BlePrinterHostApi().stopScan();
    _isScanningController.add(false);
    return s;
  }

  final Map<String, BlePrinter> _scanDevices = {};
  List<BlePrinter> get scanDevices => _scanDevices.values.toList();
  final _scanResultController = StreamController<List<BlePrinter>>.broadcast();
  Stream<List<BlePrinter>> get scanResult => _scanResultController.stream;

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
    final device = BlePrinter(
      name: name,
      address: address,
      rssi: rssi,
    );
    _scanDevices[device.address] = device;
    _scanResultController.add(_scanDevices.values.toList());
  }

  @override
  Future<void> onDiscoveryFinished(Map<dynamic, dynamic> map) async {
    print('hm_a300_ble_printer.dart~onDiscoveryFinished: $map');
    _isScanningController.add(false);
  }
}
