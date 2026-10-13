#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Pure, directly-callable selection logic, factored OUT of the gesture/menu callbacks so it can be
/// unit-tested without synthesizing touch events. The recognizers (DocumentCanvasView+Interaction) and
/// the menu actions (DocumentCanvasView+EditMenu) are thin wrappers over these.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// What a single tap at `resolved` should do. `.toggleMenu` — the tap landed on the existing collapsed
    /// caret OR inside the active selection → toggle the edit menu, KEEPING the current caret/selection (the
    /// gesture handler presents or dismisses depending on whether the menu is already showing). `.setCaret`
    /// — the tap landed elsewhere → place the caret there (collapsing any selection) and dismiss the menu.
    enum TapOutcome: Equatable { case toggleMenu, setCaret(Int) }

    func tapOutcome(forResolvedPosition resolved: Int, point: CGPoint) -> TapOutcome {
        if selFrom != selTo {
            // "Inside" is VISUAL: the tap must land ON the rendered selection (its glyph-hugging rects), not
            // merely resolve to an offset within [selFrom, selTo]. A tap in the empty area beside the selection
            // resolves (via closestGlobalPosition) to a boundary offset INSIDE the range but is visually OUTSIDE
            // — it must collapse the selection + place the caret, not toggle/keep the menu. The offset-only test
            // kept the selection on any such tap (the composer "tap-to-deselect doesn't work" bug).
            let onSelection = selectionRects(globalFrom: selFrom, globalTo: selTo).contains { $0.contains(point) }
            return onSelection ? .toggleMenu : .setCaret(resolved)
        }
        return resolved == head ? .toggleMenu : .setCaret(resolved)
    }

    /// The outcome of a toggle-tap on the caret/selection.
    enum MenuToggleAction: Equatable { case present, dismiss }

    /// Window (seconds) within which a just-fired `willDismiss` is attributed to the current tap, so the
    /// handler doesn't re-present the menu the system just closed. A generous margin over the brief gap
    /// between the system's tap-down auto-dismiss and our tap-up handler.
    static let menuToggleSuppressWindow: TimeInterval = 0.75

    /// A tap on the caret/selection toggles the edit menu: DISMISS when the menu is showing OR was just
    /// auto-dismissed by this same tap; otherwise PRESENT. Pure (unit-tested) — the `justDismissed` race
    /// fix is what stops the close-then-reopen flicker.
    ///
    /// `wasFirstResponder` gates the very FIRST (focusing) tap: a tap that brings the field into first-
    /// responder must only place the caret, never open the menu — otherwise an empty composer field (whose
    /// caret defaults to position 0, where a focusing tap also resolves → `tapOutcome` `.toggleMenu`) pops the
    /// edit menu on the first tap. A second tap on the caret of the now-focused field still toggles it.
    func menuToggleAction(menuVisible: Bool, justDismissed: Bool, wasFirstResponder: Bool) -> MenuToggleAction {
        guard wasFirstResponder else { return .dismiss }   // a focusing tap places the caret only; never opens the menu
        return (menuVisible || justDismissed) ? .dismiss : .present
    }

    /// Whether a finished loupe long-press should (re)present the edit menu on `.ended`. A quick tap near the
    /// caret is caught as a loupe (0.05s near-cursor delay), so the loupe must match the tap's toggle semantics:
    /// a STATIONARY press (`caretMoved == false`) on an ALREADY-OPEN menu (`menuWasVisibleAtBegan`) is a
    /// tap-like toggle-OFF — suppress the re-present so the menu doesn't flicker (disappear-then-reappear). A
    /// press that began with no menu, or an actual cursor DRAG, presents normally (long-press → menu / menu at
    /// the new caret). Pure so it's unit-tested without synthesizing a gesture. (memory: menu-toggle-is-visual)
    func loupeShouldPresentMenuOnEnd(menuWasVisibleAtBegan: Bool, caretMoved: Bool) -> Bool {
        return !menuWasVisibleAtBegan || caretMoved
    }

    /// Which selection endpoint a drag should move, by global-offset proximity. nil when collapsed.
    enum SelectionEndpoint: Equatable { case anchor, head }

    func nearerSelectionEndpoint(toGlobal pos: Int) -> SelectionEndpoint? {
        guard selFrom != selTo else { return nil }
        return abs(pos - anchor) <= abs(pos - head) ? .anchor : .head
    }

    /// Captures the offset between the dragged endpoint's caret and the initial touch, so the drag keeps that
    /// starting offset (the handle's knob is drawn offset from the text line — without this the endpoint snaps
    /// to whatever line sits under the finger).
    func captureSelectionDragOffset(endpoint: SelectionEndpoint, touch: CGPoint) {
        let pos = (endpoint == .anchor) ? anchor : head
        let caret = caretRect(atGlobal: pos)
        // Anchor on the caret's CENTER: at grab time `touch + offset == caret.center`, so the first map lands
        // exactly on the grabbed endpoint (no jump), and the constant offset is preserved for the rest of the drag.
        selectionDragGrabOffset = CGSize(width: caret.midX - touch.x, height: caret.midY - touch.y)
    }

    /// The global position the dragged endpoint should move to for a touch at `point`, applying the offset
    /// captured at grab time.
    func selectionDragPosition(forTouch point: CGPoint) -> Int {
        closestGlobalPosition(to: CGPoint(x: point.x + selectionDragGrabOffset.width,
                                          y: point.y + selectionDragGrabOffset.height))
    }

    /// Select the word enclosing `pos` (Select menu item / double tap). No-op at a structural gap.
    func selectWord(at pos: Int) {
        guard let t = tokenizer as? DocumentTokenizer, let r = t.wordRange(at: pos) else { return }
        applySelection(from: r.from, to: r.to)
    }

    /// Select the paragraph/region enclosing `pos` (triple tap). No-op at a structural gap.
    func selectParagraph(at pos: Int) {
        guard let t = tokenizer as? DocumentTokenizer, let r = t.paragraphRange(at: pos) else { return }
        applySelection(from: r.from, to: r.to)
    }

    /// Select the whole document, bounded to renderable start/end (so the trailing caret is renderable).
    func selectAllText() {
        // TASK 44: was `(beginningOfDocument as? DocumentTextPosition)?.offset`. Identical downcast,
        // identical `nil` on failure — performed inside the backend now. Both fallbacks are kept
        // VERBATIM and they differ from each other on purpose (`0` vs `documentSize`); neither is
        // reachable, because both backend members return a `LegacyTextPosition` on every path.
        let from = LegacyTextIdentity.globalOffset(of: beginningOfDocument) ?? 0
        let to = LegacyTextIdentity.globalOffset(of: endOfDocument) ?? documentSize
        // If the RENDERABLE bounds collapse to a single caret, the whole document is one degenerate cell — a lone
        // 1×1 EMPTY table (its single empty cell is the only renderable position). Select the full STRUCTURAL
        // range instead, so Select-All is a real range Backspace can act on (→ the whole-document reset removes
        // the table). Without this, ⌘A yields a caret and Backspace just does an in-cell delete, leaving the table.
        if from == to, documentSize > 0, boxes.contains(where: { $0 is TableBlockBox }) {
            applySelection(from: 0, to: documentSize)
            return
        }
        applySelection(from: from, to: to)
    }

    func applySelection(from: Int, to: Int) {
        finalizeMarkedText()     // Select-All / word / paragraph is a deliberate selection change: commit a
                                 // composition / dismiss a prediction first, else insertText would replace the
                                 // stale marked range instead of the new selection. clampGlobal below re-bounds.
        clearImageSelection()    // word/paragraph/Select-All deselects an atom-selected image
        // TASK 26: the UNSUPPRESSED selection bracket (`notifyingSelectionChangeIgnoringCoalescing`)
        // — this site never consulted the coalescing flag, so routing it through the suppressed
        // funnel bracket would be a behavior change.
        // TASK 39: `applyCaretOutcome` (`+Editing.swift`) inside the UNCHANGED bracket — the Task-37
        // population-C shape — and NOT `setSelection`. This bracket opens no transaction and sets no
        // suppression flag, so both of `setSelection`'s escapes fall through and it takes the full
        // publish path: `refreshSelectionUI()` and `onSelectionChange?()` are already delivered by the
        // two statements below, so publishing here doubles BOTH. Axis 4 of the divergence audit bites
        // hardest here: this bracket exists *because* this site never consulted the coalescing flag, and
        // `setSelection` does consult it.
        // **`.range`, NOT `.caret`** — Select-All / double-tap word / triple-tap paragraph is the
        // canvas's canonical RANGE producer, and it is the best-pinned site in Task 39's population:
        // `.caret(at: clampGlobal(to))` here reddens **37 tests across 11 suites**, measured on the full
        // `Scripts/iostest.sh`. Both figures from the same log —
        // `grep -cE 'Test Case .* failed' <log>` and that piped through
        // `sed -E 's/.*\[RichTextEditorUIKitTests\.([A-Za-z]+) .*/\1/' | sort -u | wc -l` — because
        // this comment said **10** until fix round 1 and a figure labelled "measured, not cited" is the
        // last one a reader re-checks (Rule 14). The eleventh is `SpellCheckTapTests`, dropped when the
        // list was typed by hand: `BlockQuoteEditTests`, `CanvasImageEditTests`,
        // `CanvasPullQuoteEditTests`, `CanvasSelectAllTableDeleteTests`, `CanvasSelectionMenuTests`,
        // `CommandRouterTests`, `ComposerBlockQuoteSelectionTests`, `MarkedTextTests`,
        // `SelectionInteractionTests`, `SpellCheckTapTests`, `TelegramCommandInputClientTests`.
        inputBackend.notifyingSelectionChangeIgnoringCoalescing {
            applyCaretOutcome(.range(clampGlobal(from), clampGlobal(to)))
        }
        setNeedsDisplay(); refreshSelectionUI()
        // A gesture-driven RANGE selection (double-tap word / triple-tap paragraph / Select All) is a
        // caret-moving op and MUST notify the host — exactly as setCaret does. The chat composer tracks the
        // editor selection through onSelectionChange; without it a word selection never reaches the panel's
        // interface state, and the next state re-apply (setInputContent) collapses the visible selection back
        // to the stale caret (the double-tap "flash then deselect" bug).
        onSelectionChange?()
    }
}
#endif
