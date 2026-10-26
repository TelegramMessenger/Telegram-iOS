#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// R7-tables rung B — the structural selection axis.
///
/// A second axis alongside the text selection: the caret PARKS in the range's first cell so the
/// structural commands resolve to it, while the range itself is what the chrome draws and what
/// formatting applies across.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    // MARK: - Reads

    internal func structuralRowRange() -> ClosedRange<Int>? {
        if case let .rows(range)? = tableStructuralSelection?.kind { return range }
        return nil
    }

    internal func structuralColumnRange() -> ClosedRange<Int>? {
        if case let .columns(range)? = tableStructuralSelection?.kind { return range }
        return nil
    }

    internal func structuralCellRect() -> TableRect? {
        if case let .cells(rect)? = tableStructuralSelection?.kind { return rect }
        return nil
    }

    /// The rect the cell chrome surrounds: a committed `.cells` selection, or — with nothing committed
    /// — the caret's own covering rect (the WHOLE merged cell when the caret is inside one).
    ///
    /// That second half is the "focus chrome": an outline and four corner knobs on every table the
    /// caret enters, which is what makes the corner drag discoverable and is legacy's behaviour.
    internal func focusedOrSelectedCellRect() -> TableRect? {
        if let rect = structuralCellRect() { return rect }
        guard let index = roleIndex(atFlatOffset: engineSelectedRange.location),
              let table = currentRoles[index].owningTable,
              let coordinates = currentRoles[index].tableCellCoordinates else { return nil }
        return TableMap(table.emptyTable).coveringRect(atRow: coordinates.row, column: coordinates.column)
    }

    /// The flat range of every cell the structural selection covers, in row-major order. Empty when
    /// there is no structural selection — which is what lets a formatting command fall through to its
    /// ordinary single-selection path.
    /// The ranges an INLINE format command acts on, when that is not simply the selection: the
    /// covered cells of a table's structural selection, or the selection with every code-block
    /// LANGUAGE line taken out of it. nil — no structural selection, and no language line touched —
    /// means the ordinary single-selection path. An empty array means the selection holds nothing a
    /// format can reach, and the command does nothing.
    ///
    /// A language line is excluded because the model cannot carry a format there:
    /// `CodeBlock.language` is a plain string, so a spoiler, italic, monospace or strikethrough
    /// applied to it was drawn on screen and absent from the message (composer harness, 2026-09-23,
    /// `HarnessCodeLanguageFormatTests`). The same line already refuses text services
    /// (`+CodeInputTraits.swift`); this is the formatting half of that rule. A collapsed caret in
    /// the line changes nothing either — a typing attribute there would format what is typed next.
    ///
    /// ITALIC also skips a pull quote's BODY (`excludingPullQuoteBodies`). A pull quote's slant is
    /// the role's, the mapper's read-back strips italic there (`ca.italic = style == .pullQuote ?
    /// false : …`), so the model can never carry it — the same "format the model cannot carry" as a
    /// language line. Left to the engine's toggle, the marker landed on every run, and on an
    /// INLINE-CODE run, whose base face the role composes upright, it slanted the code on screen
    /// while the model stayed unchanged; the next normalisation redrew the code upright and kept the
    /// marker, so the drift outlived the slant (composer harness, 2026-09-23, fuzz seed 82,
    /// `HarnessPullQuoteItalicOverCodeTests`). Toggling italic in a pull quote is therefore a no-op,
    /// in the model and on screen — what the tenth wave already made it for plain text.
    ///
    /// A code block's BODY is excluded for every inline format (composer harness p20,
    /// `HarnessSendPathCodeFormattingTests`). A code block is plain text in this editor, because it
    /// is plain text everywhere it goes: a message of paragraphs, quotes and code is sent as text
    /// + entities, where a code block is a `Pre` entity and a Telegram `Pre` / `Code` entity can
    /// contain no other entity (the Bot API's nesting rule; the shared decoder reads a code region
    /// back as ONE plain run), and the legacy composer's model holds code as plain text too. A Bold
    /// or a link applied inside code was drawn and kept in the model, then dropped by the send — and
    /// sent after all when a heading elsewhere moved the message onto the rich route, so one
    /// composer state sent two messages. The bridge reads a code body back as plain runs
    /// (`EngineDocumentBridge.plainCodeRuns`), and presentation settles it plain.
    ///
    /// The selection is also WIDENED to composed-character boundaries (`composedCharacterRange`):
    /// a format over half an emoji's surrogate pair split the run inside the pair and the model read
    /// each lone surrogate as `U+FFFD`, sent as two replacement characters while the composer showed
    /// the emoji (composer harness p20, `HarnessFormatSplitSurrogateTests`). A widened selection is
    /// answered as a one-range list, so the per-range path formats the whole character and the
    /// user's selection is left as it was.
    ///
    /// `includingTableCells: false` leaves a table's structural selection to the caller's ordinary
    /// path (a link, which has never applied across cells).
    internal func inlineFormatTargetRanges(excludingPullQuoteBodies: Bool = false,
                                           includingTableCells: Bool = true) -> [NSRange]? {
        if includingTableCells {
            let cells = structuralSelectionCellRanges()
            if !cells.isEmpty { return cells.map { composedCharacterRange($0) } }
        }
        let selection = engineSelectedRange
        let widened = composedCharacterRange(selection)
        func excluded(_ index: Int) -> Bool {
            let role = currentRoles[index]
            if role.secondaryKind == .codeLanguage { return true }
            if case .standalone(.code) = role.position { return true }
            if excludingPullQuoteBodies, case .standalone(.pullQuote) = role.position { return true }
            return false
        }
        guard currentRoles.indices.contains(where: excluded) else {
            return widened == selection ? nil : [widened]
        }
        if selection.length == 0 {
            guard let index = roleIndex(atFlatOffset: selection.location), index < currentRoles.count,
                  excluded(index) else { return nil }
            return []
        }
        let touched = touchedBlockIndices(for: widened)
        let reachesAnExcludedLine = touched.contains { index in
            excluded(index) && NSIntersectionRange(widened, flatRange(ofRoleAt: index)).length > 0
        }
        guard reachesAnExcludedLine else { return widened == selection ? nil : [widened] }
        return touched.compactMap { index -> NSRange? in
            guard !excluded(index) else { return nil }
            let part = NSIntersectionRange(widened, flatRange(ofRoleAt: index))
            return part.length > 0 ? part : nil
        }
    }

    /// `range` with each end that falls INSIDE a composed character sequence (a surrogate pair, an
    /// emoji with its modifier, a base with its marks) moved outward to the sequence's edge, on the
    /// engine's flat axis. A collapsed range is returned as it is.
    internal func composedCharacterRange(_ range: NSRange) -> NSRange {
        guard range.length > 0 else { return range }
        let blocks = engine.attributedBlocks
        func snapped(_ offset: Int, outwardIsDown: Bool) -> Int {
            guard let index = roleIndex(atFlatOffset: offset), index < blocks.count else { return offset }
            let start = flatOffset(ofRoleAt: index)
            let text = blocks[index].string as NSString
            let local = offset - start
            guard local > 0, local < text.length else { return offset }
            let sequence = text.rangeOfComposedCharacterSequence(at: local)
            guard sequence.location != local else { return offset }
            return start + (outwardIsDown ? sequence.location : NSMaxRange(sequence))
        }
        let lo = snapped(range.location, outwardIsDown: true)
        let hi = snapped(NSMaxRange(range), outwardIsDown: false)
        return NSRange(location: lo, length: hi - lo)
    }

    internal func structuralSelectionCellRanges() -> [NSRange] {
        guard let selection = tableStructuralSelection,
              let roles = roleRun(ofTableWithID: selection.table),
              let table = currentRoles[roles.lowerBound].owningTable else { return [] }
        let map = TableMap(table.emptyTable)
        let rect: TableRect
        switch selection.kind {
        case let .rows(range):
            rect = TableRect(top: range.lowerBound, left: 0, bottom: range.upperBound, right: map.columns - 1)
        case let .columns(range):
            rect = TableRect(top: 0, left: range.lowerBound, bottom: map.rows - 1, right: range.upperBound)
        case let .cells(committed):
            rect = committed
        }
        return map.cellsInRect(rect).compactMap { anchor in
            roles.first { currentRoles[$0].blockID == anchor.cellID }.map { flatRange(ofRoleAt: $0) }
        }
    }

    // MARK: - Selecting

    internal func selectTableRows(_ range: ClosedRange<Int>) {
        guard let (table, roles) = tableAtCaret() else { return }
        let map = TableMap(table.emptyTable)
        guard map.rows > 0 else { return }
        let clamped = clamped(range, upperLimit: map.rows - 1)
        commitStructuralSelection(.rows(clamped), table: table, roles: roles,
                                  parkingAtRow: clamped.lowerBound, column: 0, map: map)
    }

    internal func selectTableColumns(_ range: ClosedRange<Int>) {
        guard let (table, roles) = tableAtCaret() else { return }
        let map = TableMap(table.emptyTable)
        guard map.columns > 0 else { return }
        let clamped = clamped(range, upperLimit: map.columns - 1)
        commitStructuralSelection(.columns(clamped), table: table, roles: roles,
                                  parkingAtRow: 0, column: clamped.lowerBound, map: map)
    }

    /// EXPANDED before it is stored, so a rect that merely bisects a merged cell is grown to cover it.
    internal func selectTableCells(_ rect: TableRect) {
        guard let (table, roles) = tableAtCaret() else { return }
        let map = TableMap(table.emptyTable)
        let expanded = map.expanded(rect)
        commitStructuralSelection(.cells(expanded), table: table, roles: roles,
                                  parkingAtRow: expanded.top, column: expanded.left, map: map)
    }

    internal func clearTableStructuralSelection() {
        guard tableStructuralSelection != nil else { return }
        tableStructuralSelection = nil
        setNeedsLayout()
    }

    // MARK: - Shared

    private func clamped(_ range: ClosedRange<Int>, upperLimit: Int) -> ClosedRange<Int> {
        let lower = min(max(range.lowerBound, 0), upperLimit)
        let upper = min(max(range.upperBound, lower), upperLimit)
        return lower...upper
    }

    /// Parks the caret in the range's first cell, then stores the selection.
    ///
    /// The caret move is BRACKETED for the input delegate, so a hardware arrow navigates from the
    /// selected row rather than the stale prior caret — and it deliberately does NOT fire `onChange`:
    /// legacy records that publishing here invents a host selection report on every row/column tap.
    ///
    /// `isParkingCaretForStructuralSelection` is what stops the selection funnel from clearing the
    /// selection this call is in the middle of making. It is the flag, not a per-site exemption,
    /// because the funnel is the ONE place that clears.
    private func commitStructuralSelection(_ kind: EngineTableStructuralSelection,
                                           table: TableShape, roles: Range<Int>,
                                           parkingAtRow row: Int, column: Int, map: TableMap) {
        guard let anchor = map.anchor(atRow: row, column: column),
              let index = roles.first(where: { currentRoles[$0].blockID == anchor.cellID }) else { return }
        isParkingCaretForStructuralSelection = true
        engine.inputDelegate?.selectionWillChange(engine)
        engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: index), length: 0)
        engine.inputDelegate?.selectionDidChange(engine)
        isParkingCaretForStructuralSelection = false
        tableStructuralSelection = (table.id, kind)
        setNeedsLayout()
    }

    // MARK: - Dragging a knob

    /// The chrome struct for the table the chrome is showing, or nil.
    internal func structuralChromeGeometry() -> EngineTableStructuralChrome? {
        guard let (table, _) = structurallyChromedTable(), let grid = tableGrids[table.id] else { return nil }
        let map = TableMap(table.emptyTable)
        return EngineTableStructuralChrome(grid: grid, rowCount: map.rows, columnCount: map.columns,
                                           selection: tableStructuralSelection?.kind,
                                           focusedCell: focusedOrSelectedCellRect())
    }

    /// Moves one END of a row/column range to the slot under `point`, the other end fixed.
    ///
    /// The dragged end cannot cross the fixed one — the range floors at width 1 and never swaps —
    /// and both are bounded to the grid. No `onChange`: a live drag reports many transient ranges and
    /// none of them is a content change.
    internal func extendTableSelection(end: TableRangeEnd, towardTableLocal point: CGPoint) {
        guard let selection = tableStructuralSelection, let geometry = structuralChromeGeometry() else { return }
        let updated: EngineTableStructuralSelection
        switch selection.kind {
        case let .rows(range):
            let moved = geometry.rowIndex(atY: point.y)
            updated = .rows(end == .upper ? range.lowerBound ... max(moved, range.lowerBound)
                                          : min(moved, range.upperBound) ... range.upperBound)
        case let .columns(range):
            let moved = geometry.columnIndex(atX: point.x)
            updated = .columns(end == .upper ? range.lowerBound ... max(moved, range.lowerBound)
                                             : min(moved, range.upperBound) ... range.upperBound)
        case .cells:
            return   // a cell rect is dragged by its CORNER knobs, not by an end.
        }
        tableStructuralSelection = (selection.table, updated)
        setNeedsLayout()
    }

    /// Drags a cell rect by one CORNER, against the OPPOSITE corner of the current rect.
    ///
    /// The current rect is the committed `.cells` selection when there is one and otherwise the
    /// FOCUSED cell — which is what makes a drag started on the focus chrome PROMOTE it to a committed
    /// selection on its very first update, with no separate promotion step to forget.
    ///
    /// The moved cell is the physical slot under the finger (span-neutral, already clamped), and the
    /// result is EXPANDED like every other write, so a drag that lands on a merged cell cannot store a
    /// rect that half-covers it.
    internal func extendCellSelection(corner: TableCellCorner, towardTableLocal point: CGPoint) {
        guard let (table, _) = structurallyChromedTable(),
              let geometry = structuralChromeGeometry(),
              let current = focusedOrSelectedCellRect() else { return }
        let fixedRow: Int, fixedColumn: Int
        switch corner {
        case .topLeft:     fixedRow = current.bottom; fixedColumn = current.right
        case .topRight:    fixedRow = current.bottom; fixedColumn = current.left
        case .bottomLeft:  fixedRow = current.top;    fixedColumn = current.right
        case .bottomRight: fixedRow = current.top;    fixedColumn = current.left
        }
        let movedRow = geometry.rowIndex(atY: point.y)
        let movedColumn = geometry.columnIndex(atX: point.x)
        let rect = TableRect(top: min(fixedRow, movedRow), left: min(fixedColumn, movedColumn),
                             bottom: max(fixedRow, movedRow), right: max(fixedColumn, movedColumn))
        tableStructuralSelection = (table.id, .cells(TableMap(table.emptyTable).expanded(rect)))
        setNeedsLayout()
    }

    // MARK: - Formatting across the selection

    /// Decides ONE value across every covered cell, then applies it to each — with the engine's
    /// selection parked on that cell for both halves, since the engine's reads and writes are both
    /// about its current selection.
    ///
    /// Returns false having done NOTHING when `inlineFormatTargetRanges()` answers nil — no structural
    /// selection and no code-block language line in the selection — so a caller falls through to its
    /// ordinary single-selection path. The same per-range walk serves the selection with its language
    /// lines taken out.
    ///
    /// Deciding once is what makes the result uniform: toggling each cell independently would leave a
    /// half-coded row exactly as mixed as it started, only inverted.
    ///
    /// The park is flagged, so the selection funnel does not clear the very selection being formatted
    /// across — and the selection SURVIVES the command, because formatting is not typing and the next
    /// command should act on the same row.
    @discardableResult
    internal func acrossStructuralSelection(deciding decide: () -> Bool,
                                            apply body: (Bool) -> Void) -> Bool {
        guard let ranges = inlineFormatTargetRanges() else { return false }
        // The whole selection is text an inline format cannot reach (a code block's language
        // line): handled, and nothing changes.
        guard !ranges.isEmpty else { return true }
        let restore = engineSelectedRange
        let selection = tableStructuralSelection
        isParkingCaretForStructuralSelection = true
        defer {
            engineSelectedRange = restore
            isParkingCaretForStructuralSelection = false
            tableStructuralSelection = selection
            setNeedsLayout()
        }
        var everyCell = true
        for range in ranges {
            engineSelectedRange = range
            if !decide() { everyCell = false }
        }
        let enabling = !everyCell
        deliveringOneChangeNotification {
            recordingInlineFormatStep(selection: restore) {
                for range in ranges {
                    engineSelectedRange = range
                    body(enabling)
                }
            }
        }
        return true
    }

    // MARK: - Backspace before a table

    /// Backspace at the start of the block after a TABLE selects the whole table instead of merging
    /// into it — legacy's `selectPrecedingTableOnBackspace`.
    ///
    /// An EMPTY trailing paragraph is removed (so the paragraph a table's Return minted can be taken
    /// back); a non-empty one is kept. Either way the caret travels to the table's last cell end
    /// first, because that is where the structural selection then parks it from.
    ///
    /// Lives in `backspaceJoinRules` with the other rules that SELECT rather than delete, so it runs
    /// before anything that might merge — and so it reaches BOTH doors, which is that array's whole
    /// purpose.
    internal func applySelectPrecedingTableOnBackspace(at index: Int) -> Bool {
        guard index > 0, currentRoles[index].owningTable == nil,
              currentRoles[index].secondaryKind == nil,
              case .paragraph = currentRoles[index].shape,
              let table = currentRoles[index - 1].owningTable else { return false }
        let lastCellEnd = NSMaxRange(flatRange(ofRoleAt: index - 1))
        if flatLength(ofRoleAt: index) == 0 {
            performHostStructuralEdit {
                var plan = currentRoles
                plan.remove(at: index)
                let range = flatRange(ofRoleAt: index)
                replaceFlat(NSRange(location: range.location - 1, length: range.length + 1),
                            with: "", adopting: plan)
                engineSelectedRange = NSRange(location: lastCellEnd, length: 0)
            }
        } else {
            engineSelectedRange = NSRange(location: lastCellEnd, length: 0)
        }
        let map = TableMap(table.emptyTable)
        guard map.rows > 0 else { return true }
        selectTableRows(0 ... map.rows - 1)
        return true
    }
}
#endif
