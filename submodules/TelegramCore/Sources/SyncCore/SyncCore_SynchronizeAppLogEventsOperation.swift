import Postbox

private enum SynchronizeAppLogEventsOperationContentType: Int32 {
    case add
    case sync
}

public enum SynchronizeAppLogEventsOperationContent: PostboxCoding {
    case add(time: Double, type: String, peerId: PeerId?, data: JSON)
    case sync
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
        case SynchronizeAppLogEventsOperationContentType.add.rawValue:
            var peerId: PeerId?
            if let id = decoder.decodeOptionalInt64ForKey("p") {
                peerId = PeerId(id)
            }
            self = .add(time: decoder.decodeDoubleForKey("tm", orElse: 0.0), type: decoder.decodeStringForKey("t", orElse: ""), peerId: peerId, data: decoder.decodeObjectForKey("d", decoder: { JSON(decoder: $0) }) as! JSON)
        case SynchronizeAppLogEventsOperationContentType.sync.rawValue:
            self = .sync
        default:
            assertionFailure()
            self = .sync
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
        case let .add(time, type, peerId, data):
            encoder.encodeInt32(SynchronizeAppLogEventsOperationContentType.add.rawValue, forKey: "r")
            encoder.encodeDouble(time, forKey: "tm")
            encoder.encodeString(type, forKey: "t")
            if let peerId = peerId {
                encoder.encodeInt64(peerId.toInt64(), forKey: "p")
            } else {
                encoder.encodeNil(forKey: "p")
            }
            encoder.encodeObject(data, forKey: "d")
        case .sync:
            encoder.encodeInt32(SynchronizeAppLogEventsOperationContentType.sync.rawValue, forKey: "r")
        }
    }
}

public final class SynchronizeAppLogEventsOperation: PostboxCoding {
    public let content: SynchronizeAppLogEventsOperationContent
    
    public init(content: SynchronizeAppLogEventsOperationContent) {
        self.content = content
    }
    
    public init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("c", decoder: { SynchronizeAppLogEventsOperationContent(decoder: $0) }) as! SynchronizeAppLogEventsOperationContent
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "c")
    }
}
