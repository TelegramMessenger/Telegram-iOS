#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// Folding a detail block: the body moves BETWEEN the engine and the role's shape, never copied, so
/// there is only ever one of it (R7-details spec §7).
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    /// The flat offset of the first BODY block of the details `id` — the role directly after its
    /// title, which `flatten` always emits first. Nil for a folded details, whose span is the title
    /// alone.
    ///
    /// Asked as "the first role whose innermost ancestor is this details", as it was, a body child
    /// that is ITSELF an ancestor container never matched — its innermost ancestor is its own
    /// container, not the details. So Return in the title of a details holding a quote (or another
    /// details) found no body, moved nowhere, and the gate vetoed the keystroke: Return did nothing.
    internal func flatOffsetOfFirstBodyBlock(ofDetails id: BlockID) -> Int? {
        guard let title = currentRoles.firstIndex(where: { $0.isOwnedLine(.detailsTitle, of: id) }) else { return nil }
        // The first BODY block is the first CHILD, which is not `title + 1` because it is not the
        // span's second role in general — a rule that walks off the container's own line by index
        // arithmetic is the shape this whole family of defects took.
        guard let firstChild = contents(of: id, around: title).firstChildRole else { return nil }
        return flatOffset(ofRoleAt: firstChild)
    }

    /// The details whose TITLE the role at `index` is, if it is one.
    internal func detailsOwningTitle(atRoleAt index: Int) -> DetailsShape? {
        guard index < currentRoles.count else { return nil }
        let role = currentRoles[index]
        guard role.secondaryKind == .detailsTitle, let details = role.innermostAncestor?.details,
              details.id == role.containerID else { return nil }
        return details
    }

    /// Backspace at the START of a details' title: the details unwraps one level and the title text
    /// survives as an ordinary paragraph (§6.2, decision 5). Reached from BOTH doors, like every other
    /// rule that has two — UIKit delivers this keystroke either as a collapsed caret or as the range
    /// covering the join with the block above.
    @discardableResult
    internal func applyBackspaceAtStartOfDetailsTitle(at index: Int) -> Bool {
        guard let details = detailsOwningTitle(atRoleAt: index) else { return false }
        unwrapContainer(details.id, around: index, caretLanding: flatOffset(ofRoleAt: index))
        return true
    }

    /// Put a folded details' body back into the engine, after its title and carrying the title's
    /// ancestry (§7.2). The shape's `foldedChildren` is cleared by the document rebuild.
    internal func unfold(detailsWithID id: BlockID) {
        guard let titleIndex = currentRoles.firstIndex(where: { $0.innermostAncestor?.details?.id == id }),
              let details = currentRoles[titleIndex].innermostAncestor?.details,
              !details.expanded else { return }
        setExpanded(true, forDetailsWithID: id, around: titleIndex)
    }

    /// Take a details' body out of the engine and into its shape (§7.2). If the caret was inside the
    /// body it lands at the END of the title — the body is about to stop existing on the engine's axis,
    /// so a caret left in it would be pointing at nothing.
    internal func fold(detailsWithID id: BlockID) {
        guard let titleIndex = currentRoles.firstIndex(where: { $0.innermostAncestor?.details?.id == id }),
              let details = currentRoles[titleIndex].innermostAncestor?.details,
              details.expanded else { return }
        setExpanded(false, forDetailsWithID: id, around: titleIndex)
    }

    /// The fold toggle both directions share. It rebuilds through the DOCUMENT — the model already
    /// holds the body in whichever place the state says (children when expanded, `foldedChildren`
    /// when folded), so flipping `expanded` on the block and re-setting the document moves the body
    /// across for free, and `flatten` decides what reaches the engine.
    private func setExpanded(_ expanded: Bool, forDetailsWithID id: BlockID, around index: Int) {
        let before = document
        let selectionBefore = engineSelectedRange
        guard case let .details(block)? = before.blocksByID[id] else { return }
        var updated = block
        updated.expanded = expanded
        // The caret survives a FOLD only if it was in the title; anywhere else it was in the body,
        // which is leaving the engine.
        let titleRange = flatRange(ofRoleAt: index)
        let caretWasInTitle = NSLocationInRange(selectionBefore.location, titleRange)
            || selectionBefore.location == NSMaxRange(titleRange)
        // A fold ADDS or REMOVES the whole body from the engine's axis, so every offset past the
        // block moves by exactly that much. Restoring the caret's absolute offset left it on
        // different text — fold a details holding "one" and a caret in the paragraph below landed
        // three characters earlier (K3, 2026-09-08).
        let spanBefore = span(of: id, around: index)
        let spanEndBefore = flatOffset(ofRoleAt: spanBefore.upperBound) + flatLength(ofRoleAt: spanBefore.upperBound)
        let caretWasAfterTheBlock = selectionBefore.location >= spanEndBefore
        deliveringOneChangeNotification {
            document = before.replacingBlock(withID: id, with: .details(updated))
            guard let title = currentRoles.firstIndex(where: { $0.isOwnedLine(.detailsTitle, of: id) }) else { return }
            if caretWasInTitle {
                // FIRST, and that order is the whole of it: for a COLLAPSED details the title's end IS
                // the span's end, so the "after the block" test below claims it too — and claiming it
                // shifted a caret sitting at the end of a folded title all the way to the end of the
                // body the unfold had just revealed (K3, 2026-09-08).
                engineSelectedRange = selectionBefore
            } else if caretWasAfterTheBlock {
                let spanAfter = span(of: id, around: title)
                let spanEndAfter = flatOffset(ofRoleAt: spanAfter.upperBound) + flatLength(ofRoleAt: spanAfter.upperBound)
                engineSelectedRange = NSRange(location: max(0, selectionBefore.location + (spanEndAfter - spanEndBefore)),
                                              length: selectionBefore.length)
            } else if expanded {
                // Unfolding never moves anything at or before the title.
                engineSelectedRange = selectionBefore
            } else {
                // Folding with the caret in the BODY: it is about to stop existing on the axis.
                engineSelectedRange = NSRange(location: NSMaxRange(flatRange(ofRoleAt: title)), length: 0)
            }
        }
        recordUndoStepForStructuralChange(restoring: before, selection: selectionBefore)
    }

    /// The title's exit, shared by Return and Tab (K3, 2026-09-08). A title sits above a body the
    /// way a form field sits above the next one, so Tab is what a user reaches for and it has to mean
    /// the same thing Return already did.
    ///
    /// Where it lands depends on the FOLD, and the collapsed case is the one that changed: a folded
    /// details has no body on the engine's axis, and unfolding it to put the caret there is not what
    /// the user asked for — they asked to leave. So both exits go to the block AFTER the details, at
    /// the details' own level, and mint one when there is none.
    internal func moveCaretOutOfDetailsTitle() {
        guard let index = roleIndex(atFlatOffset: engineSelectedRange.location),
              let details = detailsOwningTitle(atRoleAt: index) else { return }
        if details.expanded {
            if let body = flatOffsetOfFirstBodyBlock(ofDetails: details.id) {
                engineSelectedRange = NSRange(location: body, length: 0)
            }
            return
        }
        moveCaretPastDetails(details.id, from: index)
    }

    /// Tab from anywhere inside a details: out of the block entirely (K3 QoL, 2026-09-08). From the
    /// TITLE it is the title's own exit — into the body first, which is one Tab away from here — and
    /// from the body it lands on the block after the details, minting one when there is none.
    ///
    /// A cell and a list item are claimed by the table and list rules BEFORE this one, so Tab keeps
    /// meaning "next cell" and "indent" inside a details; this is the plain-body case only.
    internal func moveCaretOutOfDetails() {
        guard let index = roleIndex(atFlatOffset: engineSelectedRange.location),
              let details = currentRoles[index].innermostAncestor?.details else { return }
        if detailsOwningTitle(atRoleAt: index) != nil { return moveCaretOutOfDetailsTitle() }
        moveCaretPastDetails(details.id, from: index)
    }

    /// The caret onto the details' next SIBLING, or onto a fresh paragraph when it has none.
    ///
    /// "Sibling" excludes a line owned by a container that ENCLOSES the details — a quote's author
    /// line, when the details is that quote's last child. That line is the quote's own field and not
    /// somewhere to type, and it is exactly the role that follows such a details, which is the same
    /// trap `moveCaretToCell(before:)` fell into for a quoted table. A following details' TITLE is
    /// NOT excluded: its container is that details, a sibling, so it is a real place to land.
    internal func moveCaretPastDetails(_ id: BlockID, from index: Int) {
        let span = span(of: id, around: index)
        let parent = parentAncestry(of: id, at: index)
        let next = span.upperBound + 1
        if next < currentRoles.count, !currentRoles[next].isWithin(id),
           !roleIsOwnedLineOfAnEnclosingContainer(next, enclosing: parent) {
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: next), length: 0)
            return
        }
        let end = flatOffset(ofRoleAt: span.upperBound) + flatLength(ofRoleAt: span.upperBound)
        var plan = currentRoles
        plan.insert(freshBodyRole(within: parent), at: next)
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                replaceFlat(NSRange(location: end, length: 0), with: "\n", adopting: plan)
                engineSelectedRange = NSRange(location: end + 1, length: 0)
            }
        }
    }

    /// §7.2 / §8.2. The chevron's action, and the one a host menu would call.
    public func toggleDetailsExpanded(id: BlockID) {
        guard case let .details(block)? = document.blocksByID[id] else { return }
        if block.expanded { fold(detailsWithID: id) } else { unfold(detailsWithID: id) }
    }

    /// §8.1. An empty, expanded details where the caret is — a title to type into and one empty body
    /// paragraph under it — with the caret at the title's start.
    ///
    /// The placement family is `insertTable`'s and `insertMediaBlock`'s, expressed through the
    /// DOCUMENT rather than through a role plan: an empty caret paragraph is replaced, a caret
    /// mid-paragraph splits it, offset 0 puts the details before, anything else after. And "before"
    /// and "after" are measured against the whole CONTAINER the caret sits in — a cell, a second
    /// line, a code block's body — never between a container's own lines.
    ///
    /// The anchor is the caret's leaf `containerID` and it is resolved against the whole TREE, so a
    /// details asked for inside a quote (or inside another details) becomes a CHILD of it: decision
    /// 3, anywhere a table may go. The minted roles' ancestry is not written here at all — the
    /// document set re-flattens, and `flatten` gives every block the ancestry its position in the
    /// tree implies, which is the same reason `insertTable` needs no role plan either.
    public func insertDetailsBlock() {
        guard !currentRoles.isEmpty else { return }
        let before = document
        let selection = engineSelectedRange
        guard let index = roleIndex(atFlatOffset: selection.location) else { return }
        let role = currentRoles[index]
        let details = DetailsBlock(
            id: BlockID(UUID().uuidString), title: [],
            children: [.paragraph(ParagraphBlock(id: BlockID(UUID().uuidString), style: .body, runs: []))],
            expanded: true)
        let anchor = role.containerID

        let updated: Document
        // A cell, a second line or any non-paragraph leaf places the details after its whole
        // container: `anchor` is the table's / the owner's id, so `insertingBlock` lands beside it.
        if role.owningTable != nil || role.secondaryKind != nil,
           before.blocksByID[anchor] != nil {
            updated = before.insertingBlock(.details(details), after: anchor)
        } else if let paragraph = before.blocksByID[anchor]?.asParagraph {
            let local = selection.location - flatOffset(ofRoleAt: index)
            let length = flatLength(ofRoleAt: index)
            if length == 0 {
                // Checked FIRST: an empty paragraph is both offset 0 and its own end, so any other
                // order leaves it standing beside the details it was supposed to become.
                updated = before.replacingBlock(withID: anchor, with: .details(details))
            } else if local <= 0 {
                guard let spliced = before.replacingSiblings(from: anchor, to: anchor,
                                                             with: [.details(details), .paragraph(paragraph)])
                else { return }
                updated = spliced
            } else if local >= length {
                updated = before.insertingBlock(.details(details), after: anchor)
            } else {
                let (upper, lower) = paragraph.split(at: local, newID: BlockID(UUID().uuidString))
                guard let spliced = before.replacingSiblings(
                    from: anchor, to: anchor,
                    with: [.paragraph(upper), .details(details), .paragraph(lower)]) else { return }
                updated = spliced
            }
        } else {
            updated = before.insertingBlock(.details(details), after: anchor)
        }

        document = updated
        // Resolved AFTER the set, from the rebuilt roles: the title is a SECONDARY line and occupies
        // flat space of its own, which no offset computed over the model's blocks can know.
        if let title = currentRoles.firstIndex(where: {
            $0.isOwnedLine(.detailsTitle, of: details.id)
        }) {
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: title), length: 0)
        }
        // Like `insertTable` and the container commands: the rebuild goes through the document
        // setter, whose edit `isApplyingHostDocument` swallows, so the engine's own undo has nothing
        // to replay it from. The documented cost is that this clears the history before it.
        recordUndoStepForStructuralChange(restoring: before, selection: selection)
        deliverChangeNotificationNow()
    }
}
#endif
