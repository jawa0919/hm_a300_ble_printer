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

  /// 蓝牙状态枚举值
  /// - 0: unknown      - 未知状态
  /// - 1: resetting    - 重置中
  /// - 2: unsupported  - 不支持
  /// - 3: unauthorized - 未授权
  /// - 4: poweredOff   - 蓝牙关闭
  /// - 5: poweredOn    - 蓝牙开启
  Stream<int> get bleState => _bleStateController.stream;
  final _bleStateController = StreamController<int>.broadcast(
    onListen: () {
      HmA300BlePrinterHostApi().checkBleState();
    },
  );

  Stream<bool> get isScanning => _isScanningController.stream;
  final _isScanningController = StreamController<bool>.broadcast();

  Future<bool> startScan({String? filterName}) async {
    _scanDeviceMaps.clear();
    _isScanningController.add(true);
    final s = await HmA300BlePrinterHostApi().startScan();
    return s;
  }

  Future<bool> stopScan() async {
    final s = await HmA300BlePrinterHostApi().stopScan();
    _isScanningController.add(false);
    return s;
  }

  final Map<String, BlePrinter> _scanDeviceMaps = {};
  List<BlePrinter> get scanDevices => _scanDeviceMaps.values.toList();
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
    final device = BlePrinter(name: name, address: address, rssi: rssi);
    _scanDeviceMaps[device.address] = device;
    _scanResultController.add(_scanDeviceMaps.values.toList());
  }

  @override
  Future<void> onDiscoveryFinished(Map<dynamic, dynamic> map) async {
    print('hm_a300_ble_printer.dart~onDiscoveryFinished: $map');
    _isScanningController.add(false);
  }

  /// 连接状态返回码
  ///
  /// 通用:
  /// - 200: 连接成功
  ///
  /// Android错误:
  /// - -1: 连接超时
  /// - -2: 蓝牙地址格式错误
  /// - -3: 打印机与SDK不匹配（握手不通过）
  ///
  /// iOS错误:
  /// - 0: 蓝牙连接超时
  /// - 1: 获取服务超时
  /// - 2: 验证超时
  /// - 3: 未知设备
  /// - 4: 系统错误
  /// - 5: 验证失败
  /// - 6: 流打开超时
  /// - 7: 打开的是空流
  /// - 8: 流发生错误
  Future<int> connect(String address) async {
    return await HmA300BlePrinterHostApi().connect(address);
  }

  Future<bool> disconnect(String address) async {
    return await HmA300BlePrinterHostApi().disconnect(address);
  }

  Future<bool> sendCommand(String address, String cmd) async {
    return await HmA300BlePrinterHostApi().sendCommand(address, cmd);
  }
}
