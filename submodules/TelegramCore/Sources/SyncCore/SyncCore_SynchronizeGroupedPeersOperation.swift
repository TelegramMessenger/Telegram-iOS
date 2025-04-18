import Postbox

public final class SynchronizeGroupedPeersOperation: PostboxCoding {
    public let peerId: PeerId
    public let groupId: PeerGroupId
    
    public init(peerId: PeerId, groupId: PeerGroupId) {
        self.peerId = peerId
        self.groupId = groupId
    }
    
    public init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("peerId", orElse: 0))
        self.groupId = PeerGroupId.init(rawValue: decoder.decodeInt32ForKey("groupId", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "peerId")
        encoder.encodeInt32(self.groupId.rawValue, forKey: "groupId")
    }
}
