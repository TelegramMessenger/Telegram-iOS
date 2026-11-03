import Postbox

public class FactCheckMessageAttribute: MessageAttribute, Equatable {
    public enum Content: PostboxCoding, Equatable {
        case Pending
        case Loaded(text: String, entities: [MessageTextEntity], country: String)
        
        public init(decoder: PostboxDecoder) {
            switch decoder.decodeInt32ForKey("_v", orElse: 0) {
            case 0:
                self = .Pending
            case 1:
                self = .Loaded(
                    text: decoder.decodeStringForKey("text", orElse: ""),
                    entities: decoder.decodeObjectArrayWithDecoderForKey("entities"),
                    country: decoder.decodeStringForKey("country", orElse: "")
                )
            default:
                assertionFailure()
                self = .Pending
            }
            
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            switch self {
            case .Pending:
                encoder.encodeInt32(0, forKey: "_v")
            case let .Loaded(text, entities, country):
                encoder.encodeInt32(1, forKey: "_v")
                encoder.encodeString(text, forKey: "text")
                encoder.encodeObjectArray(entities, forKey: "entities")
                encoder.encodeString(country, forKey: "country")
            }
        }
    }
    
    public let content: Content
    public let hash: Int64

    public var associatedPeerIds: [PeerId] {
        return []
    }
    
    public init(
        content: Content,
        hash: Int64
    ) {
        self.content = content
        self.hash = hash
    }
    
    required public init(decoder: PostboxDecoder) {
        self.content = decoder.decodeObjectForKey("content", decoder: { FactCheckMessageAttribute.Content(decoder: $0) }) as! FactCheckMessageAttribute.Content
        self.hash = decoder.decodeInt64ForKey("hash", orElse: 0)

    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.content, forKey: "content")
        encoder.encodeInt64(self.hash, forKey: "hash")
    }
    
    public static func ==(lhs: FactCheckMessageAttribute, rhs: FactCheckMessageAttribute) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.hash != rhs.hash {
            return false
        }
        return true
    }
}
