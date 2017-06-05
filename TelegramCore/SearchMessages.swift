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

public func searchMessages(account: Account, peerId: PeerId?, query: String, tagMask: MessageTags? = nil) -> Signal<[Message], NoError> {
    let searchResult: Signal<Api.messages.Messages, NoError>
    
    let filter:Api.MessagesFilter

    if let tags = tagMask {
        if tags.contains(.File) {
            filter = .inputMessagesFilterDocument
        } else if tags.contains(.Music) {
            filter = .inputMessagesFilterMusic
        } else if tags.contains(.WebPage) {
            filter = .inputMessagesFilterUrl
        } else {
            filter = .inputMessagesFilterEmpty
        }
    } else {
        filter = .inputMessagesFilterEmpty
    }
    
    if let peerId = peerId {
        searchResult = account.postbox.loadedPeerWithId(peerId)
            |> mapToSignal { peer -> Signal<Api.messages.Messages, NoError> in
                if let inputPeer = apiInputPeer(peer) {
                    return account.network.request(Api.functions.messages.search(flags: 0, peer: inputPeer, q: query, filter: filter, minDate: 0, maxDate: Int32.max - 1, offset: 0, maxId: Int32.max - 1, limit: 64))
                        |> retryRequest
                } else {
                    return .never()
                }
            }
    } else {
        searchResult = account.network.request(Api.functions.messages.searchGlobal(q: query, offsetDate: 0, offsetPeer: Api.InputPeer.inputPeerEmpty, offsetId: 0, limit: 64))
            |> retryRequest
    }
    
    let processedSearchResult = searchResult
        |> mapToSignal { result -> Signal<[Message], NoError> in
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
                
                return renderedMessages
            }
            
        }
    
    return processedSearchResult
}

public func downloadMessage(account: Account, message: MessageId) -> Signal<Message?, NoError> {
    let signal: Signal<Api.messages.Messages, MTRpcError>
    if message.peerId.namespace == Namespaces.Peer.CloudChannel {
        signal = .complete()
    } else {
        signal = account.network.request(Api.functions.messages.getMessages(id: [message.id]))
    }
    
    return signal
        |> retryRequest
        |> mapToSignal { result -> Signal<Message?, NoError> in
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
            
            return account.postbox.modify { modifier -> Message? in
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
        }
}

public func searchMessageIdByTimestamp(account: Account, peerId: PeerId, timestamp: Int32) -> Signal<MessageId?, NoError> {
    return account.postbox.modify { modifier -> Signal<MessageId?, NoError> in
        if let peer = modifier.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
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
