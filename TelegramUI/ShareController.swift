import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

private func canSendMessagesToPeer(_ peer: Peer) -> Bool {
    if peer is TelegramUser || peer is TelegramGroup {
        return true
    } else if let peer = peer as? TelegramSecretChat {
        return peer.embeddedState == .active
    } else if let peer = peer as? TelegramChannel {
        switch peer.info {
            case .broadcast:
                return peer.hasAdminRights(.canPostMessages)
            case .group:
                return true
        }
    } else {
        return false
    }
}

public struct ShareControllerAction {
    let title: String
    let action: () -> Void
}

public final class ShareController: ViewController {
    private var controllerNode: ShareControllerNode {
        return self.displayNode as! ShareControllerNode
    }
    
    private var animatedIn = false
    
    private let account: Account
    private let peers = Promise<[Peer]>()
    private let peersDisposable = MetaDisposable()
    
    private let shareAction: ([PeerId]) -> Void
    private let defaultAction: ShareControllerAction?
    
    public var dismissed: (() -> Void)?
    
    public init(account: Account, shareAction: @escaping ([PeerId]) -> Void, defaultAction: ShareControllerAction?) {
        self.account = account
        self.shareAction = shareAction
        self.defaultAction = defaultAction
        
        super.init(navigationBarTheme: nil)
        
        self.peers.set(account.postbox.tailChatListView(100) |> take(1) |> map { view -> [Peer] in
            var peers: [Peer] = []
            for entry in view.0.entries.reversed() {
                switch entry {
                    case let .MessageEntry(_, message, _, _, _, renderedPeer):
                        if let message = message {
                            if let peer = message.peers[message.id.peerId] {
                                if canSendMessagesToPeer(peer) {
                                    peers.append(peer)
                                }
                            }
                        }
                    default:
                        break
                }
            }
            return peers
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.peersDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ShareControllerNode(account: self.account)
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            self?.dismissed?()
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.share = { [weak self] peerIds in
            self?.shareAction(peerIds)
        }
        self.displayNodeDidLoad()
        self.peersDisposable.set((self.peers.get() |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                strongSelf.controllerNode.updatePeers(peers: next, defaultAction: strongSelf.defaultAction)
            }
        }))
        self.ready.set(self.controllerNode.ready.get())
    }
    
    override public func loadView() {
        super.loadView()
        
        self.statusBar.removeFromSupernode()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
