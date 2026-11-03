#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// `insertDocument(_:)` inserts a whole document's blocks at the caret: an EMPTY paragraph (any empty
/// `BlockBox`) at the caret is REPLACED by the inserted blocks; in every other case the blocks are inserted
/// AFTER the caret's top-level block (the current block is never split). One undo step; caret at the end.
final class CanvasInsertDocumentTests: XCTestCase {
    private func makeCanvas(_ paragraphs: [ParagraphBlock]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setParagraphs(paragraphs, width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 400); v.layoutIfNeeded()
        return v
    }
    private func caret(_ v: DocumentCanvasView, _ pos: Int) {
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(pos), DocumentTextPosition(pos))
    }
    /// A document of body paragraphs from (id, text) pairs.
    private func doc(_ paragraphs: [(String, String)]) -> Document {
        Document(blocks: paragraphs.map { .paragraph(ParagraphBlock(id: BlockID($0.0), runs: [TextRun(text: $0.1)])) })
    }
    /// The current paragraph texts, top-level, in order.
    private func texts(_ v: DocumentCanvasView) -> [String] {
        v.currentBlocks().compactMap { if case let .paragraph(p) = $0 { return p.text } else { return nil } }
    }

    // MARK: Empty paragraph at the caret → REPLACED

    func test_insertIntoEmptyBody_replacesIt() {
        let v = makeCanvas([ParagraphBlock(id: BlockID("e"), runs: [])])   // single empty body paragraph
        caret(v, v.boxes[0].textStart)
        v.insertDocument(doc([("a", "Alpha"), ("b", "Beta")]))
        XCTAssertEqual(texts(v), ["Alpha", "Beta"], "the pristine empty body becomes exactly the new document")
    }

    func test_insertIntoEmptyBody_amongSiblings_replacesOnlyThatBlock() {
        let v = makeCanvas([
            ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello")]),
            ParagraphBlock(id: BlockID("e"), runs: []),      // empty body between two blocks
            ParagraphBlock(id: BlockID("w"), runs: [TextRun(text: "World")]),
        ])
        caret(v, v.boxes[1].textStart)
        v.insertDocument(doc([("x", "X")]))
        XCTAssertEqual(texts(v), ["Hello", "X", "World"], "only the caret's empty body is replaced; siblings kept")
    }

    func test_insertIntoEmptyHeading_replacesIt_anyEmptyBlockBox() {
        // Per the design: ANY empty BlockBox at the caret is replaced, not just an empty .body paragraph.
        let v = makeCanvas([ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [])])
        caret(v, v.boxes[0].textStart)
        v.insertDocument(doc([("a", "Alpha")]))
        XCTAssertEqual(texts(v), ["Alpha"], "an empty heading at the caret is replaced too")
    }

    // MARK: Non-empty block at the caret → inserted AFTER it (never split)

    func test_insertAfterNonEmptyBlock_caretAtStart() {
        let v = makeCanvas([
            ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello")]),
            ParagraphBlock(id: BlockID("w"), runs: [TextRun(text: "World")]),
        ])
        caret(v, v.boxes[0].textStart)   // start of "Hello"
        v.insertDocument(doc([("x", "X")]))
        XCTAssertEqual(texts(v), ["Hello", "X", "World"], "inserted after the caret's block")
    }

    func test_insertAfterNonEmptyBlock_caretMid_doesNotSplit() {
        let v = makeCanvas([ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello world")])])
        caret(v, v.boxes[0].textStart + 3)   // middle of the paragraph
        v.insertDocument(doc([("x", "X")]))
        XCTAssertEqual(texts(v), ["Hello world", "X"], "the current block is inserted-after, not split")
    }

    func test_insertMultipleBlocks_preservesOrder() {
        let v = makeCanvas([ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello")])])
        caret(v, v.boxes[0].textStart)
        v.insertDocument(doc([("x", "X"), ("y", "Y"), ("z", "Z")]))
        XCTAssertEqual(texts(v), ["Hello", "X", "Y", "Z"])
    }

    // MARK: Caret inside a nested container (quote) → insert after the top-level block

    func test_insertWithCaretInsideBlockquote_insertsAfterTheQuote() {
        // A caret inside a blockquote: the "current block" is the top-level quote, so the document is inserted
        // AFTER it — never before it and never replacing anything. `resolveBox(at:)` mis-resolves a nested
        // caret to the FOLLOWING top-level block, so this exercises the structural-span top-level lookup.
        let v = DocumentCanvasView(); v.frame = CGRect(x: 0, y: 0, width: 300, height: 400)
        let bq = BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("qp"), runs: [TextRun(text: "Quoted")]))], collapsed: false)
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("lead"), runs: [TextRun(text: "Lead")])),
            .blockQuote(bq),
            .paragraph(ParagraphBlock(id: BlockID("tail"), runs: [TextRun(text: "Tail")])),
        ], width: 300)
        v.simulateParentLayout()
        let quoteBox = v.boxes[1] as! BlockQuoteBox
        caret(v, quoteBox.children.boxes[0].leafRegions().first!.globalStart + 1)   // inside "Quoted"
        v.insertDocument(doc([("x", "X")]))

        let blocks = v.currentBlocks()
        XCTAssertEqual(blocks.count, 4, "one block inserted after the quote; nothing replaced")
        guard case .blockQuote = blocks[1] else { return XCTFail("the quote stays at index 1") }
        guard case let .paragraph(px) = blocks[2], px.text == "X" else {
            return XCTFail("X must be inserted right after the quote, got \(blocks[2])")
        }
        guard case let .paragraph(pt) = blocks[3], pt.text == "Tail" else {
            return XCTFail("Tail must follow the inserted block, got \(blocks[3])")
        }
    }

    // MARK: Edge cases + caret + undo

    func test_insertEmptyDocument_isNoOp() {
        let v = makeCanvas([ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello")])])
        caret(v, v.boxes[0].textStart)
        v.insertDocument(Document(blocks: []))
        XCTAssertEqual(texts(v), ["Hello"], "an empty document changes nothing")
    }

    func test_caretLandsAtEndOfInsertedContent() {
        let v = makeCanvas([ParagraphBlock(id: BlockID("e"), runs: [])])
        caret(v, v.boxes[0].textStart)
        v.insertDocument(doc([("a", "Alpha"), ("b", "Beta")]))
        let last = v.boxes[1]   // "Beta"
        XCTAssertEqual(v.head, last.textStart + 4, "caret lands at the end of the last inserted block")
        XCTAssertEqual(v.anchor, v.head, "collapsed caret")
    }

    func test_insertIsUndoableAsOneStep() {
        let v = makeCanvas([ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello")])])
        caret(v, v.boxes[0].textStart)
        v.insertDocument(doc([("x", "X")]))
        XCTAssertEqual(texts(v), ["Hello", "X"])
        v.effectiveUndoManager?.undo()
        XCTAssertEqual(texts(v), ["Hello"], "one undo restores the pre-insert document")
    }
}
#endif
