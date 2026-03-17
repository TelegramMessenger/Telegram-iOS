import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AsyncDisplayKit
import Display
import ContextUI
import UndoUI
import AccountContext
import ChatMessageItemView
import ChatMessageItemCommon
import AvatarNode
import ChatControllerInteraction
import Pasteboard
import TelegramStringFormatting
import TelegramPresentationData

private enum OptionsId: Hashable {
    case item
    case message
}

extension ChatControllerImpl {
    func openPollOptionContextMenu(optionId: Data, params: ChatControllerInteraction.LongTapParams) -> Void {
        guard let message = params.message, let poll = message.media.first(where: { $0 is TelegramMediaPoll }) as? TelegramMediaPoll, let pollOptionIndex = poll.options.firstIndex(where: { $0.opaqueIdentifier == optionId }), let contentNode = params.contentNode else {
            return
        }
        
        let pollOption = poll.options[pollOptionIndex]
        
        let _ = (contextMenuForChatPresentationInterfaceState(chatPresentationInterfaceState: self.presentationInterfaceState, context: self.context, messages: [message], controllerInteraction: self.controllerInteraction, selectAll: false, interfaceInteraction: self.interfaceInteraction, messageNode: params.messageNode as? ChatMessageItemView)
        |> deliverOnMainQueue).start(next: { [weak self] actions in
            guard let self else {
                return
            }
          
            var items: [ContextMenuItem] = []
//            if canMark {
//                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Todo_ContextMenu_CheckTask, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  c, f in
//                    guard let self else {
//                        return
//                    }
//
//                    if !self.context.isPremium {
//                        f(.default)
//                        let controller = UndoOverlayController(
//                            presentationData: self.presentationData,
//                            content: .premiumPaywall(title: nil, text: self.presentationData.strings.Chat_Todo_PremiumRequired, customUndoText: nil, timeout: nil, linkAction: nil),
//                            action: { [weak self] action in
//                                guard let self else {
//                                    return false
//                                }
//                                if case .info = action {
//                                    let controller = self.context.sharedContext.makePremiumIntroController(context: context, source: .presence, forceDark: false, dismissed: nil)
//                                    self.push(controller)
//                                }
//                                return false
//                            }
//                        )
//                        self.present(controller, in: .current)
//                    } else {
//                        c?.dismiss(completion: {
//                            let _ = self.context.engine.messages.requestUpdateTodoMessageItems(messageId: message.id, completedIds: [todoItemId], incompletedIds: []).start()
//                        })
//                    }
//                })))
//            }
            
            //TODO:localize
            if canReplyInChat(self.presentationInterfaceState, accountPeerId: self.context.account.peerId) {
                items.append(.action(ContextMenuActionItem(text: "Reply to Option", icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reply"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] c, _ in
                    guard let self else {
                        return
                    }
                    self.interfaceInteraction?.setupReplyMessage(message.id, .pollOption(pollOption.opaqueIdentifier), { transition, completed in
                        c?.dismiss(result: .custom(transition), completion: {
                            completed()
                        })
                    })
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuCopy, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                f(.default)

                guard let self else {
                    return
                }
                storeMessageTextInPasteboard(pollOption.text, entities: pollOption.entities)
               
                self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: presentationData.strings.Conversation_TextCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            })))
            
            var isReplyThreadHead = false
            if case let .replyThread(replyThreadMessage) = self.presentationInterfaceState.chatLocation {
                isReplyThreadHead = message.id == replyThreadMessage.effectiveTopId
            }
            
            if message.id.namespace == Namespaces.Message.Cloud, let channel = message.peers[message.id.peerId] as? TelegramChannel, !channel.isMonoForum, !isReplyThreadHead {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuCopyLink, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    guard let self else {
                        return
                    }
                    var threadMessageId: MessageId?
                    if case let .replyThread(replyThreadMessage) = self.presentationInterfaceState.chatLocation {
                        threadMessageId = replyThreadMessage.effectiveMessageId
                    }
                    let _ = (self.context.engine.messages.exportMessageLink(peerId: message.id.peerId, messageId: message.id, isThread: threadMessageId != nil)
                    |> map { result -> String? in
                        return result
                    }
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] link in
                        guard let self, let link else {
                            return
                        }
                        UIPasteboard.general.string = link + "?option=\(pollOptionIndex)"
                        
                        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                        
                        var warnAboutPrivate = false
                        if case .peer = self.presentationInterfaceState.chatLocation {
                            if channel.addressName == nil {
                                warnAboutPrivate = true
                            }
                        }
                        Queue.mainQueue().after(0.2, {
                            if warnAboutPrivate {
                                self.controllerInteraction?.displayUndo(.linkCopied(title: nil, text: presentationData.strings.Conversation_PrivateMessageLinkCopiedLong))
                            } else {
                                self.controllerInteraction?.displayUndo(.linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied))
                            }
                        })
                    })
                    f(.default)
                })))
            }
            
            self.canReadHistory.set(false)
            
            //TODO:localize
            var sources: [ContextController.Source] = []
            sources.append(
                ContextController.Source(
                    id: AnyHashable(OptionsId.item),
                    title: "Option",
                    footer: "You're viewing actions for one option.\nYou can switch to actions for the list.",
                    source: .extracted(ChatTodoItemContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode)),
                    items: .single(ContextController.Items(content: .list(items)))
                )
            )
            
            let messageContentSource = ChatMessageContextExtractedContentSource(chatController: self, chatNode: self.chatDisplayNode, engine: self.context.engine, message: message, selectAll: false, snapshot: true)
            
            sources.append(
                ContextController.Source(
                    id: AnyHashable(OptionsId.message),
                    title: "Poll",
                    source: .extracted(messageContentSource),
                    items: .single(actions)
                )
            )
            
            contentNode.onDismiss = { [weak messageContentSource] in
                messageContentSource?.snapshotView?.removeFromSuperview()
            }
            
            let contextController = makeContextController(
                presentationData: self.presentationData,
                configuration: ContextController.Configuration(
                    sources: sources,
                    initialId: AnyHashable(OptionsId.item)
                )
            )
            contextController.dismissed = { [weak self] in
                self?.canReadHistory.set(true)
            }
            
            self.window?.presentInGlobalOverlay(contextController)
        })
    }
}
