import Foundation
import LottieSettings
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
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
import WalletContext

public class ChatMessageRichDataBubbleContentNode: ChatMessageBubbleContentNode {
    public final class ContainerNode: ASDisplayNode {
    }

    private enum ResolvedRichDataPageKey: Equatable {
        case pendingEdit(attribute: ObjectIdentifier, page: ObjectIdentifier)
        case translated(language: String, attribute: ObjectIdentifier, page: ObjectIdentifier)
        case original(attribute: ObjectIdentifier, page: ObjectIdentifier)

        /// Which KIND of page this is, with the per-object identities stripped.
        enum CaseTag: Equatable {
            case pendingEdit
            case translated(language: String)
            case original
        }

        /// The full key must NOT be used to detect a content change: it carries `ObjectIdentifier`s
        /// of the attribute and page objects, and a streamed AI chunk produces a fresh
        /// `RichTextMessageAttribute` on every tick — so comparing keys would report a change on
        /// every chunk. Only a move BETWEEN kinds (translate, enter or leave a pending edit) is a
        /// whole-content transition. `language` is part of the tag so that switching between two
        /// translation languages counts as one too.
        var caseTag: CaseTag {
            switch self {
            case .pendingEdit:
                return .pendingEdit
            case let .translated(language, _, _):
                return .translated(language: language)
            case .original:
                return .original
            }
        }
    }

    private struct ResolvedRichDataContent {
        let instantPage: InstantPage
        let originalAttribute: RichTextMessageAttribute?
        let key: ResolvedRichDataPageKey
        let isTranslated: Bool
        let isTranslating: Bool
    }
    
    private let containerNode: ContainerNode
    /// Clips `containerNode` to the bubble's four (possibly unequal, when merged) corner radii —
    /// see `applyContainerCorners`. Created on first layout, since an unloaded node has no layer.
    private var containerCornerMaskLayer: CAShapeLayer?
    public var statusNode: ChatMessageDateAndStatusNode?
    // `init()` may run off the main thread; UIView construction must happen on the main thread.
    // The page view is built lazily inside the apply closure (always main-thread) via ensurePageView().
    private var pageView: InstantPageV2View?
    // The page view being crossfaded OUT by a whole-content update. Kept LIVE rather than replaced
    // by a `snapshotView(afterScreenUpdates:)` replicant, so its inline video keeps playing and its
    // custom-emoji layers keep looping through the fade.
    //
    // At most one is held: a second whole-content update landing mid-fade removes the in-flight one
    // immediately rather than stacking dissolves.
    //
    // It does NOT compete with the incoming view for the media registry: `mediaRegistry` is
    // per-root-view (`rootMediaRegistryHost = self` in InstantPageV2View.init) and every bubble-side
    // lookup — transitionArgsFor, applyHiddenMedia — goes through `self.pageView`, which by then
    // points at the new view. The outgoing view's registry is unreachable, not conflicting.
    private var fadingOutPageView: InstantPageV2View?
    // Tracks the message (id + stableVersion) baked into the current pageView's render context.
    // The synthesized webpage uses a sentinel id (namespace 0, id 0) shared across all richText
    // messages, so we key cache invalidation on the message itself. When the bubble is recycled
    // with a different message we must discard pageView (render context is constructor-fixed).
    // `stableId` (not `id`) is the reuse identity: it is preserved across the Local→Cloud send
    // transition (whereas `id` flips namespace), so the pageView — and its media views' already-
    // rendered pixels — survive send instead of being rebuilt (which caused the media blink). A
    // genuinely recycled bubble carries a different stableId, so recycling still rebuilds.
    // `messageId` is kept only to detect the Local→Cloud id flip, gating the reference refresh.
    private var pageViewMessageKey: (stableId: UInt32, messageId: EngineMessage.Id, stableVersion: UInt32, pendingEditKey: ObjectIdentifier?, richPageKey: ResolvedRichDataPageKey, showMoreExpanded: Bool, structure: Int)?
    // The `InstantPage` last handed to `pageView`, held so a whole-content candidate can be
    // suppressed when the incoming page is structurally AND textually identical to what is already
    // on screen. The case that reaches it in practice is `.pendingEdit -> .original` when the server
    // confirms an edit whose result matches the optimistic local page — a dissolve there would be a
    // flash for nothing. `InstantPage` is a class with a deep `==`, and
    // `RichTextMessageAttribute.instantPage` is a plain stored `let` (no FlatBuffers
    // materialization), so this is a straight structural compare. It runs only on the
    // about-to-crossfade path, never on the hot same-content path.
    private var appliedInstantPage: InstantPage?
    // messageStableVersion is in the cache key because the synthesized instantPage content
    // mutates between streamed AI message chunks (each chunk bumps stableVersion); without
    // this, the cached layout would shadow newly-arrived content during streaming.
    private var currentPageLayout: (boundingWidth: CGFloat,
                                    presentationThemeIdentity: ObjectIdentifier,
                                    // Text Size does not change the theme object, so it needs its own key or a
                                    // size change keeps serving the old layout.
                                    baseFontSize: CGFloat,
                                    expandedDetails: [Int: Bool],
                                    expandedQuotePaths: Set<[Int]>,
                                    messageStableVersion: UInt32,
                                    pendingEditKey: ObjectIdentifier?,
                                    richPageKey: ResolvedRichDataPageKey,
                                    showMoreExpanded: Bool,
                                    codeHighlight: CachedMessageSyntaxHighlight?,
                                    layout: InstantPageV2Layout)?
    private var currentExpandedDetails: [Int: Bool] = [:]
    /// Quotes the reader expanded, keyed by structural block path. Lives on the content node, so
    /// scrolling away and back re-collapses — matching ChatMessageTextBubbleContentNode's
    /// `expandedBlockIds`. Path-keyed rather than ordinal: AI streaming appends blocks, which would
    /// shift ordinals under the state.
    private var currentExpandedQuotePaths: Set<[Int]> = Set()
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

