import Foundation

final class MutableContactPeersView: MutablePostboxView {
    fileprivate var peers: [PeerId: Peer]
    fileprivate var peerPresences: [PeerId: PeerPresence]
    fileprivate var peerIds: Set<PeerId>
    fileprivate var accountPeer: Peer?
    private let includePresences: Bool
    
    init(postbox: PostboxImpl, accountPeerId: PeerId?, includePresences: Bool) {
        var peers: [PeerId: Peer] = [:]
        var peerPresences: [PeerId: PeerPresence] = [:]

        for peerId in postbox.contactsTable.get() {
            if let peer = postbox.peerTable.get(peerId) {
                peers[peerId] = peer
            }
            if includePresences {
                if let presence = postbox.peerPresenceTable.get(peerId) {
                    peerPresences[peerId] = presence
                }
            }
        }

        self.peers = peers
        self.peerIds = Set<PeerId>(peers.map { $0.0 })
        self.peerPresences = peerPresences
        self.accountPeer = accountPeerId.flatMap(postbox.peerTable.get)
        self.includePresences = includePresences
    }

    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if let replacePeerIds = transaction.replaceContactPeerIds {
            let removedPeerIds = self.peerIds.subtracting(replacePeerIds)
            let addedPeerIds = replacePeerIds.subtracting(self.peerIds)

            self.peerIds = replacePeerIds

            for peerId in removedPeerIds {
                let _ = self.peers.removeValue(forKey: peerId)
                let _ = self.peerPresences.removeValue(forKey: peerId)
            }

            for peerId in addedPeerIds {
                if let peer = postbox.peerTable.get(peerId) {
                    self.peers[peerId] = peer
                }
                if self.includePresences {
                    if let presence = postbox.peerPresenceTable.get(peerId) {
                        self.peerPresences[peerId] = presence
                    }
                }
            }

            if !removedPeerIds.isEmpty || !addedPeerIds.isEmpty {
                updated = true
            }
        }

        if self.includePresences, !transaction.currentUpdatedPeerPresences.isEmpty {
            for peerId in self.peerIds {
                if let presence = transaction.currentUpdatedPeerPresences[peerId] {
                    updated = true
                    self.peerPresences[peerId] = presence
                }
            }
        }

        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }

    func immutableView() -> PostboxView {
        return ContactPeersView(self)
    }
}

public final class ContactPeersView: PostboxView {
    public let peers: [Peer]
    public let peerPresences: [PeerId: PeerPresence]
    public let accountPeer: Peer?
    
    init(_ mutableView: MutableContactPeersView) {
        if let accountPeer = mutableView.accountPeer {
            var peers: [Peer] = []
            peers.reserveCapacity(mutableView.peers.count)
            let accountPeerId = accountPeer.id
            for peer in mutableView.peers.values {
                if peer.id != accountPeerId {
                    peers.append(peer)
                }
            }
            self.peers = peers
        } else {
            self.peers = mutableView.peers.map({ $0.1 })
        }
        self.peerPresences = mutableView.peerPresences
        self.accountPeer = mutableView.accountPeer
    }
}

