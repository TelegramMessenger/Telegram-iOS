import XCTest
import RichTextEditorCore
@testable import RichTextEngineEditor

@available(iOS 18.4, *)
final class EngineTableGridTests: XCTestCase {
    private func cell(_ id: String, colspan: Int = 1, rowspan: Int = 1, vAlign: VerticalAlignment = .top) -> Cell {
        Cell(id: BlockID(id), verticalAlignment: vAlign, colspan: colspan, rowspan: rowspan)
    }
    private func table(widths: [Double], rows: [[Cell]], compact: Bool = false, bordered: Bool = true,
                       rowHeights: [Double?]? = nil) -> TableBlock {
        TableBlock(id: BlockID("t"), columns: widths.map(ColumnSpec.init),
                   rows: rows.enumerated().map { i, cells in Row(id: BlockID("r\(i)"), height: rowHeights?[i] ?? nil, cells: cells) },
                   compact: compact, bordered: bordered)
    }

    func test_columnsScaleProportionallyToFitTheWidth() {
        let t = table(widths: [100, 300], rows: [[cell("a"), cell("b")]])
        // 3 borders of 1pt → 800 available; 1:3 scaled by 2 → 200 / 600 (both above the floor)
        XCTAssertEqual(EngineTableGrid.columnWidths(for: t, availableWidth: 803), [200, 600])
    }

    func test_columnsNeverDropBelowTheFloorSoATableCanOverflow() {
        let t = table(widths: [100, 100, 100], rows: [[cell("a"), cell("b"), cell("c")]])
        let widths = EngineTableGrid.columnWidths(for: t, availableWidth: 200)
        XCTAssertEqual(widths, [100, 100, 100])
        let grid = EngineTableGrid.solve(table: t, availableWidth: 200, usedHeights: [:])
        XCTAssertEqual(grid.size.width, 304, "3 × 100 + 4 borders: wider than the 200 available")
    }

    func test_zeroWidthColumnsShareEqually() {
        let t = table(widths: [0, 0], rows: [[cell("a"), cell("b")]])
        XCTAssertEqual(EngineTableGrid.columnWidths(for: t, availableWidth: 203), [100, 100])
    }

    func test_rowHeightIsTheTallestCellPlusPaddingAndHonoursADeclaredMinimum() {
        let t = table(widths: [100, 100], rows: [[cell("a"), cell("b")], [cell("c"), cell("d")]], rowHeights: [nil, 80])
        let grid = EngineTableGrid.solve(table: t, availableWidth: 203,
                                         usedHeights: [BlockID("a"): 20, BlockID("b"): 36, BlockID("c"): 10, BlockID("d"): 10])
        XCTAssertEqual(grid.rowHeights, [36 + 28, 80])
        XCTAssertEqual(grid.size.height, 1 + 64 + 1 + 80 + 1)
    }

    func test_cellRectsTileTheGridBetweenBorders() {
        let t = table(widths: [100, 100], rows: [[cell("a"), cell("b")], [cell("c"), cell("d")]])
        let grid = EngineTableGrid.solve(table: t, availableWidth: 203, usedHeights: [:])
        let h = 28.0   // empty cells: 0 + 2 × 14
        XCTAssertEqual(grid.cell(withID: BlockID("a"))?.rect, CGRect(x: 1, y: 1, width: 100, height: h))
        XCTAssertEqual(grid.cell(withID: BlockID("b"))?.rect, CGRect(x: 102, y: 1, width: 100, height: h))
        XCTAssertEqual(grid.cell(withID: BlockID("c"))?.rect, CGRect(x: 1, y: 1 + h + 1, width: 100, height: h))
        XCTAssertEqual(grid.cell(withID: BlockID("a"))?.textInsets, UIEdgeInsets(top: 14, left: 6, bottom: 0, right: 7),
                       "6pt sides (+ the border on the right, as legacy's content width subtracts), 14pt top")
    }

    func test_aColspanCellSpansTheColumnsAndTheirInteriorBorder() {
        let t = table(widths: [100, 100], rows: [[cell("a", colspan: 2)], [cell("c"), cell("d")]])
        let grid = EngineTableGrid.solve(table: t, availableWidth: 203, usedHeights: [:])
        XCTAssertEqual(grid.cell(withID: BlockID("a"))?.rect.width, 201)
    }

    func test_aRowspanCellTallerThanItsRowsGrowsTheLastRowItSpans() {
        let t = table(widths: [100, 100], rows: [[cell("a", rowspan: 2), cell("b")], [cell("d")]])
        let grid = EngineTableGrid.solve(table: t, availableWidth: 203, usedHeights: [BlockID("a"): 100])
        // a needs 128; rows are 28 + 1 + 28 = 57 → the second row grows by 71
        XCTAssertEqual(grid.rowHeights, [28, 28 + 71])
        XCTAssertEqual(grid.cell(withID: BlockID("a"))?.rect.height, 128)
    }

    func test_compactHalvesBothPaddingsAndUnborderedHasNoBorders() {
        let t = table(widths: [100], rows: [[cell("a")]], compact: true, bordered: false)
        let grid = EngineTableGrid.solve(table: t, availableWidth: 100, usedHeights: [BlockID("a"): 10])
        XCTAssertEqual(grid.borderWidth, 0)
        XCTAssertEqual(grid.rowHeights, [10 + 14])
        XCTAssertEqual(grid.cell(withID: BlockID("a"))?.textInsets, UIEdgeInsets(top: 7, left: 3, bottom: 0, right: 3))
        XCTAssertEqual(grid.cell(withID: BlockID("a"))?.rect.origin, .zero)
    }

    func test_middleAndBottomAlignmentMoveTheTextInsideTheRow() {
        let t = table(widths: [100, 100, 100],
                      rows: [[cell("a"), cell("b", vAlign: .middle), cell("c", vAlign: .bottom)]])
        let grid = EngineTableGrid.solve(table: t, availableWidth: 304,
                                         usedHeights: [BlockID("a"): 60, BlockID("b"): 20, BlockID("c"): 20])
        XCTAssertEqual(grid.cell(withID: BlockID("a"))?.textInsets.top, 14)
        XCTAssertEqual(grid.cell(withID: BlockID("b"))?.textInsets.top, 14 + 20, "free 40 → half")
        XCTAssertEqual(grid.cell(withID: BlockID("c"))?.textInsets.top, 14 + 40)
    }

    func test_aRaggedRowIsPaddedAndAnOverflowingSpanIsClamped() {
        let t = table(widths: [100, 100], rows: [[cell("a")], [cell("c", colspan: 5), cell("d")]])
        let grid = EngineTableGrid.solve(table: t, availableWidth: 203, usedHeights: [:])
        XCTAssertEqual(grid.cells.count, 2, "a and c; the ragged slot is empty space, and d has nowhere to go")
        XCTAssertEqual(grid.cell(withID: BlockID("c"))?.rect.width, 201, "clamped to the grid")
        XCTAssertNil(grid.cell(withID: BlockID("d")), "a cell the map could not place is dropped from geometry, not trapped on")
    }
}
