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
    func openTodoItemContextMenu(todoItemId: Int32, params: ChatControllerInteraction.LongTapParams) -> Void {
        guard let message = params.message, let todo = message.media.first(where: { $0 is TelegramMediaTodo }) as? TelegramMediaTodo, let todoItem = todo.items.first(where: { $0.id == todoItemId }), let contentNode = params.contentNode else {
            return
        }
        
        let completion = todo.completions.first(where: { $0.id == todoItemId })
                
//        let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil// anyRecognizer as? TapLongTapOrDoubleTapGestureRecognizer
//        let gesture: ContextGesture? = nil // anyRecognizer as? ContextGesture
        
        var canMark = false
        if (todo.flags.contains(.othersCanComplete) || message.author?.id == context.account.peerId) {
            canMark = true
        }
        let canEdit = canEditMessage(context: self.context, limitsConfiguration: self.context.currentLimitsConfiguration.with { EngineConfiguration.Limits($0) }, message: message)
        
        let _ = (contextMenuForChatPresentationInterfaceState(chatPresentationInterfaceState: self.presentationInterfaceState, context: self.context, messages: [message], controllerInteraction: self.controllerInteraction, selectAll: false, interfaceInteraction: self.interfaceInteraction, messageNode: params.messageNode as? ChatMessageItemView)
        |> deliverOnMainQueue).start(next: { [weak self] actions in
            guard let self else {
                return
            }
          
            var items: [ContextMenuItem] = []
            if let completion {
                let dateText = humanReadableStringForTimestamp(strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, timestamp: completion.date, alwaysShowTime: true, allowYesterday: true, format: HumanReadableStringFormat(
                    dateFormatString: { value in
                        return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_TodoItemCompletionTimestamp_Date(value).string, ranges: [])
                    },
                    tomorrowFormatString: { value in
                        return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_TodoItemCompletionTimestamp_TodayAt(value).string, ranges: [])
                    },
                    todayFormatString: { value in
                        return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_TodoItemCompletionTimestamp_TodayAt(value).string, ranges: [])
                    },
                    yesterdayFormatString: { value in
                        return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_TodoItemCompletionTimestamp_YesterdayAt(value).string, ranges: [])
                    }
                )).string
                
                let nop: ((ContextMenuActionItem.Action) -> Void)? = nil
                items.append(.action(ContextMenuActionItem(text: dateText, textFont: .small, icon: { _ in return nil }, action: nop)))
                items.append(.separator)
                
                if canMark {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Todo_ContextMenu_UncheckTask, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, f in
                        guard let self else {
                            return
                        }
                        
                        if !self.context.isPremium {
                            f(.default)
                            let controller = UndoOverlayController(
                                presentationData: self.presentationData,
                                content: .premiumPaywall(title: nil, text: self.presentationData.strings.Chat_Todo_PremiumRequired, customUndoText: nil, timeout: nil, linkAction: nil),
                                action: { [weak self] action in
                                    guard let self else {
                                        return false
                                    }
                                    if case .info = action {
                                        let controller = self.context.sharedContext.makePremiumIntroController(context: context, source: .presence, forceDark: false, dismissed: nil)
                                        self.push(controller)
                                    }
                                    return false
                                }
                            )
                            self.present(controller, in: .current)
                        } else {
                            c?.dismiss(completion: {
                                let _ = self.context.engine.messages.requestUpdateTodoMessageItems(messageId: message.id, completedIds: [], incompletedIds: [todoItemId]).start()
                            })
                        }
                    })))
                }
            } else {
                if canMark {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Todo_ContextMenu_CheckTask, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  c, f in
                        guard let self else {
                            return
                        }
                        
                        if !self.context.isPremium {
                            f(.default)
                            let controller = UndoOverlayController(
                                presentationData: self.presentationData,
                                content: .premiumPaywall(title: nil, text: self.presentationData.strings.Chat_Todo_PremiumRequired, customUndoText: nil, timeout: nil, linkAction: nil),
                                action: { [weak self] action in
                                    guard let self else {
                                        return false
                                    }
                                    if case .info = action {
                                        let controller = self.context.sharedContext.makePremiumIntroController(context: context, source: .presence, forceDark: false, dismissed: nil)
                                        self.push(controller)
                                    }
                                    return false
                                }
                            )
                            self.present(controller, in: .current)
                        } else {
                            c?.dismiss(completion: {
                                let _ = self.context.engine.messages.requestUpdateTodoMessageItems(messageId: message.id, completedIds: [todoItemId], incompletedIds: []).start()
                            })
                        }
                    })))
                }
            }
            
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Conversation_ContextMenuCopy, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                f(.default)

                guard let self else {
                    return
                }
                storeMessageTextInPasteboard(todoItem.text, entities: todoItem.entities)
               
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
                        UIPasteboard.general.string = link + "?task=\(todoItemId)"
                        
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
            
            if canEdit {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Todo_ContextMenu_EditTask, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                    f(.default)
                    
                    guard let self else {
                        return
                    }
                    
                    self.interfaceInteraction?.editTodoMessage(message.id, todoItemId, false)
                })))
                
                if todo.items.count > 1 {
                    items.append(.separator)
                    
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Todo_ContextMenu_DeleteTask, textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self]  _, f in
                        f(.default)
                        
                        guard let self else {
                            return
                        }
                        
                        let updatedItems = todo.items.filter { $0.id != todoItemId }
                        let updatedTodo = todo.withUpdated(items: updatedItems)
                        
                        let _ = self.context.engine.messages.requestEditMessage(
                            messageId: message.id,
                            text: "",
                            media: .update(.standalone(media: updatedTodo)),
                            entities: nil,
                            inlineStickers: [:]
                        ).start()
                    })))
                }
            }
            
            self.canReadHistory.set(false)
            
            var sources: [ContextController.Source] = []
            sources.append(
                ContextController.Source(
                    id: AnyHashable(OptionsId.item),
                    title: self.presentationData.strings.Chat_Todo_ContextMenu_SectionTask,
                    footer: self.presentationData.strings.Chat_Todo_ContextMenu_SectionsInfo,
                    source: .extracted(ChatTodoItemContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode)),
                    items: .single(ContextController.Items(content: .list(items)))
                )
            )
            
            sources.append(
                ContextController.Source(
                    id: AnyHashable(OptionsId.message),
                    title: self.presentationData.strings.Chat_Todo_ContextMenu_SectionList,
                    source: .extracted(ChatMessageContextExtractedContentSource(chatController: self, chatNode: self.chatDisplayNode, engine: self.context.engine, message: message, selectAll: false, snapshot: true)),
                    items: .single(actions)
                )
            )
            
            let contextController = ContextController(
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

final class ChatTodoItemContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    
    private weak var chatNode: ChatControllerNode?
    private let contentNode: ContextExtractedContentContainingNode
    
    init(chatNode: ChatControllerNode, contentNode: ContextExtractedContentContainingNode) {
        self.chatNode = chatNode
        self.contentNode = contentNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        return ContextControllerTakeViewInfo(containingItem: .node(self.contentNode), contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        guard let chatNode = self.chatNode else {
            return nil
        }
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: chatNode.convert(chatNode.frameForVisibleArea(), to: nil))
    }
}
