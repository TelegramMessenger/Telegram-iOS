import UIKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

public class ChatListController: TelegramController {
    private let account: Account
    
    let openMessageFromSearchDisposable: MetaDisposable = MetaDisposable()
    
    private var chatListDisplayNode: ChatListControllerNode {
        return super.displayNode as! ChatListControllerNode
    }
    
    private let titleView: NetworkStatusTitleView
    private var titleDisposable: Disposable?
    private var badgeDisposable: Disposable?
    
    public override init(account: Account) {
        self.account = account
        
        self.titleView = NetworkStatusTitleView()
        
        super.init(account: account)
        
        self.navigationBar.item = nil
        
        self.titleView.title = NetworkStatusTitle(text: "Chats", activity: false)
        self.navigationItem.titleView = self.titleView
        self.tabBarItem.title = "Chats"
        self.tabBarItem.image = UIImage(bundleImageName: "Chat List/Tabs/IconChats")
        self.tabBarItem.selectedImage = UIImage(bundleImageName: "Chat List/Tabs/IconChatsSelected")
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(self.editPressed))
        //self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Compose, target: self, action: Selector("composePressed"))
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.chatListDisplayNode.chatListNode.scrollToLatest()
            }
        }
        
        self.titleDisposable = (account.networkState |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                switch state {
                    case .waitingForNetwork:
                        strongSelf.titleView.title = NetworkStatusTitle(text: "Waiting For Network...", activity: true)
                    case .connecting:
                        strongSelf.titleView.title = NetworkStatusTitle(text: "Connecting...", activity: true)
                    case .updating:
                        strongSelf.titleView.title = NetworkStatusTitle(text: "Updating...", activity: true)
                    case .online:
                        strongSelf.titleView.title = NetworkStatusTitle(text: "Chats", activity: false)
                }
            }
        })
        
        self.badgeDisposable = (account.postbox.unreadMessageCountsView(items: [.total]) |> deliverOnMainQueue).start(next: { [weak self] view in
            if let strongSelf = self {
                var count: Int32 = 0
                if let total = view.count(for: .total) {
                    count = total
                }
                if count == 0 {
                    strongSelf.tabBarItem.badgeValue = ""
                } else {
                    if count > 1000 && false {
                        strongSelf.tabBarItem.badgeValue = "\(count / 1000)K"
                    } else {
                        strongSelf.tabBarItem.badgeValue = "\(count)"
                    }
                }
            }
        })
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.openMessageFromSearchDisposable.dispose()
        self.titleDisposable?.dispose()
        self.badgeDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatListControllerNode(account: self.account)
        
        self.chatListDisplayNode.navigationBar = self.navigationBar
        
        self.chatListDisplayNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.chatListDisplayNode.chatListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.chatListDisplayNode.chatListNode.peerSelected = { [weak self] peerId in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peerId))
                strongSelf.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
            }
        }
        
        self.chatListDisplayNode.requestOpenMessageFromSearch = { [weak self] peer, messageId in
            if let strongSelf = self {
                strongSelf.openMessageFromSearchDisposable.set((storedMessageFromSearchPeer(account: strongSelf.account, peer: peer) |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: messageId.peerId, messageId: messageId))
                    }
                }))
            }
        }
        
        self.chatListDisplayNode.requestOpenPeerFromSearch = { [weak self] peer in
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
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peer.id))
                    }
                }))
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.chatListDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func editPressed() {
        
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.chatListDisplayNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.chatListDisplayNode.deactivateSearch()
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
}

