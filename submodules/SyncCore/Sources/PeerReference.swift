import Postbox

public enum PeerReference: PostboxCoding, Hashable, Equatable {
    case user(id: Int32, accessHash: Int64)
    case group(id: Int32)
    case channel(id: Int32, accessHash: Int64)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_r", orElse: 0) {
            case 0:
                self = .user(id: decoder.decodeInt32ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case 1:
                self = .group(id: decoder.decodeInt32ForKey("i", orElse: 0))
            case 2:
                self = .channel(id: decoder.decodeInt32ForKey("i", orElse: 0), accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            default:
                assertionFailure()
                self = .user(id: 0, accessHash: 0)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .user(id, accessHash):
                encoder.encodeInt32(0, forKey: "_r")
                encoder.encodeInt32(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case let .group(id):
                encoder.encodeInt32(1, forKey: "_r")
                encoder.encodeInt32(id, forKey: "i")
            case let .channel(id, accessHash):
                encoder.encodeInt32(2, forKey: "_r")
                encoder.encodeInt32(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
        }
    }
    
    public init?(_ peer: Peer) {
        switch peer {
            case let user as TelegramUser:
                if let accessHash = user.accessHash {
                    self = .user(id: user.id.id, accessHash: accessHash.value)
                } else {
                    return nil
                }
            case let group as TelegramGroup:
                self = .group(id: group.id.id)
            case let channel as TelegramChannel:
                if let accessHash = channel.accessHash {
                    self = .channel(id: channel.id.id, accessHash: accessHash.value)
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
}
