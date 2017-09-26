import Foundation
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore

enum AvatarGalleryEntry: Equatable {
    case topImage([TelegramMediaImageRepresentation], GalleryItemIndexData?)
    case image(TelegramMediaImage, GalleryItemIndexData?)
    
    var representations: [TelegramMediaImageRepresentation] {
        switch self {
            case let .topImage(representations, _):
                return representations
            case let .image(image, _):
                return image.representations
        }
    }
    
    var indexData: GalleryItemIndexData? {
        switch self {
            case let .topImage(_, indexData):
                return indexData
            case let .image(_, indexData):
                return indexData
        }
    }
    
    static func ==(lhs: AvatarGalleryEntry, rhs: AvatarGalleryEntry) -> Bool {
        switch lhs {
            case let .topImage(lhsRepresentations, lhsIndexData):
                if case let .topImage(rhsRepresentations, rhsIndexData) = rhs, lhsRepresentations == rhsRepresentations, lhsIndexData == rhsIndexData {
                    return true
                } else {
                    return false
                }
            case let .image(lhsImage, lhsIndexData):
                if case let .image(rhsImage, rhsIndexData) = rhs, lhsImage.isEqual(rhsImage), lhsIndexData == rhsIndexData {
                    return true
                } else {
                    return false
                }
        }
    }
}

final class AvatarGalleryControllerPresentationArguments {
    let transitionArguments: (AvatarGalleryEntry) -> GalleryTransitionArguments?
    
    init(transitionArguments: @escaping (AvatarGalleryEntry) -> GalleryTransitionArguments?) {
        self.transitionArguments = transitionArguments
    }
}

private func initialAvatarGalleryEntries(peer: Peer) -> [AvatarGalleryEntry]{
    var initialEntries: [AvatarGalleryEntry] = []
    if let user = peer as? TelegramUser, !user.photo.isEmpty {
        initialEntries.append(.topImage(user.photo, nil))
    } else if let group = peer as? TelegramGroup {
        initialEntries.append(.topImage(group.photo, nil))
    } else if let channel = peer as? TelegramChannel {
        initialEntries.append(.topImage(channel.photo, nil))
    }
    return initialEntries
}

func fetchedAvatarGalleryEntries(account: Account, peer: Peer) -> Signal<[AvatarGalleryEntry], NoError> {
    return requestPeerPhotos(account: account, peerId: peer.id) |> map { photos -> [AvatarGalleryEntry] in
        var result: [AvatarGalleryEntry] = []
        let initialEntries = initialAvatarGalleryEntries(peer: peer)
        if photos.isEmpty {
            result = initialEntries
        } else {
            var index: Int32 = 0
            for photo in photos {
                let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photos.count))
                if result.isEmpty, let first = initialEntries.first {
                    let image = TelegramMediaImage(imageId: photo.image.imageId, representations: first.representations)
                    result.append(.image(image, indexData))
                } else {
                    result.append(.image(photo.image, indexData))
                }
                index += 1
            }
        }
        return result
    }
}

class AvatarGalleryController: ViewController {
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
    
    private var entries: [AvatarGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<GalleryFooterContentNode?>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private let _hiddenMedia = Promise<AvatarGalleryEntry?>(nil)
    var hiddenMedia: Signal<AvatarGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let replaceRootController: (ViewController, ValuePromise<Bool>?) -> Void
    
    init(account: Account, peer: Peer, remoteEntries: Promise<[AvatarGalleryEntry]>? = nil, replaceRootController: @escaping (ViewController, ValuePromise<Bool>?) -> Void) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.replaceRootController = replaceRootController
        
        super.init(navigationBarTheme: GalleryController.darkNavigationTheme)
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        
        self.statusBar.statusBarStyle = .White
        
        let remoteEntriesSignal: Signal<[AvatarGalleryEntry], NoError>
        if let remoteEntries = remoteEntries {
            remoteEntriesSignal = remoteEntries.get()
        } else {
            remoteEntriesSignal = fetchedAvatarGalleryEntries(account: account, peer: peer)
        }
        
        let entriesSignal: Signal<[AvatarGalleryEntry], NoError> = .single(initialAvatarGalleryEntries(peer: peer)) |> then(remoteEntriesSignal)
        
        let presentationData = self.presentationData
        self.disposable.set((entriesSignal |> deliverOnMainQueue).start(next: { [weak self] entries in
            if let strongSelf = self {
                strongSelf.entries = entries
                strongSelf.centralEntryIndex = 0
                if strongSelf.isViewLoaded {
                    strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({ PeerAvatarImageGalleryItem(account: account, strings: presentationData.strings, entry: $0) }), centralItemIndex: 0, keepFirst: true)
                    
                    let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
                        strongSelf?.didSetReady = true
                    }
                    strongSelf._ready.set(ready |> map { true })
                }
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitle.get().start(next: { [weak self] title in
            if let strongSelf = self {
                strongSelf.navigationItem.setTitle(title, animated: strongSelf.navigationItem.title?.isEmpty ?? true)
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitleView.get().start(next: { [weak self] titleView in
            self?.navigationItem.titleView = titleView
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode in
            self?.galleryNode.updatePresentationState({
                $0.withUpdatedFooterContentNode(footerContentNode)
            }, transition: .immediate)
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
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
            if !self.entries.isEmpty {
                if centralItemNode.index == 0, let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]), !forceAway {
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
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? AvatarGalleryControllerPresentationArguments {
                    if centralItemNode.index != 0 {
                        return nil
                    }
                    if let transitionArguments = presentationArguments.transitionArguments(strongSelf.entries[centralItemNode.index]) {
                        return transitionArguments.transitionNode
                    }
                }
            }
            return nil
        }
        self.galleryNode.dismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        let presentationData = self.presentationData
        self.galleryNode.pager.replaceItems(self.entries.map({ PeerAvatarImageGalleryItem(account: self.account, strings: presentationData.strings, entry: $0) }), centralItemIndex: self.centralEntryIndex)
        
        self.galleryNode.pager.centralItemIndexUpdated = { [weak self] index in
            if let strongSelf = self {
                var hiddenItem: AvatarGalleryEntry?
                if let index = index {
                    hiddenItem = strongSelf.entries[index]
                    
                    if let node = strongSelf.galleryNode.pager.centralItemNode() {
                        strongSelf.centralItemTitle.set(node.title())
                        strongSelf.centralItemTitleView.set(node.titleView())
                        strongSelf.centralItemNavigationStyle.set(node.navigationStyle())
                        strongSelf.centralItemFooterContentNode.set(node.footerContent())
                    }
                }
                if strongSelf.didSetReady {
                    strongSelf._hiddenMedia.set(.single(hiddenItem))
                }
            }
        }
        
        let ready = self.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak self] _ in
            self?.didSetReady = true
        }
        self._ready.set(ready |> map { true })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleView.set(centralItemNode.titleView())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            
            if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]) {
                nodeAnimatesItself = true
                centralItemNode.animateIn(from: transitionArguments.transitionNode)
                
                self._hiddenMedia.set(.single(self.entries[centralItemNode.index]))
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
