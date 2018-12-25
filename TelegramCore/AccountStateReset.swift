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

private struct LocalChatListEntryRange {
    var upperBound: ChatListIndex?
    var lowerBound: ChatListIndex
    var count: Int32
    var hash: UInt32
    
    var apiHash: Int32 {
        return Int32(bitPattern: self.hash & UInt32(0x7FFFFFFF))
    }
}

private func combineHash(_ value: Int32, into hash: inout UInt32) {
    let low = UInt32(bitPattern: value)
    hash = (hash &* 20261) &+ low
}

private func localChatListEntryRanges(_ entries: [ChatListNamespaceEntry], limit: Int) -> [LocalChatListEntryRange] {
    var result: [LocalChatListEntryRange] = []
    var currentRange: LocalChatListEntryRange?
    for i in 0 ..< entries.count {
        switch entries[i] {
            case let .peer(index, readState, topMessageAttributes, tagSummary, interfaceState):
                var updatedRange: LocalChatListEntryRange
                if let current = currentRange {
                    updatedRange = current
                } else {
                    updatedRange = LocalChatListEntryRange(upperBound: result.last?.lowerBound, lowerBound: index, count: 0, hash: 0)
                }
                updatedRange.lowerBound = index
                updatedRange.count += 1
                
                /*
                 dialog.pinned ? 1 : 0,
                 dialog.unread_mark ? 1 : 0,
                 dialog.peer.channel_id || dialog.peer.chat_id || dialog.peer.user_id,
                 dialog.top_message.id,
                 top_message.edit_date || top_message.date,
                 dialog.read_inbox_max_id,
                 dialog.read_outbox_max_id,
                 dialog.unread_count,
                 dialog.unread_mentions_count,
                 draft.draft.date || 0

                 */
                
                combineHash(index.pinningIndex != nil ? 1 : 0, into: &updatedRange.hash)
                if let readState = readState, readState.markedUnread {
                    combineHash(1, into: &updatedRange.hash)
                } else {
                    combineHash(0, into: &updatedRange.hash)
                }
                combineHash(index.messageIndex.id.peerId.id, into: &updatedRange.hash)
                combineHash(index.messageIndex.id.id, into: &updatedRange.hash)
                var timestamp = index.messageIndex.timestamp
                for attribute in topMessageAttributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        timestamp = max(timestamp, attribute.date)
                    }
                }
                combineHash(timestamp, into: &updatedRange.hash)
                if let readState = readState, case let .idBased(maxIncomingReadId, maxOutgoingReadId, _, count, _) = readState {
                    combineHash(maxIncomingReadId, into: &updatedRange.hash)
                    combineHash(maxOutgoingReadId, into: &updatedRange.hash)
                    combineHash(count, into: &updatedRange.hash)
                } else {
                    combineHash(0, into: &updatedRange.hash)
                    combineHash(0, into: &updatedRange.hash)
                    combineHash(0, into: &updatedRange.hash)
                }
                
                if let tagSummary = tagSummary {
                    combineHash(tagSummary.count, into: &updatedRange.hash)
                } else {
                    combineHash(0, into: &updatedRange.hash)
                }
                
                if let embeddedState = interfaceState?.chatListEmbeddedState {
                    combineHash(embeddedState.timestamp, into: &updatedRange.hash)
                } else {
                    combineHash(0, into: &updatedRange.hash)
                }
            
                if Int(updatedRange.count) >= limit {
                    result.append(updatedRange)
                    currentRange = nil
                } else {
                    currentRange = updatedRange
                }
            case .hole:
                if let currentRangeValue = currentRange {
                    result.append(currentRangeValue)
                    currentRange = nil
                }
        }
    }
    if let currentRangeValue = currentRange {
        result.append(currentRangeValue)
        currentRange = nil
    }
    return result
}

private struct ResolvedChatListResetRange {
    let head: Bool
    let local: LocalChatListEntryRange
    let remote: FetchedChatList
}

