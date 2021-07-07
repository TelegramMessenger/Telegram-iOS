
import Postbox
import TelegramApi
import SwiftSignalKit

func _internal_exportMessageLink(account: Account, peerId: PeerId, messageId: MessageId, isThread: Bool = false) -> Signal<String?, NoError> {
    return account.postbox.transaction { transaction -> (Peer, MessageId)? in
        var peer: Peer? = transaction.getPeer(messageId.peerId)
        if let peer = peer {
            return (peer, messageId)
        } else {
            return nil
        }
    }
    |> mapToSignal { data -> Signal<String?, NoError> in
        guard let (peer, sourceMessageId) = data else {
            return .single(nil)
        }
        if let input = apiInputChannel(peer) {
            var flags: Int32 = 0
            flags |= 1 << 0
            if isThread {
                flags |= 1 << 1
            }
            return account.network.request(Api.functions.channels.exportMessageLink(flags: flags, channel: input, id: sourceMessageId.id)) |> mapError { _ in return }
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
