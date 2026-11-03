#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 16.0, *)
final class TableMeasureTests: XCTestCase {
    private let mapper = AttributedStringMapper()

    private func makeTable(width: CGFloat) -> TableBlockBox {
        func cell(_ id: String, _ text: String) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
        }
        let t = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [
                Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Alpha header that is quite long and wraps"), cell("b", "Beta")]),
                Row(id: BlockID("r1"), cells: [cell("c", "Gamma"), cell("d", "Delta value here")]),
            ])
        let box = TableBlockBox(table: t, mapper: mapper, width: width)
        box.setWidth(width)   // explicit: populate columnWidths up front so the tests don't depend on init internals
        return box
    }

    // The OLD height path called box.setWidth(cellContentWidth(c)) on every cell as a side effect.
    // To expose it: lay cells out at one width, then change the table's layoutWidth (so the column
    // widths differ) WITHOUT recomputing the cells, then read height. The old code re-flowed the
    // cells to the new column width; the refactored height must leave them untouched (recompute() is
    // the sole cell-layout site).
    func test_height_doesNotMutateCellWidths() {
        let box = makeTable(width: 320)
        box.recompute()                       // cells laid out at 320-derived column widths
        box.setWidth(700)                     // columns now 700-derived; cells deliberately NOT recomputed
        let cellLayout = box.cells[0][0].boxes[0].textLayout
        let before = cellLayout.containerWidth
        _ = box.height
        XCTAssertEqual(cellLayout.containerWidth, before, accuracy: 0.001,
                       "reading height must not resize cell text layouts")
    }

    // height (refactored) equals the stateless measure at the live width.
    func test_height_equalsMeasuredAtLiveWidth() {
        let box = makeTable(width: 320)
        XCTAssertEqual(box.height, box.measuredHeight(forWidth: 320), accuracy: 0.1)
    }

    // MARK: - Phase 2b Task 2: span-aware width + row-height

    private func plainCell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }

    // A colspan-2 cell must be measured at the SPANNED (double-column) content width, not a single
    // column's width. Proven by comparing the SAME combined cell content (the merged anchor's blocks,
    // via the 2a `mergingCells` transform) at colspan 2 vs pinned back to colspan 1 — any difference in
    // measured height is attributable ONLY to the width the text wrapped at.
    func test_colspanCell_measuredAtSpannedWidth() {
        let wrappingText = "Alpha header that is quite long and wraps across many lines when narrow"
        let dense = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [plainCell("a", wrappingText), plainCell("b", "Beta")])])
        let merged = dense.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))
        XCTAssertEqual(merged.rows[0].cells[0].colspan, 2, "sanity: the transform actually merged the row")

        let width: CGFloat = 202   // forces columnWidths to clamp to [minColumnWidth, minColumnWidth] (100, 100)
        let mergedBox = TableBlockBox(table: merged, mapper: mapper, width: width)
        mergedBox.setWidth(width)
        let mergedHeight = mergedBox.measuredHeight(forWidth: width)

        // Baseline: byte-identical cell content (the merge's anchor blocks = wrappingText + "Beta",
        // concatenated), but pinned back to colspan 1 — i.e. "the same text unmerged in one column".
        var unspannedAnchor = merged.rows[0].cells[0]
        unspannedAnchor.colspan = 1
        let filler = Cell(id: BlockID("filler"), blocks: [.paragraph(ParagraphBlock(id: BlockID("fillerp"), runs: []))])
        let unspanned = TableBlock(id: BlockID("t2"), columns: merged.columns,
                                   rows: [Row(id: BlockID("r0"), cells: [unspannedAnchor, filler])])
        let unspannedBox = TableBlockBox(table: unspanned, mapper: mapper, width: width)
        unspannedBox.setWidth(width)
        let unspannedHeight = unspannedBox.measuredHeight(forWidth: width)

        XCTAssertLessThan(mergedHeight, unspannedHeight - 10,
                          "a colspan-2 cell must be measured at the spanned width, wrapping less (and " +
                          "so measuring shorter) than the identical content pinned to a single column")
    }

    // A rowspan-2 cell's content height must be DISTRIBUTED across its spanned rows, growing the LAST
    // spanned row by any deficit (mirrors V2's `maxRowHeight += delta`), NOT the first. Asserted on the
    // PER-ROW heights (`box.rowHeights` after recompute) so a change that flips the growth target to the
    // first row must fail — the total-height measure alone can't see WHERE the deficit landed.
    func test_rowspanCell_distributesHeightAcrossRows() {
        let tallText = "Alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega"
        let dense = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [
                Row(id: BlockID("r0"), cells: [plainCell("a", tallText), plainCell("b", "R0")]),
                Row(id: BlockID("r1"), cells: [plainCell("c", ""), plainCell("d", "R1")]),
            ])
        let merged = dense.mergingCells(in: TableRect(top: 0, left: 0, bottom: 1, right: 0))
        XCTAssertEqual(merged.rows[0].cells[0].rowspan, 2, "sanity: the transform actually merged the column")

        let width: CGFloat = 202
        let box = TableBlockBox(table: merged, mapper: mapper, width: width)
        box.frame = CGRect(x: 0, y: 0, width: width, height: 1000)
        // Recompute TWICE to prime the cells' live layouts: the editor's `boundingHeight(forWidth:)`
        // returns a stale (init-width) reflow on the first pass and the glyph-accurate live layout once
        // the cell has been laid out at its final width — a pre-existing editor characteristic, orthogonal
        // to the span solver. The second pass converges to the deterministic per-row heights asserted below.
        box.recompute()
        box.recompute()
        XCTAssertEqual(box.rowHeights.count, 2)

        let cols = box.columnWidths
        // The short (single-row) cells "R0" / "R1" each set their own row's BASE height; the tall
        // rowspan cell's deficit is added ON TOP of the LAST spanned row (row 1), so row 1 must end up
        // materially taller than row 0.
        let pad2 = TableBlockBox.cellVerticalPadding * 2
        let row0BaseH = box.cells[0][1].measuredHeight(forWidth: box.cellContentWidth(anchorColumn: 1, colspan: 1, in: cols)) + pad2
        let row1BaseH = box.cells[1][0].measuredHeight(forWidth: box.cellContentWidth(anchorColumn: 1, colspan: 1, in: cols)) + pad2

        // Row 0 gets ONLY its own single-row cell's height (no rowspan deficit lands here).
        XCTAssertEqual(box.rowHeights[0], row0BaseH, accuracy: 0.5,
                       "the first spanned row keeps ONLY its own short cell's height — the deficit lands on the last row")
        // Row 1 absorbs the rowspan cell's deficit → strictly taller than row 0 (and than its own base).
        XCTAssertGreaterThan(box.rowHeights[1], box.rowHeights[0] + 10,
                             "the LAST spanned row absorbs the rowspan cell's deficit (grows past the first row)")
        XCTAssertGreaterThan(box.rowHeights[1], row1BaseH + 10,
                             "row 1 grew beyond its own short cell's base height")

        // The two spanned rows together (+ interior border) must still fit the rowspan cell's content.
        let spannedContentH = box.cells[0][0].measuredHeight(forWidth: box.cellContentWidth(anchorColumn: 0, colspan: 1, in: cols)) + pad2
        XCTAssertGreaterThanOrEqual(box.rowHeights[0] + box.rowHeights[1] + TableBlockBox.border, spannedContentH - 0.5,
                                    "the spanned rows together fit the rowspan cell's content")
    }

    // TWO rowspan cells over the SAME rows in different columns: each spanned region must fit its own
    // cell's content, and the map stays well-formed.
    func test_twoOverlappingRowspanCells_bothSatisfied() {
        let tallA = "Aaa bbb ccc ddd eee fff ggg hhh iii jjj kkk lll mmm nnn ooo ppp qqq rrr sss ttt"
        let tallB = "Zzz yyy xxx www vvv uuu ttt sss rrr qqq ppp ooo nnn mmm lll kkk jjj iii hhh ggg fff eee ddd ccc"
        // 3 columns × 2 rows. Merge col0 rows0-1 (tallA), merge col1 rows0-1 (tallB); col2 stays dense.
        let dense = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [
                Row(id: BlockID("r0"), cells: [plainCell("a", tallA), plainCell("b", tallB), plainCell("e", "E0")]),
                Row(id: BlockID("r1"), cells: [plainCell("c", ""), plainCell("d", ""), plainCell("f", "F1")]),
            ])
        var merged = dense.mergingCells(in: TableRect(top: 0, left: 0, bottom: 1, right: 0))
        merged = merged.mergingCells(in: TableRect(top: 0, left: 1, bottom: 1, right: 1))
        XCTAssertTrue(TableMap(merged).isWellFormed, "two disjoint rowspan merges keep the table well-formed")

        let width: CGFloat = 360
        let box = TableBlockBox(table: merged, mapper: mapper, width: width)
        box.frame = CGRect(x: 0, y: 0, width: width, height: 2000)
        box.recompute(); box.recompute()   // prime live layouts (see the rowspan test's note)
        XCTAssertEqual(box.rowHeights.count, 2)

        let cols = box.columnWidths
        let pad2 = TableBlockBox.cellVerticalPadding * 2
        let spannedTotal = box.rowHeights[0] + box.rowHeights[1] + TableBlockBox.border

        // Locate each rowspan anchor's stack via the map and assert the spanned region fits its content.
        let m = TableMap(merged)
        var rowspanCount = 0
        for anchor in m.anchors where anchor.rowspan > 1 {
            // Locate the declaring cell by id in the box's parallel arrays.
            var found: (Int, Int)?
            for r in 0..<box.cellIDs.count {
                if let c = box.cellIDs[r].firstIndex(of: anchor.cellID) { found = (r, c); break }
            }
            guard let (r, c) = found else { return XCTFail("anchor not found") }
            rowspanCount += 1
            let contentH = box.cells[r][c].measuredHeight(forWidth: box.cellContentWidth(anchorColumn: anchor.column, colspan: anchor.colspan, in: cols)) + pad2
            XCTAssertGreaterThanOrEqual(spannedTotal, contentH - 0.5,
                                        "spanned rows must fit rowspan cell \(anchor.cellID.rawValue)'s content")
        }
        XCTAssertEqual(rowspanCount, 2, "both column merges produced a rowspan cell")
    }

    // An INTERIOR span row with ZERO single-row anchors (a rowspan from above covers the whole row):
    // the row must not under-height, and the table total must fit the rowspan cell.
    func test_interiorRowWithNoSingleRowAnchors_doesNotUnderHeight() {
        let tall = "One two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen"
        // 1 column × 2 rows, merged into a single rowspan-2 cell → row 1 has NO declared single-row cell.
        let dense = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 200)],
            rows: [
                Row(id: BlockID("r0"), cells: [plainCell("a", tall)]),
                Row(id: BlockID("r1"), cells: [plainCell("b", "")]),
            ])
        let merged = dense.mergingCells(in: TableRect(top: 0, left: 0, bottom: 1, right: 0))
        XCTAssertEqual(merged.rows[0].cells[0].rowspan, 2)
        XCTAssertEqual(merged.rows[1].cells.count, 0, "row 1 declares no cells — wholly covered by the rowspan")

        let width: CGFloat = 232
        let box = TableBlockBox(table: merged, mapper: mapper, width: width)
        box.frame = CGRect(x: 0, y: 0, width: width, height: 2000)
        box.recompute(); box.recompute()   // prime live layouts (see the rowspan test's note)
        XCTAssertEqual(box.rowHeights.count, 2)

        let cols = box.columnWidths
        let pad2 = TableBlockBox.cellVerticalPadding * 2
        let contentH = box.cells[0][0].measuredHeight(forWidth: box.cellContentWidth(anchorColumn: 0, colspan: 1, in: cols)) + pad2
        // Row 0 starts at 0 (no single-row anchor declared IN row 0 either — the only cell is the
        // rowspan anchor), row 1 starts at 0; the rowspan deficit grows the LAST row to fit all content.
        XCTAssertGreaterThanOrEqual(box.rowHeights[0] + box.rowHeights[1] + TableBlockBox.border, contentH - 0.5,
                                    "the interior/covered row must not under-height the rowspan cell's content")
        // The total table height reflects that content. The rowspan cell's vertical extent is
        // `h0 + interiorBorder + h1 == contentH` (the interior divider is PART of the merged cell), so the
        // table height is one top border + contentH + one bottom border + bottomSpacing == 2 borders +
        // contentH + bottomSpacing (the interior border is already counted inside contentH's span).
        let total = box.measuredHeight(forWidth: width)
        XCTAssertGreaterThanOrEqual(total, TableBlockBox.border * 2 + contentH + TableBlockBox.bottomSpacing - 0.5)
    }

    // A fully dense table (colspan == rowspan == 1 everywhere) must measure EXACTLY as before: per row,
    // the max cell content height (clamped to the row minimum), summed with borders/bottomSpacing — the
    // span-aware solver must collapse to this when there is nothing to span.
    func test_dense_measure_unchanged() {
        let box = makeTable(width: 320)
        let cols = box.solveColumnWidths(forWidth: 320)
        var expected: CGFloat = TableBlockBox.border
        for r in 0..<box.rowCount {
            var maxH: CGFloat = 0
            for c in 0..<box.cells[r].count {
                let contentWidth = box.cellContentWidth(anchorColumn: c, colspan: 1, in: cols)
                maxH = max(maxH, box.cells[r][c].measuredHeight(forWidth: contentWidth))
            }
            expected += max(maxH + TableBlockBox.cellVerticalPadding * 2, box.rowMinHeights[r]) + TableBlockBox.border
        }
        expected += TableBlockBox.bottomSpacing
        XCTAssertEqual(box.measuredHeight(forWidth: 320), expected, accuracy: 0.01,
                       "a dense table's measured height must be byte-identical to the pre-2b formula")
    }
}
#endif
