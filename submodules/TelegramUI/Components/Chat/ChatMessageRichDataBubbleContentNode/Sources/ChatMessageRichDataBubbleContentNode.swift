import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import AccountContext
import ChatMessageBubbleContentNode
import ChatMessageDateAndStatusNode
import ChatMessageItemCommon
import ChatControllerInteraction
import InstantPageUI
import TextFormat
import TelegramUIPreferences
import TextLoadingEffect
import TextSelectionNode
import StreamingTextReveal
import ShimmeringLinkNode

public class ChatMessageRichDataBubbleContentNode: ChatMessageBubbleContentNode {
    public final class ContainerNode: ASDisplayNode {
    }

    private enum ResolvedRichDataPageKey: Equatable {
        case pendingEdit(attribute: ObjectIdentifier, page: ObjectIdentifier)
        case translated(language: String, attribute: ObjectIdentifier, page: ObjectIdentifier)
        case original(attribute: ObjectIdentifier, page: ObjectIdentifier)
    }

    private struct ResolvedRichDataContent {
        let instantPage: InstantPage
        let originalAttribute: RichTextMessageAttribute?
        let key: ResolvedRichDataPageKey
        let isTranslated: Bool
        let isTranslating: Bool
    }
    
    private let containerNode: ContainerNode
    public var statusNode: ChatMessageDateAndStatusNode?
    // `init()` may run off the main thread; UIView construction must happen on the main thread.
    // The page view is built lazily inside the apply closure (always main-thread) via ensurePageView().
    private var pageView: InstantPageV2View?
    // Tracks the message (id + stableVersion) baked into the current pageView's render context.
    // The synthesized webpage uses a sentinel id (namespace 0, id 0) shared across all richText
    // messages, so we key cache invalidation on the message itself. When the bubble is recycled
    // with a different message we must discard pageView (render context is constructor-fixed).
    private var pageViewMessageKey: (id: EngineMessage.Id, stableVersion: UInt32, pendingEditKey: ObjectIdentifier?, richPageKey: ResolvedRichDataPageKey, showMoreExpanded: Bool)?
    // messageStableVersion is in the cache key because the synthesized instantPage content
    // mutates between streamed AI message chunks (each chunk bumps stableVersion); without
    // this, the cached layout would shadow newly-arrived content during streaming.
    private var currentPageLayout: (boundingWidth: CGFloat,
                                    presentationThemeIdentity: ObjectIdentifier,
                                    baseFontSize: CGFloat,
                                    expandedDetails: [Int: Bool],
                                    messageStableVersion: UInt32,
                                    pendingEditKey: ObjectIdentifier?,
                                    richPageKey: ResolvedRichDataPageKey,
                                    showMoreExpanded: Bool,
                                    layout: InstantPageV2Layout)?
    private var currentExpandedDetails: [Int: Bool] = [:]
    // Intra-message anchor scroll that is waiting on a collapsed <details> to expand + relayout.
    private var pendingScrollAnchor: String?
    // Progress guard: the details index expanded on the previous pending pass.
    private var lastExpandedPendingDetailsIndex: Int?
    private var linkProgressDisposable: Disposable?
    private var linkProgressRects: [CGRect]?
    private var linkHighlightingNode: LinkHighlightingNode?
    private var linkProgressView: TextLoadingEffectView?
    private var shimmeringNode: ShimmeringLinkNode?
    private var shimmeringNodeIsSkeleton: Bool = false
    private var textSelectionAdapter: InstantPageMultiTextAdapter?
    private var textSelectionNode: TextSelectionNode?

    private var textRevealController: TextRevealController?
    private var textRevealLink: SharedDisplayLinkDriver.Link?
    private var currentRevealCostMap: InstantPageV2RevealCostMap?
    // Cursor value pushed into pageView.applyReveal on the prior tick. The display-link tick
    // compares the revealed prefix's height at this cursor vs the new cursor to decide when
    // to request a full bubble re-layout (so the bubble grows with the reveal).
    private var lastAppliedRevealedCount: Int = 0
    private var displayContentsUnderSpoilers: Bool = false
    private var relativeDateTimer: (timer: SwiftSignalKit.Timer, period: Int32)?

