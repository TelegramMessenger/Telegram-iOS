// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SupportTemplates",
    platforms: [.iOS(.v13), .macOS(.v10_13)],
    products: [
        .library(name: "SupportTemplates", targets: ["SupportTemplates"]),
    ],
    targets: [
        .target(name: "SupportTemplates", path: "Sources"),
        .testTarget(name: "SupportTemplatesTests", dependencies: ["SupportTemplates"], path: "Tests"),
    ]
)
