import Foundation
#if os(macOS)
    import PostboxMac
    import MtProtoKitMac
    import SwiftSignalKitMac
#else
    import Postbox
    import MtProtoKitDynamic
    import SwiftSignalKit
#endif

public func recentCalls(account: Account, limit: Int) -> Signal<[Message], NoError> {
    let filter: Api.MessagesFilter = .inputMessagesFilterPhoneCalls(flags: 0)
    
    let searchResult = account.network.request(Api.functions.messages.search(flags: 0, peer: .inputPeerEmpty, q: "", fromId: nil, filter: filter, minDate: 0, maxDate: Int32.max, offset: 0, maxId: Int32.max, limit: Int32(limit)))
        |> retryRequest
    
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
