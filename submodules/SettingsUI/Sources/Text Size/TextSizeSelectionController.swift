import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ChatListUI
import WallpaperResources
import LegacyComponents
import ItemListUI
import WallpaperBackgroundNode

private func generateMaskImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 1.0, height: 80.0), opaque: false, rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let gradientColors = [color.withAlphaComponent(0.0).cgColor, color.cgColor, color.cgColor] as CFArray
        
        var locations: [CGFloat] = [0.0, 0.75, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: 80.0), options: CGGradientDrawingOptions())
    })
}

private final class TextSizeSelectionControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var presentationThemeSettings: PresentationThemeSettings
    private var presentationData: PresentationData
    
    private let referenceTimestamp: Int32
    
    private let scrollNode: ASScrollNode
    private let pageControlBackgroundNode: ASDisplayNode
    private let pageControlNode: PageControlNode
    
    private let chatListBackgroundNode: ASDisplayNode
    private var chatNodes: [ListViewItemNode]?
    private let maskNode: ASImageNode
    private let separatorNode: ASDisplayNode
    private let chatBackgroundNode: WallpaperBackgroundNode
    private let messagesContainerNode: ASDisplayNode
    private var dateHeaderNode: ListViewItemHeaderNode?
    private var messageNodes: [ListViewItemNode]?
    private let toolbarNode: TextSelectionToolbarNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    init(context: AccountContext, presentationThemeSettings: PresentationThemeSettings, dismiss: @escaping () -> Void, apply: @escaping (Bool, PresentationFontSize, PresentationFontSize) -> Void) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationThemeSettings = presentationThemeSettings
        
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(Set([.era, .year, .month, .day, .hour, .minute, .second]), from: Date())
        components.hour = 13
        components.minute = 0
        components.second = 0
        self.referenceTimestamp = Int32(calendar.date(from: components)?.timeIntervalSince1970 ?? 0.0)
        
        self.scrollNode = ASScrollNode()
        
        self.pageControlBackgroundNode = ASDisplayNode()
        self.pageControlBackgroundNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.3)
        self.pageControlBackgroundNode.cornerRadius = 10.5
        
        self.pageControlNode = PageControlNode(dotSpacing: 7.0, dotColor: .white, inactiveDotColor: UIColor.white.withAlphaComponent(0.4))
    
        self.chatListBackgroundNode = ASDisplayNode()
        self.chatBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        self.chatBackgroundNode.displaysAsynchronously = false
        
        self.messagesContainerNode = ASDisplayNode()
        self.messagesContainerNode.clipsToBounds = true
        self.messagesContainerNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        
        self.chatBackgroundNode.update(wallpaper: self.presentationData.chatWallpaper)
        self.chatBackgroundNode.updateBubbleTheme(bubbleTheme: self.presentationData.theme, bubbleCorners: self.presentationData.chatBubbleCorners)
                        
        self.toolbarNode = TextSelectionToolbarNode(presentationThemeSettings: self.presentationThemeSettings, presentationData: self.presentationData)
                
        self.maskNode = ASImageNode()
        self.maskNode.displaysAsynchronously = false
        self.maskNode.displayWithoutProcessing = true
        self.maskNode.contentMode = .scaleToFill
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = self.presentationData.theme.rootController.tabBar.separatorColor
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.chatListBackgroundNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.maskNode.image = generateMaskImage(color: self.presentationData.theme.chatList.backgroundColor)
        
        self.pageControlNode.isUserInteractionEnabled = false
        self.pageControlNode.pagesCount = 2
        
        self.addSubnode(self.scrollNode)
        self.chatListBackgroundNode.addSubnode(self.maskNode)
        self.addSubnode(self.pageControlBackgroundNode)
        self.addSubnode(self.pageControlNode)
        self.addSubnode(self.toolbarNode)
        
        self.scrollNode.addSubnode(self.chatListBackgroundNode)
        self.scrollNode.addSubnode(self.chatBackgroundNode)
        self.scrollNode.addSubnode(self.messagesContainerNode)
        
        self.addSubnode(self.separatorNode)
        
        self.toolbarNode.cancel = {
            dismiss()
        }
        var dismissed = false
        self.toolbarNode.done = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if !dismissed {
                dismissed = true
                apply(strongSelf.presentationThemeSettings.useSystemFont, strongSelf.presentationThemeSettings.fontSize, strongSelf.presentationThemeSettings.listsFontSize)
            }
        }
        self.toolbarNode.updateUseSystemFont = { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.presentationThemeSettings.useSystemFont = value
            strongSelf.updatePresentationThemeSettings(strongSelf.presentationThemeSettings)
        }
        self.toolbarNode.updateCustomFontSize = { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            switch strongSelf.toolbarNode.customMode {
            case .chat:
                strongSelf.presentationThemeSettings.fontSize = value
            case .list:
                strongSelf.presentationThemeSettings.listsFontSize = value
            }
            strongSelf.updatePresentationThemeSettings(strongSelf.presentationThemeSettings)
        }
          
        let _ = (chatServiceBackgroundColor(wallpaper: self.presentationData.chatWallpaper, mediaBox: context.account.postbox.mediaBox)
        |> deliverOnMainQueue).start(next: { [weak self] serviceColor in
            self?.pageControlBackgroundNode.backgroundColor = serviceColor
        })
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.isPagingEnabled = true
        self.scrollNode.view.delegate = self
        self.pageControlNode.setPage(0.0)
    }
    
    func updateFontSize() {
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let bounds = scrollView.bounds
        if !bounds.width.isZero {
            self.pageControlNode.setPage(scrollView.contentOffset.x / bounds.width)
            let pageIndex = Int(round(scrollView.contentOffset.x / bounds.width))
            let customMode: TextSelectionCustomMode = pageIndex >= 1 ? .list : .chat
            if customMode != self.toolbarNode.customMode {
                self.toolbarNode.setCustomMode(customMode)
                if let (layout, navigationBarHeight) = self.validLayout {
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                    self.recursivelyEnsureDisplaySynchronously(true)
                }
            }
        }
    }
    
    func animateIn(completion: (() -> Void)? = nil) {
        if let (layout, _) = self.validLayout, case .compact = layout.metrics.widthClass {
            self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
        }
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        if let (layout, _) = self.validLayout, case .compact = layout.metrics.widthClass {
            self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
                completion?()
            })
        } else {
            completion?()
        }
    }
    
    private func updateChatsLayout(layout: ContainerViewLayout, topInset: CGFloat, transition: ContainedViewLayoutTransition) {
        var items: [ChatListItem] = []
        
        let interaction = ChatListNodeInteraction(activateSearch: {}, peerSelected: { _, _, _ in }, disabledPeerSelected: { _ in }, togglePeerSelected: { _ in }, togglePeersSelection: { _, _ in }, additionalCategorySelected: { _ in
        }, messageSelected: { _, _, _ in}, groupSelected: { _ in }, addContact: { _ in }, setPeerIdWithRevealedOptions: { _, _ in }, setItemPinned: { _, _ in }, setPeerMuted: { _, _ in }, deletePeer: { _, _ in }, updatePeerGrouping: { _, _ in }, togglePeerMarkedUnread: { _, _ in}, toggleArchivedFolderHiddenByDefault: {}, hidePsa: { _ in
        }, activateChatPreview: { _, _, gesture in
            gesture?.cancel()
        }, present: { _ in })

        let chatListPresentationData = ChatListPresentationData(theme: self.presentationData.theme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)

        func makeChatListItem(
            peer: EnginePeer,
            author: EnginePeer,
            timestamp: Int32,
            text: String,
            isPinned: Bool = false,
            presenceTimestamp: Int32? = nil,
            hasInputActivity: Bool = false,
            unreadCount: Int32 = 0
        ) -> ChatListItem {
            return ChatListItem(
                presentationData: chatListPresentationData,
                context: self.context,
                peerGroupId: .root,
                filterData: nil,
                index: ChatListIndex(pinningIndex: isPinned ? 0 : nil, messageIndex: MessageIndex(id: MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 0), timestamp: timestamp)),
                content: .peer(
                    messages: [
                        EngineMessage(
                            stableId: 0,
                            stableVersion: 0,
                            id: EngineMessage.Id(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: 0),
                            globallyUniqueId: nil,
                            groupingKey: nil,
                            groupInfo: nil,
                            threadId: nil,
                            timestamp: timestamp,
                            flags: author.id == peer.id ? [.Incoming] : [],
                            tags: [],
                            globalTags: [],
                            localTags: [],
                            forwardInfo: nil,
                            author: author,
                            text: text,
                            attributes: [],
                            media: [],
                            peers: [:],
                            associatedMessages: [:],
                            associatedMessageIds: []
                        )
                    ],
                    peer: EngineRenderedPeer(peer: peer),
                    combinedReadState: EnginePeerReadCounters(incomingReadId: 1000, outgoingReadId: 1000, count: unreadCount, markedUnread: false),
                    isRemovedFromTotalUnreadCount: false,
                    presence: presenceTimestamp.flatMap { presenceTimestamp in
                        EnginePeer.Presence(status: .present(until: presenceTimestamp + 1000), lastActivity: presenceTimestamp)
                    },
                    hasUnseenMentions: false,
                    hasUnseenReactions: false,
                    draftState: nil,
                    inputActivities: hasInputActivity ? [(author, .typingText)] : [],
                    promoInfo: nil,
                    ignoreUnreadBadge: false,
                    displayAsMessage: false,
                    hasFailedMessages: false
                ),
                editing: false,
                hasActiveRevealControls: false,
                selected: false,
                header: nil,
                enableContextActions: false,
                hiddenOffset: false,
                interaction: interaction
            )
        }

        let selfPeer: EnginePeer = .user(TelegramUser(id: self.context.account.peerId, accessHash: nil, firstName: nil, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer1: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_1_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer2: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(2)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_2_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer3: EnginePeer = .channel(TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(3)), accessHash: nil, title: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_Name, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .group(.init(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil))
        let peer3Author: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(4)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_AuthorName, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer4: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(4)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_4_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer5: EnginePeer = .channel(TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(5)), accessHash: nil, title: self.presentationData.strings.Appearance_ThemePreview_ChatList_5_Name, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .broadcast(.init(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil))
        let peer6: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(5)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_6_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))

        let timestamp = self.referenceTimestamp

        let timestamp1 = timestamp + 120
        items.append(makeChatListItem(
            peer: peer1,
            author: selfPeer,
            timestamp: timestamp1,
            text: self.presentationData.strings.Appearance_ThemePreview_ChatList_1_Text,
            isPinned: true
        ))

        let presenceTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 + 60 * 60)
        let timestamp2 = timestamp + 3660
        items.append(makeChatListItem(
            peer: peer2,
            author: peer2,
            timestamp: timestamp2,
            text: "",
            presenceTimestamp: presenceTimestamp,
            hasInputActivity: true
        ))

        let timestamp3 = timestamp + 3200
        items.append(makeChatListItem(
            peer: peer3,
            author: peer3Author,
            timestamp: timestamp3,
            text: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_Text
        ))

        let timestamp4 = timestamp + 3000
        items.append(makeChatListItem(
            peer: peer4,
            author: peer4,
            timestamp: timestamp4,
            text: self.presentationData.strings.Appearance_ThemePreview_ChatList_4_Text
        ))

        let timestamp5 = timestamp + 1000
        items.append(makeChatListItem(
            peer: peer5,
            author: peer5,
            timestamp: timestamp5,
            text: self.presentationData.strings.Appearance_ThemePreview_ChatList_5_Text
        ))

        items.append(makeChatListItem(
            peer: peer6,
            author: peer6,
            timestamp: timestamp - 360,
            text: self.presentationData.strings.Appearance_ThemePreview_ChatList_6_Text,
            unreadCount: 1
        ))
        
        let width: CGFloat
        if case .regular = layout.metrics.widthClass {
            width = layout.size.width / 2.0
        } else {
            width = layout.size.width
        }
        
        let params = ListViewItemLayoutParams(width: width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, availableHeight: layout.size.height)
        if let chatNodes = self.chatNodes {
            for i in 0 ..< items.count {
                let itemNode = chatNodes[i]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: width, height: layout.size.height))
                    
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
                itemNode!.isUserInteractionEnabled = false
                chatNodes.append(itemNode!)
                if self.maskNode.supernode != nil {
                    self.chatListBackgroundNode.insertSubnode(itemNode!, belowSubnode: self.maskNode)
                } else {
                    self.chatListBackgroundNode.addSubnode(itemNode!)
                }
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
        let headerItem = self.context.sharedContext.makeChatMessageDateHeaderItem(context: self.context, timestamp:  self.referenceTimestamp, theme: self.presentationData.theme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder)
        
        var items: [ListViewItem] = []
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
        let otherPeerId = self.context.account.peerId
        var peers = SimpleDictionary<PeerId, Peer>()
        var messages = SimpleDictionary<MessageId, Message>()
        peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_Chat_2_ReplyName, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        peers[otherPeerId] = TelegramUser(id: otherPeerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_Chat_2_ReplyName, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let replyMessageId = MessageId(peerId: peerId, namespace: 0, id: 3)
        messages[replyMessageId] = Message(stableId: 3, stableVersion: 0, id: replyMessageId, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66000, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_1_Text, attributes: [], media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let message1 = Message(stableId: 4, stableVersion: 0, id: MessageId(peerId: otherPeerId, namespace: 0, id: 4), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66003, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_3_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: [message1], theme: self.presentationData.theme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.chatBackgroundNode, availableReactions: nil, isCentered: false))
        
        let message2 = Message(stableId: 3, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 3), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66002, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_2_Text, attributes: [ReplyMessageAttribute(messageId: replyMessageId, threadMessageId: nil)], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: [message2], theme: self.presentationData.theme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.chatBackgroundNode, availableReactions: nil, isCentered: false))
        
        let waveformBase64 = "DAAOAAkACQAGAAwADwAMABAADQAPABsAGAALAA0AGAAfABoAHgATABgAGQAYABQADAAVABEAHwANAA0ACQAWABkACQAOAAwACQAfAAAAGQAVAAAAEwATAAAACAAfAAAAHAAAABwAHwAAABcAGQAAABQADgAAABQAHwAAAB8AHwAAAAwADwAAAB8AEwAAABoAFwAAAB8AFAAAAAAAHwAAAAAAHgAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAAAA="
        let voiceAttributes: [TelegramMediaFileAttribute] = [.Audio(isVoice: true, duration: 23, title: nil, performer: nil, waveform: Data(base64Encoded: waveformBase64)!)]
        let voiceMedia = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: voiceAttributes)
        
        let message3 = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66001, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [voiceMedia], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: [message3], theme: self.presentationData.theme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: FileMediaResourceStatus(mediaStatus: .playbackStatus(.paused), fetchStatus: .Local), tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.chatBackgroundNode, availableReactions: nil, isCentered: false))
        
        let message4 = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: otherPeerId, namespace: 0, id: 2), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66001, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_1_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: [message4], theme: self.presentationData.theme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.chatBackgroundNode, availableReactions: nil, isCentered: false))
        
        let width: CGFloat
        if case .regular = layout.metrics.widthClass {
            width = layout.size.width / 2.0
        } else {
            width = layout.size.width
        }
        
        let params = ListViewItemLayoutParams(width: width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, availableHeight: layout.size.height)
        if let messageNodes = self.messageNodes {
            for i in 0 ..< items.count {
                let itemNode = messageNodes[i]
                items[i].updateNode(async: { $0() }, node: {
                    return itemNode
                }, params: params, previousItem: i == 0 ? nil : items[i - 1], nextItem: i == (items.count - 1) ? nil : items[i + 1], animation: .None, completion: { (layout, apply) in
                    let nodeFrame = CGRect(origin: itemNode.frame.origin, size: CGSize(width: width, height: layout.size.height))
                    
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
                itemNode!.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
                itemNode!.isUserInteractionEnabled = false
                messageNodes.append(itemNode!)
                self.messagesContainerNode.addSubnode(itemNode!)
            }
            self.messageNodes = messageNodes
        }
        
        var bottomOffset: CGFloat = 9.0 + bottomInset
        if let messageNodes = self.messageNodes {
            for itemNode in messageNodes {
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: bottomOffset), size: itemNode.frame.size))
                bottomOffset += itemNode.frame.height
                itemNode.updateFrame(itemNode.frame, within: layout.size)
            }
        }
        
        let dateHeaderNode: ListViewItemHeaderNode
        if let currentDateHeaderNode = self.dateHeaderNode {
            dateHeaderNode = currentDateHeaderNode
            headerItem.updateNode(dateHeaderNode, previous: nil, next: headerItem)
        } else {
            dateHeaderNode = headerItem.node(synchronousLoad: true)
            dateHeaderNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            self.messagesContainerNode.addSubnode(dateHeaderNode)
            self.dateHeaderNode = dateHeaderNode
        }
        
        transition.updateFrame(node: dateHeaderNode, frame: CGRect(origin: CGPoint(x: 0.0, y: bottomOffset), size: CGSize(width: layout.size.width, height: headerItem.height)))
        dateHeaderNode.updateLayout(size: self.messagesContainerNode.frame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right)
    }
    
    func updatePresentationThemeSettings(_ presentationThemeSettings: PresentationThemeSettings) {
        let fontSize: PresentationFontSize
        let listsFontSize: PresentationFontSize
        if presentationThemeSettings.useSystemFont {
            let pointSize = UIFont.preferredFont(forTextStyle: .body).pointSize
            fontSize = PresentationFontSize(systemFontSize: pointSize)
            listsFontSize = fontSize
        } else {
            fontSize = presentationThemeSettings.fontSize
            listsFontSize = presentationThemeSettings.listsFontSize
        }
        self.presentationData = self.presentationData.withFontSizes(chatFontSize: fontSize, listsFontSize: listsFontSize)
        self.toolbarNode.updatePresentationData(presentationData: self.presentationData)
        self.toolbarNode.updatePresentationThemeSettings(presentationThemeSettings: self.presentationThemeSettings)
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            self.recursivelyEnsureDisplaySynchronously(true)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        let bounds = CGRect(origin: CGPoint(), size: layout.size)
        self.scrollNode.frame = bounds
        
        let toolbarHeight = self.toolbarNode.updateLayout(width: layout.size.width, bottomInset: layout.intrinsicInsets.bottom, layout: layout, transition: transition)
        
        self.chatListBackgroundNode.frame = CGRect(x: bounds.width, y: 0.0, width: bounds.width, height: bounds.height)
        var chatFrame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: bounds.height)
        
        let bottomInset: CGFloat
        if case .regular = layout.metrics.widthClass {
            self.chatListBackgroundNode.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width / 2.0, height: bounds.height)
            chatFrame = CGRect(x: bounds.width / 2.0, y: 0.0, width: bounds.width / 2.0, height: bounds.height)
            self.scrollNode.view.contentSize = CGSize(width: bounds.width, height: bounds.height)
            
            self.pageControlNode.isHidden = true
            self.pageControlBackgroundNode.isHidden = true
            self.separatorNode.isHidden = false
            
            self.separatorNode.frame = CGRect(x: bounds.width / 2.0, y: 0.0, width: UIScreenPixel, height: bounds.height - toolbarHeight)
            
            bottomInset = 0.0
        } else {
            self.chatListBackgroundNode.frame = CGRect(x: bounds.width, y: 0.0, width: bounds.width, height: bounds.height)
            chatFrame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: bounds.height)
            self.scrollNode.view.contentSize = CGSize(width: bounds.width * 2.0, height: bounds.height)
            
            self.pageControlNode.isHidden = false
            self.pageControlBackgroundNode.isHidden = false
            self.separatorNode.isHidden = true
            
            bottomInset = 37.0
        }
        
        self.chatBackgroundNode.frame = chatFrame
        self.chatBackgroundNode.updateLayout(size: chatFrame.size, transition: transition)
        self.messagesContainerNode.frame = chatFrame
        
        transition.updateFrame(node: self.toolbarNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: toolbarHeight + layout.intrinsicInsets.bottom)))
        
        self.updateChatsLayout(layout: layout, topInset: navigationBarHeight, transition: transition)
        self.updateMessagesLayout(layout: layout, bottomInset: toolbarHeight + bottomInset, transition: transition)
        
        let pageControlSize = self.pageControlNode.measure(CGSize(width: bounds.width, height: 100.0))
        let pageControlFrame = CGRect(origin: CGPoint(x: floor((bounds.width - pageControlSize.width) / 2.0), y: layout.size.height - toolbarHeight - 28.0), size: pageControlSize)
        self.pageControlNode.frame = pageControlFrame
        self.pageControlBackgroundNode.frame = CGRect(x: pageControlFrame.minX - 7.0, y: pageControlFrame.minY - 7.0, width: pageControlFrame.width + 14.0, height: 21.0)
        
        transition.updateFrame(node: self.maskNode, frame: CGRect(x: 0.0, y: layout.size.height - toolbarHeight - 80.0, width: bounds.width, height: 80.0))
    }
}

