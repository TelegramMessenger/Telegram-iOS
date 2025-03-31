// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "XcodeParse",
    platforms: [.macOS(.v11)],
    dependencies: [
        .package(url: "https://github.com/tuist/XcodeProj.git", exact: "9.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "XcodeParse",
            dependencies: [
                "XcodeProj",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
    ]
)
