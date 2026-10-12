import XCTest
import CoreGraphics
@testable import RichTextEditorCore

/// The reveal arithmetic, with no view in it. Every number here is the article editor's real
/// geometry, read in-process on K3: a 402x810 editor, a 68pt navigation band, and a bottom band of
/// 92 (nothing up), 400 (system keyboard) or 407 (emoji panel).
final class CaretRevealSolverTests: XCTestCase {
    /// A document taller than the viewport, with the caret wherever the case puts it.
    private func input(caretY: CGFloat, offsetY: CGFloat, bottomInset: CGFloat = 400.0,
                       contentHeight: CGFloat = 1391.0) -> RichTextCaretRevealInput {
        RichTextCaretRevealInput(
            caret: CGRect(x: 15.0, y: caretY, width: 2.0, height: 22.0),
            firstLineTop: 12.0,
            lastLineBottom: contentHeight - 12.0,
            contentHeight: contentHeight,
            viewportHeight: 810.0,
            topInset: 68.0,
            bottomInset: bottomInset,
            offsetY: offsetY
        )
    }

    func test_aVisibleCaretInTheMiddleNeedsNothing() {
        XCTAssertNil(RichTextCaretRevealSolver.offsetY(for: input(caretY: 200.0, offsetY: 0.0)))
    }

    func test_aCaretBelowTheViewportScrollsTheMinimum() {
        // Visible band at offset 0 is [68, 410]. A caret at 500..522 needs its BOTTOM on 410.
        let offset = RichTextCaretRevealSolver.offsetY(for: input(caretY: 500.0, offsetY: 0.0))
        XCTAssertEqual(offset ?? .nan, 522.0 - 810.0 + 400.0, accuracy: 0.01)
    }

    func test_aCaretOnTheFirstLineReachesTheDocumentsTop() {
        // Its line is visible at offset -60 (band [8, 350]) but the 12pt margin above it is not.
        let offset = RichTextCaretRevealSolver.offsetY(for: input(caretY: 12.0, offsetY: -60.0))
        XCTAssertEqual(offset ?? .nan, -68.0, accuracy: 0.01, "stopped short of the beginning")
    }

    func test_aCaretOnTheLastLineReachesTheDocumentsEnd() {
        let maximum = 1391.0 - 810.0 + 400.0
        let offset = RichTextCaretRevealSolver.offsetY(for: input(caretY: 1391.0 - 34.0, offsetY: maximum - 8.0))
        XCTAssertEqual(offset ?? .nan, maximum, accuracy: 0.01, "stopped short of the end")
    }

    func test_aDocumentThatFitsCannotBeScrolled() {
        // 810 - 68 - 92 = 650 of viewport, 300 of document: the only legal offset is -68.
        let fits = RichTextCaretRevealInput(
            caret: CGRect(x: 15.0, y: 100.0, width: 2.0, height: 22.0),
            firstLineTop: 12.0, lastLineBottom: 288.0, contentHeight: 300.0,
            viewportHeight: 810.0, topInset: 68.0, bottomInset: 92.0, offsetY: -68.0)
        XCTAssertNil(RichTextCaretRevealSolver.offsetY(for: fits))
    }

    /// The ends are optional because a caller may not be able to answer them; without them the
    /// solver must still do the ordinary thing rather than reaching for an end it cannot see.
    func test_withoutTheEndsItStillScrollsTheMinimum() {
        var withoutEnds = input(caretY: 12.0, offsetY: -60.0)
        withoutEnds.firstLineTop = nil
        withoutEnds.lastLineBottom = nil
        XCTAssertNil(RichTextCaretRevealSolver.offsetY(for: withoutEnds),
                     "the line itself is visible, so without the ends rule there is nothing to do")
    }

    /// A rect TALLER than the visible area — the legacy canvas's caret ±12pt band in a field one or
    /// two lines tall — fails both containment tests in turn: aligning its top pushes its bottom out,
    /// and the next call aligns the bottom, which pushes the top out again. Every reveal flipped the
    /// offset. Once the visible area lies inside such a rect, there is nothing better to do.
    /// (Review of the squash, 2026-10-12.)
    func test_aRectTallerThanTheViewportIsStableOnceItCoversTheViewport() {
        var input = RichTextCaretRevealInput(
            caret: CGRect(x: 15.0, y: 100.0, width: 2.0, height: 47.0),   // a 23pt line ±12
            firstLineTop: nil,
            lastLineBottom: nil,
            contentHeight: 400.0,
            viewportHeight: 30.0,
            topInset: 0.0,
            bottomInset: 0.0,
            offsetY: 200.0
        )
        guard let first = RichTextCaretRevealSolver.offsetY(for: input) else {
            return XCTFail("precondition: the caret is out of view and must be revealed")
        }
        input.offsetY = first
        XCTAssertNil(RichTextCaretRevealSolver.offsetY(for: input),
                     "a second reveal moved the offset again (from \(first)) — it flips on every call")
    }
}
