
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
            //channels.exportMessageLink flags:# grouped:flags.0?true thread:flags.1?true channel:InputChannel id:int = ExportedMessageLink;
            var flags: Int32 = 0
            flags |= 1 << 0
            return account.network.request(Api.functions.channels.exportMessageLink(flags: flags, channel: input, id: sourceMessageId.id)) |> mapError { _ in return }
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
