#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// The gate and settle rules for a media unit (spec §5, §6): the atom's two stops, the two-step
/// deletion, ranges that enter a unit, the caption's Return, Backspace after a unit, and the two
/// settle rules that keep a unit well-formed. Every rule reachable through both Backspace doors is
/// ONE function reached from both, as `applyBackspaceAtStartOfListItem` is.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    // MARK: - Finding the unit

    /// The atom of the unit the role at `index` belongs to — itself, or the owner of a caption
    /// line — or nil for a role outside any media unit.
    internal func mediaAtomIndex(forRoleAt index: Int) -> Int? {
        guard index >= 0, index < currentRoles.count else { return nil }
        if case .standalone(.media) = currentRoles[index].position { return index }
        guard currentRoles[index].secondaryKind == .mediaCaption else { return nil }
        let owner = currentRoles[index].containerID
        return currentRoles.firstIndex { $0.containerID == owner && $0.secondaryKind == nil }
    }

    /// The atom of the ATOM UNIT the role at `index` belongs to — itself, or the owner of a
    /// companion line — or nil for a role in no atom unit.
    ///
    /// THREE atom kinds answer here, and that is the point: a media atom, a button row and a FOLDED
    /// QUOTE are all text-free blocks occupying one attachment character, so every rule asking "what
    /// is the atom next to this" wants all three. Asked as a media question, the three Backspace
    /// rules below would each need a second copy per kind, kept in step by convention.
    ///
    /// A SIBLING of `mediaAtomIndex(forRoleAt:)` rather than a widening of it, deliberately. That
    /// function has four callers in `+SurfaceGate.swift` which are CAPTION logic — "a media unit
    /// entered but not covered keeps its atom and truncates its caption" — and a row has no caption
    /// for them to reason about. A row's cross-block-replace behaviour is already decided by
    /// `isContainer` and `containerIsCovered`, which learned the kind in this rung's Task 2.
    internal func atomUnitIndex(forRoleAt index: Int) -> Int? {
        guard index >= 0, index < currentRoles.count else { return nil }
        switch currentRoles[index].position {
        case .standalone(.media), .standalone(.buttonRow), .standalone(.collapsedQuote): return index
        default: break
        }
        guard currentRoles[index].secondaryKind == .mediaCaption else { return nil }
        let owner = currentRoles[index].containerID
        return currentRoles.firstIndex { $0.containerID == owner && $0.secondaryKind == nil }
    }

    /// The companion line of an atom unit — a media caption. A button row and a FOLDED QUOTE have
    /// NONE: neither owns any text, so the unit is the single role and this answers nil, which is
    /// exactly the caption-less media path the callers already handle.
    internal func atomUnitCompanionIndex(ofAtomAt atom: Int) -> Int? {
        guard atom < currentRoles.count, case .standalone(.media) = currentRoles[atom].position else { return nil }
        return captionIndex(ofMediaAtomAt: atom)
    }

    internal func captionIndex(ofMediaAtomAt atom: Int) -> Int? {
        guard atom < currentRoles.count else { return nil }
        let owner = currentRoles[atom].containerID
        return currentRoles.firstIndex { $0.containerID == owner && $0.secondaryKind == .mediaCaption }
    }

    internal func mediaShape(atRole index: Int) -> MediaShape? {
        guard index < currentRoles.count, case let .standalone(.media(shape)) = currentRoles[index].position else { return nil }
        return shape
    }

    /// Whether the engine block at `index` holds a `MediaTextAttachment` anywhere in its text.
    ///
    /// Read where a role alone cannot answer: a bypass split at the atom's LEADING stop leaves the
    /// media ROLE on the block above and the ATTACHMENT on the block below, and only the attachment
    /// says which of the two is really the atom.
    internal func blockCarriesMediaAttachment(_ index: Int) -> Bool {
        let blocks = engine.attributedBlocks
        guard index >= 0, index < blocks.count else { return false }
        let text = blocks[index]
        return (0..<text.length).contains { text.attribute(.attachment, at: $0, effectiveRange: nil) is MediaTextAttachment }
    }

    // MARK: - §5.1 text at the atom's two stops

    /// The atom block has offsets 0 (before) and 1 (after). Neither is a place text lands: before,
    /// a body paragraph opens above; after, the text goes to the caption's start, or to a body
    /// paragraph below a caption-less kind. A range covering the atom is the atom being replaced
    /// (typing over a selected atom, the second Backspace): the covered-container rule.
    internal func decideTextInputAtAnAtomUnit(index: Int, range: NSRange, text: String) -> SurfaceDecision {
        if range.length > 0 {
            return replaceAcrossBlocks(range, text: text, first: index, last: index)
        }
        let atomStart = flatOffset(ofRoleAt: index)
        let atomEnd = atomStart + flatLength(ofRoleAt: index)
        let body = text == "\n" ? "" : text
        let lines = body.components(separatedBy: "\n")
        if range.location <= atomStart {
            var plan = currentRoles
            plan.insert(contentsOf: lines.map { _ in freshBodyRole(within: currentRoles[index].ancestry) }, at: index)
            replaceFlat(NSRange(location: atomStart, length: 0), with: body + "\n", adopting: plan)
            engineSelectedRange = NSRange(location: atomStart + body.utf16.count, length: 0)
            return .veto
        }
        if let shape = mediaShape(atRole: index), !shape.isCaptionless,
           let caption = captionIndex(ofMediaAtomAt: index) ?? insertCaptionLine(afterAtomAt: index) {
            // By the atom's KIND, never by whether a caption line happens to exist: the two disagree
            // in exactly the damaged states settle repairs, and the gate and settle must agree about
            // one document. A captioned atom whose line has vanished gets it back here rather than
            // dropping the text into a paragraph the presence rule would then insert a line above.
            // Offset 1 IS the caption's offset 0: decided again there, as caption input.
            let captionStart = flatOffset(ofRoleAt: caption)
            engineSelectedRange = NSRange(location: captionStart, length: 0)
            switch decideTextInput(range: NSRange(location: captionStart, length: 0), text: text) {
            case let .forward(forwarded):
                replaceFlat(NSRange(location: captionStart, length: 0), with: forwarded)
                engineSelectedRange = NSRange(location: captionStart + forwarded.utf16.count, length: 0)
            case .veto:
                break
            }
            return .veto
        }
        var plan = currentRoles
        plan.insert(contentsOf: lines.map { _ in freshBodyRole(within: currentRoles[index].ancestry) }, at: index + 1)
        replaceFlat(NSRange(location: atomEnd, length: 0), with: "\n" + body, adopting: plan)
        engineSelectedRange = NSRange(location: atomEnd + 1 + body.utf16.count, length: 0)
        return .veto
    }

    // MARK: - §5.1 a COMPOSITION at the atom's two stops

    /// Places a composition that starts at an atom unit's stop, ONCE, before its first candidate:
    /// at a captioned medium's trailing stop the caret moves to the caption's start; at a leading
    /// stop (any atom) or a caption-less atom's trailing stop an empty body line is minted above /
    /// below, exactly where `decideTextInputAtAnAtomUnit` puts a typed character, and the caret goes
    /// there. The IME then owns its text there until it commits.
    ///
    /// The gate decided every candidate as a finished keystroke instead — a candidate is delivered
    /// with nothing marked yet whenever the previous one was vetoed — so before the atom each
    /// candidate committed as a paragraph of its own and one undo did not revert them, and after it
    /// every candidate accumulated in the caption and a cancel left them all (composer harness p13,
    /// `HarnessAtomStopCompositionTests`).
    ///
    /// **The mint is not a step of its own.** It registers no undo, and the baseline is put back to
    /// the state before it, so the composition's own step restores the document without the line:
    /// one undo reverts the whole composition, as a stock text view's does. A composition that ends
    /// with nothing committed (a cancel) takes the empty line away again
    /// (`removeEmptyCompositionMintedLine`), so it changes nothing.
    internal func resolveAtomStopBeforeComposition(at caret: Int) {
        compositionMintedLine = nil
        guard !isDecidingAtGate, !isSettling, !isIssuingHostEdit, !isApplyingUndoSnapshot,
              engine.markedTextRange == nil,
              let index = roleIndex(atFlatOffset: caret), atomUnitIndex(forRoleAt: index) == index else { return }
        let atomStart = flatOffset(ofRoleAt: index)
        let atomEnd = atomStart + flatLength(ofRoleAt: index)
        guard caret == atomStart || caret == atomEnd else { return }
        if caret == atomEnd, let shape = mediaShape(atRole: index), !shape.isCaptionless {
            // The caption's offset 0 IS the atom's trailing stop for text: a caret move, no edit.
            guard let caption = captionIndex(ofMediaAtomAt: index) else { return }
            engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: caption), length: 0)
            return
        }
        let baseline = lastSettledUndoSnapshot ?? currentUndoSnapshot()
        engineUndoManager.disableUndoRegistration()
        rolesBeforeEdit = currentRoles
        undoStepRegistrationCountAtGateEntry = undoStepRegistrationCount
        isDecidingAtGate = true
        _ = decideTextInputAtAnAtomUnit(index: index, range: NSRange(location: caret, length: 0), text: "")
        isDecidingAtGate = false
        let changedStructure = structureTouchedThisEdit
        settleAfterEdit()
        endHostDecidedKeystroke()
        engineUndoManager.enableUndoRegistration()
        endTypingRun()
        lastSettledUndoSnapshot = baseline
        let identifiers = engine.tgid_blockIdentifiers
        if let line = roleIndex(atFlatOffset: engineSelectedRange.location), line < identifiers.count {
            compositionMintedLine = (identifiers[line], baseline)
        }
        if changedStructure { deliverChangeNotificationNow() }
    }

    /// A composition that ended with its minted line still EMPTY — cancelled, or committed as
    /// nothing — leaves no line behind: the line goes, unrecorded, and the caret and the undo
    /// baseline return to the atom's stop (`resolveAtomStopBeforeComposition`).
    internal func removeEmptyCompositionMintedLine() {
        guard let minted = compositionMintedLine else { return }
        compositionMintedLine = nil
        guard engine.markedTextRange == nil,
              let index = engine.tgid_blockIdentifiers.firstIndex(of: minted.identifier),
              index < currentRoles.count, flatLength(ofRoleAt: index) == 0,
              case .standalone(.paragraph) = currentRoles[index].position,
              currentRoles.count > 1 else { return }
        var plan = currentRoles
        plan.remove(at: index)
        let start = flatOffset(ofRoleAt: index)
        // The line and ONE separator: the one before it, or after it for the document's first line.
        let range = index > 0 ? NSRange(location: start - 1, length: 1) : NSRange(location: start, length: 1)
        engineUndoManager.disableUndoRegistration()
        performHostStructuralEdit {
            replaceFlat(range, with: "", adopting: plan)
        }
        engineUndoManager.enableUndoRegistration()
        endTypingRun()
        engineSelectedRange = minted.baseline.selection
        lastSettledUndoSnapshot = minted.baseline
        deliverChangeNotificationNow()
    }

    // MARK: - §5.2 deleting the atom: two steps

    /// Backspace with the caret BEFORE the atom acts on the previous block, as legacy's
    /// non-selected gap does: its last grapheme goes, or the block itself when it is an empty
    /// paragraph; a previous media unit is selected instead (never deleted in one press); a
    /// leading atom is a no-op. Reached from both doors.
    @discardableResult
    internal func applyBackspaceBeforeAtomUnit(at atom: Int) -> Bool {
        guard atom > 0 else { return true }
        if let previousAtom = atomUnitIndex(forRoleAt: atom - 1) {
            selectAtomUnit(at: previousAtom)
            return true
        }
        // A SIBLING paragraph, not merely the previous role. A media atom that is a container's
        // first child has a container's own line, or the block outside it, above — and taking a
        // grapheme from either would be reaching out of the container, which is the mistake this
        // type exists to make unrepresentable.
        guard case let .sibling(previous) = neighbour(before: atom),
              case .standalone(.paragraph) = currentRoles[previous].position else { return true }
        let start = flatOffset(ofRoleAt: previous)
        let length = flatLength(ofRoleAt: previous)
        if length == 0 {
            var plan = currentRoles
            plan.remove(at: previous)
            replaceFlat(NSRange(location: start, length: 1), with: "", adopting: plan)
            engineSelectedRange = NSRange(location: start, length: 0)
        } else {
            let text = engine.attributedBlocks[previous].string as NSString
            let grapheme = text.rangeOfComposedCharacterSequence(at: length - 1)
            replaceFlat(NSRange(location: start + grapheme.location, length: grapheme.length), with: "")
            engineSelectedRange = NSRange(location: start + grapheme.location, length: 0)
        }
        return true
    }

    // MARK: - §5.5 Backspace at the start of the block after a unit

    /// Never merges: the caret lands at the caption's end (after the atom for a caption-less kind),
    /// and an empty BODY PARAGRAPH is deleted on the way.
    ///
    /// The travel is unconditional — a cell start after a unit travels out of the table, as legacy's
    /// Backspace at a cell start does. The DELETION is not: it may only take a block that is its own
    /// whole block, so only `.standalone(.paragraph)` qualifies. An emptiness test alone would
    /// remove a table's empty first cell, a code block's empty language line or a quote's empty first
    /// child POSITIONALLY out of a container that still declares it — the same trap
    /// `applyBackspaceBeforeMediaAtom` guards against one rule above.
    @discardableResult
    internal func applyBackspaceAtStartOfBlockAfterAtomUnit(at index: Int) -> Bool {
        guard index > 0, index < currentRoles.count, atomUnitIndex(forRoleAt: index) == nil,
              let atom = atomUnitIndex(forRoleAt: index - 1) else { return false }
        let target = atomUnitCompanionIndex(ofAtomAt: atom) ?? atom
        let landing = flatOffset(ofRoleAt: target) + flatLength(ofRoleAt: target)
        if case .standalone(.paragraph) = currentRoles[index].position, flatLength(ofRoleAt: index) == 0 {
            var plan = currentRoles
            plan.remove(at: index)
            let start = flatOffset(ofRoleAt: index)
            replaceFlat(NSRange(location: start - 1, length: 1), with: "", adopting: plan)
        }
        engineSelectedRange = NSRange(location: landing, length: 0)
        return true
    }

    // MARK: - §6.2 settle: atom integrity

    /// An atom block holds exactly its attachment. Only a bypass path (dictation, an IME commit, a
    /// controller path the gate never saw) can break that: text before the attachment becomes a
    /// body paragraph above; text after it moves to the caption's start, or to a body paragraph
    /// below a caption-less kind; an atom whose attachment is gone becomes a body paragraph with
    /// whatever text it has, and its caption line becomes one too.
    internal func settleMediaAtomIntegrity() {
        var index = 0
        while index < currentRoles.count {
            defer { index += 1 }
            guard case .standalone(.media) = currentRoles[index].position else { continue }
            let text = engine.attributedBlocks[index]
            let atomOffset = (0..<text.length).first {
                text.attribute(.attachment, at: $0, effectiveRange: nil) is MediaTextAttachment
            }
            guard let atomOffset else {
                var plan = currentRoles
                plan[index] = freshBodyRole(within: currentRoles[index].ancestry)
                if let caption = captionIndex(ofMediaAtomAt: index) { plan[caption] = freshBodyRole(within: currentRoles[caption].ancestry) }
                adoptRolePlan(plan)
                continue
            }
            let start = flatOffset(ofRoleAt: index)
            let after = text.length - atomOffset - 1
            if after > 0 {
                let tail = (text.string as NSString).substring(from: atomOffset + 1)
                // By the atom's KIND, never by whether its caption line happens to exist. The two
                // disagree in exactly the damaged states this rule repairs, and both ways round: a
                // tail copied into a caption-less atom's STRAY line is deleted with that line by
                // presence a moment later (text lost, silently), and a captioned atom whose line has
                // vanished would put its tail in a paragraph below and then get an EMPTY line
                // inserted above it.
                if mediaShape(atRole: index)?.isCaptionless ?? false {
                    var plan = currentRoles
                    plan.insert(freshBodyRole(within: currentRoles[index].ancestry), at: index + 1)
                    replaceFlat(NSRange(location: start + atomOffset + 1, length: 0), with: "\n", adopting: plan)
                } else if let caption = captionIndex(ofMediaAtomAt: index) ?? insertCaptionLine(afterAtomAt: index) {
                    // The caption is BELOW the atom, so inserting there does not move the tail: the
                    // later offset is edited first and the delete's range stays the one measured.
                    // The same holds for a line this rule had to insert, which lands at the atom
                    // block's end — after the tail, never before it.
                    let captionStart = flatOffset(ofRoleAt: caption)
                    replaceFlat(NSRange(location: captionStart, length: 0), with: tail)
                    replaceFlat(NSRange(location: start + atomOffset + 1, length: after), with: "")
                }
            }
            if atomOffset > 0 {
                var plan = currentRoles
                plan.insert(freshBodyRole(within: currentRoles[index].ancestry), at: index)
                replaceFlat(NSRange(location: start + atomOffset, length: 0), with: "\n", adopting: plan)
                index += 1
            }
        }
    }

    // MARK: - §6.2 settle: caption-line presence

    /// The caption line an atom is missing, inserted as its own engine block directly below it, and
    /// the index it landed at. Nil only for a role that is not a media atom.
    ///
    /// Shared by BOTH settle rules that can need one — integrity, moving a tail into the caption, and
    /// presence — so the two cannot disagree about the line's spelling: its owner, its derived
    /// `captionLineID`, and the caret it must not carry into the new line. The caret is saved and
    /// restored across the insert, as `settleAuthorLinePresence` does.
    internal func insertCaptionLine(afterAtomAt atom: Int) -> Int? {
        guard let shape = mediaShape(atRole: atom) else { return nil }
        let caret = engineSelectedRange.location
        let end = flatOffset(ofRoleAt: atom) + flatLength(ofRoleAt: atom)
        var plan = currentRoles
        plan.insert(.secondary(owner: .block(.media(shape)), line: shape.captionLineID, kind: .mediaCaption,
                               within: currentRoles[atom].ancestry), at: atom + 1)
        replaceFlat(NSRange(location: end, length: 0), with: "\n", adopting: plan)
        engineSelectedRange = NSRange(location: caret <= end ? caret : caret + 1, length: 0)
        return atom + 1
    }

    /// A captioned atom is followed by its caption line; a caption-less atom never has one. Matches
    /// the forward pass exactly, so a document set and an edit agree about the same document.
    internal func settleCaptionLinePresence() {
        var guardCount = 0
        while guardCount < currentRoles.count, let atom = currentRoles.indices.first(where: { index in
            guard let shape = mediaShape(atRole: index), !shape.isCaptionless else { return false }
            // A caption belongs to the atom's OWN unit, so this is a leaf-container question and
            // not a sibling one — a paragraph after the atom is not a missing caption.
            guard case let .sameLeafContainer(next) = neighbour(after: index) else { return true }
            return currentRoles[next].secondaryKind != .mediaCaption
        }) {
            guardCount += 1
            guard insertCaptionLine(afterAtomAt: atom) != nil else { return }
        }
        guardCount = 0
        while guardCount < currentRoles.count, let stray = currentRoles.indices.first(where: { index in
            guard currentRoles[index].secondaryKind == .mediaCaption, let atom = mediaAtomIndex(forRoleAt: index) else { return false }
            return mediaShape(atRole: atom)?.isCaptionless ?? true
        }) {
            guardCount += 1
            let range = flatRange(ofRoleAt: stray)
            // The separator BEFORE the line is what makes it its own block; at offset 0 there is
            // none, and `location - 1` would address a character outside the document.
            guard range.location > 0 else { return }
            let caret = engineSelectedRange.location
            var plan = currentRoles
            plan.remove(at: stray)
            replaceFlat(NSRange(location: range.location - 1, length: range.length + 1), with: "", adopting: plan)
            engineSelectedRange = NSRange(location: min(caret, range.location - 1), length: 0)
        }
    }
}
#endif
