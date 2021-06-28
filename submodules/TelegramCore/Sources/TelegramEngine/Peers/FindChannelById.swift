import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

func _internal_findChannelById(postbox: Postbox, network: Network, channelId: Int64) -> Signal<Peer?, NoError> {
    return network.request(Api.functions.channels.getChannels(id: [.inputChannel(channelId: channelId, accessHash: 0)]))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.messages.Chats?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Peer?, NoError> in
        guard let result = result else {
            return .single(nil)
        }
        let chats: [Api.Chat]
        switch result {
            case let .chats(apiChats):
                chats = apiChats
            case let .chatsSlice(_, apiChats):
                chats = apiChats
        }
        guard let chat = chats.first else {
            return .single(nil)
        }
        guard let peer = parseTelegramGroupOrChannel(chat: chat) else {
            return .single(nil)
        }
        
        return postbox.transaction { transaction -> Peer? in
            updatePeers(transaction: transaction, peers: [peer], update: { _, updated in
                return updated
            })
            return peer
        }
    }
}
