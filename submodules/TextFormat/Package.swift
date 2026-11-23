// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "TextFormat",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(name: "TextFormat", targets: ["TextFormat"]),
    ],
    dependencies: [
        .package(name: "TelegramCore", path: "../TelegramCore"),
    ],
    targets: [
        .target(
            name: "TextFormat",
            dependencies: [
                .product(name: "TelegramCore", package: "TelegramCore", condition: nil),
            ],
            path: "Sources",
            sources: ["TrailingHashtagBlock.swift"]),
        .testTarget(
            name: "TextFormatTests",
            dependencies: [
                "TextFormat",
                .product(name: "TelegramCore", package: "TelegramCore", condition: nil),
            ],
            path: "Tests",
            sources: ["TrailingHashtagBlockTests.swift"]),
    ]
)
