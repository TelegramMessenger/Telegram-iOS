#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Regression: a paragraph that becomes empty through an EDIT (pressing Enter for a new line, or deleting a
/// line's last character) must adopt the current typing direction so its caret opens on the correct side.
/// `refreshEmptyBoxWritingDirections()` previously ran only on reload / focus / keyboard-change, never after
/// an in-place edit — so a newly-created empty RTL line kept its caret on the LEFT.
final class RTLEmptyLineCaretTests: XCTestCase {
    private func canvas(_ paragraphs: [ParagraphBlock], keyboard: String) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.keyboardLanguageProviderForTesting = { keyboard }
        v.setParagraphs(paragraphs, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 200); v.layoutIfNeeded()
        v.refreshEmptyBoxWritingDirections()   // models the initial focus pass
        return v
    }
    private func caret(_ v: DocumentCanvasView, _ pos: Int) {
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }
    private func end(_ box: CanvasBlock) -> Int { box.textStart + box.textLength }

    func test_pressingEnter_inRTL_newEmptyLine_caretOnRight() {
        let v = canvas([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "سلام")])], keyboard: "ar")
        caret(v, end(v.boxes[0]))
        v.insertText("\n")                       // Enter → new empty paragraph below
        XCTAssertEqual(v.boxes.count, 2)
        XCTAssertEqual(v.boxes[1].textLength, 0, "the new paragraph is empty")
        let x = v.boxes[1].textLayout.caretRect(atOffset: 0).minX
        XCTAssertGreaterThan(x, 150, "new empty RTL line caret should sit in the right half (was on the left)")
    }

    func test_deletingLastChar_inRTL_caretReturnsToRight() {
        // One paragraph holding a single Arabic char; delete it → empty paragraph, caret should flip right.
        let v = canvas([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "س")])], keyboard: "ar")
        caret(v, end(v.boxes[0]))
        v.deleteBackward()                       // now empty
        XCTAssertEqual(v.boxes[0].textLength, 0)
        let x = v.boxes[0].textLayout.caretRect(atOffset: 0).minX
        XCTAssertGreaterThan(x, 150, "emptied RTL line caret should return to the right half")
    }

    func test_pressingEnter_inLTR_newEmptyLine_caretOnLeft() {
        // Guard: the same path keeps the LTR caret on the left.
        let v = canvas([ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "hello")])], keyboard: "en")
        caret(v, end(v.boxes[0]))
        v.insertText("\n")
        XCTAssertEqual(v.boxes.count, 2)
        let x = v.boxes[1].textLayout.caretRect(atOffset: 0).minX
        XCTAssertLessThan(x, 150, "new empty LTR line caret should stay on the left")
    }
}
#endif
