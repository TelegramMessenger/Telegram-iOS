#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasTokenizerTests: XCTestCase {
    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    // UITextDirection imports as an NS_TYPED_ENUM struct on this SDK, so the raw storage direction
    // must be wrapped in UITextDirection(rawValue:) rather than passed as a bare Int.
    private let fwdDir = UITextDirection(rawValue: UITextStorageDirection.forward.rawValue)
    private let backDir = UITextDirection(rawValue: UITextStorageDirection.backward.rawValue)
    // Forward word boundary (Option+Right) — UITextStorageDirection.forward.
    private func wordFwd(_ v: DocumentCanvasView, _ pos: Int) -> Int {
        let tok = DocumentTokenizer(canvas: v)
        let r = tok.position(from: DocumentTextPosition(pos), toBoundary: .word,
                             inDirection: fwdDir)
        return (r as? DocumentTextPosition)?.offset ?? -1
    }
    private func wordBack(_ v: DocumentCanvasView, _ pos: Int) -> Int {
        let tok = DocumentTokenizer(canvas: v)
        let r = tok.position(from: DocumentTextPosition(pos), toBoundary: .word,
                             inDirection: backDir)
        return (r as? DocumentTextPosition)?.offset ?? -1
    }

    // Within one paragraph "Hello World": region [1,12] (H=1..o=5, end 6; space 7? NO — single region,
    // chars are contiguous: positions 1..11 are 'H','e','l','l','o',' ','W','o','r','l','d', end slot 12).
    func test_wordForward_withinParagraph_landsOnWordEnds() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hello World")]))])
        let r = v.allLeafRegions().first!  // globalStart = 1
        let gs = r.globalStart
        // from start of "Hello" → end of "Hello"
        XCTAssertEqual(wordFwd(v, gs + 0), gs + 5)
        // from end of "Hello" → end of "World"
        XCTAssertEqual(wordFwd(v, gs + 5), gs + 11)
    }
    func test_wordBackward_withinParagraph_landsOnWordStarts() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hello World")]))])
        let gs = v.allLeafRegions().first!.globalStart
        // from inside "World" (the 'r', gs+8) → start of "World" (gs+6), NEVER the 2nd letter (gs+7)
        XCTAssertEqual(wordBack(v, gs + 8), gs + 6)
        // from start of "World" → start of "Hello"
        XCTAssertEqual(wordBack(v, gs + 6), gs + 0)
    }

    // Two paragraphs must NOT glue into one word: "Hello" [1,6], "World" [8,13].
    func test_wordForward_doesNotSkipAcrossBlocks() {
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hello")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "World")])),
        ])
        let a = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("a")) }!  // [1,6]
        let b = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("b")) }!  // [8,13]
        // from inside "Hello" → end of "Hello" (a.globalStart+5), NOT past into "World"
        XCTAssertEqual(wordFwd(v, a.globalStart + 2), a.globalStart + 5)
        // from end of "Hello" → crosses the block boundary to the END of "World" (macOS: one press
        // reaches the next word's end), never skipping past it.
        let crossed = wordFwd(v, a.globalStart + 5)
        XCTAssertEqual(crossed, b.globalStart + b.length, "crossing a block boundary lands at the next word's end")
        XCTAssertTrue(v.isRenderablePosition(crossed))
    }

    func test_wordBackward_doesNotSkipAcrossBlocks() {
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hello")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "World")])),
        ])
        let a = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("a")) }!  // [1,6]
        let b = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("b")) }!  // [8,13]
        // from inside "World" → start of "World"
        XCTAssertEqual(wordBack(v, b.globalStart + 2), b.globalStart)
        // from start of "World" → crosses back to the START of "Hello" (macOS: one press), never skipping it
        let crossed = wordBack(v, b.globalStart)
        XCTAssertEqual(crossed, a.globalStart, "crossing back lands at the previous word's start")
        XCTAssertTrue(v.isRenderablePosition(crossed))
    }

    // Cross-cell: a word never spans cell→cell.
    func test_wordForward_doesNotGlueTableCells() {
        let v = canvas([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [cell("c", "Ada"), cell("d", "Lovelace")])]))])
        let c = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("cp")) }!  // "Ada"
        // from inside "Ada" → end of "Ada"
        XCTAssertEqual(wordFwd(v, c.globalStart + 1), c.globalStart + 3)
    }

    // Every word boundary result is renderable, for all positions/directions.
    func test_wordBoundary_alwaysRenderable() {
        let v = canvas([
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hello")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("c", "Ada"), cell("d", "Lovelace")])])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "End word here")])),
        ])
        for pos in 0...v.documentSizeValue {
            XCTAssertTrue(v.isRenderablePosition(wordFwd(v, pos)), "fwd from \(pos)")
            XCTAssertTrue(v.isRenderablePosition(wordBack(v, pos)), "back from \(pos)")
        }
    }

    // rangeEnclosingPosition(.word) selects the whole word (double-tap).
    func test_rangeEnclosingWord_isWholeWord() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hello World")]))])
        let gs = v.allLeafRegions().first!.globalStart
        let tok = DocumentTokenizer(canvas: v)
        let range = tok.rangeEnclosingPosition(DocumentTextPosition(gs + 8), with: .word,
                                               inDirection: fwdDir) as? DocumentTextRange
        XCTAssertEqual(range?.from.offset, gs + 6)   // "World" start
        XCTAssertEqual(range?.to.offset, gs + 11)    // "World" end
    }

    // Paragraph granularity == one leaf region (blocks don't glue).
    func test_paragraphBoundary_isRegionEdge() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hello")]))])
        let r = v.allLeafRegions().first!
        let tok = DocumentTokenizer(canvas: v)
        let fwd = tok.position(from: DocumentTextPosition(r.globalStart + 2), toBoundary: .paragraph,
                               inDirection: fwdDir) as? DocumentTextPosition
        XCTAssertEqual(fwd?.offset, r.globalStart + r.length)
    }
}
#endif
