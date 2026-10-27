import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

public enum UpdateCloseFriendsError {
    case generic
}

public func _internal_updateCloseFriends(account: Account, peerIds: [EnginePeer.Id]) -> Signal<Never, UpdateCloseFriendsError> {
    return account.postbox.transaction { transaction -> [PeerId]? in
        let contactPeerIds = transaction.getContactPeerIds()
        var uniquePeerIds: [PeerId] = []
        var seenPeerIds = Set<PeerId>()
        for peerId in peerIds where seenPeerIds.insert(peerId).inserted {
            guard peerId.namespace == Namespaces.Peer.CloudUser, contactPeerIds.contains(peerId), transaction.getPeer(peerId) is TelegramUser else {
                return nil
            }
            uniquePeerIds.append(peerId)
        }
        return uniquePeerIds
    }
    |> castError(UpdateCloseFriendsError.self)
    |> mapToSignal { peerIds -> Signal<Void, UpdateCloseFriendsError> in
        guard let peerIds else {
            return .fail(.generic)
        }
        let selectedPeerIds = Set(peerIds)
        return account.network.request(Api.functions.contacts.editCloseFriends(id: peerIds.map { $0.id._internalGetInt64Value() }))
        |> mapError { _ in UpdateCloseFriendsError.generic }
        |> mapToSignal { result -> Signal<Void, UpdateCloseFriendsError> in
            guard case .boolTrue = result else {
                return .fail(.generic)
            }
            return account.postbox.transaction { transaction in
                let contactPeerIds = transaction.getContactPeerIds()
                var updatedPeers: [Peer] = []
                for peerId in contactPeerIds {
                    if let peer = transaction.getPeer(peerId) as? TelegramUser {
                        if selectedPeerIds.contains(peerId) {
                            var updatedFlags = peer.flags
                            updatedFlags.insert(.isCloseFriend)
                            let updatedPeer = peer.withUpdatedFlags(updatedFlags)
                            updatedPeers.append(updatedPeer)
                        } else if peer.flags.contains(.isCloseFriend) {
                            var updatedFlags = peer.flags
                            updatedFlags.remove(.isCloseFriend)
                            let updatedPeer = peer.withUpdatedFlags(updatedFlags)
                            updatedPeers.append(updatedPeer)
                        }
                    }
                }
                updatePeersCustom(transaction: transaction, peers: updatedPeers, update: { _, updated in
                    return updated
                })
            }
            |> castError(UpdateCloseFriendsError.self)
        }
    }
    |> ignoreValues
}
