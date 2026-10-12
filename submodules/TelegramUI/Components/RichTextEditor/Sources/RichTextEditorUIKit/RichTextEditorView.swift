#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// Which input backend this editor should be built for. Deliberately a KIND, not a backend
/// type: no backend type is part of this view's public API (spec: "No backend type becomes part
/// of `RichTextEditorView`'s public API"). External consumers cannot implement a backend, only
/// name one of these.
@available(iOS 13.0, *)
public enum RichTextEditorInputBackendPreference {
    case legacy
    /// Use the InputDec backend when the runtime supports it; fall back to legacy otherwise.
    case inputDecIfSupported
    /// Debug/comparison only: trap instead of falling back.
    case inputDecRequired
}

@available(iOS 13.0, *)
extension RichTextEditorInputBackendPreference {
    /// Maps the public KIND onto the module-internal factory preference, so
    /// `RichTextInputBackendPreference` never leaks into this file's public surface.
    /// `fileprivate`, not `private`: a `private` member of an extension is visible only to that
    /// type's own declaration and extensions in this file, and `RichTextEditorView.init` is
    /// neither.
    fileprivate var internalPreference: RichTextInputBackendPreference {
        switch self {
        case .legacy:
            return .legacy
        case .inputDecIfSupported:
            return .inputDecIfSupported
        case .inputDecRequired:
            return .inputDecRequired
        }
    }
}

/// Public façade. Renders all block types (paragraphs, images, tables) in a vertical canvas
/// with continuous cross-block selection.
@available(iOS 13.0, *)
public final class RichTextEditorView: UIView, UIScrollViewDelegate {
    private let scrollView = GripYieldingScrollView()
    let canvas: DocumentCanvasView

    /// Floor for the content height returned by `update(...)`/`performLayout`. Defaults to 44pt (a document
    /// editor wants a tappable minimum body). A compact host (e.g. the chat composer) sets it to 0 so the
    /// measured height hugs the actual text and the host owns the minimum field height.
    public var minimumContentHeight: CGFloat = 44

    /// Enables OS spelling underlines + tap-to-correct (default on). Set false to disable entirely.
    public var isSpellCheckingEnabled: Bool {
        get { canvas.isSpellCheckingEnabled }
        set { canvas.isSpellCheckingEnabled = newValue }
    }

    /// Host-settable colors. Defaults to `.default` (today's look). Assigning re-applies colors to the live
    /// editor: the mapper (text/link), the caret/selection/blockquote accent, and a reload so boxes rebuild
    /// with the themed mapper. A reload resets the live selection — theme changes are host-driven (e.g. an
    /// app appearance switch), so this is acceptable.
    public var theme: RichTextEditorTheme = .default {
        didSet {
            canvas.applyTheme(theme)
            if bounds.width > 0.0 {
                canvas.reload(self.document.blocks, width: bounds.width)
            }
            canvas.setNeedsDisplay()
        }
    }

    /// Per-host quote geometry (insets, spacing, bar/fill). Defaults reproduce the editor's built-in look.
    /// Set before the first `update(...)`/document seed (the compact-host knob convention); assigning it
    /// after content reloads the boxes so the new geometry takes effect (like `theme`).
    public var quoteStyle: QuoteStyle = .default {
        didSet {
            canvas.applyQuoteStyle(quoteStyle)
            if bounds.width > 0.0 {
                canvas.reload(self.document.blocks, width: bounds.width)
            }
            canvas.setNeedsDisplay()
        }
    }

    /// Per-host pull-quote geometry (padding, pill, marks, minWidth). Defaults reproduce the editor's built-in look.
    /// Set before the first `update(...)`/document seed (the compact-host knob convention); assigning it
    /// after content reloads the boxes so the new geometry takes effect (like `quoteStyle`).
    public var pullQuoteStyle: PullQuoteStyle = .default {
        didSet {
            canvas.applyPullQuoteStyle(pullQuoteStyle)
            if bounds.width > 0.0 {
                canvas.reload(self.document.blocks, width: bounds.width)
            }
            canvas.setNeedsDisplay()
        }
    }

    /// Per-host code-block geometry (vertical inset, language-line gap). Both fields default to nil,
    /// meaning "use the shared render metrics" — so an unset host matches the InstantPage V2 renderer.
    /// Side padding is deliberately not a knob: it is the paragraph inset at the block's nesting level.
    public var codeStyle: CodeStyle = .default {
        didSet {
            guard codeStyle != oldValue else { return }
            canvas.applyCodeStyle(codeStyle)
            if bounds.width > 0.0 {
                canvas.reload(self.document.blocks, width: bounds.width)
            }
            canvas.setNeedsDisplay()
        }
    }

    /// Per-host media geometry (horizontal bleed). Defaults reproduce the editor's built-in edge-to-edge
    /// look; the compact chat composer assigns `MediaBlockStyle(horizontalBleed: 0)` so media insets like
    /// the text paragraphs. Set before the first `update(...)`/document seed (the compact-host knob
    /// convention); assigning it after content reloads the boxes so the new geometry takes effect (like `quoteStyle`).
    public var mediaBlockStyle: MediaBlockStyle = .default {
        didSet {
            canvas.applyMediaBlockStyle(mediaBlockStyle)
            if bounds.width > 0.0 {
                canvas.reload(self.document.blocks, width: bounds.width)
            }
            canvas.setNeedsDisplay()
        }
    }

    /// Host-injected icons for the block-quote collapse/expand affordance. `nil` (default) ⇒ no affordance
    /// icon is drawn. Assigning it reloads so `BlockQuoteBox`es pick up the new glyphs.
    public var quoteCollapseIcons: RichTextEditorQuoteCollapseIcons? = nil {
        didSet {
            canvas.applyQuoteCollapseIcons(quoteCollapseIcons)
            if bounds.width > 0.0 {
                canvas.reload(self.document.blocks, width: bounds.width)
            }
            canvas.setNeedsDisplay()
        }
    }

    /// Host-injected fold chevron for detail blocks — the V2 `ExpandingItemVerticalRegularArrow` (template).
    /// `nil` (default) ⇒ a drawn-arrow fallback. Assigning it reloads so `DetailsBox`es pick up the image.
    public var detailsChevronImage: UIImage? = nil {
        didSet {
            canvas.detailsChevronImage = detailsChevronImage
            if bounds.width > 0.0 {
                canvas.reload(self.document.blocks, width: bounds.width)
            }
            canvas.setNeedsDisplay()
        }
    }

    /// The render metrics the editor lays text out with — fonts, per-style line-spacing factors, and
    /// the block-rhythm scalars. Defaults to the chat-message look, which is what a rich message
    /// renders as in a bubble. A host that renders its content through a differently-configured
    /// InstantPage V2 surface passes that surface's metrics here instead. Set before the first
    /// `update(...)`/document seed (the compact-host knob convention); assigning it after content
    /// rebuilds the boxes so the new metrics take effect (like `quoteStyle`).
    public var renderMetrics: RichTextRenderMetrics = .default {
        didSet {
            guard renderMetrics != oldValue else { return }
            canvas.applyRenderMetrics(renderMetrics)
            if bounds.width > 0.0 {
                canvas.reload(self.document.blocks, width: bounds.width)
            }
            canvas.setNeedsDisplay()
        }
    }

    /// Whole-document writing-direction override. `.auto` (default) auto-detects per paragraph; the forced
    /// cases pin the whole editor. Modeled like `theme`: assigning re-applies to the live mapper and
    /// reloads (resetting the live selection) when the view is sized, so boxes rebuild with the direction.
    public var layoutDirectionOverride: DocumentLayoutDirection {
        get { canvas.layoutDirectionModel }
        set {
            canvas.applyWritingDirectionOverride(newValue)
            if bounds.width > 0.0 {
                canvas.reload(self.document.blocks, width: bounds.width)
            }
            canvas.setNeedsDisplay()
        }
    }

