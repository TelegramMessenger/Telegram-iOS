#if canImport(UIKit)
import UIKit

@available(iOS 13.0, *)
extension DocumentCanvasView {
    func installSelectionInteractions() {
        if gestureRecognizers?.isEmpty ?? true {
            // One 1-tap recognizer that fires IMMEDIATELY on every tap; multi-tap escalation
            // (caret → word → paragraph) is counted manually in handleTap. We deliberately do NOT chain
            // `require(toFail:)` to double-/triple-tap recognizers — that gate made every caret placement
            // wait out the `N`s multi-tap window, which was the reported tap-to-caret latency.
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
            tap.numberOfTapsRequired = 1
            // Delegate = self so `gestureRecognizer(_:shouldReceive:)` is consulted: a touch that lands on
            // an interactive media control (the more button) is NOT received by the tap recognizer, so the
            // control gets a clean touch sequence (the recognizer can't cancel it) and the editor's default
            // media-select tap does not also fire.
            tap.delegate = self
            // The loupe/caret-drag delay adapts to the touch's PROXIMITY to the caret: near-instant when it lands
            // within `loupeNearCursorRadius` of the cursor (grab-the-cursor), longer otherwise. `minimumPressDuration`
            // is chosen per-touch in the recognizer's `touchesBegan` from `loupeDelayNearCursor` / `loupeDelayFarFromCursor`.
            let longPress = LocationAdaptiveLongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.durationForLocation = { [weak self] point in
                guard let self else { return DocumentCanvasView.loupeDelayFarFromCursor }
                return self.isPointNearCursor(point)
                    ? DocumentCanvasView.loupeDelayNearCursor
                    : DocumentCanvasView.loupeDelayFarFromCursor
            }
            // Delegate = self so `gestureRecognizerShouldBegin` is consulted for the long-press (same path the
            // handle pan uses) — it fails the long-press on a touch that lands on an active selection handle,
            // so the handle pan can grab the knob instead of the loupe collapsing the selection.
            longPress.delegate = self
            loupeLongPress = longPress
            selectionTap = tap   // TASK 32: held so `legacyRemoveSelectionInteractions()` can remove it by identity
            [tap, longPress].forEach { addGestureRecognizer($0) }
            // Arbitration with the enclosing UIScrollView's pan is intentionally gate-only (see
            // gestureRecognizerShouldBegin) pending on-device verification — do NOT add require(toFail:) or
            // simultaneous recognition blind (it would let a near-handle drag both scroll and select).
            let handlePan = UIPanGestureRecognizer(target: self, action: #selector(handleSelectionHandlePan(_:)))
            handlePan.delegate = self
            addGestureRecognizer(handlePan)
            selectionHandlePan = handlePan
        }
        // iOS 16+ installs the UIEditMenuInteraction; below 16 the canvas presents via UIMenuController on
        // demand (no persistent interaction to install) — see DocumentCanvasView+EditMenu.
        if #available(iOS 16.0, *) {
            installEditMenuInteraction()
        }
        // We deliberately do NOT add a `UITextSelectionDisplayInteraction`. The canvas draws ALL of its own
        // selection visuals — the caret (`CaretView`), the selection wash (`SelectionHighlightView` on the
        // canvas + `CellSelectionView` inside a table's scroll content), and the two handle "lollipops"
        // (`SelectionHandleView`, positioned per endpoint by `updateSelectionHandleViews`) — so they ride a
        // table's horizontal scroll/overscroll. With all three roles own-drawn, the interaction is redundant.
        //
        // Worse than redundant: on iOS 18+/26 the interaction installs its OWN default selection chrome
        // (`_UITextSelectionLollipopView` ×2, `_UITextSelectionHighlightView`, `UIStandardTextCursorView`),
        // and assigning custom no-draw `handleViews`/`highlightView`/`cursorView` no longer suppresses the
        // default lollipops — they are left ORPHANED in the hierarchy at the container origin, surfacing as
        // stray handle knobs at ~CGPoint.zero alongside our own correctly-placed handles. Not creating the
        // interaction at all removes that leak at the source (confirmed live: the chrome appears iff the
        // interaction exists). Everything we still need is independent of it — the loupe
        // (`UITextLoupeSession`), the edit menu (`UIEditMenuInteraction`), and `caretRect(for:)` (which feeds
        // the loupe / hit-test / edit-menu geometry).
        //
        // SPIKE (loupe grow-from-cursor): we do NOT install a persistent one here. A persistent interaction goes
        // stale across our view virtualization / edits and crashes (use-after-free in `setActivated:`). Instead a
        // FRESH interaction is created per loupe drag and torn down on release (see `handleLongPress`), so nothing
        // survives between drags to be corrupted, and `removeInteraction` clears its chrome.
    }

