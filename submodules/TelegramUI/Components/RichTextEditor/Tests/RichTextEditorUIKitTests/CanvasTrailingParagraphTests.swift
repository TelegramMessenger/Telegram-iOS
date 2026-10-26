#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Two paired affordances at the bottom of the document:
///   1. Backspace at the start of a trailing EMPTY body paragraph removes that paragraph, even when the
///      preceding block is a non-text atom (image / table / code block) that can't absorb a text merge —
///      so "deleting the last paragraph" is always possible. A non-empty paragraph is kept (the caret
///      just steps back into the preceding block). EXCEPTION — a preceding TABLE: the first Backspace
///      structurally selects the whole table (a second deletes it), so the caret parks inside the table
///      instead of at its last-cell end. See CanvasTableBackspaceSelectTests.
///   2. Tapping anywhere below the last block starts a new empty body paragraph there — for any trailing
///      block type (image / table / paragraph / quote / code), except an already-empty body paragraph. This
///      affordance is gated on `tapBelowAddsTrailingParagraph` (default `true`, the article editor); the chat
///      composer sets it `false`, so a tap below the content just places the caret instead.
final class CanvasTrailingParagraphTests: XCTestCase {
    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    private func table(_ id: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID(id + "r0"), cells: [cell(id + "a", "Alpha"), cell(id + "b", "Beta")])]))
    }
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.imageProvider = { _ in UIGraphicsImageRenderer(size: CGSize(width: 60, height: 40)).image { c in
            UIColor.systemPink.setFill(); c.fill(CGRect(x: 0, y: 0, width: 60, height: 40)) } }
        v.setBlocks(blocks, width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func caret(_ v: DocumentCanvasView, _ pos: Int) {
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }
    private func tapBelowLast(_ v: DocumentCanvasView) {
        v.performSingleTap(at: CGPoint(x: 20, y: v.boxes.last!.frame.maxY + 40))
    }

    // MARK: 1 — Backspace removes a trailing empty paragraph after a non-text block

    func test_backspaceAtStartOfEmptyParagraphAfterTable_removesParagraph_andSelectsTable() {
        // The empty trailing paragraph is removed AND the whole table is structurally selected (the caret
        // moves in); a SECOND Backspace deletes the table — see CanvasTableBackspaceSelectTests.
        let v = canvas([table("t"), .paragraph(ParagraphBlock(id: BlockID("bot"), runs: []))])
        caret(v, v.boxes[1].textStart)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1, "the empty paragraph is removed; the table is kept")
        XCTAssertTrue(v.boxes[0] is TableBlockBox)
        XCTAssertNotNil(v.tableSelection, "the whole table is structurally selected")
        XCTAssertNotNil(v.activeTable(), "the caret is parked inside the table")
    }

    func test_backspaceAtStartOfNonEmptyParagraphAfterTable_keepsBoth_selectsTable() {
        // A NON-empty paragraph after a table is kept; the first Backspace selects the whole table (the
        // caret moves in), a second deletes it — see CanvasTableBackspaceSelectTests.
        let v = canvas([table("t"), .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")]))])
        caret(v, v.boxes[1].textStart)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 2, "nothing deleted")
        XCTAssertEqual((v.boxes[1] as! BlockBox).currentParagraph().text, "Bot")
        XCTAssertNotNil(v.tableSelection, "the whole table is structurally selected")
        XCTAssertNotNil(v.activeTable(), "the caret is parked inside the table")
    }

    func test_backspaceAtStartOfEmptyParagraphAfterCode_removesParagraph_keepsCode() {
        let code = Block.code(CodeBlock(id: BlockID("c"), language: nil, runs: [TextRun(text: "let x = 1")]))
        let v = canvas([code, .paragraph(ParagraphBlock(id: BlockID("p"), runs: []))])
        caret(v, v.boxes[1].textStart)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1, "the empty paragraph is removed; the code block is kept")
        XCTAssertTrue(v.boxes[0] is CodeBlockBox)
        XCTAssertEqual(v.head, v.boxes[0].textStart + v.boxes[0].textLength, "caret parks at the code block's end")
    }

    func test_backspaceAtStartOfEmptyParagraphAfterTable_isUndoable() {
        let v = canvas([table("t"), .paragraph(ParagraphBlock(id: BlockID("bot"), runs: []))])
        let um = UndoManager(); um.groupsByEvent = false
        v.undoManagerOverride = um
        caret(v, v.boxes[1].textStart)
        um.beginUndoGrouping(); v.deleteBackward(); um.endUndoGrouping()
        XCTAssertEqual(v.boxes.count, 1, "empty paragraph removed")
        um.undo()
        XCTAssertEqual(v.boxes.count, 2, "undo restores the trailing empty paragraph")
        XCTAssertEqual((v.boxes[1] as? BlockBox)?.textLength, 0)
    }

    // MARK: 2 — Tapping below the last block starts a new empty body paragraph

    func test_tapBelowTrailingImage_addsBodyParagraph() {
        let v = canvas([.media(MediaBlock(id: BlockID("img"), mediaID: "k", naturalSize: Size2D(width: 60, height: 40)))])
        tapBelowLast(v)
        XCTAssertEqual(v.boxes.count, 2, "tapping below a trailing image starts a body paragraph after it")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox, "the image is kept")
        XCTAssertEqual((v.boxes[1] as! BlockBox).style, .body)
        XCTAssertEqual((v.boxes[1] as! BlockBox).textLength, 0)
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret moves into the new paragraph")
    }

    func test_tapBelowTrailingTable_addsBodyParagraph() {
        let v = canvas([table("t")])
        tapBelowLast(v)
        XCTAssertEqual(v.boxes.count, 2, "tapping below a trailing table starts a body paragraph after it")
        XCTAssertTrue(v.boxes[0] is TableBlockBox, "the table is kept")
        XCTAssertEqual((v.boxes[1] as! BlockBox).style, .body)
        XCTAssertEqual(v.head, v.boxes[1].textStart, "caret moves into the new paragraph")
    }

    func test_tapBelowTrailingImage_thenBackspace_roundTrips() {
        // The two affordances compose: tap below an image to make a paragraph, backspace to remove it.
        let v = canvas([.media(MediaBlock(id: BlockID("img"), mediaID: "k", naturalSize: Size2D(width: 60, height: 40)))])
        tapBelowLast(v)
        XCTAssertEqual(v.boxes.count, 2)
        v.deleteBackward()
        XCTAssertEqual(v.boxes.count, 1, "backspace removes the just-created trailing paragraph")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox, "the image survives the round-trip")
    }

    // MARK: 3 — `tapBelowAddsTrailingParagraph = false` (the chat-composer configuration)

    func test_tapBelowTrailingImage_withTapBelowDisabled_addsNoParagraph() {
        let v = canvas([.media(MediaBlock(id: BlockID("img"), mediaID: "k", naturalSize: Size2D(width: 60, height: 40)))])
        v.tapBelowAddsTrailingParagraph = false      // the chat composer turns the affordance off
        tapBelowLast(v)
        XCTAssertEqual(v.boxes.count, 1, "with the affordance off, a tap below the content appends no paragraph")
        XCTAssertTrue(v.boxes[0] is MediaBlockBox, "the image is kept, unchanged")
    }

    func test_tapBelowTrailingParagraph_withTapBelowDisabled_placesCaretNotNewParagraph() {
        // With the flag ON, tapping below a NON-empty trailing paragraph appends an empty one (only an
        // already-empty body paragraph is exempt). With it OFF, the tap just places the caret in the existing
        // paragraph — no new block.
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        v.tapBelowAddsTrailingParagraph = false
        tapBelowLast(v)
        XCTAssertEqual(v.boxes.count, 1, "no new paragraph is appended")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Hello", "the trailing paragraph is unchanged")
    }
}
#endif
