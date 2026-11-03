#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The grid a table's cells are laid out on. Pure: the table, the width, and each cell's used text
/// height in; every cell's rect, its text insets and the table's extent out.
///
/// Every rule and every number is the legacy `TableBlockBox`'s — `solveColumnWidths`,
/// `cellContentWidth`, `solveRowHeights` — transcribed rather than reused because the box is a
/// TextKit layout and cannot be instantiated without one. Columns are PROPORTIONAL to
/// `ColumnSpec.width` and floored, not content-sized; overflow past the available width is what
/// makes a table scroll. Spans resolve through Core's `TableMap`, which clamps them to the grid.
@available(iOS 18.4, *)
internal struct EngineTableGrid: Equatable {
    internal struct CellGeometry: Equatable {
        internal let cellID: BlockID
        internal let row: Int
        internal let column: Int
        /// The whole cell — what the engine hit-tests — borders excluded, relative to the table's
        /// top-left corner.
        internal let rect: CGRect
        /// What the cell's engine block should carry as `blockInsets`: applied INSIDE the frame.
        /// `bottom` is always 0; the row height already contains the bottom padding.
        internal let textInsets: UIEdgeInsets
    }

    internal let cells: [CellGeometry]
    internal let columnWidths: [CGFloat]
    internal let rowHeights: [CGFloat]
    internal let size: CGSize
    internal let borderWidth: CGFloat

    internal static let minColumnWidth: CGFloat = 100
    internal static let border: CGFloat = 1
    internal static let cellPadding: CGFloat = 6
    internal static let cellVerticalPadding: CGFloat = 14
    internal static let outerCornerRadius: CGFloat = 8

    internal func cell(withID id: BlockID) -> CellGeometry? { cells.first { $0.cellID == id } }

    /// How much wider than its rect a cell's placed FRAME is, so the run holds the table's trailing
    /// border: `borderWidth` for a cell that reaches the last column, else 0. The engine's run is the
    /// union of the placed frames, and the outer border lies outside every cell — so the last column's
    /// right border could never scroll into view (K3, 2026-09-11). The same amount goes on the cell's
    /// right inset, so its text column is unchanged; both sites read it from HERE.
    internal func trailingBorderExtension(for geometry: CellGeometry) -> CGFloat {
        geometry.rect.maxX >= size.width - borderWidth - 0.5 ? borderWidth : 0
    }

    internal static func columnWidths(for table: TableBlock, availableWidth: CGFloat) -> [CGFloat] {
        let count = table.columnCount
        guard count > 0 else { return [] }
        let border = table.bordered ? Self.border : 0
        let borders = CGFloat(count + 1) * border
        let avail = max(availableWidth - borders, CGFloat(count))
        let sum = table.columns.reduce(0.0) { $0 + CGFloat($1.width) }
        let fit: [CGFloat]
        if sum <= 0 { fit = Array(repeating: avail / CGFloat(count), count: count) }
        else { let scale = avail / sum; fit = table.columns.map { CGFloat($0.width) * scale } }
        if fit.allSatisfy({ $0 >= minColumnWidth }) { return fit }
        return fit.map { max($0, minColumnWidth) }
    }

    internal static func solve(table: TableBlock, availableWidth: CGFloat,
                               usedHeights: [BlockID: CGFloat]) -> EngineTableGrid {
        let border = table.bordered ? Self.border : 0
        let padding = table.compact ? cellPadding / 2 : cellPadding
        let verticalPadding = table.compact ? cellVerticalPadding / 2 : cellVerticalPadding
        let widths = columnWidths(for: table, availableWidth: availableWidth)
        let map = TableMap(table)
        var anchorByID: [BlockID: TableMap.Anchor] = [:]
        for anchor in map.anchors { anchorByID[anchor.cellID] = anchor }

        func spanned(_ values: [CGFloat], from start: Int, count: Int) -> CGFloat {
            let upper = min(start + max(count, 1), values.count)
            guard start >= 0, start < upper else { return 0 }
            return values[start..<upper].reduce(0, +) + CGFloat(upper - start - 1) * border
        }

        // Row heights: the tallest cell + padding, a declared minimum, then rowspans that still
        // do not fit grow the LAST row they span — `solveRowHeights` verbatim.
        var heights: [CGFloat] = table.rows.map { CGFloat($0.height ?? 0) }
        var pending: [(row: Int, rowspan: Int, height: CGFloat)] = []
        for (r, row) in table.rows.enumerated() {
            for cell in row.cells {
                guard let anchor = anchorByID[cell.id] else { continue }
                let cellHeight = (usedHeights[cell.id] ?? 0) + verticalPadding * 2
                if anchor.rowspan <= 1 { heights[r] = max(heights[r], cellHeight) }
                else { pending.append((anchor.row, anchor.rowspan, cellHeight)) }
            }
        }
        for item in pending {
            let lastRow = min(item.row + item.rowspan - 1, heights.count - 1)
            guard item.row >= 0, item.row <= lastRow else { continue }
            let spannedHeight = (item.row...lastRow).reduce(CGFloat(0)) { $0 + heights[$1] }
                + CGFloat(lastRow - item.row) * border
            if item.height > spannedHeight { heights[lastRow] += item.height - spannedHeight }
        }

        var columnLeft: [CGFloat] = []
        var x = border
        for width in widths { columnLeft.append(x); x += width + border }
        var rowTop: [CGFloat] = []
        var y = border
        for height in heights { rowTop.append(y); y += height + border }

        var cells: [CellGeometry] = []
        for (r, row) in table.rows.enumerated() {
            for cell in row.cells {
                guard let anchor = anchorByID[cell.id],
                      columnLeft.indices.contains(anchor.column), rowTop.indices.contains(anchor.row) else { continue }
                let rect = CGRect(x: columnLeft[anchor.column], y: rowTop[anchor.row],
                                  width: spanned(widths, from: anchor.column, count: anchor.colspan),
                                  height: spanned(heights, from: anchor.row, count: anchor.rowspan))
                let used = usedHeights[cell.id] ?? 0
                let free = max(0, rect.height - verticalPadding * 2 - used)
                let extra: CGFloat
                switch cell.verticalAlignment {
                case .top: extra = 0
                case .middle: extra = free / 2
                case .bottom: extra = free
                }
                // Right = padding + the border, mirroring `cellContentWidth`'s extra subtraction.
                cells.append(CellGeometry(cellID: cell.id, row: r, column: anchor.column, rect: rect,
                                          textInsets: UIEdgeInsets(top: verticalPadding + extra, left: padding,
                                                                   bottom: 0, right: padding + border)))
            }
        }
        return EngineTableGrid(cells: cells, columnWidths: widths, rowHeights: heights,
                               size: CGSize(width: x, height: y), borderWidth: border)
    }
}
#endif
