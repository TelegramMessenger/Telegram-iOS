// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription


let package = Package(
    name: "TdBinding",
    platforms: [
        .macOS(.v10_13)
    ],
    products: [
        .library(
            name: "TdBinding",
            targets: ["TdBinding"]),
    ],
    targets: [
        .target(
            name: "TdBinding",
            dependencies: [],
            path: ".",
            publicHeadersPath: "Public",
            cxxSettings: [
                .headerSearchPath("SharedHeaders/td/tde2e"),
            ]),
    ],
    cxxLanguageStandard: .cxx20
)
