import Foundation
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

final class ChatRecentActionsController: ViewController {
    private var controllerNode: ChatRecentActionsControllerNode {
        return self.displayNode as! ChatRecentActionsControllerNode
    }
    
    private let account: Account
    private let peer: Peer
    private var presentationData: PresentationData
    
    private var interaction: ChatRecentActionsInteraction!
    private var panelInteraction: ChatPanelInterfaceInteraction!
    
    private let titleView: ChatRecentActionsTitleView
    
    init(account: Account, peer: Peer) {
        self.account = account
        self.peer = peer
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        self.titleView = ChatRecentActionsTitleView(color: self.presentationData.theme.rootController.navigationBar.primaryTextColor)
        
        super.init(navigationBarTheme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.interaction = ChatRecentActionsInteraction(displayInfoAlert: { [weak self] in
            if let strongSelf = self {
                self?.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: strongSelf.presentationData.strings.Channel_AdminLog_InfoPanelAlertTitle, text: strongSelf.presentationData.strings.Channel_AdminLog_InfoPanelAlertText, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            }
        })
        
        self.panelInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _ in
        }, setupEditMessage: { _ in
        }, beginMessageSelection: { _ in
        }, deleteSelectedMessages: {
        }, forwardSelectedMessages: { [weak self] in
            /*if let strongSelf = self {
                if let forwardMessageIdsSet = strongSelf.interfaceState.selectionState?.selectedIds {
                    let forwardMessageIds = Array(forwardMessageIdsSet).sorted()
             
                    let controller = PeerSelectionController(account: strongSelf.account)
                    controller.peerSelected = { [weak controller] peerId in
                        if let strongSelf = self, let _ = controller {
                            let _ = (strongSelf.account.postbox.modify({ modifier -> Void in
                                modifier.updatePeerChatInterfaceState(peerId, update: { currentState in
                                    if let currentState = currentState as? ChatInterfaceState {
                                        return currentState.withUpdatedForwardMessageIds(forwardMessageIds)
                                    } else {
                                        return ChatInterfaceState().withUpdatedForwardMessageIds(forwardMessageIds)
                                    }
                                })
                            }) |> deliverOnMainQueue).start(completed: {
                                if let strongSelf = self {
                                    strongSelf.updateInterfaceState(animated: false, { $0.withoutSelectionState() })
             
                                    let ready = ValuePromise<Bool>()
             
                                    strongSelf.messageContextDisposable.set((ready.get() |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                        if let strongController = controller {
                                            strongController.dismiss()
                                        }
                                    }))
             
                                    (strongSelf.navigationController as? NavigationController)?.replaceTopController(ChatController(account: strongSelf.account, chatLocation: .peer(peerId)), animated: false, ready: ready)
                                }
                            })
                        }
                    }
                    strongSelf.present(controller, in: .window(.root))
                }
            }*/
        }, shareSelectedMessages: { [weak self] in
            /*if let strongSelf = self, let selectedIds = strongSelf.interfaceState.selectionState?.selectedIds, !selectedIds.isEmpty {
                let _ = (strongSelf.account.postbox.modify { modifier -> [Message] in
                    var messages: [Message] = []
                    for id in selectedIds {
                        if let message = modifier.getMessage(id) {
                            messages.append(message)
                        }
                    }
                    return messages
                    } |> deliverOnMainQueue).start(next: { messages in
                        if let strongSelf = self, !messages.isEmpty {
                            strongSelf.updateInterfaceState(animated: true, {
                                $0.withoutSelectionState()
                            })
             
                            let shareController = ShareController(account: strongSelf.account, subject: .messages(messages.sorted(by: { lhs, rhs in
                                return MessageIndex(lhs) < MessageIndex(rhs)
                            })), externalShare: true, immediateExternalShare: true)
                            strongSelf.present(shareController, in: .window(.root))
                        }
                    })
            }*/
        }, updateTextInputState: { _ in
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { _ in
        }, editMessage: {
        }, beginMessageSearch: { _ in
        }, dismissMessageSearch: {
        }, updateMessageSearch: { _ in
        }, navigateMessageSearch: { _ in
        }, openCalendarSearch: {
        }, toggleMembersSearch: { _ in
        }, navigateToMessage: { _ in
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
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _ in
        }, unblockPeer: {
        }, pinMessage: { _ in
        }, unpinMessage: {
        }, reportPeer: {
        }, dismissReportPeer: {
        }, deleteChat: {
        }, beginCall: {
        }, toggleMessageStickerStarred: { _ in
        }, presentController: { _, _ in
        }, navigateFeed: {
        }, openGrouping: {
        }, toggleSilentPost: {
        }, statuses: nil)
        
        self.navigationItem.titleView = self.titleView
        
        let rightButton = ChatNavigationButton(action: .search, buttonItem: UIBarButtonItem(image: PresentationResourcesRootController.navigationSearchIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.activateSearch)))
        self.navigationItem.setRightBarButton(rightButton.buttonItem, animated: false)
        
        self.titleView.title = self.presentationData.strings.Channel_AdminLog_TitleAllEvents
        self.titleView.pressed = { [weak self] in
            self?.openFilterSetup()
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChatRecentActionsControllerNode(account: self.account, peer: self.peer, presentationData: self.presentationData, interaction: self.interaction, pushController: { [weak self] c in
            (self?.navigationController as? NavigationController)?.pushViewController(c)
        }, presentController: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
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
        self.present(channelRecentActionsFilterController(account: self.account, peer: self.peer, events: self.controllerNode.filter.events, adminPeerIds: self.controllerNode.filter.adminPeerIds, apply: { [weak self] events, adminPeerIds in
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
