#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit

/// Task C12 — Family 9 (touch interaction and selection). Seven `IDUIKitInteractionCapability`
/// witnesses, ALL new: `setSelectionActive(_:visible:)`, `selectionChanged()`,
/// `id_setNeedsSelectionDisplayUpdate()`, `setGestureRecognizersEnabled(_:)`,
/// `clearGestureRecognizersForced(_:)`, `id_selectWord()`, `selectAll(_:)`. (The two `id_` ones are
/// named after private UIKit selectors, and `#function` would write such a name into the binary as
/// text: package `CLAUDE.md`, "Private UIKit names are not in the binary".) `.detach()` — the eighth
/// member this task's brief lists — stays where it already lived (`IDTextEditorBackend.detach()`),
/// unchanged in shape; this task adds one new, guarded call to `clearGestureRecognizersForced(true)`
/// there (see that method's own doc comment).
///
/// **Scope, disclosed rather than glossed.** `RichTextInputInteractionBackend`'s existing protocol
/// requirements (`installInteractions()`/`removeInteractions()`/`viewportDidChange()`/…, already
/// no-op stubs on `IDTextEditorBackend` since Task C0) have NO members shaped like `selectWord()`/
/// `selectAll(_:)`/`setSelectionActive(_:visible:)` — Telegram's own gesture recognizers (installed
/// by the SHARED, backend-agnostic `DocumentCanvasView` machinery) are what drive touch/selection
/// for BOTH backends today, and nothing in this task's Files list (`IDTextEditorBackend+Interaction.swift`,
/// the canvas thunks, the test file) authorizes widening that protocol to add a canvas→backend call
/// site for these seven. So the seven witnesses below are PRODUCED surface — real, individually
/// guarded, and reachable directly (white-box, from `IDBackendFamily9Tests` once C14 unblocks a
/// live kernel) — not yet CONSUMED from any canvas gesture. This mirrors the exact shape Task C11
/// left `kernelInteraction`'s wiring in for `hostDidResignFirstResponder()`, and the exact shape
/// this task's own `detach()` edit gives `clearGestureRecognizersForced(_:)` a first real caller.
/// The eventual UIKit-interaction-assistant delivery path (once the three canvas thunks this task
/// installs — `interactionAssistant`/`_textInputViewForAddingGestureRecognizers`/
/// `selectionContainerView` — start receiving real private-framework calls) is future, unassigned
/// work; see DIVERGENCES.md entry 13 for the Step-6 conflict-check this task could not run.
///
/// Every witness below follows the SAME guard shape every other kernel-witness call in this package
/// uses (`pasteAvailabilityFromKernel`, `hostDidResignFirstResponder`, …): detached →
/// silently no-op (never trap); attached → `TGRichTextInputDecPerform` + `reportKernelFailure(_:witness:)`
/// on a caught error, matching `IDBackendCallGuardTests`'s blanket "every reachable entry point"
/// rule (Step 8's guard is a boundary rule, not a per-call risk judgment).
///
/// **Task C13 — Family 10 (floating cursor; autoscroll deliberately deferred).** Three
/// `IDUIKitInteractionCapability` witnesses: `beginFloatingCursor(at:)`, `updateFloatingCursor(at:)`,
/// `endFloatingCursor()`. Unlike Family 9's seven above, these are NOT newly-produced surface —
/// they are the pre-existing `RichTextInputInteractionBackend` conformance members `DocumentCanvasView
/// +FloatingCursor.swift`'s three routers (`beginFloatingCursor(at:)`/`updateFloatingCursor(at:)`/
/// `endFloatingCursor()`) already forward `inputBackend.<member>` into unconditionally, for BOTH
/// backends — before this task they were empty no-op stubs on `IDTextEditorBackend`
/// (`IDTextEditorBackend.swift`), so a hold-spacebar gesture on an ID-attached canvas silently did
/// nothing. They are CONSUMED from a real call site today, not merely reachable white-box.
///
/// **Scope, disclosed rather than glossed, mirroring Family 9's own framing.** This task wires the
/// KERNEL side only — informing `IDUIKitInteractionCapability`'s private assistant that the gesture
/// is live — and the SUPPRESSION-latch side (`floatingCursorActive`, consulted by this backend's own
/// `selectedTextRange` setter so a UIKit-driven RANGE push mid-gesture cannot become a selection; see
/// `IDTextEditorBackend.swift`'s `selectedTextRange` and `floatingCursorActive` doc comments). It does
/// NOT wire Telegram's own VISUAL floating-cursor presentation (the gliding shadow / dimmed landing
/// caret / vertical auto-scroll in `DocumentCanvasView+FloatingCursor.swift`'s `legacyBegin`/
/// `legacyUpdate`/`legacyEndFloatingCursor` bodies) — those stay Legacy-backend-only, exactly as
/// Family 9's seven witnesses stayed produced-but-not-consumed for the canvas gesture-recognizer
/// side. Driving the kernel's OWN private assistant chrome (once the canvas thunks Family 9 installs
/// start receiving real private-framework calls) is future, unassigned work, same as Family 9's own
/// deferral.
///
/// **`floatingCursorActive` is written REGARDLESS of whether the kernel call succeeds**, unlike the
/// legacy backend's ordering rule (which the visual presentation's own suppression guard depends on
/// — see `LegacyRichTextInputBackend+FloatingCursor.swift`'s header). This backend's latch has no
/// canvas-side presentation guard reading it mid-forward, so there is no statement-order hazard to
/// preserve; the flag is set (or cleared) unconditionally once `isAttached` is confirmed, after the
/// guarded kernel forward, mirroring `beginFloatingCursor(at:)`/`endFloatingCursor()`'s own order on
/// the legacy side (forward first, flag second) for consistency rather than necessity.
///
/// **Deviation D2** (the brief's own Step 4, confirmed real): the kernel's witness is
/// `updateFloatingCursorAtPoint:animated:`; this backend's own `RichTextInputInteractionBackend`
/// conformance — and UIKit's real `UITextInput` requirement it ultimately answers — has no
/// `animated:` parameter. `updateFloatingCursor(at:)` passes `animated: true`, matching what the
/// private system floating-cursor control receives for its own equivalent gesture. See
/// DIVERGENCES.md entry 13.
@available(iOS 17.0, *)
extension IDTextEditorBackend {

