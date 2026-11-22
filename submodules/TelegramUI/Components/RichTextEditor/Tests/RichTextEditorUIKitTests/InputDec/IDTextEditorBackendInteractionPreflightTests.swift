#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C12 — the NON-skip-gated coverage for Family 9's preflight-gating decision: that
/// `TGRichTextInputDecHostPreflight.requireInteractionHost(_:stage:)` — the ABI-shape check the
/// kernel's own `IDUIKitInteractionCapability` init runs while constructing `.interaction` — genuinely
/// distinguishes a canvas that has the three interaction-host thunks (`interactionAssistant`,
/// `_textInputViewForAddingGestureRecognizers`, `selectionContainerView`, all installed by
/// `TGRichTextInputDecInstallCanvasCallbacks`, this task's own edit to
/// `TGRichTextInputDecCanvasCallbacks.m`) from one that does not.
///
/// This needs NO live kernel, NO host, NO `IDTextEditorBackend` attach at all — the class method is
/// public API of `RichTextInputDecObjC`, and `TGRichTextInputDecInstallCanvasCallbacks` is
/// idempotent (`class_addMethod` returns NO, harmlessly, on a repeat call) — so this is genuinely
/// EXECUTABLE on this runtime, unlike every `IDBackendFamily9Tests` assertion, which stays
/// skip-gated until Task C14. `TGRichTextInputDecHostPreflight.requireInteractionHost(_:stage:)`
/// raises `NSException` on a mismatch (it is one of the kernel's own raise sites, not a
/// nil-returning one — `TGRichTextInputDecHostPreflight.m`), so every call below is wrapped in the
/// exception guard, exactly like every kernel-facing crossing point in this package must be.
@available(iOS 17.0, *)
@MainActor
final class IDTextEditorBackendInteractionPreflightTests: XCTestCase {

    /// `IDDocumentCanvasView` specifically — the SAME class the real `.interaction` contract
    /// evaluates the ABI of during a genuine attach. `TGRichTextInputDecInstallCanvasCallbacks` is
    /// called unconditionally here (not implicitly, via `makeIDFakeClientHarness`/`attach(to:)`) so
    /// this test is independent of whether ANY backend has ever attached in this process.
    func test_requireInteractionHost_passesForACanvasWithTheThreeThunksInstalled() {
        var installError: NSError?
        XCTAssertTrue(TGRichTextInputDecInstallCanvasCallbacks(
            IDDocumentCanvasView.self, DocumentCanvasView.self, &installError), "\(installError as Any)")
        let canvas = IDDocumentCanvasView()
        var preflightError: NSError?
        let ok = TGRichTextInputDecPerform({
            TGRichTextInputDecHostPreflight.requireInteractionHost(canvas, stage: "test")
        }, &preflightError)
        XCTAssertTrue(ok, "the preflight must not raise once the three interaction-host thunks are installed: \(preflightError?.localizedDescription ?? "<no error>")")
        XCTAssertNil(preflightError)
    }

    /// The negative case: a `DocumentCanvasView` (the LEGACY base class) never acquires the three
    /// thunks by design (`TGRichTextInputDecInstallCanvasCallbacks` refuses to install onto its own
    /// `forbiddenBaseClass` argument — `CanvasCallbackInstallationTests
    /// .test_installRejectsTheForbiddenBaseClassItself` pins that refusal), so it is a genuine,
    /// always-available fixture for "the ABI check must actually reject something".
    func test_requireInteractionHost_throwsForACanvasLackingTheThreeThunks() {
        let legacy = DocumentCanvasView()
        var preflightError: NSError?
        let ok = TGRichTextInputDecPerform({
            TGRichTextInputDecHostPreflight.requireInteractionHost(legacy, stage: "test")
        }, &preflightError)
        XCTAssertFalse(ok, "the preflight must raise for a canvas lacking the three interaction-host thunks")
        XCTAssertNotNil(preflightError)
    }

    /// Stronger than "it throws": the caught reason must actually NAME the missing selector, not
    /// merely fail for some unrelated cause — pins `TGRichTextInputDecHostPreflight.m`'s own
    /// mismatch-message shape (`"<stage> failed: interaction host ABI mismatch:\n<selector> is
    /// missing"`) so a future change to that file's wording is a visible test failure here, not a
    /// silently weaker guarantee.
    ///
    /// **ONLY `selectionContainerView`, not all three — a real, measured finding, not the naive
    /// expectation.** A first draft asserted all three selector names appeared as "missing" and
    /// went genuinely RED (`XCTAssertTrue failed … got: "… ABI mismatch:\nselectionContainerView is
    /// missing"` — quoted verbatim in this task's report): on this SDK, `UIView`/`UIResponder`
    /// (an ANCESTOR of `DocumentCanvasView`, nothing this file or the kernel installs) already
    /// answers `-interactionAssistant` and `-_textInputViewForAddingGestureRecognizers` with SOME
    /// private implementation of its own — mirroring `CanvasCallbackInstallationTests`'s own
    /// documented finding that a bare `UIView()` already responds to `interactionAssistant` for the
    /// unrelated `textInputView`/`_deleteBackwardAndNotify:` pair. `IDDocumentCanvasView`'s own
    /// thunks still win for real (Objective-C method resolution always prefers the SUBCLASS's own
    /// `class_addMethod`-installed IMP over an inherited one), so this changes nothing about
    /// whether the preflight passes for `IDDocumentCanvasView` — only about which selector(s) a
    /// LEGACY canvas is caught missing.
    func test_requireInteractionHost_mismatchReasonNamesTheMissingSelector() {
        let legacy = DocumentCanvasView()
        var preflightError: NSError?
        _ = TGRichTextInputDecPerform({
            TGRichTextInputDecHostPreflight.requireInteractionHost(legacy, stage: "IDTextEditorBackendInteractionPreflightTests")
        }, &preflightError)
        let description = preflightError?.localizedDescription ?? ""
        XCTAssertTrue(description.contains("selectionContainerView is missing"),
                     "the mismatch reason must name 'selectionContainerView' as missing; got: \(description)")
    }
}
#endif
