import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

func accountStateReset(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let pinnedChats: Signal<Api.messages.PeerDialogs, NoError> = network.request(Api.functions.messages.getPinnedDialogs())
        |> retryRequest
    let state: Signal<Api.updates.State, NoError> =
        network.request(Api.functions.updates.getState())
            |> retryRequest
    
    return combineLatest(network.request(Api.functions.messages.getDialogs(flags: 0, /*feed*//*feedId: nil,*/ offsetDate: 0, offsetId: 0, offsetPeer: .inputPeerEmpty, limit: 100, hash: 0))
    |> retryRequest, pinnedChats, state)
    |> mapToSignal { result, pinnedChats, state -> Signal<Void, NoError> in
        var dialogsDialogs: [Api.Dialog] = []
        var dialogsMessages: [Api.Message] = []
        var dialogsChats: [Api.Chat] = []
        var dialogsUsers: [Api.User] = []
        
        var holeExists = false
        
        switch result {
            case let .dialogs(dialogs, messages, chats, users):
                dialogsDialogs = dialogs
                dialogsMessages = messages
                dialogsChats = chats
                dialogsUsers = users
            case let .dialogsSlice(_, dialogs, messages, chats, users):
                dialogsDialogs = dialogs
                dialogsMessages = messages
                dialogsChats = chats
                dialogsUsers = users
                holeExists = true
            case .dialogsNotModified:
                dialogsDialogs = []
                dialogsMessages = []
                dialogsChats = []
                dialogsUsers = []
        }
        
        let replacePinnedItemIds: [PinnedItemId]
        switch pinnedChats {
            case let .peerDialogs(apiDialogs, apiMessages, apiChats, apiUsers, _):
                dialogsDialogs.append(contentsOf: apiDialogs)
                dialogsMessages.append(contentsOf: apiMessages)
                dialogsChats.append(contentsOf: apiChats)
                dialogsUsers.append(contentsOf: apiUsers)
                
                var itemIds: [PinnedItemId] = []
                
                loop: for dialog in apiDialogs {
                    switch dialog {
                        case let .dialog(_, peer, _, _, _, _, _, _, _, _):
                            itemIds.append(.peer(peer.peerId))
                        /*feed*/
                        /*case let .dialogFeed(_, _, _, feedId, _, _, _, _):
                            itemIds.append(.group(PeerGroupId(rawValue: feedId)))
                            continue loop*/
                    }
            }
            
            replacePinnedItemIds = itemIds
        }
        
        var replacementHole: ChatListHole?
        var storeMessages: [StoreMessage] = []
        var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
        var mentionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary] = [:]
        var chatStates: [PeerId: PeerChatState] = [:]
        var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
        
        var topMesageIds: [PeerId: MessageId] = [:]
        
        loop: for dialog in dialogsDialogs {
            let apiPeer: Api.Peer
            let apiReadInboxMaxId: Int32
            let apiReadOutboxMaxId: Int32
            let apiTopMessage: Int32
            let apiUnreadCount: Int32
            let apiMarkedUnread: Bool
            let apiUnreadMentionsCount: Int32
            var apiChannelPts: Int32?
            let apiNotificationSettings: Api.PeerNotifySettings
            switch dialog {
                case let .dialog(flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, peerNotificationSettings, pts, _):
                    apiPeer = peer
                    apiTopMessage = topMessage
                    apiReadInboxMaxId = readInboxMaxId
                    apiReadOutboxMaxId = readOutboxMaxId
                    apiUnreadCount = unreadCount
                    apiMarkedUnread = (flags & (1 << 3)) != 0
                    apiUnreadMentionsCount = unreadMentionsCount
                    apiNotificationSettings = peerNotificationSettings
                    apiChannelPts = pts
                /*feed*/
                /*case .dialogFeed:
                    //assertionFailure()
                    continue loop*/
            }
            
            let peerId: PeerId
            switch apiPeer {
                case let .peerUser(userId):
                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                case let .peerChat(chatId):
                    peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: chatId)
                case let .peerChannel(channelId):
                    peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId)
            }
            
            if readStates[peerId] == nil {
                readStates[peerId] = [:]
            }
            readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount,  markedUnread: apiMarkedUnread)
            
            if apiTopMessage != 0 {
                mentionTagSummaries[peerId] = MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage))
                topMesageIds[peerId] = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: apiTopMessage)
            }
            
            if let apiChannelPts = apiChannelPts {
                chatStates[peerId] = ChannelState(pts: apiChannelPts, invalidatedPts: apiChannelPts)
            } else if peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudUser {
                switch state {
                    case let .state(pts, _, _, _, _):
                        chatStates[peerId] = RegularChatState(invalidatedPts: pts)
                }
            }
            
            notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
        }
        
        for message in dialogsMessages {
            if let storeMessage = StoreMessage(apiMessage: message) {
                storeMessages.append(storeMessage)
            }
        }
        
        if holeExists {
            for dialog in dialogsDialogs {
                switch dialog {
                    case let .dialog(flags, peer, topMessage, _, _, _, _, _, _, _):
                        let isPinned = (flags & (1 << 2)) != 0
                        
                        if !isPinned {
                            var timestamp: Int32?
                            for message in storeMessages {
                                if case let .Id(id) = message.id, id.id == topMessage {
                                    timestamp = message.timestamp
                                }
                            }
                            
                            if let timestamp = timestamp {
                                let index = MessageIndex(id: MessageId(peerId: peer.peerId, namespace: Namespaces.Message.Cloud, id: topMessage - 1), timestamp: timestamp)
                                if (replacementHole == nil || replacementHole!.index > index) {
                                    replacementHole = ChatListHole(index: index)
                                }
                            }
                        }
                    /*feed*/
                    /*case .dialogFeed:
                        //assertionFailure()
                        break*/
                }
            }
        }
        
        var peers: [Peer] = []
        var peerPresences: [PeerId: PeerPresence] = [:]
        for chat in dialogsChats {
            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                peers.append(groupOrChannel)
            }
        }
        for user in dialogsUsers {
            let telegramUser = TelegramUser(user: user)
            peers.append(telegramUser)
            if let presence = TelegramUserPresence(apiUser: user) {
                peerPresences[telegramUser.id] = presence
            }
        }
        
        return withResolvedAssociatedMessages(postbox: postbox, source: .network(network), storeMessages: storeMessages, { transaction, additionalPeers, additionalMessages in
            let previousPeerIds = transaction.resetChatList(keepPeerNamespaces: Set([Namespaces.Peer.SecretChat]), replacementHole: replacementHole)
            
            updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                return updated
            })
            transaction.updatePeerPresences(peerPresences)
            
            transaction.updateCurrentPeerNotificationSettings(notificationSettings)
            
            var allPeersWithMessages = Set<PeerId>()
            for message in storeMessages {
                allPeersWithMessages.insert(message.id.peerId)
            }
            
            for (_, messageId) in topMesageIds {
                if messageId.id > 1 {
                    var skipHole = false
                    if let localTopId = transaction.getTopPeerMessageIndex(peerId: messageId.peerId, namespace: messageId.namespace)?.id {
                        if localTopId >= messageId {
                            skipHole = true
                        }
                    }
                    if !skipHole {
                        transaction.addHole(MessageId(peerId: messageId.peerId, namespace: messageId.namespace, id: messageId.id - 1))
                    }
                }
            }
            
            let _ = transaction.addMessages(storeMessages, location: .UpperHistoryBlock)
            
            transaction.resetIncomingReadStates(readStates)
            
            for (peerId, chatState) in chatStates {
                if let chatState = chatState as? ChannelState {
                    if let current = transaction.getPeerChatState(peerId) as? ChannelState {
                        transaction.setPeerChatState(peerId, state: current.withUpdatedPts(chatState.pts))
                    } else {
                        transaction.setPeerChatState(peerId, state: chatState)
                    }
                } else {
                    transaction.setPeerChatState(peerId, state: chatState)
                }
            }
            
            transaction.setPinnedItemIds(replacePinnedItemIds)
            
            for (peerId, summary) in mentionTagSummaries {
                transaction.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: summary.count, maxId: summary.range.maxId)
            }
            
            let namespacesWithHoles: [PeerId.Namespace: [MessageId.Namespace]] = [
                Namespaces.Peer.CloudUser: [Namespaces.Message.Cloud],
                Namespaces.Peer.CloudGroup: [Namespaces.Message.Cloud],
                Namespaces.Peer.CloudChannel: [Namespaces.Message.Cloud]
            ]
            for peerId in previousPeerIds {
                if !allPeersWithMessages.contains(peerId), let namespaces = namespacesWithHoles[peerId.namespace] {
                    for namespace in namespaces {
                        transaction.addHole(MessageId(peerId: peerId, namespace: namespace, id: Int32.max - 1))
                    }
                }
            }
            
            if let currentState = transaction.getState() as? AuthorizedAccountState, let embeddedState = currentState.state {
                switch state {
                    case let .state(pts, _, _, seq, _):
                        transaction.setState(currentState.changedState(AuthorizedAccountState.State(pts: pts, qts: embeddedState.qts, date: embeddedState.date, seq: seq)))
                }
            }
        })
    }
}
