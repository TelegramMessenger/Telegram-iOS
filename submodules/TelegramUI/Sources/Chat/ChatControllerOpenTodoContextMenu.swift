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

extension ChatControllerImpl {
    func openTodoItemContextMenu(todoItemId: Int32, params: ChatControllerInteraction.LongTapParams) -> Void {
        guard let message = params.message, let todo = message.media.first(where: { $0 is TelegramMediaTodo }) as? TelegramMediaTodo, let todoItem = todo.items.first(where: { $0.id == todoItemId }), let contentNode = params.contentNode else {
            return
        }
        
        let completion = todo.completions.first(where: { $0.id == todoItemId })
                
        let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil// anyRecognizer as? TapLongTapOrDoubleTapGestureRecognizer
        let gesture: ContextGesture? = nil // anyRecognizer as? ContextGesture
        
        let source: ContextContentSource
//                if let location = location {
//                    source = .location(ChatMessageContextLocationContentSource(controller: self, location: messageNode.view.convert(messageNode.bounds, to: nil).origin.offsetBy(dx: location.x, dy: location.y)))
//                } else {
            source = .extracted(ChatMessageLinkContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode))
//                }
                
        
        var canMark = false
        if (todo.flags.contains(.othersCanComplete) || message.author?.id == context.account.peerId) {
            canMark = true
        }
        let canEdit = canEditMessage(context: self.context, limitsConfiguration: self.context.currentLimitsConfiguration.with { EngineConfiguration.Limits($0) }, message: message)
        
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
                items.append(.action(ContextMenuActionItem(text: "Uncheck", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                    f(.default)
                    
                    guard let self else {
                        return
                    }
                    
                    let _ = self.context.engine.messages.requestUpdateTodoMessageItems(messageId: message.id, completedIds: [], incompletedIds: [todoItemId]).start()
                })))
            }
        } else {
            if canMark {
                items.append(.action(ContextMenuActionItem(text: "Check", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                    f(.default)
                    
                    guard let self else {
                        return
                    }
                    
                    let _ = self.context.engine.messages.requestUpdateTodoMessageItems(messageId: message.id, completedIds: [todoItemId], incompletedIds: []).start()
                })))
            }
        }
        
        //TODO:localize
        items.append(.action(ContextMenuActionItem(text: "Copy", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
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
            items.append(.action(ContextMenuActionItem(text: "Copy Link", icon: { theme in
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
            items.append(.action(ContextMenuActionItem(text: "Edit Item", icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Edit"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                f(.default)
                
                guard let self else {
                    return
                }
                
                self.interfaceInteraction?.editTodoMessage(message.id, todoItemId, false)
            })))
            
            if todo.items.count > 1 {
                items.append(.separator)
                
                items.append(.action(ContextMenuActionItem(text: "Delete Item", textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self]  _, f in
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
        
        let controller = ContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), recognizer: recognizer, gesture: gesture, disableScreenshots: false)
        controller.dismissed = { [weak self] in
            self?.canReadHistory.set(true)
        }
        
        self.window?.presentInGlobalOverlay(controller)
    }
}
