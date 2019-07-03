import Foundation
import UIKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramPresentationData

final class ChatRecentActionsController: TelegramController {
    private var controllerNode: ChatRecentActionsControllerNode {
        return self.displayNode as! ChatRecentActionsControllerNode
    }
    
    private let context: AccountContext
    private let peer: Peer
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var interaction: ChatRecentActionsInteraction!
    private var panelInteraction: ChatPanelInterfaceInteraction!
    
    private let titleView: ChatRecentActionsTitleView
    
    init(context: AccountContext, peer: Peer) {
        self.context = context
        self.peer = peer
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.titleView = ChatRecentActionsTitleView(color: self.presentationData.theme.rootController.navigationBar.primaryTextColor)
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .specific(size: .compact), locationBroadcastPanelSource: .none)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.interaction = ChatRecentActionsInteraction(displayInfoAlert: { [weak self] in
            if let strongSelf = self {
                self?.present(textAlertController(context: strongSelf.context, title: strongSelf.presentationData.strings.Channel_AdminLog_InfoPanelAlertTitle, text: strongSelf.presentationData.strings.Channel_AdminLog_InfoPanelAlertText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }
        })
        
        self.panelInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _ in
        }, setupEditMessage: { _ in
        }, beginMessageSelection: { _ in
        }, deleteSelectedMessages: {
        }, reportSelectedMessages: {
        }, reportMessages: { _ in
        }, deleteMessages: { _ in
        }, forwardSelectedMessages: {
        }, forwardCurrentForwardMessages: {
        }, forwardMessages: { _ in
        }, shareSelectedMessages: {
        }, updateTextInputStateAndMode: { _ in
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { _ in
        }, openStickers: {
        }, editMessage: {
        }, beginMessageSearch: { _, _ in
        }, dismissMessageSearch: {
        }, updateMessageSearch: { _ in
        }, navigateMessageSearch: { _ in
        }, openCalendarSearch: {
        }, toggleMembersSearch: { _ in
        }, navigateToMessage: { _ in
        }, navigateToChat: { _ in
        }, openPeerInfo: {
        }, togglePeerNotifications: {
        }, sendContextResult: { _, _ in
        }, sendBotCommand: { _, _ in
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _, _ in
        }, beginMediaRecording: { _ in
        }, finishMediaRecording: { _ in
        }, stopMediaRecording: {
        }, lockMediaRecording: {
        }, deleteRecordedMedia: {
        }, sendRecordedMedia: {
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _ in
        }, unblockPeer: {
        }, pinMessage: { _ in
        }, unpinMessage: {
        }, shareAccountContact: {
        }, reportPeer: {
        }, presentPeerContact: {
        }, dismissReportPeer: {
        }, deleteChat: {
        }, beginCall: {
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
        }, statuses: nil)
        
        self.navigationItem.titleView = self.titleView
        
        let rightButton = ChatNavigationButton(action: .search, buttonItem: UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.activateSearch)))
        self.navigationItem.setRightBarButton(rightButton.buttonItem, animated: false)
        
        self.titleView.title = self.presentationData.strings.Channel_AdminLog_TitleAllEvents
        self.titleView.pressed = { [weak self] in
            self?.openFilterSetup()
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
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
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateThemeAndStrings() {
        self.titleView.color = self.presentationData.theme.rootController.navigationBar.primaryTextColor
        self.updateTitle()
        
        let rightButton = ChatNavigationButton(action: .search, buttonItem: UIBarButtonItem(image: PresentationResourcesRootController.navigationCompactSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.activateSearch)))
        self.navigationItem.setRightBarButton(rightButton.buttonItem, animated: false)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChatRecentActionsControllerNode(context: self.context, peer: self.peer, presentationData: self.presentationData, interaction: self.interaction, pushController: { [weak self] c in
            (self?.navigationController as? NavigationController)?.pushViewController(c)
        }, presentController: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a, blockInteraction: true)
        }, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
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
        self.present(channelRecentActionsFilterController(context: self.context, peer: self.peer, events: self.controllerNode.filter.events, adminPeerIds: self.controllerNode.filter.adminPeerIds, apply: { [weak self] events, adminPeerIds in
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
