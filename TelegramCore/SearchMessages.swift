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

public enum SearchMessagesLocation: Equatable {
    case general
    case group(PeerGroupId)
    case peer(peerId: PeerId, fromId: PeerId?, tags: MessageTags?)
    
    public static func ==(lhs: SearchMessagesLocation, rhs: SearchMessagesLocation) -> Bool {
        switch lhs {
            case .general:
                if case .general = rhs {
                    return true
                } else {
                    return false
                }
            case let .group(groupId):
                if case .group(groupId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .peer(lhsPeerId, lhsFromId, lhsTags):
                if case let .peer(rhsPeerId, rhsFromId, rhsTags) = rhs, lhsPeerId == rhsPeerId, lhsFromId == rhsFromId, lhsTags == rhsTags {
                    return true
                } else {
                    return false
                }
        }
    }
}

public func searchMessages(account: Account, location: SearchMessagesLocation, query: String) -> Signal<([Message], [PeerId : CombinedPeerReadState]), NoError> {
    let remoteSearchResult: Signal<Api.messages.Messages?, NoError>
    switch location {
        case let .peer(peerId, fromId, tags):
            if peerId.namespace == Namespaces.Peer.SecretChat {
                return account.postbox.transaction { transaction -> ([Message], [PeerId : CombinedPeerReadState]) in
                    var readStates: [PeerId : CombinedPeerReadState] = [:]
                    if let readState = transaction.getCombinedPeerReadState(peerId) {
                        readStates[peerId] = readState
                    }
                    return (transaction.searchMessages(peerId: peerId, query: query, tags: tags), readStates)
                }
            }
            
            let filter: Api.MessagesFilter
            
            if let tags = tags {
                if tags.contains(.file) {
                    filter = .inputMessagesFilterDocument
                } else if tags.contains(.music) {
                    filter = .inputMessagesFilterMusic
                } else if tags.contains(.webPage) {
                    filter = .inputMessagesFilterUrl
                } else {
                    filter = .inputMessagesFilterEmpty
                }
            } else {
                filter = .inputMessagesFilterEmpty
            }
        
            remoteSearchResult = account.postbox.transaction { transaction -> (peer:Peer?, from: Peer?) in
            if let fromId = fromId {
                return (peer: transaction.getPeer(peerId), from: transaction.getPeer(fromId))
            }
            return (peer: transaction.getPeer(peerId), from: nil)
            }
            |> mapToSignal { values -> Signal<Api.messages.Messages?, NoError> in
                if let peer = values.peer, let inputPeer = apiInputPeer(peer) {
                    var fromInputUser:Api.InputUser? = nil
                    var flags:Int32 = 0
                    if let from = values.from {
                        fromInputUser = apiInputUser(from)
                        if let _ = fromInputUser {
                            flags |= (1 << 0)
                        }
                    }
                    return account.network.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: query, fromId: fromInputUser, filter: filter, minDate: 0, maxDate: Int32.max - 1, offsetId: 0, addOffset: 0, limit: 100, maxId: Int32.max - 1, minId: 0, hash: 0))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                        return .single(nil)
                    }
                } else {
                    return .never()
                }
            }
        case let .group(groupId):
            /*feed*/
            remoteSearchResult = .single(nil)
            /*remoteSearchResult = account.network.request(Api.functions.channels.searchFeed(feedId: groupId.rawValue, q: query, offsetDate: 0, offsetPeer: Api.InputPeer.inputPeerEmpty, offsetId: 0, limit: 64), automaticFloodWait: false)
                |> mapError { _ in } |> map(Optional.init)*/
        case .general:
            remoteSearchResult = account.network.request(Api.functions.messages.searchGlobal(q: query, offsetDate: 0, offsetPeer: Api.InputPeer.inputPeerEmpty, offsetId: 0, limit: 64), automaticFloodWait: false)
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                return .single(nil)
            }
    }
    
    let processedSearchResult = remoteSearchResult
        |> mapToSignal { result -> Signal<([Message], [PeerId : CombinedPeerReadState]), NoError> in
            guard let result = result else {
                return .single(([], [:]))
            }
            
            //assert(false)
            let messages: [Api.Message]
            let chats: [Api.Chat]
            let users: [Api.User]
            switch result {
                case let .channelMessages(_, _, _, apiMessages, apiChats, apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case let .messages(apiMessages, apiChats, apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case let.messagesSlice(_, apiMessages, apiChats, apiUsers):
                    messages = apiMessages
                    chats = apiChats
                    users = apiUsers
                case .messagesNotModified:
                    messages = []
                    chats = []
                    users = []
            }
            
            return account.postbox.transaction { transaction -> ([Message], [PeerId : CombinedPeerReadState]) in
                var peers: [PeerId: Peer] = [:]
                
                for user in users {
                    if let user = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                        peers[user.id] = user
                    }
                }
                
                for chat in chats {
                    if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                        peers[groupOrChannel.id] = groupOrChannel
                    }
                }
                
                var peerIdsSet: Set<PeerId> = Set()
                var readStates:[PeerId : CombinedPeerReadState] = [:]
                
                var renderedMessages: [Message] = []
                for message in messages {
                    if let message = StoreMessage(apiMessage: message), let renderedMessage = locallyRenderedMessage(message: message, peers: peers) {
                        renderedMessages.append(renderedMessage)
                        peerIdsSet.insert(message.id.peerId)
                    }
                }
                
                for peerId in peerIdsSet {
                    if let readState = transaction.getCombinedPeerReadState(peerId) {
                         readStates[peerId] = readState
                    }
                }
                
                if case .general = location {
                    let secretMessages = transaction.searchMessages(peerId: nil, query: query, tags: nil)
                    renderedMessages.append(contentsOf: secretMessages)
                }
                
                renderedMessages.sort(by: { lhs, rhs in
                    return MessageIndex(lhs) > MessageIndex(rhs)
                })
                
                
                
                return (renderedMessages, readStates)
            }
            
        }
        
    return processedSearchResult
}

