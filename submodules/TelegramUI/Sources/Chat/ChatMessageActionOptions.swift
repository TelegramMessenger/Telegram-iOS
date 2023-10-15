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
import TextFormat
import ChatMessageItemView
import ChatMessageBubbleItemNode

private enum OptionsId: Hashable {
    case reply
    case forward
    case link
}

private func presentChatInputOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode, initialId: OptionsId) {
    var getContextController: (() -> ContextController?)?
    
    var sources: [ContextController.Source] = []
    
    let replySelectionState = Promise<ChatControllerSubject.MessageOptionsInfo.SelectionState>(ChatControllerSubject.MessageOptionsInfo.SelectionState(quote: nil))
    
    if let source = chatReplyOptions(selfController: selfController, sourceNode: sourceNode, getContextController: {
        return getContextController?()
    }, selectionState: replySelectionState) {
        sources.append(source)
    }
    
    var forwardDismissedForCancel: (() -> Void)?
    if let (source, dismissedForCancel) = chatForwardOptions(selfController: selfController, sourceNode: sourceNode, getContextController: {
        return getContextController?()
    }) {
        forwardDismissedForCancel = dismissedForCancel
        sources.append(source)
    }
    
    if let source = chatLinkOptions(selfController: selfController, sourceNode: sourceNode, getContextController: {
        return getContextController?()
    }, replySelectionState: replySelectionState) {
        sources.append(source)
    }
    
    if sources.isEmpty {
        return
    }
    
    selfController.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()

    selfController.canReadHistory.set(false)
    
    let contextController = ContextController(
        presentationData: selfController.presentationData,
        configuration: ContextController.Configuration(
            sources: sources,
            initialId: AnyHashable(initialId)
        )
    )
    contextController.dismissed = { [weak selfController] in
        selfController?.canReadHistory.set(true)
    }
    
    getContextController = { [weak contextController] in
        return contextController
    }
    
    contextController.dismissedForCancel = {
        forwardDismissedForCancel?()
    }
    
    selfController.presentInGlobalOverlay(contextController)
}

private func chatForwardOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode, getContextController: @escaping () -> ContextController?) -> (ContextController.Source, () -> Void)? {
    guard let peerId = selfController.chatLocation.peerId else {
        return nil
    }
    guard let initialForwardMessageIds = selfController.presentationInterfaceState.interfaceState.forwardMessageIds, !initialForwardMessageIds.isEmpty else {
        return nil
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
    
    let chatController = selfController.context.sharedContext.makeChatController(context: selfController.context, chatLocation: .peer(id: peerId), subject: .messageOptions(peerIds: [peerId], ids: selfController.presentationInterfaceState.interfaceState.forwardMessageIds ?? [], info: .forward(ChatControllerSubject.MessageOptionsInfo.Forward(options: forwardOptions))), botStart: nil, mode: .standard(previewing: true))
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
    
    let dismissedForCancel: () -> Void = { [weak selfController, weak chatController] in
        guard let selfController else {
            return
        }
        if let selectedMessageIds = (chatController as? ChatControllerImpl)?.selectedMessageIds {
            var forwardMessageIds = selfController.presentationInterfaceState.interfaceState.forwardMessageIds ?? []
            forwardMessageIds = forwardMessageIds.filter { selectedMessageIds.contains($0) }
            selfController.updateChatPresentationInterfaceState(interactive: false, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(forwardMessageIds) }) })
        }
    }
    
    //TODO:localize
    return (ContextController.Source(
        id: AnyHashable(OptionsId.forward),
        title: "Forward",
        source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)),
        items: items |> map { ContextController.Items(content: .list($0)) }
    ), dismissedForCancel)
}

func presentChatForwardOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode) {
    presentChatInputOptions(selfController: selfController, sourceNode: sourceNode, initialId: .forward)
}

