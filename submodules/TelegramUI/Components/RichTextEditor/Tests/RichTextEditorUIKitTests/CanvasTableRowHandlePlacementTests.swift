#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The table row grip is always drawn to the LEFT of the table (never inside its first column), anchored to the
/// table's left edge — so it stays in the left gutter for the full-page editor (16pt page margin) AND draws into
/// the field's left padding for the composer (zero page margin). Regression: it used a fixed x:1, which landed
/// inside the table when there was no page-margin gutter.
final class CanvasTableRowHandlePlacementTests: XCTestCase {
    private func canvas(pageMargin: CGFloat) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.pageMargin = pageMargin
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 90), ColumnSpec(width: 90)],
            rows: [Row(id: BlockID("r0"), isHeader: false, cells: [
                Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: [TextRun(text: "A")]))]),
                Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "B")]))]),
            ])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let t = v.boxes.first { $0 is TableBlockBox } as! TableBlockBox
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)   // activeTable() → this cell
        return v
    }
    private func rowGrip(_ v: DocumentCanvasView) -> CGRect? {
        v.tableHandles().first { if case .rows = $0.kind { return true } else { return false } }?.rect
    }
    private func tableBox(_ v: DocumentCanvasView) -> TableBlockBox { v.boxes.first { $0 is TableBlockBox } as! TableBlockBox }

    func test_rowGrip_isLeftOfTable_withZeroPageMargin() {
        let v = canvas(pageMargin: 0)
        let grip = rowGrip(v)
        XCTAssertNotNil(grip)
        // Grip center is left of the table's left edge — outside the first column, in the (field-padding) gutter.
        XCTAssertLessThan(grip!.midX, tableBox(v).frame.minX, "row grip is drawn to the LEFT of the table")
    }

    func test_rowGrip_unchanged_withFullPageMargin() {
        let v = canvas(pageMargin: 16)
        let grip = rowGrip(v)
        XCTAssertNotNil(grip)
        // Full-page editor: preserved at the historical x==1 (table left 16 + 2 tuck − 17 width).
        XCTAssertEqual(grip!.minX, 1, accuracy: 0.5, "full-page grip position is unchanged")
    }
}
#endif