    /// TASK 32 (Family 9, D24 clause (a)) — the inverse of `installSelectionInteractions()`'s recognizer
    /// half. **NEW code, not a moved body**: install has been one-way since it was written, which
    /// `ResponderLifecycleCharacterizationTests.test_installSelectionInteractions_isOneWay_thereIsNoRemovalPath`
    /// recorded as observed behaviour. It is reached ONLY from `LegacyRichTextInputBackend.removeInteractions()`,
    /// which `performDetachSteps()` calls as step 4 (plus `attach(to:)`'s catch path) — and `detach()` has
    /// exactly one production caller, `DocumentCanvasView.deinit`. **Deviation D18 forbids wiring it into
    /// `resignFirstResponder()`**: doing so would fix a teardown gap Task 6 pinned, which is a behaviour
    /// change. Rule R19 (`InputBackendSourceBoundaryTests`) enforces that at the source level.
    ///
    /// **BY IDENTITY, never "remove everything" — and that distinction was MEASURED, not reasoned.** The
    /// first version of this method removed every entry of `gestureRecognizers`, on the argument that
    /// `installSelectionInteractions()` is all-or-nothing behind `if gestureRecognizers?.isEmpty ?? true`
    /// and nothing else in the package calls `addGestureRecognizer` on a canvas. **That argument is
    /// false, and the count says so:** a freshly attached canvas reports **six** recognizers, not three,
    /// and a first-responder one reports **eight**. The extras are UIKit's own —
    /// `UIEditMenuInteraction` (installed by `installSelectionInteractions()`'s iOS-16 tail, outside the
    /// recognizer guard) attaches recognizers to its view, and the first-responder machinery adds more.
    /// A blanket sweep would remove those too, which is a behaviour change nobody asked for and which no
    /// count-free assertion would have caught. The three below are exactly the three install adds.
    ///
    /// **The stored references are cleared, and that is load-bearing rather than tidiness.**
    /// `gestureRecognizerShouldBegin(_:)` arbitrates by comparing `g === loupeLongPress` /
    /// `g === selectionHandlePan`. Leaving those pointing at recognizers that are no longer on any view
    /// is a dangling gate no test would see. Clearing them also restores install's own
    /// `gestureRecognizers?.isEmpty` precondition to the extent it can be restored — see the asymmetry
    /// note below for the part that cannot.
    ///
    /// **DISCLOSED ASYMMETRY, not fixed here.** `installSelectionInteractions()` ALSO installs the
    /// iOS-16+ `UIEditMenuInteraction`, and this method does NOT remove it — the task brief scopes this
    /// hook to "the recognizers `installSelectionInteractions` added". Two consequences follow and are
    /// stated rather than left to be discovered: the interaction's own recognizers survive (so
    /// `gestureRecognizers` is NOT empty afterwards), and a subsequent `installSelectionInteractions()`
    /// would therefore still skip its recognizer block. Making this a full inverse means also clearing
    /// `editMenuInteractionStorage`, or `installEditMenuInteraction()`'s `guard editMenuInteraction == nil`
    /// would refuse to reinstall. Unobservable today for the same single reason D18 rests on — this runs
    /// at `deinit`, where the interaction dies with the view — so whoever gives `detach()` a second,
    /// live-canvas caller owns closing it.
    func legacyRemoveSelectionInteractions() {
        for recognizer in [selectionTap as UIGestureRecognizer?, loupeLongPress, selectionHandlePan] {
            if let recognizer { removeGestureRecognizer(recognizer) }
        }
        selectionTap = nil
        loupeLongPress = nil
        selectionHandlePan = nil
    }

    /// The loupe "shadow" cursor tint — the desaturated snapped real-caret shown while the accent-colored cursor
    /// glides at the finger. Host-set via `RichTextEditorTheme.shadowCursor` (defaults to a light gray).
    func loupeShadowColor() -> UIColor {
        return self.mapper.theme.shadowCursor
    }

    /// Minimum horizontal separation (pt) between the accent gliding cursor (at the finger) and the snapped
    /// real caret before the gray "shadow" (`caretView`) is shown during a loupe drag. When the two sit on top
    /// of each other the shadow is redundant clutter, so it only appears once the finger has diverged this far
    /// (mid-character / between snap points), cueing where the caret will land vs where the finger is.
    static let loupeShadowMinSeparation: CGFloat = 14

    /// Whether the loupe's gray "shadow" caret should be visible: only when the accent glider (`accentX`, the
    /// finger x) is at least `loupeShadowMinSeparation` from the snapped caret (`snappedX`) — both in the same
    /// overlay-container coordinate space. Pure, so it's unit-tested without synthesizing a drag.
    func loupeShadowShouldShow(accentX: CGFloat, snappedX: CGFloat) -> Bool {
        return abs(accentX - snappedX) >= Self.loupeShadowMinSeparation
    }

    /// Positions the accent `transientCaretView` at the raw finger x (unsnapped) on the line of the snapped
    /// caret, so it glides continuously under the finger during a loupe drag — the same visual the
    /// floating-cursor gesture uses (`moveFloatingCaret`'s shadow half, without touching selection). The gray
    /// "shadow" (`caretView`) visibility is NOT set here — `updateCaretView` owns it (see its loupe branch),
    /// so a layout pass the loupe magnifier forces (which re-runs `updateCaretView`) can't clobber it.
    func positionLoupeShadow(fingerX: CGFloat, snappedGlobal pos: Int) {
        guard var placement = caretHostPlacement(forGlobal: pos) else { return }
        let raw = (placement.container === self) ? fingerX : convert(CGPoint(x: fingerX, y: 0), to: placement.container).x
        placement.frame.origin.x = min(max(raw, 0), max(0, placement.container.bounds.width - placement.frame.width))
        hostOverlay(transientCaretView, at: placement)
    }

