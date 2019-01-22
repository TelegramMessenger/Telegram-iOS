import Foundation
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import Photos

enum WallpaperListType {
    case wallpapers(WallpaperPresentationOptions?)
    case colors
}

enum WallpaperListSource {
    case list(wallpapers: [TelegramWallpaper], central: TelegramWallpaper, type: WallpaperListType)
    case wallpaper(TelegramWallpaper, WallpaperPresentationOptions?)
    case slug(String, TelegramMediaFile?, WallpaperPresentationOptions?)
    case asset(PHAsset)
    case contextResult(ChatContextResult)
    case customColor(Int32?)
}

enum WallpaperGalleryEntry: Equatable {
    case wallpaper(TelegramWallpaper)
    case asset(PHAsset)
    case contextResult(ChatContextResult)
    
    public static func ==(lhs: WallpaperGalleryEntry, rhs: WallpaperGalleryEntry) -> Bool {
        switch lhs {
            case let .wallpaper(wallpaper):
                if case .wallpaper(wallpaper) = rhs {
                    return true
                } else {
                    return false
                }
            case let .asset(lhsAsset):
                if case let .asset(rhsAsset) = rhs, lhsAsset.localIdentifier == rhsAsset.localIdentifier {
                    return true
                } else {
                    return false
                }
            case let .contextResult(lhsResult):
                if case let .contextResult(rhsResult) = rhs, lhsResult.id == rhsResult.id {
                    return true
                } else {
                    return false
                }
        }
    }
}

class WallpaperGalleryOverlayNode: ASDisplayNode {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if result != self.view {
            return result
        } else {
            return nil
        }
    }
}

class WallpaperGalleryControllerNode: GalleryControllerNode {
    override func updateDistanceFromEquilibrium(_ value: CGFloat) {
        guard let itemNode = self.pager.centralItemNode() as? WallpaperGalleryItemNode else {
            return
        }
        
        itemNode.updateDismissTransition(value)
    }
}

