import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:hm_a300_ble_printer/hm_a300_ble_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late SharedPreferences _sp;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((r) {
      _sp = r;
      final s = _sp.getString("_lastPrinter") ?? '';
      if (s.isEmpty) return;
      _lastPrinter = BlePrinter.fromJson(jsonDecode(s));
    });
    _plg.getPlatformVersion().then((r) {
      debugPrint('main.dart~getPlatformVersion: $r');
    });
    _plg.getHostInfo().then((r) {
      debugPrint('main.dart~getHostInfo: $r');
    });
    _bleStateSubscription = _plg.bleState.listen((r) {
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
  }

  BlePrinter? _lastPrinter;
  StreamSubscription<int>? _bleStateSubscription;
  StreamSubscription<List<BlePrinter>>? _scanResultsSubscription;
  List<BlePrinter> _scanResults = [];

  @override
  void dispose() {
    _bleStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _scanResults.clear();
    _plg.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('BLE is $_stateStr')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Last Connected Device: '),
            ),
          ),
          SliverToBoxAdapter(
            child: _lastPrinter == null
                ? ListTile(title: Text('None last'))
                : ListTile(
                    leading: Text("${_lastPrinter!.rssi}"),
                    title: Text(_lastPrinter!.name),
                    subtitle: Text(_lastPrinter!.address),
                    trailing: Icon(Icons.connect_without_contact),
                    onLongPress: () {
                      setState(() {
                        _lastPrinter = null;
                        _sp.remove("_lastPrinter");
                      });
                    },
                    onTap: () async {
                      await _plg.stopScan();
                      _lastPrinter!.connect().then((r) {
                        debugPrint('main.dart~connect: $r');
                        if (r == 0) {
                          // ignore: use_build_context_synchronously
                          Navigator.push(context,
                              MaterialPageRoute(builder: (c) {
                            return DevicePage(_lastPrinter!);
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
                  ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Scanning Device: '),
            ),
          ),
          _buildListView(context),
        ],
      ),
      floatingActionButton: StreamBuilder<bool>(
        initialData: false,
        stream: _plg.isScanning,
        builder: (c, s) {
          if (s.data == false) {
            return FloatingActionButton(
              onPressed: () {
                if (_stateStr != "PoweredOn") {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("请检查蓝牙状态"),
                  ));
                  return;
                }
                _scanResults.clear();
                _scanResultsSubscription = _plg.scanResult.listen((r) {
                  debugPrint('main.dart~scanResult: $r');
                  _scanResults = r;
                  setState(() {});
                });
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
              _scanResultsSubscription?.cancel();
              _plg.stopScan();
            },
            child: Icon(Icons.stop),
          );
        },
      ),
    );
  }

  SliverList _buildListView(BuildContext context) {
    return SliverList.builder(
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
                _lastPrinter = dRes;
                setState(() {});
                _sp.setString('_lastPrinter', jsonEncode(dRes));
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
    );
  }
}

class DevicePage extends StatefulWidget {
  final BlePrinter device;
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
    final cmdStr = """! 0 200 200 304 1
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
//       BlueToothName: HM-A300-55ea
//       MacAddress: 00:15:83:CE:55:EA
    final cmdStr = """! 0 200 200 448 1
PAGE - WIDTH 640
SETMAG 2 2
SETBOLD 2
T 4 0 0 10 测试店铺
B QR 410 90 M 2 U 4
MA,https://shop.duibu.cn/goods?shopId=1719898702048043010&goodsId=1904442451296854018&neadendPreview=1
ENDQR
SETMAG 1 1
T 4 0 528 285 米
SETMAG 2 2
T 4 0 464 265 10
LEFT
SETMAG 1 1
SETBOLD 0
T 5 0 0 80 品名：T9999
T 5 0 0 121 编号：-
T 5 0 0 162 缸号：-
T 5 0 0 203 色号:3#
T 5 0 0 244 幅宽：-
T 5 0 0 285 克重：-
T 3 0 0 380 觉得junkyard
SETMAG 0 0
FORM
PRINT""";
    return ListTile(
      title: Text("Example-2"),
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
}
