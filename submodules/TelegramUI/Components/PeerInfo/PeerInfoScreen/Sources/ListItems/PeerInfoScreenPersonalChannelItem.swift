import AsyncDisplayKit
import Display
import TelegramPresentationData
import AccountContext
import TextFormat
import UIKit
import AppBundle
import TelegramStringFormatting
import ContextUI
import TelegramCore
import ChatListUI
import Postbox
import StoryContainerScreen
import AvatarNode

final class PeerInfoScreenPersonalChannelItem: PeerInfoScreenItem {
    let id: AnyHashable
    let context: AccountContext
    let data: PeerInfoPersonalChannelData
    let controller: () -> ViewController?
    let action: () -> Void
    
    init(
        id: AnyHashable,
        context: AccountContext,
        data: PeerInfoPersonalChannelData,
        controller: @escaping () -> ViewController?,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.context = context
        self.data = data
        self.controller = controller
        self.action = action
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenPersonalChannelItemNode()
    }
}

private final class LoadingOverlayShimmerNode: ASDisplayNode {
    private var currentBackgroundColor: UIColor?
    private var currentForegroundColor: UIColor?
    private let imageNodeContainer: ASDisplayNode
    private let imageNode: ASImageNode
    
    private var absoluteLocation: (CGRect, CGSize)?
    private var isCurrentlyInHierarchy = false
    private var shouldBeAnimating = false
    
    override init() {
        self.imageNodeContainer = ASDisplayNode()
        self.imageNodeContainer.isLayerBacked = true
        
        self.imageNode = ASImageNode()
        self.imageNode.isLayerBacked = true
        self.imageNode.displaysAsynchronously = false
        self.imageNode.displayWithoutProcessing = true
        self.imageNode.contentMode = .scaleToFill
        
        super.init()
        
        self.imageNodeContainer.addSubnode(self.imageNode)
        self.addSubnode(self.imageNodeContainer)
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        self.isCurrentlyInHierarchy = true
        self.updateAnimation()
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.isCurrentlyInHierarchy = false
        self.updateAnimation()
    }
    
    func update(backgroundColor: UIColor, foregroundColor: UIColor) {
        if let currentBackgroundColor = self.currentBackgroundColor, currentBackgroundColor.isEqual(backgroundColor), let currentForegroundColor = self.currentForegroundColor, currentForegroundColor.isEqual(foregroundColor) {
            return
        }
        self.currentBackgroundColor = backgroundColor
        self.currentForegroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        
        self.imageNode.image = generateImage(CGSize(width: 4.0, height: 320.0), opaque: true, scale: 1.0, rotatedContext: { size, context in
            context.setFillColor(backgroundColor.cgColor)
            context.fill(CGRect(origin: CGPoint(), size: size))
            
            context.clip(to: CGRect(origin: CGPoint(), size: size))
            
            let transparentColor = backgroundColor.cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        })
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if let absoluteLocation = self.absoluteLocation, absoluteLocation.0 == rect && absoluteLocation.1 == containerSize {
            return
        }
        let sizeUpdated = self.absoluteLocation?.1 != containerSize
        let frameUpdated = self.absoluteLocation?.0 != rect
        self.absoluteLocation = (rect, containerSize)
        
        if sizeUpdated {
            if self.shouldBeAnimating {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
                self.addImageAnimation()
            }
        }
        
        if frameUpdated {
            self.imageNodeContainer.frame = CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: containerSize)
        }
        
        self.updateAnimation()
    }
    
    private func updateAnimation() {
        let shouldBeAnimating = self.isCurrentlyInHierarchy && self.absoluteLocation != nil
        if shouldBeAnimating != self.shouldBeAnimating {
            self.shouldBeAnimating = shouldBeAnimating
            if shouldBeAnimating {
                self.addImageAnimation()
            } else {
                self.imageNode.layer.removeAnimation(forKey: "shimmer")
            }
        }
    }
    
    private func addImageAnimation() {
        guard let containerSize = self.absoluteLocation?.1 else {
            return
        }
        let gradientHeight: CGFloat = 250.0
        self.imageNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -gradientHeight), size: CGSize(width: containerSize.width, height: gradientHeight))
        let animation = self.imageNode.layer.makeAnimation(from: 0.0 as NSNumber, to: (containerSize.height + gradientHeight) as NSNumber, keyPath: "position.y", timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, duration: 1.3 * 1.0, delay: 0.0, mediaTimingFunction: nil, removeOnCompletion: true, additive: true)
        animation.repeatCount = Float.infinity
        animation.beginTime = 1.0
        self.imageNode.layer.add(animation, forKey: "shimmer")
    }
}

