
public protocol CachedPeerData: Coding {
    var peerIds: Set<PeerId> { get }
    
    func isEqual(to: CachedPeerData) -> Bool
}
