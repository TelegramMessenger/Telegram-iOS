#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Table structural commands. Each takes the live table via `currentBlock()`, applies a pure
/// `TableBlock` transform (Core), and rebuilds the one `TableBlockBox` inside `editing { }` so undo
/// is the existing whole-document `[Block]` snapshot. The structural commands below no-op when the
/// caret isn't in a table; `insertTable` is the inverse — it no-ops when the caret IS in a table (or
/// on an image/gap).
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// The table box containing the caret (`head`), its index in `boxes`, and the caret's (row, col).
    /// The table the caret is in, its OWNING stack, and the caret's cell — recursing into details / expanded
    /// block-quote bodies (NOT table cells; v1 tables don't nest). `index` is the index WITHIN `stack.boxes`,
    /// so every structural op (handles, menu, row/column insert-delete, delete/convert/copy) works on a table
    /// nested in a container, not only at top level.
    func activeTable() -> (box: TableBlockBox, stack: BlockStack, index: Int, row: Int, col: Int)? {
        func search(_ stack: BlockStack) -> (box: TableBlockBox, stack: BlockStack, index: Int, row: Int, col: Int)? {
            for (i, b) in stack.boxes.enumerated() {
                if let t = b as? TableBlockBox, let loc = t.cellLocation(containing: head) {
                    return (t, stack, i, loc.row, loc.column)
                }
                if let d = b as? DetailsBox, let r = search(d.children) { return r }
                else if let bq = b as? BlockQuoteBox, !bq.collapsed, let r = search(bq.children) { return r }
            }
            return nil
        }
        return search(root)
    }

    /// Swaps a freshly-built box for `newTable` at `index` in `stack`, recomputes spans, and lands the caret
    /// in cell (caretRow, caretCol) clamped to the new geometry. Call inside `editing { … }`. `effectiveWidth`
    /// is a placeholder — BlockStack.layout re-sets each box's width, so a nested table gets its container width.
    func replaceTable(at index: Int, in stack: BlockStack, with newTable: TableBlock, caretRow: Int, caretCol: Int) {
        let newBox = TableBlockBox(table: newTable, mapper: mapper, width: effectiveWidth)
        stack.boxes[index] = newBox
        recomputeSpans()
        let r = min(max(caretRow, 0), max(newBox.rowCount - 1, 0))
        let c = min(max(caretCol, 0), max(newBox.columnCount - 1, 0))
        // TASK 39: `applyCaretOutcome` (`+Editing.swift`) — the raw, non-publishing pair — applied HERE
        // rather than returned. All twelve callers are `editing { … replaceTable(…); return .unchanged }`,
        // so a publish would be a SECOND host selection report inside `performEditing`'s own bracket
        // (class 1 at `applyCaretOutcome`). Returning the claim instead would mean giving this helper a
        // `RichTextInputCaretOutcome` return type and rewriting all twelve call sites — a signature is
        // API, which this task's Produces block excludes; and it would buy nothing, since every caller's
        // body ends immediately after this call. Task 38 settled the same question the same way at
        // `deleteButtonPill`.
        if let pos = newBox.cellTextStart(row: r, column: c) { applyCaretOutcome(.caret(at: pos)) }
    }

    func insertTableRowAbove() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(let table) = a.box.currentBlock() else { return .unchanged }
            let range = structuralRowRange() ?? (a.row...a.row)
            let at = max(range.lowerBound, 1)   // never above the header (row 0)
            replaceTable(at: a.index, in: a.stack, with: table.insertingRow(at: at), caretRow: at, caretCol: a.col)
            return .unchanged
        }
    }

    func insertTableRowBelow() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(let table) = a.box.currentBlock() else { return .unchanged }
            let range = structuralRowRange() ?? (a.row...a.row)
            let at = range.upperBound + 1
            replaceTable(at: a.index, in: a.stack, with: table.insertingRow(at: at), caretRow: at, caretCol: a.col)
            return .unchanged
        }
    }

    func deleteTableRow() {
        guard let a = activeTable() else { return }
        guard case .table(let table) = a.box.currentBlock() else { return }
        let range = structuralRowRange() ?? (a.row...a.row)
        guard range.contains(where: { table.rows.indices.contains($0) && !table.rows[$0].isHeader }) else { return }   // header-only range → nothing to delete
        editing {
            replaceTable(at: a.index, in: a.stack, with: table.removingRows(in: range),
                         caretRow: range.lowerBound, caretCol: a.col)
            return .unchanged
        }
    }

    /// Default width for a new column (markdown ignores widths; this keeps proportions sane).
    private func defaultNewColumnWidth(_ table: TableBlock) -> Double {
        guard !table.columns.isEmpty else { return 120 }
        return table.columns.reduce(0) { $0 + $1.width } / Double(table.columns.count)
    }

    func insertTableColumnLeft() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(let table) = a.box.currentBlock() else { return .unchanged }
            let range = structuralColumnRange() ?? (a.col...a.col)
            let new = table.insertingColumn(at: range.lowerBound, width: defaultNewColumnWidth(table))
            replaceTable(at: a.index, in: a.stack, with: new, caretRow: a.row, caretCol: range.lowerBound)
            return .unchanged
        }
    }

    func insertTableColumnRight() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(let table) = a.box.currentBlock() else { return .unchanged }
            let range = structuralColumnRange() ?? (a.col...a.col)
            let at = range.upperBound + 1
            let new = table.insertingColumn(at: at, width: defaultNewColumnWidth(table))
            replaceTable(at: a.index, in: a.stack, with: new, caretRow: a.row, caretCol: at)
            return .unchanged
        }
    }

    /// Removes the table the caret is in (one undo step). The caret lands at the start of the block that
    /// took the table's place — the block after it, or the previous block if the table was last, or a fresh
    /// empty paragraph if the table was the document's only block. No-op when the caret isn't in a table.
    func deleteTable() {
        guard let a = activeTable() else { return }
        editing {
            a.stack.boxes.remove(at: a.index)
            if a.stack.boxes.isEmpty {   // never leave a stack (root or a container body) with zero blocks
                a.stack.boxes.append(BlockBox(paragraph: ParagraphBlock(id: BlockID.generate()), mapper: mapper, width: effectiveWidth))
            }
            recomputeSpans()
            let targetIndex = min(a.index, a.stack.boxes.count - 1)
            let caret = snapToRenderable(a.stack.boxes[targetIndex].textStart, forward: true)
            return .caret(at: caret)   // TASK 39: terminal claim → the body's return value (36b/36c shape)
        }
    }

    /// Copies the caret's current table to the pasteboard as if it were a document containing ONLY that table:
    /// the app fragment (JSON — pastes back as a real table), an RTF table, and a plain-text flatten (one line
    /// per row, cells space-joined). No-op when the caret isn't in a table.
    func copyCurrentTable() {
        guard let a = activeTable(), case .table(let table) = a.box.currentBlock() else { return }
        let document = Document(blocks: [.table(table)])
        let plain = tableFlattenedText(table).joined(separator: "\n")
        pasteboard.setItems([RichTextEditorClipboard.pasteboardItem(for: document, plain: plain)], options: [:])
    }

    /// Replaces the caret's current table IN PLACE with body paragraphs — one per row, the row's cells joined
    /// by " " (see `tableFlattenedText`). One undo step; the caret lands at the start of the first paragraph.
    /// No-op when the caret isn't in a table.
    func convertCurrentTableToText() {
        guard let a = activeTable(), case .table(let table) = a.box.currentBlock() else { return }
        editing {
            var replacement: [CanvasBlock] = tableFlattenedText(table).map { line in
                BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body,
                                                   runs: line.isEmpty ? [] : [TextRun(text: line)]),
                         mapper: mapper, width: effectiveWidth)
            }
            if replacement.isEmpty {
                replacement = [BlockBox(paragraph: ParagraphBlock(id: BlockID.generate()), mapper: mapper, width: effectiveWidth)]
            }
            a.stack.boxes.replaceSubrange(a.index...a.index, with: replacement)
            recomputeSpans()
            let caret = snapToRenderable(a.stack.boxes[a.index].textStart, forward: true)
            return .caret(at: caret)   // TASK 39: terminal claim → the body's return value
        }
    }

    /// Backspace with a table structural (row/column) selection active. Deletes the selected rows or
    /// columns (via the existing `deleteTableRow`/`deleteTableColumn`, which read the structural range).
    /// When the selection covers EVERY row or EVERY column — which would empty the table — it removes the
    /// whole table block instead, replacing it IN PLACE with an empty body paragraph (caret there). The
    /// structural selection is cleared afterward (mirrors the structural menu's run-then-clear-selection
    /// behavior). No-op-safe when there is no live structural selection.
    func deleteTableStructuralSelection() {
        guard let sel = tableSelection, let a = activeTable(), a.box.id == sel.table else {
            clearTableSelection(); return
        }
        let coversWholeTable: Bool
        switch sel.kind {
        case .rows(let range):    coversWholeTable = range.lowerBound <= 0 && range.upperBound >= a.box.rowCount - 1
        case .columns(let range): coversWholeTable = range.lowerBound <= 0 && range.upperBound >= a.box.columnCount - 1
        case .cells:              coversWholeTable = false   // Phase 2c-T2: cell-rect delete lands with the structural commands (T2)
        }
        if coversWholeTable {
            editing {
                let para = BlockBox(paragraph: ParagraphBlock(id: BlockID.generate(), style: .body, runs: []),
                                    mapper: mapper, width: effectiveWidth)
                a.stack.boxes[a.index] = para   // stack-aware: replaces the table in its own stack, even nested
                recomputeSpans()
                return .caret(at: para.textStart)   // TASK 39: terminal claim → the body's return value
            }
        } else {
            switch sel.kind {
            case .rows:    deleteTableRow()      // reads structuralRowRange(); self-wraps in editing { }
            case .columns: deleteTableColumn()   // reads structuralColumnRange()
            case .cells:   break                 // Phase 2c-T2: cell-rect delete lands with the structural commands (T2)
            }
        }
        clearTableSelection()
    }

    /// Backspace at the START (local 0) of the top-level paragraph at `paragraphIndex` whose IMMEDIATELY
    /// PRECEDING block is a table: move the caret into the table and structurally select the WHOLE table
    /// (`.rows(0…last)`), so a SECOND Backspace deletes it via `deleteTableStructuralSelection`. An empty
    /// trailing paragraph is removed first, so the two-press model matches the non-empty case. Returns
    /// false (no-op) when the previous block isn't a `TableBlockBox` — the caller then handles the other
    /// non-paragraph atoms (image / code) unchanged.
    func selectPrecedingTableOnBackspace(paragraphIndex: Int) -> Bool {
        let tableIndex = paragraphIndex - 1
        guard tableIndex >= 0, boxes[tableIndex] is TableBlockBox else { return false }
        // The table's last-cell end; computed before any removal. Removing a LATER block does not shift it.
        let prev = prevTextPosition(before: boxes[paragraphIndex].textStart)
        if boxes[paragraphIndex].textLength == 0 {
            editing { removeBlockOutcome(at: paragraphIndex, parkingCaretAt: prev) }   // drop the empty trailing paragraph
        } else {
            // TASK 39: `applyCaretOutcome`, applied IMMEDIATELY and not returned — this branch is in no
            // `editing { }` at all, and `selectTableRows` two lines below re-resolves `activeTable()`,
            // which locates the caret's cell via `cellLocation(containing: head)`. A deferred claim would
            // hand it the PRE-move caret. (It is also why a publishing `setSelection` is wrong here twice
            // over: `selectTableRows` opens its own selection bracket right after.)
            applyCaretOutcome(.caret(at: prev))                                 // move the caret into the table
        }
        if let table = boxes[tableIndex] as? TableBlockBox {
            selectTableRows(0...max(table.rowCount - 1, 0))                     // whole-table structural selection
        }
        return true
    }

    func deleteTableColumn() {
        guard let a = activeTable() else { return }
        guard case .table(let table) = a.box.currentBlock() else { return }
        let range = structuralColumnRange() ?? (a.col...a.col)
        let removable = range.filter { table.columns.indices.contains($0) }.count
        guard table.columnCount > removable else { return }   // never delete every column
        editing {
            replaceTable(at: a.index, in: a.stack, with: table.removingColumns(in: range),
                         caretRow: a.row, caretCol: range.lowerBound)
            return .unchanged
        }
    }

    /// The cells covered by the current structural selection (a row-range's cells, or a column-range's cells),
    /// as (row, column) coords in `box`. Falls back to the caret's single cell when no structural selection.
    func selectedCellCoords(in box: TableBlockBox) -> [(row: Int, column: Int)] {
        let rowCount = box.rowCount, colCount = box.columnCount
        if let rows = structuralRowRange() {
            return rows.filter { (0..<rowCount).contains($0) }.flatMap { r in (0..<colCount).map { (r, $0) } }
        }
        if let cols = structuralColumnRange() {
            return cols.filter { (0..<colCount).contains($0) }.flatMap { c in (0..<rowCount).map { ($0, c) } }
        }
        if let rect = structuralCellRect() {
            return box.tableMap().cellsInRect(rect).map { (row: $0.row, column: $0.column) }
        }
        if let a = activeTable(), a.box.id == box.id { return [(a.row, a.col)] }
        return []
    }

    func setSelectionHorizontalAlignment(_ alignment: TextAlignment) {
        setSelectionAlignment(horizontal: alignment, vertical: nil)
    }
    func setSelectionVerticalAlignment(_ alignment: VerticalAlignment) {
        setSelectionAlignment(horizontal: nil, vertical: alignment)
    }

    /// Sets horizontal and/or vertical alignment on every cell of the current structural selection. A nil axis
    /// is left unchanged (partial apply — the "mixed" case). One undo step; preserves the structural selection.
    /// Internal (NOT private): the descriptor builder in `+TableControls.swift` calls it, and Swift `private`
    /// is file-scoped.
    func setSelectionAlignment(horizontal: TextAlignment?, vertical: VerticalAlignment?) {
        guard let a = activeTable(), horizontal != nil || vertical != nil else { return }
        editing {
            guard case .table(var t) = a.box.currentBlock() else { return .unchanged }
            for (r, c) in selectedCellCoords(in: a.box) where t.rows.indices.contains(r) && t.rows[r].cells.indices.contains(c) {
                if let h = horizontal { t.rows[r].cells[c].horizontalAlignment = h }
                if let v = vertical { t.rows[r].cells[c].verticalAlignment = v }
            }
            replaceTable(at: a.index, in: a.stack, with: t, caretRow: a.row, caretCol: a.col)
            return .unchanged
        }
    }

    /// Toggles the header/highlight flag on every cell of the current structural selection (or the caret's
    /// single cell when there is none). Mixed/none → all ON; all-header → all OFF. One undo step; preserves
    /// the structural selection. Mirrors `setSelectionAlignment`.
    func toggleSelectionHeader() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(var t) = a.box.currentBlock() else { return .unchanged }
            let coords = selectedCellCoords(in: a.box).filter { t.rows.indices.contains($0.row) && t.rows[$0.row].cells.indices.contains($0.column) }
            guard !coords.isEmpty else { return .unchanged }
            let newValue = !coords.allSatisfy { t.rows[$0.row].cells[$0.column].isHeader }
            for (r, c) in coords { t.rows[r].cells[c].isHeader = newValue }
            replaceTable(at: a.index, in: a.stack, with: t, caretRow: a.row, caretCol: a.col)
            return .unchanged
        }
    }

    /// Flips the caret's table between compact and normal cell padding, as ONE undo step. No-op when
    /// the caret is not in a table.
    func toggleTableCompact() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(var t) = a.box.currentBlock() else { return .unchanged }
            t.compact.toggle()
            replaceTable(at: a.index, in: a.stack, with: t, caretRow: a.row, caretCol: a.col)
            return .unchanged
        }
    }

    /// Shows / hides the table's grid. Not merely a paint toggle: an unbordered table lays out with
    /// zero-width borders, so the cells butt together — mirroring V2's
    /// `bordered ? v2TableBorderWidth : 0.0`.
    ///
    /// The mirror is of the RULE, not of absolute pixels: the two surfaces' table constants already
    /// differ (border 1 vs `UIScreenPixel * 2`, cell insets 6/14 vs 13/7, corner radius 8 vs 10), so
    /// this removes the largest visual delta — a whole border per boundary — rather than achieving
    /// exact parity. Unlike the button pills, table geometry has no parity test pinning it.
    func toggleTableBordered() {
        guard let a = activeTable() else { return }
        editing {
            guard case .table(var t) = a.box.currentBlock() else { return .unchanged }
            t.bordered.toggle()
            replaceTable(at: a.index, in: a.stack, with: t, caretRow: a.row, caretCol: a.col)
            return .unchanged
        }
    }

    /// Merges the cells covered by the current `.cells` structural selection into one spanning cell — the
    /// content of every covered cell is concatenated into the top-left (anchor) cell (see
    /// `TableBlock.mergingCells`). No-op, registering NO undo step, when the caret isn't in a table, there
    /// is no `.cells` selection, or the (already-expanded) rect resolves to a single cell (nothing to
    /// merge) — the single-cell check runs BEFORE `editing { }` so a no-op can't register a step.
    func mergeSelectedCells() {
        guard let a = activeTable(), let rect = structuralCellRect() else { return }
        guard a.box.tableMap().cellsInRect(rect).count > 1 else { return }   // no-op: already a single cell
        editing {
            guard case .table(let t) = a.box.currentBlock() else { return .unchanged }
            replaceTable(at: a.index, in: a.stack, with: t.mergingCells(in: rect), caretRow: rect.top, caretCol: rect.left)
            return .unchanged
        }
    }

    /// Splits the caret's merged cell back into a dense grid of single (empty, except the anchor which
    /// keeps all the pooled content) cells (see `TableBlock.splittingCell`). Resolves the target via the
    /// CARET's covering anchor (`activeTable().row/col`, already the anchor's physical origin — 2b made
    /// `cellLocation` return physical), not a `.cells` selection, so it works equally from a bare caret
    /// sitting in a merged cell and from a `.cells` selection that resolves to that one merged cell.
    /// No-op when the caret isn't in a table or its cell isn't merged (`colspan == rowspan == 1`).
    func splitSelectedCell() {
        guard let a = activeTable(),
              let anchor = a.box.tableMap().anchor(atRow: a.row, column: a.col),
              anchor.colspan > 1 || anchor.rowspan > 1 else { return }
        editing {
            guard case .table(let t) = a.box.currentBlock() else { return .unchanged }
            replaceTable(at: a.index, in: a.stack, with: t.splittingCell(at: (anchor.row, anchor.column)),
                         caretRow: anchor.row, caretCol: anchor.column)
            return .unchanged
        }
    }

    /// Creates an empty `rows`×`columns` table (row 0 a header) at the caret, mirroring `insertMedia`:
    /// clears any selection, then splits the caret's paragraph if mid-text, else inserts at the block
    /// boundary. No-op unless the caret is in a top-level paragraph (no nested tables; not on an
    /// image/gap) — guarded BEFORE `editing { }` so a no-op registers no undo entry. Caret lands in the
    /// first header cell.
    func insertTable(rows: Int, columns: Int) {
        // Insert into the caret's OWN stack — top level OR a detail block's body — via the container-aware
        // `activeStack` (NOT `resolveBox`, which mis-resolves a container-interior position to the following
        // top-level block). `!isInsideTable` prevents nested tables; `!isInsideBlockQuote` keeps tables out of
        // quotes (unsupported in v1); a detail body is allowed (its `activeStack` resolves to the body stack,
        // and nested tables there are laid out by `DetailsBox.recompute`).
        guard !boxes.isEmpty, !isInsideTable(head), !isInsideBlockQuote(head),
              let a = activeStack(at: head), a.box is BlockBox else { return }
        // Deliberately do NOT becomeFirstResponder here (matches `insertMedia`): inserting a table must not
        // steal focus / pop the keyboard when the editor is unfocused. The caret is still placed live in the
        // new table's first cell below (model caret). When already focused, that caret is scrolled into view
        // synchronously (FR-gated `scrollCaretIntoView` → `performLayout`); when unfocused, the new table is
        // laid out by the host's async `update()` on `onChange` (a later tap focuses + operates on the cells).
        editing {
            // THE CLAIM IS APPLIED HERE, ON THE NEXT INSTRUCTION — never batched to the end of this
            // transaction's own `return`: the next statement's `activeStack(at: head)` reads the caret back. A deferred claim re-resolves at the
            // pre-delete caret and silently produces a DIFFERENT document. Why, and the full list of
            // fourteen such sites: `applyReplaceOutcome`'s doc in `+Editing.swift`. Pinned by
            // `CanvasInsertTableTests.test_insertTable_midParagraph_splitsParagraph`.
            if selFrom != selTo {
                applyCaretOutcome(applySelectionReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: ""))
            }
            guard let active = activeStack(at: head), let p = active.box as? BlockBox else { return .unchanged }
            let tableBox = TableBlockBox(table: TableBlock.empty(rows: rows, columns: columns),
                                         mapper: mapper, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            let idx = active.index
            if p.textLength == 0 {
                newBoxes.replaceSubrange(idx...idx, with: [tableBox])   // empty paragraph → replace it
            } else if active.local > 0, active.local < p.textLength {
                let (upper, lower) = p.currentParagraph().split(at: active.local, newID: BlockID.generate())
                let upperBox = BlockBox(paragraph: upper, mapper: p.mapper, width: effectiveWidth)
                let lowerBox = BlockBox(paragraph: lower, mapper: p.mapper, width: effectiveWidth)
                let replacement: [any CanvasBlock] = [upperBox, tableBox, lowerBox]
                newBoxes.replaceSubrange(idx...idx, with: replacement)
            } else if active.local == 0 {
                newBoxes.insert(tableBox, at: idx)            // before the caret's block
            } else {
                newBoxes.insert(tableBox, at: idx + 1)        // after the caret's block
            }
            active.stack.boxes = newBoxes
            recomputeSpans()
            // TASK 39: terminal claim → the body's return value. The `activeStack(at: head)` read that
            // makes this function a read-back site is ABOVE, against the already-converted
            // `applySelectionReplaceOutcome` claim; nothing below reads the caret back.
            if let caret = tableBox.cellTextStart(row: 0, column: 0) { return .caret(at: caret) }
            return .unchanged
        }
    }
}
#endif
