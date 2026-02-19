import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_toggleMessageCopyProtection(account: Account, peerId: PeerId, enabled: Bool, requestMessageId: EngineMessage.Id?) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if let _ = requestMessageId {
                flags = (1 << 0)
            }
            return account.network.request(Api.functions.messages.toggleNoForwards(flags: flags, peer: inputPeer, enabled: enabled ? .boolTrue : .boolFalse, requestMsgId: requestMessageId?.id)) |> `catch` { _ in .complete() } |> map { updates -> Void in
                account.stateManager.addUpdates(updates)
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
