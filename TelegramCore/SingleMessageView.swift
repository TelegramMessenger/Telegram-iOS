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

public func singleMessageView(account: Account, messageId: MessageId, loadIfNotExists: Bool) -> Signal<MessageView, NoError> {
    return Signal { subscriber in
        let loadedMessage = account.postbox.modify { modifier -> Signal<Void, NoError> in
            if modifier.getMessage(messageId) == nil, loadIfNotExists {
                return fetchMessage(modifier: modifier, account: account, messageId: messageId)
            } else {
                return .complete()
            }
        } |> switchToLatest
        
        let disposable = loadedMessage.start()
        let viewDisposable = account.postbox.messageView(messageId).start(next: { view in
            subscriber.putNext(view)
        })
        
        return ActionDisposable {
            disposable.dispose()
            viewDisposable.dispose()
        }
    }
}

private func fetchMessage(modifier: Modifier, account: Account, messageId: MessageId) -> Signal<Void, NoError> {
    if let peer = modifier.getPeer(messageId.peerId) {
        var signal: Signal<Api.messages.Messages, MTRpcError>?
        if messageId.peerId.namespace == Namespaces.Peer.CloudUser || messageId.peerId.namespace == Namespaces.Peer.CloudGroup {
            signal = account.network.request(Api.functions.messages.getMessages(id: [messageId.id]))
        } else if messageId.peerId.namespace == Namespaces.Peer.CloudChannel {
            if let inputChannel = apiInputChannel(peer) {
                signal = account.network.request(Api.functions.channels.getMessages(channel: inputChannel, id: [messageId.id]))
            }
        }
        if let signal = signal {
            return signal
                |> `catch` { _ -> Signal<Api.messages.Messages, NoError> in
                    return .single(.messages(messages: [], chats: [], users: []))
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return account.postbox.modify { modifier -> Void in
                        let apiMessages: [Api.Message]
                        let apiChats: [Api.Chat]
                        let apiUsers: [Api.User]
                        switch result {
                            case let .messages(messages, chats, users):
                                apiMessages = messages
                                apiChats = chats
                                apiUsers = users
                            case let .messagesSlice(_, messages, chats, users):
                                apiMessages = messages
                                apiChats = chats
                                apiUsers = users
                            case let .channelMessages(_, _, _, messages, chats, users):
                                apiMessages = messages
                                apiChats = chats
                                apiUsers = users
                            case .messagesNotModified:
                                apiMessages = []
                                apiChats = []
                                apiUsers = []
                        }
                        
                        var peers: [PeerId: Peer] = [:]
                        
                        for user in apiUsers {
                            if let user = TelegramUser.merge(modifier.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                peers[user.id] = user
                            }
                        }
                        
                        for chat in apiChats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers[groupOrChannel.id] = groupOrChannel
                            }
                        }
                        
                        updatePeers(modifier: modifier, peers: Array(peers.values), update: { _, updated in
                            return updated
                        })
                        
                        for message in apiMessages {
                            if let message = StoreMessage(apiMessage: message) {
                                let _ = modifier.addMessages([message], location: .Random)
                            }
                        }
                    }
                }
        } else {
            return .complete()
        }
    } else {
        return .complete()
    }
}
