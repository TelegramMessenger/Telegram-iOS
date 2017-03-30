import UIKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

private let composeButtonImage = generateImage(CGSize(width: 24.0, height: 24.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setFillColor(UIColor(0x007ee5).cgColor)
    try? drawSvgPath(context, path: "M0,4 L15,4 L14,5 L1,5 L1,22 L18,22 L18,9 L19,8 L19,23 L0,23 L0,4 Z M18.5944456,1.70209754 L19.5995507,2.70718758 L10.0510517,12.255543 L9.54849908,13.7631781 L11.0561568,13.2606331 L20.6046559,3.71227763 L21.6097611,4.71736767 L11.5587094,14.7682681 L7.53828874,15.7733582 L9.04594649,11.250453 L18.5944456,1.70209754 Z M19.0969982,1.19955251 L20.0773504,0.21921503 C20.3690844,-0.0725145755 20.8398084,-0.0729335627 21.1298838,0.217137419 L23.0947435,2.18196761 C23.3833646,2.47058439 23.3838887,2.94326675 23.0926659,3.23448517 L22.1123136,4.21482265 L19.0969982,1.19955251 Z ")
})

public class ChatListController: TelegramController, UIViewControllerPreviewingDelegate {
    private let account: Account
    
    let openMessageFromSearchDisposable: MetaDisposable = MetaDisposable()
    
    private var chatListDisplayNode: ChatListControllerNode {
        return super.displayNode as! ChatListControllerNode
    }
    
    private let titleView: NetworkStatusTitleView
    private var titleDisposable: Disposable?
    private var badgeDisposable: Disposable?
    
    private var dismissSearchOnDisappear = false
    
    private var didSetup3dTouch = false
    
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
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: composeButtonImage, style: .plain, target: self, action: #selector(self.composePressed))
        
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
            self?.deactivateSearch(animated: true)
        }
        
        self.chatListDisplayNode.chatListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.chatListDisplayNode.chatListNode.deletePeerChat = { [weak self] peerId in
            if let strongSelf = self {
                let actionSheet = ActionSheetController()
                actionSheet.setItemGroups([ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Delete", color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        if let strongSelf = self {
                            let _ = removePeerChat(postbox: strongSelf.account.postbox, peerId: peerId, reportChatSpam: false).start()
                        }
                    })
                ]), ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Cancel", color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                })
                ])])
                strongSelf.present(actionSheet, in: .window)
            }
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
                        updatePeers(modifier: modifier, peers: [peer], update: { previousPeer, updatedPeer in
                            return updatedPeer
                        })
                    }
                }
                strongSelf.openMessageFromSearchDisposable.set((storedPeer |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        strongSelf.dismissSearchOnDisappear = true
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(ChatController(account: strongSelf.account, peerId: peer.id))
                    }
                }))
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didSetup3dTouch {
            self.didSetup3dTouch = true
            if #available(iOSApplicationExtension 9.0, *) {
                self.registerForPreviewing(with: self, sourceView: self.view)
            }
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if self.dismissSearchOnDisappear {
            self.dismissSearchOnDisappear = false
            self.deactivateSearch(animated: false)
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.chatListDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func editPressed() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(self.donePressed))
        self.chatListDisplayNode.chatListNode.updateState { state in
            return state.withUpdatedEditing(true)
        }
    }
    
    @objc func donePressed() {
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(self.editPressed))
        self.chatListDisplayNode.chatListNode.updateState { state in
            return state.withUpdatedEditing(false).withUpdatedPeerIdWithRevealedOptions(nil)
        }
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
    
    private func deactivateSearch(animated: Bool) {
        if !self.displayNavigationBar {
            self.chatListDisplayNode.deactivateSearch(animated: animated)
            self.setDisplayNavigationBar(true, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate)
        }
    }
    
    @objc func composePressed() {
        (self.navigationController as? NavigationController)?.pushViewController(ComposeController(account: self.account))
    }
    
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        if let searchController = self.chatListDisplayNode.searchDisplayController {
            if let (view, action) = searchController.previewViewAndActionAtLocation(location) {
                if let peerId = action as? PeerId {
                    if #available(iOSApplicationExtension 9.0, *) {
                        var sourceRect = view.superview!.convert(view.frame, to: self.view)
                        sourceRect.size.height -= UIScreenPixel
                        previewingContext.sourceRect = sourceRect
                    }
                    
                    let chatController = ChatController(account: self.account, peerId: peerId)
                    chatController.canReadHistory.set(false)
                    chatController.containerLayoutUpdated(ContainerViewLayout(size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height - (self.view.bounds.size.height > self.view.bounds.size.width ? 50.0 : 10.0)), intrinsicInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil), transition: .immediate)
                    return chatController
                } else if let messageId = action as? MessageId {
                    if #available(iOSApplicationExtension 9.0, *) {
                        var sourceRect = view.superview!.convert(view.frame, to: self.view)
                        sourceRect.size.height -= UIScreenPixel
                        previewingContext.sourceRect = sourceRect
                    }
                    
                    let chatController = ChatController(account: self.account, peerId: messageId.peerId, messageId: messageId)
                    chatController.canReadHistory.set(false)
                    chatController.containerLayoutUpdated(ContainerViewLayout(size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height - (self.view.bounds.size.height > self.view.bounds.size.width ? 50.0 : 10.0)), intrinsicInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil), transition: .immediate)
                    return chatController
                }
            }
            return nil
        }
        
        let listLocation = self.view.convert(location, to: self.chatListDisplayNode.chatListNode.view)
        
        var selectedNode: ChatListItemNode?
        self.chatListDisplayNode.chatListNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ChatListItemNode, itemNode.frame.contains(listLocation) {
                selectedNode = itemNode
            }
        }
        if let selectedNode = selectedNode, let item = selectedNode.item {
            if #available(iOSApplicationExtension 9.0, *) {
                var sourceRect = selectedNode.view.superview!.convert(selectedNode.frame, to: self.view)
                sourceRect.size.height -= UIScreenPixel
                previewingContext.sourceRect = sourceRect
            }
            let chatController = ChatController(account: self.account, peerId: item.peer.peerId)
            chatController.canReadHistory.set(false)
            chatController.containerLayoutUpdated(ContainerViewLayout(size: CGSize(width: self.view.bounds.size.width, height: self.view.bounds.size.height - (self.view.bounds.size.height > self.view.bounds.size.width ? 50.0 : 10.0)), intrinsicInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil), transition: .immediate)
            return chatController
        } else {
            return nil
        }
    }
    
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        if let viewControllerToCommit = viewControllerToCommit as? ViewController {
            if let chatController = viewControllerToCommit as? ChatController {
                chatController.canReadHistory.set(true)
            }
            (self.navigationController as? NavigationController)?.pushViewController(viewControllerToCommit, animated: false)
        }
    }
}

