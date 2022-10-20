// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CrowdinSDK",
    platforms: [
        .iOS(.v9)
    ],
    products: [
        .library(name: "CrowdinSDK", targets: ["CrowdinSDK"])
    ],
    dependencies: [
        .package(url: "https://github.com/serhii-londar/BaseAPI.git", .upToNextMajor(from: "0.2.0")),
        .package(url: "https://github.com/daltoniam/Starscream.git", .upToNextMajor(from: "4.0.4"))
    ],
    targets: [
        .target(name: "CrowdinSDK",
                dependencies: ["BaseAPI", "Starscream"],
                path: "Sources/CrowdinSDK",
                exclude: [
                    "Providers/Firebase/"
                ],
                resources: [
                    .process("Resources/Settings/CrowdinLogsVC.storyboard"),
                    .process("Resources/Settings/Images.xcassets"),
                    .process("Resources/Settings/SettingsItemCell.xib"),
                    .process("Resources/Settings/SettingsView.xib")
                ], swiftSettings: [
                    .define("CrowdinSDKSPM")
                ])
    ]
)
