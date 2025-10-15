import Foundation

public final class RenderedPeer: Equatable {
    public let peerId: PeerId
    public let peers: SimpleDictionary<PeerId, Peer>
    public let associatedMedia: [MediaId: Media]
    
    public init(peerId: PeerId, peers: SimpleDictionary<PeerId, Peer>, associatedMedia: [MediaId: Media]) {
        self.peerId = peerId
        self.peers = peers
        self.associatedMedia = associatedMedia
    }
    
    public init(peer: Peer) {
        self.peerId = peer.id
        self.peers = SimpleDictionary([peer.id: peer])
        self.associatedMedia = [:]
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
        if !areMediaDictionariesEqual(lhs.associatedMedia, rhs.associatedMedia) {
            return false
        }
        return true
    }
    
    public var peer: Peer? {
        return self.peers[self.peerId]
    }
}
