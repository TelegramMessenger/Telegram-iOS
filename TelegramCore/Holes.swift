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
    if tagMask == .PhotoOrVideo {
        return Api.MessagesFilter.inputMessagesFilterPhotoVideo
    } else if tagMask == .File {
        return Api.MessagesFilter.inputMessagesFilterDocument
    } else if tagMask == .Music {
        return Api.MessagesFilter.inputMessagesFilterMusic
    } else if tagMask == .WebPage {
        return Api.MessagesFilter.inputMessagesFilterUrl
    } else if tagMask == .Voice {
        return Api.MessagesFilter.inputMessagesFilterVoice
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
                if let tagMask = tagMask, let filter = messageFilterForTagMask(tagMask) {
                    switch direction {
                        case .UpperToLower:
                            break
                        case .LowerToUpper:
                            assertionFailure(".LowerToUpper not supported")
                        case .AroundIndex:
                            assertionFailure(".AroundIndex not supported")
                    }
                    //request = network.request(Api.functions.messages.search(flags: 0, peer: inputPeer, q: "", filter: filter, minDate: 0, maxDate: hole.maxIndex.timestamp, offset: 0, maxId: hole.maxIndex.id.id + 1, limit: Int32(limit)))
                    request = network.request(Api.functions.messages.search(flags: 0, peer: inputPeer, q: "", filter: filter, minDate: 0, maxDate: hole.maxIndex.timestamp, offset: 0, maxId: Int32.max, limit: Int32(limit)))
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
                    
                    //request = network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: offsetId, offsetDate: hole.maxIndex.timestamp, addOffset: addOffset, limit: Int32(selectedLimit), maxId: hole.maxIndex.id.id == Int32.max ? hole.maxIndex.id.id : (hole.maxIndex.id.id + 1), minId: hole.min - 1))
                    request = network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: offsetId, offsetDate: hole.maxIndex.timestamp, addOffset: addOffset, limit: Int32(selectedLimit), maxId: maxId, minId: minId))
                }
                
                return request
                    |> retryRequest
                    |> mapToSignal { result in
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
                        return postbox.modify { modifier in
                            var storeMessages: [StoreMessage] = []
                            
                            for message in messages {
                                if let storeMessage = StoreMessage(apiMessage: message) {
                                    storeMessages.append(storeMessage)
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
                            
                            modifier.updatePeers(peers, update: { _, updated -> Peer in
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
        return network.request(Api.functions.messages.getDialogs(offsetDate: timestamp, offsetId: id, offsetPeer: peer, limit: 100))
            |> retryRequest
            |> mapToSignal { result -> Signal<Void, NoError> in
                let dialogsChats: [Api.Chat]
                let dialogsUsers: [Api.User]
                
                var replacementHole: ChatListHole?
                var storeMessages: [StoreMessage] = []
                var readStates: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
                var chatStates: [PeerId: PeerChatState] = [:]
                var notificationSettings: [PeerId: PeerNotificationSettings] = [:]
                
                switch result {
                    case let .dialogs(dialogs, messages, chats, users):
                        dialogsChats = chats
                        dialogsUsers = users
                        
                        for dialog in dialogs {
                            let apiPeer: Api.Peer
                            let apiReadInboxMaxId: Int32
                            let apiReadOutboxMaxId: Int32
                            let apiTopMessage: Int32
                            let apiUnreadCount: Int32
                            var apiChannelPts: Int32?
                            let apiNotificationSettings: Api.PeerNotifySettings
                            switch dialog {
                                case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, peerNotificationSettings, pts, _):
                                    apiPeer = peer
                                    apiTopMessage = topMessage
                                    apiReadInboxMaxId = readInboxMaxId
                                    apiReadOutboxMaxId = readOutboxMaxId
                                    apiUnreadCount = unreadCount
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
                            
                            if let apiChannelPts = apiChannelPts {
                                chatStates[peerId] = ChannelState(pts: apiChannelPts)
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
                        
                        dialogsChats = chats
                        dialogsUsers = users
                        
                        for dialog in dialogs {
                            let apiPeer: Api.Peer
                            let apiTopMessage: Int32
                            let apiReadInboxMaxId: Int32
                            let apiReadOutboxMaxId: Int32
                            let apiUnreadCount: Int32
                            let apiNotificationSettings: Api.PeerNotifySettings
                            switch dialog {
                                case let .dialog(_, peer, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, peerNotificationSettings, _, _):
                                    apiPeer = peer
                                    apiTopMessage = topMessage
                                    apiReadInboxMaxId = readInboxMaxId
                                    apiReadOutboxMaxId = readOutboxMaxId
                                    apiUnreadCount = unreadCount
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
                                if replacementHole == nil || replacementHole!.index > index {
                                    replacementHole = ChatListHole(index: index)
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
                    modifier.updatePeers(peers, update: { _, updated -> Peer in
                        return updated
                    })
                    modifier.updatePeerPresences(peerPresences)
                    
                    modifier.updatePeerNotificationSettings(notificationSettings)
                    
                    var allPeersWithMessages = Set<PeerId>()
                    for message in storeMessages {
                        if !allPeersWithMessages.contains(message.id.peerId) {
                            allPeersWithMessages.insert(message.id.peerId)
                        }
                    }
                    modifier.addMessages(storeMessages, location: .UpperHistoryBlock)
                    modifier.replaceChatListHole(hole.index, hole: replacementHole)
                    
                    modifier.resetIncomingReadStates(readStates)
                    
                    for (peerId, chatState) in chatStates {
                        modifier.setPeerChatState(peerId, state: chatState)
                    }
                }
            }
        }
}
