import Foundation
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore

private func tagsForMessage(_ message: Message) -> MessageTags? {
    for media in message.media {
        switch media {
            case _ as TelegramMediaImage:
                return .photoOrVideo
            case let file as TelegramMediaFile:
                if file.isVideo {
                    if !file.isAnimated {
                        return .photoOrVideo
                    }
                } else if file.isVoice {
                    return .voiceOrInstantVideo
                } else if file.isSticker {
                    return nil
                } else {
                    return .file
                }
            default:
                break
        }
    }
    return nil
}

private func galleryMediaForMedia(media: Media) -> Media? {
    if let media = media as? TelegramMediaImage {
        return media
    } else if let file = media as? TelegramMediaFile {
        if file.mimeType.hasPrefix("audio/") {
            return nil
        } else if !file.isVideo && file.mimeType.hasPrefix("video/") {
            return file
        } else {
            return file
        }
    }
    return nil
}

private func mediaForMessage(message: Message) -> Media? {
    for media in message.media {
        if let result = galleryMediaForMedia(media: media) {
            return result
        } else if let webpage = media as? TelegramMediaWebpage {
            switch webpage.content {
                case let .Loaded(content):
                    if let embedUrl = content.embedUrl, !embedUrl.isEmpty {
                        return webpage
                    } else if let image = content.image {
                        if let result = galleryMediaForMedia(media: image) {
                            return result
                        }
                    } else if let file = content.file {
                        if let result = galleryMediaForMedia(media: file) {
                            return result
                        }
                    }
                case .Pending:
                    break
            }
        }
    }
    return nil
}

func galleryItemForEntry(account: Account, theme: PresentationTheme, strings: PresentationStrings, entry: MessageHistoryEntry) -> GalleryItem {
    switch entry {
        case let .MessageEntry(message, _, location, _):
            if let media = mediaForMessage(message: message) {
                if let _ = media as? TelegramMediaImage {
                    return ChatImageGalleryItem(account: account, theme: theme, strings: strings, message: message, location: location)
                } else if let file = media as? TelegramMediaFile {
                    if file.isVideo || file.mimeType.hasPrefix("video/") {
                        return UniversalVideoGalleryItem(account: account, theme: theme, strings: strings, content: NativeVideoContent(file: file), originData: GalleryItemOriginData(title: message.author?.displayTitle, timestamp: message.timestamp), indexData: location.flatMap { GalleryItemIndexData(position: Int32($0.index), totalCount: Int32($0.count)) }, caption: message.text)
                    } else {
                        if file.mimeType.hasPrefix("image/") {
                            return ChatImageGalleryItem(account: account, theme: theme, strings: strings, message: message, location: location)
                        } else {
                            return ChatDocumentGalleryItem(account: account, theme: theme, strings: strings, message: message, location: location)
                        }
                    }
                } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(webpageContent) = webpage.content {
                    if let content = WebEmbedVideoContent(webpageContent: webpageContent) {
                        return UniversalVideoGalleryItem(account: account, theme: theme, strings: strings, content: content, originData: GalleryItemOriginData(title: message.author?.displayTitle, timestamp: message.timestamp), indexData: location.flatMap { GalleryItemIndexData(position: Int32($0.index), totalCount: Int32($0.count)) }, caption: message.text)
                    }
                }
            }
        default:
            break
    }
    return ChatHoleGalleryItem()
}

final class GalleryTransitionArguments {
    let transitionNode: ASDisplayNode
    let transitionContainerNode: ASDisplayNode
    let transitionBackgroundNode: ASDisplayNode
    
    init(transitionNode: ASDisplayNode, transitionContainerNode: ASDisplayNode, transitionBackgroundNode: ASDisplayNode) {
        self.transitionNode = transitionNode
        self.transitionContainerNode = transitionContainerNode
        self.transitionBackgroundNode = transitionBackgroundNode
    }
}

final class GalleryControllerPresentationArguments {
    let transitionArguments: (MessageId, Media) -> GalleryTransitionArguments?
    
    init(transitionArguments: @escaping (MessageId, Media) -> GalleryTransitionArguments?) {
        self.transitionArguments = transitionArguments
    }
}

private enum GalleryMessageHistoryView {
    case view(MessageHistoryView)
    case single(MessageHistoryEntry)
    
    var entries: [MessageHistoryEntry] {
        switch self {
            case let .view(view):
                return view.entries
            case let .single(entry):
                return [entry]
        }
    }
}

