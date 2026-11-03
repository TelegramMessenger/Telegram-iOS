// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MosaicLayout",
    platforms: [.iOS(.v13), .macOS(.v10_13)],
    products: [
        .library(name: "MosaicLayout", targets: ["MosaicLayout"]),
    ],
    targets: [
        .target(name: "MosaicLayout", path: "Sources"),
    ]
)
