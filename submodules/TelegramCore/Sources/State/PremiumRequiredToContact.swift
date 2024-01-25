import SwiftSignalKit
import Postbox
import TelegramApi

internal func _internal_updateIsPremiumRequiredToContact(account: Account, peerIds: [EnginePeer.Id]) -> Signal<[EnginePeer.Id], NoError> {
    return account.postbox.transaction { transaction -> ([Api.InputUser], [PeerId], [PeerId]) in
        var inputUsers: [Api.InputUser] = []
        let premiumRequired: [EnginePeer.Id] = []
        var ids:[PeerId] = []
        for id in peerIds {
            if let peer = transaction.getPeer(id), let inputUser = apiInputUser(peer) {
                if peer.isPremium {
                    if let cachedData = transaction.getPeerCachedData(peerId: id) as? CachedUserData {
                        if cachedData.flags.contains(.premiumRequired) {
                            inputUsers.append(inputUser)
                            ids.append(id)
                        }
                    } else if let peer = peer as? TelegramUser, peer.flags.contains(.requirePremium), !peer.flags.contains(.mutualContact) {
                        inputUsers.append(inputUser)
                        ids.append(id)
                    }
                }
            }
        }
        return (inputUsers, premiumRequired, ids)
    } |> mapToSignal { inputUsers, premiumRequired, reqIds -> Signal<[EnginePeer.Id], NoError> in
        
        if !inputUsers.isEmpty {
            return account.network.request(Api.functions.users.getIsPremiumRequiredToContact(id: inputUsers))
            |> retryRequest
            |> mapToSignal { result in
                return account.postbox.transaction { transaction in
                    var requiredPeerIds: [EnginePeer.Id] = []
                    for (i, req) in result.enumerated() {
                        let peerId = reqIds[i]
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
                    let result = requiredPeerIds + premiumRequired
                    return result
                }
            }
        } else {
            return .single(premiumRequired)
        }
    }
}
