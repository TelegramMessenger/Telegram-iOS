#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A whole-row, whole-column, or arbitrary cell-rect selection within one table.
///
/// The engine's OWN enum: legacy's `TableStructuralSelection` is internal to `Canvas/`, which this
/// branch does not edit — the same call `EnginePasteboard` made in rung A. `TableRect` and `TableMap`
/// ARE public Core, so the merged-cell safety is shared rather than re-derived.
///
/// `.cells` is always stored ALREADY EXPANDED (`TableMap.expanded`), at every site that writes one, so
/// no consumer can be handed a rect that half-covers a merged anchor.
internal enum EngineTableStructuralSelection: Equatable {
    case rows(ClosedRange<Int>)
    case columns(ClosedRange<Int>)
    case cells(TableRect)
}

/// Which end of a row/column range a resize knob moves.
internal enum TableRangeEnd: Equatable { case lower, upper }

/// Which corner of a cell-rect outline a knob sits at and would drag.
internal enum TableCellCorner: Equatable { case topLeft, topRight, bottomLeft, bottomRight }

/// Where a table's structural chrome goes: the two grips, the resize knobs, and the selection
/// outline. A pure struct over the grid solver's numbers — no view, no engine — the way
/// `EngineBlockSpacing` is a free function over roles. That is the only reason those rules could be
/// pinned at all: geometry that needs a live editor can only be tested through one.
///
/// **Every rect is TABLE-LOCAL**: the grid's own space, the table's top-left at the origin. The view
/// applies the table's origin and the horizontal scroll offset, and applies the latter to the column
/// grip and the outline but NOT to the row grip — the asymmetry legacy encodes, and the reason the
/// view is parented into the engine rather than the run's scrolling content.
@available(iOS 18.4, *)
internal struct EngineTableStructuralChrome {
    /// Legacy's constants, carried over verbatim (`DocumentCanvasView+TableControls.swift`).
    internal static let gripWidth: CGFloat = 17
    /// How far the row grip's right edge tucks UNDER the table's left border, so the grip is always
    /// drawn to the left of the table — even at zero page margin, where it draws into the host's own
    /// padding rather than over the first column.
    internal static let gripTuck: CGFloat = 2
    internal static let gripHeight: CGFloat = 17
    /// How far a grip reaches outside the table: its width less the part tucked under the border.
    /// The room a table has to leave for its chrome on each side, and the one number the host's
    /// gutter, the chrome view's own offsets and the clip all read.
    internal static let gripGutter: CGFloat = gripWidth - gripTuck
    /// The three dots a grip actually shows — legacy's `drawHandleDots`, verbatim: a row grip is a
    /// vertical ⋮ in the left gutter, a column grip a horizontal ⋯ below the table, and the accent
    /// BAR appears only while that row or column is the structural selection.
    internal static let gripDotDiameter: CGFloat = 4
    internal static let gripDotGap: CGFloat = 3
    /// A generous square hit/anchor box, centred on the knob.
    internal static let knobHitSide: CGFloat = 44
    /// The drawn knob: a circle of this radius, centred on the outline.
    internal static let knobRadius: CGFloat = 4
    /// How far the chrome view reaches past the table's top and right borders, so a knob ON one of
    /// them is drawn whole: `draw` cannot paint outside its own bounds, and the knobs on the top and
    /// right borders were cut in half (K3, 2026-09-11). The left has the row grip's gutter and the
    /// bottom the column grip's band already.
    internal static let knobOverhang: CGFloat = knobRadius + 1
    /// Shared by the outline stroke and the knob anchors, so a knob centres ON the drawn line rather
    /// than half a line-width outside it.
    internal static let outlineWidth: CGFloat = 2

    internal let grid: EngineTableGrid
    internal let rowCount: Int
    internal let columnCount: Int
    internal let selection: EngineTableStructuralSelection?
    /// The caret's covering rect, or the committed `.cells` rect. Supplied by the caller rather than
    /// derived here — a pure struct has no caret to ask.
    internal let focusedCell: TableRect?

    internal init(grid: EngineTableGrid, rowCount: Int, columnCount: Int,
                  selection: EngineTableStructuralSelection?, focusedCell: TableRect?) {
        self.grid = grid
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.selection = selection
        self.focusedCell = focusedCell
    }

    // MARK: - Slots

