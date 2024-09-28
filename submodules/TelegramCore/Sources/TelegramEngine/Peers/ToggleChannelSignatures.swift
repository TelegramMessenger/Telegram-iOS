import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func _internal_toggleShouldChannelMessagesSignatures(account: Account, peerId: PeerId, signaturesEnabled: Bool, profilesEnabled: Bool) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId) as? TelegramChannel, let inputChannel = apiInputChannel(peer) {
            var flags: Int32 = 0
            if signaturesEnabled {
                flags |= 1 << 0
            }
            if profilesEnabled {
                flags |= 1 << 1
            }
            return account.network.request(Api.functions.channels.toggleSignatures(flags: flags, channel: inputChannel)) |> retryRequest |> map { updates -> Void in
                account.stateManager.addUpdates(updates)
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
