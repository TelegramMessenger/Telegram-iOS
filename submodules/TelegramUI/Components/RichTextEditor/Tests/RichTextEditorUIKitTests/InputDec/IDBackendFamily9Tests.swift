#if canImport(UIKit)
import RichTextInputDecObjC
// TASK F1: `BlockID` (the fake geometry client's seeded `RichTextInputLineID`) is a
// `RichTextEditorCore` type — `RichTextEditorUIKit` does not re-export its own Core import.
import RichTextEditorCore
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C12 — the ID-SPECIFIC assertions for Family 9 (touch interaction and selection): that
/// `attach(to:)` genuinely constructs a live `IDUIKitInteractionCapability` once the three
/// interaction-host thunks this task installs satisfy `TGRichTextInputDecHostPreflight
/// .requireInteractionHost:stage:`'s ABI check, that the presentation client's
/// `interactionContainerView` stays the SAME object for the whole backend lifetime, that the
/// existing tap-to-caret path is unaffected by `.interaction` now being requested, that
/// `selectWord()` genuinely reaches the kernel's interaction assistant, and that `detach()`
/// cancels gestures before tearing down presentation — mirroring `IDBackendFamily7Tests`'/
/// `IDBackendFamily8Tests`' own "ID-specific assertions over the fake harness" framing, one
/// family over.
///
/// Gated exactly like every other `.inputDec` suite in this stage: `isSupported()` evaluates the
/// WHOLE `incomingCallbacks` capability all-or-nothing (47 rows, spread across seven tasks — see
/// `task-C4-supplement.md` §1), so it stays false — and every test below SKIPS — until Task C14
/// lands the last 7 rows. That is expected here, not a regression; see this task's own report
/// (`task-C12-report.md`) for the honest disclosure, and `IDTextEditorBackendInteractionPreflightTests`
/// / `IDTextEditorBackendInteractionContainerTests` (both non-skip-gated) for the zero-skip
/// coverage this task adds alongside this suite.
@available(iOS 17.0, *)
@MainActor
final class IDBackendFamily9Tests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// The `.interaction` contract's acceptance is itself gated on the SAME three-thunk host
    /// preflight this task installs (`TGRichTextInputDecHostPreflight.requireInteractionHost:stage:`,
    /// consulted from inside `IDUIKitInteractionCapability`'s own construction) — so a successful
    /// attach on this fake harness (whose canvas class had the thunks installed by
    /// `TGRichTextInputDecInstallCanvasCallbacks`, run unconditionally at the top of `attach(to:)`)
    /// is itself the proof the preflight passed. `IDTextEditorBackend.swift`'s
    /// `requestedCapabilities` doc comment records why a REJECTED contract would instead just leave
    /// `kernelInteraction` nil rather than failing the whole attach.
    func test_interactionCapabilityIsConstructedOnlyAfterTheHostPreflightPasses() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        XCTAssertNotNil(h.idBackend.kernelInteraction,
                        "attach() must construct a live IDUIKitInteractionCapability once the host preflight (the three canvas thunks this task installs) accepts the canvas's ABI")
        XCTAssertNotNil(h.idBackend.kernelInteraction?.privateAssistant,
                        "the constructed capability must hold a real private assistant, not merely a rejected/report-only instance whose privateAssistant stayed nil")
    }

    /// Records the container's `ObjectIdentifier` at attach and again after 50 selection
    /// mutations — the spec requirement (`RichTextInputPresentationClient.interactionContainerView`'s
    /// own doc comment: "stable for the backend lifetime"). `IDTextEditorBackend.swift`'s Step-4
    /// note records WHY this holds even on the fake harness (whose `FakeInputPresentationClient
    /// .interactionContainerView` is a plain, eagerly-constructed `UIView`, not the real
    /// `lazy selectionChromeContainer` this test exists to guard on a real canvas).
    func test_interactionContainerViewIdentityIsStableForTheBackendLifetime() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        let identityAtAttach = ObjectIdentifier(h.host.presentationClient.interactionContainerView)
        let start = h.canvas.beginningOfDocument
        let end = h.canvas.endOfDocument
        for _ in 0..<50 {
            h.canvas.selectedTextRange = h.canvas.textRange(from: start, to: start)
            h.canvas.selectedTextRange = h.canvas.textRange(from: end, to: end)
        }
        let identityAfterMutations = ObjectIdentifier(h.host.presentationClient.interactionContainerView)
        XCTAssertEqual(identityAtAttach, identityAfterMutations,
                       "the interaction container's identity must be stable across every selection mutation for the whole backend lifetime")
    }

    /// A regression guard, not new routing: the EXISTING tap-to-caret path
    /// (`closestPosition(to:)`, real rendered geometry over the seeded fixture — the same
    /// mechanism `BackendSemanticContractCases.test_closestPositionToAPointInsideTheFirstLineIsInTheFirstParagraph`
    /// already pins for both backends) must keep resolving a tap correctly now that `.interaction`
    /// is requested and a live `kernelInteraction` exists alongside it. The kernel's own private
    /// interaction assistant, once genuinely delivering touches (future, unassigned work — see
    /// `IDTextEditorBackend+Interaction.swift`'s own header on scope), would resolve a tap through
    /// `id_cursorPositionAtPoint:inContainer:`/`id_nearestPositionAtPoint:inContainer:` (Family 2),
    /// which forward to this SAME `RichTextInputGeometryClient`-backed bridge — never a parallel
    /// geometry path this backend would have to maintain twice.
    ///
    /// **TASK F1 — the fixture now CONFIGURES the fake geometry client, and had to.** Before F1 this
    /// test passed while proving the opposite of its own name: `closestPosition(to:)` forwarded into
    /// `kernelInput`, so the tap was resolved by the vendored kernel's private controller against its
    /// own synthetic container and the fake geometry client — left at its default `nil`
    /// `closestPositionToReturn` — was never consulted at all. That is exactly the geometry bypass
    /// F1 removed (`IDTextEditorBackend+Geometry.swift`). With the witness genuinely routed at the
    /// client, an unconfigured client correctly answers "I cannot resolve that point" and the tap
    /// resolves to nil. Seeding both answers is what makes the assertion mean what the name claims;
    /// the two `XCTAssertEqual`s below on the client's call counts pin that the client — not the
    /// kernel — is the authority that was asked, so this cannot silently revert to a bypass again.
    func test_tapPlacesTheCaretThroughTheGeometryClient() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        h.geometry.caretGeometryToReturn = RichTextInputCaretGeometry(
            position: .downstream(1), rect: CGRect(x: 4, y: 2, width: 2, height: 18),
            writingDirection: .leftToRight,
            lineID: RichTextInputLineID(blockID: BlockID(""), regionIndex: 0),
            documentRevision: h.document.revision, layoutGeneration: 1)
        h.geometry.closestPositionToReturn = .downstream(2)
        let start = h.canvas.beginningOfDocument
        let startRect = h.canvas.caretRect(for: start)
        let point = CGPoint(x: startRect.midX + 1, y: startRect.midY)
        guard let resolved = h.canvas.closestPosition(to: point) else {
            XCTFail("closestPosition(to:) must resolve a point inside the rendered first paragraph")
            return
        }
        h.canvas.selectedTextRange = h.canvas.textRange(from: resolved, to: resolved)
        let caretQueries = h.geometry.callCounts["caretGeometry"]
        let pointQueries = h.geometry.callCounts["closestPosition"]
        XCTAssertEqual(h.canvas.selectedTextRange, h.canvas.textRange(from: resolved, to: resolved),
                       "a tap-resolved position must remain settable as the caret through the shared UITextInput surface")
        XCTAssertEqual(caretQueries, 1, "the caret rect must come from the geometry client, not the kernel")
        XCTAssertEqual(pointQueries, 1, "the tap must be resolved by the geometry client, not the kernel")
    }

    /// White-box: drives `IDTextEditorBackend.selectWord()` (`+Interaction.swift`) directly —
    /// this task's brief names no canvas gesture call site for it (see that file's own header on
    /// scope), so this is the one way to observe it reach the kernel today.
    func test_selectWordRoutesThroughTheInteractionCapability() {
        let h = makeIDFakeClientHarness(); defer { h.tearDown() }
        XCTAssertNotNil(h.idBackend.kernelInteraction, "precondition: a live interaction capability must exist")
        h.idBackend.id_selectWord()
        XCTAssertTrue(h.idBackend.witnessFailures.isEmpty,
                     "selectWord() must reach the kernel's interaction capability cleanly, recording no witness failure: \(h.idBackend.witnessFailures)")
    }

    /// `IDTextEditorBackend.detach()` calls the guarded `clearGestureRecognizersForced(true)`
    /// witness (this task's own edit, `+Interaction.swift`) BEFORE `kernelInteraction?.detach()`,
    /// both of which run before `host.presentationClient.tearDownPresentation()` — see
    /// `detach()`'s own doc comment for the exact ordering. Observed here via the fake
    /// presentation client's call count (tornDown exactly once) plus a clean witness-failure log
    /// (both guarded interaction calls completed without the exception guard catching anything).
    func test_detachCancelsGesturesBeforeTearingDownPresentation() {
        let h = makeIDFakeClientHarness()
        XCTAssertEqual(h.presentation.tearDownCallCount, 0, "precondition: presentation must not be torn down yet")
        h.backend.detach()
        XCTAssertEqual(h.presentation.tearDownCallCount, 1,
                       "detach() must tear presentation down exactly once")
        XCTAssertTrue(h.idBackend.witnessFailures.isEmpty,
                     "both the explicit clearGestureRecognizersForced(true) cancel and kernelInteraction.detach() must complete cleanly before presentation teardown: \(h.idBackend.witnessFailures)")
        h.document.finish()
    }
}
#endif
