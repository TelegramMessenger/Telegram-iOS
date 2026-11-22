// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PasscodeCore",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(
            name: "PasscodeCore",
            targets: ["PasscodeCore"]),
        .library(
            name: "PasscodeAccountManager",
            targets: ["PasscodeAccountManager"]),
    ],
    dependencies: [
        .package(name: "SSignalKit", path: "../SSignalKit"),
        .package(name: "TelegramCore", path: "../TelegramCore"),
    ],
    targets: [
        .target(
            name: "PasscodeCore",
            dependencies: [.product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil)],
            path: "Sources",
            exclude: ["AccountManagerIntegration.swift"]),
        .target(
            name: "PasscodeAccountManager",
            dependencies: ["PasscodeCore",
                           .product(name: "TelegramCore", package: "TelegramCore", condition: nil)],
            path: "Sources",
            sources: ["AccountManagerIntegration.swift"]),
        .testTarget(
            name: "PasscodeCoreTests",
            dependencies: ["PasscodeCore"],
            path: "Tests/PasscodeCoreTests"),
    ]
)
