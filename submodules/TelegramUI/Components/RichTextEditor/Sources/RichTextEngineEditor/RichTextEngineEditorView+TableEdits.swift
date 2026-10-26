#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// R7-tables rung C — the structural edits a selection enables.
///
/// Every verb is Core's span-aware primitive plus ONE splice. Core owns the model arithmetic
/// (`TableBlock+Editing.swift`); this file owns getting the result onto the engine's axis without
/// losing the user's undo history.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    // MARK: - The splice

    /// The table the caret or the committed selection is in, as a MODEL block — what every verb hands
    /// to Core. Read from `document.blocksByID`, because a `TableShape` carries no cell content: rung
    /// A's recorded trap, where reading the shape copies an empty grid that looks right in a debugger.
    internal func tableForEditing() -> (table: TableBlock, roles: Range<Int>)? {
        guard let (shape, roles) = structurallyChromedTable(),
              let block = document.blocksByID[shape.id], case let .table(table) = block else { return nil }
        return (table, roles)
    }

    /// The caret's own cell coordinates, when it is in one.
    internal func caretCellCoordinates() -> (row: Int, column: Int)? {
        roleIndex(atFlatOffset: engineSelectedRange.location)
            .flatMap { currentRoles[$0].tableCellCoordinates }
    }

    /// Replaces the caret's table with `updated`, KEEPING the undo history.
    ///
    /// `insertTable`'s document swap clears it (`recordUndoStepForStructuralChange`), because a swap and
    /// the engine's own undo replay conflict — the replay rebuilds roles by identity against a map the
    /// swap has just overwritten. Adding a row is something a user does far more often than inserting
    /// a table, so losing everything typed before it is real damage. This is the shape rung A proved
    /// with `convertCurrentTableToText`: replace a whole role run with a different number of blocks.
    ///
    /// Cell contents survive BY CONSTRUCTION — Core's primitives return a `TableBlock` that still
    /// carries them, so this renders the updated model rather than re-assembling any text.
    internal func replaceTable(with updated: TableBlock, parkingAt cell: (row: Int, column: Int)?) {
        guard let (_, roles) = structurallyChromedTable() else { return }
        let ancestry = currentRoles[roles.lowerBound].ancestry
        let (blocks, freshRoles) = bridge.engineRepresentation(for: [.table(updated)], within: ancestry)
        guard !blocks.isEmpty, blocks.count == freshRoles.count else { return }
        // Already ENGINE text — `flatten` produced it — so a cell's own newline is a line separator
        // already and the "\n" here is the BLOCK separator.
        let text = blocks.map(\.string).joined(separator: "\n")
        var plan = currentRoles
        plan.replaceSubrange(roles, with: freshRoles)
        let run = wholeRunRange(roles)
        // The splice moves the selection twice — the replacement itself, then the caret park — and
        // the selection funnel clears the structural selection on any move it was not told about.
        // The selection is the edit's SUBJECT, not a casualty of it: alignment and the header toggle
        // act on it and leave it for the next pick (K3, 2026-09-11: choosing an alignment dropped
        // the column selection). A structural action clears it itself afterwards, as legacy does.
        let wasParking = isParkingCaretForStructuralSelection
        isParkingCaretForStructuralSelection = true
        defer { isParkingCaretForStructuralSelection = wasParking }
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                replaceFlat(run, with: text, adopting: plan)
                // An attribute cannot travel through a text edit — the two-step `insertMedia` and
                // `convertCurrentTableToText` both use.
                var offset = run.location
                for block in blocks {
                    restoreStyleFlat(NSRange(location: offset, length: block.length), from: block)
                    offset += block.length + 1
                }
                let target = cell.flatMap { wanted in
                    freshRoles.firstIndex { $0.tableCellCoordinates.map { $0 == wanted } ?? false }
                } ?? 0
                engineSelectedRange = NSRange(
                    location: flatOffset(ofRoleAt: roles.lowerBound + target), length: 0)
            }
        }
        setNeedsLayout()
    }

    /// The host's record of where each table's run is scrolled, reconciled against the engine.
    ///
    /// Two directions, and which one a table takes is decided by ONE fact: whether its cells are the
    /// same blocks they were when the offset was last read. They are, almost always — the user
    /// scrolls, the engine reports it, the host writes it down. They are not exactly once per splice:
    /// `replaceTable` keeps the first cell's identity and mints the rest, so for the one pass in
    /// which the run holds a single placed cell the engine clamps the offset to that width's
    /// maximum, zero. The host puts its own value back on the first pass that has every cell again.
    ///
    /// Runs whose cells are not all placed are skipped entirely: the run is not at its real width,
    /// so its offset means nothing in either direction.
    internal func syncRunScrollOffsets() {
        let identifiers = engine.tgid_blockIdentifiers
        let placed = engine.blockFrames ?? [:]
        var live: Set<BlockID> = []
        var index = 0
        while index < currentRoles.count {
            guard let table = currentRoles[index].owningTable else { index += 1; continue }
            let first = index
            while index < currentRoles.count, currentRoles[index].containerID == table.id { index += 1 }
            live.insert(table.id)
            guard index <= identifiers.count else { continue }
            let cells = Array(identifiers[first..<index])
            guard cells.allSatisfy({ placed[$0] != nil }) else { continue }
            let current = engine.id_placedRunContentOffsetForBlock(at: UInt(first))
            if let remembered = runScrollOffsets[table.id], runScrollIdentities[table.id] != cells {
                // The cells were rebuilt under it. Identities first: assigning an offset marks the
                // engine for layout, which calls this back, and an entry that still looked rebuilt
                // would push a second time.
                runScrollIdentities[table.id] = cells
                if abs(current - remembered) > 0.5 {
                    engine.id_setPlacedRunContentOffset(remembered, forBlockAt: UInt(first))
                }
                // Re-read rather than assume: the engine clamps to the run's NEW maximum, so an edit
                // that narrowed the table lands at its new end and the host records that.
                runScrollOffsets[table.id] = engine.id_placedRunContentOffsetForBlock(at: UInt(first))
            } else {
                runScrollOffsets[table.id] = current
                runScrollIdentities[table.id] = cells
            }
        }
        for id in runScrollOffsets.keys where !live.contains(id) {
            runScrollOffsets[id] = nil
            runScrollIdentities[id] = nil
        }
    }

    /// Re-asserts every remembered offset, whatever the engine currently holds — for the one caller
    /// that has to undo the engine's own bookkeeping rather than follow it. `height(forWidth:)`
    /// probes at a width the caller has not committed to, and a probe WIDER than the table leaves
    /// the run with no scrolling range at all, so the engine clamps the offset to zero and restoring
    /// the frame does not bring it back. A query must leave nothing behind, that included.
    internal func pushRunScrollOffsets() {
        guard !runScrollOffsets.isEmpty else { return }
        var index = 0
        while index < currentRoles.count {
            guard let table = currentRoles[index].owningTable else { index += 1; continue }
            let first = index
            while index < currentRoles.count, currentRoles[index].containerID == table.id { index += 1 }
            guard let remembered = runScrollOffsets[table.id] else { continue }
            if abs(engine.id_placedRunContentOffsetForBlock(at: UInt(first)) - remembered) > 0.5 {
                engine.id_setPlacedRunContentOffset(remembered, forBlockAt: UInt(first))
            }
        }
    }

    // MARK: - Rows

    /// A RANGE has two ends, so which one each insert uses is a decision: Above takes the range's
    /// `lowerBound`, Below goes after its `upperBound` — legacy's
    /// `structuralRowRange()?.lowerBound ?? a.row` and its mirror.
    public func insertTableRowAbove() {
        guard let (table, _) = tableForEditing(),
              let at = structuralRowRange()?.lowerBound ?? caretCellCoordinates()?.row else { return }
        replaceTable(with: table.insertingRow(at: at), parkingAt: (row: at, column: 0))
    }

    public func insertTableRowBelow() {
        guard let (table, _) = tableForEditing(),
              let last = structuralRowRange()?.upperBound ?? caretCellCoordinates()?.row else { return }
        replaceTable(with: table.insertingRow(at: last + 1), parkingAt: (row: last + 1, column: 0))
    }

    public func deleteTableRow() {
        guard let (table, _) = tableForEditing(),
              let range = structuralRowRange() ?? caretCellCoordinates().map({ $0.row ... $0.row })
        else { return }
        // Core's `removingRows(in:)` filters HEADER rows out of the victims but has NO floor, so a
        // header-less table whose every row is selected would be emptied. A table with no rows is not
        // a table. Checked BEFORE the edit, so a refusal registers no undo step.
        let survivors = table.rows.indices.filter { !range.contains($0) || table.rows[$0].isHeader }
        guard !survivors.isEmpty else { return }
        replaceTable(with: table.removingRows(in: range),
                     parkingAt: (row: max(range.lowerBound - 1, 0), column: 0))
        clearTableStructuralSelection()
    }

    // MARK: - Columns

    /// The mirror of the row verbs. The fresh column takes the width of the column it was inserted
    /// beside, so a table of unequal columns does not gain a differently-sized stripe.
    public func insertTableColumnLeft() {
        guard let (table, _) = tableForEditing(),
              let at = structuralColumnRange()?.lowerBound ?? caretCellCoordinates()?.column else { return }
        replaceTable(with: table.insertingColumn(at: at, width: width(of: table, near: at)),
                     parkingAt: (row: 0, column: at))
    }

    public func insertTableColumnRight() {
        guard let (table, _) = tableForEditing(),
              let last = structuralColumnRange()?.upperBound ?? caretCellCoordinates()?.column else { return }
        replaceTable(with: table.insertingColumn(at: last + 1, width: width(of: table, near: last)),
                     parkingAt: (row: 0, column: last + 1))
    }

    public func deleteTableColumn() {
        guard let (table, _) = tableForEditing(),
              let range = structuralColumnRange() ?? caretCellCoordinates().map({ $0.column ... $0.column })
        else { return }
        // Core keeps one column whatever it is asked; the engine refuses BEFORE the edit, so a
        // no-op cannot register an undo step.
        let survivors = table.columns.indices.filter { !range.contains($0) }
        guard !survivors.isEmpty else { return }
        replaceTable(with: table.removingColumns(in: range),
                     parkingAt: (row: 0, column: max(range.lowerBound - 1, 0)))
        clearTableStructuralSelection()
    }

    private func width(of table: TableBlock, near index: Int) -> Double {
        table.columns.indices.contains(index) ? table.columns[index].width
            : (table.columns.last?.width ?? 100)
    }

    // MARK: - Merge and split

    /// Merges the cells the `.cells` selection covers into one spanning cell. Core concatenates the
    /// covered cells' content into the anchor and expands the rect so it cannot bisect an existing
    /// merge.
    public func mergeSelectedCells() {
        guard let (table, _) = tableForEditing(), let rect = focusedOrSelectedCellRect() else { return }
        // Checked BEFORE the edit so a no-op cannot register an undo step — legacy states the same
        // rule on its own `mergeSelectedCells`, for the same reason.
        let map = TableMap(table)
        guard map.cellsInRect(map.expanded(rect)).count > 1 else { return }
        replaceTable(with: table.mergingCells(in: rect), parkingAt: (row: rect.top, column: rect.left))
        clearTableStructuralSelection()
    }

    /// Splits one already-merged cell back into a dense grid. Offered only when the selection resolves
    /// to exactly ONE anchor that actually spans — splitting a 1x1 is a no-op with an undo step.
    public func splitSelectedCell() {
        guard let (table, _) = tableForEditing(), let rect = focusedOrSelectedCellRect() else { return }
        let anchors = TableMap(table).cellsInRect(rect)
        guard anchors.count == 1, let only = anchors.first,
              only.colspan > 1 || only.rowspan > 1 else { return }
        replaceTable(with: table.splittingCell(at: (row: only.row, column: only.column)),
                     parkingAt: (row: only.row, column: only.column))
        clearTableStructuralSelection()
    }

    // MARK: - Cell attributes

    /// The grid rect the attribute verbs act on: a row range as a full-width rect, a column range as a
    /// full-height one, a cell rect as itself, and the focused cell when nothing is committed.
    internal func coveredRectForAttributes() -> TableRect? {
        guard let (table, _) = tableForEditing() else { return nil }
        let map = TableMap(table)
        if let rows = structuralRowRange() {
            return TableRect(top: rows.lowerBound, left: 0, bottom: rows.upperBound, right: map.columns - 1)
        }
        if let columns = structuralColumnRange() {
            return TableRect(top: 0, left: columns.lowerBound, bottom: map.rows - 1, right: columns.upperBound)
        }
        return focusedOrSelectedCellRect()
    }

    /// Rebuilds every covered cell through `transform`, leaving all other cells and the whole grid
    /// alone — the ONE place this rung builds cells itself, since alignment and the header flag have
    /// no Core primitive.
    private func mutatingCoveredCells(_ transform: (Cell) -> Cell) {
        guard let (table, _) = tableForEditing(), let rect = coveredRectForAttributes() else { return }
        let covered = Set(TableMap(table).cellsInRect(rect).map(\.cellID))
        guard !covered.isEmpty else { return }
        var updated = table
        for row in updated.rows.indices {
            for column in updated.rows[row].cells.indices
            where covered.contains(updated.rows[row].cells[column].id) {
                updated.rows[row].cells[column] = transform(updated.rows[row].cells[column])
            }
        }
        replaceTable(with: updated, parkingAt: (row: rect.top, column: rect.left))
    }

    /// A NIL axis is left alone, which is what the host's two-axis control relies on when only one
    /// half of it is used.
    public func setSelectionAlignment(horizontal: TextAlignment?, vertical: VerticalAlignment?) {
        guard horizontal != nil || vertical != nil else { return }
        mutatingCoveredCells { cell in
            var updated = cell
            if let horizontal { updated.horizontalAlignment = horizontal }
            if let vertical { updated.verticalAlignment = vertical }
            return updated
        }
    }

    /// Decided ONCE across the covered cells — the same rule the formatting commands use, so a mixed
    /// selection goes uniformly ON rather than each cell flipping independently.
    public func toggleSelectionHeader() {
        guard let (table, _) = tableForEditing(), let rect = coveredRectForAttributes() else { return }
        let covered = TableMap(table).cellsInRect(rect).compactMap { anchor in
            table.rows.flatMap(\.cells).first { $0.id == anchor.cellID }
        }
        guard !covered.isEmpty else { return }
        let enabling = !covered.allSatisfy(\.isHeader)
        mutatingCoveredCells { cell in
            var updated = cell
            updated.isHeader = enabling
            return updated
        }
    }

    // MARK: - Backspace with a structural selection

    /// Backspace with rows or columns selected deletes them.
    ///
    /// When the selection covers EVERY row or EVERY column — which would empty the table — the whole
    /// table goes instead, replaced IN PLACE by an empty paragraph. That is legacy's behaviour and it
    /// is distinct from rung A's `deleteTable`, which JOINS the surrounding content rather than
    /// leaving a paragraph behind.
    ///
    /// NOT in `backspaceJoinRules`: every rule there fires at the START of a role and is chosen by
    /// role index, while this one keys on the SELECTION and applies wherever the caret is parked.
    /// Putting it in the array would mean inventing a role precondition it does not have. Both doors
    /// ask THIS function first — one condition, asked twice, never two copies.
    @discardableResult
    internal func deleteTableStructuralSelection() -> Bool {
        guard let selection = tableStructuralSelection, let (table, _) = tableForEditing() else { return false }
        let map = TableMap(table)
        switch selection.kind {
        case let .rows(range):
            let survivors = table.rows.indices.filter { !range.contains($0) || table.rows[$0].isHeader }
            if survivors.isEmpty { return replaceWholeTableWithAParagraph() }
            deleteTableRow()
        case let .columns(range):
            let survivors = table.columns.indices.filter { !range.contains($0) }
            if survivors.isEmpty { return replaceWholeTableWithAParagraph() }
            deleteTableColumn()
        case .cells:
            // A cell rect has no row or column to remove. Legacy offers no delete for one either.
            return false
        }
        _ = map
        clearTableStructuralSelection()
        return true
    }

    /// Replaces the whole table with an empty paragraph, in place.
    private func replaceWholeTableWithAParagraph() -> Bool {
        guard let (_, roles) = structurallyChromedTable() else { return false }
        let ancestry = currentRoles[roles.lowerBound].ancestry
        let run = wholeRunRange(roles)
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                var plan = currentRoles
                plan.replaceSubrange(roles, with: [freshBodyRole(within: ancestry)])
                replaceFlat(run, with: "", adopting: plan)
                engineSelectedRange = NSRange(location: run.location, length: 0)
            }
        }
        clearTableStructuralSelection()
        setNeedsLayout()
        return true
    }
}
#endif
