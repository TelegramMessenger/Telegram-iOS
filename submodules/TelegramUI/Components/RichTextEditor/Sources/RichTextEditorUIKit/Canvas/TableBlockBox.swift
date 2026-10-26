#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A table block: a grid of cells, each cell a `BlockStack`. Token size follows the Core model
/// (table = Σrows + 2; row = Σcells + 2; cell = Σblocks + 2). Cells are laid out row-major; the
/// canvas treats the whole table as one `CanvasBlock` and recurses via `leafRegions()`.
@available(iOS 13.0, *)
final class TableBlockBox: CanvasBlock {
    let id: BlockID
    let columns: [ColumnSpec]
    var rowIDs: [BlockID]
    var cellIsHeader: [[Bool]]
    var rowMinHeights: [CGFloat]
    var cellIDs: [[BlockID]]
    var cellBackgrounds: [[RGBAColor?]]
    var cellHAlign: [[TextAlignment]]
    var cellVAlign: [[VerticalAlignment]]
    /// Per-cell colspan/rowspan (parallel to the other per-cell arrays, keyed `[row][declaration-index]`,
    /// ANCHOR-ONLY — a covered slot has no entry). Plumbing only (Phase 2b Task 1): stored + round-tripped,
    /// but geometry (`computeColumnWidths`/`recompute`/`draw`/hit-testing) does not yet consume it.
    var cellColspan: [[Int]]
    var cellRowspan: [[Int]]
    var cells: [[BlockStack]]
    let mapper: AttributedStringMapper
    /// Whether the grid is drawn AND occupies space. See `TableBlock.bordered`. `let` for the same reason
    /// `isCompact` is: a toggle rebuilds the box, so this never changes in place — and a post-`recompute`
    /// write would silently invalidate the cached `columnWidths`/`rowHeights` with no relayout.
    let isBordered: Bool
    /// The effective border width: zero when unbordered, so cells butt together as V2 lays them out
    /// (`bordered ? v2TableBorderWidth : 0.0`). EVERY geometry site reads THIS, never the
    /// `TableBlockBox.border` constant.
    var borderWidth: CGFloat { isBordered ? TableBlockBox.border : 0.0 }

    /// Halve every cell's interior padding (the `pageBlockTable` compact flag). Set at build time from
    /// the model; a toggle rebuilds the box, so it never needs to change in place.
    let isCompact: Bool

    var frame: CGRect = .zero
    var nodeStart: Int = 0
    /// The inner scroll view's current horizontal offset, pushed in by the canvas (`syncBlockViews` /
    /// `scrollViewDidScroll`). 0 unless the table overflows and has been scrolled. All other geometry stays
    /// UNSCROLLED; only `closestPosition` (and the canvas-space consumers) fold this in (Task 3).
    var contentOffsetX: CGFloat = 0
    private(set) var layoutWidth: CGFloat
    var columnWidths: [CGFloat] = []
    var rowHeights: [CGFloat] = []

    /// Interior HORIZONTAL cell padding (each side); also drives content width.
    static let cellPadding: CGFloat = 6
    /// Interior VERTICAL cell padding (top + bottom of a cell's content). Applied at the CELL level
    /// (`recompute` content origin + row-height), exactly like `cellPadding` is for the horizontal axis.
    /// It is intentionally larger than `cellPadding`: it reproduces the cell's long-standing vertical
    /// breathing room, which *used* to come — incorrectly — from the document's 8pt inter-block inset
    /// (`BlockBox.defaultVerticalInset`) leaking into the cell's `BlockStack` ON TOP of `cellPadding`
    /// (6 + 8 = 14). That coupling tied cell padding to the document-body block spacing, so it didn't
    /// scale with the cell and the 15pt cell font looked under-filled / vertically centered. Now it is an
    /// explicit cell metric and the cell `BlockStack` carries NO block inset (`verticalInsetBase = 0`), so
    /// this is the cell's sole vertical padding.
    static let cellVerticalPadding: CGFloat = 14
    /// The padding this table actually lays out with. The `static let`s above stay at the full values —
    /// they are the non-compact constants, read directly by tests — and these instance properties are
    /// what every geometry site consumes.
    var cellPadding: CGFloat { isCompact ? TableBlockBox.cellPadding / 2 : TableBlockBox.cellPadding }
    var cellVerticalPadding: CGFloat { isCompact ? TableBlockBox.cellVerticalPadding / 2 : TableBlockBox.cellVerticalPadding }
    /// The grid line width when the table IS bordered. Read through `borderWidth`, never directly —
    /// an unbordered table lays out with zero-width borders (V2: `bordered ? v2TableBorderWidth : 0.0`).
    static let border: CGFloat = 1
    /// Outer-border corner radius (≈8pt, measured from the reference design).
    static let outerCornerRadius: CGFloat = 8
    /// Space the table reserves below its grid, within its own frame. Doubles as the table's bottom
    /// margin AND the room the ••• column handle needs to stay on-screen/tappable when the table is the
    /// document's last block (the canvas is content-sized to the table's frame). Inter-block separation
    /// from a following block is added on top via `BlockStack.framedNeighborMargin`.
    static let bottomSpacing: CGFloat = 9
    /// Minimum width a column keeps before the table overflows the content strip and scrolls horizontally
    /// (Step 2). Tunable via the demo screenshot. Columns still scale-to-fit while every column stays at or
    /// above this; once one would drop below it, the table keeps its natural width and scrolls.
    static let minColumnWidth: CGFloat = 100
    init(table: TableBlock, mapper: AttributedStringMapper, width: CGFloat) {
        id = table.id
        columns = table.columns
        rowIDs = table.rows.map { $0.id }
        cellIsHeader = table.rows.map { $0.cells.map { $0.isHeader } }
        rowMinHeights = table.rows.map { CGFloat($0.height ?? 0) }
        cellIDs = table.rows.map { $0.cells.map { $0.id } }
        cellBackgrounds = table.rows.map { $0.cells.map { $0.background } }
        cellHAlign = table.rows.map { $0.cells.map { $0.horizontalAlignment } }
        cellVAlign = table.rows.map { $0.cells.map { $0.verticalAlignment } }
        cellColspan = table.rows.map { $0.cells.map { $0.colspan } }
        cellRowspan = table.rows.map { $0.cells.map { $0.rowspan } }
        isCompact = table.compact
        isBordered = table.bordered
        // Cells render at a smaller base font than the document body (15 vs 17). Derive a cell-scoped
        // mapper once and store it as this table's `mapper`; every cell box built here, in `appendRow`,
        // and in split/merge replacements (which inherit their source box's `mapper`) shares it.
        let cellMapper = mapper.tableCellVariant()
        self.mapper = cellMapper
        layoutWidth = max(width, 1)
        cells = table.rows.map { row in
            row.cells.map { c in
                let stack = BlockStack(boxes: c.blocks.compactMap { block -> CanvasBlock? in
                    switch block {
                    case .paragraph, .media:
                        // Delegate to the shared factory; nested media never bleeds (see NOTE in MediaBlockBox).
                        return makeBox(for: block, mapper: cellMapper, horizontalBleed: 0, width: 100)
                    default:
                        return nil  // no nested table/code/collapsedQuote/pullQuote/blockQuote in a cell (v1)
                    }
                })
                // The cell owns its vertical padding (`cellVerticalPadding`), so its stack adds no
                // inter-block inset — otherwise the document's 8pt inset would stack on top.
                stack.spacingModel = .containerInterior
            stack.verticalInsetBase = 0
                return stack
            }
        }
        applyRenderOverrides()
    }

