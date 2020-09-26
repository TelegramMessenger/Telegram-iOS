
import Postbox
import TelegramApi
import SwiftSignalKit

public func exportMessageLink(account: Account, peerId: PeerId, messageId: MessageId, threadMessageId: MessageId? = nil) -> Signal<String?, NoError> {
    return account.postbox.transaction { transaction -> (Peer, MessageId)? in
        var peer: Peer?
        var messageId = messageId
        if let threadMessageId = threadMessageId {
            messageId = threadMessageId
            if let message = transaction.getMessage(threadMessageId), let sourceReference = message.sourceReference {
                peer = transaction.getPeer(sourceReference.messageId.peerId)
                messageId = sourceReference.messageId
            }
        } else {
            peer = transaction.getPeer(messageId.peerId)
        }
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
            return account.network.request(Api.functions.channels.exportMessageLink(channel: input, id: sourceMessageId.id, grouped: .boolTrue)) |> mapError { _ in return }
            |> map { res in
                switch res {
                    case let .exportedMessageLink(link, _):
                        if let _ = threadMessageId {
                            return "\(link)?comment=\(messageId.id)"
                        }
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
