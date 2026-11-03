import Foundation

/// Pure structural transforms on a `TableBlock`. Each returns a new value that preserves the grid
/// invariant (`columnCount` == every row's `cells.count`), generates fresh `BlockID`s for new
/// rows/cells, and gives each new cell one empty paragraph. New rows are body rows. The UIKit
/// command layer applies these then rebuilds the `TableBlockBox`.
extension TableBlock {
    private static func emptyCell(isHeader: Bool = false) -> Cell {
        Cell(id: BlockID.generate(), blocks: [.paragraph(ParagraphBlock(id: BlockID.generate()))], isHeader: isHeader)
    }

    /// A fresh empty table: `rows`×`columns` (each clamped to ≥1), row 0 a mandatory header, the rest
    /// body rows, every cell one empty paragraph, equal column widths. The insert-table command builds
    /// this then wraps it in a `TableBlockBox`.
    public static func empty(rows: Int, columns: Int) -> TableBlock {
        let nCols = max(columns, 1)
        let nRows = max(rows, 1)
        let cols = (0..<nCols).map { _ in ColumnSpec(width: 100) }
        let rowsArr: [Row] = (0..<nRows).map { r in
            Row(id: BlockID.generate(), isHeader: r == 0,
                cells: (0..<nCols).map { _ in TableBlock.emptyCell() })
        }
        return TableBlock(id: BlockID.generate(), columns: cols, rows: rowsArr)
    }

    /// Inserts a `Row` at covering-row coordinate `ri`, span-aware — the transpose of `insertingColumn`.
    /// An anchor whose footprint STRADDLES the new boundary (`anchor.row < ri <= anchor.row + rowspan -
    /// 1`) simply grows its `rowspan` by 1 (the new row falls inside that cell — it now covers the extra
    /// row, so no fresh cell is declared for the columns it occupies). Every column where `ri` is a CLEAN
    /// boundary — the covering slot at `(ri, c)` is some anchor's own ORIGIN row, or `ri` is the bottom
    /// edge (`ri == rows.count`, i.e. appending) — gets a fresh `emptyCell()` in the new row. Unlike
    /// `insertingColumn` (which splices a cell into every EXISTING row), this creates exactly ONE new
    /// `Row`, so no declaration-index bookkeeping is needed: the clean-boundary columns are visited in
    /// ascending order and appended straight into the new row's `cells`. The new row is always a plain
    /// body row (`isHeader: false`, matching the pre-span behavior) — there is no existing row to inherit
    /// header status from.
    public func insertingRow(at index: Int) -> TableBlock {
        let map = TableMap(self)
        var t = self
        let ri = min(max(index, 0), t.rows.count)

        // Grow every anchor whose footprint straddles the new boundary.
        for anchor in map.anchors {
            let anchorBottom = anchor.row + anchor.rowspan - 1
            guard anchor.row < ri, ri <= anchorBottom else { continue }
            guard let loc = TableBlock.location(of: anchor.cellID, in: t) else { continue }
            t.rows[loc.row].cells[loc.index].rowspan += 1
        }

        // The new row gets a fresh cell for each column where ri is a clean boundary (not interior to a
        // straddling rowspan cell already grown above).
        var newCells: [Cell] = []
        for c in 0..<t.columnCount {
            let isCleanBoundary = ri >= map.rows || map.anchor(atRow: ri, column: c)?.row == ri
            guard isCleanBoundary else { continue }
            newCells.append(TableBlock.emptyCell())
        }
        t.rows.insert(Row(id: BlockID.generate(), isHeader: false, cells: newCells), at: ri)
        return t
    }

