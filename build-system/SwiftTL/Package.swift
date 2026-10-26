// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SwiftTL",
    dependencies: [],
    targets: [
        .executableTarget(name: "SwiftTL", dependencies: []),
        .testTarget(name: "SwiftTLTests", dependencies: ["SwiftTL"]),
    ]
)
