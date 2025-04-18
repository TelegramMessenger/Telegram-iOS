import SwiftSignalKit
import Postbox
import TelegramApi

public enum RequirementToContact {
    case premium
    case stars(StarsAmount)
}

internal func _internal_updateIsPremiumRequiredToContact(account: Account, peerIds: [EnginePeer.Id]) -> Signal<[EnginePeer.Id: RequirementToContact], NoError> {
    return account.postbox.transaction { transaction -> ([Api.InputUser], [PeerId]) in
        var inputUsers: [Api.InputUser] = []
        var ids: [PeerId] = []
        for id in peerIds {
            if let peer = transaction.getPeer(id), let inputUser = apiInputUser(peer) {
                if peer.isPremium {
                    if let cachedData = transaction.getPeerCachedData(peerId: id) as? CachedUserData {
                        if let _ = cachedData.sendPaidMessageStars {
                            inputUsers.append(inputUser)
                            ids.append(id)
                        } else if cachedData.flags.contains(.premiumRequired) {
                            inputUsers.append(inputUser)
                            ids.append(id)
                        }
                    } else if let peer = peer as? TelegramUser, peer.flags.contains(.requirePremium) || peer.flags.contains(.requireStars), !peer.flags.contains(.mutualContact) {
                        inputUsers.append(inputUser)
                        ids.append(id)
                    }
                }
            }
        }
        return (inputUsers, ids)
    } |> mapToSignal { inputUsers, reqIds -> Signal<[EnginePeer.Id: RequirementToContact], NoError> in
        if !inputUsers.isEmpty {
            return account.network.request(Api.functions.users.getRequirementsToContact(id: inputUsers))
            |> retryRequest
            |> mapToSignal { result in
                return account.postbox.transaction { transaction in
                    var requirements: [EnginePeer.Id: RequirementToContact] = [:]
                    for (i, req) in result.enumerated() {
                        let peerId = reqIds[i]
                        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData in
                            let data = cachedData as? CachedUserData ?? CachedUserData()
                            var flags = data.flags
                            var sendPaidMessageStars = data.sendPaidMessageStars
                            switch req {
                            case .requirementToContactEmpty:
                                flags.remove(.premiumRequired)
                                sendPaidMessageStars = nil
                            case .requirementToContactPremium:
                                flags.insert(.premiumRequired)
                                sendPaidMessageStars = nil
                                requirements[peerId] = .premium
                            case let .requirementToContactPaidMessages(starsAmount):
                                flags.remove(.premiumRequired)
                                sendPaidMessageStars = StarsAmount(value: starsAmount, nanos: 0)
                                requirements[peerId] = .stars(StarsAmount(value: starsAmount, nanos: 0))
                            }
                            return data.withUpdatedFlags(flags).withUpdatedSendPaidMessageStars(sendPaidMessageStars)
                        })
                    }
                    return requirements
                }
            }
        } else {
            return .single([:])
        }
    }
}
