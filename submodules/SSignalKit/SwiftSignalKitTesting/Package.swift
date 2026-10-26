// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "SwiftSignalKitTesting",
    platforms: [.macOS(.v10_13)],
    products: [
        .executable(name: "SignalKitBench", targets: ["SignalKitBench"]),
    ],
    targets: [
        .target(
            name: "SwiftSignalKitLegacy",
            path: "Modules/SwiftSignalKitLegacy"),
        .target(
            name: "SwiftSignalKit2",
            path: "Modules/SwiftSignalKit2"),
        .target(
            name: "ScenariosLegacy",
            dependencies: ["SwiftSignalKitLegacy"],
            path: "ScenarioTargets/ScenariosLegacy",
            swiftSettings: [.define("SSK_LEGACY")]),
        .target(
            name: "ScenariosV2",
            dependencies: ["SwiftSignalKit2"],
            path: "ScenarioTargets/ScenariosV2"),
        .testTarget(
            name: "LegacyBehaviorTests",
            dependencies: ["SwiftSignalKitLegacy"],
            path: "BehaviorTargets/LegacyBehaviorTests",
            swiftSettings: [.define("SSK_LEGACY")]),
        .testTarget(
            name: "V2BehaviorTests",
            dependencies: ["SwiftSignalKit2"],
            path: "BehaviorTargets/V2BehaviorTests"),
        .testTarget(
            name: "LegacyStressTests",
            dependencies: ["SwiftSignalKitLegacy"],
            path: "StressTargets/LegacyStressTests",
            swiftSettings: [.define("SSK_LEGACY")]),
        .testTarget(
            name: "V2StressTests",
            dependencies: ["SwiftSignalKit2"],
            path: "StressTargets/V2StressTests"),
        .testTarget(
            name: "ParityTests",
            dependencies: ["ScenariosLegacy", "ScenariosV2"],
            path: "ParityTests"),
        .testTarget(
            name: "V2Tests",
            dependencies: ["SwiftSignalKit2"],
            path: "V2Tests"),
        .executableTarget(
            name: "SignalKitBench",
            dependencies: ["ScenariosLegacy", "ScenariosV2"],
            path: "Bench"),
    ]
)
