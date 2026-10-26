import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import PeerInfoPaneNode

extension PeerInfoScreenNode {
    func openChatWithMessageSearch() {
        if let navigationController = (self.controller?.navigationController as? NavigationController) {
            if case let .replyThread(currentMessage) = self.chatLocation, let current = navigationController.viewControllers.first(where: { controller in
                if let controller = controller as? ChatController, case let .replyThread(message) = controller.chatLocation, message.peerId == currentMessage.peerId, message.threadId == currentMessage.threadId {
                    return true
                }
                return false
            }) as? ChatController {
                var viewControllers = navigationController.viewControllers
                if let index = viewControllers.firstIndex(of: current) {
                    viewControllers.removeSubrange(index + 1 ..< viewControllers.count)
                }
                navigationController.setViewControllers(viewControllers, animated: true)
                current.activateSearch(domain: .everything, query: "")
            } else if let peer = self.data?.chatPeer {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), keepStack: .default, activateMessageSearch: (.everything, "")))
            }
        }
    }
    
    func openChatForReporting(title: String, option: Data, message: String?) {
        if let peer = self.data?.peer, let navigationController = (self.controller?.navigationController as? NavigationController) {
            if case let .channel(channel) = peer, channel.isForumOrMonoForum {
                //let _ = self.context.engine.peers.reportPeer(peerId: peer.id, reason: reason, message: "").startStandalone()
                //self.controller?.present(UndoOverlayController(presentationData: self.presentationData, content: .emoji(name: "PoliceCar", text: self.presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
            } else {
                self.context.sharedContext.navigateToChatController(
                    NavigateToChatControllerParams(
                        navigationController: navigationController,
                        context: self.context,
                        chatLocation: .peer(peer),
                        keepStack: .default,
                        reportReason: NavigateToChatControllerParams.ReportReason(title: title, option: option, message: message)
                    )
                )
            }
        }
    }
    
    func openChatForThemeChange() {
        if let peer = self.data?.peer, let navigationController = (self.controller?.navigationController as? NavigationController) {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), keepStack: .default, changeColors: true))
        }
    }

    func openChatForTranslation() {
        if let peer = self.data?.peer, let navigationController = (self.controller?.navigationController as? NavigationController) {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), keepStack: .default, changeColors: false))
        }
    }

    func openChat(peerId: EnginePeer.Id?) {
        if let peerId {
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                guard let navigationController = self.controller?.navigationController as? NavigationController else {
                    return
                }
                
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), keepStack: .always))
            })
            return
        }
        
        if let peer = self.data?.peer, let navigationController = self.controller?.navigationController as? NavigationController {
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), keepStack: .default))
        }
    }
    
    func openDeleteReaction(messageId: EngineMessage.Id) {
        guard let authorPeer = self.data?.peer, let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }

        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId),
            TelegramEngine.EngineData.Item.Messages.Message(id: messageId)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] sourcePeer, sourceMessage in
            guard let self, let sourcePeer, let sourceMessage = sourceMessage?._asMessage() else {
                return
            }
            guard let channel = sourceMessage.peers[sourceMessage.id.peerId] as? TelegramChannel, channel.hasPermission(.deleteAllMessages) else {
                return
            }

            var hasReaction = false
            for attribute in sourceMessage.attributes {
                guard let attribute = attribute as? ReactionsMessageAttribute else {
                    continue
                }
                if attribute.recentPeers.contains(where: { $0.peerId == authorPeer.id }) || attribute.topPeers.contains(where: { $0.peerId == authorPeer.id }) {
                    hasReaction = true
                    break
                }
            }
            guard hasReaction else {
                return
            }

            let chatLocation: NavigateToChatControllerParams.Location
            if case let .channel(channel) = sourcePeer, channel.isForumOrMonoForum, let threadId = sourceMessage.threadId {
                chatLocation = .replyThread(ChatReplyThreadMessage(peerId: sourcePeer.id, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: true, isMonoforumPost: channel.isMonoForum, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false))
            } else {
                chatLocation = .peer(sourcePeer)
            }

            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: chatLocation, subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always, useExisting: true, completion: { chatController in
                chatController.presentReactionDeletionOptions(author: authorPeer, messageId: messageId)
            }))
        })
    }

    /// Where "View in Chat" opens a message listed in the shared-media panes.
    func sharedMediaMessageChatDestination(message: EngineMessage) -> PeerInfoMessageChatDestination? {
        var listedThread: ChatReplyThreadMessage?
        if case let .replyThread(thread) = self.sharedMediaChatLocation.chatLocation {
            listedThread = thread
        }
        return peerInfoMessageChatDestination(message: message, listedPeer: self.data?.chatPeer, listedThread: listedThread)
    }
    
    /// How "View in Chat" leaves the profile. The destination refines it: a forum topic always
    /// resolves through `navigateToForumThread`, and a thread returns to an open copy of it when
    /// there is one.
    enum SharedMediaChatNavigation {
        /// Push the chat on top of the profile; the chat's first purposeful action then removes the
        /// profile (and, for a plain chat, older copies of the profile's chat). The shared-media
        /// context menus.
        case push
        /// Go back to an open copy of the chat, or replace the stack. The media calendar.
        case returnToExisting
    }
    
    /// "View in Chat" for a message listed in the shared-media panes.
    func openSharedMediaChat(destination: PeerInfoMessageChatDestination, messageId: EngineMessage.Id, navigation: SharedMediaChatNavigation) {
        guard let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        // navigateToForumThread always highlights the message, so every destination does.
        let subject: ChatControllerSubject = .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false)
        
        switch destination {
        case let .forumTopic(peerId, threadId):
            let keepStack: NavigateToChatKeepStack
            switch navigation {
            case .push:
                keepStack = .default
            case .returnToExisting:
                keepStack = .never
            }
            let _ = self.context.sharedContext.navigateToForumThread(context: self.context, peerId: peerId, threadId: threadId, messageId: messageId, navigationController: navigationController, activateInput: nil, scrollToEndIfExists: false, keepStack: keepStack, animated: true).startStandalone()
        case let .replyThread(thread):
            // The navigator goes back to an open copy of a forum or direct-messages thread, which
            // pops the profile as well. It never matches any other thread (a Saved Messages
            // sub-chat, a comment thread), so there a second copy is pushed, and its first
            // purposeful action removes this profile and the copy the profile was opened from.
            // Nothing else: the `.peer` cleanup below would also drop the channel's own chat
            // further down the stack, and a filter on the controller type would drop unrelated
            // profiles.
            let openCopies = navigationController.viewControllers.filter { controller in
                guard let controller = controller as? ChatController else {
                    return false
                }
                return controller.chatLocation.peerId == thread.peerId && controller.chatLocation.threadId == thread.threadId
            }
            var purposefulAction: (() -> Void)?
            if let openCopy = openCopies.last as? ChatController, thread.isForumPost || thread.isMonoforumPost {
                // The navigator installs the action on the copy it returns to (the topmost one);
                // keep that copy's own.
                purposefulAction = openCopy.purposefulAction
            } else if case .push = navigation {
                var removedControllers: [Weak<UIViewController>] = openCopies.map { Weak($0) }
                if let controller = self.controller {
                    removedControllers.append(Weak(controller))
                }
                purposefulAction = {
                    navigationController.setViewControllers(navigationController.viewControllers.filter { controller in
                        return !removedControllers.contains(where: { $0.value === controller })
                    }, animated: false)
                }
            }
            self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .replyThread(thread), subject: subject, keepStack: navigation == .push ? .always : .never, useExisting: true, purposefulAction: purposefulAction))
        case let .peer(peer):
            switch navigation {
            case .push:
                let currentPeerId = self.peerId
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), subject: subject, keepStack: .always, useExisting: false, purposefulAction: {
                    var viewControllers = navigationController.viewControllers
                    var indexesToRemove = Set<Int>()
                    var keptCurrentChatController = false
                    var index: Int = viewControllers.count - 1
                    for controller in viewControllers.reversed() {
                        if let controller = controller as? ChatController, case let .peer(peerId) = controller.chatLocation {
                            if peerId == currentPeerId && !keptCurrentChatController {
                                keptCurrentChatController = true
                            } else {
                                indexesToRemove.insert(index)
                            }
                        } else if controller is PeerInfoScreen {
                            indexesToRemove.insert(index)
                        }
                        index -= 1
                    }
                    for i in indexesToRemove.sorted().reversed() {
                        viewControllers.remove(at: i)
                    }
                    navigationController.setViewControllers(viewControllers, animated: false)
                }))
            case .returnToExisting:
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), subject: subject, keepStack: .never, useExisting: true))
            }
        }
    }
    
    /// "View in Chat" from the shared-media context menus.
    func openSharedMediaMessageInChat(message: EngineRawMessage) {
        guard let destination = self.sharedMediaMessageChatDestination(message: EngineMessage(message)) else {
            return
        }
        self.openSharedMediaChat(destination: destination, messageId: message.id, navigation: .push)
    }
    
    func openChatWithClearedHistory(type: InteractiveHistoryClearingType) {
        guard let peer = self.data?.chatPeer, let navigationController = self.controller?.navigationController as? NavigationController else {
            return
        }
        
        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer), keepStack: .default, setupController: { controller in
            controller.beginClearHistory(type: type)
        }))
    }

    func openChannelMessages() {
        guard case let .channel(channel) = self.data?.peer, let linkedMonoforumId = channel.linkedMonoforumId else {
            return
        }
        let _ = (self.context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: linkedMonoforumId)
        )
        |> deliverOnMainQueue).startStandalone(next: { [weak self] peer in
            guard let self, let peer else {
                return
            }
            if let controller = self.controller, let navigationController = controller.navigationController as? NavigationController {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(peer)))
            }
        })
    }

    func openRecentActions() {
        guard let peer = self.data?.peer else {
            return
        }
        let controller = self.context.sharedContext.makeChatRecentActionsController(context: self.context, peer: peer, adminPeerId: nil, starsState: self.data?.starsRevenueStatsState)
        self.controller?.push(controller)
    }
}
