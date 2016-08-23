import Foundation

final class MutableContactPeersView {
    fileprivate let index: PeerNameIndex
    fileprivate var peers: [PeerId: Peer]
    fileprivate var peerIds: Set<PeerId>
    fileprivate var accountPeer: Peer?
    
    init(peers: [PeerId: Peer], index: PeerNameIndex, accountPeer: Peer?) {
        self.index = index
        self.peers = peers
        self.peerIds = Set<PeerId>(peers.map { $0.0 })
        self.accountPeer = accountPeer
    }
    
    func replay(replace replacePeerIds: Set<PeerId>, getPeer: (PeerId) -> Peer?) -> Bool {
        let removedPeerIds = self.peerIds.subtracting(replacePeerIds)
        let addedPeerIds = replacePeerIds.subtracting(self.peerIds)
        
        self.peerIds = replacePeerIds
        
        for peerId in removedPeerIds {
            let _ = self.peers.removeValue(forKey: peerId)
        }
        
        for peerId in addedPeerIds {
            if let peer = getPeer(peerId) {
                self.peers[peerId] = peer
            }
        }
        
        return !removedPeerIds.isEmpty || !addedPeerIds.isEmpty
    }
}

public final class ContactPeersView {
    public let peers: [Peer]
    public let accountPeer: Peer?
    
    init(_ mutableView: MutableContactPeersView) {
        let index = mutableView.index
        self.peers = mutableView.peers.map({ $0.1 }).sorted(by: { $0.indexName.indexName(index) < $1.indexName.indexName(index) })
        self.accountPeer = mutableView.accountPeer
    }
}

