
import Postbox
import TelegramApi
import SwiftSignalKit

public func exportMessageLink(account: Account, peerId: PeerId, messageId: MessageId) -> Signal<String?, NoError> {
    return account.postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> mapToSignal { peer -> Signal<String?, NoError> in
        if let peer = peer, let input = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.exportMessageLink(channel: input, id: messageId.id, grouped: .boolTrue)) |> mapError { _ in return }
            |> map { res in
                switch res {
                    case let .exportedMessageLink(link, _):
                        return link
                }
            } |> `catch` { _ -> Signal<String?, NoError> in
                return .single(nil)
            }
        } else {
            return .single(nil)
        }
    }
}
