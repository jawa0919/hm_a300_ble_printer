import 'package:flutter/material.dart';
import 'dart:async';

import 'package:hm_a300_ble_printer/hm_a300_ble_printer.dart';

void main() {
  runApp(MaterialApp(home: const MyApp(), title: 'HM A300 Printer'));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _plg = HmA300BlePrinter();
  String _stateStr = "Unknown";

  @override
  void initState() {
    super.initState();
    _plg.getPlatformVersion().then((r) {
      debugPrint('main.dart~getPlatformVersion: $r');
    });
    _plg.getHostInfo().then((r) {
      debugPrint('main.dart~getHostInfo: $r');
    });
    _plg.checkBluetoothState().then((r) {
      debugPrint('main.dart~checkBluetoothState: $r');
      _stateStr = "On";
      setState(() {});
    }).catchError((e) {
      debugPrint('main.dart~checkBluetoothState.error: $e');
      _stateStr = e.toString();
      setState(() {});
    });
    _scanResultsSubscription = _plg.scanResult.listen((d) {
      setState(() {
        _scanResults = [..._scanResults, d];
        debugPrint('main.dart~scanResults: ${_scanResults.length}');
      });
    });
  }

  StreamSubscription<BlePrinterDevice>? _scanResultsSubscription;
  List<BlePrinterDevice> _scanResults = [];

  @override
  void dispose() {
    _scanResultsSubscription?.cancel();
    _plg.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stateStr != "On") {
      return Scaffold(body: Center(child: Text(_stateStr)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin example app')),
      body: ListView.builder(
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          final sRes = _scanResults[index];
          return ListTile(
            leading: Text("${sRes.rssi}"),
            title: Text(sRes.name),
            subtitle: Text(sRes.address),
            // trailing: StreamBuilder<BluetoothConnectionState>(
            //   stream: sRes.connectionState,
            //   builder: (c, s) {
            //     if (s.data == BluetoothConnectionState.connected) {
            //       return Icon(Icons.bluetooth_connected);
            //     }
            //     return Icon(Icons.bluetooth_disabled);
            //   },
            // ),
            onTap: () {
              // if (!sRes.device.isConnected) {
              //   FlutterBluePlus.stopScan();
              //   sRes.device.connect();
              // } else {
              //   debugPrint('main.dart~device: ${sRes.device}');
              //   // Navigator.push(context, MaterialPageRoute(builder: (c) {
              //   //   return DevicePage(sRes.device);
              //   // }));
              // }
            },
          );
        },
      ),
      floatingActionButton: StreamBuilder<bool>(
        initialData: false,
        stream: _plg.isScanning,
        builder: (c, s) {
          if (s.data == false) {
            return FloatingActionButton(
              onPressed: () {
                _scanResults.clear();
                _plg.startScan().then((r) {
                  debugPrint('main.dart~startScan: $r');
                }).catchError((e) {
                  debugPrint('main.dart~startScan: error: $e');
                });
              },
              child: Icon(Icons.find_in_page),
            );
          }
          return FloatingActionButton(
            onPressed: () {
              _plg.stopScan();
            },
            child: Icon(Icons.stop),
          );
        },
      ),
    );
  }
}
