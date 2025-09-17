import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:hm_a300_ble_printer/hm_a300_ble_printer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MaterialApp(home: const ExampleApp(), title: 'HM A300 Printer'));
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Example App")),
      body: ListView(
        children: [
          _buildExample1(context),
          _buildExample2(context),
        ],
      ),
    );
  }

//       BlueToothName: HM-A300-55ea
//       MacAddress: 00:15:83:CE:55:EA
  ListTile _buildExample1(BuildContext context) {
    final cmdStr = """! 0 200 200 304 1
LINE 0 236 528 236 1
T 8 0 0 248 测试备注
T 8 0 0 196 WX扫码查看最新产品
T 8 0 280 0 编号: 20230216001
T 8 0 280 50 品名: 波AD999
T 8 0 280 100 克重: 10
T 8 0 280 150 成分: ADV,GEQ,设备分
T 8 0 280 174 色素,白卡,发现，公屏
T 8 0 280 198 飞行,黑卡,人心,棉花
FORM  
PRINT""";
    return ListTile(
      title: Text("Example-1"),
      subtitle: Text(cmdStr),
      trailing: Icon(Icons.print),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (c) {
          return MyApp(cmdStr);
        }));
      },
    );
  }

//       BlueToothName: HM-A300-55ea
//       MacAddress: 00:15:83:CE:55:EA
  Widget _buildExample2(BuildContext context) {
    final cmdStr = """! 0 200 200 448 1
PAGE - WIDTH 640
SETMAG 2 2
SETBOLD 2
T 4 0 0 10 测试AD
B QR 410 90 M 2 U 4
MA,https://flutter.cn/
ENDQR
SETMAG 1 1
T 4 0 528 285 米
SETMAG 2 2
T 4 0 464 265 10
LEFT
SETMAG 1 1
SETBOLD 0
T 5 0 0 80 品名：AD999
T 5 0 0 121 编号：-
T 5 0 0 162 缸号：-
T 5 0 0 203 色号:3#
T 5 0 0 244 宽度：-
T 5 0 0 285 重量：-
T 3 0 0 380 测试备注
SETMAG 0 0
FORM
PRINT""";
    return ListTile(
      title: Text("Example-2"),
      subtitle: Text(cmdStr),
      trailing: Icon(Icons.print),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (c) {
          return MyApp(cmdStr);
        }));
      },
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp(this.cmdStr, {super.key});

  final String cmdStr;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _plg = HmA300BlePrinter();

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
      setState(() {
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
      });
    });
    _scanningSubscription = _plg.isScanning.listen((r) {
      debugPrint('main.dart~isScanning: $r');
      setState(() {
        _isScanning = r;
      });
    });
  }

  StreamSubscription<int>? _bleStateSubscription;
  String _stateStr = "Unknown";
  StreamSubscription<bool>? _scanningSubscription;
  bool _isScanning = false;
  StreamSubscription<List<BlePrinter>>? _scanResultsSubscription;
  List<BlePrinter> _scanResults = [];

  BlePrinter? _lastPrinter;

  @override
  void dispose() {
    _bleStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _scanningSubscription?.cancel();
    _scanResults.clear();
    _plg.stopScan();
    _plg.disconnect(_lastPrinter?.address ?? "");
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
                    onTap: () => _connectAndSend(context, _lastPrinter!),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_stateStr != "PoweredOn") {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text("请检查蓝牙状态"),
            ));
            return;
          }
          if (_isScanning) {
            _scanResultsSubscription?.cancel();
            _plg.stopScan();
            setState(() {
              _isScanning = false;
            });
            return;
          }
          _scanResults.clear();
          _scanResultsSubscription?.cancel();
          _scanResultsSubscription = _plg.scanResult.listen((r) {
            debugPrint('main.dart~scanResult: $r');
            setState(() {
              _scanResults = r;
            });
          });
          _plg.startScan().then((r) {
            debugPrint('main.dart~startScan: $r');
          }).catchError((e) {
            debugPrint('main.dart~startScan: error: $e');
          });
        },
        child: Icon(_isScanning ? Icons.stop : Icons.find_in_page),
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
          onTap: () => _connectAndSend(context, dRes),
        );
      },
    );
  }

  Future<void> _connectAndSend(BuildContext context, BlePrinter printer) async {
    if (_isScanning) _plg.stopScan();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("连接中..."),
    ));
    _plg.connect(printer.address).then((r) {
      debugPrint('main.dart~connect: $r');
      if (r == 200) {
        _lastPrinter = printer;
        setState(() {});
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("连接成功, 名称: ${printer.name},发送命令中..."),
        ));
        _sp.setString('_lastPrinter', jsonEncode(printer));
        _plg.sendCommand(printer.address, widget.cmdStr).then((r) {
          debugPrint('main.dart~sendCommand: $r');
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("发送命令完毕-$r"),
          ));
        }).catchError((e) {
          debugPrint('main.dart~sendCommand: error: $e');
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("发送命令失败: $e"),
          ));
        });
      } else {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("连接失败: $r"),
        ));
      }
    }).catchError((e) {
      debugPrint('main.dart~connect: error: $e');
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("连接失败: $e"),
      ));
    });
  }
}
