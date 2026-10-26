#if canImport(UIKit)
import UIKit
import RichTextEditorCore

// Prediction / correction traits. The canvas conforms to UITextInputTraits transitively
// (UITextInput: UIKeyInput: UITextInputTraits); these are @objc-optional members we override.
// Autocorrect/spell-check are ON because system inline predictions reportedly require them
// (and they're standard for a text editor). inlinePredictionType opts in to the iOS 17+ feature.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    var autocorrectionType: UITextAutocorrectionType {
        get { caretIsInCodeRegion ? .no : .yes } set { }
    }
    var autocapitalizationType: UITextAutocapitalizationType {
        // `.sentences` is UIKit's default for an unimplemented trait, so this changes nothing outside a
        // code block — inside one, iOS would capitalize `let` for you.
        get { caretIsInCodeRegion ? .none : .sentences } set { }
    }
    var spellCheckingType: UITextSpellCheckingType {
        // The own-drawn underline pass already skips code (`spellCheckableRef`); this turns off the OS's
        // own checking there too, which is what feeds the keyboard's correction candidates.
        get { caretIsInCodeRegion ? .no : (isSpellCheckingEnabled ? .yes : .no) } set { }
    }
}

// `UITextInlinePredictionType` is iOS 17+; below it the trait simply isn't offered (no inline predictions).
@available(iOS 17.0, *)
extension DocumentCanvasView {
    var inlinePredictionType: UITextInlinePredictionType {
        get { caretIsInCodeRegion ? .no : .yes } set { }
    }
}

@available(iOS 13.0, *)
extension DocumentCanvasView {
    // TASK 29 (Family 6): one-line router. The `(from, to)` → `LegacyTextRange` projection below
    // moved to `LegacyRichTextInputBackend+MarkedText.swift` VERBATIM, and it still reads THIS canvas's
    // `markedRange` — the marked-state authority until Task 41 — so the value is unchanged.
    var markedTextRange: UITextRange? { inputBackend.markedTextRange }

