import Foundation

public final class RenderedPeer: Equatable {
    public let peerId: PeerId
    public let peers: SimpleDictionary<PeerId, Peer>
    
    public init(peerId: PeerId, peers: SimpleDictionary<PeerId, Peer>) {
        self.peerId = peerId
        self.peers = peers
    }
    
    public init(peer: Peer) {
        self.peerId = peer.id
        self.peers = SimpleDictionary([peer.id: peer])
    }
    
    public static func ==(lhs: RenderedPeer, rhs: RenderedPeer) -> Bool {
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.peers.count != rhs.peers.count {
            return false
        }
        if !lhs.peers.isEqual(other: rhs.peers, with: { p1, p2 in
            return p1.isEqual(p2)
        }) {
            return false
        }
        return true
    }
    
    public var peer: Peer? {
        return self.peers[self.peerId]
    }
}
