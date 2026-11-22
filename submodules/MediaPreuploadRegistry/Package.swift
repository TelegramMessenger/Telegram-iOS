// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "MediaPreuploadRegistry",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(name: "MediaPreuploadRegistry", targets: ["MediaPreuploadRegistry"])
    ],
    dependencies: [
        .package(name: "SSignalKit", path: "../SSignalKit")
    ],
    targets: [
        .target(
            name: "MediaPreuploadRegistry",
            dependencies: [
                .product(name: "SwiftSignalKit", package: "SSignalKit")
            ],
            path: "Sources"
        )
    ]
)
