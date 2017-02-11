import Foundation
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore

public class ComposeController: ViewController {
    private let account: Account
    
    private var contactsNode: ComposeControllerNode {
        return self.displayNode as! ComposeControllerNode
    }
    
    private let index: PeerNameIndex = .lastNameFirst
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let createActionDisposable = MetaDisposable()
    
    public init(account: Account) {
        self.account = account
        
        super.init()
        
        self.title = "Mew Message"
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.contactsNode.contactListNode.scrollToTop()
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.createActionDisposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ComposeControllerNode(account: self.account)
        self._ready.set(self.contactsNode.contactListNode.ready)
        
        self.contactsNode.navigationBar = self.navigationBar
        
        self.contactsNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.contactsNode.requestOpenPeerFromSearch = { [weak self] peerId in
            self?.openPeer(peerId: peerId)
        }
        
        self.contactsNode.contactListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.contactsNode.contactListNode.openPeer = { [weak self] peer in
            self?.openPeer(peerId: peer.id)
        }

        self.contactsNode.openCreateNewGroup = { [weak self] in
            if let strongSelf = self {
                let controller = ContactMultiselectionController(account: strongSelf.account, mode: .groupCreation)
                (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
                strongSelf.createActionDisposable.set((controller.result
                    |> deliverOnMainQueue).start(next: { [weak controller] peerIds in
                        if let strongSelf = self, let controller = controller {
                            let createGroup = createGroupController(account: strongSelf.account, peerIds: peerIds)
                            (controller.navigationController as? NavigationController)?.pushViewController(createGroup)
                        }
                    }))
            }
        }
        
        self.contactsNode.openCreateNewSecretChat = { [weak self] in
            if let strongSelf = self {
                let controller = ContactSelectionController(account: strongSelf.account, title: "New Secret Chat")
                (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = true
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = false
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.contactsNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.contactsNode.deactivateSearch()
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func openPeer(peerId: PeerId) {
        (self.navigationController as? NavigationController)?.replaceTopController(ChatController(account: self.account, peerId: peerId), animated: true)
    }
}
