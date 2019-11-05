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

final class ThemePreviewControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var previewTheme: PresentationTheme
    private var presentationData: PresentationData
    
    public let wallpaperPromise = Promise<TelegramWallpaper>()
    
    private let referenceTimestamp: Int32
    
    private let scrollNode: ASScrollNode
    private let pageControlBackgroundNode: ASDisplayNode
    private let pageControlNode: PageControlNode
    
    private let chatListBackgroundNode: ASDisplayNode
    private var chatNodes: [ListViewItemNode]?
    private let maskNode: ASImageNode
    
    private let chatContainerNode: ASDisplayNode
    private let instantChatBackgroundNode: WallpaperBackgroundNode
    private let remoteChatBackgroundNode: TransformImageNode
    private let blurredNode: BlurredImageNode
    private var messageNodes: [ListViewItemNode]?

    private let toolbarNode: WallpaperGalleryToolbarNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var wallpaperDisposable: Disposable?
    private var colorDisposable: Disposable?
    private var statusDisposable: Disposable?
    private var fetchDisposable = MetaDisposable()
    
    init(context: AccountContext, previewTheme: PresentationTheme, dismiss: @escaping () -> Void, apply: @escaping () -> Void) {
        self.context = context
        self.previewTheme = previewTheme
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
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
        
        self.pageControlNode = PageControlNode(dotColor: previewTheme.chatList.unreadBadgeActiveBackgroundColor, inactiveDotColor: previewTheme.list.pageIndicatorInactiveColor)
    
        self.chatListBackgroundNode = ASDisplayNode()
        
        self.chatContainerNode = ASDisplayNode()
        self.instantChatBackgroundNode = WallpaperBackgroundNode()
        self.instantChatBackgroundNode.displaysAsynchronously = false
        self.instantChatBackgroundNode.image = chatControllerBackgroundImage(theme: previewTheme, wallpaper: previewTheme.chat.defaultWallpaper, mediaBox: context.sharedContext.accountManager.mediaBox, knockoutMode: context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper)
        self.instantChatBackgroundNode.motionEnabled = previewTheme.chat.defaultWallpaper.settings?.motion ?? false
        self.instantChatBackgroundNode.view.contentMode = .scaleAspectFill
        
        self.remoteChatBackgroundNode = TransformImageNode()
        self.remoteChatBackgroundNode.backgroundColor = previewTheme.chatList.backgroundColor
        self.remoteChatBackgroundNode.view.contentMode = .scaleAspectFill
        
        self.blurredNode = BlurredImageNode()
        self.blurredNode.clipsToBounds = true
        self.blurredNode.blurView.contentMode = .scaleAspectFill
        
        self.toolbarNode = WallpaperGalleryToolbarNode(theme: self.previewTheme, strings: self.presentationData.strings)
        
        if case let .file(file) = previewTheme.chat.defaultWallpaper, file.id == 0 {
            self.remoteChatBackgroundNode.isHidden = false
            self.toolbarNode.setDoneEnabled(false)
        } else {
            self.remoteChatBackgroundNode.isHidden = true
        }
        
        self.maskNode = ASImageNode()
        self.maskNode.displaysAsynchronously = false
        self.maskNode.displayWithoutProcessing = true
        self.maskNode.contentMode = .scaleToFill
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.previewTheme.list.plainBackgroundColor
        
        self.chatListBackgroundNode.backgroundColor = self.previewTheme.chatList.backgroundColor
        self.maskNode.image = generateMaskImage(color: self.previewTheme.chatList.backgroundColor)
        
        if case let .color(value) = self.previewTheme.chat.defaultWallpaper {
            self.instantChatBackgroundNode.backgroundColor = UIColor(rgb: UInt32(bitPattern: value))
        }
        
        self.pageControlNode.isUserInteractionEnabled = false
        self.pageControlNode.pagesCount = 2
        
        self.addSubnode(self.scrollNode)
        self.chatListBackgroundNode.addSubnode(self.maskNode)
        self.addSubnode(self.pageControlBackgroundNode)
        self.addSubnode(self.pageControlNode)
        self.addSubnode(self.toolbarNode)
        
        self.scrollNode.addSubnode(self.chatListBackgroundNode)
        self.scrollNode.addSubnode(self.chatContainerNode)
        
        self.chatContainerNode.addSubnode(self.instantChatBackgroundNode)
        self.chatContainerNode.addSubnode(self.remoteChatBackgroundNode)
        
        self.toolbarNode.cancel = {
            dismiss()
        }
        self.toolbarNode.done = {
            apply()
        }
        
        if case let .file(file) = self.previewTheme.chat.defaultWallpaper {
            if file.settings.blur {
                self.chatContainerNode.addSubnode(self.blurredNode)
            }
        }
        
        self.remoteChatBackgroundNode.imageUpdated = { [weak self] image in
            if let strongSelf = self, strongSelf.blurredNode.supernode != nil {
                var image = image
                if let imageToScale = image {
                    let actualSize = CGSize(width: imageToScale.size.width * imageToScale.scale, height: imageToScale.size.height * imageToScale.scale)
                    if actualSize.width > 1280.0 || actualSize.height > 1280.0 {
                        image = TGScaleImageToPixelSize(image, actualSize.fitted(CGSize(width: 1280.0, height: 1280.0)))
                    }
                }
                strongSelf.blurredNode.image = image
                strongSelf.blurredNode.blurView.blurRadius = 45.0
            }
        }
        
        self.colorDisposable = (self.wallpaperPromise.get()
        |> mapToSignal { wallpaper -> Signal<UIColor, NoError> in
            if case let .file(file) = wallpaper, file.id == 0 {
                return .complete()
            } else {
                return chatServiceBackgroundColor(wallpaper: wallpaper, mediaBox: context.account.postbox.mediaBox)
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] color in
            if let strongSelf = self {
                if strongSelf.previewTheme.chat.defaultWallpaper.hasWallpaper {
                    strongSelf.pageControlBackgroundNode.backgroundColor = color
                } else {
                    strongSelf.pageControlBackgroundNode.backgroundColor = .clear
                }
            }
        })
        
        self.wallpaperDisposable = (self.wallpaperPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] wallpaper in
            guard let strongSelf = self else {
                return
            }
            if case let .file(file) = wallpaper {
                let dimensions = file.file.dimensions ?? CGSize(width: 100.0, height: 100.0)
                let displaySize = dimensions.dividedByScreenScale().integralFloor

                var convertedRepresentations: [ImageRepresentationWithReference] = []
                for representation in file.file.previewRepresentations {
                    convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: MediaResourceReference.media(media: .standalone(media: file.file), resource: representation.resource)))
                }
                convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource), reference: .media(media: .standalone(media: file.file), resource: file.file.resource)))
                
                let signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
                let fileReference = FileMediaReference.standalone(media: file.file)
                if file.isPattern {
                    signal = patternWallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, representations: convertedRepresentations, mode: .screen, autoFetchFullSize: false)
                } else {
                    signal = wallpaperImage(account: context.account, accountManager: context.sharedContext.accountManager, fileReference: fileReference, representations: convertedRepresentations, alwaysShowThumbnailFirst: false, autoFetchFullSize: false)
                        |> afterNext { next in
                            if let _ = context.sharedContext.accountManager.mediaBox.completedResourcePath(file.file.resource) {
                            } else if let path = context.account.postbox.mediaBox.completedResourcePath(file.file.resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                context.sharedContext.accountManager.mediaBox.storeResourceData(file.file.resource.id, data: data)
                            }
                    }
                }
                strongSelf.remoteChatBackgroundNode.setSignal(signal)

                strongSelf.fetchDisposable.set(freeMediaFileInteractiveFetched(account: context.account, fileReference: .standalone(media: file.file)).start())
                
                let account = strongSelf.context.account
                let statusSignal = strongSelf.context.sharedContext.accountManager.mediaBox.resourceStatus(file.file.resource)
                |> take(1)
                |> mapToSignal { status -> Signal<MediaResourceStatus, NoError> in
                    if case .Local = status {
                        return .single(status)
                    } else {
                        return account.postbox.mediaBox.resourceStatus(file.file.resource)
                    }
                }
                
                strongSelf.statusDisposable = (statusSignal
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let strongSelf = self, case .Local = status {
                        strongSelf.toolbarNode.setDoneEnabled(true)
                    }
                })
                
                var patternColor: UIColor?
                var patternIntensity: CGFloat = 0.5
                if let color = file.settings.color {
                    if let intensity = file.settings.intensity {
                        patternIntensity = CGFloat(intensity) / 100.0
                    }
                    patternColor = UIColor(rgb: UInt32(bitPattern: color), alpha: patternIntensity)
                }

                strongSelf.remoteChatBackgroundNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets(), emptyColor: patternColor))()
            }
        })
    }
    
    deinit {
        self.colorDisposable?.dispose()
        self.wallpaperDisposable?.dispose()
        self.statusDisposable?.dispose()
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.isPagingEnabled = true
        self.scrollNode.view.delegate = self
        self.pageControlNode.setPage(0.0)
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.previewTheme = theme
    
        self.backgroundColor = self.previewTheme.list.plainBackgroundColor
        
        self.pageControlNode.dotColor = self.previewTheme.chatList.unreadBadgeActiveBackgroundColor
        self.pageControlNode.inactiveDotColor = self.previewTheme.list.pageIndicatorInactiveColor
        
        self.chatListBackgroundNode.backgroundColor = self.previewTheme.chatList.backgroundColor
        self.maskNode.image = generateMaskImage(color: self.previewTheme.chatList.backgroundColor)
        if case let .color(value) = self.previewTheme.chat.defaultWallpaper {
            self.instantChatBackgroundNode.backgroundColor = UIColor(rgb: UInt32(bitPattern: value))
        }
        
        self.toolbarNode.updateThemeAndStrings(theme: self.previewTheme, strings: self.presentationData.strings)
    
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
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
        let chatListPresentationData = ChatListPresentationData(theme: self.previewTheme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)
        
        let peers = SimpleDictionary<PeerId, Peer>()
        let messages = SimpleDictionary<MessageId, Message>()
        let selfPeer = TelegramUser(id: self.context.account.peerId, accessHash: nil, firstName: nil, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let peer1 = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 1), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_1_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let peer2 = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 2), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_2_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let peer3 = TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: 3), accessHash: nil, title: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_Name, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .group(.init(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil)
        let peer3Author = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 4), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_AuthorName, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let peer4 = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 4), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_4_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let peer5 = TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: 5), accessHash: nil, title: self.presentationData.strings.Appearance_ThemePreview_ChatList_5_Name, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .broadcast(.init(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil)
        let peer6 = TelegramUser(id: PeerId(namespace: Namespaces.Peer.SecretChat, id: 5), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_6_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let peer7 = TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: 6), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_7_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let timestamp = self.referenceTimestamp
        
        let timestamp1 = timestamp + 120
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: peer1.id, namespace: 0, id: 0), timestamp: timestamp1)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer1.id, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp1, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: selfPeer, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_1_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer1), combinedReadState: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, PeerReadState.idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 0, markedUnread: false))]), notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let presenceTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 + 60 * 60)
        let timestamp2 = timestamp + 3660
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer2.id, namespace: 0, id: 0), timestamp: timestamp2)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer2.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp2, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer2, text: "", attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer2), combinedReadState: nil, notificationSettings: nil, presence: TelegramUserPresence(status: .present(until: presenceTimestamp), lastActivity: presenceTimestamp), summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: [(peer2, .typingText)], isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let timestamp3 = timestamp + 3200
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer3.id, namespace: 0, id: 0), timestamp: timestamp3)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer3.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp3, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer3Author, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer3), combinedReadState: nil, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let timestamp4 = timestamp + 3000
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer4.id, namespace: 0, id: 0), timestamp: timestamp4)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer4.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp4, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer4, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_4_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer4), combinedReadState: nil, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let timestamp5 = timestamp + 1000
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer5.id, namespace: 0, id: 0), timestamp: timestamp5)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer4.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp5, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer5, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_5_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer5), combinedReadState: nil, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer6.id, namespace: 0, id: 0), timestamp: timestamp - 360)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer6.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp - 360, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer6, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_6_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer6), combinedReadState: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, PeerReadState.idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 1, markedUnread: false))]), notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer7.id, namespace: 0, id: 0), timestamp: timestamp - 420)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer7.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp - 420, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer6, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_7_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer7), combinedReadState: nil, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
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
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message1, theme: self.previewTheme, strings: self.presentationData.strings, wallpaper: self.previewTheme.chat.defaultWallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil))
        
        let message2 = Message(stableId: 3, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 3), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66002, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_2_Text, attributes: [ReplyMessageAttribute(messageId: replyMessageId)], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message2, theme: self.previewTheme, strings: self.presentationData.strings, wallpaper: self.previewTheme.chat.defaultWallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil))
        
        let waveformBase64 = "DAAOAAkACQAGAAwADwAMABAADQAPABsAGAALAA0AGAAfABoAHgATABgAGQAYABQADAAVABEAHwANAA0ACQAWABkACQAOAAwACQAfAAAAGQAVAAAAEwATAAAACAAfAAAAHAAAABwAHwAAABcAGQAAABQADgAAABQAHwAAAB8AHwAAAAwADwAAAB8AEwAAABoAFwAAAB8AFAAAAAAAHwAAAAAAHgAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAAAA="
        let voiceAttributes: [TelegramMediaFileAttribute] = [.Audio(isVoice: true, duration: 23, title: nil, performer: nil, waveform: MemoryBuffer(data: Data(base64Encoded: waveformBase64)!))]
        let voiceMedia = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: voiceAttributes)
        
        let message3 = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66001, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [voiceMedia], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message3, theme: self.previewTheme, strings: self.presentationData.strings, wallpaper: self.previewTheme.chat.defaultWallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: FileMediaResourceStatus(mediaStatus: .playbackStatus(.paused), fetchStatus: .Local)))
        
        let message4 = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: otherPeerId, namespace: 0, id: 2), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66001, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_1_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message4, theme: self.previewTheme, strings: self.presentationData.strings, wallpaper: self.previewTheme.chat.defaultWallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil))
        
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
                self.chatContainerNode.addSubnode(itemNode!)
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
        self.chatContainerNode.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: bounds.height)
        self.instantChatBackgroundNode.frame = self.chatContainerNode.bounds
        self.remoteChatBackgroundNode.frame = self.chatContainerNode.bounds
        self.blurredNode.frame = self.chatContainerNode.bounds
    
        self.scrollNode.view.contentSize = CGSize(width: bounds.width * 2.0, height: bounds.height)
        
        transition.updateFrame(node: self.toolbarNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: 49.0 + layout.intrinsicInsets.bottom)))
        self.toolbarNode.updateLayout(size: CGSize(width: layout.size.width, height: 49.0), layout: layout, transition: transition)
        
        self.updateChatsLayout(layout: layout, topInset: navigationBarHeight, transition: transition)
        self.updateMessagesLayout(layout: layout, bottomInset: toolbarHeight + 66.0, transition: transition)
        
        let pageControlSize = self.pageControlNode.measure(CGSize(width: bounds.width, height: 100.0))
        let pageControlFrame = CGRect(origin: CGPoint(x: floor((bounds.width - pageControlSize.width) / 2.0), y: layout.size.height - toolbarHeight - 42.0), size: pageControlSize)
        self.pageControlNode.frame = pageControlFrame
        self.pageControlBackgroundNode.frame = CGRect(x: pageControlFrame.minX - 11.0, y: pageControlFrame.minY - 12.0, width: pageControlFrame.width + 22.0, height: 30.0)
        transition.updateFrame(node: self.maskNode, frame: CGRect(x: 0.0, y: layout.size.height - toolbarHeight - 80.0, width: bounds.width, height: 80.0))
    }
}
