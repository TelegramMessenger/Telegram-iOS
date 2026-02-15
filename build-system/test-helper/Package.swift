// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "test-helper",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/Swiftgram/TDLibKit", exact: "1.5.2-tdlib-1.8.60-cb863c16"),
    ],
    targets: [
        .executableTarget(
            name: "test-helper",
            dependencies: ["TDLibKit"]
        ),
    ]
)