    var rowCount: Int { cells.count }
    var columnCount: Int { columns.count }

    /// A covering map over the stored per-cell spans, kept current by `recompute()`. Geometry does not yet
    /// consume it (Task 1 is plumbing only) — this proves the map is buildable and well-formed from the
    /// box's own arrays, ahead of the geometry work in T2–T5.
    private var gridMap: TableMap!

    /// `gridMap` if `recompute()` has run, else a freshly-built one — the same paranoia `cellRect` /
    /// `solveRowHeights` already apply (both are legitimately callable before the first `recompute()`).
    /// Shared by the span-aware hit-testing/resolution methods below (Phase 2b Task 4).
    private var effectiveGridMap: TableMap { gridMap ?? TableMap(modelTableForMap()) }

    /// `map.anchors` indexed by `cellID`, O(1) — the same lookup pattern `recompute()`/`solveRowHeights`
    /// build inline, factored out for the hit-testing/resolution methods (Phase 2b Task 4).
    private func anchorByCellID(_ map: TableMap) -> [BlockID: TableMap.Anchor] {
        var out: [BlockID: TableMap.Anchor] = [:]
        out.reserveCapacity(map.anchors.count)
        for anchor in map.anchors { out[anchor.cellID] = anchor }
        return out
    }

    /// The DECLARED `(row, column)` index into `cells`/`cellIDs` for a given cell id — the inverse of
    /// `cellIDs[r][c]` — or nil if not found (shouldn't happen for an id sourced from `cellIDs` itself, but
    /// callers treat nil defensively, matching the file's existing malformed-table fallbacks).
    private func declaredLocation(ofCellID id: BlockID) -> (row: Int, column: Int)? {
        for r in 0..<cellIDs.count {
            if let c = cellIDs[r].firstIndex(of: id) { return (r, c) }
        }
        return nil
    }

    /// The covering map for this table's CURRENT geometry (Phase 2c: `.cells(TableRect)` table-selection
    /// plumbing) — a thin internal accessor for `effectiveGridMap`, so `DocumentCanvasView`'s cell-rect
    /// selection can expand a rect / enumerate covered anchors (`TableMap.expanded`/`cellsInRect`) without
    /// duplicating the "cached map, or fresh if queried pre-`recompute()`" fallback.
    func tableMap() -> TableMap { effectiveGridMap }

    /// The `BlockStack` for the cell occupying PHYSICAL grid slot (row, column) — the covering-grid
    /// counterpart of `cellTextStart(row:column:)`/`cellRect(row:column:)` for a caller (Phase 2c cell-rect
    /// selection) that needs the cell's leaf regions rather than just its text-start position. A slot
    /// COVERED by a merged cell resolves to that cell's anchor stack (never a phantom neighbor); nil for an
    /// out-of-range slot or a malformed/dropped cell, mirroring those two.
    func declaredCellStack(atRow row: Int, column: Int) -> BlockStack? {
        guard row >= 0, row < rowCount, column >= 0, column < columnCount,
              let anchor = effectiveGridMap.anchor(atRow: row, column: column),
              let loc = declaredLocation(ofCellID: anchor.cellID) else { return nil }
        return cells[loc.row][loc.column]
    }

    /// A lightweight `TableBlock` reconstructed from this box's stored per-cell arrays, for `TableMap`
    /// construction only — cell BLOCKS are omitted (the map doesn't need cell content, only ids + spans).
    private func modelTableForMap() -> TableBlock {
        var rows: [Row] = []
        for r in 0..<cells.count {
            var outCells: [Cell] = []
            for c in 0..<cells[r].count {
                outCells.append(Cell(id: cellIDs[r][c], blocks: [], isHeader: cellIsHeader[r][c],
                                     colspan: cellColspan[r][c], rowspan: cellRowspan[r][c]))
            }
            rows.append(Row(id: rowIDs[r], cells: outCells))
        }
        return TableBlock(id: id, columns: columns, rows: rows)
    }

