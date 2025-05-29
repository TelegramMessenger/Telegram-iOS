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
import TelegramNotices
import ChatMessageWebpageBubbleContentNode
import PremiumUI
import UndoUI
import WebsiteType

private enum OptionsId: Hashable {
    case reply
    case forward
    case link
}

private func presentChatInputOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode, initialId: OptionsId) {
    var getContextController: (() -> ContextController?)?
    
    var sources: [ContextController.Source] = []
    
    let replySelectionState = Promise<ChatControllerSubject.MessageOptionsInfo.SelectionState>(ChatControllerSubject.MessageOptionsInfo.SelectionState(canQuote: false, quote: nil))
    
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
    
    let chatController = selfController.context.sharedContext.makeChatController(context: selfController.context, chatLocation: .peer(id: peerId), subject: .messageOptions(peerIds: [peerId], ids: selfController.presentationInterfaceState.interfaceState.forwardMessageIds ?? [], info: .forward(ChatControllerSubject.MessageOptionsInfo.Forward(options: forwardOptions))), botStart: nil, mode: .standard(.previewing), params: nil)
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
        var hasPaid = false
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
                    if !message.text.isEmpty {
                        hasCaptions = true
                    }
                } else if media is TelegramMediaDice {
                    isDice = true
                } else if media is TelegramMediaImage || media is TelegramMediaFile {
                    if !message.text.isEmpty {
                        hasCaptions = true
                    }
                } else if media is TelegramMediaPaidContent {
                    hasPaid = true
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
        if hasPaid {
            canHideNames = false
        }
        let hideNames = forwardOptions.hideNames
        let hideCaptions = forwardOptions.hideCaptions
        
        if canHideNames {
            items.append(.action(ContextMenuActionItem(text: hideNames ? (uniquePeerIds.count == 1 ? presentationData.strings.Conversation_ForwardOptions_ShowSendersName : presentationData.strings.Conversation_ForwardOptions_ShowSendersNames) : (uniquePeerIds.count == 1 ? presentationData.strings.Conversation_ForwardOptions_HideSendersName : presentationData.strings.Conversation_ForwardOptions_HideSendersNames), icon: { _ in
                return nil
            }, iconAnimation: ContextMenuActionItem.IconAnimation(
                name: !hideNames ? "message_preview_person_on" : "message_preview_person_off"
            ), action: { [weak selfController] _, f in
                selfController?.interfaceInteraction?.updateForwardOptionsState({ current in
                    var updated = current
                    if hideNames {
                        updated.hideNames = false
                        updated.hideCaptions = false
                        updated.unhideNamesOnCaptionChange = false
                    } else {
                        updated.hideNames = true
                        updated.unhideNamesOnCaptionChange = false
                    }
                    return updated
                })
            })))
        }
        
        if hasCaptions && !hasPaid {
            items.append(.action(ContextMenuActionItem(text: hideCaptions ? presentationData.strings.Conversation_ForwardOptions_ShowCaption : presentationData.strings.Conversation_ForwardOptions_HideCaption, icon: { _ in
                return nil
            }, iconAnimation: ContextMenuActionItem.IconAnimation(
                name: !hideCaptions ? "message_preview_caption_off" : "message_preview_caption_on"
            ), action: { [weak selfController] _, f in
                selfController?.interfaceInteraction?.updateForwardOptionsState({ current in
                    var updated = current
                    if hideCaptions {
                        updated.hideCaptions = false
                        if canHideNames {
                            if updated.unhideNamesOnCaptionChange {
                                updated.unhideNamesOnCaptionChange = false
                                updated.hideNames = false
                            }
                        }
                    } else {
                        updated.hideCaptions = true
                        if canHideNames {
                            if !updated.hideNames {
                                updated.hideNames = true
                                updated.unhideNamesOnCaptionChange = true
                            }
                        }
                    }
                    return updated
                })
            })))
        }
        
        if !items.isEmpty {
            items.append(.separator)
        }
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptions_ChangeRecipient, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replace"), color: theme.contextMenu.primaryColor) }, action: { [weak selfController] c, f in
            selfController?.interfaceInteraction?.forwardCurrentForwardMessages()
            
            f(.default)
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_MessageOptionsApplyChanges, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { _, f in
            f(.default)
        })))
        
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ForwardOptionsCancel, textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak selfController] c, f in
            f(.default)
            
            guard let selfController else {
                return
            }
            selfController.updateChatPresentationInterfaceState(interactive: false, { $0.updatedInterfaceState({ $0.withUpdatedForwardMessageIds(nil).withoutSelectionState() }) })
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
    
    return (ContextController.Source(
        id: AnyHashable(OptionsId.forward),
        title: selfController.presentationData.strings.Conversation_MessageOptionsTabForward,
        source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)),
        items: items |> map { ContextController.Items(id: AnyHashable("forward"), content: .list($0)) }
    ), dismissedForCancel)
}

func presentChatForwardOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode) {
    presentChatInputOptions(selfController: selfController, sourceNode: sourceNode, initialId: .forward)
}

private func generateChatReplyOptionItems(selfController: ChatControllerImpl, chatController: ChatControllerImpl) -> Signal<ContextController.Items, NoError> {
    guard let replySubject = selfController.presentationInterfaceState.interfaceState.replyMessageSubject else {
        return .complete()
    }
    
    let applyCurrentQuoteSelection: () -> Void = { [weak selfController, weak chatController] in
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
        var quote: EngineMessageReplyQuote?
        let trimmedText = trimStringWithEntities(string: textSelection.text, entities: textSelection.entities, maxLength: quoteMaxLength(appConfig: selfController.context.currentAppConfiguration.with({ $0 })))
        if !trimmedText.string.isEmpty {
            quote = EngineMessageReplyQuote(text: trimmedText.string, offset: textSelection.offset, entities: trimmedText.entities, media: nil)
        }
        
        selfController.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(ChatInterfaceState.ReplyMessageSubject(messageId: replySubject.messageId, quote: quote)).withoutSelectionState() }) })
    }
    
    let items = combineLatest(queue: .mainQueue(),
        selfController.context.account.postbox.messagesAtIds([replySubject.messageId]),
        ApplicationSpecificNotice.getReplyQuoteTextSelectionTips(accountManager: selfController.context.sharedContext.accountManager)
    )
    |> deliverOnMainQueue
    |> map { [weak selfController, weak chatController] messages, quoteTextSelectionTips -> ContextController.Items in
        guard let selfController, let chatController else {
            return ContextController.Items(content: .list([]))
        }
        
        var items: [ContextMenuItem] = []
        
        if replySubject.quote != nil {
            items.append(.action(ContextMenuActionItem(text: selfController.presentationData.strings.Conversation_MessageOptionsQuoteSelectedPart, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/QuoteSelected"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                applyCurrentQuoteSelection()
                
                f(.default)
            })))
        } else if let message = messages.first, !message.text.isEmpty {
            items.append(.action(ContextMenuActionItem(text: selfController.presentationData.strings.Conversation_MessageOptionsQuoteSelect, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Quote"), color: theme.contextMenu.primaryColor) }, action: { [weak selfController, weak chatController] c, _ in
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
                                c?.popItems()
                            })))
                            subItems.append(.separator)
                            
                            subItems.append(.action(ContextMenuActionItem(text: selfController.presentationData.strings.Conversation_MessageOptionsQuoteSelectedPart, icon: { theme in
                                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/QuoteSelected"), color: theme.contextMenu.primaryColor)
                            }, action: { [weak selfController, weak contentNode] _, f in
                                guard let selfController, let contentNode else {
                                    return
                                }
                                guard let textSelection = contentNode.getCurrentTextSelection() else {
                                    return
                                }
                                
                                var quote: EngineMessageReplyQuote?
                                let trimmedText = trimStringWithEntities(string: textSelection.text, entities: textSelection.entities, maxLength: quoteMaxLength(appConfig: selfController.context.currentAppConfiguration.with({ $0 })))
                                if !trimmedText.string.isEmpty {
                                    quote = EngineMessageReplyQuote(text: trimmedText.string, offset: textSelection.offset, entities: trimmedText.entities, media: nil)
                                }
                                
                                selfController.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(ChatInterfaceState.ReplyMessageSubject(messageId: replySubject.messageId, quote: quote)).withoutSelectionState() }) })
                                
                                f(.default)
                            })))
                            
                            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems), dismissed: { [weak contentNode] in
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
        
        var canReplyInAnotherChat = true
        
        if let message = messages.first {
            if selfController.presentationInterfaceState.copyProtectionEnabled {
                canReplyInAnotherChat = false
            }
            
            var isAction = false
            for media in message.media {
                if media is TelegramMediaAction || media is TelegramMediaExpiredContent {
                    isAction = true
                } else if let story = media as? TelegramMediaStory {
                    if story.isMention {
                        isAction = true
                    }
                }
            }
            
            if isAction {
                canReplyInAnotherChat = false
            }
            if message.isCopyProtected() {
                canReplyInAnotherChat = false
            }
            if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                canReplyInAnotherChat = false
            }
            if message.minAutoremoveOrClearTimeout == viewOnceTimeout {
                canReplyInAnotherChat = false
            }
            if let channel = message.peers[message.id.peerId] as? TelegramChannel, channel.isMonoForum {
                canReplyInAnotherChat = false
            }
        }
        
        if canReplyInAnotherChat {
            items.append(.action(ContextMenuActionItem(text: selfController.presentationData.strings.Conversation_MessageOptionsReplyInAnotherChat, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replace"), color: theme.contextMenu.primaryColor) }, action: { [weak selfController] c, f in
                applyCurrentQuoteSelection()
                
                f(.default)
                
                guard let selfController else {
                    return
                }
                guard let replySubject = selfController.presentationInterfaceState.interfaceState.replyMessageSubject else {
                    return
                }
                moveReplyMessageToAnotherChat(selfController: selfController, replySubject: replySubject)
            })))
        }
        
        if !items.isEmpty {
            items.append(.separator)
            
            items.append(.action(ContextMenuActionItem(text: selfController.presentationData.strings.Conversation_MessageOptionsApplyChanges, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { _, f in
                applyCurrentQuoteSelection()
                
                f(.default)
            })))
        }
        
        if replySubject.quote != nil {
            items.append(.action(ContextMenuActionItem(text: selfController.presentationData.strings.Conversation_MessageOptionsQuoteRemove, textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/QuoteRemove"), color: theme.contextMenu.destructiveColor) }, action: { [weak selfController] c, f in
                f(.default)
                
                guard let selfController else {
                    return
                }
                var replySubject = replySubject
                replySubject.quote = nil
                selfController.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(replySubject).withoutSelectionState() }).updatedSearch(nil) })
            })))
        } else {
            items.append(.action(ContextMenuActionItem(text: selfController.presentationData.strings.Conversation_MessageOptionsReplyCancel, textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak selfController] c, f in
                f(.default)
                
                guard let selfController else {
                    return
                }
                var replySubject = replySubject
                replySubject.quote = nil
                selfController.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withoutSelectionState() }).updatedSearch(nil) })
            })))
        }
        
        var tip: ContextController.Tip?
        if quoteTextSelectionTips <= 3, let message = messages.first, !message.text.isEmpty {
            tip = .quoteSelection
        }
        
        return ContextController.Items(id: AnyHashable("reply"), content: .list(items), tip: tip)
    }
    
    let _ = ApplicationSpecificNotice.incrementReplyQuoteTextSelectionTips(accountManager: selfController.context.sharedContext.accountManager).startStandalone()
    
    return items
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
        replyQuote = ChatControllerSubject.MessageOptionsInfo.Quote(messageId: replySubject.messageId, text: quote.text, offset: quote.offset)
    }
    selectionState.set(selfController.context.account.postbox.messagesAtIds([replySubject.messageId])
    |> map { messages -> ChatControllerSubject.MessageOptionsInfo.SelectionState in
        var canQuote = false
        if let message = messages.first, !message.text.isEmpty {
            canQuote = true
        }
        return ChatControllerSubject.MessageOptionsInfo.SelectionState(
            canQuote: canQuote,
            quote: replyQuote
        )
    }
    |> distinctUntilChanged)
    
    guard let chatController = selfController.context.sharedContext.makeChatController(context: selfController.context, chatLocation: .peer(id: peerId), subject: .messageOptions(peerIds: [replySubject.messageId.peerId], ids: [replySubject.messageId], info: .reply(ChatControllerSubject.MessageOptionsInfo.Reply(quote: replyQuote, selectionState: selectionState))), botStart: nil, mode: .standard(.previewing), params: nil) as? ChatControllerImpl else {
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
    
    return ContextController.Source(
        id: AnyHashable(OptionsId.reply),
        title: selfController.presentationData.strings.Conversation_MessageOptionsTabReply,
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
        let filter: ChatListNodePeersFilter = [.onlyWriteable, .excludeDisabled, .doNotSearchMessages]
        var attemptSelectionImpl: ((EnginePeer, ChatListDisabledPeerReason) -> Void)?
        let controller = selfController.context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(
            context: selfController.context,
            updatedPresentationData: selfController.updatedPresentationData,
            filter: filter,
            hasFilters: true,
            title: selfController.presentationData.strings.Conversation_MoveReplyToAnotherChatTitle,
            attemptSelection: { peer, _, reason in
                attemptSelectionImpl?(peer, reason)
            },
            multipleSelection: false,
            forwardedMessageIds: [],
            selectForumThreads: true
        ))
        let context = selfController.context
        attemptSelectionImpl = { [weak selfController, weak controller] peer, reason in
            guard let selfController, let controller = controller else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            switch reason {
            case .generic:
                controller.present(textAlertController(context: context, updatedPresentationData: selfController.updatedPresentationData, title: nil, text: presentationData.strings.Forward_ErrorDisabledForChat, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
            case .premiumRequired:
                controller.forEachController { c in
                    if let c = c as? UndoOverlayController {
                        c.dismiss()
                    }
                    return true
                }
                
                var hasAction = false
                let premiumConfiguration = PremiumConfiguration.with(appConfiguration: selfController.context.currentAppConfiguration.with { $0 })
                if !premiumConfiguration.isPremiumDisabled {
                    hasAction = true
                }
                
                controller.present(UndoOverlayController(presentationData: presentationData, content: .premiumPaywall(title: nil, text: presentationData.strings.Chat_ToastMessagingRestrictedToPremium_Text(peer.compactDisplayTitle).string, customUndoText: hasAction ? presentationData.strings.Chat_ToastMessagingRestrictedToPremium_Action : nil, timeout: nil, linkAction: { _ in
                }), elevatedLayout: false, animateInAsReplacement: true, action: { [weak selfController, weak controller] action in
                    guard let selfController, let controller else {
                        return false
                    }
                    if case .undo = action {
                        let premiumController = PremiumIntroScreen(context: selfController.context, source: .settings)
                        controller.push(premiumController)
                    }
                    return false
                }), in: .current)
            }
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
                moveReplyToChat(selfController: selfController, peerId: peerId, threadId: threadId, replySubject: replySubject, completion: { [weak strongController] in
                    strongController?.dismiss()
                })
            }
        }
        selfController.chatDisplayNode.dismissInput()
        selfController.effectiveNavigationController?.pushViewController(controller)
    })
}

