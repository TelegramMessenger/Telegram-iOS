// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RichTextEditor",
    platforms: [.iOS(.v13), .macOS(. v10_13)],
    products: [
        .library(name: "RichTextEditorCore", targets: ["RichTextEditorCore"]),
        .library(name: "RichTextEditorUIKit", targets: ["RichTextEditorUIKit"]),
    ],
    dependencies: [
        .package(path: "../../../MosaicLayout"),
    ],
    targets: [
        .target(name: "RichTextEditorCore"),
        .testTarget(name: "RichTextEditorCoreTests", dependencies: ["RichTextEditorCore"]),
        .target(name: "RichTextEditorUIKit", dependencies: [
            "RichTextEditorCore",
            .product(name: "MosaicLayout", package: "MosaicLayout"),
        ], resources: [.process("Resources/Media.xcassets")]),
        // Phase 0b's differential-corpus oracle. Objective-C, because the harness is VENDORED
        // BYTE-FOR-BYTE from InputDec (`Tests/TextInputDifferential/`) — editing it to be Swift, or
        // to silence a warning, would destroy the only property that makes it an oracle: that it was
        // not written by us. SwiftPM cannot mix Objective-C into an existing Swift target, so this
        // separate target is a necessity, not a style choice (plan ruling C-1).
        //
        // It is deliberately absent from `products:` and from `BUILD`: Bazel compiles only the two
        // `Sources` libraries, so none of this can reach the app build.
        //
        // `condition: .when(platforms: [.iOS])` is load-bearing. `IDTextInputScenario.h` opens with
        // `@import UIKit;`, which does not exist on macOS, and the vendoring rule forbids adding a
        // `TARGET_OS_IPHONE` guard to the file. Without the condition, `swift build` / `swift test`
        // (which build for macOS) would drag this target in through the test target and fail to
        // compile it. With it, the harness builds only for the simulator runs (`Scripts/iostest.sh`),
        // which is the only place it can execute anyway.
        .target(
            name: "RichTextEditorDifferentialHarness",
            path: "Tests/DifferentialSupport",
            // TASK 9d REMOVED `IDTextInputDifferentialRunner.m` FROM THIS LIST. Task 9a had to
            // exclude it because Xcode links a clang target as ONE relocatable object rather than
            // as an archive with per-file granularity, so an uncalled object file's undefined
            // symbols are still fatal: until Tasks 9b/9c/9d wrote `IDTextInputTestHost`,
            // `IDTextInputStateRecorder` and `IDTextInputTransactionDriver`, compiling the runner
            // failed the test-bundle link on four symbols (`_IDTextInputTransactionErrorDomain`
            // and three `_OBJC_CLASS_$_…`). All three now exist, so the runner compiles AND links,
            // and the family tests in `Tests/RichTextEditorUIKitTests/Differential/` drive it.
            //
            // `PROVENANCE.md` stays excluded for the ordinary reason: SwiftPM refuses to build a
            // target with an unhandled non-source file in its path.
            exclude: ["PROVENANCE.md"],
            resources: [.copy("TextInputScenarios")],
            publicHeadersPath: "include"
        ),
        .testTarget(name: "RichTextEditorUIKitTests", dependencies: [
            "RichTextEditorUIKit",
            .target(name: "RichTextEditorDifferentialHarness", condition: .when(platforms: [.iOS])),
        ]),
    ]
)
