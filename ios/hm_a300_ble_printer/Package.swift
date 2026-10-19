// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "hm_a300_ble_printer",
    platforms: [
        .iOS("12.0")  // 与你 podspec 中的 s.platform 保持一致
    ],
    products: [
        // 插件名包含下划线，库名按 Flutter 惯例用连字符
        .library(
            name: "hm-a300-ble-printer",
            targets: ["hm_a300_ble_printer"]
        )
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        // 二进制目标：PrinterSDK.xcframework 放在包根目录
        .binaryTarget(
            name: "PrinterSDK",
            path: "PrinterSDK.xcframework"
        ),
        // 你的插件源代码 target
        .target(
            name: "hm_a300_ble_printer",
            dependencies: [
                "PrinterSDK",  // ← 关键：声明对二进制框架的依赖
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
            // 如果有 PrivacyInfo.xcprivacy，取消下面注释并调整路径
            // resources: [
            //     .process("PrivacyInfo.xcprivacy")
            // ]
        )
    ]
)