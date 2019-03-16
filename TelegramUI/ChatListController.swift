import UIKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

public func useSpecialTabBarIcons() -> Bool {
    return (Date(timeIntervalSince1970: 1545642000)...Date(timeIntervalSince1970: 1546387200)).contains(Date())
}

public class ChatListController: TelegramController, KeyShortcutResponder, UIViewControllerPreviewingDelegate {
    private var validLayout: ContainerViewLayout?
    
    let context: AccountContext
    private let controlsHistoryPreload: Bool
    private let hideNetworkActivityStatus: Bool
    
    public let groupId: PeerGroupId?
    
    let openMessageFromSearchDisposable: MetaDisposable = MetaDisposable()
    
    private var chatListDisplayNode: ChatListControllerNode {
        return super.displayNode as! ChatListControllerNode
    }
    
    private let titleView: ChatListTitleView
    private var proxyUnavailableTooltipController: TooltipController?
    private var didShowProxyUnavailableTooltipController = false
    
    private var titleDisposable: Disposable?
    private var badgeDisposable: Disposable?
    private var badgeIconDisposable: Disposable?
    
    private var dismissSearchOnDisappear = false
    
    private var didSetup3dTouch = false
    
    private var passcodeLockTooltipDisposable = MetaDisposable()
    private var didShowPasscodeLockTooltipController = false
    
    private var suggestLocalizationDisposable = MetaDisposable()
    private var didSuggestLocalization = false
    
    private var presentationData: PresentationData
    private let presentationDataValue = Promise<PresentationData>()
    private var presentationDataDisposable: Disposable?
    