    // MARK: - CanvasBlock view-backed rendering
    /// Tables render via a `BlockBackingView` (not directly by the canvas `draw(_:)`).
    var rendersAsBlockView: Bool { true }
    /// The visible clipping window the table's backing view occupies in canvas space: the content-strip
    /// width (`frame.width`) when the grid overflows, else the exact grid extent. The inner scroll view's
    /// `contentSize.width` is the full `gridWidth` (Task 2); a too-wide grid scrolls inside this window.
    var blockViewFrame: CGRect {
        CGRect(x: frame.minX, y: frame.minY, width: min(gridWidth, frame.width), height: frame.height)
    }

    /// The grid's drawn width = Σ column widths + (columnCount+1) borders. Equals `frame.width` when the
    /// table fits the content strip (scale-to-fit); exceeds it when one or more columns are at
    /// `minColumnWidth` and the table overflows → horizontal scroll.
    var gridWidth: CGFloat {
        if columnWidths.isEmpty { computeColumnWidths() }
        return columnWidths.reduce(0) { $0 + $1 + borderWidth } + borderWidth
    }

    // Token size: cell = stack tokens + 2; row = Σcells + 2; table = Σrows + 2.
    var spacingKind: RichTextBlockSpacingKind { .table }

    var nodeSize: Int {
        var total = 0
        for row in cells {
            var rowTotal = 0
            for stack in row { rowTotal += stackTokens(stack) + 2 }
            total += rowTotal + 2
        }
        return total + 2
    }
    private func stackTokens(_ stack: BlockStack) -> Int { stack.boxes.reduce(0) { $0 + $1.nodeSize } }

    func setWidth(_ width: CGFloat) { layoutWidth = max(width, 1); computeColumnWidths() }

    // Pure column-width computation for an arbitrary total width (no mutation of self.columnWidths).
    // internal (not private): shared by the live height path (computeColumnWidths / rowHeightsComputed)
    // and the stateless measuredHeight, plus TableMeasureTests — keep it non-private.
    func solveColumnWidths(forWidth width: CGFloat) -> [CGFloat] {
        let borders = CGFloat(columnCount + 1) * borderWidth
        let avail = max(width - borders, CGFloat(columnCount))
        let sum = columns.reduce(0) { $0 + CGFloat($1.width) }
        let fit: [CGFloat]
        if sum <= 0 { fit = Array(repeating: avail / CGFloat(max(columnCount, 1)), count: columnCount) }
        else { let scale = avail / sum; fit = columns.map { CGFloat($0.width) * scale } }
        if fit.allSatisfy({ $0 >= TableBlockBox.minColumnWidth }) { return fit }
        return fit.map { max($0, TableBlockBox.minColumnWidth) }
    }

