import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../src/messages.g.dart';

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

  final _isScanningController = StreamController<bool>.broadcast();
  Stream<bool> get isScanning => _isScanningController.stream;

  @override
  void scanResult(Map<dynamic, dynamic> bleDevice) {
    final name = bleDevice['name'];
    final address = bleDevice['address'];
    final rssi = bleDevice['rssi'];
    final device = BlePrinterDevice(
      name: name,
      address: address,
      rssi: rssi,
    );
    print('scanResult: $device');
    _scanResultsController.add(device);
  }

  final _scanResultsController = StreamController<BlePrinterDevice>.broadcast();
  Stream<BlePrinterDevice> get scanResults => _scanResultsController.stream;

  void stopScan() async {
    await HmA300BlePrinterHostApi().stopScan();
    _isScanningController.add(false);
  }

  Future<bool> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _isScanningController.add(true);
    Future.delayed(timeout, stopScan);
    return await HmA300BlePrinterHostApi().startScan();
  }

  bool isState = false;

  Future<bool> checkBluetoothState() async {
    final open = await HmA300BlePrinterHostApi().bluetoothEnabled();
    if (!open) return Future.error("Bluetooth Enabled Failed");
    final check = await HmA300BlePrinterHostApi().checkPermission();
    if (!check) return Future.error("Bluetooth Check Permission Failed");
    return true;
  }
}

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
