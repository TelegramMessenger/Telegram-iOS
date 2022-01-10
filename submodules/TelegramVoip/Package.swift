// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TelegramVoip",
    platforms: [.macOS(.v10_11)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TelegramVoip",
            targets: ["TelegramVoip"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "TgVoipWebrtc", path: "../../../tgcalls"),
        .package(name: "SSignalKit", path: "../SSignalKit"),
        .package(name: "TelegramCore", path: "../TelegramCore")

    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TelegramVoip",
            dependencies: [
                .productItem(name: "TgVoipWebrtc", package: "TgVoipWebrtc", condition: nil),
                .productItem(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                .productItem(name: "TelegramCore", package: "TelegramCore", condition: nil),
            ],
            path: "Sources",
            exclude: [
                "IpcGroupCallContext.swift",
                "OngoingCallContext.swift",
            ],
            cxxSettings: [
                .define("WEBRTC_MAC", to: "1", nil),
            ]),
    ]
)
