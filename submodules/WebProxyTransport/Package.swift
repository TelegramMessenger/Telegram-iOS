// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "WebProxyTransport",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(name: "WebProxyTransport", targets: ["WebProxyTransport"])
    ],
    dependencies: [
        .package(name: "MtProtoKit", path: "../MtProtoKit"),
        .package(name: "SSignalKit", path: "../SSignalKit")
    ],
    targets: [
        .target(
            name: "WebProxyTransport",
            dependencies: [
                .product(name: "MtProtoKit", package: "MtProtoKit"),
                .product(name: "SwiftSignalKit", package: "SSignalKit")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "WebProxyTransportTests",
            dependencies: ["WebProxyTransport"],
            path: "Tests"
        )
    ]
)