    /// Removes the `Row` at covering-row coordinate `ri`, span-aware — the transpose of `removingColumn`,
    /// with one added wrinkle: a `Cell` lives inside its declaring `Row`'s `cells` array, so — unlike a
    /// column removal, which never has to relocate a cell to a different row — deleting the ROW that a
    /// surviving (`rowspan > 1`) cell ORIGINATES in would silently discard that cell's content unless it
    /// is first moved into the row that takes its place. So every DISTINCT anchor covering row `ri` (found
    /// via `TableMap.cellsInRect` over the single-row strip, so a colspan anchor covering `ri` at several
    /// columns is visited once) is handled one of three ways: `rowspan == 1` — left alone; it is removed
    /// along with the row itself. `rowspan > 1` and declared in an EARLIER row (straddling down into `ri`)
    /// — shrunk in place (`rowspan -= 1`); no data moves, since its declaring row survives. `rowspan > 1`
    /// and declared IN `ri` itself (this row is its origin) — its `Cell` value is lifted out, `rowspan`
    /// decremented, and reinserted into row `ri + 1` (which becomes the new row at this grid position once
    /// `ri` is deleted) at the declaration index matching its origin column — computed against the
    /// pre-removal `map` plus however many earlier transplants (processed in ascending column order, same
    /// as `cellsInRect`'s order for a single-row strip) already landed ahead of it in this same pass, so
    /// multiple same-row transplants interleave correctly with row `ri + 1`'s own pre-existing cells. Only
    /// the physical move needs this bookkeeping — the cell's covering-column ORIGIN itself is still
    /// derived (not stored), so it re-settles automatically once `TableMap` is rebuilt.
    public func removingRow(at index: Int) -> TableBlock {
        guard rows.indices.contains(index) else { return self }
        let map = TableMap(self)
        var t = self

        let strip = TableRect(top: index, left: 0, bottom: index, right: map.columns - 1)
        let coveringAnchors = map.cellsInRect(strip)

        // Anchors that reach into `index` from an earlier row just shrink in place — their declaring row
        // survives, so there's nothing to move.
        for anchor in coveringAnchors where anchor.rowspan > 1 && anchor.row < index {
            guard let loc = TableBlock.location(of: anchor.cellID, in: t) else { continue }
            t.rows[loc.row].cells[loc.index].rowspan -= 1
        }

        // Anchors that ORIGINATE in the removed row must be transplanted down to row `index + 1` (which
        // is guaranteed to exist: a clamped `rowspan > 1` anchor can only originate at `index` if the
        // table has a row `index + 1` for it to still cover).
        var transplantedSoFar = 0
        for anchor in coveringAnchors where anchor.rowspan > 1 && anchor.row == index {
            guard let loc = TableBlock.location(of: anchor.cellID, in: t) else { continue }
            var cell = t.rows[loc.row].cells[loc.index]
            t.rows[loc.row].cells.remove(at: loc.index)
            // The transplanted cell retains its OWN `isHeader` — we deliberately do NOT stamp it to the
            // destination row's header status. A re-homed cell must keep its own semantics; the
            // destination row's derived `isHeader` (all-cells-header) then correctly FOLLOWS its actual
            // cells, so re-homing a body cell into a header row makes that row a mixed (non-header) row.
            // The header-protection contract is only that a header row is never DELETED — which holds
            // (a header row is filtered out of `removingRows`' victim list and so is never the `index`
            // being removed here). NOTE: a rowspan cell straddling from a body row DOWN into a header row
            // is only user-constructible once the merge UI lands (Phase 2c) — re-confirm the product
            // behavior of the mixed-row outcome then.
            cell.rowspan -= 1
            let insertionIndex = TableBlock.declarationIndex(forRow: index + 1, coveringColumn: anchor.column, in: map) + transplantedSoFar
            t.rows[index + 1].cells.insert(cell, at: insertionIndex)
            transplantedSoFar += 1
        }

        t.rows.remove(at: index)
        return t
    }

    /// Inserts a `ColumnSpec` at covering-column coordinate `ci`, span-aware: an anchor whose footprint
    /// STRADDLES the new boundary (`anchor.column < ci <= anchor.column + colspan - 1`) simply grows its
    /// `colspan` by 1 (the new column falls inside that cell — no new cell is declared for the rows it
    /// covers). Every row where `ci` is a CLEAN boundary — the covering slot at `ci` is some anchor's own
    /// ORIGIN column, or `ci` is the right edge (`ci == columns`, i.e. appending) — gets a fresh
    /// `emptyCell()` spliced into `rows[r].cells` at the declaration index matching covering column `ci`
    /// (mirrors `splittingCell`'s re-materialization index). Classification and index computation both use
    /// the PRE-insertion `TableMap`, so a straddling anchor spanning multiple rows (via `rowspan`) grows
    /// once and is correctly skipped for every row it covers, and a row-local classification is used even
    /// when the covering anchor at `ci` isn't declared in that row (a rowspan cell descending from above).
    public func insertingColumn(at index: Int, width: Double) -> TableBlock {
        let map = TableMap(self)
        var t = self
        let ci = min(max(index, 0), t.columns.count)
        t.columns.insert(ColumnSpec(width: width), at: ci)

        // Grow every anchor whose footprint straddles the new boundary.
        for anchor in map.anchors {
            let anchorRight = anchor.column + anchor.colspan - 1
            guard anchor.column < ci, ci <= anchorRight else { continue }
            guard let loc = TableBlock.location(of: anchor.cellID, in: t) else { continue }
            t.rows[loc.row].cells[loc.index].colspan += 1
        }

        // Splice a fresh cell into every row where ci is a clean boundary (not interior to a straddler).
        for r in 0..<t.rows.count {
            let isCleanBoundary = ci >= map.columns || map.anchor(atRow: r, column: ci)?.column == ci
            guard isCleanBoundary else { continue }
            // A new cell must inherit the row's current header status: `Row.isHeader` is derived
            // (all cells header), so inserting a plain body cell into a full header row would flip
            // that row to non-header and defeat the header-delete protection in `removingRows`.
            let wasHeader = t.rows[r].isHeader
            let insertionIndex = TableBlock.declarationIndex(forRow: r, coveringColumn: ci, in: map)
            t.rows[r].cells.insert(TableBlock.emptyCell(isHeader: wasHeader), at: insertionIndex)
        }
        return t
    }

