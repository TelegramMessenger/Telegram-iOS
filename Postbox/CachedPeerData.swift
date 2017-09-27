
public protocol CachedPeerData: PostboxCoding {
    var peerIds: Set<PeerId> { get }
    var messageIds: Set<MessageId> { get }
    
    func isEqual(to: CachedPeerData) -> Bool
}