    private func ensureFirstResponder() { if !isFirstResponder { becomeFirstResponder() } }

    /// A tap within this window AND distance of the previous one continues the multi-tap run
    /// (caret → word → paragraph); otherwise it starts a fresh count. Approximates the system double-tap.
    static let multiTapWindow: TimeInterval = 0.4
    static let multiTapSlop: CGFloat = 40

    // ── Long-press → loupe delay, chosen per-touch by the touch's PROXIMITY to the current caret. ──
    // Matches iOS: a touch that starts within `loupeNearCursorRadius` of the caret can "grab" it almost
    // immediately; a touch farther away needs the longer hold before the loupe/caret-drag begins.
    /// Radius (pt) around the caret within which a touch counts as "grabbing the cursor".
    static let loupeNearCursorRadius: CGFloat = 35
    /// Delay when the touch starts WITHIN `loupeNearCursorRadius` of the caret. Near-instant. NOTE: a literal
    /// `0` is NOT usable — the tap and long-press recognizers share touches, so `0` fires the loupe on every
    /// quick tap; keep it small-but-nonzero.
    static let loupeDelayNearCursor: TimeInterval = 0.05
    /// Delay when the touch starts OUTSIDE that radius.
    static let loupeDelayFarFromCursor: TimeInterval = 0.3

    /// True when `point` (canvas coords) is within `loupeNearCursorRadius` of the current caret (`head`).
    /// `caretRect(for:)` is the same OS-facing geometry the loupe/hit-test use, so it tracks the caret even in a
    /// horizontally-scrolled table cell. Returns false when there's no real caret (e.g. `head` at a media gap).
    func isPointNearCursor(_ point: CGPoint) -> Bool {
        guard isFirstResponder else { return false }   // no visible caret to grab until the field is focused
        let caret = caretRect(atGlobal: head)
        guard caret != .zero else { return false }
        let dx = point.x - caret.midX, dy = point.y - caret.midY
        return dx * dx + dy * dy <= Self.loupeNearCursorRadius * Self.loupeNearCursorRadius
    }

    @objc private func handleSingleTap(_ g: UITapGestureRecognizer) {
        handleTap(at: g.location(in: self), time: Date().timeIntervalSinceReferenceDate)
    }

    /// Tap handling with MANUAL multi-tap counting (split out with an explicit timestamp so it's
    /// unit-testable). A single 1-tap recognizer fires immediately on every tap, so we escalate here:
    /// the 1st tap places the caret (or toggles the menu / hits a table handle, via performSingleTap), a
    /// quick 2nd tap upgrades to a word selection, a 3rd to a paragraph. A tap outside the time/space
    /// window starts a fresh count. One handler means there is no UIKit firing-order race between separate
    /// single/double/triple recognizers — and no ~0.35s `require(toFail:)` caret-placement lag.
    func handleTap(at point: CGPoint, time now: TimeInterval) {
        // A detail-block chevron is a CONTROL, not text — route every tap on it to the single-tap handler
        // (which toggles fold) and bypass multi-tap escalation, so no tap count ever moves/selects the cursor
        // (mirrors checkboxes / table controls / the image-atom bypass below).
        if firstDetailsGlyphHit(at: point) != nil {
            lastTapTime = now; lastTapLocation = point; tapCount = 1
            performSingleTap(at: point)
            return
        }
        // An image atom has no word/paragraph to escalate to — route EVERY tap on an image to the
        // single-tap (two-step select/menu) handler, bypassing multi-tap escalation.
        if let img = mediaBox(atGap: closestGlobalPosition(to: point)), img.mediaRect().contains(point) {
            lastTapTime = now; lastTapLocation = point; tapCount = 1
            performSingleTap(at: point)
            return
        }
        // A tap on a HIDDEN spoiler reveals it: place the caret inside the run (→ selection-revealed by the
        // reconcile) and flag the explosion from the tap point. Bypasses word/paragraph escalation.
        // Invariant: a prediction ghost sits at the caret, which is always OUTSIDE a hidden spoiler
        // (a hidden run never contains the caret — see isSpoilerRevealed), so setCaret's
        // finalizeMarkedText() can't shift `target` into an invalid position within the run.
        if let run = hiddenSpoilerRun(at: point) {
            lastTapTime = now; lastTapLocation = point; tapCount = 1
            ensureFirstResponder()
            spoilerRevealHint = (run.key, point)
            let target = min(max(closestGlobalPosition(to: point), run.globalRange.lowerBound),
                             run.globalRange.upperBound)
            setCaret(global: target)
            return
        }
        if now - lastTapTime < Self.multiTapWindow,
           hypot(point.x - lastTapLocation.x, point.y - lastTapLocation.y) < Self.multiTapSlop {
            tapCount += 1
        } else {
            tapCount = 1
        }
        lastTapTime = now
        lastTapLocation = point
        switch tapCount {
        case 1:
            performSingleTap(at: point)
        case 2:
            ensureFirstResponder()
            selectWord(at: closestGlobalPosition(to: point))
            presentEditMenu()
        default:                       // 3+ taps → paragraph
            ensureFirstResponder()
            selectParagraph(at: closestGlobalPosition(to: point))
            presentEditMenu()
        }
    }