    /// Removes the `ColumnSpec` at covering-column coordinate `ci`, span-aware: every DISTINCT anchor
    /// covering column `ci` (found via `TableMap.cellsInRect` over the full-height single-column strip, so
    /// a rowspan anchor covering `ci` across many rows is visited once) is shrunk (`colspan -= 1`) when it
    /// spans more than one column, or removed entirely when `colspan == 1`. No explicit "re-home the
    /// origin" step is needed: a cell's covering-column origin is DERIVED from its declaration position
    /// plus the spans of its row-siblings, not stored — so decrementing `colspan` on a cell whose origin
    /// IS `ci` automatically re-homes it onto the next surviving column once `TableMap` is rebuilt.
    public func removingColumn(at index: Int) -> TableBlock {
        guard columns.indices.contains(index) else { return self }
        let map = TableMap(self)
        var t = self
        t.columns.remove(at: index)

        let strip = TableRect(top: 0, left: index, bottom: map.rows - 1, right: index)
        for anchor in map.cellsInRect(strip) {
            guard let loc = TableBlock.location(of: anchor.cellID, in: t) else { continue }
            if anchor.colspan > 1 {
                t.rows[loc.row].cells[loc.index].colspan -= 1
            } else {
                t.rows[loc.row].cells.remove(at: loc.index)
            }
        }
        return t
    }

    /// Removes every **body** row in `range` (header rows are skipped — never removed), high-index → low
    /// (each step delegates to the span-aware `removingRow(at:)`, so a rowspan cell straddling the range
    /// shrinks/re-homes correctly at each step — mirrors `removingColumns`). A no-op if no body row is
    /// covered.
    public func removingRows(in range: ClosedRange<Int>) -> TableBlock {
        var t = self
        let victims = range.filter { t.rows.indices.contains($0) && !t.rows[$0].isHeader }.sorted(by: >)
        for i in victims {
            t = t.removingRow(at: i)
        }
        return t
    }

    /// Removes every column in `range`, high-index → low (each step delegates to the span-aware
    /// `removingColumn(at:)`, so a merged cell straddling the range shrinks/re-homes correctly at each
    /// step). Always leaves at least one column (a table with no columns is invalid); if `range` would
    /// empty the table the lowest-indexed covered column is kept.
    public func removingColumns(in range: ClosedRange<Int>) -> TableBlock {
        var t = self
        let victims = range.filter { t.columns.indices.contains($0) }.sorted(by: >)
        for i in victims {
            guard t.columns.count > 1 else { break }
            t = t.removingColumn(at: i)
        }
        return t
    }

