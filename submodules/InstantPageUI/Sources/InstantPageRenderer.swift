import Foundation
import UIKit
import AsyncDisplayKit
import Display
import CheckNode
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import GalleryUI
import ComponentFlow
import TextFormat
import EmojiTextAttachmentView
import AnimationCache
import MultiAnimationRenderer
import InvisibleInkDustNode
import ShimmeringMask
import WallpaperBackgroundNode
import UnsupportedContentPill

// MARK: - Stable item identity (for view reuse on re-layouts)

/// Stable identity for an `InstantPageV2LaidOutItem` across `update()` calls. The renderer
/// uses this to harvest existing item views and reuse them when the new layout still has
/// an item with the same id — preventing the media wrappers from torching their fetch
/// signals + image content on every chat-bubble re-apply.
///
/// Media items use their `media.index` (already unique within a page and used as the
/// gallery registry key). Details items use their `details.index`. Other items have no
/// intrinsic identity, so the renderer assigns them a `(case-tag, positional-index-in-items)`
/// pair.
public enum InstantPageV2StableItemId: Hashable {
    case media(Int)                          // media.index (4 media cases share this namespace)
    case details(Int)                        // details.index
    case thinking(Int)                       // thinking-block sequence index (own namespace)
    case positional(InstantPageV2ItemKind, Int)  // (caseTag, items-array position)
}

public enum InstantPageV2ItemKind: Hashable {
    case text, codeBlock, divider, listMarker, blockQuoteBar, shape, imageOrnament, mediaPlaceholder, table, anchor, formula, slideshow, quoteFrame, inlineButton, buttonRow, unsupportedContent
}

// MARK: - Render context

/// Bundle of render-time dependencies required to display real media inside an InstantPage V2
/// view. Tied to an `InstantPageV2View` for the view's lifetime — if any field would change
/// (typically because the bubble was recycled with a different webpage), the caller must
/// rebuild the V2View with a fresh render context.
///
/// `renderContext == nil` is permitted: the V2View falls back to grey-placeholder rendering
/// for the four media kinds (image/video/map/coverImage). This keeps the existing zero-arg
/// `InstantPageV2View()` constructor usable.
public final class InstantPageV2RenderContext {
    public let context: AccountContext
    public private(set) var webpage: TelegramMediaWebpage
    public let sourceLocation: InstantPageSourceLocation
    public private(set) var imageReference: (TelegramMediaImage) -> ImageMediaReference
    public private(set) var fileReference: (TelegramMediaFile) -> FileMediaReference
    public let present: (ViewController, Any?) -> Void
    public let push: (ViewController) -> Void
    public let openUrl: (InstantPageUrlItem) -> Void
    public let baseNavigationController: () -> NavigationController?
    /// A reference to the message hosting this page, when rendered inside a chat bubble. Used to
    /// key audio playback per message (`.richMessage(message.id)`) AND to fetch audio files via a
    /// message reference (so a stale file reference can revalidate); `nil` in the send preview,
    /// which falls back to the webpage-keyed playlist id + webpage file reference.
    public private(set) var message: MessageReference?
    /// Per-media auto-download decision for a photo, computed by the host (chat bubble) from the
    /// message's download settings. Default `{ _ in false }` — V1/web-IV and the send preview keep
    /// their existing behavior (the node's own global-settings gate). See the video/autodownload spec.
    public let shouldAutoDownloadImage: (TelegramMediaImage) -> Bool
    /// Per-media auto-download decision for a file/video. Default `{ _ in false }`.
    public let shouldAutoDownloadFile: (TelegramMediaFile) -> Bool
    /// Whether a video file should auto-play inline (energy-usage autoplay setting AND already
    /// downloaded), computed by the host. Default `{ _ in false }` — no inline autoplay.
    public let shouldAutoplayVideo: (TelegramMediaFile) -> Bool
    /// The host's chat wallpaper, when it has one. The unsupported-content pill asks it for a
    /// `.free` bubble background so the wallpaper shows through the card.
    ///
    /// A closure rather than a stored reference: a message-scoped context must not retain the
    /// chat's background node, and the host may swap its node without rebuilding the context.
    /// Bubble backgrounds here are portal views that mirror their source, so nothing else — no
    /// absolute rect, no scroll offset — has to be threaded through.
    public let wallpaperBackgroundNode: () -> WallpaperBackgroundNode?
    /// Whether the media on this page must be excluded from screenshots and screen recordings
    /// (`setLayerDisableScreenshots`), and denied the gallery's share/save affordances. Set by the
    /// chat bubble from the message's copy-protection state; `false` for V1 Instant View, web IV
    /// and the send preview, which have no protected content.
    ///
    /// Mutable because copy protection is a *peer* setting that can be toggled while a message is
    /// on screen: that changes neither the webpage nor the page layout, so the V2View — and with it
    /// this context — is not rebuilt. The host refreshes the flag before each `update(layout:…)`
    /// and every media view re-reads it from the context in its own `update(…)`.
    public private(set) var captureProtected: Bool

    public init(
        context: AccountContext,
        webpage: TelegramMediaWebpage,
        sourceLocation: InstantPageSourceLocation,
        imageReference: @escaping (TelegramMediaImage) -> ImageMediaReference,
        fileReference: @escaping (TelegramMediaFile) -> FileMediaReference,
        present: @escaping (ViewController, Any?) -> Void,
        push: @escaping (ViewController) -> Void,
        openUrl: @escaping (InstantPageUrlItem) -> Void,
        baseNavigationController: @escaping () -> NavigationController?,
        shouldAutoDownloadImage: @escaping (TelegramMediaImage) -> Bool = { _ in false },
        shouldAutoDownloadFile: @escaping (TelegramMediaFile) -> Bool = { _ in false },
        shouldAutoplayVideo: @escaping (TelegramMediaFile) -> Bool = { _ in false },
        wallpaperBackgroundNode: @escaping () -> WallpaperBackgroundNode? = { nil },
        captureProtected: Bool = false,
        message: MessageReference?
    ) {
        self.context = context
        self.webpage = webpage
        self.sourceLocation = sourceLocation
        self.imageReference = imageReference
        self.fileReference = fileReference
        self.present = present
        self.push = push
        self.openUrl = openUrl
        self.baseNavigationController = baseNavigationController
        self.message = message
        self.shouldAutoDownloadImage = shouldAutoDownloadImage
        self.shouldAutoDownloadFile = shouldAutoDownloadFile
        self.shouldAutoplayVideo = shouldAutoplayVideo
        self.wallpaperBackgroundNode = wallpaperBackgroundNode
        self.captureProtected = captureProtected
    }

    /// Refresh the copy-protection state. See `captureProtected`; the host calls this before each
    /// `InstantPageV2View.update(layout:theme:animation:)` so reused media views pick the new value
    /// up in their own `update(…)`.
    public func updateCaptureProtected(_ captureProtected: Bool) {
        self.captureProtected = captureProtected
    }

    /// Update the content-bearing webpage for a later chunk of the SAME message with the SAME
    /// server id (streamed AI `stableVersion` bumps). The `imageReference`/`fileReference`/`message`
    /// snapshot is intentionally NOT refreshed here: the message id is stable across chunks (media
    /// resolves by id) and streamed AI content carries no media. For the Local→Cloud send transition
    /// (same stableId, NEW id, real media) use `updateContent(webpage:message:imageReference:fileReference:)`.
    public func updateContent(webpage: TelegramMediaWebpage) {
        self.webpage = webpage
    }

    /// Refresh content AND the message-scoped references when the SAME logical message (same
    /// `stableId`) transitions to a new server id (Local→Cloud on send). Already-built media item
    /// VIEWS keep their construction-time (local) reference — their bytes are already local
    /// (`ApplyUpdateMessage` moved them), so the poster does not reload — but LIVE reads (inline
    /// video content-id/fetch, audio playlist key/fetch, gallery) now use the Cloud reference.
    public func updateContent(
        webpage: TelegramMediaWebpage,
        message: MessageReference?,
        imageReference: @escaping (TelegramMediaImage) -> ImageMediaReference,
        fileReference: @escaping (TelegramMediaFile) -> FileMediaReference
    ) {
        self.webpage = webpage
        self.message = message
        self.imageReference = imageReference
        self.fileReference = fileReference
    }
}

// MARK: - Inline image view data

private struct InlineImageKey: Hashable {
    let fileId: Int64
    let occurrenceIndex: Int
}

/// Per-inline-image state owned by `InstantPageV2View`.
/// `textView` is a weak reference back to the parent so `updateImageReveal` can
/// look up the current per-text-view character count.
private final class InstantPageInlineImageData {
    let view: InstantPageV2InlineImageView
    weak var textView: InstantPageV2TextView?
    var charIndexInItem: Int = 0
    var revealed: Bool = false

    init(view: InstantPageV2InlineImageView) {
        self.view = view
    }
}

// MARK: - Emoji layer data

private final class InstantPageEmojiLayerData {
    let itemLayer: InlineStickerItemLayer
    /// The view whose coordinate space `itemLayer.frame` is in — an `InstantPageV2TextView` for an
    /// emoji in body text, or an `InstantPageV2ButtonPillView` for one in a button label. Only a
    /// text host has a progressive-reveal cursor; a pill already pops in atomically with its
    /// paragraph, so a pill-hosted emoji is revealed from the start.
    weak var hostView: UIView?
    var charIndexInItem: Int = 0
    var revealed: Bool = false

    init(itemLayer: InlineStickerItemLayer) {
        self.itemLayer = itemLayer
    }
}

// MARK: - Public renderer

public final class InstantPageV2View: UIView {
    public private(set) var currentLayout: InstantPageV2Layout?
    public private(set) var currentTheme: InstantPageTheme?

    /// Invoked when a details title is tapped. Bubble routes to its expand-state mutation + requestUpdate.
    public var detailsTapped: ((_ index: Int) -> Void)?
    /// Fired when an interactive checklist checkbox is tapped. `path` is the marker's
    /// structural path (see InstantPage.togglingCheckbox); `newValue` is the toggled state.
    public var checkboxTapped: ((_ path: [Int], _ newValue: Bool) -> Void)?

    /// Fired when an InstantPage button is tapped — an inline `RichText.textButton` or a member of a
    /// `pageBlockButtonRow`. The consumer maps it onto the message-button dispatch, and reports the
    /// action's progress back through the promise so the tapped pill can shimmer while it is in
    /// flight. Leaving the promise unfulfilled is fine — the pill simply never shimmers.
    public var buttonTapped: ((InstantPageButton, Promise<Bool>) -> Void)?
    /// Fires when a `.document` row whose file is already downloaded is tapped.
    public var documentTapped: ((TelegramMediaFile) -> Void)?
    /// Fired when the Update button on an unsupported-content pill is tapped. Hosts inside a chat
    /// route this to the App Store page; hosts that leave it nil still render the button (the tap
    /// is inert) so the pill's width does not change between preview and sent message.
    public var unsupportedActionTapped: (() -> Void)?

    var itemViews: [InstantPageItemView] = []
    private var itemViewStableIds: [InstantPageV2StableItemId] = []
    /// Whether any item view currently carries a collapsed-quote fade. Lets the fade pass return
    /// immediately on the overwhelmingly common page that has neither a collapsible quote nor a
    /// leftover mask to clean up.
    private var hasQuoteFadeMasks = false

    public let renderContext: InstantPageV2RenderContext?

    private var inlineStickerItemLayers: [InlineStickerItemLayer.Key: InstantPageEmojiLayerData] = [:]
    private var inlineImageViews: [InlineImageKey: InstantPageInlineImageData] = [:]
    private var emojiEnableLooping: Bool = true

    /// Scroll-visibility rect in this view's coordinate space; gates emoji animation looping.
    /// `nil` means "not visible" → emoji don't animate. The root rect is set by the bubble and
    /// propagated down the nested tree (details/table) by `propagateVisibilityRect`.
    public var visibilityRect: CGRect? {
        didSet {
            if oldValue != self.visibilityRect {
                self.updateEmojiVisibility()
                self.updateItemVisibility()
            }
        }
    }
    public private(set) var displayContentsUnderSpoilers: Bool = false

    // Weak references to every media wrapper in the tree, keyed by `InstantPageMedia.index`.
    // Used by `transitionArgsFor` and `applyHiddenMedia` so the gallery transition + hidden-source
    // state can find a wrapper without walking the view hierarchy. Nested V2Views (details body,
    // table cells) forward their registrations to the root via `rootMediaRegistryHost`.
    var mediaRegistry: [Int: Weak<UIView>] = [:]

    // Pointer to the root V2View's registry host. The root sets this to `self`; nested views
    // inherit it via `propagateRegistryHost(to:)` in `update(layout:theme:animation:)`.
    weak var rootMediaRegistryHost: InstantPageV2View?

    var effectiveRegistryHost: InstantPageV2View {
        return self.rootMediaRegistryHost ?? self
    }

    /// Walks the `rootMediaRegistryHost` chain transitively until it finds a self-referencing
    /// host (the true root). Necessary because nested details blocks can leave an inner body's
    /// `rootMediaRegistryHost` pointing at an intermediate body rather than the outer root —
    /// `propagateRegistryHost(to:)` only walks one hop, so the chain must be followed at lookup.
    var trueRegistryRoot: InstantPageV2View {
        var host: InstantPageV2View = self
        while let next = host.rootMediaRegistryHost, next !== host {
            host = next
        }
        return host
    }

    public init(renderContext: InstantPageV2RenderContext?) {
        self.renderContext = renderContext
        super.init(frame: .zero)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.rootMediaRegistryHost = self
    }

