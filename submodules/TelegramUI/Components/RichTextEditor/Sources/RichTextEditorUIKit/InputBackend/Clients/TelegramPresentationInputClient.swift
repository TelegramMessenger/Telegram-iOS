#if canImport(UIKit)
import UIKit

/// The visible caret / selection-wash / handle / edit-menu surface. Telegram owns all of it — this
/// client is a thin router onto the canvas's existing, already-idempotent presentation machinery; it
/// adds no new drawing, no new state, and no new invalidation bus.
///
/// **`interactionContainerView` is the drawing plane only — it grants no interaction authority.** Gesture
/// recognizers (tap / long-press-loupe / selection-handle pan) are installed directly on the canvas in
/// `DocumentCanvasView+Interaction.swift` (`installSelectionInteractions`), and the iOS-16+ system edit
/// menu is a `UIEditMenuInteraction` also installed on the canvas in
/// `DocumentCanvasView+EditMenu.swift` (`installEditMenuInteraction`). Both stay exactly where they are;
/// this client hands out `selectionChromeContainer` only as a stable coordinate-conversion / chrome-hosting
/// surface (borrowed by the loupe's per-drag `UITextSelectionDisplayInteraction`, see that container's own
/// doc comment on `DocumentCanvasView`), and it is `isUserInteractionEnabled = false`.
///
/// DEVIATION D26 (plan's deviations table): `apply` keeps delegating to `refreshSelectionUI()`, which
/// still walks the unbounded `allLeafRegions()` rather than the bounded selection query Task 16 built.
/// Wiring the bounded query in here would change what is drawn during a large Select All (offscreen wash
/// segments stop being realized until scrolled to) — a performance-motivated behavior change Global
/// Constraint 17 forbids inside this extraction. `apply`'s `snapshot` parameter is therefore UNUSED: the
/// legacy path re-derives everything it draws from the canvas's own live `(anchor, head)` /
/// `isFirstResponder` / `tableSelection` / `imageSelection` state rather than from the published value —
/// exactly what makes routing through `refreshSelectionUI()` idempotent for free (see below).
///
/// DEVIATION D13: `ghostStyledLayout: BlockLayoutEngine?` (display-only bookkeeping for the inline-
/// prediction ghost foreground) stays a canvas-private presentation detail. Nothing in this client's
/// signature — nor anywhere in the `RichTextInputPresentationClient` contract — carries a
/// `BlockLayoutEngine`. `invalidate(.markedText)` reaches the ghost-styled block's own repaint through
/// `canvas.syncBlockViews()` (see that call's doc comment below) — a canvas method, not a typed hook into
/// `ghostStyledLayout` itself.
@MainActor
@available(iOS 13.0, *)
final class TelegramPresentationInputClient: RichTextInputPresentationClient {
    /// `unowned`, deliberately, not `weak` — see `TelegramDocumentInputClient`'s doc comment for the full
    /// rationale (the canvas strictly outlives its clients). Tests that discard the canvas via `_` must
    /// bind it and use `withExtendedLifetime` instead.
    private unowned let canvas: DocumentCanvasView
    /// `weak`, NOT `unowned`: unlike the canvas, the facade does not strictly outlive this client in every
    /// host configuration the brief describes (`facade: RichTextEditorView?`), and `requestReveal` must
    /// tolerate a nil/deallocated facade rather than trap.
    private weak var facade: RichTextEditorView?

    init(canvas: DocumentCanvasView, facade: RichTextEditorView?) {
        self.canvas = canvas
        self.facade = facade
        // `selectionChromeContainer` is `lazy` on the canvas and would otherwise first appear on the
        // first loupe drag; forcing it here gives `interactionContainerView` a container identity that
        // is stable for the whole backend lifetime, per the protocol's own doc comment.
        canvas.prepareInteractionContainer()
    }

    var interactionContainerView: UIView { canvas.selectionChromeContainer }

    var visibleBounds: CGRect { canvas.viewportRect() }

    /// Idempotent THROUGH `refreshSelectionUI()` → `updateCaretView()` / `updateSelectionHandleViews()`,
    /// which already guard every write behind a real container/frame (or visibility) change — see
    /// `lastCaretContainer`/`lastCaretFrame` (`DocumentCanvasView.swift`, near `selectionChromeContainer`)
    /// and `updateCaretView`'s own doc comment ("idempotent and cheap: re-running it for the same caret …
    /// does NOT restart the blink"). This method adds NO idempotence of its own — it is a pure forward to
    /// that existing mechanism, which is the whole point: a second `apply` of an equal snapshot re-derives
    /// the same container/frame from the canvas's unchanged live state and hits the same early-out.
    func apply(_ snapshot: RichTextInputPresentationSnapshot) {
        canvas.refreshSelectionUI()
    }

