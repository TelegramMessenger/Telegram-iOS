import Foundation

public struct TableRect: Equatable {
    public let top: Int
    public let left: Int
    public let bottom: Int
    public let right: Int
    public init(top: Int, left: Int, bottom: Int, right: Int) {
        self.top = top; self.left = left; self.bottom = bottom; self.right = right
    }
}

/// A covering map for a `TableBlock`, resolving grid-slot ↔ cell anchor over a table that may contain
/// merged (colspan/rowspan) cells. Built once from a `TableBlock` snapshot; pure value type, no back-reference
/// to the table. The covering grid is `table.rows.count × table.columns.count`; each `Cell` occupies exactly
/// one rectangular footprint (`colspan × rowspan`) anchored at its top-left origin slot.
public struct TableMap: Equatable {
    /// One cell's placement in the covering grid.
    public struct Anchor: Equatable {
        public let cellID: BlockID
        /// Origin (top-left) row in covering coordinates.
        public let row: Int
        /// Origin (top-left) column in covering coordinates.
        public let column: Int
        public let colspan: Int
        public let rowspan: Int
    }

    public let tableID: BlockID
    public let rows: Int
    public let columns: Int
    /// One entry per `Cell`, row-major by origin (== declaration order in `table.rows[*].cells`).
    public let anchors: [Anchor]
    /// Length `rows*columns`; value is an index into `anchors`, or -1 if the slot is uncovered
    /// (only possible for a malformed table).
    private let slotOwner: [Int]
    public let isWellFormed: Bool

    public init(_ table: TableBlock) {
        self.tableID = table.id
        let rows = table.rowCount
        let columns = table.columnCount
        self.rows = rows
        self.columns = columns

        var occupied = Array(repeating: Array(repeating: false, count: max(columns, 0)), count: max(rows, 0))
        var slotOwner = Array(repeating: -1, count: max(rows, 0) * max(columns, 0))
        var anchors: [Anchor] = []
        var anyClamped = false

        if rows > 0 && columns > 0 {
            for r in 0..<rows {
                var c = 0
                for tableCell in table.rows[r].cells {
                    while c < columns && occupied[r][c] {
                        c += 1
                    }
                    if c >= columns {
                        // No room left on this row for this cell — malformed input (row declares more
                        // cells than fit). Drop it rather than crash.
                        anyClamped = true
                        continue
                    }

                    let requestedColspan = max(tableCell.colspan, 1)
                    let requestedRowspan = max(tableCell.rowspan, 1)
                    let colspan = min(requestedColspan, columns - c)
                    let rowspan = min(requestedRowspan, rows - r)
                    if colspan != requestedColspan || rowspan != requestedRowspan {
                        anyClamped = true
                    }

                    let anchorIndex = anchors.count
                    anchors.append(Anchor(cellID: tableCell.id, row: r, column: c, colspan: colspan, rowspan: rowspan))

                    for rr in r..<(r + rowspan) {
                        for cc in c..<(c + colspan) {
                            occupied[rr][cc] = true
                            slotOwner[rr * columns + cc] = anchorIndex
                        }
                    }

                    c += colspan
                }
            }
        }

        self.anchors = anchors
        self.slotOwner = slotOwner

        let noUncoveredSlots = !slotOwner.contains(-1)
        self.isWellFormed = noUncoveredSlots && !anyClamped
    }

    public func anchor(atRow r: Int, column c: Int) -> Anchor? {
        guard r >= 0, r < rows, c >= 0, c < columns else { return nil }
        let idx = slotOwner[r * columns + c]
        guard idx >= 0, idx < anchors.count else { return nil }
        return anchors[idx]
    }

    public func coveringRect(atRow r: Int, column c: Int) -> TableRect? {
        guard let a = anchor(atRow: r, column: c) else { return nil }
        return TableRect(top: a.row, left: a.column, bottom: a.row + a.rowspan - 1, right: a.column + a.colspan - 1)
    }

    /// Distinct anchors intersecting `rect`, row-major, each returned exactly once.
    public func cellsInRect(_ rect: TableRect) -> [Anchor] {
        guard rect.top <= rect.bottom, rect.left <= rect.right else { return [] }
        var seen = Set<Int>()
        var out: [Anchor] = []
        let top = max(rect.top, 0)
        let bottom = min(rect.bottom, rows - 1)
        let left = max(rect.left, 0)
        let right = min(rect.right, columns - 1)
        guard top <= bottom, left <= right else { return [] }
        for r in top...bottom {
            for c in left...right {
                let idx = slotOwner[r * columns + c]
                guard idx >= 0, idx < anchors.count else { continue }
                if seen.insert(idx).inserted {
                    out.append(anchors[idx])
                }
            }
        }
        return out
    }

    /// Grows `rect` until no anchor's footprint straddles one of its edges (a fixed-point loop: an edge
    /// growing on one axis can pull in an anchor that then straddles the other axis).
    public func expanded(_ rect: TableRect) -> TableRect {
        var current = rect
        var changed = true
        while changed {
            changed = false
            var top = current.top, left = current.left, bottom = current.bottom, right = current.right
            for a in anchors {
                let aTop = a.row, aLeft = a.column
                let aBottom = a.row + a.rowspan - 1
                let aRight = a.column + a.colspan - 1
                // Does this anchor's footprint overlap the current rect at all?
                let overlaps = aTop <= current.bottom && aBottom >= current.top && aLeft <= current.right && aRight >= current.left
                guard overlaps else { continue }
                if aTop < top { top = aTop }
                if aLeft < left { left = aLeft }
                if aBottom > bottom { bottom = aBottom }
                if aRight > right { right = aRight }
            }
            let next = TableRect(top: top, left: left, bottom: bottom, right: right)
            if next != current {
                current = next
                changed = true
            }
        }
        return current
    }
}