    public convenience init() {
        self.init(renderContext: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Rebuilds the child view hierarchy from `layout`. The caller is responsible for
    /// sizing `self.frame` to `layout.contentSize`; this method does not touch its own frame.
    ///
    /// Reuse pass: existing item views are harvested into a `[stableId: view]` map keyed
    /// off `itemViewStableIds`. For each new item we look up its stable id; on a hit (and
    /// matching concrete view class) the existing view is reused via its typed
    /// `update(item:theme:[renderContext:])`, on a miss we fall back to `makeItemView`. Un-reused
    /// views are removed from the superview at the end. This preserves the four media wrappers
    /// (and any nested V2Views inside details/table) across chat-bubble re-applies, which would
    /// otherwise torch in-flight image fetches on every list update.
    public func update(
        layout: InstantPageV2Layout,
        theme: InstantPageTheme,
        animation: ListViewItemUpdateAnimation
    ) {
        // Where each collapsible quote sat BEFORE this update, keyed by its structural path. A quote
        // being collapsed has no fade mask yet, so a mask created now would otherwise appear already
        // closed; this is the geometry it animates out of. Read before `self.currentLayout` is
        // replaced at the end of this method.
        var previousQuoteFrames: [[Int]: CGRect] = [:]
        for item in self.currentLayout?.items ?? [] {
            if case let .quoteFrame(quote) = item, quote.collapseState != .notCollapsible {
                previousQuoteFrames[quote.path] = quote.frame
            }
        }
        // Likewise for the views the mask hangs off: by the time the fade pass runs, every frame has
        // already been set to its target.
        var previousViewFrames: [ObjectIdentifier: CGRect] = [:]

        // Build map of existing views by stable id.
        var oldViewsById: [InstantPageV2StableItemId: InstantPageItemView] = [:]
        for (oldIndex, oldId) in self.itemViewStableIds.enumerated() {
            oldViewsById[oldId] = self.itemViews[oldIndex]
        }

        var newItemViews: [InstantPageItemView] = []
        var newStableIds: [InstantPageV2StableItemId] = []
        var reusedIds: Set<InstantPageV2StableItemId> = []
        // Kept alongside `newItemViews` rather than re-derived by index from `layout.items`: an item
        // whose view cannot be built (`makeItemView` returning nil) is skipped here but still present
        // there, so the two lists are NOT index-aligned. The collapsed-quote fade pass needs each
        // view's item.
        var newItems: [InstantPageV2LaidOutItem] = []

        // Two independent position counters so thinking-block churn never renumbers content
        // blocks' stable ids (requirement: adding/removing a thinking block must not affect other
        // blocks). Content items are numbered ignoring thinking items; thinking items get their
        // own .thinking(index) namespace.
        var contentPosition = 0
        var thinkingPosition = 0
        for item in layout.items {
            let id: InstantPageV2StableItemId
            if case .thinking = item {
                id = InstantPageV2View.stableId(for: item, atPosition: thinkingPosition)
                thinkingPosition += 1
            } else {
                id = InstantPageV2View.stableId(for: item, atPosition: contentPosition)
                contentPosition += 1
            }

            if let existing = oldViewsById[id], let reusedView = self.reuse(existingView: existing, for: item, theme: theme, animation: animation) {
                let newFrame = InstantPageV2View.actualFrame(forItem: item)   // parent positions child
                previousViewFrames[ObjectIdentifier(reusedView)] = reusedView.frame
                if animation.isAnimated && reusedView.frame != newFrame {
                    // A collapsing details view keeps its body alive; remove it once this
                    // frame-shrink (the clip that hides it) finishes — see finalizePendingCollapse().
                    let detailsView = reusedView as? InstantPageV2DetailsView
                    animation.animator.updateFrame(layer: reusedView.layer, frame: newFrame, completion: { [weak detailsView] _ in
                        detailsView?.finalizePendingCollapse()
                    })
                } else {
                    reusedView.frame = newFrame
                    (reusedView as? InstantPageV2DetailsView)?.finalizePendingCollapse()
                }
                newItemViews.append(reusedView)
                newStableIds.append(id)
                newItems.append(item)
                reusedIds.insert(id)
                // Already in subviews from the previous update; just keep it.
            } else {
                guard let newView = self.makeItemView(for: item, theme: theme) else { continue }
                newItemViews.append(newView)
                newStableIds.append(id)
                newItems.append(item)
                self.addSubview(newView)
                self.propagateRegistryHost(to: newView)
            }
        }

        // Remove views that weren't reused.
        for (id, view) in oldViewsById where !reusedIds.contains(id) {
            view.removeFromSuperview()
        }

        // Z-order: bring the reused views to the front in declaration order so the
        // sublayer/subview stack matches `layout.items` order.
        for view in newItemViews {
            self.bringSubviewToFront(view)
        }

        self.itemViews = newItemViews
        self.itemViewStableIds = newStableIds
        self.currentLayout = layout
        self.currentTheme = theme
        self.applyCollapsedQuoteFades(views: newItemViews, items: newItems, previousQuoteFrames: previousQuoteFrames, previousViewFrames: previousViewFrames, animation: animation)
        self.updateInlineImages()
        self.updateInlineEmoji()
        let enableSpoilerAnimations = self.renderContext.map { $0.context.sharedContext.energyUsageSettings.fullTranslucency } ?? true
        for view in self.itemViews {
            if let textView = view as? InstantPageV2TextView {
                // Both fresh (makeItemView) and reused text views now build their dust through the
                // single init→update→updateSpoiler path, so we only push the external animation
                // setting here; its didSet rebuilds the dust if the value actually changed.
                textView.enableSpoilerAnimations = enableSpoilerAnimations
            }
        }
        // Force the current reveal state (true OR false) onto every text view every layout, so a
        // positionally-reused text view cannot retain a stale reveal flag from prior content.
        self.setDisplayContentsUnderSpoilers(self.displayContentsUnderSpoilers, atLocation: nil, animated: false)
    }

    /// Hangs the collapsed-quote fade off the content views that reach a collapsed quote's bottom
    /// edge, and dissolves it again when that quote expands.
    ///
    /// A POST-PASS over positioned views rather than a flag on the items, because **a quote's content
    /// is not grouped**: `layoutBlockQuote` emits the frame and its children as flat siblings into the
    /// page's item list, so the only thing tying a text view to the quote it sits in is geometry.
    /// (Details bodies and table cells do nest their own `InstantPageV2View`, and masking the
    /// container masks the whole subtree, so nesting needs no special case.)
    private func applyCollapsedQuoteFades(views: [InstantPageItemView], items: [InstantPageV2LaidOutItem], previousQuoteFrames: [[Int]: CGRect], previousViewFrames: [ObjectIdentifier: CGRect], animation: ListViewItemUpdateAnimation) {
        var quotes: [(frame: CGRect, isCollapsed: Bool, mirrored: Bool, path: [Int])] = []
        for item in items {
            guard case let .quoteFrame(quote) = item, quote.collapseState != .notCollapsible else {
                continue
            }
            quotes.append((quote.frame, quote.collapseState == .collapsed, quote.barOnTrailing, quote.path))
        }
        // The overwhelmingly common page has neither a collapsible quote nor a leftover fade.
        if quotes.isEmpty && !self.hasQuoteFadeMasks {
            return
        }

        var anyMaskRemains = false
        for (view, item) in zip(views, items) {
            var ownQuoteFrame: CGRect?
            if case let .quoteFrame(quote) = item {
                ownQuoteFrame = quote.frame
            }
            // Innermost wins: a nested collapsed quote fades its own content, not its parent's edge.
            var host: (frame: CGRect, isCollapsed: Bool, mirrored: Bool, path: [Int])?
            for quote in quotes {
                // A quote never fades its own background or its own chevron.
                if let ownQuoteFrame, ownQuoteFrame == quote.frame {
                    continue
                }
                guard quote.frame.insetBy(dx: -0.5, dy: -0.5).contains(view.itemFrame) else {
                    continue
                }
                if let current = host, current.frame.height <= quote.frame.height {
                    continue
                }
                host = quote
            }

            let existingMask = view.layer.mask as? InstantPageV2QuoteFadeMaskLayer
            guard let host else {
                if let existingMask, self.dissolveQuoteFade(existingMask, on: view, animation: animation) {
                    anyMaskRemains = true
                }
                continue
            }

            // The fade is anchored to the QUOTE's rect, expressed in this view's coordinate space —
            // so a view sitting well above the quote's bottom gets an all-opaque mask and is
            // untouched, exactly as it should be.
            let viewFrame = view.frame
            let localQuoteFrame = host.frame.offsetBy(dx: -viewFrame.minX, dy: -viewFrame.minY)
            let reachesFade = viewFrame.maxY > host.frame.maxY - instantPageV2QuoteFadeTileSize.height

            if host.isCollapsed && reachesFade {
                if let existingMask {
                    existingMask.invalidatePendingDissolve()
                    animation.animator.updateFrame(layer: existingMask, frame: localQuoteFrame, completion: nil)
                    animation.animator.updateBackgroundColor(layer: existingMask, color: .clear, completion: nil)
                } else {
                    let mask = InstantPageV2QuoteFadeMaskLayer()
                    // RTL: the carve-out is anchored to the tile's trailing side, so mirror it to
                    // follow the chevron across to the leading side.
                    if host.mirrored {
                        mask.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                    }
                    // A mask born already closed IS the snap: the overflow lines it exists to sweep
                    // away would be gone on the first frame. Start it at the quote's pre-toggle rect,
                    // in the pre-toggle coordinate space of the very view it is masking, and let it
                    // close alongside everything else.
                    if animation.isAnimated,
                       let previousQuote = previousQuoteFrames[host.path],
                       let previousViewFrame = previousViewFrames[ObjectIdentifier(view)] {
                        mask.frame = previousQuote.offsetBy(dx: -previousViewFrame.minX, dy: -previousViewFrame.minY)
                        view.layer.mask = mask
                        animation.animator.updateFrame(layer: mask, frame: localQuoteFrame, completion: nil)
                    } else {
                        mask.frame = localQuoteFrame
                        view.layer.mask = mask
                    }
                }
                anyMaskRemains = true
            } else if let existingMask {
                // Keep the mask tracking the quote as it grows — a stale rect would clip the newly
                // revealed lines for the length of the expand animation — while its carve-out fills
                // back in.
                animation.animator.updateFrame(layer: existingMask, frame: localQuoteFrame, completion: nil)
                if self.dissolveQuoteFade(existingMask, on: view, animation: animation) {
                    anyMaskRemains = true
                }
            }
        }
        self.hasQuoteFadeMasks = anyMaskRemains
    }

    /// Fills a fade's carve-out back in and drops the mask. Returns whether the mask is still
    /// attached on return (it is, for the length of an animated dissolve).
    private func dissolveQuoteFade(_ mask: InstantPageV2QuoteFadeMaskLayer, on view: UIView, animation: ListViewItemUpdateAnimation) -> Bool {
        guard animation.isAnimated else {
            view.layer.mask = nil
            return false
        }
        let token = mask.beginDissolve()
        // An opaque background fills the carve-out in — see `InstantPageV2QuoteFadeMaskLayer`.
        animation.animator.updateBackgroundColor(layer: mask, color: .white, completion: { [weak view, weak mask] _ in
            guard let view, let mask, view.layer.mask === mask, mask.isDissolveCurrent(token) else {
                return
            }
            view.layer.mask = nil
        })
        return true
    }

    func updateInlineEmoji() {
        guard let rc = self.renderContext else { return }
        let context = rc.context
        let cache = context.animationCache
        let renderer = context.animationRenderer
        self.emojiEnableLooping = context.sharedContext.energyUsageSettings.loopEmoji

        var nextIndexById: [Int64: Int] = [:]
        var validIds: [InlineStickerItemLayer.Key] = []

        for view in self.itemViews {
            // Top-level `.text` items host their emoji directly. The thinking block hosts emoji on
            // its shimmer-wrapped inner text view, which the page never sees as a top-level item —
            // so without this it is skipped and the emoji never get layers (invisible). Nested V2
            // sub-layouts (details bodies, table cells) instead run their own updateInlineEmoji.
            let textView: InstantPageV2TextView
            if let topLevelTextView = view as? InstantPageV2TextView {
                textView = topLevelTextView
            } else if let thinkingView = view as? InstantPageV2ThinkingView {
                textView = thinkingView.textView
            } else {
                continue
            }
            let textItem = textView.item.textItem
            let boundsWidth = textItem.frame.size.width
            for line in textItem.lines {
                if line.emojiItems.isEmpty { continue }
                let lineFrame = v2FrameForLine(line, boundingWidth: boundsWidth, alignment: textItem.alignment)
                for emojiItem in line.emojiItems {
                    let index = nextIndexById[emojiItem.emoji.fileId] ?? 0
                    nextIndexById[emojiItem.emoji.fileId] = index + 1
                    let id = InlineStickerItemLayer.Key(id: emojiItem.emoji.fileId, index: index)
                    validIds.append(id)

                    let itemSize = emojiItem.frame.width
                    let localX = lineFrame.minX + (emojiItem.frame.minX - line.frame.minX)
                    let itemFrame = CGRect(
                        x: localX + v2TextViewClippingInset,
                        y: emojiItem.frame.minY + v2TextViewClippingInset,
                        width: itemSize,
                        height: itemSize
                    )

                    var textColor: UIColor?
                    if emojiItem.range.location < textItem.attributedString.length {
                        textColor = textItem.attributedString.attribute(.foregroundColor, at: emojiItem.range.location, effectiveRange: nil) as? UIColor
                    }

                    let data: InstantPageEmojiLayerData
                    if let existing = self.inlineStickerItemLayers[id] {
                        data = existing
                        if data.itemLayer.superlayer !== textView.emojiContainerView.layer {
                            textView.emojiContainerView.layer.addSublayer(data.itemLayer)
                        }
                    } else {
                        let pointSize = floor(itemSize * 1.3)
                        let layer = InlineStickerItemLayer(
                            context: context,
                            userLocation: .other,
                            attemptSynchronousLoad: false,
                            emoji: emojiItem.emoji,
                            file: emojiItem.emoji.file,
                            cache: cache,
                            renderer: renderer,
                            placeholderColor: UIColor(white: 0.5, alpha: 0.3),
                            pointSize: CGSize(width: pointSize, height: pointSize),
                            dynamicColor: textColor
                        )
                        layer.opacity = 0.0
                        data = InstantPageEmojiLayerData(itemLayer: layer)
                        self.inlineStickerItemLayers[id] = data
                        textView.emojiContainerView.layer.addSublayer(layer)
                    }

                    data.itemLayer.dynamicColor = textColor
                    data.itemLayer.frame = itemFrame
                    data.hostView = textView
                    data.charIndexInItem = emojiItem.range.location
                }
            }
        }

        // Second walk: custom emoji inside button pills. Registered here rather than owned by the
        // pill so they inherit the same reveal, looping and visibility gates as body-text emoji
        // instead of needing a parallel implementation of all three.
        for view in self.itemViews {
            // `pillSize` comes from the ITEM, never from the pill's live bounds: a freshly created
            // InstantPageV2InlineButtonView assigns its pill's frame in `layoutSubviews`, which has
            // not run yet at this point.
            var pills: [(pill: InstantPageV2ButtonPillView, size: CGSize)] = []
            if let buttonView = view as? InstantPageV2InlineButtonView {
                pills.append((buttonView.pillView, buttonView.item.frame.size))
            } else if let rowView = view as? InstantPageV2ButtonRowView {
                for (index, pill) in rowView.pillViews.enumerated() where index < rowView.item.buttons.count {
                    pills.append((pill, rowView.item.buttons[index].frame.size))
                }
            } else {
                continue
            }

            for entry in pills {
                let pill = entry.pill
                let textColor = pill.resolvedLabelColor
                for placement in instantPageButtonEmojiPlacements(attachment: pill.attachment, pillSize: entry.size) {
                    let index = nextIndexById[placement.emoji.fileId] ?? 0
                    nextIndexById[placement.emoji.fileId] = index + 1
                    let id = InlineStickerItemLayer.Key(id: placement.emoji.fileId, index: index)
                    validIds.append(id)

                    let data: InstantPageEmojiLayerData
                    if let existing = self.inlineStickerItemLayers[id] {
                        data = existing
                        if data.itemLayer.superlayer !== pill.emojiContainerView.layer {
                            pill.emojiContainerView.layer.addSublayer(data.itemLayer)
                        }
                    } else {
                        let pointSize = floor(placement.frame.width * 1.3)
                        let layer = InlineStickerItemLayer(
                            context: context,
                            userLocation: .other,
                            attemptSynchronousLoad: false,
                            emoji: placement.emoji,
                            file: placement.emoji.file,
                            cache: cache,
                            renderer: renderer,
                            placeholderColor: UIColor(white: 0.5, alpha: 0.3),
                            pointSize: CGSize(width: pointSize, height: pointSize),
                            dynamicColor: textColor
                        )
                        layer.opacity = 0.0
                        data = InstantPageEmojiLayerData(itemLayer: layer)
                        self.inlineStickerItemLayers[id] = data
                        pill.emojiContainerView.layer.addSublayer(layer)
                    }

                    data.itemLayer.dynamicColor = textColor
                    data.itemLayer.frame = placement.frame
                    data.hostView = pill
                    // No reveal cursor on a pill host, so `charIndexInItem` is unused; the layer is
                    // taken to full opacity by `updateEmojiReveal` at the end of this method.
                    data.charIndexInItem = 0
                }
            }
        }

        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, data) in self.inlineStickerItemLayers where !validIds.contains(key) {
            removeKeys.append(key)
            data.itemLayer.removeFromSuperlayer()
        }
        for key in removeKeys {
            self.inlineStickerItemLayers.removeValue(forKey: key)
        }

        self.updateEmojiReveal(animated: false)
    }

    func updateInlineImages() {
        guard let renderContext = self.renderContext,
              let layout = self.currentLayout,
              let theme = self.currentTheme
        else { return }
        let context = renderContext.context

        var nextIndexById: [Int64: Int] = [:]
        var validKeys: Set<InlineImageKey> = []

        for view in self.itemViews {
            // Same nesting as updateInlineEmoji: top-level `.text` items host their inline images
            // directly; the thinking block hosts them on its shimmer-wrapped inner text view, which
            // the page never sees as a top-level item. Nested V2 sub-layouts run their own pass.
            let textView: InstantPageV2TextView
            if let topLevelTextView = view as? InstantPageV2TextView {
                textView = topLevelTextView
            } else if let thinkingView = view as? InstantPageV2ThinkingView {
                textView = thinkingView.textView
            } else {
                continue
            }
            let textItem = textView.item.textItem
            let boundsWidth = textItem.frame.size.width
            for line in textItem.lines {
                if line.imageItems.isEmpty { continue }
                let lineFrame = v2FrameForLine(line, boundingWidth: boundsWidth, alignment: textItem.alignment)
                for imageItem in line.imageItems {
                    let index = nextIndexById[imageItem.id.id] ?? 0
                    nextIndexById[imageItem.id.id] = index + 1
                    let key = InlineImageKey(fileId: imageItem.id.id, occurrenceIndex: index)
                    guard let media = layout.media[imageItem.id] else { continue }
                    validKeys.insert(key)

                    let localX = lineFrame.minX + (imageItem.frame.minX - line.frame.minX)
                    let itemFrame = CGRect(
                        x: localX + v2TextViewClippingInset,
                        y: imageItem.frame.minY + v2TextViewClippingInset,
                        width: imageItem.frame.width,
                        height: imageItem.frame.height
                    )

                    let data: InstantPageInlineImageData
                    if let existing = self.inlineImageViews[key] {
                        data = existing
                        if data.view.superview !== textView.imageContainerView {
                            textView.imageContainerView.addSubview(data.view)
                        }
                    } else {
                        let newView = InstantPageV2InlineImageView(
                            media: media,
                            webpage: layout.webpage,
                            frame: itemFrame,
                            context: context,
                            userLocation: .other,
                            theme: theme,
                            captureProtected: renderContext.captureProtected
                        )
                        // Image starts hidden; updateImageReveal pops it in when the streaming
                        // cursor crosses its char-index. For non-streaming pages (no
                        // `TypingDraftMessageAttribute`), `revealed = true` (via the fallback in
                        // updateImageReveal) sets alpha = 1 unconditionally on the next call.
                        newView.alpha = 0.0
                        data = InstantPageInlineImageData(view: newView)
                        self.inlineImageViews[key] = data
                        textView.imageContainerView.addSubview(newView)
                    }

                    data.view.frame = itemFrame
                    data.view.captureProtected = renderContext.captureProtected
                    data.textView = textView
                    data.charIndexInItem = imageItem.range.location
                }
            }
        }

        var removeKeys: [InlineImageKey] = []
        for (key, data) in self.inlineImageViews where !validKeys.contains(key) {
            removeKeys.append(key)
            data.view.removeFromSuperview()
        }
        for key in removeKeys {
            self.inlineImageViews.removeValue(forKey: key)
        }

        self.updateImageReveal(animated: false)
    }

    func updateEmojiReveal(animated: Bool) {
        for (_, data) in self.inlineStickerItemLayers {
            let revealed: Bool
            if let textView = data.hostView as? InstantPageV2TextView, let count = textView.currentRevealCharacterCount {
                revealed = data.charIndexInItem < count
            } else {
                revealed = true
            }
            if data.revealed == revealed {
                continue
            }
            data.revealed = revealed
            if revealed {
                if animated {
                    data.itemLayer.opacity = 1.0
                    let opacityAnim = CABasicAnimation(keyPath: "opacity")
                    opacityAnim.fromValue = 0.0
                    opacityAnim.toValue = 1.0
                    opacityAnim.duration = 0.2
                    data.itemLayer.add(opacityAnim, forKey: "emojiRevealOpacity")
                    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
                    scaleAnim.fromValue = 0.1
                    scaleAnim.toValue = 1.0
                    scaleAnim.duration = 0.2
                    scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    data.itemLayer.add(scaleAnim, forKey: "emojiRevealScale")
                } else {
                    data.itemLayer.opacity = 1.0
                }
            } else {
                data.itemLayer.opacity = 0.0
            }
        }
        self.updateEmojiVisibility()
    }

    func updateImageReveal(animated: Bool) {
        for (_, data) in self.inlineImageViews {
            let revealed: Bool
            if let textView = data.textView, let count = textView.currentRevealCharacterCount {
                revealed = data.charIndexInItem < count
            } else {
                revealed = true
            }
            if data.revealed == revealed {
                continue
            }
            data.revealed = revealed
            if revealed {
                if animated {
                    data.view.layer.opacity = 1.0
                    let opacityAnim = CABasicAnimation(keyPath: "opacity")
                    opacityAnim.fromValue = 0.0
                    opacityAnim.toValue = 1.0
                    opacityAnim.duration = 0.2
                    data.view.layer.add(opacityAnim, forKey: "inlineImageRevealOpacity")
                    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
                    scaleAnim.fromValue = 0.1
                    scaleAnim.toValue = 1.0
                    scaleAnim.duration = 0.2
                    scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    data.view.layer.add(scaleAnim, forKey: "inlineImageRevealScale")
                } else {
                    data.view.layer.opacity = 1.0
                }
            } else {
                data.view.layer.opacity = 0.0
            }
        }
    }

    func updateEmojiVisibility() {
        for (_, data) in self.inlineStickerItemLayers {
            let onScreen: Bool
            if let visibilityRect = self.visibilityRect, let hostView = data.hostView {
                let rectInSelf = hostView.convert(data.itemLayer.frame, to: self)
                onScreen = rectInSelf.intersects(visibilityRect)
            } else {
                // No visibility rect == not tracked / off-screen → don't animate. The root view's
                // rect is propagated down the nested tree (details bodies, table cells/title) by
                // `propagateVisibilityRect`, so a nil here genuinely means "not visible".
                onScreen = false
            }
            data.itemLayer.isVisibleForAnimations = self.emojiEnableLooping && data.revealed && onScreen
        }
        self.propagateVisibilityRect()
    }

    // Tells each direct item view whether it currently intersects the visibility rect, so inline
    // players (video) attach/detach with scroll. Nested details/table views run their own pass when
    // their `visibilityRect` is set by `propagateVisibilityRect` (which `updateEmojiVisibility` calls).
    func updateItemVisibility() {
        for view in self.itemViews {
            let onScreen: Bool
            if let visibilityRect = self.visibilityRect {
                onScreen = view.frame.intersects(visibilityRect)
            } else {
                onScreen = false
            }
            view.instantPageUpdateIsVisible(onScreen)
        }
    }

    // Pushes this view's `visibilityRect` down into every nested V2 view (details body, table
    // title + cells), converted into each child's coordinate space. Each child's `visibilityRect`
    // didSet re-runs `updateEmojiVisibility`, which propagates one level further — so a single
    // root assignment fans out across the whole tree.
    private func propagateVisibilityRect() {
        for view in self.itemViews {
            for nested in InstantPageV2View.nestedV2Views(of: view) {
                let childRect = self.visibilityRect.map { self.convert($0, to: nested) }
                if nested.visibilityRect != childRect {
                    nested.visibilityRect = childRect
                }
            }
        }
    }

    /// Reveals (or re-hides) every spoiler in this view and nested details/table V2 views.
    /// `location` (this view's coords) drives the dust explosion origin for whichever text view
    /// contains it; the rest just toggle. Single-flag behavior mirrors ChatMessageTextBubbleContentNode.
    public func setDisplayContentsUnderSpoilers(_ value: Bool, atLocation location: CGPoint?, animated: Bool) {
        self.displayContentsUnderSpoilers = value
        for view in self.itemViews {
            if let textView = view as? InstantPageV2TextView {
                let childLocation = location.map { self.convert($0, to: textView) }
                textView.setDisplayContentsUnderSpoilers(value, atLocation: childLocation, animated: animated)
            }
            for nested in InstantPageV2View.nestedV2Views(of: view) {
                let childLocation = location.map { self.convert($0, to: nested) }
                nested.setDisplayContentsUnderSpoilers(value, atLocation: childLocation, animated: animated)
            }
        }
    }

    private static func nestedV2Views(of view: InstantPageItemView) -> [InstantPageV2View] {
        if let detailsView = view as? InstantPageV2DetailsView {
            return detailsView.bodyView.map { [$0] } ?? []
        } else if let tableView = view as? InstantPageV2TableView {
            var result: [InstantPageV2View] = []
            if let titleSubView = tableView.titleSubView {
                result.append(titleSubView)
            }
            result.append(contentsOf: tableView.cellSubViews)
            return result
        }
        return []
    }

    /// Returns the input view typed-updated against `item`, or `nil` if the existing view's
    /// concrete class doesn't match the item's case (e.g. a `text` slot has been replaced by
    /// a `divider` in the new layout). Caller falls back to `makeItemView`.
    private func reuse(existingView: InstantPageItemView, for item: InstantPageV2LaidOutItem, theme: InstantPageTheme, animation: ListViewItemUpdateAnimation) -> InstantPageItemView? {
        switch item {
        case let .text(text):
            guard let v = existingView as? InstantPageV2TextView else { return nil }
            v.update(item: text, theme: theme, animation: animation)
            return v
        case let .codeBlock(block):
            guard let v = existingView as? InstantPageV2CodeBlockView else { return nil }
            v.update(item: block, theme: theme)
            return v
        case let .divider(divider):
            guard let v = existingView as? InstantPageV2DividerView else { return nil }
            v.update(item: divider, theme: theme)
            return v
        case let .listMarker(marker):
            guard let v = existingView as? InstantPageV2ListMarkerView else { return nil }
            v.update(item: marker, theme: theme, interactive: self.checkboxTapped != nil)
            return v
        case let .blockQuoteBar(bar):
            guard let v = existingView as? InstantPageV2BlockQuoteBarView else { return nil }
            v.update(item: bar, theme: theme)
            return v
        case let .quoteFrame(frame):
            guard let v = existingView as? InstantPageV2QuoteFrameView else { return nil }
            v.update(item: frame, theme: theme, animation: animation)
            return v
        case let .shape(shape):
            guard let v = existingView as? InstantPageV2ShapeView else { return nil }
            v.update(item: shape, theme: theme)
            return v
        case let .imageOrnament(ornament):
            guard let v = existingView as? InstantPageV2ImageOrnamentView else { return nil }
            v.update(item: ornament, theme: theme)
            return v
        case let .mediaPlaceholder(media):
            guard let v = existingView as? InstantPageV2MediaPlaceholderView else { return nil }
            v.update(item: media, theme: theme)
            return v
        case let .details(details):
            guard let v = existingView as? InstantPageV2DetailsView else { return nil }
            v.update(item: details, theme: theme, renderContext: self.renderContext, animation: animation)
            return v
        case let .table(table):
            guard let v = existingView as? InstantPageV2TableView else { return nil }
            v.update(item: table, theme: theme)
            return v
        case let .anchor(anchor):
            guard let v = existingView as? InstantPageV2AnchorView else { return nil }
            v.update(item: anchor, theme: theme)
            return v
        case let .formula(formula):
            guard let v = existingView as? InstantPageV2FormulaView else { return nil }
            v.update(item: formula, theme: theme)
            return v
        case let .inlineButton(button):
            guard let v = existingView as? InstantPageV2InlineButtonView else { return nil }
            v.update(item: button, theme: theme)
            // Re-wire on reuse: the closure captures self, and a reused view may have been created
            // against a previous InstantPageV2View.
            v.onButtonTapped = { [weak self] button, progress in
                self?.buttonTapped?(button, progress)
            }
            return v
        case let .buttonRow(row):
            guard let v = existingView as? InstantPageV2ButtonRowView else { return nil }
            v.update(item: row, theme: theme)
            v.onButtonTapped = { [weak self] button, progress in
                self?.buttonTapped?(button, progress)
            }
            return v
        case let .mediaImage(media):
            guard let v = existingView as? InstantPageV2MediaImageView, let rc = self.renderContext else { return nil }
            v.update(item: media, theme: theme, renderContext: rc)
            return v
        case let .mediaVideo(media):
            guard let v = existingView as? InstantPageV2MediaVideoView, let rc = self.renderContext else { return nil }
            v.update(item: media, theme: theme, renderContext: rc)
            return v
        case let .mediaMap(media):
            guard let v = existingView as? InstantPageV2MediaMapView, let rc = self.renderContext else { return nil }
            v.update(item: media, theme: theme, renderContext: rc)
            return v
        case let .mediaCoverImage(media):
            guard let v = existingView as? InstantPageV2MediaCoverImageView, let rc = self.renderContext else { return nil }
            v.update(item: media, theme: theme, renderContext: rc)
            return v
        case let .mediaAudio(media):
            guard let v = existingView as? InstantPageV2MediaAudioView, let rc = self.renderContext else { return nil }
            v.update(item: media, theme: theme, renderContext: rc)
            return v
        case let .document(document):
            guard let v = existingView as? InstantPageV2DocumentView, let rc = self.renderContext else { return nil }
            // Re-wire: a recycled view may belong to a previous InstantPageV2View (see onDocumentTapped).
            v.onDocumentTapped = { [weak self] file in
                self?.documentTapped?(file)
            }
            v.update(item: document, theme: theme, renderContext: rc)
            return v
        case let .thinking(thinking):
            guard let v = existingView as? InstantPageV2ThinkingView else { return nil }
            v.update(item: thinking, theme: theme)
            return v
        case let .slideshow(slideshow):
            guard let v = existingView as? InstantPageV2SlideshowView, let rc = self.renderContext else { return nil }
            v.update(item: slideshow, theme: theme, renderContext: rc)
            return v
        case let .unsupportedContent(unsupported):
            guard let v = existingView as? InstantPageV2UnsupportedView else { return nil }
            v.update(item: unsupported, theme: theme, renderContext: self.renderContext)
            // Re-wire on reuse: the closure captures self, and a reused view may have been created
            // against a previous InstantPageV2View.
            v.onActionTapped = { [weak self] in
                self?.unsupportedActionTapped?()
            }
            return v
        }
    }

    static func stableId(for item: InstantPageV2LaidOutItem, atPosition position: Int) -> InstantPageV2StableItemId {
        switch item {
        case let .mediaImage(m):       return .media(m.media.index)
        case let .mediaVideo(m):       return .media(m.media.index)
        case let .mediaMap(m):         return .media(m.media.index)
        case let .mediaCoverImage(m):  return .media(m.media.index)
        case let .mediaAudio(m):       return .media(m.media.index)
        case let .document(d):         return .media(d.media.index)
        case let .details(d):          return .details(d.index)
        case .text:                    return .positional(.text, position)
        case .codeBlock:               return .positional(.codeBlock, position)
        case .divider:                 return .positional(.divider, position)
        case .listMarker:              return .positional(.listMarker, position)
        case .blockQuoteBar:           return .positional(.blockQuoteBar, position)
        case .quoteFrame:              return .positional(.quoteFrame, position)
        case .shape:                   return .positional(.shape, position)
        case .imageOrnament:           return .positional(.imageOrnament, position)
        case .mediaPlaceholder:        return .positional(.mediaPlaceholder, position)
        case .table:                   return .positional(.table, position)
        case .anchor:                  return .positional(.anchor, position)
        case .formula:                 return .positional(.formula, position)
        case .inlineButton:            return .positional(.inlineButton, position)
        case .buttonRow:               return .positional(.buttonRow, position)
        case .thinking:                return .thinking(position)
        case .slideshow:               return .positional(.slideshow, position)
        case .unsupportedContent:      return .positional(.unsupportedContent, position)
        }
    }

    private func propagateRegistryHost(to view: InstantPageItemView) {
        let host = self.effectiveRegistryHost
        if let details = view as? InstantPageV2DetailsView {
            details.forEachSubLayoutView { sub in
                sub.rootMediaRegistryHost = host
            }
        }
        if let table = view as? InstantPageV2TableView {
            table.forEachSubLayoutView { sub in
                sub.rootMediaRegistryHost = host
            }
        }
    }

    /// Looks up the wrapper view registered under `media.index` and returns gallery transition
    /// arguments backed by its wrapped `InstantPageImageNode`. Returns `nil` if the wrapper is
    /// not currently registered (e.g. the media is inside a collapsed details block).
    func transitionArgsFor(_ media: InstantPageMedia, addToTransitionSurface: @escaping (UIView) -> Void) -> GalleryTransitionArguments? {
        guard let wrapperBox = self.trueRegistryRoot.mediaRegistry[media.index], let wrapper = wrapperBox.value else {
            return nil
        }
        guard let itemView = wrapper as? InstantPageItemView else { return nil }
        guard let transitionNode = itemView.instantPageTransitionNode(for: media) else { return nil }
        return GalleryTransitionArguments(transitionNode: transitionNode, addToTransitionSurface: addToTransitionSurface)
    }

    /// Forwards a hidden-media tick from the gallery's `hiddenMedia` signal to every registered
    /// wrapper, calling `updateHiddenMedia(media:)` on each wrapped image node.
    func applyHiddenMedia(_ hidden: InstantPageMedia?) {
        for (_, weakBox) in self.trueRegistryRoot.mediaRegistry {
            guard let wrapper = weakBox.value else { continue }
            (wrapper as? InstantPageItemView)?.instantPageUpdateHiddenMedia(hidden)
        }
    }

    private func makeItemView(for item: InstantPageV2LaidOutItem, theme: InstantPageTheme) -> InstantPageItemView? {
        switch item {
        case let .text(text):
            return InstantPageV2TextView(item: text, theme: theme)
        case let .divider(divider):
            return InstantPageV2DividerView(item: divider, theme: theme)
        case let .anchor(anchor):
            return InstantPageV2AnchorView(item: anchor, theme: theme)
        case let .listMarker(marker):
            let view = InstantPageV2ListMarkerView(item: marker, theme: theme)
            view.onCheckboxTapped = { [weak self] path, newValue in
                self?.checkboxTapped?(path, newValue)
            }
            view.update(item: marker, theme: theme, interactive: self.checkboxTapped != nil)
            return view
        case let .codeBlock(block):
            return InstantPageV2CodeBlockView(item: block, theme: theme)
        case let .blockQuoteBar(bar):
            return InstantPageV2BlockQuoteBarView(item: bar, theme: theme)
        case let .quoteFrame(frame):
            return InstantPageV2QuoteFrameView(item: frame, theme: theme)
        case let .shape(shape):
            return InstantPageV2ShapeView(item: shape, theme: theme)
        case let .imageOrnament(ornament):
            return InstantPageV2ImageOrnamentView(item: ornament)
        case let .mediaPlaceholder(media):
            return InstantPageV2MediaPlaceholderView(item: media, theme: theme)
        case let .details(details):
            let view = InstantPageV2DetailsView(item: details, theme: theme, renderContext: self.renderContext)
            view.onTitleTapped = { [weak self] index in
                self?.detailsTapped?(index)
            }
            return view
        case let .table(table):
            return InstantPageV2TableView(item: table, theme: theme, renderContext: self.renderContext)
        case let .mediaImage(media):
            if let renderContext = self.renderContext {
                return InstantPageV2MediaImageView(item: media, renderContext: renderContext, theme: theme)
            } else {
                return InstantPageV2MediaPlaceholderView(item: placeholderFallback(for: media), theme: theme)
            }
        case let .mediaVideo(media):
            if let renderContext = self.renderContext {
                return InstantPageV2MediaVideoView(item: media, renderContext: renderContext, theme: theme)
            } else {
                return InstantPageV2MediaPlaceholderView(item: placeholderFallback(for: media), theme: theme)
            }
        case let .mediaMap(media):
            if let renderContext = self.renderContext {
                return InstantPageV2MediaMapView(item: media, renderContext: renderContext, theme: theme)
            } else {
                return InstantPageV2MediaPlaceholderView(item: placeholderFallback(for: media), theme: theme)
            }
        case let .mediaCoverImage(media):
            if let renderContext = self.renderContext {
                return InstantPageV2MediaCoverImageView(item: media, renderContext: renderContext, theme: theme)
            } else {
                return InstantPageV2MediaPlaceholderView(item: placeholderFallback(for: media), theme: theme)
            }
        case let .mediaAudio(media):
            if let renderContext = self.renderContext {
                return InstantPageV2MediaAudioView(item: media, renderContext: renderContext, theme: theme)
            } else {
                return InstantPageV2MediaPlaceholderView(item: InstantPageV2MediaPlaceholderItem(frame: media.frame, kind: .audio, cornerRadius: 0.0), theme: theme)
            }
        case let .document(document):
            if let renderContext = self.renderContext {
                let view = InstantPageV2DocumentView(item: document, renderContext: renderContext, theme: theme)
                view.onDocumentTapped = { [weak self] file in
                    self?.documentTapped?(file)
                }
                return view
            } else {
                return InstantPageV2MediaPlaceholderView(item: InstantPageV2MediaPlaceholderItem(frame: document.frame, kind: .audio, cornerRadius: 0.0), theme: theme)
            }
        case let .formula(formula):
            return InstantPageV2FormulaView(item: formula, theme: theme)
        case let .inlineButton(button):
            let view = InstantPageV2InlineButtonView(item: button, theme: theme)
            view.onButtonTapped = { [weak self] button, progress in
                self?.buttonTapped?(button, progress)
            }
            return view
        case let .buttonRow(row):
            let view = InstantPageV2ButtonRowView(item: row, theme: theme)
            view.onButtonTapped = { [weak self] button, progress in
                self?.buttonTapped?(button, progress)
            }
            return view
        case let .unsupportedContent(unsupported):
            let view = InstantPageV2UnsupportedView(item: unsupported, theme: theme, renderContext: self.renderContext)
            view.onActionTapped = { [weak self] in
                self?.unsupportedActionTapped?()
            }
            return view
        case let .thinking(thinking):
            return InstantPageV2ThinkingView(item: thinking, theme: theme)
        case let .slideshow(slideshow):
            if let renderContext = self.renderContext {
                return InstantPageV2SlideshowView(item: slideshow, renderContext: renderContext, theme: theme)
            } else {
                return InstantPageV2MediaPlaceholderView(item: InstantPageV2MediaPlaceholderItem(frame: slideshow.frame, kind: .slideshow, cornerRadius: 0.0), theme: theme)
            }
        }
    }

    /// Returns the frame the parent should assign to the view for `item`.
    ///
    /// For most item types this is `item.frame`. `InstantPageV2TextView` widens its backing store
    /// by `v2TextViewClippingInset` on every side to accommodate glyph overhang and underline
    /// rendering past the text's logical `maxY` — the same inset its `init` applies when
    /// constructing the view. The reuse path must apply the same expansion so that re-layout
    /// (theme change, bubble resize, etc.) does not clip italic glyphs or underlines.
    ///
    /// Keep this helper aligned with each view class's init-time frame computation.
    private static func actualFrame(forItem item: InstantPageV2LaidOutItem) -> CGRect {
        switch item {
        case let .text(textItem):
            return textItem.frame.insetBy(dx: -v2TextViewClippingInset, dy: -v2TextViewClippingInset)
        default:
            return item.frame
        }
    }
}

// MARK: - Placeholder fallbacks for the four typed media items
//
// Used by `makeItemView` when `renderContext == nil` (the zero-arg V2View constructor):
// we still need to emit a sized grey rectangle for image/video/map/coverImage so the
// surrounding layout doesn't collapse. Each helper synthesizes a placeholder item with
// the same frame + cornerRadius as the typed item, picking the kind that matches the
// closest existing placeholder visual.

private func placeholderFallback(for item: InstantPageV2MediaImageItem) -> InstantPageV2MediaPlaceholderItem {
    return InstantPageV2MediaPlaceholderItem(frame: item.frame, kind: .image, cornerRadius: item.cornerRadius)
}

private func placeholderFallback(for item: InstantPageV2MediaVideoItem) -> InstantPageV2MediaPlaceholderItem {
    return InstantPageV2MediaPlaceholderItem(frame: item.frame, kind: .video, cornerRadius: item.cornerRadius)
}

private func placeholderFallback(for item: InstantPageV2MediaMapItem) -> InstantPageV2MediaPlaceholderItem {
    return InstantPageV2MediaPlaceholderItem(frame: item.frame, kind: .map, cornerRadius: item.cornerRadius)
}

private func placeholderFallback(for item: InstantPageV2MediaCoverImageItem) -> InstantPageV2MediaPlaceholderItem {
    return InstantPageV2MediaPlaceholderItem(frame: item.frame, kind: .webEmbed, cornerRadius: item.cornerRadius)
}

// MARK: - Item view protocol

protocol InstantPageItemView: UIView {
    /// Frame in the parent V2 view's coordinate space (== `item.frame`).
    var itemFrame: CGRect { get }
    /// Recursion hook for nested layouts (details body, table cells, table title).
    var subLayoutView: InstantPageV2View? { get }
    /// Gallery open: the transition source for `media` if this view (or a descendant) shows it.
    /// Default nil (non-media views). Media views forward to their wrapped `InstantPageImageNode`;
    /// the slideshow forwards to its matching page.
    func instantPageTransitionNode(for media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
    /// Gallery hidden-media tick: hide/show the source for `media`. Default no-op.
    func instantPageUpdateHiddenMedia(_ media: InstantPageMedia?)
    /// Visibility tick for players/animations that must attach only while on screen. Default no-op;
    /// the inline video view (`InstantPageV2MediaVideoView`) toggles `canAttachContent`.
    func instantPageUpdateIsVisible(_ isVisible: Bool)
}

extension InstantPageItemView {
    var subLayoutView: InstantPageV2View? { return nil }
    func instantPageTransitionNode(for media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? { return nil }
    func instantPageUpdateHiddenMedia(_ media: InstantPageMedia?) { }
    func instantPageUpdateIsVisible(_ isVisible: Bool) { }
}

// MARK: - Text view (port of V1 InstantPageTextItem.drawInTile)

/// Per-side padding applied to `InstantPageV2TextView`'s backing store, beyond the
/// item's typographic frame. Marker rounded rects extend ±2pt past their run, italic
/// or accented glyphs can overhang past the line's advance width, and the last line's
/// underline sits 2pt below `lineFrame.maxY`. The view grows by this amount on each
/// side and the draw context translates by the same amount so visual position is
/// unchanged.
private let v2TextViewClippingInset: CGFloat = 4.0

final class InstantPageV2TextView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2TextItem
    var itemFrame: CGRect { return self.item.frame }

