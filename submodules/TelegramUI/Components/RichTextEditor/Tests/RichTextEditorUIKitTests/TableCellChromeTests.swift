#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Phase 2c Task 3: the FOCUSED-CELL "fake" structural chrome (caret in a table cell, no COMMITTED
/// `tableSelection`) + the span-aware `.cells` outline/corner-knob geometry. Drawing/geometry only — the
/// knob DRAG gesture is T4 (this suite only asserts the knobs' rects + corner identity).
final class TableCellChromeTests: XCTestCase {
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

    private func assertRectsEqual(_ a: CGRect, _ b: CGRect, accuracy: CGFloat = 0.5, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.minX, b.minX, accuracy: accuracy, "minX", file: file, line: line)
        XCTAssertEqual(a.minY, b.minY, accuracy: accuracy, "minY", file: file, line: line)
        XCTAssertEqual(a.maxX, b.maxX, accuracy: accuracy, "maxX", file: file, line: line)
        XCTAssertEqual(a.maxY, b.maxY, accuracy: accuracy, "maxY", file: file, line: line)
    }

    // MARK: - 1. focusedOrSelectedCellRect()

    func test_focusedOrSelectedCellRect_prefersCommittedSelection() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        XCTAssertEqual(v.focusedOrSelectedCellRect(), TableRect(top: 0, left: 0, bottom: 1, right: 1))
    }

    func test_focusedOrSelectedCellRect_fallsBackToCaretCell_whenNoSelection() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 2, column: 1)!, head: t.cellTextStart(row: 2, column: 1)!)
        XCTAssertNil(v.tableSelection)
        XCTAssertEqual(v.focusedOrSelectedCellRect(), TableRect(top: 2, left: 1, bottom: 2, right: 1))
    }

    func test_focusedOrSelectedCellRect_mergedCell_reportsWholeFootprint() {
        let v = canvas(mergedTopLeftColspan2()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)   // caret in the merged (0,0)-(0,1) cell
        XCTAssertNil(v.tableSelection)
        XCTAssertEqual(v.focusedOrSelectedCellRect(), TableRect(top: 0, left: 0, bottom: 0, right: 1))
    }

    func test_focusedOrSelectedCellRect_nilWhenCaretOutsideTable() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hi")])), .table(dense3x3())], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 600); v.layoutIfNeeded()
        v.setSelectionForTesting(anchor: 0, head: 0)
        XCTAssertNil(v.focusedOrSelectedCellRect())
    }

    // MARK: - 2. Focused-cell "fake" chrome (Correctness bar item 1)

    func test_focusedCell_showsFakeChrome_whenNoSelection() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        XCTAssertNil(v.tableSelection, "precondition: no committed selection")

        let outline = v.tableSelectionOutlineRect()
        XCTAssertNotNil(outline, "the caret's cell shows fake chrome even with no committed selection")
        let expected = t.cellRect(row: 1, column: 1)!.insetBy(dx: -TableBlockBox.border, dy: -TableBlockBox.border)
        assertRectsEqual(outline!, expected)

        let knobs = v.tableResizeKnobs()
        XCTAssertEqual(knobs.count, 4, "four corner knobs for the fake chrome")
        XCTAssertEqual(Set(knobs.compactMap { $0.corner }), Set<TableCellCorner>([.topLeft, .topRight, .bottomLeft, .bottomRight]))
        XCTAssertTrue(knobs.allSatisfy { $0.end == nil }, "a corner knob carries no range end")
    }

    func test_focusedCell_insideMergedCell_showsWholeMergedCellChrome() {
        let v = canvas(mergedTopLeftColspan2()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)   // caret inside the merged (0,0)-(0,1) cell
        XCTAssertNil(v.tableSelection)

        let outline = v.tableSelectionOutlineRect()!
        let mergedCellRect = t.cellRect(row: 0, column: 0)!   // span-aware: already the whole merged footprint
        assertRectsEqual(outline, mergedCellRect.insetBy(dx: -TableBlockBox.border, dy: -TableBlockBox.border))
        // Fully encloses the neighboring covered slot (physical column 1, same anchor).
        let coveredSlot = t.cellRect(row: 0, column: 1)!
        XCTAssertLessThanOrEqual(outline.minX, coveredSlot.minX + 0.5)
        XCTAssertGreaterThanOrEqual(outline.maxX, coveredSlot.maxX - 0.5)
    }

    func test_focusedCell_atTableCorner_roundsThatCornerOnly() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)   // top-left cell, no selection
        XCTAssertNil(v.tableSelection)
        let corners = v.tableSelectionOutlineCorners()
        XCTAssertTrue(corners.contains(.topLeft))
        XCTAssertFalse(corners.contains(.topRight) || corners.contains(.bottomLeft) || corners.contains(.bottomRight))
    }

    func test_focusedCell_interior_roundsNoCorners() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)   // interior cell of a 3x3 table
        XCTAssertTrue(v.tableSelectionOutlineCorners().isEmpty)
    }

    // MARK: - 3. Committed `.cells` selection: span-aware union outline (Correctness bar item 2)

    func test_committedCellsSelection_outlineUnionExpanded_enclosesMergedCell() {
        let v = canvas(mergedTopLeftColspan2()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 2)!, head: t.cellTextStart(row: 1, column: 2)!)
        // (0,1)-(1,2) bisects the merged (0,0)-(0,1) cell along its right half → auto-expands left to col 0.
        v.selectTableCells(TableRect(top: 0, left: 1, bottom: 1, right: 2))
        guard case .cells(let committed) = v.tableSelection?.kind else { return XCTFail("expected .cells") }
        XCTAssertEqual(committed, TableRect(top: 0, left: 0, bottom: 1, right: 2), "expanded left to cover the merged cell")

        let outline = v.tableSelectionOutlineRect()!
        let lo = t.cellRect(row: 0, column: 0)!, hi = t.cellRect(row: 1, column: 2)!
        assertRectsEqual(outline, lo.union(hi).insetBy(dx: -TableBlockBox.border, dy: -TableBlockBox.border))

        // Fully encloses the merged (0,0)-(0,1) cell.
        let mergedCellRect = t.cellRect(row: 0, column: 0)!
        XCTAssertLessThanOrEqual(outline.minX, mergedCellRect.minX + 0.5)
        XCTAssertGreaterThanOrEqual(outline.maxX, mergedCellRect.maxX - 0.5)
        XCTAssertLessThanOrEqual(outline.minY, mergedCellRect.minY + 0.5)
        XCTAssertGreaterThanOrEqual(outline.maxY, mergedCellRect.maxY - 0.5)
    }

    // MARK: - 4. Cell-selection knobs are drawn at the CENTER OF EACH SIDE (keeping corner drag identity)

    func test_cellSelection_knobs_atSideCenters() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 0)!)
        v.selectTableCells(TableRect(top: 0, left: 0, bottom: 1, right: 1))
        // Knobs center on the outline STROKE's centerline (raw rect inset by half the line width).
        let inset = DocumentCanvasView.selectionOutlineWidth / 2
        let outline = v.tableSelectionOutlineRect()!.insetBy(dx: inset, dy: inset)
        let knobs = v.tableResizeKnobs()
        XCTAssertEqual(knobs.count, 4)
        // Each corner-identity knob is DRAWN at a side midpoint (relocation only — the corner drives the drag):
        // topLeft → top-center, topRight → right-center, bottomLeft → left-center, bottomRight → bottom-center.
        let expected: [TableCellCorner: CGPoint] = [
            .topLeft: CGPoint(x: outline.midX, y: outline.minY),
            .topRight: CGPoint(x: outline.maxX, y: outline.midY),
            .bottomLeft: CGPoint(x: outline.minX, y: outline.midY),
            .bottomRight: CGPoint(x: outline.midX, y: outline.maxY),
        ]
        for knob in knobs {
            guard let c = knob.corner, let pt = expected[c] else { return XCTFail("every cell knob carries a corner") }
            XCTAssertEqual(knob.rect.midX, pt.x, accuracy: 0.5)
            XCTAssertEqual(knob.rect.midY, pt.y, accuracy: 0.5)
            XCTAssertNil(knob.end, "a cell corner knob has no range end")
        }
        // All four sit on distinct edges (not stacked): 2 share the vertical centerline, 2 share the horizontal.
        XCTAssertEqual(Set(knobs.map { ($0.rect.midX * 2).rounded() }).count, 3, "x positions: minX, midX, maxX")
        XCTAssertEqual(Set(knobs.map { ($0.rect.midY * 2).rounded() }).count, 3, "y positions: minY, midY, maxY")
    }

    // MARK: - 5. No fake chrome when the caret isn't in a table (Correctness bar item 4)

    func test_noFakeChrome_whenCaretOutsideTable() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")])), .table(dense3x3())], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 600); v.layoutIfNeeded()
        v.setSelectionForTesting(anchor: 0, head: 0)   // caret in the paragraph, not the table
        XCTAssertNil(v.tableSelectionOutlineRect())
        XCTAssertTrue(v.tableResizeKnobs().isEmpty)
        XCTAssertTrue(v.tableSelectionOutlineCorners().isEmpty)
    }

    // MARK: - 6. Dense parity: .rows/.columns chrome unchanged even though the caret sits in a cell

    func test_denseParity_columnSelection_stillTwoRangeEndKnobs_notFourCorners() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 1)!, head: t.cellTextStart(row: 1, column: 1)!)
        v.selectTableColumn(1)
        let knobs = v.tableResizeKnobs()
        XCTAssertEqual(knobs.count, 2, "a committed column selection keeps its 2 range-end knobs, not 4 corner knobs")
        XCTAssertTrue(knobs.allSatisfy { $0.corner == nil })
        XCTAssertTrue(knobs.allSatisfy { $0.end != nil })
        XCTAssertTrue(v.tableSelectionOutlineCorners().isEmpty, "column 1 is interior in a 3-column table")
    }

    func test_denseParity_rowSelection_outlineAndKnobsUnchanged() {
        let v = canvas(dense3x3()); let t = table(v)
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 1, column: 0)!, head: t.cellTextStart(row: 1, column: 0)!)
        v.selectTableRow(1)
        let outline = v.tableSelectionOutlineRect()!
        let expected = t.cellRect(row: 1, column: 0)!.union(t.cellRect(row: 1, column: 2)!)
            .insetBy(dx: -TableBlockBox.border, dy: -TableBlockBox.border)
        assertRectsEqual(outline, expected)
        let knobs = v.tableResizeKnobs()
        XCTAssertEqual(knobs.count, 2)
        // Knob centers sit on the stroke centerline (outline inset by half the line width).
        let strokeInset = DocumentCanvasView.selectionOutlineWidth / 2
        let stroked = outline.insetBy(dx: strokeInset, dy: strokeInset)
        XCTAssertEqual(knobs.first { $0.end == .lower }!.rect.midY, stroked.minY, accuracy: 0.5)
        XCTAssertEqual(knobs.first { $0.end == .upper }!.rect.midY, stroked.maxY, accuracy: 0.5)
    }
}
#endif
