#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// R9-buttons — the hosted row view, positioned over the atom's frame.
///
/// Hosted the way `syncCustomEmojiViews` and `syncMediaViews` host theirs: the attachment reserves
/// the box, and this walks the laid-out text and puts a view over it. NOT through
/// `NSTextAttachmentViewProvider` — this is a custom text view that already does its own drawing,
/// and that path was measured not to fire here at all.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The row shape at a role index, or nil for any other role.
    internal func buttonRowShape(atRole index: Int) -> ButtonRowShape? {
        guard index >= 0, index < currentRoles.count,
              case let .standalone(.buttonRow(shape)) = currentRoles[index].position else { return nil }
        return shape
    }

    /// Whether rows draw their "…" control: exactly when a host is listening for the menu. The
    /// article editor wires it; the chat composer is preservation-only and does not.
    internal var showsButtonRowMenu: Bool { deferredConfiguration.onRequestButtonRowMenu != nil }

    /// Reconciles hosted row views against the laid-out document. Idempotent; runs after layout.
    internal func syncButtonRowViews() {
        var live: Set<BlockID> = []
        for index in currentRoles.indices {
            guard let shape = buttonRowShape(atRole: index) else { continue }
            let offset = flatOffset(ofRoleAt: index)
            // The ATTACHMENT's own frame, not a selection rect: a selection rect is the LINE's
            // height, which for an atom is not the atom's box.
            let frame = engine.id_attachmentFrame(forCanonicalOffset: UInt(offset))
            guard !frame.isNull, frame.width > 0, frame.height > 0 else { continue }
            live.insert(shape.id)

            let view: RichTextButtonRowView
            if let existing = buttonRowViews[shape.id] {
                view = existing
            } else {
                let fresh = RichTextButtonRowView()
                // The seam's view is passthrough by default, because the LEGACY canvas resolves pill
                // taps centrally. The engine resolves them per hosted view instead — as it already
                // does for a details chevron, a checklist marker and a media poster — so it turns
                // interaction on and attaches its own recogniser. Pills stay passthrough inside it,
                // so this view is what receives the tap.
                fresh.isUserInteractionEnabled = true
                fresh.addGestureRecognizer(
                    gatedTapRecognizer(action: #selector(handleButtonRowTap(_:))))
                buttonRowViews[shape.id] = fresh
                view = fresh
            }
            // Into the ENGINE, which is a scroll view, because `id_attachmentFrame` answers in its
            // CONTENT space. Parented to the editor instead, the view is correct only while
            // `contentOffset` is zero and then stays pinned to the screen as its text scrolls away.
            // A row inside a table cell rides the cell's own scrolling content, like the chrome.
            let host = engine.id_placedRunContentViewForBlock(at: UInt(index)) ?? engine
            if view.superview !== host { view.removeFromSuperview(); host.addSubview(view) }
            view.frame = host === engine ? frame : engine.convert(frame, to: host)
            view.update(buttons: shape.buttons, alignment: shape.alignment, width: frame.width,
                        mapper: bridge.mapper, showsMenuAffordance: showsButtonRowMenu,
                        emojiProvider: deferredConfiguration.emojiViewProvider)
        }

        for (id, view) in buttonRowViews where !live.contains(id) {
            view.removeFromSuperview()
            buttonRowViews[id] = nil
        }
    }

    // MARK: - Verbs: every pill edit is a shape rewrite

    /// The role index of a row by id, or nil.
    internal func buttonRowIndex(ofBlock id: BlockID) -> Int? {
        currentRoles.indices.first { buttonRowShape(atRole: $0)?.id == id }
    }

    /// Every pill-level edit is a SHAPE REWRITE — a row's labels ride in the shape, because it owns
    /// no text. Mirrors `applyMediaShape`: plan, adopt, re-derive the atom's attachment, restore the
    /// selection, and register the inverse so one verb is one undo step.
    internal func applyButtonRowShape(_ shape: ButtonRowShape, restoring previous: ButtonRowShape, at index: Int) {
        var plan = currentRoles
        let undoBefore = currentUndoSnapshot()
        let ancestry = currentRoles[index].ancestry
        plan[index] = currentRoles[index].replacingShape(.buttonRow(shape))
        let selection = engineSelectedRange
        performHostStructuralChange {
            adoptRolePlan(plan)
            // The atom's attachment carries the shape: re-derived now, not left to the next edit.
            engine.tgid_mergeAttributes(bridge.buttonRowAtomAttributes(for: shape, within: ancestry),
                                        removingKeys: [],
                                        inCanonicalRange: NSRange(location: flatOffset(ofRoleAt: index), length: 1))
            engineSelectedRange = selection
        }
        recordUndoStepForCommand(restoring: undoBefore)
        // NO `deliverChangeNotificationNow()`: `performHostStructuralChange` already delivers exactly
        // one, so a delivery here made every pill edit notify TWICE. `applyMediaShape`, which this
        // mirrors, has never had one. Found while writing the identical line for `applyTableShape`.
        setNeedsLayout()
    }

    /// Appends one default pill.
    internal func addButtonToRow(rowID: BlockID) {
        guard let index = buttonRowIndex(ofBlock: rowID), var shape = buttonRowShape(atRole: index) else { return }
        let previous = shape
        shape.buttons.append(ButtonRef(label: [], action: .url("")))
        applyButtonRowShape(shape, restoring: previous, at: index)
    }

    internal func setButtonRowAlignment(rowID: BlockID, _ alignment: ButtonRowAlignment) {
        guard let index = buttonRowIndex(ofBlock: rowID), var shape = buttonRowShape(atRole: index) else { return }
        let previous = shape
        shape.alignment = alignment
        applyButtonRowShape(shape, restoring: previous, at: index)
    }

    /// Replaces one pill; `nil` removes it. Removing the LAST pill removes the row, as legacy does —
    /// an empty row left behind by a pill delete is not a state a user asked for.
    internal func replaceButton(rowID: BlockID, at pill: Int, with button: ButtonRef?) {
        guard let index = buttonRowIndex(ofBlock: rowID), var shape = buttonRowShape(atRole: index),
              shape.buttons.indices.contains(pill) else { return }
        if button == nil, shape.buttons.count <= 1 { return deleteButtonRow(rowID: rowID) }
        let previous = shape
        if let button { shape.buttons[pill] = button } else { shape.buttons.remove(at: pill) }
        applyButtonRowShape(shape, restoring: previous, at: index)
    }

    /// Removes the whole row, caret parked where it began.
    internal func deleteButtonRow(rowID: BlockID) {
        guard let index = buttonRowIndex(ofBlock: rowID) else { return }
        let range = flatRange(ofRoleAt: index)
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                var plan = currentRoles
                guard currentRoles.count > 1 else {
                    // The document's ONLY block cannot be removed — the engine always holds one — so
                    // it becomes an empty paragraph instead, which is exactly what
                    // `settleButtonRowAtomIntegrity` would make of it once the atom was gone.
                    plan[index] = freshBodyRole(within: currentRoles[index].ancestry)
                    replaceFlat(range, with: "", adopting: plan)
                    engineSelectedRange = NSRange(location: range.location, length: 0)
                    return
                }
                plan.remove(at: index)
                // A block is removed with ONE separator: the one BEFORE it, or — when it is the
                // first block and so has none — the one after.
                let cut = index > 0
                    ? NSRange(location: range.location - 1, length: range.length + 1)
                    : NSRange(location: range.location, length: range.length + 1)
                replaceFlat(cut, with: "", adopting: plan)
                engineSelectedRange = NSRange(location: cut.location, length: 0)
            }
        }
        setNeedsLayout()
    }

    /// Re-derives every row's attachment. Called when the menu affordance appears or disappears,
    /// because that flag is part of the packing WIDTH and not merely of the drawing.
    /// One attribute edit for every row, offsets walked once (`applyPresentationEdits`).
    internal func rerenderButtonRowAtoms() {
        let blocks = engine.attributedBlocks
        var edits: [PresentationEdit] = []
        var start = 0
        for index in currentRoles.indices where index < blocks.count {
            defer { start += blocks[index].length + 1 }
            guard let shape = buttonRowShape(atRole: index) else { continue }
            edits.append((NSRange(location: start, length: 1),
                          bridge.buttonRowAtomAttributes(for: shape, within: currentRoles[index].ancestry), []))
        }
        applyPresentationEdits(edits)
        setNeedsLayout()
    }

    // MARK: - Tap routing

    /// The recogniser's entry point. Resolved in the ENGINE's space, like the chevron's, because the
    /// arbiter below compares frames that live there.
    @objc internal func handleButtonRowTap(_ recognizer: UITapGestureRecognizer) {
        _ = handleButtonRowTapIfNeeded(atPointInEngine: recognizer.location(in: engine))
    }

    /// Returns true when the tap was a row's — the "…" first, since it sits beside the pills and has
    /// its own rect. Resolved GEOMETRICALLY inside the hosted view, as legacy resolves it: a pill has
    /// no caret position of its own here, and never needed one.
    internal func handleButtonRowTapIfNeeded(atPointInEngine point: CGPoint) -> Bool {
        for (id, view) in buttonRowViews {
            let local = engine.convert(point, to: view)
            if !view.menuButtonRect.isEmpty, view.menuButtonRect.contains(local),
               let request = deferredConfiguration.onRequestButtonRowMenu,
               let index = buttonRowIndex(ofBlock: id), let shape = buttonRowShape(atRole: index) {
                request(ButtonRowMenuRequest(
                    view: engine,
                    sourceRect: view.convert(view.menuButtonRect, to: engine),
                    alignment: shape.alignment,
                    addButton: { [weak self] in self?.addButtonToRow(rowID: id) },
                    setAlignment: { [weak self] alignment in self?.setButtonRowAlignment(rowID: id, alignment) },
                    deleteRow: { [weak self] in self?.deleteButtonRow(rowID: id) }))
                return true
            }
            guard let edit = deferredConfiguration.onEditButtonRequested,
                  let pill = view.pillIndex(at: local),
                  let index = buttonRowIndex(ofBlock: id), let shape = buttonRowShape(atRole: index),
                  shape.buttons.indices.contains(pill) else { continue }
            edit(shape.buttons[pill], true) { [weak self] updated in
                self?.replaceButton(rowID: id, at: pill, with: updated)
            }
            return true
        }
        return false
    }

    // MARK: - Settle: atom integrity

    /// A row block holds exactly its attachment. When it does not, the role is no longer a row.
    ///
    /// This is the button row's half of `settleMediaAtomIntegrity`, and it is what makes a row
    /// DELETABLE. Selecting the atom and pressing Backspace removes the CHARACTER, leaving a
    /// zero-length block — and because a row's shape carries the whole model and `block(runs:)`
    /// ignores runs, that block still read back as a full row. Measured: after the third press the
    /// engine held `lengths=[0, 5]` with the role still `row(r)`, so the row was undeletable and the
    /// document never lost it. Media never had this bug because its integrity pass already turned an
    /// attachment-less atom into a body paragraph.
    ///
    /// Simpler than media's: a row has no companion line to demote with it, and no text of its own
    /// that could survive beside the attachment — anything typed into the block is a bypass path's
    /// doing and becomes the paragraph's text.
    ///
    /// A row that still holds its atom but ALSO holds text — a bypass path's insert at one of its
    /// stops, the engine's own plain-text paste chief among them (it never reaches the gate) — gets
    /// media's caption-less repair: text before the attachment becomes a body paragraph above, text
    /// after it one below. Left in the row's line, the text was invisible to the model (lost on
    /// send) while the engine drew it, and text before the attachment stopped the row's hosted view
    /// being drawn (composer harness p13, `HarnessButtonRowStopTypingTests`).
    internal func settleButtonRowAtomIntegrity() {
        var index = 0
        while index < currentRoles.count {
            defer { index += 1 }
            guard buttonRowShape(atRole: index) != nil else { continue }
            let text = engine.attributedBlocks[index]
            let atomOffset = (0..<text.length).first {
                text.attribute(.attachment, at: $0, effectiveRange: nil) is ButtonRowTextAttachment
            }
            guard let atomOffset else {
                var plan = currentRoles
                plan[index] = freshBodyRole(within: currentRoles[index].ancestry)
                adoptRolePlan(plan)
                continue
            }
            let start = flatOffset(ofRoleAt: index)
            if text.length - atomOffset - 1 > 0 {
                var plan = currentRoles
                plan.insert(freshBodyRole(within: currentRoles[index].ancestry), at: index + 1)
                replaceFlat(NSRange(location: start + atomOffset + 1, length: 0), with: "\n", adopting: plan)
            }
            if atomOffset > 0 {
                var plan = currentRoles
                plan.insert(freshBodyRole(within: currentRoles[index].ancestry), at: index)
                replaceFlat(NSRange(location: start + atomOffset, length: 0), with: "\n", adopting: plan)
                index += 1
            }
        }
    }

    // MARK: - Authoring

    /// A button row at the caret, carrying one default pill.
    ///
    /// One edit through the controller, like `insertMediaBlock` and deliberately NOT like
    /// `insertTable`: a document set plus `recordUndoStepForStructuralChange` is one undo step, and a
    /// row added mid-composition must not discard the typing before it.
    ///
    /// Placed wherever the caret is, at any depth — a row asked for inside a quote becomes a CHILD
    /// of that quote, taking the caret's own ancestry. A role built at top level would sit visually
    /// inside the quote and belong to no quote at all, and the regroup would close the quote before
    /// it and reopen one after. A caret in a CELL places the row after the whole table: that is the
    /// container rule in `planAtomUnitPlacement`, and it is what keeps a row out of a cell — where
    /// `EngineDocumentBridge.cellParagraph` would silently drop it — without making the button do
    /// nothing, which is the defect this project already fixed for media on K3.
    public func insertButtonRow() {
        guard !currentRoles.isEmpty else { return }
        let selection = engineSelectedRange
        if selection.length > 0 { replaceFlat(selection, with: "") }
        guard roleIndex(atFlatOffset: engineSelectedRange.location) != nil else { return }
        let shape = ButtonRowShape(ButtonRowBlock(id: BlockID(UUID().uuidString),
                                                  buttons: [ButtonRef(label: [], action: .url(""))],
                                                  alignment: .justify))
        deliveringOneChangeNotification {
            performHostStructuralEdit {
                let caret = engineSelectedRange.location
                guard let index = roleIndex(atFlatOffset: caret) else { return }
                let ancestry = currentRoles[index].ancestry
                let placement = planAtomUnitPlacement(
                    unitRoles: [.standalone(.buttonRow(shape), within: ancestry)],
                    unitText: "\u{FFFC}", at: index, caret: caret)
                replaceFlat(NSRange(location: placement.insertAt, length: 0), with: placement.inserted,
                            adopting: placement.plan)
                // The attachment cannot travel through a text edit, so it is written right after, in
                // the same undo group. Measured against the line it will sit on, so the indent it
                // subtracts is the caret's depth and not 0.
                restyleFlat(NSRange(location: placement.atomStart, length: 1),
                            with: bridge.buttonRowAtomAttributes(for: shape, within: ancestry))
                // A row is TEXT-FREE, so without a following sibling paragraph there is nowhere to
                // type after it. A SIBLING, not merely the next role: a row that is a container's
                // LAST child would otherwise see the block FOLLOWING the container, mint nothing,
                // and leave the caret outside with nothing to type into.
                let atomEnd = placement.atomStart + 1
                if case let .sibling(sibling) = neighbour(after: placement.atomRoleIndex),
                   case .standalone(.paragraph) = currentRoles[sibling].position {
                    engineSelectedRange = NSRange(location: atomEnd + 1, length: 0)
                } else {
                    var withTrailing = currentRoles
                    withTrailing.insert(.standalone(.paragraph(ParagraphShape(id: BlockID(UUID().uuidString))),
                                                    within: ancestry), at: placement.atomRoleIndex + 1)
                    replaceFlat(NSRange(location: atomEnd, length: 0), with: "\n", adopting: withTrailing)
                    engineSelectedRange = NSRange(location: atomEnd + 1, length: 0)
                }
            }
        }
        setNeedsLayout()
    }
}
#endif
