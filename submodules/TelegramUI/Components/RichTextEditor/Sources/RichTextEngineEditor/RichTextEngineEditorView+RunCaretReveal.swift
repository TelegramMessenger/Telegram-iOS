#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecHost

/// **A table wider than the field scrolls sideways to the caret** (composer harness p14,
/// `HarnessTableCaretRevealTests`).
///
/// A table is laid out in its own horizontally scrolling run (`IDPlacedRunScrollView`), and the
/// vertical reveal (`RichTextCaretRevealSolver`) deliberately leaves the horizontal axis to that run
/// (`RichTextEditorCore/CaretReveal.swift`). Nothing did it: the run had no caret logic and the host
/// only ever restored a remembered offset around a table edit. So typing in a column past the right
/// edge — after a rotation to portrait, after Tab or → into it — landed off screen with the run at 0.
///
/// **When** is the vertical reveal's rule, decided in the same place (`performCaretReveal`, inside a
/// host's layout pass): when something ASKED — a text or selection change since the last reveal
/// (`tgid_caretRevealPending`) — or when the pass changed the WIDTH the table is laid out against. It is
/// then OWED (`placedRunCaretRevealOwed`) and spent by this view's own `layoutSubviews`, after
/// `syncTableFrames` has placed the tables: measured inside the host's pass, right after a redo re-created
/// a table, the cells were not yet at their real widths, the caret read as inside the column, and nothing
/// scrolled (fuzz seed 34, `HarnessComposerFuzzTests.testEngineFuzzSeed34WidthRoundTrip`).
/// A height-only pass (the keyboard) cannot move the caret sideways, so it does not count here, and
/// that is what leaves a user's manual horizontal scroll alone: a pass with no caret move and no width
/// change never touches the run.
///
/// **What** is revealed is the selection's END — the caret, or where typing over a selection goes
/// (Tab selects a cell) — against the table's own COLUMN, which is where the engine rests a run's far
/// edge (`tableColumnOutsets`), not the wider clip window. The margins are the vertical reveal's: the
/// caret rect itself, plus its ends rule translated to columns — a caret in the FIRST column reveals
/// the table's leading edge (offset 0), one in the LAST column its trailing edge, as long as the caret
/// is still in view there (a last cell wider than the column keeps the minimum scroll).
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    /// Scrolls the placed run holding the selection's end so that end is inside the table's column.
    /// Returns whether the run moved.
    @discardableResult
    internal func revealSelectionEndInPlacedRun() -> Bool {
        guard let selection = engine.selectedTextRange else { return false }
        let offset = engine.offset(from: engine.beginningOfDocument, to: selection.end)
        guard let index = roleIndex(atFlatOffset: offset), index < currentRoles.count,
              let table = currentRoles[index].owningTable,
              let runContent = engine.id_placedRunContentViewForBlock(at: UInt(index)),
              let run = runContent.superview as? UIScrollView else { return false }
        let caret = engine.caretRect(for: selection.end)
        guard !caret.isNull, caret.minX.isFinite, caret.maxX.isFinite else { return false }

        let column = tableColumnOutsets(forTableAt: index)
        let columnMin = engine.textContainerInset.left - column.left
        let columnMax = engine.textContainerInset.left + availableTableWidth + column.right
        guard columnMax > columnMin else { return false }
        let current = engine.id_placedRunContentOffsetForBlock(at: UInt(index))

        var target: CGFloat
        if caret.minX < columnMin - 0.5 {
            target = current - (columnMin - caret.minX)
        } else if caret.maxX > columnMax + 0.5 {
            target = current + (caret.maxX - columnMax)
        } else {
            return false
        }
        // The ends rule: the first column reveals the table's leading edge, the last its trailing
        // edge — but only where the caret stays in view. The maximum is the engine's own clamp
        // (`-[IDBlockStackCanvasView setPlacedRunContentOffset:forBlockIdentifier:]`).
        let maximum = max(run.contentSize.width - run.bounds.width, 0.0)
        if let cellColumn = currentRoles[index].tableCellCoordinates?.column {
            if cellColumn == 0, target < current, caret.maxX + current <= columnMax + 0.5 {
                target = 0.0
            } else if cellColumn == table.columns.count - 1, target > current,
                      caret.minX - (maximum - current) >= columnMin - 0.5 {
                target = maximum
            }
        }
        engine.id_setPlacedRunContentOffset(target, forBlockAt: UInt(index))
        let applied = engine.id_placedRunContentOffsetForBlock(at: UInt(index))
        guard abs(applied - current) >= 0.5 else { return false }
        // The host's record of the run's offset follows, or `pushRunScrollOffsets` (a height probe)
        // would put the old one back.
        runScrollOffsets[table.id] = applied
        // The chrome, overlays and the drawn caret are placed from the run's offset.
        setNeedsLayout()
        return true
    }
}
#endif
