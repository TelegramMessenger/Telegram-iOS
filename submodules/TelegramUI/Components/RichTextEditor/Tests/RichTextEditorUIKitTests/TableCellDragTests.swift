#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Phase 2c Task 4: dragging a `.cells` corner knob PROMOTES the focused-cell "fake" chrome (T3) to a
/// committed `.cells` selection and extends it in 2D — the extend MATH + promotion (unit-testable); the raw
/// gesture wiring is runtime-verified in T6.
final class TableCellDragTests: XCTestCase {
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }

    /// A dense 3x3 table, ids "a".."i" row-major (row0: a,b,c; row1: d,e,f; row2: g,h,i).
    private func dense3x3() -> TableBlock {
        TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B"), cell("c", "C")]),
                Row(id: BlockID("r1"), cells: [cell("d", "D"), cell("e", "E"), cell("f", "F")]),
                Row(id: BlockID("r2"), cells: [cell("g", "G"), cell("h", "H"), cell("i", "I")]),
            ])
    }

    /// A 3x3 table with a colspan-2 cell merged at (0,0)-(0,1) (absorbing "b"'s content into "a"'s stack).
    private func mergedTopLeftColspan2() -> TableBlock {
        dense3x3().mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))
    }

    private func canvas(_ table: TableBlock, width: CGFloat = 390) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.table(table)], width: width)
        v.frame = CGRect(x: 0, y: 0, width: width, height: 600); v.layoutIfNeeded()
        return v
    }

    private func table(_ v: DocumentCanvasView) -> TableBlockBox { v.boxes[0] as! TableBlockBox }

    /// Canvas x at the MIDDLE of the physical column band `column` (span-neutral — unlike `cellRect`, which
    /// resolves a covered slot to its merged anchor's whole footprint). Guarantees `columnIndex(atX:)`
    /// resolves back to exactly `column`.
    private func bandMidX(_ t: TableBlockBox, column: Int) -> CGFloat {
        var x = t.frame.minX + TableBlockBox.border
        for c in 0..<column { x += t.columnWidths[c] + TableBlockBox.border }
        return x + t.columnWidths[column] / 2
    }
    /// Canvas y at the middle of the physical row band `row` — the y-axis counterpart of `bandMidX`.
    private func bandMidY(_ t: TableBlockBox, row: Int) -> CGFloat {
        var y = t.frame.minY + TableBlockBox.border
        for r in 0..<row { y += t.rowHeights[r] + TableBlockBox.border }
        return y + t.rowHeights[row] / 2
    }

    // MARK: - 1. Promotion: focused cell (fake chrome) → committed .cells selection

    func test_extendCellSelection_fromFocusedCell_commitsCellsSelection() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        XCTAssertNil(v.tableSelection, "precondition: no committed selection, only the fake chrome")

        let target = CGPoint(x: bandMidX(t, column: 1), y: bandMidY(t, row: 1))
        v.extendCellSelection(corner: .bottomRight, toward: target)

        guard case .cells(let rect) = v.tableSelection?.kind else { return XCTFail("expected a committed .cells selection") }
        XCTAssertEqual(v.tableSelection?.table, BlockID("t"))
        XCTAssertEqual(rect, TableRect(top: 0, left: 0, bottom: 1, right: 1))
    }

    // MARK: - 2. Snaps to whole merged cell

    func test_extendCellSelection_snapsToWholeMergedCell() {
        let v = canvas(mergedTopLeftColspan2()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 2, column: 2)!, head: t.cellTextStart(row: 2, column: 2)!)   // focused cell (2,2), no selection
        XCTAssertNil(v.tableSelection)

        // Drag the topLeft corner toward physical (row 0, col 1) — part of the merged (0,0)-(0,1) cell's
        // footprint but not its anchor slot.
        let target = CGPoint(x: bandMidX(t, column: 1), y: bandMidY(t, row: 0))
        v.extendCellSelection(corner: .topLeft, toward: target)

        guard case .cells(let rect) = v.tableSelection?.kind else { return XCTFail("expected .cells") }
        XCTAssertEqual(rect, TableRect(top: 0, left: 0, bottom: 2, right: 2),
                       "expanded left to fully cover the merged (0,0)-(0,1) cell, not bisect it")
    }

    // MARK: - 3. Clamps to the grid

    func test_extendCellSelection_clampsToGrid() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)

        v.extendCellSelection(corner: .topLeft, toward: CGPoint(x: -9999, y: -9999))
        guard case .cells(let low) = v.tableSelection?.kind else { return XCTFail() }
        XCTAssertEqual(low, TableRect(top: 0, left: 0, bottom: 1, right: 1), "clamped to row/column 0")

        v.clearTableSelection()
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        v.extendCellSelection(corner: .bottomRight, toward: CGPoint(x: 9999, y: 9999))
        guard case .cells(let high) = v.tableSelection?.kind else { return XCTFail() }
        XCTAssertEqual(high, TableRect(top: 1, left: 1, bottom: 2, right: 2), "clamped to the last row/column")
    }

    // MARK: - 4. The fixed corner is the CURRENT rect's corner opposite the one dragged

    func test_extendCellSelection_fixedCornerIsOppositeDraggedCorner() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)

        // Drag bottomRight out to (2,2): fixed corner is the focused cell's topLeft (1,1).
        v.extendCellSelection(corner: .bottomRight, toward: CGPoint(x: bandMidX(t, column: 2), y: bandMidY(t, row: 2)))
        guard case .cells(let rect1) = v.tableSelection?.kind else { return XCTFail() }
        XCTAssertEqual(rect1, TableRect(top: 1, left: 1, bottom: 2, right: 2))

        // Continue by dragging topLeft toward (0,0): the fixed corner must now be the CURRENT committed
        // rect's bottomRight (2,2) — NOT the original focused cell (1,1) — so the rect grows to (0,0)-(2,2).
        v.extendCellSelection(corner: .topLeft, toward: CGPoint(x: bandMidX(t, column: 0), y: bandMidY(t, row: 0)))
        guard case .cells(let rect2) = v.tableSelection?.kind else { return XCTFail() }
        XCTAssertEqual(rect2, TableRect(top: 0, left: 0, bottom: 2, right: 2))

        // And the reverse: dragging topRight/bottomLeft keep their own opposite corner fixed too.
        v.clearTableSelection()
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        v.extendCellSelection(corner: .topRight, toward: CGPoint(x: bandMidX(t, column: 0), y: bandMidY(t, row: 0)))
        guard case .cells(let rect3) = v.tableSelection?.kind else { return XCTFail() }
        // fixed = bottomLeft of the focused cell (1,1); moved = (0,0) → rect spans rows 0...1, cols 0...1.
        XCTAssertEqual(rect3, TableRect(top: 0, left: 0, bottom: 1, right: 1))
    }

    // MARK: - 5. Dense parity: extendTableSelection(end:toward:) for .rows/.columns is unchanged

    func test_denseParity_extendTableSelection_columnsUnaffectedByCellDragCode() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableColumn(0)
        v.extendTableSelection(end: .upper, toward: CGPoint(x: bandMidX(t, column: 1), y: 0))
        XCTAssertEqual(v.tableSelection?.kind, .columns(0...1))
    }

    func test_denseParity_extendTableSelection_rowsUnaffectedByCellDragCode() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableRow(0)
        v.extendTableSelection(end: .upper, toward: CGPoint(x: 0, y: bandMidY(t, row: 1)))
        XCTAssertEqual(v.tableSelection?.kind, .rows(0...1))
    }

    // MARK: - 6. Hit-testing the corner knob (committed selection AND the focused-cell fake chrome)

    func test_tableResizeCornerKnob_hitsKnob_committedCellsSelection() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        let knob = v.tableResizeKnobs().first { $0.corner == .bottomRight }!
        XCTAssertEqual(v.tableResizeCornerKnob(at: CGPoint(x: knob.rect.midX, y: knob.rect.midY)), .bottomRight)
    }

    func test_tableResizeCornerKnob_hitsKnob_focusedCellFakeChrome() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        XCTAssertNil(v.tableSelection, "precondition: fake chrome, no committed selection")
        let knob = v.tableResizeKnobs().first { $0.corner == .topLeft }!
        XCTAssertEqual(v.tableResizeCornerKnob(at: CGPoint(x: knob.rect.midX, y: knob.rect.midY)), .topLeft)
    }

    func test_tableResizeCornerKnob_nilAwayFromAnyKnob() {
        let v = canvas(dense3x3())
        XCTAssertNil(v.tableResizeCornerKnob(at: CGPoint(x: -9999, y: -9999)))
    }

    // MARK: - 7. isSelectionDragTouch recognizes a corner-knob touch, including the fake chrome (T4 wiring)

    func test_isSelectionDragTouch_trueForCornerKnob_focusedCellFakeChrome() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        XCTAssertNil(v.tableSelection)
        let knob = v.tableResizeKnobs().first { $0.corner == .bottomRight }!
        XCTAssertTrue(v.isSelectionDragTouch(CGPoint(x: knob.rect.midX, y: knob.rect.midY)),
                      "a touch on the fake chrome's corner knob must begin a drag (which promotes on the first update)")
    }

    func test_isSelectionDragTouch_trueForCornerKnob_committedCellsSelection() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        let knob = v.tableResizeKnobs().first { $0.corner == .topLeft }!
        XCTAssertTrue(v.isSelectionDragTouch(CGPoint(x: knob.rect.midX, y: knob.rect.midY)))
    }
}
#endif
