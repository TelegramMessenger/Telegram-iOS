#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// `@MainActor`: `IDTextEditorBackend.isSupported()` is main-actor isolated (inherited from
/// `RichTextInputBackend`, which is `@MainActor` — see `RichTextInputCanvasFactory.swift`'s doc
/// comment on the same point) — an XCTestCase's test methods are nonisolated by default, so this
/// class-level annotation is required. Matches the existing convention in
/// `Tests/RichTextEditorUIKitTests/InputDec/CanvasFactoryTests.swift`.
@available(iOS 17.0, *)   // decision 2: the floor is 17.0, not the manifest's 26.x
@MainActor
final class IsSupportedTests: XCTestCase {

    /// Purity: calling it must not construct a private object or install a method. Proved by
    /// asserting the legacy class still answers nothing after 100 calls (installation would
    /// leave a trace) and that repeated calls agree.
    func test_isSupportedIsPureAndStable() {
        let first = IDTextEditorBackend.isSupported()
        for _ in 0..<100 { XCTAssertEqual(IDTextEditorBackend.isSupported(), first) }
        XCTAssertFalse(DocumentCanvasView().responds(to: Selector(("_inputController"))))
    }

    /// DECISION 2 (2026-08-17): the floor is iOS 17.0, NOT an exact manifest-build match.
    /// isSupported() may therefore say yes on an OS the manifest never certified — the
    /// contract evaluation below, not the OS band, is what keeps that safe.
    func test_isSupportedRequiresAtLeastIOS17() {
        let running = ProcessInfo.processInfo.operatingSystemVersion
        if running.majorVersion < 17 {
            XCTAssertFalse(IDTextEditorBackend.isSupported(),
                           "the iOS 17.0 floor must be enforced regardless of contract acceptance")
        }
    }

    /// The manifest's runtime block is now provenance, not a gate. Pin that it is still READ
    /// (a manifest that fails to load must make isSupported() false), while asserting it does
    /// NOT constrain the answer to one build.
    func test_theManifestIsRequired_butItsBuildDoesNotGateTheAnswer() throws {
        let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest(),
                                     "a missing manifest must be a hard no, not a silent yes")
        let running = ProcessInfo.processInfo.operatingSystemVersion
        let runningString = "\(running.majorVersion).\(running.minorVersion)"
        if IDTextEditorBackend.isSupported() && runningString != manifest.osVersion {
            // Expected under decision 2. Recorded, not failed — this is the whole point of
            // moving from an exact band to a floor plus live contract evaluation.
            print("isSupported() == true on \(runningString), certified on \(manifest.osVersion)")
        }
    }

    /// Task B6 Step 6 measurement (K1 CA0A2186… and K3 FA6F7462…, both 26.5/23F73 — the
    /// certified band): `isSupported() == false` on both, because `incomingCallbacks` is
    /// rejected ("Class TGRichTextInputDecLayoutController is unavailable") while
    /// `inputController` and `typingAttributes` are both accepted. This is the real ABI
    /// boundary today, not a drift: `TGRichTextInputDecLayoutController` is only a manifest-data
    /// rename (see `Vendor/VENDOR.md`'s rename table) — no Objective-C class of that name has
    /// been vendored yet (`grep` for `@interface TGRichTextInputDecLayoutController` returns
    /// nothing), so the mandatory `incomingCallbacks` contract cannot resolve until a later task
    /// vendors that class. `mandatoryContractsAccepted` correctly reports this as a rejection
    /// rather than silently passing.
    func test_mandatoryContractsAreEvaluated_notAssumed() throws {
        let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
        // `.system()`, not the brief's `.systemResolver()`: the ObjC factory is
        // `+ (instancetype)systemResolver` on `IDUIKitCapabilityResolver`, and the Swift importer
        // strips the class-name-echoing suffix ("Resolver") from a factory method name — the
        // compiler itself renames the miscompiling call ("'systemResolver()' has been renamed to
        // 'system()'"), matching the precedent already used in `CanvasABIWitnessTests.swift:35`.
        let resolver = IDUIKitCapabilityResolver.system()
        for name in ["inputController", "typingAttributes", "incomingCallbacks"] {
            let contract = try XCTUnwrap(manifest.capabilities[name])
            let result = resolver.evaluateContract(contract)
            if IDTextEditorBackend.isSupported() {
                XCTAssertTrue(result.isAccepted,
                              "\(name) rejected: \(result.mismatches)")
            }
        }
    }

    func test_forbiddenSymbolsAreAbsentFromTheRuntimeWeUse() throws {
        let manifest = try XCTUnwrap(TGRichTextInputDecContractManifest())
        for symbol in manifest.forbiddenSymbols where symbol.hasPrefix("_UIText") {
            // The reference backend's classes may exist in UIKit; what must be true is that we
            // never *name* them. This asserts our own module does not resolve them.
            XCTAssertNil(Bundle(for: IDDocumentCanvasView.self).classNamed(symbol))
        }
    }
}
#endif
