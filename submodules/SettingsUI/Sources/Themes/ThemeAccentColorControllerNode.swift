import Foundation
import UIKit
import Display
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import SyncCore
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
 
enum ThemeColorSection: Int {
    case accent
    case background
    case messages
}

struct ThemeColorState {
    fileprivate var section: ThemeColorSection?
    fileprivate var colorPanelCollapsed: Bool
    var accentColor: UIColor
    var backgroundColors: (UIColor, UIColor?)?
    var messagesColors: (UIColor, UIColor?)?
    
    init() {
        self.section = nil
        self.colorPanelCollapsed = false
        self.accentColor = .clear
        self.backgroundColors = nil
        self.messagesColors = nil
    }
    
    init(section: ThemeColorSection, accentColor: UIColor, backgroundColors: (UIColor, UIColor?)?, messagesColors: (UIColor, UIColor?)?) {
        self.section = section
        self.colorPanelCollapsed = false
        self.accentColor = accentColor
        self.backgroundColors = backgroundColors
        self.messagesColors = messagesColors
    }
    
    func areColorsEqual(to otherState: ThemeColorState) -> Bool {
        if self.accentColor != otherState.accentColor {
            return false
        }
        if let lhsBackgroundColors = self.backgroundColors, let rhsBackgroundColors = otherState.backgroundColors {
            if lhsBackgroundColors.0 != rhsBackgroundColors.0 {
                return false
            }
            if let lhsSecondColor = lhsBackgroundColors.1, let rhsSecondColor = rhsBackgroundColors.1 {
                if lhsSecondColor != rhsSecondColor {
                    return false
                }
            } else if (lhsBackgroundColors.1 == nil) != (rhsBackgroundColors.1 == nil) {
                return false
            }
        } else if (self.backgroundColors == nil) != (otherState.backgroundColors == nil) {
            return false
        }
        if let lhsMessagesColors = self.messagesColors, let rhsMessagesColors = otherState.messagesColors {
            if lhsMessagesColors.0 != rhsMessagesColors.0 {
                return false
            }
            if let lhsSecondColor = lhsMessagesColors.1, let rhsSecondColor = rhsMessagesColors.1 {
                if lhsSecondColor != rhsSecondColor {
                    return false
                }
            } else if (lhsMessagesColors.1 == nil) != (rhsMessagesColors.1 == nil) {
                return false
            }
        } else if (self.messagesColors == nil) != (otherState.messagesColors == nil) {
            return false
        }
        return true
    }
}

final class ThemeAccentColorControllerNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private var theme: PresentationTheme
    private let themeReference: PresentationThemeReference
    private var presentationData: PresentationData
    
    private var state: ThemeColorState
    private let referenceTimestamp: Int32
    
    private let scrollNode: ASScrollNode
    private let pageControlBackgroundNode: ASDisplayNode
    private let pageControlNode: PageControlNode
    private let chatListBackgroundNode: ASDisplayNode
    private var chatNodes: [ListViewItemNode]?
    private let maskNode: ASImageNode
    private let chatBackgroundNode: WallpaperBackgroundNode
    private let messagesContainerNode: ASDisplayNode
    private var dateHeaderNode: ListViewItemHeaderNode?
    private var messageNodes: [ListViewItemNode]?
    private var colorPanelNode: WallpaperColorPanelNode
    private let toolbarNode: WallpaperGalleryToolbarNode
    
    private var serviceColorDisposable: Disposable?
    private var colorsDisposable: Disposable?
    private let colors = Promise<(UIColor, (UIColor, UIColor?)?, (UIColor, UIColor?)?)>()
    private let themePromise = Promise<PresentationTheme>()
    private var wallpaper: TelegramWallpaper
    
    private var tapGestureRecognizer: UITapGestureRecognizer?
    
    var themeUpdated: ((PresentationTheme) -> Void)?
    
    private var validLayout: (ContainerViewLayout, CGFloat, CGFloat)?
    
    var requiresWallpaperChange: Bool {
        return self.state.backgroundColors == nil && self.chatBackgroundNode.image != nil
    }
    
    init(context: AccountContext, themeReference: PresentationThemeReference, theme: PresentationTheme, dismiss: @escaping () -> Void, apply: @escaping (ThemeColorState) -> Void) {
        self.context = context
        self.themeReference = themeReference
        self.state = ThemeColorState()
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.theme = theme
        self.wallpaper = self.presentationData.chatWallpaper
        
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
        self.chatBackgroundNode = WallpaperBackgroundNode()
        self.chatBackgroundNode.displaysAsynchronously = false
        
        self.messagesContainerNode = ASDisplayNode()
        self.messagesContainerNode.clipsToBounds = true
        self.messagesContainerNode.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        
        if case .color = self.presentationData.chatWallpaper {
        } else {
            self.chatBackgroundNode.image = chatControllerBackgroundImage(theme: theme, wallpaper: self.presentationData.chatWallpaper, mediaBox: context.sharedContext.accountManager.mediaBox, knockoutMode: false)
            self.chatBackgroundNode.motionEnabled = self.presentationData.chatWallpaper.settings?.motion ?? false
        }
        
        self.colorPanelNode = WallpaperColorPanelNode(theme: self.theme, strings: self.presentationData.strings)
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
        self.scrollNode.addSubnode(self.messagesContainerNode)
                
        self.colorPanelNode.colorsChanged = { [weak self] firstColor, secondColor, _ in
            if let strongSelf = self, let section = strongSelf.state.section {
                switch section {
                    case .accent:
                        strongSelf.updateState({ current in
                            var updated = current
                            if let firstColor = firstColor {
                                updated.accentColor = firstColor
                            }
                            return updated
                        })
                    case .background:
                        strongSelf.updateState({ current in
                            var updated = current
                            if let firstColor = firstColor {
                                updated.backgroundColors = (firstColor, secondColor)
                            }
                            return updated
                        })
                    case .messages:
                        strongSelf.updateState({ current in
                            var updated = current
                            if let firstColor = firstColor {
                                updated.messagesColors = (firstColor, secondColor)
                            }
                            return updated
                        })
                }
            }
        }
        
        self.colorPanelNode.colorSelected = { [weak self] in
            if let strongSelf = self, strongSelf.state.colorPanelCollapsed {
                strongSelf.updateState({ current in
                    var updated = current
                    updated.colorPanelCollapsed = false
                    return updated
                }, animated: true)
            }
        }
        
        self.toolbarNode.cancel = {
            dismiss()
        }
        self.toolbarNode.done = { [weak self] in
            if let strongSelf = self {
                apply(strongSelf.state)
            }
        }
        
        self.colorsDisposable = (self.colors.get()
        |> deliverOn(Queue.concurrentDefaultQueue())
        |> map { accentColor, backgroundColors, messagesColors -> (PresentationTheme, (TelegramWallpaper, UIImage?)) in
            var wallpaper = context.sharedContext.currentPresentationData.with { $0 }.chatWallpaper
            var wallpaperImage: UIImage?
            if let backgroundColors = backgroundColors {
                if let bottomColor = backgroundColors.1 {
                    wallpaper = .gradient(Int32(bitPattern: backgroundColors.0.rgb), Int32(bitPattern: bottomColor.rgb))
                    wallpaperImage = chatControllerBackgroundImage(theme: nil, wallpaper: wallpaper, mediaBox: context.sharedContext.accountManager.mediaBox, knockoutMode: false)
                } else {
                    wallpaper = .color(Int32(bitPattern: backgroundColors.0.rgb))
                }
            }
            
            let serviceBackgroundColor = serviceColor(for: (wallpaper, wallpaperImage))
            let theme = makePresentationTheme(mediaBox: context.sharedContext.accountManager.mediaBox, themeReference: themeReference, accentColor: accentColor, bubbleColors: messagesColors, serviceBackgroundColor: serviceBackgroundColor, preview: true) ?? defaultPresentationTheme
            
            let _ = PresentationResourcesChat.principalGraphics(mediaBox: context.account.postbox.mediaBox, knockoutWallpaper: context.sharedContext.immediateExperimentalUISettings.knockoutWallpaper, theme: theme, wallpaper: wallpaper)
            
            return (theme, (wallpaper, wallpaperImage))
        }
        |> deliverOnMainQueue).start(next: { [weak self] theme, wallpaperAndImage in
            guard let strongSelf = self else {
                return
            }
            let (wallpaper, wallpaperImage) = wallpaperAndImage
            
            strongSelf.theme = theme
            strongSelf.themeUpdated?(theme)
            strongSelf.themePromise.set(.single(theme))
            
            strongSelf.colorPanelNode.updateTheme(theme)
            strongSelf.toolbarNode.updateThemeAndStrings(theme: theme, strings: strongSelf.presentationData.strings)
            
            strongSelf.chatListBackgroundNode.backgroundColor = theme.chatList.backgroundColor
            strongSelf.maskNode.image = generateMaskImage(color: theme.chatList.backgroundColor)
            
            if case let .color(value) = wallpaper {
                strongSelf.backgroundColor  = UIColor(rgb: UInt32(bitPattern: value))
                strongSelf.chatBackgroundNode.backgroundColor = UIColor(rgb: UInt32(bitPattern: value))
                strongSelf.chatBackgroundNode.image = nil
            } else if let wallpaperImage = wallpaperImage {
                strongSelf.chatBackgroundNode.imageContentMode = .scaleToFill
                strongSelf.chatBackgroundNode.image = wallpaperImage
            }
            strongSelf.wallpaper = wallpaper
    
            if let (layout, navigationBarHeight, messagesBottomInset) = strongSelf.validLayout {
                strongSelf.updateChatsLayout(layout: layout, topInset: navigationBarHeight, transition: .immediate)
                strongSelf.updateMessagesLayout(layout: layout, bottomInset: messagesBottomInset, transition: .immediate)
            }
        })
        
        self.serviceColorDisposable = (self.themePromise.get()
        |> mapToSignal { theme -> Signal<UIColor, NoError> in
            return chatServiceBackgroundColor(wallpaper: self.presentationData.chatWallpaper, mediaBox: context.account.postbox.mediaBox)
        }
        |> deliverOnMainQueue).start(next: { [weak self] color in
            if let strongSelf = self {
                strongSelf.pageControlBackgroundNode.backgroundColor = color
            }
        })
    }
    
    deinit {
        self.colorsDisposable?.dispose()
        self.serviceColorDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.bounces = false
        self.scrollNode.view.disablesInteractiveTransitionGestureRecognizer = true
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.isPagingEnabled = true
        self.scrollNode.view.delegate = self
        self.pageControlNode.setPage(0.0)
        self.colorPanelNode.view.disablesInteractiveTransitionGestureRecognizer = true
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.chatTapped))
        self.scrollNode.view.addGestureRecognizer(tapGestureRecognizer)
        self.tapGestureRecognizer = tapGestureRecognizer
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let bounds = scrollView.bounds
        if !bounds.width.isZero {
            self.pageControlNode.setPage(scrollView.contentOffset.x / bounds.width)
        }
    }
    
    func updateState(_ f: (ThemeColorState) -> ThemeColorState, animated: Bool = false) {
        let previousState = self.state
        self.state = f(self.state)
        
        var needsLayout = false
        var animationCurve = ContainedViewLayoutTransitionCurve.easeInOut
        var animationDuration: Double = 0.3
        
        let colorsChanged = !previousState.areColorsEqual(to: self.state)
        if colorsChanged {
            self.colors.set(.single((self.state.accentColor, self.state.backgroundColors, self.state.messagesColors)))
        }
             
        let colorPanelCollapsed = self.state.colorPanelCollapsed
        
        let sectionChanged = previousState.section != self.state.section
        if sectionChanged, let section = self.state.section {
            self.view.endEditing(true)
            
            let firstColor: UIColor?
            let secondColor: UIColor?
            var defaultColor: UIColor?
            switch section {
                case .accent:
                    firstColor = self.state.accentColor ?? .blue
                    secondColor = nil
                case .background:
                    if let backgroundColors = self.state.backgroundColors {
                        firstColor = backgroundColors.0
                        secondColor = backgroundColors.1
                    } else if let image = self.chatBackgroundNode.image {
                        firstColor = averageColor(from: image)
                        secondColor = nil
                    } else {
                        firstColor = .white
                        secondColor = nil
                    }
                case .messages:
                    defaultColor = self.state.accentColor ?? .blue
                    if let messagesColors = self.state.messagesColors {
                        firstColor = messagesColors.0
                        secondColor = messagesColors.1
                    } else {
                        firstColor = nil
                        secondColor = nil
                    }
            }

            self.colorPanelNode.updateState({ _ in
                return WallpaperColorPanelNodeState(selection: colorPanelCollapsed ? .none : .first, firstColor: firstColor, defaultColor: defaultColor, secondColor: secondColor, secondColorAvailable: self.state.section != .accent)
            }, animated: animated)
            
            needsLayout = true
        }
        
        if previousState.colorPanelCollapsed != self.state.colorPanelCollapsed {
            animationCurve = .spring
            animationDuration = 0.45
            needsLayout = true
            
            self.colorPanelNode.updateState({ current in
                var updated = current
                updated.selection = colorPanelCollapsed ? .none : .first
                return updated
            }, animated: animated)
        }
        
        if needsLayout, let (layout, navigationBarHeight, _) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: animated ? .animated(duration: animationDuration, curve: animationCurve) : .immediate)
        }
    }
    
    func updateSection(_ section: ThemeColorSection) {
        self.updateState({ current in
            var updated = current
            updated.section = section
            return updated
        }, animated: true)
    }
    
    private func updateChatsLayout(layout: ContainerViewLayout, topInset: CGFloat, transition: ContainedViewLayoutTransition) {
        var items: [ChatListItem] = []
        
        let interaction = ChatListNodeInteraction(activateSearch: {}, peerSelected: { _ in }, togglePeerSelected: { _ in }, messageSelected: { _, _, _ in}, groupSelected: { _ in }, addContact: { _ in }, setPeerIdWithRevealedOptions: { _, _ in }, setItemPinned: { _, _ in }, setPeerMuted: { _, _ in }, deletePeer: { _ in }, updatePeerGrouping: { _, _ in }, togglePeerMarkedUnread: { _, _ in}, toggleArchivedFolderHiddenByDefault: {}, activateChatPreview: { _, _, gesture in
            gesture?.cancel()
        })
        let chatListPresentationData = ChatListPresentationData(theme: self.theme, fontSize: self.presentationData.fontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: true)
        
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
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex(id: MessageId(peerId: peer1.id, namespace: 0, id: 0), timestamp: timestamp1)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer1.id, namespace: 0, id: 0), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp1, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: selfPeer, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_1_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer1), combinedReadState: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, PeerReadState.idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 0, markedUnread: false))]), notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false, displayAsMessage: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let presenceTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970 + 60 * 60)
        let timestamp2 = timestamp + 3660
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer2.id, namespace: 0, id: 0), timestamp: timestamp2)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer2.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp2, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer2, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_2_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer2), combinedReadState: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, PeerReadState.idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 0, count: 1, markedUnread: false))]), notificationSettings: nil, presence: TelegramUserPresence(status: .present(until: presenceTimestamp), lastActivity: presenceTimestamp), summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false, displayAsMessage: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let timestamp3 = timestamp + 3200
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer3.id, namespace: 0, id: 0), timestamp: timestamp3)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer3.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp3, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer3Author, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_3_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer3), combinedReadState: nil, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false, displayAsMessage: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let timestamp4 = timestamp + 3000
        items.append(ChatListItem(presentationData: chatListPresentationData, context: self.context, peerGroupId: .root, index: ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: peer4.id, namespace: 0, id: 0), timestamp: timestamp4)), content: .peer(message: Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: peer4.id, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: timestamp4, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peer4, text: self.presentationData.strings.Appearance_ThemePreview_ChatList_4_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), peer: RenderedPeer(peer: peer4), combinedReadState: nil, notificationSettings: nil, presence: nil, summaryInfo: ChatListMessageTagSummaryInfo(tagSummaryCount: nil, actionsSummaryCount: nil), embeddedState: nil, inputActivities: nil, isAd: false, ignoreUnreadBadge: false, displayAsMessage: false), editing: false, hasActiveRevealControls: false, selected: false, header: nil, enableContextActions: false, hiddenOffset: false, interaction: interaction))
        
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, availableHeight: layout.size.height)
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
        let headerItem = self.context.sharedContext.makeChatMessageDateHeaderItem(context: self.context, timestamp:  self.referenceTimestamp, theme: self.theme, strings: self.presentationData.strings, wallpaper: self.wallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder)
        
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
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message1, theme: self.theme, strings: self.presentationData.strings, wallpaper: self.wallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil))
        
        let message2 = Message(stableId: 3, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 3), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66002, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_2_Text, attributes: [ReplyMessageAttribute(messageId: replyMessageId)], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message2, theme: self.theme, strings: self.presentationData.strings, wallpaper: self.wallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil))
        
        let waveformBase64 = "DAAOAAkACQAGAAwADwAMABAADQAPABsAGAALAA0AGAAfABoAHgATABgAGQAYABQADAAVABEAHwANAA0ACQAWABkACQAOAAwACQAfAAAAGQAVAAAAEwATAAAACAAfAAAAHAAAABwAHwAAABcAGQAAABQADgAAABQAHwAAAB8AHwAAAAwADwAAAB8AEwAAABoAFwAAAB8AFAAAAAAAHwAAAAAAHgAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAHwAAAAAAAAA="
        let voiceAttributes: [TelegramMediaFileAttribute] = [.Audio(isVoice: true, duration: 23, title: nil, performer: nil, waveform: MemoryBuffer(data: Data(base64Encoded: waveformBase64)!))]
        let voiceMedia = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: LocalFileMediaResource(fileId: 0), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: 0, attributes: voiceAttributes)
        
        let message3 = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66001, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: "", attributes: [], media: [voiceMedia], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message3, theme: self.theme, strings: self.presentationData.strings, wallpaper: self.wallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: FileMediaResourceStatus(mediaStatus: .playbackStatus(.paused), fetchStatus: .Local)))
        
        let message4 = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: otherPeerId, namespace: 0, id: 2), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66001, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: self.presentationData.strings.Appearance_ThemePreview_Chat_1_Text, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: [])
        items.append(self.context.sharedContext.makeChatMessagePreviewItem(context: self.context, message: message4, theme: self.theme, strings: self.presentationData.strings, wallpaper: self.wallpaper, fontSize: self.presentationData.fontSize, dateTimeFormat: self.presentationData.dateTimeFormat, nameOrder: self.presentationData.nameDisplayOrder, forcedResourceStatus: nil))
        
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right, availableHeight: layout.size.height)
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
            dateHeaderNode = headerItem.node()
            dateHeaderNode.subnodeTransform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            self.messagesContainerNode.addSubnode(dateHeaderNode)
            self.dateHeaderNode = dateHeaderNode
        }
        
        transition.updateFrame(node: dateHeaderNode, frame: CGRect(origin: CGPoint(x: 0.0, y: bottomOffset), size: CGSize(width: layout.size.width, height: headerItem.height)))
        dateHeaderNode.updateLayout(size: self.messagesContainerNode.frame.size, leftInset: layout.safeInsets.left, rightInset: layout.safeInsets.right)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let bounds = CGRect(origin: CGPoint(), size: layout.size)
        self.scrollNode.frame = bounds
        
        let toolbarHeight = 49.0 + layout.intrinsicInsets.bottom
        self.chatListBackgroundNode.frame = CGRect(x: bounds.width, y: 0.0, width: bounds.width, height: bounds.height)
        
        self.scrollNode.view.contentSize = CGSize(width: bounds.width * 2.0, height: bounds.height)
        
        var pageControlAlpha: CGFloat = 1.0
        if self.state.section != .accent {
            pageControlAlpha = 0.0
        }
        self.scrollNode.view.isScrollEnabled = pageControlAlpha > 0.0
        
        var messagesTransition = transition
        if !self.scrollNode.view.isScrollEnabled && self.scrollNode.view.contentOffset.x > 0.0 {
            var bounds = self.scrollNode.bounds
            bounds.origin.x = 0.0
            transition.updateBounds(node: scrollNode, bounds: bounds)
            messagesTransition = .immediate
            self.pageControlNode.setPage(0.0)
        }
        
        transition.updateFrame(node: self.toolbarNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - toolbarHeight), size: CGSize(width: layout.size.width, height: 49.0 + layout.intrinsicInsets.bottom)))
        self.toolbarNode.updateLayout(size: CGSize(width: layout.size.width, height: 49.0), layout: layout, transition: transition)
        
        var bottomInset = toolbarHeight
        let standardInputHeight = layout.deviceMetrics.keyboardHeight(inLandscape: false)
        let inputFieldPanelHeight: CGFloat = 47.0
        let colorPanelHeight = max(standardInputHeight, layout.inputHeight ?? 0.0) - bottomInset + inputFieldPanelHeight
        
        var colorPanelOffset: CGFloat = 0.0
        if self.state.colorPanelCollapsed {
            colorPanelOffset = colorPanelHeight - inputFieldPanelHeight
        }
        let colorPanelFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset - colorPanelHeight + colorPanelOffset), size: CGSize(width: layout.size.width, height: colorPanelHeight))
        bottomInset += (colorPanelHeight - colorPanelOffset)
        
        if bottomInset + navigationBarHeight > bounds.height {
            return
        }
        
        transition.updateFrame(node: self.colorPanelNode, frame: colorPanelFrame)
        self.colorPanelNode.updateLayout(size: colorPanelFrame.size, transition: transition)
        
        transition.updateFrame(node: self.messagesContainerNode, frame: CGRect(x: 0.0, y: navigationBarHeight, width: bounds.width, height: bounds.height - bottomInset - navigationBarHeight))
        
        let backgroundSize = CGSize(width: bounds.width, height: bounds.height - (colorPanelHeight - colorPanelOffset))
        transition.updateFrame(node: self.chatBackgroundNode, frame: CGRect(origin: CGPoint(), size: backgroundSize))
        self.chatBackgroundNode.updateLayout(size: backgroundSize, transition: transition)
        
        var messagesBottomInset: CGFloat = 0.0
        if pageControlAlpha > 0.0 {
            messagesBottomInset += 37.0
        }
        self.updateChatsLayout(layout: layout, topInset: navigationBarHeight, transition: transition)
        self.updateMessagesLayout(layout: layout, bottomInset: messagesBottomInset, transition: messagesTransition)
        
        self.validLayout = (layout, navigationBarHeight, messagesBottomInset)
        
        let pageControlSize = self.pageControlNode.measure(CGSize(width: bounds.width, height: 100.0))
        let pageControlFrame = CGRect(origin: CGPoint(x: floor((bounds.width - pageControlSize.width) / 2.0), y: layout.size.height - bottomInset - 28.0), size: pageControlSize)
        transition.updateFrame(node: self.pageControlNode, frame: pageControlFrame)
        transition.updateFrame(node: self.pageControlBackgroundNode, frame: CGRect(x: pageControlFrame.minX - 7.0, y: pageControlFrame.minY - 7.0, width: pageControlFrame.width + 14.0, height: 21.0))
        
        transition.updateAlpha(node: self.pageControlNode, alpha: pageControlAlpha)
        transition.updateAlpha(node: self.pageControlBackgroundNode, alpha: pageControlAlpha)
        transition.updateFrame(node: self.maskNode, frame: CGRect(x: 0.0, y: layout.size.height - bottomInset - 80.0, width: bounds.width, height: 80.0))
    }
    
    @objc private func chatTapped() {
        self.updateState({ current in
            var updated = current
            updated.colorPanelCollapsed = !updated.colorPanelCollapsed
            return updated
        }, animated: true)
    }
}