class WallpaperGalleryController: ViewController {
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let account: Account
    private let source: WallpaperListSource
    var apply: ((WallpaperGalleryEntry, WallpaperPresentationOptions, CGRect?) -> Void)?
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var initialOptions: WallpaperPresentationOptions?
    private var entries: [WallpaperGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemSubtitle = Promise<String?>()
    private let centralItemStatus = Promise<MediaResourceStatus>()
    private let centralItemAction = Promise<UIBarButtonItem?>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var overlayNode: WallpaperGalleryOverlayNode?
    private var messageNodes: [ListViewItemNode]?
    private var toolbarNode: WallpaperGalleryToolbarNode?
    
    init(account: Account, source: WallpaperListSource) {
        self.account = account
        self.source = source
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
        
        self.title = self.presentationData.strings.WallpaperPreview_Title
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        switch source {
            case let .list(wallpapers, central, type):
                self.entries = wallpapers.map { .wallpaper($0) }
                self.centralEntryIndex = wallpapers.index(of: central)!
                
                if case let .wallpapers(wallpaperOptions) = type, let options = wallpaperOptions {
                    self.initialOptions = options
                }
            case let .slug(slug, file, options):
                if let file = file {
                    self.entries = [.wallpaper(.file(id: 0, accessHash: 0, isCreator: false, isDefault: false, slug: slug, file: file))]
                    self.centralEntryIndex = 0
                    self.initialOptions = options
                }
            case let .wallpaper(wallpaper, options):
                self.entries = [.wallpaper(wallpaper)]
                self.centralEntryIndex = 0
                self.initialOptions = options
            case let .asset(asset):
                self.entries = [.asset(asset)]
                self.centralEntryIndex = 0
            case let .contextResult(result):
                self.entries = [.contextResult(result)]
                self.centralEntryIndex = 0
            case let .customColor(color):
                let initialColor = color ?? 0x000000
                self.entries = [.wallpaper(.color(initialColor))]
                self.centralEntryIndex = 0
        }
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
       
        self.centralItemAttributesDisposable.add(self.centralItemSubtitle.get().start(next: { [weak self] subtitle in
            if let strongSelf = self {
                if let subtitle = subtitle {
                    let titleView = CounterContollerTitleView(theme: strongSelf.presentationData.theme)
                    titleView.title = CounterContollerTitle(title: strongSelf.presentationData.strings.WallpaperPreview_Title, counter: subtitle)
                    strongSelf.navigationItem.titleView = titleView
                    strongSelf.title = nil
                } else {
                    strongSelf.navigationItem.titleView = nil
                    strongSelf.title = strongSelf.presentationData.strings.WallpaperPreview_Title
                }
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemStatus.get().start(next: { [weak self] status in
            if let strongSelf = self {
                let enabled: Bool
                switch status {
                    case .Local:
                        enabled = true
                    default:
                        enabled = false
                }
                strongSelf.toolbarNode?.setDoneEnabled(enabled)
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemAction.get().start(next: { [weak self] barButton in
            if let strongSelf = self {
                strongSelf.navigationItem.setRightBarButton(barButton, animated: true)
            }
        }))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.centralItemAttributesDisposable.dispose()
    }
    
    private func updateThemeAndStrings() {
        if self.title != nil {
            self.title = self.presentationData.strings.WallpaperPreview_Title
        }
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.toolbarNode?.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings)
    }
    
    func dismiss(forceAway: Bool) {
        let completion: () -> Void = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.galleryNode.modalAnimateOut(completion: completion)
    }
    
    override func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
            }
        }, dismissController: { [weak self] in
                self?.dismiss(forceAway: true)
        }, replaceRootController: { controller, ready in
        })
        self.displayNode = WallpaperGalleryControllerNode(controllerInteraction: controllerInteraction, pageGap: 0.0)
        self.displayNodeDidLoad()
        
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        self.galleryNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                if let node = strongSelf.galleryNode.pager.centralItemNode() as? WallpaperGalleryItemNode {
                    strongSelf.centralItemSubtitle.set(node.subtitle.get())
                    strongSelf.centralItemStatus.set(node.status.get())
                    strongSelf.centralItemAction.set(node.actionButton.get())
                    node.action = { [weak self] in
                        self?.actionPressed()
                    }
                    
                    if let (layout, _) = strongSelf.validLayout {
                        strongSelf.containerLayoutUpdated(layout, transition: .animated(duration: 0.2, curve: .easeInOut))
                    }
                }
            }
        }
        
        self.galleryNode.backgroundNode.backgroundColor = nil
        self.galleryNode.backgroundNode.isOpaque = false
        self.galleryNode.isBackgroundExtendedOverNavigationBar = true
        
        switch self.source {
            case .asset, .contextResult, .customColor:
                self.galleryNode.scrollView.isScrollEnabled = false
            default:
                break
        }
        
        let presentationData = self.account.telegramApplicationContext.currentPresentationData.with { $0 }
        let toolbarNode = WallpaperGalleryToolbarNode(theme: presentationData.theme, strings: presentationData.strings)
        let overlayNode = WallpaperGalleryOverlayNode()
        self.overlayNode = overlayNode
        self.galleryNode.overlayNode = overlayNode
        self.galleryNode.addSubnode(overlayNode)
        
        self.toolbarNode = toolbarNode
        overlayNode.addSubnode(toolbarNode)
        
        toolbarNode.cancel = { [weak self] in
            self?.dismiss(forceAway: true)
        }
        toolbarNode.done = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode() as? WallpaperGalleryItemNode {
                    let options = centralItemNode.options
                    if !strongSelf.entries.isEmpty {
                        let entry = strongSelf.entries[centralItemNode.index]
                        switch entry {
                            case let .wallpaper(wallpaper):
                                let completion: () -> Void = {
                                    let _ = (updatePresentationThemeSettingsInteractively(postbox: strongSelf.account.postbox, { current in
                                        return PresentationThemeSettings(chatWallpaper: wallpaper, chatWallpaperOptions: options, theme: current.theme, themeAccentColor: current.themeAccentColor, fontSize: current.fontSize, automaticThemeSwitchSetting: current.automaticThemeSwitchSetting, disableAnimations: current.disableAnimations)
                                    }) |> deliverOnMainQueue).start(completed: {
                                        self?.dismiss(forceAway: true)
                                    })
                                    
                                    if case .wallpaper = strongSelf.source {
                                        let _ = saveWallpaper(account: strongSelf.account, wallpaper: wallpaper).start()
                                    }
                                    let _ = installWallpaper(account: strongSelf.account, wallpaper: wallpaper).start()
                                }
                                
                                if options.contains(.blur) {
                                    var resource: MediaResource?
                                    switch wallpaper {
                                    case let .file(file):
                                        resource = file.file.resource
                                    case let .image(representations):
                                        if let largestSize = largestImageRepresentation(representations) {
                                            resource = largestSize.resource
                                        }
                                    default:
                                        break
                                    }
                                    
                                    if let resource = resource {
                                        let _ = strongSelf.account.postbox.mediaBox.cachedResourceRepresentation(resource, representation: CachedBlurredWallpaperRepresentation(), complete: true, fetch: true).start(completed: {
                                            completion()
                                        })
                                    }
                                } else {
                                    completion()
                                }
                            default:
                                break
                        }

                        strongSelf.apply?(entry, options, nil)
                    }
                }
            }
        }
        
        let ready = self.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
            self?.didSetReady = true
        }
        self._ready.set(ready |> map { true })
    }
    
    private func currentEntry() -> WallpaperGalleryEntry? {
        if let centralItemNode = self.galleryNode.pager.centralItemNode() as? WallpaperGalleryItemNode {
            return centralItemNode.entry
        } else {
            return nil
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.galleryNode.modalAnimateIn()
        
        if let node = self.galleryNode.pager.centralItemNode() as? WallpaperGalleryItemNode {
            self.centralItemSubtitle.set(node.subtitle.get())
            self.centralItemStatus.set(node.status.get())
            self.centralItemAction.set(node.actionButton.get())
            node.action = { [weak self] in
                self?.actionPressed()
            }
            
            if let (layout, _) = self.validLayout {
                self.containerLayoutUpdated(layout, transition: .immediate)
            }
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let hadLayout = self.validLayout != nil
        
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
        self.overlayNode?.frame = self.galleryNode.bounds
        
        var items: [ChatMessageItem] = []
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: 1)
        let otherPeerId = self.account.peerId
        var peers = SimpleDictionary<PeerId, Peer>()
        let messages = SimpleDictionary<MessageId, Message>()
        peers[peerId] = TelegramUser(id: peerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_PreviewReplyAuthor, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        peers[otherPeerId] = TelegramUser(id: otherPeerId, accessHash: nil, firstName: self.presentationData.strings.Appearance_PreviewReplyAuthor, lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        
        let bottomInset = layout.intrinsicInsets.bottom + 49.0
        var optionsAvailable = true
        if let centralItemNode = self.galleryNode.pager.centralItemNode() {
            if !self.entries.isEmpty {
                let entry = self.entries[centralItemNode.index]
                switch entry {
                    case let .wallpaper(wallpaper):
                        switch wallpaper {
                            case .color:
                                optionsAvailable = false
                            default:
                                break
                        }
                    default:
                        break
                }
            }
        }
        
        let controllerInteraction = ChatControllerInteraction.default
        let chatPresentationData = ChatPresentationData(theme: ChatPresentationThemeData(theme: self.presentationData.theme, wallpaper: self.presentationData.chatWallpaper), fontSize: self.presentationData.fontSize, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: false)
        
        let topMessageText: String
        let bottomMessageText: String
        switch self.source {
            case .wallpaper, .slug:
                topMessageText = presentationData.strings.WallpaperPreview_PreviewTopText
                bottomMessageText = presentationData.strings.WallpaperPreview_PreviewBottomText
            case let .list(_, _, type):
                switch type {
                    case .wallpapers:
                        topMessageText = presentationData.strings.WallpaperPreview_SwipeTopText
                        bottomMessageText = presentationData.strings.WallpaperPreview_SwipeBottomText
                    case .colors:
                        topMessageText = presentationData.strings.WallpaperPreview_SwipeColorsTopText
                        bottomMessageText = presentationData.strings.WallpaperPreview_SwipeColorsBottomText
                }
            case .asset, .contextResult:
                topMessageText = presentationData.strings.WallpaperPreview_CropTopText
                bottomMessageText = presentationData.strings.WallpaperPreview_CropBottomText
            case .customColor:
                topMessageText = presentationData.strings.WallpaperPreview_CustomColorTopText
                bottomMessageText = presentationData.strings.WallpaperPreview_CustomColorBottomText
        }
        
        items.append(ChatMessageItem(presentationData: chatPresentationData, account: self.account, chatLocation: .peer(peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false), controllerInteraction: controllerInteraction, content: .message(message: Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 2), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66001, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[otherPeerId], text: bottomMessageText, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), read: true, selection: .none, isAdmin: false), disableDate: false))
        
        items.append(ChatMessageItem(presentationData: chatPresentationData, account: self.account, chatLocation: .peer(peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false), controllerInteraction: controllerInteraction, content: .message(message: Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: peerId, namespace: 0, id: 1), globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: 66000, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, author: peers[peerId], text: topMessageText, attributes: [], media: [], peers: peers, associatedMessages: messages, associatedMessageIds: []), read: true, selection: .none, isAdmin: false), disableDate: false))
        
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
                self.overlayNode?.addSubnode(itemNode!)
            }
            self.messageNodes = messageNodes
        }
        
        transition.updateFrame(node: self.toolbarNode!, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - 49.0 - layout.intrinsicInsets.bottom), size: CGSize(width: layout.size.width, height: 49.0 + layout.intrinsicInsets.bottom)))
        self.toolbarNode!.updateLayout(size: CGSize(width: layout.size.width, height: 49.0), layout: layout, transition: transition)
        
        if let messageNodes = self.messageNodes {
            var bottomOffset: CGFloat = layout.size.height - bottomInset - 9.0
            if optionsAvailable {
                bottomOffset -= 66.0
            }
            for itemNode in messageNodes {
                transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: bottomOffset - itemNode.frame.height), size: itemNode.frame.size))
                bottomOffset -= itemNode.frame.height
            }
        }
        
        self.validLayout = (layout, 0.0)
        
        if !hadLayout {
            self.galleryNode.pager.replaceItems(self.entries.map({ WallpaperGalleryItem(account: self.account, entry: $0) }), centralItemIndex: self.centralEntryIndex)
            
            if let initialOptions = self.initialOptions, let itemNode = self.galleryNode.pager.centralItemNode() as? WallpaperGalleryItemNode {
                itemNode.options = initialOptions
            }
        }
    }
    
    private func actionPressed() {
        guard let entry = self.currentEntry(), case let .wallpaper(wallpaper) = entry, let itemNode = self.galleryNode.pager.centralItemNode() as? WallpaperGalleryItemNode else {
            return
        }
        
        var options = ""
        if (itemNode.options.contains(.blur)) {
            options = "?mode=blur"
        }
        if (itemNode.options.contains(.motion)) {
            if options.isEmpty {
                options = "?mode=motion"
            } else {
                options += "+motion"
            }
        }
        
        var controller: ShareController?
        switch wallpaper {
            case let .file(_, _, _, _, slug, _):
                controller = ShareController(account: account, subject: .url("https://t.me/bg/\(slug)\(options)"))
            case let .color(color):
                controller = ShareController(account: account, subject: .url("https://t.me/bg/\(String(UInt32(bitPattern: color), radix: 16, uppercase: false).rightJustified(width: 6, pad: "0"))"))
            default:
                break
        }
        if let controller = controller {
            self.present(controller, in: .window(.root), blockInteraction: true)
        }
    }
}

private extension GalleryControllerNode {
    func modalAnimateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func modalAnimateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
}
