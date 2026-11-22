import Postbox

public enum GroupParticipant: PostboxCoding, Equatable {
    case member(id: PeerId, invitedBy: PeerId, invitedAt: Int32, rank: String?)
    case creator(id: PeerId, rank: String?)
    case admin(id: PeerId, invitedBy: PeerId, invitedAt: Int32, rank: String?)
    
    public var peerId: PeerId {
        switch self {
        case let .member(id, _, _, _):
            return id
        case let .creator(id, _):
            return id
        case let .admin(id, _, _, _):
            return id
        }
    }
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
        case 0:
            self = .member(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)), invitedBy: PeerId(decoder.decodeInt64ForKey("b", orElse: 0)), invitedAt: decoder.decodeInt32ForKey("t", orElse: 0), rank: decoder.decodeOptionalStringForKey("r"))
        case 1:
            self = .creator(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)), rank: decoder.decodeOptionalStringForKey("r"))
        case 2:
            self = .admin(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)), invitedBy: PeerId(decoder.decodeInt64ForKey("b", orElse: 0)), invitedAt: decoder.decodeInt32ForKey("t", orElse: 0), rank: decoder.decodeOptionalStringForKey("r"))
        default:
            self = .member(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)), invitedBy: PeerId(decoder.decodeInt64ForKey("b", orElse: 0)), invitedAt: decoder.decodeInt32ForKey("t", orElse: 0), rank: decoder.decodeOptionalStringForKey("r"))
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case let .member(id, invitedBy, invitedAt, rank):
            encoder.encodeInt32(0, forKey: "v")
            encoder.encodeInt64(id.toInt64(), forKey: "i")
            encoder.encodeInt64(invitedBy.toInt64(), forKey: "b")
            encoder.encodeInt32(invitedAt, forKey: "t")
            if let rank {
                encoder.encodeString(rank, forKey: "r")
            } else {
                encoder.encodeNil(forKey: "r")
            }
        case let .creator(id, rank):
            encoder.encodeInt32(1, forKey: "v")
            encoder.encodeInt64(id.toInt64(), forKey: "i")
            if let rank {
                encoder.encodeString(rank, forKey: "r")
            } else {
                encoder.encodeNil(forKey: "r")
            }
        case let .admin(id, invitedBy, invitedAt, rank):
            encoder.encodeInt32(2, forKey: "v")
            encoder.encodeInt64(id.toInt64(), forKey: "i")
            encoder.encodeInt64(invitedBy.toInt64(), forKey: "b")
            encoder.encodeInt32(invitedAt, forKey: "t")
            if let rank {
                encoder.encodeString(rank, forKey: "r")
            } else {
                encoder.encodeNil(forKey: "r")
            }
        }
    }
    
    public var invitedBy: PeerId {
        switch self {
        case let .admin(_, invitedBy, _, _):
            return invitedBy
        case let .member(_, invitedBy, _, _):
            return invitedBy
        case let .creator(id, _):
            return id
        }
    }
    
    public var rank: String? {
        switch self {
        case let .admin(_, _, _, rank):
            return rank
        case let .member(_, _, _, rank):
            return rank
        case let .creator(_, rank):
            return rank
        }
    }
    
    func withUpdated(rank: String?) -> GroupParticipant {
        switch self {
        case let .member(id, invitedBy, invitedAt, _):
            return .member(id: id, invitedBy: invitedBy, invitedAt: invitedAt, rank: rank)
        case let .admin(id, invitedBy, invitedAt, _):
            return .admin(id: id, invitedBy: invitedBy, invitedAt: invitedAt, rank: rank)
        case let .creator(id, _):
            return .creator(id: id, rank: rank)
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