func moveReplyToChat(selfController: ChatControllerImpl, peerId: EnginePeer.Id, threadId: Int64?, replySubject: ChatInterfaceState.ReplyMessageSubject, completion: @escaping () -> Void) {
    if let navigationController = selfController.effectiveNavigationController {
        for controller in navigationController.viewControllers {
            if let maybeChat = controller as? ChatControllerImpl {
                if case .peer(peerId) = maybeChat.chatLocation {
                    var isChatPinnedMessages = false
                    if case .pinnedMessages = maybeChat.presentationInterfaceState.subject {
                        isChatPinnedMessages = true
                    }
                    if !isChatPinnedMessages {
                        maybeChat.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(replySubject).withoutSelectionState() }) })
                        
                        var viewControllers = navigationController.viewControllers
                        if let index = viewControllers.firstIndex(where: { $0 === maybeChat }), index != viewControllers.count - 1 {
                            viewControllers.removeSubrange((index + 1) ..< viewControllers.count)
                            navigationController.setViewControllers(viewControllers, animated: true)
                        } else {
                            selfController.dismiss()
                        }
                        
                        completion()
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
            selfController.updateChatPresentationInterfaceState(animated: false, interactive: true, { $0.updatedInterfaceState({ $0.withUpdatedReplyMessageSubject(nil).withUpdatedSendMessageEffect(nil).withoutSelectionState() }) })
            
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
                |> timeout(0.2, queue: .mainQueue(), alternate: .single(true))
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
            let chatController = ChatControllerImpl(context: selfController.context, chatLocation: .peer(id: peerId))
            chatController.activateInput(type: .text)
            proceed(chatController)
        }
    })
}

