#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 28 — Family 5 (backward deletion), the single witness `deleteBackward()`: at 404 lines
/// (`DocumentCanvasView+UITextInput.swift`) the largest in the package, and the one with the most
/// branches (**24** `editing { … }` call sites — 18 bare plus 6 `editing(coalescing: .deleting)`).
///
/// `deleteBackward()` is a PLAIN `legacyCanvas` forward, per the user's D35 ruling and exactly the
/// shape Task 27b gave `insertText(_:)`. The `prepareAndRun` transaction that used to be
/// `LegacyRichTextInputBackend.deleteBackward()`'s body now lives on the test-only
/// `ReferenceMutationBackend`, which the mutation contract suites run against.
///
/// **Two tests the task brief named are deliberately ABSENT, and their absence is the point.**
/// `…runsPrepareNotifyCommitPublishInOrder` and `…ProducesExactlyOneDocumentCommit` describe the
/// REJECTED shape: under a plain forward the backend member never calls `prepareAndRun`, so it never
/// reaches `prepareMutation`/`commitPreparedMutation` and both counts would be trivially zero — an
/// unfalsifiable pair. They are re-based here on what a plain forward CAN observe (the document
/// changed, the revision moved exactly once, the trace is the hook's own), the way
/// `InsertionRouterTests` did for `replace`/`insertText`. The prepare/notify/commit ordering is still
/// pinned where it belongs — on `ReferenceMutationBackend`, by `BackendMutationContractTests`.
///
/// The brief's third named test, `test_deleteTableStructuralSelectionRunsAsACommandNotATextMutation`,
/// is re-based for the same reason and is
/// `test_deleteBackward_withATableStructuralSelection_takesTheStructuralBranchFirst` below: under a
/// plain forward NEITHER branch consults a client — no `commandClient`, no `documentClient` — so
/// "routes as a command, not a text mutation" has nothing to observe. What genuinely survives routing
/// is the BRANCH ORDER inside the moved body, and that is what the test pins.
///
/// **Which backend each test runs against, decided before any of them were written** (the handoff's
/// rule 3 — deciding this mid-task is how it gets discovered as a red):
///
///   * **Spy** for the one routing-shape test. The spy performs no work, so `XCTAssertRoutesOnly`'s
///     "and the canvas did nothing of its own" half is exactly right — and it is genuinely non-inert:
///     under the real backend this same call moves `revision`, `layoutGeneration`, `head`,
///     `undoRegistrationCount` and `dismissEditMenuCountForTesting`, five of the seven fields
///     `RouterStateSnapshot` watches. A router that kept a copy of the old body beside the forward
///     fails there.
///   * **Real legacy backend** for the three behavioural tests. A correctly-routed delete legitimately
///     moves those same fields, so `XCTAssertRouterDidNoWork` would fail FOR CORRECT CODE; they assert
///     the expected DELTA instead, which is the stronger assertion anyway since it pins the body the
///     routing moved rather than its absence.
///
/// The detached-drop characterization lives in `BackendAttachmentTests`, not here: rule R14 forbids
/// this directory from naming the canvas's backend property, and detaching requires exactly it — the
/// same reason `hasText`'s and `insertText`'s detached fallbacks live there.
///
/// Every test reads through a real `DocumentCanvasView` member, never the canvas's backend property —
/// the vacuity trap R14 mechanically forbids in this directory.
@MainActor
@available(iOS 16.0, *)
final class DeletionRouterTests: XCTestCase {

    // MARK: - Section 1: the spy backend — "one call, exact arguments, nothing else"

    private func spyCanvas() -> (DocumentCanvasView, SpyRichTextInputBackend) {
        let spy = SpyRichTextInputBackend()
        let v = DocumentCanvasView(inputBackend: spy)
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Alpha Beta")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        v.setCaret(global: v.boxes[0].textStart + 3)   // interior caret: the pre-seam body WOULD delete here
        spy.reset()
        return (v, spy)
    }

