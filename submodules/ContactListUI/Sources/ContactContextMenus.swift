import Foundation
import UIKit
import SwiftSignalKit
import ContextUI
import AccountContext
import TelegramCore
import Display
import AlertUI
import PresentationDataUtils
import OverlayStatusController
import LocalizedPeerData

func contactContextMenuItems(context: AccountContext, peerId: EnginePeer.Id, contactsController: ContactsController?) -> Signal<[ContextMenuItem], NoError> {
    let strings = context.sharedContext.currentPresentationData.with({ $0 }).strings
    
    return context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
        TelegramEngine.EngineData.Item.Peer.AreVoiceCallsAvailable(id: peerId),
        TelegramEngine.EngineData.Item.Peer.AreVideoCallsAvailable(id: peerId)
    )
    |> map { [weak contactsController] peer, areVoiceCallsAvailable, areVideoCallsAvailable -> [ContextMenuItem] in
        var items: [ContextMenuItem] = []
        
        items.append(.action(ContextMenuActionItem(text: strings.ContactList_Context_SendMessage, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Message"), color: theme.contextMenu.primaryColor) }, action: { _, f in
            if let contactsController = contactsController, let navigationController = contactsController.navigationController as? NavigationController {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId), peekData: nil))
            }
            f(.default)
        })))
        
        var canStartSecretChat = true
        if case let .user(user) = peer, user.flags.contains(.isSupport) {
            canStartSecretChat = false
        }
        
        if canStartSecretChat {
            items.append(.action(ContextMenuActionItem(text: strings.ContactList_Context_StartSecretChat, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Timer"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                let _ = (context.engine.peers.mostRecentSecretChat(id: peerId)
                |> deliverOnMainQueue).start(next: { currentPeerId in
                    if let currentPeerId = currentPeerId {
                        if let contactsController = contactsController, let navigationController = (contactsController.navigationController as? NavigationController) {
                            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: currentPeerId), peekData: nil))
                        }
                    } else {
                        var createSignal = context.engine.peers.createSecretChat(peerId: peerId)
                        var cancelImpl: (() -> Void)?
                        let progressSignal = Signal<Never, NoError> { subscriber in
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: {
                                cancelImpl?()
                            }))
                            contactsController?.present(controller, in: .window(.root))
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.15, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.start()
                        
                        createSignal = createSignal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                        let createSecretChatDisposable = MetaDisposable()
                        cancelImpl = {
                            createSecretChatDisposable.set(nil)
                        }
                        
                        createSecretChatDisposable.set((createSignal
                        |> deliverOnMainQueue).start(next: { peerId in
                            if let navigationController = (contactsController?.navigationController as? NavigationController) {
                                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(id: peerId), peekData: nil))
                            }
                        }, error: { error in
                            if let contactsController = contactsController {
                                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                let text: String
                                switch error {
                                    case .limitExceeded:
                                        text = presentationData.strings.TwoStepAuth_FloodError
                                    default:
                                        text = presentationData.strings.Login_UnknownError
                                }
                                contactsController.present(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                            }
                        }))
                    }
                })
                f(.default)
            })))
        }
        
        var canCall = true
        if case let .user(user) = peer, (user.flags.contains(.isSupport) || !areVoiceCallsAvailable) {
            canCall = false
        }
        var canVideoCall = false
        if canCall {
            if areVideoCallsAvailable {
                canVideoCall = true
            }
        }
        
        if canCall {
            items.append(.action(ContextMenuActionItem(text: strings.ContactList_Context_Call, icon: { theme in
                generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Call"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                context.requestCall(peerId: peerId, isVideo: false, completion: {})
                f(.default)
            })))
        }
        if canVideoCall {
            items.append(.action(ContextMenuActionItem(text: strings.ContactList_Context_VideoCall, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/VideoCall"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                context.requestCall(peerId: peerId, isVideo: true, completion: {})
                f(.default)
            })))
        }
        return items
    }
}
