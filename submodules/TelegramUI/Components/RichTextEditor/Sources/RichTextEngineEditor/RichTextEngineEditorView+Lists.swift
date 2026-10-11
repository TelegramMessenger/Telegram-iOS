#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// How a list ENDS — the two ways out of one, both of which the engine editor lacked entirely.
///
/// A list item is an ordinary paragraph wearing a `ListMembership`, so neither exit is a container
/// operation: both just take the membership off. That is what makes them cheap here, and it is also
/// why their absence was invisible — nothing looked broken, the list simply had no way out.
///
/// **Backspace at the start of an item** outdents a nested one and un-lists a top-level one
/// (legacy's rule, `DocumentCanvasView.deleteBackward`). Without it the FIRST item of a list could
/// not be deleted at all: the engine merges a block into the one before it, and the first block has
/// nothing before it, so Backspace did nothing at all and the bullet could not be got rid of
/// (device, 2026-09-04). It also replaces the engine's own merge for the other items, which quietly
/// dragged a list item's text into the item above instead of ending the list.
///
/// **Return on an EMPTY item** outdents a nested one one level and ends the list for a top-level
/// one, at either end — the double-return escape the quote and
/// code containers already have. Pressing Return twice at the BOTTOM leaves a plain paragraph after
/// the list; pressing it twice at the TOP leaves one before it. The top case reads oddly until you
/// watch the caret: the first Return at offset 0 puts the new empty item ABOVE and leaves the caret
/// on the content line below it, so the second Return has to act on the item above the caret, not
/// the one it is in. `decideReturnInQuoteChild` has exactly the same pair for the same reason.
///
/// Both decide BEFORE the controller edits and veto it (surface-gate spec §3.1), so neither ever
/// produces the split the engine would otherwise make and then take back.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// Whether the caret sits at the very start of the list item at `index`.
    private func caretIsAtStartOfItem(_ index: Int, caret: Int) -> Bool {
        caret == flatOffset(ofRoleAt: index)
    }

    internal func listMembership(ofRoleAt index: Int) -> ListMembership? {
        currentRoles[index].shape.paragraph?.list
    }

    /// A list item with no text of its own.
    private func isEmptyListItem(_ index: Int) -> Bool {
        listMembership(ofRoleAt: index) != nil && flatLength(ofRoleAt: index) == 0
    }

    /// Whether the item at `index` opens its list — nothing before it is a list item.
    private func isFirstItemOfItsList(_ index: Int) -> Bool {
        index == 0 || listMembership(ofRoleAt: index - 1) == nil
    }

    /// The list item the caret is in, or nil. The selection may span several — `indent()`/`outdent()`
    /// act on all of them — so this only answers whether Tab means anything here.
    internal var caretListItemIndex: Int? {
        guard let index = roleIndex(atFlatOffset: engineSelectedRange.location),
              listMembership(ofRoleAt: index) != nil else { return nil }
        return index
    }

    // MARK: - Return: the way out of a list

    /// Legacy's empty-item exit, decided before the edit. Returns whether it acted; a Return
    /// anywhere else in a list falls through and continues the list as before.
    internal func decideReturnInListItem(index: Int, caret: Int) -> Bool {
        // BOTTOM (and any empty item): the item itself is empty and the caret is in it. It stops
        // being a list item where it stands, which for a trailing item IS "a paragraph after the
        // list" — an item is a paragraph, so there is no container to climb out of.
        //
        // A NESTED empty item outdents one level instead, keeping its marker — legacy's rule
        // (`DocumentCanvasView.insertParagraphBreak`: "a nested item outdents one level, a top-level
        // one ends the list") and the same step Backspace at an item's start takes first. Ending the
        // list here split it in two mid-list, and the items after restarted their numbering
        // (`HarnessNestedListReturnTests`).
        if isEmptyListItem(index), let membership = listMembership(ofRoleAt: index) {
            if membership.level > 0 {
                outdentItem(at: index, from: membership)
            } else {
                endList(at: index)
            }
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: index), length: 0)
            return true
        }
        // TOP: the caret is at the start of the content and the item ABOVE is an empty first item —
        // the state one Return at offset 0 leaves behind. That empty item becomes the paragraph
        // before the list, and the caret goes to it, so a second Return at the top of a list opens a
        // line above it rather than stacking blank items.
        if caretIsAtStartOfItem(index, caret: caret), index > 0,
           isEmptyListItem(index - 1), isFirstItemOfItsList(index - 1) {
            endList(at: index - 1)
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: index - 1), length: 0)
            return true
        }
        // START of a non-empty item: a fresh item opens ABOVE and the item keeps itself — text, role,
        // identity and checked state — with the caret still at its start. The engine's split left the
        // identity (and so the role, `checked` with it) on the EMPTIED upper half and minted the lower
        // one, which the list continuation then gave a fresh unchecked membership: the check moved
        // onto the new empty line and the task's own text came out unchecked (composer harness p16,
        // `HarnessChecklistReturnAtStartTests`). The heading's rule, for a list item
        // (`decideReturnAtStartOfHeading`); the new item is the list continuation's: same marker and
        // level, unchecked, body style.
        if caretIsAtStartOfItem(index, caret: caret), flatLength(ofRoleAt: index) > 0,
           currentRoles[index].secondaryKind == nil, currentRoles[index].owningTable == nil,
           case .standalone(.paragraph(let paragraph)) = currentRoles[index].position,
           let membership = paragraph.list {
            let fresh = ParagraphShape(id: BlockID(UUID().uuidString),
                                       list: ListMembership(marker: membership.marker, level: membership.level,
                                                            checked: membership.checked == nil ? nil : false))
            var plan = currentRoles
            plan.insert(.standalone(.paragraph(fresh), within: currentRoles[index].ancestry), at: index)
            let start = flatOffset(ofRoleAt: index)
            replaceFlat(NSRange(location: start, length: 0), with: "\n", adopting: plan)
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: index + 1), length: 0)
            return true
        }
        return false
    }

    // MARK: - Backspace: outdent, then leave

    /// The rule itself, by INDEX rather than by caret, because the same keystroke arrives in two
    /// shapes and both have to reach it.
    ///
    /// UIKit delivers a Backspace at a block's start to a bare `UITextInput` either as a collapsed
    /// caret there or as a RANGE covering the join with the block above — and the host view routes a
    /// non-empty selection to the gate as a replacement, so the second shape never reaches the
    /// caret-based handler at all. Left to the gate it merged the item into the one above instead of
    /// outdenting it, which is the shape a device actually sees. Unit tests that set a collapsed
    /// caret cannot tell the two apart, which is exactly how the legacy editor's media backspace was
    /// wrong for a month; here both shapes are routed to this one function instead.
    @discardableResult
    internal func applyBackspaceAtStartOfListItem(at index: Int) -> Bool {
        guard index < currentRoles.count, let membership = listMembership(ofRoleAt: index) else { return false }
        if membership.level > 0 {
            outdentItem(at: index, from: membership)
        } else {
            endList(at: index)
        }
        engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: index), length: 0)
        return true
    }

    /// Whether `range` is exactly the "\n" joining the block above `last` to it — the range form of
    /// a Backspace at `last`'s start.
    ///
    /// A user who SELECTS that newline and deletes it is indistinguishable from this, and is treated
    /// the same. That is the deliberate choice: the two are the same gesture as far as the document
    /// is concerned, and a list item that sometimes outdents and sometimes merges depending on how
    /// the selection was made would be worse than either rule consistently applied.
    internal func rangeIsTheJoinBefore(_ last: Int, range: NSRange) -> Bool {
        last > 0 && range.length == 1 && range.location == flatOffset(ofRoleAt: last) - 1
    }

    // MARK: - The two mutations, and their undo

    /// The item stops being one, keeping its text and its style.
    ///
    /// Legacy also forced `.body` here, and that is deliberately NOT carried over: it did so to make
    /// a QUOTED item break "straight to a body paragraph", back when a quote was a paragraph STYLE.
    /// It is a container now (`Block.blockQuote`), `ParagraphStyleName` has no `.quote` case at all,
    /// and un-quoting is a structural operation this rule has no business performing — ending a list
    /// inside a quote must leave you in the quote, one step at a time. With that gone the demotion
    /// has no remaining purpose except to silently turn a heading that happens to be a list item into
    /// body text, so the style is left alone.
    private func endList(at index: Int) {
        guard var paragraph = currentRoles[index].shape.paragraph else { return }
        let previous = paragraph
        paragraph.list = nil
        applyParagraphShape(paragraph, restoring: previous, at: index)
    }

    private func outdentItem(at index: Int, from membership: ListMembership) {
        guard var paragraph = currentRoles[index].shape.paragraph else { return }
        let previous = paragraph
        paragraph.list = ListMembership(marker: membership.marker, level: membership.level - 1,
                                        checked: membership.checked)
        applyParagraphShape(paragraph, restoring: previous, at: index)
    }

    /// Installs a paragraph's new shape and registers the inverse.
    ///
    /// `adoptRolePlan` is the primitive for a structure change with NO edit, which is exactly what
    /// this is: the block's characters are untouched, only its membership changes. That also means
    /// the engine records nothing to undo, so the inverse is registered here — restoring the shape
    /// by the block's IDENTITY rather than by index, because an undo can run after other edits have
    /// moved it.
    private func applyParagraphShape(_ shape: ParagraphShape, restoring previous: ParagraphShape, at index: Int) {
        let undoBefore = currentUndoSnapshot()
        var plan = currentRoles
        plan[index] = currentRoles[index].replacingShape(.paragraph(shape))
        // The primitive SETTLES, which is what re-derives the block's presentation from its new
        // role — this rule knows nothing about rendering. The first version of it settled nowhere
        // and asked for nothing, which is how the bullet outdented while the text stayed put.
        performHostStructuralChange { adoptRolePlan(plan) }
        recordUndoStepForCommand(restoring: undoBefore)
        setNeedsLayout()
    }
}
#endif
