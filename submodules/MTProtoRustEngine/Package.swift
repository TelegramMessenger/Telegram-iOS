// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "MTProtoRustEngine",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(
            name: "MTProtoRustEngine",
            targets: ["MTProtoRustEngine"]),
    ],
    dependencies: [
        .package(name: "TelegramCore", path: "../TelegramCore"),
        .package(name: "MtProtoKit", path: "../MtProtoKit"),
        .package(name: "SSignalKit", path: "../SSignalKit"),
        .package(name: "EncryptionProvider", path: "../EncryptionProvider"),
        .package(name: "WebProxyTransport", path: "../WebProxyTransport"),
    ],
    targets: [
        .binaryTarget(
            name: "MTProtoEngineFFI",
            path: "MTProtoEngineFFI.xcframework"),
        .target(
            name: "MTProtoRustEngineMapping",
            dependencies: [],
            path: "Sources/MTProtoRustEngineMapping"),
        .target(
            name: "MTProtoRustEngine",
            dependencies: [
                "MTProtoEngineFFI",
                "MTProtoRustEngineMapping",
                .product(name: "TelegramCore", package: "TelegramCore", condition: nil),
                .product(name: "MtProtoKit", package: "MtProtoKit", condition: nil),
                .product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                .product(name: "WebProxyTransport", package: "WebProxyTransport", condition: nil),
            ],
            path: "Sources/MTProtoRustEngine"),
        .testTarget(
            name: "MTProtoRustEngineMappingTests",
            dependencies: ["MTProtoRustEngineMapping"],
            path: "Tests/MTProtoRustEngineMappingTests"),
        .testTarget(
            name: "MTProtoRustEngineTests",
            dependencies: [
                "MTProtoRustEngine",
                "MTProtoEngineFFI",
                "MTProtoRustEngineMapping",
                .product(name: "TelegramCore", package: "TelegramCore", condition: nil),
                .product(name: "MtProtoKit", package: "MtProtoKit", condition: nil),
                .product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                .product(name: "EncryptionProvider", package: "EncryptionProvider", condition: nil),
            ],
            path: "Tests/MTProtoRustEngineTests"),
    ]
)
