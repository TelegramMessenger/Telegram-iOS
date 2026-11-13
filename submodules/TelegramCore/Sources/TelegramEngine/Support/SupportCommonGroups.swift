import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

private let supportCommonGroupsLimit: Int32 = 100

func supportCanModerateCommonGroup(_ peer: Peer, currentChatId: PeerId) -> Bool {
    guard peer.id != currentChatId, let channel = peer as? TelegramChannel, case .group = channel.info else {
        return false
    }
    return channel.hasPermission(.banMembers)
}

func _internal_supportCommonGroupsForModeration(account: Account, userId: PeerId, currentChatId: PeerId) -> Signal<[EnginePeer], NoError> {
    let accountPeerId = account.peerId
    let network = account.network
    let postbox = account.postbox
    return postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(userId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<[EnginePeer], NoError> in
        guard let inputUser else {
            return .single([])
        }
        return network.request(Api.functions.messages.getCommonChats(userId: inputUser, maxId: 0, limit: supportCommonGroupsLimit))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.Chats?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<[EnginePeer], NoError> in
            guard let result else {
                return .single([])
            }
            let chats: [Api.Chat]
            switch result {
            case let .chats(chatsData):
                chats = chatsData.chats
            case let .chatsSlice(chatsSliceData):
                chats = chatsSliceData.chats
            }
            return postbox.transaction { transaction -> [EnginePeer] in
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: []))

                var peers: [EnginePeer] = []
                for chat in chats {
                    if let peer = transaction.getPeer(chat.peerId), supportCanModerateCommonGroup(peer, currentChatId: currentChatId) {
                        peers.append(EnginePeer(peer))
                    }
                }
                return peers
            }
        }
    }
}
