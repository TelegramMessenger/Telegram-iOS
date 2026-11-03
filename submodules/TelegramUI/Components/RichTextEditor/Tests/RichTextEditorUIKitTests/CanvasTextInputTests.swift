#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasTextInputTests: XCTestCase {
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs([
            ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Alpha")]),
            ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "Beta")]),
        ], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200); v.layoutIfNeeded()
        return v
    }

    func test_insertText_editsCaretBlock_andShiftsLaterSpans() {
        let v = canvas()
        let bStartBefore = v.boxes[1].textStart
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart + 5),
                                                DocumentTextPosition(v.boxes[0].textStart + 5)) // end of "Alpha"
        v.insertText("!")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().runs.map(\.text).joined(), "Alpha!")
        XCTAssertEqual(v.boxes[1].textStart, bStartBefore + 1) // later block shifted by +1
    }

    // A custom UITextInput must report a paragraph break as a "\n" between top-level blocks — exactly
    // like UITextView. Without it, the system keyboard's CJK/Hangul IME (which reads document context
    // via `text(in:)` and does NOT use marked text here) sees two stacked paragraphs as ONE continuous
    // line and recomposes Hangul across the invisible line break — the reported bug where a trailing
    // consonant from the lower line migrates onto the line above.
    func test_textInRange_insertsNewlineAtParagraphBoundary() {
        let v = canvas()
        let r = DocumentTextRange(DocumentTextPosition(v.boxes[0].textStart + 4),  // "a" of Alpha
                                  DocumentTextPosition(v.boxes[1].textStart + 1))  // "B" of Beta
        XCTAssertEqual(v.text(in: r), "a\nB")   // was "aB" (glued) — the bug
    }

    func test_textInRange_fullDocument_joinsParagraphsWithNewline() {
        let v = canvas()
        let r = DocumentTextRange(DocumentTextPosition(0), DocumentTextPosition(v.documentSize))
        XCTAssertEqual(v.text(in: r), "Alpha\nBeta")
    }

    // The keyboard reads the position immediately before a lower line's start — which falls in the
    // structural gap between the two paragraphs — to decide whether to recompose. That read MUST yield
    // the line break, or it concludes the previous syllable is adjacent on the same line.
    func test_textInRange_rangeInsideParagraphGap_isNewline() {
        let v = canvas()
        let gapStart = v.boxes[0].textStart + 5         // end of "Alpha" (close-token boundary)
        let secondStart = v.boxes[1].textStart          // start of "Beta"
        XCTAssertGreaterThan(secondStart, gapStart)     // there is a real gap
        let r = DocumentTextRange(DocumentTextPosition(gapStart), DocumentTextPosition(secondStart))
        XCTAssertEqual(v.text(in: r), "\n")
    }

    func test_caretRectInSecondBlock_isBelowFirst() {
        let v = canvas()
        let r0 = v.caretRect(for: DocumentTextPosition(v.boxes[0].textStart))
        let r1 = v.caretRect(for: DocumentTextPosition(v.boxes[1].textStart))
        XCTAssertGreaterThan(r1.minY, r0.minY)
    }
}
#endif