    /// Drops every piece of node state derived from the OUTGOING page's layout. Called when a
    /// whole-content update rebuilds `pageView`: each of these holds page-space geometry or block
    /// indices that no longer refer to anything in the new page.
    ///
    /// `currentExpandedDetails` is deliberately NOT reset. It is keyed by details index and read by
    /// the LAYOUT pass, which runs before apply — clearing it here would need an extra relayout
    /// round-trip to take effect, and carrying an expand state onto a same-indexed details block
    /// reads as reasonable rather than wrong.
    private func resetPageDerivedState() {
        // Built from the old view's `selectableTextItems()`; its rects are in the old page's
        // coordinate space.
        self.tearDownTextSelection(animated: false)
        self.linkProgressDisposable?.dispose()
        self.linkProgressDisposable = nil
        if self.linkProgressRects != nil {
            self.linkProgressRects = nil
            self.updateLinkProgressState()
        }
        // Clears `linkHighlightingNode` through its own animated teardown.
        self.updateTouchesAtPoint(nil)
        // An in-flight anchor scroll targets blocks that no longer exist.
        self.pendingScrollAnchor = nil
        self.lastExpandedPendingDetailsIndex = nil
        // Defensive: streaming is exempt from whole-content updates, so these are already inert.
        self.currentRevealCostMap = nil
        self.lastAppliedRevealedCount = 0
    }

