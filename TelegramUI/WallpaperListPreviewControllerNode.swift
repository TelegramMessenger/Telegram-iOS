import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

private final class WallpaperBackgroundNode: ASDisplayNode {
    let wallpaper: TelegramWallpaper
    private var fetchDisposable: Disposable?
    private let imageNode: TransformImageNode
    
    init(account: Account, wallpaper: TelegramWallpaper) {
        self.wallpaper = wallpaper
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = .subsequentUpdates
        
        super.init()
        
        self.backgroundColor = UIColor(rgb: arc4random())
        self.addSubnode(self.imageNode)
        
        let signal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>
        let fetchSignal: Signal<FetchResourceSourceType, NoError>
        let displaySize: CGSize
        switch wallpaper {
            case .builtin:
                displaySize = CGSize(width: 640.0, height: 1136.0)
                signal = settingsBuiltinWallpaperImage(account: account)
                fetchSignal = .complete()
            case let .color(color):
                displaySize = CGSize(width: 1.0, height: 1.0)
                signal = .never()
                fetchSignal = .complete()
                self.backgroundColor = UIColor(rgb: UInt32(bitPattern: color))
            case let .file(file):
                let dimensions = file.file.dimensions ?? CGSize(width: 100.0, height: 100.0)
                displaySize = dimensions.dividedByScreenScale().integralFloor
                self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                
                var convertedRepresentations: [ImageRepresentationWithReference] = []
                for representation in file.file.previewRepresentations {
                    convertedRepresentations.append(ImageRepresentationWithReference(representation: representation, reference: .standalone(resource: representation.resource)))
                }
                convertedRepresentations.append(ImageRepresentationWithReference(representation: .init(dimensions: dimensions, resource: file.file.resource), reference: .standalone(resource: file.file.resource)))
                signal = chatAvatarGalleryPhoto(account: account, representations: convertedRepresentations)
                fetchSignal = fetchedMediaResource(postbox: account.postbox, reference: convertedRepresentations[convertedRepresentations.count - 1].reference)
            case let .image(representations):
                if let largestSize = largestImageRepresentation(representations) {
                    displaySize = largestSize.dimensions.dividedByScreenScale().integralFloor
                    self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
                    
                    let convertedRepresentations: [ImageRepresentationWithReference] = representations.map({ ImageRepresentationWithReference(representation: $0, reference: .wallpaper(resource: $0.resource)) })
                    signal = chatAvatarGalleryPhoto(account: account, representations: convertedRepresentations)
                    
                    if let largestIndex = convertedRepresentations.index(where: { $0.representation == largestSize }) {
                        fetchSignal = fetchedMediaResource(postbox: account.postbox, reference: convertedRepresentations[largestIndex].reference)
                    } else {
                        fetchSignal = .complete()
                    }
                } else {
                    displaySize = CGSize(width: 100.0, height: 100.0)
                    signal = .never()
                    fetchSignal = .complete()
                }
        }
        self.imageNode.setSignal(signal, dispatchOnDisplayLink: false)
        self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: displaySize, boundingSize: displaySize, intrinsicInsets: UIEdgeInsets()))()
        self.fetchDisposable = fetchSignal.start()
        self.imageNode.contentMode = .scaleAspectFill
    }
    
    deinit {
        self.fetchDisposable?.dispose()
    }
    
    func updateLayout(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.imageNode.frame = CGRect(origin: CGPoint(), size: layout.size)
    }
}

final class WallpaperListPreviewControllerNode: ViewControllerTracingNode {
    private let account: Account
    private var presentationData: PresentationData
    private let dismiss: () -> Void
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private let toolbarBackground: ASDisplayNode
    private let toolbarSeparator: ASDisplayNode
    private let toolbarVerticalSeparator: ASDisplayNode
    private let toolbarButtonCancel: HighlightableButtonNode
    private let toolbarButtonApply: HighlightableButtonNode
    
    private var wallpapersDisposable: Disposable?
    private var wallpapers: [TelegramWallpaper]?
    let ready = ValuePromise<Bool>(false)
    
    private var messageNodes: [ListViewItemNode]?
    
    private var visibleBackgroundNodes: [WallpaperBackgroundNode] = []
    private var centralWallpaper: TelegramWallpaper?
    private var visibleBackgroundNodesOffset: CGFloat = 0.0
    