    /// The long-press `.began` multi-tap check, split out with an injected timestamp so it's unit-testable.
    /// The loupe's near-cursor delay (`loupeDelayNearCursor`) is so short that the follow-up tap of a
    /// double-/triple-tap lands on the just-placed caret and fires THIS long-press instead of completing as a
    /// tap — which is why double-tap-to-select-a-word became nearly impossible. When the press repeats a
    /// recent tap (the same window/slop test as `handleTap`, sharing `tapCount`/`lastTapTime`), consume it AS
    /// that tap: escalate to a word (or paragraph, 3rd+) selection + menu and return `true` so the caller
    /// suppresses the loupe cursor-drag. Otherwise, record a lone NEAR-cursor press as a fresh tap #1 (so the
    /// NEXT tap escalates even when the first one was itself a loupe) and return `false` to run the normal loupe.
    func handleLoupeBegan(at point: CGPoint, time now: TimeInterval) -> Bool {
        let p = closestGlobalPosition(to: point)
        if now - lastTapTime < Self.multiTapWindow,
           hypot(point.x - lastTapLocation.x, point.y - lastTapLocation.y) < Self.multiTapSlop {
            tapCount += 1
            lastTapTime = now
            lastTapLocation = point
            ensureFirstResponder()
            if tapCount >= 3 { selectParagraph(at: p) } else { selectWord(at: p) }
            presentEditMenu()
            return true
        }
        // A lone loupe that grabbed NEAR the caret stands in for a 1st tap, so a rapid follow-up escalates to
        // a word even when the first tap was itself a loupe. A deliberate FAR long-press is not a tap — leave
        // the multi-tap state untouched so it can't be mistaken for the start of a double-tap.
        if isPointNearCursor(point) {
            tapCount = 1
            lastTapTime = now
            lastTapLocation = point
        }
        return false
    }