public func downloadMessage(postbox: Postbox, network: Network, messageId: MessageId) -> Signal<Message?, NoError> {
    return postbox.transaction { transaction -> Message? in
        return transaction.getMessage(messageId)
    } |> mapToSignal { message in
        if let _ = message {
            return .single(message)
        } else {
            return postbox.loadedPeerWithId(messageId.peerId)
            |> mapToSignal { peer -> Signal<Message?, NoError> in
                let signal: Signal<Api.messages.Messages, MTRpcError>
                if messageId.peerId.namespace == Namespaces.Peer.CloudChannel {
                    if let channel = apiInputChannel(peer) {
                        signal = network.request(Api.functions.channels.getMessages(channel: channel, id: [Api.InputMessage.inputMessageID(id: messageId.id)]))
                    } else {
                        signal = .complete()
                    }
                } else {
                    signal = network.request(Api.functions.messages.getMessages(id: [Api.InputMessage.inputMessageID(id: messageId.id)]))
                }
                
                return signal
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Message?, NoError> in
                    guard let result = result else {
                        return .single(nil)
                    }
                    let messages: [Api.Message]
                    let chats: [Api.Chat]
                    let users: [Api.User]
                    switch result {
                        case let .channelMessages(_, _, _, apiMessages, apiChats, apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case let .messages(apiMessages, apiChats, apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case let.messagesSlice(_, apiMessages, apiChats, apiUsers):
                            messages = apiMessages
                            chats = apiChats
                            users = apiUsers
                        case .messagesNotModified:
                            messages = []
                            chats = []
                            users = []
                    }
                    
                    let postboxSignal = postbox.transaction { transaction -> Message? in
                        var peers: [PeerId: Peer] = [:]
                        
                        for user in users {
                            if let user = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                peers[user.id] = user
                            }
                        }
                        
                        for chat in chats {
                            if let groupOrChannel = mergeGroupOrChannel(lhs: transaction.getPeer(chat.peerId), rhs: chat) {
                                peers[groupOrChannel.id] = groupOrChannel
                            }
                        }
                        
                        var renderedMessages: [Message] = []
                        for message in messages {
                            if let message = StoreMessage(apiMessage: message), let renderedMessage = locallyRenderedMessage(message: message, peers: peers) {
                                renderedMessages.append(renderedMessage)
                            }
                        }
                        
                        return renderedMessages.first
                    }
                    
                    return postboxSignal
                }
            }
            |> `catch` { _ -> Signal<Message?, NoError> in
                return .single(nil)
            }
        }
    }
}

func fetchRemoteMessage(postbox: Postbox, source: FetchMessageHistoryHoleSource, message: MessageReference) -> Signal<Message?, NoError> {
    guard case let .message(peer, id) = message.content else {
        return .single(nil)
    }
    let signal: Signal<Api.messages.Messages, MTRpcError>
    if id.peerId.namespace == Namespaces.Peer.CloudChannel {
        if let channel = peer.inputChannel {
            signal = source.request(Api.functions.channels.getMessages(channel: channel, id: [Api.InputMessage.inputMessageID(id: id.id)]))
        } else {
            signal = .fail(MTRpcError(errorCode: 400, errorDescription: "Peer Not Found"))
        }
    } else if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
        signal = source.request(Api.functions.messages.getMessages(id: [Api.InputMessage.inputMessageID(id: id.id)]))
    } else {
        signal = .fail(MTRpcError(errorCode: 400, errorDescription: "Invalid Peer"))
    }
    
    return signal
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Message?, NoError> in
        guard let result = result else {
            return .single(nil)
        }
        let messages: [Api.Message]
        let chats: [Api.Chat]
        let users: [Api.User]
        switch result {
            case let .channelMessages(_, _, _, apiMessages, apiChats, apiUsers):
                messages = apiMessages
                chats = apiChats
                users = apiUsers
            case let .messages(apiMessages, apiChats, apiUsers):
                messages = apiMessages
                chats = apiChats
                users = apiUsers
            case let .messagesSlice(_, apiMessages, apiChats, apiUsers):
                messages = apiMessages
                chats = apiChats
                users = apiUsers
            case .messagesNotModified:
                messages = []
                chats = []
                users = []
        }
        
        return postbox.transaction { transaction -> Message? in
            var peers: [PeerId: Peer] = [:]
            
            for user in users {
                if let user = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                    peers[user.id] = user
                }
            }
            
            for chat in chats {
                if let groupOrChannel = mergeGroupOrChannel(lhs: transaction.getPeer(chat.peerId), rhs: chat) {
                    peers[groupOrChannel.id] = groupOrChannel
                }
            }
            
            var renderedMessages: [Message] = []
            for message in messages {
                if let message = StoreMessage(apiMessage: message), case let .Id(updatedId) = message.id {
                    var addedExisting = false
                    if transaction.getMessage(updatedId) != nil {
                        transaction.updateMessage(updatedId, update: { _ in
                            return .update(message)
                        })
                        if let updatedMessage = transaction.getMessage(updatedId) {
                            renderedMessages.append(updatedMessage)
                            addedExisting = true
                        }
                    }
                    
                    if !addedExisting, let renderedMessage = locallyRenderedMessage(message: message, peers: peers) {
                        renderedMessages.append(renderedMessage)
                    }
                }
            }
            
            return renderedMessages.first
        }
    }
    |> `catch` { _ -> Signal<Message?, NoError> in
        return .single(nil)
    }
}

