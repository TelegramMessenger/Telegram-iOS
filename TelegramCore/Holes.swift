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

private func messageFilterForTagMask(_ tagMask: MessageTags) -> Api.MessagesFilter? {
    if tagMask == .photoOrVideo {
        return Api.MessagesFilter.inputMessagesFilterPhotoVideo
    } else if tagMask == .file {
        return Api.MessagesFilter.inputMessagesFilterDocument
    } else if tagMask == .music {
        return Api.MessagesFilter.inputMessagesFilterMusic
    } else if tagMask == .webPage {
        return Api.MessagesFilter.inputMessagesFilterUrl
    } else if tagMask == .voiceOrInstantVideo {
        return Api.MessagesFilter.inputMessagesFilterRoundVoice
    } else {
        return nil
    }
}

func fetchMessageHistoryHole(network: Network, postbox: Postbox, hole: MessageHistoryHole, direction: MessageHistoryViewRelativeHoleDirection, tagMask: MessageTags?) -> Signal<Void, NoError> {
    return postbox.loadedPeerWithId(hole.maxIndex.id.peerId)
        |> take(1)
        //|> delay(4.0, queue: Queue.concurrentDefaultQueue())
        |> mapToSignal { peer in
            if let inputPeer = apiInputPeer(peer) {
                let limit = 100
                
                let request: Signal<Api.messages.Messages, MTRpcError>
                if let tagMask = tagMask {
                    if tagMask == MessageTags.unseenPersonalMessage {
                        let offsetId: Int32
                        let addOffset: Int32
                        let selectedLimit = limit
                        let maxId: Int32
                        let minId: Int32
                        
                        switch direction {
                            case .UpperToLower:
                                offsetId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                                addOffset = 0
                                maxId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                                minId = 1
                            case .LowerToUpper:
                                offsetId = hole.min <= 1 ? 1 : (hole.min - 1)
                                addOffset = Int32(-limit)
                                maxId = Int32.max
                                minId = hole.min - 1
                            case let .AroundIndex(index):
                                offsetId = index.id.id
                                addOffset = Int32(-limit / 2)
                                maxId = Int32.max
                                minId = 1
                        }
                        request = network.request(Api.functions.messages.getUnreadMentions(peer: inputPeer, offsetId: offsetId, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId))
                    } else if let filter = messageFilterForTagMask(tagMask) {
                        let offsetId: Int32
                        let addOffset: Int32
                        let selectedLimit = limit
                        let maxId: Int32
                        let minId: Int32
                        
                        switch direction {
                            case .UpperToLower:
                                offsetId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                                addOffset = 0
                                maxId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                                minId = 1
                            case .LowerToUpper:
                                offsetId = hole.min <= 1 ? 1 : (hole.min - 1)
                                addOffset = Int32(-limit)
                                maxId = Int32.max
                                minId = hole.min - 1
                            case let .AroundIndex(index):
                                offsetId = index.id.id
                                addOffset = Int32(-limit / 2)
                                maxId = Int32.max
                                minId = 1
                        }
                        
                        request = network.request(Api.functions.messages.search(flags: 0, peer: inputPeer, q: "", fromId: nil, filter: filter, minDate: 0, maxDate: hole.maxIndex.timestamp, offsetId: offsetId, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId))
                    } else {
                        assertionFailure()
                        request = .never()
                    }
                } else {
                    let offsetId: Int32
                    let addOffset: Int32
                    let selectedLimit = limit
                    let maxId: Int32
                    let minId: Int32
                    
                    switch direction {
                        case .UpperToLower:
                            offsetId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                            addOffset = 0
                            maxId = hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1)
                            minId = 1
                        case .LowerToUpper:
                            offsetId = hole.min <= 1 ? 1 : (hole.min - 1)
                            addOffset = Int32(-limit)
                            maxId = Int32.max
                            minId = hole.min - 1
                        case let .AroundIndex(index):
                            offsetId = index.id.id
                            addOffset = Int32(-limit / 2)
                            maxId = Int32.max
                            minId = 1
                    }
                    
                    request = network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: offsetId, offsetDate: hole.maxIndex.timestamp, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId))
                }
                
                return request
                    |> retryRequest
                    |> mapToSignal { result in
                        let messages: [Api.Message]
                        let chats: [Api.Chat]
                        let users: [Api.User]
                        var channelPts: Int32?
                        switch result {
                            case let .messages(messages: apiMessages, chats: apiChats, users: apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                            case let .messagesSlice(_, messages: apiMessages, chats: apiChats, users: apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                            case let .channelMessages(_, pts, _, apiMessages, apiChats, apiUsers):
                                messages = apiMessages
                                chats = apiChats
                                users = apiUsers
                                channelPts = pts
                        }
                        return postbox.modify { modifier in
                            var storeMessages: [StoreMessage] = []
                            
                            for message in messages {
                                if let storeMessage = StoreMessage(apiMessage: message) {
                                    if let channelPts = channelPts {
                                        var attributes = storeMessage.attributes
                                        attributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
                                        storeMessages.append(storeMessage.withUpdatedAttributes(attributes))
                                    } else {
                                        storeMessages.append(storeMessage)
                                    }
                                }
                            }
                            
                            let fillDirection: HoleFillDirection
                            switch direction {
                                case .UpperToLower:
                                    fillDirection = .UpperToLower
                                case .LowerToUpper:
                                    fillDirection = .LowerToUpper
                                case let .AroundIndex(index):
                                    fillDirection = .AroundIndex(index, lowerComplete: false, upperComplete: false)
                            }
                            
                            modifier.fillMultipleHoles(hole, fillType: HoleFill(complete: messages.count == 0, direction: fillDirection), tagMask: tagMask, messages: storeMessages)
                            
                            var peers: [Peer] = []
                            var peerPresences: [PeerId: PeerPresence] = [:]
                            for chat in chats {
                                if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                    peers.append(groupOrChannel)
                                }
                            }
                            for user in users {
                                let telegramUser = TelegramUser(user: user)
                                peers.append(telegramUser)
                                if let presence = TelegramUserPresence(apiUser: user) {
                                    peerPresences[telegramUser.id] = presence
                                }
                            }
                            
                            updatePeers(modifier: modifier, peers: peers, update: { _, updated -> Peer in
                                return updated
                            })
                            modifier.updatePeerPresences(peerPresences)
                            
                            return
                        }
                    }
            } else {
                return fail(Void.self, NoError())
            }
        }
}

