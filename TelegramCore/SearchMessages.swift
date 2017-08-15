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

public func searchMessages(account: Account, peerId: PeerId?, query: String, fromId:PeerId? = nil, tagMask: MessageTags? = nil) -> Signal<[Message], NoError> {
    if let peerId = peerId, peerId.namespace == Namespaces.Peer.SecretChat {
        return account.postbox.modify { modifier -> [Message] in
            return modifier.searchMessages(peerId: peerId, query: query, tags: tagMask)
        }
    } else {
        let searchResult: Signal<Api.messages.Messages?, NoError>
        
        let filter: Api.MessagesFilter
        
        if let tags = tagMask {
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
        
        if let peerId = peerId {
            searchResult = account.postbox.modify { modifier -> (peer:Peer?, from: Peer?) in
                if let fromId = fromId {
                    return (peer: modifier.getPeer(peerId), from: modifier.getPeer(fromId))
                }
                return (peer: modifier.getPeer(peerId), from: nil)
            } |> mapToSignal { values -> Signal<Api.messages.Messages?, NoError> in
                    if let peer = values.peer, let inputPeer = apiInputPeer(peer) {
                        var fromInputUser:Api.InputUser? = nil
                        var flags:Int32 = 0
                        if let from = values.from {
                            fromInputUser = apiInputUser(from)
                            if let _ = fromInputUser {
                                flags |= (1 << 0)
                            }
                        }
                        return account.network.request(Api.functions.messages.search(flags: flags, peer: inputPeer, q: query, fromId: fromInputUser, filter: filter, minDate: 0, maxDate: Int32.max - 1, offsetId: 0, addOffset: 0, limit: 100, maxId: Int32.max - 1, minId: 0))
                            |> map {Optional($0)}
                            |> `catch` { _ -> Signal<Api.messages.Messages?, MTRpcError> in
                                return .single(nil)
                            } |> mapError {_ in}
                    } else {
                        return .never()
                    }
                }
        } else {
            searchResult = account.network.request(Api.functions.messages.searchGlobal(q: query, offsetDate: 0, offsetPeer: Api.InputPeer.inputPeerEmpty, offsetId: 0, limit: 64))
                |> mapError {_ in} |> map {Optional($0)}
        }
        
        let processedSearchResult = searchResult
            |> mapToSignal { result -> Signal<[Message], NoError> in
                guard let result = result else {
                    return .single([])
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
                }
                
                return account.postbox.modify { modifier -> [Message] in
                    var peers: [PeerId: Peer] = [:]
                    
                    for user in users {
                        if let user = TelegramUser.merge(modifier.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                            peers[user.id] = user
                        }
                    }
                    
                    for chat in chats {
                        if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                            peers[groupOrChannel.id] = groupOrChannel
                        }
                    }
                    
                    var renderedMessages: [Message] = []
                    for message in messages {
                        if let message = StoreMessage(apiMessage: message), let renderedMessage = locallyRenderedMessage(message: message, peers: peers) {
                            renderedMessages.append(renderedMessage)
                        }
                    }
                    
                    let secretMessages = modifier.searchMessages(peerId: nil, query: query, tags: nil)
                    renderedMessages.append(contentsOf: secretMessages)
                    
                    renderedMessages.sort(by: { lhs, rhs in
                        return MessageIndex(lhs) > MessageIndex(rhs)
                    })
                    
                    return renderedMessages
                }
                
            }
        
        return processedSearchResult
    }
}


public func downloadMessage(account: Account, messageId: MessageId) -> Signal<Message?, NoError> {
    return account.postbox.modify { modifier -> Message? in
        return modifier.getMessage(messageId)
        } |> mapToSignal { message in
            if let _ = message {
                return .single(message)
            } else {
                return account.postbox.loadedPeerWithId(messageId.peerId) |> mapToSignal { peer -> Signal<Message?, NoError> in
                    let signal: Signal<Api.messages.Messages, MTRpcError>
                    if messageId.peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let channel = apiInputChannel(peer) {
                            signal = account.network.request(Api.functions.channels.getMessages(channel: channel, id: [messageId.id]))
                        } else {
                            signal = .complete()
                        }
                    } else {
                        signal = account.network.request(Api.functions.messages.getMessages(id: [messageId.id]))
                    }
                    
                    return signal |> mapError {_ in} |> mapToSignal { result -> Signal<Message?, Void> in
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
                        }
                        
                        let postboxSignal = account.postbox.modify { modifier -> Message? in
                            var peers: [PeerId: Peer] = [:]
                            
                            for user in users {
                                if let user = TelegramUser.merge(modifier.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                    peers[user.id] = user
                                }
                            }
                            
                            for chat in chats {
                                if let groupOrChannel = mergeGroupOrChannel(lhs: modifier.getPeer(chat.peerId), rhs: chat) {
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

public func searchMessageIdByTimestamp(account: Account, peerId: PeerId, timestamp: Int32) -> Signal<MessageId?, NoError> {
    return account.postbox.modify { modifier -> Signal<MessageId?, NoError> in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            return .single(modifier.findClosestMessageIdByTimestamp(peerId: peerId, timestamp: timestamp))
        } else if let peer = modifier.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: 0, offsetDate: timestamp, addOffset: -1, limit: 1, maxId: 0, minId: 0))
                |> map { result -> MessageId? in
                    let messages: [Api.Message]
                    switch result {
                        case let .messages(apiMessages, _, _):
                            messages = apiMessages
                        case let .channelMessages(_, _, _, apiMessages, _, _):
                            messages = apiMessages
                        case let.messagesSlice(_, apiMessages, _, _):
                            messages = apiMessages
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
