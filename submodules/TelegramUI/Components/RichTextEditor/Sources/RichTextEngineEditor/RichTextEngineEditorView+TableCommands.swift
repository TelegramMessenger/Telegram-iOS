#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// R7-tables rung A — the table the caret is in, and the five commands that act on it.
///
/// Everything here hangs off `tableAtCaret`. A table owns no secondary line (unlike a quote's author
/// or a details' title), so its roles are one contiguous run of cells and the run IS the table —
/// which is why both `syncTableChrome` and `+TableLayout` already walk it exactly this way.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The contiguous role run of the table with this id, or nil when no role names it.
    ///
    /// Resolved by IDENTITY rather than by a captured range, so `applyTableShape`'s undo can re-enter
    /// after other edits have moved the table.
    internal func roleRun(ofTableWithID id: BlockID) -> Range<Int>? {
        guard let lower = currentRoles.firstIndex(where: { $0.owningTable?.id == id }) else { return nil }
        var upper = lower + 1
        while upper < currentRoles.count, currentRoles[upper].containerID == id { upper += 1 }
        return lower ..< upper
    }

    /// The table the selection is in: its shape, and the run of roles that are its cells.
    ///
    /// EITHER ENDPOINT counts, mirroring legacy's `isInsideTable(head) || isInsideTable(anchor)`: a
    /// selection that merely overlaps a table still enables the table commands in the toolbar.
    internal func tableAtCaret() -> (shape: TableShape, roles: Range<Int>)? {
        let touched = touchedBlockIndices(for: engineSelectedRange)
        guard let seed = touched.first(where: { currentRoles[$0].owningTable != nil }),
              let shape = currentRoles[seed].owningTable,
              let roles = roleRun(ofTableWithID: shape.id) else { return nil }
        return (shape, roles)
    }

    // MARK: - Flag toggles

    /// Rewrites the `TableShape` carried by every one of a table's cell roles.
    ///
    /// Modelled on `applyButtonRowShape`: plan, adopt, restore the selection, register the inverse,
    /// relayout. Undo history SURVIVES, unlike the document-swap path
    /// (`recordUndoStepForStructuralChange` removes all actions) — losing everything typed before a
    /// borders toggle would be real damage.
    ///
    /// There is NO attachment to re-derive, which is where this differs from `applyButtonRowShape`: a
    /// button row's labels ride in its attachment, while a table's presentation is chrome plus placed
    /// cells and BOTH `syncTableChrome` and `+TableLayout` read `currentRoles[…].owningTable` on every
    /// layout pass. The new geometry follows from the plan with no second source to update.
    internal func applyTableShape(_ shape: TableShape, restoring previous: TableShape, at roles: Range<Int>) {
        let undoBefore = currentUndoSnapshot()
        var plan = currentRoles
        for index in roles where index < plan.count {
            plan[index] = currentRoles[index].replacingOwningTable(shape)
        }
        let selection = engineSelectedRange
        performHostStructuralChange {
            adoptRolePlan(plan)
            engineSelectedRange = selection
        }
        recordUndoStepForCommand(restoring: undoBefore)
        // NO `deliverChangeNotificationNow()` here. `performHostStructuralChange` already wraps the
        // body in `deliveringOneChangeNotification` — "one notification for the change and everything
        // settle does in response to it" — so a delivery beside it makes the same toggle notify twice.
        // `applyMediaShape`, the original of this shape, ends here too.
        setNeedsLayout()
    }

    /// Shows / hides the grid. Not merely a paint toggle: an unbordered table lays out with
    /// zero-width borders so the cells butt together, mirroring V2's
    /// `bordered ? v2TableBorderWidth : 0.0`.
    public func toggleTableBordered() {
        guard let (shape, roles) = tableAtCaret() else { return }
        var updated = shape
        updated.bordered.toggle()
        applyTableShape(updated, restoring: shape, at: roles)
    }

    /// Tighter cell insets.
    public func toggleTableCompact() {
        guard let (shape, roles) = tableAtCaret() else { return }
        var updated = shape
        updated.compact.toggle()
        applyTableShape(updated, restoring: shape, at: roles)
    }

    // MARK: - Removing and flattening

    /// The flat range spanning a run of roles — the separators BETWEEN them included, nothing outside.
    internal func wholeRunRange(_ roles: Range<Int>) -> NSRange {
        let start = flatOffset(ofRoleAt: roles.lowerBound)
        let end = NSMaxRange(flatRange(ofRoleAt: roles.upperBound - 1))
        return NSRange(location: start, length: end - start)
    }

    /// Removes the caret's whole table.
    ///
    /// `deleteButtonRow`'s shape generalised from one role to a run, separator arithmetic included:
    /// blocks are joined by "\n", so removing N of M blocks must remove N separators to leave M−N−1.
    /// N−1 of them are the run's own internal ones (already inside `wholeRunRange`); the extra one is
    /// taken BEFORE the run, or AFTER it when the run starts at role 0 and has nothing before it.
    public func deleteTable() {
        guard let (_, roles) = tableAtCaret() else { return }
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                var plan = currentRoles
                let run = wholeRunRange(roles)
                guard roles.count < currentRoles.count else {
                    // The whole document is this table. The engine always holds one block, so the run
                    // collapses to a single empty body paragraph rather than being removed.
                    let ancestry = currentRoles[roles.lowerBound].ancestry
                    plan.replaceSubrange(roles, with: [freshBodyRole(within: ancestry)])
                    replaceFlat(run, with: "", adopting: plan)
                    engineSelectedRange = NSRange(location: run.location, length: 0)
                    return
                }
                let cut = roles.lowerBound > 0
                    ? NSRange(location: run.location - 1, length: run.length + 1)
                    : NSRange(location: run.location, length: run.length + 1)
                plan.removeSubrange(roles)
                replaceFlat(cut, with: "", adopting: plan)
                engineSelectedRange = NSRange(location: cut.location, length: 0)
            }
        }
        setNeedsLayout()
    }

    /// Replaces the caret's table with one body paragraph per row, the row's cells joined by " ".
    ///
    /// Reads the MATERIALISED block, not the shape: `TableShape` carries columns, rows and the two
    /// flags but NO cell content (`emptyTable` is named for that), so flattening the shape would
    /// produce blank lines while a debugger showed plausible rows and columns.
    public func convertCurrentTableToText() {
        guard let (shape, roles) = tableAtCaret(),
              let block = document.blocksByID[shape.id], case let .table(table) = block else { return }
        var lines = tableFlattenedText(table)
        if lines.isEmpty { lines = [""] }
        let ancestry = currentRoles[roles.lowerBound].ancestry
        // Each line converted SEPARATELY, then joined by a raw "\n". `engineText` exists to stop a
        // newline splitting a block — it maps every "\n" to the line separator — so converting the
        // joined string yields ONE block of N lines, and the role plan then expects N blocks against
        // an edit that produced 1. A cell's own newline must still be converted, hence per line.
        let text = lines.map(EngineDocumentBridge.engineText).joined(separator: "\n")
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                var plan = currentRoles
                plan.replaceSubrange(roles, with: lines.map { _ in freshBodyRole(within: ancestry) })
                // `wholeRunRange`, NOT the removal cut: N blocks become M, and the joined "\n"
                // supplies the M−1 separators the replacement needs.
                let run = wholeRunRange(roles)
                replaceFlat(run, with: text, adopting: plan)
                engineSelectedRange = NSRange(location: run.location, length: 0)
            }
        }
        setNeedsLayout()
    }

    /// Copies the caret's table to the pasteboard as a document containing ONLY that table: the app
    /// fragment (JSON, pastes back as a real table), an RTF table, and a plain-text flatten.
    ///
    /// A pure read — no edit, no undo step, no change notification. A copy that shows up in the undo
    /// stack is a defect a user reports as "undo did nothing". Reads the MATERIALISED block for the
    /// reason `convertCurrentTableToText` does: the shape has no cell content.
    public func copyCurrentTable() {
        guard let (shape, _) = tableAtCaret(),
              let block = document.blocksByID[shape.id], case let .table(table) = block else { return }
        let item = RichTextEditorClipboard.pasteboardItem(
            for: Document(blocks: [.table(table)]),
            plain: tableFlattenedText(table).joined(separator: "\n"))
        pasteboard.setItems([item], options: [:])
    }
}
#endif
