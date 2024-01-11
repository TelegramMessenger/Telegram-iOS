import SwiftSignalKit
import Postbox
import TelegramApi

internal func _internal_updateIsPremiumRequiredToContact(account: Account, peerIds: [EnginePeer.Id]) -> Signal<[EnginePeer.Id], NoError> {
    return account.postbox.transaction { transaction -> [Api.InputUser] in
        var inputUsers: [Api.InputUser] = []
        for id in peerIds {
            if let peer = transaction.getPeer(id), let inputUser = apiInputUser(peer) {
                inputUsers.append(inputUser)
            }
        }
        return inputUsers
    } |> mapToSignal { inputUsers -> Signal<[EnginePeer.Id], NoError> in
        return account.network.request(Api.functions.users.getIsPremiumRequiredToContact(id: inputUsers))
        |> retryRequest
        |> mapToSignal { result in
            return account.postbox.transaction { transaction in
                var requiredPeerIds: [EnginePeer.Id] = []
                for (i, req) in result.enumerated() {
                    let peerId = peerIds[i]
                    let required = req == .boolTrue
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData in
                        let data = cachedData as? CachedUserData ?? CachedUserData()
                        var flags = data.flags
                        if required {
                            flags.insert(.premiumRequired)
                        } else {
                            flags.remove(.premiumRequired)
                        }
                        return data.withUpdatedFlags(flags)
                    })
                    if required {
                        requiredPeerIds.append(peerId)
                    }
                }
                
                return requiredPeerIds
            }
        }
    }
}
