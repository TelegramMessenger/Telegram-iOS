import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatPresentationInterfaceState
import ContextUI

func presentChatForwardOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode) {
    guard let peerId = selfController.chatLocation.peerId else {
        return
    }
    let presentationData = selfController.presentationData
    
    let forwardOptions = selfController.presentationInterfaceStatePromise.get()
    |> map { state -> ChatControllerSubject.ForwardOptions in
        var hideNames = state.interfaceState.forwardOptionsState?.hideNames ?? false
        if peerId.namespace == Namespaces.Peer.SecretChat {
            hideNames = true
        }
        return ChatControllerSubject.ForwardOptions(hideNames: hideNames, hideCaptions: state.interfaceState.forwardOptionsState?.hideCaptions ?? false)
    }
    |> distinctUntilChanged
    
    let chatController = selfController.context.sharedContext.makeChatController(context: selfController.context, chatLocation: .peer(id: peerId), subject: .messageOptions(peerIds: [peerId], ids: selfController.presentationInterfaceState.interfaceState.forwardMessageIds ?? [], info: ChatControllerSubject.MessageOptionsInfo(kind: .forward), options: forwardOptions), botStart: nil, mode: .standard(previewing: true))
    chatController.canReadHistory.set(false)
    
    let messageIds = selfController.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
    let messagesCount: Signal<Int, NoError>
    if let chatController = chatController as? ChatControllerImpl, messageIds.count > 1 {
        messagesCount = .single(messageIds.count)
        |> then(
            chatController.presentationInterfaceStatePromise.get()
            |> map { state -> Int in
                return state.interfaceState.selectionState?.selectedIds.count ?? 1
            }
        )
    } else {
        messagesCount = .single(1)
    }
    
    let accountPeerId = selfController.context.account.peerId
    let items = combineLatest(forwardOptions, selfController.context.account.postbox.messagesAtIds(messageIds), messagesCount)
    |> deliverOnMainQueue
    |> map { [weak selfController] forwardOptions, messages, messagesCount -> [ContextMenuItem] in
        guard let selfController else {
            return []
        }
        var items: [ContextMenuItem] = []
        
        var hasCaptions = false
        var uniquePeerIds = Set<PeerId>()
        
        var hasOther = false
        var hasNotOwnMessages = false
        for message in messages {
            if let author = message.effectiveAuthor {
                if !uniquePeerIds.contains(author.id) {
                    uniquePeerIds.insert(author.id)
                }
                if message.id.peerId == accountPeerId && message.forwardInfo == nil {
                } else {
                    hasNotOwnMessages = true
                }
            }
            
            var isDice = false
            var isMusic = false
            for media in message.media {
                if let media = media as? TelegramMediaFile, media.isMusic {
                    isMusic = true
                } else if media is TelegramMediaDice {
                    isDice = true
                } else {
                    if !message.text.isEmpty {
                        if media is TelegramMediaImage || media is TelegramMediaFile {
                            hasCaptions = true
                        }
                    }
                }
            }
            if !isDice && !isMusic {
                hasOther = true
            }
        }
        
        var canHideNames = hasNotOwnMessages && hasOther
        if case let .peer(peerId) = selfController.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
            canHideNames = false
        }
        let hideNames = forwardOptions.hideNames
        let hideCaptions = forwardOptions.hideCaptions
        
        if canHideNames {
            items.append(.action(ContextMenuActionItem(text: uniquePeerIds.count == 1 ? presentationData.strings.Conversation_ForwardOptions_ShowSendersName : presentationData.strings.Conversation_ForwardOptions_ShowSendersNames, icon: { theme in
                if hideNames {
                    return nil
                } else {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }
            }, action: { [weak selfController] _, f in
                selfController?.interfaceInteraction?.updateForwardOptionsState({ current in
                    var updated = current
                    updated.hideNames = false
                    updated.hideCaptions = false
                    updated.unhideNamesOnCaptionChange = false
                    return updated
                })
            })))
            
            items.append(.action(ContextMenuActionItem(text: uniquePeerIds.count == 1 ? presentationData.strings.Conversation_ForwardOptions_HideSendersName : presentationData.strings.Conversation_ForwardOptions_HideSendersNames, icon: { theme in
                if hideNames {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                } else {
                    return nil
                }
            }, action: { [weak selfController] _, f in
                selfController?.interfaceInteraction?.updateForwardOptionsState({ current in
                    var updated = current
                    updated.hideNames = true
                    updated.unhideNamesOnCaptionChange = false
                    return updated
                })
            })))
            
            items.append(.separator)
        }
        
        if hasCaptions {
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_ShowCaption, icon: { theme in
                if hideCaptions {
                    return nil
                } else {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }
            }, action: { [weak selfController] _, f in
                selfController?.interfaceInteraction?.updateForwardOptionsState({ current in
                    var updated = current
                    updated.hideCaptions = false
                    if canHideNames {
                        if updated.unhideNamesOnCaptionChange {
                            updated.unhideNamesOnCaptionChange = false
                            updated.hideNames = false
                        }
                    }
                    return updated
                })
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_HideCaption, icon: { theme in
                if hideCaptions {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                } else {
                    return nil
                }
            }, action: { [weak selfController] _, f in
                selfController?.interfaceInteraction?.updateForwardOptionsState({ current in
                    var updated = current
                    updated.hideCaptions = true
                    if canHideNames {
                        if !updated.hideNames {
                            updated.hideNames = true
                            updated.unhideNamesOnCaptionChange = true
                        }
                    }
                    return updated
                })
            })))
            
            items.append(.separator)
        }
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_ChangeRecipient, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { [weak selfController] c, f in
            selfController?.interfaceInteraction?.forwardCurrentForwardMessages()
            
            f(.default)
        })))
        
        items.append(.action(ContextMenuActionItem(text: messagesCount == 1 ? presentationData.strings.Conversation_ForwardOptions_SendMessage : presentationData.strings.Conversation_ForwardOptions_SendMessages, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Resend"), color: theme.contextMenu.primaryColor) }, action: { [weak selfController, weak chatController] c, f in
            guard let selfController else {
                return
            }
            if let selectedMessageIds = (chatController as? ChatControllerImpl)?.selectedMessageIds {
                var forwardMessageIds = selfController.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
                forwardMessageIds = forwardMessageIds.filter { selectedMessageIds.contains($0) }
                selfController.updateChatPresentationInterfaceState(interactive: false, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(forwardMessageIds) }) })
            }
            
            selfController.controllerInteraction?.sendCurrentMessage(false)
            
            f(.default)
        })))
        
        return items
    }
    
    selfController.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()

    selfController.canReadHistory.set(false)
    
    let contextController = ContextController(presentationData: selfController.presentationData, source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)), items: items |> map { ContextController.Items(content: .list($0)) })
    contextController.dismissed = { [weak selfController] in
        selfController?.canReadHistory.set(true)
    }
    contextController.dismissedForCancel = { [weak selfController, weak chatController] in
        guard let selfController else {
            return
        }
        if let selectedMessageIds = (chatController as? ChatControllerImpl)?.selectedMessageIds {
            var forwardMessageIds = selfController.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
            forwardMessageIds = forwardMessageIds.filter { selectedMessageIds.contains($0) }
            selfController.updateChatPresentationInterfaceState(interactive: false, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(forwardMessageIds) }) })
        }
    }
    contextController.immediateItemsTransitionAnimation = true
    selfController.presentInGlobalOverlay(contextController)
}


func presentChatReplyOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode) {
    guard let peerId = selfController.chatLocation.peerId else {
        return
    }
    guard let replySubject = selfController.presentationInterfaceState.interfaceState.replyMessageSubject else {
        return
    }
    
    //let presentationData = selfController.presentationData
    
    let chatController = selfController.context.sharedContext.makeChatController(context: selfController.context, chatLocation: .peer(id: peerId), subject: .messageOptions(peerIds: [replySubject.messageId.peerId], ids: [replySubject.messageId], info: ChatControllerSubject.MessageOptionsInfo(kind: .reply), options: .single(ChatControllerSubject.ForwardOptions(hideNames: false, hideCaptions: false))), botStart: nil, mode: .standard(previewing: true))
    chatController.canReadHistory.set(false)
    
    let messageIds: [EngineMessage.Id] = [replySubject.messageId]
    let messagesCount: Signal<Int, NoError> = .single(1)
    
    //let accountPeerId = selfController.context.account.peerId
    let items = combineLatest(selfController.context.account.postbox.messagesAtIds(messageIds), messagesCount)
    |> deliverOnMainQueue
    |> map { [weak selfController] messages, messagesCount -> [ContextMenuItem] in
        guard let selfController else {
            return []
        }
        var items: [ContextMenuItem] = []
        
        //TODO:localize
        items.append(.action(ContextMenuActionItem(text: "Reply in Another Chat", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { [weak selfController] c, f in
            selfController?.interfaceInteraction?.forwardCurrentForwardMessages()
            
            f(.default)
        })))
        
        return items
    }
    
    selfController.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()

    selfController.canReadHistory.set(false)
    
    let contextController = ContextController(presentationData: selfController.presentationData, source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)), items: items |> map { ContextController.Items(content: .list($0)) })
    contextController.dismissed = { [weak selfController] in
        selfController?.canReadHistory.set(true)
    }
    contextController.dismissedForCancel = { [weak selfController, weak chatController] in
        guard let selfController else {
            return
        }
        if let selectedMessageIds = (chatController as? ChatControllerImpl)?.selectedMessageIds {
            var forwardMessageIds = selfController.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
            forwardMessageIds = forwardMessageIds.filter { selectedMessageIds.contains($0) }
            selfController.updateChatPresentationInterfaceState(interactive: false, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(forwardMessageIds) }) })
        }
    }
    contextController.immediateItemsTransitionAnimation = true
    selfController.presentInGlobalOverlay(contextController)
}
