import Postbox
import FlatBuffers
import FlatSerialization

public enum PeerReference: PostboxCoding, Hashable, Equatable {
    case user(id: Int64, accessHash: Int64)
    case group(id: Int64)
    case channel(id: Int64, accessHash: Int64)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_r", orElse: 0) {
            case 0:
                let id: Int64
                if let idValue = decoder.decodeOptionalInt64ForKey("i") {
                    id = idValue
                } else {
                    id = Int64(decoder.decodeInt32ForKey("i", orElse: 0))
                }
                self = .user(id: id, accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            case 1:
                let id: Int64
                if let idValue = decoder.decodeOptionalInt64ForKey("i") {
                    id = idValue
                } else {
                    id = Int64(decoder.decodeInt32ForKey("i", orElse: 0))
                }
                self = .group(id: id)
            case 2:
                let id: Int64
                if let idValue = decoder.decodeOptionalInt64ForKey("i") {
                    id = idValue
                } else {
                    id = Int64(decoder.decodeInt32ForKey("i", orElse: 0))
                }
                self = .channel(id: id, accessHash: decoder.decodeInt64ForKey("h", orElse: 0))
            default:
                assertionFailure()
                self = .user(id: 0, accessHash: 0)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .user(id, accessHash):
                encoder.encodeInt32(0, forKey: "_r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
            case let .group(id):
                encoder.encodeInt32(1, forKey: "_r")
                encoder.encodeInt64(id, forKey: "i")
            case let .channel(id, accessHash):
                encoder.encodeInt32(2, forKey: "_r")
                encoder.encodeInt64(id, forKey: "i")
                encoder.encodeInt64(accessHash, forKey: "h")
        }
    }
    
    public init?(_ peer: Peer) {
        switch peer {
            case let user as TelegramUser:
                if let accessHash = user.accessHash {
                    self = .user(id: user.id.id._internalGetInt64Value(), accessHash: accessHash.value)
                } else {
                    return nil
                }
            case let group as TelegramGroup:
                self = .group(id: group.id.id._internalGetInt64Value())
            case let channel as TelegramChannel:
                if let accessHash = channel.accessHash {
                    self = .channel(id: channel.id.id._internalGetInt64Value(), accessHash: accessHash.value)
                } else {
                    return nil
                }
            default:
                return nil
        }
    }
    
    public init(flatBuffersObject: TelegramCore_PeerReference) throws {
        switch flatBuffersObject.valueType {
        case .peerreferenceUser:
            guard let value = flatBuffersObject.value(type: TelegramCore_PeerReference_User.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .user(id: value.id, accessHash: value.accessHash)
        case .peerreferenceGroup:
            guard let value = flatBuffersObject.value(type: TelegramCore_PeerReference_Group.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .group(id: value.id)
        case .peerreferenceChannel:
            guard let value = flatBuffersObject.value(type: TelegramCore_PeerReference_Channel.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .channel(id: value.id, accessHash: value.accessHash)
        case .none_:
            throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
        }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        switch self {
        case let .user(id, accessHash):
            let start = TelegramCore_PeerReference.startPeerReference(&builder)
            TelegramCore_PeerReference_User.add(id: id, &builder)
            TelegramCore_PeerReference_User.add(accessHash: accessHash, &builder)
            let offset = TelegramCore_PeerReference_User.endPeerReference_User(&builder, start: start)
            return TelegramCore_PeerReference.createPeerReference(&builder, valueType: .peerreferenceUser, valueOffset: offset)
        case let .group(id):
            let start = TelegramCore_PeerReference.startPeerReference(&builder)
            TelegramCore_PeerReference_Group.add(id: id, &builder)
            let offset = TelegramCore_PeerReference_Group.endPeerReference_Group(&builder, start: start)
            return TelegramCore_PeerReference.createPeerReference(&builder, valueType: .peerreferenceUser, valueOffset: offset)
        case let .channel(id, accessHash):
            let start = TelegramCore_PeerReference.startPeerReference(&builder)
            TelegramCore_PeerReference_Channel.add(id: id, &builder)
            TelegramCore_PeerReference_Channel.add(accessHash: accessHash, &builder)
            let offset = TelegramCore_PeerReference_Channel.endPeerReference_Channel(&builder, start: start)
            return TelegramCore_PeerReference.createPeerReference(&builder, valueType: .peerreferenceUser, valueOffset: offset)
        }
    }
}
