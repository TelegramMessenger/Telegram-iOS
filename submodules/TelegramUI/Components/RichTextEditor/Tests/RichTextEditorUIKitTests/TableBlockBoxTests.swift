#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class TableBlockBoxTests: XCTestCase {
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: text)]))])
    }
    private func table2x2() -> TableBlock {
        TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
                   rows: [Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B")]),
                          Row(id: BlockID("r1"), cells: [cell("c", "C"), cell("d", "D")])])
    }

    func test_mixedDoc_spansMatchCorePositionModel() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(table2x2()),
            .paragraph(ParagraphBlock(id: BlockID("bot"), runs: [TextRun(text: "Bot")])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let doc = Document(blocks: v.currentBlocks())
        let tree = DocumentTree.build(from: doc)
        XCTAssertEqual(v.documentSizeValue, DocumentTree.documentSize(doc))
        // Each cell's paragraph text node global start matches Core.
        for id in ["ap", "bp", "cp", "dp"] {
            let core = PositionResolver.globalPosition(of: .paragraph(BlockID(id)), offset: 0, in: tree)
            let region = v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }
            XCTAssertNotNil(region)
            XCTAssertEqual(region?.globalStart, core, "cell \(id)")
        }
    }

    // Dense parity (Phase 2b Task 3): a fully dense table's cellRect must be byte-identical to the pre-2b
    // single-slot formula (Σ preceding widths/heights + border, this cell's own width/height) — the
    // anchor-resolution rewrite collapses to exactly this when every cell is colspan==rowspan==1.
    func test_cellRect_denseTable_matchesPreexistingSingleSlotFormula() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(table2x2())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        for row in 0..<t.rowCount {
            for col in 0..<t.columnCount {
                var y = t.frame.minY + TableBlockBox.border
                for r in 0..<row { y += t.rowHeights[r] + TableBlockBox.border }
                var x = t.frame.minX + TableBlockBox.border
                for c in 0..<col { x += t.columnWidths[c] + TableBlockBox.border }
                let expected = CGRect(x: x, y: y, width: t.columnWidths[col], height: t.rowHeights[row])
                XCTAssertEqual(t.cellRect(row: row, column: col), expected,
                               "dense cellRect (\(row),\(col)) matches the pre-2b single-slot rect")
            }
        }
    }

    func test_tableRoundTripsThroughCurrentBlocks() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(table2x2())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        guard case .table(let out) = v.currentBlocks()[0] else { return XCTFail("expected table") }
        XCTAssertEqual(out.rowCount, 2); XCTAssertEqual(out.columnCount, 2)
        XCTAssertEqual(out.rows[1].cells[1].blocks.count, 1)
    }

    func test_tableRendersNonBlank() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(table2x2())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: v.bounds).image { _ in v.drawHierarchy(in: v.bounds, afterScreenUpdates: true) }
        XCTAssertNotNil(image.cgImage)
    }

    // An EMPTY cell reserves one line of its font's height (so its row doesn't collapse to the insets),
    // matching a single-line filled cell in the same row.
    func test_emptyCellReservesLineHeight() {
        let v = DocumentCanvasView()
        let empty = Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: []))])
        let filled = Cell(id: BlockID("b"), blocks: [.paragraph(ParagraphBlock(id: BlockID("bp"), runs: [TextRun(text: "Beta")]))])
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [empty, filled])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 300); v.layoutIfNeeded()
        let table = v.boxes.first as! TableBlockBox
        let emptyBox = table.cells[0][0].boxes[0]
        let filledBox = table.cells[0][1].boxes[0]
        XCTAssertEqual(emptyBox.height, filledBox.height, accuracy: 1.0,
                       "an empty cell reserves a real line, matching a single-line filled cell")
        // The cell box carries no block inset (vertical padding is a cell metric applied at the row
        // level, not on the box), so the box is exactly one V2 line at the CELL font size (15pt).
        let cellSheet = StyleSheet.tableCells
        let cellLine = RichTextRenderMetrics.textHeight(cellSheet.font(for: .body, attributes: .plain),
                                                       factor: cellSheet.metrics.body.lineSpacingFactor,
                                                       lineCount: 1)
        XCTAssertEqual(emptyBox.height, cellLine, accuracy: 0.5, "not collapsed — reserves a real line")
    }

    // A wholly-empty row keeps a real line's height (≈ a filled row), not just topInset+bottomInset.
    func test_emptyRowDoesNotCollapse() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [
                Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")]),
                Row(id: BlockID("r1"), cells: [
                    Cell(id: BlockID("c"), blocks: [.paragraph(ParagraphBlock(id: BlockID("cp"), runs: []))]),
                    Cell(id: BlockID("d"), blocks: [.paragraph(ParagraphBlock(id: BlockID("dp"), runs: []))]),
                ]),
            ]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        // The empty row's cells lay out at the same height as the filled row's cells.
        let table = v.boxes.first as! TableBlockBox
        let filledRowBox = table.cells[0][0].boxes[0]
        let emptyRowBox = table.cells[1][0].boxes[0]
        XCTAssertEqual(emptyRowBox.height, filledRowBox.height, accuracy: 1.0,
                       "an empty row keeps a real line's height")
    }
}

