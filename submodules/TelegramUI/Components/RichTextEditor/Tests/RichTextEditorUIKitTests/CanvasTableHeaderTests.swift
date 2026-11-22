#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasTableHeaderTests: XCTestCase {
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    func test_headerRowFlagAndRendersNonBlank() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "Name"), cell("b", "Role")]),
                   Row(id: BlockID("r1"), cells: [cell("c", "Ada"), cell("d", "Eng")])]))], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 400); v.layoutIfNeeded()
        let t = v.boxes.first as! TableBlockBox
        XCTAssertTrue(t.isHeaderRow(0))
        XCTAssertFalse(t.isHeaderRow(1))
        let image = UIGraphicsImageRenderer(bounds: v.bounds).image { _ in v.drawHierarchy(in: v.bounds, afterScreenUpdates: true) }
        XCTAssertNotNil(image.cgImage)
    }

    func test_firstRowBold_othersNot_modelStaysClean() {
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a","Name"), cell("b","Role")]),
                   Row(id: BlockID("r1"), cells: [cell("c","Ada"), cell("d","Eng")])]))], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 400); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        func bold(_ r: Int, _ c: Int) -> Bool {
            let s = t.cells[r][c].boxes[0] as! BlockBox
            let f = s.layout.attributedString.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
            return f.fontDescriptor.symbolicTraits.contains(.traitBold)
        }
        XCTAssertTrue(bold(0, 0))    // header row → bold (render-only)
        XCTAssertTrue(bold(0, 1))    // header row → bold
        XCTAssertFalse(bold(1, 0))   // body row → not bold
        XCTAssertFalse(bold(1, 1))   // body row → not bold
        // model stays clean: no synthetic bold persisted in the header row
        guard case .table(let tb) = t.currentBlock(),
              case .paragraph(let p) = tb.rows[0].cells[0].blocks[0] else { return XCTFail() }
        XCTAssertFalse(p.runs[0].attributes.bold)
    }

    func test_perCellHeader_partialRow_fillsAndBoldsOnlyHeaderCells() {
        func hcell(_ id: String, _ t: String) -> Cell {
            var c = cell(id, t); c.isHeader = true; return c
        }
        let v = DocumentCanvasView()
        // Row 0: cell (0,0) header, cell (0,1) NOT header — a partial-header row (impossible under the old model).
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
            rows: [Row(id: BlockID("r0"), cells: [hcell("a", "H"), cell("b", "x")]),
                   Row(id: BlockID("r1"), cells: [cell("c", "y"), cell("d", "z")])]))], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 400); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        XCTAssertTrue(t.isHeaderCell(0, 0))
        XCTAssertFalse(t.isHeaderCell(0, 1))
        XCTAssertFalse(t.isHeaderRow(0), "a partially-header row is not a header row")
        func bold(_ r: Int, _ c: Int) -> Bool {
            let s = t.cells[r][c].boxes[0] as! BlockBox
            let f = s.layout.attributedString.attribute(.font, at: 0, effectiveRange: nil) as! UIFont
            return f.fontDescriptor.symbolicTraits.contains(.traitBold)
        }
        XCTAssertTrue(bold(0, 0))   // header cell → bold
        XCTAssertFalse(bold(0, 1))  // non-header cell → not bold
        // model round-trips the per-cell flag and stays clean (no synthetic bold persisted)
        guard case .table(let tb) = t.currentBlock() else { return XCTFail() }
        XCTAssertTrue(tb.rows[0].cells[0].isHeader)
        XCTAssertFalse(tb.rows[0].cells[1].isHeader)
        if case .paragraph(let p) = tb.rows[0].cells[0].blocks[0] { XCTAssertFalse(p.runs[0].attributes.bold) }
    }

    /// RGBA8 (premultiplied-last, deviceRGB) sample at image point (x, y). Same pixel-buffer mechanism as
    /// `ImageSelectionHighlightTests.pixels(of:)`, narrowed to a single-point read.
    private func sample(_ image: CGImage, x: Int, y: Int) -> (r: Int, g: Int, b: Int, a: Int) {
        let w = image.width, h = image.height
        var px = [UInt8](repeating: 0, count: w * h * 4)
        let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let i = (min(max(y, 0), h - 1) * w + min(max(x, 0), w - 1)) * 4
        return (Int(px[i]), Int(px[i + 1]), Int(px[i + 2]), Int(px[i + 3]))
    }

    // Rendering-level coverage of `TableBlockBox.draw()`'s per-cell fill pass (flags + bold alone can't catch
    // an index/precedence/accumulator bug in the fill). Renders the table's own draw() into an image at canvas
    // coords (scale 1, exactly what TableContentView.drawBlockContents drives) and pixel-samples three cells:
    // a header cell (tint), a plain body cell (no fill), and a header cell with an explicit background (bg wins).
    func test_draw_perCellFillPass_headerTint_bodyClear_explicitBackgroundWins() {
        func hcell(_ id: String, _ t: String) -> Cell { var c = cell(id, t); c.isHeader = true; return c }
        var redHeader = cell("b", "R")             // header AND an explicit opaque red background
        redHeader.isHeader = true
        redHeader.background = RGBAColor(red: 1, green: 0, blue: 0, alpha: 1)
        let v = DocumentCanvasView()
        v.setBlocks([.table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
            rows: [Row(id: BlockID("r0"), cells: [hcell("a", "H"), redHeader]),
                   Row(id: BlockID("r1"), cells: [cell("c", "y"), cell("d", "z")])]))], width: 340)
        v.frame = CGRect(x: 0, y: 0, width: 340, height: 400); v.layoutIfNeeded()
        let t = v.boxes[0] as! TableBlockBox
        let fmt = UIGraphicsImageRendererFormat(); fmt.opaque = false; fmt.scale = 1
        let image = UIGraphicsImageRenderer(bounds: v.bounds, format: fmt).image { ctx in
            t.draw(in: ctx.cgContext, imageProvider: { _ in nil })
        }.cgImage!
        func center(_ r: Int, _ c: Int) -> (x: Int, y: Int) {
            let rect = t.cellRect(row: r, column: c)!
            return (Int(rect.midX), Int(rect.midY))
        }
        let (hx, hy) = center(0, 0), (bx, by) = center(1, 0), (rx, ry) = center(0, 1)
        let header = sample(image, x: hx, y: hy)   // header, no explicit bg → header tint
        let body = sample(image, x: bx, y: by)     // plain body cell → no fill
        let red = sample(image, x: rx, y: ry)      // header + explicit red bg → red wins (precedence)
        // (1) the header cell is tinted where the plain body cell is not (translucent tint over a clear bg).
        XCTAssertEqual(body.a, 0, "a plain body cell draws no fill (stays transparent)")
        XCTAssertGreaterThan(header.a, 0, "a header cell draws the translucent header tint")
        XCTAssertTrue(header.a != body.a || header.r != body.r || header.g != body.g || header.b != body.b,
                      "header-cell pixel differs from the plain body-cell pixel")
        // (2) an explicit cell background WINS over the header tint: dominated by opaque red, not a gray tint.
        XCTAssertGreaterThan(red.r, 200, "explicit-bg cell is red")
        XCTAssertLessThan(red.g, 80); XCTAssertLessThan(red.b, 80)
        XCTAssertGreaterThan(red.a, 200, "the explicit opaque background fills the cell fully")
    }

    // MARK: - Phase 2b Task 5: span-aware fill + per-segment grid lines

    /// RGBA (0-255) of a `UIColor`, resolved against the CURRENT trait environment — matches whatever
    /// `UIGraphicsImageRenderer` (no explicit trait collection) rendered the theme's dynamic colors against,
    /// so the expected border color agrees with what actually landed in the pixel buffer.
    private func rgba(_ color: UIColor) -> (r: Int, g: Int, b: Int, a: Int) {
        let resolved = color.resolvedColor(with: UITraitCollection.current)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()), Int((a * 255).rounded()))
    }

    /// Un-premultiplies an RGBA8 sample (the pixel buffer is `premultipliedLast`, so a semi-transparent
    /// stroke's raw R/G/B bytes are scaled down by its alpha — comparing them directly against an opaque
    /// theme color would read as a false mismatch). No-op at alpha 0 (returns as-is; the "no divider" case
    /// checks `.a == 0` directly, never the color, so this value is never inspected there).
    private func unpremultiplied(_ px: (r: Int, g: Int, b: Int, a: Int)) -> (r: Int, g: Int, b: Int, a: Int) {
        guard px.a > 0 else { return px }
        let factor = 255.0 / Double(px.a)
        func scaled(_ c: Int) -> Int { min(255, Int((Double(c) * factor).rounded())) }
        return (scaled(px.r), scaled(px.g), scaled(px.b), px.a)
    }

    /// The highest-alpha pixel within `±radius` of `(x, y)` along the given axis — a 1pt stroke centered on
    /// a half-pixel boundary anti-aliases its coverage across TWO adjacent pixel columns/rows (~50% alpha
    /// each, never a clean 255), so "is a divider drawn here" must look at the peak nearby alpha, not the
    /// exact sampled coordinate.
    private func peakAlphaNear(_ image: CGImage, x: Int, y: Int, radius: Int, horizontal: Bool) -> (r: Int, g: Int, b: Int, a: Int) {
        var best = sample(image, x: x, y: y)
        for d in -radius...radius {
            let px = horizontal ? sample(image, x: x + d, y: y) : sample(image, x: x, y: y + d)
            if px.a > best.a { best = px }
        }
        return best
    }

    private func renderTable(_ t: TableBlockBox) -> CGImage {
        let fmt = UIGraphicsImageRendererFormat(); fmt.opaque = false; fmt.scale = 1
        let bounds = CGRect(origin: .zero, size: CGSize(width: t.frame.maxX, height: t.frame.maxY))
        return UIGraphicsImageRenderer(bounds: bounds, format: fmt).image { ctx in
            t.draw(in: ctx.cgContext, imageProvider: { _ in nil })
        }.cgImage!
    }

    private func makeTable(width: CGFloat, height: CGFloat, table: TableBlock) -> TableBlockBox {
        let t = TableBlockBox(table: table, mapper: AttributedStringMapper(), width: width)
        t.frame = CGRect(x: 0, y: 0, width: width, height: height)
        t.recompute(); t.recompute()
        return t
    }

    private func hcell(_ id: String, _ t: String) -> Cell { var c = cell(id, t); c.isHeader = true; return c }

    /// A 3-column x 2-row table where row 0's first two cells (PER-CELL header, NOT a whole header row —
    /// so the row's third cell stays plain) merge into one colspan-2 header anchor; row 1 stays fully dense.
    /// Deliberately NOT a uniform header row: under the OLD per-slot fill, the merge's declared array index 1
    /// (physical column 2, "H2"/plain) happens to land ITS OWN dense fill exactly over the merged cell's
    /// covered physical-column-1 slot whenever every column is the same width AND every cell in the row is a
    /// header (both true in the first, since-fixed draft of this fixture) — a false pass that doesn't
    /// actually exercise the anchor-resolution fix. Making cell "c" NON-header removes that coincidence: the
    /// covered slot is filled ONLY if the fill pass correctly resolves it to the merged anchor.
    private func mergedHeaderTable() -> TableBlock {
        let dense = TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [
                Row(id: BlockID("r0"), cells: [hcell("a", "H0"), hcell("b", "H1"), cell("c", "H2")]),
                Row(id: BlockID("r1"), cells: [cell("d", "D"), cell("e", "E"), cell("f", "F")]),
            ])
        return dense.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))
    }

    /// A colspan-2 HEADER anchor must fill its WHOLE spanned rect — including the covered (second) column
    /// slot, which a naive per-slot fill (iterating `cells[r][c]` and filling only the declared origin
    /// slot) would leave unfilled/clear.
    func test_draw_mergedHeaderCell_fillsWholeSpannedRect() {
        let t = makeTable(width: 300, height: 300, table: mergedHeaderTable())
        let image = renderTable(t)
        // The merged anchor's own (first) column, within its row-0 band.
        let anchorX = Int(t.cellRect(row: 1, column: 0)!.midX)
        let row0Y = Int(t.cellRect(row: 0, column: 0)!.midY)
        // The SECOND (covered) column of the same merged cell, same row-0 band.
        let coveredX = Int(t.cellRect(row: 1, column: 1)!.midX)
        // A non-merged, non-header body cell.
        let bodyX = Int(t.cellRect(row: 1, column: 2)!.midX)
        let row1Y = Int(t.cellRect(row: 1, column: 2)!.midY)

        let anchorPixel = sample(image, x: anchorX, y: row0Y)
        let coveredPixel = sample(image, x: coveredX, y: row0Y)
        let bodyPixel = sample(image, x: bodyX, y: row1Y)

        XCTAssertGreaterThan(anchorPixel.a, 0, "the anchor's own column shows the header tint")
        XCTAssertGreaterThan(coveredPixel.a, 0,
                             "the SECOND (covered) column of the merged header cell also shows the tint — " +
                             "a per-slot fill would leave this clear")
        XCTAssertEqual(bodyPixel.a, 0, "a non-merged, non-header body cell draws no fill")
    }

    /// A 2-column x 2-row table with row 0 merged into one colspan-2 anchor (row 1 stays dense), no header/
    /// background fill — isolates the border logic from the fill pass.
    private func mergedRowTable() -> TableBlock {
        let dense = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "A"), cell("b", "B")]),
                   Row(id: BlockID("r1"), cells: [cell("c", "C"), cell("d", "D")])])
        return dense.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))
    }

    /// The interior vertical divider between columns 0/1 must be SUPPRESSED within the merged row-0 band
    /// (no anchor straddles it there — one anchor covers both slots) but must still be PRESENT in the dense
    /// row-1 band (the control), proving suppression is per-segment, not table-wide.
    func test_draw_noInteriorDividerInsideMergedCell() {
        let t = makeTable(width: 300, height: 300, table: mergedRowTable())
        let image = renderTable(t)
        let border = rgba(t.mapper.theme.tableBorder)
        // Boundary x between column 0 and column 1 (row 1's dense cell's right edge + half a border).
        let boundaryX = Int((t.cellRect(row: 1, column: 0)!.maxX + TableBlockBox.border / 2).rounded())
        let mergedRowY = Int(t.cellRect(row: 0, column: 0)!.midY)
        let denseRowY = Int(t.cellRect(row: 1, column: 0)!.midY)

        let mergedBoundaryPixel = peakAlphaNear(image, x: boundaryX, y: mergedRowY, radius: 1, horizontal: true)
        let denseBoundaryPixel = unpremultiplied(peakAlphaNear(image, x: boundaryX, y: denseRowY, radius: 1, horizontal: true))

        XCTAssertEqual(mergedBoundaryPixel.a, 0,
                       "no divider is drawn INSIDE the merged cell's row band (no fill/border there either)")
        XCTAssertGreaterThan(denseBoundaryPixel.a, 80,
                             "control: the SAME vertical boundary in the dense row-1 band still draws the divider")
        XCTAssertLessThanOrEqual(abs(denseBoundaryPixel.r - border.r), 40)
        XCTAssertLessThanOrEqual(abs(denseBoundaryPixel.g - border.g), 40)
        XCTAssertLessThanOrEqual(abs(denseBoundaryPixel.b - border.b), 40)
    }

    /// Dense parity: a fully dense table (no spans) still renders every interior divider (vertical AND
    /// horizontal) plus the per-cell header fill — proving the per-segment/anchor-driven rewrite is
    /// byte-behaviorally unchanged for the no-span case.
    func test_draw_denseTable_rendersAllDividersAndHeaderFill() {
        let dense = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), isHeader: true, cells: [cell("a", "H0"), cell("b", "H1")]),
                   Row(id: BlockID("r1"), cells: [cell("c", "C"), cell("d", "D")])])
        let t = makeTable(width: 300, height: 300, table: dense)
        let image = renderTable(t)
        let border = rgba(t.mapper.theme.tableBorder)

        let headerPixel = sample(image, x: Int(t.cellRect(row: 0, column: 0)!.midX), y: Int(t.cellRect(row: 0, column: 0)!.midY))
        XCTAssertGreaterThan(headerPixel.a, 0, "the header row still fills with the header tint")

        // Interior vertical divider (columns 0/1), sampled in BOTH row bands.
        let vBoundaryX = Int((t.cellRect(row: 0, column: 0)!.maxX + TableBlockBox.border / 2).rounded())
        for (label, y) in [("row0", Int(t.cellRect(row: 0, column: 0)!.midY)), ("row1", Int(t.cellRect(row: 1, column: 0)!.midY))] {
            let best = unpremultiplied(peakAlphaNear(image, x: vBoundaryX, y: y, radius: 1, horizontal: true))
            XCTAssertGreaterThan(best.a, 80, "dense parity: vertical divider present in \(label)")
            XCTAssertLessThanOrEqual(abs(best.r - border.r), 40, "dense parity: divider color matches the theme border in \(label)")
        }

        // Interior horizontal divider (rows 0/1).
        let hBoundaryY = Int((t.cellRect(row: 0, column: 0)!.maxY + TableBlockBox.border / 2).rounded())
        let hx = Int(t.cellRect(row: 0, column: 0)!.midX)
        let bestH = unpremultiplied(peakAlphaNear(image, x: hx, y: hBoundaryY, radius: 1, horizontal: false))
        XCTAssertGreaterThan(bestH.a, 80, "dense parity: horizontal divider present between rows 0/1")
        XCTAssertLessThanOrEqual(abs(bestH.r - border.r), 40)
    }

    /// A dense 2×2 table with INTEGER geometry (columns [100,100] at a 203pt total → 100pt columns exactly;
    /// explicit tall row heights → integer row bands), so the interior 4-way grid crossing lands on a clean
    /// pixel. The `border×border` crossing square where the vertical and horizontal dividers meet MUST be
    /// painted the border color — the pre-fix per-segment code clipped each segment to its own content band
    /// and left this square a transparent hole (the defect this test guards).
    func test_draw_interiorCrossing_isPainted_dense() {
        // width 203 = 2·100 + 3·border → columns solve to exactly [100,100] (no scale, both ≥ minColumnWidth).
        let dense = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), height: 80, cells: [cell("a", "A"), cell("b", "B")]),
                   Row(id: BlockID("r1"), height: 80, cells: [cell("c", "C"), cell("d", "D")])])
        let t = makeTable(width: 203, height: 300, table: dense)
        let image = renderTable(t)
        let border = rgba(t.mapper.theme.tableBorder)

        // The interior crossing = the corner shared by cells (0,0)/(0,1)/(1,0)/(1,1). With integer geometry
        // the `border×border` crossing square occupies exactly ONE pixel: the column band [maxX, maxX+border]
        // × the row band [maxY, maxY+border] (i.e. pixel (maxX, maxY) since border == 1). This must be
        // sampled EXACTLY, radius 0 — a neighborhood search would catch an adjacent (non-crossing) segment
        // pixel and mask the hole.
        let r00 = t.cellRect(row: 0, column: 0)!
        let cx = Int(r00.maxX), cy = Int(r00.maxY)
        let crossing = unpremultiplied(sample(image, x: cx, y: cy))
        XCTAssertGreaterThan(crossing.a, 200, "the interior 4-way crossing square is painted (not a hole)")
        XCTAssertLessThanOrEqual(abs(crossing.r - border.r), 40, "the crossing is the border color")
        XCTAssertLessThanOrEqual(abs(crossing.g - border.g), 40)
        XCTAssertLessThanOrEqual(abs(crossing.b - border.b), 40)
    }

    /// The crossing where the SUPPRESSED-then-RESUMED vertical divider (suppressed inside the colspan-2 row-0
    /// cell, resumed in the dense row-1 band) meets the horizontal divider between rows 0 and 1 must also be
    /// painted: a merge suppresses the divider only WITHIN the merged cell, never the junction below it.
    func test_draw_interiorCrossing_isPainted_belowMergedCell() {
        // Row 0 merged colspan-2, row 1 dense, integer geometry (width 203, explicit row heights).
        let dense = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), height: 80, cells: [cell("a", "A"), cell("b", "B")]),
                   Row(id: BlockID("r1"), height: 80, cells: [cell("c", "C"), cell("d", "D")])])
        let merged = dense.mergingCells(in: TableRect(top: 0, left: 0, bottom: 0, right: 1))
        let t = makeTable(width: 203, height: 300, table: merged)
        let image = renderTable(t)
        let border = rgba(t.mapper.theme.tableBorder)

        // Sanity: the vertical divider IS suppressed inside the merged row-0 cell (no hole to fill there).
        let r10 = t.cellRect(row: 1, column: 0)!
        let boundaryX = Int((r10.maxX + TableBlockBox.border / 2).rounded())
        let insideMerged = peakAlphaNear(image, x: boundaryX, y: Int(t.cellRect(row: 0, column: 0)!.midY), radius: 1, horizontal: true)
        XCTAssertEqual(insideMerged.a, 0, "sanity: no vertical divider inside the merged row-0 cell")

        // The crossing at (col boundary, row 0/1 boundary): the resumed vertical divider (row-1 band) meets
        // the horizontal divider. The crossing square is the column band [maxX, maxX+border] × the row band
        // ABOVE row 1's top ([minY-border, minY]) — pixel (maxX, minY-border) with border == 1. Sampled
        // EXACTLY (radius 0) so the hole can't be masked by an adjacent segment pixel.
        let cx = Int(r10.maxX), cy = Int(r10.minY) - Int(TableBlockBox.border)
        let crossing = unpremultiplied(sample(image, x: cx, y: cy))
        XCTAssertGreaterThan(crossing.a, 200, "the crossing below the merged cell is painted (not a hole)")
        XCTAssertLessThanOrEqual(abs(crossing.r - border.r), 40, "the crossing is the border color")
    }
}
#endif