    // MARK: - `IDUIKitInteractionCapability` witnesses (Family 9)

    /// `.setSelectionActive(_:visible:)` — tells the kernel's interaction assistant whether the
    /// SELECTION (not just a caret) is the active editing state, and whether its chrome should be
    /// visible. No call site yet — see this file's own header on scope.
    func setSelectionActive(_ active: Bool, visible: Bool) {
        guard isAttached else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.setSelectionActive(active, visible: visible)
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
    }

    /// `.selectionChanged()` — notifies the kernel's interaction assistant the selection moved, so
    /// it can re-derive its own chrome geometry.
    ///
    /// **Task H1 gave this its first real call site** (the previous "no call site yet" wording is why
    /// this note exists): making the host canvas the private controller's delegate turned
    /// `keyboardInputChangedSelection:` into a delivered callback, and it routes here. The sibling
    /// members below genuinely still have none.
    func notifySelectionChangedToKernel() {
        guard isAttached else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.id_selectionChanged()
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
    }

    /// `.setNeedsSelectionDisplayUpdate()` — a lighter-weight sibling of `selectionChanged()`:
    /// requests a redraw of the assistant's chrome without asserting the SELECTION itself changed
    /// (mirrors `setNeedsDisplay` vs. a genuine model change). No call site yet.
    func id_setNeedsSelectionDisplayUpdate() {
        guard isAttached else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.id_setNeedsSelectionDisplayUpdate()
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
    }

    /// `.setGestureRecognizersEnabled(_:)` — toggles the assistant's OWN gesture recognizers
    /// (distinct from Telegram's, which stay installed regardless — see this file's header). No
    /// call site yet.
    func setGestureRecognizersEnabled(_ enabled: Bool) {
        guard isAttached else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.setGestureRecognizersEnabled(enabled)
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
    }

    /// `.clearGestureRecognizersForced(_:)` — cancels every in-flight assistant gesture
    /// (selection-handle drag, loupe, floating cursor). Called from `IDTextEditorBackend.detach()`
    /// (this task's own edit there), which is its one real call site today —
    /// `test_detachCancelsGesturesBeforeTearingDownPresentation` (`IDBackendFamily9Tests`) pins
    /// that it runs before `host.presentationClient.tearDownPresentation()`.
    func clearGestureRecognizersForced(_ forced: Bool) {
        guard isAttached else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.clearGestureRecognizersForced(forced)
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
    }

    /// `.selectWord()` — asks the kernel's interaction assistant to select the word at the current
    /// caret, mirroring the double-tap word-select gesture Telegram's own recognizers already
    /// drive independently (see this file's header). No call site yet;
    /// `test_selectWordRoutesThroughTheInteractionCapability` (`IDBackendFamily9Tests`) drives it
    /// directly (white-box).
    func id_selectWord() {
        guard isAttached else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.id_selectWord()
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
    }

