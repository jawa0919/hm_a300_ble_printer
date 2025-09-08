import 'dart:async';

import 'package:flutter/material.dart';

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
    _plg.bleState.listen((r) {
      debugPrint('main.dart~bleState: $r');
      _stateStr = "Unknown";
      if (r == 0) {
        _stateStr = "Unknown";
      } else if (r == 1) {
        _stateStr = "Resetting";
      } else if (r == 2) {
        _stateStr = "Unsupported";
      } else if (r == 3) {
        _stateStr = "Unauthorized";
      } else if (r == 4) {
        _stateStr = "PoweredOff";
      } else if (r == 5) {
        _stateStr = "PoweredOn";
      }
      setState(() {});
    });
    _scanResultsSubscription = _plg.scanResult.listen((d) {
      _scanResults = [..._scanResults, d];
      setState(() {});
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
    if (_stateStr != "PoweredOn") {
      return Scaffold(body: Center(child: Text(_stateStr)));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Plugin example app')),
      body: ListView.builder(
        itemCount: _scanResults.length,
        itemBuilder: (context, index) {
          final dRes = _scanResults[index];
          return ListTile(
            leading: Text("${dRes.rssi}"),
            title: Text(dRes.name),
            subtitle: Text(dRes.address),
            trailing: Icon(Icons.connect_without_contact),
            onTap: () async {
              await _plg.stopScan();
              dRes.connect().then((r) {
                debugPrint('main.dart~connect: $r');
                if (r == 0) {
                  // ignore: use_build_context_synchronously
                  Navigator.push(context, MaterialPageRoute(builder: (c) {
                    return DevicePage(dRes);
                  }));
                } else {
                  // ignore: use_build_context_synchronously
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("连接失败: 错误码$r"),
                  ));
                }
              }).catchError((e) {
                debugPrint('main.dart~connect: error: $e');
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("连接失败: $e"),
                ));
              });
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

class DevicePage extends StatefulWidget {
  final BlePrinterDevice device;
  const DevicePage(this.device, {super.key});

  @override
  State<DevicePage> createState() => _DevicePageState();
}

class _DevicePageState extends State<DevicePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.device.name)),
      body: ListView(
        children: [
          _buildExample1(context),
          _buildExample2(context),
        ],
      ),
    );
  }

  ListTile _buildExample1(BuildContext context) {
//       BlueToothName: HM-A300-55ea
//       MacAddress: 00:15:83:CE:55:EA
    final cmdStr = """
! 0 200 200 304 1
LINE 0 236 528 236 1
T 8 0 0 248 测试备注
T 8 0 0 196 微信扫码查看最新产品
T 8 0 280 0 编号: 20230216001
T 8 0 280 50 品名: 路易威登
T 8 0 280 100 克重: 10
T 8 0 280 150 成分: 聚酯纤维,莫代尔,
T 8 0 280 174 氨纶,莱卡,腈纶,亚麻,苎
T 8 0 280 198 麻,涤纶,人棉,棉
FORM
PRINT""";
    return ListTile(
      title: Text("Example-1"),
      subtitle: Text(cmdStr),
      trailing: Icon(Icons.print),
      onTap: () {
        widget.device.sendCommand(cmdStr).then((r) {
          debugPrint('main.dart~print: $r');
        }).catchError((e) {
          debugPrint('main.dart~print: error: $e');
        });
      },
    );
  }

  Widget _buildExample2(BuildContext context) {
    return Container();
    // return ListTile(
    //   title: Text("Example-2"),
    //   subtitle: Text(""),
    //   trailing: Icon(Icons.print),
    //   onTap: () {
    //     widget.device.sendCommand("! 0 200 200 304 1").then((r) {
    //       debugPrint('main.dart~print: $r');
    //     }).catchError((e) {
    //       debugPrint('main.dart~print: error: $e');
    //     });
    //   },
    // );
  }
}
