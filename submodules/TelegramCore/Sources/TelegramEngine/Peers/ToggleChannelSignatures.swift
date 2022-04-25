import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func _internal_toggleShouldChannelMessagesSignatures(account: Account, peerId: PeerId, enabled: Bool) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId) as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.toggleSignatures(channel: inputChannel, enabled: enabled ? .boolTrue : .boolFalse)) |> retryRequest |> map { updates -> Void in
                account.stateManager.addUpdates(updates)
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