    /// `.selectAll(_:)` — the ONE witness here that takes UIKit's own standard-edit-action
    /// `sender:` shape (mirrors `UIResponderStandardEditActions.selectAll(_:)`, matching
    /// `+Responder.swift`'s `performCommand(_:sender:)` precedent for threading `sender` through
    /// to a kernel witness). No call site yet — Telegram's own `.selectAll` command routes through
    /// `RichTextInputCommandClient` (Family 7, `+Responder.swift`), not this witness.
    func selectAll(_ sender: Any?) {
        guard isAttached else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.selectAll(sender)
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
    }

    // MARK: - `IDUIKitInteractionCapability` witnesses (Family 10 — floating cursor)

    /// `.beginFloatingCursorAtPoint:` (Swift: `kernelInteraction?.beginFloatingCursor(at:)` — see
    /// this method's own guarded call for the naming correction) — routes the hold-spacebar
    /// gesture's begin into the kernel's interaction assistant, then raises this backend's own
    /// `floatingCursorActive` latch — the SAME store `selectedTextRange`'s setter consults
    /// (`IDTextEditorBackend.swift`) — so a UIKit-driven selection-RANGE push mid-gesture is
    /// dropped, exactly as `LegacyRichTextInputBackend.beginFloatingCursor(at:)` already does for
    /// the legacy side.
    /// `test_beginFloatingCursorMarksTheStateComposing_andSuppressesSelectedTextRangeWrites`
    /// (`IDBackendFamily10Tests`) pins the end-to-end shape through a live kernel;
    /// `IDTextEditorBackendFloatingCursorSuppressionTests` pins the suppression decision alone,
    /// needing no kernel. Silent on a detached backend — an OS-driven gesture entry point, not a
    /// content/selection-mutating member, matching `LegacyRichTextInputBackend+FloatingCursor.swift`'s
    /// own rule for this exact family.
    // ELEVENTH wrong Swift/ObjC name in this plan's prose (both the brief AND this task's own
    // supplement wrote `beginFloatingCursorAtPoint(_:)`): the ObjC selector is
    // `beginFloatingCursorAtPoint:`, but Swift's importer applies its "Omit Needless Words"
    // transform and folds `AtPoint` into the `at:` argument label — confirmed only by a real
    // iOS-simulator compile error (`swift build` cannot see this file at all; see the package
    // CLAUDE.md). The real name is `beginFloatingCursor(at:)`.
    func beginFloatingCursor(at point: CGPoint) {
        guard isAttached else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.beginFloatingCursor(at: point)
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
        setFloatingCursorActive(true)
    }

    /// **DEVIATION D2** — see this file's own header. The kernel's witness carries `animated:`;
    /// UIKit's own `UITextInput` requirement (and this backend's matching
    /// `RichTextInputInteractionBackend` member) does not, so `true` is passed on this backend's
    /// behalf, matching what the private system floating-cursor control passes for itself.
    /// `test_updateFloatingCursorForwardsThePointVerbatim` (`IDBackendFamily10Tests`) pins that the
    /// point reaches the kernel with no transformation.
    // TWELFTH wrong Swift/ObjC name in this plan's prose (again both the brief and this task's own
    // supplement wrote `updateFloatingCursorAtPoint(_:animated:)`): the ObjC selector is
    // `updateFloatingCursorAtPoint:animated:`, but Swift's importer folds `AtPoint` into `at:`,
    // leaving `updateFloatingCursor(at:animated:)` — confirmed only by a real iOS-simulator
    // compile error (`'updateFloatingCursorAtPoint(_:animated:)' has been renamed to
    // 'updateFloatingCursor(at:animated:)'`).
    func updateFloatingCursor(at point: CGPoint) {
        guard isAttached else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.updateFloatingCursor(at: point, animated: true)
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
    }

    /// `.endFloatingCursor()` — routes the gesture's end into the kernel, then clears the
    /// suppression latch (the reverse of `beginFloatingCursor(at:)`'s set), so the very next
    /// UIKit-driven `selectedTextRange` write is honoured again.
    /// `test_endFloatingCursorLeavesACollapsedCaret` (`IDBackendFamily10Tests`) pins that the caret
    /// stays collapsed at the value the (suppressed) gesture left it at.
    func endFloatingCursor() {
        guard isAttached else { return }
        var error: NSError?
        _ = TGRichTextInputDecPerform({
            self.kernelInteraction?.endFloatingCursor()
        }, &error)
        if let error { reportKernelFailure(error, witness: #function) }
        setFloatingCursorActive(false)
    }
}
#endif
