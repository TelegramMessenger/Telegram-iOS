import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

enum WallpaperListPreviewSource {
    case common
    case wallpaper(TelegramWallpaper)
}

private final class WallpaperBackgroundNode: ASDisplayNode {
    var fetchDisposable: Disposable?
    
    init(network: Network, wallpaper: TelegramWallpaper) {
        super.init()
        
        switch wallpaper {
            case .builtin:
                break
            case let .color(color):
                break
            case let .file(file):
                break
            case let .image(representations):
                break
        }
    }
    
    deinit {
        self.fetchDisposable?.dispose()
    }
}

final class WallpaperListPreviewControllerNode: ViewControllerTracingNode {
    private let account: Account
    private let presentationData: PresentationData
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let toolbarBackground: ASDisplayNode
    private let toolbarSeparator: ASDisplayNode
    private let toolbarButtonCancel: HighlightableButtonNode
    private let toolbarButtonApply: HighlightableButtonNode
    
    private var wallpapersDisposable: Disposable?
    private var wallpapers: [TelegramWallpaper]?
    let ready = Promise<Void>()
    
    private var messageNodes: [ListViewItemNode]?
    
    private var visibleBackgroundNodes: [WallpaperBackgroundNode] = []
    private var visibleBackgroundNodesOffset: CGFloat = 0.0
    
    init(account: Account, presentationData: PresentationData, source: WallpaperListPreviewSource) {
        self.account = account
        self.presentationData = presentationData
        
        self.toolbarBackground = ASDisplayNode()
        self.toolbarBackground.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        
        self.toolbarSeparator = ASDisplayNode()
        self.toolbarSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.toolbarButtonCancel = HighlightableButtonNode()
        self.toolbarButtonCancel.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Common_Cancel, font: Font.regular(17.0), textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor), for: [])
        
        self.toolbarButtonApply = HighlightableButtonNode()
        self.toolbarButtonApply.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Wallpaper_Set, font: Font.regular(17.0), textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor), for: [])
        
        super.init()
        
        self.backgroundColor = .black
        
        self.addSubnode(self.toolbarBackground)
        self.addSubnode(self.toolbarSeparator)
        self.addSubnode(self.toolbarButtonCancel)
        self.addSubnode(self.toolbarButtonApply)
        
        switch source {
            case .common:
                self.wallpapersDisposable = (telegramWallpapers(postbox: account.postbox, network: account.network)
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let strongSelf = self else {
                        return
                    }
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.updateVisibleBackgroundNodes(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
                    }
                    strongSelf.ready.set(.single(Void()))
                })
            case let .wallpaper(wallpaper):
                self.wallpapers = [wallpaper]
                if let (layout, navigationHeight) = self.validLayout {
                    self.updateVisibleBackgroundNodes(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
                }
                self.ready.set(.single(Void()))
        }
    }
    
    deinit {
        self.wallpapersDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                break
            case .cancelled, .ended:
                break
            default:
                break
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        var items: [ChatMessageItem] = []
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 1)
        var peers = SimpleDictionary<PeerId, Peer>()
        let messages = SimpleDictionary<MessageId, Message>()
        peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_PreviewReplyAuthor, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        let controllerInteraction = ChatControllerInteraction(openMessage: { _, _ in
            return false }, openPeer: { _, _, _ in }, openPeerMention: { _ in }, openMessageContextMenu: { _, _, _, _ in }, navigateToMessage: { _, _ in }, clickThroughMessage: { }, toggleMessagesSelection: { _, _ in }, sendMessage: { _ in }, sendSticker: { _, _ in }, sendGif: { _ in }, requestMessageActionCallback: { _, _, _ in }, activateSwitchInline: { _, _ in }, openUrl: { _, _, _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _ in  }, openHashtag: { _, _ in }, updateInputState: { _ in }, updateInputMode: { _ in }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in }, navigationController: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _ in }, longTap: { _ in }, openCheckoutOrReceipt: { _ in }, openSearch: { }, setupReply: { _ in
        }, canSetupReply: { _ in
            return false
        }, navigateToFirstDateMessage: { _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _ in
        }, requestSelectMessagePollOption: { _, _ in
        }, openAppStorePage: {
        }, requestMessageUpdate: { _ in
        }, cancelInteractiveKeyboardGestures: {
        }, automaticMediaDownloadSettings: AutomaticMediaDownloadSettings.defaultSettings,
           pollActionState: ChatInterfacePollActionState())
        
        let chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper), fontSize: presentationData.fontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: false)
        
        items.append(ChatMessageItem(presentationData: chatPresentationData, account: self.account, chatLocation: .peer(peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false), controllerInteraction: controllerInteraction, content: .message(message: Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: nil, text: self.presentationData.strings.Appearance_PreviewIncomingText, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), read: true, selection: .none, isAdmin: false), disableDate: true))
        
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
                messageNodes.append(itemNode!)
                self.addSubnode(itemNode!)
            }
            self.messageNodes = messageNodes
        }
        
        let bottomInset = layout.intrinsicInsets.bottom + 44.0
        transition.updateFrame(node: self.toolbarBackground, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset), size: CGSize(width: layout.size.width, height: bottomInset)))
        transition.updateFrame(node: self.toolbarSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        
        if let messageNodes = self.messageNodes {
            var bottomOffset: CGFloat = layout.size.height - bottomInset - 3.0
            for itemNode in messageNodes {
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: bottomOffset - itemNode.frame.height), size: itemNode.frame.size))
                bottomOffset -= itemNode.frame.height
            }
        }
        
        self.updateVisibleBackgroundNodes(layout: layout, navigationBarHeight: navigationBarHeight, transition: transition)
    }
    
    private func updateVisibleBackgroundNodes(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        
    }
}
