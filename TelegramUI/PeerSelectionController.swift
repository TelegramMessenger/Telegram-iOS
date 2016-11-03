import Foundation
import SwiftSignalKit
import Display
import TelegramCore
import Postbox

public final class PeerSelectionController: ViewController {
    private let account: Account
    
    var peerSelected: ((PeerId) -> Void)?
    
    private var peerSelectionNode: PeerSelectionControllerNode {
        return super.displayNode as! PeerSelectionControllerNode
    }
    
    let openMessageFromSearchDisposable: MetaDisposable = MetaDisposable()
    
    public init(account: Account) {
        self.account = account
        
        super.init()
        
        self.title = "Forward"
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(self.cancelPressed))
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.peerSelectionNode.chatListNode.scrollToLatest()
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.openMessageFromSearchDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PeerSelectionControllerNode(account: self.account, dismiss: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
        self.displayNode.backgroundColor = .white
        
        self.peerSelectionNode.navigationBar = self.navigationBar
        
        self.peerSelectionNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.peerSelectionNode.chatListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.peerSelectionNode.chatListNode.peerSelected = { [weak self] peerId in
            if let strongSelf = self, let peerSelected = strongSelf.peerSelected {
                peerSelected(peerId)
            }
        }
        
        self.peerSelectionNode.requestOpenMessageFromSearch = { [weak self] peer, messageId in
            if let strongSelf = self {
                let storedPeer = strongSelf.account.postbox.modify { modifier -> Void in
                    if modifier.getPeer(peer.id) == nil {
                        modifier.updatePeers([peer], update: { previousPeer, updatedPeer in
                            return updatedPeer
                        })
                    }
                }
                strongSelf.openMessageFromSearchDisposable.set((storedPeer |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: messageId.peerId, messageId: messageId))
                    }
                }))
            }
        }
        
        self.peerSelectionNode.requestOpenPeerFromSearch = { [weak self] peerId in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peerId))
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.peerSelectionNode.animateIn()
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.peerSelectionNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationBar.frame.maxY, transition: transition)
    }
    
    @objc func cancelPressed() {
        self.dismiss()
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.peerSelectionNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.peerSelectionNode.deactivateSearch()
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    public func dismiss() {
        self.peerSelectionNode.animateOut()
    }
}