final class TextSizeSelectionController: ViewController {
    private let context: AccountContext
    
    private var controllerNode: TextSizeSelectionControllerNode {
        return self.displayNode as! TextSizeSelectionControllerNode
    }
        
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var presentationThemeSettings: PresentationThemeSettings
    private var presentationThemeSettingsDisposable: Disposable?
    
    private var disposable: Disposable?
    private var applyDisposable = MetaDisposable()

    public init(context: AccountContext, presentationThemeSettings: PresentationThemeSettings) {
        self.context = context
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.presentationThemeSettings = presentationThemeSettings
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings))
        
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        self.navigationPresentation = .modal
        
        self.navigationItem.title = self.presentationData.strings.Appearance_TextSize_Title
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.presentationThemeSettingsDisposable?.dispose()
        self.disposable?.dispose()
        self.applyDisposable.dispose()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
        }
    }
    
    override public func loadDisplayNode() {
        super.loadDisplayNode()
        
        self.displayNode = TextSizeSelectionControllerNode(context: self.context, presentationThemeSettings: self.presentationThemeSettings, dismiss: { [weak self] in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
        }, apply: { [weak self] useSystemFont, fontSize, listsFontSize in
            if let strongSelf = self {
                strongSelf.apply(useSystemFont: useSystemFont, fontSize: fontSize, listsFontSize: listsFontSize)
            }
        })
        self.displayNodeDidLoad()
    }
    
    private func apply(useSystemFont: Bool, fontSize: PresentationFontSize, listsFontSize: PresentationFontSize) {
        let _ = (updatePresentationThemeSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { current in
            var current = current
            current.useSystemFont = useSystemFont
            current.fontSize = fontSize
            current.listsFontSize = listsFontSize
            return current
        })
        |> deliverOnMainQueue).start(completed: { [weak self] in
            self?.dismiss()
        })
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

