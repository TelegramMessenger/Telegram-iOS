#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task D4d — **a backward delete must remove the same character from the façade's mirror that the
/// document removed.**
///
/// The mirror (`TGRichTextInputDecTextStorageFacade.mirror`) is the `NSTextStorage` surface UIKit's
/// private controller reads for everything: `-string`, `attributesAtIndex:effectiveRange:`, layout,
/// selection, and — through `text(in:)` — the `canonical` field the differential corpus compares.
/// Telegram's document is the write authority; the mirror is supposed to be its faithful plain-text
/// projection. When they disagree, `blocks` (read from the real document) stays right while
/// `canonical` goes wrong, which is exactly the shape D4b's corpus reported for
/// `before-boundary-accept-then-delete`/`after-boundary-accept-then-delete`: a paragraph "\n" that
/// vanished from `canonical` while `blocks` still showed two paragraphs — a MERGE that never
/// happened.
///
/// **The mechanism (see `id_rangeOfCharacterClusterAtIndex:type:`'s own comment for the full
/// account):** Task D3c made that helper return a STRUCTURAL range while, in the same commit, it
/// made `replaceCharactersInRange:withString:` treat an incoming `.deleteBackward` range as already
/// PLAIN. The kernel is a pass-through between the two — it asks for the cluster before the caret
/// and hands the answer straight back as the replace range — so the mirror's delete landed
/// `structural - plain` units late on EVERY backward delete, which is at least one, always.
///
/// It hid well: only `canonical`/`inlineRuns` read the mirror, and in the corpus's
/// `interior-accept-then-delete` the characters on either side of the caret are both spaces, so the
/// wrong delete produced an identical string.
///
/// Every test below asserts the INVARIANT (`mirror == document`), never a hand-written expected
/// string alone, so it keeps its meaning if the fixtures change.
@available(iOS 17.0, *)
@MainActor
final class IDBackendBackwardDeleteMirrorTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipUnless(IDTextEditorBackend.isSupported())
    }

    /// The REAL `position(from:offset:)` + `selectedTextRange` pair, not `setSelectionForTesting` —
    /// same deviation, same reason, as `IDBackendFormattingThenDeleteTests`: the raw test seam never
    /// touches `state.documentRevision`, which silently rejects every subsequent `.inputDec`
    /// mutation and would make this suite pass by no-oping.
    private func caret(_ canvas: DocumentCanvasView, _ offset: Int) {
        let p = canvas.position(from: canvas.beginningOfDocument, offset: offset)!
        canvas.selectedTextRange = canvas.textRange(from: p, to: p)
    }

    /// What UIKit sees: `text(in:)` over the whole document -> the kernel ->
    /// `-[TGRichTextInputDecTextStorageFacade string]` -> the mirror. The corpus's `canonical` field
    /// is this exact read.
    private func canonical(_ canvas: DocumentCanvasView) -> String {
        guard let r = canvas.textRange(from: canvas.beginningOfDocument, to: canvas.endOfDocument)
        else { return "<no range>" }
        return canvas.text(in: r) ?? "<nil>"
    }

    /// What the document actually holds, joined the way the plain-text projection joins it — one
    /// "\n" per top-level boundary. The corpus's `blocks` field is the un-joined form of this.
    private func documentProjection(_ canvas: DocumentCanvasView) -> String {
        (canvas.differentialTopLevelBlockTexts() ?? []).joined(separator: "\n")
    }

    private func assertMirrorMatchesDocument(_ canvas: DocumentCanvasView,
                                             _ message: String,
                                             file: StaticString = #filePath,
                                             line: UInt = #line) {
        XCTAssertEqual(canonical(canvas), documentProjection(canvas),
                       "the façade mirror must project the document exactly — \(message)",
                       file: file, line: line)
    }

    /// Caret at the end of the FIRST paragraph's text: the character before it is an ordinary one,
    /// and the character one slot later is the paragraph boundary. Pre-fix the mirror deleted the
    /// boundary and read "AlphaBeta" while the document correctly read "Alph" / "Beta".
    func test_deleteBackwardInsideAParagraph_leavesTheMirrorMatchingTheDocument() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha", "Beta"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 5)   // end of "Alpha"
        canvas.deleteBackward()

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["Alph", "Beta"],
                       "the document itself was never the problem — it must still be right")
        assertMirrorMatchesDocument(canvas, "a delete inside the first paragraph")
    }

    /// The paragraph MERGE: caret at the start of "Beta" (offset 7 — the boundary takes two
    /// structural slots, the arithmetic `IDBackendDifferentialTraceTests`' own
    /// `backspace-merges-paragraphs` documents). This is the case Task D3c's comment cited as its
    /// reason for converting the cluster range to the structural axis, so it is the one that most
    /// needs to keep working after that conversion was removed.
    func test_backspaceAtAParagraphBoundary_leavesTheMirrorMatchingTheMergedDocument() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha", "Beta"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 7)   // start of "Beta"
        canvas.deleteBackward()

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["AlphaBeta"],
                       "the boundary itself must be what was deleted")
        assertMirrorMatchesDocument(canvas, "a backspace that merges two paragraphs")
    }

    /// Inside the SECOND paragraph, where structural and plain-text offsets are furthest apart —
    /// the drift was `structural - plain`, so it grows with every boundary crossed. Pre-fix the
    /// mirror read "Alpha\nBet" (a delete two slots late) against a document holding
    /// "Alpha" / "Bta".
    func test_deleteBackwardAfterAParagraphBoundary_leavesTheMirrorMatchingTheDocument() {
        let h = makeBackendHarness(backend: .inputDec, paragraphs: ["Alpha", "Beta"], width: 300)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 9)   // "Be|ta"
        canvas.deleteBackward()

        XCTAssertEqual(canvas.differentialTopLevelBlockTexts(), ["Alpha", "Bta"])
        assertMirrorMatchesDocument(canvas, "a delete two structural slots past a boundary")
    }

    /// The corpus scenario itself, transaction for transaction:
    /// `before-boundary-accept-then-delete`. The caret ends up at the end of the first paragraph,
    /// immediately before the boundary, and the delete must take the space — not the "\n".
    func test_theCorpusAcceptThenDeleteScenario_doesNotMergeTheParagraphsInTheMirror() {
        let h = makeBackendHarness(backend: .inputDec,
                                   paragraphs: ["Earlier sentence. I look forward ",
                                                "Later block stays."],
                                   width: 400)
        defer { h.tearDown() }
        let canvas = h.canvas

        caret(canvas, 33)                                                    // `set-selection`
        canvas.setMarkedText("to", selectedRange: NSRange(location: 0, length: 0))  // `set-marked-text`
        let a = canvas.position(from: canvas.beginningOfDocument, offset: 33)!
        let b = canvas.position(from: canvas.beginningOfDocument, offset: 35)!
        canvas.replace(canvas.textRange(from: a, to: b)!, withText: "to ")    // `replace-range`
        canvas.unmarkText()                                                  // `unmark-text`
        canvas.deleteBackward()                                              // `delete-backward`

        XCTAssertEqual(canonical(canvas),
                       "Earlier sentence. I look forward to\nLater block stays.",
                       "stock UIKit's own terminal text for this scenario — the trailing space goes, "
                       + "the paragraph boundary stays")
        assertMirrorMatchesDocument(canvas, "the corpus's before-boundary-accept-then-delete")
    }
}
#endif
