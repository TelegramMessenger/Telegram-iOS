import SwiftSignalKit
import Postbox
import TelegramApi

public enum RequirementToContact {
    case premium
    case stars(StarsAmount)
}

/// What the store alone says about messaging a user. The amount is known only from the
/// user's cached data; the user's own flags say that a fee applies, not how much.
public enum LocalRequirementToContact {
    case premium
    case stars(StarsAmount?)
}

/// The gate the store knows about for messaging `peer`, or nil when it knows of none.
///
/// The server's answer (`users.getRequirementsToContact`) is authoritative; this is the
/// prefilter that decides whom to ask, and the whole decision for a surface that cannot ask
/// (the Siri extension). Both sources are consulted: `CachedUserData` carries the fee and the
/// Premium flag but is refreshed only when the chat is opened, while the user's own flags
/// arrive with every update, so either saying "gated" counts. Mutual contacts are exempt from
/// the flag gate, as the server exempts them.
public func localRequirementToContact(peer: Peer, cachedData: CachedPeerData?) -> LocalRequirementToContact? {
    guard let user = peer as? TelegramUser else {
        return nil
    }
    if let cachedData = cachedData as? CachedUserData {
        if let stars = cachedData.sendPaidMessageStars {
            return .stars(stars)
        }
        if cachedData.flags.contains(.premiumRequired) {
            return .premium
        }
    }
    if user.flags.contains(.mutualContact) {
        return nil
    }
    if user.flags.contains(.requireStars) {
        return .stars(nil)
    }
    if user.flags.contains(.requirePremium) {
        return .premium
    }
    return nil
}

internal func _internal_updateIsPremiumRequiredToContact(account: Account, peerIds: [EnginePeer.Id]) -> Signal<[EnginePeer.Id: RequirementToContact], NoError> {
    return account.postbox.transaction { transaction -> ([Api.InputUser], [PeerId]) in
        var inputUsers: [Api.InputUser] = []
        var ids: [PeerId] = []
        for id in peerIds {
            guard id != account.peerId else {
                continue
            }
            if let peer = transaction.getPeer(id), let inputUser = apiInputUser(peer) {
                // Only a Premium user can gate who may message them.
                if peer.isPremium, localRequirementToContact(peer: peer, cachedData: transaction.getPeerCachedData(peerId: id)) != nil {
                    inputUsers.append(inputUser)
                    ids.append(id)
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
                            case let .requirementToContactPaidMessages(requirementToContactPaidMessagesData):
                                let starsAmount = requirementToContactPaidMessagesData.starsAmount
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