    private let renderContainer: UIView
    private let renderView: TextRenderView
    /// Sibling of `renderContainer`, holds inline `InstantPageV2InlineImageView`s
    /// owned by the parent `InstantPageV2View`. Sits BELOW `emojiContainerView`
    /// (so a colocated emoji renders above an image) and ABOVE `renderContainer`
    /// (so the reveal mask wipes text without clipping images).
    let imageContainerView: UIView = UIView()
    let emojiContainerView: UIView = UIView()
    let spoilerContainerView: UIView = UIView()
    private var dustNode: InvisibleInkDustNode?
    private var displayContentsUnderSpoilers: Bool = false
    var enableSpoilerAnimations: Bool = true {
        didSet {
            if oldValue != self.enableSpoilerAnimations, let dustNode = self.dustNode {
                self.dustNode = nil
                dustNode.view.removeFromSuperview()
                self.updateSpoiler(animated: false)
            }
        }
    }

    /// Which line last carried the collapsed-quote "…", so `update` can tell the toggle apart from
    /// every other reason it runs. `nil` = none.
    private var appliedTruncationTokenLine: Int?

    // Reveal mask state — populated in Task 5.
    private var maxCharacterDrawCount: Int?
    private var previousMaxCharacterDrawCount: Int = 0
    private var revealMaskLayer: SimpleLayer?
    private var revealLineMaskLayers: [SimpleLayer] = []
    private var animatingSnippetLayers: [SnippetLayer] = []

