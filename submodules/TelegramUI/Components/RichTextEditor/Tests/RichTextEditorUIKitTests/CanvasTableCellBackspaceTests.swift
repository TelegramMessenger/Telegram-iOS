#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Backspace of a just-typed character INSIDE a table cell must delete that character — NOT the empty paragraph
/// AFTER the table. iOS delivers the backspace as a 1-char object-replacement RANGE (`[caret-1, caret]`); the
/// in-cell `selTo` mis-resolves (via `resolveBox`, the degenerate-container tech debt) to the FOLLOWING
/// top-level block (the empty paragraph after the table), so the "empty-paragraph-after-atom" handler wrongly
/// removed it (typed char left behind, caret jumped left). The `!isInsideTable(selTo)` guard mirrors the
/// existing `!isInsideBlockQuote(selTo)` one.
final class CanvasTableCellBackspaceTests: XCTestCase {
    private func mk() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 90), ColumnSpec(width: 90)],
                rows: [Row(id: BlockID("r0"), isHeader: false, cells: [
                    Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: []))]),
                    Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: []))]),
                ])])),
            .paragraph(ParagraphBlock(id: BlockID("after"), runs: [])),   // empty paragraph after the table
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func tableBox(_ v: DocumentCanvasView) -> TableBlockBox { v.boxes.first { $0 is TableBlockBox } as! TableBlockBox }
    private func cell00Text(_ v: DocumentCanvasView) -> String {
        for b in v.currentBlocks() {
            if case .table(let tb) = b {
                return tb.rows[0].cells[0].blocks.compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }.joined()
            }
        }
        return "<no table>"
    }

    func test_backspace_afterTypingInCell_deletesChar_notAdjacentEmptyParagraph() {
        let v = mk()
        // Caret in cell(0,0); type "X".
        v.setSelectionForTesting(anchor: tableBox(v).cellTextStart(row: 0, column: 0)!, head: tableBox(v).cellTextStart(row: 0, column: 0)!)
        v.insertText("X")
        XCTAssertEqual(cell00Text(v), "X", "precondition: X typed into the cell")
        // iOS delivers Backspace as a 1-char range [caret-1, caret], both inside the cell.
        let caret = v.head
        v.setSelectionForTesting(anchor: caret - 1, head: caret)
        v.deleteBackward()
        v.layoutIfNeeded()
        XCTAssertEqual(cell00Text(v), "", "the typed character is deleted from the cell")
        XCTAssertNotNil(v.boxes.first { $0 is TableBlockBox }, "the table is kept")
        XCTAssertEqual(v.boxes.count, 2, "the empty paragraph after the table is NOT deleted (table + paragraph)")
    }
}
#endif
