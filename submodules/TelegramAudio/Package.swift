// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TelegramAudio",
    platforms: [.macOS(.v10_13)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "TelegramAudio",
            targets: ["TelegramAudio"]),
    ],
    dependencies: [
        .package(name: "SSignalKit", path: "../SSignalKit"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "TelegramAudio",
            dependencies: [
                .product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
            ],
            path: "Macos"),
    ]
)