    init(item: InstantPageV2TextItem, theme: InstantPageTheme) {
        self.item = item
        self.renderContainer = UIView()
        self.renderView = TextRenderView(item: item)
        super.init(frame: item.frame.insetBy(dx: -v2TextViewClippingInset, dy: -v2TextViewClippingInset))
        // Structural wiring only (one-time); all frames/content live in update(item:theme:).
        self.backgroundColor = .clear
        self.isOpaque = false
        self.renderContainer.backgroundColor = .clear
        self.renderContainer.isOpaque = false
        self.addSubview(self.renderContainer)
        self.renderContainer.addSubview(self.renderView)
        self.imageContainerView.isUserInteractionEnabled = false
        self.addSubview(self.imageContainerView)
        self.emojiContainerView.isUserInteractionEnabled = false
        self.addSubview(self.emojiContainerView)
        self.spoilerContainerView.isUserInteractionEnabled = false
        self.addSubview(self.spoilerContainerView)
        self.update(item: item, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(item: InstantPageV2TextItem, theme: InstantPageTheme, animation: ListViewItemUpdateAnimation = .None) {
        let _ = theme
        self.item = item
        // Lay every container out from the item's own (clipping-inset-expanded) frame rather than
        // self.bounds, so the single path is correct regardless of when the parent assigns our
        // frame — and so a reused text view that changed size (e.g. AI streaming) re-frames its
        // renderContainer/renderView too, which the old update path skipped.
        // Height includes `overflowHeight`, which the layout deliberately did not reserve: a collapsed
        // quote keeps the lines past its preview drawn so its animated fade can sweep them away. They
        // spill past this view's own bounds on purpose — nothing here clips — and the quote's mask is
        // what hides them. See `InstantPageV2TextItem.overflowHeight`.
        let containerBounds = CGRect(
            origin: .zero,
            size: CGSize(
                width: item.frame.width + v2TextViewClippingInset * 2.0,
                height: item.frame.height + item.overflowHeight + v2TextViewClippingInset * 2.0))
        let boxIsUnchanged = self.renderView.frame == containerBounds
        let truncationTokenLine = item.textItem.lines.firstIndex(where: { $0.additionalTrailingLine != nil })
        let tokenChanged = truncationTokenLine != self.appliedTruncationTokenLine
        self.appliedTruncationTokenLine = truncationTokenLine

        self.renderContainer.frame = containerBounds
        self.renderView.frame = containerBounds
        self.renderView.item = item
        // Toggling a collapsed quote changes exactly ONE thing in what this view draws: the "…" on
        // the last visible line. Every other line, and every line position, is identical in both
        // states because the cut lines stay drawn as overflow — so the token would otherwise blink
        // in and out while the geometry around it animated. Crossfade the backing store instead,
        // the way the reference does for its spoiler reveal: keep the bitmap that is already there,
        // force the redraw, then dissolve between the two and let CA discard the old one.
        //
        // Requires the box to be the same size, which is the honest precondition for a contents
        // crossfade — a resized layer would squash the old bitmap into the new bounds. That also
        // keeps this off the AI-streaming path, which grows the box and has its own reveal.
        if animation.isAnimated, tokenChanged, boxIsUnchanged, let previousContents = self.renderView.layer.contents {
            self.renderView.setNeedsDisplay()
            self.renderView.layer.displayIfNeeded()
            animation.transition.animateContents(layer: self.renderView.layer, from: previousContents)
        } else {
            self.renderView.setNeedsDisplay()
        }
        self.imageContainerView.frame = containerBounds
        self.emojiContainerView.frame = containerBounds
        self.spoilerContainerView.frame = containerBounds
        self.renderView.displayContentsUnderSpoilers = self.displayContentsUnderSpoilers
        self.updateSpoiler(animated: false)
    }

    private func spoilerRectsInContainer() -> [CGRect] {
        let textItem = self.item.textItem
        let boundsWidth = textItem.frame.size.width
        var rects: [CGRect] = []
        for line in textItem.lines {
            if line.spoilerItems.isEmpty { continue }
            let lineFrame = v2FrameForLine(line, boundingWidth: boundsWidth, alignment: textItem.alignment)
            for spoiler in line.spoilerItems {
                let localX = lineFrame.minX + (spoiler.frame.minX - line.frame.minX)
                rects.append(CGRect(x: localX + v2TextViewClippingInset, y: spoiler.frame.minY + v2TextViewClippingInset, width: spoiler.frame.width, height: spoiler.frame.height))
            }
        }
        return rects
    }

    func updateSpoiler(animated: Bool) {
        let rects = self.spoilerRectsInContainer()
        if rects.isEmpty || self.displayContentsUnderSpoilers {
            if let dustNode = self.dustNode {
                self.dustNode = nil
                dustNode.view.removeFromSuperview()
            }
            return
        }

        let dustNode: InvisibleInkDustNode
        if let current = self.dustNode {
            dustNode = current
        } else {
            dustNode = InvisibleInkDustNode(textNode: nil, enableAnimations: self.enableSpoilerAnimations)
            self.dustNode = dustNode
            self.spoilerContainerView.addSubview(dustNode.view)
        }

        var color: UIColor = UIColor(white: 0.0, alpha: 1.0)
        let textItem = self.item.textItem
        if let firstRange = textItem.lines.first(where: { !$0.spoilerItems.isEmpty })?.spoilerItems.first?.range, firstRange.location < textItem.attributedString.length {
            if let fg = textItem.attributedString.attribute(.foregroundColor, at: firstRange.location, effectiveRange: nil) as? UIColor {
                color = fg
            }
        }

        dustNode.view.frame = self.spoilerContainerView.bounds
        dustNode.update(size: self.spoilerContainerView.bounds.size, color: color, textColor: color, rects: rects, wordRects: rects)
    }

    func setDisplayContentsUnderSpoilers(_ value: Bool, atLocation location: CGPoint?, animated: Bool) {
        if self.displayContentsUnderSpoilers == value {
            return
        }
        self.displayContentsUnderSpoilers = value
        self.renderView.displayContentsUnderSpoilers = value
        self.renderView.setNeedsDisplay()
        if value {
            if let dustNode = self.dustNode {
                if let location, animated {
                    dustNode.revealAtLocation(self.convert(location, to: self.spoilerContainerView))
                } else {
                    dustNode.update(revealed: true, animated: animated)
                }
            }
        } else {
            self.updateSpoiler(animated: animated)
        }
    }

    func updateRevealCharacterCount(value: Int?, animated: Bool) {
        if self.maxCharacterDrawCount == value {
            return
        }
        self.maxCharacterDrawCount = value
        self.updateRevealMask(animateNewSegments: animated)
    }

    var currentRevealCharacterCount: Int? {
        return self.maxCharacterDrawCount
    }

    private struct RevealLineInfo {
        let lineFrame: CGRect
        let lineHeight: CGFloat
        let revealedWidth: CGFloat
        let isFull: Bool
        let isRTL: Bool
    }

    private func computeRevealedLines(characterLimit: Int) -> [RevealLineInfo] {
        var result: [RevealLineInfo] = []
        var remainingCharacters = characterLimit

        let textItem = self.item.textItem
        let boundsWidth = textItem.frame.size.width

        for line in textItem.lines {
            let lineFrame = v2FrameForLine(line, boundingWidth: boundsWidth, alignment: textItem.alignment)
            // Translate from textItem-local to renderView-local coords (renderView's draw(_) translates by the inset).
            let renderLocalLineFrame = lineFrame.offsetBy(dx: v2TextViewClippingInset, dy: v2TextViewClippingInset)
            let lineHeight = lineFrame.size.height

            guard let characterRects = line.characterRects else {
                let revealedWidth: CGFloat = remainingCharacters > 0 ? renderLocalLineFrame.width : 0.0
                result.append(RevealLineInfo(lineFrame: renderLocalLineFrame, lineHeight: lineHeight, revealedWidth: revealedWidth, isFull: remainingCharacters > 0, isRTL: line.isRTL))
                if remainingCharacters > 0 {
                    remainingCharacters -= line.range.length
                }
                continue
            }

            if remainingCharacters <= 0 {
                result.append(RevealLineInfo(lineFrame: renderLocalLineFrame, lineHeight: lineHeight, revealedWidth: 0.0, isFull: false, isRTL: line.isRTL))
                continue
            }

            let revealCount = min(characterRects.count, remainingCharacters)
            var revealedWidth: CGFloat = 0.0
            if line.isRTL {
                var minX: CGFloat = .greatestFiniteMagnitude
                for j in 0 ..< revealCount {
                    let rect = characterRects[j]
                    if !rect.isEmpty {
                        minX = min(minX, rect.minX)
                    }
                }
                if minX != .greatestFiniteMagnitude {
                    revealedWidth = ceil(renderLocalLineFrame.width - minX)
                }
            } else {
                for j in 0 ..< revealCount {
                    let rect = characterRects[j]
                    if !rect.isEmpty {
                        revealedWidth = max(revealedWidth, rect.maxX)
                    }
                }
                revealedWidth = ceil(revealedWidth)
            }

            remainingCharacters -= characterRects.count
            let isFull = remainingCharacters >= 0

            result.append(RevealLineInfo(lineFrame: renderLocalLineFrame, lineHeight: lineHeight, revealedWidth: revealedWidth, isFull: isFull, isRTL: line.isRTL))
        }

        return result
    }

    private func updateRevealMask(animateNewSegments: Bool) {
        let textItem = self.item.textItem
        let lines = textItem.lines
        let boundsWidth = textItem.frame.size.width
        let layerSize = self.renderContainer.bounds.size

        let effectiveCharacterDrawCount: Int
        if let maxCharacterDrawCount = self.maxCharacterDrawCount {
            effectiveCharacterDrawCount = maxCharacterDrawCount
        } else {
            if self.previousMaxCharacterDrawCount > 0 || !self.animatingSnippetLayers.isEmpty {
                var totalCharCount = 0
                for line in lines {
                    if let characterRects = line.characterRects {
                        totalCharCount += characterRects.count
                    } else {
                        totalCharCount += line.range.length
                    }
                }
                effectiveCharacterDrawCount = totalCharCount
            } else {
                if let _ = self.revealMaskLayer {
                    self.renderContainer.layer.mask = nil
                    self.revealMaskLayer = nil
                    self.revealLineMaskLayers.removeAll()
                }
                self.previousMaxCharacterDrawCount = 0
                return
            }
        }

        let revealMaskLayer: SimpleLayer
        if let existing = self.revealMaskLayer {
            revealMaskLayer = existing
        } else {
            revealMaskLayer = SimpleLayer()
            revealMaskLayer.backgroundColor = UIColor.clear.cgColor
            self.revealMaskLayer = revealMaskLayer
            self.renderContainer.layer.mask = revealMaskLayer
        }
        revealMaskLayer.frame = CGRect(origin: .zero, size: layerSize)

        let currentLineInfos = self.computeRevealedLines(characterLimit: effectiveCharacterDrawCount)

        // Snippet spawn pass — animate newly-revealed characters.
        if self.previousMaxCharacterDrawCount < effectiveCharacterDrawCount,
           let contents = self.renderView.layer.contents,
           animateNewSegments {
            let containerOrigin = self.renderContainer.frame.origin
            var previousRemaining = self.previousMaxCharacterDrawCount
            var currentRemaining = effectiveCharacterDrawCount
            var globalCharIndex = 0

            for i in 0 ..< lines.count {
                let line = lines[i]
                let lineInfo = currentLineInfos[i]
                guard let characterRects = line.characterRects else { continue }

                let lineCharCount = characterRects.count
                let prevCount = min(max(0, previousRemaining), lineCharCount)
                let curCount = min(max(0, currentRemaining), lineCharCount)

                previousRemaining -= lineCharCount
                currentRemaining -= lineCharCount

                if curCount <= prevCount {
                    globalCharIndex += lineCharCount
                    continue
                }

                for j in prevCount ..< curCount {
                    let charRect = characterRects[j]
                    if charRect.isEmpty { continue }

                    let snippetRect = CGRect(
                        x: lineInfo.lineFrame.minX + charRect.origin.x,
                        y: lineInfo.lineFrame.minY,
                        width: charRect.width,
                        height: lineInfo.lineHeight
                    )

                    if snippetRect.width < 0.5 { continue }

                    let contentsRect = CGRect(
                        x: snippetRect.minX / layerSize.width,
                        y: snippetRect.minY / layerSize.height,
                        width: snippetRect.width / layerSize.width,
                        height: snippetRect.height / layerSize.height
                    )

                    let snippetLayer = SnippetLayer(characterIndex: globalCharIndex + j)
                    snippetLayer.contents = contents
                    snippetLayer.contentsRect = contentsRect
                    snippetLayer.contentsScale = self.renderView.layer.contentsScale
                    snippetLayer.contentsGravity = self.renderView.layer.contentsGravity
                    snippetLayer.frame = snippetRect.offsetBy(dx: containerOrigin.x, dy: containerOrigin.y)

                    self.layer.addSublayer(snippetLayer)
                    self.animatingSnippetLayers.append(snippetLayer)

                    ComponentTransition(animation: .curve(duration: 0.22, curve: .easeInOut)).animateBlur(layer: snippetLayer, fromRadius: 2.0, toRadius: 0.0)
                    snippetLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    snippetLayer.animatePosition(from: CGPoint(x: 0.0, y: 6.0), to: .zero, duration: 0.2, additive: true)
                    snippetLayer.animateScale(from: 0.5, to: 1.0, duration: 0.2, completion: { [weak self, weak snippetLayer] _ in
                        guard let self, let snippetLayer else { return }
                        snippetLayer.removeFromSuperlayer()
                        self.animatingSnippetLayers.removeAll(where: { $0 === snippetLayer })
                        self.updateRevealMask(animateNewSegments: false)
                    })
                }
                globalCharIndex += lineCharCount
            }
        }

        // Mask rebuild — when snippets are in flight, clamp to the lowest animating one
        // (so the mask never exposes a char a snippet is still flying for). With no animations
        // in flight, snap directly to the current target — `previousMaxCharacterDrawCount`
        // would lag by one call (it's updated at the end of this function) and is 0 on a fresh
        // view, which would hide every char until the next tick.
        let maskCharacterLimit: Int
        if let lowestAnimating = self.animatingSnippetLayers.min(by: { $0.characterIndex < $1.characterIndex })?.characterIndex {
            maskCharacterLimit = lowestAnimating
        } else {
            maskCharacterLimit = effectiveCharacterDrawCount
        }
        // Build mask rects from each revealed glyph's ink bbox, unioned per line.
        // Per-character rects are stored in line-local CT coords (y positive-up,
        // baseline-relative; rect.minY is negative for descenders); convert to
        // renderContainer-local UIKit coords as:
        //   x = renderLocalLineFrame.minX + rect.minX
        //   y = renderLocalLineFrame.minY + lineAscent - rect.maxY
        // where `lineAscent = lineFrame.size.height` (top of line frame → baseline).
        //
        // Per-glyph rect captures descenders, italic overhang, accents exactly. Per
        // line we accumulate the union of revealed glyphs into one mask rect (one
        // CALayer sublayer per line), and consecutive fully-revealed lines collapse
        // further into a single rect — so a fully-revealed prefix is always one
        // sublayer regardless of line count.
        //
        // Lines without per-character data (computeRevealCharacterRects == false on
        // a non-streaming layout) fall back to a line-spanning rect, treated as a
        // full line for merging.
        var maskRects: [CGRect] = []
        var pendingFullPrefix: CGRect? = nil
        var remainingChars = maskCharacterLimit

        for line in lines {
            if remainingChars <= 0 {
                break
            }

            let lineFrame = v2FrameForLine(line, boundingWidth: boundsWidth, alignment: textItem.alignment)
            let renderLocalLineFrame = lineFrame.offsetBy(dx: v2TextViewClippingInset, dy: v2TextViewClippingInset)
            let lineAscent = lineFrame.size.height

            let lineUnion: CGRect?
            let isFullLine: Bool
            if let characterRects = line.characterRects {
                let revealCount = min(characterRects.count, remainingChars)
                isFullLine = revealCount >= characterRects.count
                var union: CGRect? = nil
                for j in 0 ..< revealCount {
                    let rect = characterRects[j]
                    if rect.isEmpty {
                        continue
                    }
                    let glyphRect = CGRect(
                        x: renderLocalLineFrame.minX + rect.minX,
                        y: renderLocalLineFrame.minY + lineAscent - rect.maxY,
                        width: rect.width,
                        height: rect.height
                    )
                    union = union?.union(glyphRect) ?? glyphRect
                }
                lineUnion = union
                remainingChars -= characterRects.count
            } else {
                // No per-character data — expose the whole line.
                lineUnion = line.range.length > 0 ? renderLocalLineFrame : nil
                isFullLine = remainingChars >= line.range.length
                remainingChars -= line.range.length
            }

            guard let lineUnion else {
                continue
            }

            if isFullLine {
                pendingFullPrefix = pendingFullPrefix?.union(lineUnion) ?? lineUnion
            } else {
                if let pending = pendingFullPrefix {
                    maskRects.append(pending)
                    pendingFullPrefix = nil
                }
                maskRects.append(lineUnion)
            }
        }
        if let pending = pendingFullPrefix {
            maskRects.append(pending)
        }

        while self.revealLineMaskLayers.count < maskRects.count {
            let childLayer = SimpleLayer()
            childLayer.backgroundColor = UIColor.white.cgColor
            revealMaskLayer.addSublayer(childLayer)
            self.revealLineMaskLayers.append(childLayer)
        }
        while self.revealLineMaskLayers.count > maskRects.count {
            let removed = self.revealLineMaskLayers.removeLast()
            removed.removeFromSuperlayer()
        }
        for i in 0 ..< maskRects.count {
            self.revealLineMaskLayers[i].frame = maskRects[i]
        }

        self.previousMaxCharacterDrawCount = effectiveCharacterDrawCount

        if self.maxCharacterDrawCount == nil && self.animatingSnippetLayers.isEmpty {
            self.renderContainer.layer.mask = nil
            self.revealMaskLayer = nil
            self.revealLineMaskLayers.removeAll()
        }
    }
}

private final class TextRenderView: UIView {
    var item: InstantPageV2TextItem
    var displayContentsUnderSpoilers: Bool = false

    init(item: InstantPageV2TextItem) {
        self.item = item
        super.init(frame: .zero)
        self.backgroundColor = .clear
        self.isOpaque = false
        self.contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
        context.translateBy(x: v2TextViewClippingInset, y: v2TextViewClippingInset)

        if !self.displayContentsUnderSpoilers {
            let textItemForClip = self.item.textItem
            let clipBoundsWidth = textItemForClip.frame.size.width
            var spoilerRects: [CGRect] = []
            for line in textItemForClip.lines {
                if line.spoilerItems.isEmpty { continue }
                let lineFrame = v2FrameForLine(line, boundingWidth: clipBoundsWidth, alignment: textItemForClip.alignment)
                for spoiler in line.spoilerItems {
                    spoilerRects.append(spoiler.frame.offsetBy(dx: lineFrame.minX - line.frame.minX, dy: 0.0))
                }
            }
            if !spoilerRects.isEmpty {
                // Even-odd subtracts each spoiler rect from the full-bounds rect. Spoiler rects never
                // overlap (same-line ranges are horizontally monotonic; cross-line rects differ in y),
                // so no hole is accidentally re-included by an odd crossing count.
                let path = CGMutablePath()
                path.addRect(CGRect(origin: .zero, size: textItemForClip.frame.size).insetBy(dx: -v2TextViewClippingInset, dy: -v2TextViewClippingInset))
                for rect in spoilerRects {
                    path.addRect(rect)
                }
                context.addPath(path)
                context.clip(using: .evenOdd)
            }
        }

        let textItem = self.item.textItem
        let boundsWidth = textItem.frame.size.width
        let intersectRect = rect.offsetBy(dx: -v2TextViewClippingInset, dy: -v2TextViewClippingInset)

        for line in textItem.lines {
            let lineFrame = v2FrameForLine(line, boundingWidth: boundsWidth, alignment: textItem.alignment)
            if !intersectRect.intersects(lineFrame) {
                continue
            }

            let lineOrigin = lineFrame.origin
            context.textPosition = CGPoint(x: lineOrigin.x, y: lineOrigin.y + lineFrame.size.height)

            if !line.markedItems.isEmpty {
                context.saveGState()
                for item in line.markedItems {
                    let itemFrame = item.frame.offsetBy(dx: lineFrame.minX, dy: 0.0)
                    context.setFillColor(item.color.cgColor)

                    let height = floor(item.frame.size.height * 2.2)
                    let markRect = CGRect(x: itemFrame.minX - 2.0, y: floor(itemFrame.minY + (itemFrame.height - height) / 2.0), width: itemFrame.width + 4.0, height: height)
                    let path = UIBezierPath(roundedRect: markRect, cornerRadius: 3.0)
                    context.addPath(path.cgPath)
                    context.fillPath()
                }
                context.restoreGState()
            }

            if textItem.opaqueBackground {
                context.setBlendMode(.normal)
            }

            let glyphRuns = CTLineGetGlyphRuns(line.line) as NSArray
            if glyphRuns.count != 0 {
                for run in glyphRuns {
                    let run = run as! CTRun
                    let glyphCount = CTRunGetGlyphCount(run)
                    CTRunDraw(run, context, CFRangeMake(0, glyphCount))
                }
            }

            // The collapsed-quote "…", drawn after the line's own glyphs on the same baseline. Its
            // width is deliberately outside `lineFrame`, exactly as in `InteractiveTextComponent`.
            if let additionalTrailingLine = line.additionalTrailingLine {
                context.textPosition = CGPoint(x: lineOrigin.x + lineFrame.size.width, y: lineOrigin.y + lineFrame.size.height)
                CTLineDraw(additionalTrailingLine, context)
            }

            if textItem.opaqueBackground {
                context.setBlendMode(.copy)
            }

            if !line.strikethroughItems.isEmpty {
                for item in line.strikethroughItems {
                    let itemFrame = item.frame.offsetBy(dx: lineFrame.minX, dy: 0.0)
                    context.fill(CGRect(x: itemFrame.minX, y: itemFrame.minY + floor((itemFrame.size.height / 2.0) + 1.0), width: itemFrame.size.width, height: 1.0))
                }
            }

            if !line.underlineItems.isEmpty {
                for item in line.underlineItems {
                    var color: UIColor? = item.color
                    if color == nil {
                        textItem.attributedString.enumerateAttributes(in: item.range, options: []) { attributes, _, _ in
                            if let foreground = attributes[NSAttributedString.Key.foregroundColor] as? UIColor {
                                color = foreground
                            }
                        }
                    }
                    if let color {
                        context.setFillColor(color.cgColor)
                    }
                    let itemFrame = item.frame.offsetBy(dx: lineFrame.minX, dy: 0.0)
                    context.fill(CGRect(x: itemFrame.minX, y: itemFrame.minY + itemFrame.size.height + 2.0, width: itemFrame.size.width, height: 1.0))
                }
            }
        }

        context.restoreGState()
    }
}

/// Private snippet layer for the streaming reveal pop-in animation.
/// Each instance represents one character cropped from the renderView's backing texture,
/// animating in (blur + alpha + position + scale) before the mask absorbs its rect.
private final class SnippetLayer: SimpleLayer {
    let characterIndex: Int

    init(characterIndex: Int) {
        self.characterIndex = characterIndex
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(layer: Any) {
        if let other = layer as? SnippetLayer {
            self.characterIndex = other.characterIndex
        } else {
            self.characterIndex = 0
        }
        super.init(layer: layer)
    }
}

// MARK: - Divider view

final class InstantPageV2DividerView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2DividerItem
    var itemFrame: CGRect { return self.item.frame }

    init(item: InstantPageV2DividerItem, theme: InstantPageTheme) {
        self.item = item
        super.init(frame: item.frame)
        self.update(item: item, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2DividerItem, theme: InstantPageTheme) {
        let _ = theme
        self.item = item
        self.backgroundColor = item.color
    }
}

// MARK: - Anchor view (zero-height; nothing to render)

final class InstantPageV2AnchorView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2AnchorItem
    var itemFrame: CGRect { return self.item.frame }

    init(item: InstantPageV2AnchorItem, theme: InstantPageTheme) {
        self.item = item
        super.init(frame: item.frame)
        self.isHidden = true   // structural: zero-height, never renders
        self.update(item: item, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2AnchorItem, theme: InstantPageTheme) {
        let _ = theme
        self.item = item
    }
}

// MARK: - List marker view

final class InstantPageV2ListMarkerView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2ListMarkerItem
    var itemFrame: CGRect { return self.item.frame }

    /// Fired on tap of an interactive checkbox: (path, newValue).
    var onCheckboxTapped: ((_ path: [Int], _ newValue: Bool) -> Void)?

    private var checkNode: CheckNode?
    private var tapRecognizer: UITapGestureRecognizer?
    private var interactive: Bool = false

    init(item: InstantPageV2ListMarkerItem, theme: InstantPageTheme) {
        self.item = item
        super.init(frame: item.frame)
        self.backgroundColor = .clear   // structural
        self.isOpaque = false           // structural
        self.update(item: item, theme: theme, interactive: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2ListMarkerItem, theme: InstantPageTheme, interactive: Bool) {
        let _ = theme
        self.item = item
        self.interactive = interactive
        self.rebuildContents()
        self.updateInteractivity()
    }

    /// Whether this marker is an interactive checkbox (has a path and interactivity is enabled).
    private var isInteractiveCheckbox: Bool {
        if case .checklist = self.item.kind, self.interactive, self.item.checkboxPath != nil {
            return true
        }
        return false
    }

    private func updateInteractivity() {
        let shouldBeInteractive = self.isInteractiveCheckbox
        self.isUserInteractionEnabled = shouldBeInteractive
        if shouldBeInteractive {
            if self.tapRecognizer == nil {
                let recognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap))
                self.addGestureRecognizer(recognizer)
                self.tapRecognizer = recognizer
            }
        } else if let recognizer = self.tapRecognizer {
            self.removeGestureRecognizer(recognizer)
            self.tapRecognizer = nil
        }
    }

    @objc private func handleTap() {
        guard case let .checklist(checked, _) = self.item.kind, let path = self.item.checkboxPath else {
            return
        }
        let newValue = !checked
        // Optimistic visual flip; the model re-render supersedes (or reverts) this.
        self.checkNode?.setSelected(newValue, animated: true)
        self.onCheckboxTapped?(path, newValue)
    }

    private func rebuildContents() {
        for subview in Array(self.subviews) {
            subview.removeFromSuperview()
        }
        if let sublayers = self.layer.sublayers {
            for sublayer in Array(sublayers) {
                sublayer.removeFromSuperlayer()
            }
        }
        self.checkNode = nil

        let item = self.item
        switch item.kind {
        case .bullet:
            let radius: CGFloat = min(item.frame.width, item.frame.height) / 2.0
            let dot = CALayer()
            dot.backgroundColor = item.color.cgColor
            dot.frame = CGRect(
                x: (item.frame.width - radius * 2.0) / 2.0,
                y: (item.frame.height - radius * 2.0) / 2.0,
                width: radius * 2.0,
                height: radius * 2.0
            )
            dot.cornerRadius = radius
            self.layer.addSublayer(dot)
        case let .number(string, alignment):
            // The string carries the font and colour it was MEASURED with during layout; do not
            // rebuild them here. This used to set `systemFont(ofSize: 17.0)` and `item.color`
            // explicitly, which silently disagreed with the theme's paragraph font whenever that
            // was not system 17 — and since the marker column's width comes from the measured
            // string, the drawn digits then no longer filled the box that was supposed to align them.
            let label = UILabel()
            label.attributedText = string
            // The frame is the WHOLE marker column, so this alignment is what lines the dots up.
            label.textAlignment = alignment
            label.frame = CGRect(origin: .zero, size: item.frame.size)
            self.addSubview(label)
        case let .checklist(checked, colors):
            let checkNodeTheme = CheckNodeTheme(
                backgroundColor: colors.background,
                strokeColor: colors.stroke,
                borderColor: colors.border,
                overlayBorder: false,
                hasInset: false,
                hasShadow: false
            )
            let checkNode = CheckNode(theme: checkNodeTheme, content: .check(isRectangle: true))
            checkNode.displaysAsynchronously = false
            checkNode.isUserInteractionEnabled = false
            checkNode.frame = CGRect(origin: .zero, size: item.frame.size)
            checkNode.setSelected(checked, animated: false)
            self.addSubview(checkNode.view)
            self.checkNode = checkNode
        }
    }
}

// MARK: - Quote bar view

final class InstantPageV2BlockQuoteBarView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2BarItem
    var itemFrame: CGRect { return self.item.frame }