func accountStateReset(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Void, NoError> {
    let pinnedChats: Signal<Api.messages.PeerDialogs, NoError> = network.request(Api.functions.messages.getPinnedDialogs())
    |> retryRequest
    let state: Signal<Api.updates.State, NoError> = network.request(Api.functions.updates.getState())
    |> retryRequest
    
    return postbox.transaction { transaction -> [ChatListNamespaceEntry] in
        return transaction.getChatListNamespaceEntries(groupId: nil, namespace: Namespaces.Message.Cloud, summaryTag: MessageTags.unseenPersonalMessage)
    }
    |> mapToSignal { localChatListEntries -> Signal<Void, NoError> in
        let localRanges = localChatListEntryRanges(localChatListEntries, limit: 10)
        var signal: Signal<ResolvedChatListResetRange?, NoError> = .complete()
        for i in 0 ..< localRanges.count {
            let upperBound: MessageIndex
            let head = i == 0
            let localRange = localRanges[i]
            if let rangeUpperBound = localRange.upperBound {
                upperBound = rangeUpperBound.messageIndex
            } else {
                upperBound = MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: 0), namespace: Namespaces.Message.Cloud, id: 0), timestamp: 0)
            }
            
            let rangeSignal: Signal<ResolvedChatListResetRange?, NoError> = fetchChatList(postbox: postbox, network: network, location: .general, upperBound: upperBound, hash: localRange.apiHash, limit: localRange.count)
            |> map { remote -> ResolvedChatListResetRange? in
                if let remote = remote {
                    return ResolvedChatListResetRange(head: head, local: localRange, remote: remote)
                } else {
                    return nil
                }
            }
            
            signal = signal
            |> then(rangeSignal)
        }
        let collectedResolvedRanges: Signal<[ResolvedChatListResetRange], NoError> = signal
        |> map { next -> [ResolvedChatListResetRange] in
            if let next = next {
                return [next]
            } else {
                return []
            }
        }
        |> reduceLeft(value: [], f: { list, next in
            var list = list
            list.append(contentsOf: next)
            return list
        })
        
        return combineLatest(collectedResolvedRanges, state)
        |> mapToSignal { collectedRanges, state -> Signal<Void, NoError> in
            return postbox.transaction { transaction -> Void in
                for range in collectedRanges {
                    let previousPeerIds = transaction.resetChatList(keepPeerNamespaces: [Namespaces.Peer.SecretChat], upperBound: range.local.upperBound ?? ChatListIndex.absoluteUpperBound, lowerBound: range.local.lowerBound)
                    
                    updatePeers(transaction: transaction, peers: range.remote.peers, update: { _, updated -> Peer in
                        return updated
                    })
                    updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: range.remote.peerPresences)
                    
                    transaction.updateCurrentPeerNotificationSettings(range.remote.notificationSettings)
                    
                    var allPeersWithMessages = Set<PeerId>()
                    for message in range.remote.storeMessages {
                        allPeersWithMessages.insert(message.id.peerId)
                    }
                    
                    for (_, messageId) in range.remote.topMessageIds {
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
                    
                    let _ = transaction.addMessages(range.remote.storeMessages, location: .UpperHistoryBlock)
                    
                    transaction.resetIncomingReadStates(range.remote.readStates)
                    
                    for (peerId, chatState) in range.remote.chatStates {
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
                    
                    for (peerId, summary) in range.remote.mentionTagSummaries {
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
                    
                    if range.head {
                        transaction.setPinnedItemIds(range.remote.pinnedItemIds ?? [])
                    }
                }
                
                if let currentState = transaction.getState() as? AuthorizedAccountState, let embeddedState = currentState.state {
                    switch state {
                        case let .state(pts, _, _, seq, _):
                            transaction.setState(currentState.changedState(AuthorizedAccountState.State(pts: pts, qts: embeddedState.qts, date: embeddedState.date, seq: seq)))
                    }
                }
            }
        }
        
        return combineLatest(network.request(Api.functions.messages.getDialogs(flags: 0, offsetDate: 0, offsetId: 0, offsetPeer: .inputPeerEmpty, limit: 100, hash: 0))
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
                updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                
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
}
