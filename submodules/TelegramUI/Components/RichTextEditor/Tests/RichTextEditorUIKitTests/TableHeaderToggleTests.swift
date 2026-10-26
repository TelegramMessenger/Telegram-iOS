#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

@available(iOS 13.0, *)
final class TableHeaderToggleTests: XCTestCase {
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), style: .body, runs: [TextRun(text: text)]))])
    }

    private func makeView() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","A"), cell("b","B")]),
                   Row(id: BlockID("r1"), cells: [cell("c","C"), cell("d","D")])]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 400); v.layoutIfNeeded()
        return v
    }

    func test_toggleHeader_onSelectedColumn_setsThenClearsThoseCells() {
        let v = makeView()
        let t = v.boxes[0] as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        v.selectTableColumn(1)
        // Column 1 is mixed (r0 header, r1 body) → first toggle turns ALL on.
        v.toggleSelectionHeader()
        guard case .table(let on) = v.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertTrue(on.rows[0].cells[1].isHeader)
        XCTAssertTrue(on.rows[1].cells[1].isHeader)
        XCTAssertFalse(on.rows[1].cells[0].isHeader, "column 0 untouched")
        // Now all-on → next toggle turns them all off.
        v.selectTableColumn(1)
        v.toggleSelectionHeader()
        guard case .table(let off) = v.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertFalse(off.rows[0].cells[1].isHeader)
        XCTAssertFalse(off.rows[1].cells[1].isHeader)
    }

    func test_toggleHeader_caretCellOnly_whenNoStructuralSelection() {
        let v = makeView()
        let t = v.boxes[0] as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)   // body cell, no structural selection
        v.toggleSelectionHeader()
        guard case .table(let out) = v.boxes[0].currentBlock() else { return XCTFail() }
        XCTAssertTrue(out.rows[1].cells[0].isHeader)
        XCTAssertFalse(out.rows[1].cells[1].isHeader)
    }
}
#endif