    init(item: InstantPageV2BarItem, theme: InstantPageTheme) {
        self.item = item
        super.init(frame: item.frame)
        self.update(item: item, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2BarItem, theme: InstantPageTheme) {
        let _ = theme
        self.item = item
        self.backgroundColor = item.color
        self.layer.cornerRadius = item.cornerRadius
    }
}

// MARK: - Quote frame view (accent bar + accent-tinted rounded fill, for block quotes & code)

/// The expand chevron a collapsible quote carries, in the SAME asset the chat's own collapsible
/// blockquote uses (`InteractiveTextComponent`'s `expandArrowIcon`) — so the two surfaces cannot
/// drift into two different arrows. Baked white once and recoloured per quote through
/// `layerTintColor`, which multiplies the contents rather than re-rendering the image per theme.
private let instantPageV2QuoteExpandArrowIcon: UIImage? = {
    return generateTintedImage(image: UIImage(bundleImageName: "Item List/ExpandingItemVerticalRegularArrow"), color: .white)
}()

final class InstantPageV2QuoteFrameView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2QuoteFrameItem
    var itemFrame: CGRect { return self.item.frame }
    private let imageView: UIImageView
    private var chevronLayer: SimpleLayer?
    /// The fill's parameters as last rendered. `instantPageV2QuoteFillImage` is a full CoreGraphics
    /// render, and `update` runs on every layout of every quote in the chat list, so it is only
    /// re-rendered when one of its four inputs actually moves — never for a size change, which the
    /// resizable image handles by stretching.
    private var appliedFill: (accent: UIColor, barWidth: CGFloat, cornerRadius: CGFloat, fillAlpha: CGFloat)?

