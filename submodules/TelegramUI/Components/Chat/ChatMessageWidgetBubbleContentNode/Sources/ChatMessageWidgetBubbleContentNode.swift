import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import LottieSettings
import AccountContext
import ChatMessageBubbleContentNode
import ChatMessageDateAndStatusNode
import ChatMessageItemCommon
import ChatControllerInteraction
import MessageWidget
import UnsupportedContentPill
import WallpaperBackgroundNode
import MessageWidgetStorage

/// Whether widget messages render as widgets: the client's own flag (Debug Settings ▸ "Widget messages"; widget-sandbox
/// v0.1.0, integration.md "Enabling") on and the app-config kill switch off. Off, a widget message shows as unsupported
/// media with its caption.
public func chatMessageWidgetRenderingEnabled(context: AccountContext) -> Bool {
    return context.sharedContext.immediateExperimentalUISettings.widgetMessages && !MessageWidgetKillSwitch.isEngaged
}

/// One subscription for the whole process, started by the first pass that lays a widget out (on main): every widget
/// hears the app's active state through `MessageWidgetApplicationState`, so one in an app that stays alive in the
/// background (a call, audio) pauses its timers and frames. The signal delivers the current state at once.
private var messageWidgetApplicationStateDisposable: Disposable?

public func feedMessageWidgetApplicationState(context: AccountContext) {
    if messageWidgetApplicationStateDisposable != nil {
        return
    }
    messageWidgetApplicationStateDisposable = (context.sharedContext.applicationBindings.applicationIsActive
    |> deliverOnMainQueue).startStrict(next: { isActive in
        MessageWidgetApplicationState.shared.isActive = isActive
    })
}

/// A widget message (`TelegramMediaWidget`) in its own bubble: the widget runs on `MessageWidgetRegistry` /
/// `MessageWidgetInstance`, edge to edge inside the bubble, sized from its anchors (`MessageWidgetBubbleSize`, widget-sandbox
/// v0.1.0 integration.md "Bubble sizing") and hard-clipped at the bubble's height. When it cannot run (rendering off, a
/// payload that does not decode, a widget that fails to start) the bubble shows the unsupported-media pill instead, with
/// the caption still under it (integration.md "Enabling": "unsupported media with its caption").
public final class ChatMessageWidgetBubbleContentNode: ChatMessageBubbleContentNode {
    /// One widget per message, at this path in the registry.
    private static let path: [Int] = []
    /// The padding of the bubble's own around the widget: none (widget-sandbox v0.1.1, sdk-v1 §5.1 "The widget view
    /// fills the bubble"). The widget's body margin, the text tokens' padding, is the inset, and a background the widget
    /// paints reaches the bubble's rounded edges.
    static let bubbleInset: CGFloat = 0.0

