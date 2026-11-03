// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TDShim",
    platforms: [
        .iOS(.v17),
        .macOS(.v12),
        .watchOS(.v9),
    ],
    products: [
        .library(name: "TDShim", targets: ["TDShim"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Swiftgram/TDLibFramework", .exact("1.8.64-49b3bcbb")),
    ],
    targets: [
        .target(
            name: "TDShim",
            dependencies: [
                .product(name: "TDLibFramework", package: "TDLibFramework"),
            ]
        ),
        .testTarget(
            name: "TDShimTests",
            dependencies: ["TDShim"]
        ),
    ]
)
