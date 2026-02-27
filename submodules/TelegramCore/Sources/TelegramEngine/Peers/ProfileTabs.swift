import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_setMainProfileTab(account: Account, peerId: PeerId, tab: TelegramProfileTab) -> Signal<Never, NoError> {
    return account.postbox.loadedPeerWithId(peerId)
    |> mapToSignal { peer in
        return account.postbox.transaction { transaction -> Signal<Never, NoError> in
            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                if let current = current as? CachedUserData {
                    return current.withUpdatedMainProfileTab(tab)
                } else if let current = current as? CachedChannelData {
                    return current.withUpdatedMainProfileTab(tab)
                } else {
                    return current
                }
            })
            if let inputChannel = apiInputChannel(peer) {
                return account.network.request(Api.functions.channels.setMainProfileTab(channel: inputChannel, tab: tab.apiTab))
                |> `catch` { error in
                    return .complete()
                }
                |> mapToSignal { _ -> Signal<Never, NoError> in
                    return .complete()
                }
            } else {
                return account.network.request(Api.functions.account.setMainProfileTab(tab: tab.apiTab))
                |> `catch` { error in
                    return .complete()
                }
                |> mapToSignal { _ -> Signal<Never, NoError> in
                    return .complete()
                }
            }
        } |> switchToLatest
    }
}
