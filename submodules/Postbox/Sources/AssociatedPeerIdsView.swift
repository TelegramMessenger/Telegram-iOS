import Foundation

/// The peers associated with each of `peerIds` (`Transaction.getAssociatedPeerIds`): for a user, its secret chats.
/// It changes when a peer is stored whose `associatedPeerId` is one of them, so an observer learns of a secret chat
/// created after it started, in the transaction that created it.
final class MutableAssociatedPeerIdsView: MutablePostboxView {
    fileprivate let peerIds: Set<PeerId>
    fileprivate var associatedPeerIds: [PeerId: Set<PeerId>]

    init(postbox: PostboxImpl, peerIds: Set<PeerId>) {
        self.peerIds = peerIds
        self.associatedPeerIds = MutableAssociatedPeerIdsView.read(postbox: postbox, peerIds: peerIds)
    }

    private static func read(postbox: PostboxImpl, peerIds: Set<PeerId>) -> [PeerId: Set<PeerId>] {
        var result: [PeerId: Set<PeerId>] = [:]
        for peerId in peerIds {
            let associatedPeerIds = postbox.reverseAssociatedPeerTable.get(peerId: peerId)
            if !associatedPeerIds.isEmpty {
                result[peerId] = associatedPeerIds
            }
        }
        return result
    }

    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        // `PeerTable` writes the reverse associations in `beforeCommit`, after views replay, so the table does not
        // hold this transaction's peers yet: they are applied from the updated peers themselves.
        var updated = false
        for (peerId, peer) in transaction.currentUpdatedPeers {
            for (watchedPeerId, associatedPeerIds) in self.associatedPeerIds where watchedPeerId != peer.associatedPeerId && associatedPeerIds.contains(peerId) {
                var associatedPeerIds = associatedPeerIds
                associatedPeerIds.remove(peerId)
                self.associatedPeerIds[watchedPeerId] = associatedPeerIds.isEmpty ? nil : associatedPeerIds
                updated = true
            }
            if let associatedPeerId = peer.associatedPeerId, self.peerIds.contains(associatedPeerId) {
                var associatedPeerIds = self.associatedPeerIds[associatedPeerId] ?? Set()
                if associatedPeerIds.insert(peerId).inserted {
                    self.associatedPeerIds[associatedPeerId] = associatedPeerIds
                    updated = true
                }
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        // Another process (the notification service extension) may have stored a secret chat.
        let associatedPeerIds = MutableAssociatedPeerIdsView.read(postbox: postbox, peerIds: self.peerIds)
        if associatedPeerIds != self.associatedPeerIds {
            self.associatedPeerIds = associatedPeerIds
            return true
        }
        return false
    }

    func immutableView() -> PostboxView {
        return AssociatedPeerIdsView(self)
    }
}

public final class AssociatedPeerIdsView: PostboxView {
    /// Only the peers that have associated peers have an entry.
    public let associatedPeerIds: [PeerId: Set<PeerId>]

    init(_ view: MutableAssociatedPeerIdsView) {
        self.associatedPeerIds = view.associatedPeerIds
    }
}
