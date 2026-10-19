import Flutter
import UIKit

public class HmA300BlePrinterPlugin: NSObject, FlutterPlugin, HmA300BlePrinterHostApi {
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
    func getPlatformNameAsync() async throws -> String {
        return await "iOS " + UIDevice.current.systemVersion
    }
    
    func getRunningInfoAsync() async throws -> String {
        var st = try await fApi!.getDartVersionAsync()
        st += "\n"
        await st += ("iOS " + UIDevice.current.systemVersion)
        return st
    }
}
