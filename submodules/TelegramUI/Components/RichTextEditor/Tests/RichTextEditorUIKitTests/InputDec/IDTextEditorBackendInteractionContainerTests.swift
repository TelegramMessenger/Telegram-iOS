#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C12 — the NON-skip-gated coverage for Family 9's container-identity invariant: that
/// `DocumentCanvasView.selectionChromeContainer` (`lazy`, per that property's own doc comment) is
/// already forced into existence by the canvas's OWN construction — via the `TelegramPresentationInputClient`
/// it builds internally, immediately before `self.inputBackend.attach(to: self)` runs
/// (`DocumentCanvasView.init`'s "Interaction backend seam" comment) — with no help needed from the
/// ID backend's OWN `attach(to:)`. See `IDTextEditorBackend.swift`'s Step-4 doc comment for the
/// full verification this task's report records.
///
/// This needs NO live kernel and NO `IDTextEditorBackend` attach at all — the invariant lives
/// entirely in `DocumentCanvasView`/`TelegramPresentationInputClient`, so it is genuinely
/// EXECUTABLE on this runtime, unlike `IDBackendFamily9Tests
/// .test_interactionContainerViewIdentityIsStableForTheBackendLifetime`, which stays skip-gated
/// until Task C14 (and, run against the FAKE harness, exercises `FakeInputPresentationClient`'s own
/// plain, non-`lazy` `UIView` — not this real mechanism at all).
@available(iOS 17.0, *)
@MainActor
final class IDTextEditorBackendInteractionContainerTests: XCTestCase {

    /// Mirrors `IDTextEditorBackendWindowRemovalTests.makeUnattachedCanvas()`, verbatim in intent
    /// — `IDDocumentCanvasView(inputBackend:)`'s init self-attaches and can hit `assertionFailure()`
    /// on the EXPECTED `incomingCallbacks` rejection with no reporter installed; swallowing that one
    /// EXPECTED report is enough to get a live canvas with no risk of masking a genuinely new
    /// failure.
    private func makeUnattachedCanvas() -> IDDocumentCanvasView {
        let previousReporter = RichTextInputContractViolation.reporter
        RichTextInputContractViolation.reporter = { _ in }
        let canvas = IDDocumentCanvasView(inputBackend: IDTextEditorBackend())
        RichTextInputContractViolation.reporter = previousReporter
        canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 600)
        return canvas
    }

    /// The forcing itself, proven — not merely that a LATER read happens to agree with an EARLIER
    /// one (which would also hold if BOTH were lazily realized on first read, a materially weaker
    /// guarantee than "already stable by construction"). `selectionChromeContainer`'s lazy
    /// initializer calls `addSubview(v)` as a side effect, so `canvas.subviews.count` distinguishes
    /// "already forced" (reading it now adds NOTHING) from "forced for the first time by this very
    /// read" (reading it now adds exactly one subview).
    ///
    /// **Proven capable of failing, not merely capable of passing**: commenting out
    /// `canvas.prepareInteractionContainer()` inside `TelegramPresentationInputClient.init`
    /// (`DocumentCanvasView.swift`) and re-running this test — done, then reverted, for this
    /// report — makes `countAfterFirstRead` genuinely `countBeforeAnyRead + 1`, a real
    /// `XCTAssertEqual failed` with the mismatched counts quoted in this task's report, because the
    /// canvas's own internal `TelegramPresentationInputClient` no longer forces the container ahead
    /// of this test's own first read.
    func test_constructingTheCanvasAlreadyForcesTheInteractionContainer_beforeAnyExplicitRead() {
        let canvas = makeUnattachedCanvas()
        let countBeforeAnyRead = canvas.subviews.count
        _ = canvas.selectionChromeContainer
        let countAfterFirstRead = canvas.subviews.count
        XCTAssertEqual(countAfterFirstRead, countBeforeAnyRead,
                       "reading selectionChromeContainer must add NO new subview here — the canvas's own construction (via its internal TelegramPresentationInputClient) must have already forced it")
    }

    /// The identity fact `TelegramPresentationInputClientTests` already pins for a PLAIN
    /// `DocumentCanvasView` — this test is the missing counterpart for the `IDDocumentCanvasView`
    /// subclass specifically, constructed under the SAME reporter-guarded, `IDTextEditorBackend`
    /// self-attach path Family 9's real attach uses (`makeUnattachedCanvas()` above), not a bare
    /// `DocumentCanvasView()`.
    func test_interactionContainerViewOnTheIDCanvas_isTheSameObjectAsSelectionChromeContainer() {
        let canvas = makeUnattachedCanvas()
        let client = TelegramPresentationInputClient(canvas: canvas, facade: nil)
        XCTAssertTrue(client.interactionContainerView === canvas.selectionChromeContainer,
                     "interactionContainerView must be exactly the ID canvas's own selectionChromeContainer, not a copy")
    }
}
#endif