    // "Show more" affordance for partial rich messages (instantPage.isComplete == false).
    // Managed inline, mirroring the statusNode pattern: a bubble-owned TextNode below the page
    // content, with a TextLoadingEffectView shimmer while the full-text request is in flight.
    private var showMoreTextNode: TextNode?
    private var showMoreLoadingView: TextLoadingEffectView?
    private var requestFullRichTextDisposable: Disposable?
    private var requestFullRichTextMessageId: EngineMessage.Id?
    // Transient per-message expand state. The full page is shown only after the user taps "Show
    // more"; tagging it with the message id means any other message starts collapsed (partial)
    // every time, even if its attribute already carries a cached fullInstantPage.
    private var showMoreExpanded: (messageId: EngineMessage.Id, value: Bool)?
    // The expand state actually applied on the previous layout pass, used to detect the
    // collapse→expand transition so the bubble can grow downward in screen space (see the
    // setInvertOffsetDirection call in the apply closure). nil until the first apply.
    private var appliedShowMoreExpanded: Bool?

    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            if oldValue != self.visibility {
                self.updatePageViewVisibilityRect()
            }
        }
    }

    // Pushes the current `visibility` sub-rect into `pageView.visibilityRect`, translated into the
    // page view's coordinate space (the page view sits at the top of the bubble; no header offset).
    // Re-invoked from the apply closure after `pageView.frame` is set, because the pageView's
    // y-origin and size can change across streamed chunks (content growth) without a `visibility`
    // change, which would otherwise leave the animation-gating rect stale.
    private func updatePageViewVisibilityRect() {
        guard let pageView = self.pageView else {
            return
        }
        switch self.visibility {
        case .none:
            pageView.visibilityRect = nil
        case let .visible(_, subRect):
            var rect = subRect
            rect.origin.x = 0.0
            rect.size.width = 10000.0
            rect.origin.y -= pageView.frame.minY
            pageView.visibilityRect = rect
        }
    }

    required public init() {
        self.containerNode = ContainerNode()
        self.containerNode.clipsToBounds = true

        super.init()

        self.addSubnode(self.containerNode)
    }

    private static func resolvedRichDataContent(item: ChatMessageBubbleContentItem, showMoreExpanded: Bool) -> ResolvedRichDataContent? {
        if let attribute = item.attributes.updatingMedia?.richText {
            let instantPage = (showMoreExpanded ? attribute.fullInstantPage : nil) ?? attribute.instantPage
            return ResolvedRichDataContent(
                instantPage: instantPage,
                originalAttribute: attribute,
                key: .pendingEdit(attribute: ObjectIdentifier(attribute), page: ObjectIdentifier(instantPage)),
                isTranslated: false,
                isTranslating: false
            )
        }

        guard let attribute = item.message.richText else {
            return nil
        }

        let isIncoming = item.message.effectivelyIncoming(item.context.account.peerId)
        var canDisplayTranslation = isIncoming
        if let subject = item.associatedData.subject, case .messageOptions = subject {
            canDisplayTranslation = false
        }

        if canDisplayTranslation, let translateToLanguage = item.associatedData.translateToLanguage {
            if let translation = item.message.attributes.first(where: { ($0 as? TranslationMessageAttribute)?.toLang == translateToLanguage }) as? TranslationMessageAttribute, let instantPage = translation.instantPage {
                return ResolvedRichDataContent(
                    instantPage: instantPage,
                    originalAttribute: attribute,
                    key: .translated(language: translateToLanguage, attribute: ObjectIdentifier(translation), page: ObjectIdentifier(instantPage)),
                    isTranslated: true,
                    isTranslating: false
                )
            } else {
                return ResolvedRichDataContent(
                    instantPage: attribute.instantPage,
                    originalAttribute: attribute,
                    key: .original(attribute: ObjectIdentifier(attribute), page: ObjectIdentifier(attribute.instantPage)),
                    isTranslated: false,
                    isTranslating: true
                )
            }
        }

        let instantPage = (showMoreExpanded ? attribute.fullInstantPage : nil) ?? attribute.instantPage
        return ResolvedRichDataContent(
            instantPage: instantPage,
            originalAttribute: attribute,
            key: .original(attribute: ObjectIdentifier(attribute), page: ObjectIdentifier(instantPage)),
            isTranslated: false,
            isTranslating: false
        )
    }

    /// Builds (or reuses) the V2View. Same-message stableVersion bumps (streamed AI chunks) reuse
    /// the existing view, updating only the webpage content in place. The view is rebuilt only when
    /// the bubble is recycled with a different message/webpage (different message id).
    private func ensurePageView(item: ChatMessageBubbleContentItem, webpage: TelegramMediaWebpage, richPageKey: ResolvedRichDataPageKey, showMoreExpanded: Bool) -> InstantPageV2View {
        let key = (id: item.message.id, stableVersion: item.message.stableVersion, pendingEditKey: (item.attributes.updatingMedia?.richText).map({ ObjectIdentifier($0) }), richPageKey: richPageKey, showMoreExpanded: showMoreExpanded)
        if let existing = self.pageView, let current = self.pageViewMessageKey, current.id == key.id {
            if current.stableVersion == key.stableVersion && current.pendingEditKey == key.pendingEditKey && current.richPageKey == key.richPageKey && current.showMoreExpanded == key.showMoreExpanded {
                return existing
            }
            // Same message, new chunk: reuse the view. Update only the content-bearing webpage on
            // the existing render context; the subsequent pageView.update(layout:) call diffs item
            // views by stable id (content blocks keep their ids, so their views and in-flight
            // reveal state persist; only added/removed blocks change). This replaces the old
            // wholesale rebuild and eliminates the per-chunk full-text-then-mask flash.
            existing.renderContext?.updateContent(webpage: webpage)
            self.pageViewMessageKey = key
            return existing
        }
        self.pageView?.removeFromSuperview()
        self.pageView = nil

        // Capture only the MessageReference (value type) — the closures are retained on the
        // render context which is owned by the V2View, so we must avoid making them retain
        // the bubble (`self`) or the message indirectly via `item`.
        let messageReference = MessageReference(item.message)
        let policyContext = item.context
        let autoDownloadSettings = item.controllerInteraction.automaticMediaDownloadSettings
        let autoDownloadPeerType = item.associatedData.automaticDownloadPeerType
        let autoDownloadNetworkType = item.associatedData.automaticDownloadNetworkType
        let autoDownloadContactsPeerIds = item.associatedData.contactsPeerIds
        let messageAuthorPeerId = item.message.author?.id
        let messagePeerId = item.message.id.peerId
        let renderContext = InstantPageV2RenderContext(
            context: item.context,
            webpage: webpage,
            sourceLocation: InstantPageSourceLocation(userLocation: .peer(messagePeerId), peerType: autoDownloadPeerType),
            imageReference: { image in
                return ImageMediaReference.message(message: messageReference, media: image)
            },
            fileReference: { file in
                return FileMediaReference.message(message: messageReference, media: file)
            },
            present: { [weak self] controller, args in
                self?.item?.controllerInteraction.presentController(controller, args)
            },
            push: { [weak self] controller in
                self?.item?.controllerInteraction.navigationController()?.pushViewController(controller)
            },
            openUrl: { [weak self] urlItem in
                self?.openInstantPageUrl(urlItem)
            },
            baseNavigationController: { [weak self] in
                self?.item?.controllerInteraction.navigationController()
            },
            shouldAutoDownloadImage: { image in
                return shouldDownloadMediaAutomatically(settings: autoDownloadSettings, peerType: autoDownloadPeerType, networkType: autoDownloadNetworkType, authorPeerId: messageAuthorPeerId, contactsPeerIds: autoDownloadContactsPeerIds, media: image)
            },
            shouldAutoDownloadFile: { file in
                return shouldDownloadMediaAutomatically(settings: autoDownloadSettings, peerType: autoDownloadPeerType, networkType: autoDownloadNetworkType, authorPeerId: messageAuthorPeerId, contactsPeerIds: autoDownloadContactsPeerIds, media: file)
            },
            shouldAutoplayVideo: { file in
                let enabled = file.isAnimated ? policyContext.sharedContext.energyUsageSettings.autoplayGif : policyContext.sharedContext.energyUsageSettings.autoplayVideo
                guard enabled else { return false }
                return policyContext.engine.resources.completedResourcePath(id: EngineMediaResource.Id(file.resource.id)) != nil
            },
            message: messageReference
        )
        let view = InstantPageV2View(renderContext: renderContext)
        self.pageView = view
        self.pageViewMessageKey = key
        self.containerNode.view.addSubview(view)
        view.detailsTapped = { [weak self] index in
            guard let self else { return }
            let current = self.currentExpandedDetails[index] ?? self.defaultExpanded(forDetailsIndex: index)
            self.currentExpandedDetails[index] = !current
            if let item = self.item {
                item.controllerInteraction.requestMessageUpdate(item.message.id, false, nil)
            }
        }
        return view
    }

    /// True when the rendered page is the message's primary (non-translated, non-full,
    /// non-pending-edit) InstantPage — the only rendering whose checkbox paths are safe to
    /// edit — AND the message is editable.
    private func checkboxesInteractive(item: ChatMessageBubbleContentItem, resolved: ResolvedRichDataContent) -> Bool {
        // `.original` (server state) and `.pendingEdit` (an in-flight edit) are both eligible —
        // keeping checkboxes live during the pending round-trip lets the user toggle several boxes
        // in a row. `.translated` is inert, as is the translation-pending fallback (which reports an
        // `.original` key over the genuine original page but with `isTranslating == true`).
        switch resolved.key {
        case .original, .pendingEdit:
            break
        case .translated:
            return false
        }
        if resolved.isTranslating {
            return false
        }
        // The primary page is the resolved attribute's `instantPage` (class identity). The show-more
        // (`fullInstantPage`) rendering carries the same key but a different page object, so an
        // identity check excludes it. `originalAttribute` is Optional (it is the pending edit's
        // attribute in the `.pendingEdit` case).
        guard let attribute = resolved.originalAttribute, resolved.instantPage === attribute.instantPage else {
            return false
        }
        return item.controllerInteraction.canEditMessageRichText(item.message)
    }

    private func defaultExpanded(forDetailsIndex index: Int) -> Bool {
        guard let layout = self.currentPageLayout?.layout else { return false }
        func search(_ items: [InstantPageV2LaidOutItem]) -> Bool? {
            for item in items {
                if case let .details(d) = item {
                    if d.index == index {
                        return d.defaultExpanded
                    }
                    // Recurse into an expanded parent's body so NESTED details indices resolve too;
                    // the flat top-level scan missed them, leaving the toggle's "current state"
                    // computation wrong for a nested details whose model default is expanded.
                    if let inner = d.innerLayout, let found = search(inner.items) {
                        return found
                    }
                }
            }
            return nil
        }
        return search(layout.items) ?? false
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.linkProgressDisposable?.dispose()
        self.relativeDateTimer?.timer.invalidate()
        self.requestFullRichTextDisposable?.dispose()
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let previousItem = self.item
        let currentPageLayout = self.currentPageLayout
        let currentExpandedDetails = self.currentExpandedDetails
        let showMoreExpandedState = self.showMoreExpanded
        let statusLayout = ChatMessageDateAndStatusNode.asyncLayout(self.statusNode)
        let showMoreTextLayout = TextNode.asyncLayout(self.showMoreTextNode)
        // Captured at main-thread, top of asyncLayoutContent. Mirrors TextBubble's
        // `currentMaxGlyphCount` (TextBubble:313). The bubble's bounding size is sized
        // to this revealed prefix during streaming, so it grows with the reveal rather
        // than being final-sized from the first chunk.
        let currentMaxGlyphCount: Int? = self.textRevealController?.currentGlyphCount

        return { [weak self] item, layoutConstants, _, _, _, _ in
            // Structural detector (model-only): does the effective rich page end with full-width
            // visual media? This is emitted BEFORE the page is laid out, so it inspects the block
            // model rather than laid-out items. Its only job is to push non-inline reactions outside
            // the bubble (the overlaid pill can't host multi-row reactions). The authoritative
            // full-width placement decision happens later, in the layout phase.
            var wantsReactionsOutside = false
            if let attribute = (item.attributes.updatingMedia.map(\.richText) ?? item.message.richText) {
                let showMoreExpanded = (showMoreExpandedState?.messageId == item.message.id) ? (showMoreExpandedState?.value ?? false) : false
                let page = (showMoreExpanded ? attribute.fullInstantPage : nil) ?? attribute.instantPage
                if let lastBlock = page.blocks.last, richDataBlockEndsWithVisualMedia(lastBlock) {
                    let reactions = mergedMessageReactions(attributes: item.message.attributes, isTags: item.message.areReactionsTags(accountPeerId: item.context.account.peerId))
                    let hasReactions = !(reactions?.reactions.isEmpty ?? true)
                    let inline = shouldDisplayInlineDateReactions(message: EngineMessage(item.message), isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions)
                    wantsReactionsOutside = hasReactions && !inline
                }
            }
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 8.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none, wantsReactionsOutside: wantsReactionsOutside)

            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let suggestedBoundingWidth: CGFloat = constrainedSize.width

                var boundingSize = CGSize(width: suggestedBoundingWidth, height: 0.0)

                var pageLayout: InstantPageV2Layout?
                // Built alongside pageLayout so the apply closure can hand it to ensurePageView.
                var pageWebpage: TelegramMediaWebpage?

                // Horizontal text inset baked into the InstantPage layout. The pageView sits at
                // self-x 0 (containerNode at 1, pageView at -1 inside it), so the page's text
                // left edge in the status node's coordinate space is exactly this value. Used as
                // the status node's left edge + side inset, mirroring TextBubble's bubbleInsets.
                let pageHorizontalInset: CGFloat = 11.0

                let isDark = item.presentationData.theme.theme.overallDarkAppearance
                let isIncoming = item.message.effectivelyIncoming(item.context.account.peerId)
                let messageTheme = isIncoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                var underlineLinks = true
                if !messageTheme.primaryTextColor.isEqual(messageTheme.linkTextColor) {
                    underlineLinks = false
                }
                let _ = underlineLinks
                
                let author = item.message.author
                let mainColor: UIColor
                var secondaryColor: UIColor? = nil
                var tertiaryColor: UIColor? = nil
                
                let nameColors: PeerNameColors.Colors?
                switch author?.nameColor {
                case let .preset(nameColor):
                    nameColors = item.context.peerNameColors.get(nameColor, dark: item.presentationData.theme.theme.overallDarkAppearance)
                case let .collectible(collectibleColor):
                    nameColors = collectibleColor.peerNameColors(dark: item.presentationData.theme.theme.overallDarkAppearance)
                default:
                    nameColors = nil
                }
                
                let codeBlockBackgroundColor: UIColor
                let codeBlockTitleColor: UIColor
                let codeBlockAccentColor: UIColor
                if !isIncoming {
                    mainColor = messageTheme.accentTextColor
                    if let _ = nameColors?.secondary {
                        secondaryColor = .clear
                    }
                    if let _ = nameColors?.tertiary {
                        tertiaryColor = .clear
                    }
                    
                    if item.presentationData.theme.theme.overallDarkAppearance {
                        codeBlockTitleColor = .white
                        codeBlockAccentColor = UIColor(white: 1.0, alpha: 0.5)
                    } else {
                        codeBlockTitleColor = mainColor
                        codeBlockAccentColor = mainColor
                    }
                    
                    codeBlockBackgroundColor = mainColor.withMultipliedAlpha(0.1)
                } else {
                    let authorNameColor = nameColors?.main
                    secondaryColor = nameColors?.secondary
                    tertiaryColor = nameColors?.tertiary
                    
                    if let authorNameColor {
                        mainColor = authorNameColor
                    } else {
                        mainColor = messageTheme.accentTextColor
                    }
                    
                    codeBlockTitleColor = mainColor
                    codeBlockAccentColor = mainColor
                    
                    codeBlockBackgroundColor = mainColor.withMultipliedAlpha(0.1)
                }
                
                let _ = secondaryColor
                let _ = tertiaryColor
                
                let _ = codeBlockTitleColor
                let _ = codeBlockAccentColor
                
                let baseFontSize = item.presentationData.fontSize.baseDisplaySize
                let fontScale = baseFontSize / 17.0
                let scaledFontSize: (CGFloat) -> CGFloat = { size in
                    return floor(size * fontScale)
                }
                let textCategories = InstantPageTextCategories(
                    kicker: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: scaledFontSize(15.0), lineSpacingFactor: 0.685), color: messageTheme.primaryTextColor),
                    header: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: scaledFontSize(19.0), lineSpacingFactor: 0.685), color: messageTheme.primaryTextColor),
                    subheader: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: scaledFontSize(18.0), lineSpacingFactor: 0.685), color: messageTheme.primaryTextColor),
                    paragraph: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: scaledFontSize(17.0), lineSpacingFactor: 1.0), color: messageTheme.primaryTextColor),
                    caption: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: scaledFontSize(15.0), lineSpacingFactor: 1.0), color: messageTheme.secondaryTextColor),
                    credit: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: scaledFontSize(13.0), lineSpacingFactor: 1.0), color: messageTheme.secondaryTextColor),
                    table: InstantPageTextAttributes(font: InstantPageFont(style: .sans, size: scaledFontSize(15.0), lineSpacingFactor: 1.0), color: messageTheme.primaryTextColor),
                    article: InstantPageTextAttributes(font: InstantPageFont(style: .serif, size: scaledFontSize(18.0), lineSpacingFactor: 1.0), color: messageTheme.primaryTextColor),
                    codeBlock: InstantPageTextAttributes(font: InstantPageFont(style: .monospace, size: scaledFontSize(14.0), lineSpacingFactor: 1.0), color: messageTheme.primaryTextColor),
                )
                let pageTheme = InstantPageTheme(
                    type: isDark ? .dark : .light,
                    pageBackgroundColor: .clear,
                    textCategories: textCategories,
                    serif: false,
                    codeBlockBackgroundColor: codeBlockBackgroundColor,
                    linkColor: messageTheme.linkTextColor,
                    textHighlightColor: messageTheme.accentTextColor.withMultipliedAlpha(0.1),
                    linkHighlightColor: messageTheme.linkTextColor.withMultipliedAlpha(0.1),
                    markerColor: UIColor(rgb: 0xfef3bc),
                    panelBackgroundColor: messageTheme.accentControlColor.withMultipliedAlpha(0.1),
                    panelHighlightedBackgroundColor: messageTheme.accentControlColor.withMultipliedAlpha(0.25),
                    panelPrimaryColor: messageTheme.primaryTextColor,
                    panelSecondaryColor: messageTheme.secondaryTextColor,
                    panelAccentColor: messageTheme.accentTextColor,
                    tableBorderColor: isDark || !isIncoming ? messageTheme.accentControlColor.withMultipliedAlpha(0.25) : UIColor(white: 0.0, alpha: 0.1),
                    tableHeaderColor: isDark || !isIncoming ? messageTheme.accentControlColor.withMultipliedAlpha(0.1) : UIColor(white: 0.0, alpha: 0.05),
                    controlColor: messageTheme.accentControlColor,
                    imageTintColor: nil,
                    overlayPanelColor: isDark ? UIColor(white: 0.0, alpha: 0.13) : UIColor(white: 1.0, alpha: 0.13),
                    separatorColor: messageTheme.secondaryTextColor.mixedWith(mainColor.withMultipliedAlpha(0.2), alpha: 0.3),
                    secondaryControlColor: messageTheme.secondaryTextColor.mixedWith(mainColor.withMultipliedAlpha(0.2), alpha: 0.3),
                    quoteAccentColor: mainColor
                )
                
                var hasDraft = false
                if item.message.attributes.contains(where: { $0 is TypingDraftMessageAttribute }) {
                    hasDraft = true
                }
                var hadDraft = false
                if let previousItem, previousItem.message.attributes.contains(where: { $0 is TypingDraftMessageAttribute }) {
                    hadDraft = true
                }

                // Resolve the node-local expand state for THIS message (collapsed for any other).
                let showMoreExpanded = (showMoreExpandedState?.messageId == item.message.id) ? (showMoreExpandedState?.value ?? false) : false
                let resolvedContent = ChatMessageRichDataBubbleContentNode.resolvedRichDataContent(item: item, showMoreExpanded: showMoreExpanded)

                if let resolvedContent {
                    #if DEBUG && false
                    let instantPage = InstantPage(blocks: [.thinking(.concat([
                        .textCustomEmoji(fileId: 5384559872899555845, alt: "a"),
                        .plain("Thinking...")
                    ]))], media: [:], isComplete: true, rtl: false, url: "", views: nil)
                    #else
                    let instantPage = resolvedContent.instantPage
                    #endif

                    let webpage = TelegramMediaWebpage(webpageId: EngineMedia.Id(namespace: 0, id: 0), content: .Loaded(TelegramMediaWebpageLoadedContent(
                        url: "",
                        displayUrl: "",
                        hash: 0,
                        type: nil,
                        websiteName: nil,
                        title: nil,
                        text: nil,
                        embedUrl: nil,
                        embedType: nil,
                        embedSize: nil,
                        duration: nil,
                        author: nil,
                        isMediaLargeByDefault: nil,
                        imageIsVideoCover: false,
                        image: nil,
                        file: nil,
                        story: nil,
                        attributes: [],
                        instantPage: instantPage
                    )))
                    pageWebpage = webpage

                    let presentationThemeIdentity = ObjectIdentifier(item.presentationData.theme.theme)
                    let currentMessageStableVersion = item.message.stableVersion
                    let currentPendingEditKey = (item.attributes.updatingMedia?.richText).map({ ObjectIdentifier($0) })
                    if let current = currentPageLayout,
                       current.boundingWidth == suggestedBoundingWidth,
                       current.presentationThemeIdentity == presentationThemeIdentity,
                       current.baseFontSize == baseFontSize,
                       current.expandedDetails == currentExpandedDetails,
                       current.showMoreExpanded == showMoreExpanded,
                       current.messageStableVersion == currentMessageStableVersion,
                       current.pendingEditKey == currentPendingEditKey,
                       current.richPageKey == resolvedContent.key,
                       current.layout.formattedDateUpdatePeriod == nil {
                        // Reuse the cached layout only when it has no relative `textDate`. A relative
                        // date's formatted string ("N minutes ago") is baked into the laid-out text at
                        // layout time, and none of the cache-key inputs change as wall-clock advances —
                        // so reusing it would freeze the date and defeat the refresh timer (which fires
                        // `requestFullUpdate` precisely to re-run `layoutInstantPageV2` → `formatDate`).
                        // Forcing a recompute for relative-date pages keeps the timer's tick visible.
                        pageLayout = current.layout
                    } else {
                        pageLayout = layoutInstantPageV2(
                            webpage: webpage,
                            instantPage: instantPage,
                            userLocation: .other,
                            boundingWidth: suggestedBoundingWidth - 2.0,
                            horizontalInset: pageHorizontalInset,
                            theme: pageTheme,
                            strings: item.presentationData.strings,
                            dateTimeFormat: item.presentationData.dateTimeFormat,
                            cachedMessageSyntaxHighlight: nil,
                            expandedDetails: currentExpandedDetails,
                            fitToWidth: true,
                            computeRevealCharacterRects: hasDraft || hadDraft
                        )
                    }
                }
                
                // Cost map computed here (not in apply) so we can size the bubble to the
                // revealed prefix this layout pass. Mirrors TextBubble's clippedGlyphCountLayout.
                let revealCostMap: InstantPageV2RevealCostMap? = (hasDraft || hadDraft) ? pageLayout?.computeRevealCostMap() : nil
                let revealedGlyphCount: Int? = (hasDraft || hadDraft) ? (currentMaxGlyphCount ?? 0) : nil

                if let pageLayout {
                    let effectiveSize: CGSize
                    if let costMap = revealCostMap, let glyphCount = revealedGlyphCount {
                        effectiveSize = costMap.revealedContentSize(revealedCount: glyphCount, layout: pageLayout)
                    } else {
                        effectiveSize = pageLayout.contentSize
                    }
                    boundingSize.width = effectiveSize.width
                    boundingSize.height = effectiveSize.height
                }

                // Authoritative detector: the bottom-most laid-out item is full-width visual media,
                // so the status becomes an image-style pill overlaid on it (no reserved strip).
                // Captured by the nested measure/apply closures below.
                let mediaStatusFrame: CGRect? = pageLayout.flatMap(lastFullWidthMediaFrame(in:))

                // The hardcoded "Thinking…" header was removed in favor of server-sent
                // InstantPageBlock.thinking blocks (rendered inside the pageView). There is no
                // header strip anymore, so the page content starts at the top of the bubble.
                let streamingHeaderOffset: CGFloat = 0.0

                if hasDraft {
                    // The bubble's bottom inset is supplied by the `statusBottomEdge + 6.0`
                    // max() in the measure closure below — but that branch is gated by
                    // `!hasDraft`, so during streaming the bubble has only its 1pt bottom rim
                    // past `revealedContentSize.height` (= bounds.maxY + closingPad). Without
                    // this, descenders of the last revealed line sit cramped against the
                    // bubble's bottom edge and the bubble visibly grows by 6pt when streaming
                    // ends and the status node fades in. 6pt matches the constant inside the
                    // status max() (which itself tracks `TextBubble`'s `bubbleInsets.bottom`).
                    // `hadDraft && !hasDraft` (the finalize pass) doesn't need this because
                    // `!hasDraft` re-enables the status max(), which supplies the inset for it.
                    boundingSize.height += 6.0
                }

                let message = item.message
                let incoming = isIncoming

                var edited = false
                if item.attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var dateReplies = 0
                var starsCount: Int64?
                var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: item.topMessage)
                if item.message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }

                for attribute in item.message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    } else if let attribute = attribute as? PaidStarsMessageAttribute, item.message.id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        starsCount = attribute.stars.value
                    }
                }

                let dateFormat: MessageTimestampStatusFormat
                if item.presentationData.isPreview {
                    dateFormat = .full
                } else if let subject = item.associatedData.subject, case .messageOptions = subject {
                    dateFormat = .minimal
                } else {
                    dateFormat = .regular
                }
                let dateText = stringForMessageTimestampStatus(context: item.context, message: EngineMessage(item.message), dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: dateFormat, associatedData: item.associatedData)

                let statusType: ChatMessageDateAndStatusType?
                var displayStatus = false
                switch position {
                case let .linear(_, neighbor):
                    if case .None = neighbor {
                        displayStatus = true
                    } else if case .Neighbour(true, _, _) = neighbor {
                        displayStatus = true
                    }
                default:
                    break
                }
                if case let .customChatContents(contents) = item.associatedData.subject {
                    if case .hashTagSearch = contents.kind {
                        displayStatus = true
                    } else {
                        displayStatus = false
                    }
                } else if !item.presentationData.chatBubbleCorners.hasTails {
                    displayStatus = false
                } else if case let .messageOptions(_, _, info) = item.associatedData.subject, case let .link(link) = info, link.isCentered {
                    displayStatus = false
                }
                
                if displayStatus {
                    let outgoingStatus: ChatMessageDateAndStatusOutgoingType
                    if message.flags.contains(.Failed) {
                        outgoingStatus = .Failed
                    } else if (message.flags.isSending && !message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                        outgoingStatus = .Sending
                    } else {
                        outgoingStatus = .Sent(read: item.read)
                    }
                    if mediaStatusFrame != nil {
                        statusType = incoming ? .ImageIncoming : .ImageOutgoing(outgoingStatus)
                    } else {
                        statusType = incoming ? .BubbleIncoming : .BubbleOutgoing(outgoingStatus)
                    }
                } else {
                    statusType = nil
                }

                // Only trail the status inline with the last text line when the bottom-most page
                // item is itself a text item; otherwise (table/image/etc. last) the status falls
                // through to the contentSize.height anchor and sits below all content.
                let lastTextLine = pageLayout.flatMap(InstantPageUI.lastTextLineFrameIfLastItemIsText(in:))
                var lastTextLineFrame: CGRect? = lastTextLine?.frame
                // Baseline → visible-text-bottom compensation. Applied whether the date trails on
                // the last line or wraps onto its own line below it (0 for attachment-inflated lines,
                // whose maxY already sits at the visible bottom).
                var lastTextLineTrailingPadding: CGFloat = lastTextLine?.trailingBottomPadding ?? 0.0

                // "Show more" affordance for partial rich messages: laid out as a bubble-owned text
                // node below the page content. Shown only when the page is incomplete AND the user
                // has not expanded it yet (showMoreExpanded == false), the message is not streaming,
                // it is a Cloud message (requestFullRichText is a no-op otherwise), and we are not in
                // a preview / messageOptions context. When present, the date trails the link's line
                // by substituting its frame for the last-text-line frame the status machinery consumes.
                var showMore = false
                if let attribute = resolvedContent?.originalAttribute,
                   resolvedContent?.isTranslated != true,
                   resolvedContent?.isTranslating != true,
                   !showMoreExpanded,
                   !attribute.instantPage.isComplete,
                   !hasDraft,
                   item.message.id.namespace == Namespaces.Message.Cloud,
                   !item.presentationData.isPreview {
                    if let subject = item.associatedData.subject, case .messageOptions = subject {
                        showMore = false
                    } else {
                        showMore = true
                    }
                }

                var showMoreLayoutResult: (TextNodeLayout, () -> TextNode)?
                var showMoreFramePageLocal: CGRect?
                if showMore, let pageLayout {
                    let title = item.presentationData.strings.Chat_RichText_ShowMore
                    let attributedTitle = NSAttributedString(string: title, font: Font.regular(17.0), textColor: messageTheme.linkTextColor)
                    // The link only fits within the existing bubble width (it does not widen the
                    // bubble the way the status node does); the short fixed string never needs more,
                    // and `.end` truncation is a safe fallback for a pathologically narrow bubble.
                    let constrainedWidth = max(1.0, boundingSize.width - pageHorizontalInset * 2.0)
                    let layout = showMoreTextLayout(TextNodeLayoutArguments(attributedString: attributedTitle, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: 100.0)))
                    let showMoreTopSpacing: CGFloat = 2.0
                    let frame = CGRect(origin: CGPoint(x: pageHorizontalInset, y: pageLayout.contentSize.height + showMoreTopSpacing), size: layout.0.size)
                    showMoreLayoutResult = layout
                    showMoreFramePageLocal = frame
                    // Date trails the link line (or wraps below it if it doesn't fit) — reuse the
                    // status machinery by substituting the link frame for the last-text-line frame.
                    lastTextLineFrame = frame
                    lastTextLineTrailingPadding = 0.0
                    // Ensure the bubble contains the link even when the status node is hidden. The 1.0
                    // is the content top rim; 6.0 the bottom breathing room used elsewhere in this file.
                    boundingSize.height = max(boundingSize.height, 1.0 + frame.maxY + 6.0)
                }

                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageDateAndStatusNode))?
                if let statusType = statusType {
                    var isReplyThread = false
                    if case .replyThread = item.chatLocation {
                        isReplyThread = true
                    }

                    // Measure trailing extent from the line's actual visible RIGHT EDGE (after
                    // alignment, in page coords) — not just its intrinsic width. A right-aligned
                    // or RTL last line has `lineWidth` worth of glyphs but sits all the way at
                    // the right text inset (lineFrame.maxX == text.frame.minX + textItem.width).
                    // Feeding the status node just `lineWidth` would let the trail/wrap decision
                    // place the date inline with the line — on top of it. `pageHorizontalInset`
                    // is the offset between page-coords and status-node-local coords (the status
                    // node sits at x=pageHorizontalInset in self, and pageView sits at self-x 0).
                    let dateLayoutInput: ChatMessageDateAndStatusNode.LayoutInput
                    if mediaStatusFrame != nil {
                        // Overlaid pill: reactions live outside the bubble. Inline reactions, if any,
                        // render inside the pill via reactionSettings — mirroring media messages.
                        let inlineReactionSettings = shouldDisplayInlineDateReactions(message: EngineMessage(item.message), isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.StandaloneReactionSettings() : nil
                        dateLayoutInput = .standalone(reactionSettings: item.presentationData.isPreview ? nil : inlineReactionSettings)
                    } else {
                        let trailingWidthToMeasure: CGFloat = lastTextLineFrame.map { $0.maxX - pageHorizontalInset } ?? 10000.0
                        dateLayoutInput = .trailingContent(contentWidth: trailingWidthToMeasure, reactionSettings: ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: shouldDisplayInlineDateReactions(message: EngineMessage(item.message), isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions), preferAdditionalInset: false))
                    }

                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: item.context,
                        presentationData: item.presentationData,
                        edited: edited && !item.presentationData.isPreview,
                        impressionCount: !item.presentationData.isPreview ? viewCount : nil,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: dateLayoutInput,
                        constrainedSize: CGSize(width: boundingSize.width, height: .greatestFiniteMagnitude),
                        availableReactions: item.associatedData.availableReactions,
                        savedMessageTags: item.associatedData.savedMessageTags,
                        // Empty the status node's own reactions exactly when they are externalized
                        // (wantsReactionsOutside), NOT when the pill is shown — otherwise a structural
                        // "externalize" that the layout declines to pillify (e.g. a narrow collage cell)
                        // would render reactions both inline here AND in the external buttons node. When
                        // the pill IS shown, its `.standalone` input renders no reaction list regardless.
                        reactions: (item.presentationData.isPreview || wantsReactionsOutside) ? [] : dateReactionsAndPeers.reactions,
                        reactionPeers: wantsReactionsOutside ? [] : dateReactionsAndPeers.peers,
                        displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        areReactionsTags: item.topMessage.areReactionsTags(accountPeerId: item.context.account.peerId),
                        areStarReactionsEnabled: item.associatedData.areStarReactionsEnabled,
                        messageEffect: item.topMessage.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects),
                        replyCount: dateReplies,
                        starsCount: starsCount,
                        isPinned: item.message.tags.contains(.pinned) && (!item.associatedData.isInPinnedListMode || isReplyThread),
                        hasAutoremove: item.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: EngineMessage(item.topMessage)),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                }

                if let statusSuggestedWidthAndContinue, !hasDraft, mediaStatusFrame == nil {
                    // Mirrors TextBubble: max(contentWidth, statusWidth + sideInsets), where
                    // sideInsets = left + right text inset (= pageHorizontalInset on each side).
                    // Skipped for the overlaid pill — the media already defines the bubble width.
                    boundingSize.width = max(boundingSize.width, statusSuggestedWidthAndContinue.0 + pageHorizontalInset * 2.0)
                }

                return (boundingSize.width, { boundingWidth in
                    // Non-pill: pass `boundingWidth - sideInsets` (mirrors TextBubble) so the
                    // right-aligned date lands at the right text inset. For the overlaid pill,
                    // pass the status node's own suggested width so its internal `leftOffset`
                    // (= passedWidth - layoutSize.width) is 0 — otherwise the date is shoved right
                    // of its backdrop pill (the pill is anchored at the node's own bounds). This
                    // mirrors ChatMessageInteractiveMediaNode, which calls the continue closure with
                    // the suggested width for the standalone image status.
                    let statusContinueWidth: CGFloat = mediaStatusFrame != nil ? (statusSuggestedWidthAndContinue?.0 ?? 0.0) : (boundingWidth - pageHorizontalInset * 2.0)
                    let statusSizeAndApply = statusSuggestedWidthAndContinue?.1(statusContinueWidth)
                    if let statusSizeAndApply, !hasDraft, mediaStatusFrame == nil {
                        // Status node anchor Y in the content node's space — mirrors the apply
                        // closure below.
                        let statusAnchorY: CGFloat
                        if let lastTextLineFrame {
                            // The renderer draws the baseline at the line frame's maxY, so the
                            // visible text sits `trailingBottomPadding` below it. Apply that pad
                            // whether the date trails on the line OR wraps onto its own line below:
                            // in both cases the date should reference the visible text bottom, not
                            // the baseline (mirrors TextBubble, whose status anchors at the text
                            // frame's maxY). Without it the wrapped date crowded the last line.
                            statusAnchorY = 1.0 + lastTextLineFrame.maxY + lastTextLineTrailingPadding + streamingHeaderOffset
                        } else if let pageLayout {
                            statusAnchorY = 1.0 + pageLayout.contentSize.height + streamingHeaderOffset
                        } else {
                            statusAnchorY = 1.0 + streamingHeaderOffset
                        }
                        // Date's bottom edge: a trailing date sits ~1pt below the anchor; a wrapped
                        // date extends `statusHeight` below it. Leave ~6pt to the bubble's bottom
                        // edge, matching TextBubble's bottom inset.
                        let statusBottomEdge = statusAnchorY + max(1.0, statusSizeAndApply.0.height)
                        boundingSize.height = max(boundingSize.height, statusBottomEdge + 6.0)
                    }

                    return (boundingSize, { animation, _, info in
                        guard let self else {
                            return
                        }
                        self.item = item

                        // If the bubble was recycled onto a different message while a full-text
                        // request was in flight, cancel it so this message never shows another's
                        // shimmer.
                        if let pendingId = self.requestFullRichTextMessageId, pendingId != item.message.id {
                            self.requestFullRichTextDisposable?.dispose()
                            self.requestFullRichTextDisposable = nil
                            self.requestFullRichTextMessageId = nil
                            self.updateShowMoreLoading(false)
                        }

                        // On the collapse→expand transition (tapping "Show more"), grow the bubble
                        // downward in screen space (inverted list offset direction) instead of pushing
                        // earlier messages up — matching the audio-transcription expand. The ListView
                        // clamps this to what fits, so "if possible" is handled for us. Only fires on a
                        // change, and never on the first apply (appliedShowMoreExpanded is nil).
                        if let appliedShowMoreExpanded = self.appliedShowMoreExpanded, appliedShowMoreExpanded != showMoreExpanded {
                            info?.setInvertOffsetDirection()
                        }
                        self.appliedShowMoreExpanded = showMoreExpanded

                        animation.animator.updateFrame(layer: self.containerNode.layer, frame: CGRect(origin: CGPoint(x: 1.0, y: 0.0), size: CGSize(width: boundingWidth - 2.0, height: boundingSize.height)), completion: nil)
                        self.containerNode.cornerRadius = layoutConstants.image.defaultCornerRadius

                        if let statusSizeAndApply {
                            // Match TextBubble: anchor the status node's x at the fixed text-block
                            // left edge (not the last line's minX, which is large for nested
                            // content and shoves the right-aligned date off the bubble). The status
                            // node positions the date trailing/below relative to this origin.
                            let statusFrame: CGRect
                            if let mediaStatusFrame {
                                // Overlaid pill: anchor to the media item's bottom-right corner,
                                // inset by the standard image status insets. page-coord (px,py)
                                // maps to self-coord (px, 1.0 + py).
                                let insets = layoutConstants.image.statusInsets
                                // Full-width flush media frames are widened by instantPageV2MediaEdgeBleed
                                // (4pt) past the visible/clipped right edge; clamp to the content width so
                                // the pill's trailing inset matches image messages (6pt, not 2pt).
                                let visibleMaxX = min(mediaStatusFrame.maxX, pageLayout?.contentSize.width ?? mediaStatusFrame.maxX)
                                let statusX = visibleMaxX - insets.right - statusSizeAndApply.0.width
                                let statusY = 1.0 + mediaStatusFrame.maxY - insets.bottom - statusSizeAndApply.0.height
                                statusFrame = CGRect(origin: CGPoint(x: statusX, y: statusY + streamingHeaderOffset), size: statusSizeAndApply.0)
                            } else {
                                let statusFrameY: CGFloat
                                if let lastTextLineFrame {
                                    // Apply the text-rect pad (baseline → visible text bottom) for both
                                    // the trailing and wrapped cases, so the date references the visible
                                    // text bottom rather than the baseline. Mirrors the measure closure
                                    // and TextBubble. Without it the wrapped date crowded the last line.
                                    statusFrameY = 1.0 + lastTextLineFrame.maxY + lastTextLineTrailingPadding
                                } else if let pageLayout {
                                    statusFrameY = 1.0 + pageLayout.contentSize.height
                                } else {
                                    statusFrameY = 1.0
                                }
                                statusFrame = CGRect(origin: CGPoint(x: pageHorizontalInset, y: statusFrameY + streamingHeaderOffset), size: statusSizeAndApply.0)
                            }
                            let statusNode = statusSizeAndApply.1(self.statusNode == nil ? .None : animation)

                            if self.statusNode !== statusNode {
                                self.statusNode?.removeFromSupernode()
                                self.statusNode = statusNode

                                self.addSubnode(statusNode)

                                statusNode.reactionSelected = { [weak self] _, value, sourceView in
                                    guard let self, let item = self.item else {
                                        return
                                    }
                                    item.controllerInteraction.updateMessageReaction(item.topMessage, .reaction(value), false, sourceView)
                                }
                                statusNode.openReactionPreview = { [weak self] gesture, sourceNode, value in
                                    guard let self, let item = self.item else {
                                        gesture?.cancel()
                                        return
                                    }
                                    item.controllerInteraction.openMessageReactionContextMenu(item.topMessage, sourceNode, gesture, value)
                                }
                                statusNode.frame = statusFrame
                            } else {
                                animation.animator.updatePosition(layer: statusNode.layer, position: statusFrame.center, completion: nil)
                                animation.animator.updateBounds(layer: statusNode.layer, bounds: CGRect(origin: .zero, size: statusFrame.size), completion: nil)
                            }
                        } else if let statusNode = self.statusNode {
                            self.statusNode = nil
                            statusNode.removeFromSupernode()
                        }

                        if let forwardInfo = item.message.forwardInfo, forwardInfo.flags.contains(.isImported), let statusNode = self.statusNode {
                            statusNode.pressed = { [weak self] in
                                guard let self, let statusNode = self.statusNode, let item = self.item else {
                                    return
                                }
                                item.controllerInteraction.displayImportedMessageTooltip(statusNode)
                            }
                        } else {
                            self.statusNode?.pressed = nil
                        }

                        if let pageLayout, let pageWebpage, let resolvedContent {
                            self.currentPageLayout = (
                                suggestedBoundingWidth,
                                ObjectIdentifier(item.presentationData.theme.theme),
                                item.presentationData.fontSize.baseDisplaySize,
                                self.currentExpandedDetails,
                                item.message.stableVersion,
                                (item.attributes.updatingMedia?.richText).map({ ObjectIdentifier($0) }),
                                resolvedContent.key,
                                showMoreExpanded,
                                pageLayout
                            )
                            let pageView = self.ensurePageView(item: item, webpage: pageWebpage, richPageKey: resolvedContent.key, showMoreExpanded: showMoreExpanded)
                            if self.checkboxesInteractive(item: item, resolved: resolvedContent) {
                                pageView.checkboxTapped = { [weak self] path, newValue in
                                    guard let self, let item = self.item else {
                                        return
                                    }
                                    item.controllerInteraction.toggleMessageRichTextCheckbox(item.message.id, path, newValue)
                                }
                            } else {
                                pageView.checkboxTapped = nil
                            }
                            pageView.update(layout: pageLayout, theme: pageTheme, animation: animation)
                            pageView.frame = CGRect(
                                origin: CGPoint(x: -1.0, y: streamingHeaderOffset),
                                size: pageLayout.contentSize
                            )
                            self.updatePageViewVisibilityRect()
                            if self.displayContentsUnderSpoilers {
                                pageView.setDisplayContentsUnderSpoilers(true, atLocation: nil, animated: false)
                            }
                            let showTextAsPlaceholder = item.associatedData.showTextAsPlaceholder
                            var isTranslating = resolvedContent.isTranslating
                            if showTextAsPlaceholder {
                                isTranslating = true
                            }
                            self.updateIsTranslating(isTranslating, showTextAsPlaceholder: showTextAsPlaceholder)
                            // Continue an in-flight anchor scroll that is waiting on a <details>
                            // expansion to re-lay-out. This runs on EVERY apply pass (not only the
                            // expand-triggered one), but only does anything while a scroll is pending
                            // — and scrollToAnchor is idempotent: each invocation either resolves and
                            // scrolls (clearing pending) or expands the next collapsed level, and the
                            // progress guard guarantees termination. So an unrelated relayout (theme,
                            // width, reactions) that lands mid-expand simply advances/no-ops the loop.
                            // Deferred via justDispatch to avoid re-entering layout from this apply.
                            if let pendingAnchor = self.pendingScrollAnchor {
                                Queue.mainQueue().justDispatch { [weak self] in
                                    guard let self, self.pendingScrollAnchor == pendingAnchor else {
                                        return
                                    }
                                    self.scrollToAnchor(pendingAnchor)
                                }
                            }
                        } else {
                            self.currentPageLayout = nil
                            self.updateIsTranslating(false, showTextAsPlaceholder: false)
                            self.pageView?.update(
                                layout: InstantPageV2Layout(contentSize: .zero, items: [], detailsIndices: []),
                                theme: pageTheme,
                                animation: animation
                            )
                            self.pageViewMessageKey = nil
                        }

                        // "Show more" link node.
                        if let showMoreLayoutResult, let showMoreFramePageLocal {
                            let showMoreTextNode = showMoreLayoutResult.1()
                            if self.showMoreTextNode !== showMoreTextNode {
                                self.showMoreTextNode?.removeFromSupernode()
                                self.showMoreTextNode = showMoreTextNode
                                showMoreTextNode.isUserInteractionEnabled = false
                                self.addSubnode(showMoreTextNode)
                            }
                            // Self-coords: the 1.0 mirrors statusFrameY's container offset; the page
                            // content sits 1pt below the content-node top.
                            showMoreTextNode.frame = CGRect(origin: CGPoint(x: pageHorizontalInset, y: 1.0 + showMoreFramePageLocal.minY), size: showMoreFramePageLocal.size)
                            // Keep the shimmer alive across intervening relayouts while loading.
                            if self.requestFullRichTextDisposable != nil, self.requestFullRichTextMessageId == item.message.id {
                                self.updateShowMoreLoading(true)
                            }
                        } else {
                            if let showMoreTextNode = self.showMoreTextNode {
                                self.showMoreTextNode = nil
                                showMoreTextNode.removeFromSupernode()
                            }
                            self.updateShowMoreLoading(false)
                        }

                        if let formattedDateUpdatePeriod = pageLayout?.formattedDateUpdatePeriod {
                            // Recreate the timer only when the period changes — unlike the TextBubble
                            // reference (ChatMessageTextBubbleContentNode), which rebuilds it every apply.
                            // The timer fires `requestFullUpdate`, which relays out and re-enters here; at
                            // a steady period this guard is false, so the running timer keeps its schedule
                            // instead of being reallocated (no per-apply churn, no firing-phase reset, no
                            // self-trigger loop). Do not "simplify" this to match the reference.
                            if self.relativeDateTimer?.period != formattedDateUpdatePeriod {
                                self.relativeDateTimer?.timer.invalidate()
                                let timer = SwiftSignalKit.Timer(timeout: Double(formattedDateUpdatePeriod), repeat: true, completion: { [weak self] in
                                    self?.requestFullUpdate?(ControlledTransition(duration: 0.15, curve: .easeInOut, interactive: false))
                                }, queue: Queue.mainQueue())
                                self.relativeDateTimer = (timer, formattedDateUpdatePeriod)
                                timer.start()
                            }
                        } else if let (timer, _) = self.relativeDateTimer {
                            self.relativeDateTimer = nil
                            timer.invalidate()
                        }

                        // === Streaming state apply ===

                        // 1. Compute / cache the cost map.
                        // Reuse the cost map computed in the layout pass (the bubble's
                        // size depended on it) — don't recompute. Keep the previous map
                        // alive while a reveal/finalize is still in flight: on a post-
                        // streaming pass (hasDraft && hadDraft both false) revealCostMap is
                        // nil, and clobbering it would strand the display-link tick (whose
                        // guard requires a cost map), aborting the finalize before it can
                        // clear the mask and restore the status alpha.
                        if let revealCostMap {
                            self.currentRevealCostMap = revealCostMap
                        } else if self.textRevealController == nil {
                            self.currentRevealCostMap = nil
                        }

                        // 2. Drive the reveal controller.
                        let previousAnimateGlyphCount: Int? = (hasDraft || hadDraft) ? (self.textRevealController?.currentGlyphCount ?? 0) : nil
                        if previousAnimateGlyphCount != nil || self.textRevealController != nil || hasDraft || hadDraft {
                            if hasDraft {
                                self.statusNode?.alpha = 0.0
                            }
                            // Seed the (possibly freshly rebuilt) V2 view to the reveal cursor's
                            // current position so we don't flash full text. Use the live controller
                            // count rather than `previousAnimateGlyphCount`, which is nil — and would
                            // reset the reveal to 0 — on post-streaming finalize passes where the
                            // controller is still animating.
                            let seedCount = self.textRevealController?.currentGlyphCount ?? previousAnimateGlyphCount ?? 0
                            self.pageView?.applyReveal(revealedCount: seedCount,
                                                       costMap: self.currentRevealCostMap,
                                                       animated: false)
                            self.lastAppliedRevealedCount = seedCount
                            self.updateTextRevealAnimation(previousGlyphCount: previousAnimateGlyphCount ?? 0,
                                                           hasDraft: hasDraft,
                                                           hadDraft: hadDraft)
                        }
                    })
                })
            })
        }
    }
    
    private func updateTextRevealAnimation(previousGlyphCount: Int, hasDraft: Bool, hadDraft: Bool) {
        let toCount = self.currentRevealCostMap?.total ?? 0
        let now = CACurrentMediaTime()

        if hasDraft, let controller = self.textRevealController, controller.isFinalizing {
            self.textRevealController = nil
            self.textRevealLink = nil
        }

        if self.textRevealController == nil && (hasDraft || hadDraft) {
            self.textRevealController = TextRevealController(initialRevealedCount: previousGlyphCount, initialLength: toCount, durationMultiplier: 10.0)
        }

        guard let controller = self.textRevealController else { return }

        if hasDraft {
            controller.observeUpdate(latestLength: toCount, at: now)
        } else if hadDraft {
            controller.finalize(finalLength: toCount)
        }

        if controller.isFinalizing && controller.revealedCount >= Double(controller.latestLength) {
            self.textRevealController = nil
            self.textRevealLink = nil
            self.pageView?.applyReveal(revealedCount: nil, costMap: nil, animated: false)
            self.lastAppliedRevealedCount = 0
            // The cursor already caught up at finalize time, so the display-link `isComplete`
            // branch (which normally restores the status alpha) will never run. Restore it
            // here too, mirroring that branch.
            if let item = self.item, let statusNode = self.statusNode,
               !item.message.attributes.contains(where: { $0 is TypingDraftMessageAttribute }) {
                ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut).updateAlpha(node: statusNode, alpha: 1.0)
            }
            return
        }

        guard toCount > 0 else { return }

        if self.textRevealLink == nil {
            self.textRevealLink = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                guard let self else { return }
                guard let item = self.item else {
                    self.textRevealController = nil
                    self.textRevealLink = nil
                    return
                }
                guard let controller = self.textRevealController, let costMap = self.currentRevealCostMap else {
                    self.textRevealLink = nil
                    return
                }
                let now = CACurrentMediaTime()
                let (revealedGlyphCount, isComplete) = controller.tick(now: now)

                if isComplete {
                    self.textRevealController = nil
                    self.textRevealLink = nil
                    self.pageView?.applyReveal(revealedCount: nil, costMap: nil, animated: false)
                    self.lastAppliedRevealedCount = 0

                    if let statusNode = self.statusNode,
                       !item.message.attributes.contains(where: { $0 is TypingDraftMessageAttribute }) {
                        ContainedViewLayoutTransition.animated(duration: 0.2, curve: .easeInOut).updateAlpha(node: statusNode, alpha: 1.0)
                    }
                    self.requestFullUpdate?(ControlledTransition(duration: 0.15, curve: .easeInOut, interactive: false))
                } else {
                    // If the revealed prefix's bottom y would change at the new cursor (i.e.
                    // crossing a line/item boundary), trigger a full bubble re-layout so the
                    // bubble grows with the reveal. Mirrors TextBubble's
                    // `cachedLayout.sizeForCharacterCount(...)` check at lines 1209-1216.
                    var requestUpdate = false
                    if let pageLayout = self.currentPageLayout?.layout, self.lastAppliedRevealedCount != revealedGlyphCount {
                        let prevHeight = costMap.revealedContentSize(revealedCount: self.lastAppliedRevealedCount, layout: pageLayout).height
                        let newHeight = costMap.revealedContentSize(revealedCount: revealedGlyphCount, layout: pageLayout).height
                        if prevHeight != newHeight {
                            requestUpdate = true
                        }
                    }
                    self.pageView?.applyReveal(revealedCount: revealedGlyphCount, costMap: costMap, animated: true)
                    self.lastAppliedRevealedCount = revealedGlyphCount
                    if requestUpdate {
                        self.requestFullUpdate?(ControlledTransition(duration: 0.15, curve: .easeInOut, interactive: false))
                    }
                }
            }
        }
    }

    private func translationShimmerRects(pageView: InstantPageV2View) -> [CGRect] {
        let pageOrigin = pageView.frame.origin
        let entries = pageView.selectableTextItems()
            .filter { $0.item.selectable && !$0.item.attributedString.string.isEmpty }
            .map { entry in
                InstantPageMultiTextAdapter.Entry(
                    item: entry.item,
                    frameOrigin: CGPoint(
                        x: entry.parentOffset.x + pageOrigin.x,
                        y: entry.parentOffset.y + pageOrigin.y
                    )
                )
            }
        guard !entries.isEmpty else {
            return []
        }

        let adapter = InstantPageMultiTextAdapter(entries: entries)
        guard let text = adapter.currentText, text.length > 0, let rects = adapter.textRangeRects(in: NSRange(location: 0, length: text.length))?.rects else {
            return []
        }
        return rects
    }

    private func updateIsTranslating(_ isTranslating: Bool, showTextAsPlaceholder: Bool) {
        guard let item = self.item, let pageView = self.pageView else {
            if let shimmeringNode = self.shimmeringNode {
                self.shimmeringNode = nil
                self.shimmeringNodeIsSkeleton = false
                shimmeringNode.removeFromSupernode()
            }
            return
        }

        var rects = self.translationShimmerRects(pageView: pageView)
        if isTranslating, !rects.isEmpty {
            pageView.isHidden = showTextAsPlaceholder

            let isIncoming = item.message.effectivelyIncoming(item.context.account.peerId)
            let messageTheme = item.presentationData.theme.theme.chat.message
            let color: UIColor
            if showTextAsPlaceholder {
                rects = rects.map { $0.insetBy(dx: 0.0, dy: 6.0 + UIScreenPixel) }
                if rects.count == 2 {
                    rects[0].origin.y += 1.0
                    rects[1].origin.y -= 1.0
                }
                color = isIncoming ? messageTheme.incoming.secondaryTextColor.withMultipliedAlpha(0.25) : messageTheme.outgoing.secondaryTextColor.withMultipliedAlpha(0.25)
            } else if item.presentationData.theme.theme.overallDarkAppearance {
                color = isIncoming ? messageTheme.incoming.primaryTextColor.withAlphaComponent(0.1) : messageTheme.outgoing.primaryTextColor.withAlphaComponent(0.1)
            } else {
                color = isIncoming ? messageTheme.incoming.accentTextColor.withAlphaComponent(0.1) : messageTheme.outgoing.secondaryTextColor.withAlphaComponent(0.1)
            }

            let shimmeringNode: ShimmeringLinkNode
            let isNew: Bool
            if let current = self.shimmeringNode, self.shimmeringNodeIsSkeleton == showTextAsPlaceholder {
                shimmeringNode = current
                isNew = false
            } else {
                self.shimmeringNode?.removeFromSupernode()
                shimmeringNode = ShimmeringLinkNode(color: color, isSkeleton: showTextAsPlaceholder)
                self.shimmeringNode = shimmeringNode
                self.shimmeringNodeIsSkeleton = showTextAsPlaceholder
                self.containerNode.insertSubnode(shimmeringNode, at: 0)
                isNew = true
            }

            shimmeringNode.updateRects(rects, color: color)
            shimmeringNode.frame = self.containerNode.bounds
            shimmeringNode.updateLayout(self.containerNode.bounds.size)
            if isNew {
                shimmeringNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        } else {
            pageView.isHidden = false
            if let shimmeringNode = self.shimmeringNode {
                self.shimmeringNode = nil
                self.shimmeringNodeIsSkeleton = false
                shimmeringNode.alpha = 0.0
                shimmeringNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak shimmeringNode] _ in
                    shimmeringNode?.removeFromSupernode()
                })
            }
        }
    }

    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        if let statusNode = self.statusNode, statusNode.alpha != 0.0 {
            statusNode.layer.animateAlpha(from: 0.0, to: statusNode.alpha, duration: 0.2)
        }
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        if let statusNode = self.statusNode, statusNode.alpha != 0.0 {
            statusNode.layer.animateAlpha(from: 0.0, to: statusNode.alpha, duration: 0.2)
        }
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        if let statusNode = self.statusNode, statusNode.alpha != 0.0 {
            statusNode.layer.animateAlpha(from: statusNode.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if case .tap = gesture {
        } else {
            if let item = self.item, let subject = item.associatedData.subject, case .messageOptions = subject {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
        }

        if case .tap = gesture, let showMoreTextNode = self.showMoreTextNode, showMoreTextNode.frame.contains(point) {
            // Highlight rect in containerNode-local coords (the highlight overlay lives inside
            // containerNode, which sits at self (1, 1); the text node is on self).
            let rects = [showMoreTextNode.frame.offsetBy(dx: -1.0, dy: -1.0)]
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                self?.activateShowMore()
            }), rects: rects)
        }

        if case .tap = gesture, !self.displayContentsUnderSpoilers, let entityHit = self.entityForTapLocation(point), entityHit.attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)] != nil {
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                self?.revealSpoilers(atContentPoint: point)
            }))
        }

        guard let urlHit = self.urlForTapLocation(point) else {
            if let entityHit = self.entityForTapLocation(point), let content = self.entityTapContent(entityHit.attributes) {
                let rects = self.computeHighlightRects(item: entityHit.item, parentOffset: entityHit.parentOffset, localPoint: entityHit.localPoint)
                return ChatMessageBubbleContentTapAction(
                    content: content,
                    rects: rects,
                    activate: self.makeActivate(item: entityHit.item, parentOffset: entityHit.parentOffset, localPoint: entityHit.localPoint)
                )
            }
            return ChatMessageBubbleContentTapAction(content: .none)
        }

        let split = self.splitAnchor(urlHit.urlItem.url)
        if split.base.isEmpty, let anchor = split.anchor {
            // Don't accept intra-message anchor taps while the message is still streaming.
            if let item = self.item, item.message.attributes.contains(where: { $0 is TypingDraftMessageAttribute }) {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
            let rects = self.computeHighlightRects(item: urlHit.item, parentOffset: urlHit.parentOffset, localPoint: urlHit.localPoint)
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                self?.scrollToAnchor(anchor)
            }), rects: rects)
        }
        if let webpage = self.currentLoadedWebpage(), webpage.content.url == split.base, let anchor = split.anchor {
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                self?.scrollToAnchor(anchor)
            }))
        }

        // Default to concealed=true: InstantPageTextItem does not expose a clean
        // "attribute substring with displayed range" API, so we cannot compare
        // displayed text to the resolved URL the way the chat text bubble does.
        // The chat URL handler will show a confirmation when concealed is true
        // and the visible text differs from the destination — safer default.
        let concealed = true
        let url = ChatMessageBubbleContentTapAction.Url(url: urlHit.urlItem.url, concealed: concealed, allowInlineWebpageResolution: urlHit.urlItem.webpageId != nil)
        let rects = self.computeHighlightRects(item: urlHit.item, parentOffset: urlHit.parentOffset, localPoint: urlHit.localPoint)
        
        if let webpageId = urlHit.urlItem.webpageId {
            let split = self.splitAnchor(url.url)
            return ChatMessageBubbleContentTapAction(
                content: .externalInstantPage(url: url, webpageId: webpageId, anchor: split.anchor),
                rects: rects,
                activate: self.makeActivate(item: urlHit.item, parentOffset: urlHit.parentOffset, localPoint: urlHit.localPoint)
            )
        } else {
            return ChatMessageBubbleContentTapAction(
                content: .url(url),
                rects: rects,
                activate: self.makeActivate(item: urlHit.item, parentOffset: urlHit.parentOffset, localPoint: urlHit.localPoint)
            )
        }
    }

    private func textItemAtLocation(_ location: CGPoint) -> (item: InstantPageTextItem, parentOffset: CGPoint)? {
        guard let pageView = self.pageView else { return nil }
        let local = self.view.convert(location, to: pageView)
        return pageView.textItemAt(point: local)
    }

    private func urlForTapLocation(_ point: CGPoint) -> (item: InstantPageTextItem, urlItem: InstantPageUrlItem, parentOffset: CGPoint, localPoint: CGPoint)? {
        guard let pageView = self.pageView else { return nil }
        let local = self.view.convert(point, to: pageView)
        return pageView.urlItemAt(point: local).map {
            (item: $0.item, urlItem: $0.urlItem, parentOffset: $0.parentOffset, localPoint: $0.localPoint)
        }
    }

    private func entityForTapLocation(_ point: CGPoint) -> (item: InstantPageTextItem, parentOffset: CGPoint, localPoint: CGPoint, attributes: [NSAttributedString.Key: Any])? {
        guard let pageView = self.pageView else { return nil }
        let local = self.view.convert(point, to: pageView)
        guard let hit = pageView.textItemAt(point: local) else { return nil }
        let localPoint = CGPoint(x: local.x - hit.parentOffset.x, y: local.y - hit.parentOffset.y)
        guard let (_, attributes) = hit.item.attributesAtPoint(localPoint, orNearest: false) else { return nil }
        return (item: hit.item, parentOffset: hit.parentOffset, localPoint: localPoint, attributes: attributes)
    }

    private func revealSpoilers(atContentPoint point: CGPoint) {
        guard !self.displayContentsUnderSpoilers, let pageView = self.pageView else {
            return
        }
        self.displayContentsUnderSpoilers = true
        let local = self.view.convert(point, to: pageView)
        pageView.setDisplayContentsUnderSpoilers(true, atLocation: local, animated: true)
    }

    private func entityTapContent(_ attributes: [NSAttributedString.Key: Any]) -> ChatMessageBubbleContentTapAction.Content? {
        if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
            return .peerMention(peerId: mention.peerId, mention: mention.mention, openProfile: false)
        } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
            return .textMention(peerName)
        } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
            return .botCommand(botCommand)
        } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
            // Cashtags are carried as a Hashtag attribute (no dedicated cashtag key/tap-action exists);
            // the leading "$" in the string distinguishes them, and the chat hashtag handler searches both.
            return .hashtag(hashtag.peerName, hashtag.hashtag)
        } else if let bankCard = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BankCard)] as? String {
            return .bankCard(bankCard)
        } else if let date = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Date)] as? Int32 {
            // The displayed string is unused downstream (ChatMessageBubbleItemNode matches `.date(date, _)`).
            return .date(date, "")
        }
        return nil
    }

    /// Bridges an InstantPageUrlItem (used by the gallery's caption URL handler) to the
    /// chat layer's URL handler. `concealed: true` matches `tapActionAtPoint` for the same
    /// reason: V2 cannot reliably compare displayed link text to the resolved URL.
    private func openInstantPageUrl(_ url: InstantPageUrlItem) {
        guard let item = self.item else { return }
        item.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(
            url: url.url,
            concealed: true,
            allowInlineWebpageResolution: url.webpageId != nil
        ))
    }

    private func computeHighlightRects(item: InstantPageTextItem, parentOffset: CGPoint, localPoint: CGPoint) -> [CGRect] {
        // Text item returns rects in its local coords; translate back into containerNode-local coords.
        // containerNode is offset by (1, 1) from the bubble-content-node, but the highlight overlay lives
        // *inside* containerNode, so we use layout-coords (= containerNode-local) for the rects.
        let originX = parentOffset.x
        let originY = parentOffset.y
        return item.linkSelectionRects(at: localPoint).map { rect in
            rect.offsetBy(dx: originX, dy: originY)
        }
    }

    private func makeActivate(item: InstantPageTextItem, parentOffset: CGPoint, localPoint: CGPoint) -> (() -> Promise<Bool>?)? {
        return { [weak self, weak item] in
            guard let self else {
                return nil
            }
            let promise = Promise<Bool>()
            self.linkProgressDisposable?.dispose()
            if self.linkProgressRects != nil {
                self.linkProgressRects = nil
                self.updateLinkProgressState()
            }
            self.linkProgressDisposable = (promise.get() |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                guard let self else {
                    return
                }
                let updated: [CGRect]?
                if value, let item {
                    updated = self.computeHighlightRects(item: item, parentOffset: parentOffset, localPoint: localPoint)
                } else {
                    updated = nil
                }
                let changed: Bool
                if let lhs = self.linkProgressRects, let rhs = updated {
                    changed = lhs != rhs
                } else {
                    changed = (self.linkProgressRects == nil) != (updated == nil)
                }
                if changed {
                    self.linkProgressRects = updated
                    self.updateLinkProgressState()
                }
            })
            return promise
        }
    }

    private func updateLinkProgressState() {
        guard let messageItem = self.item else {
            return
        }
        if let rects = self.linkProgressRects, !rects.isEmpty {
            let linkProgressView: TextLoadingEffectView
            if let current = self.linkProgressView {
                linkProgressView = current
            } else {
                linkProgressView = TextLoadingEffectView(frame: CGRect())
                self.linkProgressView = linkProgressView
                self.containerNode.view.addSubview(linkProgressView)
            }
            linkProgressView.frame = self.containerNode.bounds

            let progressColor: UIColor = messageItem.message.effectivelyIncoming(messageItem.context.account.peerId)
                ? messageItem.presentationData.theme.theme.chat.message.incoming.linkHighlightColor
                : messageItem.presentationData.theme.theme.chat.message.outgoing.linkHighlightColor

            linkProgressView.update(color: progressColor, size: self.containerNode.bounds.size, rects: rects)
        } else if let linkProgressView = self.linkProgressView {
            self.linkProgressView = nil
            linkProgressView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak linkProgressView] _ in
                linkProgressView?.removeFromSuperview()
            })
        }
    }

    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let statusNode = self.statusNode, statusNode.supernode != nil, let result = statusNode.hitTest(self.view.convert(point, to: statusNode.view), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
    
    override public func updateTouchesAtPoint(_ point: CGPoint?) {
        guard let messageItem = self.item else {
            return
        }

        var rects: [CGRect]?
        if let point {
            if let showMoreTextNode = self.showMoreTextNode, showMoreTextNode.frame.contains(point) {
                rects = [showMoreTextNode.frame.offsetBy(dx: -1.0, dy: -1.0)]
            } else if let urlHit = self.urlForTapLocation(point) {
                rects = self.computeHighlightRects(item: urlHit.item, parentOffset: urlHit.parentOffset, localPoint: urlHit.localPoint)
            } else if let entityHit = self.entityForTapLocation(point), self.entityTapContent(entityHit.attributes) != nil {
                rects = self.computeHighlightRects(item: entityHit.item, parentOffset: entityHit.parentOffset, localPoint: entityHit.localPoint)
            }
        }

        if let rects, !rects.isEmpty {
            let highlightingNode: LinkHighlightingNode
            if let current = self.linkHighlightingNode {
                highlightingNode = current
            } else {
                let color: UIColor = messageItem.message.effectivelyIncoming(messageItem.context.account.peerId)
                    ? messageItem.presentationData.theme.theme.chat.message.incoming.linkHighlightColor
                    : messageItem.presentationData.theme.theme.chat.message.outgoing.linkHighlightColor
                highlightingNode = LinkHighlightingNode(color: color)
                highlightingNode.useModernPathCalculation = true
                self.linkHighlightingNode = highlightingNode
                self.containerNode.insertSubnode(highlightingNode, at: 0)
            }
            highlightingNode.frame = self.containerNode.bounds
            highlightingNode.updateRects(rects)
        } else if let highlightingNode = self.linkHighlightingNode {
            self.linkHighlightingNode = nil
            highlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak highlightingNode] _ in
                highlightingNode?.removeFromSupernode()
            })
        }
    }
    
    override public func updateSearchTextHighlightState(text: String?, messages: [EngineMessage.Index]?) {
    }
    
    override public func willUpdateIsExtractedToContextPreview(_ value: Bool) {
        if !value, let textSelectionNode = self.textSelectionNode {
            self.textSelectionNode = nil
            self.textSelectionAdapter = nil
            textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                textSelectionNode?.highlightAreaNode.removeFromSupernode()
                textSelectionNode?.removeFromSupernode()
            })
        }
    }

    override public func updateIsExtractedToContextPreview(_ value: Bool) {
        guard value, self.textSelectionNode == nil, let messageItem = self.item, self.currentPageLayout?.layout != nil, let pageView = self.pageView, let rootNode = messageItem.controllerInteraction.chatControllerNode() else {
            return
        }

        // pageView sits at (-1, 0) inside containerNode; the adapter is placed at
        // containerNode.bounds, so shift each item's page-space origin into
        // containerNode-local coords for the adapter to operate in.
        let pageOrigin = pageView.frame.origin
        let entries = pageView.selectableTextItems()
            .filter { $0.item.selectable && !$0.item.attributedString.string.isEmpty }
            .map { entry in
                InstantPageMultiTextAdapter.Entry(
                    item: entry.item,
                    frameOrigin: CGPoint(
                        x: entry.parentOffset.x + pageOrigin.x,
                        y: entry.parentOffset.y + pageOrigin.y
                    )
                )
            }
        guard !entries.isEmpty else {
            return
        }

        let adapter = InstantPageMultiTextAdapter(entries: entries)
        adapter.frame = self.containerNode.bounds
        self.textSelectionAdapter = adapter
        self.containerNode.addSubnode(adapter)

        let incoming = messageItem.message.effectivelyIncoming(messageItem.context.account.peerId)
        let theme = messageItem.presentationData.theme.theme
        let selectionColor = incoming ? theme.chat.message.incoming.textSelectionColor : theme.chat.message.outgoing.textSelectionColor
        let knobColor = incoming ? theme.chat.message.incoming.textSelectionKnobColor : theme.chat.message.outgoing.textSelectionKnobColor

        let textSelectionNode = TextSelectionNode(
            theme: TextSelectionTheme(selection: selectionColor, knob: knobColor, isDark: theme.overallDarkAppearance),
            strings: messageItem.presentationData.strings,
            textNodeOrView: .node(adapter),
            updateIsActive: { _ in },
            present: { [weak self] c, a in
                guard let self, let item = self.item else {
                    return
                }
                if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .reply = info {
                    item.controllerInteraction.presentControllerInCurrent(c, a)
                } else {
                    item.controllerInteraction.presentGlobalOverlayController(c, a)
                }
            },
            rootView: { [weak rootNode] in
                return rootNode?.view
            },
            performAction: { [weak self] text, action in
                guard let self, let item = self.item else {
                    return
                }
                if case .copy = action,
                   let range = self.textSelectionNode?.getSelection(),
                   range.length > 0,
                   let adapter = self.textSelectionAdapter {
                    let markdown = adapter.markdownForRange(range)
                    if !markdown.isEmpty {
                        item.controllerInteraction.performTextSelectionAction(item.message, true, NSAttributedString(string: markdown), nil, .copy)
                        return
                    }
                }
                item.controllerInteraction.performTextSelectionAction(item.message, true, text, nil, action)
            }
        )

        let enableCopy = (!messageItem.associatedData.isCopyProtectionEnabled && !messageItem.message.isCopyProtected()) || messageItem.message.id.peerId.isVerificationCodes
        textSelectionNode.enableCopy = enableCopy

        var enableOtherActions = true
        if let subject = messageItem.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .reply = info {
            enableOtherActions = false
        }

        textSelectionNode.enableQuote = false
        textSelectionNode.enableTranslate = enableOtherActions
        textSelectionNode.enableShare = enableOtherActions && enableCopy
        textSelectionNode.enableLookup = true
        textSelectionNode.menuSkipCoordnateConversion = !enableOtherActions

        textSelectionNode.frame = self.containerNode.bounds
        textSelectionNode.highlightAreaNode.frame = self.containerNode.bounds
        self.containerNode.insertSubnode(textSelectionNode.highlightAreaNode, at: 0)
        self.containerNode.addSubnode(textSelectionNode)
        self.textSelectionNode = textSelectionNode
    }

    override public func transitionNode(messageId: EngineMessage.Id, media: EngineRawMedia, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        // V2 V0: media items render as gray placeholders; no transition node is exposed.
        return nil
    }

    override public func updateHiddenMedia(_ media: [EngineRawMedia]?) -> Bool {
        // V2 V0: media items render as gray placeholders; nothing to hide.
        return false
    }

    override public func getAnchorRect(anchor: String) -> CGRect? {
        guard let pageView = self.pageView, let rect = pageView.anchorFrame(name: anchor) else {
            return nil
        }
        // Small top breathing room so the target isn't flush against the content-area top
        // (cf. V1 InstantPageControllerNode's -10 offset). The chat scroll consumes only the
        // returned rect's minY (ChatController's scrollToMessageIdWithAnchor → .bottom(anchorY)),
        // so pulling minY up by the margin is what lands the anchor below the top edge; the rect
        // is grown to keep maxY stable should a future caller use the full rect (e.g. a highlight).
        let topMargin: CGFloat = 8.0
        let adjusted = CGRect(x: rect.minX, y: max(0.0, rect.minY - topMargin), width: rect.width, height: rect.height + topMargin)
        return self.view.convert(adjusted, from: pageView)
    }

    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if let statusNode = self.statusNode, !statusNode.isHidden {
            return statusNode.reactionView(value: value)
        }
        return nil
    }
    
    override public func messageEffectTargetView() -> UIView? {
        if let statusNode = self.statusNode, !statusNode.isHidden {
            return statusNode.messageEffectTargetView()
        }
        return nil
    }
    
    override public func getStatusNode() -> ASDisplayNode? {
        return self.statusNode
    }

    private func splitAnchor(_ url: String) -> (base: String, anchor: String?) {
        if let anchorRange = url.range(of: "#") {
            let anchor = String(url[anchorRange.upperBound...]).removingPercentEncoding
            let base = String(url[..<anchorRange.lowerBound])
            return (base, anchor)
        }
        return (url, nil)
    }

    private func currentLoadedWebpage() -> TelegramMediaWebpage? {
        return nil   // V2 V0: media items are placeholders; no inline webpage resolution.
    }

    private func scrollToAnchor(_ anchor: String) {
        guard let item = self.item else {
            return
        }
        // Empty fragment ("#") is a no-op.
        if anchor.isEmpty {
            self.clearPendingScroll()
            return
        }
        // 1. Anchor is in the currently laid-out content → scroll now.
        if self.pageView?.anchorFrame(name: anchor) != nil {
            self.clearPendingScroll()
            item.controllerInteraction.scrollToMessageIdWithAnchor(item.message.index, anchor)
            return
        }
        // 2. Not laid out — it may be buried in a collapsed <details>. Find the path and expand
        //    the first collapsed details on it, then retry after the relayout (post-relayout hook).
        let anchorExpanded = (self.showMoreExpanded?.messageId == item.message.id) ? (self.showMoreExpanded?.value ?? false) : false
        guard let resolvedContent = ChatMessageRichDataBubbleContentNode.resolvedRichDataContent(item: item, showMoreExpanded: anchorExpanded),
              let path = instantPageAnchorPath(in: resolvedContent.instantPage, name: anchor),
              !path.isEmpty,
              let collapsedIndex = self.pageView?.firstCollapsedDetails(forOrdinalPath: path)
        else {
            self.clearPendingScroll()
            return
        }
        // Progress guard: if expanding this same index last pass didn't move us forward, stop.
        if self.lastExpandedPendingDetailsIndex == collapsedIndex {
            self.clearPendingScroll()
            return
        }
        self.currentExpandedDetails[collapsedIndex] = true
        self.pendingScrollAnchor = anchor
        self.lastExpandedPendingDetailsIndex = collapsedIndex
        item.controllerInteraction.requestMessageUpdate(item.message.id, false, nil)
    }

    private func clearPendingScroll() {
        self.pendingScrollAnchor = nil
        self.lastExpandedPendingDetailsIndex = nil
    }

    // Fired by the "Show more" tap action. Expands this bubble to the full page: if the attribute
    // already carries a cached fullInstantPage, expands immediately; otherwise fetches it (which
    // persists it onto the message) while shimmering the link, then expands. Guards against a
    // second request while one is in flight, and against re-expanding an already-expanded bubble.
    private func activateShowMore() {
        guard let item = self.item, let attribute = item.message.richText else {
            return
        }
        let messageId = item.message.id
        if let state = self.showMoreExpanded, state.messageId == messageId, state.value {
            return
        }
        // Full page already cached on the attribute — expand immediately, no network, no shimmer.
        if attribute.fullInstantPage != nil {
            self.showMoreExpanded = (messageId, true)
            item.controllerInteraction.requestMessageUpdate(messageId, false, nil)
            return
        }
        // Otherwise fetch it; keep the link visible and shimmering until it arrives.
        if self.requestFullRichTextDisposable != nil {
            return
        }
        self.requestFullRichTextMessageId = messageId
        self.updateShowMoreLoading(true)
        self.requestFullRichTextDisposable = (item.context.engine.messages.requestFullRichText(id: messageId)
        |> deliverOnMainQueue).startStrict(next: { [weak self] result in
            guard let self else {
                return
            }
            if result?.fullInstantPage != nil {
                self.showMoreExpanded = (messageId, true)
            }
            self.finishShowMore()
            if let item = self.item, item.message.id == messageId {
                item.controllerInteraction.requestMessageUpdate(messageId, false, nil)
            }
        }, completed: { [weak self] in
            self?.finishShowMore()
        })
    }

    // Clears the in-flight request state and stops the shimmer. Invoked from both the request's
    // `next` and `completed` handlers (the signal emits one value then completes); idempotent.
    private func finishShowMore() {
        self.requestFullRichTextDisposable?.dispose()
        self.requestFullRichTextDisposable = nil
        self.requestFullRichTextMessageId = nil
        self.updateShowMoreLoading(false)
    }

    // Shows/hides the shimmer over the "Show more" text node. The TextLoadingEffectView masks
    // itself with the text node's own range rects, so it is placed at the text node's frame in
    // self-coordinates (same parent). Removing the text node also removes the shimmer.
    private func updateShowMoreLoading(_ loading: Bool) {
        guard let item = self.item, let showMoreTextNode = self.showMoreTextNode else {
            if let loadingView = self.showMoreLoadingView {
                self.showMoreLoadingView = nil
                loadingView.removeFromSuperview()
            }
            return
        }
        if loading {
            let loadingView: TextLoadingEffectView
            if let current = self.showMoreLoadingView {
                loadingView = current
            } else {
                loadingView = TextLoadingEffectView(frame: CGRect())
                self.showMoreLoadingView = loadingView
                self.view.addSubview(loadingView)
            }
            loadingView.frame = showMoreTextNode.frame
            let color = item.message.effectivelyIncoming(item.context.account.peerId)
                ? item.presentationData.theme.theme.chat.message.incoming.linkTextColor
                : item.presentationData.theme.theme.chat.message.outgoing.linkTextColor
            let title = item.presentationData.strings.Chat_RichText_ShowMore
            loadingView.update(color: color, textNode: showMoreTextNode, range: NSRange(location: 0, length: (title as NSString).length))
        } else if let loadingView = self.showMoreLoadingView {
            self.showMoreLoadingView = nil
            loadingView.removeFromSuperview()
        }
    }
}

private func richDataBlockEndsWithVisualMedia(_ block: InstantPageBlock) -> Bool {
    func captionIsEmpty(_ caption: InstantPageCaption) -> Bool {
        return caption.text == .empty && caption.credit == .empty
    }
    switch block {
    case let .image(_, caption, _, _, _),
         let .video(_, caption, _, _, _),
         let .map(_, _, _, _, caption):
        return captionIsEmpty(caption)
    case let .collage(_, caption),
         let .slideshow(_, caption):
        return captionIsEmpty(caption)
    case let .cover(inner):
        return richDataBlockEndsWithVisualMedia(inner)
    default:
        return false
    }
}
