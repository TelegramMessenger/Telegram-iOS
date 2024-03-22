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

final class PeerInfoScreenPersonalChannelItem: PeerInfoScreenItem {
    let id: AnyHashable
    let context: AccountContext
    let data: PeerInfoPersonalChannelData
    let requestLayout: (Bool) -> Void
    let action: () -> Void
    
    init(
        id: AnyHashable,
        context: AccountContext,
        data: PeerInfoPersonalChannelData,
        requestLayout: @escaping (Bool) -> Void,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.context = context
        self.data = data
        self.requestLayout = requestLayout
        self.action = action
    }
    
    func node() -> PeerInfoScreenItemNode {
        return PeerInfoScreenPersonalChannelItemNode()
    }
}

private final class PeerInfoScreenPersonalChannelItemNode: PeerInfoScreenItemNode {
    private let containerNode: ContextControllerSourceNode
    private let contextSourceNode: ContextExtractedContentContainingNode
    
    private let extractedBackgroundImageNode: ASImageNode
    
    private var extractedRect: CGRect?
    private var nonExtractedRect: CGRect?
    
    private let maskNode: ASImageNode
    
    private let bottomSeparatorNode: ASDisplayNode
    
    private let activateArea: AccessibilityAreaNode
    
    private var item: PeerInfoScreenPersonalChannelItem?
    private var presentationData: PresentationData?
    private var theme: PresentationTheme?
    
    private var itemNode: ListViewItemNode?
    
    override init() {
        self.contextSourceNode = ContextExtractedContentContainingNode()
        self.containerNode = ContextControllerSourceNode()
        
        self.extractedBackgroundImageNode = ASImageNode()
        self.extractedBackgroundImageNode.displaysAsynchronously = false
        self.extractedBackgroundImageNode.alpha = 0.0
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.bottomSeparatorNode = ASDisplayNode()
        self.bottomSeparatorNode.isLayerBacked = true
        
        self.activateArea = AccessibilityAreaNode()
        
        super.init()
        
        self.addSubnode(self.bottomSeparatorNode)
        
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
    
    override func update(width: CGFloat, safeInsets: UIEdgeInsets, presentationData: PresentationData, item: PeerInfoScreenItem, topItem: PeerInfoScreenItem?, bottomItem: PeerInfoScreenItem?, hasCorners: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        guard let item = item as? PeerInfoScreenPersonalChannelItem else {
            return 50.0
        }
        
        self.item = item
        self.presentationData = presentationData
        self.theme = presentationData.theme
                
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
            peerSelected: { _, _, _, _ in
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
            activateChatPreview: { _, _, _, _, _ in
            },
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
            openPremiumGift: { _ in
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
            openStories: { _, _ in
            },
            dismissNotice: { _ in
            },
            editPeer: { _ in
            }
        )
        
        let index: EngineChatList.Item.Index
        let messages: [EngineMessage]
        if let message = item.data.topMessage {
            index = EngineChatList.Item.Index.chatList(ChatListIndex(pinningIndex: nil, messageIndex: message.index))
            messages = [message]
        } else {
            index = EngineChatList.Item.Index.chatList(ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: item.data.peer.id, namespace: Namespaces.Message.Cloud, id: 1), timestamp: 0)))
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
                peer: EngineRenderedPeer(peer: item.data.peer),
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
                storyState: nil,
                requiresPremiumForMessaging: false,
                displayAsTopicList: false,
                tags: [],
                customMessageListData: ChatListItemContent.CustomMessageListData(
                    commandPrefix: nil,
                    searchQuery: nil,
                    messageCount: nil,
                    hideSeparator: true,
                    hideDate: false
                )
            )),
            editing: false,
            hasActiveRevealControls: false,
            selected: false,
            header: nil,
            enableContextActions: false,
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
        if let itemNode = self.itemNode {
            itemNode.frame = CGRect(origin: CGPoint(x: safeInsets.left, y: 0.0), size: CGSize(width: width - safeInsets.left - safeInsets.right, height: height))
        }
        
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
    }
}
