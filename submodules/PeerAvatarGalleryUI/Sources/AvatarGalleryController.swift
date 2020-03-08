import Foundation
import UIKit
import Display
import QuickLook
import Postbox
import SwiftSignalKit
import AsyncDisplayKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import AccountContext
import GalleryUI

public enum AvatarGalleryEntryId: Hashable {
    case topImage
    case image(MediaId)
}

public enum AvatarGalleryEntry: Equatable {
    case topImage([ImageRepresentationWithReference], GalleryItemIndexData?)
    case image(MediaId, TelegramMediaImageReference?, [ImageRepresentationWithReference], Peer?, Int32, GalleryItemIndexData?, MessageId?)
    
    public var id: AvatarGalleryEntryId {
        switch self {
        case .topImage:
            return .topImage
        case let .image(image):
            return .image(image.0)
        }
    }
    
    public var representations: [ImageRepresentationWithReference] {
        switch self {
            case let .topImage(representations, _):
                return representations
            case let .image(_, _, representations, _, _, _, _):
                return representations
        }
    }
    
    public var indexData: GalleryItemIndexData? {
        switch self {
            case let .topImage(_, indexData):
                return indexData
            case let .image(_, _, _, _, _, indexData, _):
                return indexData
        }
    }
    
    public static func ==(lhs: AvatarGalleryEntry, rhs: AvatarGalleryEntry) -> Bool {
        switch lhs {
            case let .topImage(lhsRepresentations, lhsIndexData):
                if case let .topImage(rhsRepresentations, rhsIndexData) = rhs, lhsRepresentations == rhsRepresentations, lhsIndexData == rhsIndexData {
                    return true
                } else {
                    return false
                }
            case let .image(lhsId, lhsImageReference, lhsRepresentations, lhsPeer, lhsDate, lhsIndexData, lhsMessageId):
                if case let .image(rhsId, rhsImageReference, rhsRepresentations, rhsPeer, rhsDate, rhsIndexData, rhsMessageId) = rhs, lhsId == rhsId, lhsImageReference == rhsImageReference, lhsRepresentations == rhsRepresentations, arePeersEqual(lhsPeer, rhsPeer), lhsDate == rhsDate, lhsIndexData == rhsIndexData, lhsMessageId == rhsMessageId {
                    return true
                } else {
                    return false
                }
        }
    }
}

public final class AvatarGalleryControllerPresentationArguments {
    let animated: Bool
    let transitionArguments: (AvatarGalleryEntry) -> GalleryTransitionArguments?
    
    public init(animated: Bool = true, transitionArguments: @escaping (AvatarGalleryEntry) -> GalleryTransitionArguments?) {
        self.animated = animated
        self.transitionArguments = transitionArguments
    }
}

public func initialAvatarGalleryEntries(peer: Peer) -> [AvatarGalleryEntry] {
    var initialEntries: [AvatarGalleryEntry] = []
    if !peer.profileImageRepresentations.isEmpty, let peerReference = PeerReference(peer) {
        initialEntries.append(.topImage(peer.profileImageRepresentations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.avatar(peer: peerReference, resource: $0.resource)) }), nil))
    }
    return initialEntries
}

public func fetchedAvatarGalleryEntries(account: Account, peer: Peer) -> Signal<[AvatarGalleryEntry], NoError> {
    let initialEntries = initialAvatarGalleryEntries(peer: peer)
    return Signal<[AvatarGalleryEntry], NoError>.single(initialEntries)
    |> then(
        requestPeerPhotos(account: account, peerId: peer.id)
        |> map { photos -> [AvatarGalleryEntry] in
            var result: [AvatarGalleryEntry] = []
            let initialEntries = initialAvatarGalleryEntries(peer: peer)
            if photos.isEmpty {
                result = initialEntries
            } else {
                var index: Int32 = 0
                for photo in photos {
                    let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photos.count))
                    if result.isEmpty, let first = initialEntries.first {
                        result.append(.image(photo.image.imageId, photo.image.reference, first.representations, peer, photo.date, indexData, photo.messageId))
                    } else {
                        result.append(.image(photo.image.imageId, photo.image.reference, photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.standalone(resource: $0.resource)) }), peer, photo.date, indexData, photo.messageId))
                    }
                    index += 1
                }
            }
            return result
        }
    )
}

