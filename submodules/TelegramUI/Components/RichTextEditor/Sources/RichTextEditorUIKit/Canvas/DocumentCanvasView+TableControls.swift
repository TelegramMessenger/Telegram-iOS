#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A whole-row, whole-column, or arbitrary cell-rect structural selection within a table. `.rows`/`.columns`
/// are a contiguous, ≥1-wide range; `.cells` is an arbitrary rectangle of cells (Phase 2c), always stored
/// already-EXPANDED (via `TableMap.expanded`) so it never bisects a merged cell.
@available(iOS 13.0, *)
enum TableStructuralSelection: Equatable { case rows(ClosedRange<Int>); case columns(ClosedRange<Int>); case cells(TableRect) }

/// What a tap on a table handle does: select its row/column, or — if that one is already selected —
/// open the context menu.
@available(iOS 13.0, *)
enum TableHandleTap: Equatable { case select(TableStructuralSelection); case menu }

/// Which end of a structural range a resize knob moves: the lower bound (left/top) or upper (right/bottom).
@available(iOS 13.0, *)
enum TableRangeEnd: Equatable { case lower, upper }

/// One of the four corners of a `.cells` structural selection's outline — or a focused cell's "fake"
/// outline when there is no committed selection (Phase 2c-T3) — identifying which corner a resize knob
/// sits at and would drag. T4 wires the actual drag; T3 only reports the geometry + corner identity.
@available(iOS 13.0, *)
enum TableCellCorner: Equatable { case topLeft, topRight, bottomLeft, bottomRight }

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Hit/draw rects for the row (left gutter) and column (below table) handles. Draw and hit-test share
    /// these rects, so the visible-band clip in `drawTableChrome` is draw-only — a scrolled-off handle is
    /// simply off-screen and unreachable by touch.
    /// The two handles for the caret's current cell in its table: a vertical ⋮ row handle in the left
    /// gutter, and a horizontal ••• column handle just below the table bottom (matching the reference).
    /// Empty when the caret isn't in a table. `rect` is the hit/draw rect in canvas coordinates.
    func tableHandles() -> [(rect: CGRect, kind: TableStructuralSelection)] {
        guard let a = activeTable() else { return [] }
        let b = a.box.borderWidth   // 0 for an unbordered table, so the handles sit flush
        // The grip spans the active structural RANGE when one is selected, else the caret's single cell.
        let rowRange = structuralRowRange() ?? (a.row...a.row)
        let colRange = structuralColumnRange() ?? (a.col...a.col)
        var out: [(rect: CGRect, kind: TableStructuralSelection)] = []
        if let top = a.box.cellRect(row: rowRange.lowerBound, column: 0),
           let bot = a.box.cellRect(row: rowRange.upperBound, column: 0) {
            let y = top.minY - b
            // The row grip sits in the LEFT gutter, its right edge tucking `gripTuck` under the table's left
            // border, so it's ALWAYS drawn to the LEFT of the table — even with a zero page margin (the chat
            // composer), where it draws into the field's left padding rather than over the first column. Anchored
            // to the table's (unscrolled) left edge, this is x==1 for the full-page editor's 16pt page margin
            // (unchanged) and negative for the composer. (Was a fixed x:1, which assumed a page-margin gutter and
            // landed inside the table when there was none.)
            let gripWidth: CGFloat = 17, gripTuck: CGFloat = 2
            let x = a.box.frame.minX + gripTuck - gripWidth
            out.append((CGRect(x: x, y: y, width: gripWidth, height: bot.maxY + b - y), .rows(rowRange)))
        }
        if let lo = a.box.cellRect(row: 0, column: colRange.lowerBound),
           let hi = a.box.cellRect(row: 0, column: colRange.upperBound) {
            let off = a.box.contentOffsetX
            let tableBottom = (a.box.cellRect(row: a.box.rowCount - 1, column: colRange.lowerBound)?.maxY ?? a.box.frame.maxY) + b
            let width = hi.maxX + b - (lo.minX - b)   // unscrolled span
            out.append((CGRect(x: lo.minX - b - off, y: tableBottom, width: width, height: 17), .columns(colRange)))
        }
        return out
    }

    /// The handle hit by `point`, or nil.
    func tableHandle(at point: CGPoint) -> TableStructuralSelection? {
        for h in tableHandles() where h.rect.contains(point) {
            return h.kind
        }
        return nil
    }

    /// The resize knobs (◇) for the current chrome, in canvas coordinates: TWO knobs at the structural
    /// selection's ends for `.rows`/`.columns` (column → left/right edges, vertically centered; row →
    /// top/bottom edges, horizontally centered); FOUR knobs — drawn at the CENTER OF EACH SIDE (see
    /// `cornerKnobs`, which keeps their corner identity for the 2D drag) — for a committed `.cells` selection
    /// OR, when there is no committed selection but the caret sits in a table cell, the caret cell's
    /// "fake" outline (Phase 2c-T3; `focusedOrSelectedCellRect()`). `rect` is a generous square hit/anchor
    /// rect centered on the knob. `end` is set for the row/column case (nil for a corner knob); `corner`
    /// is set for the `.cells`/fake-chrome case (nil for a row/column knob) — T4 wires the corner drag.
    /// Empty when there is neither a structural selection nor a focused cell.
    func tableResizeKnobs() -> [(rect: CGRect, end: TableRangeEnd?, corner: TableCellCorner?)] {
        let hit: CGFloat = 44
        func box(_ center: CGPoint) -> CGRect {
            CGRect(x: center.x - hit / 2, y: center.y - hit / 2, width: hit, height: hit)
        }
        // Center knobs on the outline STROKE's centerline, not the raw outline rect. The stroke is drawn on
        // `outer.insetBy(lineWidth/2)` (its outer edge flush with the table border — see
        // `drawTableSelectionOutline`), so a knob placed on the raw rect sits ~half-a-line-width (1pt) OUTSET
        // from the visible line. Insetting by the same amount lands every knob on the drawn line.
        let strokeInset = DocumentCanvasView.selectionOutlineWidth / 2
        if let sel = tableSelection, let raw = tableSelectionOutlineRect() {
            let outline = raw.insetBy(dx: strokeInset, dy: strokeInset)
            switch sel.kind {
            case .columns:
                let y = outline.midY
                return [(box(CGPoint(x: outline.minX, y: y)), .lower, nil),
                        (box(CGPoint(x: outline.maxX, y: y)), .upper, nil)]
            case .rows:
                let x = outline.midX
                return [(box(CGPoint(x: x, y: outline.minY)), .lower, nil),
                        (box(CGPoint(x: x, y: outline.maxY)), .upper, nil)]
            case .cells:
                return cornerKnobs(outline, box: box)
            }
        }
        // No committed selection but the caret sits in a table cell → FAKE chrome's 4 corner knobs.
        guard tableSelection == nil, focusedOrSelectedCellRect() != nil,
              let raw = tableSelectionOutlineRect() else { return [] }
        return cornerKnobs(raw.insetBy(dx: strokeInset, dy: strokeInset), box: box)
    }

    /// Stroke width of the table selection outline. Shared by the stroke draw (`drawTableSelectionOutline`)
    /// and the knob geometry (`tableResizeKnobs`), so a knob centers on the drawn line rather than 1pt outset.
    static let selectionOutlineWidth: CGFloat = 2

    /// The four resize knobs of `outline`, shared by the committed `.cells` and the focused-cell "fake"
    /// chrome paths. They are drawn at the CENTER OF EACH SIDE (not the geometric corners), but each keeps
    /// its `TableCellCorner` identity so the 2D corner drag (`extendCellSelection`, which pins the opposite
    /// corner) is unchanged — only the draw/hit anchor moves. Each corner slides to the midpoint of one
    /// adjacent edge, so opposite corners map to opposite sides and all four land on distinct edges:
    /// topLeft → top-center, bottomRight → bottom-center, topRight → right-center, bottomLeft → left-center.
    private func cornerKnobs(_ outline: CGRect, box: (CGPoint) -> CGRect) -> [(rect: CGRect, end: TableRangeEnd?, corner: TableCellCorner?)] {
        [(box(CGPoint(x: outline.midX, y: outline.minY)), nil, .topLeft),     // top edge center
         (box(CGPoint(x: outline.maxX, y: outline.midY)), nil, .topRight),    // right edge center
         (box(CGPoint(x: outline.minX, y: outline.midY)), nil, .bottomLeft),  // left edge center
         (box(CGPoint(x: outline.midX, y: outline.maxY)), nil, .bottomRight)] // bottom edge center
    }

    /// Which resize knob (if any) `point` hits — the row/column `end`, for chrome that has one.
    func tableResizeKnob(at point: CGPoint) -> TableRangeEnd? {
        tableResizeKnobs().first { $0.rect.contains(point) }?.end
    }

    /// Which corner-resize knob (if any) `point` hits — mirrors `tableResizeKnob(at:)` for the `.cells`/
    /// focused-cell "fake" chrome's four corner knobs (Phase 2c-T4). Non-nil whether the chrome is a
    /// committed `.cells` selection OR the caret's focused-cell fake outline (no committed selection yet) —
    /// `tableResizeKnobs()` already returns corner knobs for both.
    func tableResizeCornerKnob(at point: CGPoint) -> TableCellCorner? {
        tableResizeKnobs().first { $0.rect.contains(point) }?.corner
    }

    /// Draws the two resize knobs as plain accent-colored filled circles (diameter 8, no inner dot),
    /// centered on each knob's hit rect. Calibrated against ReferenceDesign/TexEditor_8.
    func drawTableResizeKnobs(in ctx: CGContext) {
        let radius: CGFloat = 4
        for knob in tableResizeKnobs() {
            let c = CGPoint(x: knob.rect.midX, y: knob.rect.midY)
            let circle = CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)
            self.mapper.theme.accent.setFill(); UIBezierPath(ovalIn: circle).fill()
        }
    }

    /// Outcome of a tap on `point`: select the hit handle's row/column, or open the menu when that
    /// row/column is already the structural selection. nil if the point isn't on a handle.
    func tableHandleTap(at point: CGPoint) -> TableHandleTap? {
        guard let hit = tableHandle(at: point) else { return nil }
        return tableSelection?.kind == hit ? .menu : .select(hit)
    }

    /// Selects the row range `range` (single-row tap → `r...r`); parks the caret in the range's first
    /// cell so the structural commands resolve to it. The structural selection bypasses the text caret.
    func selectTableRows(_ range: ClosedRange<Int>) {
        finalizeMarkedText()   // deliberate selection change finalizes marked text (uniform invariant)
        clearImageSelection()  // structural selections are mutually exclusive
        guard let a = activeTable(), let pos = a.box.cellTextStart(row: range.lowerBound, column: 0) else { return }
        // Bracket the caret move (like setCaret/selectImage) so the OS re-reads selectedTextRange = the parked
        // cell; without it a hardware Arrow navigates from the STALE prior caret instead of the selected row.
        // TASK 26: unsuppressed selection bracket (this site never consulted the coalescing flag).
        // TASK 39: `applyCaretOutcome` (`+Editing.swift`) inside the UNCHANGED bracket, not
        // `setSelection` — Task 37's population C. This bracket opens no transaction and sets no
        // suppression flag, so a publish takes the full path, and NONE of the three structural
        // selectors calls `onSelectionChange?()` today: a publish would INVENT a host selection report
        // on every row/column/cell selection, not merely double one. Axis 4 of Task 39's divergence
        // audit applies verbatim — the bracket exists BECAUSE these sites never consulted the
        // coalescing flag, and `setSelection` consults it. `selectTableColumns` and `selectTableCells`
        // below are the same line for the same reasons.
        inputBackend.notifyingSelectionChangeIgnoringCoalescing { applyCaretOutcome(.caret(at: pos)) }
        tableSelection = (a.box.id, .rows(range))
        refreshSelectionUI(); setNeedsDisplay()
    }

    func selectTableColumns(_ range: ClosedRange<Int>) {
        finalizeMarkedText()   // deliberate selection change finalizes marked text (uniform invariant)
        clearImageSelection()  // structural selections are mutually exclusive
        guard let a = activeTable(), let pos = a.box.cellTextStart(row: 0, column: range.lowerBound) else { return }
        // see selectTableRows: keep the OS's selectedTextRange in sync
        inputBackend.notifyingSelectionChangeIgnoringCoalescing { applyCaretOutcome(.caret(at: pos)) }   // TASK 39: see selectTableRows
        tableSelection = (a.box.id, .columns(range))
        refreshSelectionUI(); setNeedsDisplay()
    }

    /// Convenience: select a single row / column (the 6d entry points; demo + tests use these).
    func selectTableRow(_ r: Int) { selectTableRows(r...r) }
    func selectTableColumn(_ c: Int) { selectTableColumns(c...c) }

    /// Selects the cell rectangle `rect` (Phase 2c model plumbing — no drawing/gestures yet). `rect` is
    /// EXPANDED against the active table's covering map first (`TableMap.expanded`) so a rect that merely
    /// bisects a merged cell is grown to fully cover it; the caret parks in the expanded rect's top-left
    /// cell. Mirrors `selectTableRows`/`selectTableColumns`.
    func selectTableCells(_ rect: TableRect) {
        finalizeMarkedText()   // deliberate selection change finalizes marked text (uniform invariant)
        clearImageSelection()  // structural selections are mutually exclusive
        guard let a = activeTable() else { return }
        let expanded = a.box.tableMap().expanded(rect)
        guard let pos = a.box.cellTextStart(row: expanded.top, column: expanded.left) else { return }
        // Bracket the caret move (like selectTableRows/selectTableColumns) so the OS re-reads
        // selectedTextRange = the parked cell.
        inputBackend.notifyingSelectionChangeIgnoringCoalescing { applyCaretOutcome(.caret(at: pos)) }   // TASK 39: see selectTableRows
        tableSelection = (a.box.id, .cells(expanded))
        refreshSelectionUI(); setNeedsDisplay()
    }

    /// Convenience: select a single cell.
    func selectTableCell(row: Int, column: Int) {
        selectTableCells(TableRect(top: row, left: column, bottom: row, right: column))
    }

    /// All leaf text regions inside the currently structurally-selected table row or column range, or nil if
    /// there is no structural table selection. Lets a character-format command apply to the whole
    /// row/column (every cell's text) instead of the collapsed caret it parks in.
    func tableStructuralSelectionRegions() -> [LeafTextRegion]? {
        guard let sel = tableSelection,
              let box = boxes.compactMap({ $0 as? TableBlockBox }).first(where: { $0.id == sel.table }) else { return nil }
        switch sel.kind {
        case .rows(let range):
            return range.filter { box.cells.indices.contains($0) }.flatMap { box.cells[$0].flatMap { $0.leafRegions() } }
        case .columns(let range):
            return box.cells.flatMap { row in range.compactMap { row.indices.contains($0) ? row[$0] : nil } }
                            .flatMap { $0.leafRegions() }
        case .cells(let rect):
            return box.tableMap().cellsInRect(rect)
                .compactMap { box.declaredCellStack(atRow: $0.row, column: $0.column) }
                .flatMap { $0.leafRegions() }
        }
    }

    func clearTableSelection() {
        guard tableSelection != nil else { return }
        tableSelection = nil
        refreshSelectionUI(); setNeedsDisplay()
    }

    /// The selected row range, when a row structural selection is active (else nil → commands use the caret row).
    func structuralRowRange() -> ClosedRange<Int>? {
        if let s = tableSelection, case .rows(let r) = s.kind { return r }
        return nil
    }
    /// The selected column range, when a column structural selection is active.
    func structuralColumnRange() -> ClosedRange<Int>? {
        if let s = tableSelection, case .columns(let c) = s.kind { return c }
        return nil
    }
    /// The selected cell rect (already expanded), when a `.cells` structural selection is active.
    func structuralCellRect() -> TableRect? {
        if let s = tableSelection, case .cells(let r) = s.kind { return r }
        return nil
    }

    /// The rect the "cell chrome" (outline + corner knobs) should draw around: a COMMITTED `.cells`
    /// selection's (already-expanded) rect, or — when there is NO committed selection but the caret sits
    /// in a table cell — that cell's covering rect (the whole merged cell if the caret is inside one),
    /// WITHOUT committing `tableSelection` (Phase 2c-T3 "fake" structural chrome). nil when the caret
    /// isn't in a table at all.
    func focusedOrSelectedCellRect() -> TableRect? {
        if let r = structuralCellRect() { return r }
        guard let a = activeTable() else { return nil }
        return a.box.tableMap().coveringRect(atRow: a.row, column: a.col)
    }

    /// The selected row/column/cells range's bounding rect, expanded by the border so its outer edge is
    /// flush with the table's outer border (cells are inset from the grid by `border`). When there is NO
    /// committed `tableSelection` but the caret sits in a table cell, this returns that cell's outline
    /// instead (Phase 2c-T3 "fake" structural chrome — see `focusedOrSelectedCellRect()`) — WITHOUT
    /// committing a selection. nil if there's neither a selection nor a focused cell.
    func tableSelectionOutlineRect() -> CGRect? {
        if let sel = tableSelection, let a = activeTable(), a.box.id == sel.table {
            let rect: TableRect
            switch sel.kind {
            case .rows(let range):
                rect = TableRect(top: range.lowerBound, left: 0, bottom: range.upperBound, right: a.box.columnCount - 1)
            case .columns(let range):
                rect = TableRect(top: 0, left: range.lowerBound, bottom: a.box.rowCount - 1, right: range.upperBound)
            case .cells(let r):
                rect = r
            }
            return cellOutlineRect(rect, in: a.box)
        }
        guard tableSelection == nil, let a = activeTable(), let rect = focusedOrSelectedCellRect() else { return nil }
        return cellOutlineRect(rect, in: a.box)
    }

    /// The canvas-coordinate outline rect for cell-grid rect `rect` in `box`: the union of its top-left
    /// and bottom-right corner `cellRect`s, expanded by the border and offset by the table's horizontal
    /// scroll — shared by every `tableSelectionOutlineRect()` branch (row/column ranges are expressed as
    /// a full-span `TableRect` before reaching here) so they can't drift.
    private func cellOutlineRect(_ rect: TableRect, in box: TableBlockBox) -> CGRect? {
        guard let lo = box.cellRect(row: rect.top, column: rect.left),
              let hi = box.cellRect(row: rect.bottom, column: rect.right) else { return nil }
        return lo.union(hi).insetBy(dx: -box.borderWidth, dy: -box.borderWidth)
            .offsetBy(dx: -box.contentOffsetX, dy: 0)
    }

    /// Which corners of the selection outline round to match the table's rounded OUTER corners. Interior
    /// corners stay square; for `.rows`/`.columns` so do the corners ADJACENT to the selection handle (the
    /// handle bar abuts the outline there with a square edge) — there is no handle for a `.cells` selection
    /// or the focused-cell "fake" chrome, so ALL FOUR corners round wherever they meet the table's actual
    /// outer corner. Empty = a fully-square selection (or nothing selected/focused).
    func tableSelectionOutlineCorners() -> UIRectCorner {
        if let sel = tableSelection, let a = activeTable(), a.box.id == sel.table {
            switch sel.kind {
            case .columns(let range):
                // Column grip sits at the BOTTOM → bottom corners square; round the top corners where the
                // range reaches the table's rounded outer corners.
                var corners: UIRectCorner = []
                if range.lowerBound == 0 { corners.insert(.topLeft) }
                if range.upperBound == a.box.columnCount - 1 { corners.insert(.topRight) }
                return corners
            case .rows(let range):
                // Row grip sits at the LEFT → left corners square; round the right corners.
                var corners: UIRectCorner = []
                if range.lowerBound == 0 { corners.insert(.topRight) }
                if range.upperBound == a.box.rowCount - 1 { corners.insert(.bottomRight) }
                return corners
            case .cells(let rect):
                return cellOutlineCorners(rect, in: a.box)
            }
        }
        guard tableSelection == nil, let a = activeTable(), let rect = focusedOrSelectedCellRect() else { return [] }
        return cellOutlineCorners(rect, in: a.box)
    }

    /// The corners of grid-rect `rect` (in `box`) that meet the table's actual outer corner — shared by
    /// the committed `.cells` and focused-cell "fake" chrome paths.
    private func cellOutlineCorners(_ rect: TableRect, in box: TableBlockBox) -> UIRectCorner {
        var corners: UIRectCorner = []
        if rect.top == 0 && rect.left == 0 { corners.insert(.topLeft) }
        if rect.top == 0 && rect.right == box.columnCount - 1 { corners.insert(.topRight) }
        if rect.bottom == box.rowCount - 1 && rect.left == 0 { corners.insert(.bottomLeft) }
        if rect.bottom == box.rowCount - 1 && rect.right == box.columnCount - 1 { corners.insert(.bottomRight) }
        return corners
    }

    /// Draws the table structural chrome (outline + handles + resize knobs). Called by the chrome overlay
    /// (which sits above the block views) instead of from the canvas's own `draw(_:)`.
    func drawTableChrome(in ctx: CGContext) {
        guard let a = activeTable() else { drawTableChromeLayers(in: ctx); return }
        ctx.saveGState()
        // Clip to the table's visible horizontal band (full height). Extend LEFT past x=0 so the left-gutter row
        // grip stays visible even when it sits at a NEGATIVE x — the composer's zero page margin draws it into
        // the field's left padding (the canvas/scroll/editor are all clipsToBounds=false, so the field's own
        // background is the real left bound). The right edge still clips chrome for scrolled-off columns.
        let leftGutter: CGFloat = 30
        ctx.clip(to: CGRect(x: -leftGutter, y: 0, width: a.box.blockViewFrame.maxX + leftGutter, height: bounds.height))
        drawTableChromeLayers(in: ctx)
        ctx.restoreGState()
    }

    private func drawTableChromeLayers(in ctx: CGContext) {
        drawTableSelectionOutline(in: ctx)
        drawTableHandles(in: ctx)
        drawTableResizeKnobs(in: ctx)
    }

    func drawTableSelectionOutline(in ctx: CGContext) {
        guard let outer = tableSelectionOutlineRect() else { return }
        let lineWidth = DocumentCanvasView.selectionOutlineWidth
        // CG centers a stroke on its path, so inset by half the line width to keep the stroke's OUTER
        // edge flush with the table's outer border (the rect that `tableSelectionOutlineRect` aligns to).
        let rect = outer.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        // Round only the corners meeting the table's rounded outer border (concentric: table radius −
        // the half-line-width inset); interior corners stay square. accent — from TexEditor_8.
        let corners = tableSelectionOutlineCorners()
        let r = max(TableBlockBox.outerCornerRadius - lineWidth / 2, 0)
        let path = corners.isEmpty
            ? UIBezierPath(rect: rect)
            : UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: r, height: r))
        self.mapper.theme.accent.setStroke(); path.lineWidth = lineWidth; path.stroke()
    }

    // tableHandles() returns the handles for the caret's cell; the one matching tableSelection.kind is tinted with the accent color.
    // Row handle = vertical ⋮ (left gutter); column handle = horizontal ••• (below the table).
    func drawTableHandles(in ctx: CGContext) {
        for h in tableHandles() {
            let active = tableSelection?.kind == h.kind
            let horizontal: Bool
            if case .columns = h.kind { horizontal = true } else { horizontal = false }
            drawHandleDots(in: h.rect, active: active, horizontal: horizontal)
        }
    }

    /// Three dots centered in `rect` — along x when `horizontal` (column ⋯), else along y (row ⋮).
    /// When `active` (its row/column is selected) the dots sit on an accent-colored rounded pill and turn
    /// `systemBackground` (white in light) — matching the reference's highlighted handle.
    private func drawHandleDots(in rect: CGRect, active: Bool, horizontal: Bool) {
        if active {
            // accent bar spanning the whole selection (rect = column width / row height), rounded ends
            self.mapper.theme.accent.setFill()
            if horizontal {
                UIBezierPath(roundedRect: rect, byRoundingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: min(rect.width, rect.height), height: min(rect.width, rect.height))).fill()
            } else {
                UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: min(rect.width, rect.height), height: min(rect.width, rect.height))).fill()
            }
        }
        (active ? UIColor.systemBackground : .secondaryLabel).setFill()
        let d: CGFloat = 4, gap: CGFloat = 3
        let cx = rect.midX, cy = rect.midY
        for i in -1...1 {
            let off = CGFloat(i) * (d + gap)
            let x = horizontal ? cx + off : cx
            let y = horizontal ? cy : cy + off
            UIBezierPath(ovalIn: CGRect(x: x - d / 2, y: y - d / 2, width: d, height: d)).fill()
        }
    }

    /// The standard structural-action handler: run a structural command, then clear the selection.
    private func structuralPerform(_ run: @escaping (DocumentCanvasView) -> Void) -> () -> Void {
        { [weak self] in guard let self else { return }; run(self); self.clearTableSelection() }
    }

    /// The alignment descriptor for the current structural selection: per-axis uniform value (nil if the
    /// selected cells disagree) + an `apply` that sets the chosen axes on the selection.
    private func structuralAlignmentDescriptor() -> TableStructuralMenuRequest.Alignment? {
        guard let a = activeTable() else { return nil }
        guard case .table(let t) = a.box.currentBlock() else { return nil }
        let coords = selectedCellCoords(in: a.box).filter { t.rows.indices.contains($0.row) && t.rows[$0.row].cells.indices.contains($0.column) }
        guard !coords.isEmpty else { return nil }
        let hs = Set(coords.map { t.rows[$0.row].cells[$0.column].horizontalAlignment })
        let vs = Set(coords.map { t.rows[$0.row].cells[$0.column].verticalAlignment })
        return TableStructuralMenuRequest.Alignment(
            horizontal: hs.count == 1 ? hs.first : nil,
            vertical: vs.count == 1 ? vs.first : nil,
            apply: { [weak self] h, v in self?.setSelectionAlignment(horizontal: h, vertical: v) })
    }

    /// The header descriptor for the current structural selection: the uniform per-cell header value
    /// (nil if the selected cells disagree) + an `apply` that toggles it on all selected cells.
    private func structuralHeaderDescriptor() -> TableStructuralMenuRequest.Header? {
        guard let a = activeTable() else { return nil }
        guard case .table(let t) = a.box.currentBlock() else { return nil }
        let coords = selectedCellCoords(in: a.box).filter { t.rows.indices.contains($0.row) && t.rows[$0.row].cells.indices.contains($0.column) }
        guard !coords.isEmpty else { return nil }
        let flags = Set(coords.map { t.rows[$0.row].cells[$0.column].isHeader })
        return TableStructuralMenuRequest.Header(
            isHeader: flags.count == 1 ? flags.first : nil,
            apply: { [weak self] in self?.toggleSelectionHeader() })
    }

    /// The structural row/column menu, described for the host to present its own menu. nil when there is
    /// no structural selection. `view`/`sourceRect` anchor to the active handle, in canvas coordinates.
    func tableStructuralMenuRequest() -> TableStructuralMenuRequest? {
        guard let sel = tableSelection, let a = activeTable(), a.box.id == sel.table else { return nil }
        let sourceRect = tableHandles().first { $0.kind == sel.kind }?.rect ?? .zero
        switch sel.kind {
        case .columns(let range):
            var actions: [TableStructuralMenuRequest.Action] = [
                .init(kind: .addColumnLeft, perform: structuralPerform { $0.insertTableColumnLeft() }),
                .init(kind: .addColumnRight, perform: structuralPerform { $0.insertTableColumnRight() }),
            ]
            // Hide Delete when the range covers every column (deleting all would empty the table).
            let coversAll = range.lowerBound == 0 && range.upperBound == a.box.columnCount - 1
            if !coversAll {
                actions.append(.init(kind: .deleteColumn, perform: structuralPerform { $0.deleteTableColumn() }))
            }
            let alignment = structuralAlignmentDescriptor()
            return TableStructuralMenuRequest(view: self, sourceRect: sourceRect, actions: actions, alignment: alignment, header: structuralHeaderDescriptor())
        case .rows(let range):
            let includesHeader = range.contains { a.box.isHeaderRow($0) }
            let hasBodyRow = range.contains { a.box.cells.indices.contains($0) && !a.box.isHeaderRow($0) }
            var actions: [TableStructuralMenuRequest.Action] = []
            if !includesHeader {                       // can't insert above the header
                actions.append(.init(kind: .addRowAbove, perform: structuralPerform { $0.insertTableRowAbove() }))
            }
            actions.append(.init(kind: .addRowBelow, perform: structuralPerform { $0.insertTableRowBelow() }))
            if hasBodyRow {                             // at least one deletable (non-header) row
                actions.append(.init(kind: .deleteRow, perform: structuralPerform { $0.deleteTableRow() }))
            }
            return TableStructuralMenuRequest(view: self, sourceRect: sourceRect, actions: actions, alignment: structuralAlignmentDescriptor(), header: structuralHeaderDescriptor())
        case .cells(let rect):
            let map = a.box.tableMap()
            let anchors = map.cellsInRect(rect)
            var actions: [TableStructuralMenuRequest.Action] = []
            if anchors.count >= 2 {
                actions.append(.init(kind: .mergeCells, perform: structuralPerform { $0.mergeSelectedCells() }))
            }
            if anchors.count == 1, let only = anchors.first, only.colspan > 1 || only.rowspan > 1 {
                actions.append(.init(kind: .splitCell, perform: structuralPerform { $0.splitSelectedCell() }))
            }
            // T4: anchor sourceRect to the cell-selection outline (tableHandles() has no `.cells` entry, so
            // the handle-based sourceRect computed above is always .zero for this branch).
            let cellsSourceRect = tableSelectionOutlineRect() ?? sourceRect
            return TableStructuralMenuRequest(view: self, sourceRect: cellsSourceRect, actions: actions, alignment: structuralAlignmentDescriptor(), header: structuralHeaderDescriptor())
        }
    }

    /// Moves the structural selection's `end` knob to the row/column under `point`, keeping the other
    /// end fixed. The dragged end cannot cross the fixed end (minimum range width 1; no swap); both are
    /// bounded to the grid. Live (`setNeedsDisplay`) for outline/knob/bar feedback.
    func extendTableSelection(end: TableRangeEnd, toward point: CGPoint) {
        guard let sel = tableSelection,
              let box = boxes.compactMap({ $0 as? TableBlockBox }).first(where: { $0.id == sel.table }) else { return }
        switch sel.kind {
        case .rows(let range):
            if end == .upper {
                let fixed = range.lowerBound
                let moved = max(min(box.rowIndex(atY: point.y), box.rowCount - 1), fixed)
                tableSelection = (sel.table, .rows(fixed...moved))
            } else {
                let fixed = range.upperBound
                let moved = min(max(box.rowIndex(atY: point.y), 0), fixed)
                tableSelection = (sel.table, .rows(moved...fixed))
            }
        case .columns(let range):
            let x = point.x + box.contentOffsetX
            if end == .upper {
                let fixed = range.lowerBound
                let moved = max(min(box.columnIndex(atX: x), box.columnCount - 1), fixed)
                tableSelection = (sel.table, .columns(fixed...moved))
            } else {
                let fixed = range.upperBound
                let moved = min(max(box.columnIndex(atX: x), 0), fixed)
                tableSelection = (sel.table, .columns(moved...fixed))
            }
        case .cells:
            break   // Phase 2c-T4: cell-rect knob-drag resize is `extendCellSelection`, wired at the gesture handler
        }
        setNeedsDisplay()
    }

    /// Drags a `.cells` corner knob, extending (or, from the focused-cell "fake" chrome, PROMOTING to) a
    /// committed `.cells` selection (Phase 2c-T4). The FIXED corner is the CURRENT rect's corner OPPOSITE
    /// `corner` — the current rect is the committed `.cells` selection if one exists, else the focused
    /// cell's covering rect (`focusedOrSelectedCellRect()`), which is how a drag starting from the fake
    /// chrome (no committed selection) promotes on its very first update. The moved cell is the PHYSICAL
    /// grid slot under `point` (`rowIndex(atY:)`/`columnIndex(atX:)` — span-neutral, already clamped to the
    /// grid). The new rect is the min/max of the fixed and moved cells on both axes, then
    /// `TableMap.expanded` so it never bisects a merged cell. Live (`setNeedsDisplay`) like
    /// `extendTableSelection`; the caret is left where it is (the selection's committed rect is what the
    /// chrome/menu read).
    func extendCellSelection(corner: TableCellCorner, toward point: CGPoint) {
        guard let a = activeTable(), let currentRect = focusedOrSelectedCellRect() else { return }
        let box = a.box
        let fixedRow: Int, fixedCol: Int
        switch corner {
        case .topLeft:     fixedRow = currentRect.bottom; fixedCol = currentRect.right
        case .topRight:    fixedRow = currentRect.bottom; fixedCol = currentRect.left
        case .bottomLeft:  fixedRow = currentRect.top;    fixedCol = currentRect.right
        case .bottomRight: fixedRow = currentRect.top;    fixedCol = currentRect.left
        }
        let movedRow = box.rowIndex(atY: point.y)
        let movedCol = box.columnIndex(atX: point.x + box.contentOffsetX)
        let rect = TableRect(top: min(fixedRow, movedRow), left: min(fixedCol, movedCol),
                              bottom: max(fixedRow, movedRow), right: max(fixedCol, movedCol))
        tableSelection = (box.id, .cells(box.tableMap().expanded(rect)))
        setNeedsDisplay()
    }

    /// Demo helper: place the caret in the first table's (0,0) cell and select column 0 (shows handles + outline).
    func selectFirstTableColumn() {
        guard let t = boxes.compactMap({ $0 as? TableBlockBox }).first,
              let pos = t.cellTextStart(row: 0, column: 0) else { return }
        // TASK 39: applied IMMEDIATELY (not returned — there is no `editing { }` here at all), because
        // `selectTableColumn(0)` on the next line resolves `activeTable()` through
        // `cellLocation(containing: head)` and would otherwise see the PRE-move caret.
        applyCaretOutcome(.caret(at: pos))
        selectTableColumn(0)
    }
}
#endif
