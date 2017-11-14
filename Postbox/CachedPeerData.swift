
public protocol CachedPeerData: PostboxCoding {
    var peerIds: Set<PeerId> { get }
    var messageIds: Set<MessageId> { get }
    
    var associatedHistoryPeerId: PeerId? { get }
    
    func isEqual(to: CachedPeerData) -> Bool
}
