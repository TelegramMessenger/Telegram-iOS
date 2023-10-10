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
import ChatInterfaceState
import PresentationDataUtils
import ChatMessageTextBubbleContentNode

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
        return ChatControllerSubject.ForwardOptions(hideNames: hideNames, hideCaptions: state.interfaceState.forwardOptionsState?.hideCaptions ?? false, replyOptions: nil)
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

private func generateChatReplyOptionItems(selfController: ChatControllerImpl, chatController: ChatControllerImpl) -> Signal<ContextController.Items, NoError> {
    guard let replySubject = selfController.presentationInterfaceState.interfaceState.replyMessageSubject else {
        return .complete()
    }
    
    let messageIds: [EngineMessage.Id] = [replySubject.messageId]
    let messagesCount: Signal<Int, NoError> = .single(1)
    
    let items = combineLatest(selfController.context.account.postbox.messagesAtIds(messageIds), messagesCount)
    |> deliverOnMainQueue
    |> map { [weak selfController, weak chatController] messages, messagesCount -> [ContextMenuItem] in
        guard let selfController, let chatController else {
            return []
        }
        var items: [ContextMenuItem] = []
        
        if replySubject.quote != nil {
            //TODO:localize
            items.append(.action(ContextMenuActionItem(text: "Quote Selected Part", icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/QuoteSelected"), color: theme.contextMenu.primaryColor)
            }, action: { [weak selfController, weak chatController] _, f in
                guard let selfController, let chatController else {
                    return
                }
                
                var messageItemNode: ChatMessageItemView?
                chatController.chatDisplayNode.historyNode.enumerateItemNodes { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item, item.message.id == replySubject.messageId {
                        messageItemNode = itemNode
                    }
                    return true
                }
                var targetContentNode: ChatMessageTextBubbleContentNode?
                if let messageItemNode = messageItemNode as? ChatMessageBubbleItemNode {
                    for contentNode in messageItemNode.contentNodes {
                        if let contentNode = contentNode as? ChatMessageTextBubbleContentNode {
                            targetContentNode = contentNode
                            break
                        }
                    }
                }
                guard let contentNode = targetContentNode else {
                    return
                }
                guard let textSelection = contentNode.getCurrentTextSelection() else {
                    return
                }
                
                selfController.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(ChatInterfaceState.ReplyMessageSubject(messageId: replySubject.messageId, quote: EngineMessageReplyQuote(text: textSelection.text, entities: textSelection.entities))).withoutSelectionState() }) })
                
                f(.default)
            })))
        } else {
            //TODO:localize
            items.append(.action(ContextMenuActionItem(text: "Select Specific Quote", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Quote"), color: theme.contextMenu.primaryColor) }, action: { [weak selfController, weak chatController] c, _ in
                guard let selfController, let chatController else {
                    return
                }
                var messageItemNode: ChatMessageItemView?
                chatController.chatDisplayNode.historyNode.enumerateItemNodes { itemNode in
                    if let itemNode = itemNode as? ChatMessageItemView, let item = itemNode.item, item.message.id == replySubject.messageId {
                        messageItemNode = itemNode
                    }
                    return true
                }
                if let messageItemNode = messageItemNode as? ChatMessageBubbleItemNode {
                    for contentNode in messageItemNode.contentNodes {
                        if let contentNode = contentNode as? ChatMessageTextBubbleContentNode {
                            contentNode.beginTextSelection(range: nil)
                            
                            var subItems: [ContextMenuItem] = []
                            
                            subItems.append(.action(ContextMenuActionItem(text: selfController.presentationData.strings.Common_Back, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor)
                            }, iconPosition: .left, action: { [weak selfController, weak chatController] c, _ in
                                guard let selfController, let chatController else {
                                    return
                                }
                                c.setItems(generateChatReplyOptionItems(selfController: selfController, chatController: chatController), minHeight: nil, previousActionsTransition: .slide(forward: false))
                                //c.popItems()
                            })))
                            subItems.append(.separator)
                            
                            //TODO:localize
                            subItems.append(.action(ContextMenuActionItem(text: "Quote Selected Part", icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/QuoteSelected"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak selfController, weak contentNode] _, f in
                                guard let selfController, let contentNode else {
                                    return
                                }
                                guard let textSelection = contentNode.getCurrentTextSelection() else {
                                    return
                                }
                                
                                selfController.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(ChatInterfaceState.ReplyMessageSubject(messageId: replySubject.messageId, quote: EngineMessageReplyQuote(text: textSelection.text, entities: textSelection.entities))).withoutSelectionState() }) })
                                
                                f(.default)
                            })))
                            
                            //c.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
                            
                            let minHeight = c.getActionsMinHeight()
                            c.immediateItemsTransitionAnimation = false
                            c.setItems(.single(ContextController.Items(content: .list(subItems))), minHeight: minHeight, previousActionsTransition: .slide(forward: true))
                            
                            break
                        }
                    }
                }
            })))
        }
        
        //TODO:localize
        items.append(.action(ContextMenuActionItem(text: "Reply in Another Chat", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor) }, action: { [weak selfController] c, f in
            f(.default)
            
            guard let selfController else {
                return
            }
            guard let replySubject = selfController.presentationInterfaceState.interfaceState.replyMessageSubject else {
                return
            }
            moveReplyMessageToAnotherChat(selfController: selfController, replySubject: replySubject)
        })))
        
        if replySubject.quote != nil {
            items.append(.action(ContextMenuActionItem(text: "Remove Quote", textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/QuoteRemove"), color: theme.contextMenu.destructiveColor) }, action: { [weak selfController] c, f in
                f(.default)
                
                guard let selfController else {
                    return
                }
                var replySubject = replySubject
                replySubject.quote = nil
                selfController.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(replySubject).withoutSelectionState() }).updatedSearch(nil) })
            })))
        }
        
        return items
    }
    
    var tip: ContextController.Tip?
    if "".isEmpty {
        tip = .quoteSelection
    }
    return items |> map { ContextController.Items(content: .list($0), tip: tip) }
}

func presentChatReplyOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode) {
    guard let peerId = selfController.chatLocation.peerId else {
        return
    }
    guard let replySubject = selfController.presentationInterfaceState.interfaceState.replyMessageSubject else {
        return
    }
    
    let replyOptionsSubject = Promise<ChatControllerSubject.ForwardOptions>()
    replyOptionsSubject.set(.single(ChatControllerSubject.ForwardOptions(hideNames: false, hideCaptions: false, replyOptions: ChatControllerSubject.ReplyOptions(hasQuote: replySubject.quote != nil))))
    
    //let presentationData = selfController.presentationData
    
    var replyQuote: ChatControllerSubject.MessageOptionsInfo.ReplyQuote?
    if let quote = replySubject.quote {
        replyQuote = ChatControllerSubject.MessageOptionsInfo.ReplyQuote(messageId: replySubject.messageId, text: quote.text)
    }
    guard let chatController = selfController.context.sharedContext.makeChatController(context: selfController.context, chatLocation: .peer(id: peerId), subject: .messageOptions(peerIds: [replySubject.messageId.peerId], ids: [replySubject.messageId], info: ChatControllerSubject.MessageOptionsInfo(kind: .reply(initialQuote: replyQuote)), options: replyOptionsSubject.get()), botStart: nil, mode: .standard(previewing: true)) as? ChatControllerImpl else {
        return
    }
    chatController.canReadHistory.set(false)
    
    let items = generateChatReplyOptionItems(selfController: selfController, chatController: chatController)
    
    selfController.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()

    selfController.canReadHistory.set(false)
    
    let contextController = ContextController(presentationData: selfController.presentationData, source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)), items: items)
    contextController.dismissed = { [weak selfController] in
        selfController?.canReadHistory.set(true)
    }
    contextController.dismissedForCancel = {
    }
    contextController.immediateItemsTransitionAnimation = true
    selfController.presentInGlobalOverlay(contextController)
    
    chatController.performTextSelectionAction = { [weak selfController, weak contextController] message, canCopy, text, action in
        guard let selfController, let contextController else {
            return
        }
        
        contextController.dismiss()
        
        selfController.controllerInteraction?.performTextSelectionAction(message, canCopy, text, action)
    }
}

