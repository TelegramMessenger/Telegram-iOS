import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public func groupsInCommon(account:Account, peerId:PeerId) -> Signal<[Peer], NoError> {
    return account.postbox.transaction { transaction -> Signal<[Peer], NoError> in
        if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
            return account.network.request(Api.functions.messages.getCommonChats(userId: inputUser, maxId: 0, limit: 100))
            |> retryRequest
            |> mapToSignal {  result -> Signal<[Peer], NoError> in
                let chats: [Api.Chat]
                switch result {
                    case let .chats(chats: apiChats):
                        chats = apiChats
                    case let .chatsSlice(count: _, chats: apiChats):
                        chats = apiChats
                }
                
                return account.postbox.transaction { transaction -> [Peer] in
                    var peers:[Peer] = []
                    for chat in chats {
                        if let peer = parseTelegramGroupOrChannel(chat: chat) {
                            peers.append(peer)
                        }
                    }
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer? in
                        return updated
                    })
                    return peers
                }
            }
        } else {
            return .single([])
        }
    } |> switchToLatest
}