public func fetchedAvatarGalleryEntries(account: Account, peer: Peer, firstEntry: AvatarGalleryEntry) -> Signal<[AvatarGalleryEntry], NoError> {
    let initialEntries = [firstEntry]
    return Signal<[AvatarGalleryEntry], NoError>.single(initialEntries)
    |> then(
        requestPeerPhotos(account: account, peerId: peer.id)
        |> map { photos -> [AvatarGalleryEntry] in
            var result: [AvatarGalleryEntry] = []
            let initialEntries = [firstEntry]
            if photos.isEmpty {
                result = initialEntries
            } else {
                var index: Int32 = 0
                for photo in photos {
                    let indexData = GalleryItemIndexData(position: index, totalCount: Int32(photos.count))
                    if result.isEmpty, let first = initialEntries.first {
                        result.append(.image(photo.image.imageId, photo.image.reference, first.representations, peer, photo.date, indexData, photo.messageId))
                    } else {
                        result.append(.image(photo.image.imageId, photo.image.reference, photo.image.representations.map({ ImageRepresentationWithReference(representation: $0, reference: MediaResourceReference.standalone(resource: $0.resource)) }), peer, photo.date, indexData, photo.messageId))
                    }
                    index += 1
                }
            }
            return result
        }
    )
}

public class AvatarGalleryController: ViewController, StandalonePresentableController {
    private var galleryNode: GalleryControllerNode {
        return self.displayNode as! GalleryControllerNode
    }
    
    private let context: AccountContext
    private let peer: Peer
    private let sourceHasRoundCorners: Bool
    
    private var presentationData: PresentationData
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private var adjustedForInitialPreviewingLayout = false
    
    private let disposable = MetaDisposable()
    
    private var entries: [AvatarGalleryEntry] = []
    private var centralEntryIndex: Int?
    
    private let centralItemTitle = Promise<String>()
    private let centralItemTitleView = Promise<UIView?>()
    private let centralItemNavigationStyle = Promise<GalleryItemNodeNavigationStyle>()
    private let centralItemFooterContentNode = Promise<(GalleryFooterContentNode?, GalleryOverlayContentNode?)>()
    private let centralItemAttributesDisposable = DisposableSet();
    
    private let _hiddenMedia = Promise<AvatarGalleryEntry?>(nil)
    public var hiddenMedia: Signal<AvatarGalleryEntry?, NoError> {
        return self._hiddenMedia.get()
    }
    
    private let replaceRootController: (ViewController, ValuePromise<Bool>?) -> Void
    
    public init(context: AccountContext, peer: Peer, sourceHasRoundCorners: Bool = true, remoteEntries: Promise<[AvatarGalleryEntry]>? = nil, centralEntryIndex: Int? = nil, replaceRootController: @escaping (ViewController, ValuePromise<Bool>?) -> Void, synchronousLoad: Bool = false) {
        self.context = context
        self.peer = peer
        self.sourceHasRoundCorners = sourceHasRoundCorners
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.replaceRootController = replaceRootController
        
        self.centralEntryIndex = centralEntryIndex
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: GalleryController.darkNavigationTheme, strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        let backItem = UIBarButtonItem(backButtonAppearanceWithTitle: self.presentationData.strings.Common_Back, target: self, action: #selector(self.donePressed))
        self.navigationItem.leftBarButtonItem = backItem
        
        self.statusBar.statusBarStyle = .White
        
        let remoteEntriesSignal: Signal<[AvatarGalleryEntry], NoError>
        if let remoteEntries = remoteEntries {
            remoteEntriesSignal = remoteEntries.get()
        } else {
            remoteEntriesSignal = fetchedAvatarGalleryEntries(account: context.account, peer: peer)
        }
        
        let entriesSignal: Signal<[AvatarGalleryEntry], NoError> = .single(initialAvatarGalleryEntries(peer: peer)) |> then(remoteEntriesSignal)
        
        let presentationData = self.presentationData
        
        let semaphore: DispatchSemaphore?
        if synchronousLoad {
            semaphore = DispatchSemaphore(value: 0)
        } else {
            semaphore = nil
        }
        
        let syncResult = Atomic<(Bool, (() -> Void)?)>(value: (false, nil))
        
        self.disposable.set(entriesSignal.start(next: { [weak self] entries in
            let f: () -> Void = {
                if let strongSelf = self {
                    strongSelf.entries = entries
                    if strongSelf.centralEntryIndex == nil {
                        strongSelf.centralEntryIndex = 0
                    }
                    if strongSelf.isViewLoaded {
                        let canDelete: Bool
                        if strongSelf.peer.id == strongSelf.context.account.peerId {
                            canDelete = true
                        } else if let group = strongSelf.peer as? TelegramGroup {
                            switch group.role {
                                case .creator, .admin:
                                    canDelete = true
                                case .member:
                                    canDelete = false
                            }
                        } else if let channel = strongSelf.peer as? TelegramChannel {
                            canDelete = channel.hasPermission(.changeInfo)
                        } else {
                            canDelete = false
                        }
                        strongSelf.galleryNode.pager.replaceItems(strongSelf.entries.map({ entry in PeerAvatarImageGalleryItem(context: context, peer: peer, presentationData: presentationData, entry: entry, sourceHasRoundCorners: sourceHasRoundCorners, delete: canDelete ? {
                            self?.deleteEntry(entry)
                            } : nil) }), centralItemIndex: 0, keepFirst: true)
                        
                        let ready = strongSelf.galleryNode.pager.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void())) |> afterNext { [weak strongSelf] _ in
                            strongSelf?.didSetReady = true
                        }
                        strongSelf._ready.set(ready |> map { true })
                    }
                }
            }
            
            var process = false
            let _ = syncResult.modify { processed, _ in
                if !processed {
                    return (processed, f)
                }
                process = true
                return (true, nil)
            }
            semaphore?.signal()
            if process {
                Queue.mainQueue().async {
                    f()
                }
            }
        }))
        