public final class LoadingOverlayNode: ASDisplayNode {
    private let effectNode: LoadingOverlayShimmerNode
    private let maskNode: ASImageNode
    private var currentParams: (size: CGSize, presentationData: PresentationData)?
    
    override public init() {
        self.effectNode = LoadingOverlayShimmerNode()
        self.maskNode = ASImageNode()
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.effectNode)
        self.effectNode.view.mask = self.maskNode.view
    }
    
    public func update(context: AccountContext, size: CGSize, isInlineMode: Bool, presentationData: PresentationData, transition: ContainedViewLayoutTransition) {
        if self.currentParams?.size != size || self.currentParams?.presentationData !== presentationData {
            self.currentParams = (size, presentationData)
                        
            let chatListPresentationData = ChatListPresentationData(theme: presentationData.theme, fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameSortOrder: presentationData.nameSortOrder, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true)
            
            let peer1: EnginePeer = .user(TelegramUser(id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(0)), accessHash: nil, firstName: "FirstName", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
            let timestamp1: Int32 = 100000
            let peers: [EnginePeer.Id: EnginePeer] = [:]
            let interaction = ChatListNodeInteraction(context: context, animationCache: context.animationCache, animationRenderer: context.animationRenderer, activateSearch: {}, peerSelected: { _, _, _, _, _ in }, disabledPeerSelected: { _, _, _ in }, togglePeerSelected: { _, _ in }, togglePeersSelection: { _, _ in }, additionalCategorySelected: { _ in
            }, messageSelected: { _, _, _, _ in}, groupSelected: { _ in }, addContact: { _ in }, setPeerIdWithRevealedOptions: { _, _ in }, setItemPinned: { _, _ in }, setPeerMuted: { _, _ in }, setPeerThreadMuted: { _, _, _ in }, deletePeer: { _, _ in }, deletePeerThread: { _, _ in }, setPeerThreadStopped: { _, _, _ in }, setPeerThreadPinned: { _, _, _ in }, setPeerThreadHidden: { _, _, _ in }, updatePeerGrouping: { _, _ in }, togglePeerMarkedUnread: { _, _ in}, toggleArchivedFolderHiddenByDefault: {}, toggleThreadsSelection: { _, _ in }, hidePsa: { _ in }, activateChatPreview: { _, _, _, gesture, _ in
                gesture?.cancel()
            }, present: { _ in }, openForumThread: { _, _ in }, openStorageManagement: {}, openPasswordSetup: {}, openPremiumIntro: {}, openPremiumGift: { _, _ in }, openPremiumManagement: {}, openActiveSessions: {}, openBirthdaySetup: {}, performActiveSessionAction: { _, _ in }, openChatFolderUpdates: {}, hideChatFolderUpdates: {}, openStories: { _, _ in }, openStarsTopup: { _ in
            }, dismissNotice: { _ in
            }, editPeer: { _ in
            }, openWebApp: { _ in
            }, openPhotoSetup: {
            }, openAdInfo: { _, _ in
            }, openAccountFreezeInfo: {
            }, openUrl: { _ in
            })
            
            let items = (0 ..< 1).map { _ -> ChatListItem in
                let message = EngineMessage(
                    stableId: 0,
                    stableVersion: 0,
                    id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0),
                    globallyUniqueId: nil,
                    groupingKey: nil,
                    groupInfo: nil,
                    threadId: nil,
                    timestamp: timestamp1,
                    flags: [],
                    tags: [],
                    globalTags: [],
                    localTags: [],
                    customTags: [],
                    forwardInfo: nil,
                    author: peer1,
                    text: "Text",
                    attributes: [],
                    media: [],
                    peers: peers,
                    associatedMessages: [:],
                    associatedMessageIds: [],
                    associatedMedia: [:],
                    associatedThreadInfo: nil,
                    associatedStories: [:]
                )
                let readState = EnginePeerReadCounters()

                return ChatListItem(presentationData: chatListPresentationData, context: context, chatListLocation: .chatList(groupId: .root), filterData: nil, index: .chatList(EngineChatList.Item.Index.ChatList(pinningIndex: 0, messageIndex: EngineMessage.Index(id: EngineMessage.Id(peerId: peer1.id, namespace: 0, id: 0), timestamp: timestamp1))), content: .peer(ChatListItemContent.PeerData(
                    messages: [message],
                    peer: EngineRenderedPeer(peer: peer1),
                    threadInfo: nil,
                    combinedReadState: readState,
                    isRemovedFromTotalUnreadCount: false,
                    presence: nil,
                    hasUnseenMentions: false,
                    hasUnseenReactions: false,
                    draftState: nil,
                    mediaDraftContentType: nil,
                    inputActivities: nil,
                    promoInfo: nil,
                    ignoreUnreadBadge: false,
                    displayAsMessage: false,
                    hasFailedMessages: false,
                    forumTopicData: nil,
                    topForumTopicItems: [],
                    autoremoveTimeout: nil,
                    storyState: nil,
                    requiresPremiumForMessaging: false,
                    displayAsTopicList: false,
                    tags: []
                )), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enabledContextActions: nil, hiddenOffset: false, interaction: interaction)
            }
            
            var itemNodes: [ChatListItemNode] = []
            for i in 0 ..< items.count {
                items[i].nodeConfiguredForParams(async: { f in f() }, params: ListViewItemLayoutParams(width: size.width, leftInset: 0.0, rightInset: 0.0, availableHeight: 100.0), synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: (i == items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    if let itemNode = node as? ChatListItemNode {
                        itemNodes.append(itemNode)
                    }
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
            }
            
            self.maskNode.image = generateImage(size, rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                var currentY: CGFloat = 0.0
                let fakeLabelPlaceholderHeight: CGFloat = 8.0
                
                func fillLabelPlaceholderRect(origin: CGPoint, width: CGFloat) {
                    let startPoint = origin
                    let diameter = fakeLabelPlaceholderHeight
                    context.fillEllipse(in: CGRect(origin: startPoint, size: CGSize(width: diameter, height: diameter)))
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: startPoint.x + width - diameter, y: startPoint.y), size: CGSize(width: diameter, height: diameter)))
                    context.fill(CGRect(origin: CGPoint(x: startPoint.x + diameter / 2.0, y: startPoint.y), size: CGSize(width: width - diameter, height: diameter)))
                }
                
                while currentY < size.height {
                    let sampleIndex = 0
                    let itemHeight: CGFloat = itemNodes[sampleIndex].contentSize.height
                    
                    context.setFillColor(UIColor.black.cgColor)
                    
                    let textFrame = itemNodes[sampleIndex].textNode.textNode.frame.offsetBy(dx: 0.0, dy: currentY)
                    
                    fillLabelPlaceholderRect(origin: CGPoint(x: textFrame.minX, y: currentY + itemHeight - floor(itemNodes[sampleIndex].titleNode.frame.midY - fakeLabelPlaceholderHeight / 2.0) - fakeLabelPlaceholderHeight), width: 60.0)
                    
                    fillLabelPlaceholderRect(origin: CGPoint(x: textFrame.minX, y: currentY + floor((itemHeight - fakeLabelPlaceholderHeight) / 2.0)), width: 120.0)
                    fillLabelPlaceholderRect(origin: CGPoint(x: textFrame.minX + 120.0 + 10.0, y: currentY + floor((itemHeight - fakeLabelPlaceholderHeight) / 2.0)), width: 60.0)
                    
                    let dateFrame = itemNodes[sampleIndex].dateNode.frame.offsetBy(dx: 0.0, dy: currentY)
                    fillLabelPlaceholderRect(origin: CGPoint(x: dateFrame.maxX - 30.0, y: dateFrame.minY + 4.0), width: 30.0)
                    
                    currentY += itemHeight
                }
            })
            
            self.effectNode.update(backgroundColor: presentationData.theme.list.mediaPlaceholderColor, foregroundColor: presentationData.theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4))
            self.effectNode.updateAbsoluteRect(CGRect(origin: CGPoint(), size: size), within: size)
        }
        transition.updateFrame(node: self.maskNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
        transition.updateFrame(node: self.effectNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: size))
    }
}


