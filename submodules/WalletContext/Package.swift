// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "WalletContext",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(
            name: "WalletContext",
            targets: ["WalletContext"]),
    ],
    dependencies: [
        .package(name: "SSignalKit", path: "../SSignalKit"),
        .package(name: "TelegramCore", path: "../TelegramCore"),
        .package(name: "PasscodeCore", path: "../PasscodeCore"),
        .package(name: "WalletBackupCrypto", path: "../WalletBackupCrypto"),
        .package(name: "WalletEngine", path: "../../../../packages/WalletEngine"),
    ],
    targets: [
        .target(
            name: "WalletContext",
            dependencies: [
                .product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                .product(name: "TelegramCore", package: "TelegramCore", condition: nil),
                .product(name: "PasscodeCore", package: "PasscodeCore", condition: nil),
                .product(name: "WalletBackupCrypto", package: "WalletBackupCrypto", condition: nil),
                .product(name: "WalletEngineFFI", package: "WalletEngine", condition: nil),
            ],
            path: "Sources"),
    ]
)
