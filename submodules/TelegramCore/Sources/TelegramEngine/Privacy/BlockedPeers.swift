import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public func requestBlockedPeers(account: Account) -> Signal<[Peer], NoError> {
    return account.network.request(Api.functions.contacts.getBlocked(offset: 0, limit: 100))
        |> retryRequest
        |> mapToSignal { result -> Signal<[Peer], NoError> in
            return account.postbox.transaction { transaction -> [Peer] in
                var peers: [Peer] = []
                let apiUsers: [Api.User]
                let apiChats: [Api.Chat]
                switch result {
                    case let .blocked(_, chats, users):
                        apiUsers = users
                        apiChats = chats
                    case let .blockedSlice(_, _, chats, users):
                        apiUsers = users
                        apiChats = chats
                }
                for chat in apiChats {
                    if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                        peers.append(groupOrChannel)
                    }
                }
                for user in apiUsers {
                    let parsed = TelegramUser(user: user)
                    peers.append(parsed)
                }
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                    return updated
                })
                
                return peers
            }
        }
}

func _internal_requestUpdatePeerIsBlocked(account: Account, peerId: PeerId, isBlocked: Bool) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let signal: Signal<Api.Bool, MTRpcError>
            if isBlocked {
                signal = account.network.request(Api.functions.contacts.block(id: inputPeer))
            } else {
                signal = account.network.request(Api.functions.contacts.unblock(id: inputPeer))
            }
            return signal
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        if result != nil {
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                let previous: CachedUserData
                                if let current = current as? CachedUserData {
                                    previous = current
                                } else {
                                    previous = CachedUserData()
                                }
                                return previous.withUpdatedIsBlocked(isBlocked)
                            })
                        }
                    }
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
