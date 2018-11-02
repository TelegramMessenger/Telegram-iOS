import UIKit
import Postbox
import SwiftSignalKit
import Display
import TelegramCore

//private let tabImageNone = UIImage(bundleImageName: "Chat List/Tabs/IconChats")?.precomposed()
//private let tabImageUp = tabImageNone.flatMap({ image in
//    return generateImage(image.size, contextGenerator: { size, context in
//        context.clear(CGRect(origin: CGPoint(), size: size))
//        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
//        context.setBlendMode(.copy)
//        context.setFillColor(UIColor.clear.cgColor)
//        context.translateBy(x: 0.0, y: 7.0)
//        let _ = try? drawSvgPath(context, path: "M14.6557321,9.04533883 C14.9642504,8.81236784 15.4032142,8.87361104 15.6361852,9.18212936 C15.8691562,9.49064768 15.807913,9.9296115 15.4993947,10.1625825 L11.612306,13.0978342 C11.3601561,13.2882398 11.0117095,13.2861239 10.7618904,13.0926701 L6.97141581,10.1574184 C6.66574952,9.92071787 6.60984175,9.48104267 6.84654232,9.17537638 C7.08324289,8.86971009 7.5229181,8.81380232 7.82858438,9.05050289 L11.1958257,11.658013 L14.6557321,9.04533883 Z ")
//    })
//})
//private let tabImageUnread = tabImageNone.flatMap({ image in
//    return generateImage(image.size, contextGenerator: { size, context in
//        context.clear(CGRect(origin: CGPoint(), size: size))
//        context.draw(image.cgImage!, in: CGRect(origin: CGPoint(), size: size))
//        context.setBlendMode(.copy)
//        context.setFillColor(UIColor.clear.cgColor)
//        context.translateBy(x: 0.0, y: 7.0)
//        let _ = try? drawSvgPath(context, path: "M14.6557321,12.0977948 L11.1958257,9.48512064 L7.82858438,12.0926307 C7.5229181,12.3293313 7.08324289,12.2734235 6.84654232,11.9677572 C6.60984175,11.662091 6.66574952,11.2224158 6.97141581,10.9857152 L10.7618904,8.05046348 C11.0117095,7.85700968 11.3601561,7.85489378 11.612306,8.04529942 L15.4993947,10.9805511 C15.807913,11.2135221 15.8691562,11.6524859 15.6361852,11.9610043 C15.4032142,12.2695226 14.9642504,12.3307658 14.6557321,12.0977948 Z ")
//    })
//})

public class ChatListController: TelegramController, KeyShortcutResponder, UIViewControllerPreviewingDelegate {
    private var validLayout: ContainerViewLayout?
    
    private let account: Account
    private let controlsHistoryPreload: Bool
    
    public let groupId: PeerGroupId?
    
    let openMessageFromSearchDisposable: MetaDisposable = MetaDisposable()
    
    private var chatListDisplayNode: ChatListControllerNode {
        return super.displayNode as! ChatListControllerNode
    }
    
    private let titleView: NetworkStatusTitleView
    private var proxyUnavailableTooltipController: TooltipController?
    private var didShowProxyUnavailableTooltipController = false
    
    private var titleDisposable: Disposable?
    private var badgeDisposable: Disposable?
    private var badgeIconDisposable: Disposable?
    
    private var dismissSearchOnDisappear = false
    
    private var didSetup3dTouch = false
    