    // Expanded == the collapsed arrow turned over. Held as a constant so the two update paths cannot
    // disagree about which way "up" is.
    private static let expandedChevronTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)

    init(item: InstantPageV2QuoteFrameItem, theme: InstantPageTheme) {
        self.item = item
        self.imageView = UIImageView()
        super.init(frame: item.frame)
        // Stays false even for a collapsible quote: the tap is resolved by the host's
        // `tapActionAtPoint`, AFTER its URL and entity hits, so a link inside the visible lines still
        // wins. An interactive view here would take the touch first and break that.
        self.isUserInteractionEnabled = false
        self.addSubview(self.imageView)
        self.update(item: item, theme: theme, animation: .None)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2QuoteFrameItem, theme: InstantPageTheme, animation: ListViewItemUpdateAnimation) {
        let _ = theme
        self.item = item
        let fill = (accent: item.accentColor, barWidth: item.barWidth, cornerRadius: item.cornerRadius, fillAlpha: item.fillAlpha)
        if self.appliedFill == nil || self.appliedFill! != fill {
            self.appliedFill = fill
            self.imageView.image = instantPageV2QuoteFillImage(accent: fill.accent, barWidth: fill.barWidth, cornerRadius: fill.cornerRadius, fillAlpha: fill.fillAlpha)
        }
        // RTL: mirror horizontally so the leading bar sits on the trailing (right) edge; the fill is
        // otherwise symmetric, so the mirror only moves the bar + swaps which corners the arc rounds.
        self.imageView.transform = item.barOnTrailing ? CGAffineTransform(scaleX: -1.0, y: 1.0) : .identity
        // Animated, because the CALLER animates our own frame: a collapsing quote's frame shrinks
        // over the transition, and assigning the fill's frame directly would snap the chrome to the
        // new size on the first frame while everything around it slid. Position + bounds rather than
        // frame, since the RTL mirror puts a transform on this layer. The fill is a resizable image,
        // so the stretch follows the bounds animation for free.
        let fillFrame = CGRect(origin: .zero, size: item.frame.size)
        animation.animator.updatePosition(layer: self.imageView.layer, position: fillFrame.center, completion: nil)
        animation.animator.updateBounds(layer: self.imageView.layer, bounds: CGRect(origin: .zero, size: fillFrame.size), completion: nil)

        switch item.collapseState {
        case .notCollapsible:
            if let chevronLayer = self.chevronLayer {
                self.chevronLayer = nil
                chevronLayer.removeFromSuperlayer()
            }
        case .collapsed, .expanded:
            guard let icon = instantPageV2QuoteExpandArrowIcon else {
                return
            }
            var isNew = false
            let chevronLayer: SimpleLayer
            if let current = self.chevronLayer {
                chevronLayer = current
            } else {
                isNew = true
                chevronLayer = SimpleLayer()
                chevronLayer.contents = icon.cgImage
                chevronLayer.contentsScale = icon.scale
                self.chevronLayer = chevronLayer
                self.layer.addSublayer(chevronLayer)
            }
            chevronLayer.layerTintColor = item.accentColor.cgColor

            // Same offsets as the reference: 6pt in from the trailing edge, 3pt up from the bottom.
            // Under RTL the bar takes the trailing edge, so the chevron moves to the leading side.
            let x = item.barOnTrailing ? 6.0 : item.frame.width - 6.0 - icon.size.width
            let chevronFrame = CGRect(origin: CGPoint(x: x, y: item.frame.height - 3.0 - icon.size.height), size: icon.size)
            let transform = item.collapseState == .expanded ? InstantPageV2QuoteFrameView.expandedChevronTransform : CATransform3DIdentity
            // Position + bounds, never `frame`: the layer carries a rotation, and `frame` is derived
            // from the transformed bounds, so writing it would fight the rotation on every update.
            if isNew {
                chevronLayer.bounds = CGRect(origin: .zero, size: chevronFrame.size)
                chevronLayer.position = chevronFrame.center
                chevronLayer.transform = transform
            } else {
                animation.animator.updatePosition(layer: chevronLayer, position: chevronFrame.center, completion: nil)
                animation.animator.updateBounds(layer: chevronLayer, bounds: CGRect(origin: .zero, size: chevronFrame.size), completion: nil)
                animation.animator.updateTransform(layer: chevronLayer, transform: transform, completion: nil)
            }
        }
    }
}

// MARK: - Shape view (for pullQuote line ornaments)

final class InstantPageV2ShapeView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2ShapeItem
    var itemFrame: CGRect { return self.item.frame }

    init(item: InstantPageV2ShapeItem, theme: InstantPageTheme) {
        self.item = item
        super.init(frame: item.frame)
        self.update(item: item, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2ShapeItem, theme: InstantPageTheme) {
        let _ = theme
        self.item = item
        self.applyKind()
    }

    private func applyKind() {
        switch self.item.kind {
        case let .roundedRect(cornerRadius):
            self.backgroundColor = self.item.color
            self.layer.cornerRadius = cornerRadius
        case .line(_):
            self.backgroundColor = self.item.color
            self.layer.cornerRadius = 0.0
        }
    }
}

// MARK: - Image ornament view (for pullQuote corner marks)

final class InstantPageV2ImageOrnamentView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2ImageOrnamentItem
    var itemFrame: CGRect { return self.item.frame }
    private let imageView: UIImageView

    init(item: InstantPageV2ImageOrnamentItem) {
        self.item = item
        let iv = UIImageView(image: UIImage(bundleImageName: item.imageName)?.withRenderingMode(.alwaysTemplate))
        iv.tintColor = item.color
        iv.frame = CGRect(origin: .zero, size: item.frame.size)
        iv.contentMode = .scaleAspectFit
        if item.rotated { iv.transform = CGAffineTransform(rotationAngle: .pi) }
        self.imageView = iv
        super.init(frame: item.frame)
        addSubview(iv)
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2ImageOrnamentItem, theme: InstantPageTheme) {
        let _ = theme
        let previous = self.item
        self.item = item
        if previous.imageName != item.imageName {
            self.imageView.image = UIImage(bundleImageName: item.imageName)?.withRenderingMode(.alwaysTemplate)
        }
        self.imageView.tintColor = item.color
        // Reset transform before writing frame (frame under a live transform is undefined), then re-apply.
        self.imageView.transform = .identity
        self.imageView.frame = CGRect(origin: .zero, size: item.frame.size)
        self.imageView.transform = item.rotated ? CGAffineTransform(rotationAngle: .pi) : .identity
    }
}

// MARK: - Media placeholder view (V0: gray rectangle)

final class InstantPageV2MediaPlaceholderView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2MediaPlaceholderItem
    var itemFrame: CGRect { return self.item.frame }

    init(item: InstantPageV2MediaPlaceholderItem, theme: InstantPageTheme) {
        self.item = item
        super.init(frame: item.frame)
        self.update(item: item, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2MediaPlaceholderItem, theme: InstantPageTheme) {
        self.item = item
        self.backgroundColor = theme.imageTintColor?.withAlphaComponent(0.2) ?? UIColor(white: 0.85, alpha: 1.0)
        self.layer.cornerRadius = item.cornerRadius
        self.clipsToBounds = item.cornerRadius > 0.0
    }
}

// MARK: - Details view

