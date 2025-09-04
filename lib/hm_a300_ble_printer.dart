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

  Future<bool> checkBluetoothState() async {
    final isOpen = await HmA300BlePrinterHostApi().bleEnabled();
    if (!isOpen) return Future.error("Bluetooth Enabled Failed");
    final isCheck = await HmA300BlePrinterHostApi().blePermission();
    if (!isCheck) return Future.error("Bluetooth Permission Failed");
    return true;
  }

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
  void onScanResult(Map<dynamic, dynamic> map) {
    print('onScanResult: $map');
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
}
