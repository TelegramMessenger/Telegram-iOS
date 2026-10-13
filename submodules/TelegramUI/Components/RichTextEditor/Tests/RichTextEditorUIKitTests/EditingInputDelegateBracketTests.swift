#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// A programmatic edit moves the caret, so it MUST bracket the change with the input system's
/// `selectionWillChange`/`selectionDidChange` (alongside `textWillChange`/`textDidChange`). Otherwise the
/// OS keeps a STALE `selectedTextRange` — the visible cause of the custom-emoji-keyboard bugs: the caret
/// appears not to advance after a programmatic insert, and the next insert lands at the wrong place
/// (leaving a stray `U+FFFC` "service character"). The `reload` path already does this; `editing { }`
/// (behind insertText / insertEmoji / deleteBackward / structural edits) must too.
final class EditingInputDelegateBracketTests: XCTestCase {
    // Reuses the shared `InputDelegateSpy` (MarkedTextTests.swift), which records the four bracket calls.

    private func makeCanvas(text: String = "ab") -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: text)]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        c.layoutIfNeeded()
        return c
    }

    func test_insertEmoji_bracketsSelectionChange() {
        let c = makeCanvas()
        let d = InputDelegateSpy(); c.inputDelegate = d
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertEmoji(id: "star", altText: nil)
        XCTAssertGreaterThan(d.selectionDidChangeCount, 0, "a programmatic emoji insert must notify the input system the caret moved")
        XCTAssertGreaterThan(d.selectionWillChangeCount, 0)
    }

    func test_insertText_bracketsSelectionChange() {
        let c = makeCanvas()
        let d = InputDelegateSpy(); c.inputDelegate = d
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertText("x")
        XCTAssertGreaterThan(d.selectionDidChangeCount, 0)
        XCTAssertGreaterThan(d.selectionWillChangeCount, 0)
    }

    func test_deleteBackward_bracketsSelectionChange() {
        let c = makeCanvas()
        let d = InputDelegateSpy(); c.inputDelegate = d
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 2, head: c.boxes[0].textStart + 2)
        c.deleteBackward()
        XCTAssertGreaterThan(d.selectionDidChangeCount, 0)
        XCTAssertGreaterThan(d.selectionWillChangeCount, 0)
    }

    /// Regression for the reported "service character" symptom at the MODEL level: an insert → backspace →
    /// re-insert cycle must leave exactly one emoji (one `U+FFFC`), with the caret after it — never a
    /// leftover bare `U+FFFC`.
    func test_insertDeleteReinsert_leavesExactlyOneEmoji() {
        let c = makeCanvas(text: "")
        c.setSelectionForTesting(anchor: c.boxes[0].textStart, head: c.boxes[0].textStart)
        c.insertEmoji(id: "star", altText: nil)
        XCTAssertEqual(c.head, c.boxes[0].textStart + 1, "caret advances past the first emoji")
        c.deleteBackward()
        c.insertEmoji(id: "star", altText: nil)
        let para = c.currentBlocks().compactMap { b -> ParagraphBlock? in
            if case let .paragraph(p) = b { return p }; return nil
        }.first
        XCTAssertEqual(para?.text, "\u{FFFC}", "exactly one U+FFFC remains — no stray service character")
        XCTAssertEqual(para?.runs.filter { $0.attributes.emoji != nil }.count, 1, "exactly one emoji run")
        XCTAssertEqual(c.head, c.boxes[0].textStart + 1, "caret advances past the re-inserted emoji")
    }
}
#endif
