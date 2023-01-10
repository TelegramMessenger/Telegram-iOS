import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_toggleMessageCopyProtection(account: Account, peerId: PeerId, enabled: Bool) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.toggleNoForwards(peer: inputPeer, enabled: enabled ? .boolTrue : .boolFalse)) |> `catch` { _ in .complete() } |> map { updates -> Void in
                account.stateManager.addUpdates(updates)
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