    // TASK 29 (Family 6): one-line router per accessor. The get-nil / set-no-op pair (we draw our own
    // underline decoration; no system styling) moved to the backend UNCHANGED — the backend's own
    // member is `get { nil } set { }` too, NOT the stored property it used to be, because routing onto
    // storage would make the getter start returning what was last set.
    // `RouterWitnessBodyTests` cannot express a `{ get set }` witness (see its SCOPE LIMIT note, which
    // names this member); `MarkedTextRouterTests.test_markedTextStyleGetterIsNilAndSetterIsANoOp` and
    // its spy sibling are the cover.
    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get { inputBackend.markedTextStyle }
        set { inputBackend.markedTextStyle = newValue }
    }

    /// True iff `pos` is inside a TOP-LEVEL body paragraph (a `BlockBox`) — not a table cell, image
    /// caption, or structural boundary. v1 composes only here (cells/captions are a follow-up).
    func isBodyParagraphPosition(_ pos: Int) -> Bool {
        // Exclude container interiors: a caret inside a table cell OR a block quote is not a TOP-LEVEL body
        // paragraph. `box(containingGlobal:)` has no degenerate-safe resolution there and would mis-resolve a
        // quote-interior position to the FOLLOWING top-level BlockBox and wrongly report `true` — letting IME
        // marked text compose in a quote (v1 composes only in top-level body paragraphs).
        guard !isInsideTable(clampGlobal(pos)), !isInsideBlockQuote(clampGlobal(pos)) else { return false }
        if let (box, _) = box(containingGlobal: clampGlobal(pos)), box is BlockBox { return true }
        return false
    }

    // TASK 29 (Family 6): one-line router. The body below moved to
    // `legacySetMarkedText(_:selectedRange:)` and the backend forwards straight back to it
    // (`LegacyRichTextInputBackend+MarkedText.swift`) — a PLAIN D24 forward with no bracket of its
    // own, because the body emits its own TWO brackets (a text bracket, then a SEPARATE selection one).
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        inputBackend.setMarkedText(markedText, selectedRange: selectedRange)
    }

    /// Was `DocumentCanvasView.setMarkedText(_:selectedRange:)`, renamed by TASK 29 when the witness
    /// became a router; the body is untouched. `LegacyRichTextInputBackend.setMarkedText(_:selectedRange:)`
    /// forwards here, and `legacyApplyMutation`'s `.setMarkedText` case dispatches here directly (never
    /// to the witness — see that method's ⚠️ RECURSION HAZARD note).
    ///
    /// **Bracket ownership lives HERE, and that is why the backend's forward is bare.** This body emits
    /// a `notifyingContentChange` text bracket for the provisional edit and then a SEPARATE, unsuppressed
    /// `notifyingSelectionChangeIgnoringCoalescing` bracket for the caret placement, plus the
    /// `notifyContentSizeChanged()` / `onSelectionChange?()` tail — six recorded events for one begin,
    /// pinned by exact equality in
    /// `MarkedTextTraceCharacterizationTests.test_compositionBeginUpdateCommit_traceAndRevisions` and
    /// `DelegateTraceCharacterizationTests.test_setMarkedText_emitsATextBracketThenASeparateSelectionBracket`.
    /// A bracket added at the backend would double them.
    func legacySetMarkedText(_ markedText: String?, selectedRange: NSRange) {
        let text = markedText ?? ""
        // The range being replaced: an existing composition, else the live selection.
        let lo = markedRange?.from ?? selFrom
        let hi = markedRange?.to ?? selTo

        // Body-paragraph guard: if we can't compose here, commit any pending composition and fall back
        // to a plain insert so we never strand provisional text in an unsupported region.
        guard isBodyParagraphPosition(lo) else {
            commitMarkedText()
            // TASK 29, DELIBERATE: this stays on the WITNESS `insertText(_:)`, which is a router into
            // the backend since Task 27b — so this branch calls out to the backend and straight back
            // into `legacyInsertText`. NOT repointed at `legacyInsertText`: the "dispatch to the LEGACY
            // body, never the witness of the same name" rule belongs to `legacyApplyMutation`
            // specifically (its own doc comment says so), and Task 27b left the two other
            // canvas-internal callers of the witness — `DocumentCanvasView.swift`'s hardware-Return
            // path and `+Formula.swift`'s LaTeX insert — routing through the backend for the same
            // reason. Repointing would be an unmandated behaviour change. It IS observable: on this
            // branch a spy backend records `setMarkedText` AND `insertText`.
            if !text.isEmpty { insertText(text) }
            return
        }

        // Capture the composition-start snapshot on the FIRST setMarkedText of a run.
        // TASK 41: the snapshot lives on the BACKEND now, and the two values that used to be written
        // here as `compositionUndoSnapshot` + `compositionAnchorHead` travel as ONE
        // `RichTextCompositionSnapshot`, through the RAW non-publishing setter — this body emits its
        // own two delegate brackets (see the doc comment above) and must not gain a third emission.
        if markedRange == nil {
            inputBackend.setCompositionSnapshot(
                RichTextCompositionSnapshot(blocks: currentBlocks(), anchor: anchor, head: head))
        }

        // Provisional text edit: in place, NO undo snapshot (applyReplaceOutcome mutates + recomputes spans).
        inputBackend.notifyingContentChange {   // TASK 26: text-only half of setMarkedText's two brackets
            // This caret is NOT read back (the unconditional selection bracket ~20 lines
            // below overwrites both endpoints from `lo + selectedRange.location`), but it IS delivered to
            // the host: `textDidChange` fires with it live. Reproduce it. Pinned by
            // `MarkedTextTraceCharacterizationTests.test_compositionBeginUpdateCommit_traceAndRevisions`
            // and `CaretLandingCharacterizationTests
            // .test_setMarkedTextProvisionalEditLandsTheCaretAtTheEndOfTheProvisionalText`.
            applyCaretOutcome(applyReplaceOutcome(globalFrom: lo, globalTo: hi, text: text))
            bumpDocumentRevision()   // applyReplaceOutcome here is OUTSIDE `editing { }`
        }

        let newLen = (text as NSString).length
        if newLen == 0 {
            inputBackend.setCompositionMarkedRange(nil, isPrediction: false)
            inputBackend.setCompositionSnapshot(nil)   // cancelled — discard snapshot
        } else {
            // A system inline PREDICTION arrives with the caret at the START (sel {0,0}) — the ghost
            // trails the caret; CJK/IME composition keeps the caret at the END. (See markedTextIsPrediction.)
            inputBackend.setCompositionMarkedRange(
                NSRange(location: lo, length: newLen),
                isPrediction: selectedRange.location == 0 && selectedRange.length == 0)
        }

        refreshPredictionStyling()   // grey ghost for a prediction; clears it otherwise

        // Place the selection within the marked text (selectedRange is marked-text-relative).
        // TASK 26: the SEPARATE, unsuppressed selection bracket — this site never consulted the
        // coalescing flag (see `+Notifications.swift`).
        inputBackend.notifyingSelectionChangeIgnoringCoalescing {
            let selStart = clampGlobal(lo + selectedRange.location)
            // TASK 37, POPULATION C — applied through `applyCaretOutcome` (`+Editing.swift`), the raw
            // NON-PUBLISHING endpoint pair, and **NOT `setSelection(_:reason: .keyboard)`**. The
            // enclosing bracket opens no transaction and sets no suppression flag, so a `setSelection`
            // here takes the FULL publish path and lands a `canvasSelectionChanged` BETWEEN this
            // bracket's WILL and DID: measured at 7 events where the golden trace pins 6 (recorded at
            // `applyCaretOutcome`). `.range` because a composition selection is a RANGE whenever
            // `selectedRange.length > 0`, and it must not be normalized.
            applyCaretOutcome(.range(selStart, clampGlobal(selStart + selectedRange.length)))
        }

        notifyContentSizeChanged(); setNeedsDisplay(); refreshSelectionUI()
        onSelectionChange?()   // a growing composition advances the caret — scroll it into view (CJK/IME typing)
    }

    // TASK 29 (Family 6): one-line router. The body below moved to `legacyUnmarkText()` and the backend
    // forwards straight back to it — a PLAIN D24 forward. `commitMarkedText()` emits NO delegate or
    // canvas-hook event at all (pinned by
    // `MarkedTextTraceCharacterizationTests.test_compositionBeginUpdateCommit_traceAndRevisions`'s
    // `XCTAssertEqual(recorder.kinds, [])`), so a bracket at the backend would be the ONLY bracket —
    // a fabricated one, not a doubled one.
    func unmarkText() { inputBackend.unmarkText() }

    /// Was `DocumentCanvasView.unmarkText()`, renamed by TASK 29 when the witness became a router; the
    /// body is untouched. `LegacyRichTextInputBackend.unmarkText()` forwards here, and
    /// `legacyApplyMutation`'s `.unmarkText` case dispatches here directly (never to the witness — see
    /// that method's ⚠️ RECURSION HAZARD note).
    func legacyUnmarkText() {
        commitMarkedText()
    }

    /// Commits the active composition: registers ONE undo from the start snapshot and clears marked
    /// state. Does NOT mutate text (provisional chars stay committed). No-op when not composing.
    /// Keyboard-driven accept/confirm paths (unmarkText, the confirming-keystroke guard) call this; our
    /// own gesture/focus/structural interruptions call `finalizeMarkedText()` instead, which DISMISSES a
    /// prediction rather than committing it.
    func commitMarkedText() {
        guard markedRange != nil else { return }
        breakUndoCoalescing()   // a composition is its own undo step; end any surrounding Latin typing run
        // TASK 41: one snapshot value off the backend where there were two canvas properties. The
        // pair was written and cleared together at all four of its former write sites, so reading them
        // as one is behaviour-identical — and it removes the state in which one is set and the other
        // is not.
        let snap = inputBackend.compositionSnapshot
        // This `?? (anchor, head)` fallback is a READ-BACK of whatever caret the caller's
        // `applyReplaceOutcome` just left — see the marked-commit branch in `+UITextInput.swift`.
        let (a, h) = snap.map { ($0.anchor, $0.head) } ?? (anchor, head)
        inputBackend.setCompositionMarkedRange(nil, isPrediction: false)
        inputBackend.setCompositionSnapshot(nil)
        refreshPredictionStyling()   // clear any grey ghost colour
        if let snap { registerUndo(snapshot: snap.blocks, anchor: a, head: h) }
        setNeedsDisplay()
    }

    /// Removes an active PREDICTION's provisional ghost text. The ghost is keyboard-owned, never user
    /// content, so this registers NO undo. No-op unless a prediction is currently showing.
    func dismissPrediction() {
        guard let m = markedRange, markedTextIsPrediction else { return }
        inputBackend.notifyingContentChange {   // TASK 26: dismissPrediction is a text-only bracket
            // This caret is reproduced with NO app-visible symptom, deliberately: a live prediction
            // always already parks the caret at `m.from` (`markedTextIsPrediction` is defined as
            // `selectedRange == {0,0}`), so the write is dead in every reachable state. Only arm 2 of
            // `CaretLandingCharacterizationTests.test_dismissPredictionLandsTheCaretAtTheGhostStart` —
            // which seeds the caret through the silent test seam — can see it at all. Kept because a
            // dead write reproduced is a behaviour preserved; removing it is a separate decision.
            applyCaretOutcome(applyReplaceOutcome(globalFrom: m.from, globalTo: m.to, text: ""))   // remove ghost; caret → m.from
            bumpDocumentRevision()   // applyReplaceOutcome here is OUTSIDE `editing { }`
        }
        inputBackend.setCompositionMarkedRange(nil, isPrediction: false)
        inputBackend.setCompositionSnapshot(nil)
        refreshPredictionStyling()   // clear any grey ghost colour
        setNeedsDisplay()
    }

    /// Finalizes any active marked text before a NON-keyboard-driven interruption (gesture caret-move,
    /// focus loss, structural edit, undo/redo, full reload): a COMPOSITION is committed (kept, one undo
    /// step); a PREDICTION ghost is DISMISSED (removed). Committing a prediction here would desync the
    /// keyboard's shadow document and duplicate the word on its accept-`replace` (the on-device bug).
    /// Returns the dismissed prediction's range (so a caller setting a caret from a pre-dismiss coordinate
    /// can adjust for the removed length); nil for a committed composition / no marked text.
    @discardableResult
    func finalizeMarkedText() -> (from: Int, to: Int)? {
        guard markedRange != nil else { return nil }
        if markedTextIsPrediction {
            let removed = markedRange
            dismissPrediction()
            return removed
        }
        commitMarkedText()
        return nil
    }

    /// Rects (canvas coords) to underline as composing/marked text — the marked range's selection
    /// rects. Empty when not composing. A PREDICTION is rendered as grey ghost text (no underline —
    /// see `refreshPredictionStyling`), so only CJK/IME composition gets the underline. Render-only.
    func markedTextDecorations() -> [CGRect] {
        guard let m = markedRange, m.to > m.from, !markedTextIsPrediction else { return [] }
        return selectionRects(globalFrom: m.from, globalTo: m.to)
    }

    /// Applies (or clears) the grey ghost colour for the active inline prediction as a DISPLAY-ONLY
    /// rendering attribute on the owning leaf's layout — so the predicted continuation looks like the
    /// native gray ghost text and nothing leaks into the model. Cleared automatically when the
    /// prediction moves, is dismissed, or commits. Call after any marked-range change.
    func refreshPredictionStyling() {
        ghostStyledLayout?.setGhostForeground(nil, start: 0, end: 0)   // clear the previously styled leaf
        ghostStyledLayout = nil
        guard let m = markedRange, markedTextIsPrediction,
              let (region, _) = leafRegion(containingGlobal: m.from) else { return }
        region.layout.setGhostForeground(self.mapper.theme.placeholder,
                                         start: m.from - region.globalStart,
                                         end: m.to - region.globalStart)
        ghostStyledLayout = region.layout
    }

    /// Draws a 1pt underline under the marked text (IME convention). Composed into the on-top
    /// `selectionHighlight` overlay's `draw(_:)`.
    func drawMarkedTextUnderline(in ctx: CGContext) {
        let rects = markedTextDecorations()
        guard !rects.isEmpty else { return }
        mapper.theme.markedTextUnderline.setFill()
        for r in rects { ctx.fill(CGRect(x: r.minX, y: r.maxY - 1, width: r.width, height: 1)) }
    }
}
#endif
