#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// The composer-host surface the engine can genuinely answer.
///
/// ANSWER-OR-TRAP, not deferred capability. Everything here has a real engine equivalent today, so
/// every member forwards and **none returns a constant**. That distinction is the whole discipline:
/// the prior attempt at this project shipped `hasText -> false` and `isEditableForWritingTools ->
/// false`, which were indistinguishable from correct answers at every call site and cost five manual
/// debugging sessions to find. Configuration for capabilities that do NOT exist yet lives in
/// `RichTextEngineEditorView+DeferredConfiguration.swift` instead, under a rule that makes each entry
/// name the rung that will consume it.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// The four-argument spelling, kept for the call sites that have it and for the ones that mean
    /// it: a pass with nothing to say about the caret. It forwards `.none`, which is exactly that.
    @discardableResult
    public func update(size: CGSize,
                       insets: UIEdgeInsets,
                       contentMargins: UIEdgeInsets,
                       scrollIndicatorInsets: UIEdgeInsets?) -> CGFloat {
        update(size: size, insets: insets, contentMargins: contentMargins,
               scrollIndicatorInsets: scrollIndicatorInsets, caretReveal: .none)
    }

    /// Lays the editor out at `size` and returns the content height the composer sizes its field to,
    /// and is the ONE place the caret may be revealed — see `performCaretReveal`.
    ///
    /// Takes all five parameters explicitly. `RichTextEditorView`'s equivalent defaults two of them,
    /// which is fine for a direct caller but means the protocol requirement must declare them all —
    /// a method with defaulted parameters witnesses a requirement only when the full signature
    /// matches. (`height(forWidth:)` is the opposite case and needed a forwarder; see
    /// `RichTextEditorView.swift:457`.)
    @discardableResult
    public func update(size: CGSize,
                       insets: UIEdgeInsets,
                       contentMargins: UIEdgeInsets,
                       scrollIndicatorInsets: UIEdgeInsets?,
                       caretReveal: RichTextEditorCaretReveal) -> CGFloat {
        composerHostState.contentMargins = contentMargins
        // The engine FILLS the editor; the margins go to its own text container, which is the
        // mechanism the legacy input node uses for the identical property (it assigns the panel's
        // value straight to `defaultTextContainerInset`). Insetting the engine's FRAME instead made
        // the padding stack on top of the engine's own `textContainerInset` default of (8, 5, 8, 5),
        // which read as the field having extra margins and the text being pushed inward.
        // Captured to decide whether THIS pass moves the text, and therefore the caret — see
        // `markCaretForRedrawIfHostGeometryMoved`. Read before the two assignments below, which are
        // the only things here that re-lay the text out.
        let geometryBefore = EngineTextGeometry(frame: engine.frame, inset: engine.textContainerInset)
        // A changed TOP inset must re-seat a scroll view that is RESTING AT THE TOP — UIKit only
        // clamps `contentOffset` when an inset changes, and with `contentInsetAdjustmentBehavior =
        // .never` nothing else re-seats it. For a document shorter than the viewport the clamp is
        // enough (the content-height floor leaves −top as the only valid offset), but a document
        // TALLER than the viewport leaves offset 0 in range, so its first screenful stayed hidden
        // under the top band: the article editor opened scrolled under its navigation bar. Captured
        // BEFORE the write; `<=` admits a rubber-band overscroll above the top, which is still "at
        // the top". Legacy carries the identical rule and comment (`RichTextEditorView.update`).
        let previousTopInset = engine.contentInset.top
        let wasRestingAtTop = engine.contentOffset.y <= -previousTopInset + 0.5
        // This pass is changing the geometry the caret is measured against, so it may have taken the
        // caret out of sight — see the call below.
        //
        // The whole applied geometry, not "the viewport shrank", which is what this asked before.
        // That was one instance (the keyboard arriving) mistaken for the rule, and it missed the
        // other direction: a pass that makes the field TALLER can also make it NARROWER, and the
        // re-wrap moves the caret down further than the extra height reveals. Measured on K3 with the
        // caret at the end of a scrolling draft, dismissing the software keyboard — field 274 -> 298,
        // content 405 -> 428, caret 377 -> 400 against a visible band ending at 405. Nothing asked,
        // because the caret never moved in the document; the text moved under it.
        //
        // Compared against what the LAST pass applied, not against the view's own bounds: the chat
        // panel assigns the editor's frame directly (`textFieldFrame`) and only then calls this, so by
        // the time we are here the view already has the new size and reading it would answer "it did
        // not change" for every resize there is. Traced on the device — the field went 298 to 274 tall
        // and this still said no.
        let geometryNow = ComposerHostState.AppliedGeometry(size: size, insets: insets)
        let theGeometryChanged = composerHostState.appliedGeometry
            .map { $0 != geometryNow } ?? false
        // The part of that change a TABLE's horizontal reveal answers to: only a new width (or new
        // side margins) moves a caret sideways; a height-only pass leaves a run where the user put it.
        let theWidthChanged = (composerHostState.appliedGeometry
            .map { abs($0.size.width - size.width) > 0.01 } ?? false)
            || abs(geometryBefore.inset.left - textContainerInset(forContentMargins: contentMargins).left) > 0.01
            || abs(geometryBefore.inset.right - textContainerInset(forContentMargins: contentMargins).right) > 0.01
        engine.frame = CGRect(origin: .zero, size: size)
        engine.textContainerInset = textContainerInset(forContentMargins: contentMargins)
        markCaretForRedrawIfHostGeometryMoved(from: geometryBefore)
        engine.contentInset = insets
        // `verticalScrollIndicatorInsets` rather than the deprecated whole-inset setter. `nil` is the
        // protocol's "track the content insets" — the indicator is inset by the same bands the content
        // scrolls under — and NOT "leave whatever the engine had", which is what it used to mean here:
        // the article editor passes nil, so its scrollbar ran under the navigation bar and behind the
        // keyboard. A non-nil value REPLACES that (absolute, not additive), which is how the composer
        // pins its indicator to a fixed visual position instead of following the keyboard.
        engine.verticalScrollIndicatorInsets = scrollIndicatorInsets ?? insets
        engine.horizontalScrollIndicatorInsets = scrollIndicatorInsets ?? insets
        engine.setNeedsLayout()
        engine.layoutIfNeeded()
        // After the layout above, so the new content size is in place — an offset write is clamped by
        // it. Gated on the top inset actually CHANGING, so an update driven by anything else — a
        // keyboard-driven bottom inset, a re-layout after an edit — never re-seats a scroll the user
        // owns.
        if abs(insets.top - previousTopInset) > 0.01, wasRestingAtTop {
            engine.contentOffset = CGPoint(x: engine.contentOffset.x, y: -insets.top)
        }
        // Recorded BEFORE the reveal, so a reveal that re-enters this cannot compare against a value
        // it is in the middle of producing.
        composerHostState.appliedGeometry = geometryNow
        performCaretReveal(caretReveal, geometryChanged: theGeometryChanged, widthChanged: theWidthChanged)
        // The placeholder is placed from the frame and both insets, all three of which this pass may
        // have moved; without this it kept the position the last edit gave it.
        refreshBodyPlaceholder()
        // Measure through `height(forWidth:)` rather than reading `contentSize.height` here.
        //
        // The engine's `layoutSubviews` FLOORS `contentSize.height` at the height of the VISIBLE area
        // — which for the composer, whose host passes `.zero` insets, is the whole bounds — so
        // reading it while the engine is framed at the composer's full height returns that height for
        // every document — a four-paragraph document measures exactly as tall as a one-paragraph one.
        // `height(forWidth:)` already probes at height 0 and restores the prior frame, so it is both
        // the correct measurement and the only one; duplicating the probe here would be a second copy
        // of a rule this project has now got wrong three times.
        // Ceiled AFTER the max, not before it: `minimumContentHeight` is a HOST value and the one
        // part of this answer the measurement does not own, so a fractional floor went out to the
        // caller verbatim — measured, a floor of 200.5 was returned as 200.5. `height(forWidth:)` is
        // already integral, so this ceil is only ever deciding the floor.
        return ceil(max(minimumContentHeight, height(forWidth: engine.frame.width)))
    }

    /// The one place this editor changes its own `contentOffset` for the caret — and only ever inside
    /// a host's layout pass, against the geometry that pass has just applied.
    ///
    /// `ifNeeded` is not "reveal whenever the caret is out of band". Both hosts re-lay out for
    /// reasons that have nothing to do with the caret, and a bare out-of-band test would yank back a
    /// scroll the user deliberately dragged away. It reveals when something ASKED — a text or
    /// selection change since the last reveal, which the engine records as
    /// `tgid_caretRevealPending` — or when this pass CHANGED THE GEOMETRY the caret is measured
    /// against, which is the host moving the caret rather than the user.
    ///
    /// That second condition used to read "shrank the viewport", and that was one instance mistaken
    /// for the rule. The keyboard arriving under a caret nobody moved is a shrink; so is the composer
    /// re-wrapping wider when focus hides the accessory buttons. But the SAME pass can grow the field
    /// and still hide the caret, because changing the width re-wraps the text and moves every line
    /// below the change — measured on K3 dismissing the software keyboard with the caret at the end
    /// of a scrolling draft, where the field grew 24pt and the content grew 23, leaving the caret
    /// 18pt below the edge with nothing asking and nothing shrinking.
    ///
    /// The animation is honoured only in that second case. A reveal owed to a caret that MOVED is
    /// written immediately whatever the host passed: an animated one mutates `contentOffset`
    /// mid-flight, and a rapid second arrow key then computes its destination against in-flux state
    /// — the non-determinism `RichTextEditorView.scrollCaretIntoView`'s own comment records. So the
    /// animation stays tied to the GEOMETRY having changed, which is what it was tied to before under
    /// the narrower name.
    internal func performCaretReveal(_ request: RichTextEditorCaretReveal, geometryChanged: Bool, widthChanged: Bool = false) {
        guard case let .ifNeeded(animation) = request else { return }
        let wasAsked = engine.tgid_caretRevealPending
        guard wasAsked || geometryChanged else { return }
        // Cleared whatever the outcome: the host asked, so the editor is no longer owed a reveal —
        // including when the guards below decline one. Left set, the DEBUG audit would report a
        // reveal nobody owes.
        engine.tgid_caretRevealPending = false
        guard engine.isFirstResponder else { return }
        // Sideways, inside a table's run: it moves the caret horizontally only, so the vertical answer
        // below is the same either way. Its own trigger is narrower (see
        // `revealSelectionEndInPlacedRun`), and it follows a selection's END as well as a caret. OWED
        // to this view's own layout pass rather than performed here: the tables are placed at their
        // real widths there (`syncTableFrames`), and measured before that, a pass right after a
        // document set read the caret inside a column the table had not yet been widened past and
        // declined — leaving the caret off screen until something else asked (fuzz seed 34).
        if wasAsked || widthChanged {
            placedRunCaretRevealOwed = true
            setNeedsLayout()
        }
        guard let selection = engine.selectedTextRange, selection.isEmpty else { return }

        let caret = engine.caretRect(for: selection.end)
        guard !caret.isNull, caret.minY.isFinite, caret.height.isFinite else { return }
        let insets = engine.adjustedContentInset
        let firstLine = engine.caretRect(for: engine.beginningOfDocument)
        let lastLine = engine.caretRect(for: engine.endOfDocument)
        let input = RichTextCaretRevealInput(
            caret: caret,
            firstLineTop: firstLine.isNull ? nil : firstLine.minY,
            lastLineBottom: lastLine.isNull ? nil : lastLine.maxY,
            contentHeight: engine.contentSize.height,
            viewportHeight: engine.bounds.height,
            topInset: insets.top,
            bottomInset: insets.bottom,
            offsetY: engine.contentOffset.y)
        guard let offsetY = RichTextCaretRevealSolver.offsetY(for: input) else { return }

        let target = CGPoint(x: engine.contentOffset.x, y: offsetY)
        guard geometryChanged, case let .animated(duration, curve) = animation else {
            engine.contentOffset = target
            return
        }
        let options: UIView.AnimationOptions = [.allowUserInteraction, .beginFromCurrentState]
        switch curve {
        case .easeInOut:
            UIView.animate(withDuration: duration, delay: 0.0,
                           options: options.union(.curveEaseInOut)) {
                self.engine.contentOffset = target
            }
        case .spring:
            // A REAL spring, critically damped so a revealed caret never overshoots and comes back.
            // It is not a byte-match of what `ContainedViewLayoutTransition` uses — that is the
            // private `kCAMediaTimingFunctionSpring`, and this package cannot import `Display` to
            // reach it. Close enough that a reveal and the layout it accompanies do not visibly
            // disagree, and honest about being a spring rather than an `easeInOut` wearing the name:
            // a case that silently behaved as another curve would be exactly the kind of plausible
            // lie this project keeps paying for.
            UIView.animate(withDuration: duration, delay: 0.0,
                           usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0,
                           options: options) {
                self.engine.contentOffset = target
            }
        }
    }

    /// Margin-aware measurement: horizontal margins reduce the width text may occupy, so the probe
    /// must measure at the REDUCED width. Ignoring them would report a height for a wider line box
    /// than the composer will actually give the text, and the field would be measured too short.
    public func height(forWidth width: CGFloat, contentMargins: UIEdgeInsets?) -> CGFloat {
        // The margins are NOT subtracted from `width` here, and that is the whole point: they live in
        // the engine's `textContainerInset`, so the engine narrows the column itself. Subtracting
        // them as well counted them twice — measured, an applied column of 260pt was probed at 200 —
        // which over-reported the height and made the composer's field grow before the text had
        // reached the edge.
        //
        // A caller may probe margins it has not applied yet (the protocol's whole point is asking
        // "how tall with M?" before committing to M), so they are applied for the duration and put
        // back. When they equal the live ones — the common case, since the host usually probes what
        // it just applied — the engine's own setter short-circuits and this costs nothing.
        guard let contentMargins else { return height(forWidth: width) }
        let priorInset = engine.textContainerInset
        engine.textContainerInset = textContainerInset(forContentMargins: contentMargins)
        defer { engine.textContainerInset = priorInset }
        return height(forWidth: width)
    }

    /// The floor the composer's field never shrinks below. Storage on the wrapper because the engine
    /// has no equivalent concept — but it is READ on every `update(...)`, so it is not inert.
    public var minimumContentHeight: CGFloat {
        get { composerHostState.minimumContentHeight }
        set { composerHostState.minimumContentHeight = newValue }
    }

    /// Horizontal page margin the composer lays the field out within. Read by `update(...)` callers
    /// through `contentMargins`; stored here so the composer can ask for what it set.
    public var contentPageMargin: CGFloat {
        get { composerHostState.contentPageMargin }
        set {
            guard composerHostState.contentPageMargin != newValue else { return }
            composerHostState.contentPageMargin = newValue
            // Re-derive from the margins already applied, so a host that sets this AFTER its first
            // `update(...)` is not left at the old column until the next one.
            engine.textContainerInset =
                textContainerInset(forContentMargins: composerHostState.contentMargins)
            engine.setNeedsLayout()
        }
    }

    /// The engine's text-container inset for a set of host content margins.
    ///
    /// `contentPageMargin` is the editor's OWN horizontal page margin and is ADDITIVE to the host's
    /// margins — the legacy canvas derives its content width the same way, as
    /// `bounds.width - (pageMargin + margins.left) - (pageMargin + margins.right)`. It is horizontal
    /// only; there is no vertical page margin.
    ///
    /// It has to be folded in HERE, at the one place the inset is derived, because both the applied
    /// pass and the height PROBE go through it. The probe swaps margins in for its duration, so a
    /// page margin added only on the applied side would let a caller measure a wider column than the
    /// text is actually given — the same double-counting that made the composer's field grow early,
    /// in the other direction.
    ///
    /// The composer zeroes this (its panel owns the padding around the field); the full-page article
    /// editor keeps the 16pt default and passes `contentMargins` with left/right 0, so this property
    /// IS its side insets. While it was stored-and-unread that editor had essentially none.
    /// **The TOP is snapped to a whole point, and the remainder handed to the BOTTOM.**
    ///
    /// This inset is where the text starts, so every block origin — and every line boundary inside a
    /// block — is measured from it. The chat panel's vertical pair is `textInputViewInternalInsets`
    /// (5.0 / 4.0) plus `calculateTextFieldRealInsets` (4.5 / 5.5), deliberately lopsided so the
    /// TOTAL is even, and the engine is handed the 4.5 / 5.5 half as `contentMargins`. Passed
    /// through, that put every composer block origin on a HALF POINT, and a line's selection rect is
    /// quantised to a whole-point height — so the rect fell half a point short of the next line and
    /// left the seam the article editor (which passes 12.0) never showed.
    ///
    /// The SUM is preserved exactly, which is what the panel's pair is about: the field measures and
    /// lays out the same, and only the split between the halves moves — 4.5 / 5.5 becomes 5 / 5.
    /// Horizontal is left alone deliberately: the reported defect is vertical, and the right inset
    /// carries the panel's own accessory arithmetic.
    private func textContainerInset(forContentMargins margins: UIEdgeInsets) -> UIEdgeInsets {
        let page = composerHostState.contentPageMargin
        let top = EngineBlockSpacing.snappedToWholePoints(margins.top)
        let bottom = (margins.top + margins.bottom) - top
        return UIEdgeInsets(top: top, left: margins.left + page,
                            bottom: bottom, right: margins.right + page)
    }

    /// Placeholder strings for empty states. The engine renders the body placeholder today; the
    /// block-specific entries (pull quote, code block, details title) become reachable at R7, but the
    /// whole value round-trips now because the composer sets it as one struct.
    public var placeholders: RichTextEditorPlaceholders {
        get { composerHostState.placeholders }
        set {
            composerHostState.placeholders = newValue
            refreshBodyPlaceholder()
        }
    }

    /// Shows `placeholders.body` when the document holds no text at all, and hides it otherwise.
    ///
    /// Called from the placeholder setter and from the observation callback, so it tracks typing.
    /// Only the body entry is honoured — see `bodyPlaceholderLabel`'s comment for why the rest wait
    /// for R7.
    internal func refreshBodyPlaceholder() {
        let text = composerHostState.placeholders.body
        let isEmpty = engine.attributedBlocks.allSatisfy { $0.length == 0 }
        bodyPlaceholderLabel.text = text
        bodyPlaceholderLabel.font = engine.font
        bodyPlaceholderLabel.isHidden = text.isEmpty || !isEmpty
        if bodyPlaceholderLabel.superview == nil {
            addSubview(bodyPlaceholderLabel)
        }
        let inset = engine.textContainerInset
        // The placeholder stands in for the document's first line, so it sits where that line is —
        // which is below the top CONTENT inset, the band the host reserves for its navigation bar.
        // Reading only the text-container inset put it at the editor's own top edge: in the article
        // editor "Type something..." was drawn 68pt too high, underneath the Close button. Composed
        // from the insets rather than from `contentOffset` because the offset is the scroll's, and a
        // document empty enough to show a placeholder cannot scroll — its content fits by definition,
        // so the only valid offset is `-contentInset.top`.
        let contentInset = engine.adjustedContentInset
        bodyPlaceholderLabel.frame = CGRect(x: engine.frame.minX + contentInset.left + inset.left,
                                            y: engine.frame.minY + contentInset.top + inset.top,
                                            width: max(0, engine.frame.width - contentInset.left - contentInset.right - inset.left - inset.right),
                                            height: bodyPlaceholderLabel.font.lineHeight)
    }

    /// Forwards to the engine's own background. Not stored-and-ignored: reading it back reads the
    /// engine, so a caller cannot be told a colour that is not on screen.
    public var canvasBackgroundColor: UIColor? {
        get { engine.backgroundColor }
        set { engine.backgroundColor = newValue }
    }

    /// Whether a tap below the last block appends a trailing paragraph.
    public var tapBelowAddsTrailingParagraph: Bool {
        get { composerHostState.tapBelowAddsTrailingParagraph }
        set { composerHostState.tapBelowAddsTrailingParagraph = newValue }
    }

    /// Consulted when a hardware Return arrives; returning true means the host handled it.
    public var onHardwareReturn: ((UIKeyModifierFlags) -> Bool)? {
        get { composerHostState.onHardwareReturn }
        set { composerHostState.onHardwareReturn = newValue }
    }

    /// Fired after the ENGINE takes the responder role — see `+Responder.swift`, where the wrapper
    /// deliberately never calls `super.becomeFirstResponder()`.
    public var onBecameFirstResponder: (() -> Void)? {
        get { composerHostState.onBecameFirstResponder }
        set { composerHostState.onBecameFirstResponder = newValue }
    }

    public var onResignedFirstResponder: (() -> Void)? {
        get { composerHostState.onResignedFirstResponder }
        set { composerHostState.onResignedFirstResponder = newValue }
    }

    /// The editor's colour theme.
    ///
    /// NOT accept-and-store, although it looks like configuration. `AttributedStringMapper.init`
    /// takes a theme (`:54`) and `characterAttributes(from:)` reads `theme.primaryText` as the
    /// foreground, so the theme decides the colour the engine renders text in. Stored inertly, the
    /// engine composer would render the default palette regardless of the app's appearance —
    /// white-on-white in dark mode. It can name no consuming rung either, so the register's own rule
    /// bars it. Setting it rebuilds the mapper and re-applies the document.
    public var theme: RichTextEditorTheme {
        get { composerHostState.theme }
        set {
            composerHostState.theme = newValue
            rebuildMapper(withTheme: newValue)
            bodyPlaceholderLabel.textColor = newValue.placeholder
        }
    }

    /// The engine's scroll offset. The engine IS a `UIScrollView`, so this is its own value rather
    /// than a mirrored copy.
    public var composerContentOffset: CGPoint { engine.contentOffset }

    /// The language the keyboard should open in on the next focus. Forwarded to the ENGINE, which is
    /// the first responder — the wrapper never takes the role, so a pre-selection stored here would
    /// never be queried. See `TGIDEngineObservation.h` for the single-shot ordering invariant.
    public var initialInputPrimaryLanguage: String? {
        get { engine.tgid_initialPrimaryLanguage }
        set { engine.tgid_initialPrimaryLanguage = newValue }
    }

    /// Re-arm the pre-selection so the next focus re-applies `initialInputPrimaryLanguage`.
    public func resetInputPrimaryLanguage() { engine.tgid_resetInitialPrimaryLanguage() }
}