class GalleryController: ViewController {
    static let darkNavigationTheme = NavigationBarTheme(buttonColor: .white, primaryTextColor: .white, backgroundColor: UIColor(white: 0.0, alpha: 0.6), separatorColor: UIColor(white: 0.0, alpha: 0.8))
    static let lightNavigationTheme = NavigationBarTheme(buttonColor: UIColor(rgb: 0x007ee5), primaryTextColor: .black, backgroundColor: UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0), separatorColor: UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0))
    
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let account: Account
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    
    private var entries: [MessageHistoryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemRightBarButtonItem = Promise<UIBarButtonItem?>()
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<GalleryFooterContentNode?>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private let _hiddenMedia = Promise<(MessageId, Media)?>(nil)
    var hiddenMedia: Signal<(MessageId, Media)?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let replaceRootController: (ViewController, ValuePromise<Bool>?) -> Void
    private let baseNavigationController: NavigationController?
    
    init(account: Account, messageId: MessageId, invertItemOrder: Bool = false, replaceRootController: @escaping (ViewController, ValuePromise<Bool>?) -> Void, baseNavigationController: NavigationController?) {
        self.account = account
        self.replaceRootController = replaceRootController
        self.baseNavigationController = baseNavigationController
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarTheme: GalleryController.darkNavigationTheme)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        
        self.statusBar.statusBarStyle = .White
        
        let message = account.postbox.messageAtId(messageId)
        
        let messageView = message
            |> filter({ $0 != nil })
            |> mapToSignal { message -> Signal<GalleryMessageHistoryView?, Void> in
                if let tags = tagsForMessage(message!) {
                    let view = account.postbox.aroundMessageHistoryViewForPeerId(messageId.peerId, index: MessageIndex(message!), count: 50, clipHoles: false, anchorIndex: MessageIndex(message!), fixedCombinedReadState: nil, topTaggedMessageIdNamespaces: [], tagMask: tags, orderStatistics: [.combinedLocation])
                        
                    return view
                        |> mapToSignal { (view, _, _) -> Signal<GalleryMessageHistoryView?, Void> in
                            let mapped = GalleryMessageHistoryView.view(view)
                            return .single(mapped)
                        }
                } else {
                    return .single(GalleryMessageHistoryView.single(MessageHistoryEntry.MessageEntry(message!, false, nil, nil)))
                }
            }
            |> take(1)
            |> deliverOnMainQueue
        
        self.disposable.set(messageView.start(next: { [weak self] view in
            if let strongSelf = self {
                if let view = view {
                    strongSelf.entries = view.entries
                        loop: for i in 0 ..< strongSelf.entries.count {
                        switch strongSelf.entries[i] {
                            case let .MessageEntry(message, _, _, _) where message.id == messageId:
                                strongSelf.centralEntryIndex = i
                                break loop
                            default:
                                break
                        }
                    }
                    if strongSelf.isViewLoaded {
                        strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({ galleryItemForEntry(account: account, theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, entry: $0) }), centralItemIndex: strongSelf.centralEntryIndex)
                        
                        let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
                            strongSelf?.didSetReady = true
                        }
                        strongSelf._ready.set(ready |> map { true })
                    }
                }
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitle.get().start(next: { [weak self] title in
            self?.navigationItem.title = title
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitleView.get().start(next: { [weak self] titleView in
            self?.navigationItem.titleView = titleView
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemRightBarButtonItem.get().start(next: { [weak self] rightBarButtonItem in
            self?.navigationItem.rightBarButtonItem = rightBarButtonItem
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode in
            self?.galleryNode.updatePresentationState({
                $0.withUpdatedFooterContentNode(footerContentNode)
            }, transition: .immediate)
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemNavigationStyle.get().start(next: { [weak self] style in
            if let strongSelf = self {
                switch style {
                    case .dark:
                        strongSelf.statusBar.statusBarStyle = .White
                        strongSelf.navigationBar?.updateTheme(GalleryController.darkNavigationTheme)
                        strongSelf.galleryNode.backgroundNode.backgroundColor = UIColor.black
                        strongSelf.galleryNode.isBackgroundExtendedOverNavigationBar = true
                    case .light:
                        strongSelf.statusBar.statusBarStyle = .Black
                        strongSelf.navigationBar?.updateTheme(GalleryController.lightNavigationTheme)
                        strongSelf.galleryNode.backgroundNode.backgroundColor = UIColor(rgb: 0xbdbdc2)
                        strongSelf.galleryNode.isBackgroundExtendedOverNavigationBar = false
                }
            }
        }))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.centralItemAttributesDisposable.dispose()
    }
    
    @objc func donePressed() {
        self.dismiss(forceAway: false)
    }
    
    private func dismiss(forceAway: Bool) {
        var animatedOutNode = true
        var animatedOutInterface = false
        
        let completion = { [weak self] in
            if animatedOutNode && animatedOutInterface {
                self?._hiddenMedia.set(.single(nil))
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? GalleryControllerPresentationArguments {
            if case let .MessageEntry(message, _, _, _) = self.entries[centralItemNode.index] {
                if let media = mediaForMessage(message: message), let transitionArguments = presentationArguments.transitionArguments(message.id, media), !forceAway {
                    animatedOutNode = false
                    centralItemNode.animateOut(to: transitionArguments.transitionNode, completion: {
                        animatedOutNode = true
                        completion()
                    })
                }
            }
        }
        
        self.galleryNode.animateOut(animateContent: animatedOutNode, completion: {
            animatedOutInterface = true
            completion()
        })
    }
    
    override func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments)
            }
        }, dismissController: { [weak self] in
            self?.dismiss(forceAway: true)
        }, replaceRootController: { [weak self] controller, ready in
            if let strongSelf = self {
                strongSelf.replaceRootController(controller, ready)
            }
        })
        self.displayNode = GalleryControllerNode(controllerInteraction: controllerInteraction)
        self.displayNodeDidLoad()
        
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        
        self.galleryNode.transitionNodeForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? GalleryControllerPresentationArguments {
                    if case let .MessageEntry(message, _, _, _) = strongSelf.entries[centralItemNode.index] {
                        if let media = mediaForMessage(message: message), let transitionArguments = presentationArguments.transitionArguments(message.id, media) {
                            return transitionArguments.transitionNode
                        }
                    }
                }
            }
            return nil
        }
        self.galleryNode.dismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.galleryNode.beginCustomDismiss = { [weak self] in
            if let strongSelf = self {
                strongSelf._hiddenMedia.set(.single(nil))
                
                var animatedOutNode = true
                var animatedOutInterface = false
                
                let completion = {
                    if animatedOutNode && animatedOutInterface {
                        //self?.presentingViewController?.dismiss(animated: false, completion: nil)
                    }
                }
                
                /*if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? GalleryControllerPresentationArguments {
                    if case let .MessageEntry(message, _, _, _) = self.entries[centralItemNode.index] {
                        if let media = mediaForMessage(message: message), let transitionArguments = presentationArguments.transitionArguments(message.id, media), !forceAway {
                            animatedOutNode = false
                            centralItemNode.animateOut(to: transitionArguments.transitionNode, completion: {
                                animatedOutNode = true
                                completion()
                            })
                        }
                    }
                }*/
                
                strongSelf.galleryNode.animateOut(animateContent: animatedOutNode, completion: {
                    animatedOutInterface = true
                    //completion()
                })
            }
        }
        
        self.galleryNode.completeCustomDismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        let baseNavigationController = self.baseNavigationController
        self.galleryNode.baseNavigationController = { [weak baseNavigationController] in
            return baseNavigationController
        }
        
        self.galleryNode.pager.replaceItems(self.entries.map({ galleryItemForEntry(account: self.account, theme: self.presentationData.theme, strings: self.presentationData.strings, entry: $0) }), centralItemIndex: self.centralEntryIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: (MessageId, Media)?
                if let index = index {
                    if case let .MessageEntry(message, _, _, _) = strongSelf.entries[index], let media = mediaForMessage(message: message) {
                        hiddenItem = (message.id, media)
                    }
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleView.set(node.titleView())
                        strongSelf.centralItemRightBarButtonItem.set(node.rightBarButtonItem())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
                        strongSelf.centralItemFooterContentNode.set(node.footerContent())
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(hiddenItem))
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? GalleryControllerPresentationArguments {
            if case let .MessageEntry(message, _, _, _) = self.entries[centralItemNode.index] {
                self.centralItemTitle.set(centralItemNode.title())
                self.centralItemTitleView.set(centralItemNode.titleView())
                self.centralItemRightBarButtonItem.set(centralItemNode.rightBarButtonItem())
                self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
                self.centralItemFooterContentNode.set(centralItemNode.footerContent())
                
                if let media = mediaForMessage(message: message), let transitionArguments = presentationArguments.transitionArguments(message.id, media) {
                    nodeAnimatesItself = true
                    centralItemNode.activateAsInitial()
                    centralItemNode.animateIn(from: transitionArguments.transitionNode)
                    
                    self._hiddenMedia.set(.single((message.id, media)))
                }
            }
        }
        
        self.galleryNode.animateIn(animateContent: !nodeAnimatesItself)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
