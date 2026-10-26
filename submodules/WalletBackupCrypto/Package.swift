// swift-tools-version:5.9

import PackageDescription
import Foundation

let packageDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let iosRoot = packageDirectory.deletingLastPathComponent().deletingLastPathComponent()
let tde2eIncludeRoot = iosRoot.appendingPathComponent("third-party/td/td/tde2e").path

let package = Package(
    name: "WalletBackupCrypto",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(
            name: "WalletBackupCrypto",
            targets: ["WalletBackupCrypto"]),
    ],
    targets: [
        .target(
            name: "WalletBackupCrypto",
            dependencies: [],
            path: ".",
            exclude: ["BUILD"],
            sources: ["Sources"],
            publicHeadersPath: "PublicHeaders",
            cxxSettings: [
                .unsafeFlags(["-I", tde2eIncludeRoot])
            ]),
    ],
    cxxLanguageStandard: .cxx17
)
