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

final class ChatRecentActionsController: TelegramBaseController {
    private var controllerNode: ChatRecentActionsControllerNode {
        return self.displayNode as! ChatRecentActionsControllerNode
    }
    
    private let context: AccountContext
    private let peer: Peer
    private let initialAdminPeerId: PeerId?
    private var presentationData: PresentationData
    private var presentationDataPromise = Promise<PresentationData>()
    override var updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>) {
        return (self.presentationData, self.presentationDataPromise.get())
    }
    private var presentationDataDisposable: Disposable?
    private var didSetPresentationData = false
    
    private var interaction: ChatRecentActionsInteraction!
    private var panelInteraction: ChatPanelInterfaceInteraction!
    
    private let titleView: ChatRecentActionsTitleView
    
    init(context: AccountContext, peer: Peer, adminPeerId: PeerId?) {
        self.context = context
        self.peer = peer
        self.initialAdminPeerId = adminPeerId
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.titleView = ChatRecentActionsTitleView(color: self.presentationData.theme.rootController.navigationBar.primaryTextColor)
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .specific(size: .compact), locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        self.automaticallyControlPresentationContextLayout = false
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.interaction = ChatRecentActionsInteraction(displayInfoAlert: { [weak self] in
            if let strongSelf = self {
                let text: String
                if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                    text = strongSelf.presentationData.strings.Channel_AdminLog_InfoPanelChannelAlertText
                } else {
                    text = strongSelf.presentationData.strings.Channel_AdminLog_InfoPanelAlertText
                }
                self?.present(textAlertController(context: strongSelf.context, updatedPresentationData: strongSelf.updatedPresentationData, title: strongSelf.presentationData.strings.Channel_AdminLog_InfoPanelAlertTitle, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }
        })
        
        self.panelInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _, _ in
        }, setupEditMessage: { _, _ in
        }, beginMessageSelection: { _, _ in
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
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _, _ in
        }, beginMediaRecording: { _ in
        }, finishMediaRecording: { _ in
        }, stopMediaRecording: {
        }, lockMediaRecording: {
        }, deleteRecordedMedia: {
        }, sendRecordedMedia: { _ in
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _, _, _, _ in
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
        }, reportPeerIrrelevantGeoLocation: {
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
        }, editMessageMedia: { _, _ in
        }, updateShowCommands: { _ in
        }, updateShowSendAsPeers: { _ in
        }, openInviteRequests: {
        }, openSendAsPeer: { _, _ in
        }, presentChatRequestAdminInfo: {
        }, displayCopyProtectionTip: { _, _ in
        }, openWebView: { _, _, _, _ in
        }, updateShowWebView: { _ in
        }, chatController: {
            return nil
        }, statuses: nil)
        
        self.navigationItem.titleView = self.titleView
        
        let rightButton = ChatNavigationButton(action: .search, buttonItem: UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.activateSearch)))
        self.navigationItem.setRightBarButton(rightButton.buttonItem, animated: false)
        
        self.titleView.title = self.presentationData.strings.Channel_AdminLog_TitleAllEvents
        self.titleView.pressed = { [weak self] in
            self?.openFilterSetup()
        }
        
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
        
        self.presentationDataDisposable = combineLatest(queue: Queue.mainQueue(), context.sharedContext.presentationData, context.engine.themes.getChatThemes(accountManager: context.sharedContext.accountManager, onlyCached: true), themeEmoticon).start(next: { [weak self] presentationData, chatThemes, themeEmoticon in
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
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateThemeAndStrings() {
        self.titleView.color = self.presentationData.theme.rootController.navigationBar.primaryTextColor
        self.updateTitle()
        
        let rightButton = ChatNavigationButton(action: .search, buttonItem: UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.activateSearch)))
        self.navigationItem.setRightBarButton(rightButton.buttonItem, animated: false)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChatRecentActionsControllerNode(context: self.context, controller: self, peer: self.peer, presentationData: self.presentationData, interaction: self.interaction, pushController: { [weak self] c in
            (self?.navigationController as? NavigationController)?.pushViewController(c)
        }, presentController: { [weak self] c, t, a in
            self?.present(c, in: t, with: a, blockInteraction: true)
        }, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        })
        
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
    
    @objc func activateSearch() {
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
    
    private func openFilterSetup() {
        self.present(channelRecentActionsFilterController(context: self.context, updatedPresentationData: self.updatedPresentationData, peer: self.peer, events: self.controllerNode.filter.events, adminPeerIds: self.controllerNode.filter.adminPeerIds, apply: { [weak self] events, adminPeerIds in
            self?.controllerNode.updateFilter(events: events, adminPeerIds: adminPeerIds)
            self?.updateTitle()
        }), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    
    private func updateTitle() {
        if self.controllerNode.filter.isEmpty {
            self.titleView.title = self.presentationData.strings.Channel_AdminLog_TitleAllEvents
        } else {
            self.titleView.title = self.presentationData.strings.Channel_AdminLog_TitleSelectedEvents
        }
    }
}