        if let semaphore = semaphore {
            let _ = semaphore.wait(timeout: DispatchTime.now() + 1.0)
        }
        
        var syncResultApply: (() -> Void)?
        let _ = syncResult.modify { processed, f in
            syncResultApply = f
            return (true, nil)
        }
        
        syncResultApply?()
        
        self.centralItemAttributesDisposable.add(self.centralItemTitle.get().start(next: { [weak self] title in
            if let strongSelf = self {
                strongSelf.navigationItem.setTitle(title, animated: strongSelf.navigationItem.title?.isEmpty ?? true)
            }
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemTitleView.get().start(next: { [weak self] titleView in
            self?.navigationItem.titleView = titleView
        }))
        
        self.centralItemAttributesDisposable.add(self.centralItemFooterContentNode.get().start(next: { [weak self] footerContentNode, _ in
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
                if (centralItemNode.index == 0 || !self.sourceHasRoundCorners), let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]), !forceAway {
                    animatedOutNode = false
                    centralItemNode.animateOut(to: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface, completion: {
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
    
    override public func loadDisplayNode() {
        let controllerInteraction = GalleryControllerInteraction(presentController: { [weak self] controller, arguments in
            if let strongSelf = self {
                strongSelf.present(controller, in: .window(.root), with: arguments, blockInteraction: true)
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
        
        self.galleryNode.transitionDataForCentralItem = { [weak self] in
            if let strongSelf = self {
                if let centralItemNode = strongSelf.galleryNode.pager.centralItemNode(), let presentationArguments = strongSelf.presentationArguments as? AvatarGalleryControllerPresentationArguments {
                    if centralItemNode.index != 0 && strongSelf.sourceHasRoundCorners {
                        return nil
                    }
                    if let transitionArguments = presentationArguments.transitionArguments(strongSelf.entries[centralItemNode.index]) {
                        return (transitionArguments.transitionNode, transitionArguments.addToTransitionSurface)
                    }
                }
            }
            return nil
        }
        self.galleryNode.dismiss = { [weak self] in
            self?._hiddenMedia.set(.single(nil))
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        let canDelete: Bool
        if self.peer.id == self.context.account.peerId {
            canDelete = true
        } else if let group = self.peer as? TelegramGroup {
            switch group.role {
            case .creator, .admin:
                canDelete = true
            case .member:
                canDelete = false
            }
        } else if let channel = self.peer as? TelegramChannel {
            canDelete = channel.hasPermission(.changeInfo)
        } else {
            canDelete = false
        }
        
        let presentationData = self.presentationData
        self.galleryNode.pager.replaceItems(self.entries.map({ entry in PeerAvatarImageGalleryItem(context: self.context, peer: peer, presentationData: presentationData, entry: entry, sourceHasRoundCorners: self.sourceHasRoundCorners, delete: canDelete ? { [weak self] in
            self?.deleteEntry(entry)
            } : nil) }), centralItemIndex: self.centralEntryIndex)
        
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
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        var nodeAnimatesItself = false
        
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
            self.centralItemTitle.set(centralItemNode.title())
            self.centralItemTitleView.set(centralItemNode.titleView())
            self.centralItemNavigationStyle.set(centralItemNode.navigationStyle())
            self.centralItemFooterContentNode.set(centralItemNode.footerContent())
            
            if let transitionArguments = presentationArguments.transitionArguments(self.entries[centralItemNode.index]) {
                nodeAnimatesItself = true
                if presentationArguments.animated {
                    centralItemNode.animateIn(from: transitionArguments.transitionNode, addToTransitionSurface: transitionArguments.addToTransitionSurface)
                }
                
                self._hiddenMedia.set(.single(self.entries[centralItemNode.index]))
            }
        }
        
        if !self.isPresentedInPreviewingContext() {
            self.galleryNode.setControlsHidden(false, animated: false)
            if let presentationArguments = self.presentationArguments as? AvatarGalleryControllerPresentationArguments {
                if presentationArguments.animated {
                    self.galleryNode.animateIn(animateContent: !nodeAnimatesItself)
                }
            }
        }
    }
    
    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        if let centralItemNode = self.galleryNode.pager.centralItemNode(), let itemSize = centralItemNode.contentSize() {
            return itemSize.aspectFitted(layout.size)
        } else {
            return nil
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.galleryNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.galleryNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
        
        if !self.adjustedForInitialPreviewingLayout && self.isPresentedInPreviewingContext() {
            self.adjustedForInitialPreviewingLayout = true
            self.galleryNode.setControlsHidden(true, animated: false)
            if let centralItemNode = self.galleryNode.pager.centralItemNode(), let itemSize = centralItemNode.contentSize() {
                self.preferredContentSize = itemSize.aspectFitted(self.view.bounds.size)
                self.containerLayoutUpdated(ContainerViewLayout(size: self.preferredContentSize, metrics: LayoutMetrics(), deviceMetrics: layout.deviceMetrics, intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
                centralItemNode.activateAsInitial()
            }
        }
    }
    
    private func deleteEntry(_ rawEntry: AvatarGalleryEntry) {
        var entry = rawEntry
        if case .topImage = entry, !self.entries.isEmpty {
            entry = self.entries[0]
        }
        
        switch entry {
            case .topImage:
                if self.peer.id == self.context.account.peerId {
                } else {
                    if entry == self.entries.first {
                        let _ = updatePeerPhoto(postbox: self.context.account.postbox, network: self.context.account.network, stateManager: self.context.account.stateManager, accountPeerId: self.context.account.peerId, peerId: self.peer.id, photo: nil, mapResourceToAvatarSizes: { _, _ in .single([:]) }).start()
                        self.dismiss(forceAway: true)
                    } else {
                        if let index = self.entries.firstIndex(of: entry) {
                            self.entries.remove(at: index)
                            self.galleryNode.pager.transaction(GalleryPagerTransaction(deleteItems: [index], insertItems: [], updateItems: [], focusOnItem: index - 1))
                        }
                    }
                }
            case let .image(_, reference, _, _, _, _, messageId):
                if self.peer.id == self.context.account.peerId {
                    if let reference = reference {
                        let _ = removeAccountPhoto(network: self.context.account.network, reference: reference).start()
                    }
                    if entry == self.entries.first {
                        self.dismiss(forceAway: true)
                    } else {
                        if let index = self.entries.firstIndex(of: entry) {
                            self.entries.remove(at: index)
                            self.galleryNode.pager.transaction(GalleryPagerTransaction(deleteItems: [index], insertItems: [], updateItems: [], focusOnItem: index - 1))
                        }
                    }
                } else {
                    if let messageId = messageId {
                        let _ = deleteMessagesInteractively(account: self.context.account, messageIds: [messageId], type: .forEveryone).start()
                    }
                    
                    if entry == self.entries.first {
                        let _ = updatePeerPhoto(postbox: self.context.account.postbox, network: self.context.account.network, stateManager: self.context.account.stateManager, accountPeerId: self.context.account.peerId, peerId: self.peer.id, photo: nil, mapResourceToAvatarSizes: { _, _ in .single([:]) }).start()
                        self.dismiss(forceAway: true)
                    } else {
                        if let index = self.entries.firstIndex(of: entry) {
                            self.entries.remove(at: index)
                            self.galleryNode.pager.transaction(GalleryPagerTransaction(deleteItems: [index], insertItems: [], updateItems: [], focusOnItem: index - 1))
                        }
                    }
                }
        }
    }
}
