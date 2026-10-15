// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "TelegramApi",
    platforms: [.macOS(.v10_13)],
    products: [
        .library(name: "TelegramApi", targets: ["TelegramApi"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TelegramApiObjC",
            path: "ObjC",
            // SwiftPMGenerated (and Sources/SwiftPMGenerated, Tests/SwiftPMGenerated) hold the
            // generated sources, written by generate-swiftpm.sh and gitignored: run it before
            // building. Bazel generates its own.
            sources: ["Sources", "SwiftPMGenerated"],
            publicHeadersPath: "PublicHeaders",
            // The TLObject root implements retain/release itself (MRC); SwiftPM defaults to ARC.
            cSettings: [.unsafeFlags(["-fno-objc-arc"])],
            linkerSettings: [.linkedFramework("Foundation"), .linkedLibrary("z")]),
        .target(
            name: "TelegramApi",
            dependencies: ["TelegramApiObjC"],
            path: "Sources"),
        .target(
            name: "TLRuntimeFixture",
            dependencies: ["TelegramApiObjC"],
            path: "TestSupport/RuntimeFixture",
            cSettings: [.unsafeFlags(["-fno-objc-arc"])]),
        .testTarget(
            name: "TelegramApiTests",
            dependencies: ["TelegramApi", "TelegramApiObjC", "TLRuntimeFixture"],
            path: "Tests"),
    ]
)
