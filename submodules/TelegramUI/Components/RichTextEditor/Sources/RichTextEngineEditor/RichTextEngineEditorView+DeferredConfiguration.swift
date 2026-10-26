#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// ACCEPT-AND-STORE: host configuration for capabilities this rung does not have yet.
///
/// The editor's members split three ways. This is the first category: the host TELLS us something,
/// we have nowhere to use it, and the stored value is exactly what the naming rung will need.
///
/// That is NOT the plausible default the trap discipline bans. `hasText -> false` was a lie about
/// STATE — it made the editor claim to be empty when it was not, and it disabled Select All for a
/// month before anyone traced it. A stored `quoteStyle` claims nothing; it is a deferred capability,
/// and R7 reads exactly what was stored.
///
/// THE RULE: every entry below names the rung that will consume it. **A member that cannot name a
/// consuming rung is not configuration** — it belongs in answer-or-trap or perform-or-trap instead.
/// `DeferredConfigurationRegisterTests` enforces both halves: this file is the only place such a
/// member may be declared, and every one carries a `// CONSUMED BY: R<n>` marker whose nearest
/// preceding declaration is its own.
///
/// A rung that LANDS does not empty this register — the value is still host configuration, and where
/// it is stored has not changed. It is marked `— DONE` and says what reads it, so the marker stays a
/// live statement rather than decaying into a stale promise. Two entries reached that state at
/// R9-inline (custom emoji, the edit-menu items provider), and three were RE-DEFERRED to a different
/// rung there: the two media-paste hooks and the rich-paste transformer all named R9, but pasted
/// content has nowhere to land until R7's blocks exist, so R9 was never going to consume them.
public struct DeferredConfiguration {
    public var quoteStyle: QuoteStyle = .default
    public var codeStyle: CodeStyle = .default
    public var mediaBlockStyle: MediaBlockStyle = .default
    public var quoteCollapseIcons: RichTextEditorQuoteCollapseIcons?
    public var detailsChevronImage: UIImage?
    public var renderMetrics: RichTextRenderMetrics = .default
    public var configureSelectionHandleView: ((UIView) -> Void)?
    public var pullQuoteStyle: PullQuoteStyle = .default
    public var onEditFormulaRequested: ((String, @escaping (String) -> Void) -> Void)?
    public var onEditButtonRequested: ((ButtonRef, Bool, @escaping (ButtonRef?) -> Void) -> Void)?
    public var onRequestButtonRowMenu: ((ButtonRowMenuRequest) -> Void)?
    public var formulaRenderer: ((RichTextFormulaRenderContext) -> RichTextFormulaRenderResult?)?
    public var buttonIconProvider: ((ButtonAction) -> RichTextButtonIcon?)?
    public var emojiViewProvider: ((String, CGSize) -> (UIView & RichTextEmojiView)?)?
    public var mediaViewProvider: (([MediaProviderItem], BlockID, MediaDisplayMode, RichTextMediaItemView?) -> RichTextMediaItemView?)?
    public var checklistMarkerViewProvider: ((Bool, CGSize) -> (UIView & RichTextChecklistMarkerView)?)?
    public var syntaxHighlighter: ((String, String, @escaping ([RichTextSyntaxToken]) -> Void) -> Void)?
    public var canPasteMedia: (() -> Bool)?
    public var onPasteMedia: (() -> Bool)?
    public var plainTextFragmentTransformer: ((String) -> Document?)?
    public var contextMenuItemsProvider: (([UIMenuElement]) -> [UIMenuElement])?
    public var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)?
    public var onRequestMediaControl: ((MediaControlRequest) -> Void)?

    public init() {}
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    // CONSUMED BY: R7 — PARTLY. `authorSpacing` and the interiors are read by `EngineBlockSpacing`, and
    // `trailingInset` is resolved into the stylesheet by `applyQuoteStyle` — it is the inset a
    // quote's CONTENT stops short of the column by, legacy's `BlockQuoteBox` rule, with the band
    // still drawn full width. The bar's colour, width and radius are still drawn from
    // `RichTextEditorTheme.accent` and `ContainerDecorationView`'s constants rather than from here,
    // and the LEADING inset is still the stylesheet's own `quoteIndent` — see `applyQuoteStyle`.
    public var quoteStyle: QuoteStyle {
        get { deferredConfiguration.quoteStyle }
        set {
            guard deferredConfiguration.quoteStyle != newValue else { return }
            deferredConfiguration.quoteStyle = newValue
            applyQuoteStyle(newValue)
        }
    }

    // CONSUMED BY: R7 — `applyCodeStyle` resolves its optional fields into the stylesheet against
    // `metrics.code`, exactly as the legacy canvas does. `codeHorizontalInset` insets the code's own
    // paragraphs and `codeVerticalInset` is reserved around the block by `EngineBlockSpacing`. The
    // band's COLOUR is still `RichTextEditorTheme.codeBackground`, which is where it lives for the
    // legacy canvas too.
    //
    // `horizontalBleed` and `cornerRadius` are read by the decoration pass, which is what makes the
    // two hosts' bands different SHAPES: a document host leaves both default and gets a square band
    // reaching the container's edge, while a compact host passes bleed 0 + a radius and gets a
    // rounded band pinned to the text column, moving its code inward with `horizontalInset` instead.
    // Those are alternatives — a host sets one or the other, never both to non-zero.
    public var codeStyle: CodeStyle {
        get { deferredConfiguration.codeStyle }
        set {
            guard deferredConfiguration.codeStyle != newValue else { return }
            deferredConfiguration.codeStyle = newValue
            applyCodeStyle(newValue)
        }
    }

    // CONSUMED BY: R7-media — DONE. The bridge computes each media atom's slot at
    // `horizontalBleed` (`MediaTextAttachment`), and `+MediaHosting.swift` widens the hosted view by
    // it. A change rebuilds the bridge, as `pullQuoteStyle` does.
    public var mediaBlockStyle: MediaBlockStyle {
        get { deferredConfiguration.mediaBlockStyle }
        set {
            guard deferredConfiguration.mediaBlockStyle != newValue else { return }
            deferredConfiguration.mediaBlockStyle = newValue
            applyMediaBlockStyle(newValue)
        }
    }

    // CONSUMED BY: R7-collapse — DONE. `syncQuoteCollapseGlyph` uses `collapse` on an OPEN quote
    // that is taller than its own preview, and `syncCollapsedQuoteViews` uses `expand` on a folded
    // one. Left unset both fall back to a drawn chevron, so a quote is foldable whether or not a
    // host configures artwork — the rule `detailsChevronImage` already follows.
    //
    // The member stays accept-and-store: the register stores what the host hands it and nothing here
    // validates it.
    public var quoteCollapseIcons: RichTextEditorQuoteCollapseIcons? {
        get { deferredConfiguration.quoteCollapseIcons }
        set { deferredConfiguration.quoteCollapseIcons = newValue }
    }

    // CONSUMED BY: R7-details — live. The host's disclosure arrow: `syncChevron` puts it in the
    // gutter beside every details' title and rotates it with the fold state. Its size and inset are
    // the editor's (`DetailsShape.chevronSize` / `chevronLeadingInset`), so a host supplies artwork
    // only. Left unset it falls back to `drawnChevron`, so a details is foldable whether or not a
    // host configures one — the same rule the list checkbox follows.
    //
    // The marker stays because the member is still accept-and-store: the register stores what the
    // host hands it and nothing here validates it. It names R7-details as the consumer now rather
    // than as the rung that will get to it.
    public var detailsChevronImage: UIImage? {
        get { deferredConfiguration.detailsChevronImage }
        set { deferredConfiguration.detailsChevronImage = newValue }
    }

    // CONSUMED BY: R7 for the block rhythm and the text's own line geometry — `applyRenderMetrics`
    // feeds both the mapper's stylesheet and `EngineBlockSpacing`. R8 is where the 0.01pt InstantPage
    // FRAME-parity contract makes them load-bearing to the pixel; until then they are honoured but
    // not pinned against the renderer.
    public var renderMetrics: RichTextRenderMetrics {
        get { deferredConfiguration.renderMetrics }
        set {
            guard deferredConfiguration.renderMetrics != newValue else { return }
            deferredConfiguration.renderMetrics = newValue
            applyRenderMetrics(newValue)
        }
    }

    // RE-DEFERRED TO: R7-media. Container content is text, which the engine's own selection already
    // covers; this is for handles over HOSTED block content, which arrives with media and tables.
    public var configureSelectionHandleView: ((UIView) -> Void)? {
        get { deferredConfiguration.configureSelectionHandleView }
        set { deferredConfiguration.configureSelectionHandleView = newValue }
    }

    // CONSUMED BY: R9-formulas — DONE. The provider is stored AND handed to the bridge's mapper;
    // storing it alone is what made every formula render as its own LaTeX source.
    public func registerFormulaRenderer(
        _ provider: @escaping (RichTextFormulaRenderContext) -> RichTextFormulaRenderResult?
    ) {
        deferredConfiguration.formulaRenderer = provider
        applyFormulaRenderer(provider)
    }

    // CONSUMED BY: R9-buttons — DONE. Read through the mapper by BOTH pill kinds: an inline pill
    // pays width for its icon (`inlineIconReserve`), while a block row's pills keep the side room
    // clear for a corner badge (`blockIconReserve`). The old note here said rows "arrive with the
    // container work" — they did not; they arrived with this rung, as a fifth EngineBlockShape.
    public func registerButtonIconProvider(_ provider: @escaping (ButtonAction) -> RichTextButtonIcon?) {
        deferredConfiguration.buttonIconProvider = provider
    }

    // CONSUMED BY: R9-inline — DONE. `+CustomEmoji.swift` asks this for a view per `EmojiRef` and positions it
    // over the glyph rect. Kept here because it is still host CONFIGURATION — the register is about
    // where a value is stored, not whether anything reads it.
    public func registerEmojiViewProvider(
        _ provider: @escaping (_ id: String, _ size: CGSize) -> (UIView & RichTextEmojiView)?
    ) {
        deferredConfiguration.emojiViewProvider = provider
    }

    // CONSUMED BY: R7-media — DONE. `+MediaHosting.swift` asks this for a view per media block and
    // positions it over the atom's attachment frame, re-providing on an items change with the
    // existing view so cells can be reused in place.
    public func registerMediaViewProvider(
        _ provider: @escaping ([MediaProviderItem], BlockID, MediaDisplayMode, RichTextMediaItemView?) -> RichTextMediaItemView?
    ) {
        deferredConfiguration.mediaViewProvider = provider
    }

    // CONSUMED BY: R7-lists — DONE. `+ListMarkers.swift` asks this for a checkbox per checklist item
    // and positions it in the gutter the mapper's list indent reserves, with the tap toggling
    // `checked`. A host that registers nothing still gets a marker: the item falls back to Core's own
    // `☐`/`☑` glyph, drawn and tappable the same way, so whether a box can be ticked never depends on
    // the host's configuration.
    public func registerChecklistMarkerViewProvider(
        _ provider: @escaping (_ checked: Bool, _ size: CGSize) -> (UIView & RichTextChecklistMarkerView)?
    ) {
        deferredConfiguration.checklistMarkerViewProvider = provider
    }

    // CONSUMED BY: R9-syntax-highlighting — NOT YET. Master's code-block highlighting (libprisma via a
    // host seam) reached the shared `RichTextEditor` protocol in the 2026-09-15 merge, and the ENGINE
    // editor does not colour code yet: it stores the provider and a code block renders plain, which is
    // the same degradation a host that registers nothing already gets in either editor. Stored rather
    // than trapped deliberately — both hosts register this unconditionally at construction, so a trap
    // here would make the engine editor unusable in the composer the moment it is selected.
    public func registerSyntaxHighlighter(
        _ provider: ((_ language: String, _ text: String,
                      _ completion: @escaping ([RichTextSyntaxToken]) -> Void) -> Void)?
    ) {
        deferredConfiguration.syntaxHighlighter = provider
    }

    // CONSUMED BY: R7-media — DONE. Installed on the host view as `tgid_canPasteMediaHandler` /
    // `tgid_pasteMediaHandler`, consulted from `canPerformAction:` and `paste:` where legacy consults them.
    public var canPasteMedia: (() -> Bool)? {
        get { deferredConfiguration.canPasteMedia }
        set { deferredConfiguration.canPasteMedia = newValue }
    }

    // CONSUMED BY: R7-media — DONE. Installed on the host view as `tgid_canPasteMediaHandler` /
    // `tgid_pasteMediaHandler`, consulted from `canPerformAction:` and `paste:` where legacy consults them.
    public var onPasteMedia: (() -> Bool)? {
        get { deferredConfiguration.onPasteMedia }
        set { deferredConfiguration.onPasteMedia = newValue }
    }

    // CONSUMED BY: R7-paste — DONE. `+Clipboard.swift`'s `pasteTransformedPlainText(from:)`
    // asks it for a `Document` when `paste:` finds plain text and no fragment or RTF, behind the
    // fragment check in `tgid_richPasteHandler`, and splices the answer through `replaceRange`'s
    // machinery as two undo steps (rich → the raw text → nothing), legacy's shape. Only a top-level
    // body paragraph takes it: inside a code block (or any container) the text pastes literally.
    public var plainTextFragmentTransformer: ((String) -> Document?)? {
        get { deferredConfiguration.plainTextFragmentTransformer }
        set { deferredConfiguration.plainTextFragmentTransformer = newValue }
    }

    // CONSUMED BY: R9-inline — DONE. `+EditMenu.swift` hands the system's suggested actions to this provider
    // and returns the superset, which is how Telegram's Format menu reaches the engine editor at
    // all. Note the seam UIKit actually uses is `-editMenuForTextRange:suggestedActions:` on the
    // VIEW; a host-attached `UIEditMenuInteraction` is never consulted.
    public var contextMenuItemsProvider: ((_ defaultElements: [UIMenuElement]) -> [UIMenuElement])? {
        get { deferredConfiguration.contextMenuItemsProvider }
        set { deferredConfiguration.contextMenuItemsProvider = newValue }
    }

    // RE-DEFERRED TO: R7-tables. Tables still TRAP in the bridge.
    public var onRequestTableStructuralMenu: ((TableStructuralMenuRequest) -> Void)? {
        get { deferredConfiguration.onRequestTableStructuralMenu }
        set { deferredConfiguration.onRequestTableStructuralMenu = newValue }
    }

    // CONSUMED BY: R7-media — DONE. `+MediaCommands.swift` builds the request from a hosted view's
    // control tap, its closures bound to the block's identity.
    public var onRequestMediaControl: ((MediaControlRequest) -> Void)? {
        get { deferredConfiguration.onRequestMediaControl }
        set { deferredConfiguration.onRequestMediaControl = newValue }
    }
}
#endif
