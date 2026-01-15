// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "MakeProject",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MakeProject", targets: ["MakeProject"])
    ],
    dependencies: [
        .package(url: "https://github.com/tuist/XcodeProj.git", from: "8.15.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "MakeProject",
            dependencies: [
                .product(name: "XcodeProj", package: "XcodeProj"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        )
    ]
)