    /// One grid SLOT's rect, computed from the solver's column widths and row heights rather than
    /// looked up among the placed cells: a slot inside a merged cell has no `CellGeometry` of its own,
    /// so a lookup would answer nil exactly where a span makes the question interesting.
    private func slotRect(row: Int, column: Int) -> CGRect? {
        guard grid.rowHeights.indices.contains(row), grid.columnWidths.indices.contains(column) else { return nil }
        let border = grid.borderWidth
        let x = border + grid.columnWidths[0 ..< column].reduce(0, +) + CGFloat(column) * border
        let y = border + grid.rowHeights[0 ..< row].reduce(0, +) + CGFloat(row) * border
        return CGRect(x: x, y: y, width: grid.columnWidths[column], height: grid.rowHeights[row])
    }

    /// The grid rect the chrome surrounds: a row range spans every column, a column range every row.
    private func activeRect() -> TableRect? {
        switch selection {
        case let .rows(range):
            return TableRect(top: range.lowerBound, left: 0, bottom: range.upperBound, right: columnCount - 1)
        case let .columns(range):
            return TableRect(top: 0, left: range.lowerBound, bottom: rowCount - 1, right: range.upperBound)
        case let .cells(rect):
            return rect
        case nil:
            return focusedCell
        }
    }

    private func rowRange() -> ClosedRange<Int>? {
        if case let .rows(range) = selection { return range }
        return focusedCell.map { $0.top ... $0.bottom }
    }

    private func columnRange() -> ClosedRange<Int>? {
        if case let .columns(range) = selection { return range }
        return focusedCell.map { $0.left ... $0.right }
    }

    // MARK: - Hit resolution

    /// The row containing a table-local y, clamped to the grid. Span-neutral: it answers about the
    /// physical slot, which is what a drag moves over.
    internal func rowIndex(atY y: CGFloat) -> Int {
        let border = grid.borderWidth
        var top = border
        for (index, height) in grid.rowHeights.enumerated() {
            if y < top + height { return index }
            top += height + border
        }
        return max(grid.rowHeights.count - 1, 0)
    }

    /// The column containing a table-local x, clamped to the grid.
    internal func columnIndex(atX x: CGFloat) -> Int {
        let border = grid.borderWidth
        var left = border
        for (index, width) in grid.columnWidths.enumerated() {
            if x < left + width { return index }
            left += width + border
        }
        return max(grid.columnWidths.count - 1, 0)
    }

    // MARK: - The chrome

    /// Which side of the table a grip hangs off. It decides the grip's identity across passes, which
    /// way its dots run, and which two corners its selected bar rounds — the row grips are a mirrored
    /// PAIR, so nothing else tells them apart.
    internal enum HandleSide {
        case leading, trailing, below
    }

    /// The row grips — one in the gutter on EACH side of the table — and the column grip below it.
    /// Each spans the active structural RANGE on its own axis, or the focused cell's extent when that
    /// axis is not the one selected (legacy's `structuralRowRange() ?? (a.row...a.row)`).
    ///
    /// Every one of them rides the table's horizontal scroll, the row grips included. They are
    /// anchored to the table's own left and right edges, so on a wide table the leading grip leaves
    /// with the first column and the trailing one arrives with the last: the gutter a grip sits in
    /// belongs to the table, not to the viewport.
    internal func handles() -> [(rect: CGRect, kind: EngineTableStructuralSelection, side: HandleSide)] {
        let border = grid.borderWidth
        var result: [(rect: CGRect, kind: EngineTableStructuralSelection, side: HandleSide)] = []
        if let rows = rowRange(),
           let top = slotRect(row: rows.lowerBound, column: 0),
           let bottom = slotRect(row: rows.upperBound, column: 0) {
            let y = top.minY - border
            let height = bottom.maxY + border - y
            // Tucked `gripTuck` under the table's own border on each side, so a grip is always
            // OUTSIDE the cells it selects however narrow the host's margin is.
            result.append((CGRect(x: Self.gripTuck - Self.gripWidth, y: y,
                                  width: Self.gripWidth, height: height),
                           .rows(rows), .leading))
            result.append((CGRect(x: grid.size.width - Self.gripTuck, y: y,
                                  width: Self.gripWidth, height: height),
                           .rows(rows), .trailing))
        }
        if let columns = columnRange(),
           let leading = slotRect(row: 0, column: columns.lowerBound),
           let trailing = slotRect(row: 0, column: columns.upperBound) {
            let x = leading.minX - border
            result.append((CGRect(x: x, y: grid.size.height,
                                  width: trailing.maxX + border - x, height: Self.gripHeight),
                           .columns(columns), .below))
        }
        return result
    }