    /// Testable core of the single-tap handler (`point` in canvas coordinates).
    func performSingleTap(at point: CGPoint) {
        let wasMenuVisible = editMenuVisible               // capture before the system auto-dismisses on touch-down
        let wasFirstResponderAtEntry = isFirstResponder
        ensureFirstResponder()
        // A FOCUSING tap must only place the caret, never open the menu. "Focusing" = the field wasn't first
        // responder before this touch — but the chat composer focuses the editor on touch-DOWN (the panel's
        // `ensureFocusedOnTap`), so `isFirstResponder` is already true here and can't be trusted. Treat the tap
        // as focusing if it wasn't focused at entry OR a genuine focus transition just happened (the flag set in
        // becomeFirstResponder, whoever triggered it). Consume the flag so the NEXT tap toggles the menu normally.
        let justFocused = didJustBecomeFirstResponder
        didJustBecomeFirstResponder = false
        let wasFirstResponder = wasFirstResponderAtEntry && !justFocused
        // A tap BELOW the document's last block starts a new empty body paragraph after it — so you can
        // always begin a normal paragraph below the final block, whatever its type (image / table / quote /
        // code / non-empty paragraph). The ONE exception: when the last block is ALREADY an empty body
        // paragraph, don't stack a redundant empty — fall through and just place the caret in it. Gated on
        // `tapBelowAddsTrailingParagraph`: a compact host (the chat composer) turns it off so a tap below the
        // content just places the caret instead of growing the field.
        if tapBelowAddsTrailingParagraph, let last = boxes.last, point.y > last.frame.maxY,
           !((last as? BlockBox).map { $0.style == .body && $0.textLength == 0 } ?? false) {
            insertEmptyBodyParagraph(at: boxes.count)   // append a body paragraph after the trailing block
            return
        }
        // A tap on a BlockQuoteBox's collapse or expand glyph toggles collapsed state. Check this BEFORE
        // the normal caret path so every block-quote glyph hit routes here — including nested quotes.
        if let bq = firstBlockQuoteGlyphHit(at: point) {
            clearStructuralSelections()
            toggleCollapsed(box: bq)
            return
        }
        // A tap on a DetailsBox's chevron folds/unfolds it (title stays visible either way).
        if let details = firstDetailsGlyphHit(at: point) {
            clearStructuralSelections()
            toggleDetailsExpanded(box: details)
            return
        }
        if let checklist = checklistBox(atCanvasPoint: point) {
            ensureFirstResponder()
            toggleChecklistItem(box: checklist)
            return
        }
        if let action = tableHandleTap(at: point) {
            switch action {
            case .select(let kind):                        // 1st tap → select the row/column (no menu yet)
                dismissEditMenu()
                switch kind {
                case .rows(let r): selectTableRows(r)
                case .columns(let c): selectTableColumns(c)
                case .cells: break   // Phase 2c-T3/T4: tapping a cell-rect handle lands with gestures (T4) — tableHandleTap() never returns .cells today
                }
            case .menu:
                // 2nd tap on the already-selected handle → ask the host to present the structural menu.
                // Presentation (and any toggle-to-dismiss) is the host's concern now — see the design spec.
                if let request = tableStructuralMenuRequest() {
                    onRequestTableStructuralMenu?(request)
                }
            }
            return
        }
        if handleButtonTapIfNeeded(at: point) {
            return
        }
        if handleFormulaTapIfNeeded(at: point) {
            return
        }
        let p = closestGlobalPosition(to: point)
        // Tap on an image body (resolves to its gap AND the point is inside the image) → atom-select /
        // menu. MUST precede the clear below (else a 2nd tap on a selected image would clear it before
        // its menu could open).
        if let img = mediaBox(atGap: p), img.mediaRect().contains(point) {
            handleImageTap(img, wasMenuVisible: wasMenuVisible, wasFirstResponder: wasFirstResponder)
            return
        }
        // A tap that lands on a spelling-flagged word toggles its correction menu (present the guesses, or close
        // them on a repeat tap of the same word — see `beginSpellingCorrection`). This fires even on a FOCUSING
        // tap: the field was just made first responder above, and a tap directly on a red word means "correct
        // it", so the guesses appear on the first tap rather than the tap only placing the caret. A tap that
        // misses every flagged word returns false and falls through to the normal caret/selection handling below.
        if beginSpellingCorrection(at: point) { return }
        clearStructuralSelections()                        // a non-handle, non-image tap clears both structural selections
        switch tapOutcome(forResolvedPosition: p, point: point) {
        case .toggleMenu:
            // Tap on the caret / inside the selection: toggle the menu, keeping the current selection.
            // The system auto-dismisses the menu on this tap's touch-down (firing willDismiss) BEFORE this
            // handler runs on tap-up, so `wasMenuVisible` is already false — `justDismissed` recognizes that
            // case and suppresses a re-present (the close-then-reopen flicker).
            let justDismissed = Date().timeIntervalSinceReferenceDate - lastMenuDismissTime < Self.menuToggleSuppressWindow
            switch menuToggleAction(menuVisible: wasMenuVisible, justDismissed: justDismissed, wasFirstResponder: wasFirstResponder) {
            case .present: presentEditMenu()
            case .dismiss: dismissEditMenu()
            }
        case .setCaret(let q):
            dismissEditMenu()
            setCaret(global: q)
        }
    }

    /// Test seam: calls the same code path as a real single tap without needing a gesture recognizer.
    func performSingleTapForTesting(at point: CGPoint) { performSingleTap(at: point) }