    /// Fades `outgoing` out and hands it to `fadingOutPageView` for the duration. Durations match
    /// `ChatMessageTextBubbleContentNode`'s plain-text content swap (0.12s out / 0.1s in, started
    /// together), so a message that changes between rich and plain dissolves identically either way.
    ///
    /// No clipping work is needed here: `containerNode.clipsToBounds` is already true and the corner
    /// mask lives on `containerNode`, so a shrinking bubble clips the outgoing view for free while
    /// its own resize animation runs underneath.
    private func beginCrossfadeOut(_ outgoing: InstantPageV2View) {
        // Only one dissolve at a time.
        if let previous = self.fadingOutPageView {
            self.fadingOutPageView = nil
            previous.removeFromSuperview()
        }
        // Inert for input and for VoiceOver, but still animating visually.
        outgoing.isUserInteractionEnabled = false
        outgoing.accessibilityElementsHidden = true
        self.fadingOutPageView = outgoing
        // The incoming view is added via addSubview and therefore lands on top; bring the outgoing
        // one forward so it is the layer fading out over the new content, matching TextBubble.
        outgoing.superview?.bringSubviewToFront(outgoing)
        outgoing.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak self, weak outgoing] _ in
            guard let outgoing else {
                return
            }
            if let self, self.fadingOutPageView === outgoing {
                self.fadingOutPageView = nil
            }
            outgoing.removeFromSuperview()
        })
    }

    required public init(lottieSettings: LottieRenderingSettings) {
        self.containerNode = ContainerNode()
        self.containerNode.clipsToBounds = true

        super.init(lottieSettings: lottieSettings)

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

    /// The message-scoped media-reference closures for the render context. Extracted so the
    /// initial build and the Local→Cloud reference refresh construct identical closures.
    private static func mediaReferenceClosures(messageReference: MessageReference) -> (image: (TelegramMediaImage) -> ImageMediaReference, file: (TelegramMediaFile) -> FileMediaReference) {
        return (
            image: { image in ImageMediaReference.message(message: messageReference, media: image) },
            file: { file in FileMediaReference.message(message: messageReference, media: file) }
        )
    }

    /// Whether this message's media must be screenshot-protected, matching
    /// `ChatMessageInteractiveMediaNode`'s rule for regular media messages (its third disjunct,
    /// extended/paid media, cannot occur inside a rich message). Recomputed on every apply rather
    /// than captured once: `isCopyProtectionEnabled` is a peer setting that can flip while the
    /// bubble is on screen.
    private static func isCaptureProtected(item: ChatMessageBubbleContentItem) -> Bool {
        return item.associatedData.isCopyProtectionEnabled || item.message.isCopyProtected()
    }

    /// Builds (or reuses) the V2View. Same-message stableVersion bumps (streamed AI chunks) reuse
    /// the existing view, updating only the webpage content in place. The view is rebuilt when the
    /// bubble is recycled with a genuinely different message (different `stableId`), and — since
    /// the whole-content split — when the SAME message's content is wholly replaced.
    private func ensurePageView(
        item: ChatMessageBubbleContentItem,
        webpage: TelegramMediaWebpage,
        page: InstantPage,
        richPageKey: ResolvedRichDataPageKey,
        showMoreExpanded: Bool,
        structure: Int,
        isStreaming: Bool,
        animation: ListViewItemUpdateAnimation
    ) -> InstantPageV2View {
        // Set only by the whole-content branch below; read by the rebuild tail. This cannot be
        // inferred from `self.fadingOutPageView != nil` — a dissolve from a PREVIOUS update can
        // still be in flight when a scroll recycle rebuilds for a different message, which would
        // fade the recycled bubble in for no reason.
        var crossfadeIn = false

        // Copy protection is a peer setting that can flip without any of the keys below changing,
        // so refresh it up front — ahead of every reuse branch, including the early returns. The
        // rebuild path picks the same value up through the render context's initializer.
        self.pageView?.renderContext?.updateCaptureProtected(ChatMessageRichDataBubbleContentNode.isCaptureProtected(item: item))

        let key = (stableId: item.message.stableId, messageId: item.message.id, stableVersion: item.message.stableVersion, pendingEditKey: (item.attributes.updatingMedia?.richText).map({ ObjectIdentifier($0) }), richPageKey: richPageKey, showMoreExpanded: showMoreExpanded, structure: structure)
        if let existing = self.pageView, let current = self.pageViewMessageKey, current.stableId == key.stableId {
            if current.stableVersion == key.stableVersion && current.messageId == key.messageId && current.pendingEditKey == key.pendingEditKey && current.richPageKey == key.richPageKey && current.showMoreExpanded == key.showMoreExpanded {
                // `structure` is not compared here: `richPageKey` carries the page object's
                // ObjectIdentifier, so an equal key already implies the same page and therefore
                // the same structure.
                return existing
            }

            // A whole-content update replaces the document rather than editing it. Diffing into the
            // existing view would reuse item views positionally — a paragraph view at position 3
            // rendering whatever unrelated block now occupies position 3 — so the view is rebuilt.
            let isLocalToCloudFlip = current.messageId != key.messageId
            let isWholeContentUpdate =
                   animation.isAnimated                                          // nothing to show otherwise
                && !isStreaming                                                  // streamed chunk: exempt
                && !isLocalToCloudFlip                                           // send flip: exempt
                && (   current.richPageKey.caseTag != key.richPageKey.caseTag    // translate / pending edit
                    || current.showMoreExpanded    != key.showMoreExpanded       // "show more"
                    || current.structure           != key.structure)             // block shape
                // Suppress the no-op confirmation: `.pendingEdit -> .original` where the server's
                // result matches the optimistic local page already on screen.
                && !(self.appliedInstantPage.flatMap({ $0 == page }) ?? false)

            if !isWholeContentUpdate {
                // Same logical message (stableId), same document. Two sub-cases:
                //  - messageId unchanged (streamed AI chunk / pending edit): swap only the webpage;
                //    the construction-time reference snapshot stays valid (media resolves by id). The
                //    subsequent pageView.update(layout:) diffs item views by stable id, so content
                //    blocks keep their views + in-flight reveal state (only added/removed blocks
                //    change) — eliminating the per-chunk full-text-then-mask flash.
                //  - messageId changed (Local→Cloud send flip): also refresh the render context's
                //    MessageReference + reference closures, so live consumers (inline video/audio/
                //    gallery) use the Cloud reference. The reused media VIEWS keep their init-time
                //    (local) reference — their bytes are already local, so the poster does not reload
                //    and there is no blink; a later scroll-recycle rebuilds them against the Cloud ref.
                if isLocalToCloudFlip {
                    let messageReference = MessageReference(item.message)
                    let closures = ChatMessageRichDataBubbleContentNode.mediaReferenceClosures(messageReference: messageReference)
                    existing.renderContext?.updateContent(webpage: webpage, message: messageReference, imageReference: closures.image, fileReference: closures.file)
                } else {
                    existing.renderContext?.updateContent(webpage: webpage)
                }
                self.pageViewMessageKey = key
                self.appliedInstantPage = page
                return existing
            }

            self.resetPageDerivedState()
            self.beginCrossfadeOut(existing)
            crossfadeIn = true
            // `beginCrossfadeOut` took ownership of the outgoing view, so clear the slot before the
            // rebuild below to keep its `removeFromSuperview()` from tearing down the fading view.
            self.pageView = nil
            // Falls through to the rebuild below, which fades the new view in.
        }
        self.pageView?.removeFromSuperview()
        self.pageView = nil

        // Abandon any dissolve still in flight when this rebuild is NOT a crossfade: the bubble is
        // now showing a different message, so finishing the previous message's fade would leave
        // content on screen that no longer belongs to it.
        if !crossfadeIn, let previous = self.fadingOutPageView {
            self.fadingOutPageView = nil
            previous.removeFromSuperview()
        }

        // Capture only the MessageReference (value type) — the closures are retained on the
        // render context which is owned by the V2View, so we must avoid making them retain
        // the bubble (`self`) or the message indirectly via `item`.
        let messageReference = MessageReference(item.message)
        let closures = ChatMessageRichDataBubbleContentNode.mediaReferenceClosures(messageReference: messageReference)
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
            imageReference: closures.image,
            fileReference: closures.file,
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
            wallpaperBackgroundNode: { [weak self] in
                return self?.item?.controllerInteraction.presentationContext.backgroundNode
            },
            captureProtected: ChatMessageRichDataBubbleContentNode.isCaptureProtected(item: item),
            message: messageReference
        )
        let view = InstantPageV2View(renderContext: renderContext)
        self.pageView = view
        self.pageViewMessageKey = key
        self.appliedInstantPage = page
        self.containerNode.view.addSubview(view)
        if crossfadeIn {
            view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
        }
        view.unsupportedActionTapped = { [weak self] in
            guard let item = self?.item else {
                return
            }
            item.controllerInteraction.openAppStorePage()
        }
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
    
    /// The syntax-highlight job in flight for this node, so an identical spec set is not re-run on every
    /// layout pass. Mirrors `ChatMessageTextBubbleContentNode.codeHighlightState`.
    private var codeHighlightState: (id: EngineMessage.Id, specs: [CachedMessageSyntaxHighlight.Spec], disposable: MetaDisposable)?

    deinit {
        self.codeHighlightState?.disposable.dispose()
        self.linkProgressDisposable?.dispose()
        self.relativeDateTimer?.timer.invalidate()
        self.requestFullRichTextDisposable?.dispose()
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let previousItem = self.item
        let currentPageLayout = self.currentPageLayout
        let currentExpandedDetails = self.currentExpandedDetails
        let currentExpandedQuotePaths = self.currentExpandedQuotePaths
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
            // The bubble's header (author name, "Forwarded from", reply) ends in an overlap that
            // assumes the content below brings its own top inset, as a text bubble does. A page that
            // opens with text does (its leading padding); one that opens flush — a photo, a code
            // band, a file row — brings none and would run into the header. Such a page takes the
            // media bubble's spacing, so with both inset 2pt a photo here sits exactly where a photo
            // message's does.
            let headerSpacingShowMoreExpanded = (showMoreExpandedState?.messageId == item.message.id) ? (showMoreExpandedState?.value ?? false) : false
            var headerSpacing: CGFloat = 0.0
            if let resolvedContent = ChatMessageRichDataBubbleContentNode.resolvedRichDataContent(item: item, showMoreExpanded: headerSpacingShowMoreExpanded), instantPageV2ContentStartsFlushAtTop(resolvedContent.instantPage.blocks) {
                headerSpacing = 7.0
            }
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: headerSpacing, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none, wantsReactionsOutside: wantsReactionsOutside)

            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let suggestedBoundingWidth: CGFloat = constrainedSize.width

                var boundingSize = CGSize(width: suggestedBoundingWidth, height: 0.0)

                /// Syntax-highlight specs for this message's code blocks, and the answer already stored
                /// on the message. Declared HERE, in the measure scope the apply closure captures, so the
                /// apply step can drive the async job from them.
                var codeHighlightSpecs: [CachedMessageSyntaxHighlight.Spec] = []
                var cachedMessageSyntaxHighlight: CachedMessageSyntaxHighlight?
                var pageLayout: InstantPageV2Layout?
                // Built alongside pageLayout so the apply closure can hand it to ensurePageView.
                var pageWebpage: TelegramMediaWebpage?
                // Shape-only fingerprint of the resolved page, decided in the layout pass (pure,
                // safe off-main, one tree walk against a pass already O(page)) and consumed by
                // `ensurePageView` in apply.
                var pageStructure: Int = 0
                var pageResolvedInstantPage: InstantPage?

                // The page's text left edge in THIS node's coordinate space — the status node's left
                // edge + side inset, mirroring TextBubble's bubbleInsets. The page itself is inset by
                // `pageContentInset` (below), so the value handed to the layout is smaller by that
                // much; these two must not be conflated, or the status and date drift off the text.
                let pageHorizontalInset: CGFloat = 11.0

                // The whole page is inset by this much on all four sides, so full-width media sits
                // INSIDE the bubble background (corners clipped by the rounded container) instead of
                // running under it — matching how a regular media bubble insets its image. The page
                // gives the same amount back out of its own insets (`horizontalInset` here,
                // `edgeSpacingReduction` vertically), so every block keeps its absolute position and
                // the bubble keeps its size.
                //
                // It is 2, not 1, because THIS NODE'S BOUNDS ARE 1pt LARGER THAN THE BACKGROUND on
                // each side: the first point only reaches the background edge (which is why the old
                // container sat at x = 1 and read as flush), and the second is the visible inset.
                // Measure any change to this against the background, not against these bounds.
                let pageContentInset: CGFloat = 2.0

                // The text inset INSIDE the page — what the layout is given, and the origin that
                // page-space frames are measured from. Smaller than `pageHorizontalInset` by the
                // inset, so that text still lands at `pageHorizontalInset` in this node's space.
                let pageLayoutHorizontalInset: CGFloat = pageHorizontalInset - pageContentInset

                let isDark = item.presentationData.theme.theme.overallDarkAppearance
                let isIncoming = item.message.effectivelyIncoming(item.context.account.peerId)
                let messageTheme = isIncoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                // Service-message colours for the unsupported-content pill, so a pill inside this
                // bubble matches the standalone unsupported bubble rather than the bubble's palette.
                let serviceColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
                
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

                }
                
                let _ = secondaryColor
                let _ = tertiaryColor
                
                let _ = codeBlockTitleColor
                let _ = codeBlockAccentColor
                
                let textCategories = InstantPageTextCategories.chatMessage(
                    primaryText: messageTheme.primaryTextColor,
                    secondaryText: messageTheme.secondaryTextColor
                )
                let tableHeaderColor = isDark || !isIncoming ? messageTheme.accentControlColor.withMultipliedAlpha(0.1) : UIColor(white: 0.0, alpha: 0.05)
                
                let checkboxFill = isIncoming ? item.presentationData.theme.theme.list.itemCheckColors.fillColor : messageTheme.accentControlColor
                var checkboxForeground = isIncoming ? item.presentationData.theme.theme.list.itemCheckColors.foregroundColor : item.presentationData.theme.theme.list.itemCheckColors.foregroundColor
                if isDark && checkboxForeground == checkboxFill {
                    checkboxForeground = messageTheme.mediaControlInnerBackgroundColor
                }
                
                // Incoming bubbles are neutral, so a 15% tint with a full-strength label reads fine.
                // Outgoing bubbles can be saturated (Day Blue), where the tint mixes into the bubble
                // colour and the label loses contrast, so there the fill is solid with a white label,
                // as the message's inline keyboard buttons (ChatButtonKeyboardInputNode) draw them.
                let buttonDangerColor = item.presentationData.theme.theme.contextMenu.destructiveColor
                let buttonSuccessColor = item.presentationData.theme.theme.list.freeTextSuccessColor
                let buttonDangerBackgroundColor = isIncoming ? buttonDangerColor.withMultipliedAlpha(0.15) : buttonDangerColor
                let buttonDangerForegroundColor = isIncoming ? buttonDangerColor : UIColor.white
                let buttonSuccessBackgroundColor = isIncoming ? buttonSuccessColor.withMultipliedAlpha(0.15) : buttonSuccessColor
                let buttonSuccessForegroundColor = isIncoming ? buttonSuccessColor : UIColor.white
                
                let pageTheme = InstantPageTheme(
                    type: isDark ? .dark : .light,
                    pageBackgroundColor: .clear,
                    textCategories: textCategories,
                    serif: false,
                    // A code block reads as a highlighted table row, not as an accent-tinted quote
                    // — the same fill a filled table cell gets. (V1 Instant View still reads this
                    // field for its own gray box; only the value THIS host passes changes.)
                    codeBlockBackgroundColor: tableHeaderColor,
                    linkColor: messageTheme.linkTextColor,
                    textHighlightColor: messageTheme.accentTextColor.withMultipliedAlpha(0.1),
                    linkHighlightColor: messageTheme.linkTextColor.withMultipliedAlpha(0.1),
                    markerColor: UIColor(rgb: 0xfef3bc),
                    panelBackgroundColor: messageTheme.accentControlColor.withMultipliedAlpha(0.1),
                    panelHighlightedBackgroundColor: messageTheme.accentControlColor.withMultipliedAlpha(0.8),
                    panelPrimaryColor: messageTheme.primaryTextColor,
                    panelSecondaryColor: messageTheme.secondaryTextColor,
                    panelAccentColor: messageTheme.accentTextColor,
                    tableBorderColor: isDark || !isIncoming ? messageTheme.accentControlColor.withMultipliedAlpha(0.25) : UIColor(white: 0.0, alpha: 0.1),
                    tableHeaderColor: tableHeaderColor,
                    controlColor: messageTheme.accentControlColor,
                    imageTintColor: nil,
                    overlayPanelColor: isDark ? UIColor(white: 0.0, alpha: 0.13) : UIColor(white: 1.0, alpha: 0.13),
                    separatorColor: messageTheme.secondaryTextColor.mixedWith(mainColor.withMultipliedAlpha(0.2), alpha: 0.3),
                    secondaryControlColor: messageTheme.secondaryTextColor.mixedWith(mainColor.withMultipliedAlpha(0.2), alpha: 0.3),
                    quoteAccentColor: mainColor,
                    buttonDangerBackgroundColor: buttonDangerBackgroundColor,
                    buttonDangerForegroundColor: buttonDangerForegroundColor,
                    buttonSuccessBackgroundColor: buttonSuccessBackgroundColor,
                    buttonSuccessForegroundColor: buttonSuccessForegroundColor,
                    checkboxFill: checkboxFill,
                    checkboxForeground: checkboxForeground,
                    neutralButtonBackgroundColor: tableHeaderColor,
                    neutralButtonForegroundColor: isIncoming ? messageTheme.primaryTextColor : messageTheme.accentControlColor,
                    unsupportedPillFillColor: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper),
                    unsupportedPillPrimaryColor: serviceColor.primaryText
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
                    pageStructure = instantPageStructureFingerprint(instantPage)
                    pageResolvedInstantPage = instantPage

                    // The code in a RICH message lives in InstantPageBlock.preformatted, not in a `.Pre`
                    // entity, so the entity-based `extractMessageSyntaxHighlightSpecs` the text bubble
                    // uses cannot see it — this walks the page instead. Declared in the outer scope
                    // (beside `pageLayout`) because the APPLY closure drives the job from them.
                    codeHighlightSpecs = instantPageSyntaxHighlightSpecs(for: instantPage.blocks)
                    if !codeHighlightSpecs.isEmpty {
                        for attribute in item.message.attributes {
                            if let attribute = attribute as? DerivedDataMessageAttribute {
                                if let value = attribute.data["code"]?.get(CachedMessageSyntaxHighlight.self) {
                                    cachedMessageSyntaxHighlight = value
                                }
                            }
                        }
                    }

                    let presentationThemeIdentity = ObjectIdentifier(item.presentationData.theme.theme)
                    // Settings ▸ Appearance ▸ Text Size (bugs.telegram.org/c/62776). A rich message is a
                    // bubble like any other, so the whole page — fonts and the geometry tuned against them —
                    // scales by the same step a plain bubble's `messageFont` takes. The theme above stays
                    // authored at 17pt; the renderer applies the scale once.
                    let baseFontSize = item.presentationData.fontSize.baseDisplaySize
                    let currentMessageStableVersion = item.message.stableVersion
                    let currentPendingEditKey = (item.attributes.updatingMedia?.richText).map({ ObjectIdentifier($0) })
                    if let current = currentPageLayout,
                       current.boundingWidth == suggestedBoundingWidth,
                       current.presentationThemeIdentity == presentationThemeIdentity,
                       current.baseFontSize == baseFontSize,
                       current.expandedDetails == currentExpandedDetails,
                       current.expandedQuotePaths == currentExpandedQuotePaths,
                       current.showMoreExpanded == showMoreExpanded,
                       current.messageStableVersion == currentMessageStableVersion,
                       current.pendingEditKey == currentPendingEditKey,
                       current.richPageKey == resolvedContent.key,
                       // LOAD-BEARING. The guard keys on `messageStableVersion`, and whether a
                       // `storeLocallyDerivedData` write bumps that is Postbox's business, not this
                       // node's. Without this clause a newly-arrived highlight could be computed,
                       // persisted, and never painted, because the node would keep serving the layout it
                       // cached before the job finished.
                       current.codeHighlight == cachedMessageSyntaxHighlight,
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
                            horizontalInset: pageLayoutHorizontalInset,
                            theme: pageTheme,
                            strings: item.presentationData.strings,
                            dateTimeFormat: item.presentationData.dateTimeFormat,
                            cachedMessageSyntaxHighlight: cachedMessageSyntaxHighlight,
                            expandedDetails: currentExpandedDetails,
                            expandedQuotePaths: currentExpandedQuotePaths,
                            fitToWidth: true,
                            computeRevealCharacterRects: hasDraft || hadDraft,
                            edgeSpacingReduction: pageContentInset,
                            contentScale: instantPageChatMessageContentScale(baseFontSize: baseFontSize)
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
                    // The page is inset on every side, so the bubble is its content plus the two
                    // rims. Both axes cancel the trims above (`horizontalInset` is 1pt smaller and
                    // `layoutTextItem` reserves the right margin as `maxX + horizontalInset`;
                    // `edgeSpacingReduction` takes 1pt off each vertical edge), so the bubble ends up
                    // exactly the size it was before the inset.
                    boundingSize.width = effectiveSize.width + pageContentInset * 2.0
                    boundingSize.height = effectiveSize.height + pageContentInset * 2.0
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
                    // The link is body text, so it takes the body size the page was just laid out at.
                    let attributedTitle = NSAttributedString(string: title, font: Font.regular(item.presentationData.fontSize.baseDisplaySize), textColor: messageTheme.linkTextColor)
                    // The link only fits within the existing bubble width (it does not widen the
                    // bubble the way the status node does); the short fixed string never needs more,
                    // and `.end` truncation is a safe fallback for a pathologically narrow bubble.
                    let constrainedWidth = max(1.0, boundingSize.width - pageHorizontalInset * 2.0)
                    let layout = showMoreTextLayout(TextNodeLayoutArguments(attributedString: attributedTitle, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: constrainedWidth, height: 100.0)))
                    let showMoreTopSpacing: CGFloat = 2.0
                    // Page-space, matching the other frames assigned to `lastTextLineFrame` below —
                    // the node itself is still placed at `pageHorizontalInset` in self-space.
                    let frame = CGRect(origin: CGPoint(x: pageLayoutHorizontalInset, y: pageLayout.contentSize.height + showMoreTopSpacing), size: layout.0.size)
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
                    // is where the text lands in self-coords; `pageLayoutHorizontalInset` is the same
                    // edge in page-coords (the status node sits at x=pageHorizontalInset in self, and
                    // the pageView sits at self-x `pageContentInset` inside containerNode).
                    let dateLayoutInput: ChatMessageDateAndStatusNode.LayoutInput
                    if mediaStatusFrame != nil {
                        // Overlaid pill: reactions live outside the bubble. Inline reactions, if any,
                        // render inside the pill via reactionSettings — mirroring media messages.
                        let inlineReactionSettings = shouldDisplayInlineDateReactions(message: EngineMessage(item.message), isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.StandaloneReactionSettings() : nil
                        dateLayoutInput = .standalone(reactionSettings: item.presentationData.isPreview ? nil : inlineReactionSettings)
                    } else {
                        let trailingWidthToMeasure: CGFloat = lastTextLineFrame.map { $0.maxX - pageLayoutHorizontalInset } ?? 10000.0
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
                        
                        self.containerNode.layer.cornerCurve = .circular

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

                        // Inset on all four sides — `boundingWidth` is the FINAL bubble width handed
                        // back by the bubble layout (it can exceed the width this node proposed), so
                        // the width term is relative to the bubble, not to the page.
                        animation.animator.updateFrame(layer: self.containerNode.layer, frame: CGRect(origin: CGPoint(x: pageContentInset, y: pageContentInset), size: CGSize(width: boundingWidth - pageContentInset * 2.0, height: boundingSize.height - pageContentInset * 2.0)), completion: nil)
                        // Four independent radii, because a merged bubble does not have one: a message
                        // grouped with the one above gets small top corners and full-size bottom ones.
                        // `chatMessageBubbleImageContentCorners` is the same helper the media bubble
                        // uses, so rich bubbles round exactly like a photo in the same merge position.
                        // `position` is already handed to this layout closure — the merge geometry
                        // needed no new plumbing from the bubble.
                        //
                        // A single `cornerRadius` cannot express this, so the container is masked by a
                        // path instead. Each radius is reduced by the inset to stay concentric with the
                        // bubble's own curve.
                        let imageCorners = chatMessageBubbleImageContentCorners(
                            relativeContentPosition: position,
                            normalRadius: layoutConstants.image.defaultCornerRadius,
                            mergedRadius: layoutConstants.image.mergedCornerRadius,
                            mergedWithAnotherContentRadius: layoutConstants.image.contentMergedCornerRadius,
                            layoutConstants: layoutConstants,
                            chatPresentationData: item.presentationData
                        )
                        self.applyContainerCorners(imageCorners, inset: pageContentInset, animation: animation)

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

                        // Kick the highlight job for any spec set we do not already have an answer for.
                        // Persisting mutates the message, which re-lays-out this bubble into a cache hit.
                        // Mirrors ChatMessageTextBubbleContentNode's codeHighlightState loop.
                        if !codeHighlightSpecs.isEmpty {
                            if let current = self.codeHighlightState, current.id == item.message.id, current.specs == codeHighlightSpecs {
                            } else {
                                if let codeHighlightState = self.codeHighlightState {
                                    self.codeHighlightState = nil
                                    codeHighlightState.disposable.dispose()
                                }
                                let disposable = MetaDisposable()
                                self.codeHighlightState = (item.message.id, codeHighlightSpecs, disposable)
                                disposable.set(asyncUpdateMessageSyntaxHighlight(engine: item.context.engine, messageId: item.message.id, current: cachedMessageSyntaxHighlight, specs: codeHighlightSpecs).startStrict(completed: {
                                }))
                            }
                        } else if let codeHighlightState = self.codeHighlightState {
                            self.codeHighlightState = nil
                            codeHighlightState.disposable.dispose()
                        }

                        if let pageLayout, let pageWebpage, let resolvedContent {
                            self.currentPageLayout = (
                                suggestedBoundingWidth,
                                ObjectIdentifier(item.presentationData.theme.theme),
                                item.presentationData.fontSize.baseDisplaySize,
                                self.currentExpandedDetails,
                                self.currentExpandedQuotePaths,
                                item.message.stableVersion,
                                (item.attributes.updatingMedia?.richText).map({ ObjectIdentifier($0) }),
                                resolvedContent.key,
                                showMoreExpanded,
                                cachedMessageSyntaxHighlight,
                                pageLayout
                            )
                            let pageView = self.ensurePageView(
                                item: item,
                                webpage: pageWebpage,
                                page: pageResolvedInstantPage ?? resolvedContent.instantPage,
                                richPageKey: resolvedContent.key,
                                showMoreExpanded: showMoreExpanded,
                                structure: pageStructure,
                                isStreaming: hasDraft || hadDraft,
                                animation: animation
                            )
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
                            pageView.buttonTapped = { [weak self] button, progress in
                                guard let self else {
                                    return
                                }
                                // Reuse the whole bot-button dispatch by synthesising the
                                // ReplyMarkupButton it expects. Only InlineButtonType-derived actions
                                // can occur on a page button, so .text (which would sendMessage) is
                                // unreachable here.
                                self.performRichTextButtonAction?(ReplyMarkupButton(
                                    title: button.text.plainText,
                                    titleWhenForwarded: nil,
                                    action: button.action,
                                    style: nil
                                ), progress)
                            }
                            pageView.documentTapped = { [weak self] file in
                                guard let self else {
                                    return
                                }
                                self.openRichTextDocument?(file)
                            }
                            pageView.update(layout: pageLayout, theme: pageTheme, animation: animation)
                            // Flush inside `containerNode`, which supplies the inset on every side.
                            // This used to be -1, cancelling the container's horizontal inset so the
                            // page ran under the clip and lost its leading 1pt rather than sitting in.
                            pageView.frame = CGRect(
                                origin: CGPoint(x: 0.0, y: streamingHeaderOffset),
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

    /// Tightens the rich content's corners beyond what the inset alone requires.
    ///
    /// Distinct from the inset compensation it sits next to: subtracting the inset is what keeps the
    /// curve CONCENTRIC with the bubble's, and is not a matter of taste — this is the visual tuning
    /// on top. Keep them separate so changing the inset does not silently change the look, and
    /// vice versa.
    private static let richBubbleExtraCornerRadiusReduction: CGFloat = 2.0

    /// Clips `containerNode` to the bubble's four corner radii.
    ///
    /// `CALayer.cornerRadius` carries a single value, which is enough only for an unmerged bubble;
    /// a merged one has different radii top and bottom, so the clip is a mask path instead. Each
    /// radius is reduced by `inset` so the curve stays concentric with the bubble's own — an inset
    /// box that keeps the outer radius reads as a differently-rounded rectangle sitting inside it.
    ///
    /// Called from the apply closure right after the container frame is set, so it reads the frame
    /// that was just applied rather than the presented one.
    private func applyContainerCorners(_ corners: ImageCorners, inset: CGFloat, animation: ListViewItemUpdateAnimation) {
        let size = self.containerNode.frame.size
        guard size.width > 0.0, size.height > 0.0 else {
            return
        }

        let cornersTransition: ContainedViewLayoutTransition
        if case let .System(duration, _) = animation {
            cornersTransition = .animated(duration: duration, curve: .easeInOut)
        } else {
            cornersTransition = .immediate
        }
        // A radius can never exceed half the box, or opposite corners' arcs cross and the path
        // inverts — reachable for a short bubble whose height is under twice the corner radius.
        let limit = min(size.width, size.height) / 2.0
        let radius: (ImageCorner) -> CGFloat = { corner in
            return max(0.0, min(limit, corner.radius - inset - ChatMessageRichDataBubbleContentNode.richBubbleExtraCornerRadiusReduction + 5.0))
        }
        let topLeft = radius(corners.topLeft)
        let topRight = radius(corners.topRight)
        let bottomLeft = radius(corners.bottomLeft)
        let bottomRight = radius(corners.bottomRight)
        let radii = CornerRadii(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)

        // Preferred path: the layer's own per-corner radii. It composites with the layer, so there is
        // no offscreen mask pass, and it animates as a layer property.
        if CALayer.cornerRadiiSupported {
            if let maskLayer = self.containerCornerMaskLayer {
                // Left over from an earlier layout on a build without the property.
                self.containerNode.layer.mask = nil
                self.containerCornerMaskLayer = nil
                maskLayer.removeAllAnimations()
            }
            cornersTransition.updateCornerRadii(layer: self.containerNode.layer, cornerRadii: radii)
            return
        }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: topLeft, y: 0.0))
        path.addLine(to: CGPoint(x: size.width - topRight, y: 0.0))
        path.addArc(tangent1End: CGPoint(x: size.width, y: 0.0), tangent2End: CGPoint(x: size.width, y: topRight), radius: topRight)
        path.addLine(to: CGPoint(x: size.width, y: size.height - bottomRight))
        path.addArc(tangent1End: CGPoint(x: size.width, y: size.height), tangent2End: CGPoint(x: size.width - bottomRight, y: size.height), radius: bottomRight)
        path.addLine(to: CGPoint(x: bottomLeft, y: size.height))
        path.addArc(tangent1End: CGPoint(x: 0.0, y: size.height), tangent2End: CGPoint(x: 0.0, y: size.height - bottomLeft), radius: bottomLeft)
        path.addLine(to: CGPoint(x: 0.0, y: topLeft))
        path.addArc(tangent1End: CGPoint(x: 0.0, y: 0.0), tangent2End: CGPoint(x: topLeft, y: 0.0), radius: topLeft)
        path.closeSubpath()

        let maskLayer: CAShapeLayer
        let isNewMask: Bool
        if let existing = self.containerCornerMaskLayer {
            maskLayer = existing
            isNewMask = false
        } else {
            maskLayer = CAShapeLayer()
            self.containerCornerMaskLayer = maskLayer
            self.containerNode.layer.mask = maskLayer
            isNewMask = true
        }
        let previousPath = maskLayer.path
        maskLayer.frame = CGRect(origin: CGPoint(), size: size)
        maskLayer.path = path
        // The mask does not follow the layer's frame animation on its own, so a growing bubble would
        // clip to its old shape for the whole animation and snap at the end. Animate the path
        // alongside. Skipped on the first application, where there is no previous shape to grow from.
        if case let .animated(duration, curve) = cornersTransition, !isNewMask, let previousPath, previousPath != path {
            maskLayer.animate(from: previousPath, to: path, keyPath: "path", timingFunction: curve.timingFunction, duration: duration, mediaTimingFunction: curve.mediaTimingFunction)
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

        // Resolved FIRST, and for every gesture: an unsupported pill's Update button is a real
        // `UIButton` inside the page view, and unless the bubble steps aside here its tap recognizer
        // claims the touch and cancels the button's tracking, so `touchUpInside` never fires — the
        // button highlights and then does nothing. `.ignore` is what makes the recognizer fail
        // (ChatMessageBubbleItemNode:1355), which is also how the standalone
        // `ChatMessageUnsupportedBubbleContentNode` keeps the same button alive.
        //
        // Before the collapsible-quote toggle in particular: a pill inside a collapsed quote must
        // still hand its button the tap rather than expanding the quote under it.
        if self.unsupportedActionContains(point) {
            return ChatMessageBubbleContentTapAction(content: .ignore)
        }

        if case .tap = gesture, let showMoreTextNode = self.showMoreTextNode, showMoreTextNode.frame.contains(point) {
            // Highlight rect in containerNode-local coords (the highlight overlay lives inside
            // containerNode, which sits at self (1, 1); the text node is on self).
            let rects = [showMoreTextNode.frame.offsetBy(dx: -1.0, dy: -1.0)]
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                self?.activateShowMore()
            }), rects: rects)
        }

        let entityHit = self.entityForTapLocation(point)
        if case .tap = gesture, !self.displayContentsUnderSpoilers, let entityHit, entityHit.attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)] != nil {
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                self?.revealSpoilers(atContentPoint: point)
            }))
        }

        if let entityHit, entityHit.attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.TonAddress)] != nil {
            guard let content = self.entityTapContent(entityHit.attributes) else {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
            return ChatMessageBubbleContentTapAction(
                content: content,
                rects: self.computeHighlightRects(item: entityHit.item, parentOffset: entityHit.parentOffset, localPoint: entityHit.localPoint),
                activate: self.makeActivate(item: entityHit.item, parentOffset: entityHit.parentOffset, localPoint: entityHit.localPoint)
            )
        }

        guard let urlHit = self.urlForTapLocation(point) else {
            if let entityHit {
                let rects = self.computeHighlightRects(item: entityHit.item, parentOffset: entityHit.parentOffset, localPoint: entityHit.localPoint)

                // A link-styled page button (richButtonStyle link:flags.3) whose action is not a URL,
                // so it carries the button rather than an InstantPageUrlItem and cannot use the url
                // arm below.
                //
                // `.custom` is the only content case that fits, and ChatMessageBubbleItemNode's
                // `.custom` arm (:6021) calls the closure but IGNORES `tapAction.activate` — so the
                // closure mints the progress promise itself. `makeActivate` is the call that wires
                // the shimmer over the tapped rects, which is how a link-styled `.callback` gets the
                // same loading treatment a pill does.
                if let actionItem = entityHit.attributes[NSAttributedString.Key(rawValue: InstantPageButtonActionAttribute)] as? InstantPageButtonActionItem {
                    let activate = self.makeActivate(item: entityHit.item, parentOffset: entityHit.parentOffset, localPoint: entityHit.localPoint)
                    return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                        guard let self else {
                            return
                        }
                        let progress = activate?() ?? Promise<Bool>()
                        // Mirrors the pill's dispatch (:1056): synthesise the ReplyMarkupButton the
                        // bot-button handler expects. Only InlineButtonType-derived actions can occur
                        // on a page button, so .text (which would sendMessage) is unreachable here.
                        self.performRichTextButtonAction?(ReplyMarkupButton(
                            title: actionItem.button.text.plainText,
                            titleWhenForwarded: nil,
                            action: actionItem.button.action,
                            style: nil
                        ), progress)
                    }), rects: rects)
                }

                if let content = self.entityTapContent(entityHit.attributes) {
                    return ChatMessageBubbleContentTapAction(
                        content: content,
                        rects: rects,
                        activate: self.makeActivate(item: entityHit.item, parentOffset: entityHit.parentOffset, localPoint: entityHit.localPoint)
                    )
                }
            }
            if let action = self.collapsibleQuoteTapAction(point) {
                return action
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

    /// True when `point` (this node's coords) is inside the Update button of an unsupported-content
    /// pill in the rendered page. The page answers from its LAYOUT — during touch arbitration there
    /// is no useful way to ask the pill view, and a nested pill (details body, table cell) must be
    /// found too.
    private func unsupportedActionContains(_ point: CGPoint) -> Bool {
        guard let pageView = self.pageView else {
            return false
        }
        return pageView.unsupportedActionFrame(at: self.view.convert(point, to: pageView)) != nil
    }

    /// Toggling a collapsed quote, resolved LAST in `tapActionAtPoint`: a URL, button or entity inside
    /// the visible three lines wins over the expand toggle. `.custom` is the content case for an action
    /// with no chat-level meaning of its own — the same one a link-styled page button uses.
    private func collapsibleQuoteTapAction(_ point: CGPoint) -> ChatMessageBubbleContentTapAction? {
        guard let pageView = self.pageView else {
            return nil
        }
        let local = self.view.convert(point, to: pageView)
        guard let path = pageView.collapsibleQuoteAt(point: local) else {
            return nil
        }
        return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
            guard let self, let item = self.item else {
                return
            }
            if self.currentExpandedQuotePaths.contains(path) {
                self.currentExpandedQuotePaths.remove(path)
            } else {
                self.currentExpandedQuotePaths.insert(path)
            }
            item.controllerInteraction.requestMessageUpdate(item.message.id, false, nil)
        }))
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

    /// Whether a tap on these attributes does anything.
    ///
    /// LOAD-BEARING that `tapActionAtPoint` and `updateTouchesAtPoint` agree on this set: the first
    /// decides what a tap DOES, the second whether it lights up. A link-styled button is not an
    /// `entityTapContent` case — `tapActionAtPoint` handles it separately, because it needs the hit
    /// geometry that `entityTapContent` deliberately does not take — so gating the highlight on
    /// `entityTapContent` alone gave a control that acted on tap but never highlighted.
    private func entityIsTappable(_ attributes: [NSAttributedString.Key: Any]) -> Bool {
        if attributes[NSAttributedString.Key(rawValue: InstantPageButtonActionAttribute)] is InstantPageButtonActionItem {
            return true
        }
        return self.entityTapContent(attributes) != nil
    }

    private func entityTapContent(_ attributes: [NSAttributedString.Key: Any]) -> ChatMessageBubbleContentTapAction.Content? {
        if let tonAddress = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.TonAddress)] as? InstantPageTonAddressItem {
            if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)] != nil, !self.displayContentsUnderSpoilers {
                return nil
            }
            if let item = self.item, item.associatedData.isSuspiciousPeer, item.message.effectivelyIncoming(item.context.account.peerId) {
                return nil
            }
            guard tonAddress.address.utf8.count == 48, WalletContext.transferAddress(from: tonAddress.address) != nil else {
                return nil
            }
            return .tonAddress(tonAddress.address)
        } else if let mention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
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
            } else if let entityHit = self.entityForTapLocation(point), entityHit.attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.TonAddress)] != nil {
                if self.entityIsTappable(entityHit.attributes) {
                    rects = self.computeHighlightRects(item: entityHit.item, parentOffset: entityHit.parentOffset, localPoint: entityHit.localPoint)
                }
            } else if let urlHit = self.urlForTapLocation(point) {
                rects = self.computeHighlightRects(item: urlHit.item, parentOffset: urlHit.parentOffset, localPoint: urlHit.localPoint)
            } else if let entityHit = self.entityForTapLocation(point), self.entityIsTappable(entityHit.attributes) {
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
    
    /// Removes the selection overlay built by `updateIsExtractedToContextPreview(true)`.
    ///
    /// LOAD-BEARING that every un-extract path reaches this. `TextSelectionNode.hitTest` claims
    /// EVERY point inside its bounds (it is sized to `containerNode.bounds`), and it is the topmost
    /// subnode of `containerNode` — so while it is attached it becomes the hit view for the whole
    /// bubble content. UIKit collects a touch's gesture recognizers from the hit view UPWARD, and
    /// the page's media taps live on recognizers INSIDE `pageView` — a sibling branch, not an
    /// ancestor — so a leftover selection node silently kills tap-to-open on every image and video
    /// in the message. Bubble-level taps (links, buttons, quote toggles) keep working, because that
    /// recognizer sits on the item node, an ancestor of the hit view: the failure presents as
    /// "only media stopped reacting".
    ///
    /// The adapter is removed from its supernode too. It is `isUserInteractionEnabled = false`, so
    /// leaving it attached did not block touches — but it holds the whole page's attributed text.
    private func tearDownTextSelection(animated: Bool) {
        if let adapter = self.textSelectionAdapter {
            self.textSelectionAdapter = nil
            adapter.removeFromSupernode()
        }
        guard let textSelectionNode = self.textSelectionNode else {
            return
        }
        self.textSelectionNode = nil
        if animated {
            textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                textSelectionNode?.highlightAreaNode.removeFromSupernode()
                textSelectionNode?.removeFromSupernode()
            })
        } else {
            textSelectionNode.highlightAreaNode.removeFromSupernode()
            textSelectionNode.removeFromSupernode()
        }
    }

    override public func willUpdateIsExtractedToContextPreview(_ value: Bool) {
        if !value {
            self.tearDownTextSelection(animated: true)
        }
    }

    override public func updateIsExtractedToContextPreview(_ value: Bool) {
        // The un-extract must be handled HERE as well as in `willUpdate…`, because the two hooks are
        // separate closures on the item node (`ChatMessageBubbleItemNode`'s
        // `willUpdateIsExtractedToContextPreview` vs `isExtractedToContextPreviewUpdated`) and the
        // SEND ANIMATION only fires the second one: `ChatMessageTransitionNode` sets
        // `isExtractedToContextPreview` + calls `isExtractedToContextPreviewUpdated?(true/false)`
        // and never touches `willUpdate…`. Handling `false` only in `willUpdate…` therefore left the
        // selection overlay attached on every message sent from the composer. This mirrors
        // `ChatMessageTextBubbleContentNode`, which tears down in both hooks for the same reason.
        if !value {
            self.tearDownTextSelection(animated: true)
            return
        }
        guard self.textSelectionNode == nil, let messageItem = self.item, self.currentPageLayout?.layout != nil, let pageView = self.pageView, let rootNode = messageItem.controllerInteraction.chatControllerNode() else {
            return
        }

        // pageView sits flush at (0, 0) inside containerNode; the adapter is placed at
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

    override public func unsupportedContentAreas() -> [CGRect] {
        guard let layout = self.currentPageLayout?.layout, let pageView = self.pageView else {
            return []
        }
        // Converting through the view hierarchy rather than re-deriving `pageContentInset` and the
        // streaming-header offset by hand: those are the layout pass's business, and a second copy
        // would drift. Safe mid-animation because every `ControlledTransitionAnimator.updateFrame`
        // writes the model layer's position and bounds synchronously and animates *from* the old
        // value, so the hierarchy already reports target geometry once apply returns.
        return unsupportedContentTearZones(in: layout).map { self.view.convert($0, from: pageView) }
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