/// Composer-host state with no engine equivalent. Distinct from `DeferredConfiguration`: every field
/// here is READ by code on this rung, so none of it is a deferred capability.
public struct ComposerHostState {
    /// The geometry the last `update(...)` applied — the size it was given and its insets.
    ///
    /// The view's own bounds cannot answer this: a host may assign the editor's frame directly before
    /// calling `update`, as the chat panel does through `textFieldFrame`, so by the time the call runs
    /// the bounds are already the new ones. nil until the first pass, which changes nothing.
    ///
    /// The WIDTH is part of it, and that is the half a height-only record could not see: a width
    /// change re-wraps the text, which moves the caret in content coordinates without the viewport
    /// shrinking and without anything asking. See `performCaretReveal`.
    internal var appliedGeometry: AppliedGeometry?

    /// What a caret reveal compares between passes. Equatable so the comparison cannot drift from
    /// the fields it is made of.
    internal struct AppliedGeometry: Equatable {
        var size: CGSize
        var insets: UIEdgeInsets
    }

    /// The content margins the host applied on its last `update(...)`, mirrored so the view can
    /// answer for what it was asked to apply.
    ///
    /// They are applied to the ENGINE'S TEXT CONTAINER, not to its frame — the same mechanism the
    /// legacy input node uses for the identical property. Insetting the frame stacked them on top of
    /// the engine's own `textContainerInset`, which read as the field having extra left padding.
    ///
    /// The value survives a layout pass because the engine holds it; `update(...)` used to inset the
    /// frame and then forget the margins entirely, so the next `layoutSubviews` — which UIKit runs
    /// unprompted — reset the engine to the full bounds and the text laid out wider than the field the
    /// host asked for, overflowing the button strip.
    internal var contentMargins: UIEdgeInsets = .zero

    public var minimumContentHeight: CGFloat = 44
    /// 0 — every host states its own. The legacy view instead defaults to the document's 16
    /// (`CanvasMetrics.pageMargin`), so a host that sets neither gets a different column from the two
    /// editors; both current hosts set it explicitly, which is what keeps that from mattering. The
    /// full-page article editor relied on legacy's default and so had NO side insets here until it
    /// did.
    public var contentPageMargin: CGFloat = 0
    public var placeholders = RichTextEditorPlaceholders(body: "", listEnd: "", listOutdent: "")
    /// `true`, as legacy's is: the article editor never sets this and relies on the default, so a
    /// `false` here silently took the affordance away from the one host that wants it. The chat
    /// composer sets it `false` explicitly.
    public var tapBelowAddsTrailingParagraph = true
    public var onHardwareReturn: ((UIKeyModifierFlags) -> Bool)?
    public var onBecameFirstResponder: (() -> Void)?
    public var onResignedFirstResponder: (() -> Void)?
    public var theme: RichTextEditorTheme = .default

    public init() {}
}
#endif