private func generateChatReplyOptionItems(selfController: ChatControllerImpl, chatController: ChatControllerImpl) -> Signal<ContextController.Items, NoError> {
    guard let replySubject = selfController.presentationInterfaceState.interfaceState.replyMessageSubject else {
        return .complete()
    }
    
    let items = selfController.context.account.postbox.messagesAtIds([replySubject.messageId])
    |> deliverOnMainQueue
    |> map { [weak selfController, weak chatController] messages -> [ContextMenuItem] in
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
                            }, iconPosition: .left, action: { c, _ in
                                c.popItems()
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
                            
                            c.pushItems(items: .single(ContextController.Items(content: .list(subItems), dismissed: { [weak contentNode] in
                                guard let contentNode else {
                                    return
                                }
                                contentNode.cancelTextSelection()
                            })))
                            
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

private func chatReplyOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode, getContextController: @escaping () -> ContextController?, selectionState: Promise<ChatControllerSubject.MessageOptionsInfo.SelectionState>) -> ContextController.Source? {
    guard let peerId = selfController.chatLocation.peerId else {
        return nil
    }
    guard let replySubject = selfController.presentationInterfaceState.interfaceState.replyMessageSubject else {
        return nil
    }
    
    var replyQuote: ChatControllerSubject.MessageOptionsInfo.Quote?
    if let quote = replySubject.quote {
        replyQuote = ChatControllerSubject.MessageOptionsInfo.Quote(messageId: replySubject.messageId, text: quote.text)
    }
    selectionState.set(.single(ChatControllerSubject.MessageOptionsInfo.SelectionState(quote: replyQuote)))
    
    guard let chatController = selfController.context.sharedContext.makeChatController(context: selfController.context, chatLocation: .peer(id: peerId), subject: .messageOptions(peerIds: [replySubject.messageId.peerId], ids: [replySubject.messageId], info: .reply(ChatControllerSubject.MessageOptionsInfo.Reply(quote: replyQuote, selectionState: selectionState))), botStart: nil, mode: .standard(previewing: true)) as? ChatControllerImpl else {
        return nil
    }
    chatController.canReadHistory.set(false)
    
    let items = generateChatReplyOptionItems(selfController: selfController, chatController: chatController)
    
    chatController.performTextSelectionAction = { [weak selfController] message, canCopy, text, action in
        guard let selfController, let contextController = getContextController() else {
            return
        }
        
        contextController.dismiss()
        
        selfController.controllerInteraction?.performTextSelectionAction(message, canCopy, text, action)
    }
    
    //TODO:localize
    return ContextController.Source(
        id: AnyHashable(OptionsId.reply),
        title: "Reply",
        source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)),
        items: items
    )
}

func presentChatReplyOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode) {
    presentChatInputOptions(selfController: selfController, sourceNode: sourceNode, initialId: .reply)
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

private func chatLinkOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode, getContextController: @escaping () -> ContextController?, replySelectionState: Promise<ChatControllerSubject.MessageOptionsInfo.SelectionState>) -> ContextController.Source? {
    guard let peerId = selfController.chatLocation.peerId else {
        return nil
    }
    guard let initialUrlPreview = selfController.presentationInterfaceState.urlPreview else {
        return nil
    }
    
    let linkOptions = combineLatest(queue: .mainQueue(),
        selfController.presentationInterfaceStatePromise.get(),
        replySelectionState.get()
    )
    |> map { state, replySelectionState -> ChatControllerSubject.LinkOptions in
        let urlPreview = state.urlPreview ?? initialUrlPreview
        
        var webpageOptions: TelegramMediaWebpageDisplayOptions = .default
        
        if let (_, webpage) = state.urlPreview, case let .Loaded(content) = webpage.content {
            webpageOptions = content.displayOptions
        }
        
        return ChatControllerSubject.LinkOptions(
            messageText: state.interfaceState.composeInputState.inputText.string,
            messageEntities: generateChatInputTextEntities(state.interfaceState.composeInputState.inputText, generateLinks: true),
            replyMessageId: state.interfaceState.replyMessageSubject?.messageId,
            replyQuote: replySelectionState.quote?.text,
            url: urlPreview.0,
            webpage: urlPreview.1,
            linkBelowText: webpageOptions.position != .aboveText,
            largeMedia: webpageOptions.largeMedia != false
        )
    }
    |> distinctUntilChanged
    
    guard let chatController = selfController.context.sharedContext.makeChatController(context: selfController.context, chatLocation: .peer(id: peerId), subject: .messageOptions(peerIds: [peerId], ids: selfController.presentationInterfaceState.interfaceState.forwardMessageIds ?? [], info: .link(ChatControllerSubject.MessageOptionsInfo.Link(options: linkOptions))), botStart: nil, mode: .standard(previewing: true)) as? ChatControllerImpl else {
        return nil
    }
    chatController.canReadHistory.set(false)
    
    let items = linkOptions
    |> deliverOnMainQueue
    |> map { [weak selfController] linkOptions -> [ContextMenuItem] in
        guard let selfController else {
            return []
        }
        var items: [ContextMenuItem] = []
        
        if "".isEmpty {
            //TODO:localize
            
            items.append(.action(ContextMenuActionItem(text: "Above the Message", icon: { theme in
                if linkOptions.linkBelowText {
                    return nil
                } else {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }
            }, action: { [weak selfController] _, f in
                selfController?.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    guard var urlPreview = state.urlPreview else {
                        return state
                    }
                    if case let .Loaded(content) = urlPreview.1.content {
                        var displayOptions = content.displayOptions
                        displayOptions.position = .aboveText
                        urlPreview = (urlPreview.0, TelegramMediaWebpage(webpageId: urlPreview.1.webpageId, content: .Loaded(content.withDisplayOptions(displayOptions))))
                    }
                    return state.updatedUrlPreview(urlPreview)
                })
            })))
            
            items.append(.action(ContextMenuActionItem(text: "Below the Message", icon: { theme in
                if !linkOptions.linkBelowText {
                    return nil
                } else {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }
            }, action: { [weak selfController] _, f in
                selfController?.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    guard var urlPreview = state.urlPreview else {
                        return state
                    }
                    if case let .Loaded(content) = urlPreview.1.content {
                        var displayOptions = content.displayOptions
                        displayOptions.position = .belowText
                        urlPreview = (urlPreview.0, TelegramMediaWebpage(webpageId: urlPreview.1.webpageId, content: .Loaded(content.withDisplayOptions(displayOptions))))
                    }
                    return state.updatedUrlPreview(urlPreview)
                })
            })))
        }
        
        if "".isEmpty {
            if !items.isEmpty {
                items.append(.separator)
            }
            
            //TODO:localize
            
            items.append(.action(ContextMenuActionItem(text: "Smaller Media", icon: { theme in
                if linkOptions.largeMedia {
                    return nil
                } else {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }
            }, action: { [weak selfController] _, f in
                selfController?.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    guard var urlPreview = state.urlPreview else {
                        return state
                    }
                    if case let .Loaded(content) = urlPreview.1.content {
                        var displayOptions = content.displayOptions
                        displayOptions.largeMedia = false
                        urlPreview = (urlPreview.0, TelegramMediaWebpage(webpageId: urlPreview.1.webpageId, content: .Loaded(content.withDisplayOptions(displayOptions))))
                    }
                    return state.updatedUrlPreview(urlPreview)
                })
            })))
            
            items.append(.action(ContextMenuActionItem(text: "Larger Media", icon: { theme in
                if !linkOptions.largeMedia {
                    return nil
                } else {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                }
            }, action: { [weak selfController] _, f in
                selfController?.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    guard var urlPreview = state.urlPreview else {
                        return state
                    }
                    if case let .Loaded(content) = urlPreview.1.content {
                        var displayOptions = content.displayOptions
                        displayOptions.largeMedia = true
                        urlPreview = (urlPreview.0, TelegramMediaWebpage(webpageId: urlPreview.1.webpageId, content: .Loaded(content.withDisplayOptions(displayOptions))))
                    }
                    return state.updatedUrlPreview(urlPreview)
                })
            })))
        }
        
        if !items.isEmpty {
            items.append(.separator)
        }
        
        //TODO:localize
        items.append(.action(ContextMenuActionItem(text: "Remove Link Preview", textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak selfController, weak chatController] c, f in
            guard let selfController else {
                return
            }
            
            selfController.chatDisplayNode.dismissUrlPreview()
            
            let _ = chatController
            
            f(.default)
        })))
        
        return items
    }
    
    chatController.performOpenURL = { [weak selfController] message, url in
        guard let selfController else {
            return
        }
        
        //TODO:
        //func urlPreviewStateForInputText(_ inputText: NSAttributedString?, context: AccountContext, currentQuery: String?) -> (String?, Signal<(TelegramMediaWebpage?) -> TelegramMediaWebpage?, NoError>)? {
        if let (updatedUrlPreviewUrl, signal) = urlPreviewStateForInputText(NSAttributedString(string: url), context: selfController.context, currentQuery: nil), let updatedUrlPreviewUrl {
            let _ = (signal
            |> deliverOnMainQueue).start(next: { [weak selfController] result in
                guard let selfController else {
                    return
                }
                
                selfController.updateChatPresentationInterfaceState(animated: true, interactive: false, { state in
                    if let webpage = result(nil), var urlPreview = state.urlPreview {
                        if case let .Loaded(content) = urlPreview.1.content, case let .Loaded(newContent) = webpage.content {
                            urlPreview = (updatedUrlPreviewUrl, TelegramMediaWebpage(webpageId: webpage.webpageId, content: .Loaded(newContent.withDisplayOptions(content.displayOptions))))
                        }
                        
                        return state.updatedUrlPreview(urlPreview)
                    } else {
                        return state
                    }
                })
            })
        }
    }
    
    //TODO:localize
    return ContextController.Source(
        id: AnyHashable(OptionsId.link),
        title: "Link",
        source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)),
        items: items |> map { ContextController.Items(content: .list($0)) }
    )
}

func presentChatLinkOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode) {
    presentChatInputOptions(selfController: selfController, sourceNode: sourceNode, initialId: .link)
}
