import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func loadedPeerFromMessage(account: Account, peerId: PeerId, messageId: MessageId) -> Signal<Peer?, NoError> {
    return account.postbox.modify { modifier -> Signal<Peer?, NoError> in
        if let peer = modifier.getPeer(peerId) {
            if let user = peer as? TelegramUser {
                if user.accessHash != 0 {
                    return .single(user)
                } else {
                    let messageSignal: Signal<Api.messages.Messages?, NoError>?
                    if messageId.peerId.namespace == Namespaces.Peer.CloudUser || messageId.peerId.namespace == Namespaces.Peer.CloudGroup {
                        messageSignal = account.network.request(Api.functions.messages.getMessages(id: [Api.InputMessage.inputMessageID(id: messageId.id)]))
                            |> map { Optional($0) }
                            |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                                return .single(nil)
                            }
                    } else if messageId.peerId.namespace == Namespaces.Peer.CloudChannel, let channelPeer = modifier.getPeer(messageId.peerId), let inputChannel = apiInputChannel(channelPeer) {
                        messageSignal = account.network.request(Api.functions.channels.getMessages(channel: inputChannel, id: [Api.InputMessage.inputMessageID(id: messageId.id)]))
                            |> map { Optional($0) }
                            |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
                                return .single(nil)
                            }
                    } else {
                        messageSignal = nil
                    }
                    
                    if let messageSignal = messageSignal {
                        return messageSignal |> mapToSignal { result -> Signal<Peer?, NoError> in
                            return account.postbox.modify { modifier -> Peer? in
                                if let result = result {
                                    let apiUsers: [Api.User]
                                    switch result {
                                        case let .messages(_, _, users):
                                            apiUsers = users
                                        case let .messagesSlice(_, _, _, users):
                                            apiUsers = users
                                        case let .channelMessages(_, _, _, _, _, users):
                                            apiUsers = users
                                        case .messagesNotModified:
                                            apiUsers = []
                                    }
                                    
                                    for user in apiUsers {
                                        let telegramUser = TelegramUser(user: user)
                                        if telegramUser.id == peerId && telegramUser.accessHash != 0 {
                                            if let presence = TelegramUserPresence(apiUser: user) {
                                                modifier.updatePeerPresences([telegramUser.id: presence])
                                            }
                                            
                                            updatePeers(modifier: modifier, peers: [telegramUser], update: { _, updated -> Peer in
                                                return updated
                                            })
                                            
                                            return telegramUser
                                        }
                                    }
                                }
                                return nil
                            }
                        }
                    } else {
                        return .single(nil)
                    }
                }
            } else {
                return .single(peer)
            }
        } else {
            return .single(nil)
        }
    } |> switchToLatest
}