    private let registry: MessageWidgetRegistry
    /// Clips the widget to the bubble's height and corners.
    private let clipView: UIView
    private let clipMask: CAShapeLayer
    private let dateAndStatusNode: ChatMessageDateAndStatusNode
    /// Shown instead of the widget when it cannot run.
    private let pillView: UnsupportedContentPillView
    /// Under the widget where the bubble's tail joins its bottom corner: the tail's shape (`chatBubbleMediaCorner`, the
    /// mask a photo's tail corner uses) in the colour the widget shows at that corner, so a widget that paints to its
    /// edge continues into the tail as a photo does.
    private let tailLayer = CALayer()
    private let tailMask = CALayer()
    /// The tail's side while the widget's bottom corner joins one (true: the left, an incoming bubble's); nil without.
    private var tailOnLeft: Bool?
    /// What `chatMessageWidgetRenderingEnabled` answered in the last applied layout; nil before the first.
    private var laidOutEnabled: Bool?
    private var availabilityObserver: NSObjectProtocol?
    private let hapticFeedback = HapticFeedback()

    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            if oldValue != self.visibility {
                // Off screen, a widget's timers and frames pause, and its storage is written now (§5.4).
                self.registry.setVisible(self.visibility != .none)
                if self.visibility == .none, let storageSink = self.storageSink {
                    MessageWidgetStorageStore.shared.flush(storageSink.key)
                }
            }
        }
    }
    /// Where the widget of the message the last pass laid out commits its storage (SDK v1 §5.4); its key is also the
    /// one the writes on hide and teardown flush.
    private var storageSink: MessageWidgetStorageSink?

    required public init(lottieSettings: LottieRenderingSettings) {
        self.registry = MessageWidgetRegistry()
        self.clipView = UIView()
        self.clipView.clipsToBounds = true
        self.clipMask = CAShapeLayer()
        self.dateAndStatusNode = ChatMessageDateAndStatusNode()
        self.pillView = UnsupportedContentPillView()

        super.init(lottieSettings: lottieSettings)

        self.pillView.action = { [weak self] in
            guard let item = self?.item else {
                return
            }
            item.controllerInteraction.openAppStorePage()
        }

        // Both arrive on the main queue after a widget's snapshot is applied (MessageWidgetInstance), so neither can
        // re-enter a widget mid-apply.
        self.registry.onLayoutChange = { [weak self] in
            guard let self, let item = self.item else {
                return
            }
            // The relayout reads the widget's new height from the registry; no JS runs.
            item.controllerInteraction.requestMessageUpdate(item.message.id, false, nil)
        }
        // Widgets switched off or on while the chat is open (the client's flag, the server's kill switch): nothing else
        // lays out a bubble whose widget never changes size, so a running widget would keep running and a pill would stay.
        self.availabilityObserver = NotificationCenter.default.addObserver(forName: MessageWidgetAvailability.didChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            guard let self, let item = self.item, let laidOutEnabled = self.laidOutEnabled else {
                return
            }
            if chatMessageWidgetRenderingEnabled(context: item.context) != laidOutEnabled {
                item.controllerInteraction.requestMessageUpdate(item.message.id, false, nil)
            }
        })
        self.registry.onBridge = { [weak self] call in
            guard let self, let item = self.item else {
                return
            }
            switch call {
            case let .openLink(url), let .openTelegramLink(url):
                // A widget's URL is never shown to the user, and opening it reveals the user's IP address to that
                // host (a t.me link is resolved over the network as well), so the "Open link?" confirmation must
                // always appear: no `message:` (with one, ChatController skips it when the message's author or its
                // forward source is verified) and `forceConcealed`. A confirmed t.me link opens in the app. SDK v1
                // §5.2: the confirmation shows the whole URL, and only one is shown at a time; a link that comes
                // while one is up is dropped.
                MessageWidgetLinkDialog.shared.request { displayUpdated in
                    item.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: url, concealed: true, forceConcealed: true, fullUrl: true, alertDisplayUpdated: { controller in
                        displayUpdated(controller)
                    }))
                }
            case let .haptic(kind, value):
                // SDK v1 §2.6, as Mini Apps play them (WebAppController's web_app_trigger_haptic_feedback).
                switch (kind, value) {
                case ("impact", "light"):
                    self.hapticFeedback.impact(.light)
                case ("impact", "medium"):
                    self.hapticFeedback.impact(.medium)
                case ("impact", "heavy"):
                    self.hapticFeedback.impact(.heavy)
                case ("impact", "rigid"):
                    self.hapticFeedback.impact(.rigid)
                case ("impact", "soft"):
                    self.hapticFeedback.impact(.soft)
                case ("notification", "success"):
                    self.hapticFeedback.success()
                case ("notification", "error"):
                    self.hapticFeedback.error()
                case ("notification", "warning"):
                    self.hapticFeedback.warning()
                case ("selection", _):
                    self.hapticFeedback.tap()
                default:
                    break
                }
            }
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let availabilityObserver = self.availabilityObserver {
            NotificationCenter.default.removeObserver(availabilityObserver)
        }
        // A widget's runtime is main-thread only. A node is normally released on main, but one built by an off-main
        // layout can be released there, so hand the teardown to main rather than run it here.
        let registry = self.registry
        let storageKey = self.storageSink?.key
        // The widget's storage is written now (§5.4); a commit its last task made reaches the store after this and
        // is written after the store's short delay.
        let teardown = {
            registry.destroyAll()
            if let storageKey {
                MessageWidgetStorageStore.shared.flush(storageKey)
            }
        }
        if Thread.isMainThread {
            teardown()
        } else {
            Queue.mainQueue().async(teardown)
        }
    }

    override public func didLoad() {
        super.didLoad()

        self.clipView.layer.mask = self.clipMask
        // Below the date pill and anything else the bubble adds.
        self.view.insertSubview(self.clipView, at: 0)
        self.view.insertSubview(self.pillView, aboveSubview: self.clipView)
        self.tailLayer.actions = ["position": NSNull(), "bounds": NSNull(), "backgroundColor": NSNull(), "hidden": NSNull()]
        self.tailMask.actions = ["position": NSNull(), "bounds": NSNull(), "contents": NSNull()]
        self.tailLayer.mask = self.tailMask
        self.tailLayer.isHidden = true
        self.view.layer.insertSublayer(self.tailLayer, below: self.clipView.layer)
    }

    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let statusLayout = self.dateAndStatusNode.asyncLayout()
        let registry = self.registry

        return { [weak self] item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 5.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)

            let widget = item.message.media.first(where: { $0 is TelegramMediaWidget }) as? TelegramMediaWidget
            let anchors = MessageWidgetAnchors(width: widget?.width ?? 0, height: widget?.height ?? 0)
            let source = widget?.html() ?? ""
            // Whether the widget may run at all: the client's flag, and a payload that decodes to some HTML.
            let enabled = chatMessageWidgetRenderingEnabled(context: item.context)
            let renderable = enabled && !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let heightKey = AnyHashable(item.message.stableId)

            var incoming = item.message.effectivelyIncoming(item.context.account.peerId)
            if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .forward = info {
                incoming = false
            }
            let inset = ChatMessageWidgetBubbleContentNode.bubbleInset
            let bubbleInsets = UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)

            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let maximumWidgetWidth = max(1.0, constrainedSize.width - bubbleInsets.left - bubbleInsets.right)
                let widgetWidth = MessageWidgetBubbleSize.width(anchors: anchors, maximumWidth: maximumWidgetWidth)

                // A widget's instance and the height cache are main-thread only, so the widget runs only from a pass on
                // main (the chat history's CoreList backend lays out there). Off main the bubble takes its placeholder
                // or fixed height and shows no widget until a main-thread pass.
                let isMainThreadPass = Thread.isMainThread
                var reported: CGFloat?
                var cached: CGFloat?
                var failedToStart = false
                if isMainThreadPass {
                    var bubbleIsVisible = false
                    if let self, case .visible = self.visibility {
                        bubbleIsVisible = true
                    }
                    registry.setVisible(bubbleIsVisible)
                    feedMessageWidgetApplicationState(context: item.context)
                    registry.stoppedLabel = item.presentationData.strings.Message_WidgetStopped
                    registry.maxMessageLength = Int(item.context.userLimits.maxMessageLength)
                    // SDK v1 §2.9: the app's UI language (a code the runtime cannot read as BCP 47 becomes en-US).
                    registry.locale = item.presentationData.strings.baseLanguageCode
                    // SDK v1 §2.8 and §5.4: the widget's storage is this message's, kept by the store and written into the
                    // message's derived data; where the id is not the message's own (the admin log, a preview) it stays
                    // in memory, apart from the message's. One sink per message (stable id), following its id from
                    // pending to sent; set on every pass, for widgets made in it.
                    let persists = messageWidgetStoragePersists(associatedData: item.associatedData, isPreview: item.presentationData.isPreview)
                    let storageKey = MessageWidgetStorageStore.Key(accountPeerId: item.context.account.peerId, message: item.message.id, persists: persists)
                    let storageWriter: MessageWidgetStorageWriter? = persists ? MessageWidgetEngineStorageWriter(engine: item.context.engine) : nil
                    let storageSink: MessageWidgetStorageSink
                    if let current = self?.storageSink, current.owner == heightKey {
                        current.update(key: storageKey, writer: storageWriter)
                        storageSink = current
                    } else {
                        storageSink = MessageWidgetStorageSink(owner: heightKey, key: storageKey, writer: storageWriter)
                        self?.storageSink = storageSink
                    }
                    registry.storage = MessageWidgetStorageStore.shared.preload(storageKey, storedAttributes: item.message.attributes)
                    registry.onStorageCommit = { commit in
                        storageSink.commit(commit)
                    }
                    // Another message's stable id (the node was recycled) destroys the runtime. SDK v1 §2.3, §2.4, §5.1:
                    // the chat's palette and its message text.
                    registry.beginPass(ownerId: heightKey, theme: messageWidgetTheme(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper, incoming: incoming, fontSize: item.presentationData.fontSize, textInsets: layoutConstants.text.bubbleInsets))
                    // Not asked when it may not run: the pass then ends with no widget, which destroys a running one
                    // (the flag was just turned off).
                    if renderable {
                        // A fixed height is the most the widget's document may be, so a stopped widget's badge, at the
                        // document's bottom, stays inside the clip. Handed over on every pass, so an edit of the anchors reaches it.
                        registry.maximumHeight = anchors.height > 0 ? MessageWidgetBubbleSize.height(anchors: anchors, reported: nil, cached: nil) : MessageWidgetBubbleSize.maximumHeight
                        if registry.size(path: ChatMessageWidgetBubbleContentNode.path, source: source, width: widgetWidth) != nil {
                            reported = registry.reportedHeight(path: ChatMessageWidgetBubbleContentNode.path, source: source)
                        } else {
                            failedToStart = true
                        }
                    }
                    registry.endPass()
                    if anchors.height <= 0, let reported {
                        MessageWidgetHeightCache.shared.set(reported, for: heightKey)
                    }
                    cached = MessageWidgetHeightCache.shared.height(for: heightKey)
                }
                let showsPill = !renderable || failedToStart
                let presentationData = item.presentationData
                let pillStrings = UnsupportedContentPillStrings(strings: presentationData.strings)
                let pillColors = UnsupportedContentPillColors(
                    fill: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper),
                    primaryText: serviceMessageColorComponents(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper).primaryText,
                    isDark: presentationData.theme.theme.overallDarkAppearance
                )
                let pillLayout = UnsupportedContentPill.layout(strings: pillStrings, colors: pillColors, constrainedWidth: maximumWidgetWidth)
                let widgetHeight = showsPill ? pillLayout.size.height : MessageWidgetBubbleSize.height(anchors: anchors, reported: reported, cached: cached)

                let statusType: ChatMessageDateAndStatusType?
                if case .customChatContents = item.associatedData.subject {
                    statusType = nil
                } else if showsPill {
                    // The pill has its own button at the bottom; the unsupported bubble it stands for shows no date.
                    statusType = nil
                } else {
                    switch position {
                    case .linear(_, .None), .linear(_, .Neighbour(true, _, _)):
                        // Nothing follows the widget (a caption carries the date itself): the date on a pill over it.
                        if incoming {
                            statusType = .ImageIncoming
                        } else if item.message.flags.contains(.Failed) {
                            statusType = .ImageOutgoing(.Failed)
                        } else if (item.message.flags.isSending && !item.message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                            statusType = .ImageOutgoing(.Sending)
                        } else {
                            statusType = .ImageOutgoing(.Sent(read: item.read))
                        }
                    default:
                        statusType = nil
                    }
                }

                var statusSize = CGSize()
                var statusApply: ((ListViewItemUpdateAnimation) -> Void)?
                if let statusType {
                    var edited = false
                    if item.attributes.updatingMedia != nil {
                        edited = true
                    }
                    var viewCount: Int?
                    var dateReplies = 0
                    var starsCount: Int64?
                    var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: item.message)
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
                    var isReplyThread = false
                    if case .replyThread = item.chatLocation {
                        isReplyThread = true
                    }
                    let dateText = stringForMessageTimestampStatus(context: item.context, message: EngineMessage(item.message), dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: item.presentationData.isPreview ? .full : .regular, associatedData: item.associatedData)
                    let statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: item.context,
                        presentationData: item.presentationData,
                        edited: edited,
                        impressionCount: !item.presentationData.isPreview ? viewCount : nil,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: .standalone(reactionSettings: shouldDisplayInlineDateReactions(message: EngineMessage(item.message), isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions) ? ChatMessageDateAndStatusNode.StandaloneReactionSettings() : nil),
                        constrainedSize: CGSize(width: constrainedSize.width, height: CGFloat.greatestFiniteMagnitude),
                        availableReactions: item.associatedData.availableReactions,
                        savedMessageTags: item.associatedData.savedMessageTags,
                        reactions: dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        areReactionsTags: item.topMessage.areReactionsTags(accountPeerId: item.context.account.peerId),
                        areStarReactionsEnabled: item.associatedData.areStarReactionsEnabled,
                        messageEffect: item.topMessage.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects),
                        replyCount: dateReplies,
                        starsCount: starsCount,
                        isPinned: item.message.tags.contains(.pinned) && !item.associatedData.isInPinnedListMode && !isReplyThread,
                        hasAutoremove: item.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: EngineMessage(item.topMessage)),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                    let (dateAndStatusSize, dateAndStatusApply) = statusSuggestedWidthAndContinue.1(statusSuggestedWidthAndContinue.0)
                    statusSize = dateAndStatusSize
                    statusApply = dateAndStatusApply
                }

                let contentWidth = (showsPill ? pillLayout.size.width : widgetWidth) + bubbleInsets.left + bubbleInsets.right
                return (contentWidth, { boundingWidth in
                    let layoutSize = CGSize(width: boundingWidth, height: widgetHeight + bubbleInsets.top + bubbleInsets.bottom)
                    // A fixed-width widget in a wider bubble (a longer caption) is centred; the pill fills the bubble.
                    let frameWidth = showsPill ? boundingWidth - bubbleInsets.left - bubbleInsets.right : widgetWidth
                    let widgetFrame = CGRect(x: floor((boundingWidth - frameWidth) / 2.0), y: bubbleInsets.top, width: frameWidth, height: widgetHeight)
                    // The bubble's own radii, as its background draws them (`messageBubbleImage`: a merged corner is the
                    // auxiliary radius when the setting merges corners), so the widget's edge is the bubble's.
                    let bubbleCorners = item.presentationData.chatBubbleCorners
                    let mergedRadius = (bubbleCorners.mergeBubbleCorners && bubbleCorners.mainRadius >= 10.0) ? bubbleCorners.auxiliaryRadius : bubbleCorners.mainRadius
                    let corners = chatMessageBubbleImageContentCorners(relativeContentPosition: position, normalRadius: bubbleCorners.mainRadius, mergedRadius: mergedRadius, mergedWithAnotherContentRadius: layoutConstants.image.contentMergedCornerRadius, layoutConstants: layoutConstants, chatPresentationData: item.presentationData)
                    // The bubble's body is square where its tail joins it; an incoming bubble without tails is rounded there.
                    let drawsTail = !incoming || bubbleCorners.hasTails
                    var tailOnLeft: Bool?
                    if drawsTail && !showsPill {
                        if case .Tail = corners.bottomLeft {
                            tailOnLeft = true
                        } else if case .Tail = corners.bottomRight {
                            tailOnLeft = false
                        }
                    }
                    let tailImage = tailOnLeft.flatMap { PresentationResourcesChat.chatBubbleMediaCorner(item.presentationData.theme.theme, incoming: $0, mainRadius: bubbleCorners.mainRadius, inset: 0.0) }
                    // The date sits where it sits on a photo: the photo's inset plus the status inset from the bubble's edge.
                    let statusRight = layoutConstants.image.bubbleInsets.right + layoutConstants.image.statusInsets.right
                    let statusBottom = layoutConstants.image.bubbleInsets.bottom + layoutConstants.image.statusInsets.bottom
                    let statusFrame = CGRect(origin: CGPoint(x: layoutSize.width - statusRight - statusSize.width, y: layoutSize.height - statusBottom - statusSize.height), size: statusSize)

                    return (layoutSize, { [weak self] animation, _, _ in
                        guard let self else {
                            return
                        }
                        self.item = item
                        self.laidOutEnabled = enabled

                        self.clipView.frame = widgetFrame
                        self.clipMask.frame = CGRect(origin: CGPoint(), size: widgetFrame.size)
                        self.clipMask.path = ChatMessageWidgetBubbleContentNode.roundedPath(size: widgetFrame.size, corners: corners, drawsTail: drawsTail)
                        self.clipView.isHidden = showsPill
                        self.pillView.isHidden = !showsPill
                        self.tailOnLeft = tailImage == nil ? nil : tailOnLeft
                        if let tailOnLeft, let tailImage {
                            // The image's body edge is 6 pt in from its tail side (mediaBubbleCornerImage).
                            let size = tailImage.size
                            let x = tailOnLeft ? widgetFrame.minX - (size.width - bubbleCorners.mainRadius - 1.0) : widgetFrame.maxX - (bubbleCorners.mainRadius + 1.0)
                            self.tailLayer.frame = CGRect(x: x, y: widgetFrame.maxY - size.height, width: size.width, height: size.height)
                            self.tailMask.frame = CGRect(origin: CGPoint(), size: size)
                            self.tailMask.contentsScale = tailImage.scale
                            self.tailMask.contents = tailImage.cgImage
                        }
                        if showsPill {
                            self.pillView.frame = widgetFrame
                            self.pillView.update(layout: pillLayout, colors: pillColors, strings: pillStrings, size: widgetFrame.size, wallpaperBackgroundNode: item.controllerInteraction.presentationContext.backgroundNode, animation: animation)
                        }

                        if isMainThreadPass {
                            if let live = registry.view(path: ChatMessageWidgetBubbleContentNode.path, source: source) {
                                for subview in self.clipView.subviews where subview !== live {
                                    subview.removeFromSuperview()
                                }
                                if live.superview !== self.clipView {
                                    self.clipView.addSubview(live)
                                }
                                (live as? MessageWidgetView)?.onBottomCornerColorsChange = { [weak self] _, _ in
                                    self?.updateTailColor()
                                }
                                // Laid out at its own width; its height is the content's, which the clip cuts at the bubble's.
                                live.frame = CGRect(origin: CGPoint(), size: CGSize(width: widgetWidth, height: max(widgetHeight, reported ?? 0.0)))
                            } else {
                                for subview in self.clipView.subviews {
                                    subview.removeFromSuperview()
                                }
                            }
                        }

                        self.updateTailColor()

                        if let statusApply {
                            if self.dateAndStatusNode.supernode == nil {
                                self.addSubnode(self.dateAndStatusNode)
                            }
                            statusApply(animation)
                            self.dateAndStatusNode.frame = statusFrame
                        } else if self.dateAndStatusNode.supernode != nil {
                            self.dateAndStatusNode.removeFromSupernode()
                        }
                    })
                })
            })
        }
    }

    /// The tail takes the colour the live widget shows at the corner it joins; nothing without one.
    private func updateTailColor() {
        var color: CGColor?
        if let tailOnLeft = self.tailOnLeft, !self.clipView.isHidden, let live = self.clipView.subviews.first as? MessageWidgetView {
            color = tailOnLeft ? live.bottomCornerColors.left : live.bottomCornerColors.right
        }
        self.tailLayer.backgroundColor = color
        self.tailLayer.isHidden = color == nil
    }

    /// A rounded rect with each corner's own radius (`ImageCorners`: a corner merged with a neighbour is smaller); the
    /// corner the bubble's tail joins is square when the bubble draws one.
    static func roundedPath(size: CGSize, corners: ImageCorners, drawsTail: Bool) -> CGPath {
        let path = CGMutablePath()
        let limit = min(size.width, size.height) / 2.0
        let radius: (ImageCorner) -> CGFloat = { corner in
            if case .Tail = corner, drawsTail {
                return 0.0
            }
            return min(corner.radius, limit)
        }
        let topLeft = radius(corners.topLeft)
        let topRight = radius(corners.topRight)
        let bottomLeft = radius(corners.bottomLeft)
        let bottomRight = radius(corners.bottomRight)
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
        return path
    }

    override public func willUpdateIsExtractedToContextPreview(_ value: Bool) {
        super.willUpdateIsExtractedToContextPreview(value)
        // The long press opened the message's menu: the widget's touch is the menu's now, so lifting the finger must not
        // click the widget (sdk-v1 §5.5: the long press stays with the bubble).
        if value, let widgetView = self.clipView.subviews.first as? MessageWidgetView {
            widgetView.cancelTouches()
        }
    }

    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if !self.pillView.isHidden {
            if self.pillView.actionContains(self.view.convert(point, to: self.pillView)) {
                return ChatMessageBubbleContentTapAction(content: .ignore)
            }
            return ChatMessageBubbleContentTapAction(content: .none)
        }
        // A live widget takes its own taps (MessageWidgetView); the long press stays with the bubble, whose context
        // menu opens over the widget too (`hasLongTapAction: false`). A stopped widget leaves everything to the bubble.
        if self.clipView.frame.contains(point) && self.registry.isLive(path: ChatMessageWidgetBubbleContentNode.path) {
            return ChatMessageBubbleContentTapAction(content: .ignore, hasLongTapAction: false)
        }
        return ChatMessageBubbleContentTapAction(content: .none)
    }

    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if !self.dateAndStatusNode.isHidden {
            return self.dateAndStatusNode.reactionView(value: value)
        }
        return nil
    }

    override public func messageEffectTargetView() -> UIView? {
        if !self.dateAndStatusNode.isHidden {
            return self.dateAndStatusNode.messageEffectTargetView()
        }
        return nil
    }
}

/// SDK v1 §5.4 (V2b plan, Task 9): whether a widget's storage is written for its message. Not in the admin log, whose
/// message ids are synthetic and could name an unrelated real message, nor in a preview (a chat preview, a forward or
/// reply preview), which shows a message under a borrowed context; there it is kept in memory only.
public func messageWidgetStoragePersists(associatedData: ChatMessageItemAssociatedData, isPreview: Bool) -> Bool {
    if associatedData.isRecentActions || isPreview {
        return false
    }
    if let subject = associatedData.subject, case .messageOptions = subject {
        return false
    }
    return true
}
