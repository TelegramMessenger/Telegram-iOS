import Foundation
import TelegramPresentationData
import AccountContext
import Postbox
import TelegramCore
import SwiftSignalKit
import ContextUI
import ChatControllerInteraction
import Display
import UIKit
import UndoUI
import ShareController
import ChatQrCodeScreen
import ChatShareMessageTagView
import ReactionSelectionNode
import TopMessageReactions

func chatShareToSavedMessagesAdditionalView(_ chatController: ChatControllerImpl, reactionItems: [ReactionItem], correlationIds: [Int64]) -> (() -> UndoOverlayControllerAdditionalView?)? {
    if !chatController.presentationInterfaceState.isPremium {
        return nil
    }
    if correlationIds.count < 1 {
        return nil
    }
    return { [weak chatController] () -> UndoOverlayControllerAdditionalView? in
        guard let chatController else {
            return nil
        }
        return ChatShareMessageTagView(context: chatController.context, presentationData: chatController.presentationData, isSingleMessage: correlationIds.count == 1, reactionItems: reactionItems, completion: { [weak chatController] file, updateReaction in
            guard let chatController else {
                return
            }
            
            let _ = (chatController.context.account.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: chatController.context.account.peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), count: 45, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: Set(), tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .not(Namespaces.Message.allNonRegular), orderStatistics: [])
            |> map { view, _, _ -> [EngineMessage.Id] in
                let messageIds = correlationIds.compactMap { correlationId in
                    return chatController.context.engine.messages.synchronouslyLookupCorrelationId(correlationId: correlationId)
                }
                if messageIds.isEmpty {
                    return []
                }
                
                let exactResult = view.entries.compactMap { entry -> EngineMessage.Id? in
                    if messageIds.contains(entry.message.id) {
                        return entry.message.id
                    } else {
                        return nil
                    }
                }
                if !exactResult.isEmpty {
                    return exactResult
                }
                
                return []
            }
            |> filter { !$0.isEmpty }
            |> take(1)
            |> timeout(5.0, queue: .mainQueue(), alternate: .single([]))
            |> deliverOnMainQueue).start(next: { [weak chatController] messageIds in
                guard let chatController else {
                    return
                }
                if !messageIds.isEmpty {
                    let _ = chatController.context.engine.messages.setMessageReactions(ids: messageIds, reactions: [updateReaction])
                    
                    var isBuiltinReaction = false
                    if case .builtin = updateReaction {
                        isBuiltinReaction = true
                    }
                    let presentationData = chatController.context.sharedContext.currentPresentationData.with { $0 }
                    chatController.present(UndoOverlayController(presentationData: presentationData, content: .messageTagged(context: chatController.context, isSingleMessage: messageIds.count == 1, customEmoji: file, isBuiltinReaction: isBuiltinReaction, customUndoText: presentationData.strings.Chat_ToastMessageTagged_Action), elevatedLayout: false, position: .top, animateInAsReplacement: false, action: { [weak chatController] action in
                        if (action == .info || action == .undo), let chatController {
                            let _ = (chatController.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: chatController.context.account.peerId))
                            |> deliverOnMainQueue).start(next: { [weak chatController] peer in
                                guard let chatController else {
                                    return
                                }
                                guard let peer else {
                                    return
                                }
                                guard let navigationController = chatController.navigationController as? NavigationController else {
                                    return
                                }
                                chatController.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: chatController.context, chatLocation: .peer(peer), forceOpenChat: true))
                            })
                            return false
                        }
                        return false
                    }), in: .current)
                }
            })
        })
    }
}