    /// Merges every cell intersecting `rect` into one spanning cell. `rect` is first normalized via
    /// `TableMap.expanded` so it can never bisect an existing merged cell — the caller may pass any rect
    /// touching the intended region. The ANCHOR is the cell whose origin is the normalized rect's
    /// top-left corner; its `id`/`background`/`horizontalAlignment`/`verticalAlignment`/`isHeader` are
    /// kept, its `colspan`/`rowspan` set to the normalized rect's span, and its `blocks` become its own
    /// blocks followed by every OTHER collected cell's blocks, row-major (concatenation — content is
    /// pooled, never dropped). Every other collected cell is removed from its row. No-op (returns
    /// `self`) when the normalized rect resolves to a single cell.
    public func mergingCells(in rect: TableRect) -> TableBlock {
        let map = TableMap(self)
        let normalizedRect = map.expanded(rect)
        let collected = map.cellsInRect(normalizedRect)
        guard collected.count > 1 else { return self }
        guard let anchorAnchor = map.anchor(atRow: normalizedRect.top, column: normalizedRect.left) else { return self }
        // Row-major, excluding the anchor itself.
        let others = collected.filter { $0.cellID != anchorAnchor.cellID }

        var t = self
        guard let anchorLoc = TableBlock.location(of: anchorAnchor.cellID, in: t) else { return self }

        var mergedBlocks = t.rows[anchorLoc.row].cells[anchorLoc.index].blocks
        // The anchor's original first block, kept as the fallback so an all-empty merge stays ONE empty
        // paragraph rather than a block-less (invalid) cell.
        let fallbackBlock = mergedBlocks.first ?? .paragraph(ParagraphBlock(id: BlockID.generate()))
        // Collect removal indices per row before mutating (removal happens after the anchor is
        // rewritten, so indices captured here stay valid).
        var removalIndicesByRow: [Int: [Int]] = [:]
        for other in others {
            guard let loc = TableBlock.location(of: other.cellID, in: t) else { continue }
            mergedBlocks.append(contentsOf: t.rows[loc.row].cells[loc.index].blocks)
            removalIndicesByRow[loc.row, default: []].append(loc.index)
        }

        // Don't pool empty cells' filler paragraphs into the merged cell — an empty cell contributes no
        // content, so it shouldn't inject a blank paragraph between the non-empty cells' text. Keep ≥1
        // block: if EVERY merged cell was empty, the result is the anchor's single empty paragraph.
        let nonEmpty = mergedBlocks.filter { !TableBlock.isEmptyFillerParagraph($0) }
        mergedBlocks = nonEmpty.isEmpty ? [fallbackBlock] : nonEmpty

        var anchorCell = t.rows[anchorLoc.row].cells[anchorLoc.index]
        anchorCell.blocks = mergedBlocks
        anchorCell.colspan = normalizedRect.right - normalizedRect.left + 1
        anchorCell.rowspan = normalizedRect.bottom - normalizedRect.top + 1
        t.rows[anchorLoc.row].cells[anchorLoc.index] = anchorCell

        // Remove high-index → low per row so earlier indices in that row don't shift (the anchor's own
        // index is never among these — a merge rect's anchor is always the leftmost declared cell in
        // its row within the rect, so any sibling removal index in the anchor's row is strictly greater).
        for (row, indices) in removalIndicesByRow {
            for index in indices.sorted(by: >) {
                t.rows[row].cells.remove(at: index)
            }
        }
        return t
    }

    /// Splits the merged cell whose footprint covers `origin` back into a dense grid of single cells.
    /// No-op (returns `self`) when that cell isn't merged (`colspan == 1 && rowspan == 1`). The
    /// anchor keeps ALL of its pooled content and shrinks to `colspan = rowspan = 1`; every other slot
    /// in its former footprint (row-major) is re-materialized as a fresh, empty cell inserted at the
    /// declaration index matching its covering column (computed via a freshly-rebuilt `TableMap` after
    /// each insertion, so cells outside the footprint that were only pushed right by the merge's span
    /// settle back at their original covering column).
    public func splittingCell(at origin: (row: Int, column: Int)) -> TableBlock {
        let map = TableMap(self)
        guard let anchor = map.anchor(atRow: origin.row, column: origin.column) else { return self }
        guard anchor.colspan > 1 || anchor.rowspan > 1 else { return self }
        guard let footprint = map.coveringRect(atRow: origin.row, column: origin.column) else { return self }
        guard let anchorLoc = TableBlock.location(of: anchor.cellID, in: self) else { return self }

        var t = self
        t.rows[anchorLoc.row].cells[anchorLoc.index].colspan = 1
        t.rows[anchorLoc.row].cells[anchorLoc.index].rowspan = 1

        for r in footprint.top...footprint.bottom {
            for c in footprint.left...footprint.right {
                if r == footprint.top && c == footprint.left { continue }   // the anchor's own slot
                let insertionIndex = TableBlock.declarationIndex(forRow: r, coveringColumn: c, in: TableMap(t))
                t.rows[r].cells.insert(TableBlock.emptyCell(), at: insertionIndex)
            }
        }
        return t
    }

    /// A block that carries no content and is not a list item — the shape of an empty cell's default
    /// paragraph (`emptyCell()`), so merging empty cells drops these rather than pooling blank paragraphs.
    /// A list item (has a marker) or any non-paragraph block is never treated as empty filler.
    private static func isEmptyFillerParagraph(_ block: Block) -> Bool {
        if case .paragraph(let p) = block { return p.text.isEmpty && p.list == nil }
        return false
    }

    /// Locates a cell by id: its row index and its declaration index within that row's `cells`.
    private static func location(of cellID: BlockID, in table: TableBlock) -> (row: Int, index: Int)? {
        for r in table.rows.indices {
            if let i = table.rows[r].cells.firstIndex(where: { $0.id == cellID }) {
                return (r, i)
            }
        }
        return nil
    }

    /// Where a fresh cell covering grid column `c` in row `r` belongs in `rows[r].cells`: cells declare
    /// in strictly increasing covering-column order, so the insertion index is the count of that row's
    /// currently-declared cells whose covering column is `< c`.
    private static func declarationIndex(forRow r: Int, coveringColumn c: Int, in map: TableMap) -> Int {
        map.anchors.filter { $0.row == r && $0.column < c }.count
    }
}
