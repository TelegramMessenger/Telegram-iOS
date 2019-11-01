import Foundation

final class MutableContactPeersView {
    fileprivate var peers: [PeerId: Peer]
    fileprivate var peerPresences: [PeerId: PeerPresence]
    fileprivate var peerIds: Set<PeerId>
    fileprivate var accountPeer: Peer?
    private let includePresences: Bool
    
    init(peers: [PeerId: Peer], peerPresences: [PeerId: PeerPresence], accountPeer: Peer?, includePresences: Bool) {
        self.peers = peers
        self.peerIds = Set<PeerId>(peers.map { $0.0 })
        self.peerPresences = peerPresences
        self.accountPeer = accountPeer
        self.includePresences = includePresences
    }
    
    func replay(replacePeerIds: Set<PeerId>?, updatedPeerPresences: [PeerId: PeerPresence], getPeer: (PeerId) -> Peer?, getPeerPresence: (PeerId) -> PeerPresence?) -> Bool {
        var updated = false
        if let replacePeerIds = replacePeerIds {
            let removedPeerIds = self.peerIds.subtracting(replacePeerIds)
            let addedPeerIds = replacePeerIds.subtracting(self.peerIds)
            
            self.peerIds = replacePeerIds
            
            for peerId in removedPeerIds {
                let _ = self.peers.removeValue(forKey: peerId)
                let _ = self.peerPresences.removeValue(forKey: peerId)
            }
            
            for peerId in addedPeerIds {
                if let peer = getPeer(peerId) {
                    self.peers[peerId] = peer
                }
                if self.includePresences {
                    if let presence = getPeerPresence(peerId) {
                        self.peerPresences[peerId] = presence
                    }
                }
            }
            
            if !removedPeerIds.isEmpty || !addedPeerIds.isEmpty {
                updated = true
            }
        }
        
        if self.includePresences, !updatedPeerPresences.isEmpty {
            for peerId in self.peerIds {
                if let presence = updatedPeerPresences[peerId] {
                    updated = true
                    self.peerPresences[peerId] = presence
                }
            }
        }
        
        return updated
    }
}

public final class ContactPeersView {
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

