#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// The edit primitives the gate and settle use (surface-gate spec §3), the flat geometry they
/// share, and the roles' passage through undo and redo. Every edit here is a top-level controller
/// edit; the host never edits from inside the engine's change notification.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    // MARK: - Flat geometry (the engine's axis)

    /// The length of the engine block at `index`, on the canonical axis `engineSelectedRange`
    /// speaks. The ENGINE's length, never a model sum: a formula run renders as one U+FFFC while
    /// its model text is the LaTeX source, and every offset after it would be wrong by the
    /// difference.
    internal func flatLength(ofRoleAt index: Int) -> Int {
        let blocks = engine.attributedBlocks
        return index < blocks.count ? blocks[index].length : 0
    }

    /// The flat offset at which the engine block at `index` begins — blocks joined by "\n".
    internal func flatOffset(ofRoleAt index: Int) -> Int {
        engine.attributedBlocks.prefix(index).reduce(0) { $0 + $1.length + 1 }
    }

    internal func flatRange(ofRoleAt index: Int) -> NSRange {
        NSRange(location: flatOffset(ofRoleAt: index), length: flatLength(ofRoleAt: index))
    }

    /// The role index whose flat span contains the caret, or nil.
    internal func roleIndex(atFlatOffset offset: Int) -> Int? {
        var start = 0
        for (index, block) in engine.attributedBlocks.enumerated() where index < currentRoles.count {
            let end = start + block.length
            if offset >= start && offset <= end { return index }
            start = end + 1
        }
        return nil
    }

    /// Whether the selection's start is in a ONE-LINE field (`EngineBlockRole.isOneLineField`): where a
    /// composition's candidate may not carry a line break (`tgid_markedTextFilter`).
    internal func selectionIsInOneLineField() -> Bool {
        guard let index = roleIndex(atFlatOffset: engineSelectedRange.location) else { return false }
        return currentRoles[index].isOneLineField
    }

    // MARK: - Edit primitives (through the controller)

    /// A text edit the controller records: it joins the keystroke's undo group when issued from
    /// inside the change notification. Flat offsets equal canonical offsets. Structure is left to
    /// identity: only a NON-structural edit goes through here (removing a blank line before an
    /// exit); a structural one carries its plan (`replaceFlat(_:with:adopting:)`).
    internal func replaceFlat(_ range: NSRange, with text: String) {
        guard let start = engine.position(from: engine.beginningOfDocument, offset: range.location),
              let end = engine.position(from: start, offset: range.length),
              let textRange = engine.textRange(from: start, to: end) else { return }
        engine.replace(textRange, withText: text)
    }

    /// A structural edit with the roles it produces: `plan` is adopted, by position, in the change
    /// notification of THIS edit (structure-only roles design §3). There is no state in which the
    /// roles are a by-identity guess of the edit, and a plan cannot be built from post-edit roles
    /// because it is an argument of the edit — settle's rejoin captured its plan after its own
    /// merge had rebuilt the roles one shorter and removed a role past the end (device crash,
    /// 2026-09-04). An edit the engine reports no change for adopts the plan directly.
    internal func replaceFlat(_ range: NSRange, with text: String, adopting plan: [EngineBlockRole]) {
        // A STRUCTURAL edit is not typing, so it opens its own undo step rather than folding into
        // the run before it. The shape that says so is this overload: an edit that carries a plan
        // decided a structure, where a plain `replaceFlat` is a character going in. Without this the
        // double-Return exit from a code block coalesced with the newline that preceded it and one
        // undo took back both keystrokes.
        // SETTLE's own structural edits are the exception: they are consequences of the edit being
        // settled (an author line minted because the first character gave a quote content), not
        // keystrokes, and closing the run there split typing into an empty quote into two undo
        // steps (composer harness, 2026-09-24, fuzz seed 29, `HarnessCompositionUndoStepTests`).
        // `recordUndoForEngineEdit` keeps the run where the text it covers moved to.
        let isSettleEdit = isSettling
        if !isSettleEdit { endTypingRun() }
        pendingRolePlan = plan
        replaceFlat(range, with: text)
        if pendingRolePlan != nil {
            pendingRolePlan = nil
            adoptRolePlan(plan)
        }
        // And typing AFTER it does not fold into it either. The edit itself opened a run ending at
        // its own end, so a character typed where a structural exit left the caret (the paragraph
        // after a pull quote's double Return) continued that run and one undo took back both. It
        // passed only while the empty line's separator re-attribution, read as a replacement,
        // happened to open a step of its own (`recordUndoForEngineEdit`).
        if !isSettleEdit { endTypingRun() }
    }

    /// A host COMMAND's structural edits, framed like the gate frames a keystroke's: the roles
    /// before them are captured for the replay snapshot, the gate is told not to decide them, and
    /// settle runs once when they are done.
    ///
    /// A command decides its own structure and carries it as a plan, so a gate that re-read its
    /// text would decide it a second time. Tab out of the last cell of a TRAILING table used to do
    /// exactly that: the command's `replaceFlat(…, "\n", adopting:)` reached the surface, the gate
    /// read a Return in a cell, called the command again one level down — where the flag it sets
    /// let the inner edit through — and vetoed the outer one, whose plan was then dropped on the
    /// floor. It produced the right document only because the two plans were computed from the same
    /// roles a moment apart. Any command whose text the gate has a rule for would not be so lucky.
    internal func performHostStructuralEdit(_ body: () -> Void) {
        // Already inside a rule's own edits (the gate calls the same commands): they frame it.
        guard !isDecidingAtGate, !isSettling, !isIssuingHostEdit else { return body() }
        if rolesBeforeEdit == nil { rolesBeforeEdit = currentRoles }
        isIssuingHostEdit = true
        body()
        isIssuingHostEdit = false
        settleAfterEdit()
        endHostDecidedKeystroke()
    }

    /// A host rule that changes STRUCTURE without editing text — ending a list, ticking a checkbox.
    ///
    /// The counterpart of `performHostStructuralEdit`, and it exists for the same reason one level
    /// down: such a change had no settle at all. The gate's veto path settles, and an edit settles
    /// through the controller's callback, but a rule that only rewrites roles reached neither — so
    /// `normalisePresentation` never ran for it and the block kept the presentation of the role it
    /// used to have. That is the whole of the bug class: not the rules, but that there were two
    /// kinds of structural change and only one of them settled.
    ///
    /// One notification for the change and everything settle does in response to it.
    internal func performHostStructuralChange(_ body: () -> Void) {
        guard !isDecidingAtGate, !isSettling, !isIssuingHostEdit else { return body() }
        if rolesBeforeEdit == nil { rolesBeforeEdit = currentRoles }
        deliveringOneChangeNotification {
            isIssuingHostEdit = true
            body()
            isIssuingHostEdit = false
            settleAfterEdit()
            endHostDecidedKeystroke()
        }
    }

    /// An attribute-only edit the controller does not record.
    ///
    /// **Registers no undo of its own.** It used to register the inverse so that undoing the
    /// keystroke also un-restyled — necessary when the stack held UIKit's TEXT operations, which
    /// cannot express an attribute change. The stack now holds document snapshots
    /// (`+UndoStack.swift`), and presentation is derived from the role on the way back in, so the
    /// restyle is already covered by the step the edit itself registered. Registering here as well
    /// put one entry of ours between every pair of keystrokes, which is what stopped a typed run
    /// coalescing into one undo.
    internal func restyleFlat(_ range: NSRange, with attributes: [NSAttributedString.Key: Any]) {
        let joined = joinedEngineText()
        guard range.location >= 0, NSMaxRange(range) <= joined.length, range.length > 0 else { return }
        engine.id_setAttributes(attributes, inCanonicalRange: range)
    }

    /// Applies a captured run of attributes back over `range`.
    ///
    /// NOT undo machinery, despite the name's connotation — it is the second half of the "an
    /// attribute cannot travel through a text edit" two-step that `insertMedia`, `insertButtonRow`,
    /// the formula and inline-button inserts and `convertCurrentTableToText` all use: replace the
    /// characters, then put the attachment's attributes back over them. It registered its own
    /// inverse while the stack held UIKit's text operations; the snapshot stack
    /// (`+UndoStack.swift`) covers it, so it no longer does.
    internal func restoreStyleFlat(_ range: NSRange, from previous: NSAttributedString) {
        let joined = joinedEngineText()
        guard NSMaxRange(range) <= joined.length, previous.length == range.length else { return }
        previous.enumerateAttributes(in: NSRange(location: 0, length: previous.length)) { attributes, run, _ in
            engine.id_setAttributes(attributes,
                                    inCanonicalRange: NSRange(location: range.location + run.location,
                                                              length: run.length))
        }
    }

    /// The engine's blocks joined by "\n", attributes kept — the canonical text as the controller
    /// addresses it.
    private func joinedEngineText() -> NSMutableAttributedString {
        let joined = NSMutableAttributedString()
        for (index, block) in engine.attributedBlocks.enumerated() {
            if index > 0 { joined.append(NSAttributedString(string: "\n")) }
            joined.append(block)
        }
        return joined
    }

    // MARK: - Roles across undo and redo
    //
    // **There is nothing here any more, and that is the point.**
    //
    // `registerReplayRoleSnapshot`, `installReplayRoles`, `adoptReplayRoles`, `rolesForReplay` and
    // `installReplayRoleCleanup` all existed for one reason: UIKit replays TEXT. An undo put the
    // characters back and nothing restored the ROLES around them, so the pre-keystroke roles were
    // registered in the keystroke's own undo group, adopted positionally as each replay landed, and
    // the block's presentation re-derived a run-loop turn later because a replay never reaches
    // settle.
    //
    // The editor's own stack restores a `Document`, and the setter derives the roles from it through
    // the bridge and re-renders every block that differs. There is no window in which text and
    // structure disagree, so none of it is needed — and leaving it in place "unreachable and
    // harmless" would be worse than deleting it: a reader would believe the replay path still
    // exists. See `+UndoStack.swift`.
}
#endif