    // Long press places the caret and (on release) presents the menu, with a magnifier loupe
    // (`UITextLoupeSession`, iOS 17+) tracking the caret during the drag.
    @objc private func handleLongPress(_ g: UILongPressGestureRecognizer) {
        ensureFirstResponder()
        let point = g.location(in: self)
        let p = closestGlobalPosition(to: point)
        switch g.state {
        case .began:
            // A double-/triple-tap's follow-up tap can fire this near-instant loupe instead of completing as a
            // tap (the near-cursor delay is tiny). If so, consume it as the multi-tap it is — select word/
            // paragraph + present the menu — and skip the loupe cursor-drag for the rest of this gesture.
            if handleLoupeBegan(at: point, time: Date().timeIntervalSinceReferenceDate) {
                loupeConsumedAsMultiTap = true
                return
            }
            loupeConsumedAsMultiTap = false
            // Capture whether the menu was open (BEFORE we dismiss it) so `.ended` can suppress a re-present for
            // a stationary press on an already-open menu (a tap-like toggle-off) instead of flickering it.
            loupeMenuWasVisibleAtBegan = editMenuVisible
            dismissEditMenu()
            // Mark the loupe drag active BEFORE `setCaret` so the caret it renders is already SOLID (see
            // `loupeDragActive` / `updateCaretView`) by the time `begin(...)` below captures it as the
            // selection-widget — otherwise the loupe grows from a mid-blink (near-invisible) caret.
            if #available(iOS 17.0, *) { loupeDragActive = true }
            // Coalesce the OS input-delegate selection notifications for the whole drag: the per-frame caret
            // moves below skip the `selectionWillChange/DidChange` bracket (see `setCaret`), so the keyboard's
            // autocorrect/candidate bar doesn't recompute + JUMP on every move; `endCoalescedSelectionDrag`
            // (terminal state below) fires exactly one bracket for the final caret.
            beginCoalescedSelectionDrag()
            // Record the finger x BEFORE `setCaret` (its `updateCaretView` reads it for the shadow-visibility rule).
            loupeFingerX = point.x
            // Place the caret WITHOUT reporting to the host: a loupe drag reports the selection ONCE at its
            // final position (the terminal state below), not on every frame — the spacebar-trackpad model.
            setCaret(global: p, reportSelectionChange: false)
            loupeHeadAtBegan = head   // to detect a stationary press vs a real drag on `.ended`
            // The magnifier loupe is iOS 17+; below it, the long-press still places the caret + (on release)
            // presents the menu — just without the magnifier.
            // `setCaret` above has already positioned + shown our own `caretView` at `p`; pass it as the
            // selection-widget so the loupe lifts off from / settles back onto the real caret (the native
            // magnifier animation) instead of fading in at the touch point. It's our custom cursor — the
            // canvas installs no `UITextSelectionDisplayInteraction`, so this is the only caret view there is.
            if #available(iOS 17.0, *) {
                // SPIKE: activate the display interaction and borrow ITS system cursorView as the loupe widget
                // (a bare/own caret view is ignored by the loupe's grow animation — 3 approaches proved it).
                // Create a FRESH interaction for THIS drag (torn down on release) so nothing stale survives to crash.
                let sel = UITextSelectionDisplayInteraction(textInput: self, delegate: self)
                addInteraction(sel)
                selectionDisplayInteraction = sel
                sel.isActivated = true
                sel.setNeedsSelectionUpdate()
                sel.layoutManagedSubviews()
                let cv = sel.cursorView
                loupeSession = UITextLoupeSession.begin(at: point, fromSelectionWidgetView: cv, in: self)
                // Keep the borrowed system cursor NEAR-INVISIBLE (alpha 0.01) — it exists only as the loupe's
                // grow anchor. It blinks natively; a visible-but-dimmed one would flicker through when the finger
                // is idle. Our own bright TransientCaretView is the visible cursor, gliding at the raw finger x.
                cv.alpha = 0.01
                // The GLIDING cursor (follows the finger) is the ACCENT; the snapped landing caret is the GRAY
                // "shadow" (the real position). Recolor the steady caret to gray for the drag; restore on end.
                transientCaretView.accentColor = caretView.accentColor
                loupeSavedCaretAccent = caretView.accentColor
                caretView.accentColor = loupeShadowColor()
                positionLoupeShadow(fingerX: point.x, snappedGlobal: p)
                transientCaretView.show(animated: true)
            }
        case .changed:
            if loupeConsumedAsMultiTap { return }   // consumed as a double-tap → keep the word selection, ignore drag
            loupeFingerX = point.x   // BEFORE setCaret (its updateCaretView reads it for the shadow-visibility rule)
            setCaret(global: p, reportSelectionChange: false)   // move the caret silently; report once on release
            if #available(iOS 17.0, *) {
                // Keep the borrowed system cursor tracking (grow anchor) but NEAR-INVISIBLE (its native blink
                // would flicker through otherwise); our TransientCaretView is the visible cursor.
                selectionDisplayInteraction?.setNeedsSelectionUpdate()
                selectionDisplayInteraction?.layoutManagedSubviews()
                selectionDisplayInteraction?.cursorView.alpha = 0.01
                // Glide the bright shadow at the raw finger x (unsnapped).
                positionLoupeShadow(fingerX: point.x, snappedGlobal: p)
                // At an image gap caretRect(for:) is .zero; the loupe wants CGRectNull there (no caret) so it
                // tracks the touch instead of snapping toward the view origin. No real caret sits at {0,0}.
                let caret = caretRect(atGlobal: p)
                loupeSession?.move(to: point, withCaretRect: caret == .zero ? .null : caret,
                                   trackingCaret: caret != .zero)
            }
        case .ended, .cancelled, .failed:
            if loupeConsumedAsMultiTap {   // consumed as a double-tap → nothing to tear down; keep the selection + menu
                loupeConsumedAsMultiTap = false
                return
            }
            loupeFingerX = nil   // drag over: the final caret (below) is shown, not gated on the last finger x
            if let accent = loupeSavedCaretAccent {   // restore the caret's accent (was recolored gray for the drag)
                caretView.accentColor = accent
                loupeSavedCaretAccent = nil
            }
            if g.state == .ended { setCaret(global: p) }   // finalize the caret at the release position first
            if #available(iOS 17.0, *) {
                // Snap the invisible system cursor (the loupe's animate-OUT anchor) to the FINAL caret before
                // invalidating. The loupe's move(to: finger) had been dragging the widget along with the touch, so
                // without this the loupe settles back onto the finger instead of the caret on release.
                selectionDisplayInteraction?.setNeedsSelectionUpdate()
                selectionDisplayInteraction?.layoutManagedSubviews()
                loupeSession?.invalidate()
                loupeSession = nil
                transientCaretView.hide(animated: true)   // fade the gliding shadow
                // SPIKE: tear the interaction DOWN (not just deactivate) so its chrome is removed and nothing
                // persists to be corrupted before the next drag.
                if let sel = selectionDisplayInteraction {
                    sel.isActivated = false
                    removeInteraction(sel)
                    selectionDisplayInteraction = nil
                }
            }
            loupeDragActive = false   // resume the steady caret's blink
            // The drag coalesced the OS input-delegate brackets (keyboard suggestions didn't churn per frame);
            // now the final caret is settled (`.ended` re-ran `setCaret` above; `.cancelled`/`.failed` sit at
            // the last-dragged caret), so fire exactly ONE bracket to sync the keyboard. No-op if not coalescing.
            endCoalescedSelectionDrag()
            if g.state == .ended {
                // Present the menu on release — EXCEPT for a stationary press on an already-open menu, which is a
                // tap-like toggle-off: re-presenting it there is the disappear-then-reappear flicker (a quick tap
                // near the caret is caught as a loupe). A real drag, or a press with no menu open, presents.
                if loupeShouldPresentMenuOnEnd(menuWasVisibleAtBegan: loupeMenuWasVisibleAtBegan,
                                               caretMoved: head != loupeHeadAtBegan) {
                    presentEditMenu()   // setCaret above already reported the final caret to the host (once)
                }
            } else {
                // .cancelled/.failed take no setCaret path — refresh so the caret blinks again, and report the
                // final (last-dragged) caret to the host ONCE so its selection isn't left stale after the drag.
                updateCaretView()
                onSelectionChange?()
            }
        default:
            break
        }
    }

    @objc private func handleSelectionHandlePan(_ g: UIPanGestureRecognizer) {
        let point = g.location(in: self)
        let pos = closestGlobalPosition(to: point)
        switch g.state {
        case .began:
            if let corner = tableResizeCornerKnob(at: point) {
                // A `.cells` corner-knob drag — either a committed `.cells` selection's knob, or the
                // focused-cell "fake" chrome's (no committed selection yet; `extendCellSelection`'s first
                // call promotes it). Checked before the row/column knob (which requires `tableSelection !=
                // nil`) so the fake-chrome case is reachable at all.
                draggingTableCornerKnob = corner
            } else if tableSelection != nil, let end = tableResizeKnob(at: point) {
                draggingTableKnob = end                       // table range-knob drag
            } else {
                draggingEndpoint = nearerSelectionEndpoint(toGlobal: pos)   // text-selection handle drag
                // Capture the touch→endpoint offset so the drag keeps its starting offset from the finger
                // (the knob is drawn offset from the text line; mapping the raw finger snaps the endpoint to
                // whatever line is under the touch — the "line-centered" drag bug).
                // Coalesce the per-touch-move input-delegate notifications for the duration of the drag —
                // one bracket fires on `.ended` (the keyboard's autocorrect/candidate work is meaningless
                // mid-drag and pegs the CPU on every frame). The table-knob path uses structural selection
                // (not these setters), so it doesn't coalesce.
                if let end = draggingEndpoint {
                    captureSelectionDragOffset(endpoint: end, touch: point)
                    beginCoalescedSelectionDrag()
                }
            }
        case .changed:
            if let corner = draggingTableCornerKnob {
                extendCellSelection(corner: corner, toward: point)
            } else if let end = draggingTableKnob {
                extendTableSelection(end: end, toward: point)
            } else if let end = draggingEndpoint {
                let target = selectionDragPosition(forTouch: point)   // touch + captured grab offset
                if end == .anchor { setSelectionAnchor(global: target) } else { setSelectionHead(global: target) }
                // If the head endpoint is being dragged into a scrollable table's edge zone, auto-scroll.
                updateDragAutoScroll(point: point, headInTable: end == .head && tableBox(containingGlobal: head) != nil)
            }
        case .ended, .cancelled, .failed:
            stopDragAutoScroll()
            endCoalescedSelectionDrag()   // sync the OS to the final selection before presenting the menu
            if draggingTableKnob != nil || draggingTableCornerKnob != nil || draggingEndpoint != nil {
                presentMenuAfterSelectionDrag(tableKnob: draggingTableKnob != nil || draggingTableCornerKnob != nil)
            }
            draggingTableKnob = nil
            draggingTableCornerKnob = nil
            draggingEndpoint = nil
        default:
            break
        }
    }

    /// The drag-end menu decision (extracted for testability). A table resize-KNOB drag (row/column range OR
    /// a `.cells` corner) extended a STRUCTURAL selection → ask the host to present the structural menu (its
    /// `menuFor:` delegate no longer handles the structural case). A text selection-HANDLE drag presents the
    /// normal edit menu.
    func presentMenuAfterSelectionDrag(tableKnob: Bool) {
        if tableKnob {
            if let request = tableStructuralMenuRequest() { onRequestTableStructuralMenu?(request) }
        } else {
            presentEditMenu()
        }
    }
}