    /// Content width for a cell ANCHORED at grid column `c0` spanning `colspan` physical columns: sums
    /// the spanned columns' widths plus the interior borders they subsume (a colspan-2 cell also gets the
    /// divider between its two columns), then removes the one leading border + this cell's own
    /// horizontal padding — the colspan generalization of the old single-column formula (which this
    /// reduces to exactly when `colspan == 1`). Mirrors `InstantPageV2Layout.layoutTable`'s column-span
    /// width accumulation (`columnSpans`).
    func cellContentWidth(anchorColumn c0: Int, colspan: Int, in cols: [CGFloat]) -> CGFloat {
        let upper = min(c0 + max(colspan, 1), cols.count)
        guard c0 >= 0, c0 < upper else { return 1 }
        let spanWidth = cols[c0..<upper].reduce(0, +)
        let width = spanWidth + CGFloat(upper - c0 - 1) * borderWidth - borderWidth - cellPadding * 2
        return max(width, 1)
    }

    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        let cols = solveColumnWidths(forWidth: max(width, 1))
        let heights = solveRowHeights(columnWidths: cols)
        let rows = heights.reduce(CGFloat(0)) { $0 + $1 + borderWidth }
        return borderWidth + rows + TableBlockBox.bottomSpacing
    }

    private func computeColumnWidths() { columnWidths = solveColumnWidths(forWidth: layoutWidth) }

    /// Cell content width (column width minus the left border and horizontal padding). Dense/single-
    /// column only; kept for the two dense-only call sites in this file's height/width plumbing (the
    /// SPAN-AWARE cell layout in `recompute()` and the union rect in `cellRect` go through
    /// `cellContentWidth(anchorColumn:colspan:in:)` / `spannedSlotExtent` instead).
    private func cellContentWidth(_ col: Int) -> CGFloat { max(columnWidths[col] - borderWidth - cellPadding * 2, 1) }

    /// Σ of `values[start..<start+count]` plus the `(count-1)` interior borders they subsume — the raw
    /// spanned SLOT extent (a frame width/height), as opposed to `cellContentWidth(anchorColumn:colspan:in:)`
    /// which further subtracts the leading border + horizontal cell padding to get usable CONTENT width.
    /// Shared by `recompute()`'s frame walk (the x-advance / free-height math) and `cellRect`'s union rect,
    /// so the two can't drift. Reduces to `values[start]` (no border added) when `count <= 1` — the dense
    /// case, byte-identical to summing a single slot.
    private func spannedSlotExtent(_ values: [CGFloat], from start: Int, count: Int) -> CGFloat {
        let upper = min(start + max(count, 1), values.count)
        guard start >= 0, start < upper else { return 0 }
        return values[start..<upper].reduce(0, +) + CGFloat(upper - start - 1) * borderWidth
    }

    var height: CGFloat {
        if columnWidths.isEmpty { computeColumnWidths() }
        // Grid + a reserved strip below it (bottomSpacing) so the column handle stays on-screen for a
        // trailing table; the gap to the block ABOVE comes from that block's facing inset.
        return borderWidth + rowHeightsComputed().reduce(0) { $0 + $1 + borderWidth } + TableBlockBox.bottomSpacing
    }

    /// Row heights, span-aware — the SOLE row-height solver, shared by `measuredHeight(forWidth:)`
    /// (stateless) and `rowHeightsComputed()` (live) so they cannot drift. Mirrors
    /// `InstantPageV2Layout.layoutTable`'s two-pass `awaitingSpanCells` resolution:
    /// - **Pass A:** every row-declared anchor with `rowspan == 1` sets its row's base height (max cell
    ///   content height, measured at its own — possibly colspan-widened — content width, clamped to the
    ///   row's minimum). A row with no single-row anchor starts at its minimum (default 0).
    /// - **Pass B:** each `rowspan > 1` anchor's own content height is compared to the sum of the rows it
    ///   spans (+ interior borders); any deficit grows the LAST spanned row (mirrors V2's
    ///   `maxRowHeight += delta`) rather than being stacked as an extra row.
    /// Builds its own `TableMap` (rather than trusting the cached `gridMap`) so it stays correct even
    /// when called before `recompute()` has ever run (both `measuredHeight` and `height` are legitimately
    /// callable then).
    ///
    /// Anchors are resolved to cells by `cellID` (an O(1) `[BlockID: Anchor]` lookup), NOT by positional
    /// index — `cellColspan`/`cellRowspan` are freely settable and `TableBlock` is `Codable`, so a
    /// decoded/imported doc can be MALFORMED (a row declaring more cells than fit), in which case
    /// `TableMap` DROPS the overflowing cell from `anchors`. A positional zip would then misalign every
    /// later cell to a neighbor's span → silently-wrong widths/heights. A cell whose id isn't in the map
    /// (dropped) falls back to a dense (colspan/rowspan 1) measurement rather than misattributing a span.
    private func solveRowHeights(columnWidths cols: [CGFloat]) -> [CGFloat] {
        let map = TableMap(modelTableForMap())
        var anchorByID: [BlockID: TableMap.Anchor] = [:]
        anchorByID.reserveCapacity(map.anchors.count)
        for anchor in map.anchors { anchorByID[anchor.cellID] = anchor }

        var heights = rowMinHeights
        var rowspanPending: [(row: Int, rowspan: Int, height: CGFloat)] = []

        for r in 0..<cells.count {
            for c in 0..<cells[r].count {
                // Resolve this cell's placement by id; a malformed/dropped cell measures dense (1×1) at
                // its declared column — never inheriting a neighbor's span.
                let anchor = anchorByID[cellIDs[r][c]]
                let column = anchor?.column ?? c
                let colspan = anchor?.colspan ?? 1
                let rowspan = anchor?.rowspan ?? 1
                let originRow = anchor?.row ?? r
                let contentWidth = cellContentWidth(anchorColumn: column, colspan: colspan, in: cols)
                let cellHeight = cells[r][c].measuredHeight(forWidth: contentWidth) + cellVerticalPadding * 2
                if rowspan <= 1 {
                    if heights.indices.contains(r) { heights[r] = max(heights[r], cellHeight) }
                } else {
                    rowspanPending.append((row: originRow, rowspan: rowspan, height: cellHeight))
                }
            }
        }

        for pending in rowspanPending {
            let lastRow = min(pending.row + pending.rowspan - 1, heights.count - 1)
            guard pending.row >= 0, pending.row <= lastRow else { continue }
            let spannedHeight = (pending.row...lastRow).reduce(CGFloat(0)) { $0 + heights[$1] }
                + CGFloat(lastRow - pending.row) * borderWidth
            if pending.height > spannedHeight {
                heights[lastRow] += pending.height - spannedHeight
            }
        }

        return heights
    }

    /// Non-mutating: cell layout is owned by `recompute()`, not by reading height.
    private func rowHeightsComputed() -> [CGFloat] {
        let cols = columnWidths.isEmpty ? solveColumnWidths(forWidth: layoutWidth) : columnWidths
        return solveRowHeights(columnWidths: cols)
    }

    // CanvasBlock
    func currentBlock() -> Block {
        var rows: [Row] = []
        for (r, row) in cells.enumerated() {
            var outCells: [Cell] = []
            for (c, stack) in row.enumerated() {
                var blocks = stack.boxes.map { $0.currentBlock() }
                if isHeaderCell(r, c) { blocks = blocks.map { TableBlockBox.strippingBold($0) } }
                outCells.append(Cell(id: cellIDs[r][c], blocks: blocks, background: cellBackgrounds[r][c],
                                     horizontalAlignment: cellHAlign[r][c], verticalAlignment: cellVAlign[r][c],
                                     isHeader: cellIsHeader[r][c], colspan: cellColspan[r][c], rowspan: cellRowspan[r][c]))
            }
            rows.append(Row(id: rowIDs[r], height: rowMinHeights[r] > 0 ? Double(rowMinHeights[r]) : nil,
                            cells: outCells))
        }
        return .table(TableBlock(id: id, columns: columns, rows: rows, compact: isCompact, bordered: isBordered))
    }

    /// Re-applies the render-only overrides to every cell's display layout: per-cell alignment and,
    /// for header cells, bold. Idempotent; called at build and on each recompute so it survives edits.
    private func applyRenderOverrides() {
        for (r, row) in cells.enumerated() {
            for (c, stack) in row.enumerated() {
                let alignment = cellHAlign[r][c]
                for box in stack.boxes {
                    (box as? BlockBox)?.applyDisplayOverride(alignment: alignment, forceBold: isHeaderCell(r, c), mapper: mapper)
                }
            }
        }
    }

    /// Clears the bold trait from a paragraph block's runs (the header row's bold is a render override).
    private static func strippingBold(_ block: Block) -> Block {
        guard case .paragraph(var p) = block else { return block }
        p.runs = p.runs.map { run in var r = run; r.attributes.bold = false; return r }
        return .paragraph(p)
    }

    /// Assigns nodeStarts to every cell stack row-major, matching the Core token walk, and lays out
    /// cell frames — SPAN-AWARE (Phase 2b Task 3): a merged (colspan/rowspan > 1) cell is laid out at its
    /// full spanned rect, not a single grid slot. Returns nothing; the canvas reads `nodeSize`/`leafRegions`
    /// afterward.
    ///
    /// The frame walk is a column-cursor over the PHYSICAL covering grid (mirrors
    /// `InstantPageV2Layout.layoutTable`'s pass 2/3 `awaitingSpanCells` column skip): `k` tracks the next
    /// unoccupied physical column in row `r`, and before placing each DECLARED cell it steps `k` (and `x`)
    /// past any physical column still covered by a rowspan anchor that originated in an EARLIER row
    /// (`gridMap.anchor(atRow:r,column:k)!.row < r`) — since that earlier row's declared-cell loop already
    /// advanced past those columns, only a LATER row needs to skip them.
    ///
    /// The TOKEN `pos` walk is DELIBERATELY untouched and stays independent of `k`: it iterates the
    /// DECLARED anchors in `cells[r]` — one `.cell` node per anchor, exactly as before merges existed
    /// (`TableBlock`'s cells are removed, not covered, on merge — see `TableBlock.mergingCells`) — so a
    /// merge changes `pos` accounting only by however many fewer anchors there now are, never by the
    /// physical column/slot count a span covers. Regression-guarded by `TableSpanGeometryTests
    /// .test_recompute_tokenPositionsUnchanged` (a positional/physical-column-driven `pos` would desync
    /// every global position after the merge — the nav/selection/command suites would then fail too).
    func recompute() {
        gridMap = TableMap(modelTableForMap())
        applyRenderOverrides()
        if columnWidths.isEmpty { computeColumnWidths() }
        rowHeights = rowHeightsComputed()

        // Anchor lookup by cellID — same pattern as `solveRowHeights` (T2): a cell resolves to its
        // (originColumn, colspan, rowspan) by id, never a positional counter, so a decoded/malformed table
        // (TableMap may drop an overflowing cell) can't misattribute a neighbor's span.
        var anchorByID: [BlockID: TableMap.Anchor] = [:]
        anchorByID.reserveCapacity(gridMap.anchors.count)
        for anchor in gridMap.anchors { anchorByID[anchor.cellID] = anchor }

        // Token base: this table's content starts at nodeStart + 1 (the table open token).
        var pos = nodeStart + 1
        var y = frame.minY + borderWidth
        for (r, row) in cells.enumerated() {
            pos += 1                                   // row open token
            var x = frame.minX + borderWidth
            var k = 0                                  // physical column cursor over the covering grid
            for (c, stack) in row.enumerated() {
                pos += 1                               // cell open token — independent of `k`, see above

                // Skip physical columns already occupied by a rowspan anchor DESCENDING from an earlier
                // row (the V2-mirrored `awaitingSpanCells` skip) before placing this row's next anchor.
                while k < columnCount, let occupant = gridMap.anchor(atRow: r, column: k), occupant.row < r {
                    x += columnWidths[k] + borderWidth
                    k += 1
                }

                let anchor = anchorByID[cellIDs[r][c]]
                let colspan = anchor?.colspan ?? 1
                let rowspan = anchor?.rowspan ?? 1
                // Malformed-table degenerate path (id not in the map — TableMap dropped an overflowing
                // cell): fall back to the DECLARED index `c`, IDENTICAL to `solveRowHeights`, so a
                // malformed table degrades the same way in both solvers (width/height stay in agreement).
                let originColumn = anchor?.column ?? c

                let spannedWidth = spannedSlotExtent(columnWidths, from: originColumn, count: colspan)
                let spannedHeight = spannedSlotExtent(rowHeights, from: r, count: rowspan)
                let contentWidth = cellContentWidth(anchorColumn: originColumn, colspan: colspan, in: columnWidths)

                // Vertical alignment: offset content within the SPANNED free vertical space (mirrors the
                // V2 renderer, InstantPageV2Layout.layoutTable). `.top` (default) → offset 0 — byte-
                // identical to before for a dense (colspan==rowspan==1) cell, where `spannedHeight ==
                // rowHeights[r]` exactly.
                let contentH = stack.measuredHeight(forWidth: contentWidth)
                let free = max(0, (spannedHeight - cellVerticalPadding * 2) - contentH)
                let vFactor: CGFloat = { switch cellVAlign[r][c] { case .top: return 0; case .middle: return 0.5; case .bottom: return 1 } }()
                let contentOrigin = CGPoint(x: x + cellPadding,
                                            y: y + cellVerticalPadding + free * vFactor)
                _ = stack.recompute(baseOffset: pos - 1)   // cell content begins at (cell open) → baseOffset
                _ = stack.layout(origin: contentOrigin, width: contentWidth)
                pos += stackTokens(stack)
                pos += 1                               // cell close token

                x += spannedWidth + borderWidth
                k += colspan
            }
            pos += 1                                   // row close token
            y += rowHeights[r] + borderWidth
        }
    }

    func leafRegions() -> [LeafTextRegion] { cells.flatMap { $0.flatMap { $0.leafRegions() } } }

    /// Every cell paragraph box paired with its canvas-coordinate frame, for view hosting. (Cell IMAGES are
    /// excluded — they still draw in place via `draw`; only paragraphs become view-backed.)
    func cellParagraphBoxes() -> [(box: BlockBox, frame: CGRect)] {
        cells.flatMap { row in row.flatMap { $0.boxes.compactMap { b in (b as? BlockBox).map { ($0, $0.frame) } } } }
    }

    /// The cell `BlockStack` that owns global position `pos`, with the box + local offset + index
    /// within that stack. Mirrors `leafRegions()`'s recursion, for the editing engine.
    func cellStack(containing pos: Int) -> (stack: BlockStack, box: CanvasBlock, local: Int, index: Int)? {
        for row in cells {
            for stack in row {
                for (i, b) in stack.boxes.enumerated() {
                    if let first = b.leafRegions().first,
                       pos >= first.globalStart, pos <= first.globalStart + first.length {
                        return (stack, b, pos - first.globalStart, i)
                    }
                }
            }
        }
        return nil
    }

    /// (row, column) of the cell whose stack owns `pos`, or nil. SPAN-AWARE (Phase 2b Task 4): returns the
    /// owning cell's ANCHOR PHYSICAL origin (`gridMap`'s covering-grid space), not its declared-array index
    /// — so a position inside a merged cell whose declared index sits at an earlier column (because a
    /// preceding anchor's span pushed it down) still reports its true physical column, matching
    /// `cellRect(row:column:)`'s physical coordinate space (Task 3). A malformed/dropped cell (id absent
    /// from the map) falls back to its declared `(r, c)`, mirroring `solveRowHeights`/`recompute`'s own
    /// degenerate-table fallback. Reduces to the declared index for a dense table (physical == declared).
    func cellLocation(containing pos: Int) -> (row: Int, column: Int)? {
        for (r, row) in cells.enumerated() {
            for (c, stack) in row.enumerated() {
                for b in stack.boxes {
                    if let first = b.leafRegions().first, pos >= first.globalStart, pos <= first.globalStart + first.length {
                        if let anchor = anchorByCellID(effectiveGridMap)[cellIDs[r][c]] {
                            return (anchor.row, anchor.column)
                        }
                        return (r, c)
                    }
                }
            }
        }
        return nil
    }

    /// The global text start of the cell occupying PHYSICAL grid slot (row, column) — its first leaf
    /// region's global start (where Tab places the caret). SPAN-AWARE (Phase 2b Task 4): `row`/`column` are
    /// covering-grid (`gridMap`) coordinates, exactly like `cellRect`/`cellLocation` — a slot COVERED by a
    /// merged cell resolves to that cell's ANCHOR (never nil, never a neighboring cell's start). Reduces to
    /// the pre-2b single-slot lookup for a dense table (physical == declared there).
    func cellTextStart(row: Int, column: Int) -> Int? {
        guard row >= 0, row < rowCount, column >= 0, column < columnCount else { return nil }
        guard let anchor = effectiveGridMap.anchor(atRow: row, column: column),
              let loc = declaredLocation(ofCellID: anchor.cellID) else { return nil }
        return cells[loc.row][loc.column].leafRegions().first?.globalStart
    }

    /// The canvas-coordinate rect of the cell occupying PHYSICAL grid slot (row, column), from cached grid
    /// geometry (matches `draw` / `closestPosition`). SPAN-AWARE (Phase 2b Task 3): `row`/`column` are
    /// covering-grid coordinates (0..<rowCount / 0..<columnCount, i.e. `gridMap`'s space, NOT a row's
    /// declared-cell array index) — querying a slot COVERED by a merged cell resolves to that cell's
    /// ANCHOR and returns the union rect over its whole footprint (Σ spanned column widths / row heights,
    /// plus the interior borders the span subsumes), not a phantom single-slot rect. Reduces to the exact
    /// pre-2b single-slot rect for a dense (colspan==rowspan==1) table. Used by vertical caret nav to snap
    /// into the same-column neighbor cell.
    func cellRect(row: Int, column: Int) -> CGRect? {
        guard row >= 0, row < rowCount, column >= 0, column < columnCount,
              rowHeights.indices.contains(row), columnWidths.indices.contains(column) else { return nil }
        // `gridMap` is built by `recompute()`; fall back to a freshly-built map if queried before any
        // `recompute()` has run (mirrors `solveRowHeights`'s own paranoia — both are legitimately callable
        // that early).
        let map = gridMap ?? TableMap(modelTableForMap())
        guard let anchor = map.anchor(atRow: row, column: column) else { return nil }
        var y = frame.minY + borderWidth
        for r in 0..<anchor.row { y += rowHeights[r] + borderWidth }
        var x = frame.minX + borderWidth
        for c in 0..<anchor.column { x += columnWidths[c] + borderWidth }
        let width = spannedSlotExtent(columnWidths, from: anchor.column, count: anchor.colspan)
        let height = spannedSlotExtent(rowHeights, from: anchor.row, count: anchor.rowspan)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// The row index whose vertical band contains canvas-y `y`, clamped to `0..<rowCount`. The inverse
    /// of `cellRect`'s y math (sum of `rowHeights` + `border`, from `frame.minY + border`). A point in a
    /// border slot resolves to the row above it (half-border slack).
    func rowIndex(atY y: CGFloat) -> Int {
        guard !rowHeights.isEmpty else { return 0 }
        var top = frame.minY + borderWidth
        for r in 0..<rowHeights.count {
            let bottom = top + rowHeights[r]
            if y < bottom + borderWidth / 2 { return r }
            top = bottom + borderWidth
        }
        return rowHeights.count - 1
    }

    /// The column index whose horizontal band contains canvas-x `x`, clamped to `0..<columnCount`.
    func columnIndex(atX x: CGFloat) -> Int {
        guard !columnWidths.isEmpty else { return 0 }
        var left = frame.minX + borderWidth
        for c in 0..<columnWidths.count {
            let right = left + columnWidths[c]
            if x < right + borderWidth / 2 { return c }
            left = right + borderWidth
        }
        return columnWidths.count - 1
    }

    /// Appends a row of `columnCount` empty single-paragraph cells (fresh ids). Caller recomputes + undo.
    func appendRow() {
        let n = max(columnCount, 1)
        var rowStacks: [BlockStack] = []
        var ids: [BlockID] = []
        var bgs: [RGBAColor?] = []
        for _ in 0..<n {
            let para = ParagraphBlock(id: BlockID.generate())
            let stack = BlockStack(boxes: [BlockBox(paragraph: para, mapper: mapper, width: 100)])
            stack.spacingModel = .containerInterior
            stack.verticalInsetBase = 0   // cell owns its vertical padding (see cellVerticalPadding)
            rowStacks.append(stack)
            ids.append(BlockID.generate()); bgs.append(nil)
        }
        cells.append(rowStacks); cellIDs.append(ids); cellBackgrounds.append(bgs)
        cellHAlign.append(Array(repeating: .center, count: n))
        cellVAlign.append(Array(repeating: .top, count: n))
        cellIsHeader.append(Array(repeating: false, count: n))
        cellColspan.append(Array(repeating: 1, count: n))
        cellRowspan.append(Array(repeating: 1, count: n))
        rowIDs.append(BlockID.generate()); rowMinHeights.append(0)
    }

    /// Whether cell (r, c) is a header/highlight cell.
    func isHeaderCell(_ r: Int, _ c: Int) -> Bool {
        cellIsHeader.indices.contains(r) && cellIsHeader[r].indices.contains(c) && cellIsHeader[r][c]
    }

    /// Whether row `r` is a full header row (every cell a header). Derived from per-cell flags.
    func isHeaderRow(_ r: Int) -> Bool {
        cellIsHeader.indices.contains(r) && !cellIsHeader[r].isEmpty && cellIsHeader[r].allSatisfy { $0 }
    }

    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        let totalW = columnWidths.reduce(0) { $0 + $1 + borderWidth } + borderWidth
        let totalH = borderWidth + rowHeights.reduce(0) { $0 + $1 + borderWidth }
        // Rounded outer border path (also the clip for fills so corners stay rounded). CG centers
        // strokes, so inset by half the border so the 1pt stroke fills its slot flush with the frame edge.
        let half = borderWidth / 2
        let outer = UIBezierPath(roundedRect: CGRect(x: frame.minX + half, y: frame.minY + half,
                                                     width: totalW - borderWidth,
                                                     height: totalH - borderWidth),
                                 cornerRadius: TableBlockBox.outerCornerRadius - half)
        // `gridMap` if `recompute()` has run, else a freshly-built one (matches every other span-aware
        // reader in this file — `cellRect`/`closestPosition`/etc). Shared by both the fill pass and the
        // per-segment grid lines below so they can't resolve to different anchors.
        let map = effectiveGridMap

        // Cumulative physical column/row band origins (the left/top edge of each column's/row's own content,
        // i.e. just past its leading border) — the SAME geometry `cellRect`'s union rect sums, so a segment
        // boundary / malformed-cell fallback computed here can't drift from `cellRect`'s. Built once and
        // shared by the fill pass (its degenerate fallback) and the grid-line pass.
        var colLeft: [CGFloat] = []
        colLeft.reserveCapacity(columnWidths.count)
        do {
            var acc = frame.minX + borderWidth
            for w in columnWidths { colLeft.append(acc); acc += w + borderWidth }
        }
        var rowTop: [CGFloat] = []
        rowTop.reserveCapacity(rowHeights.count)
        do {
            var acc = frame.minY + borderWidth
            for h in rowHeights { rowTop.append(acc); acc += h + borderWidth }
        }

        // Per-cell fills (explicit background wins over the header highlight), clipped to the rounded outer
        // border so header/background cells at the table corners round with the table. SPAN-AWARE
        // (Phase 2b Task 5): iterate the DECLARED anchors (`cells[r][c]`), but fill each at its ANCHOR'S
        // PHYSICAL origin rect (`cellRect`, which unions the whole spanned footprint) — so a merged header/
        // background cell tints its ENTIRE span, not just its declared origin slot. Reduces to the exact
        // pre-2b per-slot fill for a dense (colspan==rowspan==1) table, where the anchor's own rect IS that
        // single slot.
        ctx.saveGState(); outer.addClip()
        let anchorByID = anchorByCellID(map)
        for (r, row) in cells.enumerated() {
            for (c, _) in row.enumerated() {
                guard let fill = cellBackgrounds[r][c]?.uiColor ?? (isHeaderCell(r, c) ? mapper.theme.tableHeaderBackground : nil) else { continue }
                let anchor = anchorByID[cellIDs[r][c]]
                // Malformed-table fallback (id not in the map — TableMap dropped an overflowing cell): fill
                // the DECLARED `(r, c)` slot IN PLACE via the cumulative `colLeft`/`rowTop` sums, exactly as
                // `recompute`/`solveRowHeights` fall back to the declared index — so a dropped cell degrades
                // at its own position, NOT at the table's (0,0) origin.
                let originRow = anchor?.row ?? r
                let originColumn = anchor?.column ?? c
                let rect = cellRect(row: originRow, column: originColumn)
                    ?? CGRect(x: colLeft[c], y: rowTop[r], width: columnWidths[c], height: rowHeights[r])
                fill.setFill(); ctx.fill(rect)
            }
        }
        ctx.restoreGState()
        var y = frame.minY + borderWidth
        for (r, row) in cells.enumerated() {
            var x = frame.minX + borderWidth
            for (c, stack) in row.enumerated() {
                // Cell PARAGRAPHS render via their own backing views (hosted in the table's content view so
                // they ride horizontal scroll); only non-paragraph boxes (cell images — rare) draw in place.
                for box in stack.boxes where !(box is BlockBox) {
                    box.draw(in: ctx, imageProvider: imageProvider)
                }
                x += columnWidths[c] + borderWidth
            }
            y += rowHeights[r] + borderWidth
        }
        // Interior grid lines — PER-SEGMENT (Phase 2b Task 5), mirroring `InstantPageV2Layout.layoutTable`'s
        // "each cell emits its own top/left border sized to itself" rule: a divider segment at a given
        // physical boundary is drawn only where the two slots straddling it resolve to DIFFERENT anchors —
        // so a merged cell's whole footprint draws as one uninterrupted span with no interior divider
        // through it, while every genuinely dense boundary still draws.
        //
        // Each DRAWN segment is EXTENDED by `border/2` at BOTH ends into the perpendicular border gaps, so
        // two collinear segments meet on the intersection centerline and — crucially — two PERPENDICULAR
        // segments crossing at an interior 4-way junction both paint the `border×border` crossing square
        // (without the extension each segment is clipped to its own content band and the crossing square is
        // left a transparent hole — the defect the old single-full-length-line code never had). With the
        // extension a fully dense table draws byte-identically to that old code: every interior boundary has
        // different anchors on both sides at every row/column, so the per-row/per-column segments are
        // contiguous AND their crossings are filled, reproducing two continuous full-length lines. Extending
        // at the table's OUTER edge is harmless — the rounded outer border stroke paints over it.
        // An unbordered table paints no grid at all — and, because `borderWidth` is 0, the cells have
        // already been laid out flush, so there is nothing to stroke between them anyway. Cell fills
        // (header tint, per-cell background) are NOT borders and stay.
        guard isBordered else {
            return
        }
        mapper.theme.tableBorder.setStroke()
        ctx.setLineWidth(borderWidth)
        let ext = borderWidth / 2
        if columnWidths.count > 1 {
            for c in 1..<columnWidths.count {
                let bx = colLeft[c] - ext
                for r in 0..<rowHeights.count {
                    guard map.anchor(atRow: r, column: c - 1)?.cellID != map.anchor(atRow: r, column: c)?.cellID else { continue }
                    ctx.move(to: CGPoint(x: bx, y: rowTop[r] - ext))
                    ctx.addLine(to: CGPoint(x: bx, y: rowTop[r] + rowHeights[r] + ext))
                }
            }
        }
        if rowHeights.count > 1 {
            for r in 1..<rowHeights.count {
                let by = rowTop[r] - ext
                for c in 0..<columnWidths.count {
                    guard map.anchor(atRow: r - 1, column: c)?.cellID != map.anchor(atRow: r, column: c)?.cellID else { continue }
                    ctx.move(to: CGPoint(x: colLeft[c] - ext, y: by))
                    ctx.addLine(to: CGPoint(x: colLeft[c] + columnWidths[c] + ext, y: by))
                }
            }
        }
        ctx.strokePath()
        // Rounded outer border (path built up front, also used to clip the header tint).
        outer.lineWidth = borderWidth
        outer.stroke()
    }

    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        guard rowCount > 0, columnCount > 0 else { return nodeStart + 1 }
        // The incoming point is a VISIBLE canvas touch; the cell walk below is unscrolled, so add the offset.
        let point = CGPoint(x: point.x + contentOffsetX, y: point.y)
        // Find the PHYSICAL band under the point (`rowIndex`/`columnIndex` are span-neutral — see their own
        // doc comments), resolve it to its covering ANCHOR, and recurse into THAT anchor's stack. This is
        // what makes a tap in a COVERED slot (e.g. the second column of a colspan-2 cell) resolve into the
        // anchor's own text instead of a phantom single-slot cell. Reduces to the pre-2b per-slot walk for a
        // dense table (every physical band's anchor IS that slot's own declared cell).
        let r = rowIndex(atY: point.y)
        let c = columnIndex(atX: point.x)
        if let anchor = effectiveGridMap.anchor(atRow: r, column: c), let loc = declaredLocation(ofCellID: anchor.cellID) {
            return cells[loc.row][loc.column].closestPosition(toCanvasPoint: point)
        }
        // Fallback (malformed/uncovered slot): last cell's closest position.
        if let lastStack = cells.last?.last { return lastStack.closestPosition(toCanvasPoint: point) }
        return nodeStart + 1
    }

    // Degenerate single-text-region conformance (unused: the canvas uses leafRegions() for tables).
    // Per-instance (not static): the canvas never edits through a table's `textLayout` — a collapsed
    // caret resting on a table boundary is snapped into a cell first (see `caretSnappedIntoContainer`) — but
    // keeping this per-instance contains any future accidental write to one table rather than leaking
    // it into a process-wide shared layout.
    private let emptyLayout = makeBlockLayout(attributedString: NSAttributedString(string: ""), width: 1)
    var textLayout: BlockLayoutEngine { emptyLayout }
    var textStart: Int { nodeStart }
    var textLength: Int { 0 }
    var textRef: TextNodeRef { .paragraph(id) }
    var textOrigin: CGPoint { frame.origin }
}
#endif
