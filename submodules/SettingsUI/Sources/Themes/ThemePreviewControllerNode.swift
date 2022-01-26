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

final class ThemePreviewControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var previewTheme: PresentationTheme
    private var presentationData: PresentationData
    private let isPreview: Bool
        
    private let ready: Promise<Bool>
    
    public let wallpaperPromise = Promise<TelegramWallpaper>()
    
    private let referenceTimestamp: Int32
    
    private let scrollNode: ASScrollNode
    private let pageControlBackgroundNode: ASDisplayNode
    private let pageControlNode: PageControlNode
    
    private let chatListBackgroundNode: ASDisplayNode
    private var chatNodes: [ListViewItemNode]?
    private let maskNode: ASImageNode
    
    private let separatorNode: ASDisplayNode
    
    private let chatContainerNode: ASDisplayNode
    private let messagesContainerNode: ASDisplayNode
    private let instantChatBackgroundNode: WallpaperBackgroundNode
    private let remoteChatBackgroundNode: TransformImageNode
    private let blurredNode: BlurredImageNode
    private let wallpaperNode: WallpaperBackgroundNode
    private var dateHeaderNode: ListViewItemHeaderNode?
    private var messageNodes: [ListViewItemNode]?

    private let toolbarNode: WallpaperGalleryToolbarNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var wallpaperDisposable: Disposable?
    private var colorDisposable: Disposable?
    private var statusDisposable: Disposable?
    private var fetchDisposable = MetaDisposable()
    
    private var dismissed = false

    private var wallpaper: TelegramWallpaper
    
    init(context: AccountContext, previewTheme: PresentationTheme, initialWallpaper: TelegramWallpaper?, dismiss: @escaping () -> Void, apply: @escaping () -> Void, isPreview: Bool, forceReady: Bool, ready: Promise<Bool>) {
        self.context = context
        self.previewTheme = previewTheme
        self.isPreview = isPreview

        self.wallpaper = initialWallpaper ?? previewTheme.chat.defaultWallpaper
        
        self.ready = ready
        
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
        self.pageControlBackgroundNode.cornerRadius = 10.5
        
        self.pageControlNode = PageControlNode(dotSpacing: 7.0, dotColor: .white, inactiveDotColor: UIColor.white.withAlphaComponent(0.4))
    
        self.chatListBackgroundNode = ASDisplayNode()
        
        self.chatContainerNode = ASDisplayNode()
        self.chatContainerNode.clipsToBounds = true
        
        self.messagesContainerNode = ASDisplayNode()
        self.messagesContainerNode.clipsToBounds = true
        self.messagesContainerNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        
        self.instantChatBackgroundNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        self.instantChatBackgroundNode.displaysAsynchronously = false

        self.ready.set(.single(true))
        self.instantChatBackgroundNode.update(wallpaper: wallpaper)

        self.instantChatBackgroundNode.view.contentMode = .scaleAspectFill
        
        self.remoteChatBackgroundNode = TransformImageNode()
        self.remoteChatBackgroundNode.view.contentMode = .scaleAspectFill
        
        self.blurredNode = BlurredImageNode()
        self.blurredNode.blurView.contentMode = .scaleAspectFill

        self.wallpaperNode = createWallpaperBackgroundNode(context: context, forChatDisplay: false)
        
        self.toolbarNode = WallpaperGalleryToolbarNode(theme: self.previewTheme, strings: self.presentationData.strings, doneButtonType: .set)
        
        if case .file = previewTheme.chat.defaultWallpaper, !forceReady {
            self.toolbarNode.setDoneEnabled(false)
        }
        
        self.maskNode = ASImageNode()
        self.maskNode.displaysAsynchronously = false
        self.maskNode.displayWithoutProcessing = true
        self.maskNode.contentMode = .scaleToFill
        
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = previewTheme.rootController.tabBar.separatorColor
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.previewTheme.list.plainBackgroundColor
        
        self.chatListBackgroundNode.backgroundColor = self.previewTheme.chatList.backgroundColor
        self.maskNode.image = generateMaskImage(color: self.previewTheme.chatList.backgroundColor)
        
        if case let .color(value) = self.wallpaper {
            self.instantChatBackgroundNode.backgroundColor = UIColor(rgb: value)
        }
        
        self.pageControlNode.isUserInteractionEnabled = false
        self.pageControlNode.pagesCount = 2
        
        self.addSubnode(self.scrollNode)
        if !isPreview {
            self.chatListBackgroundNode.addSubnode(self.maskNode)
            self.addSubnode(self.pageControlBackgroundNode)
            self.addSubnode(self.pageControlNode)
            self.addSubnode(self.toolbarNode)
        }
        
        self.scrollNode.addSubnode(self.chatListBackgroundNode)
        self.scrollNode.addSubnode(self.chatContainerNode)
        
        self.chatContainerNode.addSubnode(self.instantChatBackgroundNode)
        self.chatContainerNode.addSubnode(self.remoteChatBackgroundNode)
        self.chatContainerNode.addSubnode(self.messagesContainerNode)
        
        self.addSubnode(self.separatorNode)
        
        self.toolbarNode.cancel = {
            dismiss()
        }
        self.toolbarNode.done = { [weak self] in
            if let strongSelf = self {
                if !strongSelf.dismissed {
                    strongSelf.dismissed = true
                    apply()
                }
            }
        }

        var gradientColors: [UInt32] = []
        if case let .file(file) = self.wallpaper {
            gradientColors = file.settings.colors

            if file.settings.blur {
                self.chatContainerNode.insertSubnode(self.blurredNode, belowSubnode: self.messagesContainerNode)
            }
        } else if case let .gradient(gradient) = self.wallpaper {
            gradientColors = gradient.colors
        }

        if gradientColors.count >= 3 {
            self.chatContainerNode.insertSubnode(self.wallpaperNode, belowSubnode: self.messagesContainerNode)
        }

        self.wallpaperNode.update(wallpaper: self.wallpaper)
        self.wallpaperNode.updateBubbleTheme(bubbleTheme: self.previewTheme, bubbleCorners: self.presentationData.chatBubbleCorners)

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
            self?.ready.set(.single(true))
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
                strongSelf.pageControlBackgroundNode.backgroundColor = color
            }
        })
        
        self.wallpaperDisposable = (self.wallpaperPromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] wallpaper in
            guard let strongSelf = self else {
                return
            }
            if case let .file(file) = wallpaper {
                let dimensions = file.file.dimensions ?? PixelDimensions(width: 100, height: 100)
                let displaySize = dimensions.cgSize.dividedByScreenScale().integralFloor

                var convertedRepresentations: [ImageRepresentationWithReference] = []
                for representation in file.file.previewRepresentations {
                    convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: .wallpaper(wallpaper: .slug(file.slug), resource: representation.resource)))
                }
                convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource, progressiveSizes: [], immediateThumbnailData: nil), reference: .wallpaper(wallpaper: .slug(file.slug), resource: file.file.resource)))
                
                let signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
                if wallpaper.isPattern {
                    signal = .complete()
                } else {
                    signal = .complete()
                }
                strongSelf.remoteChatBackgroundNode.setSignal(signal)
                
                strongSelf.fetchDisposable.set(fetchedMediaResource(mediaBox: context.sharedContext.accountManager.mediaBox, reference: .wallpaper(wallpaper: .slug(file.slug), resource: file.file.resource)).start())
                                
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
                
                var patternArguments: PatternWallpaperArguments?
                if !file.settings.colors.isEmpty {
                    var patternIntensity: CGFloat = 0.5
                    if let intensity = file.settings.intensity {
                        patternIntensity = CGFloat(intensity) / 100.0
                    }
                    var patternColors = [UIColor(rgb: file.settings.colors[0], alpha: patternIntensity)]
                    if file.settings.colors.count >= 2 {
                        patternColors.append(UIColor(rgb: file.settings.colors[1], alpha: patternIntensity))
                    }
                    patternArguments = PatternWallpaperArguments(colors: patternColors, rotation: file.settings.rotation)
                }

                strongSelf.remoteChatBackgroundNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets(), custom: patternArguments))()
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
        
        self.scrollNode.view.bounces = false
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.isPagingEnabled = true
        self.scrollNode.view.delegate = self
        self.pageControlNode.setPage(0.0)
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.previewTheme = theme
    
        self.backgroundColor = self.previewTheme.list.plainBackgroundColor
        
        self.chatListBackgroundNode.backgroundColor = self.previewTheme.chatList.backgroundColor
        self.maskNode.image = generateMaskImage(color: self.previewTheme.chatList.backgroundColor)
        if case let .color(value) = self.wallpaper {
            self.instantChatBackgroundNode.backgroundColor = UIColor(rgb: value)
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
        }, present: { _ in
        })

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

        let chatListPresentationData = ChatListPresentationData(theme: self.previewTheme, fontSize: self.presentationData.listsFontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)

        let selfPeer: EnginePeer = .user(TelegramUser(id: self.context.account.peerId, accessHash: nil, firstName: nil, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer1: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_1_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer2: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(2)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_2_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer3: EnginePeer = .channel(TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(3)), accessHash: nil, title: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_Name, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .group(.init(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil))
        let peer3Author: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(4)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_AuthorName, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer4: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(4)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_4_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer5: EnginePeer = .channel(TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(5)), accessHash: nil, title: self.presentationData.strings.Appearance_ThemePreview_ChatList_5_Name, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .member, info: .broadcast(.init(flags: [])), flags: [], restrictionInfo: nil, adminRights: nil, bannedRights: nil, defaultBannedRights: nil))
        let peer6: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(5)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_6_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        let peer7: EnginePeer = .user(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(6)), accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_ChatList_7_Name, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: []))
        
        let timestamp = self.referenceTimestamp
        
        let timestamp1 = timestamp + 120
        items.append(makeChatListItem(
            peer: peer1,
            author: selfPeer,
            timestamp: timestamp1,
            text: self.presentationData.strings.Appearance_ThemePreview_ChatList_1_Text
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
            text: self.presentationData.strings.Appearance_ThemePreview_ChatList_6_Text
        ))

        items.append(makeChatListItem(
            peer: peer7,
            author: peer6,
            timestamp: timestamp - 420,
            text: self.presentationData.strings.Appearance_ThemePreview_ChatList_7_Text
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
        let headerItem = self.context.sharedContext.makeChatMessageDateHeaderItem(context: self.context, timestamp:  self.referenceTimestamp, theme: self.previewTheme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder)
        
        var items: [ListViewItem] = []
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
        let otherPeerId = self.context.account.peerId
        var peers = SimpleDictionary<PeerId, Peer>()
        var messages = SimpleDictionary<MessageId, Message>()
        peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_Chat_2_ReplyName, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        peers[otherPeerId] = TelegramUser(id: otherPeerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_ThemePreview_Chat_2_ReplyName, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        var sampleMessages: [Message] = []
  
        let message1 = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: otherPeerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66000, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_4_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        sampleMessages.append(message1)
        
        let message2 = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 2), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66001, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_5_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        sampleMessages.append(message2)
        
        let message3 = Message(stableId: 3, stableVersion: 0, id: MessageId(peerId: otherPeerId, namespace: 0, id: 3), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66002, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_6_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        sampleMessages.append(message3)
        
        let message4 = Message(stableId: 4, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 4), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66003, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_7_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        messages[message4.id] = message4
        sampleMessages.append(message4)
        
        let message5 = Message(stableId: 5, stableVersion: 0, id: MessageId(peerId: otherPeerId, namespace: 0, id: 5), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66004, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_1_Text, attributes: [ReplyMessageAttribute(messageId: message4.id, threadMessageId: nil)], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        messages[message5.id] = message5
        sampleMessages.append(message5)
        
        let waveformBase64 = "DAAOAAkACQAGAAwADwAMABAADQAPABsAGAALAA0AGAAfABoAHgATABgAGQAYABQADAAVABEAHwANAA0ACQAWABkACQAOAAwACQAfAAAAGQAVAAAAEwATAAAACAAfAAAAHAAAABwAHwAAABcAGQAAABQADgAAABQAHwAAAB8AHwAAAAwADwAAAB8AEwAAABoAFwAAAB8AFAAAAAAAHwAAAAAAHgAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAAAA="
        let voiceAttributes: [TelegramMediaFileAttribute] = [.Audio(isVoice: true, duration: 23, title: nil, performer: nil, waveform: Data(base64Encoded: waveformBase64)!)]
        let voiceMedia = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: voiceAttributes)
        
        let message6 = Message(stableId: 6, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 6), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66005, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [voiceMedia], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        sampleMessages.append(message6)
        
        let message7 = Message(stableId: 7, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 7), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66006, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_2_Text, attributes: [ReplyMessageAttribute(messageId: message5.id, threadMessageId: nil)], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        sampleMessages.append(message7)
        
        let message8 = Message(stableId: 8, stableVersion: 0, id: MessageId(peerId: otherPeerId, namespace: 0, id: 8), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: 66007, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_3_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        sampleMessages.append(message8)
        
        items = sampleMessages.reversed().map { message in
            self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, messages: [message], theme: self.previewTheme, strings: self.presentationData.strings, wallpaper: self.wallpaper, fontSize: self.presentationData.chatFontSize, chatBubbleCorners: self.presentationData.chatBubbleCorners, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: !message.media.isEmpty ? FileMediaResourceStatus(mediaStatus: .playbackStatus(.paused), fetchStatus: .Local) : nil, tapMessage: nil, clickThroughMessage: nil, backgroundNode: self.wallpaperNode, availableReactions: nil, isCentered: false)
        }
                
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
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        let bounds = CGRect(origin: CGPoint(), size: layout.size)
        self.scrollNode.frame = bounds
        
        let toolbarHeight = 49.0 + layout.intrinsicInsets.bottom
        self.chatListBackgroundNode.frame = CGRect(x: bounds.width, y: 0.0, width: bounds.width, height: bounds.height)
        self.chatContainerNode.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: bounds.height)
        
        let bottomInset: CGFloat
        if case .regular = layout.metrics.widthClass {
            self.chatListBackgroundNode.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width / 2.0, height: bounds.height)
            self.chatContainerNode.frame = CGRect(x: bounds.width / 2.0, y: 0.0, width: bounds.width / 2.0, height: bounds.height)
            self.scrollNode.view.contentSize = CGSize(width: bounds.width, height: bounds.height)
            
            self.pageControlNode.isHidden = true
            self.pageControlBackgroundNode.isHidden = true
            self.separatorNode.isHidden = false
            
            self.separatorNode.frame = CGRect(x: bounds.width / 2.0, y: 0.0, width: UIScreenPixel, height: bounds.height - toolbarHeight)
            
            bottomInset = 0.0
        } else {
            self.chatListBackgroundNode.frame = CGRect(x: bounds.width, y: 0.0, width: bounds.width, height: bounds.height)
            self.chatContainerNode.frame = CGRect(x: 0.0, y: 0.0, width: bounds.width, height: bounds.height)
            self.scrollNode.view.contentSize = CGSize(width: bounds.width * 2.0, height: bounds.height)
            
            self.pageControlNode.isHidden = false
            self.pageControlBackgroundNode.isHidden = false
            self.separatorNode.isHidden = true
            
            bottomInset = 38.0
        }
        
        self.messagesContainerNode.frame = self.chatContainerNode.bounds
        self.instantChatBackgroundNode.frame = self.chatContainerNode.bounds
        self.instantChatBackgroundNode.updateLayout(size: self.instantChatBackgroundNode.bounds.size, transition: .immediate)
        self.remoteChatBackgroundNode.frame = self.chatContainerNode.bounds
        self.blurredNode.frame = self.chatContainerNode.bounds
        self.wallpaperNode.frame = self.chatContainerNode.bounds
        self.wallpaperNode.updateLayout(size: self.wallpaperNode.bounds.size, transition: .immediate)
        
        transition.updateFrame(node: self.toolbarNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: toolbarHeight)))
        self.toolbarNode.updateLayout(size: CGSize(width: layout.size.width, height: 49.0), layout: layout, transition: transition)
        
        self.updateChatsLayout(layout: layout, topInset: navigationBarHeight, transition: transition)
        self.updateMessagesLayout(layout: layout, bottomInset: self.isPreview ? 0.0 : (toolbarHeight + bottomInset), transition: transition)
        
        let pageControlSize = self.pageControlNode.measure(CGSize(width: bounds.width, height: 100.0))
        let pageControlFrame = CGRect(origin: CGPoint(x: floor((bounds.width - pageControlSize.width) / 2.0), y: layout.size.height - toolbarHeight - 28.0), size: pageControlSize)
        self.pageControlNode.frame = pageControlFrame
        self.pageControlBackgroundNode.frame = CGRect(x: pageControlFrame.minX - 7.0, y: pageControlFrame.minY - 7.0, width: pageControlFrame.width + 14.0, height: 21.0)
        transition.updateFrame(node: self.maskNode, frame: CGRect(x: 0.0, y: layout.size.height - toolbarHeight - 80.0, width: bounds.width, height: 80.0))
    }
}
