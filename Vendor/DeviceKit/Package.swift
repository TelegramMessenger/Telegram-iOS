// swift-tools-version:5.0
//===----------------------------------------------------------------------===//
//
// This source file is part of the DeviceKit open source project
//
// Copyright © 2014 - 2018 Dennis Weissmann and the DeviceKit project authors
//
// License: https://github.com/dennisweissmann/DeviceKit/blob/master/LICENSE
// Contributors: https://github.com/dennisweissmann/DeviceKit#contributors
//
//===----------------------------------------------------------------------===//

import PackageDescription

let package = Package(
    name: "DeviceKit",
    platforms: [
        .iOS(.v9),
        .tvOS(.v9),
        .watchOS(.v2)
    ],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "DeviceKit",
            targets: ["DeviceKit"])
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "DeviceKit",
            dependencies: [],
            path: "Source"),
        .testTarget(
            name: "DeviceKitTests",
            dependencies: ["DeviceKit"],
            path: "Tests")
    ],
    swiftLanguageVersions: [.v5]
)
