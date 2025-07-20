import Foundation
import UIKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData
import TelegramBaseController
import AccountContext
import AlertUI
import PresentationDataUtils
import ChatPresentationInterfaceState
import ChatNavigationButton
import CounterControllerTitleView
import AdminUserActionsSheet

public final class ChatRecentActionsController: TelegramBaseController {
    private var controllerNode: ChatRecentActionsControllerNode {
        return self.displayNode as! ChatRecentActionsControllerNode
    }
    
    private let context: AccountContext
    private let peer: Peer
    private let initialAdminPeerId: PeerId?
    let starsState: StarsRevenueStats?
    
    private var presentationData: PresentationData
    private var presentationDataPromise = Promise<PresentationData>()
    override public var updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) {
        return (self.presentationData, self.presentationDataPromise.get())
    }
    private var presentationDataDisposable: Disposable?
    private var didSetPresentationData = false
    
    private var panelInteraction: ChatPanelInterfaceInteraction!
    
    private let titleView: CounterControllerTitleView
    private var rightBarButton: ChatNavigationButton?
    
    private var adminsDisposable: Disposable?
    
    public init(context: AccountContext, peer: Peer, adminPeerId: PeerId?, starsState: StarsRevenueStats?) {
        self.context = context
        self.peer = peer
        self.initialAdminPeerId = adminPeerId
        self.starsState = starsState
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.titleView = CounterControllerTitleView(theme: self.presentationData.theme)
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .specific(size: .compact), locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        self.automaticallyControlPresentationContextLayout = false
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.panelInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _, _ in
        }, setupEditMessage: { _, _ in
        }, beginMessageSelection: { _, _ in
        }, cancelMessageSelection: { _ in
        }, deleteSelectedMessages: {
        }, reportSelectedMessages: {
        }, reportMessages: { _, _ in
        }, blockMessageAuthor: { _, _ in
        }, deleteMessages: { _, _, f in
            f(.default)
        }, forwardSelectedMessages: {
        }, forwardCurrentForwardMessages: {
        }, forwardMessages: { _ in
        }, updateForwardOptionsState: { _ in
        }, presentForwardOptions: { _ in
        }, presentReplyOptions: { _ in
        }, presentLinkOptions: { _ in
        }, presentSuggestPostOptions: {
        }, shareSelectedMessages: {
        }, updateTextInputStateAndMode: { _ in
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { _ in
        }, openStickers: {
        }, editMessage: {
        }, beginMessageSearch: { _, _ in
        }, dismissMessageSearch: {
        }, updateMessageSearch: { _ in
        }, openSearchResults: {
        }, navigateMessageSearch: { _ in
        }, openCalendarSearch: {
        }, toggleMembersSearch: { _ in
        }, navigateToMessage: { _, _, _, _ in
        }, navigateToChat: { _ in
        }, navigateToProfile: { _ in
        }, openPeerInfo: {
        }, togglePeerNotifications: {
        }, sendContextResult: { _, _, _, _ in
            return false
        }, sendBotCommand: { _, _ in
        }, sendShortcut: { _ in
        }, openEditShortcuts: {
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _, _ in
        }, beginMediaRecording: { _ in
        }, finishMediaRecording: { _ in
        }, stopMediaRecording: {
        }, lockMediaRecording: {
        }, resumeMediaRecording: {
        }, deleteRecordedMedia: {
        }, sendRecordedMedia: { _, _ in
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _, _, _, _, _, _ in
            return false
        }, unblockPeer: {
        }, pinMessage: { _, _ in
        }, unpinMessage: { _, _, _ in
        }, unpinAllMessages: {
        }, openPinnedList: { _ in
        }, shareAccountContact: {
        }, reportPeer: {
        }, presentPeerContact: {
        }, dismissReportPeer: {
        }, deleteChat: {
        }, beginCall: { _ in
        }, toggleMessageStickerStarred: { _ in
        }, presentController: { _, _ in
        }, presentControllerInCurrent: { _, _ in
        }, getNavigationController: {
            return nil
        }, presentGlobalOverlayController: { _, _ in
        }, navigateFeed: {
        }, openGrouping: {
        }, toggleSilentPost: {
        }, requestUnvoteInMessage: { _ in
        }, requestStopPollInMessage: { _ in
        }, updateInputLanguage: { _ in
        }, unarchiveChat: {
        }, openLinkEditing: {  
        }, displaySlowmodeTooltip: { _, _ in
        }, displaySendMessageOptions: { _, _ in
        }, openScheduledMessages: {
        }, openPeersNearby: {
        }, displaySearchResultsTooltip: { _, _ in
        }, unarchivePeer: {
        }, scrollToTop: {
        }, viewReplies: { _, _ in
        }, activatePinnedListPreview: { _, _ in
        }, joinGroupCall: { _ in
        }, presentInviteMembers: {
        }, presentGigagroupHelp: {
        }, openMonoforum: {
        }, editMessageMedia: { _, _ in
        }, updateShowCommands: { _ in
        }, updateShowSendAsPeers: { _ in
        }, openInviteRequests: {
        }, openSendAsPeer: { _, _ in
        }, presentChatRequestAdminInfo: {
        }, displayCopyProtectionTip: { _, _ in
        }, openWebView: { _, _, _, _ in
        }, updateShowWebView: { _ in
        }, insertText: { _ in
        }, backwardsDeleteText: {
        }, restartTopic: {
        }, toggleTranslation: { _ in
        }, changeTranslationLanguage: { _ in
        }, addDoNotTranslateLanguage: { _ in
        }, hideTranslationPanel: {
        }, openPremiumGift: {
        }, openSuggestPost: { _, _ in
        }, openPremiumRequiredForMessaging: {
        }, openStarsPurchase: { _ in
        }, openMessagePayment: {
        }, openBoostToUnrestrict: {
        }, updateRecordingTrimRange: { _, _, _, _ in
        }, dismissAllTooltips: {
        }, editTodoMessage: { _, _, _ in
        }, updateHistoryFilter: { _ in
        }, updateChatLocationThread: { _, _ in
        }, toggleChatSidebarMode: {
        }, updateDisplayHistoryFilterAsList: { _ in
        }, requestLayout: { _ in
        }, chatController: {
            return nil
        }, statuses: nil)
        
        self.navigationItem.titleView = self.titleView
        
        let rightBarButton = ChatNavigationButton(action: .search(hasTags: false), buttonItem: UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.activateSearch)))
        self.rightBarButton = rightBarButton
        
        self.titleView.title = CounterControllerTitle(title: EnginePeer(peer).compactDisplayTitle, counter: self.presentationData.strings.Channel_AdminLog_TitleAllEvents)
        
        let themeEmoticon = self.context.account.postbox.peerView(id: peer.id)
        |> map { view -> String? in
            let cachedData = view.cachedData
            if let cachedData = cachedData as? CachedUserData {
                return cachedData.themeEmoticon
            } else if let cachedData = cachedData as? CachedGroupData {
                return cachedData.themeEmoticon
            } else if let cachedData = cachedData as? CachedChannelData {
                return cachedData.themeEmoticon
            } else {
                return nil
            }
        }
        |> distinctUntilChanged
        
        self.presentationDataDisposable = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, context.engine.themes.getChatThemes(accountManager: context.sharedContext.accountManager, onlyCached: true), themeEmoticon).startStrict(next: { [weak self] presentationData, chatThemes, themeEmoticon in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                var presentationData = presentationData
                if let themeEmoticon = themeEmoticon, let theme = chatThemes.first(where: { $0.emoticon == themeEmoticon }) {
                    if let theme = makePresentationTheme(cloudTheme: theme, dark: presentationData.theme.overallDarkAppearance) {
                        presentationData = presentationData.withUpdated(theme: theme)
                        presentationData = presentationData.withUpdated(chatWallpaper: theme.chat.defaultWallpaper)
                    }
                }
                
                let isFirstTime = !strongSelf.didSetPresentationData
                strongSelf.presentationData = presentationData
                strongSelf.presentationDataPromise.set(.single(presentationData))
                strongSelf.didSetPresentationData = true
                
                if isFirstTime || previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.adminsDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.titleView.theme = self.presentationData.theme
        self.updateTitle()
        
        let rightButton = ChatNavigationButton(action: .search(hasTags: false), buttonItem: UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.activateSearch)))
        self.navigationItem.setRightBarButton(rightButton.buttonItem, animated: false)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatRecentActionsControllerNode(context: self.context, controller: self, peer: self.peer, presentationData: self.presentationData, pushController: { [weak self] c in
            (self?.navigationController as? NavigationController)?.pushViewController(c)
        }, presentController: { [weak self] c, t, a in
            self?.present(c, in: t, with: a, blockInteraction: true)
        }, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        })
        self.controllerNode.isEmptyUpdated = { [weak self] isEmpty in
            guard let self, let rightBarButton = self.rightBarButton else {
                return
            }
            self.navigationItem.setRightBarButton(isEmpty ? nil : rightBarButton.buttonItem, animated: true)
        }
        if let adminPeerId = self.initialAdminPeerId {
            self.controllerNode.updateFilter(events: .all, adminPeerIds: [adminPeerId])
            self.updateTitle()
        }
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        var childrenLayout = layout
        childrenLayout.intrinsicInsets.bottom += 49.0
        self.presentationContext.containerLayoutUpdated(childrenLayout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func activateSearch() {
        if let navigationBar = self.navigationBar {
            if !(navigationBar.contentNode is ChatRecentActionsSearchNavigationContentNode) {
                let searchNavigationNode = ChatRecentActionsSearchNavigationContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, cancel: { [weak self] in
                    self?.deactivateSearch()
                })
            
                navigationBar.setContentNode(searchNavigationNode, animated: true)
                searchNavigationNode.setQueryUpdated({ [weak self] query in
                    self?.controllerNode.updateSearchQuery(query)
                    self?.updateTitle()
                })
                searchNavigationNode.activate()
            }
        }
    }
    
    private func deactivateSearch() {
        self.controllerNode.updateSearchQuery("")
        self.navigationBar?.setContentNode(nil, animated: true)
        self.updateTitle()
    }
    
    private var adminsPromise: Promise<[RenderedChannelParticipant]?>?
    func openFilterSetup() {
        if self.adminsPromise == nil {
            self.adminsPromise = Promise()
            let (disposable, _) = self.context.peerChannelMemberCategoriesContextsManager.admins(engine: self.context.engine, postbox: self.context.account.postbox, network: self.context.account.network, accountPeerId: self.context.account.peerId, peerId: self.peer.id) { membersState in
                if case .loading = membersState.loadingState, membersState.list.isEmpty {
                    self.adminsPromise?.set(.single(nil))
                } else {
                    self.adminsPromise?.set(.single(membersState.list))
                }
            }
            self.adminsDisposable = disposable
        }
        
        guard let adminsPromise = self.adminsPromise else {
            return
        }
        
        let _ = (adminsPromise.get()
        |> filter { $0 != nil }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let self else {
                return
            }
            var adminPeers: [EnginePeer] = []
            if let result {
                for participant in result {
                    adminPeers.append(EnginePeer(participant.peer))
                }
            }
            let controller = RecentActionsSettingsSheet(
                context: self.context,
                peer: EnginePeer(self.peer),
                adminPeers: adminPeers,
                initialValue: RecentActionsSettingsSheet.Value(
                    events: self.controllerNode.filter.events,
                    admins: self.controllerNode.filter.adminPeerIds
                ),
                completion: { [weak self] result in
                    guard let self else {
                        return
                    }
                    self.controllerNode.updateFilter(events: result.events, adminPeerIds: result.admins)
                    self.updateTitle()
                }
            )
            self.push(controller)
        })
    }
    
    private func updateTitle() {
        let title = EnginePeer(self.peer).compactDisplayTitle
        let subtitle: String
        if self.controllerNode.filter.isEmpty {
            subtitle = self.presentationData.strings.Channel_AdminLog_TitleAllEvents
        } else {
            subtitle = self.presentationData.strings.Channel_AdminLog_TitleSelectedEvents
        }
        self.titleView.title = CounterControllerTitle(title: title, counter: subtitle)
    }
}