extension ChatControllerImpl {
    func openMessageShareMenu(id: EngineMessage.Id) {
        guard let messages = self.chatDisplayNode.historyNode.messageGroupInCurrentHistoryView(id), let message = messages.first else {
            return
        }

        let chatPresentationInterfaceState = self.presentationInterfaceState
        var warnAboutPrivate = false
        var canShareToStory = false
        if case .peer = chatPresentationInterfaceState.chatLocation, let channel = message.peers[message.id.peerId] as? TelegramChannel {
            if case .broadcast = channel.info {
                canShareToStory = true
            }
            if channel.addressName == nil {
                warnAboutPrivate = true
            }
        }
        let shareController = ShareController(context: self.context, subject: .messages(messages), updatedPresentationData: self.updatedPresentationData, shareAsLink: true)
        shareController.parentNavigationController = self.navigationController as? NavigationController
        
        if let message = messages.first, message.media.contains(where: { media in
            if media is TelegramMediaContact || media is TelegramMediaPoll {
                return true
            } else if let file = media as? TelegramMediaFile, file.isSticker || file.isAnimatedSticker || file.isVideoSticker {
                return true
            } else {
                return false
            }
        }) {
            canShareToStory = false
        }
        if message.text.containsOnlyEmoji {
            canShareToStory = false
        }
        
        if canShareToStory {
            shareController.shareStory = { [weak self] in
                guard let self else {
                    return
                }
                Queue.mainQueue().after(0.15) {
                    let controller = self.context.sharedContext.makeStorySharingScreen(context: self.context, subject: .messages(messages), parentController: self)
                    self.push(controller)
                }
            }
        }
        shareController.openShareAsImage = { [weak self] messages in
            guard let self else {
                return
            }
            self.present(ChatQrCodeScreenImpl(context: self.context, subject: .messages(messages)), in: .window(.root))
        }
        shareController.dismissed = { [weak self] shared in
            if shared {
                self?.commitPurposefulAction()
            }
        }
        shareController.actionCompleted = { [weak self] in
            guard let self else {
                return
            }
            let content: UndoOverlayContent
            if warnAboutPrivate {
                content = .linkCopied(title: nil, text: self.presentationData.strings.Conversation_PrivateMessageLinkCopiedLong)
            } else {
                content = .linkCopied(title: nil, text: self.presentationData.strings.Conversation_LinkCopied)
            }
            self.present(UndoOverlayController(presentationData: self.presentationData, content: content, elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
        }
        shareController.enqueued = { [weak self] peerIds, correlationIds in
            guard let self else {
                return
            }
          
            let _ = (self.context.engine.data.get(
                EngineDataList(
                    peerIds.map(TelegramEngine.EngineData.Item.Peer.RenderedPeer.init)
                )
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peerList in
                guard let self else {
                    return
                }
                let peers = peerList.compactMap { $0 }
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                let text: String
                var savedMessages = false
                if peerIds.count == 1, let peerId = peerIds.first, peerId == self.context.account.peerId {
                    text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One : presentationData.strings.Conversation_ForwardTooltip_SavedMessages_Many
                    savedMessages = true
                } else {
                    if peers.count == 1, let peer = peers.first?.chatOrMonoforumMainPeer {
                        var peerName = peer.id == self.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        peerName = peerName.replacingOccurrences(of: "**", with: "")
                        text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_Chat_One(peerName).string : presentationData.strings.Conversation_ForwardTooltip_Chat_Many(peerName).string
                    } else if peers.count == 2, let firstPeer = peers.first?.chatOrMonoforumMainPeer, let secondPeer = peers.last?.chatOrMonoforumMainPeer {
                        var firstPeerName = firstPeer.id == self.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        firstPeerName = firstPeerName.replacingOccurrences(of: "**", with: "")
                        var secondPeerName = secondPeer.id == self.context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        secondPeerName = secondPeerName.replacingOccurrences(of: "**", with: "")
                        text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string : presentationData.strings.Conversation_ForwardTooltip_TwoChats_Many(firstPeerName, secondPeerName).string
                    } else if let peer = peers.first?.chatOrMonoforumMainPeer {
                        var peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        peerName = peerName.replacingOccurrences(of: "**", with: "")
                        text = messages.count == 1 ? presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string : presentationData.strings.Conversation_ForwardTooltip_ManyChats_Many(peerName, "\(peers.count - 1)").string
                    } else {
                        text = ""
                    }
                }
                
                let reactionItems: Signal<[ReactionItem], NoError>
                if savedMessages {
                    reactionItems = tagMessageReactions(context: self.context, subPeerId: self.chatLocation.threadId.flatMap(EnginePeer.Id.init))
                } else {
                    reactionItems = .single([])
                }
                
                let _ = (reactionItems
                |> deliverOnMainQueue).startStandalone(next: { [weak self] reactionItems in
                    guard let self else {
                        return
                    }
                    
                    self.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, position: savedMessages ? .top : .bottom, animateInAsReplacement: !savedMessages, action: { [weak self] action in
                        if savedMessages, let self, action == .info {
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
                    }, additionalView: savedMessages ? chatShareToSavedMessagesAdditionalView(self, reactionItems: reactionItems, correlationIds: correlationIds) : nil), in: .current)
                })
            })
        }
        self.chatDisplayNode.dismissInput()
        self.present(shareController, in: .window(.root), blockInteraction: true)
    }
}
