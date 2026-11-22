#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class FullBleedLayoutTests: XCTestCase {
    private func canvas(_ blocks: [Block], width: CGFloat) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600)
        v.layoutIfNeeded()
        return v
    }

    func test_paragraphText_insetByPageMargin() {
        let v = canvas([.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "Hi")]))], width: 390)
        let box = v.boxes[0] as! BlockBox
        XCTAssertEqual(box.textOrigin.x, CanvasMetrics.pageMargin, accuracy: 0.5)   // 16pt, not 8
    }

    func test_imageRect_fullBleedToCanvasEdges() {
        let v = canvas([
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 100, height: 50),
                              caption: [TextRun(text: "Cap")]))
        ], width: 390)
        let img = v.boxes[0] as! MediaBlockBox
        let rect = img.mediaRect()
        XCTAssertEqual(rect.minX, 0, accuracy: 0.5)          // bleeds to the left edge
        XCTAssertEqual(rect.width, 390, accuracy: 0.5)        // full canvas width
    }

    func test_caption_insetByPageMargin() {
        let v = canvas([
            .media(MediaBlock(id: BlockID("img"), mediaID: "x", naturalSize: Size2D(width: 100, height: 50),
                              caption: [TextRun(text: "Cap")]))
        ], width: 390)
        let img = v.boxes[0] as! MediaBlockBox
        XCTAssertEqual(img.textOrigin.x, CanvasMetrics.pageMargin, accuracy: 0.5)   // caption at 16
    }

    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id+"p"), runs: [TextRun(text: t)]))])
    }

    func test_tableGrid_insetByPageMargin() {
        let v = canvas([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","Name"), cell("b","Role")]),
                   Row(id: BlockID("r1"), cells: [cell("c","Ada"), cell("d","Eng")])]))], width: 390)
        let t = v.boxes[0] as! TableBlockBox
        let r0c0 = t.cellRect(row: 0, column: 0)!
        XCTAssertGreaterThanOrEqual(r0c0.minX, CanvasMetrics.pageMargin)   // grid inset, not at x=0
    }

    func test_cellText_isTight_notPageMarginInset() {
        let v = canvas([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","Name"), cell("b","Role")]),
                   Row(id: BlockID("r1"), cells: [cell("c","Ada"), cell("d","Eng")])]))], width: 390)
        let t = v.boxes[0] as! TableBlockBox
        let innerBox = t.cells[0][0].boxes[0] as! BlockBox
        let cellLeft = t.cellRect(row: 0, column: 0)!.minX
        // Cell text must sit within ~cellPadding of the cell's left border (NOT pageMargin-inset).
        XCTAssertLessThanOrEqual(innerBox.textOrigin.x - cellLeft, TableBlockBox.cellPadding + 2)   // +2: 1pt cell border + sub-pixel rounding
    }
}
#endif