func moveReplyMessageToAnotherChat(selfController: ChatControllerImpl, replySubject: ChatInterfaceState.ReplyMessageSubject) {
    let _ = selfController.presentVoiceMessageDiscardAlert(action: { [weak selfController] in
        guard let selfController else {
            return
        }
        let filter: ChatListNodePeersFilter = [.onlyWriteable, .includeSavedMessages, .excludeDisabled, .doNotSearchMessages]
        var attemptSelectionImpl: ((EnginePeer) -> Void)?
        let controller = selfController.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(
            context: selfController.context,
            updatedPresentationData: selfController.updatedPresentationData,
            filter: filter,
            hasFilters: true,
            title: "Reply in...", //TODO:localize
            attemptSelection: { peer, _ in
                attemptSelectionImpl?(peer)
            },
            multipleSelection: false,
            forwardedMessageIds: [],
            selectForumThreads: true
        ))
        let context = selfController.context
        attemptSelectionImpl = { [weak selfController, weak controller] peer in
            guard let selfController, let controller = controller else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            controller.present(textAlertController(context: context, updatedPresentationData: selfController.updatedPresentationData, title: nil, text: presentationData.strings.Forward_ErrorDisabledForChat, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }
        controller.peerSelected = { [weak selfController, weak controller] peer, threadId in
            guard let selfController, let strongController = controller else {
                return
            }
            let peerId = peer.id
            //let accountPeerId = selfController.context.account.peerId
            
            var isPinnedMessages = false
            if case .pinnedMessages = selfController.presentationInterfaceState.subject {
                isPinnedMessages = true
            }
            
            if case .peer(peerId) = selfController.chatLocation, selfController.parentController == nil, !isPinnedMessages {
                selfController.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(replySubject).withoutSelectionState() }).updatedSearch(nil) })
                selfController.updateItemNodesSearchTextHighlightStates()
                selfController.searchResultsController = nil
                strongController.dismiss()
            } else {
                if let navigationController = selfController.navigationController as? NavigationController {
                    for controller in navigationController.viewControllers {
                        if let maybeChat = controller as? ChatControllerImpl {
                            if case .peer(peerId) = maybeChat.chatLocation {
                                var isChatPinnedMessages = false
                                if case .pinnedMessages = maybeChat.presentationInterfaceState.subject {
                                    isChatPinnedMessages = true
                                }
                                if !isChatPinnedMessages {
                                    maybeChat.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(replySubject).withoutSelectionState() }) })
                                    selfController.dismiss()
                                    strongController.dismiss()
                                    return
                                }
                            }
                        }
                    }
                }

                let _ = (ChatInterfaceState.update(engine: selfController.context.engine, peerId: peerId, threadId: threadId, { currentState in
                    return currentState.withUpdatedReplyMessageSubject(replySubject)
                })
                |> deliverOnMainQueue).startStandalone(completed: { [weak selfController] in
                    guard let selfController else {
                        return
                    }
                    let proceed: (ChatController) -> Void = { [weak selfController] chatController in
                        guard let selfController else {
                            return
                        }
                        selfController.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(nil).withoutSelectionState() }) })
                        
                        let navigationController: NavigationController?
                        if let parentController = selfController.parentController {
                            navigationController = (parentController.navigationController as? NavigationController)
                        } else {
                            navigationController = selfController.effectiveNavigationController
                        }
                        
                        if let navigationController = navigationController {
                            var viewControllers = navigationController.viewControllers
                            if threadId != nil {
                                viewControllers.insert(chatController, at: viewControllers.count - 2)
                            } else {
                                viewControllers.insert(chatController, at: viewControllers.count - 1)
                            }
                            navigationController.setViewControllers(viewControllers, animated: false)
                            
                            selfController.controllerNavigationDisposable.set((chatController.ready.get()
                            |> SwiftSignalKit.filter { $0 }
                            |> take(1)
                            |> deliverOnMainQueue).startStrict(next: { [weak navigationController] _ in
                                viewControllers.removeAll(where: { $0 is PeerSelectionController })
                                navigationController?.setViewControllers(viewControllers, animated: true)
                            }))
                        }
                    }
                    if let threadId = threadId {
                        let _ = (selfController.context.sharedContext.chatControllerForForumThread(context: selfController.context, peerId: peerId, threadId: threadId)
                        |> deliverOnMainQueue).startStandalone(next: { chatController in
                            proceed(chatController)
                        })
                    } else {
                        proceed(ChatControllerImpl(context: selfController.context, chatLocation: .peer(id: peerId)))
                    }
                })
            }
        }
        selfController.chatDisplayNode.dismissInput()
        selfController.effectiveNavigationController?.pushViewController(controller)
    })
}