@available(iOS 13.0, *)
extension DocumentCanvasView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        // The loupe / move-cursor long-press must NOT begin on an active selection handle: it fires on the
        // stationary hold, and the handle pan only begins once the finger MOVES, so without this gate the
        // long-press wins the race, `setCaret`s the caret at the touch (collapsing the selection), and the
        // handles vanish before they can be grabbed. Failing it here lets the handle pan own that touch.
        if g === loupeLongPress { return shouldBeginCursorLongPress(at: g.location(in: self)) }
        guard g === selectionHandlePan else { return true }   // only gate our handle pan; everything else passes
        return isSelectionDragTouch(g.location(in: self))
    }

    /// If a touch lands on an interactive media control, NONE of the canvas's own recognizers receive it —
    /// the control (e.g. the more button) handles it exclusively. This is what makes a media control tappable:
    /// otherwise the tap recognizer would `cancelsTouchesInView` the control's touch AND run the editor's
    /// default media-select. A touch anywhere else (poster area included) is received normally, so the default
    /// tap handling runs. Matches: "if the media view returns anything from hitTest, leave it be; if not, use
    /// the default tap logic." Gates every canvas recognizer with delegate == self (tap / loupe / handle pan).
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return mediaControlHitTest(atCanvasPoint: touch.location(in: self)) == nil
    }

    // MARK: - Gesture predicates

    /// The interactive media control (if any) under `point` (canvas coords), by routing the point through the
    /// `mediaOverlay` pass-through `hitTest`. Non-nil ⇒ a control (e.g. the more button) owns the touch and the
    /// canvas's recognizers must yield (see `gestureRecognizer(_:shouldReceive:)`); nil ⇒ default tap handling.
    /// Exposed as a named seam so the routing is unit-testable without synthesizing a `UITouch`.
    func mediaControlHitTest(atCanvasPoint point: CGPoint) -> UIView? {
        return mediaOverlay.hitTest(convert(point, to: mediaOverlay), with: nil)
    }

    /// Whether the loupe / move-cursor long-press should be allowed to begin at `point`. It yields to an
    /// active selection handle (an "active item") so the handle can be grabbed — everywhere else (including a
    /// collapsed caret, where there are no handles) it proceeds. Shares `isSelectionDragTouch`'s hit-region for
    /// selection handles + table resize knobs, and ALSO prohibits pickup on a table's structural GRIPS (the row
    /// ⋮ / column ••• handles): a stationary hold on a grip must let the grip TAP select the row/column, not move
    /// the caret. The grips are TAP targets (not drag targets), so they're excluded here rather than added to
    /// `isSelectionDragTouch` — which also gates the handle PAN and scroll-yield, where a grip must not begin a
    /// (spurious) text-selection drag.
    func shouldBeginCursorLongPress(at point: CGPoint) -> Bool {
        return !isSelectionDragTouch(point) && tableHandle(at: point) == nil
    }

    /// True when a touch should begin a selection-handle / table-knob DRAG rather than a scroll. Shared by
    /// the canvas handle-pan gate (returns this) and the inner table scroll gate (begins only when this is
    /// FALSE), so a handle/knob drag always wins near a grip — gate-only, no require(toFail:).
    func isSelectionDragTouch(_ point: CGPoint) -> Bool {
        // A `.cells` corner-knob drag — committed `.cells` selection OR the focused-cell fake chrome (no
        // committed selection yet); `tableResizeCornerKnob` covers both, so it isn't gated on `tableSelection`.
        if tableResizeCornerKnob(at: point) != nil { return true }
        if tableSelection != nil, tableResizeKnob(at: point) != nil { return true }   // a table row/column knob drag
        guard selFrom != selTo else { return false }          // no text selection → no handle drag → a drag scrolls
        let tol: CGFloat = 22
        let startRect = caretRect(atGlobal: selFrom)
        let endRect = caretRect(atGlobal: selTo)
        return startRect.insetBy(dx: -tol, dy: -tol).contains(point)
            || endRect.insetBy(dx: -tol, dy: -tol).contains(point)
    }
}

