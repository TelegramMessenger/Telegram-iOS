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
import ChatControllerInteraction
import EventKit
import EventKitUI
import ChatScheduleTimeController
import TextFormat

extension ChatControllerImpl: EKEventEditViewDelegate {
    func openDateContextMenu(date: Int32, params: ChatControllerInteraction.LongTapParams) -> Void {
        guard let message = params.message, let contentNode = params.contentNode else {
            return
        }
                
        guard let messages = self.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(message.id) else {
            return
        }
        
        var updatedMessages = messages
        for i in 0 ..< updatedMessages.count {
            if updatedMessages[i].id == message.id {
                let message = updatedMessages.remove(at: i)
                updatedMessages.insert(message, at: 0)
                break
            }
        }
        
        let recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil// anyRecognizer as? TapLongTapOrDoubleTapGestureRecognizer
        let gesture: ContextGesture? = nil // anyRecognizer as? ContextGesture
                                           
        let source: ContextContentSource
//                if let location = location {
//                    source = .location(ChatMessageContextLocationContentSource(controller: self, location: messageNode.view.convert(messageNode.bounds, to: nil).origin.offsetBy(dx: location.x, dy: location.y)))
//                } else {
            source = .extracted(ChatMessageLinkContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode))
//                }
        
        var items: [ContextMenuItem] = []
        items.append(
            .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Date_Copy, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Copy"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                f(.default)

                guard let self else {
                    return
                }
                
                let fullDate = stringForEntityFormattedDate(timestamp: date, format: .full(timeFormat: .short, dateFormat: .long, dayOfWeek: false), strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat)
                UIPasteboard.general.string = fullDate

                self.present(UndoOverlayController(presentationData: self.presentationData, content: .copy(text: self.presentationData.strings.Conversation_DateCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
            }))
        )
        items.append(
            .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Date_AddToCalendar, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Calendar"), color: theme.contextMenu.primaryColor) }, action: { [weak self]  _, f in
                f(.default)

                guard let self else {
                    return
                }
                
                let eventStore = EKEventStore()
                let event = EKEvent(eventStore: eventStore)
                event.startDate = Date(timeIntervalSince1970: Double(date))
                event.endDate = Date(timeIntervalSince1970: Double(date + 3600))
                       
                let editViewController = EKEventEditViewController()
                editViewController.eventStore = eventStore
                editViewController.event = event
                editViewController.editViewDelegate = self

                if let rootController = self.navigationController?.view.window?.rootViewController {
                    rootController.present(editViewController, animated: true)
                }
            }))
        )
        items.append(
            .action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Context_Date_SetReminder, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unmute"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                f(.default)

                guard let self else {
                    return
                }
                
                let controller = ChatScheduleTimeScreen(
                    context: self.context,
                    mode: .reminders,
                    currentTime: date,
                    currentRepeatPeriod: nil,
                    minimalTime: nil,
                    isDark: false,
                    completion: { [weak self] result in
                        guard let self else {
                            return
                        }
                        let attributes: [MessageAttribute] = [
                            OutgoingScheduleInfoMessageAttribute(scheduleTime: result.time, repeatPeriod: result.repeatPeriod)
                        ]
                        let forwardMessage: EnqueueMessage = .forward(source: message.id, threadId: nil, grouping: .auto, attributes: attributes, correlationId: nil)
                        let _ = enqueueMessages(account: self.context.account, peerId: self.context.account.peerId, messages: [forwardMessage]).start()
                        
                        let text = self.presentationData.strings.Conversation_DateReminderSet.replacingOccurrences(of: "[", with: "**").replacingOccurrences(of: "]()", with: "**")
                        self.present(UndoOverlayController(presentationData: self.presentationData, content: .forward(savedMessages: true, text: text), elevatedLayout: false, animateInAsReplacement: false, action: { [weak self] action in
                            if let self, action == .info {
                                let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                                    guard let self, let peer else {
                                        return
                                    }
                                    guard let navigationController = self.navigationController as? NavigationController else {
                                        return
                                    }
                                    self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), forceOpenChat: true))
                                })
                            }
                            return false
                        }), in: .current)
                    }
                )
                self.push(controller)
            }))
        )
                 
        self.canReadHistory.set(false)
        
        let controller = makeContextController(presentationData: self.presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), recognizer: recognizer, gesture: gesture, disableScreenshots: false)
        controller.dismissed = { [weak self] in
            self?.canReadHistory.set(true)
        }
        
        self.window?.presentInGlobalOverlay(controller)
    }
    
    public func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        controller.dismiss(animated: true)
    }
}
