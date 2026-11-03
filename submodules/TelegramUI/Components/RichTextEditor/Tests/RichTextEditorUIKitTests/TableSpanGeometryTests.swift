#if canImport(UIKit)
import XCTest
import RichTextEditorCore
@testable import RichTextEditorUIKit

@available(iOS 13.0, *)
final class TableSpanGeometryTests: XCTestCase {
    func mergedTopRowTable() -> TableBlock {
        func c(_ id: String,_ t: String) -> Cell { Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id+"p"), runs: [TextRun(text: t)]))]) }
        let dense = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [c("a","A"), c("b","B")]),
                   Row(id: BlockID("r1"), cells: [c("c","C"), c("d","D")])])
        return dense.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))
    }

    func test_currentBlock_roundTripsSpans() {
        let box = TableBlockBox(table: mergedTopRowTable(), mapper: AttributedStringMapper(), width: 300)
        box.frame = CGRect(x: 0, y: 0, width: 300, height: 300); box.recompute()
        guard case .table(let out) = box.currentBlock() else { return XCTFail() }
        XCTAssertEqual(out.rows[0].cells.count, 1)
        XCTAssertEqual(out.rows[0].cells[0].colspan, 2)
        XCTAssertEqual(out.rows[0].cells[0].rowspan, 1)
        XCTAssertEqual(out.rows[1].cells.count, 2)
        XCTAssertTrue(TableMap(out).isWellFormed)
    }

    func test_mergedTable_doesNotCrashOnLayout() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(mergedTopRowTable())], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        let img = UIGraphicsImageRenderer(bounds: v.bounds).image { _ in v.drawHierarchy(in: v.bounds, afterScreenUpdates: true) }
        XCTAssertNotNil(img.cgImage)
    }

    // MARK: - Phase 2b Task 3: span-aware frame walk + cellRect union

    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }

    /// A 3x3 dense grid merged into: a colspan-2/rowspan-2 anchor at (0,0) (absorbing b/c/d's content),
    /// a dense cell at (0,2)/(1,2), and a fully dense row 2. Exercises the physical-column-cursor SKIP:
    /// row 1's only declared cell ("f") sits at physical column 2 (its declared array index is 0), since
    /// physical columns 0-1 are occupied by the rowspan descending from row 0.
    private func topLeftMergedGrid() -> TableBlock {
        let dense = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B"), cell("e", "E")]),
                Row(id: BlockID("r1"), cells: [cell("c", "C"), cell("d", "D"), cell("f", "F")]),
                Row(id: BlockID("r2"), cells: [cell("g", "G"), cell("h", "H"), cell("i", "I")]),
            ])
        return dense.mergingCells(in: TableRect(top: 0, left: 0, bottom: 1, right: 1))
    }

    func test_cellRect_spansColumnsAndRows() {
        let box = TableBlockBox(table: topLeftMergedGrid(), mapper: AttributedStringMapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        box.recompute(); box.recompute()
        let cols = box.columnWidths, rows = box.rowHeights
        guard let rect = box.cellRect(row: 0, column: 0) else { return XCTFail("expected a rect") }
        XCTAssertEqual(rect.width, cols[0] + cols[1] + TableBlockBox.border, accuracy: 0.01,
                       "the spanned rect's width unions both columns plus the interior border it subsumes")
        XCTAssertEqual(rect.height, rows[0] + rows[1] + TableBlockBox.border, accuracy: 0.01,
                       "the spanned rect's height unions both rows plus the interior border it subsumes")
        // Querying a COVERED slot resolves to the SAME anchor rect.
        XCTAssertEqual(box.cellRect(row: 0, column: 1), rect, "a covered slot resolves to its anchor's union rect")
        XCTAssertEqual(box.cellRect(row: 1, column: 0), rect, "a covered slot resolves to its anchor's union rect")
        XCTAssertEqual(box.cellRect(row: 1, column: 1), rect, "a covered slot resolves to its anchor's union rect")
    }

    func test_recompute_laysMergedCellAtSpannedWidth() {
        let box = TableBlockBox(table: topLeftMergedGrid(), mapper: AttributedStringMapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        box.recompute(); box.recompute()
        let expectedContentWidth = box.cellContentWidth(anchorColumn: 0, colspan: 2, in: box.columnWidths)
        let mergedParagraph = box.cells[0][0].boxes[0]
        XCTAssertEqual(mergedParagraph.frame.width, expectedContentWidth, accuracy: 0.5,
                       "the merged cell lays out at the SPANNED content width, not a single column's width")
        // Sanity: NOT laid out at a single unspanned column's width.
        let singleColumnWidth = box.cellContentWidth(anchorColumn: 0, colspan: 1, in: box.columnWidths)
        XCTAssertGreaterThan(mergedParagraph.frame.width, singleColumnWidth + 10,
                             "sanity: the spanned width is materially wider than one column")
    }

    // Row 1's only declared cell ("f") sits at PHYSICAL column 2 (columns 0-1 are covered by the
    // rowspan descending from row 0) — its laid-out frame must sit at column 2, not stack at physical
    // column 0 (which would happen if the frame walk didn't skip occupied columns).
    func test_recompute_skipsPhysicalColumnsOccupiedByDescendingRowspan() {
        let box = TableBlockBox(table: topLeftMergedGrid(), mapper: AttributedStringMapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        box.recompute(); box.recompute()
        let fBox = box.cells[1][0].boxes[0]   // "f" is row 1's only DECLARED cell (array index 0)
        let col2Rect = box.cellRect(row: 1, column: 2)!
        XCTAssertEqual(fBox.frame.minX, col2Rect.minX + TableBlockBox.cellPadding, accuracy: 0.5,
                       "\"f\" (declared index 0, physical column 2) lays out at column 2, not column 0")
    }

    // Depth-3 descending skip: a colspan1/rowspan3 cell in column 0 covers rows 0-2. The declared cells
    // in rows 1 AND 2 (each their row's only declared cell) must be placed at PHYSICAL column 1 — the
    // column-cursor skip must step past column 0 for BOTH descending rows, not just the first, proving the
    // skip generalizes beyond depth 2 (the `while` loop, not a one-shot).
    func test_recompute_skipsPhysicalColumns_forRowspanDepth3() {
        let dense = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B0")]),
                Row(id: BlockID("r1"), cells: [cell("c", "C"), cell("d", "B1")]),
                Row(id: BlockID("r2"), cells: [cell("e", "E"), cell("f", "B2")]),
            ])
        // Merge column 0 across all three rows → a colspan1/rowspan3 anchor at (0,0).
        let merged = dense.mergingCells(in: TableRect(top: 0, left: 0, bottom: 2, right: 0))
        XCTAssertEqual(merged.rows[0].cells[0].rowspan, 3, "sanity: the transform merged a rowspan-3 cell")
        XCTAssertEqual(merged.rows[1].cells.count, 1, "row 1 declares only its column-1 cell")
        XCTAssertEqual(merged.rows[2].cells.count, 1, "row 2 declares only its column-1 cell")
        XCTAssertTrue(TableMap(merged).isWellFormed, "the rowspan-3 merge keeps the table well-formed")

        let box = TableBlockBox(table: merged, mapper: AttributedStringMapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: 500)
        box.recompute(); box.recompute()
        guard case .table(let out) = box.currentBlock() else { return XCTFail("expected a table") }
        XCTAssertTrue(TableMap(out).isWellFormed, "the box round-trips to a well-formed table after layout")

        // Both descending rows' declared cells sit at physical column 1 (past the rowspan in column 0).
        let expectedX = box.frame.minX + TableBlockBox.border + box.columnWidths[0] + TableBlockBox.border
                        + TableBlockBox.cellPadding
        let row1Box = box.cells[1][0].boxes[0]   // "d" / "B1" — row 1's only declared cell
        let row2Box = box.cells[2][0].boxes[0]   // "f" / "B2" — row 2's only declared cell
        XCTAssertEqual(row1Box.frame.minX, expectedX, accuracy: 0.5,
                       "row 1's declared cell skips column 0 (rowspan depth 1)")
        XCTAssertEqual(row2Box.frame.minX, expectedX, accuracy: 0.5,
                       "row 2's declared cell ALSO skips column 0 (rowspan depth 2) — the skip is a loop, not one-shot")
        // And via the physical-slot API, both resolve to column 1's own single-slot rect (not the span).
        XCTAssertEqual(box.cellRect(row: 1, column: 1)!.minX, expectedX - TableBlockBox.cellPadding, accuracy: 0.5)
        XCTAssertEqual(box.cellRect(row: 2, column: 1)!.minX, expectedX - TableBlockBox.cellPadding, accuracy: 0.5)
    }

    // The token/position walk must stay driven by ANCHOR count, never physical column/slot count.
    // `mergingCells` is content-PRESERVING (the doc comment: "content is pooled, never dropped") — the
    // absorbed cell's blocks are appended into the anchor's own `BlockStack`, so their token footprint
    // survives intact; only that cell's own `.cell`-node WRAPPER (open + close = 2 tokens) disappears,
    // since one fewer `.cell` is declared. So every body cell's global start must shift down by EXACTLY
    // 2 per removed cell — not by the removed cell's content tokens, which is what a (wrong) slot/physical-
    // column-driven walk would additionally subtract. (Equivalently: nodeSize drops by the same amount.)
    func test_recompute_tokenPositionsUnchanged() {
        let denseHeaderTable = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [
                Row(id: BlockID("h"), isHeader: true, cells: [cell("h0", "H0"), cell("h1", "H1")]),
                Row(id: BlockID("r0"), cells: [cell("p", "P"), cell("q", "Q")]),
                Row(id: BlockID("r1"), cells: [cell("s", "S"), cell("t", "T")]),
            ])
        let mergedHeaderTable = denseHeaderTable.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))
        XCTAssertEqual(mergedHeaderTable.rows[0].cells.count, 1, "sanity: the header merged to one cell")
        // Sanity: the merge is content-preserving — h1's paragraph survives inside the merged cell's stack.
        XCTAssertEqual(mergedHeaderTable.rows[0].cells[0].blocks.count, 2,
                       "sanity: the merged cell holds BOTH h0's and h1's blocks (concatenated, not dropped)")

        let denseBox = TableBlockBox(table: denseHeaderTable, mapper: AttributedStringMapper(), width: 320)
        denseBox.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        denseBox.recompute(); denseBox.recompute()
        var denseBodyStarts: [Int] = []
        for r in 1...2 { for c in 0...1 { denseBodyStarts.append(denseBox.cellTextStart(row: r, column: c)!) } }

        let mergedBox = TableBlockBox(table: mergedHeaderTable, mapper: AttributedStringMapper(), width: 320)
        mergedBox.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        mergedBox.recompute(); mergedBox.recompute()
        var mergedBodyStarts: [Int] = []
        for r in 1...2 { for c in 0...1 { mergedBodyStarts.append(mergedBox.cellTextStart(row: r, column: c)!) } }

        // Exactly ONE `.cell` node's wrapper (open + close) disappeared — h1's own content tokens moved
        // into h0's cell but were never lost, so the shift is 2, not h1's stackTokens + 2.
        let removedCellWrapperTokens = 2
        for (dense, merged) in zip(denseBodyStarts, mergedBodyStarts) {
            XCTAssertEqual(merged, dense - removedCellWrapperTokens,
                           "the body shifts down by EXACTLY the removed cell's OWN wrapper tokens (2) — " +
                           "its content tokens are preserved inside the merged anchor, and the token walk " +
                           "is driven by anchor count, not physical column/slot count")
        }
        // Equivalent, coarser check: nodeSize drops by exactly the one removed cell-node wrapper.
        XCTAssertEqual(mergedBox.nodeSize, denseBox.nodeSize - removedCellWrapperTokens,
                       "merging two cells into one reduces nodeSize by exactly the removed cell's wrapper tokens")
    }

    // MARK: - Phase 2b Task 4: span-aware hit-testing + slot→anchor resolution

    /// A tap physically inside a covered slot of a rowspan/colspan-2 anchor (topLeftMergedGrid's (0,0) anchor
    /// spans physical rows 0-1 / columns 0-1, so (0,1)/(1,0)/(1,1) are all COVERED slots) must resolve — via
    /// `closestPosition(toCanvasPoint:)` — to a position inside the ANCHOR's own stack, never a phantom cell.
    func test_tapInCoveredSlot_resolvesToAnchorStack() {
        let box = TableBlockBox(table: topLeftMergedGrid(), mapper: AttributedStringMapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        box.recompute(); box.recompute()
        let anchorStart = box.cells[0][0].leafRegions().first!.globalStart

        // The anchor's stack is a MERGE (`mergingCells` concatenates the absorbed cells' blocks), so it holds
        // several leaf regions (A's own paragraph, plus B/C/D's pooled-in paragraphs) — span the whole stack,
        // not just its first region, when checking a resolved position falls "inside the anchor's text".
        let anchorRegions = box.cells[0][0].leafRegions()
        let anchorLo = anchorRegions.first!.globalStart
        let anchorHi = anchorRegions.last!.globalStart + anchorRegions.last!.length

        for (row, column) in [(0, 1), (1, 0), (1, 1)] {
            let coveredRect = box.cellRect(row: row, column: column)!
            let pos = box.closestPosition(toCanvasPoint: CGPoint(x: coveredRect.midX, y: coveredRect.midY))
            // The resolved position must fall inside the ANCHOR's own stack, and `cellLocation` must report
            // it at the anchor's origin (0, 0) — not the covered slot.
            XCTAssertTrue(pos >= anchorLo && pos <= anchorHi,
                          "tap in covered slot (\(row),\(column)) resolves inside the anchor's own text")
            let loc = box.cellLocation(containing: pos)
            XCTAssertEqual(loc?.row, 0, "covered-slot tap (\(row),\(column)) maps to the anchor's origin row")
            XCTAssertEqual(loc?.column, 0, "covered-slot tap (\(row),\(column)) maps to the anchor's origin column")
            XCTAssertEqual(box.cellTextStart(row: 0, column: 0), anchorStart)
        }
    }

    /// `cellLocation(containing:)` must report the owning anchor's PHYSICAL origin, not the declared-cell
    /// array index — proven two ways: the colspan-2/rowspan-2 anchor's own origin is (0,0) (== its declared
    /// index, nothing to distinguish there), and row 1's only declared cell ("f", declared index 0) sits at
    /// PHYSICAL column 2 because the rowspan descending from row 0 occupies columns 0-1 — `cellLocation` must
    /// report column 2, matching `cellRect`'s physical coordinate space (Task 3), not the declared index 0.
    func test_cellLocation_returnsAnchorOriginPhysicalColumn() {
        let box = TableBlockBox(table: topLeftMergedGrid(), mapper: AttributedStringMapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        box.recompute(); box.recompute()

        let anchorStart = box.cells[0][0].leafRegions().first!.globalStart
        let anchorLoc = box.cellLocation(containing: anchorStart)
        XCTAssertEqual(anchorLoc?.row, 0)
        XCTAssertEqual(anchorLoc?.column, 0)

        let fStart = box.cells[1][0].leafRegions().first!.globalStart   // "f": row 1's only declared cell
        let fLoc = box.cellLocation(containing: fStart)
        XCTAssertEqual(fLoc?.row, 1)
        XCTAssertEqual(fLoc?.column, 2, "\"f\" sits at PHYSICAL column 2 (declared index 0) — the rowspan " +
                       "from row 0 occupies physical columns 0-1")
    }

    /// `cellTextStart(row:column:)` at a slot COVERED by a spanning anchor must return the ANCHOR's own text
    /// start (never nil, never a neighboring cell's start) — the inverse query to `cellRect`'s covered-slot
    /// resolution, over the SAME topLeftMergedGrid anchor.
    func test_cellTextStart_coveredSlotResolvesToAnchor() {
        let box = TableBlockBox(table: topLeftMergedGrid(), mapper: AttributedStringMapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        box.recompute(); box.recompute()
        let anchorStart = box.cells[0][0].leafRegions().first!.globalStart

        XCTAssertEqual(box.cellTextStart(row: 0, column: 0), anchorStart, "the anchor's own origin slot")
        XCTAssertEqual(box.cellTextStart(row: 0, column: 1), anchorStart, "covered slot resolves to the anchor")
        XCTAssertEqual(box.cellTextStart(row: 1, column: 0), anchorStart, "covered slot resolves to the anchor")
        XCTAssertEqual(box.cellTextStart(row: 1, column: 1), anchorStart, "covered slot resolves to the anchor")
    }

    /// Dense parity: for a table with NO spans, `cellLocation`/`cellTextStart`/`closestPosition` must behave
    /// exactly as before the span-aware rewrite — physical coordinates equal declared indices everywhere.
    func test_denseTable_cellLocationTextStartAndClosestPosition_matchDeclaredIndex() {
        let dense = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B")]),
                   Row(id: BlockID("r1"), cells: [cell("c", "C"), cell("d", "D")])])
        let box = TableBlockBox(table: dense, mapper: AttributedStringMapper(), width: 320)
        box.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        box.recompute(); box.recompute()

        for r in 0..<box.rowCount {
            for c in 0..<box.columnCount {
                let start = box.cells[r][c].leafRegions().first!.globalStart
                let loc = box.cellLocation(containing: start)
                XCTAssertEqual(loc?.row, r, "dense (\(r),\(c)): cellLocation row unchanged")
                XCTAssertEqual(loc?.column, c, "dense (\(r),\(c)): cellLocation column unchanged")
                XCTAssertEqual(box.cellTextStart(row: r, column: c), start, "dense (\(r),\(c)): cellTextStart unchanged")

                let rect = box.cellRect(row: r, column: c)!
                let pos = box.closestPosition(toCanvasPoint: CGPoint(x: rect.midX, y: rect.midY))
                let tappedLoc = box.cellLocation(containing: pos)
                XCTAssertEqual(tappedLoc?.row, r, "dense (\(r),\(c)): a tap in the cell's own rect lands in it")
                XCTAssertEqual(tappedLoc?.column, c, "dense (\(r),\(c)): a tap in the cell's own rect lands in it")
            }
        }
    }
}
#endif