    private var passcodeLockTooltipDisposable = MetaDisposable()
    private var didShowPasscodeLockTooltipController = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    public init(account: Account, groupId: PeerGroupId?, controlsHistoryPreload: Bool) {
        self.account = account
        self.controlsHistoryPreload = controlsHistoryPreload
        
        self.groupId = groupId
        
        self.presentationData = (account.telegramApplicationContext.currentPresentationData.with { $0 })
        
        self.titleView = NetworkStatusTitleView(theme: self.presentationData.theme)
        
        super.init(account: account, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .always, locationBroadcastPanelSource: .summary)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        if groupId == nil {
            self.navigationBar?.item = nil
        
            self.titleView.title = NetworkStatusTitle(text: self.presentationData.strings.DialogList_Title, activity: false, hasProxy: false, connectsViaProxy: false, isPasscodeSet: false, isManuallyLocked: false)
            self.navigationItem.titleView = self.titleView
            self.tabBarItem.title = self.presentationData.strings.DialogList_Title
            
            let icon = UIImage(bundleImageName: "Chat List/Tabs/IconChats")
            self.tabBarItem.image = icon
            self.tabBarItem.selectedImage = icon
            
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationComposeIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.composePressed))
        } else {
            self.navigationItem.title = "Channels"
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        }
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.DialogList_Title, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            self?.chatListDisplayNode.chatListNode.scrollToPosition(.top)
        }
        self.scrollToTopWithTabBar = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.chatListDisplayNode.searchDisplayController != nil {
                strongSelf.deactivateSearch(animated: true)
            } else {
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
                strongSelf.chatListDisplayNode.chatListNode.scrollToPosition(.auto)
            }
        }
        
        let hasProxy = account.postbox.preferencesView(keys: [PreferencesKeys.proxySettings])
        |> map { preferences -> (Bool, Bool) in
            if let settings = preferences.values[PreferencesKeys.proxySettings] as? ProxySettings {
                return (!settings.servers.isEmpty, settings.enabled)
            } else {
                return (false, false)
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
        
        let passcode = account.postbox.combinedView(keys: [.accessChallengeData])
        |> map { view -> (Bool, Bool) in
            let data = (view.views[.accessChallengeData] as! AccessChallengeDataView).data
            return (data.isLockable, data.autolockDeadline == 0)
        }
        
        self.titleDisposable = (combineLatest(account.networkState |> deliverOnMainQueue, hasProxy |> deliverOnMainQueue, passcode |> deliverOnMainQueue)).start(next: { [weak self] state, proxy, passcode in
            if let strongSelf = self {
                let (hasProxy, connectsViaProxy) = proxy
                let (isPasscodeSet, isManuallyLocked) = passcode
                var checkProxy = false
                switch state {
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
                        let tooltipController = TooltipController(text: "The proxy may be unavailable. Try selecting another one.", timeout: 60.0, dismissByTapOutside: true)
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
        })
        
        self.badgeDisposable = (renderedTotalUnreadCount(postbox: account.postbox) |> deliverOnMainQueue).start(next: { [weak self] count in
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
                let _ = strongSelf.account.postbox.transaction({ transaction -> Void in
                    var data = transaction.getAccessChallengeData()
                    if data.isLockable {
                        if data.autolockDeadline != 0 {
                            data = data.withUpdatedAutolockDeadline(0)
                        } else {
                            data = data.withUpdatedAutolockDeadline(nil)
                        }
                        transaction.setAccessChallengeData(data)
                    }
                }).start()
            }
        }
        
        self.titleView.openProxySettings = { [weak self] in
            if let strongSelf = self {
                (strongSelf.navigationController as? NavigationController)?.pushViewController(proxySettingsController(account: account))
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
        self.badgeIconDisposable?.dispose()
        self.passcodeLockTooltipDisposable.dispose()
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
            self.chatListDisplayNode.updateThemeAndStrings(theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameSortOrder: self.presentationData.nameSortOrder, nameDisplayOrder: self.presentationData.nameDisplayOrder, disableAnimations: self.presentationData.disableAnimations)
        }
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatListControllerNode(account: self.account, groupId: self.groupId, controlsHistoryPreload: self.controlsHistoryPreload, presentationData: self.presentationData)
        
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
                let _ = (strongSelf.account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(peerId)
                } |> deliverOnMainQueue).start(next: { peer in
                    if let strongSelf = self, let peer = peer {
                        let actionSheet = ActionSheetController(presentationTheme: strongSelf.presentationData.theme)
                        var items: [ActionSheetItem] = []
                        var canClear = true
                        var canStop = false
                        if let channel = peer as? TelegramChannel {
                            if case .broadcast = channel.info {
                                canClear = false
                            }
                            if let addressName = channel.addressName, !addressName.isEmpty {
                                canClear = false
                            }
                        } else if let user = peer as? TelegramUser, user.botInfo != nil {
                            canStop = true
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
                        
                        if canStop {
                            items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.DialogList_DeleteBotConversationConfirmation, color: .destructive, action: { [weak actionSheet] in
                                actionSheet?.dismissAnimated()
                                
                                if let strongSelf = self {
                                    let _ = removePeerChat(postbox: strongSelf.account.postbox, peerId: peerId, reportChatSpam: false).start()
                                    let _ = requestUpdatePeerIsBlocked(account: strongSelf.account, peerId: peer.id, isBlocked: true).start()
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
                    }
                })
            }
        }
        
        self.chatListDisplayNode.chatListNode.peerSelected = { [weak self] peerId, animated in
            if let strongSelf = self {
                if let navigationController = strongSelf.navigationController as? NavigationController {
                    /*let _ = (ApplicationSpecificNotice.getProxyAdsAcknowledgment(postbox: strongSelf.account.postbox)
                    |> deliverOnMainQueue).start(next: { value in
                        if !value {
                            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: "The proxy you are using displays a sponsored channel in your chat list.", actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {
                                if let strongSelf = self {
                                    let _ = ApplicationSpecificNotice.setProxyAdsAcknowledgment(postbox: strongSelf.account.postbox).start()
                                }
                            })]), in: .window(.root))
                        }
                    })*/
                    
                    navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(peerId), animated: animated, completion: { [weak self] in
                        self?.chatListDisplayNode.chatListNode.clearHighlightAnimated(true)
                    })
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
        
        self.chatListDisplayNode.requestOpenPeerFromSearch = { [weak self] peer, dismissSearch in
            if let strongSelf = self {
                let storedPeer = strongSelf.account.postbox.transaction { transaction -> Void in
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
                            navigateToChatController(navigationController: navigationController, account: strongSelf.account, chatLocation: .peer(peer.id), purposefulAction: { [weak self] in
                                if let strongSelf = self {
                                    strongSelf.deactivateSearch(animated: false)
                                }
                            })
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
        
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        #if DEBUG
        DispatchQueue.main.async {
            let count = ChatControllerCount.with({ $0 })
            if count != 0 {
                self.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: self.presentationData.theme), title: "", text: "ChatControllerCount \(count)", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]), in: .window(.root))
            }
        }
        #endif
        
        if !self.didSetup3dTouch {
            self.didSetup3dTouch = true
            if #available(iOSApplicationExtension 9.0, *) {
                self.registerForPreviewing(with: self, sourceView: self.view, theme: PeekControllerTheme(presentationTheme: self.presentationData.theme), onlyNative: false)
            }
        }
        
        if let lockViewFrame = self.titleView.lockViewFrame, !self.didShowPasscodeLockTooltipController {
            self.passcodeLockTooltipDisposable.set((combineLatest(ApplicationSpecificNotice.getPasscodeLockTips(postbox: self.account.postbox), account.postbox.combinedView(keys: [.accessChallengeData]) |> take(1))
                |> deliverOnMainQueue).start(next: { [weak self] tooltipValue, passcodeView in
                    if let strongSelf = self {
                        if !tooltipValue {
                            let hasPasscode = (passcodeView.views[.accessChallengeData] as! AccessChallengeDataView).data.isLockable
                            if hasPasscode {
                                let _ = ApplicationSpecificNotice.setPasscodeLockTips(postbox: strongSelf.account.postbox).start()
                                
                                let tooltipController = TooltipController(text: strongSelf.presentationData.strings.DialogList_PasscodeLockHelp, dismissByTapOutside: true)
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
        
        self.validLayout = layout
        
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
                strongSelf.chatListDisplayNode.activateSearch()
                strongSelf.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
            })
        }
    }
    
    func deactivateSearch(animated: Bool) {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: animated ? .animated(duration: 0.5, curve: .spring) : .immediate)
            self.chatListDisplayNode.deactivateSearch(animated: animated)
        }
    }
    
    @objc func composePressed() {
        (self.navigationController as? NavigationController)?.replaceAllButRootController(ComposeController(account: self.account), animated: true)
    }
    
    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
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
            if let (view, action) = searchController.previewViewAndActionAtLocation(location) {
                if let peerId = action as? PeerId, peerId.namespace != Namespaces.Peer.SecretChat {
                    if #available(iOSApplicationExtension 9.0, *) {
                        var sourceRect = view.superview!.convert(view.frame, to: self.view)
                        sourceRect.size.height -= UIScreenPixel
                        previewingContext.sourceRect = sourceRect
                    }
                    
                    let chatController = ChatController(account: self.account, chatLocation: .peer(peerId), mode: .standard(previewing: true))
//                    chatController.peekActions = .remove({ [weak self] in
//                        if let strongSelf = self {
//                            let _ = removeRecentPeer(account: strongSelf.account, peerId: peerId).start()
//                            let searchContainer = strongSelf.chatListDisplayNode.searchDisplayController?.contentNode as? ChatListSearchContainerNode
//                            searchContainer?.removePeerFromTopPeers(peerId)
//                        }
//                    })
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
                case let .peer(_, peer, _, _, _, _, _, _, _):
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
        
        return [
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
    }
}