private final class PeerInfoScreenPersonalChannelItemNode: PeerInfoScreenItemNode {
    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    
    private let extractedBackgroundImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let selectionNode: PeerInfoScreenSelectableBackgroundNode
    private let maskNode: ASImageNode
    
    private let bottomSeparatorNode: ASDisplayNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenPersonalChannelItem?
    private var presentationData: PresentationData?
    private var theme: PresentationTheme?
    
    private var itemNode: ListViewItemNode?
    private var loadingOverlayNode: LoadingOverlayNode?
    
    override init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        var bringToFrontForHighlightImpl: (() -> Void)?
        self.selectionNode = PeerInfoScreenSelectableBackgroundNode(bringToFrontForHighlight: { bringToFrontForHighlightImpl?() })
        self.selectionNode.isUserInteractionEnabled = false
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init()
        
        bringToFrontForHighlightImpl = { [weak self] in
            self?.bringToFrontForHighlight?()
        }
        
        self.addSubnode(self.bottomSeparatorNode)
        self.addSubnode(self.selectionNode)
        
        self.containerNode.addSubnode(self.contextSourceNode)
        self.containerNode.targetNodeForActivationProgress = self.contextSourceNode.contentNode
        self.addSubnode(self.containerNode)
        
        self.addSubnode(self.maskNode)
        
