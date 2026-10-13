#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// A host-supplied checklist checkbox view. The editor stays `CheckNode`-free; the host builds a
/// `CheckNode`-backed view conforming to this and the editor hosts/positions/animates it.
public protocol RichTextChecklistMarkerView: AnyObject {
    func setChecked(_ checked: Bool, animated: Bool)
}

/// A host-supplied inline custom-emoji view. The editor hosts/positions/culls it and keeps its
/// `dynamicColor` synced to the current text color, so a "template" (single-color) custom emoji tints
/// to match the surrounding text (mirrors how the legacy input tints template emoji). A host whose
/// emoji is never a template can leave `dynamicColor` unused.
public protocol RichTextEmojiView: AnyObject {
    /// The tint the editor pushes for a custom *template* emoji — the current text color. `nil` means
    /// untinted. Non-template (full-color) emoji ignore it; the editor assigns it regardless.
    var dynamicColor: UIColor? { get set }
}

/// Shared factory: turns one `Block` into its `CanvasBlock` box. Used by the document root
/// (`DocumentCanvasView.setBlocks`), table cells (`TableBlockBox.init`), and — once landed —
/// `BlockQuoteBox` (Task 4), so all three build children through one recursive function.
///
/// - Parameters:
///   - quoteStyle:     The canvas-level `QuoteStyle`; ignored by cell callers (default is fine).
///   - pullQuoteStyle: The canvas-level `PullQuoteStyle`; ignored by cell callers.
///   - expandImage:    The expand icon for `BlockQuoteBox`; nil when irrelevant.
///   - horizontalBleed: Media bleed beyond the content strip; 0 for table cells.
@available(iOS 13.0, *)
func makeBox(for block: Block, mapper: AttributedStringMapper,
             quoteStyle: QuoteStyle = .default, pullQuoteStyle: PullQuoteStyle = .default,
             expandImage: UIImage? = nil, collapseImage: UIImage? = nil,
             horizontalBleed: CGFloat = 0, width: CGFloat) -> CanvasBlock? {
    switch block {
    case .paragraph(let p):      return BlockBox(paragraph: p, mapper: mapper, width: width)
    case .media(let img):        return MediaBlockBox(media: img, mapper: mapper, width: width,
                                                      horizontalBleed: horizontalBleed)
    case .table(let t):          return TableBlockBox(table: t, mapper: mapper, width: width)
    case .code(let c):           return CodeBlockBox(code: c, mapper: mapper, width: width)
    case .pullQuote(let pq):     return PullQuoteBox(pullQuote: pq, mapper: mapper,
                                                     pullQuoteStyle: pullQuoteStyle, width: width)
    case .blockQuote(let bq):   return BlockQuoteBox(blockQuote: bq, mapper: mapper,
                                                      quoteStyle: quoteStyle,
                                                      pullQuoteStyle: pullQuoteStyle,
                                                      expandImage: expandImage,
                                                      collapseImage: collapseImage, width: width)
    case .details(let d):        return DetailsBox(details: d, mapper: mapper,
                                                   quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle,
                                                   expandImage: expandImage,
                                                   collapseImage: collapseImage, width: width)
    case .buttonRow(let r):      return ButtonRowBox(row: r, mapper: mapper, width: width)
    }
}

/// The multi-block document surface. ONE view owns every block and the unified global selection.
/// (Internal — only `RichTextEditorView` is public; keeps `UITextInput` witnesses internal.)
@available(iOS 13.0, *)
final class DocumentCanvasView: UIView {
    let root = BlockStack()
    var boxes: [CanvasBlock] { get { root.boxes } set { root.boxes = newValue } }
    var mapper: AttributedStringMapper
    /// The whole-document writing-direction override (the model side of `applyWritingDirectionOverride`).
    /// Mirrored into `Document.layoutDirection` by the façade getter; render-only auto-detection is separate.
    var layoutDirectionModel: DocumentLayoutDirection = .auto
    var imageProvider: (String) -> UIImage? = { _ in nil }
    /// Returns a FRESH, non-interactive view for an emoji `id` sized to the requested square, or nil.
    /// The canvas owns/positions/removes it and keeps its `dynamicColor` synced to the current text color
    /// (template-emoji tinting); a host with only a CALayer wraps it in a conforming `UIView`.
    var emojiViewProvider: (_ id: String, _ size: CGSize) -> (UIView & RichTextEmojiView)? = { _, _ in nil }
    /// Returns a FRESH checkbox view for a checklist marker (host-side `CheckNode`). `nil` when unset —
    /// the editor falls back to the Unicode glyph marker. The canvas hosts/positions/animates the view.
    var checklistMarkerViewProvider: ((_ checked: Bool, _ size: CGSize) -> (UIView & RichTextChecklistMarkerView)?)?
    /// Host hook for editing a formula atom. The editor supplies current LaTeX and a replacement callback;
    /// the host owns presentation and formula rendering dependencies.
    var formulaEditRequested: ((_ latex: String, _ completion: @escaping (String) -> Void) -> Void)?
    /// Asked to present the pill property sheet. `isBlockPill` distinguishes a row pill from an inline
    /// one (the host offers different properties per kind). The completion applies the edit; `nil`
    /// deletes the pill.
    var buttonEditRequested: ((_ button: ButtonRef, _ isBlockPill: Bool, _ completion: @escaping (ButtonRef?) -> Void) -> Void)?
    /// Asked to present a row's alignment/delete menu.
    var buttonRowMenuRequested: ((ButtonRowMenuRequest) -> Void)?
    /// Hosted emoji views, keyed by `EmojiRef.instanceID` so edits/undo reuse (not recreate) them.
    /// Plain `internal` (NOT `private(set)`): the reconciler in `DocumentCanvasView+Emoji.swift` mutates it.
    var emojiViews: [String: HostedEmoji] = [:]
    /// Hosted checklist checkbox views, keyed by the owning `BlockBox`'s `BlockID`. Pooled so a toggle
    /// reuses (and animates) the existing view rather than recreating it.
    var checklistMarkerViews: [BlockID: HostedChecklistMarker] = [:]
    /// Back-most container for blockquote run fills (see `BlockquoteUnderlay`). Behind every block view.
    let blockquoteUnderlay = BlockquoteUnderlay()
    /// Back-most container for pull-quote pill fills — a second `BlockquoteUnderlay` instance with
    /// `barWidth = 0` (no leading bar, symmetric rounded pill). Behind every block view, alongside the
    /// blockquote underlay.
    let pullQuoteUnderlay = BlockquoteUnderlay()
    /// Non-interactive overlay hosting an opening (top-left) and closing (bottom-right, rotated 180°)
    /// quote-mark image view per pull-quote pill, tinted to the accent. Purely decorative; all touches
    /// fall through to the canvas (`isUserInteractionEnabled = false`).
    let pullQuoteMarksView = PullQuoteMarksView()
    /// Non-interactive container for body/caption emoji views (canvas coords). Kept below the chrome
    /// overlay (which is brought to front each layout pass). Cell emoji live in the table content view.
    let emojiOverlay = UIView()
    /// Hide an emoji view when its canvas frame is more than this far outside the visible viewport.
    var emojiCullMargin: CGFloat = 50
    /// Returns a media view for a container's items (in order), or nil. The canvas owns/positions/
    /// resizes/removes it. Mirrors `emojiViewProvider` but for block-level media; carries the whole item
    /// list (not just the primary item) so a multi-media container's host view can render every item.
    /// `existing` is the currently-hosted view for this block on an items-change (nil otherwise); the host
    /// may update it IN PLACE and return the SAME instance (surviving cells reused, fetch preserved) or
    /// return a fresh instance (recreate fallback). Returns nil = "not ready" (keep any existing view).
    var mediaViewProvider: (_ items: [MediaProviderItem], _ blockID: BlockID, _ displayMode: MediaDisplayMode, _ existing: RichTextMediaItemView?) -> RichTextMediaItemView? = { _, _, _, _ in nil }
    /// Hosted media views, keyed by the OWNING block's `BlockID` (the occurrence) so edits/undo reuse —
    /// not recreate — them, and two blocks sharing one `mediaID` get two independent views.
    var mediaItemViews: [BlockID: HostedMediaItem] = [:]
    /// Pass-through container for media views (canvas coords). Kept below the chrome overlay; above block
    /// backing views so a full-bleed medium overlays its block. It is user-interaction-ENABLED but its
    /// `hitTest` returns a subview only when the touch lands on an interactive media control (e.g. the
    /// more button) — otherwise nil, so the touch falls through to the canvas's own tap handling. See
    /// `MediaPassthroughOverlayView`.
    let mediaOverlay = MediaPassthroughOverlayView()
    /// Hide a media view when its canvas frame is more than this far outside the visible viewport.
    var mediaCullMargin: CGFloat = 50
    /// Pooled dust views, keyed by spoiler-run identity so a hidden run keeps its animating emitter across
    /// reconcile passes. Mutated by the reconciler in `DocumentCanvasView+Spoilers.swift`.
    var spoilerDustViews: [SpoilerKey: HostedSpoilerDust] = [:]
    /// The spoiler runs found by the last `syncSpoilers` (hidden-state + canvas rects). Drives the tap
    /// hit-test. Recomputed each pass; never persisted.
    var spoilerRuns: [SpoilerRun] = []
    /// Set by a tap on a hidden spoiler so the next reconcile plays the EXPLOSION (vs a cross-fade) for that
    /// run, from the tap point. Consumed + cleared in one pass.
    var spoilerRevealHint: (key: SpoilerKey, canvasPoint: CGPoint)?
    /// Non-interactive container for body/caption dust views (canvas coords), above emoji, below the wash.
    /// Cell dust rides the table content view (like cell emoji).
    let spoilerOverlay = UIView()
    /// Hide a dust view when its canvas frame is more than this far outside the visible viewport.
    var spoilerCullMargin: CGFloat = 50
    /// True iff some leaf region currently carries a `.rtSpoiler` run. A cheap gate so `syncSpoilers` (which
    /// runs on every caret move) does NO work in a spoiler-free document. Recomputed only when the model
    /// changes (load / edit / undo) — never on a pure selection change.
    var documentHasSpoilers = false
    /// Overscan band (points) realized above AND below the visible viewport, so scrolling reveals an
    /// already-drawn paragraph instead of a blank flash. NEGATIVE (the default) ⇒ auto = one viewport
    /// height each side. Tunable via the façade (`RichTextEditorView.blockViewOverscan`).
    var blockViewOverscan: CGFloat = -1
    /// Persistent block-view subviews, keyed by BlockID so edits/undo reuse (not recreate) them.
    private(set) var blockViews: [BlockID: BlockBackingView] = [:]
    /// Hosted INLINE button pills, keyed by global position (see `syncButtonPillViews`). A block row's
    /// pills are not here — they are subviews of the row's own `ButtonRowBackingView`.
    var buttonPillViews: [Int: HostedButtonPill] = [:]
    /// Bounded reuse queue of free PARAGRAPH/IMAGE backing views (both plain `BlockBackingView`). A culled
    /// view is detached + dropped from `blockViews` and pushed here; a newly-realized paragraph/image pops
    /// it and rebinds. Tables (`TableBackingView`) are heavyweight + few, so they are created/destroyed,
    /// not queued. Excess beyond the cap is released.
    private var recycleQueue: [BlockBackingView] = []
    private let recycleQueueCap = 24   // ~2–3 screenfuls of paragraphs at typical heights; excess freed views are released
    /// Topmost overlay that draws table structural chrome (outline, handles, knobs) ABOVE the block views.
    private let blockChromeOverlay = BlockChromeOverlay()
    /// Dedicated overlay that draws the selection highlight + image washes ON TOP of all non-table content
    /// (text, emoji, image atoms) — above the emoji overlay, below the chrome. Table-cell highlights ride
    /// their own content-view overlay (`CellSelectionView`) to keep horizontal overscroll.
    let selectionHighlight = SelectionHighlightView()

    /// The app's own blinking text caret (the canvas installs no `UITextSelectionDisplayInteraction`, so
    /// there is no OS caret). When the caret is inside a horizontally-scrollable table cell it's reparented
    /// into that table's scrolling content view so it rides the scroll/overscroll; otherwise it's a direct
    /// subview of the canvas.
    let caretView = CaretView()
    /// The own-rendered FLOATING caret for the spacebar-trackpad gesture (see DocumentCanvasView+FloatingCursor).
    let transientCaretView = TransientCaretView()
    /// Own-drawn selection-handle lollipops (one per endpoint), shown for a ranged selection. Like the
    /// caret, each is hosted in the canvas or a table's scrolling content view per its endpoint's region,
    /// ON TOP of the wash. The handle DRAG is a separate proximity-gated pan (`isSelectionDragTouch`).
    let startHandleView = SelectionHandleView(isStart: true)
    let endHandleView = SelectionHandleView(isStart: false)
    /// Host hook to configure each selection-handle ("knob") view — e.g. to set Display's
    /// `disablesInteractiveModalDismiss` / `disablesInteractiveKeyboardGestureRecognizer` so a knob drag isn't
    /// hijacked by the interactive modal/keyboard-dismiss gestures. The package can't import Display, so the
    /// host applies the flags; the handle views are hit-testable so the flags are scoped to knob interaction.
    /// Applied to BOTH handle views (passed as bare `UIView`s) when set.
    var configureSelectionHandleView: ((UIView) -> Void)? {
        didSet {
            configureSelectionHandleView?(startHandleView)
            configureSelectionHandleView?(endHandleView)
        }
    }
    /// The container + frame the caret view was last placed at, so a repeated `updateCaretView()` (e.g. on a
    /// scroll tick) that lands the caret at the SAME spot does NOT restart the blink.
    private weak var lastCaretContainer: UIView?
    private var lastCaretFrame: CGRect = .null

    /// Fired by `notifyContentSizeChanged()` whenever the content height may have changed (after an
    /// edit/undo/IME/document-swap). The host (`RichTextEditorView`) sizes the canvas frame-based, not via
    /// Auto Layout, so the canvas does NOT lay itself out — it notifies through this hook and the parent
    /// drives layout explicitly (`performLayout` → `layoutContent`).
    var onContentSizeChange: (() -> Void)?
    /// Fired whenever the caret moves to a spot the host may need to reveal: the OS moving the selection
    /// through the `selectedTextRange` setter (hardware arrow navigation), and every editing operation
    /// that relocates the caret (typing, delete, Enter, IME-composition commit — via `editing { }` and the
    /// marked-text branch). The host uses it to scroll the caret into view, since these can land the caret
    /// off-screen (arrowing up out of a tall image; typing the line below the keyboard).
    var onSelectionChange: (() -> Void)?
    /// Fired once when the canvas actually GAINS first-responder status (not on a repeat
    /// `becomeFirstResponder()` while already focused — the tap handlers call it unconditionally). The
    /// host surfaces this as `RichTextEditorView.onBecameFirstResponder`.
    var onBecameFirstResponder: (() -> Void)?
    /// Fired once when the canvas actually RESIGNS first-responder status. Surfaced as
    /// `RichTextEditorView.onResignedFirstResponder`.
    var onResignedFirstResponder: (() -> Void)?
    /// Pasting MEDIA (image/gif/video/sticker) is a host concern — the editor never embeds it inline.
    /// `canPasteMedia` answers whether Paste should be offered for the current pasteboard (so the menu item
    /// shows for an image-only clipboard); `onPasteMedia` performs the media paste (routing to the host's
    /// send flow) and returns whether it consumed the paste. Consulted only when there is no TEXT rep — the
    /// editor pastes text (fragment/RTF/plain) itself.
    var canPasteMedia: (() -> Bool)?
    var onPasteMedia: (() -> Bool)?
    var plainTextFragmentTransformer: ((String) -> Document?)?

    /// A HARDWARE-keyboard Return (plain or ⌘) routes here before the editor inserts a newline, so a host
    /// (the chat composer) can send-on-Enter / send-on-⌘-Enter. Mirrors the legacy `ChatInputTextViewImpl`'s
    /// `shouldReturn`. Return `true` to have the editor insert a newline (the default when unset — standalone
    /// editors like the article composer and Demo just add a line); `false` means the host consumed the Return
    /// (e.g. sent the message) and the editor does nothing. The SOFTWARE keyboard's Return never triggers a
    /// keyCommand, so it always inserts a newline (there's a separate send button) — matching the legacy input.
    var onHardwareReturn: ((UIKeyModifierFlags) -> Bool)?

    /// Interior content margins — interactable padding around the document, ADDED to the built-in
    /// `pageMargin`. Unlike the host's scroll insets (covered by chrome/keyboard, content scrolls under),
    /// these are PART of the content: the text lays out inset by them (so it wraps narrower and is offset
    /// from the canvas edges), the content height grows by top+bottom, and the margin area still hit-tests
    /// to the nearest text position. Applied by `RichTextEditorView.update(size:insets:contentMargins:)`
    /// (a layout-affecting input, passed every update); default `.zero`. A plain stored value: the `update`
    /// that sets it re-runs `performLayout`, which lays the canvas out EXPLICITLY (`layoutContent()`), so the
    /// setter neither schedules layout itself nor fires `onContentSizeChange`/`onChange`.
    var contentMargins: UIEdgeInsets = .zero

    /// The built-in horizontal page margin applied to paragraph/table text (in addition to `contentMargins`).
    /// Defaults to the document metric (`CanvasMetrics.pageMargin`, 16pt); a compact host (e.g. the chat
    /// composer) can set it to 0 so the host controls all horizontal insets via the frame + `contentMargins`.
    /// Media bleed is governed separately by `mediaBlockStyle` / `applyMediaBlockStyle`.
    var pageMargin: CGFloat = CanvasMetrics.pageMargin

    /// The base inter-block vertical inset for the document root (each side). Defaults to the document
    /// metric (`BlockBox.defaultVerticalInset`, 8pt); a compact host (the chat composer) sets it to 0 so a
    /// single paragraph hugs its text height instead of carrying the inter-paragraph gap. Applied to the
    /// root stack in `layoutContent`; nested (table-cell) stacks keep the document default.
    var blockVerticalInset: CGFloat = BlockBox.defaultVerticalInset

    /// Per-host media geometry. Applied via `applyMediaBlockStyle(_:)`; read at `MediaBlockBox` creation
    /// in `setBlocks` / `insertMedia`. Defaults to the document edge-to-edge look.
    var mediaBlockStyle: MediaBlockStyle = .default

    /// Per-host quote geometry. Applied via `applyQuoteStyle(_:)` (rebuilds the mapper stylesheet + pushes
    /// render values to the underlay).
    var quoteStyle: QuoteStyle = .default

    /// Per-host pull-quote geometry. Applied via `applyPullQuoteStyle(_:)` (pushes corner radius + fill alpha
    /// to the underlay). Read by `pullQuotePillRects()` / `pullQuoteMarkRects()` for the pill + mark geometry.
    var pullQuoteStyle: PullQuoteStyle = .default

    /// Per-host code-block geometry. Applied via `applyCodeStyle(_:)`, which resolves its optionals
    /// against the shared render metrics (`StyleSheet.metrics.code`) — so an unset host renders what
    /// the InstantPage V2 renderer will.
    var codeStyle: CodeStyle = .default

    /// Host-injected collapse/expand icons (nil ⇒ no affordance drawn). The `collapse` image goes to
    /// `BlockQuoteBox`; the `expand` image likewise.
    var quoteCollapseIcons: RichTextEditorQuoteCollapseIcons?

    /// Host-injected fold chevron for detail blocks (the V2 `ExpandingItemVerticalRegularArrow`). Stamped onto
    /// each top-level `DetailsBox` during layout; `nil` ⇒ a drawn-arrow fallback.
    var detailsChevronImage: UIImage?

    /// Placeholder strings drawn in empty paragraphs. Stamped onto each top-level box during layout.
    /// Defaults to the editor's built-in hints; a compact host (chat composer) sets them to "" to suppress
    /// the editor's placeholder (it draws its own). Applied on the next layout pass.
    var placeholders: RichTextEditorPlaceholders = .default

    /// Whether a tap in the empty area below the document's last block appends a new empty body paragraph
    /// after it (`insertEmptyBodyParagraph`). Defaults to `true` (the full-page document editor: lets you
    /// always start a normal paragraph below the final block, whatever its type). A compact host (the chat
    /// composer) sets it to `false` — there is no "empty area below the content" to grow into, so a tap there
    /// just places the caret in the existing trailing paragraph.
    var tapBelowAddsTrailingParagraph = true

    // Selection as global UTF-16 positions; `anchor` fixed, `head` moving.
    //
    /// **READ-ONLY PROJECTIONS OF THE BACKEND'S CANONICAL SELECTION — TASK 40b closes Phase 5.**
    /// These were the canvas's own storage (`var anchor = 0` / `var head = 0`) until Task 35, then
    /// read/write forwarders for the length of the phase, and are now GET-ONLY computed projections
    /// of the ONE store, `LegacyRichTextInputBackend.canonicalSelectionStorage`, reached through the
    /// `RichTextInputBackend` contract members `canonicalSelectionAnchorOffset` /
    /// `canonicalSelectionHeadOffset` (deviation D33 — `inputBackend` is typed
    /// `any RichTextInputBackend`, so nothing declared only on the concrete class is reachable here).
    /// Spec hard invariant 3: **the backend is the only input-state authority.**
    ///
    /// **WHAT THE COMPILER ACTUALLY ENFORCES, stated precisely because the imprecise version was
    /// wrong** (Task 40b fix round 1). This paragraph read "there is no canvas-side way to write a
    /// selection at all", and the review falsified it fifteen lines further down its own comment:
    /// door 3 below IS a canvas-side way to write a selection, with seven live call locations, and
    /// the reviewer demonstrated a second by planting
    /// `(inputBackend as? LegacyRichTextInputBackend)?.canonicalSelectionStorage = …` in a canvas
    /// file — it compiles. What the compiler enforces is narrower and still worth having:
    /// **the canvas has no selection STORE and no writable selection PROPERTY.** Nothing here holds a
    /// copy that can drift, and no `v.anchor = …` exists to be written by accident. The remaining
    /// ways in are deliberate, named, and now enumerated by a test rather than by a wish.
    ///
    /// **HOW A SELECTION IS WRITTEN NOW, since deleting a setter deletes the obvious answer.** Three
    /// doors, in order of preference. Doors 1 and 3 have EXACT per-file caller allowances in
    /// `InputBackendSourceBoundaryTests.test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated`, so
    /// widening either costs an edit to a constant — the sentences below used to be advice with no
    /// mechanism behind them:
    ///   1. `inputBackend.setSelection(_:reason:)` — the publishing one, and the only one that
    ///      reports to the host. Package-wide there is exactly ONE call to it in `Sources/`
    ///      (`LegacyRichTextInputBackend.swift`); a second one is a decision, not a detail.
    ///   2. Return a `RichTextInputCaretOutcome` claim from an editing transaction and let
    ///      `applyCaretOutcome` (`+Editing.swift`) apply it — the route Tasks 36a-36c put all 30
    ///      converted caret writes through, and the right answer for anything inside `editing { }`.
    ///      The encouraged door, and deliberately the only unlimited one.
    ///   3. `inputBackend.setCanonicalAnchor(_:)` / `setCanonicalHead(_:)` — the raw, non-publishing,
    ///      unguarded D33 pair. SEVEN call locations, four of them structural
    ///      (`legacyApplyMutation`'s seat-before-dispatch lines); read their contract at the
    ///      declaration before adding an eighth. (Seven LOCATIONS is fourteen CALLS — each writes
    ///      both endpoints — and the test counts calls. The unit has misled this branch four times;
    ///      it is spelled out at the assertion.)
    ///
    /// There is no door 4. Reaching `canonicalSelectionStorage` or `markedRangeStorage` through a
    /// concrete downcast is a second writable authority that read-only projections cannot prevent and
    /// the R7 write scan cannot see (it is `.`-qualified), so the same test forbids naming either
    /// outside `S/InputBackend/` — absolute zero, no allowance.
    ///
    /// **TASK 42 CLOSED THAT DOOR AT ITS THROAT rather than one store at a time.** The per-store list
    /// only reaches stores with a distinct `…Storage` name; Task 42's three (`floatingCursorActive`,
    /// `floatingCursorPoint`, `floatingScrollVelocity`) share their names with the projections below,
    /// so no blunt name scan can cover them. The same test therefore also holds the CONCRETE backend
    /// type to exactly ONE mention outside `S/InputBackend/` — `init`'s
    /// `inputBackend ?? LegacyRichTextInputBackend()`, further down this file. With no second mention
    /// there is no downcast, and so no reachable store, for any of them. **Red-checked** by planting
    /// `(inputBackend as? LegacyRichTextInputBackend)?.floatingCursorPoint = .zero` in
    /// `+FloatingCursor.swift`: it compiles (the door was real) and the rule names the file.
    ///
    /// **THE SETTERS ARE GONE, and their deletion cost nothing.** Task 35 made them deprecated so the
    /// ~1000 pre-seam write sites kept compiling; the deprecation warning WAS the Phase-5 conversion
    /// worklist, driven to zero by Tasks 36a-39 (`Sources/`) and Task 40a (`Tests/`), which then
    /// flipped both accessors to `@available(*, unavailable)` — a compile-time proof that no writer
    /// remained anywhere. This commit deletes them, and the package builds with **no other edit in
    /// `Sources/` or `Tests/`**, which is that proof cashed in.
    ///
    /// **THE `-warnings-as-errors` PROHIBITION IS RETIRED HERE.** For the length of Phase 5 this
    /// comment (and a matching note in the package's `BUILD`) told anyone tidying that file NOT to
    /// add a `copts` attribute, because it would turn the deprecation worklist into build errors and
    /// strand the phase mid-conversion. There is no worklist any more: these accessors emit zero
    /// warnings and have zero writers. Adding `-warnings-as-errors` to match the 676 sibling `BUILD`
    /// files is now an ordinary change, and the `BUILD` note has been retired in the same commit.
    ///
    /// **PERFORMANCE — Task 40b's static half, done; the on-device half, OWED.** Each read is one
    /// witness-table indirect call plus two stored-field loads (`RichTextInputPosition` is a plain
    /// struct): no allocation, no enum switch, no snapshot build. Task 35's review audited the 937
    /// `anchor|head|selFrom|selTo` mentions under `Sources/` and found no per-glyph or per-line loop
    /// re-reading a forwarder; **Task 40b re-ran that audit against the finished tree and confirms
    /// it** — the per-frame readers (`refreshSelectionUI()` → `updateCaretView()` /
    /// `updateSelectionHandleViews()` / `syncSpoilers()`) read a handful of times and pass the values
    /// DOWN as parameters. Exactly FOUR loop bodies read a projection per iteration —
    /// `selectionIsTextOnly` (`+State.swift`), `changeListLevel` (`+Indent.swift`), `setAlignment`
    /// (`+ParagraphFormat.swift`) and `activeTable` (`+Tables.swift`) — and every one of them
    /// iterates top-level BOXES (tens, not thousands); three are user-initiated command handlers, not
    /// per-frame work. So the expected cost is tens of extra indirect calls per selection change.
    /// **The autorepeat typing-latency comparison against a pre-Phase-5 baseline was NOT run and is
    /// owed** — it needs a device/simulator, which the session that landed this could not drive. If
    /// it ever comes back dirty, the fix is NOT a cached copy of either endpoint on the canvas (that
    /// second store is the thing Phase 5 exists to remove) — it is a batched read at the top of the
    /// affected function.
    var anchor: Int { inputBackend.canonicalSelectionAnchorOffset }

