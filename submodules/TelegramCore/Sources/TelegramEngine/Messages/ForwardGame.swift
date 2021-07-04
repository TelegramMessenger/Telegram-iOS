import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

func _internal_forwardGameWithScore(account: Account, messageId: MessageId, to peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let _ = transaction.getMessage(messageId), let fromPeer = transaction.getPeer(messageId.peerId), let fromInputPeer = apiInputPeer(fromPeer), let toPeer = transaction.getPeer(peerId), let toInputPeer = apiInputPeer(toPeer) {
            return account.network.request(Api.functions.messages.forwardMessages(flags: 1 << 8, fromPeer: fromInputPeer, id: [messageId.id], randomId: [Int64.random(in: Int64.min ... Int64.max)], toPeer: toInputPeer, scheduleDate: nil))
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
