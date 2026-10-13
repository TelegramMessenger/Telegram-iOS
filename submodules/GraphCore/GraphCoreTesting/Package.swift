// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "GraphCoreTesting",
    platforms: [.macOS(.v10_13)],
    products: [
        .executable(name: "GraphCoreBench", targets: ["GraphCoreBench"]),
    ],
    targets: [
        .target(
            name: "GraphCoreLegacy",
            path: "Modules/GraphCoreLegacy",
            swiftSettings: [.unsafeFlags(["-enable-testing"])]),
        .target(
            name: "GraphCore2",
            path: "Modules/GraphCore2",
            swiftSettings: [.unsafeFlags(["-enable-testing"])]),
        .target(
            name: "ScenariosLegacy",
            dependencies: ["GraphCoreLegacy"],
            path: "ScenarioTargets/ScenariosLegacy",
            swiftSettings: [.define("GC_LEGACY")]),
        .target(
            name: "ScenariosV2",
            dependencies: ["GraphCore2"],
            path: "ScenarioTargets/ScenariosV2"),
        .testTarget(
            name: "ParityTests",
            dependencies: ["ScenariosLegacy", "ScenariosV2"],
            path: "ParityTests"),
        .testTarget(
            name: "AnimationTests",
            dependencies: ["GraphCoreLegacy", "GraphCore2"],
            path: "AnimationTests"),
        .executableTarget(
            name: "GraphCoreBench",
            dependencies: ["ScenariosLegacy", "ScenariosV2"],
            path: "Bench"),
    ]
)