    /// The caret is deliberately placed mid-word by `spyCanvas()`, so the pre-seam, non-routing answer
    /// is a real edit — the spy performing no work is signal, not a coincidence of an inert caret.
    ///
    /// RED IF: the witness kept its own body (the canvas would delete a character, moving five of the
    /// seven watched fields, and the one recorded spy call would be
    /// `notifyingContentAndSelectionChange` rather than `deleteBackward()`).
    func test_deleteBackward_callsTheBackendExactlyOnce() {
        let (v, spy) = spyCanvas()
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha Beta",
                       "precondition: there is text before the caret for a non-routing body to delete")
        XCTAssertRoutesOnly(v, spy, member: "deleteBackward()", arguments: []) {
            v.deleteBackward()
        }
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alpha Beta",
                       "the spy performs no edit — the document is untouched")
    }

    // MARK: - Section 2: the real legacy backend — the canvas body the routing moved

    private func realCanvas(_ text: String = "Alpha") -> (DocumentCanvasView, RichTextInputEventRecorder) {
        let v = DocumentCanvasView()
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: text)])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        let recorder = RichTextInputEventRecorder(); recorder.attach(canvas: v); recorder.reset()
        return (v, recorder)
    }

    /// The whole moved body, end to end, through the real backend: the grapheme before the caret goes,
    /// the caret steps back, and the revision moves EXACTLY once.
    ///
    /// The revision assertion is the re-based form of the brief's
    /// `…ProducesExactlyOneDocumentCommit`. It is the observation that survives Option A: a plain
    /// forward never reaches `commitPreparedMutation`, but a witness that dispatched back into itself
    /// (the hazard Step 4's repoint exists for) would move the revision more than once. `documentCommit`
    /// could not see that anyway — Task 27a measured that `prepareAndRun`'s idle guard rejects the
    /// re-entrant call, leaving the commit count at 1.
    ///
    /// RED IF: the backend dropped the `legacyDeleteBackward` forward (nothing changes), or the
    /// dispatcher repoint went to the wrong body.
    func test_deleteBackward_runsTheWholeCanvasBodyThroughTheBackend() {
        let (v, _) = realCanvas()
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 3)
        let before = v.documentRevision

        v.deleteBackward()

        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Alha")
        XCTAssertEqual(v.head, s + 2, "the caret steps back over the deleted character")
        XCTAssertEqual(v.documentRevision, before + 1, "exactly one revision for one delete")
    }

    /// **The load-bearing test of this task.** `legacyDeleteBackward` brackets itself — per branch,
    /// across 24 `editing { … }` call sites — so the routed member must add NO bracket of its own. One
    /// ordinary Backspace is exactly the six events below.
    ///
    /// **Measured, and the measurement is narrower than the brief's Step 5 — say which half was run.**
    /// The red-check applied the **bracket ALONE** (`notifyingContentAndSelectionChange { … }` around
    /// the forward), not the bracket plus the trailing `publishState` that Step 5 also asks for: six
    /// events became **ten**, and the observed trace still carried exactly ONE
    /// `canvasContentSizeChanged`/`canvasSelectionChanged` pair, which is how you can tell `publishState`
    /// was not part of the mutation. Step 5's full shape would add a SECOND such pair on top of
    /// `editing`'s own tail — predicted, not measured here, and the bracket alone is already fatal.
    ///
    /// `EditingInputDelegateBracketTests.test_deleteBackward_bracketsSelectionChange` pins the same
    /// bracket from the canvas side; the golden traces in `DelegateTraceCharacterizationTests` pin
    /// `editing { }`'s own shape, which is what this forward must not add to.
    ///
    /// RED IF: the backend member gained a bracket. Verified red against exactly that (see the task
    /// report's red-check section).
    func test_deleteBackward_emitsExactlyTheWitnessesOwnBracket_theBackendAddsNoneOfItsOwn() {
        let (v, recorder) = realCanvas()
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 3)
        recorder.reset()

        v.deleteBackward()

        XCTAssertEqual(recorder.kinds, [.textWillChange, .selectionWillChange, .selectionDidChange,
                                        .textDidChange, .canvasContentSizeChanged, .canvasSelectionChanged])
    }

    /// The family-specific divergence axis, pinned rather than merely disclosed. The table
    /// structural-selection delete is hooked NEAR THE TOP of `legacyDeleteBackward` and must keep
    /// firing before the in-cell text branch: with a whole-table row selection live the caret is parked
    /// INSIDE a cell, so a body that reached the generic branch would delete one character of "Alpha"
    /// and leave the table standing.
    ///
    /// Re-based from the brief's `…RunsAsACommandNotATextMutation`: under a plain forward neither branch
    /// consults a client, so there is no `commandClient`-vs-`documentClient` split left to observe —
    /// the BRANCH ORDER is what survives routing, and it is what this asserts.
    ///
    /// **NOT the only guard on that property, and it never was.**
    /// `CanvasTableBackspaceSelectTests.test_secondBackspace_deletesSelectedTable_toEmptyParagraphInPlace`
    /// already pins the same select-then-delete behaviour from the canvas side, and it is in Task 28's
    /// own Step-6 regression gate. This test's distinct job is to pin it **through the routed witness**,
    /// in the file a future editor of the router reads — so it is deliberate reinforcement of a covered
    /// property, not new coverage.
    ///
    /// RED IF: the structural branch stopped running first (the table survives and the cell loses a
    /// character), or the forward reached a body that no longer contains it.
    func test_deleteBackward_withATableStructuralSelection_takesTheStructuralBranchFirst() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [
                    Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"),
                                                                             runs: [TextRun(text: "Alpha")]))]),
                    Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"),
                                                                             runs: [TextRun(text: "Beta")]))]),
                ])])),
            .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 500); v.layoutIfNeeded()
        let botStart = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bot")) }!.globalStart
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(botStart), DocumentTextPosition(botStart))

        v.deleteBackward()   // first Backspace: parks the caret in the table and selects every row

        XCTAssertNotNil(v.tableSelection, "precondition: a structural selection is live")
        XCTAssertNotNil(v.activeTable(), "precondition: the caret is parked INSIDE a cell, so a body " +
                                         "that reached the generic branch would delete a cell character")

        v.deleteBackward()   // second Backspace: the structural branch, not the in-cell text branch
        v.layoutIfNeeded()

        XCTAssertFalse(v.currentBlocks().contains { if case .table = $0 { return true } else { return false } },
                       "the structural branch ran: the table is gone")
        XCTAssertNil(v.tableSelection, "…and the structural selection was cleared")
        XCTAssertEqual(v.currentBlocks().compactMap {
            if case .paragraph(let p) = $0 { return p.text } else { return nil }
        }, ["Top", "", "Bot"], "the table became an empty paragraph in place; no cell text was deleted")
    }
}
#endif
