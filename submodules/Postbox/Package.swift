// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Postbox",
    platforms: [.macOS(.v10_12)],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Postbox",
            targets: ["Postbox"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "MurMurHash32", path: "../MurMurHash32"),
        .package(name: "Crc32", path: "../Crc32"),
        .package(name: "sqlcipher", path: "../sqlcipher"),
        .package(name: "StringTransliteration", path: "../StringTransliteration"),
        .package(name: "ManagedFile", path: "../ManagedFile"),
        .package(name: "RangeSet", path: "../Utils/RangeSet"),
        .package(name: "SSignalKit", path: "../SSignalKit"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Postbox",
            dependencies: [.product(name: "MurMurHash32", package: "MurMurHash32", condition: nil),
                            .product(name: "SwiftSignalKit", package: "SSignalKit", condition: nil),
                           .product(name: "ManagedFile", package: "ManagedFile", condition: nil),
                           .product(name: "RangeSet", package: "RangeSet", condition: nil),
                           .product(name: "sqlcipher", package: "sqlcipher", condition: nil),
                           .product(name: "StringTransliteration", package: "StringTransliteration", condition: nil),
                           .product(name: "Crc32", package: "Crc32", condition: nil)],
            path: "Sources"),
    ]
)
