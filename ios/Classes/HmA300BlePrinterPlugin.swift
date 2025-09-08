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

// 为了方便使用，创建全局实例
let log = Logger.shared

public class HmA300BlePrinterPlugin: NSObject, FlutterPlugin,
    HmA300BlePrinterHostApi, CBCentralManagerDelegate
{

    // 初始化CBCentralManager并设置代理为当前类
    private lazy var mCentralManager: CBCentralManager = {
        let centralManager = CBCentralManager(delegate: self, queue: nil)
        return centralManager
    }()

    // 用于存储扫描到的设备
    private var ptPrinters = [String: PTPrinter]()

    // Flutter API接口实例
    private var fApi: HmA300BlePrinterFlutterApi?

    func getHostInfo(completion: @escaping (Result<String, any Error>) -> Void) {
        completion(Result.success("iOS " + UIDevice.current.systemVersion))
    }

    func checkState() {
        let state = self.mCentralManager.state
        log.info("checkState: \(state)")
        var map = [String: Any]()
        map["state"] = state.rawValue
        if let api = fApi {
            api.onStateChanged(map: map) {
                result in
                switch result {
                case .success:
                    log.info("checkState成功通知Flutter蓝牙状态更新")
                case .failure(let error):
                    log.error("checkState通知Flutter蓝牙状态更新失败: \(error)")
                }
            }
        }
    }

    func startScan(completion: @escaping (Result<Bool, any Error>) -> Void) {
        log.info("开始扫描蓝牙设备")
        let dispatcher = PTDispatcher.share()
        dispatcher?.whenFindAllBluetooth({ pts in
            guard let temp = pts as? [PTPrinter] else { return }
            let dataSources = temp.sorted(by: { (pt1, pt2) -> Bool in
                return pt1.distance.floatValue < pt2.distance.floatValue
            })
            dataSources.forEach({ (pt) in
                if let uuid = pt.uuid, self.ptPrinters[uuid] == nil {
                    self.ptPrinters[uuid] = pt
                    var map = [String: Any]()
                    map["name"] = pt.name
                    map["address"] = pt.uuid
                    map["rssi"] = pt.distance.intValue
                    if let api = self.fApi {
                        api.onFound(map: map) {
                            result in
                            switch result {
                            case .success:
                                log.info("成功通知Flutter发现设备")
                            case .failure(let error):
                                log.error("通知Flutter发现设备失败: \(error)")
                            }
                        }
                    }
                }
            })
        })
        PTDispatcher.share()?.scanBluetooth()
        completion(Result.success(true))
    }

    func stopScan(completion: @escaping (Result<Bool, any Error>) -> Void) {
        log.info("停止扫描蓝牙设备")
        // 获取PTDispatcher实例
        let dispatcher = PTDispatcher.share()
        dispatcher?.stopScanBluetooth()
        completion(Result.success(true))
    }

    func connect(
        address: String,
        completion: @escaping (Result<Int64, any Error>) -> Void
    ) {
        log.info("连接设备: \(address)")
        if ptPrinters.keys.contains(address) {
            let tPrinter = ptPrinters[address]
            let dispatcher = PTDispatcher.share()
            dispatcher?.whenConnectSuccess({
                log.info("打印机连接成功")
                completion(Result.success(0))
            })
            dispatcher?.whenConnectFailureWithErrorBlock({ (error) in
                log.error("打印机连接失败: \(error.rawValue)")
                completion(
                    Result.failure(
                        PigeonError(
                            code: "connect-failed",
                            message: "连接失败",
                            details: nil
                        )
                    )
                )
            })
            dispatcher?.connect(tPrinter)
        } else {
            log.error("未找到地址为: \(address) 的设备")
            completion(
                Result.failure(
                    PigeonError(
                        code: "device-not-found",
                        message: "未找到对应设备",
                        details: nil
                    )
                )
            )
        }
    }

    func disconnect(
        address: String,
        completion: @escaping (Result<Bool, any Error>) -> Void
    ) {
        log.info("断开连接: \(address)")
        let dispatcher = PTDispatcher.share()
        if let connectedPrinter = dispatcher?.printerConnected {
            if connectedPrinter.uuid == address {
                dispatcher?.whenUnconnect({ (error) in
                    log.info("打印机断开连接成功")
                    completion(Result.success(true))
                })
                dispatcher?.disconnect()
            } else {
                log.error("当前连接的打印机UUID与请求断开的地址不匹配")
                completion(
                    Result.failure(
                        PigeonError(
                            code: "not-connected",
                            message: "该设备未连接",
                            details: nil
                        )
                    )
                )
            }
        } else {
            log.error("当前没有已连接的打印机")
            completion(
                Result.failure(
                    PigeonError(
                        code: "no-printer-connected",
                        message: "当前没有已连接的打印机",
                        details: nil
                    )
                )
            )
        }
    }

    func sendCommand(
        address: String,
        cmd: String,
        completion: @escaping (Result<Bool, any Error>) -> Void
    ) {
        log.info("发送命令: \(cmd) 到设备: \(address)")
        let dispatcher = PTDispatcher.share()
        if let connectedPrinter = dispatcher?.printerConnected {
            if connectedPrinter.uuid == address {
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
            } else {
                log.error("当前连接的打印机UUID与请求断开的地址不匹配")
                completion(
                    Result.failure(
                        PigeonError(
                            code: "not-connected",
                            message: "该设备未连接",
                            details: nil
                        )
                    )
                )
            }
        } else {
            log.error("当前没有已连接的打印机")
            completion(
                Result.failure(
                    PigeonError(
                        code: "no-printer-connected",
                        message: "当前没有已连接的打印机",
                        details: nil
                    )
                )
            )
        }
    }

    func printerEncoding(
        address: String,
        encoding: String,
        completion: @escaping (Result<Int64, any Error>) -> Void
    ) {
        log.info("设置编码: \(encoding) 到设备: \(address)")
        // 简化实现，返回成功
        completion(Result.success(0))
    }

    func printerPrintAreaSize(
        address: String,
        data: [String],
        completion: @escaping (Result<Int64, any Error>) -> Void
    ) {
        log.info("设置打印区域大小到设备: \(address)")
        // 简化实现，返回成功
        completion(Result.success(0))
    }

    func printerWriteData(
        address: String,
        data: String,
        completion: @escaping (Result<Int64, any Error>) -> Void
    ) {
        log.info("写入数据到设备: \(address)")
        // 简化实现，返回成功
        completion(Result.success(0))
    }

    func printerLine(
        address: String,
        data: [String],
        completion: @escaping (Result<Int64, any Error>) -> Void
    ) {
        log.info("打印行到设备: \(address)")
        // 简化实现，返回成功
        completion(Result.success(0))
    }

    func printerText(
        address: String,
        data: [String],
        completion: @escaping (Result<Int64, any Error>) -> Void
    ) {
        log.info("打印文本到设备: \(address)")
        // 简化实现，返回成功
        completion(Result.success(0))
    }

    func printerForm(
        address: String,
        completion: @escaping (Result<Int64, any Error>) -> Void
    ) {
        log.info("打印表单到设备: \(address)")
        // 简化实现，返回成功
        completion(Result.success(0))
    }

    func printerPrint(
        address: String,
        completion: @escaping (Result<Int64, any Error>) -> Void
    ) {
        log.info("执行打印操作到设备: \(address)")
        // 简化实现，返回成功
        completion(Result.success(0))
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "hm_a300_ble_printer",
            binaryMessenger: registrar.messenger()
        )
        let instance = HmA300BlePrinterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        HmA300BlePrinterHostApiSetup.setUp(
            binaryMessenger: registrar.messenger(),
            api: instance
        )
        // 使用instance实例而不是self来初始化fApi，因为self在静态方法中指向类本身而不是实例
        instance.fApi = HmA300BlePrinterFlutterApi(
            binaryMessenger: registrar.messenger()
        )
    }

    public func handle(
        _ call: FlutterMethodCall,
        result: @escaping FlutterResult
    ) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - CBCentralManagerDelegate方法实现

    // 蓝牙状态变化时调用
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        log.info("蓝牙状态更新: \(central.state)")
        // 这里可以根据需要发送状态变化通知给Flutter
        var map = [String: Any]()
        map["state"] = central.state.rawValue
        if let api = fApi {
            api.onStateChanged(map: map) {
                result in
                switch result {
                case .success:
                    log.info("成功通知Flutter蓝牙状态更新")
                case .failure(let error):
                    log.error("通知Flutter蓝牙状态更新失败: \(error)")
                }
            }
        }
    }

    // 发现设备时调用
    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        log.info("发现设备成功: \(peripheral.name ?? "未知设备")")
    }

    // 连接成功时调用
    public func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        log.info("连接设备成功: \(peripheral.name ?? "未知设备")")
        // 这里可以实现连接成功后的逻辑
    }

    // 连接失败时调用
    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        log.error(
            "连接设备失败: \(peripheral.name ?? "未知设备"), 错误: \(error?.localizedDescription ?? "未知错误")"
        )
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