final class InstantPageV2DetailsView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2DetailsItem
    var itemFrame: CGRect { return self.item.frame }

    let titleTextView: InstantPageV2TextView
    private let chevronView: UIImageView
    var bodyView: InstantPageV2View?
    private let titleHitView: UIView

    // The expanded chevron is the collapsed one rotated 180° (down → up).
    private static let expandedChevronTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
    // On an animated collapse the body is kept until the toggle animation finishes (so the
    // shrinking clip can hide it), then removed in finalizePendingCollapse() — which the parent
    // (InstantPageV2View.update) calls from the completion of the frame-shrink (clip) animation.
    private var bodyPendingRemoval = false

    var onTitleTapped: ((Int) -> Void)?

    var subLayoutView: InstantPageV2View? { return self.bodyView }

    func forEachSubLayoutView(_ body: (InstantPageV2View) -> Void) {
        if let bodyView = self.bodyView { body(bodyView) }
    }

    init(item: InstantPageV2DetailsItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext?) {
        self.item = item

        let titleV2Item = InstantPageV2TextItem(
            frame: item.titleTextItem.frame,
            textItem: item.titleTextItem
        )
        self.titleTextView = InstantPageV2TextView(item: titleV2Item, theme: theme)
        self.titleTextView.isUserInteractionEnabled = false

        self.chevronView = UIImageView()
        self.chevronView.image = UIImage(bundleImageName: "Item List/ExpandingItemVerticalRegularArrow")?.withRenderingMode(.alwaysTemplate)
        self.chevronView.contentMode = .scaleAspectFit
        // Decorative: let taps fall through to titleHitView (which carries the toggle gesture).
        self.chevronView.isUserInteractionEnabled = false

        self.titleHitView = UIView()
        self.titleHitView.backgroundColor = .clear

        super.init(frame: item.frame)
        self.backgroundColor = .clear   // structural
        self.clipsToBounds = true       // structural — the parent's frame-height animation clips the body

        self.addSubview(self.titleTextView)
        self.addSubview(self.chevronView)

        let tap = UITapGestureRecognizer(target: self, action: #selector(self.titleTapped))
        self.insertSubview(self.titleHitView, at: 0)
        self.titleHitView.addGestureRecognizer(tap)

        // All content (title, chevron tint/position, separator, titleHit frame, body) flows through
        // update — its expanded branch lazily creates the body, so init no longer builds it itself.
        self.update(item: item, theme: theme, renderContext: renderContext, animation: .None)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func titleTapped() {
        self.onTitleTapped?(self.item.index)
    }

    func update(item: InstantPageV2DetailsItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext?, animation: ListViewItemUpdateAnimation) {
        self.item = item

        let titleV2Item = InstantPageV2TextItem(
            frame: item.titleTextItem.frame,
            textItem: item.titleTextItem
        )
        self.titleTextView.update(item: titleV2Item, theme: theme)

        self.chevronView.tintColor = theme.textCategories.paragraph.color
        let chevronSize = CGSize(width: 18.0, height: 18.0)
        self.chevronView.bounds = CGRect(origin: .zero, size: chevronSize)
        self.chevronView.center = CGPoint(
            x: item.rtl ? (item.frame.width - item.sideInset - chevronSize.width / 2.0) : (item.sideInset + chevronSize.width / 2.0),
            y: item.titleFrame.midY
        )

        self.titleHitView.frame = item.titleFrame

        // Body lifecycle. The reveal/hide of the body is produced by the parent animating this
        // view's own frame height (clipsToBounds = true), not by the body itself — see
        // InstantPageV2View.update. The body's internal layout is forwarded `animation` so a
        // *nested* details block inside the body can also animate its own toggle.
        if item.isExpanded {
            if let innerLayout = item.innerLayout {
                let body: InstantPageV2View
                if let existingBody = self.bodyView {
                    // Reuse: covers expanded→expanded content updates and a re-expand that
                    // interrupts a still-pending collapse removal.
                    body = existingBody
                    self.bodyPendingRemoval = false
                } else {
                    body = InstantPageV2View(renderContext: renderContext)
                    self.addSubview(body)
                    self.bodyView = body
                }
                // Forward taps on details NESTED inside this body up to the same toggle handler this
                // view uses: makeItemView wired our onTitleTapped to the owning InstantPageV2View's
                // detailsTapped, so chaining through onTitleTapped reaches the bubble's toggle handler.
                // Without this, a nested details' tap hits the body view's nil detailsTapped and is dropped.
                body.detailsTapped = { [weak self] index in
                    self?.onTitleTapped?(index)
                }
                body.update(layout: innerLayout, theme: theme, animation: animation)
                body.frame = CGRect(
                    origin: CGPoint(x: 0.0, y: item.titleFrame.maxY),
                    size: innerLayout.contentSize
                )
            }
        } else {
            if let existingBody = self.bodyView {
                if animation.isAnimated {
                    // Keep the body visible while the parent's frame-shrink clips it away;
                    // it is removed in finalizePendingCollapse() (called from that clip animation's
                    // completion in InstantPageV2View.update).
                    self.bodyPendingRemoval = true
                } else {
                    existingBody.removeFromSuperview()
                    self.bodyView = nil
                }
            }
        }

        // Chevron rotation. The body teardown on collapse is NOT tied to this completion — see
        // finalizePendingCollapse(), which the parent calls from the frame-shrink (clip) animation.
        let targetTransform = item.isExpanded ? InstantPageV2DetailsView.expandedChevronTransform : CATransform3DIdentity
        animation.animator.updateTransform(layer: self.chevronView.layer, transform: targetTransform, completion: nil)
    }

    /// Removes the body kept alive across an animated collapse. The parent (InstantPageV2View.update)
    /// calls this from the completion of the frame-shrink animation that clips the body away, so the
    /// body is torn down exactly when it finishes being hidden. The guard makes a re-expand that
    /// interrupts the collapse safe — the re-expand clears `bodyPendingRemoval` first.
    func finalizePendingCollapse() {
        if !self.item.isExpanded, self.bodyPendingRemoval {
            self.bodyView?.removeFromSuperview()
            self.bodyView = nil
            self.bodyPendingRemoval = false
        }
    }
}

// MARK: - Code block view

final class InstantPageV2CodeBlockView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2CodeBlockItem
    var itemFrame: CGRect { return self.item.frame }

    private var languageView: InstantPageV2TextView?
    let textView: InstantPageV2TextView

    init(item: InstantPageV2CodeBlockItem, theme: InstantPageTheme) {
        self.item = item

        // item.textItem.frame is already in block-local coordinates.
        let innerV2TextItem = InstantPageV2TextItem(
            frame: item.textItem.frame,
            textItem: item.textItem
        )
        self.textView = InstantPageV2TextView(item: innerV2TextItem, theme: theme)

        super.init(frame: item.frame)
        self.addSubview(self.textView)
        self.update(item: item, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2CodeBlockItem, theme: InstantPageTheme) {
        self.item = item

        // A plain band. No fill image, no bar, no corner radius: a code block reads as a highlighted
        // table row. Corners at a bubble edge are clipped by the rounded container the page sits in,
        // exactly as they are for full-width media.
        self.backgroundColor = item.backgroundColor

        if let languageItem = item.languageItem {
            let inner = InstantPageV2TextItem(frame: languageItem.frame, textItem: languageItem)
            if let existing = self.languageView {
                existing.update(item: inner, theme: theme)
                existing.frame = self.textViewFrame(for: languageItem)
            } else {
                let view = InstantPageV2TextView(item: inner, theme: theme)
                view.frame = self.textViewFrame(for: languageItem)
                self.addSubview(view)
                self.languageView = view
            }
        } else if let existing = self.languageView {
            existing.removeFromSuperview()
            self.languageView = nil
        }

        let innerV2TextItem = InstantPageV2TextItem(
            frame: item.textItem.frame,
            textItem: item.textItem
        )
        self.textView.update(item: innerV2TextItem, theme: theme)
        self.textView.frame = self.textViewFrame(for: item.textItem)
    }

    /// `InstantPageV2TextView` sizes itself from its item's frame ONLY in `init` (and lays its inner
    /// containers out from the item on every update) — so the PARENT owns its frame across updates.
    /// This block's two children can both move when a language line appears or disappears, so both
    /// are re-framed here rather than relying on their construction-time size.
    private func textViewFrame(for textItem: InstantPageTextItem) -> CGRect {
        return textItem.frame.insetBy(dx: -v2TextViewClippingInset, dy: -v2TextViewClippingInset)
    }
}

// MARK: - Thinking view (dimmed shimmering reasoning block)

/// A top-level thinking block: dimmed text drawn fully, masked by a continuously-running
/// `ShimmeringMaskView`. Reveal is whole-block alpha (driven from the cost map), NOT char-by-char,
/// and the block contributes zero reveal cost. Structure mirrors `InstantPageV2CodeBlockView`
/// (container hosting an inner `InstantPageV2TextView`).
final class InstantPageV2ThinkingView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2ThinkingItem
    var itemFrame: CGRect { return self.item.frame }

    private let shimmerView: ShimmeringMaskView
    let textView: InstantPageV2TextView   // exposed so the parent V2 view can host its inline emoji

    init(item: InstantPageV2ThinkingItem, theme: InstantPageTheme) {
        self.item = item
        self.shimmerView = ShimmeringMaskView(peakAlpha: 0.3, duration: 1.0)
        let innerV2TextItem = InstantPageV2TextItem(frame: item.textItem.frame, textItem: item.textItem)
        self.textView = InstantPageV2TextView(item: innerV2TextItem, theme: theme)

        super.init(frame: item.frame)
        self.backgroundColor = .clear                              // structural
        self.addSubview(self.shimmerView)                          // structural
        self.shimmerView.contentView.addSubview(self.textView)     // structural
        self.update(item: item, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Parent positions self at the item frame (the bare line box). The shimmer and its gradient
    /// mask are sized to the text view's clipping-inset-EXPANDED frame and shifted to
    /// `(-inset, -inset)`, so the mask doesn't crop the glyph overhang the inset reserves (tall
    /// ascenders, descenders, the last line's underline) — the symptom of sizing the mask to the
    /// bare line box. The inner text view fills the shimmer; its `+inset` render translate lands the
    /// glyphs back at self's origin, so the text position is unchanged. Mirrors how a `.text` view's
    /// frame is inset-expanded (`actualFrame` / `InstantPageV2TextView.init`).
    private func layoutContents() {
        let inset = v2TextViewClippingInset
        let expandedSize = CGSize(width: self.item.frame.size.width + inset * 2.0,
                                  height: self.item.frame.size.height + inset * 2.0)
        self.shimmerView.frame = CGRect(x: -inset, y: -inset, width: expandedSize.width, height: expandedSize.height)
        self.textView.frame = CGRect(origin: .zero, size: expandedSize)
        self.shimmerView.update(
            size: expandedSize,
            containerWidth: expandedSize.width,
            offsetX: 0.0,
            gradientWidth: 200.0,
            transition: .immediate
        )
    }

    func update(item: InstantPageV2ThinkingItem, theme: InstantPageTheme) {
        self.item = item
        let innerV2TextItem = InstantPageV2TextItem(frame: item.textItem.frame, textItem: item.textItem)
        self.textView.update(item: innerV2TextItem, theme: theme)
        self.layoutContents()
    }
}

// MARK: - Table view

/// The set of grid corners a cell occupies, so a filled corner cell's stripe can be rounded to
/// follow the table's rounded outer border. `cellFrame` is table-grid-local (pre-`gridOffsetY`).
private func tableStripeCornerMask(cellFrame: CGRect, gridWidth: CGFloat, gridHeight: CGFloat, effectiveBorderWidth: CGFloat) -> CACornerMask {
    let edge = effectiveBorderWidth / 2.0 + 0.5
    let firstCol = cellFrame.minX <= edge
    let firstRow = cellFrame.minY <= edge
    let lastCol = cellFrame.maxX >= gridWidth - edge
    let lastRow = cellFrame.maxY >= gridHeight - edge
    var mask: CACornerMask = []
    if firstRow && firstCol { mask.insert(.layerMinXMinYCorner) }
    if firstRow && lastCol { mask.insert(.layerMaxXMinYCorner) }
    if lastRow && firstCol { mask.insert(.layerMinXMaxYCorner) }
    if lastRow && lastCol { mask.insert(.layerMaxXMaxYCorner) }
    return mask
}

final class InstantPageV2TableView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2TableItem
    var itemFrame: CGRect { return self.item.frame }

    private let scrollView: UIScrollView
    let contentView: UIView
    var titleSubView: InstantPageV2View?
    var cellSubViews: [InstantPageV2View] = []
    private var stripeLayers: [CALayer] = []
    private var lineLayers: [CALayer] = []

    var subLayoutView: InstantPageV2View? { return nil }

    func forEachSubLayoutView(_ body: (InstantPageV2View) -> Void) {
        if let titleView = self.titleSubView { body(titleView) }
        for cellView in self.cellSubViews { body(cellView) }
    }

    init(item: InstantPageV2TableItem, theme: InstantPageTheme, renderContext: InstantPageV2RenderContext?) {
        self.item = item
        self.scrollView = UIScrollView()
        self.contentView = UIView()
        super.init(frame: item.frame)
        self.backgroundColor = .clear

        // Structural, one-time scroll-view configuration. Frames / contentSize / indicator
        // visibility all depend on the item and are (re)applied by update(item:theme:).
        // Scrollable tables clip to the full width with no inset on the clip; the inset lives inside
        // the scroll content width as a margin on BOTH sides (`contentInset * 2.0`, mirroring V1's
        // `InstantPageScrollableNode`), so a scrolled-to-the-end table keeps a symmetric trailing
        // inset instead of jamming its right border flush against the screen edge.
        self.scrollView.clipsToBounds = true
        self.scrollView.alwaysBounceHorizontal = false
        self.scrollView.alwaysBounceVertical = false
        self.scrollView.showsVerticalScrollIndicator = false
        self.addSubview(self.scrollView)
        self.scrollView.addSubview(self.contentView)

        // Build the (content-less) child structure sized to the construction-time item; update fills
        // every frame / colour / sub-layout below. Insertion order matches the original interleaved
        // build so the layer/subview z-order is unchanged (stripes at the bottom, then the title and
        // cell sub-views, then the inner grid lines). Cell-count changes on later reuse are not
        // reconciled here (pre-existing limitation) — update's index-guarded loops refresh in place.
        if item.titleSubLayout != nil {
            let v = InstantPageV2View(renderContext: renderContext)
            self.contentView.addSubview(v)
            self.titleSubView = v
        }
        for cell in item.cells {
            if cell.backgroundColor != nil {
                let stripe = CALayer()
                self.contentView.layer.insertSublayer(stripe, at: 0)
                self.stripeLayers.append(stripe)
            }
            if cell.subLayout != nil {
                let v = InstantPageV2View(renderContext: renderContext)
                self.contentView.addSubview(v)
                self.cellSubViews.append(v)
            }
        }
        if item.bordered {
            for _ in item.horizontalLines + item.verticalLines {
                let line = CALayer()
                self.contentView.layer.addSublayer(line)
                self.lineLayers.append(line)
            }
        }

        self.update(item: item, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2TableItem, theme: InstantPageTheme) {
        self.item = item

        self.scrollView.frame = CGRect(origin: .zero, size: item.frame.size)
        self.scrollView.contentSize = CGSize(width: item.contentSize.width + item.contentInset * 2.0, height: item.contentSize.height)
        self.scrollView.disablesInteractiveTransitionGestureRecognizer = self.scrollView.contentSize.width > item.frame.width
        self.scrollView.showsHorizontalScrollIndicator = item.contentSize.width + item.contentInset * 2.0 > item.frame.width
        self.contentView.frame = CGRect(x: item.contentInset, y: 0.0, width: item.contentSize.width, height: item.contentSize.height)

        // Forward updates to nested V2 sub-layouts (title + each cell). Recursive update
        // propagation. Cell-count or title-presence changes fall back to rebuild via the
        // V2View's internal `update(layout:theme:animation:)` (task B refines).
        if let titleLayout = item.titleSubLayout, let titleView = self.titleSubView, let titleFrame = item.titleFrame {
            titleView.update(layout: titleLayout, theme: theme, animation: .None)
            titleView.frame = CGRect(
                x: v2TableCellInsets.left,
                y: titleFrame.minY + v2TableCellInsets.top,
                width: titleLayout.contentSize.width,
                height: titleLayout.contentSize.height
            )
        }

        let gridOffsetY = item.titleFrame?.height ?? 0.0
        var cellLayoutIndex = 0
        for cell in item.cells {
            if let subLayout = cell.subLayout, cellLayoutIndex < self.cellSubViews.count {
                let cellView = self.cellSubViews[cellLayoutIndex]
                cellView.update(layout: subLayout, theme: theme, animation: .None)
                cellView.frame = cell.frame.offsetBy(dx: 0.0, dy: gridOffsetY)
                cellLayoutIndex += 1
            }
        }

        // Stripe layers (cell backgrounds) — update color + frame + corner rounding in original order.
        let effectiveBorderWidth = item.bordered ? v2TableBorderWidth : 0.0
        let gridHeight = item.contentSize.height - gridOffsetY
        var stripeIndex = 0
        for cell in item.cells {
            if let bg = cell.backgroundColor, stripeIndex < self.stripeLayers.count {
                let stripe = self.stripeLayers[stripeIndex]
                stripe.backgroundColor = bg.cgColor
                stripe.frame = cell.frame.offsetBy(dx: 0.0, dy: gridOffsetY)
                let cornerMask = tableStripeCornerMask(cellFrame: cell.frame, gridWidth: item.contentSize.width, gridHeight: gridHeight, effectiveBorderWidth: effectiveBorderWidth)
                if cornerMask.isEmpty {
                    stripe.cornerRadius = 0.0
                    stripe.maskedCorners = []
                } else {
                    stripe.cornerRadius = max(0.0, v2TableCornerRadius - effectiveBorderWidth)
                    stripe.maskedCorners = cornerMask
                }
                stripeIndex += 1
            }
        }

        // Inner line layers — refresh colour AND frame in place. (`lineLayers` holds only inner grid
        // lines; the outer border is the contentView layer's own rounded border, refreshed below.)
        // Frames are set here (not in init) so reuse with a different grid re-positions the lines.
        let lineRects = item.horizontalLines + item.verticalLines
        for (i, line) in self.lineLayers.enumerated() {
            line.backgroundColor = item.borderColor.cgColor
            if i < lineRects.count {
                line.frame = lineRects[i].offsetBy(dx: 0.0, dy: gridOffsetY)
            }
        }

        // Rounded outer border — refresh radius/color/width (theme or `bordered` flag may change).
        self.contentView.layer.cornerRadius = v2TableCornerRadius
        self.contentView.layer.borderColor = item.borderColor.cgColor
        self.contentView.layer.borderWidth = item.bordered ? v2TableBorderWidth : 0.0
    }
}

// MARK: - Public helpers on InstantPageV2View

public extension InstantPageV2View {
    func lastTextLineFrame() -> CGRect? {
        guard let layout = self.currentLayout else { return nil }
        return InstantPageUI.lastTextLineFrame(in: layout)
    }

    func textItemAt(point: CGPoint) -> (item: InstantPageTextItem, parentOffset: CGPoint)? {
        guard let layout = self.currentLayout else { return nil }
        return findTextItem(in: layout, point: point, accumulatedOffset: .zero)
    }

    /// The structural path of the collapsible quote containing `point`, or nil. The host resolves the
    /// expand tap through this AFTER its URL / entity hits, so a link inside a collapsed quote's
    /// visible lines still opens rather than toggling.
    ///
    /// Innermost wins: a collapsible quote nested inside another is matched before its parent (a longer
    /// path is deeper), so its own chevron toggles the quote it belongs to.
    ///
    /// Top-level items only, matching where `layoutBlockQuote` puts a quote's frame item. A quote
    /// nested inside a details body or a table cell lives in that container's own sub-layout and is
    /// not reachable here — those containers are not collapsible-quote hosts today.
    func collapsibleQuoteAt(point: CGPoint) -> [Int]? {
        guard let layout = self.currentLayout else { return nil }
        var best: InstantPageV2QuoteFrameItem?
        for item in layout.items {
            guard case let .quoteFrame(frameItem) = item, frameItem.collapseState != .notCollapsible else {
                continue
            }
            guard frameItem.frame.contains(point) else {
                continue
            }
            if let current = best, current.path.count >= frameItem.path.count {
                continue
            }
            best = frameItem
        }
        return best?.path
    }

    /// The frame (this view's coords) of the unsupported pill's Update button containing `point`,
    /// or nil.
    ///
    /// A host whose surface arbitrates its own touches must consult this BEFORE claiming a tap: the
    /// pill's button is a real `UIButton`, and a surrounding tap recognizer that claims the touch
    /// cancels the button's tracking, so `touchUpInside` never fires. In a chat bubble that is
    /// `tapActionAtPoint` returning `.ignore` for this rect (see
    /// `ChatMessageRichDataBubbleContentNode`).
    func unsupportedActionFrame(at point: CGPoint) -> CGRect? {
        guard let layout = self.currentLayout else { return nil }
        return InstantPageUI.unsupportedActionFrame(in: layout, containing: point)
    }

    func urlItemAt(point: CGPoint) -> (urlItem: InstantPageUrlItem, item: InstantPageTextItem,
                                       parentOffset: CGPoint, localPoint: CGPoint)? {
        guard let hit = self.textItemAt(point: point) else { return nil }
        let localPoint = CGPoint(x: point.x - hit.parentOffset.x, y: point.y - hit.parentOffset.y)
        guard let url = hit.item.urlAttribute(at: localPoint) else { return nil }
        return (urlItem: url, item: hit.item, parentOffset: hit.parentOffset, localPoint: localPoint)
    }

    func selectableTextItems() -> [(item: InstantPageTextItem, parentOffset: CGPoint)] {
        guard let layout = self.currentLayout else { return [] }
        var result: [(InstantPageTextItem, CGPoint)] = []
        collectSelectableTextItems(in: layout, accumulatedOffset: .zero, into: &result)
        return result.map { (item: $0.0, parentOffset: $0.1) }
    }

    func detailsItem(atIndex index: Int) -> (frame: CGRect, titleFrame: CGRect)? {
        guard let layout = self.currentLayout else { return nil }
        for item in layout.items {
            if case let .details(d) = item, d.index == index {
                return (frame: d.frame, titleFrame: d.titleFrame.offsetBy(dx: d.frame.minX, dy: d.frame.minY))
            }
        }
        return nil
    }

    /// The frame (pageView-space) of the anchor `name` in the *currently laid-out* layout.
    /// Returns nil if the anchor isn't present — e.g. it's inside a collapsed `<details>`
    /// (whose inner blocks aren't laid out) or doesn't exist. Mirrors `findTextItem`.
    func anchorFrame(name: String) -> CGRect? {
        guard let layout = self.currentLayout else { return nil }
        return findAnchorFrame(in: layout, name: name, accumulatedOffset: .zero)
    }

    /// Given a details-sibling-ordinal path (from `instantPageAnchorPath`), walk the live layout
    /// and return the `currentExpandedDetails` index of the FIRST not-yet-expanded `<details>` on
    /// the path. Returns nil if every details on the path is already expanded, or the path doesn't
    /// match the live layout. Reads indices from the laid-out items — never reproduces them.
    func firstCollapsedDetails(forOrdinalPath path: [Int]) -> Int? {
        guard let layout = self.currentLayout else { return nil }
        var currentItems = layout.items
        for ordinal in path {
            var seen = 0
            var found: InstantPageV2DetailsItem?
            for item in currentItems {
                if case let .details(details) = item {
                    if seen == ordinal {
                        found = details
                        break
                    }
                    seen += 1
                }
            }
            guard let details = found else { return nil }
            if !details.isExpanded {
                return details.index
            }
            guard let inner = details.innerLayout else { return nil }
            currentItems = inner.items
        }
        return nil
    }
}

// MARK: - Private recursion helpers

private func findTextItem(
    in layout: InstantPageV2Layout,
    point: CGPoint,
    accumulatedOffset: CGPoint
) -> (item: InstantPageTextItem, parentOffset: CGPoint)? {
    for item in layout.items {
        let f = item.frame.offsetBy(dx: accumulatedOffset.x, dy: accumulatedOffset.y)
        if !f.contains(point) { continue }
        switch item {
        case let .text(text):
            return (item: text.textItem, parentOffset: CGPoint(x: f.minX, y: f.minY))
        case let .codeBlock(block):
            let textOrigin = CGPoint(
                x: f.minX + block.textItem.frame.minX,
                y: f.minY + block.textItem.frame.minY
            )
            return (item: block.textItem, parentOffset: textOrigin)
        case let .details(details):
            if details.titleFrame.offsetBy(dx: f.minX, dy: f.minY).contains(point) {
                let titleOrigin = CGPoint(
                    x: f.minX + details.titleTextItem.frame.minX,
                    y: f.minY + details.titleTextItem.frame.minY
                )
                return (item: details.titleTextItem, parentOffset: titleOrigin)
            }
            if let inner = details.innerLayout {
                let innerOffset = CGPoint(x: f.minX, y: f.minY + details.titleFrame.maxY)
                if let hit = findTextItem(in: inner, point: point, accumulatedOffset: innerOffset) {
                    return hit
                }
            }
        case let .table(table):
            for cell in table.cells {
                let cellAbs = cell.frame.offsetBy(dx: f.minX + table.contentInset, dy: f.minY)
                if !cellAbs.contains(point) { continue }
                if let sub = cell.subLayout {
                    if let hit = findTextItem(in: sub, point: point,
                                              accumulatedOffset: CGPoint(x: cellAbs.minX, y: cellAbs.minY)) {
                        return hit
                    }
                }
            }
            if let titleLayout = table.titleSubLayout, let titleFrame = table.titleFrame {
                let titleAbs = titleFrame.offsetBy(dx: f.minX + table.contentInset, dy: f.minY)
                if titleAbs.contains(point) {
                    if let hit = findTextItem(in: titleLayout, point: point,
                                              accumulatedOffset: CGPoint(x: titleAbs.minX, y: titleAbs.minY)) {
                        return hit
                    }
                }
            }
        default:
            continue
        }
    }
    return nil
}

private func findAnchorFrame(
    in layout: InstantPageV2Layout,
    name: String,
    accumulatedOffset: CGPoint
) -> CGRect? {
    for item in layout.items {
        let f = item.frame.offsetBy(dx: accumulatedOffset.x, dy: accumulatedOffset.y)
        switch item {
        case let .anchor(anchor):
            if anchor.name == name {
                return CGRect(x: f.minX, y: f.minY, width: 0.0, height: 0.0)
            }
        case let .text(text):
            if let (lineIndex, _) = text.textItem.anchors[name], lineIndex < text.textItem.lines.count {
                let line = text.textItem.lines[lineIndex].frame
                return CGRect(x: f.minX + line.minX, y: f.minY + line.minY, width: line.width, height: line.height)
            }
        case let .codeBlock(block):
            if let (lineIndex, _) = block.textItem.anchors[name], lineIndex < block.textItem.lines.count {
                let line = block.textItem.lines[lineIndex].frame
                return CGRect(
                    x: f.minX + block.textItem.frame.minX + line.minX,
                    y: f.minY + block.textItem.frame.minY + line.minY,
                    width: line.width, height: line.height
                )
            }
        case let .thinking(thinking):
            if let (lineIndex, _) = thinking.textItem.anchors[name], lineIndex < thinking.textItem.lines.count {
                let line = thinking.textItem.lines[lineIndex].frame
                return CGRect(
                    x: f.minX + thinking.textItem.frame.minX + line.minX,
                    y: f.minY + thinking.textItem.frame.minY + line.minY,
                    width: line.width, height: line.height
                )
            }
        case let .details(details):
            if let (lineIndex, _) = details.titleTextItem.anchors[name], lineIndex < details.titleTextItem.lines.count {
                let line = details.titleTextItem.lines[lineIndex].frame
                return CGRect(
                    x: f.minX + details.titleTextItem.frame.minX + line.minX,
                    y: f.minY + details.titleTextItem.frame.minY + line.minY,
                    width: line.width, height: line.height
                )
            }
            if let inner = details.innerLayout {
                let innerOffset = CGPoint(x: f.minX, y: f.minY + details.titleFrame.maxY)
                if let hit = findAnchorFrame(in: inner, name: name, accumulatedOffset: innerOffset) {
                    return hit
                }
            }
        case let .table(table):
            for cell in table.cells {
                if let sub = cell.subLayout {
                    let cellOffset = CGPoint(x: f.minX + table.contentInset + cell.frame.minX, y: f.minY + cell.frame.minY)
                    if let hit = findAnchorFrame(in: sub, name: name, accumulatedOffset: cellOffset) {
                        return hit
                    }
                }
            }
            if let titleLayout = table.titleSubLayout, let titleFrame = table.titleFrame {
                let titleOffset = CGPoint(x: f.minX + table.contentInset + titleFrame.minX, y: f.minY + titleFrame.minY)
                if let hit = findAnchorFrame(in: titleLayout, name: name, accumulatedOffset: titleOffset) {
                    return hit
                }
            }
        default:
            continue
        }
    }
    return nil
}

private func collectSelectableTextItems(
    in layout: InstantPageV2Layout,
    accumulatedOffset: CGPoint,
    into result: inout [(InstantPageTextItem, CGPoint)]
) {
    for item in layout.items {
        switch item {
        case let .text(text):
            if text.textItem.selectable && !text.textItem.attributedString.string.isEmpty {
                result.append((text.textItem, CGPoint(
                    x: accumulatedOffset.x + text.frame.minX,
                    y: accumulatedOffset.y + text.frame.minY
                )))
            }
        case let .codeBlock(block):
            if block.textItem.selectable && !block.textItem.attributedString.string.isEmpty {
                result.append((block.textItem, CGPoint(
                    x: accumulatedOffset.x + block.frame.minX + block.textItem.frame.minX,
                    y: accumulatedOffset.y + block.frame.minY + block.textItem.frame.minY
                )))
            }
        case let .details(details):
            if details.titleTextItem.selectable && !details.titleTextItem.attributedString.string.isEmpty {
                result.append((details.titleTextItem, CGPoint(
                    x: accumulatedOffset.x + details.frame.minX + details.titleTextItem.frame.minX,
                    y: accumulatedOffset.y + details.frame.minY + details.titleTextItem.frame.minY
                )))
            }
            if let inner = details.innerLayout {
                let innerOffset = CGPoint(
                    x: accumulatedOffset.x + details.frame.minX,
                    y: accumulatedOffset.y + details.frame.minY + details.titleFrame.maxY
                )
                collectSelectableTextItems(in: inner, accumulatedOffset: innerOffset, into: &result)
            }
        case let .table(table):
            if let titleLayout = table.titleSubLayout, let titleFrame = table.titleFrame {
                let titleOffset = CGPoint(
                    x: accumulatedOffset.x + table.frame.minX + table.contentInset + titleFrame.minX,
                    y: accumulatedOffset.y + table.frame.minY + titleFrame.minY
                )
                collectSelectableTextItems(in: titleLayout, accumulatedOffset: titleOffset, into: &result)
            }
            for cell in table.cells {
                if let sub = cell.subLayout {
                    let cellOffset = CGPoint(
                        x: accumulatedOffset.x + table.frame.minX + table.contentInset + cell.frame.minX,
                        y: accumulatedOffset.y + table.frame.minY + cell.frame.minY
                    )
                    collectSelectableTextItems(in: sub, accumulatedOffset: cellOffset, into: &result)
                }
            }
        default:
            continue
        }
    }
}

// MARK: - Formula view

/// Renders both block (`InstantPageBlock.formula(latex:)`) and inline (`InstantPageFormulaAttribute`)
/// math, sourcing the pre-rendered Retina image from `InstantPageMathAttachment.rendered`.
///
/// For block formulas wider than the bubble's available width, the layout sets
/// `isScrollable = true`; this view then wraps the image in a horizontal `UIScrollView`
/// matching V1's `InstantPageScrollableNode` (no bounce on non-overflowing content,
/// scroll indicator hidden — appropriate for content embedded inside a chat bubble).
final class InstantPageV2FormulaView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2FormulaItem
    var itemFrame: CGRect { return self.item.frame }

    init(item: InstantPageV2FormulaItem, theme: InstantPageTheme) {
        self.item = item
        super.init(frame: item.frame)
        self.backgroundColor = .clear   // structural
        self.isOpaque = false           // structural
        self.update(item: item, theme: theme)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(item: InstantPageV2FormulaItem, theme: InstantPageTheme) {
        let _ = theme
        self.item = item

        // Image content and scroll/non-scroll shape may change with width; rebuild. On the first
        // call (from init) there is nothing to tear down, so this collapses to a plain build.
        for sub in self.subviews { sub.removeFromSuperview() }
        if let sublayers = self.layer.sublayers {
            for layer in sublayers { layer.removeFromSuperlayer() }
        }
        self.buildContents()
    }

    private func buildContents() {
        let item = self.item
        let imageLayer = CALayer()
        imageLayer.contents = item.attachment.rendered.image.cgImage
        imageLayer.contentsScale = item.attachment.rendered.image.scale
        imageLayer.contentsGravity = .resizeAspect
        imageLayer.frame = item.imageFrame

        if item.isScrollable {
            self.clipsToBounds = true
            self.isUserInteractionEnabled = true
            let scroll = UIScrollView(frame: CGRect(origin: .zero, size: item.frame.size))
            scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            scroll.contentSize = item.scrollContentSize
            scroll.showsHorizontalScrollIndicator = false
            scroll.showsVerticalScrollIndicator = false
            scroll.alwaysBounceHorizontal = false
            scroll.alwaysBounceVertical = false
            scroll.contentInsetAdjustmentBehavior = .never
            scroll.disablesInteractiveTransitionGestureRecognizer = true
            self.addSubview(scroll)

            // Layers don't autoresize with their superview; host the image layer inside a UIView
            // so the scroll view's content-size growth keeps the image positioned correctly.
            let imageHost = UIView(frame: CGRect(origin: .zero, size: item.scrollContentSize))
            imageHost.layer.addSublayer(imageLayer)
            scroll.addSubview(imageHost)
        } else {
            // Inline and centered-block formulas don't accept touches; the bubble's link/long-press
            // recognizers run against the underlying text view instead.
            self.isUserInteractionEnabled = false
            self.layer.addSublayer(imageLayer)
        }
    }
}