private enum TextSelectionCustomMode {
    case list
    case chat
}

private final class TextSelectionToolbarNode: ASDisplayNode {
    private var presentationThemeSettings: PresentationThemeSettings
    private var presentationData: PresentationData
    
    private let cancelButton = HighlightableButtonNode()
    private let doneButton = HighlightableButtonNode()
    private let separatorNode = ASDisplayNode()
    private let topSeparatorNode = ASDisplayNode()
    
    private var switchItemNode: ItemListSwitchItemNode
    private var fontSizeItemNode: ThemeSettingsFontSizeItemNode
    
    private(set) var customMode: TextSelectionCustomMode = .chat
    
    var cancel: (() -> Void)?
    var done: (() -> Void)?
    
    var updateUseSystemFont: ((Bool) -> Void)?
    var updateCustomFontSize: ((PresentationFontSize) -> Void)?
    
    init(presentationThemeSettings: PresentationThemeSettings, presentationData: PresentationData) {
        self.presentationThemeSettings = presentationThemeSettings
        self.presentationData = presentationData
        
        self.switchItemNode = ItemListSwitchItemNode(type: .regular)
        self.fontSizeItemNode = ThemeSettingsFontSizeItemNode()
        
        super.init()
        
        self.addSubnode(self.switchItemNode)
        self.addSubnode(self.fontSizeItemNode)
        self.addSubnode(self.cancelButton)
        self.addSubnode(self.doneButton)
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.topSeparatorNode)
        
