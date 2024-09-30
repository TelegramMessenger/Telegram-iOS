// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "OpenSSLEncryption",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .library(
            name: "OpenSSLEncryption",
            targets: ["OpenSSLEncryption"]),
    ],
    targets: [
        .target(
            name: "OpenSSLEncryption",
            dependencies: [],
            path: ".",
            exclude: ["BUILD"],
            publicHeadersPath: "PublicHeaders",
            cSettings: [
                .headerSearchPath("PublicHeaders"),
                .headerSearchPath("SharedHeaders/openssl/include"),
                .headerSearchPath("SharedHeaders/EncryptionProvider"),
            ]),
    ]
)
