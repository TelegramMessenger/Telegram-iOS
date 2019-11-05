import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ChatListUI
import AccountContext

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

final class ThemeAccentColorControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var theme: PresentationTheme
    private let currentTheme: PresentationThemeReference
    private var presentationData: PresentationData
    
    private let referenceTimestamp: Int32
    
    private let scrollNode: ASScrollNode
    private let pageControlBackgroundNode: ASDisplayNode
    private let pageControlNode: PageControlNode
    
    private let chatListBackgroundNode: ASDisplayNode
    private var chatNodes: [ListViewItemNode]?
    private let maskNode: ASImageNode
    
    private let chatBackgroundNode: WallpaperBackgroundNode
    private var messageNodes: [ListViewItemNode]?
    
    private var colorPanelNode: WallpaperColorPanelNode
    private let toolbarNode: WallpaperGalleryToolbarNode
    
    private var validLayout: (ContainerViewLayout, CGFloat, CGFloat)?
    
    private var serviceColorDisposable: Disposable?
    private var colorDisposable: Disposable?
    private let colorValue = ValuePromise<UIColor>(ignoreRepeated: true)
    
    var themeUpdated: ((PresentationTheme) -> Void)?
    var color: UInt32 {
        return self.colorPanelNode.color.rgb
    }
    
    init(context: AccountContext, currentTheme: PresentationThemeReference, color: UIColor, theme: PresentationTheme, dismiss: @escaping () -> Void, apply: @escaping () -> Void) {
        self.context = context
        self.currentTheme = currentTheme
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.theme = theme
        self.colorValue.set(color)
        
        let calendar = Calendar(identifier: .gregorian)
        var components = calendar.dateComponents(Set([.era, .year, .month, .day, .hour, .minute, .second]), from: Date())
        components.hour = 13
        components.minute = 0
        components.second = 0
        self.referenceTimestamp = Int32(calendar.date(from: components)?.timeIntervalSince1970 ?? 0.0)
        
        self.scrollNode = ASScrollNode()
        self.pageControlBackgroundNode = ASDisplayNode()
        self.pageControlBackgroundNode.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.3)
        self.pageControlBackgroundNode.cornerRadius = 8.0
        
        self.pageControlNode = PageControlNode(dotColor: self.theme.chatList.unreadBadgeActiveBackgroundColor, inactiveDotColor: self.presentationData.theme.list.pageIndicatorInactiveColor)
        
        self.chatListBackgroundNode = ASDisplayNode()
        self.chatBackgroundNode = WallpaperBackgroundNode()
        self.chatBackgroundNode.displaysAsynchronously = false
        if case .color = self.presentationData.chatWallpaper {
        } else {
            self.chatBackgroundNode.image = chatControllerBackgroundImage(theme: theme, wallpaper: self.presentationData.chatWallpaper, mediaBox: context.sharedContext.accountManager.mediaBox, knockoutMode: context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper)
            self.chatBackgroundNode.motionEnabled = self.presentationData.chatWallpaper.settings?.motion ?? false
        }
        
        self.colorPanelNode = WallpaperColorPanelNode(theme: self.theme, strings: self.presentationData.strings)
        self.colorPanelNode.color = color
        self.toolbarNode = WallpaperGalleryToolbarNode(theme: self.theme, strings: self.presentationData.strings)
        
        self.maskNode = ASImageNode()
        self.maskNode.displaysAsynchronously = false
        self.maskNode.displayWithoutProcessing = true
        self.maskNode.contentMode = .scaleToFill
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        
        self.chatListBackgroundNode.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        if case let .color(value) = self.presentationData.theme.chat.defaultWallpaper {
            self.chatBackgroundNode.backgroundColor = UIColor(rgb: UInt32(bitPattern: value))
        }
        
        self.pageControlNode.isUserInteractionEnabled = false
        self.pageControlNode.pagesCount = 2
        
        self.addSubnode(self.scrollNode)
        self.chatListBackgroundNode.addSubnode(self.maskNode)
        self.addSubnode(self.pageControlBackgroundNode)
        self.addSubnode(self.pageControlNode)
        self.addSubnode(self.colorPanelNode)
        self.addSubnode(self.toolbarNode)
        
        self.scrollNode.addSubnode(self.chatListBackgroundNode)
        self.scrollNode.addSubnode(self.chatBackgroundNode)
        
        self.colorPanelNode.colorChanged = { [weak self] color, ended in
            if let strongSelf = self {
                strongSelf.colorValue.set(color)
            }
        }
        
        self.toolbarNode.cancel = {
            dismiss()
        }
        self.toolbarNode.done = {
            apply()
        }
        
        self.colorDisposable = (self.colorValue.get()
        |> deliverOn(Queue.concurrentDefaultQueue())
        |> map { color -> PresentationTheme in
            let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: currentTheme, accentColor: color, serviceBackgroundColor: defaultServiceBackgroundColor, baseColor: nil, preview: true)
            
            let wallpaper = context.sharedContext.currentPresentationData.with { $0 }.chatWallpaper
            let _ = PresentationResourcesChat.principalGraphics(mediaBox: context.account.postbox.mediaBox, knockoutWallpaper: context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper, theme: theme, wallpaper: wallpaper, gradientBubbles: context.sharedContext.immediateExperimentalUISettings.gradientBubbles)
            
            return theme
        }
        |> deliverOnMainQueue).start(next: { [weak self] theme in
            if let strongSelf = self {
                strongSelf.theme = theme
                strongSelf.themeUpdated?(theme)
                
                strongSelf.colorPanelNode.updateTheme(theme)
                strongSelf.toolbarNode.updateThemeAndStrings(theme: theme, strings: strongSelf.presentationData.strings)
                strongSelf.maskNode.image = generateMaskImage(color: theme.chatList.backgroundColor)
                
                if case let .color(value) = theme.chat.defaultWallpaper {
                    strongSelf.backgroundColor  = UIColor(rgb: UInt32(bitPattern: value))
                    strongSelf.chatListBackgroundNode.backgroundColor = UIColor(rgb: UInt32(bitPattern: value))
                    strongSelf.chatBackgroundNode.backgroundColor = UIColor(rgb: UInt32(bitPattern: value))
                }
        
                if let (layout, navigationBarHeight, messagesBottomInset) = strongSelf.validLayout {
                    strongSelf.pageControlNode.dotColor = theme.chatList.unreadBadgeActiveBackgroundColor
                    strongSelf.pageControlNode.inactiveDotColor = theme.list.pageIndicatorInactiveColor
                    strongSelf.updateChatsLayout(layout: layout, topInset: navigationBarHeight, transition: .immediate)
                    strongSelf.updateMessagesLayout(layout: layout, bottomInset: messagesBottomInset, transition: .immediate)
                }
            }
        })
        
        self.serviceColorDisposable = (chatServiceBackgroundColor(wallpaper: self.presentationData.chatWallpaper, mediaBox: context.account.postbox.mediaBox)
        |> deliverOnMainQueue).start(next: { [weak self] color in
            if let strongSelf = self {
                if strongSelf.presentationData.chatWallpaper.hasWallpaper {
                    strongSelf.pageControlBackgroundNode.backgroundColor = color
                } else {
                    strongSelf.pageControlBackgroundNode.backgroundColor = .clear
                }
            }
        })
    }
    
    deinit {
        self.colorDisposable?.dispose()
        self.serviceColorDisposable?.dispose()
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
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    

    
    private func updateChatsLayout(layout: ContainerViewLayout, topInset: CGFloat, transition: ContainedViewLayoutTransition) {
        var items: [ChatListItem] = []
        
        let interaction = ChatListNodeInteraction(activateSearch: {}, peerSelected: { _ in }, togglePeerSelected: { _ in }, messageSelected: { _, _, _ in}, groupSelected: { _ in }, addContact: { _ in }, setPeerIdWithRevealedOptions: { _, _ in }, setItemPinned: { _, _ in }, setPeerMuted: { _, _ in }, deletePeer: { _ in }, updatePeerGrouping: { _, _ in }, togglePeerMarkedUnread: { _, _ in}, toggleArchivedFolderHiddenByDefault: {})
        let chatListPresentationData = ChatListPresentationData(theme: self.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)
        
        let peers = SimpleDictionary<PeerId, Peer>()
        let messages = SimpleDictionary<MessageId, Message>()
        let selfPeer = TelegramUser(id: self.context.account.peerId, accessHash: nil, firstName: nil, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let peer1 = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 1), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_1_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let peer2 = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 2), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_2_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let peer3 = TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: 3), accessHash: nil, title: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_Name, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .group(.init(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil)
        let peer3Author = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 4), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_AuthorName, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let peer4 = TelegramUser(id: PeerId(namespace: Namespaces.Peer.SecretChat, id: 4), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_4_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let timestamp = self.referenceTimestamp
        
        let timestamp1 = timestamp + 120
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: peer1.id, namespace: 0, id: 0), timestamp: timestamp1)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer1.id, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp1, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: selfPeer, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_1_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer1), combinedReadState: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, PeerReadState.idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 0, markedUnread: false))]), notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let presenceTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 + 60 * 60)
        let timestamp2 = timestamp + 3660
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer2.id, namespace: 0, id: 0), timestamp: timestamp2)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer2.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp2, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer2, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_2_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer2), combinedReadState: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, PeerReadState.idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 1, markedUnread: false))]), notificationSettings: nil, presence: TelegramUserPresence(status: .present(until: presenceTimestamp), lastActivity: presenceTimestamp), summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let timestamp3 = timestamp + 3200
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer3.id, namespace: 0, id: 0), timestamp: timestamp3)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer3.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp3, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer3Author, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer3), combinedReadState: nil, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let timestamp4 = timestamp + 3000
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer4.id, namespace: 0, id: 0), timestamp: timestamp4)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer4.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp4, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer4, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_4_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer4), combinedReadState: nil, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
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
                itemNode!.isUserInteractionEnabled = false
                chatNodes.append(itemNode!)
                self.chatListBackgroundNode.insertSubnode(itemNode!, belowSubnode: self.maskNode)
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
        var items: [ListViewItem] = []
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 1)
        let otherPeerId = self.context.account.peerId
        var peers = SimpleDictionary<PeerId, Peer>()
        var messages = SimpleDictionary<MessageId, Message>()
        peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_Chat_2_ReplyName, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        peers[otherPeerId] = TelegramUser(id: otherPeerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_Chat_2_ReplyName, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let replyMessageId = MessageId(peerId: peerId, namespace: 0, id: 3)
        messages[replyMessageId] = Message(stableId: 3, stableVersion: 0, id: replyMessageId, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66000, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_1_Text, attributes: [], media: [], peers: peers, associatedMessages: SimpleDictionary(), associatedMessageIds: [])
        
        let message1 = Message(stableId: 4, stableVersion: 0, id: MessageId(peerId: otherPeerId, namespace: 0, id: 4), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66003, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_3_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message1, theme: self.theme, strings: self.presentationData.strings, wallpaper: self.theme.chat.defaultWallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil))
        
        let message2 = Message(stableId: 3, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 3), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66002, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_2_Text, attributes: [ReplyMessageAttribute(messageId: replyMessageId)], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message2, theme: self.theme, strings: self.presentationData.strings, wallpaper: self.theme.chat.defaultWallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil))
        
        let waveformBase64 = "DAAOAAkACQAGAAwADwAMABAADQAPABsAGAALAA0AGAAfABoAHgATABgAGQAYABQADAAVABEAHwANAA0ACQAWABkACQAOAAwACQAfAAAAGQAVAAAAEwATAAAACAAfAAAAHAAAABwAHwAAABcAGQAAABQADgAAABQAHwAAAB8AHwAAAAwADwAAAB8AEwAAABoAFwAAAB8AFAAAAAAAHwAAAAAAHgAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAAAA="
        let voiceAttributes: [TelegramMediaFileAttribute] = [.Audio(isVoice: true, duration: 23, title: nil, performer: nil, waveform: MemoryBuffer(data: Data(base64Encoded: waveformBase64)!))]
        let voiceMedia = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: voiceAttributes)
        
        let message3 = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66001, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [voiceMedia], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message3, theme: self.theme, strings: self.presentationData.strings, wallpaper: self.theme.chat.defaultWallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: FileMediaResourceStatus(mediaStatus: .playbackStatus(.paused), fetchStatus: .Local)))
        
        let message4 = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: otherPeerId, namespace: 0, id: 2), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66001, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_1_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message4, theme: self.theme, strings: self.presentationData.strings, wallpaper: self.theme.chat.defaultWallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil))
        
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
                itemNode.updateFrame(itemNode.frame, within: layout.size)
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let bounds = CGRect(origin: CGPoint(), size: layout.size)
        self.scrollNode.frame = bounds
        
        let toolbarHeight = 49.0 + layout.intrinsicInsets.bottom
        self.chatListBackgroundNode.frame = CGRect(x: bounds.width, y: 0.0, width: bounds.width, height: bounds.height)
        self.chatBackgroundNode.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: bounds.height)
        
        self.scrollNode.view.contentSize = CGSize(width: bounds.width * 2.0, height: bounds.height)
        
        transition.updateFrame(node: self.toolbarNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: 49.0 + layout.intrinsicInsets.bottom)))
        self.toolbarNode.updateLayout(size: CGSize(width: layout.size.width, height: 49.0), layout: layout, transition: transition)
        
        var bottomInset = toolbarHeight
        let standardInputHeight = layout.deviceMetrics.keyboardHeight(inLandscape: false)
        let height = max(standardInputHeight, layout.inputHeight ?? 0.0) - bottomInset + 47.0
        let colorPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset - height), size: CGSize(width: layout.size.width, height: height))
        bottomInset += height
        
        transition.updateFrame(node: self.colorPanelNode, frame: colorPanelFrame)
        self.colorPanelNode.updateLayout(size: colorPanelFrame.size, keyboardHeight: layout.inputHeight ?? 0.0, transition: transition)
        
        let messagesBottomInset = bottomInset + 36.0
        self.updateChatsLayout(layout: layout, topInset: navigationBarHeight, transition: transition)
        self.updateMessagesLayout(layout: layout, bottomInset: messagesBottomInset, transition: transition)
        
        self.validLayout = (layout, navigationBarHeight, messagesBottomInset)
        
        let pageControlSize = self.pageControlNode.measure(CGSize(width: bounds.width, height: 100.0))
        let pageControlFrame = CGRect(origin: CGPoint(x: floor((bounds.width - pageControlSize.width) / 2.0), y: layout.size.height - bottomInset - 27.0), size: pageControlSize)
        self.pageControlNode.frame = pageControlFrame
        self.pageControlBackgroundNode.frame = CGRect(x: pageControlFrame.minX - 11.0, y: pageControlFrame.minY - 12.0, width: pageControlFrame.width + 22.0, height: 30.0)
        
        transition.updateFrame(node: self.maskNode, frame: CGRect(x: 0.0, y: layout.size.height - bottomInset - 80.0, width: bounds.width, height: 80.0))
    }
}
