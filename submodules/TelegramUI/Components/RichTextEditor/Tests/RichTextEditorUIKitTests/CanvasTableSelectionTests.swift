#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasTableSelectionTests: XCTestCase {
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

    func test_tapInSecondCell_landsInThatCell() {
        let v = canvas()
        let regionB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let pt = CGPoint(x: regionB.canvasOrigin.x + 2, y: regionB.canvasOrigin.y + 2)
        let pos = v.closestGlobalPosition(to: pt)
        XCTAssertEqual(v.leafRegion(containingGlobal: pos)?.region.ref, .paragraph(BlockID("bp")))
    }

    func test_withinCellSelection_producesRects() {
        let v = canvas()
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let rects = v.selectionRects(globalFrom: rA.globalStart, globalTo: rA.globalStart + rA.length)
        XCTAssertFalse(rects.isEmpty)
    }

    func test_caretInCell_isWithinCellArea() {
        let v = canvas()
        let rB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let caret = v.caretRect(for: DocumentTextPosition(rB.globalStart))
        XCTAssertGreaterThan(caret.minX, rB.canvasOrigin.x - 1)
    }

    func test_crossCellSelection_unionCoversBothCells() {
        let v = canvas()
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let rB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let rects = v.selectionRects(globalFrom: rA.globalStart + 2, globalTo: rB.globalStart + 2)
        XCTAssertFalse(rects.isEmpty)
        let inA = rects.contains { $0.minX < rB.canvasOrigin.x - 1 }
        let inB = rects.contains { $0.maxX > rB.canvasOrigin.x - 1 }
        XCTAssertTrue(inA, "highlight covers part of cell A")
        XCTAssertTrue(inB, "highlight continues into cell B")
    }

    func test_closestPosition_atGridGutterAndBelowTable_landsInRealRegion() {
        let v = canvas()
        let rA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        let rB = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("bp")) }!
        let gutter = CGPoint(x: rB.canvasOrigin.x - 2, y: rB.canvasOrigin.y + 2)
        XCTAssertNotNil(v.leafRegion(containingGlobal: v.closestGlobalPosition(to: gutter)),
                        "a point in the inter-cell gutter resolves to a real text region")
        let below = CGPoint(x: rA.canvasOrigin.x + 2, y: v.bounds.height - 1)
        XCTAssertNotNil(v.leafRegion(containingGlobal: v.closestGlobalPosition(to: below)),
                        "a point below the table resolves to a real text region")
    }
}
#endif
