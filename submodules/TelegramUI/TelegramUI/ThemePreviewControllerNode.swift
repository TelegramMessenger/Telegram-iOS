import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences

class ThemePreviewControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let previewTheme: PresentationTheme
    private var presentationData: PresentationData
    
    private let scrollNode: ASScrollNode
    private let pageControlBackgroundNode: ASDisplayNode
    private let pageControlNode: PageControlNode
    
    private let chatListBackgroundNode: ASDisplayNode
    private var chatNodes: [ListViewItemNode]?

    private let chatBackgroundNode: ASDisplayNode
    private var messageNodes: [ListViewItemNode]?

    private let toolbarNode: WallpaperGalleryToolbarNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var colorDisposable: Disposable?
    
    init(context: AccountContext, previewTheme: PresentationTheme, dismiss: @escaping () -> Void, apply: @escaping () -> Void) {
        self.context = context
        self.previewTheme = previewTheme
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.scrollNode = ASScrollNode()
        self.pageControlBackgroundNode = ASDisplayNode()
        self.pageControlBackgroundNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.3)
        self.pageControlBackgroundNode.cornerRadius = 6.0
        
        self.pageControlNode = PageControlNode(dotColor: previewTheme.chatList.unreadBadgeActiveBackgroundColor, inactiveDotColor: previewTheme.list.pageIndicatorInactiveColor)
    
        self.chatListBackgroundNode = ASDisplayNode()
        self.chatBackgroundNode = ASDisplayNode()
        
        self.toolbarNode = WallpaperGalleryToolbarNode(theme: self.previewTheme, strings: self.presentationData.strings)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.previewTheme.list.plainBackgroundColor
        
        self.chatListBackgroundNode.backgroundColor = self.previewTheme.chatList.backgroundColor
        
        if case let .color(value) = self.previewTheme.chat.defaultWallpaper {
            self.chatBackgroundNode.backgroundColor = UIColor(rgb: UInt32(bitPattern: value))
        }
        
        self.pageControlNode.isUserInteractionEnabled = false
        self.pageControlNode.pagesCount = 2
        
        self.addSubnode(self.scrollNode)
        self.addSubnode(self.pageControlBackgroundNode)
        self.addSubnode(self.pageControlNode)
        self.addSubnode(self.toolbarNode)
        
        self.scrollNode.addSubnode(self.chatListBackgroundNode)
        self.scrollNode.addSubnode(self.chatBackgroundNode)
        
        self.toolbarNode.cancel = {
            dismiss()
        }
        self.toolbarNode.done = {
            apply()
        }
        
        self.colorDisposable = (chatServiceBackgroundColor(wallpaper: self.previewTheme.chat.defaultWallpaper, mediaBox: context.account.postbox.mediaBox)
        |> deliverOnMainQueue).start(next: { [weak self] color in
            if let strongSelf = self {
                if strongSelf.previewTheme.chat.defaultWallpaper.hasWallpaper {
                    strongSelf.pageControlBackgroundNode.backgroundColor = color
                } else {
                    strongSelf.pageControlBackgroundNode.backgroundColor = .clear
                }
            }
        })
    }
    
    deinit {
        self.colorDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.isPagingEnabled = true
        self.scrollNode.view.delegate = self
        self.pageControlNode.setPage(0.0)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let bounds = scrollView.bounds
        if !bounds.width.isZero {
            self.pageControlNode.setPage(scrollView.contentOffset.x / bounds.width)
        }
    }
    
    func animateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    private func updateChatsLayout(layout: ContainerViewLayout, topInset: CGFloat, transition: ContainedViewLayoutTransition) {
        var items: [ChatListItem] = []
        
        let interaction = ChatListNodeInteraction(activateSearch: {}, peerSelected: { _ in }, togglePeerSelected: { _ in }, messageSelected: { _, _, _ in}, groupSelected: { _ in }, addContact: { _ in }, setPeerIdWithRevealedOptions: { _, _ in }, setItemPinned: { _, _ in }, setPeerMuted: { _, _ in }, deletePeer: { _ in }, updatePeerGrouping: { _, _ in }, togglePeerMarkedUnread: { _, _ in}, toggleArchivedFolderHiddenByDefault: {})
        let chatListPresentationData = ChatListPresentationData(theme: self.previewTheme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)
        
        let peers = SimpleDictionary<PeerId, Peer>()
        let messages = SimpleDictionary<MessageId, Message>()
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 1)
        let peer1 = TelegramUser(id: peerId, accessHash: nil, firstName: "", lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let peer2 = TelegramUser(id: peerId, accessHash: nil, firstName: "", lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(namespace: 0, id: 1), namespace: 0, id: 0), timestamp: 66003)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66003, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer1, text: "", attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer1), combinedReadState: nil, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(namespace: 0, id: 2), namespace: 0, id: 0), timestamp: 66000)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer1, text: "", attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer2), combinedReadState: nil, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right)
        if let chatNodes = self.chatNodes {
            for i in 0 ..< items.count {
                let itemNode = chatNodes[i]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: layout.size.width, height: layout.size.height))
                    
                    itemNode.contentSize = layout.contentSize
                    itemNode.insets = layout.insets
                    itemNode.frame = nodeFrame
                    itemNode.isUserInteractionEnabled = false
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            }
        } else {
            var chatNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                var itemNode: ListViewItemNode?
                items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                //itemNode!.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
                itemNode!.isUserInteractionEnabled = false
                chatNodes.append(itemNode!)
                self.chatListBackgroundNode.addSubnode(itemNode!)
            }
            self.chatNodes = chatNodes
        }
        
        if let chatNodes = self.chatNodes {
            var topOffset: CGFloat = topInset
            for itemNode in chatNodes {
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: topOffset), size: itemNode.frame.size))
                topOffset += itemNode.frame.height
            }
        }
    }
    
    private func updateMessagesLayout(layout: ContainerViewLayout, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) {
        var items: [ChatMessageItem] = []
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 1)
        let otherPeerId = self.context.account.peerId
        var peers = SimpleDictionary<PeerId, Peer>()
        var messages = SimpleDictionary<MessageId, Message>()
        peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: "", lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        peers[otherPeerId] = TelegramUser(id: otherPeerId, accessHash: nil, firstName: "", lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let replyMessageId = MessageId(peerId: peerId, namespace: 0, id: 3)
        messages[replyMessageId] = Message(stableId: 3, stableVersion: 0, id: replyMessageId, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let controllerInteraction = ChatControllerInteraction.default
        let chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: self.previewTheme, wallpaper: self.previewTheme.chat.defaultWallpaper), fontSize: self.presentationData.fontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: false, largeEmoji: false)
        
        items.append(ChatMessageItem(presentationData: chatPresentationData, context: self.context, chatLocation: .peer(peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false), controllerInteraction: controllerInteraction, content: .message(message: Message(stableId: 4, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 4), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66003, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: "", attributes: [ReplyMessageAttribute(messageId: replyMessageId)], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), read: true, selection: .none, attributes: ChatMessageEntryAttributes()), disableDate: false))
        
        items.append(ChatMessageItem(presentationData: chatPresentationData, context: self.context, chatLocation: .peer(peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false), controllerInteraction: controllerInteraction, content: .message(message: Message(stableId: 3, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 3), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66002, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), read: true, selection: .none, attributes: ChatMessageEntryAttributes()), disableDate: false))
        
        items.append(ChatMessageItem(presentationData: chatPresentationData, context: self.context, chatLocation: .peer(peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false), controllerInteraction: controllerInteraction, content: .message(message: Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 2), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66001, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), read: true, selection: .none, attributes: ChatMessageEntryAttributes()), disableDate: false))
        
        let voiceAttributes: [TelegramMediaFileAttribute] = [.Audio(isVoice: true, duration: 14, title: nil, performer: nil, waveform: MemoryBuffer())]
        let voiceMedia = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: nil, attributes: voiceAttributes)
        
        items.append(ChatMessageItem(presentationData: chatPresentationData, context: self.context, chatLocation: .peer(peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false, forcedResourceStatus: FileMediaResourceStatus(mediaStatus: .playbackStatus(.playing), fetchStatus: .Local)), controllerInteraction: controllerInteraction, content: .message(message: Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66001, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [voiceMedia], peers: peers, associatedMessages: messages, associatedMessageIds: []), read: true, selection: .none, attributes: ChatMessageEntryAttributes()), disableDate: false))
        
        items.append(ChatMessageItem(presentationData: chatPresentationData, context: self.context, chatLocation: .peer(peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false), controllerInteraction: controllerInteraction, content: .message(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: "", attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), read: true, selection: .none, attributes: ChatMessageEntryAttributes()), disableDate: false))
        
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right)
        if let messageNodes = self.messageNodes {
            for i in 0 ..< items.count {
                let itemNode = messageNodes[i]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: layout.size.width, height: layout.size.height))
                    
                    itemNode.contentSize = layout.contentSize
                    itemNode.insets = layout.insets
                    itemNode.frame = nodeFrame
                    itemNode.isUserInteractionEnabled = false
                    
                    apply(ListViewItemApply(isOnScreen: true))
                })
            }
        } else {
            var messageNodes: [ListViewItemNode] = []
            for i in 0 ..< items.count {
                var itemNode: ListViewItemNode?
                items[i].nodeConfiguredForParams(async: { $0() }, params: params, synchronousLoads: false, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], completion: { node, apply in
                    itemNode = node
                    apply().1(ListViewItemApply(isOnScreen: true))
                })
                itemNode!.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
                itemNode!.isUserInteractionEnabled = false
                messageNodes.append(itemNode!)
                self.chatBackgroundNode.addSubnode(itemNode!)
            }
            self.messageNodes = messageNodes
        }
        
        if let messageNodes = self.messageNodes {
            var bottomOffset: CGFloat = layout.size.height - bottomInset - 9.0
            for itemNode in messageNodes {
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: bottomOffset - itemNode.frame.height), size: itemNode.frame.size))
                bottomOffset -= itemNode.frame.height
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let bounds = CGRect(origin: CGPoint(), size: layout.size)
        self.scrollNode.frame = bounds
        
        let toolbarHeight = 49.0 + layout.intrinsicInsets.bottom
        self.chatListBackgroundNode.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: bounds.height)
        self.chatBackgroundNode.frame = CGRect(x: bounds.width, y: 0.0, width: bounds.width, height: bounds.height)
    
        self.scrollNode.view.contentSize = CGSize(width: bounds.width * 2.0, height: bounds.height)
        
        transition.updateFrame(node: self.toolbarNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: 49.0 + layout.intrinsicInsets.bottom)))
        self.toolbarNode.updateLayout(size: CGSize(width: layout.size.width, height: 49.0), layout: layout, transition: transition)
        
        self.updateChatsLayout(layout: layout, topInset: navigationBarHeight, transition: transition)
        self.updateMessagesLayout(layout: layout, bottomInset: toolbarHeight + 66.0, transition: transition)
        
        let pageControlSize = self.pageControlNode.measure(CGSize(width: bounds.width, height: 100.0))
        let pageControlFrame = CGRect(origin: CGPoint(x: floor((bounds.width - pageControlSize.width) / 2.0), y: layout.size.height - toolbarHeight - 42.0), size: pageControlSize)
        self.pageControlNode.frame = pageControlFrame
        self.pageControlBackgroundNode.frame = CGRect(x: pageControlFrame.minX - 11.0, y: pageControlFrame.minY - 12.0, width: pageControlFrame.width + 22.0, height: 30.0)
    }
}