    /// The moving endpoint. See `anchor` immediately above for the whole rule — deliberately not
    /// restated here.
    var head: Int { inputBackend.canonicalSelectionHeadOffset }

    // Floating cursor (spacebar-trackpad) gesture state — see DocumentCanvasView+FloatingCursor.swift.
    //
    /// **READ-ONLY PROJECTIONS OF THE BACKEND'S FLOATING-CURSOR STATE — TASK 42.** These three were the
    /// canvas's own storage until this task, in parallel with a backend copy of the flag that Task 22e
    /// added and Task 33 made the real gesture's; there is now ONE store, on the backend, reached
    /// through the `RichTextInputBackend` contract members `floatingCursorActive` /
    /// `floatingCursorPoint` / `floatingScrollVelocity` (deviation D33 — `inputBackend` is typed
    /// `any RichTextInputBackend`, so nothing declared only on the concrete class is reachable here).
    /// Spec hard invariant 3: **the backend is the only input-state authority.**
    ///
    /// **`floatingCursorActive` carried TWO jobs under one name until this task, and the merge is what
    /// makes the sentence below true:** the canvas's copy was the PRESENTATION flag (the dimmed landing
    /// caret in `updateCaretView()`, `floatingAutoScrollTick`'s guard) while the backend's was the
    /// SUPPRESSION flag the `selectedTextRange` setter consults. One store now serves both, so a cancel
    /// path can no longer clear one and leave the other latched.
    ///
    /// **HOW THIS STATE IS WRITTEN NOW.** Three doors, all raw and non-publishing, each held to an
    /// EXACT per-file call-site count by
    /// `InputBackendSourceBoundaryTests.test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated` — the R7
    /// write scan cannot see any of them, because it has no `.`-qualified form:
    ///   1. `inputBackend.setFloatingCursorActive(_:)` — **3 calls**, in `legacyBeginFloatingCursor`,
    ///      `legacyEndFloatingCursor` and `cancelFloatingCursor()` (`+FloatingCursor.swift`);
    ///   2. `inputBackend.setFloatingCursorPoint(_:)` — **3 calls**, in `legacyBeginFloatingCursor`,
    ///      `legacyUpdateFloatingCursor` and `floatingAutoScrollTick`;
    ///   3. `inputBackend.setFloatingScrollVelocity(_:)` — **2 calls**, in
    ///      `updateFloatingAutoScroll(viewportY:)` and `stopFloatingAutoScroll()`.
    /// The backend ALSO writes the flag itself, at six of its own members; that list lives at the
    /// store's declaration (`LegacyRichTextInputBackend.swift`) and is not restated here.
    ///
    /// **There is no downcast door for these three, and it took a different mechanism to say so.**
    /// Unlike `canonicalSelectionStorage`/`markedRangeStorage`, the backend's stores share their names
    /// with these projections (a stored `var` satisfies the protocol's `{ get }` directly), so the
    /// per-store name scan cannot cover them. The same test instead holds the CONCRETE backend type to
    /// one mention outside `S/InputBackend/` — see the `anchor` doc above.
    var floatingCursorActive: Bool { inputBackend.floatingCursorActive }

    /// The last raw floating point (canvas coords). See `floatingCursorActive` immediately above for
    /// the whole rule — deliberately not restated here.
    var floatingCursorPoint: CGPoint { inputBackend.floatingCursorPoint }

    /// **THE ONE THAT DOES NOT MOVE, AND MUST NOT.** A `CADisplayLink` RETAINS ITS TARGET, and
    /// `willMove(toWindow:)` is its only teardown — the Task-6 retain cycle
    /// `WindowDetachCharacterizationTests` exists to guard. A link owned by the backend would outlive
    /// the view it scrolls. The backend owns the STATE; this canvas owns the link, and starts/stops it
    /// from the same two bodies it always did.
    var floatingScrollLink: CADisplayLink?

    /// The per-tick auto-scroll step. A read-only projection like the two above.
    ///
    /// **"No link ⇒ no velocity" is why `stopFloatingAutoScroll()` writes BOTH halves**: the link above
    /// is canvas storage and this is a backend door call, so the invariant would straddle the seam if
    /// the two writes were separated. They are not — both stay in that one body. Pinned by
    /// `FloatingCursorStateAuthorityTests.test_stoppingTheAutoScrollClearsTheLinkAndTheVelocityTogether`.
    var floatingScrollVelocity: CGFloat { inputBackend.floatingScrollVelocity }

    /// Last non-zero width laid out; used to rebuild boxes during undo (extensions can't add
    /// stored properties, so it lives here).
    var lastLayoutWidth: CGFloat = 0
    var effectiveWidth: CGFloat { lastLayoutWidth > 0 ? lastLayoutWidth : (bounds.width > 0 ? bounds.width : 320) }

    func clampGlobal(_ n: Int) -> Int { min(max(n, 0), documentSize) }

    /// Resolves a global position to the box that owns it, snapping structural-boundary and
    /// end-of-document positions to the nearest in-text position. Returns the box, the local
    /// UTF-16 offset, and the box's index.
    func resolveBox(at pos: Int) -> (box: CanvasBlock, local: Int, index: Int)? {
        if let (b, l) = box(containingGlobal: pos), let i = boxIndex(of: b) { return (b, l, i) }
        for (i, b) in boxes.enumerated() {
            if pos < b.textStart { return (b, 0, i) }
            if pos <= b.textStart + b.textLength { return (b, pos - b.textStart, i) }
        }
        if let last = boxes.last { return (last, last.textLength, boxes.count - 1) }
        return nil
    }
    private(set) var documentSize = 0

    /// Monotonic count of document CONTENT mutations. Observation-only until the input backend reads
    /// it (Phase 2): a counter with no readers cannot change behavior. Bumped at exactly five SITES —
    /// `editing(coalescing:_:)`, `setBlocks(_:width:)`, `setMarkedText(_:selectedRange:)`,
    /// `dismissPrediction()`, and `insertText`'s marked-commit branch. Deliberately NOT hooked into
    /// `recomputeSpans()`, which also runs for the layout-only `setParagraphsWidthIfNeeded(_:)`.
    ///
    /// Five sites is NOT five bumps per logical mutation: two production paths call `setBlocks` from
    /// inside `editing { }` and therefore bump TWICE — `replaceRange(globalFrom:globalTo:with:)`
    /// (+Editing.swift:840-846) and `pasteFragment` / `pasteMarkdownTwoStep` step 1 via
    /// `spliceFragmentInEditing` (+Clipboard.swift:107,170 → :133,:140). That is deviation D31:
    /// the contract is "strictly increasing per content mutation", never "exactly one per mutation".
    /// `DocumentRevisionTests` pins both counts. Do not add an `editing`-depth flag to suppress the
    /// inner bump — a second piece of transaction state on the canvas is what Phase 5 exists to remove.
    private(set) var documentRevision: UInt64 = 0

    /// Monotonic count of changes that can move geometry, including changes that are not document
    /// mutations (layout passes, viewport scroll, table horizontal scroll). Over-counting is allowed:
    /// the counter is only ever compared for equality.
    private(set) var layoutGeneration: UInt64 = 0

    /// Records a document content mutation. Content changes geometry, so this bumps both counters.
    func bumpDocumentRevision() {
        documentRevision &+= 1
        layoutGeneration &+= 1
    }

    /// Records a geometry-affecting change that is NOT a document mutation.
    func bumpLayoutGeneration() {
        layoutGeneration &+= 1
    }

    /// TASK 39b — the HOST-ORIGINATED document-change bracket.
    ///
    /// Captures the revision, runs `body`, then hands the backend the delta with an EXPLICIT
    /// `RichTextMarkedTextPolicy`. The spec forbids expressing a host-originated change as a
    /// counterfeit keyboard mutation, and requires the synchronization to happen BEFORE the new
    /// document is published visually — so the caller's own notification/publication work stays
    /// AFTER this returns.
    ///
    /// **It goes on ORIGINATION POINTS, never on `setBlocks(_:width:)`.** That primitive has six
    /// callers and only two are host-originated (`reload`, `registerUndo`'s restore); `+Clipboard`'s
    /// two paste splices and `replaceRange` all run inside `editing { }` and are KEYBOARD mutations,
    /// so a bracket there would fire a counterfeit EXTERNAL change — the mirror of what the spec
    /// forbids. Pinned by `ExternalSynchronizationTests`' four negative controls, three of which
    /// reach `setBlocks` (a plain-keystroke control alone cannot: it never gets there).
    func synchronizingExternalChange(reason: RichTextInputExternalChangeReason,
                                     markedTextPolicy: RichTextMarkedTextPolicy,
                                     changedRangeBefore: NSRange? = nil,
                                     changedRangeAfter: NSRange? = nil,
                                     _ body: () -> Void) {
        // **`oldRevision` IS THE BACKEND'S OWN ADOPTED BASELINE, NOT THIS CANVAS'S COUNTER — and the
        // brief specified the canvas's. That version was BUILT AND MEASURED before this one was
        // written, and it traps.**
        //
        // The premise behind reading `documentRevision` here is that the two counters agree by
        // construction, the backend's being "a cached adoption" of the canvas's. They do not agree,
        // and the reason is structural rather than incidental: `LegacyRichTextInputBackend
        // .documentRevision` has exactly four writers, and in a real (non-fixture) canvas only ONE of
        // them ever runs. `installInitialState` seeds it at `attach(to:)` — which happens inside
        // `DocumentCanvasView.init`, before any content exists, so it seeds ZERO.
        // `ensureCanonicalSelectionIsCurrent` and `runMutation` (`+Mutation.swift`) both hang off
        // `prepareAndRun`, and no routed witness calls that: `insertText`, `deleteBackward`,
        // `replace(_:withText:)`, `setMarkedText`/`unmarkText` are all PLAIN D24 forwards to the
        // canvas (that method's own reentry-ledger note says so in as many words). The fourth is
        // `synchronizeAfterExternalChange` itself, which had no production caller at all until this
        // task. So the canvas counter advances on every edit and the backend's stays at 0.
        //
        // MEASURED, not inferred, on a real-backend canvas: after `setParagraphs` + one `insertText` +
        // one `reload`, `canvas.documentRevision` reads 1, 2, 3 while `inputBackend.state
        // .documentRevision` reads 0, 0, 0. With the canvas counter passed as `oldRevision` the
        // continuity guard (`change.oldRevision == documentRevision`) rejects the change, and
        // `RichTextInputContractViolation.report` is an `assertionFailure` in DEBUG: the first probe
        // that ran it produced `Fatal error: … revision continuity violated — change describes
        // oldRevision 1 → newRevision 2, but this backend has adopted 0` and killed the xctest process.
        // In a DEBUG app that is a crash on the first formatting toggle after a keystroke.
        //
        // Reading the backend's baseline is not a way of dodging the guard, it is what continuity
        // MEANS from the backend's side: "you are at X, the document is now at Y — adopt it". Nothing
        // is being misdescribed, because these five sites pass NO `changedRangeBefore`/`After`, so
        // there is no baseline-relative diff for a stale baseline to invalidate — which is the precise
        // hazard the guard's own comment says it exists to catch. And the call is a strict improvement
        // on today: `synchronizeAfterExternalChange` ADOPTS `newRevision`, so each of these sites now
        // drags the backend's cache forward instead of leaving it pinned at 0 forever.
        //
        // **What it costs, stated plainly: at these five call sites the continuity guard can no longer
        // fail.** It still guards every other caller (the fake-client contract suites drive it
        // directly). The honest fix is for the backend to own the mutation path so its counter tracks
        // by construction — Task 41's territory, not a wiring task's.
        //
        // **STOP. THIS BLOCK'S INSTRUCTION WAS DISCHARGED BY TASK 41 AND MUST NOT BE FOLLOWED.**
        // It is preserved rather than deleted because the final branch review found that a stage-2
        // implementer discharging Phase-6 gate item 23 reads it as an outstanding obligation, re-points
        // `oldRevision` at the canvas counter, and ships a DEBUG crash. Task 41 BUILT exactly that fix
        // and MEASURED it: all five `synchronizingExternalChange` sites report `revision continuity
        // violated … has adopted 0`, which is an `assertionFailure` in DEBUG — a crash on the first
        // formatting toggle after a keystroke — **and it does not repair the branch it was meant to
        // repair.** Do not re-derive it; it has been run.
        //
        // WHAT THE TEXT BELOW GOT RIGHT, and it was a real latent bug: with composition state live, a
        // width reflow while composing would rebase from a stale revision and silently drop the marked
        // range. Task 41 reproduced it as a failing test FIRST (`("nil") is not equal to
        // ("Optional({2, 2})")`) and then fixed it — **not** by moving `oldRevision`, but by removing
        // the stale-cache read entirely via `RichTextInputExternalChangeReason.preservesTextOffsets`.
        // The `.layoutOnly` fast path this text cites no longer exists, and `markedRangeStorage` is no
        // longer "dead today" — Task 41 is the commit that made it live.
        //
        // WHAT ACTUALLY REMAINS is narrower and is NOT this line's to fix: the continuity guard is
        // self-satisfying at these five sites while `prepareAndRun` has zero production callers, so it
        // cannot fail by construction. That is **Phase-6 gate item 23**, a stage-2 ENTRY CONDITION,
        // and the item says in terms that stage 1 cannot fail it. Deleting the guard is a permitted
        // answer there — Task 41 removed its second consumer — provided the decision is written down.
        let oldRevision = inputBackend.state.documentRevision
        body()
        // `.layoutOnly` is defined as "geometry moved, the document did not", and the backend keys on
        // exactly that to SKIP adopting a new revision. So it declares an unmoved pair rather than the
        // catch-up pair the other four reasons declare — a `.layoutOnly` change that claimed a higher
        // revision would be a claim the backend deliberately ignores, i.e. a lie with no effect.
        let newRevision = reason == .layoutOnly ? oldRevision : max(documentRevision, oldRevision)
        // FIX ROUND 1 (review Major 1) — **THE SYNCHRONIZE CALL IS SILENCED TOWARD THE HOST, AND ONLY
        // THE CALL. Never `body()`.**
        //
        // `synchronizeAfterExternalChange` ends in `publishState(reason: .externalSynchronization)`,
        // and `TelegramLifecycleInputClient.backendDidPublishState` routes that reason — ungated at
        // that layer — to `canvas.notifyContentSizeChanged()` → `onContentSizeChange` → the facade's
        // `onChange` (a pure relay). That is a NEW host callback this task introduces, at EVERY site,
        // not just the width reflow where a pre-existing test happened to go red. MEASURED, both
        // sides, by `ExternalSynchronizationTests.test_noSiteAddsAHostContentSizeNotification`: at BASE
        // (`7c43541031`'s five source files restored, that test run against them) `reload` notifies the
        // host ONCE, a bold toggle ONCE, a responder undo TWICE and a width reflow NOT AT ALL; before
        // this fix they read 2, 2, 3, 0.
        //
        // **Around the call, not around `body()`, and the difference is a regression in the opposite
        // direction.** Every site's body notifies the host from PRE-EXISTING code — `setBlocks`
        // (`reload`, the undo restore), `editing`'s tail (both formatting sites), `registerUndo`'s own
        // call. Suppressing across the body would DELETE notifications that existed before this task.
        //
        // Saved and restored (under the `defer` below), never reset to `false`, so an outer suppression
        // (`pasteMarkdownTwoStep` step 1 holds one) is never cleared.
        //
        // **The second observable the publish reaches, and it is NOT covered by that flag** (review
        // Minor 3; the review predicted it would disappear here for free — it does not, because
        // `suppressHostChangeNotification` gates `notifyContentSizeChanged` and nothing else).
        // `publishState`'s other half is `presentationClient.apply` → `refreshSelectionUI()` →
        // `inputBackend.checkOnSelectionChange()` → `nativeCheckOnSelectionChange()`, whose
        // `defer { lastCheckedCaret = now }` runs BEFORE its own early-return guard and so re-seeds the
        // counter `setBlocks` deliberately cleared ("a fresh document: nothing checked until the caret
        // traverses it"). `reload` is the only one of the five where that survives — the other four run
        // their own `refreshSelectionUI()` around the bracket, so the counter ends up seeded at BASE
        // too — and there it means the first caret move after a host document set spell-checks a word
        // of a freshly loaded draft the user never traversed, which is the exact case the
        // selection-driven checker exists to avoid. Checkpointed on the same principle as the flag: the
        // sync's publish is a NEW event and must not perturb pre-existing state. Pinned by
        // `test_aReloadStillLeavesNothingCheckedUntilTheCaretTraversesIt` (green at BASE, red without
        // this checkpoint). The rest of `refreshSelectionUI` is idempotent — `updateCaretView`,
        // `updateSelectionHandleViews`, `syncSpoilers` — and is left to run, which is right: the caret
        // and handles do need repositioning against the new content.
        // **The THIRD thing that publish can perturb** (fix round 2, review N3). The same
        // `nativeCheckOnSelectionChange` runs `clearAllCorrectionFlags()` — which strips every
        // `.correction` range from `spellResults` and the alternatives backing them — ALSO before its
        // early-return guard, whenever an autocorrect underline is live in a region other than the
        // caret's. MEASURED, and the reachability is NOT where it was predicted to be: at the two
        // FORMATTING sites there is no delta at all, because `editing`'s own tail already ran the
        // identical code with the identical caret and the identical `spellResults` inside `body()` —
        // the flag is cleared at BASE too. At `reload` and the undo restore `setBlocks` has already
        // emptied `spellResults`, so there is nothing to clear. **`setParagraphsWidthIfNeeded` is the
        // one reachable site**: its body runs no `refreshSelectionUI()` of its own, so at BASE nothing
        // touches the flag and at HEAD the publish silently dropped a live autocorrect underline
        // elsewhere in the document. Pinned by
        // `test_aWidthReflowDoesNotClearAnAutocorrectFlagElsewhere` (green at BASE, red without the
        // checkpoint) and characterised at the formatting sites by its sibling.
        //
        // **All FOUR restores are under ONE `defer`** (fix round 2, review N1). The list has grown one
        // finding at a time — three consecutive reviews asked the same question, *what does
        // `publishState`'s presentation half touch that is not idempotent?* — and nothing here forces a
        // fifth entry if new non-idempotent state lands in that reach. The durable answer is for
        // `.externalSynchronization` not to route into `notifyContentSizeChanged`/`refreshSelectionUI`
        // at all; that is a backend-client change, out of scope for a wiring task. Recorded in the plan
        // against Task 41.
        //
        // **TASK 41 — EXPLICITLY DEFERRED, WITH AN OWNER AND A PRICE, because the plan requires the
        // deferral to be written rather than silent.**
        //
        // OWNER: the stage-2 task that routes mutations through `prepareAndRun`. It inherits this
        // together with the other half of deviation D38 (see this method's `oldRevision` note and
        // `reconcileMarkedTextForExternalChange`'s fast-path note), because both are waiting on the
        // same precondition — the backend owning the mutation path — and splitting them across two
        // commits would leave the backend's cached revision half-live.
        //
        // WHY NOT HERE, measured rather than asserted. Stopping `.externalSynchronization` from
        // reaching `refreshSelectionUI` means reason-gating `publishState`'s PRESENTATION half, not
        // just the lifecycle client's `switch`: `publishState` calls `presentationClient.apply`
        // unconditionally, before the reason is ever consulted. That is a change to what "publish"
        // MEANS, and it is pinned as a pair — `BackendRevisionContractTests
        // .test_layoutOnlyExternalChange_keepsTheDocumentRevision_andPublishesOnce` asserts
        // `presentationApply == 1` AND `lifecyclePublish == 1` for exactly this reason, so the change
        // starts by reddening a contract test that deliberately pins today's answer. Task 41 moves
        // composition state; deciding what a published snapshot delivers to the presentation client is
        // not a decision it is positioned to make well.
        //
        // WHAT TASK 41 CONTRIBUTES INSTEAD — the fifth data point, built rather than predicted. Its
        // one new call into this reach (`registerUndo`'s `clearCompositionState()`,
        // `+Editing.swift`) needed exactly the same workaround for the fifth time, and MEASURED the
        // cost of not having it: `test_noSiteAddsAHostContentSizeNotification` reads 3/3 for
        // undo/redo against a BASE of 2/2. So the prediction this comment made — "nothing here forces
        // a fifth entry" — is now a fact with a number attached, and the next task in this reach can
        // cite it rather than re-derive it.
        //
        // Behaviourally
        // identical to the straight-line form today — the call cannot early-return between them — but a
        // future statement inserted here that returns would leak `suppressHostChangeNotification = true`
        // for the canvas's whole lifetime, silently killing EVERY host content-size notification from
        // then on. Large silent blast radius, one word to prevent.
        let wasSuppressingHostChangeNotification = suppressHostChangeNotification
        let checkpointedLastCheckedCaret = lastCheckedCaret
        let checkpointedSpellResults = spellResults
        let checkpointedSpellingAlternatives = spellingAlternatives
        suppressHostChangeNotification = true
        defer {
            suppressHostChangeNotification = wasSuppressingHostChangeNotification
            lastCheckedCaret = checkpointedLastCheckedCaret
            spellResults = checkpointedSpellResults
            spellingAlternatives = checkpointedSpellingAlternatives
        }
        inputBackend.synchronizeAfterExternalChange(RichTextInputExternalChange(
            oldRevision: oldRevision,
            newRevision: newRevision,
            reason: reason,
            changedRangeBefore: changedRangeBefore,
            changedRangeAfter: changedRangeAfter,
            selection: inputBackend.state.selection,
            markedTextPolicy: markedTextPolicy))
    }