public func searchMessageIdByTimestamp(account: Account, peerId: PeerId, timestamp: Int32) -> Signal<MessageId?, NoError> {
    return account.postbox.transaction { transaction -> Signal<MessageId?, NoError> in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            return .single(transaction.findClosestMessageIdByTimestamp(peerId: peerId, timestamp: timestamp))
        } else if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: 0, offsetDate: timestamp, addOffset: -1, limit: 1, maxId: 0, minId: 0, hash: 0))
                |> map { result -> MessageId? in
                    let messages: [Api.Message]
                    switch result {
                        case let .messages(apiMessages, _, _):
                            messages = apiMessages
                        case let .channelMessages(_, _, _, apiMessages, _, _):
                            messages = apiMessages
                        case let.messagesSlice(_, apiMessages, _, _):
                            messages = apiMessages
                        case .messagesNotModified:
                            messages = []
                    }
                    for message in messages {
                        if let message = StoreMessage(apiMessage: message), case let .Id(id) = message.id {
                            return id
                        }
                    }
                    return nil
                }
                |> `catch` { _ -> Signal<MessageId?, NoError> in
                    return .single(nil)
                }
        } else {
            return .single(nil)
        }
    } |> switchToLatest
}

enum UpdatedRemotePeerError {
    case generic
}

func updatedRemotePeer(postbox: Postbox, network: Network, peer: PeerReference) -> Signal<Peer, UpdatedRemotePeerError> {
    if let inputUser = peer.inputUser {
        return network.request(Api.functions.users.getUsers(id: [inputUser]))
        |> mapError { _ -> UpdatedRemotePeerError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Peer, UpdatedRemotePeerError> in
            if let updatedPeer = result.first.flatMap(TelegramUser.init(user:)), updatedPeer.id == peer.id {
                return postbox.transaction { transaction -> Peer in
                    updatePeers(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                        return updated
                    })
                    return updatedPeer
                }
                |> mapError { _ -> UpdatedRemotePeerError in
                    return .generic
                }
            } else {
                return .fail(.generic)
            }
        }
    } else if case let .group(id) = peer {
        return network.request(Api.functions.messages.getChats(id: [id]))
        |> mapError { _ -> UpdatedRemotePeerError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Peer, UpdatedRemotePeerError> in
            let chats: [Api.Chat]
            switch result {
                case let .chats(c):
                    chats = c
                case let .chatsSlice(_, c):
                    chats = c
            }
            if let updatedPeer = chats.first.flatMap(parseTelegramGroupOrChannel), updatedPeer.id == peer.id {
                return postbox.transaction { transaction -> Peer in
                    updatePeers(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                        return updated
                    })
                    return updatedPeer
                }
                |> mapError { _ -> UpdatedRemotePeerError in
                    return .generic
                }
            } else {
                return .fail(.generic)
            }
        }
    } else if let inputChannel = peer.inputChannel {
        return network.request(Api.functions.channels.getChannels(id: [inputChannel]))
        |> mapError { _ -> UpdatedRemotePeerError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Peer, UpdatedRemotePeerError> in
            let chats: [Api.Chat]
            switch result {
                case let .chats(c):
                    chats = c
                case let .chatsSlice(_, c):
                    chats = c
            }
            if let updatedPeer = chats.first.flatMap(parseTelegramGroupOrChannel), updatedPeer.id == peer.id {
                return postbox.transaction { transaction -> Peer in
                    updatePeers(transaction: transaction, peers: [updatedPeer], update: { _, updated in
                        return updated
                    })
                    return updatedPeer
                }
                |> mapError { _ -> UpdatedRemotePeerError in
                    return .generic
                }
            } else {
                return .fail(.generic)
            }
        }
    } else {
        return .fail(.generic)
    }
}
