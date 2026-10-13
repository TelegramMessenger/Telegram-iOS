#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasTableBoundaryTests: XCTestCase {
    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
            .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 500); v.layoutIfNeeded()
        return v
    }
    private func hasTable(_ v: DocumentCanvasView) -> Bool {
        v.currentBlocks().contains { if case .table = $0 { return true } else { return false } }
    }

    // Backspace at the start of the block AFTER a table now structurally selects the whole table
    // (the caret moves in; a SECOND Backspace deletes it — covered in CanvasTableBackspaceSelectTests).
    func test_backspaceAtStartOfBlockAfterTable_selectsWholeTable() {
        let v = canvas()   // [Top, table(Alpha|Beta), Bot]
        let bot = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bot")) }!
        let sizeBefore = v.documentSizeValue
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(bot.globalStart), DocumentTextPosition(bot.globalStart))
        v.deleteBackward()
        XCTAssertEqual(v.documentSizeValue, sizeBefore, "nothing deleted on the first press")
        XCTAssertNotNil(v.tableSelection, "the whole table is structurally selected")
        XCTAssertNotNil(v.activeTable(), "the caret is parked inside the table")
    }

    func test_dragSelectFromParagraphIntoCell_deleteDoesNotDestroyTable() {
        let v = canvas()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.setSelectionForTesting(anchor: 2, head: cellA.globalStart + 2)   // inside "Top" inside cell A
        v.deleteBackward()
        XCTAssertTrue(hasTable(v), "table must survive a straddling selection delete")
        XCTAssertEqual(v.currentBlocks().count, 3)   // Top, table, Bot all intact
    }

    func test_selectAllThenDelete_clearsDocument() {
        let v = canvas()   // [Top, table, Bot]
        v.setSelectionForTesting(anchor: 0, head: v.documentSizeValue)
        v.deleteBackward()
        // 3b: select-all delete clears everything (table gone), leaving an empty paragraph.
        XCTAssertFalse(v.currentBlocks().contains { if case .table = $0 { return true } else { return false } })
        XCTAssertTrue(v.currentBlocks().allSatisfy { if case .paragraph(let p) = $0 { return p.text.isEmpty } else { return false } })
    }

    func test_deleteRangeSpanningTable_topLevelEndpoints_dropsTableAndMerges() {
        let v = canvas()   // [Top, table, Bot]
        let top = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("top")) }!
        let bot = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bot")) }!
        v.setSelectionForTesting(anchor: top.globalStart + 1, head: bot.globalStart + 1)   // inside "Top" (after "T") inside "Bot" (after "B")
        v.deleteBackward()
        XCTAssertFalse(v.currentBlocks().contains { if case .table = $0 { return true } else { return false } })
        // endpoints merged: "T" + "ot" = "Tot"
        guard case .paragraph(let p) = v.currentBlocks().first(where: { if case .paragraph = $0 { return true } else { return false } })!
        else { return XCTFail() }
        XCTAssertEqual(p.text, "Tot")
    }

    func test_typingAtCaretBeforeLeadingTable_landsInFirstCell() {
        // A document that STARTS with a table: the initial caret at 0 resolves to the table box.
        // Typing must not write through the table's degenerate layout (dropping the keystroke) — it
        // snaps into the first cell.
        let v = DocumentCanvasView()
        v.setBlocks([
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
            .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 500); v.layoutIfNeeded()
        let before = v.documentSizeValue
        v.setSelectionForTesting(anchor: 0, head: 0)
        v.insertText("X")
        XCTAssertEqual(v.documentSizeValue, before + 1, "keystroke must not be dropped")
        guard case .table(let model) = (v.boxes.first as! TableBlockBox).currentBlock(),
              case .paragraph(let p) = model.rows[0].cells[0].blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "XAlpha")
    }

    func test_typingAtCaretAfterTrailingTable_landsInLastCell() {
        // A document that ENDS with a table: the caret at documentSize resolves to the table box.
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 500); v.layoutIfNeeded()
        let before = v.documentSizeValue
        v.setSelectionForTesting(anchor: v.documentSizeValue, head: v.documentSizeValue)
        v.insertText("Y")
        XCTAssertEqual(v.documentSizeValue, before + 1, "keystroke must not be dropped")
        let tableBlock = v.currentBlocks().compactMap { b -> TableBlock? in
            if case .table(let t) = b { return t } else { return nil }
        }.first
        guard let model = tableBlock, case .paragraph(let p) = model.rows[0].cells[1].blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "YBeta")
    }

    func test_downFromParagraphAboveTable_landsInRealRegion_notStuck() {
        let v = canvas()
        let top = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("top")) }!
        let down = (v.position(from: DocumentTextPosition(top.globalStart + 1), in: .down, offset: 1) as! DocumentTextPosition).offset
        XCTAssertNotNil(v.leafRegion(containingGlobal: down), "Down must land in a real text region, not a structural gap")
        // A second Down must make progress (not stuck at the same position)
        let down2 = (v.position(from: DocumentTextPosition(down), in: .down, offset: 1) as! DocumentTextPosition).offset
        XCTAssertNotEqual(down2, down, "Down must keep advancing through/past the table")
    }
}
#endif
