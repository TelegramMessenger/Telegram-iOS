import Postbox

public class TranslationMessageAttribute: MessageAttribute, Equatable {
    
    public struct Additional : PostboxCoding, Equatable {
        
        public let text: String
        public let entities: [MessageTextEntity]
        public init(text: String, entities: [MessageTextEntity]) {
            self.text = text
            self.entities = entities
        }
        
        public init(decoder: PostboxDecoder) {
            self.text = decoder.decodeStringForKey("text", orElse: "")
            self.entities = decoder.decodeObjectArrayWithDecoderForKey("entities")
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeString(self.text, forKey: "text")
            encoder.encodeObjectArray(self.entities, forKey: "entities")
        }
        
        
    }
    
    public let text: String
    public let entities: [MessageTextEntity]
    public let toLang: String

    public let additional:[Additional]
    
    public var associatedPeerIds: [PeerId] {
        return []
    }
    
    public init(
        text: String,
        entities: [MessageTextEntity],
        additional:[Additional] = [],
        toLang: String
    ) {
        self.text = text
        self.entities = entities
        self.toLang = toLang
        self.additional = additional
    }
    
    required public init(decoder: PostboxDecoder) {
        self.text = decoder.decodeStringForKey("text", orElse: "")
        self.entities = decoder.decodeObjectArrayWithDecoderForKey("entities")
        self.additional = decoder.decodeObjectArrayWithDecoderForKey("additional")
        self.toLang = decoder.decodeStringForKey("toLang", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.text, forKey: "text")
        encoder.encodeObjectArray(self.entities, forKey: "entities")
        encoder.encodeString(self.toLang, forKey: "toLang")
        encoder.encodeObjectArray(self.additional, forKey: "additional")
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
        if lhs.additional != rhs.additional {
            return false
        }
        return true
    }
}
