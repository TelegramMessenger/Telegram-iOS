import Postbox

private enum SynchronizeAppLogEventsOperationContentType: Int32 {
    case add
    case sync
}

public enum SynchronizeAppLogEventsOperationContent: Codable {
    case add(time: Double, type: String, peerId: PeerId?, data: JSON)
    case sync
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        switch try container.decode(Int32.self, forKey: "r") {
        case SynchronizeAppLogEventsOperationContentType.add.rawValue:
            var peerId: PeerId?
            if let id = try? container.decodeIfPresent(Int64.self, forKey: "p") {
                peerId = PeerId(id)
            }
            self = .add(
                time: try container.decode(Double.self, forKey: "tm"),
                type: try container.decode(String.self, forKey: "t"),
                peerId: peerId,
                data: try container.decode(JSON.self, forKey: "d")
            )
        case SynchronizeAppLogEventsOperationContentType.sync.rawValue:
            self = .sync
        default:
            assertionFailure()
            self = .sync
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        switch self {
        case let .add(time, type, peerId, data):
            try container.encode(SynchronizeAppLogEventsOperationContentType.add.rawValue, forKey: "r")
            try container.encode(time, forKey: "tm")
            try container.encode(type, forKey: "t")
            try container.encodeIfPresent(peerId?.toInt64(), forKey: "p")
            try container.encode(data, forKey: "d")
        case .sync:
            try container.encode(SynchronizeAppLogEventsOperationContentType.sync.rawValue, forKey: "r")
        }
    }
}

public final class SynchronizeAppLogEventsOperation: Codable, PostboxCoding {
    public let content: SynchronizeAppLogEventsOperationContent
    
    public init(content: SynchronizeAppLogEventsOperationContent) {
        self.content = content
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        self.content = try container.decode(SynchronizeAppLogEventsOperationContent.self, forKey: "c")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)

        try container.encode(self.content, forKey: "c")
    }

    public init(decoder: PostboxDecoder) {
        self.content = decoder.decode(SynchronizeAppLogEventsOperationContent.self, forKey: "c")!
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encode(self.content, forKey: "c")
    }
}