    /// Fires (no payload) whenever anything changes — a content edit, a content-size change, or a
    /// selection/caret move. The host responds by re-running its own layout (which calls
    /// `update(size:insets:)`). May fire more than once per logical change; treat it as idempotent.
    public var onChange: (() -> Void)?
    /// See `RichTextEditor.onCaretRevealNeeded`: the synchronous report that a reveal is owed.
    /// Separate from `onChange` precisely because the selection-driven half of that is coalesced
    /// to a trailing async call, and a reveal a turn late races the next arrow key.
    public var onCaretRevealNeeded: (() -> Void)?
    /// Set when a text or selection change asks for a reveal, cleared by the pass that performs one.
    /// It is what makes `ifNeeded` mean "something asked" rather than "the caret is out of band": a
    /// host re-lays out for reasons that have nothing to do with the caret, and without this every
    /// such pass would drag the document back to the caret from wherever the user had scrolled it.
    /// The engine editor holds the same flag, on the engine (`tgid_caretRevealPending`).
    private var isCaretRevealOwed = false

    /// Fires once when the editor gains first-responder focus (the editing surface becomes first
    /// responder) — not on a repeat tap while already focused. A host can react by showing chrome.
    public var onBecameFirstResponder: (() -> Void)?

    /// Fires once when the editor loses first-responder focus (resigns first responder). A host can
    /// react by dismissing a panel / chrome.
    public var onResignedFirstResponder: (() -> Void)?

    /// Pasting media (image/gif/video/sticker) is a host concern — the editor never embeds it. Set these to
    /// route a media paste to the host (e.g. the chat send flow): `canPasteMedia` gates whether Paste is
    /// offered; `onPasteMedia` performs it (returns whether it consumed the paste). Text paste is handled by
    /// the editor regardless of these.
    public var canPasteMedia: (() -> Bool)? { didSet { canvas.canPasteMedia = canPasteMedia } }
    public var onPasteMedia: (() -> Bool)? { didSet { canvas.onPasteMedia = onPasteMedia } }

    /// Host transform for pasted PLAIN text. When set and it returns a `Document`, that document is
    /// spliced at the caret (one undo step) instead of the built-in newline-split paste. Returning nil
    /// falls back to the built-in behavior. The package attaches no meaning to the string — a host uses
    /// this to convert e.g. markdown to rich content without the package depending on any markdown code.
    public var plainTextFragmentTransformer: ((String) -> Document?)? { didSet { canvas.plainTextFragmentTransformer = plainTextFragmentTransformer } }

    /// A HARDWARE-keyboard Return (plain or ⌘) is offered to the host before the editor inserts a newline, so
    /// a chat composer can implement send-on-Enter / send-on-⌘-Enter. Return `true` to have the editor insert
    /// a newline (the default when unset); `false` when the host consumed the Return (e.g. sent the message).
    /// The software keyboard's Return is unaffected (it always inserts a newline).
    public var onHardwareReturn: ((UIKeyModifierFlags) -> Bool)? { didSet { canvas.onHardwareReturn = onHardwareReturn } }

    /// Configure each selection-handle ("knob") view. The closure is invoked once per handle view (start and
    /// end), passing it as a bare `UIView`. Use it to set host-framework properties the editor package can't
    /// reach — e.g. Display's `disablesInteractiveTransitionGestureRecognizer` (the navigation back-swipe a
    /// horizontal knob drag triggers), `disablesInteractiveModalDismiss`, and `disablesInteractiveKeyboard-
    /// GestureRecognizer` — so a knob drag isn't hijacked by those gestures. The handle views are hit-testable
    /// (hit area = the drag tolerance around the endpoint caret), so the effect is scoped to knob interaction
    /// rather than the whole editor surface.
    public var configureSelectionHandleView: ((UIView) -> Void)? { didSet { canvas.configureSelectionHandleView = configureSelectionHandleView } }

    /// Localized titles for the editor's custom edit-menu items on all supported iOS versions.
    public var editMenuStrings: RichTextEditorMenuStrings {
        get { canvas.editMenuStrings }
        set { canvas.editMenuStrings = newValue }
    }

