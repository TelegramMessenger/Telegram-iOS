// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TelegramCore",
    platforms: [.macOS(.v10_12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TelegramCore",
            targets: ["TelegramCore"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "Postbox", path: "../Postbox"),
        .package(name: "SSignalKit", path: "../SSignalKit"),
        .package(name: "MtProtoKit", path: "../MtProtoKit"),
        .package(name: "TelegramApi", path: "../TelegramApi"),
        .package(name: "CryptoUtils", path: "../CryptoUtils"),
        .package(name: "NetworkLogging", path: "../NetworkLogging"),
        .package(name: "Reachability", path: "../Reachability"),
        .package(name: "EncryptionProvider", path: "../EncryptionProvider"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TelegramCore",
            dependencies: [.product(name: "Postbox", package: "Postbox", condition: nil),
                            .product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                            .product(name: "MtProtoKit", package: "MtProtoKit", condition: nil),
                           .product(name: "TelegramApi", package: "TelegramApi", condition: nil),
                           .product(name: "CryptoUtils", package: "CryptoUtils", condition: nil),
                           .product(name: "NetworkLogging", package: "NetworkLogging", condition: nil),
                           .product(name: "Reachability", package: "Reachability", condition: nil),
                           .product(name: "EncryptionProvider", package: "EncryptionProvider", condition: nil)],
            path: "Sources"),
    ]
)