func fetchChatListHole(network: Network, postbox: Postbox, hole: ChatListHole) -> Signal<Void, NoError> {
    let offset: Signal<(Int32, Int32, Api.InputPeer), NoError>
    if hole.index.id.peerId.namespace == Namespaces.Peer.Empty {
        offset = single((0, 0, Api.InputPeer.inputPeerEmpty), NoError.self)
    } else {
        offset = postbox.loadedPeerWithId(hole.index.id.peerId)
            |> take(1)
            |> map { peer in
                return (hole.index.timestamp, hole.index.id.id + 1, apiInputPeer(peer) ?? .inputPeerEmpty)
            }
    }
    return offset
        |> mapToSignal { (timestamp, id, peer) in
            let pinnedChats: Signal<Api.messages.PeerDialogs?, NoError>
            if case .inputPeerEmpty = peer, timestamp == 0 {
                pinnedChats = network.request(Api.functions.messages.getPinnedDialogs())
                    |> retryRequest
                    |> map { Optional($0) }
            } else {
                pinnedChats = .single(nil)
            }
            
            return combineLatest(network.request(Api.functions.messages.getDialogs(flags: 0, offsetDate: timestamp, offsetId: id, offsetPeer: peer, limit: 100))
            |> retryRequest, pinnedChats)
            |> mapToSignal { result, pinnedChats -> Signal<Void, NoError> in
                var dialogsChats: [Api.Chat] = []
                var dialogsUsers: [Api.User] = []
                
                var replacementHole: ChatListHole?
                var storeMessages: [StoreMessage] = []
                var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
                var mentionTagSummaries: [PeerId: MessageHistoryTagNamespaceSummary] = [:]
                var chatStates: [PeerId: PeerChatState] = [:]
                var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
                
                switch result {
                    case let .dialogs(dialogs, messages, chats, users):
                        dialogsChats.append(contentsOf: chats)
                        dialogsUsers.append(contentsOf: users)
                        
                        for dialog in dialogs {
                            let apiPeer: Api.Peer
                            let apiReadInboxMaxId: Int32
                            let apiReadOutboxMaxId: Int32
                            let apiTopMessage: Int32
                            let apiUnreadCount: Int32
                            let apiUnreadMentionsCount: Int32
                            var apiChannelPts: Int32?
                            let apiNotificationSettings: Api.PeerNotifySettings
                            switch dialog {
                                case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, peerNotificationSettings, pts, _):
                                    apiPeer = peer
                                    apiTopMessage = topMessage
                                    apiReadInboxMaxId = readInboxMaxId
                                    apiReadOutboxMaxId = readOutboxMaxId
                                    apiUnreadCount = unreadCount
                                    apiUnreadMentionsCount = unreadMentionsCount
                                    apiNotificationSettings = peerNotificationSettings
                                    apiChannelPts = pts
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
                            readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount)
                            
                            if apiTopMessage != 0 {
                                mentionTagSummaries[peerId] = MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage))
                            }
                            
                            if let apiChannelPts = apiChannelPts {
                                chatStates[peerId] = ChannelState(pts: apiChannelPts, invalidatedPts: nil)
                            }
                            
                            notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                        }
                        
                        for message in messages {
                            if let storeMessage = StoreMessage(apiMessage: message) {
                                storeMessages.append(storeMessage)
                            }
                        }
                    case let .dialogsSlice(_, dialogs, messages, chats, users):
                        for message in messages {
                            if let storeMessage = StoreMessage(apiMessage: message) {
                                storeMessages.append(storeMessage)
                            }
                        }
                        
                        dialogsChats.append(contentsOf: chats)
                        dialogsUsers.append(contentsOf: users)
                        
                        for dialog in dialogs {
                            let apiPeer: Api.Peer
                            let apiTopMessage: Int32
                            let apiReadInboxMaxId: Int32
                            let apiReadOutboxMaxId: Int32
                            let apiUnreadCount: Int32
                            let apiUnreadMentionsCount: Int32
                            let apiNotificationSettings: Api.PeerNotifySettings
                            let isPinned: Bool
                            switch dialog {
                                case let .dialog(flags, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, peerNotificationSettings, _, _):
                                    isPinned = (flags & (1 << 2)) != 0
                                    apiPeer = peer
                                    apiTopMessage = topMessage
                                    apiReadInboxMaxId = readInboxMaxId
                                    apiReadOutboxMaxId = readOutboxMaxId
                                    apiUnreadCount = unreadCount
                                    apiUnreadMentionsCount = unreadMentionsCount
                                    apiNotificationSettings = peerNotificationSettings
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
                            readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount)
                            
                            if apiTopMessage != 0 {
                                mentionTagSummaries[peerId] = MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage))
                            }
                            
                            notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                            
                            let topMessageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: apiTopMessage)
                            
                            var timestamp: Int32?
                            for message in storeMessages {
                                if case let .Id(id) = message.id, id == topMessageId {
                                    timestamp = message.timestamp
                                }
                            }
                            
                            if let timestamp = timestamp {
                                let index = MessageIndex(id: MessageId(peerId: topMessageId.peerId, namespace: topMessageId.namespace, id: topMessageId.id - 1), timestamp: timestamp)
                                if !isPinned && (replacementHole == nil || replacementHole!.index > index) {
                                    replacementHole = ChatListHole(index: index)
                                }
                            }
                        }
                }
                
                var replacePinnedPeerIds: [PeerId]?
                
                if let pinnedChats = pinnedChats {
                    switch pinnedChats {
                        case let .peerDialogs(apiDialogs, apiMessages, apiChats, apiUsers, _):
                            dialogsChats.append(contentsOf: apiChats)
                            dialogsUsers.append(contentsOf: apiUsers)
                            
                            var peerIds: [PeerId] = []
                            
                            for dialog in apiDialogs {
                                let apiPeer: Api.Peer
                                let apiReadInboxMaxId: Int32
                                let apiReadOutboxMaxId: Int32
                                let apiTopMessage: Int32
                                let apiUnreadCount: Int32
                                let apiUnreadMentionsCount: Int32
                                var apiChannelPts: Int32?
                                let apiNotificationSettings: Api.PeerNotifySettings
                                switch dialog {
                                    case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, unreadMentionsCount, peerNotificationSettings, pts, _):
                                        apiPeer = peer
                                        apiTopMessage = topMessage
                                        apiReadInboxMaxId = readInboxMaxId
                                        apiReadOutboxMaxId = readOutboxMaxId
                                        apiUnreadCount = unreadCount
                                        apiUnreadMentionsCount = unreadMentionsCount
                                        apiNotificationSettings = peerNotificationSettings
                                        apiChannelPts = pts
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
                                
                                peerIds.append(peerId)
                                
                                if readStates[peerId] == nil {
                                    readStates[peerId] = [:]
                                }
                                readStates[peerId]![Namespaces.Message.Cloud] = .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount)
                                
                                if apiTopMessage != 0 {
                                    mentionTagSummaries[peerId] = MessageHistoryTagNamespaceSummary(version: 1, count: apiUnreadMentionsCount, range: MessageHistoryTagNamespaceCountValidityRange(maxId: apiTopMessage))
                                }
                                
                                if let apiChannelPts = apiChannelPts {
                                    chatStates[peerId] = ChannelState(pts: apiChannelPts, invalidatedPts: nil)
                                }
                                
                                notificationSettings[peerId] = TelegramPeerNotificationSettings(apiSettings: apiNotificationSettings)
                            }
                            
                            replacePinnedPeerIds = peerIds
                            
                            for message in apiMessages {
                                if let storeMessage = StoreMessage(apiMessage: message) {
                                    storeMessages.append(storeMessage)
                                }
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
                
                return postbox.modify { modifier in
                    updatePeers(modifier: modifier, peers: peers, update: { _, updated -> Peer in
                        return updated
                    })
                    modifier.updatePeerPresences(peerPresences)
                    
                    modifier.updateCurrentPeerNotificationSettings(notificationSettings)
                    
                    var allPeersWithMessages = Set<PeerId>()
                    for message in storeMessages {
                        if !allPeersWithMessages.contains(message.id.peerId) {
                            allPeersWithMessages.insert(message.id.peerId)
                        }
                    }
                    let _ = modifier.addMessages(storeMessages, location: .UpperHistoryBlock)
                    modifier.replaceChatListHole(hole.index, hole: replacementHole)
                    
                    modifier.resetIncomingReadStates(readStates)
                    
                    for (peerId, chatState) in chatStates {
                        if let chatState = chatState as? ChannelState {
                            if let current = modifier.getPeerChatState(peerId) as? ChannelState {
                                modifier.setPeerChatState(peerId, state: current.withUpdatedPts(chatState.pts))
                            } else {
                                modifier.setPeerChatState(peerId, state: chatState)
                            }
                        } else {
                            modifier.setPeerChatState(peerId, state: chatState)
                        }
                    }
                    
                    if let replacePinnedPeerIds = replacePinnedPeerIds {
                        modifier.setPinnedPeerIds(replacePinnedPeerIds)
                    }
                    
                    for (peerId, summary) in mentionTagSummaries {
                        modifier.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: summary.count, maxId: summary.range.maxId)
                    }
                }
            }
        }
}