extension TableBlockBoxTests {
    private func headerTable() -> TableBlock {
        TableBlock(id: BlockID("t"),
                   columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                   rows: [
                       Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Name"), cell("b", "Role")]),
                       Row(id: BlockID("r1"), cells: [cell("c", "Ada"), cell("d", "Eng")]),
                   ])
    }
    private func box(_ v: DocumentCanvasView) -> TableBlockBox { v.boxes.first as! TableBlockBox }
    private func cellFont(_ t: TableBlockBox, _ r: Int, _ c: Int) -> UIFont {
        let b = t.cells[r][c].boxes[0] as! BlockBox
        return b.layout.attributedString.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
    }
    private func cellAlignment(_ t: TableBlockBox, _ r: Int, _ c: Int) -> NSTextAlignment {
        let b = t.cells[r][c].boxes[0] as! BlockBox
        let ps = b.layout.attributedString.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        return ps?.alignment ?? .natural
    }

    func test_firstRowRendersBold_otherRowsDoNot() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(headerTable())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let t = box(v)
        // The header row (row 0) renders bold in every column; body rows do not.
        XCTAssertTrue(cellFont(t, 0, 0).fontDescriptor.symbolicTraits.contains(.traitBold), "header row col 0 bold")
        XCTAssertTrue(cellFont(t, 0, 1).fontDescriptor.symbolicTraits.contains(.traitBold), "header row col 1 bold")
        XCTAssertFalse(cellFont(t, 1, 0).fontDescriptor.symbolicTraits.contains(.traitBold), "body row col 0 not bold")
        XCTAssertFalse(cellFont(t, 1, 1).fontDescriptor.symbolicTraits.contains(.traitBold), "body row col 1 not bold")
    }

    func test_perCellHeader_flagsFirstRowCells_withTranslucentTint() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(headerTable())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let t = box(v)
        XCTAssertTrue(t.isHeaderCell(0, 0)); XCTAssertTrue(t.isHeaderCell(0, 1))
        XCTAssertFalse(t.isHeaderCell(1, 0))
        var alpha: CGFloat = 1
        RichTextEditorTheme.default.tableHeaderBackground.getWhite(nil, alpha: &alpha)
        XCTAssertLessThan(alpha, 1)
    }

    func test_headerBold_isStrippedFromModelOnExtraction() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(headerTable())], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        guard case .table(let out) = v.currentBlocks()[0] else { return XCTFail("expected table") }
        // Header cell runs are NOT bold in the model (render-only; markdown-clean).
        guard case .paragraph(let p) = out.rows[0].cells[0].blocks[0] else { return XCTFail() }
        XCTAssertFalse(p.runs.first?.attributes.bold ?? true)
    }

    // Alignment is now a PER-CELL render override (`Cell.horizontalAlignment`), not a per-column one:
    // each cell renders (and round-trips) its own alignment, independent of its column or its neighbors.
    func test_cellAlignment_rendersAndRoundTripsClean() {
        let v = DocumentCanvasView()
        var c10 = cell("c", "Ada")  // row 1, column 0
        c10.horizontalAlignment = .left
        var c11 = cell("d", "Eng")  // row 1, column 1
        c11.horizontalAlignment = .center
        let table = TableBlock(id: BlockID("t"),
                               columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                               rows: [
                                   Row(id: BlockID("r0"), cells: [cell("a", "Name"), cell("b", "Role")]),
                                   Row(id: BlockID("r1"), cells: [c10, c11]),
                               ])
        v.setBlocks([.table(table)], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let t = box(v)
        XCTAssertEqual(cellAlignment(t, 1, 1), .center, "cell (1,1) renders centered per its own alignment")
        XCTAssertEqual(cellAlignment(t, 1, 0), .left, "cell (1,0) renders left per its own alignment")
        guard case .table(let out) = v.currentBlocks()[0] else { return XCTFail("expected table") }
        XCTAssertEqual(out.rows[1].cells[1].horizontalAlignment, .center, "cell (1,1) alignment round-trips")
        XCTAssertEqual(out.rows[1].cells[0].horizontalAlignment, .left, "cell (1,0) alignment round-trips")
    }

    // A table whose columns all scale to >= minColumnWidth fits: scale-to-fit, no overflow (today's behavior).
    func test_widthPolicy_fittingTable_scalesToFit_noOverflow() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 120), ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B"), cell("c", "C")])]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        XCTAssertEqual(t.gridWidth, t.frame.width, accuracy: 0.5, "fitting table grid == content strip")
        XCTAssertEqual(t.blockViewFrame.width, t.gridWidth, accuracy: 0.5, "view frame == grid width when it fits")
    }

    // A table with more columns than fit at minColumnWidth overflows and keeps each column at the minimum.
    func test_widthPolicy_wideTable_overflows_atMinColumnWidth() {
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "C\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        XCTAssertTrue(t.columnWidths.allSatisfy { $0 >= TableBlockBox.minColumnWidth - 0.01 },
                      "every column is at least the minimum")
        XCTAssertGreaterThan(t.gridWidth, t.frame.width, "wide table overflows the content strip")
        XCTAssertEqual(t.blockViewFrame.width, t.frame.width, accuracy: 0.5,
                       "view frame is the visible clipping window, not the full grid")
    }

    // A table that scales to exactly minColumnWidth per column still takes the fit branch (>= is inclusive).
    func test_widthPolicy_exactBoundary_noOverflow() {
        // n=3, border=1: avail = layoutWidth - 4; for fit == 100 we need avail = 300 → layoutWidth = 304.
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a","A"), cell("b","B"), cell("c","C")])]))], width: 304 + 2*16)
        v.frame = CGRect(x: 0, y: 0, width: 304 + 2*16, height: 200); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        XCTAssertEqual(t.gridWidth, t.frame.width, accuracy: 0.5, "table at exact min still fits — no scroll")
    }

    // A wide, scrolled table: caretRect for a cell shifts left by the offset; a tap at the shifted
    // location still resolves to the same global position (round-trip through the seam).
    func test_seam_caretAndHitTest_foldInContentOffset() {
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "Cell\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let pos = t.cellTextStart(row: 0, column: 4)!
        let unscrolled = v.caretRect(for: DocumentTextPosition(pos))
        t.contentOffsetX = 150
        let scrolled = v.caretRect(for: DocumentTextPosition(pos))
        XCTAssertEqual(scrolled.minX, unscrolled.minX - 150, accuracy: 0.5, "caret shifts left by the offset")
        XCTAssertEqual(scrolled.minY, unscrolled.minY, accuracy: 0.5, "y unchanged by horizontal scroll")
        let hit = v.closestGlobalPosition(to: CGPoint(x: scrolled.midX, y: scrolled.midY))
        XCTAssertEqual(hit, pos, "hit-test folds the offset back in")
    }

    func test_seam_selectionRects_foldInContentOffset() {
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "Cell\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let from = t.cellTextStart(row: 0, column: 4)!
        let rectsUnscrolled = v.selectionRects(globalFrom: from, globalTo: from + 2)
        t.contentOffsetX = 150
        let rectsScrolled = v.selectionRects(globalFrom: from, globalTo: from + 2)
        XCTAssertEqual(rectsUnscrolled.count, rectsScrolled.count)
        XCTAssertFalse(rectsScrolled.isEmpty)
        XCTAssertEqual(rectsScrolled[0].minX, rectsUnscrolled[0].minX - 150, accuracy: 0.5)
    }

    func test_autoScrollToCaret_revealsOffscreenCell() {
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "Cell\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let tv = v.blockViews[BlockID("t")] as! TableBackingView
        tv.layoutIfNeeded()
        XCTAssertEqual(tv.scroll.contentOffset.x, 0, accuracy: 0.5)
        let pos = t.cellTextStart(row: 0, column: 5)!
        v.setCaret(global: pos)
        tv.layoutIfNeeded()
        XCTAssertGreaterThan(tv.scroll.contentOffset.x, 0, "the last column is scrolled into view")
        let cellRect = t.cellRect(row: 0, column: 5)!
        let contentX = cellRect.minX - t.frame.minX
        XCTAssertLessThanOrEqual(contentX, tv.scroll.contentOffset.x + tv.bounds.width + 0.5)
        XCTAssertGreaterThanOrEqual(contentX + cellRect.width, tv.scroll.contentOffset.x - 0.5)
    }

    func test_dragAutoScroll_advancesOffsetTowardRightEdge() {
        let v = DocumentCanvasView()
        let cols = (0..<6).map { _ in ColumnSpec(width: 100) }
        let cells = (0..<6).map { i in cell("c\(i)", "Cell\(i)") }
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: cols,
            rows: [Row(id: BlockID("r0"), cells: cells)]))], width: 390)
        v.frame = CGRect(x: 0, y: 0, width: 390, height: 300); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let tv = v.blockViews[BlockID("t")] as! TableBackingView
        tv.layoutIfNeeded()
        // Non-collapsed selection with the head inside the table.
        v.setSelectionForTesting(anchor: t.cellTextStart(row: 0, column: 0)!, head: t.cellTextStart(row: 0, column: 1)!)
        let before = tv.scroll.contentOffset.x
        let rightEdge = CGPoint(x: t.frame.minX + tv.bounds.width - 4, y: t.frame.minY + 10)
        v.updateDragAutoScroll(point: rightEdge, headInTable: true)
        for _ in 0..<5 { v.dragAutoScrollTick() }
        XCTAssertGreaterThan(tv.scroll.contentOffset.x, before, "auto-scroll advances toward the right edge")
        v.stopDragAutoScroll()
        XCTAssertLessThanOrEqual(tv.scroll.contentOffset.x, tv.scroll.contentSize.width - tv.bounds.width + 0.5, "clamped to max")
    }

    // MARK: - Cell base font (15pt, vs the document body's 17pt)

    /// The font of the first character of the leaf region with `ref`, or nil if empty/absent.
    private func regionFont(_ v: DocumentCanvasView, _ ref: TextNodeRef) -> UIFont? {
        guard let r = v.allLeafRegions().first(where: { $0.ref == ref }), r.layout.attributedString.length > 0
        else { return nil }
        return r.layout.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
    }

    func test_cellBodyRendersAt15pt_documentBodyStays17() {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("top"), runs: [TextRun(text: "Top")])),
            .table(table2x2()),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        XCTAssertEqual(regionFont(v, .paragraph(BlockID("ap")))?.pointSize ?? 0, 15, accuracy: 0.5, "cell body is 15pt")
        XCTAssertEqual(regionFont(v, .paragraph(BlockID("top")))?.pointSize ?? 0, 17, accuracy: 0.5, "document body stays 17pt")
        // The pinned model size matches what was rendered.
        guard case .table(let out) = v.currentBlocks()[1], case .paragraph(let p) = out.rows[0].cells[0].blocks[0]
        else { return XCTFail("expected a table with a paragraph cell") }
        XCTAssertEqual(p.runs.first?.attributes.fontSize, 15, "read-back pins the cell's 15pt size")
    }

    func test_cellText_verticalPaddingIsCellMetric_notDocumentInset() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
            // Row 1 (non-header) avoids the header bold; "Ag" carries ascender + descender.
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "Ag"), cell("b", "Bg")]),
                   Row(id: BlockID("r1"), cells: [cell("c", "Ag"), cell("d", "Bg")])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let box = t.cells[1][0].boxes[0] as! BlockBox
        // The cell stack carries NO document inter-block inset; the vertical padding is a cell metric.
        XCTAssertEqual(box.topInset, 0, "a cell box carries no document inter-block top inset")
        XCTAssertEqual(box.bottomInset, 0, "a cell box carries no document inter-block bottom inset")
        // Text sits exactly `cellVerticalPadding` below the cell top and above the bottom (symmetric).
        let cr = t.cellRect(row: 1, column: 0)!
        let topGap = box.textOrigin.y - cr.minY
        // Against the V2-CORRECTED text height: the raw pinned line box overhangs the last baseline by a
        // full line box, so measuring from it reads the padding ~2pt short even though the glyphs sit
        // exactly `cellVerticalPadding` above the cell bottom.
        let bottomGap = cr.maxY - (box.textOrigin.y + box.layout.correctedBoundingHeight)
        XCTAssertEqual(topGap, TableBlockBox.cellVerticalPadding, accuracy: 0.5, "top gap == cellVerticalPadding")
        XCTAssertEqual(bottomGap, TableBlockBox.cellVerticalPadding, accuracy: 0.5, "bottom gap == cellVerticalPadding")
    }

    func test_compactTable_halvesCellPadding() {
        func makeView(compact: Bool) -> DocumentCanvasView {
            let v = DocumentCanvasView()
            v.setBlocks([.table(TableBlock(id: BlockID("t"),
                columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Ag"), cell("b", "Bg")]),
                       Row(id: BlockID("r1"), cells: [cell("c", "Ag"), cell("d", "Bg")])],
                compact: compact))], width: 320)
            v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
            return v
        }

        let normal = makeView(compact: false).boxes[0] as! TableBlockBox
        let compact = makeView(compact: true).boxes[0] as! TableBlockBox

        XCTAssertEqual(compact.cellPadding, TableBlockBox.cellPadding / 2, accuracy: 0.01)
        XCTAssertEqual(compact.cellVerticalPadding, TableBlockBox.cellVerticalPadding / 2, accuracy: 0.01)
        XCTAssertEqual(normal.cellPadding, TableBlockBox.cellPadding, accuracy: 0.01)

        // The halved padding must reach the laid-out geometry, not just the property.
        let normalBox = normal.cells[1][0].boxes[0] as! BlockBox
        let compactBox = compact.cells[1][0].boxes[0] as! BlockBox
        let normalTopGap = normalBox.textOrigin.y - normal.cellRect(row: 1, column: 0)!.minY
        let compactTopGap = compactBox.textOrigin.y - compact.cellRect(row: 1, column: 0)!.minY
        XCTAssertEqual(normalTopGap, TableBlockBox.cellVerticalPadding, accuracy: 0.5)
        XCTAssertEqual(compactTopGap, TableBlockBox.cellVerticalPadding / 2, accuracy: 0.5)
        XCTAssertLessThan(compact.frame.height, normal.frame.height, "a compact table is shorter")

        // `compact` must survive the model read-back.
        guard case .table(let out) = compact.currentBlock() else { return XCTFail("expected a table") }
        XCTAssertTrue(out.compact)
    }

    func test_typingFirstCharInEmptyCell_is15pt() {
        let v = DocumentCanvasView()
        let empty = Cell(id: BlockID("a"), blocks: [.paragraph(ParagraphBlock(id: BlockID("ap"), runs: []))])
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
            rows: [Row(id: BlockID("r0"), cells: [empty, cell("b", "B")])]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 400); v.layoutIfNeeded()
        let region = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(region.globalStart),
                                                DocumentTextPosition(region.globalStart))
        v.insertText("X")
        XCTAssertEqual(regionFont(v, .paragraph(BlockID("ap")))?.pointSize ?? 0, 15, accuracy: 0.5,
                       "the first character typed into an empty cell is 15pt, not the document's 17pt")
    }

    func test_splitInCell_thenTypeInNewLine_stays15pt() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 160), ColumnSpec(width: 160)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])]))], width: 360)
        v.frame = CGRect(x: 0, y: 0, width: 360, height: 400); v.layoutIfNeeded()
        let cellA = v.allLeafRegions().first { $0.ref == .paragraph(BlockID("ap")) }!
        // Caret at the end of "Alpha" → Enter splits the cell, leaving a new EMPTY lower paragraph.
        v.selectedTextRange = DocumentTextRange(DocumentTextPosition(cellA.globalStart + 5),
                                                DocumentTextPosition(cellA.globalStart + 5))
        v.insertText("\n")
        v.insertText("Y")
        let typed = v.allLeafRegions().first { $0.layout.attributedString.string == "Y" }
        XCTAssertNotNil(typed, "the new in-cell line holds the typed character")
        let font = typed?.layout.attributedString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(font?.pointSize ?? 0, 15, accuracy: 0.5,
                       "a cell line created by an in-cell split inherits the cell's 15pt base font")
    }

    // MARK: - Borders

    /// A table is bordered by default — every table authored before the flag existed drew its grid, and
    /// the forward converter hard-coded `bordered: true`.
    func test_table_isBorderedByDefault() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(table2x2())], width: 320)
        XCTAssertTrue(box(v).isBordered)
        XCTAssertEqual(box(v).borderWidth, TableBlockBox.border)
    }

    /// Hiding borders is NOT just a paint toggle: the border WIDTH goes to zero, so the cells butt
    /// together — mirroring V2's `bordered ? v2TableBorderWidth : 0.0`. Without this the editor's table
    /// would be wider than the one in the sent message by one border per boundary.
    func test_unborderedTable_collapsesTheCellGaps() {
        let v = DocumentCanvasView()
        var model = table2x2()
        model.bordered = false
        v.setBlocks([.table(model)], width: 320)
        let t = box(v)
        XCTAssertFalse(t.isBordered)
        XCTAssertEqual(t.borderWidth, 0.0)

        // Two columns side by side: with no border between them the second starts exactly where the
        // first ends.
        guard let left = t.cellRect(row: 0, column: 0), let right = t.cellRect(row: 0, column: 1) else {
            return XCTFail("expected two cell rects")
        }
        XCTAssertEqual(right.minX, left.maxX, accuracy: 0.01, "an unbordered table has no gap between cells")
    }

    /// And the bordered case still leaves exactly one border between them.
    func test_borderedTable_keepsOneBorderBetweenCells() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(table2x2())], width: 320)
        let t = box(v)
        guard let left = t.cellRect(row: 0, column: 0), let right = t.cellRect(row: 0, column: 1) else {
            return XCTFail("expected two cell rects")
        }
        XCTAssertEqual(right.minX - left.maxX, TableBlockBox.border, accuracy: 0.01)
    }

    /// The flag round-trips through the canvas, so a toggle survives read-back and reaches the wire.
    func test_borderedFlag_roundTripsThroughTheCanvas() {
        let v = DocumentCanvasView()
        var model = table2x2()
        model.bordered = false
        v.setBlocks([.table(model)], width: 320)
        guard case let .table(restored) = v.currentBlocks().first else {
            return XCTFail("expected a table")
        }
        XCTAssertFalse(restored.bordered)
    }

    /// The toggle flips it as one undo step and re-lays-out.
    func test_toggleTableBordered_flipsTheFlag() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(table2x2())], width: 320)
        // `activeTable()` needs a caret in a CELL; `cellTextStart` is how the table tests express that.
        guard let caret = box(v).cellTextStart(row: 0, column: 0) else {
            return XCTFail("expected a first-cell text start")
        }
        v.setSelectionForTesting(anchor: caret, head: caret)
        v.toggleTableBordered()
        guard case let .table(restored) = v.currentBlocks().first else {
            return XCTFail("expected a table")
        }
        XCTAssertFalse(restored.bordered)
        XCTAssertEqual(box(v).borderWidth, 0.0)
    }
}
#endif
