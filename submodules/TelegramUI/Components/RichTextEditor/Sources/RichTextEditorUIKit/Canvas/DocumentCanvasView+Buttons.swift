#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Backspace handling for button rows.
///
/// A row is TEXT-FREE, and that is the whole problem this file exists to solve. `prevTextPosition`
/// walks back to the nearest position that carries text, so with N adjacent rows it skips over ALL of
/// them — and iOS delivers Backspace as an object-replacement RANGE anchored there. Left to the generic
/// selection-replace, `applyReplaceOutcome`'s `replaceSubrange(start.index ... end.index)` then drops every row
/// in between at once (the reported "Backspace deletes the whole sequence" bug).
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// The row and pill index addressed by `pos`, if it lands on a pill atom. A row's interior spans
    /// `nodeStart + 1 ... nodeStart + atomCount`, one atom per pill (minimum one, so an empty row is
    /// still addressable).
    func buttonRowPill(at pos: Int) -> (box: ButtonRowBox, index: Int)? {
        for box in allBoxesForButtons() {
            guard let row = box as? ButtonRowBox else { continue }
            let first = row.nodeStart + 1
            let count = max(1, row.buttons.count)
            if pos >= first, pos < first + count {
                return (row, pos - first)
            }
        }
        return nil
    }

    /// The LAST pill whose atom lies within `[lo, hi]` — the one nearest the caret, so a Backspace that
    /// spans several rows removes the closest pill and leaves the rest for subsequent presses.
    func lastButtonPill(in lo: Int, _ hi: Int) -> (box: ButtonRowBox, index: Int)? {
        var result: (box: ButtonRowBox, index: Int)?
        for box in allBoxesForButtons() {
            guard let row = box as? ButtonRowBox else { continue }
            let first = row.nodeStart + 1
            let count = max(1, row.buttons.count)
            for index in 0 ..< count where (first + index) >= lo && (first + index) <= hi {
                result = (row, index)
            }
        }
        return result
    }

    /// Every box that can host a row, flattened. Rows are top-level for authoring, but one can arrive
    /// inside a block quote or a details body via the edit round-trip, so the walk recurses those two
    /// containers exactly as `owningStack` does.
    private func allBoxesForButtons() -> [CanvasBlock] {
        var out: [CanvasBlock] = []
        func walk(_ stack: BlockStack) {
            for box in stack.boxes {
                out.append(box)
                if let d = box as? DetailsBox { walk(d.children) }
                else if let bq = box as? BlockQuoteBox, !bq.collapsed { walk(bq.children) }
            }
        }
        walk(root)
        return out
    }

    /// Deletes ONE pill. When it was the row's last, the row itself goes. Returns the caret position to
    /// park at, or nil when the row could not be located.
    ///
    /// Called inside `editing { }` by the caller, so it registers as one undo step.
    ///
    /// **TASK 38 — the two caret writes below are the only ones in this task's six files that sit in
    /// no `editing { }` of their own, and Task 37's rule is that being in no bracket is NOT what
    /// makes a site safe** (`applyCaretOutcome`, `+Editing.swift`). Asked of the CALLERS: both are
    /// `deleteButtonPillIfNeeded`'s `editing { deleteButtonPill(…) }`, so every reachable call runs
    /// under `performEditing`, whose tail already delivers `refreshSelectionUI()` +
    /// `onSelectionChange?()`. A `setSelection` here would therefore be a SECOND host selection
    /// report per transaction, inside the delegate bracket — Class 1 of that measurement, verbatim.
    /// One level further out (`legacyDeleteBackward` ← the backend's `deleteBackward()`) adds no
    /// publish of its own: that witness is forwarded BARE (`+Deletion.swift`).
    ///
    /// They apply through `applyCaretOutcome` rather than becoming this function's return value.
    /// Both mechanisms would be behaviour-identical (nothing between these writes and the end of the
    /// enclosing body reads the caret back), so the deciding argument is scope: the `Bool` return is
    /// a DIFFERENT signal — "the row could not be located" — and an outcome cannot carry it, while
    /// R22 forbids keeping `@discardableResult` on an outcome-returning declaration. This task adds
    /// no API; it converts writes.
    @discardableResult
    func deleteButtonPill(row: ButtonRowBox, index: Int) -> Bool {
        guard let (stack, boxIndex) = owningStack(ofBlockID: row.id) else { return false }

        if row.buttons.count <= 1 {
            // The last pill (or an already-empty row): remove the whole block, parking the caret where
            // the row began so a further Backspace addresses whatever now precedes it.
            let caret = max(0, row.nodeStart)
            var newBoxes = stack.boxes
            newBoxes.remove(at: boxIndex)
            stack.boxes = newBoxes
            recomputeSpans()
            applyCaretOutcome(.caret(at: caret))
            return true
        }

        row.replaceButton(at: index, with: nil)
        recomputeSpans()
        // Land on the pill that took its place, or the new last pill when the tail was removed, so
        // repeated Backspaces walk leftwards through the row.
        let remaining = max(1, row.buttons.count)
        let landing = row.nodeStart + 1 + min(index, remaining - 1)
        applyCaretOutcome(.caret(at: landing))
        return true
    }

    /// The Backspace entry point, hooked at the TOP of `deleteBackward` — before the generic
    /// selection-replace, which is what would otherwise wipe a whole run of rows.
    ///
    /// Handles both shapes iOS delivers:
    /// - a COLLAPSED caret sitting on a pill atom, and
    /// - an object-replacement RANGE whose span reaches back over one or more rows. The
    ///   `selFrom >= prevTextPosition(before: selTo)` guard is the same one the media / collapsed-quote
    ///   / quote-child arms use: it admits a structural range while excluding a genuine text selection
    ///   that merely happens to end after a row.
    func deleteButtonPillIfNeeded() -> Bool {
        if selFrom == selTo {
            guard let (row, index) = buttonRowPill(at: selTo) else { return false }
            editing { deleteButtonPill(row: row, index: index); return .unchanged }
            return true
        }
        guard selFrom >= prevTextPosition(before: selTo),
              let (row, index) = lastButtonPill(in: selFrom, selTo)
        else { return false }
        editing { deleteButtonPill(row: row, index: index); return .unchanged }
        return true
    }

    // MARK: - Authoring

    /// Inserts a button row at the caret, carrying one default pill. Mirrors `insertTable` exactly:
    /// an EMPTY caret paragraph is replaced, a caret interior to a paragraph splits it, and a caret at
    /// the start/end inserts before/after — the empty-replace must be checked FIRST, since an empty
    /// paragraph satisfies both `local == 0` and `local == textLength`.
    ///
    /// Rows are TOP-LEVEL for authoring (`!isInsideTable` / `!isInsideBlockQuote`); one arriving inside a
    /// container via the edit round-trip still renders and round-trips, it just cannot be created there.
    func insertButtonRow() {
        guard !boxes.isEmpty, !isInsideTable(head), !isInsideBlockQuote(head),
              let a = activeStack(at: head), a.box is BlockBox else { return }
        editing {
            // THE CLAIM IS APPLIED HERE, ON THE NEXT INSTRUCTION — never batched to the end of this
            // transaction's own `return`: the next statement's `activeStack(at: head)` reads the caret back. A deferred claim re-resolves at the
            // pre-delete caret and silently produces a DIFFERENT document. Why, and the full list of
            // fourteen such sites: `applyReplaceOutcome`'s doc in `+Editing.swift`. Pinned by
            // `CaretLandingCharacterizationTests.test_insertButtonRowOverAMidParagraphSelectionSplitsTheParagraph`.
            if selFrom != selTo {
                applyCaretOutcome(applySelectionReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: ""))
            }
            guard let active = activeStack(at: head), let p = active.box as? BlockBox else { return .unchanged }
            let model = ButtonRowBlock(id: BlockID.generate(),
                                       buttons: [ButtonRef(label: [], action: .url(""))],
                                       alignment: .justify)
            let rowBox = ButtonRowBox(row: model, mapper: mapper, width: effectiveWidth)
            var newBoxes = active.stack.boxes
            let idx = active.index
            if p.textLength == 0 {
                newBoxes.replaceSubrange(idx...idx, with: [rowBox])
            } else if active.local > 0, active.local < p.textLength {
                let (upper, lower) = p.currentParagraph().split(at: active.local, newID: BlockID.generate())
                let replacement: [any CanvasBlock] = [
                    BlockBox(paragraph: upper, mapper: p.mapper, width: effectiveWidth),
                    rowBox,
                    BlockBox(paragraph: lower, mapper: p.mapper, width: effectiveWidth),
                ]
                newBoxes.replaceSubrange(idx...idx, with: replacement)
            } else if active.local == 0 {
                newBoxes.insert(rowBox, at: idx)
            } else {
                newBoxes.insert(rowBox, at: idx + 1)
            }
            active.stack.boxes = newBoxes
            recomputeSpans()
            let caret = rowBox.nodeStart + 1
            return .caret(at: caret)
        }
    }

    /// Converts the current selection into ONE inline pill whose label is the selected text — the Link
    /// flow's analogue. The run collapses to a single `U+FFFC`, so the pill is an atom like an emoji.
    func makeSelectionInlineButton() {
        guard selFrom != selTo, let region = leafRegion(containingGlobal: selFrom)?.0 else { return }
        let label: String = {
            guard let range = selectedTextRange else { return "" }
            return text(in: range) ?? ""
        }()
        guard !label.isEmpty else { return }
        editing {
            let attributes: CharacterAttributes = {
                var ca = CharacterAttributes.plain
                ca.button = ButtonRef(label: [TextRun(text: label)], action: .url(""))
                return ca
            }()
            let fragment = NSAttributedString(string: "\u{FFFC}",
                                              attributes: mapper.attributes(for: attributes, style: .body))
            let lo = min(selFrom, selTo) - region.globalStart
            let hi = max(selFrom, selTo) - region.globalStart
            guard lo >= 0, hi <= region.layout.attributedString.length else { return .unchanged }
            region.layout.replace(start: lo, end: hi, with: fragment)
            recomputeSpans()
            let caret = region.globalStart + lo + fragment.length
            return .caret(at: caret)
        }
    }

    /// Replaces (or, with `nil`, removes) the inline pill whose atom sits at `pos`.
    func replaceInlineButton(at pos: Int, with button: ButtonRef?) {
        guard let (region, _) = leafRegion(containingGlobal: pos) else { return }
        let local = pos - region.globalStart
        guard local >= 0, local < region.layout.attributedString.length,
              region.layout.attributedString.attribute(.attachment, at: local, effectiveRange: nil) is ButtonTextAttachment
        else { return }
        editing {
            if let button {
                var ca = CharacterAttributes.plain
                ca.button = button
                let fragment = NSAttributedString(string: "\u{FFFC}",
                                                  attributes: mapper.attributes(for: ca, style: .body))
                region.layout.replace(start: local, end: local + 1, with: fragment)
            } else {
                region.layout.replace(start: local, end: local + 1, with: NSAttributedString(string: ""))
            }
            recomputeSpans()
            let caret = region.globalStart + local + (button == nil ? 0 : 1)
            return .caret(at: caret)
        }
    }

    /// Appends a pill to a row and immediately asks the host to edit it, so a fresh button is never
    /// left blank. One undo step for the insertion; the edit itself is another.
    func addButtonToRow(rowID: BlockID) {
        guard let (stack, index) = owningStack(ofBlockID: rowID),
              let row = stack.boxes[index] as? ButtonRowBox else { return }
        var appended = 0
        editing {
            appended = row.appendButton(ButtonRef(label: [], action: .url("")))
            recomputeSpans()
            let caret = row.nodeStart + 1 + appended
            return .caret(at: caret)
        }
        guard let buttonEditRequested, row.buttons.indices.contains(appended) else { return }
        let appendedIndex = appended
        buttonEditRequested(row.buttons[appendedIndex], true) { [weak self] updated in
            guard let self, let (stack, i) = self.owningStack(ofBlockID: rowID),
                  let liveRow = stack.boxes[i] as? ButtonRowBox else { return }
            self.editing {
                if updated == nil, liveRow.buttons.count <= 1 {
                    var newBoxes = stack.boxes
                    newBoxes.remove(at: i)
                    stack.boxes = newBoxes
                } else {
                    liveRow.replaceButton(at: appendedIndex, with: updated)
                }
                self.recomputeSpans()
                return .unchanged
            }
        }
    }

    /// Sets a row's alignment as one undo step.
    func setButtonRowAlignment(rowID: BlockID, _ alignment: ButtonRowAlignment) {
        guard let (stack, index) = owningStack(ofBlockID: rowID),
              let row = stack.boxes[index] as? ButtonRowBox else { return }
        editing {
            row.setAlignment(alignment)
            recomputeSpans()
            return .unchanged
        }
    }

    /// Removes a whole row, caret parked where it began.
    func deleteButtonRow(rowID: BlockID) {
        guard let (stack, index) = owningStack(ofBlockID: rowID),
              let row = stack.boxes[index] as? ButtonRowBox else { return }
        editing {
            let caret = max(0, row.nodeStart)
            var newBoxes = stack.boxes
            newBoxes.remove(at: index)
            stack.boxes = newBoxes
            recomputeSpans()
            return .caret(at: caret)
        }
    }

    /// Tap routing, called from `+Interaction` right after `handleFormulaTapIfNeeded`. Mirrors that
    /// function's early-return shape: returns false (letting the tap place a caret normally) when the
    /// point is not on a pill or no host is listening.
    func handleButtonTapIfNeeded(at point: CGPoint) -> Bool {
        // The row's "…" menu affordance, checked FIRST: it sits beside the pills and has its own rect.
        for box in allBoxesForButtons() {
            guard let row = box as? ButtonRowBox, row.hitsMenuButton(atCanvasPoint: point),
                  let buttonRowMenuRequested
            else { continue }
            dismissEditMenu()
            let rowID = row.id
            buttonRowMenuRequested(ButtonRowMenuRequest(
                view: self,
                sourceRect: row.menuButtonCanvasRect(),
                alignment: row.alignment,
                addButton: { [weak self] in self?.addButtonToRow(rowID: rowID) },
                setAlignment: { [weak self] alignment in self?.setButtonRowAlignment(rowID: rowID, alignment) },
                deleteRow: { [weak self] in self?.deleteButtonRow(rowID: rowID) }
            ))
            return true
        }

        guard let buttonEditRequested else { return false }

        // A block-row pill.
        for box in allBoxesForButtons() {
            guard let row = box as? ButtonRowBox, let index = row.pillIndex(atCanvasPoint: point),
                  row.buttons.indices.contains(index)
            else { continue }
            dismissEditMenu()
            let caret = row.nodeStart + 1 + index
            setCaret(global: caret)
            let rowID = row.id
            buttonEditRequested(row.buttons[index], true) { [weak self] updated in
                guard let self, let (stack, i) = self.owningStack(ofBlockID: rowID),
                      let liveRow = stack.boxes[i] as? ButtonRowBox else { return }
                self.editing {
                    if updated == nil, liveRow.buttons.count <= 1 {
                        var newBoxes = stack.boxes
                        newBoxes.remove(at: i)
                        stack.boxes = newBoxes
                    } else {
                        liveRow.replaceButton(at: index, with: updated)
                    }
                    self.recomputeSpans()
                    return .unchanged
                }
            }
            return true
        }

        // An inline pill.
        guard let (attachment, position) = inlineButton(atCanvasPoint: point) else { return false }
        dismissEditMenu()
        setCaret(global: position + 1)
        buttonEditRequested(attachment.button, false) { [weak self] updated in
            self?.replaceInlineButton(at: position, with: updated)
        }
        return true
    }

    /// The inline pill under a canvas point, with the global position of its atom.
    func inlineButton(atCanvasPoint point: CGPoint) -> (attachment: ButtonTextAttachment, position: Int)? {
        for region in allLeafRegions() {
            let attr = region.layout.attributedString
            var found: (ButtonTextAttachment, Int)?
            attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length), options: []) { value, range, stop in
                guard let attachment = value as? ButtonTextAttachment,
                      let box = region.layout.attachmentBox(at: range.location)
                else { return }
                let canvasRect = box.offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y)
                if canvasRect.contains(point) {
                    found = (attachment, region.globalStart + range.location)
                    stop.pointee = true
                }
            }
            if let found { return found }
        }
        return nil
    }
}
#endif

