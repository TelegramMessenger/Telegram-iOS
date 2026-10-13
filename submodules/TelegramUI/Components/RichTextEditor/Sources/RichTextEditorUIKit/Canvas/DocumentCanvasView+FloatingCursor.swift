#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The iOS hold-spacebar-to-move-cursor (keyboard-as-trackpad) gesture. The OS dispatches these optional
/// `UITextInput` methods to the first responder. The editor own-draws everything (no
/// `UITextSelectionDisplayInteraction`), so we render the floating cursor ourselves: a bright gliding
/// **shadow** (`transientCaretView`) follows the finger continuously, while the steady `CaretView` becomes a
/// dimmed **landing** indicator at the snapped position (see `updateCaretView`).
///
/// Two runtime-verified facts shape this implementation (both contradict the original spec's assumptions):
///  1. The `point` is an ABSOLUTE canvas (content) coordinate that already tracks the cursor across the whole
///     document — NOT a relative delta. So we feed it straight to `closestGlobalPosition`.
///  2. During the gesture iOS ALSO pushes selection RANGES (anchored at the gesture's start position) through
///     the `selectedTextRange` setter; applying them turns the cursor MOVE into a text SELECTION. The setter
///     ignores those writes while the gesture is live — the handlers here own the caret.
///
/// **TASK 33 (Family 10) — the three UIKit entry points are now ROUTERS.** `beginFloatingCursor(at:)`,
/// `updateFloatingCursor(at:)` and `endFloatingCursor()` forward one line into the backend, which calls
/// the `legacy…`-prefixed bodies below (their former selves, moved verbatim). Two consequences a reader
/// of this file needs:
///
///   * **TASK 42 COLLAPSED THE TWO STORES.** Task 33 left this class with its own `floatingCursorActive`
///     (the PRESENTATION flag: the dimmed landing caret in `updateCaretView()`, `floatingAutoScrollTick`'s
///     guard) written in lockstep with the backend's (the SUPPRESSION flag the `selectedTextRange` setter
///     consults). There is now ONE store, on the backend; this class's `floatingCursorActive`,
///     `floatingCursorPoint` and `floatingScrollVelocity` are get-only projections of it, and the writes
///     in the bodies below go through the three contract doors
///     (`setFloatingCursorActive(_:)`/`setFloatingCursorPoint(_:)`/`setFloatingScrollVelocity(_:)`).
///     `floatingScrollLink` is the one that did NOT move: a `CADisplayLink` retains its target and
///     `willMove(toWindow:)` must keep invalidating it (Task 6's retain cycle), so it stays canvas
///     storage and `stopFloatingAutoScroll()` keeps writing BOTH halves of "no link ⇒ no velocity".
///   * **`cancelFloatingCursor()` below now clears THE flag** — through the door, not by reaching into a
///     concrete class — because there is only one to clear. Task 33 argued a canvas body must not write
///     backend state; what changed is that the write is a CONTRACT call now, exactly like this file's
///     `inputBackend.notifyingSelectionChangeIgnoringCoalescing` and the canvas's other door calls. The
///     backend members that reach this method keep their own clears (redundant, deliberately — see that
///     file's header for both reasons).
///   * **Two of the door calls carry a statement-ORDER requirement**, disclosed at each site: the flag
///     must be set BEFORE `legacyBeginFloatingCursor`'s `updateCaretView()` and cleared BEFORE
///     `legacyEndFloatingCursor`'s, or that call paints the wrong caret.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// TASK 33 — the routed witness. UIKit dispatches this to the first responder when the hold-spacebar
    /// gesture begins; the body it used to run is `legacyBeginFloatingCursor(at:)` directly below.
    func beginFloatingCursor(at point: CGPoint) {
        inputBackend.beginFloatingCursor(at: point)
    }

    /// TASK 33 — `beginFloatingCursor(at:)`'s pre-seam body, VERBATIM (D24 clause (a): a renamed witness
    /// body). It brackets and publishes on its own behalf — `notifyingSelectionChangeIgnoringCoalescing`
    /// for the collapse below — so the backend member that calls it adds no bracket of its own.
    func legacyBeginFloatingCursor(at point: CGPoint) {
        guard !floatingCursorActive else { return }
        _ = finalizeMarkedText()
        clearStructuralSelections()
        dismissEditMenuForSelectionOrTextChange()
        // Collapse a ranged selection to its head (the caret we lift off from), bracketing the change.
        if anchor != head {
            // TASK 26: unsuppressed — the collapse brackets unconditionally, exactly as before.
            // TASK 37, POPULATION C: `applyCaretOutcome` (`+Editing.swift`) — the raw, NON-PUBLISHING
            // pair — and NOT `setSelection(_:reason: .floatingCursor)`; this bracket opens no
            // transaction and sets no suppression flag, so a publishing write here reports to the host
            // mid-gesture. Measured at `applyCaretOutcome`. **It writes BOTH endpoints where the
            // forwarder line wrote only `anchor`, and that is a no-op by construction**: the guard
            // above admits only `anchor != head`, so `head` is already the value being claimed, and
            // `setCanonicalHead` neither publishes nor observes (deviation D6 — the re-wrapped
            // `.downstream` affinity is the only value this backend ever emits).
            inputBackend.notifyingSelectionChangeIgnoringCoalescing { applyCaretOutcome(.caret(at: head)) }
        }
        // TASK 42, DOOR 1 — the flag is the BACKEND's store now; this line used to write a canvas field.
        // **It must stay ABOVE `updateCaretView()`**: that call reads the flag to decide between the
        // dimmed landing caret and the steady one, so a write below it paints the wrong caret.
        inputBackend.setFloatingCursorActive(true)
        inputBackend.setFloatingCursorPoint(point)   // the begin point is in canvas coords, at the current caret
        updateCaretView()                  // floatingCursorActive == true → dimmed landing caret at `head`
        transientCaretView.accentColor = caretView.accentColor
        if let placement = caretHostPlacement(forGlobal: head) {
            hostOverlay(transientCaretView, at: placement)
        }
        transientCaretView.show(animated: true)
    }

    /// TASK 33 — the routed witness. **DEVIATION D2:** UIKit's real requirement has no `animated:`
    /// parameter (the plan's Interfaces block spells it `updateFloatingCursor(at:animated:)`); the
    /// witness and the backend member both carry UIKit's spelling, pinned at compile time by
    /// `FloatingCursorRouterTests.test_updateFloatingCursorHasNoAnimatedParameter`.
    func updateFloatingCursor(at point: CGPoint) {
        inputBackend.updateFloatingCursor(at: point)
    }

    /// TASK 33 — `updateFloatingCursor(at:)`'s pre-seam body, VERBATIM. Its per-sample bracket lives one
    /// level down, in `moveFloatingCaret(toGlobal:shadowX:)`.
    func legacyUpdateFloatingCursor(at point: CGPoint) {
        guard floatingCursorActive else { return }
        // `point` is an absolute canvas (content) coordinate tracking the floating cursor. Use it DIRECTLY
        // (no relative-delta, no viewport clamp): the underlying caret snaps to the nearest grapheme
        // position; the shadow glides continuously under the finger.
        inputBackend.setFloatingCursorPoint(point)
        resolveFloatingCaret()
        // Auto-scroll when the floating cursor nears the viewport's vertical edge.
        let offsetY = (superview as? UIScrollView)?.contentOffset.y ?? 0
        updateFloatingAutoScroll(viewportY: point.y - offsetY)
    }

    /// TASK 33 — the routed witness.
    func endFloatingCursor() {
        inputBackend.endFloatingCursor()
    }

    /// TASK 33 — `endFloatingCursor()`'s pre-seam body, VERBATIM. It publishes on its own behalf (the
    /// trailing `onSelectionChange?()`), so the backend member that calls it adds no publication.
    func legacyEndFloatingCursor() {
        guard floatingCursorActive else { return }
        stopFloatingAutoScroll()
        // TASK 42, DOOR 1 — same store, same ordering requirement as `legacyBeginFloatingCursor` in
        // reverse: `updateCaretView()` two lines down reads the flag to restore the steady caret.
        inputBackend.setFloatingCursorActive(false)
        transientCaretView.hide(animated: true)
        updateCaretView()        // floatingCursorActive == false → steady caret reappears (full alpha + blink) at `head`
        onSelectionChange?()     // host resumes scroll-follow / onChange
    }

    /// Snaps the underlying caret to the grapheme position nearest the current floating point, and glides
    /// the shadow continuously under the finger.
    func resolveFloatingCaret() {
        let pos = closestGlobalPosition(to: floatingCursorPoint)
        moveFloatingCaret(toGlobal: pos, shadowX: floatingCursorPoint.x)
    }

    /// The lightweight per-update caret move: bracket the input delegate (mandatory invariant), update the
    /// selection, reposition the dimmed landing caret (`updateCaretView`), and position the bright shadow.
    /// Deliberately does NOT call `scrollCaretIntoViewIfNeeded` / `onSelectionChange` / `refreshSelectionUI`
    /// — the gesture owns scrolling (non-animated, via the auto-scroll driver). `setNeedsDisplay()` suffices:
    /// the selection is collapsed for the gesture's duration (begin collapses it), so there are no handles or
    /// selection wash to refresh — only the highlight repaint.
    ///
    /// `shadowX` (canvas coords) overrides the shadow's horizontal position so it glides continuously with
    /// the finger instead of snapping to the caret rect; the snapped caret rect still supplies the line's
    /// vertical extent + host (so the shadow stays on the right line / rides table-cell scroll). When
    /// `shadowX` is nil the shadow uses the snapped rect.
    func moveFloatingCaret(toGlobal pos: Int, shadowX: CGFloat? = nil) {
        let target = clampGlobal(pos)
        // TASK 26 — the documented asymmetry, a selection bracket that fires even while a coalesced
        // drag is suppressing the three funnels. The floating cursor owns the caret and re-syncs the OS
        // on every sample, even mid-coalesced-drag; that is deliberate, not an oversight, and this
        // comment is where the intent lives (FIX ROUND 1, review m2: it used to be a dedicated
        // `notifyingFloatingCaretMove` protocol member, which was a pure forwarder onto the bracket
        // below — a call-site intent does not earn a second requirement on a contract stage 2
        // inherits). Pinned by `DelegateTraceCharacterizationTests
        // .test_moveFloatingCaret_emitsABracketEvenWhileCoalescing` and
        // `DelegateEmissionTests.test_moveFloatingCaretIgnoresSuppression`.
        // TASK 37, POPULATION C — same mechanism and same reason as `legacyBeginFloatingCursor`'s
        // collapse above. The gate that sees a publishing write here is not a trace suite:
        // `FloatingCursorTests.test_perUpdate_doesNotFireOnSelectionChange_endFiresOnce` counts host
        // reports, and measured 2 where it requires 0 — which is the deliberate per-sample suppression
        // this method's comment above describes, lost.
        inputBackend.notifyingSelectionChangeIgnoringCoalescing { applyCaretOutcome(.caret(at: target)) }
        setNeedsDisplay()
        updateCaretView()   // reposition the dimmed "landing" caret at the snapped position
        guard var placement = caretHostPlacement(forGlobal: target) else { return }
        if let sx = shadowX {
            // Map the finger x into the host container's coordinate space (identity for the canvas), and
            // clamp to the host bounds so an overshooting finger can't fling the shadow off-screen.
            let raw = (placement.container === self) ? sx : convert(CGPoint(x: sx, y: 0), to: placement.container).x
            placement.frame.origin.x = min(max(raw, 0), max(0, placement.container.bounds.width - placement.frame.width))
        }
        hostOverlay(transientCaretView, at: placement)
    }

    /// Per-update edge-band check: if the floating caret is in the top/bottom band, (re)start the
    /// `CADisplayLink` auto-scroller in that direction; otherwise stop it.
    func updateFloatingAutoScroll(viewportY: CGFloat) {
        let band: CGFloat = 60
        let v = floatingAutoScrollStep(forViewportY: viewportY, viewportHeight: viewportRect().size.height, band: band)
        inputBackend.setFloatingScrollVelocity(v)
        if abs(v) < 0.001 { stopFloatingAutoScroll(); return }
        if floatingScrollLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(floatingAutoScrollTick))
            link.add(to: .main, forMode: .common)
            floatingScrollLink = link
        }
    }

    /// **TASK 42 — the "no link ⇒ no velocity" invariant lives HERE, in one body, and that is the whole
    /// answer to it straddling the seam.** The link is canvas storage (a `CADisplayLink` retains its
    /// target and `willMove(toWindow:)` must keep invalidating it); the velocity is now the backend's.
    /// Both writes stay in these two lines rather than one migrating to the backend, so a velocity left
    /// non-zero with no link to consume it — a silent stuck-autoscroll state — is impossible by
    /// construction rather than by an argument spanning two objects. Pinned by
    /// `FloatingCursorStateAuthorityTests.test_stoppingTheAutoScrollClearsTheLinkAndTheVelocityTogether`.
    func stopFloatingAutoScroll() {
        floatingScrollLink?.invalidate(); floatingScrollLink = nil
        inputBackend.setFloatingScrollVelocity(0)
    }

    /// Tears down an in-flight floating-cursor gesture without firing host callbacks — for interruptions
    /// (resign first responder, removal from window) where the OS won't deliver `endFloatingCursor`.
    /// Invalidates the auto-scroll display link (which retains `self`), clears the active flag, and hides
    /// the transient caret. Safe to call when no gesture is active (no-op).
    ///
    /// **TASK 33 — it clears THIS class's flag and not the backend's, and that asymmetry is the one thing
    /// to know about this method.** Every backend member that reaches it clears the backend's mirror
    /// itself; the enumeration of those members, and why the fix is not a write from here, are in
    /// `LegacyRichTextInputBackend+FloatingCursor.swift`'s header.
    func cancelFloatingCursor() {
        stopFloatingAutoScroll()
        guard floatingCursorActive else { return }
        inputBackend.setFloatingCursorActive(false)
        transientCaretView.hide(animated: false)
    }

    /// Pure: the per-tick vertical scroll step (points) for a floating-caret viewport-Y. Zero outside the
    /// top/bottom `band`; signed toward the nearer edge; magnitude grows with penetration into the band.
    func floatingAutoScrollStep(forViewportY y: CGFloat, viewportHeight h: CGFloat, band: CGFloat) -> CGFloat {
        let maxStep: CGFloat = 14
        guard band > 0 else { return 0 }
        if y < band { return -maxStep * (1 - max(0, y) / band) }
        if y > h - band { return maxStep * (1 - max(0, h - y) / band) }
        return 0
    }

    @objc func floatingAutoScrollTick() {
        guard floatingCursorActive, let sv = superview as? UIScrollView else { return stopFloatingAutoScroll() }
        let maxY = max(sv.contentSize.height - sv.bounds.height, 0)
        let newY = min(max(sv.contentOffset.y + floatingScrollVelocity, 0), maxY)
        guard newY != sv.contentOffset.y else { return }   // already at the edge
        let delta = newY - sv.contentOffset.y
        sv.contentOffset.y = newY        // fires the façade's scrollViewDidScroll → viewportDidChange
        // Keep the floating point under the finger as content scrolls. TASK 42: read-modify-write
        // through the projection + door, where this used to be `floatingCursorPoint.y += delta`.
        inputBackend.setFloatingCursorPoint(CGPoint(x: floatingCursorPoint.x,
                                                    y: floatingCursorPoint.y + delta))
        resolveFloatingCaret()           // re-snap (+ re-glide the shadow) against the new offset
    }
}
#endif