    /// Maps the option set onto the canvas invalidation entry points the legacy path already has. Bits
    /// are handled independently (not exclusively) since `RichTextInputPresentationInvalidation` is an
    /// `OptionSet` and a caller may combine them in one call. Mapping, bit by bit (fix-round-1 pinned all
    /// eight — see `test_invalidateEachBitMovesItsOwnObservableSignal`):
    /// - `.layout` → `notifyContentSizeChanged()` (fires the host's content-size hook).
    /// - `.editMenu` → `dismissEditMenuForSelectionOrTextChange()` (the existing dismiss counter).
    /// - `.spelling` / `.annotations` → `setNeedsSpellUnderlineDisplay()`. Both bits name the SAME
    ///   observable surface in this legacy path — the spelling/grammar underline overlay
    ///   (`selectionHighlight` + each table's cell overlay) — which is exactly what that call reaches.
    ///   (The ghost-foreground/spoiler-hidden RENDERING ATTRIBUTES `TelegramAnnotationInputClient` also
    ///   writes are a separate mechanism that bypasses this client entirely — D29 — so there is no
    ///   reachable gap here today; see the `.markedText` note below for where that same rendering-attribute
    ///   mechanism DOES need more than `setNeedsSpellUnderlineDisplay()`-style handling.)
    /// - `.handles` → `setNeedsHandleDisplay()` (fix-round-1 item 1 — was WRONGLY mapped to
    ///   `setNeedsDisplay()`, whose cascade never reaches `startHandleView`/`endHandleView`; see that
    ///   canvas method's doc comment).
    /// - `.caret` / `.selection` → `setNeedsDisplay()` (repaints `selectionHighlight` + table overlays +
    ///   chrome).
    /// - `.markedText` → BOTH `setNeedsDisplay()` (the marked-text underline, drawn by `selectionHighlight`)
    ///   AND `syncBlockViews()` (fix-round-1 item 3 — empirically verified: `NSTextLayoutManager
    ///   .addRenderingAttribute`, which `refreshPredictionStyling()`/`setGhostForeground` use for the
    ///   ghost-prediction foreground, does NOT self-trigger the owning `BlockBackingView`'s
    ///   `setNeedsDisplay()`, and `canvas.setNeedsDisplay()`'s own cascade doesn't reach a plain paragraph
    ///   view either — only `TableBackingView`s + the two overlays. Production's actual repaint path is the
    ///   render-signature reconciliation `syncBlockViews()`/`layoutSubviews` already run every layout pass
    ///   (`bindRealizedView` compares `BlockBox.renderSignature`, which folds in `layout.renderVersion` —
    ///   bumped by `setGhostForeground`); calling it here reaches the SAME repaint synchronously instead of
    ///   depending on a host round-trip through `notifyContentSizeChanged()`.
    func invalidate(_ invalidation: RichTextInputPresentationInvalidation) {
        if invalidation.contains(.layout) {
            canvas.notifyContentSizeChanged()
        }
        if invalidation.contains(.editMenu) {
            canvas.dismissEditMenuForSelectionOrTextChange()
        }
        if invalidation.contains(.spelling) || invalidation.contains(.annotations) {
            canvas.setNeedsSpellUnderlineDisplay()
        }
        if invalidation.contains(.handles) {
            canvas.setNeedsHandleDisplay()
        }
        if invalidation.contains(.markedText) {
            canvas.syncBlockViews()
        }
        if invalidation.contains(.caret) || invalidation.contains(.selection)
            || invalidation.contains(.markedText) {
            canvas.setNeedsDisplay()
        }
    }

    /// Calls BOTH existing reveal authorities, in their current order — preserving, not repairing, the
    /// canvas/facade split: the canvas's own `scrollCaretIntoViewIfNeeded()` handles the TABLE-CELL
    /// horizontal reveal (scrolling a cell's inner horizontal scroll view so the caret's column is
    /// visible), and the facade's `scrollCaretIntoView(animated:)` handles the OUTER document vertical
    /// reveal. `target` is UNUSED: the legacy reveal path always reveals the current caret (`head`) — it
    /// has no notion of revealing a specific endpoint/range/rect distinct from that.
    func requestReveal(_ target: RichTextInputRevealTarget, animated: Bool) {
        canvas.scrollCaretIntoViewIfNeeded()
        facade?.scrollCaretIntoView(animated: animated)
    }

    /// `reason` is UNUSED: the legacy `dismissEditMenu()` has exactly one behavior regardless of why the
    /// caller is dismissing.
    func dismissEditMenu(reason: RichTextInputEditMenuDismissReason) {
        canvas.dismissEditMenu()
    }

    /// DEVIATION D18: wired ONLY here — never into `resignFirstResponder`, which must keep leaking the
    /// loupe session, the per-drag `UITextSelectionDisplayInteraction`, the drag auto-scroll display link,
    /// and the coalescing flag (Task 6's `ResponderLifecycleCharacterizationTests` pins those leaks).
    func tearDownPresentation() {
        canvas.legacyTearDownPresentation()
    }
}
#endif
