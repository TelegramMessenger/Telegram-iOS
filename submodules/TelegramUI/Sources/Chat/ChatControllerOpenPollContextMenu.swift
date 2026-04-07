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
import Pasteboard
import TelegramStringFormatting
import TelegramPresentationData
import AvatarNode
import ChatPresentationInterfaceState

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
        
        var selectedOptions: [Data] = []
        if let voters = poll.results.voters {
            for voter in voters {
                if voter.selected {
                    selectedOptions.append(voter.opaqueIdentifier)
                }
            }
        }
        
        var addedByPeer: Signal<EnginePeer?, NoError> = .single(nil)
        if let peerId = pollOption.addedBy {
            addedByPeer = self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
        }
        
        let _ = combineLatest(
            queue: Queue.mainQueue(),
            contextMenuForChatPresentationInterfaceState(chatPresentationInterfaceState: self.presentationInterfaceState, context: self.context, messages: [message], controllerInteraction: self.controllerInteraction, selectAll: false, interfaceInteraction: self.interfaceInteraction, messageNode: params.messageNode as? ChatMessageItemView),
            addedByPeer
        ).start(next: { [weak self] actions, addedByPeer in
            guard let self else {
                return
            }
          
            var items: [ContextMenuItem] = []
            if !poll.isClosed && (selectedOptions.isEmpty || !poll.revotingDisabled) {
                if selectedOptions.contains(pollOption.opaqueIdentifier) {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Poll_RetractOptionVote, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Unvote"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                        guard let self else {
                            return
                        }
                        c?.dismiss(result: .default, completion: {
                            var updatedOptions = selectedOptions
                            updatedOptions.removeAll(where: { $0 == pollOption.opaqueIdentifier } )
                            self.controllerInteraction?.requestSelectMessagePollOptions(message.id, updatedOptions)
                        })
                    })))
                } else {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Poll_VoteOption, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/StopPoll"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                        guard let self else {
                            return
                        }
                        c?.dismiss(result: .default, completion: {
                            var updatedOptions = selectedOptions
                            if !poll.kind.multipleAnswers {
                                updatedOptions = []
                            }
                            updatedOptions.append(pollOption.opaqueIdentifier)
                            self.controllerInteraction?.requestSelectMessagePollOptions(message.id, updatedOptions)
                        })
                    })))
                }
            }
            
            var canReply = canReplyInChat(self.presentationInterfaceState, accountPeerId: self.context.account.peerId)
            if !canSendMessagesToChat(self.presentationInterfaceState) && (self.presentationInterfaceState.copyProtectionEnabled || message.isCopyProtected()) {
                canReply = false
            }
            
            if canReply {
                items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Poll_ReplyToOption, icon: { theme in
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
                        let encodeBase64URL: (Data) -> String = { data in
                            var string = data.base64EncodedString()
                            string = string
                                .replacingOccurrences(of: "+", with: "-")
                                .replacingOccurrences(of: "/", with: "_")
                            string = string.replacingOccurrences(of: "=", with: "")
                            return string
                        }
                        let optionId = encodeBase64URL(pollOption.opaqueIdentifier)
                        UIPasteboard.general.string = link + "?option=\(optionId)"
                        
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
            
            if let addedByPeer, let date = pollOption.date {
                var canRemove = false
                if !poll.isClosed {
                    if poll.isCreator {
                        canRemove = true
                    } else if addedByPeer.id == self.context.account.peerId {
                        let pollConfiguration = PollConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
                        let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                        if currentTime < date + pollConfiguration.pollOptionDeletePeriod {
                            canRemove = true
                        }
                    }
                }
                if canRemove {
                    items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.Chat_Poll_RemoveOption, textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self]  _, f in
                        f(.default)
                        
                        guard let self else {
                            return
                        }
                        let _ = self.context.engine.messages.deletePollOption(messageId: message.id, opaqueIdentifier: pollOption.opaqueIdentifier).start()
                    })))
                }
                
                items.append(.separator)
                
                var peerName = addedByPeer.compactDisplayTitle
                if peerName.count > 20 {
                    peerName = peerName.prefix(20) + "..."
                }
                peerName = "**\(peerName)**"
                let dateText = humanReadableStringForTimestamp(strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, timestamp: date, alwaysShowTime: true, allowYesterday: true, format: HumanReadableStringFormat(
                    dateFormatString: { value in
                        if addedByPeer.id == self.context.account.peerId {
                            return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_PollOptionAddedTimestampYou_Date(value).string, ranges: [])
                        } else {
                            return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_PollOptionAddedTimestamp_Date(peerName, value).string, ranges: [])
                        }
                    },
                    tomorrowFormatString: { value in
                        if addedByPeer.id == self.context.account.peerId {
                            return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_PollOptionAddedTimestampYou_TodayAt(value).string, ranges: [])
                        } else {
                            return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_PollOptionAddedTimestamp_TodayAt(peerName, value).string, ranges: [])
                        }
                    },
                    todayFormatString: { value in
                        if addedByPeer.id == self.context.account.peerId {
                            return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_PollOptionAddedTimestampYou_TodayAt(value).string, ranges: [])
                        } else {
                            return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_PollOptionAddedTimestamp_TodayAt(peerName, value).string, ranges: [])
                        }
                    },
                    yesterdayFormatString: { value in
                        if addedByPeer.id == self.context.account.peerId {
                            return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_PollOptionAddedTimestampYou_YesterdayAt(value).string, ranges: [])
                        } else {
                            return PresentationStrings.FormattedString(string: self.presentationData.strings.Chat_PollOptionAddedTimestamp_YesterdayAt(peerName, value).string, ranges: [])
                        }
                    }
                )).string
                
                let avatarSize = CGSize(width: 24.0, height: 24.0)
                items.append(.action(ContextMenuActionItem(text: dateText, textFont: .small, parseMarkdown: true, icon: { _ in return nil }, iconSource: ContextMenuActionItemIconSource(size: avatarSize, signal: peerAvatarCompleteImage(account: self.context.account, peer: addedByPeer, size: avatarSize)), action: { [weak self] _, f in
                    f(.default)
                    guard let self else {
                        return
                    }
                    self.openPeer(peer: addedByPeer, navigation: .chat(textInputState: nil, subject: nil, peekData: nil), fromMessage: nil)
                })))
            }
            
            self.canReadHistory.set(false)
            
            var sources: [ContextController.Source] = []
            sources.append(
                ContextController.Source(
                    id: AnyHashable(OptionsId.item),
                    title: self.presentationData.strings.Chat_Poll_ContextMenu_SectionOption,
                    footer: self.presentationData.strings.Chat_Poll_ContextMenu_SectionsInfo,
                    source: .extracted(ChatTodoItemContextExtractedContentSource(chatNode: self.chatDisplayNode, contentNode: contentNode)),
                    items: .single(ContextController.Items(content: .list(items)))
                )
            )
            
            let messageContentSource = ChatMessageContextExtractedContentSource(chatController: self, chatNode: self.chatDisplayNode, engine: self.context.engine, message: message, selectAll: false, snapshot: true)
            
            sources.append(
                ContextController.Source(
                    id: AnyHashable(OptionsId.message),
                    title: self.presentationData.strings.Chat_Poll_ContextMenu_SectionPoll,
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

private struct PollConfiguration {
    static var defaultValue: PollConfiguration {
        return PollConfiguration(pollOptionDeletePeriod: 300)
    }
    
    let pollOptionDeletePeriod: Int32
    
    init(pollOptionDeletePeriod: Int32) {
        self.pollOptionDeletePeriod = pollOptionDeletePeriod
    }
    
    static func with(appConfiguration: AppConfiguration) -> PollConfiguration {
        if let data = appConfiguration.data, let pollOptionDeletePeriod = data["poll_answer_delete_period"] as? Double {
            return PollConfiguration(pollOptionDeletePeriod: Int32(pollOptionDeletePeriod))
        } else {
            return .defaultValue
        }
    }
}
