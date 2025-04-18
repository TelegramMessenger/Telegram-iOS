import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public func _internal_updateCloseFriends(account: Account, peerIds: [EnginePeer.Id]) -> Signal<Never, NoError> {
    let ids: [Int64] = peerIds.map { $0.id._internalGetInt64Value() }
    return account.network.request(Api.functions.contacts.editCloseFriends(id: ids))
    |> retryRequest
    |> mapToSignal { result -> Signal<Void, NoError> in
        return account.postbox.transaction { transaction in
            let contactPeerIds = transaction.getContactPeerIds()
            var updatedPeers: [Peer] = []
            for peerId in contactPeerIds {
                if let peer = transaction.getPeer(peerId) as? TelegramUser {
                    if peerIds.contains(peerId) {
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
    }
    |> ignoreValues
}
