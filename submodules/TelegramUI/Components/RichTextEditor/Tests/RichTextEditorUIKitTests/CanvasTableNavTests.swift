#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasTableNavTests: XCTestCase {
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 300); v.layoutIfNeeded()
        return v
    }

    func test_rightAtEndOfCellA_entersCellB() {
        let v = canvas()
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let rB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let endOfA = rA.globalStart + rA.length
        let next = (v.position(from: DocumentTextPosition(endOfA), in: .right, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(next, rB.globalStart)
    }

    func test_leftAtStartOfCellB_returnsToCellAEnd() {
        let v = canvas()
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let rB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let prev = (v.position(from: DocumentTextPosition(rB.globalStart), in: .left, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(prev, rA.globalStart + rA.length)
    }

    // A 2-row 2-column table with a paragraph above ("Top") and below ("Bot").
    // (0,0)"Alpha"(ap) (0,1)"Beta"(bp) / (1,0)"Gamma"(cp) (1,1)"Delta"(dp).
    private func canvas2x2() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [
                    Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")]),
                    Row(id: BlockID("r1"), cells: [cell("c", "Gamma"), cell("d", "Delta")]),
                ])),
            .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 700); v.layoutIfNeeded()
        return v
    }
    private func ref(_ v: DocumentCanvasView, at pos: Int) -> TextNodeRef? {
        v.leafRegion(containingGlobal: pos)?.region.ref
    }

    // Correction 1: Backspace at a cell's first-paragraph start moves to the previous cell (no delete).
    func test_backspaceAtCellBStart_movesToPrevCell_noDelete() {
        let v = canvas()   // 1-row 2-col table (Alpha|Beta)
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let rB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let sizeBefore = v.documentSizeValue
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(rB.globalStart), DocumentTextPosition(rB.globalStart))
        v.deleteBackward()
        XCTAssertEqual(v.documentSizeValue, sizeBefore, "nothing deleted")
        XCTAssertEqual(v.head, rA.globalStart + rA.length, "caret moved to end of the previous cell")
        XCTAssertEqual(v.anchor, v.head)
    }

    // Correction 1 edge: Backspace at the table's FIRST cell start is a no-op (no previous cell).
    func test_backspaceAtFirstCellStart_isNoOp() {
        let v = canvas()
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(rA.globalStart), DocumentTextPosition(rA.globalStart))
        v.deleteBackward()
        XCTAssertEqual(v.head, rA.globalStart, "caret stays — no previous cell to move to")
    }

    // Correction 2: Up in a 2nd-row cell moves to the cell above (same column), not above the table.
    func test_upInSecondRowCell_movesToCellAbove() {
        let v = canvas2x2()
        let rC = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("cp")) }!   // (1,0) "Gamma"
        let up = (v.position(from: DocumentTextPosition(rC.globalStart + 2), in: .up, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(ref(v, at: up), .paragraph(BlockID("ap")), "Up lands in the cell above (0,0), not above the table")
    }

    // Correction 2 edge: Up in a top-row cell (no cell above) escapes to the text above the table.
    func test_upInFirstRowCell_escapesAboveTable() {
        let v = canvas2x2()
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!   // (0,0) "Alpha"
        let up = (v.position(from: DocumentTextPosition(rA.globalStart + 2), in: .up, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(ref(v, at: up), .paragraph(BlockID("top")), "Up from the top row escapes above the table")
    }

    // Correction 2 (symmetric): Down in a 1st-row cell moves to the cell below.
    func test_downInFirstRowCell_movesToCellBelow() {
        let v = canvas2x2()
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!   // (0,0) "Alpha"
        let down = (v.position(from: DocumentTextPosition(rA.globalStart + 2), in: .down, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(ref(v, at: down), .paragraph(BlockID("cp")), "Down lands in the cell below (1,0)")
    }

    // Correction 2 edge: Down in a bottom-row cell (no cell below) escapes to the text below the table.
    func test_downInLastRowCell_escapesBelowTable() {
        let v = canvas2x2()
        let rC = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("cp")) }!   // (1,0) "Gamma"
        let down = (v.position(from: DocumentTextPosition(rC.globalStart + 2), in: .down, offset: 1) as! DocumentTextPosition).offset
        XCTAssertEqual(ref(v, at: down), .paragraph(BlockID("bot")), "Down from the bottom row escapes below the table")
    }

    // Correction 1: Backspace at (1,0) start moves to the previous row's LAST cell (row-major chain).
    func test_backspaceAtRowStartCell_movesToPreviousRowLastCell() {
        let v = canvas2x2()
        let bp = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!   // (0,1) "Beta"
        let cp = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("cp")) }!   // (1,0) "Gamma"
        let sizeBefore = v.documentSizeValue
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(cp.globalStart), DocumentTextPosition(cp.globalStart))
        v.deleteBackward()
        XCTAssertEqual(v.documentSizeValue, sizeBefore, "nothing deleted")
        XCTAssertEqual(v.head, bp.globalStart + bp.length, "moved to (0,1) end — previous cell row-major")
    }

    // Backspace at the FIRST cell with a block above moves to the END of that block (exits the table
    // upward), without deleting.
    func test_backspaceAtFirstCellStart_withBlockAbove_movesToBlockBeforeEnd() {
        let v = canvas2x2()   // "Top" sits above the table
        let top = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("top")) }!
        let ap = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!   // (0,0)
        let sizeBefore = v.documentSizeValue
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(ap.globalStart), DocumentTextPosition(ap.globalStart))
        v.deleteBackward()
        XCTAssertEqual(v.documentSizeValue, sizeBefore, "nothing deleted")
        XCTAssertEqual(v.head, top.globalStart + top.length, "moved to the end of the block before the table")
    }

    // Backspace at the first cell when the block before the table is an IMAGE → its caption end.
    func test_backspaceAtFirstCellStart_withImageBefore_movesToCaptionEnd() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 80, height: 50),
                              caption: [TextRun(text: "Cap")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
        ], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 500); v.layoutIfNeeded()
        let imageBox = v.boxes.first { $0 is MediaBlockBox }!
        let ap = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let sizeBefore = v.documentSizeValue
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(ap.globalStart), DocumentTextPosition(ap.globalStart))
        v.deleteBackward()
        XCTAssertEqual(v.documentSizeValue, sizeBefore, "nothing deleted")
        XCTAssertEqual(v.head, imageBox.textStart + imageBox.textLength, "moved to the image's caption end")
    }

    // Correction 2 edge: Up from the only row when the table is the FIRST block lands in a real region.
    func test_upInOnlyRowCell_tableIsFirstBlock_landsInRealRegion() {
        let v = canvas()   // table-only, single row
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let up = (v.position(from: DocumentTextPosition(rA.globalStart + 2), in: .up, offset: 1) as! DocumentTextPosition).offset
        XCTAssertNotNil(v.leafRegion(containingGlobal: up), "Up with nothing above lands in a real region (no gap/crash)")
    }
}
#endif