    /// TEST SEAM. The one supported way for a test to plant a raw directional selection without going
    /// through a funnel that also notifies the delegate. Every suite this plan creates uses it instead
    /// of writing `anchor`/`head`, so Task 40b's read-only conversion touches no file this plan
    /// authored (deviation D22). Deliberately silent — it is the raw assignment it replaces, nothing
    /// more.
    ///
    /// **TASK 40a REPOINTED THIS BODY AT THE D33 PAIR, NOT AT `setSelection(_:reason:)`, AND BOTH
    /// ALTERNATIVES WERE MEASURED RATHER THAN REASONED ABOUT.** Task 35 left the two raw
    /// forwarder writes here as the first two entries of the Phase-5 worklist precisely because
    /// repointing them is the change that decides whether the TEST seam publishes. The brief named
    /// `inputBackend.setSelection(_:reason: .programmatic)`; that shape is wrong, and so is the
    /// brief's own fallback. The three measurements, on a green control — full `Scripts/iostest.sh`,
    /// **2663 executed (UIKit 2282 / 5 skipped + Core 381), 0 failures, exit 0**:
    ///
    /// **THE UNIT MATTERS AND IS SPELLED OUT ON PURPOSE (fix round 1).** This note first recorded the
    /// control as "381 tests, exit 0", which is the **Core target alone** — `iostest.sh` prints one
    /// `Executed …` line per target and a `tail -2` catches only the last. **Not one of Task 40a's
    /// ~480 converted call sites is in the 381**; they are all UIKit. A later task that re-runs this
    /// gate, greps `Executed 381 tests, with 0 failures` and calls it green would be certifying a run
    /// in which the UIKit target failed to build or never ran — the exact false-zero shape the whole
    /// compile-gate rationale below exists to replace. Quote both targets or quote the total.
    ///
    ///   1. **Publishing `inputBackend.setSelection(…, reason: .programmatic)` → exit 65, 2 red**
    ///      (`ExternalSynchronizationTests.test_boldToggleSynchronizesAsFormattingWithPreserveIfRebasable`
    ///      and `test_setLinkSynchronizesAsFormatting`, both "expected exactly one external change —
    ///      got 0"). This continues Phase 5's unbroken record: across Tasks 36a-39, 143 converted
    ///      warnings and NOT ONE became a publishing `setSelection`.
    ///   2. **The brief's `if let legacy = … as? LegacyRichTextInputBackend { silent } else { publish }`
    ///      → the SAME 2 red.** The failure is not about publication at all, which is why the
    ///      downcast does not fix it: `spyCanvas()` injects `SpyRichTextInputBackend`, whose
    ///      `setSelection(_:reason:)` is an EMPTY BODY that deliberately does not write
    ///      `canonicalSelectionStorage` (see its own comment: it reproduces the pre-Task-35
    ///      arrangement, where the canvas owned that storage). So on any spy-backed canvas the
    ///      repointed seam became a NO-OP, both tests seeded a collapsed selection instead of a
    ///      3-character range, and `toggleBold()`/`setLink()` over an empty selection mutate nothing.
    ///      The brief's `else` branch is exactly the branch a spy-backed canvas takes, so its shape
    ///      reproduces the bug it was written to avoid.
    ///   3. **The D33 pair below → green.**
    ///
    /// So the seam writes `setCanonicalAnchor`/`setCanonicalHead` — the same two members the
    /// `anchor`/`head` forwarder SETTERS call. This is a pure de-sugaring: it is byte-for-byte the
    /// behaviour of the `anchor = …; head = …` it replaces, at every backend, which is what lets Task
    /// 40a convert ~480 test lines onto it without re-recording a single characterization. It also
    /// needs NO new member on `LegacyRichTextInputBackend` (the brief's `setCanonicalSelectionSilently`
    /// is unnecessary — and would have had to violate its own stated contract, D33) and NO downcast,
    /// so no source-boundary rule is engaged and none was edited.
    ///
    /// **THIS SEAM WRITES BOTH ENDPOINTS, ALWAYS `.downstream`.** Two consequences a caller must know.
    /// (a) There is no single-endpoint form: ten converted sites re-supply the endpoint they do not
    /// intend to change (`setSelectionForTesting(anchor: v.anchor, head: newHead)`), which is correct
    /// because Swift evaluates arguments before the callee body. (b) `setCanonicalAnchor`/
    /// `setCanonicalHead` construct `.downstream(_:)` unconditionally, so a lone-endpoint write that
    /// previously left the OTHER side's affinity untouched now normalises it. That is inert today —
    /// `.upstream` is constructed exactly once package-wide, in a COMMENT in
    /// `TelegramGeometryInputClient.swift` recording that the legacy backend never emits it (D6) — but
    /// the suites this seam now carries are the ones whose subject is selection DIRECTION, so a
    /// backend that grows a real affinity model must revisit this line before trusting them.
    ///
    /// **Do not "simplify" this to `setSelection`.** The correct-looking one-liner is measurement 1.
    func setSelectionForTesting(anchor newAnchor: Int, head newHead: Int) {
        inputBackend.setCanonicalAnchor(newAnchor)
        inputBackend.setCanonicalHead(newHead)
    }

    var selFrom: Int { min(anchor, head) }
    var selTo: Int { max(anchor, head) }