/// SPIKE: required delegate for the borrowed `UITextSelectionDisplayInteraction`. Returning `nil` uses the
/// default container (the interaction hosts its own chrome). If the spike shows a leak we can't otherwise hide,
/// the next step is to return a dedicated, hidden container here so the orphaned lollipops land somewhere we own.
/// A long-press recognizer whose `minimumPressDuration` is chosen per-touch from the initial touch location
/// (near-instant on selectable content, longer on empty area). The duration is set in `touchesBegan` BEFORE
/// `super` — which is where the recognizer schedules its timer — so the per-touch value takes effect.
@available(iOS 13.0, *)
final class LocationAdaptiveLongPressGestureRecognizer: UILongPressGestureRecognizer {
    /// Returns the press duration to use for a touch that begins at `point` (in the recognizer's `view`).
    var durationForLocation: ((CGPoint) -> TimeInterval)?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if let provider = durationForLocation, let point = touches.first?.location(in: view) {
            minimumPressDuration = provider(point)
        }
        super.touchesBegan(touches, with: event)
    }
}

@available(iOS 17.0, *)
extension DocumentCanvasView: UITextSelectionDisplayInteractionDelegate {
    func selectionContainerViewBelowText(for interaction: UITextSelectionDisplayInteraction) -> UIView? {
        // Host all of the interaction's chrome in our stable, untracked container so (a) our reload/virtualization
        // never frees its views and (b) it's corralled where we can hide it.
        bringSubviewToFront(selectionChromeContainer)
        return selectionChromeContainer
    }
}
#endif