func fetchCallListHole(network: Network, postbox: Postbox, holeIndex: MessageIndex, limit: Int32 = 100) -> Signal<Void, NoError> {
    let offset: Signal<(Int32, Int32, Api.InputPeer), NoError>
    if holeIndex.id.peerId.namespace == Namespaces.Peer.Empty {
        offset = single((0, 0, Api.InputPeer.inputPeerEmpty), NoError.self)
    } else {
        offset = postbox.loadedPeerWithId(holeIndex.id.peerId)
            |> take(1)
            |> map { peer in
                return (holeIndex.timestamp, holeIndex.id.id + 1, apiInputPeer(peer) ?? .inputPeerEmpty)
        }
    }
    return offset
        |> mapToSignal { (timestamp, id, peer) -> Signal<Void, NoError> in
            let searchResult = network.request(Api.functions.messages.search(flags: 0, peer: peer, q: "", fromId: nil, filter: .inputMessagesFilterPhoneCalls(flags: 0), minDate: 0, maxDate: holeIndex.timestamp, offsetId: 0, addOffset: 0, limit: limit, maxId: holeIndex.id.id, minId: 0))
                |> retryRequest
                |> mapToSignal { result -> Signal<Void, NoError> in
                    let messages: [Api.Message]
                    let chats: [Api.Chat]
                    let users: [Api.User]
                    switch result {
                        case let .messages(messages: apiMessages, chats: apiChats, users: apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case let .messagesSlice(_, messages: apiMessages, chats: apiChats, users: apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case let .channelMessages(_, _, _, apiMessages, apiChats, apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                    }
                    return postbox.modify { modifier -> Void in
                        var storeMessages: [StoreMessage] = []
                        var topIndex: MessageIndex?
                        
                        for message in messages {
                            if let storeMessage = StoreMessage(apiMessage: message) {
                                storeMessages.append(storeMessage)
                                if let index = storeMessage.index, topIndex == nil || index < topIndex! {
                                    topIndex = index
                                }
                            }
                        }
                        
                        var updatedIndex: MessageIndex?
                        if let topIndex = topIndex {
                            updatedIndex = topIndex.predecessor()
                        }
                        
                        modifier.replaceGlobalMessageTagsHole(globalTags: [.Calls, .MissedCalls], index: holeIndex, with: updatedIndex, messages: storeMessages)
                        
                        var peers: [Peer] = []
                        var peerPresences: [PeerId: PeerPresence] = [:]
                        for chat in chats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers.append(groupOrChannel)
                            }
                        }
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            if let presence = TelegramUserPresence(apiUser: user) {
                                peerPresences[telegramUser.id] = presence
                            }
                        }
                        
                        updatePeers(modifier: modifier, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        modifier.updatePeerPresences(peerPresences)
                    }
                }
            return searchResult
        }
}