    // UITextInput plumbing + undo.
    // TASK 26 DELETED `var textInputDelegate: UITextInputDelegate?` from here, and TASK 43 DELETED
    // `var inputTokenizer: UITextInputTokenizer?` from the same spot. Both live on the backend:
    // `LegacyRichTextInputBackend.inputDelegate` (the package's only sender of `UITextInputDelegate`
    // notifications, rule R16) and `.tokenizerStorage` (built eagerly in `attach(to:)`, cleared on
    // detach). The canvas reaches each exclusively through its UITextInput witness in
    // `+UITextInput.swift`, a one-line router. `inputTokenizer` had been DEAD since Task 24 moved the
    // cache — declaration plus two comments, zero readers — which is the whole reason its deletion is
    // a one-line change and not a migration. `Mirror`-pinned absent by
    // `DelegateOwnershipTests.test_theCanvasHasNoDelegateStorage`.
    /// iOS 16+ system edit-menu interaction. Untyped storage because a stored property can't be
    /// `@available`-gated narrower than its (now iOS-13) enclosing type, while `UIEditMenuInteraction` is
    /// iOS 16+; below 16 the canvas falls back to `UIMenuController` (see DocumentCanvasView+EditMenu).
    private var editMenuInteractionStorage: AnyObject?
    @available(iOS 16.0, *)
    var editMenuInteraction: UIEditMenuInteraction? {
        get { editMenuInteractionStorage as? UIEditMenuInteraction }
        set { editMenuInteractionStorage = newValue }
    }
    /// Host-provided transform of the edit-menu elements. Consulted by the iOS-16 `menuFor:` delegate only,
    /// and only for a non-collapsed selection. nil ⇒ the editor's default menu. (iOS 13–15 keeps its built-in
    /// items — see DocumentCanvasView+EditMenu; UIMenuItem cannot carry a closure.)
    var hostContextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])?
    var editMenuStrings: RichTextEditorMenuStrings = .default
    /// Host hook for the table row/column structural menu. Fired from the `.menu` handle-tap case with a
    /// framework-agnostic description; the host presents its own ContextController. nil ⇒ no menu shown.
    var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)?
    /// Host hook for a media control (the "more" button; the "+" later). Fired from a bound media view with
    /// an account-free `MediaControlRequest` (opaque `mediaID` + occurrence-bound operation closures); the
    /// host resolves the concrete media and presents its own menu. nil ⇒ no menu shown.
    var onRequestMediaControl: ((MediaControlRequest) -> Void)?
    /// Whether the edit menu is currently presented (tracked via UIEditMenuInteractionDelegate), so a tap
    /// on the caret/selection can TOGGLE the menu instead of re-presenting it (the close-then-reopen flicker).
    var editMenuVisible = false
    /// Test observability: counts `dismissEditMenu()` calls (a presented `UIEditMenuInteraction` can't be
    /// driven in a unit test, so the auto-dismiss-on-change behavior is asserted via this counter).
    var dismissEditMenuCountForTesting = 0
    /// TASK 30: the presentation counterpart, added for the same reason and used the same way. Both of
    /// `presentEditMenu()`'s real effects are unreachable from a unit test (`isFirstResponder` is false
    /// for an unhosted canvas, and `editMenuInteraction` is nil until it is installed), so WITHOUT this
    /// counter the menu re-presentation that `legacySelect(_:)`/`legacySelectAll(_:)` perform is
    /// completely unobservable — which is exactly how a routing that dropped it could have shipped
    /// green. Incremented at the TOP of `presentEditMenu()`, before its guard: the fact under test is
    /// that the attempt was made.
    ///
    /// Deliberately NOT added to `RouterStateSnapshot` (`T/Support/RouterAssertions.swift`), whose
    /// seven fields each carry a proven-live negative control in `RouterHarnessTests`: an eighth field
    /// would need its own control, and it would earn nothing — a router that kept a copy of a select
    /// body already moves `anchor`/`head`, which that snapshot does watch.
    var presentEditMenuCountForTesting = 0
    /// Reference-time of the last edit-menu dismissal. The system auto-dismisses the menu on a tap-down,
    /// BEFORE our single-tap handler runs (on tap-up), so `editMenuVisible` is already false by then; this
    /// lets the handler tell "this tap just dismissed the menu" from "no menu was up".
    var lastMenuDismissTime: TimeInterval = 0
    /// Manual multi-tap counting (see `handleTap`). The single-tap recognizer is no longer gated on a
    /// double-tap recognizer FAILING — that `require(toFail:)` made every caret placement wait out the
    /// ~0.35s multi-tap window. One 1-tap recognizer now fires immediately and these track the rapid-tap
    /// run that escalates caret → word → paragraph.
    var lastTapTime: TimeInterval = 0
    var lastTapLocation: CGPoint = .zero
    var tapCount = 0
    /// Set on a genuine not-focused→focused transition (`becomeFirstResponder`), consumed by the next
    /// `performSingleTap`. A FOCUSING tap must only place the caret, never open the menu. We can't detect it
    /// from `isFirstResponder` at touch-up: the chat composer focuses the editor on touch-DOWN (the panel's
    /// `ensureFocusedOnTap`), so by the time the tap handler runs `isFirstResponder` is already true. This flag
    /// captures the transition regardless of who triggered it (touch-down focus or the handler's own
    /// `ensureFirstResponder`).
    var didJustBecomeFirstResponder = false
    /// Active magnifier loupe during a long-press caret drag (iOS 17+). Begun on `.began`, moved on
    /// `.changed`, invalidated + niled on `.ended`/`.cancelled`/`.failed`. The storage is untyped because a
    /// stored property can't be `@available`-gated narrower than its enclosing (iOS-16) type, while
    /// `UITextLoupeSession` is iOS 17+; the typed accessor below is the gated view onto it.
    private var loupeSessionStorage: AnyObject?
    @available(iOS 17.0, *)
    var loupeSession: UITextLoupeSession? {
        get { loupeSessionStorage as? UITextLoupeSession }
        set { loupeSessionStorage = newValue }
    }
    /// SPIKE (loupe grow-from-cursor): a `UITextSelectionDisplayInteraction` (iOS 17+) installed solely to borrow
    /// its system `cursorView` for the loupe's `fromSelectionWidgetView`. Kept DEACTIVATED except during a loupe
    /// drag. Untyped storage for the same availability reason as `loupeSessionStorage`. INSTRUMENTED — evaluate
    /// the leaked-chrome logs before deciding whether this can stay.
    private var selectionDisplayInteractionStorage: AnyObject?
    @available(iOS 17.0, *)
    var selectionDisplayInteraction: UITextSelectionDisplayInteraction? {
        get { selectionDisplayInteractionStorage as? UITextSelectionDisplayInteraction }
        set { selectionDisplayInteractionStorage = newValue }
    }
    /// SPIKE: a stable container the borrowed interaction hosts its selection chrome in (via the delegate). It is
    /// NOT tracked in `blockViews`, so the block-view reload loop never removes it, and it is created lazily on the
    /// first loupe drag. All the interaction's chrome (cursor / lollipops / accessory) lands here so we can hide it.
    lazy var selectionChromeContainer: UIView = {
        let v = UIView()
        v.isUserInteractionEnabled = false
        v.clipsToBounds = false
        addSubview(v)
        return v
    }()
    /// True for the duration of a long-press magnifier (loupe) drag. While set, `updateCaretView` keeps the
    /// steady caret SOLID (no blink, full alpha) so the loupe lifts off from / magnifies a crisp caret — a
    /// blinking caret is invisible for the part of each cycle its opacity dips toward 0, which made the loupe
    /// appear to pop in "from nothing" with no visible cursor (device-log-verified). Set BEFORE `begin(...)`
    /// (so the caret is already solid when the loupe captures it) and cleared on drag end.
    var loupeDragActive = false
    /// The current finger x (canvas/self space) during a loupe drag, set by the long-press handler each frame.
    /// `updateCaretView`'s loupe branch reads it to hide the gray "shadow" (`caretView`) while the accent glider
    /// at the finger sits within `loupeShadowMinSeparation` of the snapped caret. Owned here (not in
    /// `positionLoupeShadow`) so a re-run of `updateCaretView` — the loupe magnifier forces layout passes —
    /// re-applies the rule instead of `freezeSolid` leaving the shadow visible. `nil` when not dragging.
    var loupeFingerX: CGFloat?
    /// True when the current long-press `.began` was consumed as the follow-up tap of a double-/triple-tap
    /// (see `handleLoupeBegan`) rather than starting a loupe cursor-drag. While set, the long-press `.changed`
    /// / `.ended` handlers no-op (no `setCaret`, no loupe teardown) so the word/paragraph selection they made
    /// survives the rest of the gesture. Reset when the gesture ends.
    var loupeConsumedAsMultiTap = false
    /// Whether the edit menu was already showing when the current loupe long-press began, and the caret's global
    /// position at that moment — captured in `.began` so `.ended` can tell a STATIONARY press on an open menu
    /// (a tap-like toggle-off — suppress the re-present, else the menu flickers disappear-then-reappear) from a
    /// real cursor drag (present at the new position). A quick tap near the caret is caught as a loupe (the
    /// near-cursor press delay is 0.05s), so the loupe must match the tap path's menu-toggle semantics.
    var loupeMenuWasVisibleAtBegan = false
    var loupeHeadAtBegan = 0
    /// The steady caret's normal accent, saved while a loupe drag recolors it to the desaturated "shadow" gray
    /// (the snapped landing caret is the gray shadow; the gliding `transientCaretView` is the accent). Restored
    /// on drag end.
    var loupeSavedCaretAccent: UIColor?
    var draggingEndpoint: SelectionEndpoint?
    // The (caret-center − initial-touch) offset captured when a selection-handle drag begins, so the dragged
    // endpoint keeps its starting offset from the finger instead of snapping to the line under the touch (the
    // knob is drawn offset from the text line). Applied at every drag map via `selectionDragPosition(forTouch:)`.
    var selectionDragGrabOffset: CGSize = .zero
    var draggingTableKnob: TableRangeEnd?
    // A `.cells` corner-knob drag (Phase 2c-T4) — set in `.began` when the touch hits a corner knob, either a
    // committed `.cells` selection's or the focused-cell "fake" chrome's (no committed selection yet). The
    // FIRST `extendCellSelection` call promotes the fake chrome to a real committed `.cells` selection.
    var draggingTableCornerKnob: TableCellCorner?
    var selectionHandlePan: UIPanGestureRecognizer?
    /// The 1-tap caret/selection recognizer `installSelectionInteractions()` adds. **TASK 32 added this
    /// storage**, and it is not decoration: `legacyRemoveSelectionInteractions()` must remove exactly the
    /// three recognizers install added, BY IDENTITY, and this was the only one of the three not held.
    /// (Measured, because the obvious shortcut is wrong: a canvas does NOT hold only our three.
    /// `UIEditMenuInteraction` — which `installSelectionInteractions()` also installs — attaches its own
    /// recognizers to the view, and becoming first responder adds more still, so a freshly-attached
    /// canvas reports SIX and a focused one EIGHT. Removing "all of them" would tear out UIKit's.)
    /// Storing the reference changes nothing at runtime: the view already retains it through
    /// `gestureRecognizers`.
    var selectionTap: UITapGestureRecognizer?
    // The loupe / move-cursor long-press. Held so `gestureRecognizerShouldBegin` can fail it on a touch that
    // lands on an active selection handle (letting the handle pan grab the knob instead) — see that method.
    var loupeLongPress: LocationAdaptiveLongPressGestureRecognizer?
    // True while an interactive selection-handle drag is in flight. While set, the per-touch-move selection
    // setters (`setSelectionHead`/`setSelectionAnchor`) SKIP the `inputDelegate` selection bracket; one
    // bracket fires when the drag ends (`endCoalescedSelectionDrag`). Driving the keyboard's autocorrect/
    // candidate pipeline (`-[_UIKeyboardStateManager updateForChangedSelection]`, which also re-enters our
    // tokenizer) on every frame pegs the CPU and is meaningless mid-drag — you can't accept a suggestion
    // while dragging a handle. The `selectedTextRange` getter stays live, so the OS reads the correct value
    // if it queries during the drag; only the proactive candidate recompute is deferred to the gesture end.
    /// TASK 43 DELETED `var coalescingSelectionNotifications: Bool` from here. It had been a Task-26
    /// computed FORWARDER (never storage) onto `inputBackend.suppressesSelectionNotifications` — a
    /// `RichTextInputBackend` requirement since Task 11 / deviation D33, with TWO consumers the backend
    /// must keep in step: `setSelection`'s publish-deferral and the `notifyingSelectionChange(_:)`
    /// bracket's suppression. Its four canvas-side use sites now name the backend member directly:
    /// `beginCoalescedSelectionDrag()` (set), `endCoalescedSelectionDrag()`'s guard + clear, and
    /// `nativeCheckOnSelectionChange()`'s guard (`+NativeTextCheckingClient.swift`). That count is
    /// pinned by `InputBackendSourceBoundaryTests`
    /// `.test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated`, because the flag's `didSet` FIRES
    /// A DEFERRED SELECTION PUBLISH on the clearing edge — a fifth site is a new host-visible
    /// publication moment, not a detail.
    ///
    /// `Tests/…/Support/CanvasCoalescingTestAccess.swift` re-vends the old spelling to the TEST target
    /// only, so `Characterization/ResponderLifecycleCharacterizationTests.swift` stays byte-identical
    /// (Phase 6 gate item 3); same device as D22's permanent test-facing typealiases.
    // Auto-scroll state while dragging a text-selection handle near an edge: vertically against the host
    // document scroll view, and/or horizontally within a scrollable table the head is in. One display link
    // drives both axes.
    private(set) var dragAutoScrollLink: CADisplayLink?
    private(set) var dragAutoScrollTable: TableBlockBox?
    private(set) var dragAutoScrollVelocityX: CGFloat = 0   // table horizontal, points/tick, signed
    private(set) var dragAutoScrollVelocityY: CGFloat = 0   // document vertical, points/tick, signed
    private(set) var dragAutoScrollPoint: CGPoint = .zero   // last touch (canvas coords), for re-extending
    /// Transient table row/column structural selection (separate from the text selection). The `table` id
    /// guards against a stale selection after the active table is rebuilt. nil = none. Mutually exclusive
    /// with `imageSelection`.
    var tableSelection: (table: BlockID, kind: TableStructuralSelection)?
    /// Transient atom-selection of a top-level image (separate from the text selection). The BlockID
    /// guards a stale selection after a relayout/undo. nil = none. Mutually exclusive with `tableSelection`.
    var imageSelection: BlockID?
    /// The image whose `imageSelection` was just cleared by the `selectedTextRange` setter — iOS overrides a
    /// tap-selected media's selection (clearing `imageSelection`) right before its Backspace. `deleteBackward`
    /// consumes this to replace that media; any non-delete edit clears it. nil = none.
    var imageObjectDeletePending: BlockID?
    /// Marked (composing/provisional) text as global positions over the same axis as `(anchor, head)`.
    /// nil = no active composition. The provisional characters live in the leaf region's storage like
    /// any committed text; this just tracks which range is provisional (for the underline + commit).
    ///
    /// **TASK 41 — A READ-ONLY PROJECTION. The store is `LegacyRichTextInputBackend`'s, and it is the
    /// only one.** This was `var markedRange: (from: Int, to: Int)?` — real storage, and the live
    /// composition authority — until this task; the backend's own `markedRangeStorage` was a PARALLEL
    /// value that nothing reachable ever set non-nil, which is the two-store split Task 29 disclosed.
    /// The tuple shape survives the move because ~24 test files assert on it, and because `to` being
    /// EXCLUSIVE is a convention several canvas bodies depend on; the backend stores the same fact as
    /// an `NSRange`, and this is the bridge.
    ///
    /// Writing composition state now goes through the backend, and there are exactly THREE doors —
    /// declared in `RichTextInputBackend.swift` and, since TASK 41 FIX ROUND 1 (review M4/m4), each
    /// held to an EXACT per-file CALL-SITE count by
    /// `InputBackendSourceBoundaryTests.test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated`, exactly as
    /// the selection doors are. That mechanism is the point: the first version of this list said "two
    /// doors, both enumerated at their declaration", which was a sentence with nothing behind it AND
    /// undercounted by one — the same shape R7b was created to replace.
    ///   1. `inputBackend.setCompositionMarkedRange(_:isPrediction:)` — raw and non-publishing, the
    ///      marked-text analogue of the D33 selection pair;
    ///   2. `inputBackend.setCompositionSnapshot(_:)` — its partner, same contract. Doors 1 and 2 have
    ///      **8 calls between them, all in `+MarkedText.swift`**, in the three composition-lifecycle
    ///      bodies that emit their own delegate brackets;
    ///   3. `inputBackend.clearCompositionState()` — the PUBLISHING one, **1 call**, in `registerUndo`'s
    ///      restore closure (`+Editing.swift`), which holds `suppressHostChangeNotification` across it.
    /// Note the R7 write scan CANNOT see any of the three: it has no `.`-qualified form, so
    /// `inputBackend.setComposition…` is not a "write" to it. Door enumeration is the only mechanism.
    /// Reaching `markedRangeStorage` through a concrete downcast is not a third door: R7b
    /// (`test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated`) forbids naming it outside
    /// `S/InputBackend/` at all.
    var markedRange: (from: Int, to: Int)? {
        inputBackend.markedRange.map { (from: $0.location, to: $0.location + $0.length) }
    }
    /// True when the active marked text is a system INLINE PREDICTION (ghost text: `setMarkedText` with
    /// the caret at the start, `sel == {0,0}`) rather than CJK/IME composition. Predictions are
    /// keyboard-owned provisional text: a gesture/focus interruption must DISMISS the ghost (remove it),
    /// never COMMIT it — committing desyncs the keyboard's shadow doc and duplicates the word on accept.
    ///
    /// TASK 41: a READ-ONLY projection, like `markedRange` above. The backend's accessor ANDs the flag
    /// with "a range exists", so this can never read `true` while nothing is composing.
    var markedTextIsPrediction: Bool { inputBackend.isComposingPrediction }
    /// The layout currently carrying the grey prediction-ghost rendering colour (display-only), so it
    /// can be cleared when the prediction moves or ends. Weak: the layout is owned by its box.
    ///
    /// **DEVIATION D13 — THIS ONE DOES NOT MOVE, AND MUST NOT.** It is the odd member out of the five
    /// properties this block used to hold: the other four moved to the backend at Task 41, and this
    /// holds a `BlockLayoutEngine`. Passing a `BlockLayoutEngine` across the input-backend boundary is
    /// an explicit patch-rejection criterion (R1 bans the type name from every shared contract file),
    /// so the ghost styling stays canvas-side PRESENTATION state, written by `refreshPredictionStyling()`
    /// which every composition-lifecycle body already calls after changing the marked range.
    /// `MarkedStateAuthorityTests.test_ghostStyledLayoutStaysOnTheCanvas` asserts it by name.
    weak var ghostStyledLayout: BlockLayoutEngine?
    /// Injectable pasteboard (defaults to the system pasteboard; tests inject a fake — see TextPasteboard).
    var pasteboard: TextPasteboard = UIPasteboard.general
    // MARK: Spell checking (see DocumentCanvasView+SpellCheck, +NativeTextCheckingClient)
    /// Native-checking underline style per flagged range.
    enum SpellStyle: Equatable { case spelling, grammar, correction }
    /// Per-region flagged ranges in REGION-LOCAL UTF-16, keyed by the owning block's id (from the region's
    /// `ref`). `contentHash` is reserved for a future content-keyed cache (native checking self-invalidates
    /// via the controller, so it is currently unused — 0).
    /// Accepted limitation: this is a side table edits do NOT shift, so a flagged word positioned after a
    /// mid-region edit renders at a stale offset until the caret next re-traverses it (self-healing). The old
    /// debounced full-region rescan used to mask this by rebuilding every flag on each pass.
    var spellResults: [BlockID: (contentHash: Int, ranges: [(range: NSRange, style: SpellStyle)])] = [:]
    /// Delivered `.correction` candidate replacements ("alternatives"), region-local — mirrors `spellResults`.
    /// Stashed from `nativeReplace` via KVC on the delivered `NSTextAlternatives` (see
    /// `+NativeTextCheckingClient.stashSpellingAlternatives`); best-effort (corrections were not observed firing
    /// in the test host). `.spelling`/`.grammar` flags never populate this — those go through the public
    /// `UITextChecker` guesses lookup instead (`+SpellCheck.nativeSpellingGuesses`).
    var spellingAlternatives: [BlockID: [(range: NSRange, candidates: [String], primary: String?)]] = [:]
    /// The native checking driver (nil ⇒ private class unavailable ⇒ checking off; no fallback).
    var nativeChecker: NativeTextChecker?
    /// Global caret position at the last selection-driven native check. nil until the first post-focus
    /// selection settles: native does NOT scan on focus — only words the caret traverses are checked.
    var lastCheckedCaret: Int?
    /// Set only for the duration of a driven `checkSpellingForWord`/`checkGrammarForSentence` call. The
    /// controller calls back `removeAnnotation:forRange:` SYNCHRONOUSLY within that call whenever the
    /// checked word/sentence turns out clean (verified live) — without knowing which check triggered it,
    /// `nativeRemoveAnnotation` can't tell a stale `.spelling` flag from an unrelated `.grammar` flag that
    /// merely overlaps the checked word, and would wipe both (the same style-isolation bug `.spelling`
    /// clears in `nativeCheckOnSelectionChange` have). Bracketed by `driveNativeCheck(style:_:)`.
    var inFlightCheckStyle: SpellStyle?
    /// Host toggle (façade `isSpellCheckingEnabled`). When false: no checking, no underlines, no tap override.
    var isSpellCheckingEnabled = true {
        didSet {
            guard oldValue != isSpellCheckingEnabled else { return }
            // TASK 34: the ENABLE branch routes through the backend (`installCheckingIfNeeded()`,
            // deviation D37); the `preheat()` beside it and the whole DISABLE branch below stay here,
            // because D11 keeps the `NativeTextChecker` handle canvas-owned — `deinit` invalidates it.
            if isSpellCheckingEnabled { inputBackend.installCheckingIfNeeded(); nativeChecker?.preheat() }
            else { nativeChecker?.invalidate(); nativeChecker = nil; spellResults = [:]; spellingAlternatives = [:]; pendingSpellingMenu = nil; setNeedsSpellUnderlineDisplay() }
            reloadInputViews()   // let the keyboard re-read the trait
            // TASK 31, DEVIATION D4: the six `UITextInputTraits` witnesses deliberately do NOT route.
            // `spellCheckingType` reads THIS property (`isSpellCheckingEnabled ? .yes : .no`), so
            // extracting it onto the backend would break the toggle — the backend is TOLD instead.
            // Same shape as `editPolicy`'s didSet below, and the same plain, unwrapped
            // `inputBackend` spelling for the same documented reason (see that didSet's note).
            // The `guard oldValue != …` at the top of this body is load-bearing for this call too:
            // setting the trait to its current value must notify nothing.
            inputBackend.textInputTraitsDidChange()
        }
    }
    /// The host's edit policy. Defaults to `.legacyUnrestricted`, which reproduces today's behavior
    /// exactly (everything permitted): neither `isEditable` (`+UITextInput.swift`) nor
    /// `canBecomeFirstResponder` (below) is gated on it. TASK 31 ROUTED both to the backend, where
    /// each answers a bare `true` — the same unconditional value, one hop away; the two `DCV:<line>`
    /// citations this sentence used to carry are gone rather than repaired, on the register item that
    /// line citations in this tree rot silently.
    /// Changing it notifies the backend, which re-reads the policy at operation time.
    var editPolicy: RichTextInputEditPolicy = .legacyUnrestricted {
        didSet {
            guard editPolicy != oldValue else { return }
            // NOT `inputBackend?.editPolicyDidChange()` — `inputBackend` is a non-optional
            // `private(set) var` (Task 20), so the optional-chained spelling would silently compile
            // down to an always-true `?`-on-a-non-optional (a warning, not an error) and reads as
            // if a nil backend were an expected, tolerated state. It never is: the canvas always has
            // exactly one attached backend for its whole lifetime. The plain, unwrapped call is the
            // only spelling that documents that invariant instead of hiding it.
            inputBackend.editPolicyDidChange()
        }
    }
    /// Set while the tap-to-fix guesses menu is up; `range` is GLOBAL (same axis as the selection).
    /// `revertTo` is the pre-correction original word — non-nil only for a `.correction` flag with a stashed
    /// `spellingAlternatives` entry (best-effort; see that field's doc) — and drives the "Revert to …" menu
    /// action added in N5.
    var pendingSpellingMenu: (range: NSRange, guesses: [String], revertTo: String?)?
    var undoManagerOverride: UndoManager?
    /// The editor's OWN undo manager, used in production. We deliberately do NOT fall back to the
    /// responder-chain `UIResponder.undoManager`: that manager is shared app-wide, so OTHER responders'
    /// (and the system text-input subsystem's) selection/typing undo registrations would surface in the
    /// editor's `canUndo` / `undo()` — the "a selection change is undoable / undo is active on the first
    /// tap before any content edit" bug. A private per-canvas manager keeps the buffer pristine: only the
    /// editor's own content edits (every `registerUndo`) count. Tests inject their own via `undoManagerOverride`.
    private let ownUndoManager = UndoManager()
    var effectiveUndoManager: UndoManager? { undoManagerOverride ?? ownUndoManager }

    /// Expose the editor's OWN (dedicated, private) undo manager to the responder chain so the SYSTEM undo
    /// affordances act on our edits: hardware ⌘Z / ⌘⇧Z, shake-to-undo, and the Edit-menu Undo/Redo items.
    /// Without this override, `UIResponder.undoManager` returns the app-wide SHARED manager (the window's),
    /// which our edits never touch — so ⌘Z did nothing after we went private for buffer isolation.
    ///
    /// **Safe by construction:** overriding `undoManager` changes only WHO can call `undo()` on our manager,
    /// not WHAT is registered into it. This manager only ever receives our `editing()` content-edit
    /// registrations (we register nothing on selection changes), and it is a private instance no other
    /// responder holds — so the foreign-entry pollution that motivated going private (which lived in the
    /// shared instance we no longer use) cannot appear here. UIKit does not auto-register typing/selection
    /// undos into a bare custom `UITextInput` (it owns no text here) and — like `UITextView` — never records
    /// cursor movements as undo steps.
    /// TASK 30 (Family 7): one-line router. The value is unchanged — the backend answers from
    /// `RichTextInputCommandClient.undoManager`, which for the Telegram client IS this canvas's
    /// `effectiveUndoManager` (`Clients/TelegramCommandInputClient.swift`), i.e. the very expression
    /// this override used to evaluate. `UndoBufferIsolationTests
    /// .test_undoManager_isTheEditorsOwnManager` / `…_followsInjectedOverride` pin both halves of that
    /// from the canvas side and were left untouched.
    ///
    /// DIVERGENCE, disclosed (axis 2): a DETACHED backend answers `nil`, where this override kept
    /// answering `ownUndoManager` from canvas state that is still alive. `nil` means "this responder
    /// has no undo manager" — Cmd-Z does nothing for that window — which is the safe direction (the
    /// alternative, falling back to the app-wide shared manager, is precisely the buffer pollution the
    /// paragraph above says this override exists to prevent, and `nil` does NOT cause it: an override
    /// returning nil does not re-consult `super`).
    override var undoManager: UndoManager? { inputBackend.undoManager }

    /// Coalescing kind for an edit: consecutive `.typing` (or consecutive `.deleting`) edits that
    /// are contiguous collapse into ONE undo step; `.none` always starts/breaks a step (structural,
    /// format, paste, media, list, table edits).
    enum UndoCoalescing { case typing, deleting, none }
    /// The currently-open coalescing run. `caret` is where the NEXT contiguous keystroke must land
    /// for it to join this run. `nil` = no open run (the next edit registers a fresh undo step).
    var openUndoRun: (kind: UndoCoalescing, caret: Int)?
    /// Number of NEW undo steps `editing` has started (a coalesced keystroke registers nothing, so it
    /// does not increment). A test seam that measures coalescing directly, independent of NSUndoManager
    /// grouping — mirrors the module's other internal test hooks.
    var undoRegistrationCount = 0
    /// Closes any open coalescing run so the next edit registers a fresh undo step. Called on every
    /// run-breaking boundary that isn't already caught by the contiguity check (undo/redo restore,
    /// IME commit, document swap, resign-first-responder).
    func breakUndoCoalescing() { openUndoRun = nil }

    /// When set, an `editing { }` block skips its trailing HOST notifications (`notifyContentSizeChanged`
    /// and `onSelectionChange`) so the host does not re-lay-out / redraw for that edit. Used by the
    /// markdown two-step paste to keep the intermediate raw-text state (step 1) off-screen — only step 2's
    /// rich result triggers a host layout, so the paste shows no flash of the raw markdown. The canvas has
    /// no `draw(_:)` and is parent-driven, so suppressing the host layout keeps the block views unchanged.
    var suppressHostChangeNotification = false

    /// Last known value of `caretIsInCodeRegion`, so a crossing can be detected and the keyboard told to
    /// re-read its cached traits. See `refreshCodeInputTraitsIfNeeded`.
    private var lastCaretWasInCodeRegion = false

    /// Host-supplied syntax highlighter: (language, text, completion). nil disables highlighting entirely.
    /// The editor cannot call libprisma itself — see `RichTextSyntaxToken`.
    var syntaxHighlighter: ((String, String, @escaping ([RichTextSyntaxToken]) -> Void) -> Void)?
    /// Answers, keyed by (normalized language, exact text). In-memory and per-canvas; nothing persists.
    var syntaxHighlightCache: [CodeHighlightSpec: [RichTextSyntaxToken]] = [:]
    /// Specs already requested and not yet answered, so a second pass does not re-ask.
    var inFlightSyntaxHighlightSpecs: Set<CodeHighlightSpec> = []
    /// Debounce for the highlight pass. Tests set 0 to fire on the next runloop turn.
    var syntaxHighlightDebounceInterval: TimeInterval = 0.3
    /// The scheduled pass, cancelled and replaced by each new edit. Internal (not `private`) so the
    /// `+SyntaxHighlight` extension in another file can reach it.
    var pendingSyntaxHighlightWork: DispatchWorkItem?
    /// Counts block-view repaints caused by a colour change; read by tests through
    /// `codeHighlightRepaintCountForTesting`.
    var codeHighlightRepaintCount: Int = 0

    /// Token for the input-language-change observer (see init); removed in deinit.
    private var inputModeObserver: NSObjectProtocol?

    /// The attached input backend. One backend for the whole canvas lifetime; there is no live
    /// switching. Injectable so tests can install a recording spy.
    ///
    /// DEVIATION D30: the spec's authority table puts backend selection in "an external factory
    /// before attachment". Stage 1 has exactly one backend, so this defaulted `init` parameter IS
    /// the interim selection point; stage 2's `RichTextInputCanvasFactory` replaces the default.
    private(set) var inputBackend: any RichTextInputBackend

    /// The six Telegram clients the backend reaches through `RichTextInputHost`/`LegacyRichTextInputHost`.
    /// Implicitly-unwrapped: Swift requires stored properties to be initialized before `super.init`,
    /// but every client captures `self` (`canvas: self`), so they cannot be built before then. Each is
    /// assigned in `init` IMMEDIATELY after `super.init(frame:)` and is never nil afterwards — the six
    /// `LegacyRichTextInputHost` vending properties below force-unwrap them.
    private var documentInputClient: TelegramDocumentInputClient!
    private var geometryInputClient: TelegramGeometryInputClient!
    private var annotationInputClient: TelegramAnnotationInputClient!
    private var presentationInputClient: TelegramPresentationInputClient!
    private var lifecycleInputClient: TelegramLifecycleInputClient!
    private var commandInputClient: TelegramCommandInputClient!

    deinit {
        // `deinit` is always `nonisolated` (a hard Swift rule — no type, including a `@MainActor`
        // one, can isolate its deinit), but `inputBackend.detach()` is a `@MainActor` call. UIKit
        // objects are always deallocated on the main thread in practice, so `assumeIsolated` is the
        // sanctioned bridge rather than a real concurrency hazard.
        MainActor.assumeIsolated {
            inputBackend.detach()   // FIRST statement: terminal and idempotent, safe even if attach failed.
        }
        if let inputModeObserver { NotificationCenter.default.removeObserver(inputModeObserver) }
        nativeChecker?.invalidate(); nativeChecker = nil   // tear down the native checking controller explicitly
    }

    /// The `mapper:` parameter and its default are UNCHANGED from the pre-Task-20 initializer — this
    /// AMENDS that initializer in place rather than adding a second one. A second initializer would
    /// make the bare `DocumentCanvasView()` call ambiguous at every one of the ~298 in-tree call
    /// sites across 124 test files (`grep -rn "DocumentCanvasView(mapper" Sources Tests` → 0: no call
    /// site passes `mapper:` today, but the parameter stays so the amendment is source-compatible).
    init(mapper: AttributedStringMapper = AttributedStringMapper(),
         inputBackend: (any RichTextInputBackend)? = nil) {
        self.mapper = mapper
        self.inputBackend = inputBackend ?? LegacyRichTextInputBackend()
        super.init(frame: .zero)
        // Re-flip an empty paragraph's caret when the input language changes (globe key) or the keyboard
        // first appears — `currentInputModeDidChange` fires for both. So an RTL input language puts the
        // caret on the right of an empty paragraph live, without a reload/refocus. `queue: nil` delivers
        // synchronously on the posting (main) thread.
        self.inputModeObserver = NotificationCenter.default.addObserver(
            forName: UITextInputMode.currentInputModeDidChangeNotification, object: nil, queue: nil
        ) { [weak self] _ in
            self?.refreshEmptyBoxWritingDirections()
            self?.updateCaretView()
        }
        backgroundColor = .systemBackground
        blockChromeOverlay.canvas = self
        addSubview(blockquoteUnderlay)   // back-most: blockquote fills behind every block view
        pullQuoteUnderlay.barWidth = 0                             // no leading bar — a symmetric pill
        pullQuoteUnderlay.accentColor = blockquoteUnderlay.accentColor
        // Corner radius + fill come from the pull-quote style (NOT the block-quote underlay) so the default
        // pull-quote look applies even in hosts that never assign a custom pullQuoteStyle (e.g. the composer).
        pullQuoteUnderlay.cornerRadius = pullQuoteStyle.cornerRadius
        pullQuoteUnderlay.fillAlpha = pullQuoteStyle.fillAlpha
        addSubview(pullQuoteUnderlay)    // back-most: pull-quote pill fills behind every block view
        emojiOverlay.isUserInteractionEnabled = false
        emojiOverlay.backgroundColor = .clear
        addSubview(emojiOverlay)
        mediaOverlay.isUserInteractionEnabled = true   // pass-through: only interactive media controls claim a touch (see MediaPassthroughOverlayView)
        mediaOverlay.backgroundColor = .clear
        addSubview(mediaOverlay)   // above block backing views, below the selection wash / chrome
        spoilerOverlay.isUserInteractionEnabled = false
        spoilerOverlay.backgroundColor = .clear
        addSubview(spoilerOverlay)   // above emoji, below the selection wash
        selectionHighlight.canvas = self
        addSubview(selectionHighlight)   // selection wash, above text + emoji, below chrome
        addSubview(blockChromeOverlay)
        // Interactive collapse-button overlay: above text/chrome, but hitTest passes only button touches
        // so caret placement / text selection / table chrome all still work through it.
        // Non-interactive pull-quote corner-mark overlay (decorative; isUserInteractionEnabled = false).
        addSubview(pullQuoteMarksView)
        addSubview(caretView)   // own caret, above content; reparented into a table's content view when needed
        addSubview(transientCaretView)   // own floating caret, above content; reparented like caretView
        addSubview(startHandleView)   // own-drawn selection handles, hosted per-endpoint like the caret
        addSubview(endHandleView)

        // The fixed attachment order (spec, non-negotiable): (1) the canvas + its six clients are
        // now fully constructed — every subview above is in place; (2) the backend was already
        // selected, above, before any of this ran; (3)-(5) `attach(to:)` seeds the initial
        // revision/selection and installs interactions; (6) first-responder activation is only
        // possible after `init` returns, so it is implicitly ordered after this block.
        documentInputClient = TelegramDocumentInputClient(canvas: self)
        geometryInputClient = TelegramGeometryInputClient(canvas: self)
        annotationInputClient = TelegramAnnotationInputClient(canvas: self)
        presentationInputClient = TelegramPresentationInputClient(canvas: self, facade: nil)
        lifecycleInputClient = TelegramLifecycleInputClient(canvas: self)
        commandInputClient = TelegramCommandInputClient(canvas: self, facade: nil)
        do {
            try self.inputBackend.attach(to: self)
        } catch {
            // NEVER `try?`. A swallowed attach leaves `isAttached == false`, after which every
            // operational member hits the detached-backend guard and returns silently — an editor
            // that looks alive and does nothing. Spec failure class 2 requires an unsupported or
            // forced backend to "report a precise construction/attachment error", and `attach` is
            // the declared channel. Stage 2 moves construction+attach into
            // `RichTextInputCanvasFactory`, where the fallback-to-legacy decision belongs (D30);
            // until then the report is the whole diagnostic.
            RichTextInputContractViolation.report("backend attach failed: \(error)")
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // TASK 31 (Family 8): one-line routers. The backend answers a bare `true` for both — the same
    // values these two have today. `canResignFirstResponder` is a NEW override: the canvas had none,
    // so `UIResponder`'s own documented `true` applied, and an override returning `true` reproduces it
    // exactly. Adding it is what lets the backend own BOTH halves of the responder gate rather than
    // one, which is the shape `RichTextInputResponderBackend` declares.
    override var canBecomeFirstResponder: Bool { inputBackend.canBecomeFirstResponder }
    override var canResignFirstResponder: Bool { inputBackend.canResignFirstResponder }

    /// When non-nil, replaces the system keyboard while the canvas stays first responder (a consumer
    /// sets e.g. an `EmptyInputView` to hide the keyboard while showing a separate emoji panel, so the
    /// caret keeps rendering). `nil` ⇒ system keyboard.
    var customInputView: UIView?
    override var inputView: UIView? { return self.customInputView }

    /// Test seam: when set, replaces the live `textInputMode?.primaryLanguage` lookup.
    /// Avoids subclassing the `final class DocumentCanvasView` just for tests.
    var keyboardLanguageProviderForTesting: (() -> String?)?

    /// Keyboard input-language pre-selection (mirrors the legacy `ChatInputTextView`). The chat composer
    /// seeds `initialPrimaryLanguage` from the draft's saved keyboard language. On the FIRST `textInputMode`
    /// query after it is set, return the active input mode whose `primaryLanguage` matches, so the keyboard
    /// opens in that language; thereafter report `super.textInputMode` (the live keyboard), which is the value
    /// the host reads back as the current input language.
    ///
    /// LOAD-BEARING ORDERING INVARIANT: the override is single-shot (the first query consumes the
    /// pre-selection and flips `didInitializePrimaryInputLanguage`). The host's read-back also queries
    /// `textInputMode`, so correctness depends on UIKit querying first — which it does, because
    /// `becomeFirstResponder` brings up the keyboard (querying `textInputMode`) before any keystroke or host
    /// read. This matches the legacy node exactly; do NOT add a separate non-side-effecting read path.
    var initialPrimaryLanguage: String?
    private var didInitializePrimaryInputLanguage = false

    override var textInputMode: UITextInputMode? {
        if !self.didInitializePrimaryInputLanguage {
            self.didInitializePrimaryInputLanguage = true
            if let initialPrimaryLanguage = self.initialPrimaryLanguage {
                for inputMode in UITextInputMode.activeInputModes {
                    if let primaryLanguage = inputMode.primaryLanguage, primaryLanguage == initialPrimaryLanguage {
                        return inputMode
                    }
                }
            }
        }
        return super.textInputMode
    }

    /// Re-arm the pre-selection so the next `textInputMode` query re-applies `initialPrimaryLanguage`.
    /// (The legacy `ChatInputTextNode.resetInitialPrimaryLanguage()` body is empty; this implements the
    /// documented intent. For the rich node this path is currently unreachable — its only caller is gated on
    /// `isCurrentlyEmoji()`, which the node reports `false`.)
    func resetInitialPrimaryLanguage() {
        self.didInitializePrimaryInputLanguage = false
        self.reloadInputViews()
    }

    // MARK: - Responder lifecycle (TASK 31, Family 8)
    //
    // **`super` stays HERE.** The backend owns the ordering AROUND these two calls and the
    // genuine-transition rule; it does not own the transition itself. Each witness therefore makes TWO
    // backend calls rather than one, which is why neither is in `RouterWitnessBodyTests`'
    // `enabledWitnesses` (that rule requires exactly one statement, and `super` is legitimately a
    // second) — `ResponderRouterTests` pins them from the backend side instead.
    //
    // The bodies these two used to carry are the five `legacy…` hooks below, moved VERBATIM and split
    // exactly where a host callback used to sit between two segments. Do not merge them: the split
    // points ARE the behaviour (see each hook's own note).

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        inputBackend.hostWillBecomeFirstResponder()
        let became = super.becomeFirstResponder()
        if became { inputBackend.hostDidBecomeFirstResponder() }
        else { inputBackend.hostDidFailToBecomeFirstResponder() }
        return became
    }

    /// TASK 31 (D24 clause (a)) — `becomeFirstResponder()`'s FIRST post-`super` segment, verbatim:
    /// show the own-drawn caret/handles once focused. It ran under `if became` before; the backend now
    /// runs it on the success path only, which is the same condition.
    func legacyDidBecomeFirstResponder() {
        refreshEmptyBoxWritingDirections(); updateCaretView(); updateSelectionHandleViews()
    }

    /// TASK 31 — the TRANSITION-GATED half of the old body's second line, kept as its own hook rather
    /// than folded into `legacyDidBecomeFirstResponder()` above.
    ///
    /// **This is load-bearing, and the obvious decomposition gets it wrong.** In the pre-seam body
    /// `didJustBecomeFirstResponder = true` sat INSIDE `if became && !wasFirstResponder`, alongside
    /// `onBecameFirstResponder?()` — it is not "the post-become work minus the transition test", it IS
    /// the transition test. The chat composer focuses the editor on touch-DOWN
    /// (`ChatTextInputPanelNode`'s touch-down recognizer -> `ensureFocusedOnTap()` ->
    /// `makeInputFirstResponder()` -> `RichTextEditorView.becomeFirstResponder()` -> here), and none of
    /// those hops tests `isFirstResponder` first, so a tap on an ALREADY-FOCUSED composer is a repeat
    /// `becomeFirstResponder()`. Setting this flag there would make `performSingleTap`
    /// (`+Interaction.swift`) classify every such tap as FOCUSING — and the edit menu would stop
    /// toggling. Pinned by
    /// `ResponderRouterTests.test_aRepeatBecomeFirstResponderDoesNotSetTheFocusingTapFlag`.
    func legacyMarkDidJustBecomeFirstResponder() {
        didJustBecomeFirstResponder = true
    }

    /// TASK 31 — `becomeFirstResponder()`'s LAST segment, verbatim: install + preheat the native
    /// checker and seed `lastCheckedCaret` (no scan; native checks only words the caret traverses).
    ///
    /// **Separate from `legacyDidBecomeFirstResponder()` because ORDER is observable.** In the pre-seam
    /// body this ran AFTER `onBecameFirstResponder?()`, which is a public host callback the chat
    /// composer sets (-> `TelegramLifecycleInputClient.backendDidBeginEditing()`) and drives on every
    /// touch-down, so it can run arbitrary synchronous work between the two segments. Under a
    /// zero-behaviour-change phase that is enough to preserve the order rather than argue it inert.
    /// Pinned by
    /// `ResponderRouterTests.test_becomeFirstResponder_runsTheNativeCheckingInstallAfterTheHostCallback`.
    func legacyFinishBecomingFirstResponder() {
        inputBackend.installCheckingIfNeeded(); nativeChecker?.preheat(); lastCheckedCaret = head
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        inputBackend.hostWillResignFirstResponder()
        let resigned = super.resignFirstResponder()
        if resigned { inputBackend.hostDidResignFirstResponder() }
        else { inputBackend.hostDidFailToResignFirstResponder() }
        return resigned
    }

    /// TASK 31 — `resignFirstResponder()`'s pre-`super` segment, verbatim. **Unconditional, unlike the
    /// become side**: it ran before the `wasFirstResponder` capture and before `super`, so it is not
    /// gated on the resign succeeding. `ResponderRouterTests
    /// .test_resignFirstResponder_whenNeverFocused_stillRunsThePreResignTeardown` pins that half.
    func legacyWillResignFirstResponder() {
        finalizeMarkedText()
        breakUndoCoalescing()   // losing focus ends any open typing/deleting run (matches native)
        cancelFloatingCursor()  // tear down any in-flight floating-cursor gesture (display link retains self)
    }

    /// TASK 31 — `resignFirstResponder()`'s post-`super` segment, verbatim, and **the asymmetry with
    /// the become side is the interesting part**: here the flag write was NOT transition-gated (only
    /// `onResignedFirstResponder?()` was), so both statements belong in one un-gated hook. Hiding the
    /// caret/handles and dropping a stale focusing-tap flag both happen on any successful resign.
    func legacyDidResignFirstResponder() {
        updateCaretView(); updateSelectionHandleViews()   // hide caret + handles (no longer FR)
        didJustBecomeFirstResponder = false               // don't carry a stale focusing-tap flag across a defocus
    }

    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(handleTabKey)),
         UIKeyCommand(input: "\t", modifierFlags: .shift, action: #selector(handleShiftTabKey)),
         // HARDWARE Return (plain + ⌘) routes to the host's return handler (send-on-Enter / ⌘-Enter) before
         // the editor inserts a newline — mirrors the legacy ChatInputTextViewImpl's own \r keyCommands. As the
         // first responder these take precedence over the app-level empty-action \r shortcut (which only
         // supplied the "Send Message" discoverability title). The SOFTWARE keyboard's Return doesn't fire
         // keyCommands, so it still inserts a newline via insertText.
         UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(handleReturnKey(_:))),
         UIKeyCommand(input: "\r", modifierFlags: .command, action: #selector(handleReturnKey(_:))),
         // Formatting shortcuts owned by the editor. The app-level ones (ChatControllerKeyShortcuts) mutate
         // the LEGACY ChatTextInputState (NSAttributedString), which the native editor doesn't use — so ⌘B
         // etc. silently no-op'd once the editor became the composer. The editor is the first responder, so
         // these keyCommands take precedence over KeyShortcutsController's (which sits higher in the chain),
         // fixing BOTH the chat composer and the attachment/article editor (both embed this view). Inputs +
         // modifiers match the app-level shortcuts.
         UIKeyCommand(input: "B", modifierFlags: .command, action: #selector(keyToggleBold)),
         UIKeyCommand(input: "I", modifierFlags: .command, action: #selector(keyToggleItalic)),
         UIKeyCommand(input: "U", modifierFlags: .command, action: #selector(keyToggleUnderline)),
         UIKeyCommand(input: "X", modifierFlags: [.command, .shift], action: #selector(keyToggleStrikethrough)),
         UIKeyCommand(input: "M", modifierFlags: [.command, .shift], action: #selector(keyToggleMonospace))]
    }
    @objc private func handleTabKey() {
        // Inside a table cell → cell nav; otherwise a quote-aware Tab (body → author end, author → out).
        if isInsideTable(head) { moveToCell(forward: true); return }
        handleQuoteTabForward()
    }
    @objc private func handleShiftTabKey() { moveToCell(forward: false) }
    @objc private func handleReturnKey(_ command: UIKeyCommand) { performHardwareReturn(command.modifierFlags) }
    /// Ask the host first (send-on-Enter etc.). true (or no host) → insert a newline like a normal Return;
    /// false → the host consumed it (sent the message), so the editor does nothing.
    func performHardwareReturn(_ modifierFlags: UIKeyModifierFlags) {
        if onHardwareReturn?(modifierFlags) ?? true { insertText("\n") }
    }
    @objc private func keyToggleBold() { toggleBold() }
    @objc private func keyToggleItalic() { toggleItalic() }
    @objc private func keyToggleUnderline() { toggleUnderline() }
    @objc private func keyToggleStrikethrough() { toggleStrikethrough() }
    @objc private func keyToggleMonospace() { toggleInlineCode() }

    /// Applies a theme: updates the mapper (text/link colors used on the next reload) and pushes the accent
    /// color to the persistent caret/selection/blockquote views. The caller reloads content afterward so the
    /// boxes rebuild with the themed mapper.
    func applyTheme(_ theme: RichTextEditorTheme) {
        self.mapper.theme = theme
        self.caretView.accentColor = theme.accent
        self.transientCaretView.accentColor = theme.accent
        self.startHandleView.accentColor = theme.accent
        self.endHandleView.accentColor = theme.accent
        self.blockquoteUnderlay.accentColor = theme.accent
        self.pullQuoteUnderlay.accentColor = theme.accent
        self.pullQuoteMarksView.accentColor = theme.accent
    }

    /// Applies quote geometry: rebuilds the mapper's stylesheet with the indent/trailing/spacing fields
    /// (preserving theme/emojiScale/writing-direction — the stylesheet is immutable) and pushes the
    /// render-only bar/radius/fill values to the underlay. The caller reloads afterward (mirrors applyTheme).
    func applyQuoteStyle(_ q: QuoteStyle) {
        self.quoteStyle = q
        var s = self.mapper.styleSheet
        s.quoteIndent = q.leadingInset
        s.quoteTrailingInset = q.trailingInset
        s.quoteSpacingBefore = q.spacingBefore
        s.quoteSpacingAfter = q.spacingAfter
        s.quoteTopInset = q.topInset
        s.quoteBottomInset = q.bottomInset
        self.mapper = AttributedStringMapper(styleSheet: s, emojiScale: self.mapper.emojiScale,
                                             theme: self.mapper.theme,
                                             baseWritingDirection: self.mapper.baseWritingDirection,
                                             formulaRenderer: self.mapper.formulaRenderer,
                                             buttonIconProvider: self.mapper.buttonIconProvider)
        self.blockquoteUnderlay.barWidth = q.barWidth
        self.blockquoteUnderlay.cornerRadius = q.cornerRadius
        self.blockquoteUnderlay.fillAlpha = q.fillAlpha
    }

    /// Applies code-block geometry: stores the style and resolves its optionals into the stylesheet
    /// against the shared render metrics. The caller reloads so the new insets take effect.
    func applyCodeStyle(_ c: CodeStyle) {
        self.codeStyle = c
        var s = self.mapper.styleSheet
        s.codeVerticalInset = c.verticalInset ?? s.metrics.code.verticalInset
        s.codeLanguageSpacing = c.languageSpacing ?? s.metrics.code.languageSpacing
        s.codeHorizontalInset = c.horizontalInset
        s.codeCornerRadius = c.cornerRadius
        self.mapper = AttributedStringMapper(styleSheet: s, emojiScale: self.mapper.emojiScale,
                                             theme: self.mapper.theme,
                                             baseWritingDirection: self.mapper.baseWritingDirection,
                                             formulaRenderer: self.mapper.formulaRenderer,
                                             buttonIconProvider: self.mapper.buttonIconProvider)
    }

    /// Applies pull-quote geometry: stores the style, pushes corner radius + fill alpha to the barless pill
    /// underlay, and stores the value so the next box build picks up the new padding. The caller reloads
    /// afterward (mirrors applyQuoteStyle — no mapper rebuild needed; geometry is read at box-build time).
    func applyPullQuoteStyle(_ s: PullQuoteStyle) {
        self.pullQuoteStyle = s
        self.pullQuoteUnderlay.cornerRadius = s.cornerRadius
        self.pullQuoteUnderlay.fillAlpha = s.fillAlpha
    }

    /// Applies host media geometry: stores it so the next box build (`setBlocks` / `insertMedia`) uses the
    /// new bleed. Pure geometry — no mapper rebuild (unlike `applyQuoteStyle`). The caller reloads afterward.
    func applyMediaBlockStyle(_ m: MediaBlockStyle) {
        self.mediaBlockStyle = m
    }

    /// Applies host-injected collapse/expand icons: stores them (read at `BlockQuoteBox` creation).
    /// The caller reloads afterward.
    func applyQuoteCollapseIcons(_ icons: RichTextEditorQuoteCollapseIcons?) {
        self.quoteCollapseIcons = icons
    }

    /// Applies host-supplied render metrics: rebuilds the mapper's stylesheet around them (preserving
    /// the other stylesheet fields + theme/emojiScale/writing-direction — the stylesheet is immutable).
    /// The caller reloads afterward (mirrors `applyQuoteStyle`). A host passes the metrics its
    /// counterpart InstantPage V2 surface will use, so the editor is WYSIWYG against it.
    func applyRenderMetrics(_ m: RichTextRenderMetrics) {
        var s = self.mapper.styleSheet
        s.metrics = m
        // `metrics.code` is the FALLBACK for an unset `CodeStyle` field, so the resolved values have
        // to be recomputed here too — a host that sets `renderMetrics` after `codeStyle` would
        // otherwise keep the stale defaults, which is exactly the drift this contract exists to stop.
        s.codeVerticalInset = self.codeStyle.verticalInset ?? m.code.verticalInset
        s.codeLanguageSpacing = self.codeStyle.languageSpacing ?? m.code.languageSpacing
        self.mapper = AttributedStringMapper(styleSheet: s, emojiScale: self.mapper.emojiScale,
                                             theme: self.mapper.theme,
                                             baseWritingDirection: self.mapper.baseWritingDirection,
                                             formulaRenderer: self.mapper.formulaRenderer,
                                             buttonIconProvider: self.mapper.buttonIconProvider)
    }

    /// Builds a box per block (paragraph, image, or table). Tables become `TableBlockBox`es whose
    /// cells the canvas reaches via `leafRegions()`.
    func setBlocks(_ blocks: [Block], width: CGFloat) {
        spellResults = [:]   // stale per-block results (keyed by BlockID) must not linger across a document swap
        spellingAlternatives = [:]   // same staleness risk (keyed by BlockID) as spellResults above
        if width > 0 { lastLayoutWidth = width }
        breakUndoCoalescing()   // a full document swap — programmatic set OR an undo/redo restore (the registerUndo closure calls setBlocks) — ends any open typing/deleting run
        tableSelection = nil
        imageSelection = nil   // a full document swap drops any transient structural selection
        spoilerDustViews.values.forEach { $0.view.removeFromSuperview() }
        spoilerDustViews.removeAll()
        spoilerRuns = []
        spoilerRevealHint = nil
        // `width` here is the raw canvas width; the per-box TextKit layout is re-done at the content width
        // (bounds − 2·pageMargin) on the next `layoutSubviews` pass, so this init width is a transient hint.
        boxes = blocks.compactMap {
            makeBox(for: $0, mapper: mapper, quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle,
                    expandImage: quoteCollapseIcons?.expand, collapseImage: quoteCollapseIcons?.collapse,
                    horizontalBleed: mediaBlockStyle.horizontalBleed, width: width)
        }
        recomputeSpans()
        recomputeDocumentHasSpoilers()   // a fresh document may load spoilers, or none (gates syncSpoilers)
        // TASK 39: a per-endpoint CLAMP of the selection the document swap may have invalidated, applied
        // through `applyCaretOutcome` (`+Editing.swift`) — the raw, non-publishing pair — and NOT
        // through `setSelection(_:reason: .externalSynchronization)`, which the brief specified.
        // Three reasons — **and Rule 27 says which is which, because only one of the three has been
        // built and run** (fix round 1; Task 39's review measured the second and it did NOT reproduce):
        //   1. **ARGUED, and sufficient on its own: `setSelection` would GATE the clamp.** Its
        //      `editPolicy.isSelectable` check drops the write entirely, so a non-selectable policy
        //      would leave `anchor`/`head` pointing PAST the new `documentSize`. The clamp is a safety
        //      invariant of the swap, not a user selection attempt; it must not be droppable.
        //      Unobservable today — production runs `.legacyUnrestricted` — which is exactly why no
        //      suite can measure it and why the argument has to carry it.
        //   2. **UNPROVEN — a hypothesis, not a finding. It would trap on a detached backend**
        //      (`guard isAttached` → `assertionFailure` in DEBUG), and `setBlocks` is the document-swap
        //      primitive, reached from `reload`, `registerUndo`'s restore and `spliceFragmentInEditing`
        //      — but **the review built the publishing clamp and measured 0 traps**: no
        //      `detach()`-then-swap probe exists. Class 2 at `applyCaretOutcome` is real; this SITE is
        //      not a demonstrated instance of it. Do not cite it as one.
        //   3. **ARGUED: it would publish inside somebody else's bracket.** Both of the first two
        //      callers run it inside `notifyingContentAndSelectionChange { }`, and the third inside
        //      `editing { }`.
        // **`.range`, NOT `.caret`.** Each endpoint is clamped INDEPENDENTLY and the pair's direction is
        // preserved, exactly as the two raw writes did — a reversed selection stays reversed (`.range`
        // does not normalize). Collapsing this to a caret would silently drop a surviving selection on
        // every document swap; that is axis 2 of the plan's blind-axes block — **and until Task 39 this
        // site had NO pin at all.** Measured: with `.caret(at: min(head, documentSize))` built here, the
        // full `Scripts/iostest.sh` reported **zero failures**. The pin is now
        // `DocumentRevisionTests.test_setBlocks_clampsEachSelectionEndpointIndependently_soASurvivingRangeSurvives`
        // and its reversed twin, which need ONE endpoint inside the shrunken document and one outside —
        // with both outside, the two spellings agree and the test is vacuous (Rule 16).
        applyCaretOutcome(.range(min(anchor, documentSize), min(head, documentSize)))
        bumpDocumentRevision()   // a whole-document replacement is a content mutation
        notifyContentSizeChanged(); setNeedsDisplay()
        // Re-apply what we already know BEFORE the first layout of the new boxes: a rebuild (theme /
        // quote style / undo restore) reconstructs them from the model, which carries no colours, and
        // waiting for the debounced pass would show a plain frame first.
        reapplyCachedSyntaxHighlights()
        scheduleSyntaxHighlightPass()   // a document seed / undo restore changes every spec
        lastCheckedCaret = nil   // a fresh document: nothing checked until the caret traverses it
    }

    /// A full-document replacement that NOTIFIES the input system (so the keyboard's shadow document
    /// stays in sync — an unbracketed reload is a top cause of stale/misplaced predictions). Use this
    /// from the public `document` setter; `setBlocks` alone is for internal layout-only rebuilds.
    func reload(_ blocks: [Block], width: CGFloat) {
        finalizeMarkedText()
        inputBackend.notifyingContentAndSelectionChange {   // TASK 26: the backend is the only emitter
            // TASK 39b: the synchronization sits INSIDE the notify bracket, after the content is in
            // place and before `textDidChange` — "before the new document is published visually". The
            // bracket opens NO transaction (`+Notifications.swift`), so the change is processed inline
            // rather than deferred, which `ExternalSynchronizationTests
            // .test_theChangeIsDeliveredBeforeTextDidChange` measures rather than assumes.
            // `.discard`: the whole document is replaced, so a marked range into the old one cannot
            // rebase — and `finalizeMarkedText()` above has already committed any composition.
            synchronizingExternalChange(reason: .documentReplacement, markedTextPolicy: .discard) {
                setBlocks(blocks, width: width)
            }
        }
        refreshEmptyBoxWritingDirections()
    }

    func currentBlocks() -> [Block] { boxes.map { $0.currentBlock() } }

    // MARK: - Viewport helpers

    /// The visible canvas rect: the host scroll view's window onto the content, or `bounds` when there
    /// is no scroll-view host (most unit tests / a non-scroll embed) — in which case the band covers the
    /// whole document and every box realizes (behavioral invariance).
    func viewportRect() -> CGRect {
        if let sv = superview as? UIScrollView { return CGRect(origin: sv.contentOffset, size: sv.bounds.size) }
        return bounds
    }

    /// The visible rect grown by the overscan band (one viewport height each side by default).
    func viewportBand() -> CGRect { overscanRect(for: viewportRect()) }

    /// The blockquote run fills that intersect `band` (off-screen runs are dropped so they allocate no
    /// underlay image view). The no-scroll-host fallback band covers the whole document ⇒ all runs kept.
    func visibleBlockquoteFills(band: CGRect) -> [CGRect] {
        // Quote fills only (including nested), from the recursive blockQuoteFillRects(). Code bands
        // are painted by `CodeBlockBox` itself, so they are deliberately not fed here.
        let all = blockQuoteFillRects()
        return all.filter { $0.intersects(band) }
    }

    /// Reconciles the back-most blockquote underlay to only the on-screen quote runs, and the barless
    /// pull-quote underlay to the content-hugging pill rects for all pull-quote boxes.
    func syncBlockquoteUnderlay() {
        blockquoteUnderlay.sync(runFills: visibleBlockquoteFills(band: viewportBand()))
        pullQuoteUnderlay.sync(runFills: pullQuotePillRects())
    }

    private func overscanRect(for visible: CGRect) -> CGRect {
        let overscan = blockViewOverscan >= 0 ? blockViewOverscan : visible.height
        return visible.insetBy(dx: 0, dy: -overscan)
    }

    /// Indices of the boxes whose drawn extent overlaps `band` — boundary-touching boxes ARE included
    /// (a conservative over-realization that avoids a blank strip at the exact viewport edge). Binary-
    /// searches the y-monotonic box frames (`BlockStack.layout` stacks them top-to-bottom, so `frame.minY`
    /// strictly increases), then widens outward while a neighbor's `blockViewFrame` (which may spill past
    /// `frame`, e.g. a full-bleed image) still intersects. Cost: O(log N + window).
    func blockWindow(forBand band: CGRect) -> [Int] {
        let n = boxes.count
        guard n > 0 else { return [] }
        // first index whose frame is NOT entirely above the band (frame.maxY >= band.minY)
        var lo = 0, hi = n
        while lo < hi { let m = (lo + hi) / 2; if boxes[m].frame.maxY < band.minY { lo = m + 1 } else { hi = m } }
        var first = lo
        // last index that STARTS at or before the band's bottom (frame.minY <= band.maxY)
        lo = 0; hi = n
        while lo < hi { let m = (lo + hi) / 2; if boxes[m].frame.minY <= band.maxY { lo = m + 1 } else { hi = m } }
        var last = lo - 1
        guard first <= last else { return [] }
        // Forward-looking guard: current types (image/table) don't spill vertically past their frame, but
        // a future non-text embed might — so widen on blockViewFrame, not frame.
        while first > 0 && boxes[first - 1].blockViewFrame.intersects(band) { first -= 1 }
        while last < n - 1 && boxes[last + 1].blockViewFrame.intersects(band) { last += 1 }
        return Array(first...last)
    }

    // MARK: - Block view pool

    /// Reconciles the block-view pool against the boxes currently in (or near) the viewport: realize the
    /// boxes whose drawn extent intersects the overscan band, recycle the rest. `blockViews` therefore
    /// holds only the *realized* views. Called from `layoutSubviews` (via `syncBlockViews()`) and the
    /// host's `scrollViewDidScroll` (via `viewportDidChange()`).
    /// Returns `true` when a fresh `TableBackingView` was created this call (used by `viewportDidChange`
    /// to decide whether to re-host cell emoji into the new content view).
    @discardableResult
    func reconcileBlockViews(visibleRect: CGRect) -> Bool {
        var createdFreshTable = false
        let band = overscanRect(for: visibleRect)
        var wantedIDs = Set<BlockID>()

        // Realize (create or rebind) one box's backing view.
        func realize(_ box: CanvasBlock) {
            wantedIDs.insert(box.id)
            if let view = blockViews[box.id] {
                bindRealizedView(view, to: box, fresh: false)          // stayed realized
            } else {
                let view: BlockBackingView
                if box is TableBlockBox {
                    let t = TableBackingView(); t.canvas = self
                    t.pendingOffsetRestore = true                       // restore saved H-scroll on first layout
                    view = t
                    createdFreshTable = true
                } else if box is ButtonRowBox {
                    // Hosts a ButtonPillView per pill rather than drawing into its backing store, so a
                    // pill label can carry a live custom emoji. Not recycled through the plain-view pool:
                    // a recycled plain view would draw nothing and a recycled row view would keep stale
                    // pill subviews.
                    let r = ButtonRowBackingView(); r.canvas = self
                    view = r
                } else {
                    view = dequeueRecycledView()                        // reuse (or create) a plain backing view
                }
                blockViews[box.id] = view
                insertSubview(view, aboveSubview: blockquoteUnderlay)    // above the back-most quote fills, below the overlays
                bindRealizedView(view, to: box, fresh: true)
            }
        }

        // DFS in tree order. Realize a box when it renders-as-view AND its extent meets the band, then descend
        // into a details / (expanded) block-quote body (NOT table cells — a `TableBackingView` self-hosts those,
        // so a nested table gets its own view here and hosts its own cell views). Visiting a container BEFORE
        // its children means a FRESH container chrome view is inserted below its fresh child views (children
        // draw above the chrome). A container off-band ⇒ its children (within its frame) are off-band too.
        func realizeTree(_ box: CanvasBlock) {
            let inBand = box.blockViewFrame.intersects(band)
            if box.rendersAsBlockView, inBand { realize(box) }
            guard inBand else { return }
            if let d = box as? DetailsBox {
                for c in d.children.boxes { realizeTree(c) }
            } else if let bq = box as? BlockQuoteBox, !bq.collapsed {
                for c in bq.children.boxes { realizeTree(c) }
            }
        }

        for i in blockWindow(forBand: band) { realizeTree(boxes[i]) }   // top-level binary-search; recurse visible containers

        for (id, view) in blockViews where !wantedIDs.contains(id) {
            view.removeFromSuperview()
            blockViews[id] = nil
            // A ButtonRowBackingView is excluded for the same reason a TableBackingView is: it is a
            // subclass with its own subviews and an empty `draw(_:)`, so recycling it for a paragraph
            // would render that paragraph blank.
            if !(view is TableBackingView), !(view is ButtonRowBackingView) {
                view.box = nil                                          // drop the strong ref to the old box
                view.lastRenderedSignature = nil
                if recycleQueue.count < recycleQueueCap { recycleQueue.append(view) }
            }
            // A TableBackingView is released; its `contentOffsetX` already lives on the box.
        }
        return createdFreshTable
    }

    /// `syncBlockViews()` keeps its old call sites (`layoutSubviews`) but is now viewport-aware.
    func syncBlockViews() { reconcileBlockViews(visibleRect: viewportRect()) }

    /// TASK 32 (Family 9) — a one-line router. The body moved to `legacyViewportDidChange()` below;
    /// `RichTextEditorView.scrollViewDidScroll` still calls THIS member, so the host-facing entry point
    /// is unchanged and the backend is what decides what a viewport change means.
    func viewportDidChange() {
        inputBackend.viewportDidChange()
    }

    /// TASK 32 (D24 clause (a)) — `viewportDidChange()`'s body, verbatim.
    ///
    /// Called when only the VIEWPORT moved (the host scrolled) — frames are unchanged, so no relayout:
    /// re-realize block views + emoji against the moved viewport, re-cull the blockquote underlay, and
    /// re-home the caret/handles (a caret hosted in a table that was just realized must re-attach).
    func legacyViewportDidChange() {
        bumpLayoutGeneration()
        let realizedFreshTable = reconcileBlockViews(visibleRect: viewportRect())
        syncBlockquoteUnderlay()
        // A freshly re-realized table has a brand-new (empty) content view; re-host emoji so its cell
        // emoji migrate back into it. Otherwise the cheap hide/show cull suffices (frames unchanged).
        if realizedFreshTable { syncEmojiViews(); syncButtonPillViews(); syncChecklistMarkerViews(); syncMediaItemViews() } else { cullEmojiViews(); cullButtonPillViews(); cullMediaItemViews() }
        refreshSelectionUI()
        scrollCaretIntoViewIfNeeded()
    }

    private func dequeueRecycledView() -> BlockBackingView {
        if let v = recycleQueue.popLast() { return v }
        let v = BlockBackingView(); v.canvas = self; return v
    }

    /// Binds (or re-binds) a realized view to its box: frame, table H-scroll sync, and the repaint gate.
    /// `fresh` = the view was just created/recycled (its bitmap is stale ⇒ force a repaint).
    private func bindRealizedView(_ view: BlockBackingView, to box: CanvasBlock, fresh: Bool) {
        // A structural edit (split/merge) keeps a surviving block's BlockID but swaps its BlockBox for a
        // brand-new instance whose fresh BlockLayout resets `renderVersion` to 0. `renderSignature` encodes
        // that per-instance counter, so it is MEANINGLESS to compare across a box-instance replacement —
        // a same-height/same-style upper half can collide with the old signature and wrongly skip the
        // repaint, leaving the pre-split full-text bitmap. Detect the instance swap and force a repaint;
        // the signature gate below still covers the common same-instance cases (scroll, typing in place).
        let boxInstanceChanged = view.box !== box
        view.box = box
        view.frame = box.blockViewFrame                                  // image: full drawn extent; table: visible window
        if let t = box as? TableBlockBox, let tv = view as? TableBackingView, !fresh {
            t.contentOffsetX = max(0, tv.scroll.contentOffset.x)         // a stays-realized table: sync view→box
        }
        view.setNeedsLayout()
        if let p = box as? BlockBox {
            let sig = p.renderSignature
            if fresh || boxInstanceChanged || view.lastRenderedSignature != sig {   // recycled OR rebound OR content changed
                view.lastRenderedSignature = sig
                view.setNeedsDisplay()
            }
        } else {
            view.setNeedsDisplay()   // image/table: no renderSignature gate, so always repaint (they're few)
        }
    }

    var realizedBlockViewCountForTesting: Int { blockViews.count }
    func isBlockViewRealizedForTesting(_ id: BlockID) -> Bool { blockViews[id] != nil }
    func blockViewForTesting(_ id: BlockID) -> UIView? { blockViews[id] }
    func checklistMarkerViewForTesting(_ id: BlockID) -> UIView? { checklistMarkerViews[id]?.view }
    var recycleQueueDepthForTesting: Int { recycleQueue.count }

    /// Called by a `TableBackingView` whenever its inner scroll view moves: keep the box's `contentOffsetX`
    /// in lock-step (canvas-space queries fold it in, Task 3) and repaint the offset-dependent chrome/caret.
    func tableDidScroll(_ view: TableBackingView) {
        bumpLayoutGeneration()
        guard let t = view.box as? TableBlockBox else { return }
        t.contentOffsetX = max(0, view.scroll.contentOffset.x)
        refreshSelectionUI()
        blockChromeOverlay.setNeedsDisplay()
    }

    func setParagraphs(_ paragraphs: [ParagraphBlock], width: CGFloat) {
        setBlocks(paragraphs.map { .paragraph($0) }, width: width)
    }

    func currentParagraphs() -> [ParagraphBlock] {
        boxes.compactMap { ($0 as? BlockBox)?.currentParagraph() }
    }

    /// Assigns each box its `nodeStart` (= prior tokens + 1) and accumulates `documentSize` from each
    /// box's `nodeSize` (paragraph: textLength+2; image: textLength+5). Matches `RichTextEditorCore`
    /// row-major token addressing.
    func recomputeSpans() {
        documentSize = root.recompute(baseOffset: 0)
        for case let t as TableBlockBox in boxes { t.recompute() }
        for case let bq as BlockQuoteBox in boxes { bq.recompute() }
        for case let d as DetailsBox in boxes { d.recompute() }
    }

    /// The box whose text contains `pos` (inclusive of the trailing caret slot), or nil at a
    /// structural boundary between blocks.
    func box(containingGlobal pos: Int) -> (box: CanvasBlock, local: Int)? {
        for box in boxes where pos >= box.textStart && pos <= box.textStart + box.textLength {
            return (box, pos - box.textStart)
        }
        return nil
    }

    /// All editable leaf regions in document order (recurses into tables). v1: rebuilt per call; cache
    /// if profiling shows it matters.
    func allLeafRegions() -> [LeafTextRegion] { root.leafRegions() }

    /// Leaf regions whose owning box intersects `rect`, in canonical document order, plus the regions
    /// containing each `alwaysInclude` global offset (which may be far offscreen — they are the
    /// selection's endpoints and must always be drawable).
    ///
    /// CANVAS-INTERNAL. `LeafTextRegion`'s first stored property is `let layout: BlockLayoutEngine`
    /// (`Canvas/LeafTextRegion.swift`), so this type may never appear in a client signature.
    ///
    /// Cost: O(log N + window) for the walk, plus O(N) once per `alwaysInclude` offset — the endpoints
    /// are a two-element list, and `allLeafRegions()` is what the unbounded path pays on EVERY call.
    /// `alwaysInclude` entries must already be resolved to a real leaf region's own `globalStart`
    /// (see `leafRegionEndpoint(_:preferring:)`) — this only does exact containment, no gap fallback.
    /// (`legacySelectionSegments` is the sole caller and always pre-resolves; see its comment.)
    func leafRegions(intersecting rect: CGRect, alwaysInclude: [Int]) -> [LeafTextRegion] {
        // blockWindow(forBand:) binary-searches the y-monotonic box frames and widens on blockViewFrame;
        // reuse it rather than re-deriving the window. It returns TOP-LEVEL indices, and
        // CanvasBlock.leafRegions() recurses into tables / details / expanded quotes for us.
        var out: [LeafTextRegion] = []
        var seen = Set<Int>()                       // globalStart is unique per leaf region
        for i in blockWindow(forBand: rect) {
            for r in boxes[i].leafRegions() where seen.insert(r.globalStart).inserted {
                out.append(r)
            }
        }
        for pos in alwaysInclude {
            guard let (r, _) = leafRegion(containingGlobal: pos), seen.insert(r.globalStart).inserted else { continue }
            out.append(r)
        }
        out.sort { $0.globalStart < $1.globalStart }
        return out
    }

    /// Direction to prefer when resolving an endpoint that lands in a structural gap (owned by no leaf
    /// region): `.following` for a SELECTION START (the selection's first real content is what comes
    /// next), `.preceding` for a SELECTION END (the selection's last real content is what came before).
    /// Getting this backwards is exactly the fix-round-1 defect: a direction-AGNOSTIC fallback resolved
    /// an END endpoint to the FOLLOWING region, which can never appear in `legacySelectionSegments`'s
    /// output for that range (its clamped span is empty), permanently unsetting `containsEnd` —
    /// `test_containsEndMatchesTheWitnessAtAnInteriorStructuralGap` pins this at a genuine INTERIOR gap
    /// (a captioned media atom's 2-position gap before its caption), not just the document's own two
    /// boundary sentinels, where the old symmetric rule happened to be right by coincidence.
    enum LeafRegionGapDirection { case following, preceding }

    /// The leaf region that "owns" `pos` for endpoint purposes: exact containment
    /// (`leafRegion(containingGlobal:)`) when `pos` addresses real content, else the nearest region in
    /// `direction` — mirroring the block-level "a tap in a gap resolves to the block below" gap-ownership
    /// convention for `.following`. Degrades gracefully at the document's own extremes, where there is
    /// nothing on the preferred side: `.following` past the last region falls back to the last region;
    /// `.preceding` before the first region falls back to the first. That degradation is CORRECT there
    /// (a genuine whole-document range — `selectAllText()`'s degenerate-table branch uses exactly
    /// `(0, documentSize)` — addresses the document's own leading/trailing structural tokens, which own
    /// no leaf region themselves: `leafRegion(containingGlobal:)` returns nil for both `0` and
    /// `documentSize`, verified — the first leaf region's `globalStart` is `1`, and the last region's
    /// `globalStart + length` is one less than `documentSize`), but it is NOT the general rule for an
    /// interior gap, which is why this takes a direction rather than always preferring one side.
    private func leafRegionEndpoint(_ pos: Int, preferring direction: LeafRegionGapDirection) -> LeafTextRegion? {
        if let (r, _) = leafRegion(containingGlobal: pos) { return r }
        let all = allLeafRegions()
        switch direction {
        case .following:
            return all.first(where: { $0.globalStart > pos }) ?? all.last
        case .preceding:
            return all.last(where: { $0.globalStart + $0.length <= pos }) ?? all.first
        }
    }

    /// An attributed SNAPSHOT of a global range, assembled from the intersecting leaf regions.
    /// Returns a copy: the live text is `region.layout.attributedString`, i.e. the engine's
    /// NSTextStorage, which no caller outside layout may retain or mutate.
    ///
    /// The separator between two included regions follows the SAME rule as `legacyPlainText`'s "\n" at a
    /// crossed top-level paragraph boundary, table cells glued — via the shared `forEachLeafRegionInRange`
    /// walk (`DocumentCanvasView+UITextInput.swift`), not an independent `out.length > 0` check. Task 12
    /// fix round 1: the original version here inserted "\n" between every pair of appended regions
    /// regardless of table nesting, which disagreed with `legacyPlainText` on any range spanning more than
    /// one leaf region inside a table (e.g. a cross-cell range came out glued as plain text but
    /// newline-separated as attributed text). This is new code with no production consumer yet, so
    /// bringing it into agreement with the documented, already-shipped `legacyPlainText` invariant is not
    /// a behavior change to any existing surface.
    func legacyAttributedText(globalFrom: Int, globalTo: Int) -> NSAttributedString? {
        guard globalFrom >= 0, globalTo >= globalFrom, globalTo <= documentSize else { return nil }
        let out = NSMutableAttributedString()
        forEachLeafRegionInRange(globalFrom, globalTo) { region, needsSeparator in
            if needsSeparator { out.append(NSAttributedString(string: "\n")) }
            let a = max(globalFrom, region.globalStart), b = min(globalTo, region.globalStart + region.length)
            guard a < b else { return }
            out.append(region.layout.attributedString.attributedSubstring(
                from: NSRange(location: a - region.globalStart, length: b - a)))
        }
        return NSAttributedString(attributedString: out)
    }

    /// The leaf region containing `pos` (inclusive of the trailing caret slot), with the local offset.
    func leafRegion(containingGlobal pos: Int) -> (region: LeafTextRegion, local: Int)? {
        for r in allLeafRegions() where pos >= r.globalStart && pos <= r.globalStart + r.length {
            return (r, pos - r.globalStart)
        }
        return nil
    }

    /// Deviation D7: ".line" means "the whole enclosing leaf region" everywhere in this editor
    /// (DocumentTokenizer.swift:33,73,165), and BlockLayoutEngine exposes no line fragments. A true
    /// visual-line API would be an improvement, which the seam's non-goals forbid.
    func legacyLineRegion(containingGlobal pos: Int)
        -> (range: NSRange, lineID: RichTextInputLineID)? {
        // LeafTextRegion carries neither `blockID` nor `regionIndex` (S/Canvas/LeafTextRegion.swift:10-24
        // stores layout/globalStart/length/ref/canvasOrigin only), so both halves of the ID are DERIVED:
        //   * blockID — unwrapped from `ref`, which is a TextNodeRef whose every case has one BlockID
        //     payload (RichTextEditorCore/Position/TextNodeRef.swift:4-17).
        //   * regionIndex — the region's ordinal among the same block's regions in document order
        //     (a code block or a details box contributes several).
        // Both are stable for one layout generation, which is all `lineID`'s contract requires.
        let all = allLeafRegions()
        guard let idx = all.firstIndex(where: {
            pos >= $0.globalStart && pos <= $0.globalStart + $0.length
        }) else { return nil }
        let region = all[idx]
        let id = blockID(ofRef: region.ref)
        let regionIndex = all[..<idx].reduce(0) { blockID(ofRef: $1.ref) == id ? $0 + 1 : $0 }
        return (range: NSRange(location: region.globalStart, length: region.length),
                lineID: RichTextInputLineID(blockID: id, regionIndex: regionIndex))
    }

    /// The single `BlockID` payload of any `TextNodeRef` case.
    func blockID(ofRef ref: TextNodeRef) -> BlockID {
        switch ref {
        case .paragraph(let id), .caption(let id), .code(let id),
             .pullQuote(let id), .quoteAuthor(let id), .detailsTitle(let id),
             .codeLanguage(let id): return id
        }
    }

    func boxIndex(of box: CanvasBlock) -> Int? { boxes.firstIndex { $0 === box } }

    /// Public-within-module accessor for the façade.
    var documentSizeValue: Int { documentSize }

    /// The left/right padding from the canvas edge to the text: the built-in `pageMargin` plus the
    /// configurable `contentMargins` on that side. The text content width is the canvas width minus both.
    var contentLeftPad: CGFloat { self.pageMargin + contentMargins.left }
    var contentRightPad: CGFloat { self.pageMargin + contentMargins.right }
    func contentWidth(forWidth width: CGFloat) -> CGFloat { max(width - contentLeftPad - contentRightPad, 1) }

    /// Re-flows boxes to a new width if it changed, so the caller can read an accurate
    /// `intrinsicContentSize` BEFORE it sizes the canvas frame. Called from the façade's `performLayout`,
    /// which lays the canvas out explicitly (`layoutContent()`) right after — so this does not schedule
    /// layout itself.
    func setParagraphsWidthIfNeeded(_ width: CGFloat) {
        let content = contentWidth(forWidth: width)
        guard let first = boxes.first, abs(first.frame.width - content) > 0.5 || first.frame.width == 0 else { return }
        // TASK 39b: the bracket goes AFTER the guard, deliberately. A `return` inside a closure exits
        // the CLOSURE, so wrapping the whole body would fire a `.layoutOnly` external change on every
        // layout pass where nothing changed — the guard's entire purpose. Pinned by
        // `ExternalSynchronizationTests.test_aNoOpWidthPassSynchronizesNothing`.
        // `.layoutOnly` keeps the revision (the backend skips its adoption for this reason alone);
        // `.preserveIfRebasable` because a reflow moves no text, so a marked range survives.
        //
        // **WHY SILENCING THE SYNC TOWARD THE HOST MATTERS MOST HERE**, kept from the round-1 fix that
        // lived on these lines: this method's ONE production caller is
        // `RichTextEditorView.performLayout`, i.e. the host's own layout pass, so a host callback out
        // of the synchronization would be exactly the recursion the facade's layout contract forbids
        // ("`update` must NOT synchronously fire `onChange`"). MEASURED: with the sync unsilenced the
        // full suite was 2651/1, the single red being
        // `CanvasContentMarginsTests.test_facade_updateWithMargins_doesNotSynchronouslyFireOnChange`,
        // whose message is that invariant verbatim. There is nobody to notify anyway — the caller reads
        // the fresh `intrinsicContentSize` on its very next line. The suppression itself now lives
        // inside `synchronizingExternalChange`, uniformly for all five sites (review Major 1); this
        // site no longer holds one of its own, and must not re-acquire one — a site-level flag would
        // span `body()` too, and at the other four that would delete a PRE-EXISTING notification.
        synchronizingExternalChange(reason: .layoutOnly, markedTextPolicy: .preserveIfRebasable) {
            for box in boxes { box.setWidth(content) }
            recomputeSpans()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Skip a zero-width UIKit layout pass before the canvas is framed: laying out at width 0 builds the
        // media/overlay views at a 0×0 rect (and binds their fetch), redone the instant the real frame lands.
        // The parent (`RichTextEditorView.performLayout`) sets a non-zero canvas frame before calling
        // `layoutContent()` directly, so the real (framed) layout path is unaffected.
        if bounds.width > 0 {
            layoutContent()
        }
    }

    /// Lays out the document content + overlays against `bounds`. The parent
    /// (`RichTextEditorView.performLayout`) calls this DIRECTLY so layout never depends on the UIKit
    /// `needsLayout` flag — the editor's convention is that the parent drives layout explicitly and a view
    /// never `setNeedsLayout()`s itself; it only notifies the parent (`onContentSizeChange`). Also invoked
    /// by `layoutSubviews` for any UIKit-driven pass. Idempotent.
    func layoutContent() {
        bumpLayoutGeneration()
        if bounds.width > 0 { lastLayoutWidth = bounds.width }
        // The document's top-level sequence lays out on InstantPage V2's rhythm, so the editor's block
        // spacing matches the rendered message. Its metrics come from the mapper, so a host's
        // `renderMetrics` reaches the rhythm as well as the fonts.
        applyRootSpacingConfig()
        // A top-level code block's band reaches the CANVAS edge by default (the document-editor look,
        // and what the renderer does in a bubble). A compact host overrides it: the composer's canvas
        // sits inside the input field's rounded background, and `contentRightPad` also reserves room
        // for the accessory and send buttons — so the canvas edge is well past what the field shows.
        let codeBleed: (minXSide: CGFloat, maxXSide: CGFloat) = codeStyle.horizontalBleed
            .map { (minXSide: $0, maxXSide: $0) }
            ?? (minXSide: contentLeftPad, maxXSide: contentRightPad)
        _ = root.layout(origin: CGPoint(x: contentLeftPad, y: contentMargins.top),
                        width: contentWidth(forWidth: bounds.width),
                        codeBleed: codeBleed)
        for case let t as TableBlockBox in boxes { t.recompute() }   // cell frames depend on the table frame
        for case let bq as BlockQuoteBox in boxes { bq.recompute() }   // child frames depend on the quote frame
        for case let d as DetailsBox in boxes { d.recompute() }   // body child frames depend on the details frame
        stampListMarkers()
        syncBlockViews()
        blockquoteUnderlay.frame = bounds
        sendSubviewToBack(blockquoteUnderlay)
        pullQuoteUnderlay.frame = bounds
        sendSubviewToBack(pullQuoteUnderlay)   // goes below blockquoteUnderlay; block views (inserted aboveSubview: blockquoteUnderlay) are above both
        syncBlockquoteUnderlay()
        pullQuoteMarksView.frame = bounds
        pullQuoteMarksView.sync(marks: pullQuoteMarkRects())
        emojiOverlay.frame = bounds
        syncEmojiViews()
        syncButtonPillViews()
        syncChecklistMarkerViews()
        mediaOverlay.frame = bounds
        syncMediaItemViews()
        spoilerOverlay.frame = bounds
        syncSpoilers()
        selectionHighlight.frame = bounds
        bringSubviewToFront(selectionHighlight)   // above emoji
        // Extend the chrome overlay LEFT of x=0 so the row grip — which sits at a NEGATIVE x when the page
        // margin is zero (the composer draws it into the field's left padding) — isn't clipped by the overlay's
        // own draw context. A view's `draw(_:)` is ALWAYS bounded by its frame (the graphics context is the
        // frame), independent of `clipsToBounds`, so widening the frame is the only way to paint there. The
        // matching `bounds.origin` shift keeps it drawing in canvas coordinates (see BlockChromeOverlay).
        let chromeLeftExtension: CGFloat = 40
        blockChromeOverlay.frame = CGRect(x: -chromeLeftExtension, y: 0, width: bounds.width + chromeLeftExtension, height: bounds.height)
        blockChromeOverlay.bounds.origin = CGPoint(x: -chromeLeftExtension, y: 0)
        bringSubviewToFront(blockChromeOverlay)    // chrome stays above the selection wash
        blockChromeOverlay.setNeedsDisplay()
        updateCaretView()              // frames/geometry may have changed (re-flow, table relayout); idempotent.
        updateSelectionHandleViews()   // reposition the own-drawn handles too
        // TASK 32 (Family 9) — notification-only, and deliberately the LAST statement rather than the
        // first. `bumpLayoutGeneration()` at the top of this method has already advanced the counter, so
        // a call there and a call here report the SAME value; what differs is whether "layout did change"
        // is announced before or after the layout it names actually ran. The end is the honest reading,
        // and it is equivalent in coverage because this method has NO early returns — every entry that
        // bumps the generation also reaches this line. Nothing consumes the notification today (the
        // backend only stores it, see `lastObservedLayoutGeneration`), so both placements are
        // behaviour-neutral; the choice is recorded rather than left to be re-derived.
        //
        // NOT added to `viewportDidChange()`'s hook, which bumps the SAME counter — see
        // `lastObservedLayoutGeneration`'s own doc comment for what that means for the stored value.
        inputBackend.layoutDidChange(generation: layoutGeneration)
    }

    // TASK 31 (Family 8). `super` stays here, exactly as it does for become/resign; only the
    // `newWindow == nil` teardown body moves. Two statements, so this witness is likewise not in
    // `RouterWitnessBodyTests`' `enabledWitnesses` — `ResponderRouterTests` covers both the nil and
    // the non-nil argument, so a router that hard-coded `nil`, or that kept the branch on this side,
    // reads differently from a correct one.
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        inputBackend.hostWillMove(toWindow: newWindow)
    }

    /// TASK 31 (D24 clause (a)) — `willMove(toWindow:)`'s body, verbatim.
    /// `WindowDetachCharacterizationTests` calls this "the ONLY teardown for the two CADisplayLinks",
    /// so the branch stays exactly where it was: on the canvas, keyed on a nil window.
    func legacyWillMove(toWindow newWindow: UIWindow?) {
        if newWindow == nil {
            stopDragAutoScroll()     // don't let a CADisplayLink retain a torn-down view
            cancelFloatingCursor()   // same: tear down the floating-cursor display link on window removal
        }
    }

    /// Points the root stack at the document's rhythm (V2, top-level sequence, the host's metrics).
    /// EVERY height path states it rather than inheriting what the last one left, because any of them can
    /// run first: `layoutContent`, `intrinsicContentSize` (read by `performLayout` BEFORE the layout
    /// pass), and `measuredContentHeight` (a host measuring an unframed editor).
    func applyRootSpacingConfig() {
        root.spacingModel = .instantPageV2
        root.sequenceKind = .topLevel
        root.metrics = mapper.styleSheet.metrics
    }

    /// The content height the host sizes the scroll view from. **`root.currentHeight`, not a sum of box
    /// heights:** under the V2 rhythm a gap next to a block that cannot own it (a button row / table /
    /// media / code block at a sequence edge, or two such neighbours) is laid down as bare space
    /// belonging to no box frame, so summing box heights under-reports the laid-out extent — 4pt per
    /// bare gap, accumulating — and the trailing blocks fell outside the scrollable range: unreachable,
    /// overlapping the host's bottom inset band. A paragraphs-only document is unaffected (no bare gaps),
    /// which is why this stayed hidden.
    override var intrinsicContentSize: CGSize {
        applyRootSpacingConfig()
        return CGSize(width: UIView.noIntrinsicMetric,
                      height: contentMargins.top + root.currentHeight + contentMargins.bottom)
    }

    /// Stateless content height the document would have at canvas `width` — the measure analogue of
    /// `intrinsicContentSize.height` (same `contentMargins` + content-width derivation). Never mutates
    /// the live layout (no box `setWidth`, no frame/overlay/caret change).
    ///
    /// FRAMING DEPENDENCY (future enhancement): this reads each box's `topInset`/`bottomInset`
    /// (`BlockStack.measuredHeight` → `BlockBox.measuredHeight`), which are set only by a LAYOUT pass
    /// (`BlockStack.layout` via `facingInset`, run from `layoutContent`). So an editor that has NOT been
    /// framed/laid-out yet measures too tall — each box keeps its default `BlockBox.defaultVerticalInset`
    /// (8pt) rather than the host's configured inset (the composer's 0). Callers therefore measure a FRAMED
    /// editor (the live composer field is on-screen; the `measuredContentHeight` static probe sets a non-zero
    /// `probe.frame` before seeding). The robust fix (deferred) is to make the measure framing-independent —
    /// compute the facing insets here (mirroring `layout`) instead of reading the stored, layout-set values.
    func measuredContentHeight(forWidth width: CGFloat, contentMargins explicitMargins: UIEdgeInsets? = nil) -> CGFloat {
        // The measure must be PURE: a host sizing its field by this value (the chat composer) may call it
        // BEFORE the matching `update(...)` has pushed the real `contentMargins` onto the live canvas (a draft
        // applied before the editor is sized). Reading live `self.contentMargins` then yields a too-small height
        // (the right-inset reservation is missing → text measured at the full width → fewer wrapped lines), and
        // the field visibly grows on the next pass. So callers that know the intended margins pass them in;
        // others keep the live value.
        let margins = explicitMargins ?? self.contentMargins
        let contentW = max(width - (self.pageMargin + margins.left) - (self.pageMargin + margins.right), 1)
        // Same purity requirement for the RHYTHM: this can run before `layoutContent()` has ever set the
        // root's spacing model, so state it here too rather than inheriting whatever the last layout left.
        applyRootSpacingConfig()
        return margins.top + root.measuredHeight(forWidth: contentW) + margins.bottom
    }

    /// Notifies the host that the content height may have changed (e.g. after an edit), so it re-runs
    /// layout. The editor convention: a view never `setNeedsLayout()`s itself for a content change — it
    /// notifies its parent, which drives layout explicitly. `intrinsicContentSize` is a pure computed
    /// property, so there is nothing to invalidate; this only fires the callback.
    func notifyContentSizeChanged() {
        if suppressHostChangeNotification { return }   // step 1 of a two-step paste stays off-screen (no flash)
        onContentSizeChange?()
    }

    /// Selection/caret changes call `setNeedsDisplay()` without a layout pass; propagate the repaint to
    /// the selection overlays and the chrome overlay — and to TABLE views only (their cell wash is
    /// selection-dependent). Paragraph/image views are NOT cascaded: their pixels don't depend on the
    /// selection, so they repaint only via the signature gate in `syncBlockViews`.
    override func setNeedsDisplay() {
        super.setNeedsDisplay()
        for v in blockViews.values where v is TableBackingView { v.setNeedsDisplay() }
        selectionHighlight.setNeedsDisplay()
        blockChromeOverlay.setNeedsDisplay()
    }

    // No `draw(_:)` override: the canvas paints nothing of its own, so it allocates no document-sized
    // backing store (the surface-size lever). Every visual is a bounded subview — block content via each
    // `BlockBackingView`, the blockquote fills via the back-most `blockquoteUnderlay`, the selection wash
    // via `selectionHighlight` / each table's `CellSelectionView`, table chrome via `blockChromeOverlay`,
    // and the caret/handles via their own-drawn views.

    /// Draws the selection highlight for all NON-TABLE regions (body + image captions) plus the image-atom
    /// washes, in canvas coordinates. Called by the `selectionHighlight` overlay so it renders ON TOP of
    /// the text and the emoji subviews. Table-cell regions are excluded (their highlight rides each table's
    /// own content-view overlay so it tracks horizontal overscroll).
    func drawNonTableSelectionHighlight(in ctx: CGContext) {
        self.mapper.theme.accent.withAlphaComponent(0.30).setFill()
        if selFrom != selTo {
            for r in selectionHighlightRects(globalFrom: selFrom, globalTo: selTo,
                                             regionFilter: { !self.isRegionInTable($0) }) {
                ctx.fill(r)
            }
        }
        // Image-atom wash for a selected (range-covered or tap-selected) image — moved here from the
        // image's BlockBackingView so it sits above any caption emoji and reads consistently.
        for case let img as MediaBlockBox in boxes {
            if let rect = imageSelectionTintRect(for: img) { ctx.fill(rect) }
        }
    }

    /// True if `region` belongs to a table (its global start falls in a `TableBlockBox`'s node span). Such
    /// regions' highlight is drawn by the table's content-view overlay, not the canvas overlay.
    func isRegionInTable(_ region: LeafTextRegion) -> Bool {
        boxes.contains { ($0 is TableBlockBox)
            && region.globalStart >= $0.nodeStart
            && region.globalStart < $0.nodeStart + $0.nodeSize }
    }

    /// Rect-union: clamp the global range to each leaf region, enumerate `.selection` segments,
    /// offset into canvas coordinates. The cross-block continuous highlight.
    /// - Parameter regionFilter: Optional predicate; only regions that pass are included (the canvas
    ///   selection overlay passes `{ !isRegionInTable($0) }` so table-cell regions are drawn by their
    ///   own content-view overlay). Defaults to `{ _ in true }` so existing callers are unaffected.
    /// **DO NOT DELEGATE THIS TO `legacySelectionSegments` — it is a test oracle.** The two bodies are
    /// near-duplicates and deduplicating them is tempting, but `BoundedSelectionGeometryTests` uses this
    /// function as the FROZEN, INDEPENDENT oracle its routed-witness comparisons are checked against
    /// (Task 25 re-review). Routing goes only through `legacySelectionSegments`; if this helper ever
    /// called it, those comparisons would silently re-tautologise — which is exactly how the Critical
    /// that Task 25 shipped went undetected the first time.
    func selectionRects(globalFrom: Int, globalTo: Int,
                        regionFilter: (LeafTextRegion) -> Bool = { _ in true }) -> [CGRect] {
        var rects: [CGRect] = []
        for r in allLeafRegions() where regionFilter(r) {
            let lo = max(globalFrom, r.globalStart), hi = min(globalTo, r.globalStart + r.length)
            guard lo < hi else { continue }
            let offX = tableContentOffsetX(forGlobal: r.globalStart)
            for seg in r.layout.selectionRects(start: lo - r.globalStart, end: hi - r.globalStart) {
                rects.append(seg.offsetBy(dx: r.canvasOrigin.x - offX, dy: r.canvasOrigin.y))
            }
        }
        return rects
    }

    /// The same rect-union as `selectionRects(globalFrom:globalTo:)`, but (a) optionally bounded to
    /// `visibleRect` plus the endpoint regions, and (b) carrying each segment's global range and its
    /// endpoint flags. `visibleRect: nil` means "the whole document" and MUST reproduce
    /// `selectionRects` exactly — `test_segmentsMatchTheWitnessRectsForASmallSelection` pins that.
    func legacySelectionSegments(globalFrom: Int, globalTo: Int, visibleRect: CGRect?,
                                 includeStartEndpoint: Bool, includeEndEndpoint: Bool)
        -> [(range: NSRange, rect: CGRect, containsStart: Bool, containsEnd: Bool)] {
        // The endpoint OWNER — the region `containsStart`/`containsEnd` names, and the region forced
        // into the bounded walk — is resolved via `leafRegionEndpoint(_:preferring:)`, DIRECTION-AWARE:
        // a start prefers the region FOLLOWING a structural gap, an end prefers the one PRECEDING it.
        // Computed unconditionally (independent of includeStart/EndEndpoint, which govern only forced
        // visibility, not this geometric fact). A genuine content position resolves identically
        // regardless of direction (`leafRegionEndpoint` falls through to exact containment first), so
        // direction only matters at a genuine structural gap — either an interior one (a captioned
        // media atom's 2-position gap before its caption: `test_containsEndMatchesTheWitnessAtAn-
        // InteriorStructuralGap` pins that a direction-AGNOSTIC fallback resolves an END endpoint to the
        // WRONG (following) region, which can never appear in `out` below since its clamped span is
        // empty for that range — permanently unsetting `containsEnd`) or the document's own leading/
        // trailing structural sentinel (`globalFrom`/`globalTo` of `0`/`documentSize` own no region
        // under raw containment — verified: `leafRegion(containingGlobal:)` returns nil for both — which
        // is what `test_boundedRequestStillIncludesBothEndpointSegments` pins; there both directions
        // degrade to the correct region since there is nothing on the "wrong" side to prefer).
        //
        // TASK 25 FIX ROUND 1 (reviewer Minor) — this comment used to say the region-identity
        // resolution above "matches the (unmodified) UITextInput witness `selectionRects(for:)`,
        // which flags purely by ARRAY POSITION ... over the FULL unbounded region walk". That is now
        // CIRCULAR: Task 25 routed `selectionRects(for:)` through `LegacyRichTextInputBackend` and
        // (transitively) through THIS function, so it is no longer an independent witness to compare
        // against. The array-position rule still lives on, but as the backend's OWN derivation
        // (`LegacyRichTextInputBackend+Geometry.swift`'s `selectionRects(for:)`, over `segments` —
        // not read from `containsStart`/`containsEnd` below), and the region-identity resolution here
        // is what makes that later per-index rule produce the SAME picks the pre-seam witness made,
        // not something separately "matched" against a witness that no longer exists in independent
        // form. `BoundedSelectionGeometryTests`'s `preSeamWitnessRects(_:from:to:)` is the actual frozen
        // oracle now (it inlines the array-position rule over THIS function's sibling
        // `selectionRects(globalFrom:globalTo:)`, never over the routed `for:` witness).
        let startOwner = leafRegionEndpoint(globalFrom, preferring: .following)
        let endOwner = leafRegionEndpoint(globalTo, preferring: .preceding)
        var endpoints: [Int] = []
        if includeStartEndpoint, let s = startOwner { endpoints.append(s.globalStart) }
        if includeEndEndpoint, let e = endOwner { endpoints.append(e.globalStart) }
        let regions = visibleRect.map { leafRegions(intersecting: $0, alwaysInclude: endpoints) }
            ?? allLeafRegions()
        let startOwnerGlobalStart = startOwner?.globalStart
        let endOwnerGlobalStart = endOwner?.globalStart
        var out: [(range: NSRange, rect: CGRect, containsStart: Bool, containsEnd: Bool)] = []
        for r in regions {
            let lo = max(globalFrom, r.globalStart), hi = min(globalTo, r.globalStart + r.length)
            guard lo < hi else { continue }
            let offX = tableContentOffsetX(forGlobal: r.globalStart)
            // BlockLayoutEngine.selectionRects returns rects only, with no per-rect range, so the segment
            // range is the region's clamped span. That is one range per REGION, matching how the unbounded
            // path already groups; do not invent sub-ranges the engine cannot supply.
            let range = NSRange(location: lo, length: hi - lo)
            let containsStart = r.globalStart == startOwnerGlobalStart
            let containsEnd = r.globalStart == endOwnerGlobalStart
            for seg in r.layout.selectionRects(start: lo - r.globalStart, end: hi - r.globalStart) {
                out.append((range: range,
                            rect: seg.offsetBy(dx: r.canvasOrigin.x - offX, dy: r.canvasOrigin.y),
                            containsStart: containsStart, containsEnd: containsEnd))
            }
        }
        return out
    }

    /// Selection rects for DRAWING the highlight wash, styled like UITextView (distinct from the
    /// glyph-hugging `selectionRects`): a line covered in full fills to the text container's trailing edge,
    /// and an empty line spanned by the selection gets a full-width rect. Used only by the highlight draw
    /// path — the OS witness / edit-menu / spoiler / marked-text geometry keep the glyph-hugging rects.
    func selectionHighlightRects(globalFrom: Int, globalTo: Int,
                                 regionFilter: (LeafTextRegion) -> Bool = { _ in true }) -> [CGRect] {
        var rects: [CGRect] = []
        for r in allLeafRegions() where regionFilter(r) {
            let regionEnd = r.globalStart + r.length
            let offX = tableContentOffsetX(forGlobal: r.globalStart)
            let lo = max(globalFrom, r.globalStart), hi = min(globalTo, regionEnd)
            if lo < hi {
                // The selection continuing past this region's last character means its trailing newline (the
                // next block) is selected → the final covered line fills to the edge, like UITextView.
                let continuesPast = globalTo > regionEnd
                for seg in r.layout.selectionFillRects(start: lo - r.globalStart, end: hi - r.globalStart,
                                                       fillTrailingLine: continuesPast,
                                                       isRTL: resolvedDirection(forGlobal: lo) == .rightToLeft) {
                    rects.append(seg.offsetBy(dx: r.canvasOrigin.x - offX, dy: r.canvasOrigin.y))
                }
            } else if r.length == 0, globalFrom <= r.globalStart, r.globalStart < globalTo {
                // An empty line spanned by the selection → a full-width highlight (the empty paragraph has no
                // glyphs, so `selectionFillRects` yields nothing; synthesize the line-height-tall full row).
                let h = r.emptyLineHeight > 0 ? r.emptyLineHeight : r.layout.caretRect(atOffset: 0).height
                rects.append(CGRect(x: r.canvasOrigin.x - offX, y: r.canvasOrigin.y,
                                    width: r.layout.containerWidth, height: h))
            }
        }
        return rects
    }

    /// Maps a point in canvas coordinates to the closest global text position.
    func closestGlobalPosition(to point: CGPoint) -> Int { root.closestPosition(toCanvasPoint: point) }

    /// The `TableBlockBox` whose node span (incl. structural token slots) contains `pos`, if any — used to
    /// fold in horizontal scroll. Wider than `tableBox(containing:)` in Navigation (which matches cell text only).
    func tableBox(containingGlobal pos: Int) -> TableBlockBox? {
        // Recurses into details / (expanded) block-quote bodies so a nested table is found; does NOT descend
        // into table cells (a nested table's own cells are found by that table).
        func find(_ stack: [CanvasBlock]) -> TableBlockBox? {
            for b in stack {
                guard pos > b.nodeStart, pos < b.nodeStart + b.nodeSize else { continue }
                if let t = b as? TableBlockBox { return t }
                if let d = b as? DetailsBox, let hit = find(d.children.boxes) { return hit }
                if let bq = b as? BlockQuoteBox, !bq.collapsed, let hit = find(bq.children.boxes) { return hit }
            }
            return nil
        }
        return find(boxes)
    }

    /// The horizontal scroll offset of the table containing `pos` (0 if none) — subtract it to turn an
    /// unscrolled-canvas rect into a VISIBLE canvas rect.
    func tableContentOffsetX(forGlobal pos: Int) -> CGFloat { tableBox(containingGlobal: pos)?.contentOffsetX ?? 0 }

    /// True if `pos` is the gap before a media atom box's `nodeStart` — a renderable caret slot.
    /// Recurses into details / expanded block-quote bodies (via `allBoxesRecursive`) so a NESTED media
    /// atom's gap is a gap position too.
    func isGapPosition(_ pos: Int) -> Bool {
        allBoxesRecursive().contains { $0 is MediaBlockBox && $0.nodeStart == pos }
    }

    /// The media box whose gap-before-atom is at `pos`, if any. Recurses into details / expanded block-quote
    /// bodies — every image action (tap-select, edit-menu geometry, delete, spoiler) routes through this, so a
    /// media block nested in a container must resolve here just like a top-level one.
    func mediaBox(atGap pos: Int) -> MediaBlockBox? {
        allBoxesRecursive().first { ($0 as? MediaBlockBox)?.nodeStart == pos } as? MediaBlockBox
    }

    /// The COLLAPSED block-quote box whose leading gap is at `pos`, if any. The folded quote is a
    /// caption-less atom holding no editable text, so a caret can focus its gap but typing there must open a
    /// body paragraph before it — mirroring `mediaBox(atGap:)`. Recurses (a collapsed quote can nest in a
    /// details body); `allBoxesRecursive` lists a collapsed quote as a leaf atom (it walks no children).
    func collapsedBlockQuoteBox(atGap pos: Int) -> BlockQuoteBox? {
        allBoxesRecursive().first { ($0 as? BlockQuoteBox).map { $0.collapsed && $0.nodeStart == pos } ?? false } as? BlockQuoteBox
    }

    /// If the caret (`head`) is inside a horizontally-scrollable table, scroll its cell into view.
    /// Non-animated (fires during typing/nav); the scroll callback syncs `contentOffsetX` + repaints.
    func scrollCaretIntoViewIfNeeded() {
        // Note: an image-gap caret inside a cell isn't found by cellLocation (no UI path inserts one today),
        // so this simply no-ops for that case.
        guard let t = tableBox(containingGlobal: head),
              let tv = blockViews[t.id] as? TableBackingView,
              let loc = t.cellLocation(containing: head),
              let cellRect = t.cellRect(row: loc.row, column: loc.column) else { return }
        guard t.gridWidth > tv.bounds.width else { return }   // not scrollable → cheap early exit, no layout flush
        tv.layoutIfNeeded()                                   // ensure scroll.frame/contentSize are current
        let x = cellRect.minX - t.frame.minX                  // cell x in the scroll view's content space
        let target = CGRect(x: x, y: 0, width: cellRect.width, height: 1)
        tv.scroll.scrollRectToVisible(target, animated: false)
    }

    /// While dragging a selection handle, auto-scroll as the touch nears an edge: **vertically** against the
    /// host document scroll view whenever the touch enters its top/bottom band (the common case — selecting
    /// past the visible text), and/or **horizontally** within a scrollable table when the dragged head is in
    /// that table and the touch nears its left/right edge. A single `CADisplayLink` applies both nudges per
    /// tick and re-extends the head against the updated geometry. (`point` is in canvas / content coords.)
    func updateDragAutoScroll(point: CGPoint, headInTable: Bool) {
        dragAutoScrollPoint = point

        // Vertical: scroll the host document when the touch is in the viewport's top/bottom band. Reuses the
        // floating-cursor curve (60pt band, 14pt max step) so the two gestures auto-scroll identically.
        var vy: CGFloat = 0
        if let sv = superview as? UIScrollView {
            vy = floatingAutoScrollStep(forViewportY: point.y - sv.contentOffset.y,
                                        viewportHeight: sv.bounds.height, band: 60)
        }
        dragAutoScrollVelocityY = vy

        // Horizontal: nudge a scrollable table the head is in when the touch nears its left/right edge.
        var vx: CGFloat = 0
        if headInTable, let t = tableBox(containingGlobal: head),
           let tv = blockViews[t.id] as? TableBackingView, t.gridWidth > tv.bounds.width {
            let edge: CGFloat = 36, step: CGFloat = 12
            let left = t.frame.minX, right = t.frame.minX + tv.bounds.width
            if point.x < left + edge { vx = -step } else if point.x > right - edge { vx = step }
            dragAutoScrollTable = (vx != 0) ? t : nil
        } else {
            dragAutoScrollTable = nil
        }
        dragAutoScrollVelocityX = vx

        if vy == 0 && vx == 0 { stopDragAutoScroll(); return }
        if dragAutoScrollLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(dragAutoScrollTick))
            link.add(to: .main, forMode: .common)
            dragAutoScrollLink = link
        }
    }

    func stopDragAutoScroll() {
        dragAutoScrollLink?.invalidate(); dragAutoScrollLink = nil
        dragAutoScrollTable = nil; dragAutoScrollVelocityX = 0; dragAutoScrollVelocityY = 0
        dragAutoScrollPoint = .zero
    }

    @objc func dragAutoScrollTick() {
        var moved = false
        // Vertical document scroll: advance the host offset and keep the touch point under the finger as the
        // content scrolls (so the head re-extends to follow), exactly like the floating-cursor auto-scroll.
        if dragAutoScrollVelocityY != 0, let sv = superview as? UIScrollView {
            let maxY = max(sv.contentSize.height - sv.bounds.height, 0)
            let newY = min(max(sv.contentOffset.y + dragAutoScrollVelocityY, 0), maxY)
            if newY != sv.contentOffset.y {
                let delta = newY - sv.contentOffset.y
                sv.contentOffset.y = newY        // fires the façade's scrollViewDidScroll → viewportDidChange
                dragAutoScrollPoint.y += delta   // track the same screen point as content scrolls under it
                moved = true
            }
        }
        // Horizontal table scroll: advance the table's internal offset (the canvas-space point is unaffected).
        if dragAutoScrollVelocityX != 0, let t = dragAutoScrollTable, let tv = blockViews[t.id] as? TableBackingView {
            let maxX = max(tv.scroll.contentSize.width - tv.bounds.width, 0)
            let newX = min(max(tv.scroll.contentOffset.x + dragAutoScrollVelocityX, 0), maxX)
            if newX != tv.scroll.contentOffset.x {
                tv.scroll.contentOffset.x = newX   // triggers tableDidScroll → syncs contentOffsetX
                moved = true
            }
        }
        guard moved else { return }   // both axes already clamped at their edge
        // Re-extend the endpoint being dragged to the content now under the touch: the anchor when the start
        // handle is dragged, else the head (the default — also the table-only / direct-call path). The tick
        // owns the scroll position, so suppress `setSelectionHead`'s scrollCaretIntoViewIfNeeded (it would
        // fight `newX`); `setSelectionAnchor` never scrolls, so it needs no suppression.
        let target = selectionDragPosition(forTouch: dragAutoScrollPoint)   // touch + captured grab offset
        if draggingEndpoint == .anchor { setSelectionAnchor(global: target) }
        else { setSelectionHead(global: target, scrollIntoView: false) }
    }

    /// Sets a collapsed caret (clears the drag anchor).
    func setCaret(global pos: Int) {
        setCaret(global: pos, reportSelectionChange: true)
    }

    /// Sets a collapsed caret (clears the drag anchor). `reportSelectionChange` gates the host-facing selection
    /// report (`onSelectionChange`): pass `false` for the per-frame moves of an interactive caret drag (the
    /// long-press magnifier loupe) so the host is told ONCE at the drag's final position instead of on every
    /// frame — the same "report once at the end" model the floating cursor (spacebar-trackpad) uses. The
    /// own-drawn visuals + table-cell scroll-follow still update every call. The OS input-delegate bracket
    /// obeys `inputBackend.suppressesSelectionNotifications` (like `setSelectionHead`): during a coalesced caret drag it is
    /// skipped per frame — otherwise the keyboard's autocorrect/candidate bar recomputes and visibly JUMPS on
    /// every move — and `endCoalescedSelectionDrag` fires exactly one bracket for the final caret at the end.
    func setCaret(global pos: Int, reportSelectionChange: Bool) {
        var target = pos
        if let g = finalizeMarkedText() {            // a dismissed prediction shifts later positions left
            if pos >= g.to { target = pos - (g.to - g.from) }
            else if pos > g.from { target = g.from }
        }
        target = clampGlobal(target)
        clearStructuralSelections()
        dismissEditMenuForSelectionOrTextChange()   // the caret moved → close any open menu (native UITextView)
        // TASK 26: the coalescing-aware selection bracket now lives on the backend
        // (`notifyingSelectionChange`), which consults the SAME
        // `suppressesSelectionNotifications` flag `beginCoalescedSelectionDrag()` sets. (Until TASK 43
        // the canvas reached it through a `coalescingSelectionNotifications` forwarder; that forwarder
        // is deleted and the four canvas sites name the backend member directly.)
        //
        // # TASK 39 — THE THREE FUNNELS DO **NOT** BECOME `setSelection` WRAPPERS, AND THAT IS MEASURED
        //
        // The task's brief expected them to: "`setCaret` / `setSelectionHead` / `setSelectionAnchor`
        // are the canvas's user-facing selection entry points and publishing is their POINT". It is
        // the one part of that brief's `setSelection` sentence that had survived Tasks 37 and 38 — and
        // it is false. **THE CONSTRUCTION (Rule 19), run at `c039177d5b`:** all 40 of Task 39's
        // warnings converted to a publishing `inputBackend.setSelection(_:reason:)`, full
        // `Scripts/iostest.sh`. **3 red across 3 suites (6 assertion failures), 0 `Fatal error` lines,
        // 0 restarts** out of 2639 executed (UIKit 2258 / 5 skipped + Core 381).
        // **ATTRIBUTION, measured rather than inferred:** reverting ONLY these three funnels to the raw
        // pair — **with the other 36 warnings still publishing** — turns all three green again
        // (`DelegateTraceCharacterizationTests` 23/0, `MarkedTextTraceCharacterizationTests` 10/0,
        // `SelectionInteractionTests` 26/0; Task 39's review reproduced it as a FULL green suite,
        // 2641/0, which is the stronger form). So every failure is THESE THREE LINES, and the funnels
        // are the *worst* of this task's population rather than its exception.
        //
        // **THE SPLIT, IN THE GATE'S UNIT, DERIVED FROM THE COMPILER AND NOT BY EYE** (fix round 1 —
        // this note first said "six warnings on four lines", which is wrong in both units and was
        // copied into eight other places before anyone re-derived it). Command:
        // `grep -oE "^/[^ ]+\.swift:[0-9]+:[0-9]+: warning: setter for '(anchor|head)' is deprecated"
        // /tmp/build.log | sort -u | grep /Sources/`, minus `+Editing.swift` and
        // `setSelectionForTesting`:
        //
        //   | | warnings | lines |
        //   |---|---:|---:|
        //   | Task 39's whole scope | **40** | **26** |
        //   | these three funnels (`:2044` ×2, `:2059`, `:2070`) | **4** | **3** |
        //   | everything else — SILENT under the publishing shape | **36** | **23** |
        //
        // A line is not a warning here: `anchor = x; head = x` on one line emits two, and
        // `setSelectionHead`/`setSelectionAnchor` emit one each. Quote the unit or the figure rots.
        //
        //   * `SelectionInteractionTests
        //     .test_setCaret_withReportSuppressed_defersHostReport_untilTheDragEnds` — **3 host reports
        //     instead of 0** mid-drag, then 5 instead of 1. This is `setCanonicalAnchor`'s measured
        //     reason 2 landing verbatim: a publish reaches `onSelectionChange?()` through
        //     `lifecycleClient.backendDidPublishState(.selection)`, so it **defeats
        //     `setCaret(global:reportSelectionChange:)`** — the parameter exists precisely so a loupe
        //     drag reports ONCE at its final position.
        //   * `DelegateTraceCharacterizationTests
        //     .test_endCoalescedSelectionDrag_emitsExactlyOneBracketWithNoStateChangeBetween` — 3 events
        //     instead of 2, the extra `canvasSelectionChanged` landing at index 0. During a coalesced
        //     drag `setSelection` defers via `pendingCoalescedSelectionPublish`, and clearing
        //     `suppressesSelectionNotifications` then fires that deferred publish out of the flag's
        //     `didSet` — **an extra publish in the suppressed path too**, not merely in the plain one.
        //   * `MarkedTextTraceCharacterizationTests.test_commitOnSelectionChange_traceAndMarkedState` —
        //     class-1 doubling: an extra `canvasSelectionChanged` between WILL and DID.
        //
        // `setSelectionHead`/`setSelectionAnchor` below never call `onSelectionChange?()` at all, so a
        // publish there does not double a report — it INVENTS one. The mechanism is therefore the same
        // one Tasks 36a-38 reached: `applyCaretOutcome` (`+Editing.swift`), the raw non-publishing
        // pair, applied at exactly the instruction the raw write occupied. Sending the funnels through
        // `setSelection` stays what `LegacyRichTextInputBackend+Attachment.swift`'s re-entrancy
        // enumeration already names it: **Task 40b's**, the commit that deletes the raw pair and has no
        // choice — and it must bring the `reportSelectionChange` story with it.
        inputBackend.notifyingSelectionChange {
            applyCaretOutcome(.caret(at: target))
        }
        setNeedsDisplay(); refreshSelectionUI()
        scrollCaretIntoViewIfNeeded()
        guard reportSelectionChange else { return }
        onSelectionChange?()   // tap is harmless (caret already visible → no-op); covers non-tap movers —
                               // Backspace-at-cell-start / Tab cell-nav — that can land the caret off-screen
    }

    /// Moves the selection head, keeping the anchor (drag-to-select). During an interactive handle drag the
    /// input-delegate bracket is coalesced to the gesture's end (see `beginCoalescedSelectionDrag()`).
    func setSelectionHead(global pos: Int, scrollIntoView: Bool = true) {
        finalizeMarkedText()
        clearStructuralSelections()
        dismissEditMenuForSelectionOrTextChange()
        // TASK 39: `applyCaretOutcome` — NOT `setSelection`; measured, see `setCaret` above. `.range`
        // rather than `.caret` because this funnel KEEPS the anchor (drag-to-select), and re-claiming
        // the anchor at its current value is a no-op by construction: `setCanonicalAnchor` re-wraps the
        // same `utf16Offset` as `.downstream`, the only affinity this backend emits (D6). The argument
        // list is evaluated before anything is written, so `anchor` here is the pre-write value.
        // Pinned, measured not cited: `.caret(at: pos)` here reddens **13 tests across 7 suites**,
        // `DirectionalSelectionCharacterizationTests.test_reversedSelection_survivesAHandleDragToTheLeft`
        // among them. (Fix round 1: the suite figure read **9**; both numbers come from one log —
        // `grep -cE 'Test Case .* failed'`, and that piped through
        // `sed -E 's/.*\[RichTextEditorUIKitTests\.([A-Za-z]+) .*/\1/' | sort -u | wc -l`. Rule 14:
        // "measured, not cited" is the last label a reader re-checks, so the command goes with it.)
        // Task 39 ran the same probe at all seven of its `.range` sites — see `setBlocks` for the three
        // that reddened NOTHING, and `applyCaretOutcome` for why the per-site form is the only one that
        // can see a zero.
        inputBackend.notifyingSelectionChange { applyCaretOutcome(.range(anchor, pos)) }   // TASK 26: see setCaret
        setNeedsDisplay(); refreshSelectionUI()
        if scrollIntoView { scrollCaretIntoViewIfNeeded() }
    }

    /// Moves the selection anchor (keeps the head), bracketing the input-delegate change like setSelectionHead
    /// (also coalesced during an interactive handle drag).
    func setSelectionAnchor(global pos: Int) {
        finalizeMarkedText()
        clearStructuralSelections()
        dismissEditMenuForSelectionOrTextChange()
        // TASK 39: the mirror of `setSelectionHead` — `.range(pos, head)` keeps the head. See there.
        // Its pin is a single test: `.caret(at: pos)` reddens only
        // `SelectionInteractionTests.test_dragAutoScroll_reextendsTheDraggedAnchor_notTheHead` (measured).
        inputBackend.notifyingSelectionChange { applyCaretOutcome(.range(pos, head)) }   // TASK 26: see setCaret
        setNeedsDisplay(); refreshSelectionUI()
    }

    /// Begins coalescing input-delegate selection notifications for an interactive selection-handle drag.
    /// While active, `setSelectionHead`/`setSelectionAnchor` update the selection + visuals every frame but
    /// skip the `inputDelegate` bracket; `endCoalescedSelectionDrag` fires exactly one bracket at the end.
    func beginCoalescedSelectionDrag() { inputBackend.suppressesSelectionNotifications = true }

    /// Ends a coalesced drag. If notifications were being coalesced, fire ONE input-delegate bracket so the OS
    /// re-syncs (and recomputes autocorrect/candidates) against the final selection — the `selectedTextRange`
    /// getter was live throughout, but the keyboard only refreshes on a bracket. No-op when no drag coalesced.
    func endCoalescedSelectionDrag() {
        guard inputBackend.suppressesSelectionNotifications else { return }
        // TASK 43 — the CLEAR, not just a flag reset: `suppressesSelectionNotifications`' `didSet`
        // flushes the publish `setSelection` deferred during the drag. It must stay ahead of the two
        // calls below, which is the order Task 26 established and this task preserved verbatim.
        inputBackend.suppressesSelectionNotifications = false
        inputBackend.notifyCoalescedSelectionResync()   // TASK 26: one bracket, no state change between
        inputBackend.checkOnSelectionChange()   // TASK 34 (D37): once at the final caret of a coalesced drag
    }

    // MARK: - Input backend seam (Task 18): `TelegramPresentationInputClient` hooks

    /// Forces `selectionChromeContainer` into existence at attach time. It is `lazy` (declared above,
    /// near `loupeSessionStorage`) and would otherwise first appear on the first loupe drag, while the
    /// presentation client's `interactionContainerView` must have a container identity that is STABLE
    /// for the whole backend lifetime (spec requirement, `RichTextInputPresentationClient.swift`).
    /// Called once from `TelegramPresentationInputClient.init`.
    func prepareInteractionContainer() {
        _ = selectionChromeContainer
    }

    /// The single presentation teardown entry point, wired ONLY from
    /// `TelegramPresentationInputClient.tearDownPresentation()`. Does NOT change the selection (anchor/head
    /// are untouched) — it only hides/cancels the visible presentation surface.
    ///
    /// DEVIATION from the brief's literal `hideHandle(.anchor)` / `hideHandle(.head)` spelling: there is no
    /// such enum. `hideHandle(_:)` (below `positionHandle`) takes the concrete `SelectionHandleView`
    /// instance, so this calls it with `startHandleView`/`endHandleView` directly — the real spelling at
    /// that declaration.
    ///
    /// DEVIATION D18 (see the plan's deviations table): `resignFirstResponder` keeps leaking the loupe
    /// session, the per-drag `UITextSelectionDisplayInteraction`, the drag auto-scroll display link, and the
    /// coalescing flag — this method is NOT called from `resignFirstResponder`, and must never be wired
    /// there. Fixing those leaks is an explicit non-goal of this extraction.
    func legacyTearDownPresentation() {
        hideCaretView()
        hideHandle(startHandleView)
        hideHandle(endHandleView)
        stopDragAutoScroll()
        cancelFloatingCursor()
        dismissEditMenu()
    }

    /// Marks the two selection-handle lollipop views' own drawn content dirty WITHOUT repositioning or
    /// showing/hiding them — the handle counterpart to `setNeedsSpellUnderlineDisplay()`. Added for
    /// `TelegramPresentationInputClient.invalidate(.handles)` (fix-round-1 item 1): `canvas.setNeedsDisplay()`
    /// cascades to `selectionHighlight`/`blockChromeOverlay`/`TableBackingView`s but never to
    /// `startHandleView`/`endHandleView`, so a caller invalidating `.handles` alone previously got zero
    /// effect. Positioning (and show/hide) stays `updateSelectionHandleViews()`'s job, reached through
    /// `apply`/`refreshSelectionUI()` — this is deliberately the narrower "repaint in place" signal a pure
    /// invalidation needs, not a reposition.
    func setNeedsHandleDisplay() {
        startHandleView.setNeedsDisplay()
        endHandleView.setNeedsDisplay()
    }

    func refreshSelectionUI() {
        // The canvas owns every selection visual (caret, wash, handles); there is no
        // `UITextSelectionDisplayInteraction` to notify (see `installSelectionInteractions`).
        updateCaretView()
        updateSelectionHandleViews()
        syncSpoilers()
        refreshCodeInputTraitsIfNeeded()
        inputBackend.checkOnSelectionChange()   // TASK 34 (D37): selection-driven check (native-parity)
    }

    /// True when the caret sits ANYWHERE in a code block — its code text or its language line. Read by the
    /// text-input traits: both regions are identifiers, not prose, so autocorrect, autocapitalization,
    /// spell checking and inline predictions are all off there. Otherwise iOS capitalizes `let` to `Let`
    /// and autocorrects identifiers into English words. (Smart quotes / dashes / insert-delete need no
    /// gating: they are already `.no` editor-wide — see `+NativeTextCheckingClient`.)
    var caretIsInCodeRegion: Bool {
        guard let (region, _) = leafRegion(containingGlobal: head) else { return false }
        if case .code = region.ref { return true }
        if case .codeLanguage = region.ref { return true }
        return false
    }

    /// Reload the keyboard's cached traits when the caret enters or leaves a code block. UIKit caches
    /// `UITextInputTraits` and only re-reads them on `reloadInputViews()` — the same reason the
    /// spell-checking toggle calls it. Called from `refreshSelectionUI`, the funnel every selection mover
    /// already goes through; the `!=` guard keeps it a cheap no-op for ordinary caret movement.
    func refreshCodeInputTraitsIfNeeded() {
        let now = caretIsInCodeRegion
        guard now != lastCaretWasInCodeRegion else { return }
        lastCaretWasInCodeRegion = now
        reloadInputViews()
    }

    /// Positions the two own-drawn selection-handle views at the ranged selection's endpoints — each hosted
    /// in the table's scrolling content view for a cell endpoint, else the canvas — ON TOP of the wash and
    /// riding the right scroll. Hidden for a collapsed / structural / non-renderable selection. Mirrors
    /// `updateCaretView`; idempotent, so it's safe from `refreshSelectionUI` and `layoutSubviews`.
    func updateSelectionHandleViews() {
        guard isFirstResponder, selFrom != selTo, tableSelection == nil, imageSelection == nil else {
            hideHandle(startHandleView); hideHandle(endHandleView); return
        }
        positionHandle(startHandleView, atGlobal: selFrom)
        positionHandle(endHandleView, atGlobal: selTo)
    }

    private func positionHandle(_ handle: SelectionHandleView, atGlobal pos: Int) {
        guard let region = leafRegion(containingGlobal: pos) else { return hideHandle(handle) }
        let unscrolled = region.region.caretRect(atLocal: region.local)
            .offsetBy(dx: region.region.canvasOrigin.x + region.region.emptyLineLeadingIndent,
                      dy: region.region.canvasOrigin.y)
        if let table = tableBox(containingGlobal: pos),
           let tv = blockViews[table.id] as? TableBackingView,
           region.region.globalStart >= table.nodeStart,
           region.region.globalStart < table.nodeStart + table.nodeSize {
            // Cell endpoint → host in the table's content view (content-local = unscrolled − frame.origin),
            // so it rides the horizontal scroll like the caret.
            let contentCaret = unscrolled.offsetBy(dx: -table.frame.minX, dy: -table.frame.minY)
            tv.hostHandle(handle, at: handle.boundingFrame(forCaret: contentCaret))
            handle.setCaretLocalRect(handle.caretLocalRect(forCaret: contentCaret))   // interactive hit area
        } else {
            if handle.superview !== self { addSubview(handle) }
            bringSubviewToFront(handle)   // above the wash (and chrome — they're never co-visible with a text range)
            handle.frame = handle.boundingFrame(forCaret: unscrolled)
            handle.setCaretLocalRect(handle.caretLocalRect(forCaret: unscrolled))   // interactive hit area
        }
        handle.isHidden = false
    }

    private func hideHandle(_ handle: SelectionHandleView) {
        handle.isHidden = true
        if handle.superview !== self { addSubview(handle) }   // never leave it parked in a torn-down table
    }

    /// Positions (and shows/hides) the app's own blinking caret. Idempotent and cheap: re-running it for the
    /// same caret (a scroll tick / relayout) does NOT restart the blink (only a real container/frame change
    /// does), so it's safe to call from `refreshSelectionUI` (every selection change) and `layoutSubviews`.
    ///
    /// The caret shows iff we're first responder, the selection is COLLAPSED (`selFrom == selTo`), there's
    /// no structural table selection, and `head` is renderable. When the caret is inside a horizontally-
    /// scrollable table CELL it's hosted in that table's scrolling content view (so it rides the scroll);
    /// otherwise (paragraph / image-gap) it's a subview of the canvas.
    func updateCaretView() {
        // During a floating-cursor (spacebar-trackpad) gesture the steady caret becomes the DIMMED
        // "landing" indicator at the SNAPPED position (where the caret lands on release); the bright
        // gliding shadow (transientCaretView) is positioned separately by the floating handlers.
        if floatingCursorActive {
            guard isFirstResponder, let placement = caretHostPlacement(forGlobal: head) else { return hideCaretView() }
            hostOverlay(caretView, at: placement)
            caretView.freezeSolid()
            caretView.alpha = 0.4
            lastCaretContainer = placement.container
            lastCaretFrame = placement.frame
            return
        }
        // During a long-press magnifier (loupe) drag, draw the spacebar-style two-cursor visual: OUR own accent
        // caret is the "landing" at the snapped position, while the desaturated `transientCaretView` glides at the
        // finger (the borrowed system cursor is near-invisible — grow anchor only). Solid, no blink.
        if loupeDragActive {
            guard isFirstResponder, let placement = caretHostPlacement(forGlobal: head) else { return hideCaretView() }
            hostOverlay(caretView, at: placement)
            caretView.alpha = 1
            caretView.freezeSolid()   // NOTE: sets isHidden=false — so the visibility rule below must run AFTER it.
            // Show the gray "shadow" (the snapped real caret) only once the accent glider (at the finger,
            // `loupeFingerX`) has diverged from it by >= `loupeShadowMinSeparation`; coincident, it's redundant
            // clutter. Applied HERE (the sole owner of `caretView` during a loupe drag) so a re-run — the loupe
            // magnifier forces layout passes that call this again — re-asserts it instead of leaving it visible.
            // `nil` finger x (the drag's terminal refresh) → shown, so the final caret is never left hidden.
            if let fx = loupeFingerX {
                let accentX = (placement.container === self) ? fx : convert(CGPoint(x: fx, y: 0), to: placement.container).x
                caretView.isHidden = !loupeShadowShouldShow(accentX: accentX, snappedX: placement.frame.midX)
            } else {
                caretView.isHidden = false
            }
            lastCaretContainer = placement.container
            lastCaretFrame = placement.frame
            return
        }
        caretView.alpha = 1   // restore full opacity after a gesture

        // Should it show?
        guard isFirstResponder, selFrom == selTo, tableSelection == nil, imageSelection == nil else { return hideCaretView() }

        guard let placement = caretHostPlacement(forGlobal: head) else { return hideCaretView() }
        hostOverlay(caretView, at: placement)

        caretView.isHidden = false
        // Reset the blink ONLY when the caret actually moved (container or frame changed). A no-op refresh
        // (scroll tick / relayout at the same spot) keeps the existing blink running.
        let changed = placement.container !== lastCaretContainer || !placement.frame.equalTo(lastCaretFrame)
        if changed { caretView.resetBlink() } else { caretView.startBlink() }
        lastCaretContainer = placement.container
        lastCaretFrame = placement.frame
    }

    /// The (container, frame) where a caret-like overlay for global `pos` should be hosted, or `nil` if
    /// `pos` is not a renderable caret slot. For an in-cell position the container is the owning
    /// `TableBackingView` (frame in its content-local space); otherwise the canvas (frame in canvas
    /// space). Extracted from `updateCaretView` so the steady caret and the floating transient caret host
    /// identically — including riding a table's horizontal scroll.
    func caretHostPlacement(forGlobal pos: Int) -> (container: UIView, frame: CGRect)? {
        let leaf = leafRegion(containingGlobal: pos)
        if let region = leaf,
           let table = tableBox(containingGlobal: pos),
           let tv = blockViews[table.id] as? TableBackingView,
           region.region.globalStart >= table.nodeStart,
           region.region.globalStart < table.nodeStart + table.nodeSize {
            let unscrolled = region.region.caretRect(atLocal: region.local)
                .offsetBy(dx: region.region.canvasOrigin.x + region.region.emptyLineLeadingIndent,
                          dy: region.region.canvasOrigin.y)
            let frame = caretBar(from: unscrolled)
                .offsetBy(dx: -table.frame.minX, dy: -table.frame.minY)
            return (tv, frame)
        } else if let region = leaf {
            let frame = caretBar(from: region.region.caretRect(atLocal: region.local)
                .offsetBy(dx: region.region.canvasOrigin.x + region.region.emptyLineLeadingIndent,
                          dy: region.region.canvasOrigin.y))
            return (self, frame)
        } else if let img = mediaBox(atGap: pos) {
            let rr = img.mediaRect()
            return (self, CGRect(x: rr.minX, y: rr.minY, width: 2, height: rr.height))
        }
        return nil
    }

    /// Hosts an arbitrary overlay view at a placement (reparenting into a table's content view when
    /// needed), matching how the steady caret is hosted.
    func hostOverlay(_ v: UIView, at placement: (container: UIView, frame: CGRect)) {
        if let tv = placement.container as? TableBackingView {
            tv.hostCaret(v, at: placement.frame)
        } else {
            if v.superview !== placement.container { placement.container.addSubview(v) }
            placement.container.bringSubviewToFront(v)
            v.frame = placement.frame
        }
    }

    /// A 2pt-wide caret bar from a TextKit caret rect (keeps the OS-caret look used by `caretRect`).
    private func caretBar(from rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: rect.minY, width: 2, height: rect.height)
    }

    private func hideCaretView() {
        caretView.stopBlink()
        if caretView.superview !== self { addSubview(caretView) }   // never leave it parked in a table's content view
        lastCaretContainer = nil
        lastCaretFrame = .null
    }

    /// Demo helper: set a selection spanning the middle of two blocks by index.
    func selectAcrossBlocks(firstIndex: Int, secondIndex: Int) {
        guard boxes.indices.contains(firstIndex), boxes.indices.contains(secondIndex) else { return }
        // TASK 39: `applyCaretOutcome` (`+Editing.swift`), and `.range` — this is a genuine two-endpoint
        // selection, not a caret. A publishing `setSelection` here would be the FIRST report on this
        // path rather than a second one (these helpers sit in no bracket and no caller publishes), i.e.
        // it would INVENT a host selection report; and `becomeFirstResponder()` on the next line runs
        // arbitrary responder/keyboard code, so the claim must land before it, exactly where the raw
        // pair did. Measured context: `setCaret`'s note above.
        // **UNPINNED, measured.** `.caret(at: <the second endpoint>)` here and in
        // `selectAcrossLeafRegions` each redden ZERO tests in the full suite — no test calls either
        // helper (`grep -rn selectAcross Tests/` is empty; their only callers are the facade's two
        // demo forwards). The `.range` spelling rests on the oracle (`e626bbd2fc`'s raw pair wrote two
        // distinct endpoints) and on the method names, not on a gate. Whoever gives these a caller that
        // matters should pin them first.
        applyCaretOutcome(.range(boxes[firstIndex].textStart + boxes[firstIndex].textLength / 2,
                                 boxes[secondIndex].textStart + boxes[secondIndex].textLength / 2))
        becomeFirstResponder()
        setNeedsDisplay(); refreshSelectionUI()
    }

    /// Demo helper: set a selection spanning mid-way through two leaf regions by document-order index.
    func selectAcrossLeafRegions(firstLeaf: Int, secondLeaf: Int) {
        let regions = allLeafRegions()
        guard regions.indices.contains(firstLeaf), regions.indices.contains(secondLeaf) else { return }
        let r1 = regions[firstLeaf], r2 = regions[secondLeaf]
        // TASK 39: see `selectAcrossBlocks` — same shape, same reasons.
        applyCaretOutcome(.range(r1.globalStart + max(1, r1.length / 2),
                                 r2.globalStart + max(1, r2.length / 2)))
        becomeFirstResponder()
        setNeedsDisplay(); refreshSelectionUI()
    }
}

/// One pooled emoji: the host view plus its last canvas-space frame (for offscreen culling).
@available(iOS 13.0, *)
final class HostedEmoji {
    let view: UIView & RichTextEmojiView
    var canvasFrame: CGRect
    init(view: UIView & RichTextEmojiView, canvasFrame: CGRect) { self.view = view; self.canvasFrame = canvasFrame }
}

/// One pooled media view: the host view plus its last canvas-space frame (for offscreen culling).
@available(iOS 13.0, *)
final class HostedMediaItem {
    let view: RichTextMediaItemView
    var canvasFrame: CGRect
    // Signature of the item set the hosted `view` was built for (mediaID + kind + natural size, in order).
    // `syncMediaItemViews` recreates the view via the provider when a block's live items no longer match this
    // — the seam is one-shot, so a reused view can't be re-fed a changed item list in place.
    var itemsSignature: String
    init(view: RichTextMediaItemView, canvasFrame: CGRect, itemsSignature: String) {
        self.view = view; self.canvasFrame = canvasFrame; self.itemsSignature = itemsSignature
    }
}

/// The canvas conforms to the REFINEMENT (deviation D24), which implies `RichTextInputHost`.
@available(iOS 13.0, *)
extension DocumentCanvasView: LegacyRichTextInputHost {
    /// DEVIATION D23. This is NOT `inputView`: `DocumentCanvasView` already overrides UIResponder's
    /// `var inputView: UIView?` above to vend `customInputView` (the host's replacement keyboard),
    /// which deviation D5 keeps deliberately un-routed. Two members cannot share a name and
    /// `UIView?` does not satisfy a `UIView` requirement.
    var hostInputView: UIView { self }

    /// DEVIATION D24. The declared path from `LegacyRichTextInputBackend` to the `legacy…` hooks.
    var legacyCanvas: DocumentCanvasView { self }

    var documentClient: any RichTextInputDocumentClient { documentInputClient }
    var geometryClient: any RichTextInputGeometryClient { geometryInputClient }
    var annotationClient: any RichTextInputAnnotationClient { annotationInputClient }
    var presentationClient: any RichTextInputPresentationClient { presentationInputClient }
    var lifecycleClient: any RichTextInputLifecycleClient { lifecycleInputClient }
    var commandClient: any RichTextInputCommandClient { commandInputClient }
}
#endif
