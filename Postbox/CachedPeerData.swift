
public protocol CachedPeerData: PostboxCoding {
    var peerIds: Set<PeerId> { get }
    
    func isEqual(to: CachedPeerData) -> Bool
}
