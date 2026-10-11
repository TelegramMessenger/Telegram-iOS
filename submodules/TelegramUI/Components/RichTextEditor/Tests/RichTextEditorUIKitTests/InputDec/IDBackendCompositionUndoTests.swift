#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task D4f — **committing a composition must register the composition's undo step.**
///
/// This is a DIFFERENT mechanism from the plain-vs-structural axis class the rest of D4f is about,
/// and the residual it explains is what was left of the `ime` corpus family once the axis half was
/// fixed: the four `*-return-commit-then-undo` scenarios, which wrap a composition in a driver-opened
/// undo group and then undo it. Stock UIKit returns to the original text and reports `canRedo == 1`;
/// this backend kept the composed text and reported `canRedo == 0` — the signature of an undo that
/// popped an EMPTY group.
///
/// **The mechanism.** A composition's single undo step is registered by
/// `DocumentCanvasView.commitMarkedText()` (`+MarkedText.swift`), from the whole-document snapshot
/// `legacySetMarkedText` captured at composition start. That body is reachable only through
/// `DocumentCanvasView.legacyApplyMutation`'s `.unmarkText` case — i.e. only through the document
/// client. `IDTextEditorBackend.unmarkText()` never went there: it forwarded to the kernel (whose
/// own `unmarkText` mutates no character and so never reaches the storage façade) and then called
/// `commitMarkedTextStateIfComposing()`, which retires `state.markedRange` and nothing else. So the
/// composition committed, the text stayed, and no undo action was ever registered.
///
/// The second half was equally quiet: `IDTextEditorBackend.compositionSnapshot` was a hardcoded
/// `nil` with a no-op writer — self-consistent, and documented as such, precisely BECAUSE nothing on
/// this backend read it. `commitMarkedText()` is that reader (`if let snap { registerUndo(...) }`),
/// so even a routed `.unmarkText` would have registered nothing without real storage. Both halves
/// had to land together, which is why they are one commit.
@available(iOS 17.0, *)
@MainActor
final class IDBackendCompositionUndoTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    private static let corpusParagraphs = ["Alpha middle omega", "Second block remains unchanged."]

    private func caret(_ canvas: DocumentCanvasView, _ offset: Int) {
        let p = canvas.position(from: canvas.beginningOfDocument, offset: offset)!
        canvas.selectedTextRange = canvas.textRange(from: p, to: p)
    }

    /// The corpus's `*-return-commit-then-undo` scenario, transaction for transaction: an undo group
    /// opened by the driver around the whole composition, then one undo.
    private func composeInsideAnUndoGroup(_ canvas: DocumentCanvasView) {
        canvas.undoManager?.beginUndoGrouping()
        canvas.setMarkedText("k", selectedRange: NSRange(location: 1, length: 0))
        canvas.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        canvas.setMarkedText("かな", selectedRange: NSRange(location: 2, length: 0))
        canvas.unmarkText()
        canvas.undoManager?.endUndoGrouping()
    }

    /// After the boundary — the corpus's `after-boundary-return-commit-then-undo`. Character index 19
    /// is the second paragraph's first character; the harness's `caret(_:_:)` reaches it as structural
    /// offset 20 relative to `beginningOfDocument`.
    func test_undoingACommittedComposition_restoresTheOriginalDocument() {
        let h = makeBackendHarness(backend: .inputDec,
                                   paragraphs: Self.corpusParagraphs, width: 400)
        defer { h.tearDown() }
        let canvas = h.canvas
        let before = canvas.differentialTopLevelBlockTexts()

        caret(canvas, 20)
        composeInsideAnUndoGroup(canvas)

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(),
                       ["Alpha middle omega", "かなSecond block remains unchanged."],
                       "fixture check: the composition committed before the undo")
        XCTAssertTrue(canvas.undoManager?.canUndo ?? false, "there must be something to undo")

        canvas.undoManager?.undo()

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), before,
                       "the undo must revert the whole composed word, as stock UIKit does")
        XCTAssertTrue(canvas.undoManager?.canRedo ?? false,
                      "stock reports canRedo == 1 here; an undo that popped an EMPTY group reports 0, "
                      + "which is exactly what the corpus measured")
    }

    /// Before the boundary — the corpus's `before-boundary-return-commit-then-undo`. Included because
    /// the two failed IDENTICALLY, which is what rules the undo defect independent of the boundary
    /// (the axis half of this task moved only the after-boundary scenarios).
    func test_undoingACompositionAtTheEndOfTheFirstParagraph_restoresTheOriginalDocument() {
        let h = makeBackendHarness(backend: .inputDec,
                                   paragraphs: Self.corpusParagraphs, width: 400)
        defer { h.tearDown() }
        let canvas = h.canvas
        let before = canvas.differentialTopLevelBlockTexts()

        caret(canvas, 18)   // end of "Alpha middle omega"
        composeInsideAnUndoGroup(canvas)

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(),
                       ["Alpha middle omegaかな", "Second block remains unchanged."],
                       "fixture check: the composition committed before the undo")

        canvas.undoManager?.undo()

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), before)
    }

    /// The composition is ONE undo step, not one per `setMarkedText` — the whole reason
    /// `RichTextCompositionSnapshot` is captured at composition START rather than per update.
    func test_aCompositionIsASingleUndoStep() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 5)
        canvas.setMarkedText("k", selectedRange: NSRange(location: 1, length: 0))
        canvas.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        canvas.setMarkedText("かな", selectedRange: NSRange(location: 2, length: 0))
        canvas.unmarkText()

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["Alphaかな"])
        canvas.undoManager?.undo()
        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["Alpha"],
                       "ONE undo must remove the whole composed word, not its last update")
    }

    /// CONTROL. Undo of an ORDINARY insert worked before this task and must keep working — it is
    /// what makes the failures above about the COMPOSITION commit rather than about undo generally.
    func test_undoingAnOrdinaryInsert_isUnaffected() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 5)
        canvas.insertText("x")
        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["Alphax"])

        canvas.undoManager?.undo()
        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["Alpha"])
    }

    /// CONTROL. `unmarkText()` with no composition open must stay silent — it registers nothing and
    /// must not drive a mutation, exactly as before this task.
    func test_unmarkTextWithNoCompositionOpen_registersNothing() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 5)
        canvas.unmarkText()

        XCTAssertFalse(canvas.undoManager?.canUndo ?? true,
                       "a bare unmarkText must not push an undo step")
        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["Alpha"])
    }

    /// The composition snapshot is a whole-document copy; leaving one behind after a commit gives the
    /// NEXT composition a stale undo baseline. Driven through two consecutive compositions: the
    /// second undo must restore the state after the FIRST, not the state before it.
    func test_asecondCompositionUndoesToTheStateLeftByTheFirst() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 5)
        canvas.setMarkedText("か", selectedRange: NSRange(location: 1, length: 0))
        canvas.unmarkText()
        let afterFirst = canvas.differentialTopLevelBlockTexts()
        XCTAssertEqual(afterFirst, ["Alphaか"])

        canvas.setMarkedText("な", selectedRange: NSRange(location: 1, length: 0))
        canvas.unmarkText()
        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["Alphaかな"])

        canvas.undoManager?.undo()
        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), afterFirst,
                       "the second composition's snapshot must be its OWN start, not the first's")
    }
}
#endif