    init(account: Account, presentationData: PresentationData, source: WallpaperListPreviewSource, dismiss: @escaping () -> Void) {
        self.account = account
        self.presentationData = presentationData
        self.dismiss = dismiss
        
        self.toolbarBackground = ASDisplayNode()
        self.toolbarBackground.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        
        self.toolbarSeparator = ASDisplayNode()
        self.toolbarSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.toolbarVerticalSeparator = ASDisplayNode()
        self.toolbarVerticalSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        
        self.toolbarButtonCancel = HighlightableButtonNode()
        self.toolbarButtonCancel.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Common_Cancel, font: Font.regular(17.0), textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor), for: [])
        
        self.toolbarButtonApply = HighlightableButtonNode()
        self.toolbarButtonApply.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Wallpaper_Set, font: Font.regular(17.0), textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor), for: [])
        
        super.init()
        
        self.backgroundColor = .black
        
        self.addSubnode(self.toolbarBackground)
        self.addSubnode(self.toolbarSeparator)
        self.addSubnode(self.toolbarVerticalSeparator)
        self.addSubnode(self.toolbarButtonCancel)
        self.addSubnode(self.toolbarButtonApply)
        
        self.toolbarButtonCancel.addTarget(self, action: #selector(self.cancelPressed), forControlEvents: .touchUpInside)
        self.toolbarButtonCancel.addTarget(self, action: #selector(self.applyPressed), forControlEvents: .touchUpInside)
        
        switch source {
            /*case .common:
                self.wallpapersDisposable = (telegramWallpapers(postbox: account.postbox, network: account.network)
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let strongSelf = self else {
                        return
                    }
                    if let (layout, navigationHeight) = strongSelf.validLayout {
                        strongSelf.updateVisibleBackgroundNodes(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
                    }
                    strongSelf.ready.set(true)
                })*/
            case let .list(wallpapers, central):
                self.wallpapers = wallpapers
                self.centralWallpaper = central
                if let (layout, navigationHeight) = self.validLayout {
                    self.updateVisibleBackgroundNodes(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
                }
                self.ready.set(true)
            case let .wallpaper(wallpaper):
                self.wallpapers = [wallpaper]
                self.centralWallpaper = wallpaper
                if let (layout, navigationHeight) = self.validLayout {
                    self.updateVisibleBackgroundNodes(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
                }
                self.ready.set(true)
        }
    }
    
    deinit {
        self.wallpapersDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        self.toolbarBackground.backgroundColor = self.presentationData.theme.rootController.navigationBar.backgroundColor
        self.toolbarSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.toolbarVerticalSeparator.backgroundColor = self.presentationData.theme.rootController.navigationBar.separatorColor
        self.toolbarButtonCancel.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Common_Cancel, font: Font.regular(17.0), textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor), for: [])
        self.toolbarButtonApply.setAttributedTitle(NSAttributedString(string: self.presentationData.strings.Wallpaper_Set, font: Font.regular(17.0), textColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor), for: [])
        
        self.backgroundColor = .black
        if let (layout, navigationHeight) = self.validLayout {
            self.updateVisibleBackgroundNodes(layout: layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
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
                itemNode!.subnodeTransform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
                messageNodes.append(itemNode!)
                self.addSubnode(itemNode!)
            }
            self.messageNodes = messageNodes
        }
        
        let bottomInset = layout.intrinsicInsets.bottom + 44.0
        transition.updateFrame(node: self.toolbarBackground, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset), size: CGSize(width: layout.size.width, height: bottomInset)))
        transition.updateFrame(node: self.toolbarSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset), size: CGSize(width: layout.size.width, height: UIScreenPixel)))
        transition.updateFrame(node: self.toolbarVerticalSeparator, frame: CGRect(origin: CGPoint(x: floor(layout.size.width / 2.0), y: layout.size.height - bottomInset), size: CGSize(width: UIScreenPixel, height: bottomInset)))
        
        transition.updateFrame(node: self.toolbarButtonCancel, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - bottomInset), size: CGSize(width: floor(layout.size.width / 2.0), height: 44.0)))
        transition.updateFrame(node: self.toolbarButtonApply, frame: CGRect(origin: CGPoint(x: floor(layout.size.width / 2.0), y: layout.size.height - bottomInset), size: CGSize(width: ceil(layout.size.width / 2.0), height: 44.0)))
        
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
        var visibleBackgroundNodes: [WallpaperBackgroundNode] = []
        if let wallpapers = self.wallpapers, let centralWallpaper = self.centralWallpaper {
            outer: for i in 0 ..< wallpapers.count {
                if wallpapers[i] == centralWallpaper {
                    for j in max(0, i - 1) ... min(i + 1, wallpapers.count - 1) {
                        let itemPostition = j - i
                        let itemFrame = CGRect(origin: CGPoint(x: CGFloat(itemPostition) * layout.size.width, y: 0.0), size: layout.size)
                        var currentItemNode: WallpaperBackgroundNode?
                        inner: for current in self.visibleBackgroundNodes {
                            if current.wallpaper == wallpapers[j] {
                                currentItemNode = current
                                break inner
                            }
                        }
                        let itemNode = currentItemNode ?? WallpaperBackgroundNode(account: self.account, wallpaper: wallpapers[j])
                        visibleBackgroundNodes.append(itemNode)
                        let itemNodeTransition: ContainedViewLayoutTransition
                        if itemNode.supernode == nil {
                            self.insertSubnode(itemNode, at: 0)
                            itemNodeTransition = .immediate
                        } else {
                            itemNodeTransition = transition
                        }
                        itemNodeTransition.updateFrame(node: itemNode, frame: itemFrame)
                        itemNode.updateLayout(layout, navigationHeight: navigationBarHeight, transition: itemNodeTransition)
                        visibleBackgroundNodes.append(itemNode)
                    }
                    break outer
                }
            }
        }
        
        for itemNode in self.visibleBackgroundNodes {
            var found = false
            inner: for updatedItemNode in visibleBackgroundNodes {
                if itemNode === updatedItemNode {
                    found = true
                    break
                }
            }
            if !found {
                itemNode.removeFromSupernode()
            }
        }
        self.visibleBackgroundNodes = visibleBackgroundNodes
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let (layout, _) = self.validLayout {
            let additionalButtonHeight = layout.intrinsicInsets.bottom
            
            if self.toolbarButtonCancel.isEnabled {
                var buttonFrame = self.toolbarButtonCancel.frame
                buttonFrame.size.height += additionalButtonHeight
                if buttonFrame.contains(point) {
                    return self.toolbarButtonCancel.view
                }
            }
            if self.toolbarButtonApply.isEnabled {
                var buttonFrame = self.toolbarButtonApply.frame
                buttonFrame.size.height += additionalButtonHeight
                if buttonFrame.contains(point) {
                    return self.toolbarButtonApply.view
                }
            }
        }
        return super.hitTest(point, with: event)
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func applyPressed() {
        
    }
}
