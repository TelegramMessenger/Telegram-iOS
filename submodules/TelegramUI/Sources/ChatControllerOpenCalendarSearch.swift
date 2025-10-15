import Foundation
import TelegramPresentationData
import AccountContext
import Postbox
import TelegramCore
import SwiftSignalKit
import CalendarMessageScreen
import ContextUI
import ChatControllerInteraction
import Display
import UIKit
import UndoUI

extension ChatControllerImpl {
    func openCalendarSearch(timestamp: Int32) {
        guard let peerId = self.chatLocation.peerId else {
            return
        }
        self.chatDisplayNode.dismissInput()

        let initialTimestamp = timestamp
        var dismissCalendarScreen: (() -> Void)?
        var selectDay: ((Int32) -> Void)?
        var openClearHistory: ((Int32) -> Void)?

        let enableMessageRangeDeletion: Bool = peerId.namespace == Namespaces.Peer.CloudUser
        
        let displayMedia = self.presentationInterfaceState.historyFilter == nil

        let calendarScreen = CalendarMessageScreen(
            context: self.context,
            peerId: peerId,
            calendarSource: self.context.engine.messages.sparseMessageCalendar(peerId: peerId, threadId: self.chatLocation.threadId, tag: .photoOrVideo, displayMedia: displayMedia),
            initialTimestamp: initialTimestamp,
            enableMessageRangeDeletion: enableMessageRangeDeletion,
            canNavigateToEmptyDays: true,
            navigateToDay: { [weak self] c, index, timestamp in
                guard let strongSelf = self else {
                    c.dismiss()
                    return
                }
                
                strongSelf.alwaysShowSearchResultsAsList = false
                strongSelf.chatDisplayNode.alwaysShowSearchResultsAsList = false
                strongSelf.updateChatPresentationInterfaceState(animated: false, interactive: false, { state in
                    return state.updatedDisplayHistoryFilterAsList(false).updatedSearch(nil)
                })

                c.dismiss()

                strongSelf.loadingMessage.set(.single(.generic))

                let peerId: PeerId
                let threadId: Int64?
                switch strongSelf.chatLocation {
                case let .peer(peerIdValue):
                    peerId = peerIdValue
                    threadId = nil
                case let .replyThread(replyThreadMessage):
                    peerId = replyThreadMessage.peerId
                    threadId = replyThreadMessage.threadId
                case .customChatContents:
                    return
                }

                strongSelf.messageIndexDisposable.set((strongSelf.context.engine.messages.searchMessageIdByTimestamp(peerId: peerId, threadId: threadId, timestamp: timestamp) |> deliverOnMainQueue).startStrict(next: { messageId in
                    if let strongSelf = self {
                        strongSelf.loadingMessage.set(.single(nil))
                        if let messageId = messageId {
                            strongSelf.navigateToMessage(from: nil, to: .id(messageId, NavigateToMessageParams(timestamp: nil, quote: nil)), forceInCurrentChat: true)
                        }
                    }
                }))
            },
            previewDay: { [weak self] timestamp, _, sourceNode, sourceRect, gesture in
                guard let strongSelf = self else {
                    return
                }

                var items: [ContextMenuItem] = []

                items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Chat_JumpToDate, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor)
                }, action: { _, f in
                    f(.dismissWithoutContent)
                    dismissCalendarScreen?()

                    strongSelf.loadingMessage.set(.single(.generic))

                    let peerId: PeerId
                    let threadId: Int64?
                    switch strongSelf.chatLocation {
                    case let .peer(peerIdValue):
                        peerId = peerIdValue
                        threadId = nil
                    case let .replyThread(replyThreadMessage):
                        peerId = replyThreadMessage.peerId
                        threadId = replyThreadMessage.threadId
                    case .customChatContents:
                        return
                    }

                    strongSelf.messageIndexDisposable.set((strongSelf.context.engine.messages.searchMessageIdByTimestamp(peerId: peerId, threadId: threadId, timestamp: timestamp) |> deliverOnMainQueue).startStrict(next: { messageId in
                        if let strongSelf = self {
                            strongSelf.loadingMessage.set(.single(nil))
                            if let messageId = messageId {
                                strongSelf.navigateToMessage(from: nil, to: .id(messageId, NavigateToMessageParams(timestamp: nil, quote: nil)), forceInCurrentChat: true)
                            }
                        }
                    }))
                })))

                if enableMessageRangeDeletion && (peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.SecretChat) {
                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.DialogList_ClearHistoryConfirmation, textColor: .destructive, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        openClearHistory?(timestamp)
                    })))

                    items.append(.separator)

                    items.append(.action(ContextMenuActionItem(text: strongSelf.presentationData.strings.Common_Select, icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Select"), color: theme.contextMenu.primaryColor)
                    }, action: { _, f in
                        f(.dismissWithoutContent)
                        selectDay?(timestamp)
                    })))
                }

                let chatController = strongSelf.context.sharedContext.makeChatController(context: strongSelf.context, chatLocation: .peer(id: peerId), subject: .message(id: .timestamp(timestamp), highlight: nil, timecode: nil, setupReply: false), botStart: nil, mode: .standard(.previewing), params: nil)
                chatController.canReadHistory.set(false)
                
                strongSelf.chatDisplayNode.messageTransitionNode.dismissMessageReactionContexts()
                
                let contextController = ContextController(presentationData: strongSelf.presentationData, source: .controller(ChatContextControllerContentSourceImpl(controller: chatController, sourceNode: sourceNode, sourceRect: sourceRect, passthroughTouches: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
                strongSelf.presentInGlobalOverlay(contextController)
            }
        )
        
        calendarScreen.completedWithRemoveMessagesInRange = { [weak self] range, type, dayCount, calendarSource in
            guard let strongSelf = self else {
                return
            }
            
            let statusText: String
            switch type {
            case .forEveryone:
                statusText = strongSelf.presentationData.strings.Chat_MessageRangeDeleted_ForBothSides(Int32(dayCount))
            default:
                statusText = strongSelf.presentationData.strings.Chat_MessageRangeDeleted_ForMe(Int32(dayCount))
            }
            
            strongSelf.chatDisplayNode.historyNode.ignoreMessagesInTimestampRange = range
            
            strongSelf.present(UndoOverlayController(presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, content: .removedChat(context: strongSelf.context, title: NSAttributedString(string: statusText), text: nil), elevatedLayout: false, action: { value in
                guard let strongSelf = self else {
                    return false
                }
                
                if value == .commit {
                    let _ = calendarSource.removeMessagesInRange(minTimestamp: range.lowerBound, maxTimestamp: range.upperBound, type: type, completion: {
                        Queue.mainQueue().after(1.0, {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.chatDisplayNode.historyNode.ignoreMessagesInTimestampRange = nil
                        })
                    })
                    return true
                } else if value == .undo {
                    strongSelf.chatDisplayNode.historyNode.ignoreMessagesInTimestampRange = nil
                    return true
                }
                return false
            }), in: .current)
        }

        self.effectiveNavigationController?.pushViewController(calendarScreen)
        
        dismissCalendarScreen = { [weak calendarScreen] in
            calendarScreen?.dismiss(completion: nil)
        }
        selectDay = { [weak calendarScreen] timestamp in
            calendarScreen?.selectDay(timestamp: timestamp)
        }
        openClearHistory = { [weak calendarScreen] timestamp in
            calendarScreen?.openClearHistory(timestamp: timestamp)
        }
    }
}