    /// Transform the editor's default edit-menu elements into the final set. `defaultElements` is the system
    /// suggested actions (Cut/Copy/Paste/Select + Writing Tools) followed by the editor's own custom items
    /// (the built-in "Format" submenu + Look Up / Translate / Share). Return the elements to present.
    /// Consulted ONLY for a non-collapsed selection, ONLY on iOS 16+ (`UIEditMenuInteraction`); on iOS 13–15
    /// the editor's built-in items are shown unchanged. nil ⇒ default menu.
    public var contextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])? {
        get { canvas.hostContextMenuItemsProvider }
        set { canvas.hostContextMenuItemsProvider = newValue }
    }

    /// The editor's table row/column structural menu, handed to the host to present its own menu (a
    /// ContextController) anchored to the tapped handle. Fired when the user taps an already-selected table
    /// handle. The editor builds WHAT the menu contains; the host owns presentation. Unset ⇒ no menu.
    public var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)? {
        get { canvas.onRequestTableStructuralMenu }
        set { canvas.onRequestTableStructuralMenu = newValue }
    }

    /// Fired when a media control (the "more" button; the "+" later) is tapped, with an account-free
    /// `MediaControlRequest` — the opaque mediaID + occurrence-bound operation closures. The host resolves
    /// the concrete media and presents its own menu. Mirrors `onRequestTableStructuralMenu`. Unset ⇒ no menu.
    public var onRequestMediaControl: ((MediaControlRequest) -> Void)? {
        get { canvas.onRequestMediaControl }
        set { canvas.onRequestMediaControl = newValue }
    }

    /// A read-only snapshot of the editor at the current selection — drives a host toolbar's per-action
    /// availability + selected state. Pure: never mutates or fires `onChange`.
    public struct EditorState: Equatable {
        public let bold: Bool
        public let italic: Bool
        public let underline: Bool
        public let strikethrough: Bool
        public let code: Bool
        /// True when the caret's inherited format / the whole selection carries the spoiler marker
        /// (`.rtSpoiler` / `CharacterAttributes.spoiler`). Drives a host toolbar's Spoiler check-state.
        public let spoiler: Bool
        public let paragraphStyle: ParagraphStyleName?
        /// True when the caret/selection is inside a first-class code block (`Block.code` / `CodeBlockBox`).
        /// Distinct from `code` (the inline-monospace character format). `paragraphStyle` is nil in a code block.
        public let isCodeBlock: Bool
        /// True when the caret/selection is inside a pull-quote block (`Block.pullQuote` / `PullQuoteBox`).
        public let isPullQuote: Bool
        public let listMarker: ListMarker?
        public let link: String?
        public let hasSelection: Bool
        public let isInTable: Bool
        /// True when the caret/selection is inside a table whose `compact` flag is set (halved cell
        /// padding). False when not in a table at all, so a host needs no optional handling.
        public let isTableCompact: Bool
        /// Whether the caret's table draws its grid. `true` when the caret isn't in a table.
        public let isTableBordered: Bool
        /// True when a non-empty selection touches only paragraph text — no media or table block, and
        /// neither endpoint is inside a table cell. A list marker can only be meaningfully applied to
        /// paragraph blocks, so a host toolbar uses this to gate a per-selection List action. False for
        /// a collapsed caret.
        public let selectionIsTextOnly: Bool
        public let canUndo: Bool
        public let canRedo: Bool
        /// Number of `Block.blockQuote` containers enclosing the caret (0 = not in a quote; N = nested N levels
        /// deep). Drives a host toolbar's Quote check-state (≥1 → checked). Pure: reads canvas state only.
        public let blockQuoteDepth: Int

        /// Public so a second editor implementation can report its own state. The memberwise init is
        /// internal, which is invisible until another module conforms to `RichTextEditor` — the
        /// engine editor now does, for the article-editor host.
        public init(bold: Bool,
                italic: Bool,
                underline: Bool,
                strikethrough: Bool,
                code: Bool,
                spoiler: Bool,
                paragraphStyle: ParagraphStyleName?,
                isCodeBlock: Bool,
                isPullQuote: Bool,
                listMarker: ListMarker?,
                link: String?,
                hasSelection: Bool,
                isInTable: Bool,
                isTableCompact: Bool,
                isTableBordered: Bool,
                selectionIsTextOnly: Bool,
                canUndo: Bool,
                canRedo: Bool,
                blockQuoteDepth: Int) {
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.strikethrough = strikethrough
        self.code = code
        self.spoiler = spoiler
        self.paragraphStyle = paragraphStyle
        self.isCodeBlock = isCodeBlock
        self.isPullQuote = isPullQuote
        self.listMarker = listMarker
        self.link = link
        self.hasSelection = hasSelection
        self.isInTable = isInTable
        self.isTableCompact = isTableCompact
        self.isTableBordered = isTableBordered
        self.selectionIsTextOnly = selectionIsTextOnly
        self.canUndo = canUndo
        self.canRedo = canRedo
        self.blockQuoteDepth = blockQuoteDepth
        }
    }

    public func currentState() -> EditorState { canvas.currentState() }

    public override convenience init(frame: CGRect) {
        self.init(frame: frame, inputBackend: .legacy)
    }

    /// Designated initializer. `inputBackend` names WHICH input backend the canvas is built for;
    /// production reaches the editor through the convenience initializer above and therefore stays
    /// on `.legacy`. The body below is `commonInit()` — deliberately extracted rather than
    /// duplicated, so the two entry points can never drift.
    public init(frame: CGRect, inputBackend: RichTextEditorInputBackendPreference) {
        self.canvas = RichTextInputCanvasFactory.make(inputBackend.internalPreference)
        super.init(frame: frame)
        commonInit()
    }

    private func commonInit() {
        addSubview(scrollView)
        scrollView.clipsToBounds = false
        // Don't hold touches during pan-arbitration (~150ms) before delivering them to the canvas's tap
        // recognizer — that delay compounded the tap-to-caret latency. The handle-pan↔scroll arbitration
        // is gate-only (DocumentCanvasView.gestureRecognizerShouldBegin), so this is safe.
        scrollView.delaysContentTouches = false
        // The parent owns insets exactly (via update(size:insets:)). The editor frame can reach into the
        // bottom safe area, so the default .automatic adjustment would ADD the home-indicator inset on top
        // of the parent's contentInset.bottom (double-counting it at rest). .never keeps the inset contract exact.
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.canvas = canvas   // yield the outer scroll's pan to a selection-handle grip (vertical knob drag)
        scrollView.addSubview(canvas)
        canvas.installSelectionInteractions()
        // The canvas is sized frame-based in layoutSubviews, so a content-height change (typing wraps a
        // line, a cell grows, undo, …) must re-trigger our layout — otherwise it only updates on the next
        // layout pass (e.g. a rotation).
        canvas.onContentSizeChange = { [weak self] in
            guard let self else { return }
            self.onChange?()                 // pure relay; the host re-lays-out via update()
            self.isCaretRevealOwed = true    // …and that pass is where the caret is revealed
            // An edit reports its selection change right after this, and that report asks for the
            // reveal; asking here too cost every keystroke a second host reveal pass.
            if !self.canvas.selectionChangeFollowsContentSizeChange {
                self.onCaretRevealNeeded?()
            }
        }
        // The OS moves the caret via arrows through the canvas's selectedTextRange setter, which can land
        // it off-screen (e.g. arrowing up out of a tall image to the block above). Scroll it back into view.
        // `scrollCaretIntoView` stays SYNCHRONOUS (arrow-key scroll-follow must settle before the setter
        // returns — see its doc-comment). The HOST notification, however, is coalesced (see below): the OS
        // drives a backspace/replace as a non-collapsed `selectedTextRange` set immediately followed — same
        // runloop turn — by the delete that collapses it, i.e. two synchronous selection changes. Fired
        // synchronously, a host reading `currentState().hasSelection` would observe the transient non-empty
        // range and flare a selection-gated toolbar into its "has selection" state and back out. Coalescing
        // to one trailing async call lets the host see only the settled selection. Content-size changes still
        // relay synchronously (above), so typed text lays out immediately.
        // The caret is no longer followed from here: this REPORTS that one is owed and the host's
        // next pass decides. The scroll that used to sit on this line decided against geometry the
        // host was about to change, which is the whole of what this design replaces.
        canvas.onSelectionChange = { [weak self] in
            self?.isCaretRevealOwed = true
            self?.onCaretRevealNeeded?()
            self?.scheduleSelectionDrivenOnChange()
        }
        // Surface first-responder transitions (the canvas is the actual first responder) to the host.
        canvas.onBecameFirstResponder = { [weak self] in self?.onBecameFirstResponder?() }
        canvas.onResignedFirstResponder = { [weak self] in self?.onResignedFirstResponder?() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    public var document: Document {
        get { Document(blocks: canvas.currentBlocks(), layoutDirection: canvas.layoutDirectionModel) }
        set {
            canvas.applyWritingDirectionOverride(newValue.layoutDirection)
            var blocks = newValue.blocks
            if blocks.isEmpty { blocks = [.paragraph(ParagraphBlock(id: BlockID.generate()))] }
            canvas.reload(blocks, width: bounds.width)
            // Only lay out when the view is framed. `reload` already applied the model and fired
            // `onContentSizeChange`, so an UNFRAMED set (draft restore / attachment init before the first
            // layout pass) defers to the host's next framed `update(...)`. A zero-width `performLayout` would
            // only build the media/overlay views at a 0×0 rect (and bind their fetch) and redo it the instant
            // the real frame lands — matching every other setter here, which gate on `bounds.width > 0`.
            if bounds.width > 0.0 {
                performLayout(size: bounds.size)   // explicit parent-driven layout for the content swap (no self-schedule)
            }
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        // Skip a zero-width UIKit layout pass (the view is in the hierarchy but not yet framed): it can't lay
        // text out and would only build the media/overlay views at a 0×0 rect, redone the instant the real
        // frame arrives. The host's framed `update(...)` drives the real layout. Matches the `document` setter.
        if bounds.width > 0.0 {
            performLayout(size: bounds.size)
        }
    }

    /// Parent-driven layout. Lays the document out at `size.width`, applies `insets` to the internal scroll
    /// view (bottom = the keyboard/input-panel overlap the parent owns), and returns the measured content
    /// height (a 44pt minimum, matching the laid-out canvas) so a content-hugging host can size to it; a
    /// fixed-region host ignores it. The view does NOT set its own frame — the parent does that, then calls
    /// this (and may use the return to pick the frame).
    ///
    /// `contentMargins` is interior padding that is PART of the content (distinct from `insets`): the text
    /// lays out inset by it (wrapping narrower, offset from the edges), the content height grows by
    /// top+bottom, and the margin area still hit-tests to the nearest position. Insets are non-interactable
    /// bands the content scrolls UNDER (nav bar / keyboard / input panel). Both are layout-affecting inputs,
    /// so — like `insets` — margins are applied HERE rather than via a side-effecting property setter (which
    /// would hide a re-layout and could re-enter `onChange`); pass them every `update`, and they persist
    /// across intervening system layout passes until the next `update`.
    /// `scrollIndicatorInsets` (optional) positions the vertical scroll indicator independently of the
    /// content `insets`. `nil` (the default) tracks the content insets — the indicator is inset by the same
    /// bands the content scrolls under. A non-nil value REPLACES that (absolute, not additive) — a compact
    /// host (the chat composer) sets a constant input-field inset so the scrollbar sits at a fixed visual
    /// position instead of following the keyboard/panel overlap. It is purely visual (scrollbar geometry):
    /// it does NOT enter `performLayout` / the content-size math. Supplied every `update`, so there is no
    /// stored override for a later `update` to clobber.
    /// The four-argument spelling, kept for the call sites that have it and for the ones that mean
    /// it: a pass with nothing to say about the caret. It forwards `.none`, which is exactly that.
    @discardableResult
    public func update(size: CGSize, insets: UIEdgeInsets, contentMargins: UIEdgeInsets = .zero,
                       scrollIndicatorInsets: UIEdgeInsets? = nil) -> CGFloat {
        update(size: size, insets: insets, contentMargins: contentMargins,
               scrollIndicatorInsets: scrollIndicatorInsets, caretReveal: .none)
    }

    @discardableResult
    public func update(size: CGSize, insets: UIEdgeInsets, contentMargins: UIEdgeInsets,
                       scrollIndicatorInsets: UIEdgeInsets?,
                       caretReveal: RichTextEditorCaretReveal) -> CGFloat {
        // THIS pass is where the caret is revealed, against the geometry it applies. The editor's
        // own follow from `canvas.onSelectionChange` is still in place until the task that removes
        // it, so for now a reveal can happen twice — the second is a no-op, because the first left
        // the caret visible.
        // A changed TOP inset must re-seat a scroll view that is resting at the top — UIKit only CLAMPS
        // `contentOffset` when an inset changes, and with `contentInsetAdjustmentBehavior = .never` nothing
        // else re-seats it. For a SHORT document the clamp is enough (the visible-height floor in
        // `performLayout` makes −top the only valid offset), but a document TALLER than the viewport leaves
        // offset 0 in range, so its first screenful stayed hidden under the top inset band (the article
        // editor opened scrolled under the navigation bar). Captured BEFORE the inset is written; `<=`
        // admits a rubber-band overscroll above the top, which is still "at the top".
        let previousTopInset = scrollView.contentInset.top
        let wasRestingAtTop = scrollView.contentOffset.y <= -previousTopInset + 0.5
        scrollView.contentInset = insets
        scrollView.verticalScrollIndicatorInsets = scrollIndicatorInsets ?? insets
        canvas.contentMargins = contentMargins
        let contentHeight = performLayout(size: size)
        if case let .ifNeeded(animation) = caretReveal { revealCaret(animation, layoutIsCurrent: true) }
        // After `performLayout`, so the new content size is in place (an offset write can be clamped by it).
        // Gated on the top inset actually CHANGING, so an update driven by anything else — a keyboard-driven
        // bottom inset, a re-layout after an edit — never re-seats a scroll the user owns.
        if abs(insets.top - previousTopInset) > 0.01, wasRestingAtTop {
            scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: -insets.top)
        }
        return contentHeight
    }

    /// Sizes the scroll view + canvas to `size` and returns the measured CONTENT height (min 44). The
    /// canvas is laid out at least as tall as the VISIBLE viewport (`size.height` minus the top/bottom
    /// content insets) even when the content is shorter, so its tap/long-press/loupe recognizers receive
    /// touches anywhere in the unobscured editor area — a tap in the empty space below the text maps to the
    /// nearest position (document end), matching UITextView. Flooring at the visible height (not the full
    /// frame) keeps the scroll content == visible area for a short doc, so the scrollable range is zero (no
    /// phantom scroll/bounce over the inset bands); the insets are read here so a later `update` with new
    /// insets re-flows the content size. Insets themselves are NOT written here, so a system layout pass
    /// (rotation, etc.) never clobbers the parent-applied inset; only `update(size:insets:)` changes them.
    @discardableResult
    private func performLayout(size: CGSize) -> CGFloat {
        performLayoutCountForTesting += 1
        scrollView.frame = CGRect(origin: .zero, size: size)
        canvas.setParagraphsWidthIfNeeded(size.width)
        let contentHeight = max(canvas.intrinsicContentSize.height, self.minimumContentHeight)
        let insets = scrollView.contentInset
        let visibleHeight = max(size.height - insets.top - insets.bottom, 0)   // unobscured viewport
        let canvasHeight = max(contentHeight, visibleHeight)   // fill the visible area so empty-area taps still hit the canvas
        canvas.frame = CGRect(x: 0, y: 0, width: size.width, height: canvasHeight)
        canvas.layoutContent()   // drive the canvas layout explicitly (not via the needsLayout flag), so a
                                 // setting applied just above (margins, width) takes effect even when the
                                 // canvas frame didn't change (e.g. a short doc whose height is floored).
        scrollView.contentSize = CGSize(width: size.width, height: canvasHeight)
        #if DEBUG
        refreshDebugLayoutOverlay()
        #endif
        return contentHeight
    }

    /// Measures the content height the document would have at `width`, WITHOUT mutating the live layout
    /// — no reflow of the displayed boxes, no frame/scroll/overlay/caret change, no `onChange`. Applies
    /// the same `minimumContentHeight` floor and `contentMargins` as `update(...)`, so the measured value
    /// equals what a subsequent `update` at this width returns (measure == commit). Pure read.
    ///
    /// `contentMargins`: pass the margins the host will apply via the next `update(...)` to keep the measure
    /// correct even when called BEFORE that update has pushed them onto the live canvas (the chat composer
    /// sizes its field from this while the editor is still unsized after a draft set). Omit (`nil`) to measure
    /// against the live `contentMargins`, matching the previous behavior for hosts that update before measuring.
    public func height(forWidth width: CGFloat, contentMargins: UIEdgeInsets? = nil) -> CGFloat {
        max(canvas.measuredContentHeight(forWidth: width, contentMargins: contentMargins), minimumContentHeight)
    }

    /// Explicit arity so the `RichTextEditor` protocol's `height(forWidth:)` requirement is
    /// witnessed (`RichTextEngineEditor/RichTextEditorProtocol.swift`) — a method with a defaulted
    /// parameter does NOT satisfy a protocol requirement that omits it, so this plain-arity
    /// forwarder exists purely to close that gap. No behaviour of its own beyond forwarding with
    /// `contentMargins: nil`, matching this method's own default.
    public func height(forWidth width: CGFloat) -> CGFloat {
        height(forWidth: width, contentMargins: nil)
    }

    /// Measures the content height `lineCount` body paragraphs would occupy at `width`, using a THROWAWAY probe
    /// view the caller configures via `configure` (host layout knobs — page margin, block inset, metrics). Pure:
    /// it never touches any live editor. Routes through the real layout (`height(forWidth:contentMargins:)`), so
    /// the result equals what a live editor with the same config + content + margins reports. `contentMargins`
    /// must be the SAME margins the live field measures with (the chat composer's `trackedContentMargins`) — its
    /// vertical component is added to the height exactly as the live `textHeightForWidth` adds it, so the caller's
    /// 3-line size matches the real field. Used by the chat composer to size the 3-line AI-button trigger.
    /// `lineCount` floors at 1.
    public static func measuredContentHeight(forWidth width: CGFloat, lineCount: Int, contentMargins: UIEdgeInsets = .zero, configure: (RichTextEditorView) -> Void) -> CGFloat {
        let probe = RichTextEditorView()
        probe.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: 100.0))
        configure(probe)
        let count = max(1, lineCount)
        probe.document = Document(blocks: (0..<count).map { _ in
            Block.paragraph(ParagraphBlock(id: .generate(), style: .body, runs: [TextRun(text: "A")]))
        })
        return probe.height(forWidth: width, contentMargins: contentMargins)
    }

    /// Test accessor: the current bottom content inset.
    var bottomContentInsetForTesting: CGFloat { scrollView.contentInset.bottom }
    /// Test accessor: the current vertical scroll indicator insets (asserted decoupled from the content inset).
    var verticalScrollIndicatorInsetsForTesting: UIEdgeInsets { scrollView.verticalScrollIndicatorInsets }
    /// Test accessor: the scroll view's content height (the scrollable extent).
    var scrollContentHeightForTesting: CGFloat { scrollView.contentSize.height }
    /// Test accessor: the scroll view's content offset (read to assert caret-follow scrolling; set to
    /// simulate the caret being scrolled off-screen).
    var contentOffsetForTesting: CGPoint {
        get { scrollView.contentOffset }
        set { scrollView.contentOffset = newValue }
    }
    /// Test accessor: the underlying canvas (to set up selection in unit tests).
    var canvasForTesting: DocumentCanvasView { canvas }
    /// Test seam: how many synchronous layout passes have run (`CaretRevealLayoutPassTests`).
    var performLayoutCountForTesting = 0

    public func toggleBold() { canvas.toggleBold() }
    /// The chat's ⇧⌘N: removes every inline mark from the selection as one undo step (see the canvas's
    /// `clearInlineFormatting`). Also the `RichTextEditor` protocol's requirement, whose default does nothing.
    public func clearInlineFormatting() { canvas.clearInlineFormatting() }
    public func toggleItalic() { canvas.toggleItalic() }
    public func toggleStrikethrough() { canvas.toggleStrikethrough() }
    public func toggleUnderline() { canvas.toggleUnderline() }
    public func toggleInlineCode() { canvas.toggleInlineCode() }
    public func toggleSpoiler() { canvas.toggleSpoiler() }
    public func setParagraphStyle(_ name: ParagraphStyleName) { canvas.setParagraphStyle(name) }
    public func setAlignment(_ alignment: TextAlignment) { canvas.setAlignment(alignment) }
    public func setList(_ marker: ListMarker?) { canvas.setList(marker) }
    public func makePullQuote() { canvas.makePullQuote() }
    public func wrapInBlockQuote() { canvas.wrapInBlockQuote() }
    public func unwrapBlockQuoteLevel() { canvas.unwrapBlockQuoteLevel() }

    // TASK 39b — **these two deliberately do NOT wrap `synchronizingExternalChange`, and that is the
    // whole ruling, not an omission.** `effectiveUndoManager?.undo()` INVOKES `registerUndo`'s closure
    // (`DocumentCanvasView+Editing.swift`), which carries the bracket; wrapping here as well would emit
    // TWO external changes for one user-visible undo. The closure is also the only placement that emits
    // exactly once on BOTH entry paths — this facade one and the responder's system Cmd-Z, which never
    // passes through here at all.
    //
    // The task brief specified `.commitBeforeChange` for this path, on the grounds that
    // `canvas.finalizeMarkedText()` below IS commit-before-change. It is — and the two policies are
    // INDISTINGUISHABLE in the backend anyway: `.discard` and `.commitBeforeChange` are the same
    // statement (`markedRangeStorage = nil`) in `reconcileMarkedTextForExternalChange`, so swapping
    // either the bodies or the case labels is a textual no-op nothing in the package can see. That is
    // the load-bearing half of the argument (review fix round 1). The weaker half, still true: by the
    // time the closure runs there is no marked text left to commit, so the two describe the identical
    // state here. The policy value DESCRIBES what happened to the marked range; on this path
    // the answer is "already finalized upstream". Making the facade's intent visible to a
    // self-re-registering `UndoManager` closure would need a transient flag for zero behavioural
    // difference. Pinned by `ExternalSynchronizationTests.test_theFacadeUndoPathSynchronizesExactlyOnce`.
    public func undo() { canvas.finalizeMarkedText(); canvas.effectiveUndoManager?.undo(); onChange?() }
    public func redo() { canvas.finalizeMarkedText(); canvas.effectiveUndoManager?.redo(); onChange?() }
    // The trailing `onChange?()` is load-bearing for a host toolbar's undo/redo availability. The undo/redo
    // closure fires its `notifyContentSizeChanged` refresh WHILE STILL INSIDE `UndoManager.undo()/redo()`, so a
    // host that re-reads `currentState().canUndo/canRedo` synchronously from that notification sees the stack
    // BEFORE the manager finalizes popping the group — stale for the LAST undo/redo (the control that should
    // disable stays enabled until an unrelated layout pass re-reads state). One more `onChange` AFTER the call
    // returns (stack settled) refreshes the host with the final availability. Idempotent: an extra no-op
    // `undo()`/`redo()` (empty stack) still re-notifies, which is harmless.

    // MARK: Table structural commands (operate on the caret's table; no-op otherwise)
    public func insertTableRowAbove() { canvas.insertTableRowAbove() }
    public func insertTableRowBelow() { canvas.insertTableRowBelow() }
    public func deleteTableRow() { canvas.deleteTableRow() }
    public func insertTableColumnLeft() { canvas.insertTableColumnLeft() }
    public func insertTableColumnRight() { canvas.insertTableColumnRight() }
    public func deleteTableColumn() { canvas.deleteTableColumn() }
    /// Deletes the table the caret is in (no-op otherwise).
    public func deleteTable() { canvas.deleteTable() }

    /// Flips the caret's table between compact (halved cell padding) and normal, as one undo step.
    /// No-op when the caret is not in a table.
    public func toggleTableCompact() { canvas.toggleTableCompact() }

    /// Shows / hides the caret table's grid. An unbordered table also lays out flush (zero-width
    /// borders), matching how the sent message renders it.
    public func toggleTableBordered() { canvas.toggleTableBordered() }
    /// Copies the caret's current table to the pasteboard (app fragment + RTF table + plain-text flatten). No-op outside a table.
    public func copyCurrentTable() { canvas.copyCurrentTable() }
    /// Replaces the caret's current table with body paragraphs (one per row, cells space-joined), one undo step. No-op outside a table.
    public func convertCurrentTableToText() { canvas.convertCurrentTableToText() }
    /// Sets horizontal/vertical alignment on every cell of the current structural table selection (row-range
    /// or column-range), falling back to the caret's single cell when there is no structural selection.
    public func setSelectionHorizontalAlignment(_ alignment: TextAlignment) { canvas.setSelectionHorizontalAlignment(alignment) }
    public func setSelectionVerticalAlignment(_ alignment: VerticalAlignment) { canvas.setSelectionVerticalAlignment(alignment) }

    /// Inserts an empty `rows`×`cols` table (row 0 a header) at the caret. No-op unless the caret is in
    /// a top-level paragraph.
    public func insertTable(rows: Int, cols: Int) { canvas.insertTable(rows: rows, columns: cols) }

    /// Inserts a fresh, expanded detail (folding) block at the caret (empty title + one empty body paragraph),
    /// with the caret placed in the title. No-op unless the caret is in a top-level paragraph.
    public func insertDetailsBlock() { canvas.insertDetailsBlock() }

    /// Sets `url` as a link over the current selection (no-op if the selection is empty).
    public func setLink(_ url: String) { canvas.setLink(url) }
    /// Removes any link over the current selection.
    public func removeLink() { canvas.removeLink() }
    /// The link the entire selection carries (for prefilling a link editor), or nil.
    public func currentLink() -> String? { canvas.currentLink() }

    /// The plain text of the current selection (empty string when the selection is collapsed). Used by a
    /// host link editor to label the prompt and decide add-vs-edit.
    public func selectedText() -> String {
        guard let range = canvas.selectedTextRange else { return "" }
        return canvas.text(in: range) ?? ""
    }

    /// The current selection as global position offsets, or `nil` when the selection is collapsed. Used by a
    /// host (the attachment screen's AI-edit-on-selection) to scope an edit to the selected range.
    public func selectedGlobalRange() -> (from: Int, to: Int)? {
        // TASK 44: was `canvas.selectedTextRange as? DocumentTextRange`, then two `.offset` reads.
        // `canonicalSelection` IS the store that getter builds its range from
        // (`LegacyRichTextInputBackend.selectedTextRange`'s getter returns
        // `LegacyTextRange(anchor, head)` verbatim, unordered, on every path), so this reads the same
        // two numbers one hop earlier and the facade names no identity type. The `min`/`max` normalise
        // here, exactly as before — an unordered pair is load-bearing INSIDE the seam, not at this
        // public boundary, whose contract is `(from, to)` ascending.
        let selection = canvas.canonicalSelection
        let from = selection.anchor.utf16Offset, to = selection.head.utf16Offset
        guard from != to else { return nil }
        return (min(from, to), max(from, to))
    }

    /// Replaces the global range `[from, to)` with `document`'s blocks as ONE undo step (delete + fragment
    /// splice; caret collapses to the end of the inserted content). An empty `document` deletes the range.
    public func replaceRange(from: Int, to: Int, with document: Document) {
        canvas.replaceRange(globalFrom: from, globalTo: to, with: document)
    }

    /// Increases the list nesting level of the touched list items (no-op on non-list paragraphs).
    public func indent() { canvas.indent() }
    /// Decreases the list nesting level of the touched list items (clamps at 0; no-op on non-list).
    public func outdent() { canvas.outdent() }

    /// Inserts an inline custom emoji `id` (host-resolved to a view via `registerEmojiViewProvider`) at
    /// the caret. `altText` is its plain-text / Markdown form (optional).
    public func insertEmoji(id: String, altText: String? = nil) { canvas.insertEmoji(id: id, altText: altText) }

    /// Inserts plain `text` at the caret (replacing any selection) in one undo step. Used for unicode
    /// emoji and any programmatic plain-text insertion.
    public func insertText(_ text: String) { canvas.insertText(text) }

    /// Inserts a formula at the caret as a single inline atom carrying formula metadata. Without a
    /// registered renderer, invalid/unrenderable formula content degrades to visible raw LaTeX.
    public func insertFormula(latex: String) { canvas.insertFormula(latex: latex) }

    /// Legacy's `insertFormula` IS the inline one — it inserts a single atom at the caret — so the
    /// engine's block/inline split collapses to the same call here.
    public func insertInlineFormula(latex: String) { canvas.insertFormula(latex: latex) }

    /// The selection's text becomes an inline formula. A genuine thin forwarder: the canvas's
    /// `insertFormula` already replaces the selection and inserts one inline atom at the caret, so
    /// reading the selection as the latex is the only thing this adds.
    public func makeSelectionInlineFormula() {
        guard let range = canvas.selectedTextRange, let latex = canvas.text(in: range),
              !latex.isEmpty else { return }
        canvas.insertFormula(latex: latex)
    }

    /// Inserts a button row (one default pill) at the caret. Top-level only: a row inside a table or a
    /// block quote is preserved and rendered if it arrives via the edit round-trip, but not created.
    public func insertButtonRow() { canvas.insertButtonRow() }

    /// Converts the current selection into ONE inline pill whose label is the selected text — the Link
    /// flow's analogue. No-op with a collapsed caret or an empty selection.
    public func makeSelectionInlineButton() { canvas.makeSelectionInlineButton() }

    /// Inserts one inline pill carrying `button` at the caret, replacing any selection.
    ///
    /// Composed from the verbs the canvas already has rather than a canvas-side insert: the label is
    /// typed as plain text, selected, turned into a pill by `makeSelectionInlineButton`, and the pill
    /// is then given the authored button — three undo steps where the engine editor's `insertInlineButton`
    /// costs one. An empty label is typed as a single space, so there is a run to convert; the pill
    /// itself carries the authored (empty) label, as the engine's does.
    public func insertInlineButton(_ button: ButtonRef) {
        // A code block holds plain text only, so the label goes in as text — `insertFormula`'s rule
        // (`InlineButtonInCodeTests`). A pill's U+FFFC there was read back as a raw character.
        if canvas.caretIsInCodeRegion {
            if !button.labelText.isEmpty { canvas.insertText(button.labelText) }
            return
        }
        let label = button.labelText.isEmpty ? " " : button.labelText
        guard let start = canvas.selectedTextRange?.start else { return }
        canvas.insertText(label)
        guard let end = canvas.selectedTextRange?.end,
              let range = canvas.textRange(from: start, to: end) else { return }
        canvas.selectedTextRange = range
        canvas.makeSelectionInlineButton()
        // The conversion parks the caret right after the pill, so the pill's own position is one
        // back. Read from the canonical selection, not `selectedGlobalRange()`, which answers nil
        // for exactly this collapsed caret.
        let caret = canvas.canonicalSelection.head.utf16Offset
        guard caret > 0 else { return }
        canvas.replaceInlineButton(at: caret - 1, with: button)
    }

    /// Deletes one unit before the caret (drives a custom keyboard's backspace key).
    public func deleteBackward() { canvas.deleteBackward() }

    /// A custom input view that replaces the system keyboard while the editor is first responder.
    /// Set an `EmptyInputView` to hide the keyboard while showing a separate input panel (the caret
    /// stays visible because the canvas remains first responder); `nil` restores the system keyboard.
    public var customInputView: UIView? {
        get { canvas.customInputView }
        set {
            canvas.customInputView = newValue
            if canvas.isFirstResponder {
                canvas.reloadInputViews()
            }
        }
    }

    /// Registers the closure that turns an emoji `id` (+ requested square size) into a FRESH, non-
    /// interactive view. The editor owns/positions/removes it, makes it ride scrolling, and keeps its
    /// `dynamicColor` synced to the current text color (so a template custom emoji tints to the text).
    /// Register the host's syntax highlighter. The editor detects which code blocks need highlighting,
    /// debounces, caches answers and applies them; the host only turns (language, text) into colours and
    /// calls `completion` on the main queue whenever it is ready. Answering late is expected; never
    /// answering leaves the block plain. The editor cannot do this itself — it cannot see libprisma.
    public func registerSyntaxHighlighter(
        _ provider: ((_ language: String, _ text: String,
                      _ completion: @escaping ([RichTextSyntaxToken]) -> Void) -> Void)?
    ) {
        self.canvas.syntaxHighlighter = provider
        self.canvas.scheduleSyntaxHighlightPass()
    }

    public func registerEmojiViewProvider(_ provider: @escaping (_ id: String, _ size: CGSize) -> (UIView & RichTextEmojiView)?) {
        canvas.emojiViewProvider = provider
    }

    /// Registers a host-provided formula renderer. The editor owns the inline text atom; formula parsing
    /// and drawing stay outside this package.
    public func registerFormulaRenderer(_ provider: @escaping (RichTextFormulaRenderContext) -> RichTextFormulaRenderResult?) {
        canvas.mapper.formulaRenderer = provider
        let blocks = canvas.currentBlocks()
        if !blocks.isEmpty {
            canvas.reload(blocks, width: canvas.effectiveWidth)
            performLayout(size: bounds.size)
        }
    }

    /// Registers a host-provided button type icon. The icon depends on the button's ACTION, and this
    /// package's Telegram-free model carries every action it cannot name as an opaque blob — only the
    /// host can decode that back into the action its InstantPage V2 counterpart resolves an icon from.
    ///
    /// It is geometry as much as decoration: an inline pill grows by `inlineIconReserve` to hold its
    /// icon, so registering (or not) moves the line break of any paragraph holding a button. Register it
    /// alongside the other providers, before the first reload, exactly as with the formula renderer.
    public func registerButtonIconProvider(_ provider: @escaping (ButtonAction) -> RichTextButtonIcon?) {
        canvas.mapper.buttonIconProvider = provider
        let blocks = canvas.currentBlocks()
        if !blocks.isEmpty {
            canvas.reload(blocks, width: canvas.effectiveWidth)
            performLayout(size: bounds.size)
        }
    }

    /// Called when the user taps an existing formula atom. The host presents UI and invokes `completion`
    /// with the replacement LaTeX.
    /// Asked to present the pill property sheet when a pill is tapped — for BOTH pill kinds. The
    /// completion applies the edit; passing `nil` deletes the pill (and its row, if it was the last).
    /// Mirrors `onEditFormulaRequested`. While unset, tapping a pill just places the caret.
    ///
    /// `isBlockPill` says which kind was tapped (`true` = a `pageBlockButtonRow` pill, `false` = an
    /// inline `RichText.textButton`) — the same distinction `AttributedStringMapper.buttonAttachment`
    /// and the renderer's `isInline` draw with. A host offers different properties per kind: the article
    /// editor drops the link style for a row pill, where a chrome-less button is not something an author
    /// should create, and keeps it inline (where it IS the plain-link rendering).
    public var onEditButtonRequested: ((_ button: ButtonRef, _ isBlockPill: Bool, _ completion: @escaping (ButtonRef?) -> Void) -> Void)? {
        didSet { canvas.buttonEditRequested = onEditButtonRequested }
    }

    /// Asked to present a button row's alignment/delete menu. Mirrors `onRequestTableStructuralMenu`.
    public var onRequestButtonRowMenu: ((ButtonRowMenuRequest) -> Void)? {
        didSet { canvas.buttonRowMenuRequested = onRequestButtonRowMenu }
    }

    public var onEditFormulaRequested: ((_ latex: String, _ completion: @escaping (String) -> Void) -> Void)? {
        get { canvas.formulaEditRequested }
        set { canvas.formulaEditRequested = newValue }
    }

    /// Registers a provider that builds the checklist checkbox view (host-side `CheckNode`). When unset,
    /// checklist items fall back to the Unicode glyph marker.
    public func registerChecklistMarkerViewProvider(
        _ provider: @escaping (_ checked: Bool, _ size: CGSize) -> (UIView & RichTextChecklistMarkerView)?) {
        canvas.checklistMarkerViewProvider = provider
    }

    /// Hide an emoji view when its frame is more than this far outside the viewport (default 50pt).
    public var emojiCullMargin: CGFloat {
        get { canvas.emojiCullMargin }
        set { canvas.emojiCullMargin = newValue }
    }

    /// Overscan band (points) of block views realized above/below the viewport. Negative ⇒ auto (one
    /// viewport height each side, the default). Larger = fewer pop-in flashes on fast flings, more memory.
    public var blockViewOverscan: CGFloat {
        get { canvas.blockViewOverscan }
        set { canvas.blockViewOverscan = newValue }
    }

    /// Inserts a media block (`kind`) at the caret. The host resolves `mediaID` to a view via
    /// `registerMediaViewProvider`. `naturalSize` drives the block's aspect-correct display height.
    public func insertMedia(mediaID: String, naturalSize: CGSize, kind: MediaKind, caption: [TextRun] = []) {
        canvas.insertMedia(mediaID: mediaID, naturalSize: naturalSize, kind: kind, caption: caption)
    }

    /// Inserts `document`'s blocks at the caret: the caret's block is REPLACED if it's an empty paragraph,
    /// otherwise the blocks are inserted AFTER it (never splitting it). One undo step; caret at the end.
    public func insertDocument(_ document: Document) {
        canvas.insertDocument(document)
    }

    /// Paste the richest representation on the system pasteboard at the caret (private fragment UTI → RTF →
    /// plain), via the editor's own reader + fragment splice — mirrors the built-in Paste command.
    public func pasteFromPasteboard() { canvas.paste(nil) }

    /// Registers the closure that turns a container's items (in order) into a `RichTextMediaItemView`. Called
    /// on first realization and on every items-change; the editor owns/positions/resizes/culls it. `existing`
    /// is the currently-hosted view on an items-change (nil on first realization) — the host may update it in
    /// place and return the SAME instance (surviving cells reused) or return a fresh one.
    public func registerMediaViewProvider(
        _ provider: @escaping ([MediaProviderItem], BlockID, MediaDisplayMode, RichTextMediaItemView?) -> RichTextMediaItemView?
    ) {
        canvas.mediaViewProvider = provider
    }

    /// Hide a media view when its canvas frame is more than this far outside the viewport (default 50pt).
    public var mediaCullMargin: CGFloat {
        get { canvas.mediaCullMargin }
        set { canvas.mediaCullMargin = newValue }
    }

    /// Test seam: the hosted media view for the first media block in `document`, if realized.
    func hostedMediaViewForTesting(forFirstMediaBlock document: Document) -> RichTextMediaItemView? {
        for block in document.blocks { if case let .media(m) = block { return canvas.hostedMediaViewForTesting(m.id) } }
        return nil
    }

    /// Test seam: the number of realized hosted media views.
    var hostedMediaCountForTesting: Int { canvas.hostedMediaCountForTesting }

    /// Demo helper: select from mid-way through the 2nd block to mid-way through the 3rd.
    public func selectRangeAcrossFirstTwoBodyParagraphs() {
        canvas.selectAcrossBlocks(firstIndex: 1, secondIndex: 2)
    }

    /// Demo helper: set a cross-cell selection spanning from mid-way through leaf region at
    /// `firstLeaf` to mid-way through the region at `secondLeaf` (document order). Use this to
    /// demonstrate Phase 4 continuous cross-cell selection.
    public func selectAcrossLeafRegions(firstLeaf: Int, secondLeaf: Int) {
        canvas.selectAcrossLeafRegions(firstLeaf: firstLeaf, secondLeaf: secondLeaf)
    }

    /// Demo helper: select the first table's first column (showcases the table handles + selection outline).
    public func selectFirstTableColumn() { canvas.selectFirstTableColumn() }

    /// Demo helper: tap the first hidden spoiler (drives the reveal — text shows + dust dissolves).
    public func revealFirstSpoiler() { canvas.tapFirstSpoilerForTesting() }

    /// Selects the whole STRUCTURAL range, `[0, documentSize]`.
    ///
    /// TASK 44 note, because the obvious "cleanup" here is a behaviour change: this is deliberately
    /// NOT `canvas.documentEndOffset`. That is the last RENDERABLE slot (`snapToRenderable`
    /// backwards from the close token) and is strictly less than `documentSizeValue` whenever the
    /// document ends in a structural token — `selectAllText()` (`+SelectionActions.swift`) is the
    /// renderable-bounded variant and even it falls back to the structural range for a degenerate
    /// document. The facade's Select-All has always been the structural one; the endpoints are
    /// unchanged, only the object construction moved behind the backend.
    public func selectAll() {
        canvas.setSelectedGlobalRange(from: 0, to: canvas.documentSizeValue)
    }

    /// Collapses the selection to a caret at the last renderable position (end of the document). A host uses
    /// this to target an UNFOCUSED editor's end with a subsequent format/insert command: the default caret
    /// sits at offset 0 (a structural slot that touches no paragraph), so a command applied there no-ops /
    /// lands at the start. `endOfDocument` already snaps past the closing structural token to a real slot.
    public func moveCaretToDocumentEnd() {
        // TASK 44: was `guard let end = canvas.endOfDocument as? DocumentTextPosition else { return }`
        // followed by `DocumentTextRange(end, end)`. `documentEndOffset` is that same downcast of that
        // same member, and the `guard` is preserved rather than collapsed — under the legacy backend
        // it is unreachable, but under any other one it is the difference between doing nothing (what
        // this method has always done) and jumping the caret to offset 0 (fix round 1, review Minor 2).
        // The write takes the identical `selectedTextRange` path it took before.
        guard let end = canvas.documentEndOffset else { return }
        canvas.setSelectedGlobalRange(from: end, to: end)
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool { canvas.becomeFirstResponder() }

    /// Scrolls the outer scroll view so the caret is visible (above the bottom inset; respects contentInset).
    /// Arrow-key nav drives this via `onSelectionChange` with `animated: false`: a synchronous scroll
    /// settles before the setter returns, so a rapid second arrow queries a stable layout. An ANIMATED
    /// scroll mutates `contentOffset` mid-flight, and a second arrow then computes its destination against
    /// that in-flux state → non-deterministic arrow results (the reported "random" behaviour). Only scrolls
    /// when the caret is actually outside the visible band, so in-screen nav/typing never churns the scroll.
    /// Access widened `private` → internal (Task 18) so `TelegramPresentationInputClient.requestReveal`
    /// can call it directly as the "outer vertical reveal" authority, alongside the canvas's own
    /// `scrollCaretIntoViewIfNeeded()` (table-cell horizontal reveal) — the existing two-authority split
    /// this method's doc-comment above describes is preserved verbatim, not repaired. No behavior change:
    /// every existing call site (`onSelectionChange` below) is unaffected by the wider access.
    /// The shared contract's reveal, through the solver both editors use
    /// (see the RichTextEditor `CLAUDE.md`, "The host decides when the caret is revealed"). Called from
    /// `update(…caretReveal:)` — the host's pass — and from
    /// `TelegramPresentationInputClient.requestReveal`, which is an input-backend seam rather than a
    /// host seam and is a caller like any other.
    ///
    /// `animation` is accepted and not used: legacy's reveal has always been immediate, and its own
    /// comment records why an animated one is dangerous — it mutates `contentOffset` mid-flight, so a
    /// rapid second arrow key computes its destination against in-flux state. The parameter exists so
    /// the two editors answer one contract, not so this one grows a motion it does not want.
    func revealCaret(_ animation: RichTextEditorAnimation, layoutIsCurrent: Bool = false) {
        _ = animation
        guard isCaretRevealOwed else { return }
        // Cleared whatever the outcome, including when the guards below decline: the host asked, so
        // the editor is no longer owed one.
        isCaretRevealOwed = false
        guard canvas.isFirstResponder else { return }
        // Lay the canvas out explicitly so `caretRect` + the scrollable extent reflect the latest edit
        // before we measure/scroll — the editor convention is parent-driven layout, so we don't rely on a
        // pending self-scheduled pass. Idempotent for arrow nav (content unchanged → same layout). Skipped
        // when `update` has just laid out at this size: a second full pass measured nothing new.
        if !layoutIsCurrent {
            performLayout(size: bounds.size)
        }
        var caret = canvas.caretRect(atGlobal: canvas.head)
        guard caret != .zero, !caret.isNull else { return }
        // An image-gap caret is full-image-height; its whole rect would never fit the visible band (→ always
        // scroll) and would jump/oscillate. Track a short band at its top edge instead.
        if caret.height > 64 { caret = CGRect(x: caret.minX, y: caret.minY, width: caret.width, height: 24) }
        let insets = scrollView.adjustedContentInset
        // The band's padding is what the visible height leaves, at most 12pt: in a field shorter than
        // the caret plus 24pt, a full band cannot be shown, and revealing it aligned one of ITS edges
        // and cut the caret (`ShortFieldCaretRevealTests`).
        let visibleHeight = scrollView.bounds.height - insets.top - insets.bottom
        let padding = max(0.0, min(12.0, (visibleHeight - caret.height) / 2.0))
        let target = caret.insetBy(dx: 0, dy: -padding)
        // The document's two ends are nil here: this canvas has no cheap answer for either, and its
        // reveal has always worked against the ±12 band above instead. The solver reads nil as "do
        // the ordinary minimum scroll", which is exactly legacy's behaviour — parity, not a downgrade.
        let input = RichTextCaretRevealInput(
            caret: target,
            firstLineTop: nil,
            lastLineBottom: nil,
            contentHeight: scrollView.contentSize.height,
            viewportHeight: scrollView.bounds.height,
            topInset: insets.top,
            bottomInset: insets.bottom,
            offsetY: scrollView.contentOffset.y)
        guard let offsetY = RichTextCaretRevealSolver.offsetY(for: input) else { return }
        scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: offsetY)
    }

    /// The spelling `TelegramPresentationInputClient` and this file's own selection hook still use.
    /// The spelling `TelegramPresentationInputClient` and this file's own selection hook still use.
    /// It ASKS and then reveals, because those callers are the ones doing the asking — the gate
    /// exists to stop an unrelated host layout from revealing, not to stop a deliberate request.
    func scrollCaretIntoView(animated: Bool = false) {
        _ = animated
        isCaretRevealOwed = true
        revealCaret(.immediate)
    }

    private var isSelectionOnChangeScheduled = false

    /// Coalesce the HOST `onChange` for SELECTION changes to a single trailing call per runloop turn.
    /// A backspace/replace arrives as an OS-driven non-collapsed `selectedTextRange` set followed — in the
    /// same runloop turn — by the delete that collapses it (and the delete's own content-size `onChange`,
    /// which relays SYNCHRONOUSLY and reports the settled state). Dispatched async, this fires AFTER both, so
    /// the host observes only the settled selection instead of the transient non-empty range → no toolbar
    /// "selection flare". The `scheduled` flag collapses N synchronous selection changes into one call.
    /// Content edits are unaffected (their notification is the synchronous content-size relay).
    private func scheduleSelectionDrivenOnChange() {
        if isSelectionOnChangeScheduled { return }
        isSelectionOnChangeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isSelectionOnChangeScheduled = false
            self.onChange?()
        }
    }

    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        canvas.viewportDidChange()   // realize/recycle block views + emoji + blockquote underlay for the new viewport
        #if DEBUG
        refreshDebugLayoutOverlay()   // keep block outlines tracking the scrolled content
        #endif
    }

    #if DEBUG
    /// DEBUG-only: exposes the (private) scroll content inset to the debug layout overlay.
    var debugContentInset: UIEdgeInsets { scrollView.contentInset }
    #endif

    // MARK: - Composer-host scroll accessors (internal — consumed by RichTextEditorView+ComposerHost.swift)

    var scrollViewContentOffset: CGPoint { self.scrollView.contentOffset }
}
#endif
