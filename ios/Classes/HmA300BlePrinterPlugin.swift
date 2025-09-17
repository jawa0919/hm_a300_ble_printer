import CoreBluetooth
import Flutter
import PrinterSDK
import UIKit

// 简单的日志工具类
class Logger {
    static let shared = Logger()
    private let prefix = "[HmA300BlePrinter]"

    func info(_ message: String) {
        let timestamp = self.getCurrentTimestamp()
        print("\(prefix) \(timestamp) [INFO] \(message)")
    }

    func warning(_ message: String) {
        let timestamp = self.getCurrentTimestamp()
        print("\(prefix) \(timestamp) [WARNING] \(message)")
    }

    func error(_ message: String) {
        let timestamp = self.getCurrentTimestamp()
        print("\(prefix) \(timestamp) [ERROR] \(message)")
    }

    private func getCurrentTimestamp() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return dateFormatter.string(from: Date())
    }
}

let log = Logger.shared

public class HmA300BlePrinterPlugin: NSObject, FlutterPlugin, HmA300BlePrinterHostApi, CBCentralManagerDelegate {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "hm_a300_ble_printer", binaryMessenger: registrar.messenger())
        let instance = HmA300BlePrinterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        HmA300BlePrinterHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
        instance.fApi = HmA300BlePrinterFlutterApi(binaryMessenger: registrar.messenger())
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private var fApi: HmA300BlePrinterFlutterApi?

    func getHostInfo(completion: @escaping (Result<String, any Error>) -> Void) {
        if let api = fApi {
            api.getFlutterInfo { result in
                switch result {
                case .success(let flutterInfo):
                    let iosVersion = UIDevice.current.systemVersion
                    let combinedInfo = "\(flutterInfo)-iOS: \(iosVersion)"
                    completion(Result.success(combinedInfo))
                case .failure(let error):
                    log.error("获取Flutter信息失败: \(error)")
                }
            }
        }
    }

    // 初始化CBCentralManager并设置代理为当前类
    private lazy var mCentralManager: CBCentralManager = {
        let centralManager = CBCentralManager(delegate: self, queue: nil)
        return centralManager
    }()

    private var ptPrinters = [String: PTPrinter]()

    func checkBleState(completion: @escaping (Result<Void, any Error>) -> Void) {
        let state = self.mCentralManager.state
        log.info("checkState: \(state)")
        var map = [String: Any]()
        map["state"] = state.rawValue
        fApi?.onBleStateChanged(map: map) { result in }
        completion(Result.success(()))
    }

    func startScan(completion: @escaping (Result<Bool, any Error>) -> Void) {
        log.info("开始扫描蓝牙设备")
        let dispatcher = PTDispatcher.share()
        dispatcher?.whenFindAllBluetooth({ pts in
            guard let temp = pts as? [PTPrinter] else { return }
            temp.forEach({ (pt) in
                if let uuid = pt.uuid, self.ptPrinters[uuid] == nil {
                    self.ptPrinters[uuid] = pt
                    var map = [String: Any]()
                    map["name"] = pt.name
                    map["address"] = pt.uuid
                    map["rssi"] = pt.distance.intValue
                    self.fApi?.onFound(map: map) { result in }
                }
            })

        })
        self.ptPrinters.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
            dispatcher?.stopScanBluetooth()
            self.fApi?.onDiscoveryFinished(map: [String: Any]()) { result in }
        }
        dispatcher?.scanBluetooth()
        completion(Result.success(true))
    }

    func stopScan(completion: @escaping (Result<Bool, any Error>) -> Void) {
        log.info("停止扫描蓝牙设备")
        let dispatcher = PTDispatcher.share()
        dispatcher?.stopScanBluetooth()
        completion(Result.success(true))
    }

    func connect(address: String, completion: @escaping (Result<Int64, any Error>) -> Void) {
        let dispatcher = PTDispatcher.share()
        log.info("连接设备: \(address)---\(dispatcher?.printerConnected?.uuid ?? "")")
        if address.isEmpty {
            completion(Result.failure(PigeonError(code: "address is empty", message: nil, details: nil)))
            return
        }
        if address == dispatcher?.printerConnected?.uuid {
            log.info("\(address)打印机已经连接了")
            completion(Result.success(200))
            return
        }
        if ptPrinters.keys.contains(address) {
            let tPrinter = ptPrinters[address]
            dispatcher?.whenConnectSuccess({
                log.info("打印机连接成功")
                completion(Result.success(200))
            })
            dispatcher?.whenConnectFailureWithErrorBlock({ (error) in
                log.error("打印机连接失败: \(error.rawValue)")
                completion(Result.success(Int64(error.rawValue)))
            })
            dispatcher?.connect(tPrinter)
        } else {
            log.info("\(address)打印机需要先发现一下再连接")
            var isFind = false
            dispatcher?.whenFindAllBluetooth({ pts in
                guard let temp = pts as? [PTPrinter] else { return }
                for tPrinter in temp {
                    if tPrinter.uuid == address {
                        isFind = true
                        dispatcher?.stopScanBluetooth()
                        dispatcher?.whenConnectSuccess({
                            log.info("打印机连接成功")
                            completion(Result.success(200))
                        })
                        dispatcher?.whenConnectFailureWithErrorBlock({ (error) in
                            log.error("打印机连接失败: \(error.rawValue)")
                            completion(Result.success(Int64(error.rawValue)))
                        })
                        dispatcher?.connect(tPrinter)
                        break
                    }
                }
            })
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) {
                dispatcher?.stopScanBluetooth()
                if !isFind {
                    log.info("没有发现打印机在附近")
                    completion(Result.success(0))
                }
            }
            dispatcher?.scanBluetooth()
        }
    }

    func disconnect(address: String, completion: @escaping (Result<Bool, any Error>) -> Void) {
        let dispatcher = PTDispatcher.share()
        log.info("断开连接: \(address)---\(dispatcher?.printerConnected?.uuid ?? "")")
        if address == dispatcher?.printerConnected?.uuid {
            dispatcher?.whenUnconnect({ (isActive) in
                log.error("打印机断开链接回调: \(isActive)")
                completion(Result.success(isActive))
            })
            dispatcher?.disconnect()
        } else {
            log.error("\(address)打印机未连接")
            completion(Result.success(false))
        }
    }

    func sendCommand(address: String, cmd: String, completion: @escaping (Result<Bool, any Error>) -> Void) {
        let dispatcher = PTDispatcher.share()
        log.info("发送命令: \(address)---\(dispatcher?.printerConnected?.uuid ?? "")")
        if address.isEmpty {
            completion(Result.failure(PigeonError(code: "address is empty", message: nil, details: nil)))
            return
        }
        if address == dispatcher?.printerConnected?.uuid {
            dispatcher?.whenSendSuccess({ (_, _) in
                completion(Result.success(true))
            })
            dispatcher?.whenSendFailure {
                completion(Result.success(false))
            }
            dispatcher?.whenReceiveData { (data) in
            }
            let pc = PTCommandCPCL.init()
            pc.appendCommand(cmd)
            dispatcher?.send(pc.cmdData as Data)
            //            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            //                completion(Result.success(true))
            //            }
        } else {
            log.error("\(address)打印机未连接")
            completion(Result.failure(PigeonError(code: "address is disconnect", message: nil, details: nil)))
        }
    }

    // MARK: - CBCentralManagerDelegate方法实现

    // 蓝牙状态变化时调用
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log.info("蓝牙状态更新: \(central.state)")
        // 这里可以根据需要发送状态变化通知给Flutter
        var map = [String: Any]()
        map["state"] = central.state.rawValue
        fApi?.onBleStateChanged(map: map) { result in }
    }

    // 发现设备时调用
    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        log.info("发现设备成功: \(peripheral.name ?? "未知设备")")
        // 这里可以实现发现设备后的逻辑
    }

    // 连接成功时调用
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log.info("连接设备成功: \(peripheral.name ?? "未知设备")")
        // 这里可以实现连接成功后的逻辑
    }

    // 连接失败时调用
    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        log.error("连接设备失败: \(peripheral.name ?? "未知设备"), 错误: \(error?.localizedDescription ?? "未知错误")")
        // 这里可以实现连接失败后的逻辑
    }

    // 断开连接时调用
    public func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        log.info("断开连接: \(peripheral.name ?? "未知设备")")
        // 这里可以实现断开连接后的逻辑
    }
}
