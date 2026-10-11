// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RichTextEditor",
    platforms: [.iOS(.v13), .macOS(. v10_13)],
    products: [
        .library(name: "RichTextEditorCore", targets: ["RichTextEditorCore"]),
        .library(name: "RichTextEditorUIKit", targets: ["RichTextEditorUIKit"]),
        // TASK PH4. Exposed as a product for exactly one consumer: `Host/`, the phase-4 host
        // application, whose "Raw engine" arm builds an `IDBlockTextView` directly so a defect seen
        // through the adapter can be re-checked WITHOUT the adapter in the path. Nothing else in
        // this repo may depend on it.
        //
        // This does NOT put the engine on Telegram's graph. Telegram is built by Bazel from `BUILD`,
        // which has no `deps` edge to `:RichTextInputDecUpstream` and excludes the adapter from
        // `RichTextEditorUIKit`'s `srcs`; `Tests/RichTextEditorCoreTests/SourceBoundary/
        // InputDecUpstreamAdapterBoundaryTests.swift` pins both halves. A SwiftPM product is
        // invisible to Bazel.
        .library(name: "RichTextInputDecUpstream", targets: ["RichTextInputDecUpstream"]),
        .library(name: "RichTextInputDecHost", targets: ["RichTextInputDecHost"]),
        .library(name: "RichTextEngineEditor", targets: ["RichTextEngineEditor"]),
    ],
    dependencies: [
        .package(path: "../../../MosaicLayout"),
    ],
    targets: [
        .target(name: "RichTextEditorCore"),
        .testTarget(name: "RichTextEditorCoreTests", dependencies: ["RichTextEditorCore"]),
        // Vendored InputDec UIKit behavior kernel (Objective-C). The path is deliberately OUTSIDE
        // Sources/RichTextEditorUIKit: the Bazel glob there is `**/*.swift` and would silently drop
        // .m/.h that SwiftPM happily compiles.
        //
        // `publicHeadersPath: "include"` makes SwiftPM synthesize an umbrella-DIRECTORY module map
        // over include/**, so EVERY header there is compiled — including the kernel headers whose
        // line 1 is `#import <UIKit/UIKit.h>`. Since this package also declares `.macOS(.v10_13)`
        // (line 6) and RichTextEditorUIKit depends on this target, the export script wraps every
        // vendored .h AND .m in `#if TARGET_OS_IOS`; without the header half, `swift build` on
        // macOS fails with "module 'UIKit' not found". On macOS every vendored TU is therefore
        // empty and the module is carried by Host/TGRichTextInputDecModuleAnchor.m alone, which is
        // deliberately unguarded.
        //
        // `exclude: ["Vendor"]` is required — the provenance JSON + VENDOR.md inside the target
        // directory are unhandled resources and SwiftPM errors out on them.
        //
        // The two header search paths are BOTH load-bearing and not interchangeable with the
        // umbrella. Quoted `#import`s inside include/Kernel/*.h resolve sibling-relative, but
        // include/TGRichTextInputDec.h and include/TGRichTextInputDecContract.h import kernel
        // headers ACROSS directories, and SwiftPM only propagates `include` itself to dependents.
        //
        // These files are OURS to edit (2026-09-15) — see Sources/RichTextInputDecObjC/Vendor/VENDOR.md.
        // VendorSnapshotIntegrityTests still pins the two GENERATED artifacts, so an accidental edit
        // to a generated blob is still caught; a deliberate one re-records the pin.
        .target(
            name: "RichTextInputDecObjC",
            path: "Sources/RichTextInputDecObjC",
            exclude: ["Vendor"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("include/Kernel"),
            ]
        ),
        // PORTED from upstream InputDec (78 files, 16,492 upstream lines) — the real text engine.
        // A FORK, not a synced snapshot: no export script owns it, no integrity test pins it.
        // See Sources/RichTextInputDecUpstream/PROVENANCE.md for the upstream commit, the
        // working-tree caveat, and every deviation.
        //
        // The `../RichTextInputDecObjC/include/Kernel` search path is REQUIRED and is not
        // redundant with the dependency. SwiftPM propagates a dependency's `publicHeadersPath`
        // directory and nothing else — not its cSettings header search paths — so a dependent
        // sees include/ but NOT include/Kernel/. Three ported files import kernel headers by
        // bare basename (IDUIKitBehaviorBackend.h, IDUIKitBehaviorCapabilities.h,
        // IDUIKitBehaviorKernel.h). A relative path escaping the target directory is accepted
        // by SwiftPM as long as it stays inside the package; verified before this was written.
        //
        // Every ported file is wrapped in `#if TARGET_OS_IOS` (the export script's own
        // convention, applied here for the same reason: this package also declares .macOS and
        // 14 of these files open with `@import UIKit;`). That leaves the whole module empty on
        // macOS, so TextView/RichTextInputDecUpstreamModuleAnchor.m is deliberately unguarded —
        // exactly as Host/TGRichTextInputDecModuleAnchor.m is for the vendored sibling.
        .target(
            name: "RichTextInputDecUpstream",
            dependencies: ["RichTextInputDecObjC"],
            path: "Sources/RichTextInputDecUpstream",
            exclude: ["PROVENANCE.md"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("Internal"),
                .headerSearchPath("../RichTextInputDecObjC/include/Kernel"),
            ]
        ),
        // The HOST LAYER over the ported engine: observation and host-driven content
        // replacement, by subclass and handler-chaining. It edits NO ported file.
        //
        // It needs THREE search paths beyond its own: the engine's public headers, the engine's
        // Internal/ headers (documentChangeHandler and id_textStorageAdapter live there), and the
        // kernel headers that IDBlockTextViewInternal.h imports by bare basename. SwiftPM
        // propagates a dependency's publicHeadersPath and nothing else.
        //
        // NO BAZEL TARGET, DELIBERATELY (Global Constraint 7).
        .target(
            name: "RichTextInputDecHost",
            dependencies: ["RichTextInputDecUpstream"],
            path: "Sources/RichTextInputDecHost",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("../RichTextInputDecUpstream/include"),
                .headerSearchPath("../RichTextInputDecUpstream/Internal"),
                .headerSearchPath("../RichTextInputDecObjC/include/Kernel"),
            ]
        ),
        .target(
            name: "RichTextEngineEditor",
            dependencies: [
                "RichTextEditorCore",
                "RichTextEditorUIKit",
                "RichTextInputDecUpstream",
                "RichTextInputDecHost",
            ],
            path: "Sources/RichTextEngineEditor"
        ),
        // PHASE 2: this target DOES depend on RichTextInputDecUpstream and the Bazel target does
        // NOT, and the asymmetry is the whole design — read BUILD's `srcs` exclude for the full
        // reasoning. Short version: `InputBackend/InputDec/Upstream/` holds the adapter over the
        // real ported engine (`IDUpstreamInputBackend`), it must `import RichTextInputDecUpstream`,
        // and that import must not reach the APP, because `IDBlockTextView.m`'s pre-`main` `+load`
        // would then run on every launch for every user and can `@throw` uncaught. Bazel builds the
        // app; this package is test-only here. So the edge lives here, the files are excluded there,
        // and `Tests/RichTextEditorCoreTests/SourceBoundary/InputDecUpstreamAdapterBoundaryTests.swift`
        // pins both halves so the divergence cannot go quiet.
        //
        // On macOS every ported file compiles to nothing (`#if TARGET_OS_IOS`) and the adapter is
        // `#if canImport(UIKit)`-guarded, so `swift build` for macOS is unaffected by this edge.
        .target(name: "RichTextEditorUIKit", dependencies: [
            "RichTextEditorCore",
            "RichTextInputDecObjC",
            "RichTextInputDecUpstream",
            .product(name: "MosaicLayout", package: "MosaicLayout"),
        ], resources: [.process("Resources/Media.xcassets")],
        // Task B6: enables the InputDec backend's isSupported() gate. Stage B still has no
        // production call site that selects anything but `.legacy` (RichTextInputCanvasFactory),
        // so defining this is safe here — it only makes `isSupported()`'s real answer observable.
        swiftSettings: [.define("TG_RICHTEXT_INPUTDEC_ENABLED")]),
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
        // Task P2's stock-parity support layer, ported from InputDec's `Tests/` (NOT from its
        // product source). Objective-C for two independent reasons, both forced:
        //
        //  1. `IDSpellingReadinessProbe.m` is 1,083 upstream lines that swizzle the private
        //     `UITextInputController` / `UITextCheckingController` via `method_setImplementation`
        //     and call through raw `IMP` casts. Transliterating it to Swift would destroy the one
        //     property that makes it an oracle — that it was not written by us.
        //  2. Several parity assertions need an `objc_msgSend` cast Swift cannot form at all
        //     (the private 6-argument loupe gesture takes three `CGPoint`-returning blocks and an
        //     out-`BOOL *`). Task P1 had to DROP a whole upstream test for exactly this; the shim
        //     lives here so the Swift suites can call it.
        //
        // It is deliberately separate from `RichTextEditorDifferentialHarness`, which is
        // PROVENANCE-governed as a byte-for-byte vendoring and must not absorb new files.
        //
        // `condition: .when(platforms: [.iOS])` on the *dependency* (below) is what keeps this off
        // the macOS `swift build` / `swift test` path: every file here opens with `@import UIKit`.
        .target(
            name: "RichTextEditorStockParitySupport",
            path: "Tests/StockParitySupport",
            publicHeadersPath: "include"
        ),
        // NOTE: the Task A6 brief's listing for this target reads
        // `dependencies: ["RichTextEditorUIKit", "RichTextInputDecObjC"]`, which predates the
        // differential harness and would DROP it. The harness entry (with its iOS-only condition)
        // must stay: `IDTextInputScenario.h` opens with `@import UIKit;` and cannot be guarded.
        .testTarget(name: "RichTextEditorUIKitTests", dependencies: [
            "RichTextEditorUIKit",
            "RichTextInputDecObjC",
            "RichTextInputDecUpstream",
            "RichTextEngineEditor",
            .target(name: "RichTextEditorDifferentialHarness", condition: .when(platforms: [.iOS])),
            .target(name: "RichTextEditorStockParitySupport", condition: .when(platforms: [.iOS])),
        ]),
    ]
)