private func chatLinkOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode, getContextController: @escaping () -> ContextController?, replySelectionState: Promise<ChatControllerSubject.MessageOptionsInfo.SelectionState>) -> ContextController.Source? {
    guard let peerId = selfController.chatLocation.peerId else {
        return nil
    }
    
    let initialUrlPreview: ChatPresentationInterfaceState.UrlPreview?
    if selfController.presentationInterfaceState.interfaceState.editMessage != nil {
        initialUrlPreview = selfController.presentationInterfaceState.editingUrlPreview
    } else {
        initialUrlPreview = selfController.presentationInterfaceState.urlPreview
    }
    
    guard let initialUrlPreview else {
        return nil
    }
    
    let linkOptions = combineLatest(queue: .mainQueue(),
        selfController.presentationInterfaceStatePromise.get(),
        replySelectionState.get()
    )
    |> map { state, replySelectionState -> ChatControllerSubject.LinkOptions in
        let urlPreview: ChatPresentationInterfaceState.UrlPreview
        if state.interfaceState.editMessage != nil {
            urlPreview = state.editingUrlPreview ?? initialUrlPreview
        } else {
            urlPreview = state.urlPreview ?? initialUrlPreview
        }
        
        var webpageHasLargeMedia = false
        if case let .Loaded(content) = urlPreview.webPage.content {
            if let isMediaLargeByDefault = content.isMediaLargeByDefault {
                if isMediaLargeByDefault {
                    webpageHasLargeMedia = true
                }
            } else {
                webpageHasLargeMedia = true
            }
        }
        
        let composeInputText: NSAttributedString = state.interfaceState.effectiveInputState.inputText
        
        var replyMessageId: EngineMessage.Id?
        var replyQuote: String?
        
        if state.interfaceState.editMessage == nil {
            replyMessageId = state.interfaceState.replyMessageSubject?.messageId
            replyQuote = replySelectionState.quote?.text
        }
        
        let inputText = chatInputStateStringWithAppliedEntities(composeInputText.string, entities: generateChatInputTextEntities(composeInputText, generateLinks: false))
        
        var largeMedia = false
        if webpageHasLargeMedia {
            if let value = urlPreview.largeMedia {
                largeMedia = value
            } else if case let .Loaded(content) = urlPreview.webPage.content {
                largeMedia = !defaultWebpageImageSizeIsSmall(webpage: content)
            } else {
                largeMedia = true
            }
        } else {
            largeMedia = false
        }
        
        return ChatControllerSubject.LinkOptions(
            messageText: composeInputText.string,
            messageEntities: generateChatInputTextEntities(composeInputText, generateLinks: true),
            hasAlternativeLinks: detectUrls(inputText).count > 1,
            replyMessageId: replyMessageId,
            replyQuote: replyQuote,
            url: urlPreview.url,
            webpage: urlPreview.webPage,
            linkBelowText: urlPreview.positionBelowText,
            largeMedia: largeMedia
        )
    }
    |> distinctUntilChanged
    
    guard let chatController = selfController.context.sharedContext.makeChatController(context: selfController.context, chatLocation: .peer(id: peerId), subject: .messageOptions(peerIds: [peerId], ids: selfController.presentationInterfaceState.interfaceState.forwardMessageIds ?? [], info: .link(ChatControllerSubject.MessageOptionsInfo.Link(options: linkOptions, isCentered: false))), botStart: nil, mode: .standard(.previewing), params: nil) as? ChatControllerImpl else {
        return nil
    }
    chatController.canReadHistory.set(false)
    
    let items = linkOptions
    |> deliverOnMainQueue
    |> map { [weak selfController] linkOptions -> ContextController.Items in
        guard let selfController else {
            return ContextController.Items(id: AnyHashable(linkOptions.url), content: .list([]))
        }
        var items: [ContextMenuItem] = []
        
        do {
            items.append(.action(ContextMenuActionItem(text: linkOptions.linkBelowText ? selfController.presentationData.strings.Conversation_MessageOptionsLinkMoveUp : selfController.presentationData.strings.Conversation_MessageOptionsLinkMoveDown, icon: { theme in
                return nil
            }, iconAnimation: ContextMenuActionItem.IconAnimation(
                name: linkOptions.linkBelowText ? "message_preview_sort_above" : "message_preview_sort_below"
            ), action: { [weak selfController] _, f in
                selfController?.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    if state.interfaceState.editMessage != nil {
                        guard var urlPreview = state.editingUrlPreview else {
                            return state
                        }
                        urlPreview.positionBelowText = !urlPreview.positionBelowText
                        return state.updatedEditingUrlPreview(urlPreview)
                    } else {
                        guard var urlPreview = state.urlPreview else {
                            return state
                        }
                        urlPreview.positionBelowText = !urlPreview.positionBelowText
                        return state.updatedUrlPreview(urlPreview)
                    }
                })
            })))
        }
        
        if case let .Loaded(content) = linkOptions.webpage.content, let isMediaLargeByDefault = content.isMediaLargeByDefault, isMediaLargeByDefault {
            let shrinkTitle: String
            let enlargeTitle: String
            if let file = content.file, file.isVideo {
                shrinkTitle = selfController.presentationData.strings.Conversation_MessageOptionsShrinkVideo
                enlargeTitle = selfController.presentationData.strings.Conversation_MessageOptionsEnlargeVideo
            } else {
                shrinkTitle = selfController.presentationData.strings.Conversation_MessageOptionsShrinkImage
                enlargeTitle = selfController.presentationData.strings.Conversation_MessageOptionsEnlargeImage
            }
            
            items.append(.action(ContextMenuActionItem(text: linkOptions.largeMedia ? shrinkTitle : enlargeTitle, icon: { _ in
                return nil
            }, iconAnimation: ContextMenuActionItem.IconAnimation(
                name: !linkOptions.largeMedia ? "message_preview_media_large" : "message_preview_media_small"
            ), action: { [weak selfController] _, f in
                selfController?.updateChatPresentationInterfaceState(animated: true, interactive: true, { state in
                    if state.interfaceState.editMessage != nil {
                        guard var urlPreview = state.editingUrlPreview else {
                            return state
                        }
                        if let largeMedia = urlPreview.largeMedia {
                            urlPreview.largeMedia = !largeMedia
                        } else {
                            urlPreview.largeMedia = false
                        }
                        return state.updatedEditingUrlPreview(urlPreview)
                    } else {
                        guard var urlPreview = state.urlPreview else {
                            return state
                        }
                        if let largeMedia = urlPreview.largeMedia {
                            urlPreview.largeMedia = !largeMedia
                        } else {
                            urlPreview.largeMedia = false
                        }
                        return state.updatedUrlPreview(urlPreview)
                    }
                })
            })))
        }
        
        if !items.isEmpty {
            items.append(.separator)
        }
        
        items.append(.action(ContextMenuActionItem(text: selfController.presentationData.strings.Conversation_MessageOptionsApplyChanges, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { _, f in
            f(.default)
        })))
        
        items.append(.action(ContextMenuActionItem(text: selfController.presentationData.strings.Conversation_LinkOptionsCancel, textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak selfController, weak chatController] c, f in
            guard let selfController else {
                return
            }
            
            selfController.chatDisplayNode.dismissUrlPreview()
            
            let _ = chatController
            
            f(.default)
        })))
        
        return ContextController.Items(id: AnyHashable(linkOptions.url), content: .list(items))
    }
    
    var webpageCache: [String: TelegramMediaWebpage] = [:]
    chatController.performOpenURL = { [weak selfController] message, url, progress in
        guard let selfController else {
            return
        }
        
        if let (updatedUrlPreviewState, signal) = urlPreviewStateForInputText(NSAttributedString(string: url), context: selfController.context, currentQuery: nil, forPeerId: selfController.chatLocation.peerId), let updatedUrlPreviewState, let detectedUrl = updatedUrlPreviewState.detectedUrls.first {
            if let webpage = webpageCache[detectedUrl] {
                progress?.set(.single(false))
                
                selfController.updateChatPresentationInterfaceState(animated: true, interactive: false, { state in
                    if state.interfaceState.editMessage != nil {
                        if var urlPreview = state.editingUrlPreview {
                            urlPreview.url = detectedUrl
                            urlPreview.webPage = webpage
                            
                            return state.updatedEditingUrlPreview(urlPreview)
                        } else {
                            return state
                        }
                    } else {
                        if var urlPreview = state.urlPreview {
                            urlPreview.url = detectedUrl
                            urlPreview.webPage = webpage
                            
                            return state.updatedUrlPreview(urlPreview)
                        } else {
                            return state
                        }
                    }
                })
            } else {
                progress?.set(.single(true))
                let _ = (signal
                |> afterDisposed {
                    progress?.set(.single(false))
                }
                |> deliverOnMainQueue).start(next: { [weak selfController] result in
                    guard let selfController else {
                        return
                    }
                    
                    selfController.updateChatPresentationInterfaceState(animated: true, interactive: false, { state in
                        if state.interfaceState.editMessage != nil {
                            if let (webpage, webpageUrl) = result(nil), var urlPreview = state.editingUrlPreview {
                                urlPreview.url = webpageUrl
                                urlPreview.webPage = webpage
                                webpageCache[detectedUrl] = webpage
                                
                                return state.updatedEditingUrlPreview(urlPreview)
                            } else {
                                return state
                            }
                        } else {
                            if let (webpage, webpageUrl) = result(nil), var urlPreview = state.urlPreview {
                                urlPreview.url = webpageUrl
                                urlPreview.webPage = webpage
                                webpageCache[detectedUrl] = webpage
                                
                                return state.updatedUrlPreview(urlPreview)
                            } else {
                                return state
                            }
                        }
                    })
                })
            }
        }
    }
    
    return ContextController.Source(
        id: AnyHashable(OptionsId.link),
        title: selfController.presentationData.strings.Conversation_MessageOptionsTabLink,
        source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, passthroughTouches: true)),
        items: items
    )
}

func presentChatLinkOptions(selfController: ChatControllerImpl, sourceNode: ASDisplayNode) {
    presentChatInputOptions(selfController: selfController, sourceNode: sourceNode, initialId: .link)
}
