import Postbox

public enum GroupParticipant: PostboxCoding, Equatable {
    case member(id: PeerId, invitedBy: PeerId, invitedAt: Int32)
    case creator(id: PeerId)
    case admin(id: PeerId, invitedBy: PeerId, invitedAt: Int32)
    
    public var peerId: PeerId {
        switch self {
        case let .member(id, _, _):
            return id
        case let .creator(id):
            return id
        case let .admin(id, _, _):
            return id
        }
    }
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
        case 0:
            self = .member(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)), invitedBy: PeerId(decoder.decodeInt64ForKey("b", orElse: 0)), invitedAt: decoder.decodeInt32ForKey("t", orElse: 0))
        case 1:
            self = .creator(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)))
        case 2:
            self = .admin(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)), invitedBy: PeerId(decoder.decodeInt64ForKey("b", orElse: 0)), invitedAt: decoder.decodeInt32ForKey("t", orElse: 0))
        default:
            self = .member(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)), invitedBy: PeerId(decoder.decodeInt64ForKey("b", orElse: 0)), invitedAt: decoder.decodeInt32ForKey("t", orElse: 0))
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case let .member(id, invitedBy, invitedAt):
            encoder.encodeInt32(0, forKey: "v")
            encoder.encodeInt64(id.toInt64(), forKey: "i")
            encoder.encodeInt64(invitedBy.toInt64(), forKey: "b")
            encoder.encodeInt32(invitedAt, forKey: "t")
        case let .creator(id):
            encoder.encodeInt32(1, forKey: "v")
            encoder.encodeInt64(id.toInt64(), forKey: "i")
        case let .admin(id, invitedBy, invitedAt):
            encoder.encodeInt32(2, forKey: "v")
            encoder.encodeInt64(id.toInt64(), forKey: "i")
            encoder.encodeInt64(invitedBy.toInt64(), forKey: "b")
            encoder.encodeInt32(invitedAt, forKey: "t")
        }
    }
    
    public var invitedBy: PeerId {
        switch self {
        case let .admin(_, invitedBy, _):
            return invitedBy
        case let .member(_, invitedBy, _):
            return invitedBy
        case let .creator(id):
            return id
        }
    }
}

public final class CachedGroupParticipants: PostboxCoding, Equatable {
    public let participants: [GroupParticipant]
    public let version: Int32
    
    public init(participants: [GroupParticipant], version: Int32) {
        self.participants = participants
        self.version = version
    }
    
    public init(decoder: PostboxDecoder) {
        self.participants = decoder.decodeObjectArrayWithDecoderForKey("p")
        self.version = decoder.decodeInt32ForKey("v", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.participants, forKey: "p")
        encoder.encodeInt32(self.version, forKey: "v")
    }
    
    public static func ==(lhs: CachedGroupParticipants, rhs: CachedGroupParticipants) -> Bool {
        return lhs.version == rhs.version && lhs.participants == rhs.participants
    }
}
