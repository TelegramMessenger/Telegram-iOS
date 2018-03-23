import UIKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

public class ChatListController: TelegramController, UIViewControllerPreviewingDelegate {
    private let account: Account
    private let controlsHistoryPreload: Bool
    
    public let groupId: PeerGroupId?
    
    let openMessageFromSearchDisposable: MetaDisposable = MetaDisposable()
    
    private var chatListDisplayNode: ChatListControllerNode {
        return super.displayNode as! ChatListControllerNode
    }
    
    private let titleView: NetworkStatusTitleView
    private var titleDisposable: Disposable?
    private var badgeDisposable: Disposable?
    
    private var dismissSearchOnDisappear = false
    
    private var didSetup3dTouch = false
    
    private let passcodeDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    public init(account: Account, groupId: PeerGroupId?, controlsHistoryPreload: Bool) {
        self.account = account
        self.controlsHistoryPreload = controlsHistoryPreload
        
        self.groupId = groupId
        
        self.presentationData = (account.telegramApplicationContext.currentPresentationData.with { $0 })
        
        self.titleView = NetworkStatusTitleView(theme: self.presentationData.theme)
        
        super.init(account: account, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), enableMediaAccessoryPanel: true, locationBroadcastPanelSource: .summary)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        if groupId == nil {
            self.navigationBar?.item = nil
        
            self.titleView.title = NetworkStatusTitle(text: self.presentationData.strings.DialogList_Title, activity: false)
            self.navigationItem.titleView = self.titleView
            self.tabBarItem.title = self.presentationData.strings.DialogList_Title
            self.tabBarItem.image = UIImage(bundleImageName: "Chat List/Tabs/IconChats")
            self.tabBarItem.selectedImage = UIImage(bundleImageName: "Chat List/Tabs/IconChats")
            
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationComposeIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.composePressed))
        } else {
            self.navigationItem.title = "Channels"
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        }
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.DialogList_Title, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.chatListDisplayNode.chatListNode.scrollToLatest()
            }
        }
        
        self.titleDisposable = (account.networkState |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                switch state {
                    case .waitingForNetwork:
                        strongSelf.titleView.title = NetworkStatusTitle(text: strongSelf.presentationData.strings.State_WaitingForNetwork, activity: true)
                    case let .connecting(toProxy):
                        strongSelf.titleView.title = NetworkStatusTitle(text: toProxy ? strongSelf.presentationData.strings.State_ConnectingToProxy : strongSelf.presentationData.strings.State_Connecting, activity: true)
                    case .updating:
                        strongSelf.titleView.title = NetworkStatusTitle(text: strongSelf.presentationData.strings.State_Updating, activity: true)
                    case .online:
                        strongSelf.titleView.title = NetworkStatusTitle(text: strongSelf.presentationData.strings.DialogList_Title, activity: false)
                }
            }
        })
        
        self.badgeDisposable = (renderedTotalUnreadCount(postbox: account.postbox) |> deliverOnMainQueue).start(next: { [weak self] count in
            if let strongSelf = self {
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
        
        self.passcodeDisposable.set((account.postbox.combinedView(keys: [.accessChallengeData]) |> deliverOnMainQueue).start(next: { [weak self] view in
            if let strongSelf = self {
                let data = (view.views[.accessChallengeData] as! AccessChallengeDataView).data
                strongSelf.titleView.updatePasscode(isPasscodeSet: data.isLockable, isManuallyLocked: data.autolockDeadline == 0)
            }
        }))
        
        self.titleView.toggleIsLocked = { [weak self] in
            if let strongSelf = self {
                let _ = strongSelf.account.postbox.modify({ modifier -> Void in
                    var data = modifier.getAccessChallengeData()
                    if data.isLockable {
                        if data.autolockDeadline != 0 {
                            data = data.withUpdatedAutolockDeadline(0)
                        } else {
                            data = data.withUpdatedAutolockDeadline(nil)
                        }
                        modifier.setAccessChallengeData(data)
                    }
                }).start()
            }
        }
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.updateThemeAndStrings()
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
        self.passcodeDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.tabBarItem.title = self.presentationData.strings.DialogList_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.DialogList_Title, style: .plain, target: nil, action: nil)
        var editing = false
        self.chatListDisplayNode.chatListNode.updateState { state in
            editing = state.editing
            return state
        }
        let editItem: UIBarButtonItem
        if editing {
            editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        } else {
            editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        }
        if self.groupId == nil {
            self.navigationItem.leftBarButtonItem = editItem
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationComposeIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.composePressed))
        } else {
            self.navigationItem.rightBarButtonItem = editItem
        }
        
        self.titleView.theme = self.presentationData.theme
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        if self.isNodeLoaded {
            self.chatListDisplayNode.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings, timeFormat: self.presentationData.timeFormat)
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatListControllerNode(account: self.account, groupId: self.groupId, controlsHistoryPreload: self.controlsHistoryPreload, theme: self.presentationData.theme, strings: self.presentationData.strings, timeFormat: self.presentationData.timeFormat)
        
        self.chatListDisplayNode.navigationBar = self.navigationBar
        
        self.chatListDisplayNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch(animated: true)
        }
        
        self.chatListDisplayNode.chatListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.chatListDisplayNode.chatListNode.presentAlert = { [weak self] text in
            if let strongSelf = self {
                self?.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }
        }
        
        self.chatListDisplayNode.chatListNode.deletePeerChat = { [weak self] peerId in
            if let strongSelf = self {
                let _ = (strongSelf.account.postbox.modify { modifier -> Peer? in
                    return modifier.getPeer(peerId)
                } |> deliverOnMainQueue).start(next: { peer in
                    if let strongSelf = self, let peer = peer {
                        let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                        var items: [ActionSheetItem] = []
                        var canClear = true
                        if let channel = peer as? TelegramChannel {
                            if case .broadcast = channel.info {
                                canClear = false
                            }
                            if let addressName = channel.addressName, !addressName.isEmpty {
                                canClear = false
                            }
                        }
                        if canClear {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.DialogList_ClearHistoryConfirmation, color: .accent, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                if let strongSelf = self {
                                    let _ = clearHistoryInteractively(postbox: strongSelf.account.postbox, peerId: peerId).start()
                                }
                            }))
                        }
                        
                        items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Delete, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            if let strongSelf = self {
                                let _ = removePeerChat(postbox: strongSelf.account.postbox, peerId: peerId, reportChatSpam: false).start()
                            }
                        }))
                        
                        actionSheet.setItemGroups([ActionSheetItemGroup(items: items),
                            ActionSheetItemGroup(items: [
                                ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                                    actionSheet?.dismissAnimated()
                                })
                            ])
                        ])
                        strongSelf.present(actionSheet, in: .window(.root))
                    }
                })
            }
        }
        
        self.chatListDisplayNode.chatListNode.peerSelected = { [weak self] peerId in
            if let strongSelf = self {
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(peerId))
                    strongSelf.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                }
            }
        }
        
        self.chatListDisplayNode.chatListNode.groupSelected = { [weak self] groupId in
            if let strongSelf = self {
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .group(groupId))
                    strongSelf.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                }
            }
        }
        
        self.chatListDisplayNode.chatListNode.updatePeerGrouping = { [weak self] peerId, group in
            if let strongSelf = self {
                let _ = updatePeerGroupIdInteractively(postbox: strongSelf.account.postbox, peerId: peerId, groupId: group ? Namespaces.PeerGroup.feed : nil).start()
            }
        }
        
        self.chatListDisplayNode.requestOpenMessageFromSearch = { [weak self] peer, messageId in
            if let strongSelf = self {
                strongSelf.openMessageFromSearchDisposable.set((storedMessageFromSearchPeer(account: strongSelf.account, peer: peer) |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        if let navigationController = strongSelf.navigationController as? NavigationController {
                            navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(messageId.peerId), messageId: messageId)
                            strongSelf.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                        }
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
                        if let navigationController = strongSelf.navigationController as? NavigationController {
                            navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(peer.id))
                            strongSelf.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                        }
                    }
                }))
            }
        }
        
        self.chatListDisplayNode.requestOpenRecentPeerOptions = { [weak self] peer in
            if let strongSelf = self {
                strongSelf.chatListDisplayNode.view.endEditing(true)
                let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Delete, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            if let strongSelf = self {
                                let _ = removeRecentPeer(account: strongSelf.account, peerId: peer.id).start()
                                let searchContainer = strongSelf.chatListDisplayNode.searchDisplayController?.contentNode as? ChatListSearchContainerNode
                                searchContainer?.removePeerFromTopPeers(peer.id)
                            }
                        })
                    ]),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                strongSelf.present(actionSheet, in: .window(.root))
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didSetup3dTouch {
            self.didSetup3dTouch = true
            if #available(iOSApplicationExtension 9.0, *) {
                self.registerForPreviewing(with: self, sourceView: self.view, theme: PeekControllerTheme(presentationTheme: self.presentationData.theme), onlyNative: false)
            }
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        if self.dismissSearchOnDisappear {
            self.dismissSearchOnDisappear = false
            self.deactivateSearch(animated: false)
        }
        
        self.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.chatListDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    override public func navigationStackConfigurationUpdated(next: [ViewController]) {
        super.navigationStackConfigurationUpdated(next: next)
        
        let chatLocation = (next.first as? ChatController)?.chatLocation
        
        self.chatListDisplayNode.chatListNode.updateSelectedChatLocation(chatLocation, progress: 1.0, transition: .immediate)
    }
    
    @objc func editPressed() {
        let editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        if self.groupId == nil {
            self.navigationItem.leftBarButtonItem = editItem
        } else {
            self.navigationItem.rightBarButtonItem = editItem
        }
        self.chatListDisplayNode.chatListNode.updateState { state in
            return state.withUpdatedEditing(true)
        }
    }
    
    @objc func donePressed() {
        let editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        if self.groupId == nil {
            self.navigationItem.leftBarButtonItem = editItem
        } else {
            self.navigationItem.rightBarButtonItem = editItem
        }
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
            self.setDisplayNavigationBar(true, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate)
            self.chatListDisplayNode.deactivateSearch(animated: animated)
        }
    }
    
    @objc func composePressed() {
        (self.navigationController as? NavigationController)?.replaceAllButRootController(ComposeController(account: self.account), animated: true)
    }
    
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        let boundsSize = self.view.bounds.size
        var contentSize = CGSize(width: boundsSize.width, height: boundsSize.height - (boundsSize.height > boundsSize.width ? 50.0 : 10.0))
        if (boundsSize.width.isEqual(to: 375.0) && boundsSize.height.isEqual(to: 812.0))  {
            contentSize.height -= 56.0
        } else if (boundsSize.height.isEqual(to: 375.0) && boundsSize.width.isEqual(to: 812.0)) {
            contentSize.height += 107.0
        }
        
        if let searchController = self.chatListDisplayNode.searchDisplayController {
            if let (view, action) = searchController.previewViewAndActionAtLocation(location) {
                if let peerId = action as? PeerId, peerId.namespace != Namespaces.Peer.SecretChat {
                    if #available(iOSApplicationExtension 9.0, *) {
                        var sourceRect = view.superview!.convert(view.frame, to: self.view)
                        sourceRect.size.height -= UIScreenPixel
                        previewingContext.sourceRect = sourceRect
                    }
                    
                    let chatController = ChatController(account: self.account, chatLocation: .peer(peerId), mode: .standard(previewing: true))
                    chatController.peekActions = .remove({ [weak self] in
                        if let strongSelf = self {
                            let _ = removeRecentPeer(account: strongSelf.account, peerId: peerId).start()
                            let searchContainer = strongSelf.chatListDisplayNode.searchDisplayController?.contentNode as? ChatListSearchContainerNode
                            searchContainer?.removePeerFromTopPeers(peerId)
                        }
                    })
                    chatController.canReadHistory.set(false)
                    chatController.containerLayoutUpdated(ContainerViewLayout(size: contentSize, metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false), transition: .immediate)
                    return chatController
                } else if let messageId = action as? MessageId, messageId.peerId.namespace != Namespaces.Peer.SecretChat {
                    if #available(iOSApplicationExtension 9.0, *) {
                        var sourceRect = view.superview!.convert(view.frame, to: self.view)
                        sourceRect.size.height -= UIScreenPixel
                        previewingContext.sourceRect = sourceRect
                    }
                    
                    let chatController = ChatController(account: self.account, chatLocation: .peer(messageId.peerId), messageId: messageId, mode: .standard(previewing: true))
                    chatController.canReadHistory.set(false)
                    chatController.containerLayoutUpdated(ContainerViewLayout(size: contentSize, metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false), transition: .immediate)
                    return chatController
                }
            }
            return nil
        }
        
        var isEditing = false
        self.chatListDisplayNode.chatListNode.updateState { state in
            isEditing = state.editing
            return state
        }
        
        if isEditing {
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
            switch item.content {
                case let .peer(_, peer, _, _, _, _, _):
                    if peer.peerId.namespace != Namespaces.Peer.SecretChat {
                        let chatController = ChatController(account: self.account, chatLocation: .peer(peer.peerId), mode: .standard(previewing: true))
                        chatController.canReadHistory.set(false)
                        chatController.containerLayoutUpdated(ContainerViewLayout(size: contentSize, metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false), transition: .immediate)
                        return chatController
                    } else {
                        return nil
                    }
                case let .groupReference(groupId, _, _, _):
                    let chatListController = ChatListController(account: self.account, groupId: groupId, controlsHistoryPreload: false)
                    chatListController.containerLayoutUpdated(ContainerViewLayout(size: contentSize, metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false), transition: .immediate)
                    return chatListController
            }
        } else {
            return nil
        }
    }
    
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        if let viewControllerToCommit = viewControllerToCommit as? ViewController {
            if let chatController = viewControllerToCommit as? ChatController {
                chatController.canReadHistory.set(true)
                chatController.updatePresentationMode(.standard(previewing: false))
                if let navigationController = self.navigationController as? NavigationController {
                    navigateToChatController(navigationController: navigationController, chatController: chatController, account: self.account, chatLocation: chatController.chatLocation, animated: false)
                    self.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                }
            }
        }
    }
}