    /// TWO knobs at a row/column range's ends; FOUR for a cell rect or the focused cell.
    ///
    /// The four are drawn at the CENTRE OF EACH SIDE and each keeps its corner identity, so the 2D
    /// drag — which pins the OPPOSITE corner — is unchanged and only the anchor moves.
    internal func knobs() -> [(rect: CGRect, end: TableRangeEnd?, corner: TableCellCorner?)] {
        guard let raw = outlineRect() else { return [] }
        let outline = raw.insetBy(dx: Self.outlineWidth / 2, dy: Self.outlineWidth / 2)
        func box(_ centre: CGPoint) -> CGRect {
            CGRect(x: centre.x - Self.knobHitSide / 2, y: centre.y - Self.knobHitSide / 2,
                   width: Self.knobHitSide, height: Self.knobHitSide)
        }
        switch selection {
        case .rows:
            let x = outline.midX
            return [(box(CGPoint(x: x, y: outline.minY)), .lower, nil),
                    (box(CGPoint(x: x, y: outline.maxY)), .upper, nil)]
        case .columns:
            let y = outline.midY
            return [(box(CGPoint(x: outline.minX, y: y)), .lower, nil),
                    (box(CGPoint(x: outline.maxX, y: y)), .upper, nil)]
        case .cells, nil:
            return [(box(CGPoint(x: outline.midX, y: outline.minY)), nil, .topLeft),
                    (box(CGPoint(x: outline.maxX, y: outline.midY)), nil, .topRight),
                    (box(CGPoint(x: outline.minX, y: outline.midY)), nil, .bottomLeft),
                    (box(CGPoint(x: outline.midX, y: outline.maxY)), nil, .bottomRight)]
        }
    }

    /// The union of the active rect's corner slots, grown by the border — one helper for all three
    /// selection kinds, so they cannot drift.
    internal func outlineRect() -> CGRect? {
        guard let rect = activeRect(),
              let topLeft = slotRect(row: rect.top, column: rect.left),
              let bottomRight = slotRect(row: rect.bottom, column: rect.right) else { return nil }
        return topLeft.union(bottomRight).insetBy(dx: -grid.borderWidth, dy: -grid.borderWidth)
    }

    /// Which corners round to match the table's own rounded outer corners. Interior corners stay
    /// square — and so do the corners ADJACENT TO A GRIP, because the grip's bar abuts them with a
    /// square edge. A cell rect and the focused cell have no grip on their own axis, so all four
    /// round wherever they reach the table's real corner.
    internal func outlineCorners() -> UIRectCorner {
        switch selection {
        case .rows:
            // NONE. A row selection is flanked by a grip on BOTH sides now, and a rounded outline
            // corner against a bar's square edge reads as a notch — which is what the right-hand
            // corners did once the mirrored grip arrived (K3, 2026-09-11). The left-hand pair has
            // been square for this reason since the grip existed; this is the same rule, applied to
            // the side that grew one.
            return []
        case let .columns(range):
            var corners: UIRectCorner = []
            if range.lowerBound == 0 { corners.insert(.topLeft) }
            if range.upperBound == columnCount - 1 { corners.insert(.topRight) }
            return corners
        case let .cells(rect):
            return cornersMeetingTheTable(rect)
        case nil:
            guard let focusedCell else { return [] }
            return cornersMeetingTheTable(focusedCell)
        }
    }

    private func cornersMeetingTheTable(_ rect: TableRect) -> UIRectCorner {
        var corners: UIRectCorner = []
        if rect.top == 0, rect.left == 0 { corners.insert(.topLeft) }
        if rect.top == 0, rect.right == columnCount - 1 { corners.insert(.topRight) }
        if rect.bottom == rowCount - 1, rect.left == 0 { corners.insert(.bottomLeft) }
        if rect.bottom == rowCount - 1, rect.right == columnCount - 1 { corners.insert(.bottomRight) }
        return corners
    }
}
#endif
