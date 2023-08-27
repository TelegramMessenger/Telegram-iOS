import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func _internal_updateAccountPeerName(account: Account, firstName: String, lastName: String) -> Signal<Void, NoError> {
    let accountPeerId = account.peerId
    return account.network.request(Api.functions.account.updateProfile(flags: (1 << 0) | (1 << 1), firstName: firstName, lastName: lastName, about: nil))
        |> map { result -> Api.User? in
            return result
        }
        |> `catch` { _ in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Void, NoError> in
            return account.postbox.transaction { transaction -> Void in
                if let result = result {
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: [], users: [result]))
                }
            }
        }
}

public enum UpdateAboutError {
    case generic
}


func _internal_updateAbout(account: Account, about: String?) -> Signal<Void, UpdateAboutError> {
    return account.network.request(Api.functions.account.updateProfile(flags: about == nil ? 0 : (1 << 2), firstName: nil, lastName: nil, about: about))
        |> mapError { _ -> UpdateAboutError in
            return .generic
        }
        |> mapToSignal { apiUser -> Signal<Void, UpdateAboutError> in
            return account.postbox.transaction { transaction -> Void in
                transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, current in
                    if let current = current as? CachedUserData {
                        return current.withUpdatedAbout(about)
                    } else {
                        return current
                    }
                })
            }
            |> castError(UpdateAboutError.self)
    }
}
