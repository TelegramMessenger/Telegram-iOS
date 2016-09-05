import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum TelegramGroupMembership: Int32 {
    case Member
    case Left
    case Removed
}

public final class TelegramGroup: Peer {
    public let id: PeerId
    public let title: String
    public let photo: [TelegramMediaImageRepresentation]
    public let participantCount: Int
    public let membership: TelegramGroupMembership
    public let version: Int
    
    public var indexName: PeerIndexNameRepresentation {
        return .title(self.title)
    }
    
    public init(id: PeerId, title: String, photo: [TelegramMediaImageRepresentation], participantCount: Int, membership: TelegramGroupMembership, version: Int) {
        self.id = id
        self.title = title
        self.photo = photo
        self.participantCount = participantCount
        self.membership = membership
        self.version = version
    }
    
    public init(decoder: Decoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i"))
        self.title = decoder.decodeStringForKey("t")
        self.photo = decoder.decodeObjectArrayForKey("ph")
        self.participantCount = Int(decoder.decodeInt32ForKey("pc"))
        self.membership = TelegramGroupMembership(rawValue: decoder.decodeInt32ForKey("m"))!
        self.version = Int(decoder.decodeInt32ForKey("v"))
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.id.toInt64(), forKey: "i")
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeObjectArray(self.photo, forKey: "ph")
        encoder.encodeInt32(Int32(self.participantCount), forKey: "pc")
        encoder.encodeInt32(self.membership.rawValue, forKey: "m")
        encoder.encodeInt32(Int32(self.version), forKey: "v")
    }
    
    public func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TelegramGroup {
            if self.id != other.id {
                return false
            }
            if self.title != other.title {
                return false
            }
            if self.photo != other.photo {
                return false
            }
            if self.membership != other.membership {
                return false
            }
            if self.version != other.version {
                return false
            }
            if self.participantCount != other.participantCount {
                return false
            }
            return true
        } else {
            return false
        }
    }
}
