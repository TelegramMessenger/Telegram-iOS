import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

func _internal_findChannelById(accountPeerId: PeerId, postbox: Postbox, network: Network, channelId: Int64) -> Signal<Peer?, NoError> {
    return network.request(Api.functions.channels.getChannels(id: [.inputChannel(channelId: channelId, accessHash: 0)]))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.Chats?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Peer?, NoError> in
        return postbox.transaction { transaction -> Peer? in
            guard let result = result else {
                return nil
            }
            let chats: [Api.Chat]
            switch result {
            case let .chats(apiChats):
                chats = apiChats
            case let .chatsSlice(_, apiChats):
                chats = apiChats
            }
            guard let id = chats.first?.peerId else {
                return nil
            }
            
            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: [])
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
            
            return transaction.getPeer(id)
        }
    }
}
