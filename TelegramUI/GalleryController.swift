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
                return .PhotoOrVideo
            case let file as TelegramMediaFile:
                if file.isVideo {
                    if !file.isAnimated {
                        return .PhotoOrVideo
                    }
                } else if file.isVoice {
                    return .Voice
                } else if file.isSticker {
                    return nil
                } else {
                    return .File
                }
            default:
                break
        }
    }
    return nil
}

private func mediaForMessage(message: Message) -> Media? {
    for media in message.media {
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
    }
    return nil
}

private func itemForEntry(account: Account, entry: MessageHistoryEntry) -> GalleryItem {
    switch entry {
        case let .MessageEntry(message, _, location):
            if let media = mediaForMessage(message: message) {
                if let _ = media as? TelegramMediaImage {
                    return ChatImageGalleryItem(account: account, message: message, location: location)
                } else if let file = media as? TelegramMediaFile {
                    if file.isVideo || file.mimeType.hasPrefix("video/") {
                        return ChatVideoGalleryItem(account: account, message: message, location: location)
                    } else {
                        if file.mimeType.hasPrefix("image/") {
                            return ChatImageGalleryItem(account: account, message: message, location: location)
                        } else {
                            return ChatDocumentGalleryItem(account: account, message: message, location: location)
                        }
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
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let account: Account
    
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
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemAttributesDisposable = DisposableSet()
    
    private let _hiddenMedia = Promise<(MessageId, Media)?>(nil)
    var hiddenMedia: Signal<(MessageId, Media)?, NoError> {
        return self._hiddenMedia.get()
    }
    
    init(account: Account, messageId: MessageId) {
        self.account = account
        
        super.init()
        
        self.navigationBar.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        self.navigationBar.stripeColor = UIColor.clear
        self.navigationBar.foregroundColor = UIColor.white
        self.navigationBar.accentColor = UIColor.white
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(self.donePressed))
        
        self.statusBar.style = .White
        
        let message = account.postbox.messageAtId(messageId)
        
        let messageView = message
            |> filter({ $0 != nil })
            |> mapToSignal { message -> Signal<GalleryMessageHistoryView?, Void> in
                if let tags = tagsForMessage(message!) {
                    let view = account.postbox.aroundMessageHistoryViewForPeerId(messageId.peerId, index: MessageIndex(message!), count: 50, anchorIndex: MessageIndex(message!), fixedCombinedReadState: nil, tagMask: tags)
                        
                    return view
                        |> mapToSignal { (view, _) -> Signal<GalleryMessageHistoryView?, Void> in
                            let mapped = GalleryMessageHistoryView.view(view)
                            return .single(mapped)
                        }
                } else {
                    return .single(GalleryMessageHistoryView.single(MessageHistoryEntry.MessageEntry(message!, false, nil)))
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
                            case let .MessageEntry(message, _, _) where message.id == messageId:
                                strongSelf.centralEntryIndex = i
                                break loop
                            default:
                                break
                        }
                    }
                    if strongSelf.isViewLoaded {
                        strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({ itemForEntry(account: account, entry: $0) }), centralItemIndex: strongSelf.centralEntryIndex)
                        
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
        
        self.centralItemAttributesDisposable.add(self.centralItemNavigationStyle.get().start(next: { [weak self] style in
            if let strongSelf = self {
                switch style {
                    case .dark:
                        strongSelf.statusBar.style = .White
                        strongSelf.navigationBar.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
                        strongSelf.navigationBar.stripeColor = UIColor.clear
                        strongSelf.navigationBar.foregroundColor = UIColor.white
                        strongSelf.navigationBar.accentColor = UIColor.white
                        strongSelf.galleryNode.backgroundNode.backgroundColor = UIColor.black
                        strongSelf.galleryNode.isBackgroundExtendedOverNavigationBar = true
                    case .light:
                        strongSelf.statusBar.style = .Black
                        strongSelf.navigationBar.backgroundColor = UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0)
                        strongSelf.navigationBar.foregroundColor = UIColor.black
                        strongSelf.navigationBar.accentColor = UIColor(0x007ee5)
                        strongSelf.navigationBar.stripeColor = UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
                        strongSelf.galleryNode.backgroundNode.backgroundColor = UIColor(0xbdbdc2)
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
        var animatedOutNode = true
        var animatedOutInterface = false
        
        let completion = { [weak self] in
            if animatedOutNode && animatedOutInterface {
                self?._hiddenMedia.set(.single(nil))
                self?.presentingViewController?.dismiss(animated: false, completion: nil)
            }
        }
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? GalleryControllerPresentationArguments {
            if case let .MessageEntry(message, _, _) = self.entries[centralItemNode.index] {
                if let media = mediaForMessage(message: message), let transitionArguments = presentationArguments.transitionArguments(message.id, media) {
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
        self.displayNode = GalleryControllerNode()
        self.displayNodeDidLoad()
        
        self.galleryNode.statusBar = self.statusBar
        self.galleryNode.navigationBar = self.navigationBar
        
        self.galleryNode.transitionNodeForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? GalleryControllerPresentationArguments {
                    if case let .MessageEntry(message, _, _) = strongSelf.entries[centralItemNode.index] {
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
        
        self.galleryNode.pager.replaceItems(self.entries.map({ itemForEntry(account: self.account, entry: $0) }), centralItemIndex: self.centralEntryIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: (MessageId, Media)?
                if let index = index {
                    if case let .MessageEntry(message, _, _) = strongSelf.entries[index], let media = mediaForMessage(message: message) {
                        hiddenItem = (message.id, media)
                    }
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleView.set(node.titleView())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
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
            if case let .MessageEntry(message, _, _) = self.entries[centralItemNode.index] {
                self.centralItemTitle.set(centralItemNode.title())
                self.centralItemTitleView.set(centralItemNode.titleView())
                self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
                
                if let media = mediaForMessage(message: message), let transitionArguments = presentationArguments.transitionArguments(message.id, media) {
                    nodeAnimatesItself = true
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
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationBar.frame.maxY, transition: transition)
    }
}
