import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import MapResourceToAvatarSizes
import TelegramPresentationData
import Postbox

private final class BookmarksLauncherController: ViewController {
    private let context: AccountContext
    private var didLaunch = false
    
    init(context: AccountContext) {
        self.context = context
        super.init(navigationBarPresentationData: nil)
        self.navigationPresentation = .modal
        self.statusBar.statusBarStyle = .Ignore
        self.title = nil
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.didLaunch { return }
        self.didLaunch = true
        self.ensureAndOpenBookmarks()
    }
    
    private func ensureAndOpenBookmarks() {
        let context = self.context
        let resolve: Signal<EnginePeer?, NoError> = resolveOrCreateBookmarksPeer(context: context)
        
        let _ : Disposable = (resolve
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let self else { return }
            if let peer, let navigationController = self.navigationController as? NavigationController {
                // Зафиксируем отображение как Messages
                let _ = self.context.engine.peers.updateForumViewAsMessages(peerId: peer.id, value: true).startStandalone()
                self.context.sharedContext.navigateToChatController(
                    NavigateToChatControllerParams(
                        navigationController: navigationController,
                        context: self.context,
                        chatLocation: .peer(peer),
                        keepStack: .always
                    )
                )
            }
            // This launcher controller can be removed from the stack
            if let navigationController = self.navigationController as? NavigationController {
                var controllers = navigationController.viewControllers
                controllers = controllers.filter { $0 !== self }
                navigationController.setViewControllers(controllers, animated: false)
            }
        })
    }
}

// MARK: - Helpers (strongly typed to avoid inference issues)

private func resolveOrCreateBookmarksPeer(context: AccountContext) -> Signal<EnginePeer?, NoError> {
    let presentationData: PresentationData = context.sharedContext.currentPresentationData.with { $0 }
    let search: Signal<[EngineRenderedPeer], NoError> = context.engine.contacts.searchLocalPeers(query: "Bookmarks")

    let found: Signal<EnginePeer?, NoError> = (search
    |> take(1)
    |> map { (peers: [EngineRenderedPeer]) -> EnginePeer? in
        for rendered in peers {
            if let peer = rendered.peer, case let .channel(channel) = peer, channel.isForum {
                if peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder) == "Bookmarks" {
                    return peer
                }
            }
        }
        return nil
    })

    return found
    |> mapToSignal { maybePeer -> Signal<EnginePeer?, NoError> in
        if let peer = maybePeer {
            // Ensure the Bookmarks group has the bookmarks icon as its avatar
            if let image = PresentationResourcesSettings.bookmarks, let data = image.jpegData(compressionQuality: 0.9) {
                let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                context.account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                let _ = (context.engine.peers.updatePeerPhoto(
                    peerId: peer.id,
                    photo: context.engine.peers.uploadedPeerPhoto(resource: resource),
                    mapResourceToAvatarSizes: { res, reps in
                        return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: res, representations: reps)
                    }
                )
                |> deliverOnMainQueue).startStandalone()
            }
            return Signal<EnginePeer?, NoError>.single(peer)
        } else {
            return createBookmarksPeer(context: context)
        }
    }
}

private func createBookmarksPeer(context: AccountContext) -> Signal<EnginePeer?, NoError> {
    // 1) Create forum supergroup → PeerId?, NoError
    let createdId: Signal<PeerId?, NoError> = (context.engine.peers.createSupergroup(
        title: "Bookmarks",
        description: "",
        isForum: true,
        ttlPeriod: nil
    )
    |> map(Optional.init)
    |> `catch` { _ -> Signal<PeerId?, NoError> in
        return .single(nil)
    })

    // 2) Resolve EnginePeer from id; set avatar; return EnginePeer?, NoError
    return createdId
    |> mapToSignal { (peerIdOpt: PeerId?) -> Signal<EnginePeer?, NoError> in
        guard let peerId = peerIdOpt else {
            return .single(nil)
        }
        return (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        |> take(1))
        |> mapToSignal { (peerOpt: EnginePeer?) -> Signal<EnginePeer?, NoError> in
            if let peer = peerOpt, case let .channel(channel) = peer, channel.isForum {
                if let image = PresentationResourcesSettings.bookmarks, let data = image.jpegData(compressionQuality: 0.9) {
                    let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                    context.account.postbox.mediaBox.storeResourceData(resource.id, data: data, synchronous: true)
                    let _ = (context.engine.peers.updatePeerPhoto(
                        peerId: peer.id,
                        photo: context.engine.peers.uploadedPeerPhoto(resource: resource),
                        mapResourceToAvatarSizes: { res, reps in
                            return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: res, representations: reps)
                        }
                    )
                    |> deliverOnMainQueue).startStandalone()
                }
                // View as Messages (и запретим пользователю переключать меню далее)
                let _ = context.engine.peers.setChannelForumMode(id: peer.id, isForum: true, displayForumAsTabs: true).startStandalone()
                let _ = context.engine.peers.updateForumViewAsMessages(peerId: peer.id, value: true).startStandalone()
            }
            return .single(peerOpt)
        }
    }
}

public func bookmarksController(context: AccountContext) -> ViewController {
    return BookmarksLauncherController(context: context)
}