    private let stateDisposable = MetaDisposable()
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    public init(context: AccountContext, groupId: PeerGroupId?, controlsHistoryPreload: Bool, hideNetworkActivityStatus: Bool = false) {
        self.context = context
        self.controlsHistoryPreload = controlsHistoryPreload
        self.hideNetworkActivityStatus = hideNetworkActivityStatus
        
        self.groupId = groupId
        
        self.presentationData = (context.sharedContext.currentPresentationData.with { $0 })
        self.presentationDataValue.set(.single(self.presentationData))
        
        self.titleView = ChatListTitleView(theme: self.presentationData.theme)
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .always, locationBroadcastPanelSource: .summary)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        if groupId == nil {
            self.navigationBar?.item = nil
        
            self.titleView.title = NetworkStatusTitle(text: self.presentationData.strings.DialogList_Title, activity: false, hasProxy: false, connectsViaProxy: false, isPasscodeSet: false, isManuallyLocked: false)
            self.navigationItem.titleView = self.titleView
            self.tabBarItem.title = self.presentationData.strings.DialogList_Title
            
            let icon: UIImage?
            if (useSpecialTabBarIcons()) {
                icon = UIImage(bundleImageName: "Chat List/Tabs/NY/IconChats")
            } else {
                icon = UIImage(bundleImageName: "Chat List/Tabs/IconChats")
            }
            
            self.tabBarItem.image = icon
            self.tabBarItem.selectedImage = icon
            
            let leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
            leftBarButtonItem.accessibilityLabel = self.presentationData.strings.Common_Edit
            self.navigationItem.leftBarButtonItem = leftBarButtonItem
            
            let rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationComposeIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.composePressed))
            rightBarButtonItem.accessibilityLabel = "Compose"
            self.navigationItem.rightBarButtonItem = rightBarButtonItem
        } else {
            self.navigationItem.title = "Channels"
            let rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
            rightBarButtonItem.accessibilityLabel = self.presentationData.strings.Common_Edit
            self.navigationItem.rightBarButtonItem = rightBarButtonItem
        }
        
        let backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.DialogList_Title, style: .plain, target: nil, action: nil)
        backBarButtonItem.accessibilityLabel = self.presentationData.strings.Common_Back
        self.navigationItem.backBarButtonItem = backBarButtonItem
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.chatListDisplayNode.scrollToTop()
            }
        }
        self.scrollToTopWithTabBar = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.chatListDisplayNode.searchDisplayController != nil {
                strongSelf.deactivateSearch(animated: true)
            } else {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.chatListDisplayNode.chatListNode.scrollToPosition(.top)
            }
            //.auto for unread navigation
        }
        self.longTapWithTabBar = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.chatListDisplayNode.searchDisplayController != nil {
                strongSelf.deactivateSearch(animated: true)
            } else {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.chatListDisplayNode.chatListNode.scrollToPosition(.auto)
            }
        }
        
        let hasProxy = context.sharedContext.accountManager.sharedData(keys: [SharedDataKeys.proxySettings])
        |> map { sharedData -> (Bool, Bool) in
            if let settings = sharedData.entries[SharedDataKeys.proxySettings] as? ProxySettings {
                return (!settings.servers.isEmpty, settings.enabled)
            } else {
                return (false, false)
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
        
        let passcode = context.sharedContext.accountManager.accessChallengeData()
        |> map { view -> (Bool, Bool) in
            let data = view.data
            return (data.isLockable, data.autolockDeadline == 0)
        }
        
        if !self.hideNetworkActivityStatus {
            self.titleDisposable = combineLatest(queue: .mainQueue(), context.account.networkState, hasProxy, passcode, self.chatListDisplayNode.chatListNode.state).start(next: { [weak self] networkState, proxy, passcode, state in
                if let strongSelf = self {
                    if state.editing {
                        strongSelf.navigationItem.rightBarButtonItem = nil
                        
                        let title = !state.selectedPeerIds.isEmpty ? strongSelf.presentationData.strings.ChatList_SelectedChats(Int32(state.selectedPeerIds.count)) : strongSelf.presentationData.strings.DialogList_Title
                        strongSelf.titleView.title = NetworkStatusTitle(text: title, activity: false, hasProxy: false, connectsViaProxy: false, isPasscodeSet: false, isManuallyLocked: false)
                    } else {
                        let rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationComposeIcon(strongSelf.presentationData.theme), style: .plain, target: strongSelf, action: #selector(strongSelf.composePressed))
                        rightBarButtonItem.accessibilityLabel = "Compose"
                        strongSelf.navigationItem.rightBarButtonItem = rightBarButtonItem
                        
                        let (hasProxy, connectsViaProxy) = proxy
                        let (isPasscodeSet, isManuallyLocked) = passcode
                        var checkProxy = false
                        switch networkState {
                            case .waitingForNetwork:
                                strongSelf.titleView.title = NetworkStatusTitle(text: strongSelf.presentationData.strings.State_WaitingForNetwork, activity: true, hasProxy: false, connectsViaProxy: connectsViaProxy, isPasscodeSet: isPasscodeSet, isManuallyLocked: isManuallyLocked)
                            case let .connecting(proxy):
                                var text = strongSelf.presentationData.strings.State_Connecting
                                if let layout = strongSelf.validLayout, proxy != nil && layout.metrics.widthClass != .regular && layout.size.width > 320.0 {
                                    text = strongSelf.presentationData.strings.State_ConnectingToProxy
                                }
                                if let proxy = proxy, proxy.hasConnectionIssues {
                                    checkProxy = true
                                }
                                strongSelf.titleView.title = NetworkStatusTitle(text: text, activity: true, hasProxy: hasProxy, connectsViaProxy: connectsViaProxy, isPasscodeSet: isPasscodeSet, isManuallyLocked: isManuallyLocked)
                            case .updating:
                                strongSelf.titleView.title = NetworkStatusTitle(text: strongSelf.presentationData.strings.State_Updating, activity: true, hasProxy: hasProxy, connectsViaProxy: connectsViaProxy, isPasscodeSet: isPasscodeSet, isManuallyLocked: isManuallyLocked)
                            case .online:
                                strongSelf.titleView.title = NetworkStatusTitle(text: strongSelf.presentationData.strings.DialogList_Title, activity: false, hasProxy: hasProxy, connectsViaProxy: connectsViaProxy, isPasscodeSet: isPasscodeSet, isManuallyLocked: isManuallyLocked)
                        }
                        if checkProxy {
                            if strongSelf.proxyUnavailableTooltipController == nil && !strongSelf.didShowProxyUnavailableTooltipController && strongSelf.isNodeLoaded && strongSelf.displayNode.view.window != nil {
                                strongSelf.didShowProxyUnavailableTooltipController = true
                                let tooltipController = TooltipController(content: .text(strongSelf.presentationData.strings.Proxy_TooltipUnavailable), timeout: 60.0, dismissByTapOutside: true)
                                strongSelf.proxyUnavailableTooltipController = tooltipController
                                tooltipController.dismissed = { [weak tooltipController] in
                                    if let strongSelf = self, let tooltipController = tooltipController, strongSelf.proxyUnavailableTooltipController === tooltipController {
                                        strongSelf.proxyUnavailableTooltipController = nil
                                    }
                                }
                                strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceViewAndRect: {
                                    if let strongSelf = self, let rect = strongSelf.titleView.proxyButtonFrame {
                                        return (strongSelf.titleView, rect.insetBy(dx: 0.0, dy: -4.0))
                                    }
                                    return nil
                                }))
                            }
                        } else {
                            strongSelf.didShowProxyUnavailableTooltipController = false
                            if let proxyUnavailableTooltipController = strongSelf.proxyUnavailableTooltipController {
                                strongSelf.proxyUnavailableTooltipController = nil
                                proxyUnavailableTooltipController.dismiss()
                            }
                        }
                    }
                }
            })
        }
        
        self.badgeDisposable = (renderedTotalUnreadCount(accountManager: context.sharedContext.accountManager, postbox: context.account.postbox) |> deliverOnMainQueue).start(next: { [weak self] count in
            if let strongSelf = self {
                if count.0 == 0 {
                    strongSelf.tabBarItem.badgeValue = ""
                } else {
                    if count.0 > 1000 {
                        strongSelf.tabBarItem.badgeValue = "\(count.0 / 1000)K"
                    } else {
                        strongSelf.tabBarItem.badgeValue = "\(count.0)"
                    }
                }
            }
        })
        
        self.titleView.toggleIsLocked = { [weak self] in
            if let strongSelf = self {
                let _ = (strongSelf.context.sharedContext.accountManager.transaction({ transaction -> Void in
                    var data = transaction.getAccessChallengeData()
                    if data.isLockable {
                        if data.autolockDeadline != 0 {
                            data = data.withUpdatedAutolockDeadline(0)
                        } else {
                            data = data.withUpdatedAutolockDeadline(nil)
                        }
                        transaction.setAccessChallengeData(data)
                    }
                }) |> deliverOnMainQueue).start(completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.presentInGlobalOverlay(OverlayStatusController(theme: strongSelf.presentationData.theme, strings: strongSelf.presentationData.strings, type: .shieldSuccess(strongSelf.presentationData.strings.Passcode_AppLockedAlert, true)))
                })
            }
        }
        
        self.titleView.openProxySettings = { [weak self] in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(proxySettingsController(context: context))
            }
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataValue.set(.single(presentationData))
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.DialogList_SearchLabel, activate: { [weak self] in
            self?.activateSearch()
        })
        self.searchContentNode?.updateExpansionProgress(0.0)
        self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
        
        if !GlobalExperimentalSettings.isAppStoreBuild {
            self.tabBarItemDebugTapAction = {
                preconditionFailure("debug tap")
            }
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.openMessageFromSearchDisposable.dispose()
        self.titleDisposable?.dispose()
        self.badgeDisposable?.dispose()
        self.badgeIconDisposable?.dispose()
        self.passcodeLockTooltipDisposable.dispose()
        self.suggestLocalizationDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.stateDisposable.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.tabBarItem.title = self.presentationData.strings.DialogList_Title
        
        let backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.DialogList_Title, style: .plain, target: nil, action: nil)
        backBarButtonItem.accessibilityLabel = self.presentationData.strings.Common_Back
        self.navigationItem.backBarButtonItem = backBarButtonItem
        
        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.DialogList_SearchLabel)
        var editing = false
        self.chatListDisplayNode.chatListNode.updateState { state in
            editing = state.editing
            return state
        }
        let editItem: UIBarButtonItem
        if editing {
            editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
            editItem.accessibilityLabel = self.presentationData.strings.Common_Done
        } else {
            editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
            editItem.accessibilityLabel = self.presentationData.strings.Common_Edit
        }
        if self.groupId == nil {
            self.navigationItem.leftBarButtonItem = editItem
            let rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationComposeIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.composePressed))
            rightBarButtonItem.accessibilityLabel = "Compose"
            self.navigationItem.rightBarButtonItem = rightBarButtonItem
        } else {
            self.navigationItem.rightBarButtonItem = editItem
        }
        
        self.titleView.theme = self.presentationData.theme
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        if self.isNodeLoaded {
            self.chatListDisplayNode.updatePresentationData(self.presentationData)
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatListControllerNode(context: self.context, groupId: self.groupId, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: self.presentationData, controller: self)
        
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
            guard let strongSelf = self else {
                return
            }
            let _ = (strongSelf.context.account.postbox.transaction { transaction -> RenderedPeer? in
                guard let peer = transaction.getPeer(peerId) else {
                    return nil
                }
                if let associatedPeerId = peer.associatedPeerId {
                    if let associatedPeer = transaction.getPeer(associatedPeerId) {
                        return RenderedPeer(peerId: peerId, peers: SimpleDictionary([peer.id: peer, associatedPeer.id: associatedPeer]))
                    } else {
                        return nil
                    }
                } else {
                    return RenderedPeer(peer: peer)
                }
            }
            |> deliverOnMainQueue).start(next: { peer in
                guard let strongSelf = self, let peer = peer, let chatPeer = peer.peers[peer.peerId], let mainPeer = peer.chatMainPeer else {
                    return
                }
                let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                var items: [ActionSheetItem] = []
                var canClear = true
                var canStop = false
            
                var deleteTitle = strongSelf.presentationData.strings.Common_Delete
                if let channel = chatPeer as? TelegramChannel {
                    if case .broadcast = channel.info {
                        canClear = false
                        deleteTitle = strongSelf.presentationData.strings.Channel_LeaveChannel
                    } else {
                        deleteTitle = strongSelf.presentationData.strings.Group_LeaveGroup
                    }
                    if let addressName = channel.addressName, !addressName.isEmpty {
                        canClear = false
                    }
                } else if let user = chatPeer as? TelegramUser, user.botInfo != nil {
                    canStop = !user.flags.contains(.isSupport)
                    deleteTitle = strongSelf.presentationData.strings.ChatList_DeleteChat
                } else if let _ = chatPeer as? TelegramSecretChat {
                    deleteTitle = strongSelf.presentationData.strings.ChatList_DeleteChat
                }
                items.append(DeleteChatPeerActionSheetItem(context: strongSelf.context, peer: mainPeer, chatPeer: chatPeer, strings: strongSelf.presentationData.strings))
                if canClear {
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.DialogList_ClearHistoryConfirmation, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.chatListDisplayNode.chatListNode.updateState({ state in
                            var state = state
                            state.pendingClearHistoryPeerIds.insert(peer.peerId)
                            return state
                        })
                        strongSelf.present(UndoOverlayController(context: strongSelf.context, text: strongSelf.presentationData.strings.Undo_MessagesDeleted, action: { shouldCommit in
                            guard let strongSelf = self else {
                                return
                            }
                            if shouldCommit {
                                let _ = clearHistoryInteractively(postbox: strongSelf.context.account.postbox, peerId: peerId).start(completed: {
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    strongSelf.chatListDisplayNode.chatListNode.updateState({ state in
                                        var state = state
                                        state.pendingClearHistoryPeerIds.remove(peer.peerId)
                                        return state
                                    })
                                })
                            } else {
                                strongSelf.chatListDisplayNode.chatListNode.updateState({ state in
                                    var state = state
                                    state.pendingClearHistoryPeerIds.remove(peer.peerId)
                                    return state
                                })
                            }
                        }), in: .window(.root))
                    }))
                }
            
                items.append(ActionSheetButtonItem(title: deleteTitle, color: .destructive, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.schedulePeerChatRemoval(peer: peer)
                }))
        
                if canStop {
                    items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.DialogList_DeleteBotConversationConfirmation, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        if let strongSelf = self {
                            strongSelf.chatListDisplayNode.chatListNode.setCurrentRemovingPeerId(peerId)
                            let _ = removePeerChat(account: strongSelf.context.account, peerId: peerId, reportChatSpam: false).start(completed: {
                                self?.chatListDisplayNode.chatListNode.setCurrentRemovingPeerId(peerId)
                            })
                            let _ = requestUpdatePeerIsBlocked(account: strongSelf.context.account, peerId: peer.peerId, isBlocked: true).start()
                        }
                    }))
                }
        
                actionSheet.setItemGroups([ActionSheetItemGroup(items: items),
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                        })
                    ])
                ])
                strongSelf.present(actionSheet, in: .window(.root))
            })
        }
        
        self.chatListDisplayNode.chatListNode.peerSelected = { [weak self] peerId, animated, isAd in
            if let strongSelf = self {
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    if isAd {
                        let _ = (ApplicationSpecificNotice.getProxyAdsAcknowledgment(accountManager: strongSelf.context.sharedContext.accountManager)
                        |> deliverOnMainQueue).start(next: { value in
                            guard let strongSelf = self else {
                                return
                            }
                            if !value {
                                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.DialogList_AdNoticeAlert, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                                    if let strongSelf = self {
                                        let _ = ApplicationSpecificNotice.setProxyAdsAcknowledgment(accountManager: strongSelf.context.sharedContext.accountManager).start()
                                    }
                                })]), in: .window(.root))
                            }
                        })
                    }
                    
                    var scrollToEndIfExists = false
                    if let layout = strongSelf.validLayout, case .regular = layout.metrics.widthClass {
                        scrollToEndIfExists = true
                    }
                    navigateToChatController(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peerId), scrollToEndIfExists: scrollToEndIfExists, animated: animated, completion: { [weak self] in
                        self?.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                    })
                }
            }
        }
        
        self.chatListDisplayNode.chatListNode.groupSelected = { [weak self] groupId in
            if let strongSelf = self {
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    var scrollToEndIfExists = false
                    if let layout = strongSelf.validLayout, case .regular = layout.metrics.widthClass {
                        scrollToEndIfExists = true
                    }
                    navigateToChatController(navigationController: navigationController, context: strongSelf.context, chatLocation: .group(groupId), scrollToEndIfExists: scrollToEndIfExists)
                    strongSelf.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                }
            }
        }
        
        self.chatListDisplayNode.chatListNode.updatePeerGrouping = { [weak self] peerId, group in
            if let strongSelf = self {
                let _ = updatePeerGroupIdInteractively(postbox: strongSelf.context.account.postbox, peerId: peerId, groupId: group ? Namespaces.PeerGroup.feed : nil).start()
            }
        }
        
        self.chatListDisplayNode.requestOpenMessageFromSearch = { [weak self] peer, messageId in
            if let strongSelf = self {
                strongSelf.openMessageFromSearchDisposable.set((storedMessageFromSearchPeer(account: strongSelf.context.account, peer: peer)
                |> deliverOnMainQueue).start(next: { [weak strongSelf] actualPeerId in
                    if let strongSelf = strongSelf {
                        if let navigationController = strongSelf.navigationController as? NavigationController {
                            navigateToChatController(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(actualPeerId), messageId: messageId, purposefulAction: {
                                self?.deactivateSearch(animated: false)
                            })
                            strongSelf.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                        }
                    }
                }))
            }
        }
        
        self.chatListDisplayNode.requestOpenPeerFromSearch = { [weak self] peer, dismissSearch in
            if let strongSelf = self {
                let storedPeer = strongSelf.context.account.postbox.transaction { transaction -> Void in
                    if transaction.getPeer(peer.id) == nil {
                        updatePeers(transaction: transaction, peers: [peer], update: { previousPeer, updatedPeer in
                            return updatedPeer
                        })
                    }
                }
                strongSelf.openMessageFromSearchDisposable.set((storedPeer |> deliverOnMainQueue).start(completed: { [weak strongSelf] in
                    if let strongSelf = strongSelf {
                        if dismissSearch {
                            strongSelf.dismissSearchOnDisappear = true
                        }
                        if let navigationController = strongSelf.navigationController as? NavigationController {
                            navigateToChatController(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(peer.id), purposefulAction: { [weak self] in
                                self?.deactivateSearch(animated: false)
                            })
                            strongSelf.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                        }
                    }
                }))
            }
        }
        
        self.chatListDisplayNode.requestOpenRecentPeerOptions = { [weak self] peer in
            if let strongSelf = self {
                strongSelf.view.window?.endEditing(true)
                let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                
                actionSheet.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Delete, color: .destructive, action: { [weak actionSheet] in
                            actionSheet?.dismissAnimated()
                            
                            if let strongSelf = self {
                                let _ = removeRecentPeer(account: strongSelf.context.account, peerId: peer.id).start()
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
        
        self.chatListDisplayNode.requestAddContact = { [weak self] phoneNumber in
            if let strongSelf = self {
                strongSelf.view.endEditing(true)
                openAddContact(context: strongSelf.context, phoneNumber: phoneNumber, present: { [weak self] controller, arguments in
                    self?.present(controller, in: .window(.root), with: arguments)
                }, completed: {
                    self?.deactivateSearch(animated: false)
                })
            }
        }
        
        self.chatListDisplayNode.chatListNode.contentOffsetChanged = { [weak self] offset in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode, let validLayout = strongSelf.validLayout {
                var offset = offset
                if validLayout.inVoiceOver {
                    offset = .known(0.0)
                }
                searchContentNode.updateListVisibleContentOffset(offset)
            }
        }
        
        self.chatListDisplayNode.chatListNode.contentScrollingEnded = { [weak self] listView in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                return fixNavigationSearchableListNodeScrolling(listView, searchNode: searchContentNode)
            } else {
                return false
            }
        }
        
        let context = self.context
        let peerIdsAndOptions: Signal<(ChatListSelectionOptions, Set<PeerId>)?, NoError> = self.chatListDisplayNode.chatListNode.state
        |> map { state -> Set<PeerId>? in
            if !state.editing {
                return nil
            }
            return state.selectedPeerIds
        }
        |> distinctUntilChanged
        |> mapToSignal { selectedPeerIds -> Signal<(ChatListSelectionOptions, Set<PeerId>)?, NoError> in
            if let selectedPeerIds = selectedPeerIds {
                return chatListSelectionOptions(postbox: context.account.postbox, peerIds: selectedPeerIds)
                |> map { options -> (ChatListSelectionOptions, Set<PeerId>)? in
                    return (options, selectedPeerIds)
                }
            } else {
                return .single(nil)
            }
        }
        
        self.stateDisposable.set(combineLatest(queue: .mainQueue(), self.presentationDataValue.get(), peerIdsAndOptions).start(next: { [weak self] presentationData, peerIdsAndOptions in
            var toolbar: Toolbar?
            if let (options, _) = peerIdsAndOptions {
                let leftAction: ToolbarAction
                switch options.read {
                    case let .all(enabled):
                        leftAction = ToolbarAction(title: presentationData.strings.ChatList_ReadAll, isEnabled: enabled)
                    case let .selective(enabled):
                        leftAction = ToolbarAction(title: presentationData.strings.ChatList_Read, isEnabled: enabled)
                }
                toolbar = Toolbar(leftAction: leftAction, rightAction: ToolbarAction(title: presentationData.strings.Common_Delete, isEnabled: options.delete))
            }
            self?.setToolbar(toolbar, transition: .animated(duration: 0.3, curve: .easeInOut))
        }))
        
        /*self.badgeIconDisposable = (self.chatListDisplayNode.chatListNode.scrollToTopOption
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] option in
            guard let strongSelf = self else {
                return
            }
            switch option {
                case .none:
                    strongSelf.tabBarItem.selectedImage = tabImageNone
                case .top:
                    strongSelf.tabBarItem.selectedImage = tabImageUp
                case .unread:
                    strongSelf.tabBarItem.selectedImage = tabImageUnread
            }
        })*/
        
        self.ready.set(self.chatListDisplayNode.chatListNode.ready)
        
        self.displayNodeDidLoad()
    }
    
    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if #available(iOSApplicationExtension 9.0, *) {
            if !self.didSetup3dTouch && self.traitCollection.forceTouchCapability != .unknown {
                self.didSetup3dTouch = true
                self.registerForPreviewingNonNative(with: self, sourceView: self.view, theme: PeekControllerTheme(presentationTheme: self.presentationData.theme))
            }
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        #if false && DEBUG
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let count = ChatControllerCount.with({ $0 })
            if count != 0 {
                strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: "", text: "ChatControllerCount \(count)", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window(.root))
            }
        })
        #endif

        
        if let lockViewFrame = self.titleView.lockViewFrame, !self.didShowPasscodeLockTooltipController {
            self.passcodeLockTooltipDisposable.set(combineLatest(queue: .mainQueue(), ApplicationSpecificNotice.getPasscodeLockTips(accountManager: self.context.sharedContext.accountManager), self.context.sharedContext.accountManager.accessChallengeData() |> take(1)).start(next: { [weak self] tooltipValue, passcodeView in
                    if let strongSelf = self {
                        if !tooltipValue {
                            let hasPasscode = passcodeView.data.isLockable
                            if hasPasscode {
                                let _ = ApplicationSpecificNotice.setPasscodeLockTips(accountManager: strongSelf.context.sharedContext.accountManager).start()
                                
                                let tooltipController = TooltipController(content: .text(strongSelf.presentationData.strings.DialogList_PasscodeLockHelp), dismissByTapOutside: true)
                                strongSelf.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceViewAndRect: { [weak self] in
                                    if let strongSelf = self {
                                        return (strongSelf.titleView, lockViewFrame.offsetBy(dx: 4.0, dy: 14.0))
                                    }
                                    return nil
                                }))
                                strongSelf.didShowPasscodeLockTooltipController = true
                            }
                        } else {
                            strongSelf.didShowPasscodeLockTooltipController = true
                        }
                    }
                }))
        }
        
        if !self.didSuggestLocalization {
            self.didSuggestLocalization = true
            
            let network = self.context.account.network
            let signal = combineLatest(self.context.sharedContext.accountManager.transaction { transaction -> String in
                let languageCode: String
                if let current = transaction.getSharedData(SharedDataKeys.localizationSettings) as? LocalizationSettings {
                    let code = current.primaryComponent.languageCode
                    let rawSuffix = "-raw"
                    if code.hasSuffix(rawSuffix) {
                        languageCode = String(code.dropLast(rawSuffix.count))
                    } else {
                        languageCode = code
                    }
                } else {
                    languageCode = "en"
                }
                return languageCode
            }, self.context.account.postbox.transaction { transaction -> SuggestedLocalizationEntry? in
                var suggestedLocalization: SuggestedLocalizationEntry?
                if let localization = transaction.getPreferencesEntry(key: PreferencesKeys.suggestedLocalization) as? SuggestedLocalizationEntry {
                    suggestedLocalization = localization
                }
                return suggestedLocalization
            })
            |> mapToSignal({ value -> Signal<(String, SuggestedLocalizationInfo)?, NoError> in
                guard let suggestedLocalization = value.1, !suggestedLocalization.isSeen && suggestedLocalization.languageCode != "en" && suggestedLocalization.languageCode != value.0 else {
                    return .single(nil)
                }
                return suggestedLocalizationInfo(network: network, languageCode: suggestedLocalization.languageCode, extractKeys: LanguageSuggestionControllerStrings.keys)
                |> map({ suggestedLocalization -> (String, SuggestedLocalizationInfo)? in
                    return (value.0, suggestedLocalization)
                })
            })
        
            self.suggestLocalizationDisposable.set((signal |> deliverOnMainQueue).start(next: { [weak self] suggestedLocalization in
                guard let strongSelf = self, let (currentLanguageCode, suggestedLocalization) = suggestedLocalization else {
                    return
                }
                if let controller = languageSuggestionController(context: strongSelf.context, suggestedLocalization: suggestedLocalization, currentLanguageCode: currentLanguageCode, openSelection: { [weak self] in
                    if let strongSelf = self {
                        let controller = LocalizationListController(context: strongSelf.context)
                        (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
                    }
                }) {
                    strongSelf.present(controller, in: .window(.root))
                    _ = markSuggestedLocalizationAsSeenInteractively(postbox: strongSelf.context.account.postbox, languageCode: suggestedLocalization.languageCode).start()
                }
            }))
        }
    }
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
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
        
        let wasInVoiceOver = self.validLayout?.inVoiceOver ?? false
        
        self.validLayout = layout
        
        if let searchContentNode = self.searchContentNode, layout.inVoiceOver != wasInVoiceOver {
            searchContentNode.updateListVisibleContentOffset(.known(0.0))
            self.chatListDisplayNode.chatListNode.scrollToPosition(.top)
        }
        
        self.chatListDisplayNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationInsetHeight, transition: transition)
    }
    
    override public func navigationStackConfigurationUpdated(next: [ViewController]) {
        super.navigationStackConfigurationUpdated(next: next)
        
        let chatLocation = (next.first as? ChatController)?.chatLocation
        
        self.chatListDisplayNode.chatListNode.updateSelectedChatLocation(chatLocation, progress: 1.0, transition: .immediate)
    }
    
    @objc func editPressed() {
        let editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        editItem.accessibilityLabel = self.presentationData.strings.Common_Done
        if self.groupId == nil {
            self.navigationItem.leftBarButtonItem = editItem
        } else {
            self.navigationItem.rightBarButtonItem = editItem
        }
        self.searchContentNode?.setIsEnabled(false, animated: true)
        self.chatListDisplayNode.chatListNode.updateState { state in
            var state = state
            state.editing = true
            state.peerIdWithRevealedOptions = nil
            return state
        }
    }
    
    @objc func donePressed() {
        let editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        editItem.accessibilityLabel = self.presentationData.strings.Common_Edit
        if self.groupId == nil {
            self.navigationItem.leftBarButtonItem = editItem
        } else {
            self.navigationItem.rightBarButtonItem = editItem
        }
        self.searchContentNode?.setIsEnabled(true, animated: true)
        self.chatListDisplayNode.chatListNode.updateState { state in
            var state = state
            state.editing = false
            state.peerIdWithRevealedOptions = nil
            state.selectedPeerIds.removeAll()
            return state
        }
    }
    
    func activateSearch() {
        if self.displayNavigationBar {
            let _ = (self.chatListDisplayNode.chatListNode.ready
            |> take(1)
            |> deliverOnMainQueue).start(completed: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let scrollToTop = strongSelf.scrollToTop {
                    scrollToTop()
                }
                if let searchContentNode = strongSelf.searchContentNode {
                    strongSelf.chatListDisplayNode.activateSearch(placeholderNode: searchContentNode.placeholderNode)
                }
                strongSelf.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
            })
        }
    }
    
    func deactivateSearch(animated: Bool) {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate)
            if let searchContentNode = self.searchContentNode {
                self.chatListDisplayNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode, animated: animated)
            }
        }
    }
    
    @objc func composePressed() {
        (self.navigationController as? NavigationController)?.replaceAllButRootController(ComposeController(context: self.context), animated: true)
    }
    
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        if #available(iOSApplicationExtension 9.0, *) {
            if let (controller, rect) = self.previewingController(from: previewingContext.sourceView, for: location) {
                previewingContext.sourceRect = rect
                return controller
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    func previewingController(from sourceView: UIView, for location: CGPoint) -> (UIViewController, CGRect)? {
        guard let layout = self.validLayout, case .compact = layout.metrics.widthClass else {
            return nil
        }
        
        let boundsSize = self.view.bounds.size
        let contentSize: CGSize
        if let metrics = DeviceMetrics.forScreenSize(layout.size) {
            contentSize = metrics.previewingContentSize(inLandscape: boundsSize.width > boundsSize.height)
        } else {
            contentSize = boundsSize
        }
        
        if let searchController = self.chatListDisplayNode.searchDisplayController {
            if let (view, bounds, action) = searchController.previewViewAndActionAtLocation(location) {
                if let peerId = action as? PeerId, peerId.namespace != Namespaces.Peer.SecretChat {
                    var sourceRect = view.superview!.convert(view.frame, to: sourceView)
                    sourceRect = CGRect(x: sourceRect.minX, y: sourceRect.minY + bounds.minY, width: bounds.width, height: bounds.height)
                    sourceRect.size.height -= UIScreenPixel
                    
                    let chatController = ChatController(context: self.context, chatLocation: .peer(peerId), mode: .standard(previewing: true))
                    chatController.canReadHistory.set(false)
                    chatController.containerLayoutUpdated(ContainerViewLayout(size: contentSize, metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
                    return (chatController, sourceRect)
                } else if let messageId = action as? MessageId, messageId.peerId.namespace != Namespaces.Peer.SecretChat {
                    var sourceRect = view.superview!.convert(view.frame, to: sourceView)
                    sourceRect = CGRect(x: sourceRect.minX, y: sourceRect.minY + bounds.minY, width: bounds.width, height: bounds.height)
                    sourceRect.size.height -= UIScreenPixel
                    
                    let chatController = ChatController(context: self.context, chatLocation: .peer(messageId.peerId), messageId: messageId, mode: .standard(previewing: true))
                    chatController.canReadHistory.set(false)
                    chatController.containerLayoutUpdated(ContainerViewLayout(size: contentSize, metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
                    return (chatController, sourceRect)
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
            if let itemNode = itemNode as? ChatListItemNode, itemNode.frame.contains(listLocation), !itemNode.isDisplayingRevealedOptions {
                selectedNode = itemNode
            }
        }
        if let selectedNode = selectedNode, let item = selectedNode.item {
            var sourceRect = selectedNode.view.superview!.convert(selectedNode.frame, to: sourceView)
            sourceRect.size.height -= UIScreenPixel
            switch item.content {
                case let .peer(_, peer, _, _, _, _, _, _, _):
                    if peer.peerId.namespace != Namespaces.Peer.SecretChat {
                        let chatController = ChatController(context: self.context, chatLocation: .peer(peer.peerId), mode: .standard(previewing: true))
                        chatController.canReadHistory.set(false)
                        chatController.containerLayoutUpdated(ContainerViewLayout(size: contentSize, metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
                        return (chatController, sourceRect)
                    } else {
                        return nil
                    }
                case let .groupReference(groupId, _, _, _):
                    let chatListController = ChatListController(context: self.context, groupId: groupId, controlsHistoryPreload: false)
                    chatListController.containerLayoutUpdated(ContainerViewLayout(size: contentSize, metrics: LayoutMetrics(), intrinsicInsets: UIEdgeInsets(), safeInsets: UIEdgeInsets(), statusBarHeight: nil, inputHeight: nil, standardInputHeight: 216.0, inputHeightIsInteractivellyChanging: false, inVoiceOver: false), transition: .immediate)
                    return (chatListController, sourceRect)
            }
        } else {
            return nil
        }
    }
    
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        self.previewingCommit(viewControllerToCommit)
    }
    
    func previewingCommit(_ viewControllerToCommit: UIViewController) {
        if let viewControllerToCommit = viewControllerToCommit as? ViewController {
            if let chatController = viewControllerToCommit as? ChatController {
                chatController.canReadHistory.set(true)
                chatController.updatePresentationMode(.standard(previewing: false))
                if let navigationController = self.navigationController as? NavigationController {
                    navigateToChatController(navigationController: navigationController, chatController: chatController, context: self.context, chatLocation: chatController.chatLocation, animated: false)
                    self.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                }
            }
        }
    }
    
    public var keyShortcuts: [KeyShortcut] {
        let strings = self.presentationData.strings
        
        let toggleSearch: () -> Void = { [weak self] in
            if let strongSelf = self {
                if strongSelf.displayNavigationBar {
                    strongSelf.activateSearch()
                } else {
                    strongSelf.deactivateSearch(animated: true)
                }
            }
        }
        
        let inputShortcuts: [KeyShortcut] = [
            KeyShortcut(title: strings.KeyCommand_JumpToPreviousChat, input: UIKeyInputUpArrow, modifiers: [.alternate], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.chatListDisplayNode.chatListNode.selectChat(.previous(unread: false))
                }
            }),
            KeyShortcut(title: strings.KeyCommand_JumpToNextChat, input: UIKeyInputDownArrow, modifiers: [.alternate], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.chatListDisplayNode.chatListNode.selectChat(.next(unread: false))
                }
            }),
            KeyShortcut(title: strings.KeyCommand_JumpToPreviousUnreadChat, input: UIKeyInputUpArrow, modifiers: [.alternate, .shift], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.chatListDisplayNode.chatListNode.selectChat(.previous(unread: true))
                }
            }),
            KeyShortcut(title: strings.KeyCommand_JumpToNextUnreadChat, input: UIKeyInputDownArrow, modifiers: [.alternate, .shift], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.chatListDisplayNode.chatListNode.selectChat(.next(unread: true))
                }
            }),
            KeyShortcut(title: strings.KeyCommand_NewMessage, input: "N", modifiers: [.command], action: { [weak self] in
                if let strongSelf = self {
                    strongSelf.composePressed()
                }
            }),
            KeyShortcut(title: strings.KeyCommand_Find, input: "\t", modifiers: [], action: toggleSearch),
            KeyShortcut(input: UIKeyInputEscape, modifiers: [], action: toggleSearch)
        ]
        
        let openChat: (Int) -> Void = { [weak self] index in
            if let strongSelf = self {
                if index == 0 {
                    strongSelf.chatListDisplayNode.chatListNode.selectChat(.peerId(strongSelf.context.account.peerId))
                } else {
                    strongSelf.chatListDisplayNode.chatListNode.selectChat(.index(index - 1))
                }
            }
        }
        
        let chatShortcuts: [KeyShortcut] = (0 ... 9).map { index in
            return KeyShortcut(input: "\(index)", modifiers: [.command], action: {
                openChat(index)
            })
        }
        
        return inputShortcuts + chatShortcuts
    }
    
    override public func toolbarActionSelected(left: Bool) {
        let peerIds = self.chatListDisplayNode.chatListNode.currentState.selectedPeerIds
        if left {
            let signal: Signal<Void, NoError>
            let context = self.context
            if !peerIds.isEmpty {
                signal = self.context.account.postbox.transaction { transaction -> Void in
                    for peerId in peerIds {
                        togglePeerUnreadMarkInteractively(transaction: transaction, viewTracker: context.account.viewTracker, peerId: peerId, setToValue: false)
                    }
                }
            } else {
                signal = self.context.account.postbox.transaction { transaction -> Void in
                    markAllChatsAsReadInteractively(transaction: transaction, viewTracker: context.account.viewTracker)
                }
            }
            let _ = (signal
            |> deliverOnMainQueue).start(completed: { [weak self] in
                self?.donePressed()
            })
        } else if !peerIds.isEmpty {
            let actionSheet = ActionSheetController(presentationTheme: self.presentationData.theme)
            var items: [ActionSheetItem] = []
            items.append(ActionSheetButtonItem(title: self.presentationData.strings.ChatList_DeleteConfirmation(Int32(peerIds.count)), color: .destructive, action: { [weak self, weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                guard let strongSelf = self else {
                    return
                }
                
                let context = strongSelf.context
                let presentationData = strongSelf.presentationData
                let progressSignal = Signal<Never, NoError> { subscriber in
                    let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
                    self?.present(controller, in: .window(.root))
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.8, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                
                let signal: Signal<Void, NoError> = strongSelf.context.account.postbox.transaction { transaction -> Void in
                    for peerId in peerIds {
                        removePeerChat(account: context.account, transaction: transaction, mediaBox: context.account.postbox.mediaBox, peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: false)
                    }
                }
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                let _ = (signal
                |> deliverOnMainQueue).start(completed: {
                    self?.donePressed()
                })
            }))
            
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            self.present(actionSheet, in: .window(.root))
        }
    }
    
    func schedulePeerChatRemoval(peer: RenderedPeer, deleteGloballyIfPossible: Bool = false) {
        guard let chatPeer = peer.peers[peer.peerId] else {
            return
        }
        let peerId = peer.peerId
        self.chatListDisplayNode.chatListNode.setCurrentRemovingPeerId(peerId)
        self.chatListDisplayNode.chatListNode.updateState({ state in
            var state = state
            state.pendingRemovalPeerIds.insert(peer.peerId)
            return state
        })
        self.chatListDisplayNode.chatListNode.setCurrentRemovingPeerId(nil)
        let statusText: String
        if let channel = chatPeer as? TelegramChannel {
            if deleteGloballyIfPossible {
                if case .broadcast = channel.info {
                    statusText = self.presentationData.strings.Undo_DeletedChannel
                } else {
                    statusText = self.presentationData.strings.Undo_DeletedGroup
                }
            } else {
                if case .broadcast = channel.info {
                    statusText = self.presentationData.strings.Undo_LeftChannel
                } else {
                    statusText = self.presentationData.strings.Undo_LeftGroup
                }
            }
        } else if let _ = chatPeer as? TelegramGroup {
            if deleteGloballyIfPossible {
                statusText = self.presentationData.strings.Undo_DeletedGroup
            } else {
                statusText = self.presentationData.strings.Undo_LeftGroup
            }
        } else if let _ = chatPeer as? TelegramSecretChat {
            statusText = self.presentationData.strings.Undo_SecretChatDeleted
        } else {
            statusText = self.presentationData.strings.Undo_ChatDeleted
        }
        self.present(UndoOverlayController(context: self.context, text: statusText, action: { [weak self] shouldCommit in
            guard let strongSelf = self else {
                return
            }
            if shouldCommit {
                strongSelf.chatListDisplayNode.chatListNode.setCurrentRemovingPeerId(peerId)
                let _ = removePeerChat(account: strongSelf.context.account, peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: deleteGloballyIfPossible).start(completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.chatListDisplayNode.chatListNode.updateState({ state in
                        var state = state
                        state.pendingRemovalPeerIds.remove(peer.peerId)
                        return state
                    })
                    self?.chatListDisplayNode.chatListNode.setCurrentRemovingPeerId(nil)
                })
            } else {
                strongSelf.chatListDisplayNode.chatListNode.setCurrentRemovingPeerId(peerId)
                strongSelf.chatListDisplayNode.chatListNode.updateState({ state in
                    var state = state
                    state.pendingRemovalPeerIds.remove(peer.peerId)
                    return state
                })
                self?.chatListDisplayNode.chatListNode.setCurrentRemovingPeerId(nil)
            }
        }), in: .window(.root))
    }
}
