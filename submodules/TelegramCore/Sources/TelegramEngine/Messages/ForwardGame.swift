import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

func _internal_forwardGameWithScore(account: Account, messageId: MessageId, to peerId: PeerId, threadId: Int64?, as sendAsPeerId: PeerId?) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let _ = transaction.getMessage(messageId), let fromPeer = transaction.getPeer(messageId.peerId), let fromInputPeer = apiInputPeer(fromPeer), let toPeer = transaction.getPeer(peerId), let toInputPeer = apiInputPeer(toPeer) {
            var flags: Int32 = 1 << 8
            
            var sendAsInputPeer: Api.InputPeer?
            if let sendAsPeerId = sendAsPeerId, let sendAsPeer = transaction.getPeer(sendAsPeerId), let inputPeer = apiInputPeerOrSelf(sendAsPeer, accountPeerId: account.peerId) {
                sendAsInputPeer = inputPeer
                flags |= (1 << 13)
            }
            
            return account.network.request(Api.functions.messages.forwardMessages(flags: flags, fromPeer: fromInputPeer, id: [messageId.id], randomId: [Int64.random(in: Int64.min ... Int64.max)], toPeer: toInputPeer, topMsgId: threadId.flatMap { Int32(clamping: $0) }, scheduleDate: nil, sendAs: sendAsInputPeer, quickReplyShortcut: nil, videoTimestamp: nil, allowPaidStars: nil))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { updates -> Signal<Void, NoError> in
                if let updates = updates {
                    account.stateManager.addUpdates(updates)
                }
                return .complete()
            }
        }
        return .complete()
    } |> switchToLatest
}
