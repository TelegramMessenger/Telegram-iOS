import Postbox

public class TranslationMessageAttribute: MessageAttribute, Equatable {
    public let text: String
    public let entities: [MessageTextEntity]
    public let toLang: String

    public var associatedPeerIds: [PeerId] {
        return []
    }
    
    public init(
        text: String,
        entities: [MessageTextEntity],
        toLang: String
    ) {
        self.text = text
        self.entities = entities
        self.toLang = toLang
    }
    
    required public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("text", orElse: "")
        self.entities = decoder.decodeObjectArrayWithDecoderForKey("entities")
        self.toLang = decoder.decodeStringForKey("toLang", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "text")
        encoder.encodeObjectArray(self.entities, forKey: "entities")
        encoder.encodeString(self.toLang, forKey: "toLang")
    }
    
    public static func ==(lhs: TranslationMessageAttribute, rhs: TranslationMessageAttribute) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if lhs.toLang != rhs.toLang {
            return false
        }
        return true
    }
}
