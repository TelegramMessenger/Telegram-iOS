import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_toggleAutoTranslation(account: Account, peerId: PeerId, enabled: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputChannel = apiInputChannel(peer) {
            return account.network.request(Api.functions.channels.toggleAutotranslation(channel: inputChannel, enabled: enabled ? .boolTrue : .boolFalse)) |> `catch` { _ in .complete() } |> map { updates -> Void in
                account.stateManager.addUpdates(updates)
            }
        } else {
            return .complete()
        }
    }
    |> switchToLatest
    |> ignoreValues
}
