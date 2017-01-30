import Foundation

final class MutableMultiplePeersView {
    let peerIds: Set<PeerId>
    
    var peers: [PeerId: Peer] = [:]
    var presences: [PeerId: PeerPresence] = [:]
    
    init(peerIds: [PeerId], getPeer: (PeerId) -> Peer?, getPeerPresence: (PeerId) -> PeerPresence?) {
        self.peerIds = Set(peerIds)
        
        for peerId in self.peerIds {
            if let peer = getPeer(peerId) {
                self.peers[peerId] = peer
            }
            if let presence = getPeerPresence(peerId) {
                self.presences[peerId] = presence
            }
        }
    }
    
    func replay(updatedPeers: [PeerId: Peer], updatedPeerPresences: [PeerId: PeerPresence]) -> Bool {
        if updatedPeers.isEmpty && updatedPeerPresences.isEmpty {
            return false
        }
        
        var updated = false
        
        for peerId in self.peerIds {
            if let peer = updatedPeers[peerId] {
                self.peers[peerId] = peer
                updated = true
            }
            if let presence = updatedPeerPresences[peerId] {
                self.presences[peerId] = presence
                updated = true
            }
        }
        
        return updated
    }
}

public final class MultiplePeersView {
    public let peers: [PeerId: Peer]
    public let presences: [PeerId: PeerPresence]
    
    init(_ view: MutableMultiplePeersView) {
        self.peers = view.peers
        self.presences = view.presences
    }
}