        self.updatePresentationData(presentationData: self.presentationData)
        
        self.cancelButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.cancelButton.backgroundColor = strongSelf.presentationData.theme.list.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.cancelButton.backgroundColor = .clear
                    })
                }
            }
        }
        
        self.doneButton.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.doneButton.backgroundColor = strongSelf.presentationData.theme.list.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.doneButton.backgroundColor = .clear
                    })
                }
            }
        }
        
        self.cancelButton.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.doneButton.addTarget(self, action: #selector(self.donePressed), forControlEvents: .touchUpInside)
    }
    
    func setDoneEnabled(_ enabled: Bool) {
        self.doneButton.alpha = enabled ? 1.0 : 0.4
        self.doneButton.isUserInteractionEnabled = enabled
    }
    
    func setCustomMode(_ customMode: TextSelectionCustomMode) {
        self.customMode = customMode
    }
    
    func updatePresentationData(presentationData: PresentationData) {
        self.backgroundColor = presentationData.theme.rootController.tabBar.backgroundColor
        self.separatorNode.backgroundColor = presentationData.theme.rootController.tabBar.separatorColor
        self.topSeparatorNode.backgroundColor = presentationData.theme.rootController.tabBar.separatorColor
        
        self.cancelButton.setTitle(presentationData.strings.Common_Cancel, with: Font.regular(17.0), with: presentationData.theme.list.itemPrimaryTextColor, for: [])
        self.doneButton.setTitle(presentationData.strings.Wallpaper_Set, with: Font.regular(17.0), with: presentationData.theme.list.itemPrimaryTextColor, for: [])
    }
    
    func updatePresentationThemeSettings(presentationThemeSettings: PresentationThemeSettings) {
        self.presentationThemeSettings = presentationThemeSettings
    }
    
    func updateLayout(width: CGFloat, bottomInset: CGFloat, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) -> CGFloat {
        var contentHeight: CGFloat = 0.0
        
        let switchItem = ItemListSwitchItem(presentationData: ItemListPresentationData(self.presentationData), title: self.presentationData.strings.Appearance_TextSize_UseSystem, value: self.presentationThemeSettings.useSystemFont, disableLeadingInset: true, sectionId: 0, style: .blocks, updated: { [weak self] value in
            self?.updateUseSystemFont?(value)
        })
        let fontSizeItem = ThemeSettingsFontSizeItem(theme: self.presentationData.theme, fontSize: self.customMode == .chat ? self.presentationThemeSettings.fontSize : self.presentationThemeSettings.listsFontSize, enabled: !self.presentationThemeSettings.useSystemFont, disableLeadingInset: true, disableDecorations: true, force: true, sectionId: 0, updated: { [weak self] value in
            self?.updateCustomFontSize?(value)
        })
        
        switchItem.updateNode(async: { f in
            f()
        }, node: {
            return self.switchItemNode
        }, params: ListViewItemLayoutParams(width: width, leftInset: layout.intrinsicInsets.left, rightInset: layout.intrinsicInsets.right, availableHeight: 1000.0), previousItem: nil, nextItem: fontSizeItem, animation: .None, completion: { layout, apply in
            self.switchItemNode.contentSize = layout.contentSize
            self.switchItemNode.insets = layout.insets
            transition.updateFrame(node: self.switchItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: layout.contentSize))
            contentHeight += layout.contentSize.height
            apply(ListViewItemApply(isOnScreen: true))
        })
        
        fontSizeItem.updateNode(async: { f in
            f()
        }, node: {
            return self.fontSizeItemNode
        }, params: ListViewItemLayoutParams(width: width, leftInset: layout.intrinsicInsets.left, rightInset: layout.intrinsicInsets.right, availableHeight: 1000.0), previousItem: switchItem, nextItem: nil, animation: .None, completion: { layout, apply in
            self.fontSizeItemNode.contentSize = layout.contentSize
            self.fontSizeItemNode.insets = layout.insets
            transition.updateFrame(node: self.fontSizeItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: layout.contentSize))
            contentHeight += layout.contentSize.height
            apply(ListViewItemApply(isOnScreen: true))
        })
        
        self.cancelButton.frame = CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: floor(width / 2.0), height: 49.0))
        self.doneButton.frame = CGRect(origin: CGPoint(x: floor(width / 2.0), y: contentHeight), size: CGSize(width: width - floor(width / 2.0), height: 49.0))
        
        contentHeight += 49.0
        
        self.topSeparatorNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: UIScreenPixel))
        
        let resultHeight = contentHeight + bottomInset
        
        self.separatorNode.frame = CGRect(origin: CGPoint(x: floor(width / 2.0), y: self.cancelButton.frame.minY), size: CGSize(width: UIScreenPixel, height: resultHeight - self.cancelButton.frame.minY))
        
        return resultHeight
    }
    
    @objc func cancelPressed() {
        self.cancel?()
    }
    
    @objc func donePressed() {
        self.doneButton.isUserInteractionEnabled = false
        self.done?()
    }
}