        self.contextSourceNode.contentNode.clipsToBounds = true
        
        self.contextSourceNode.contentNode.addSubnode(self.extractedBackgroundImageNode)
        
        self.addSubnode(self.activateArea)
        
        self.containerNode.isGestureEnabled = false
        
        self.contextSourceNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
            guard let strongSelf = self, let theme = strongSelf.theme else {
                return
            }
            
            if isExtracted {
                strongSelf.extractedBackgroundImageNode.image = generateStretchableFilledCircleImage(diameter: 28.0, color: theme.list.plainBackgroundColor)
            }
            
            if let extractedRect = strongSelf.extractedRect, let nonExtractedRect = strongSelf.nonExtractedRect {
                let rect = isExtracted ? extractedRect : nonExtractedRect
                transition.updateFrame(node: strongSelf.extractedBackgroundImageNode, frame: rect)
            }
            
            transition.updateAlpha(node: strongSelf.extractedBackgroundImageNode, alpha: isExtracted ? 1.0 : 0.0, completion: { _ in
                if !isExtracted {
                    self?.extractedBackgroundImageNode.image = nil
                }
            })
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateTouchesAtPoint(point)
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    @objc private func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
        case .ended:
            if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
                    self.item?.action()
                case .longTap:
                    break
                default:
                    break
                }
            }
        default:
            break
        }
    }
    
    override func update(context: AccountContext, width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenPersonalChannelItem else {
            return 50.0
        }
        
        self.item = item
        self.presentationData = presentationData
        self.theme = presentationData.theme
        
        self.selectionNode.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.item?.action()
            }
        }
                
        let sideInset: CGFloat = 16.0 + safeInsets.left
        
        self.bottomSeparatorNode.backgroundColor = presentationData.theme.list.itemBlocksSeparatorColor
        
        let chatListPresentationData = ChatListPresentationData(
            theme: presentationData.theme,
            fontSize: presentationData.listsFontSize,
            strings: presentationData.strings,
            dateTimeFormat: presentationData.dateTimeFormat,
            nameSortOrder: presentationData.nameSortOrder,
            nameDisplayOrder: presentationData.nameDisplayOrder,
            disableAnimations: false
        )
        
        let chatListNodeInteraction = ChatListNodeInteraction(
            context: item.context,
            animationCache: item.context.animationCache,
            animationRenderer: item.context.animationRenderer,
            activateSearch: {
            },
            peerSelected: { _, _, _, _, _ in
            },
            disabledPeerSelected: { _, _, _ in
            },
            togglePeerSelected: { _, _ in
            },
            togglePeersSelection: { _, _ in
            },
            additionalCategorySelected: { _ in
            },
            messageSelected: { _, _, _, _ in
            },
            groupSelected: { _ in
            },
            addContact: { _ in
            },
            setPeerIdWithRevealedOptions: { _, _ in
            },
            setItemPinned: { _, _ in
            },
            setPeerMuted: { _, _ in
            },
            setPeerThreadMuted: { _, _, _ in
            },
            deletePeer: { _, _ in
            },
            deletePeerThread: { _, _ in
            },
            setPeerThreadStopped: { _, _, _ in
            },
            setPeerThreadPinned: { _, _, _ in
            },
            setPeerThreadHidden: { _, _, _ in
            },
            updatePeerGrouping: { _, _ in
            },
            togglePeerMarkedUnread: { _, _ in
            },
            toggleArchivedFolderHiddenByDefault: {
            },
            toggleThreadsSelection: { _, _ in
            },
            hidePsa: { _ in
            },
            activateChatPreview: nil,
            present: { _ in
            },
            openForumThread: { _, _ in
            },
            openStorageManagement: {
            },
            openPasswordSetup: {
            },
            openPremiumIntro: {
            },
            openPremiumGift: { _, _ in
            },
            openPremiumManagement: {
            },
            openActiveSessions: {
            },
            openBirthdaySetup: {
            },
            performActiveSessionAction: { _, _ in
            },
            openChatFolderUpdates: {
            },
            hideChatFolderUpdates: {
            },
            openStories: { [weak self] _, sourceNode in
                guard let self, let item = self.item else {
                    return
                }
                guard let itemNode = self.itemNode as? ChatListItemNode else {
                    return
                }
                guard let controller = item.controller() else {
                    return
                }
                
                StoryContainerScreen.openPeerStories(context: item.context, peerId: item.data.peer.peerId, parentController: controller, avatarNode: itemNode.avatarNode)
            },
            openStarsTopup: { _ in
            },
            dismissNotice: { _ in
            },
            editPeer: { _ in
            },
            openWebApp: { _ in
            },
            openPhotoSetup: {
            },
            openAdInfo: { _, _ in
            },
            openAccountFreezeInfo: {
            },
            openUrl: { _ in
            }
        )
        
        let index: EngineChatList.Item.Index
        let messages: [EngineMessage]
        let isLoading = item.data.isLoading
        
        if !isLoading, !item.data.topMessages.isEmpty {
            index = EngineChatList.Item.Index.chatList(ChatListIndex(pinningIndex: nil, messageIndex: item.data.topMessages[0].index))
            messages = item.data.topMessages
        } else {
            index = EngineChatList.Item.Index.chatList(ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: item.data.peer.peerId, namespace: Namespaces.Message.Cloud, id: 1), timestamp: 0)))
            messages = []
        }
        
        let chatListItem = ChatListItem(
            presentationData: chatListPresentationData,
            context: item.context,
            chatListLocation: .chatList(groupId: .root),
            filterData: nil,
            index: index,
            content: .peer(ChatListItemContent.PeerData(
                messages: messages,
                peer: item.data.peer,
                threadInfo: nil,
                combinedReadState: nil,
                isRemovedFromTotalUnreadCount: false,
                presence: nil,
                hasUnseenMentions: false,
                hasUnseenReactions: false,
                draftState: nil,
                mediaDraftContentType: nil,
                inputActivities: nil,
                promoInfo: nil,
                ignoreUnreadBadge: false,
                displayAsMessage: false,
                hasFailedMessages: false,
                forumTopicData: nil,
                topForumTopicItems: [],
                autoremoveTimeout: nil,
                storyState: item.data.storyStats.flatMap { storyStats in
                    return ChatListItemContent.StoryState(
                        stats: storyStats,
                        hasUnseenCloseFriends: false
                    )
                },
                requiresPremiumForMessaging: false,
                displayAsTopicList: false,
                tags: [],
                customMessageListData: ChatListItemContent.CustomMessageListData(
                    commandPrefix: nil,
                    searchQuery: nil,
                    messageCount: nil,
                    hideSeparator: true,
                    hideDate: isLoading,
                    hidePeerStatus: false
                )
            )),
            editing: false,
            hasActiveRevealControls: false,
            selected: false,
            header: nil,
            enabledContextActions: nil,
            hiddenOffset: false,
            interaction: chatListNodeInteraction
        )
        var itemNode: ListViewItemNode?
        let params = ListViewItemLayoutParams(width: width - safeInsets.left - safeInsets.right, leftInset: 0.0, rightInset: 0.0, availableHeight: 1000.0)
        if let current = self.itemNode {
            itemNode = current
            chatListItem.updateNode(
                async: { f in f () },
                node: {
                    return current
                },
                params: params,
                previousItem: nil,
                nextItem: nil, animation: .None,
                completion: { layout, apply in
                    let nodeFrame = CGRect(origin: current.frame.origin, size: CGSize(width: layout.size.width, height: layout.size.height))
                    
                    current.contentSize = layout.contentSize
                    current.insets = layout.insets
                    current.frame = nodeFrame
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
        } else {
            var outItemNode: ListViewItemNode?
            chatListItem.nodeConfiguredForParams(
                async: { f in f() },
                params: params,
                synchronousLoads: true,
                previousItem: nil,
                nextItem: nil,
                completion: { node, apply in
                    outItemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                }
            )
            itemNode = outItemNode
        }
        
        let height = itemNode?.contentSize.height ?? 50.0
        
        if self.itemNode !== itemNode {
            self.itemNode?.removeFromSupernode()
            
            self.itemNode = itemNode
            if let itemNode {
                itemNode.isUserInteractionEnabled = false
                self.contextSourceNode.contentNode.addSubnode(itemNode)
            }
        }
        let itemFrame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        if let itemNode = self.itemNode {
            itemNode.frame = itemFrame
        }
        
        if let itemNode = self.itemNode, item.data.isLoading {
            let loadingOverlayNode: LoadingOverlayNode
            if let current = self.loadingOverlayNode {
                loadingOverlayNode = current
            } else {
                loadingOverlayNode = LoadingOverlayNode()
                self.loadingOverlayNode = loadingOverlayNode
                itemNode.supernode?.insertSubnode(loadingOverlayNode, aboveSubnode: itemNode)
            }
            loadingOverlayNode.frame = itemFrame
            loadingOverlayNode.update(
                context: item.context,
                size: itemFrame.size,
                isInlineMode: false,
                presentationData: presentationData,
                transition: .immediate
            )
        } else {
            if let loadingOverlayNode = self.loadingOverlayNode {
                self.loadingOverlayNode = nil
                loadingOverlayNode.removeFromSupernode()
            }
        }
        
        let highlightNodeOffset: CGFloat = topItem == nil ? 0.0 : UIScreenPixel
        self.selectionNode.update(size: CGSize(width: width, height: height + highlightNodeOffset), theme: presentationData.theme, transition: transition)
        transition.updateFrame(node: self.selectionNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -highlightNodeOffset), size: CGSize(width: width, height: height + highlightNodeOffset)))
        
        transition.updateFrame(node: self.bottomSeparatorNode, frame: CGRect(origin: CGPoint(x: sideInset, y: height - UIScreenPixel), size: CGSize(width: width - sideInset, height: UIScreenPixel)))
        transition.updateAlpha(node: self.bottomSeparatorNode, alpha: bottomItem == nil ? 0.0 : 1.0)
        
        let hasCorners = hasCorners && (topItem == nil || bottomItem == nil)
        let hasTopCorners = hasCorners && topItem == nil
        let hasBottomCorners = hasCorners && bottomItem == nil
        
        self.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners) : nil
        self.maskNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        self.bottomSeparatorNode.isHidden = hasBottomCorners
        
        self.activateArea.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: height))
        
        let contentSize = CGSize(width: width, height: height)
        self.containerNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        self.contextSourceNode.frame = CGRect(origin: CGPoint(), size: contentSize)
        transition.updateFrame(node: self.contextSourceNode.contentNode, frame: CGRect(origin: CGPoint(), size: contentSize))
        
        let nonExtractedRect = CGRect(origin: CGPoint(), size: CGSize(width: contentSize.width, height: contentSize.height))
        let extractedRect = nonExtractedRect
        self.extractedRect = extractedRect
        self.nonExtractedRect = nonExtractedRect
        
        if self.contextSourceNode.isExtractedToContextPreview {
            self.extractedBackgroundImageNode.frame = extractedRect
        } else {
            self.extractedBackgroundImageNode.frame = nonExtractedRect
        }
        self.contextSourceNode.contentRect = extractedRect
        
        return height
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        var isHighlighted = false
        if let point, let itemNode = self.itemNode as? ChatListItemNode {
            if !itemNode.avatarNode.view.convert(itemNode.avatarNode.view.bounds, to: self.view).contains(point) {
                isHighlighted = true
            } else if let item = self.item, item.data.storyStats == nil {
                isHighlighted = true
            }
        }
        
        if isHighlighted {
            self.selectionNode.updateIsHighlighted(true)
        } else {
            self.selectionNode.updateIsHighlighted(false)
        }
    }
}
