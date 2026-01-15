import Foundation
import Postbox
import TelegramApi

public final class SummarizationMessageAttribute: Equatable, MessageAttribute {
    public struct Summary: Equatable, Codable, PostboxCoding {
        public let text: String
        public let entities: [MessageTextEntity]
        
        public init(
            text: String,
            entities: [MessageTextEntity]
        ) {
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
    
    public let fromLang: String
    public let summary: Summary?
    public let translated: [String: Summary]
    
    public init(
        fromLang: String,
        summary: Summary? = nil,
        translated: [String: Summary] = [:]
    ) {
        self.fromLang = fromLang
        self.summary = summary
        self.translated = translated
    }
    
    required public init(decoder: PostboxDecoder) {
        self.fromLang = decoder.decodeStringForKey("fl", orElse: "")
        self.summary = decoder.decodeObjectForKey("s", decoder: { Summary(decoder: $0) }) as? Summary
        self.translated = decoder.decodeObjectDictionaryForKey("t", keyDecoder: { decoder in
            return decoder.decodeStringForKey("k", orElse: "")
        }, valueDecoder: { decoder in
            return Summary(decoder: decoder)
        })
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.fromLang, forKey: "fl")
        if let summary = self.summary {
            encoder.encodeObject(summary, forKey: "s")
        } else {
            encoder.encodeNil(forKey: "s")
        }
        encoder.encodeObjectDictionary(self.translated, forKey: "t", keyEncoder: { k, e in
            e.encodeString(k, forKey: "k")
        })
    }
    
    public static func ==(lhs: SummarizationMessageAttribute, rhs: SummarizationMessageAttribute) -> Bool {
        if lhs.fromLang != rhs.fromLang {
            return false
        }
        if lhs.summary != rhs.summary {
            return false
        }
        if lhs.translated != rhs.translated {
            return false
        }
        return true
    }
}

public extension SummarizationMessageAttribute {
    func summaryForLang(_ lang: String?) -> Summary? {
        if let lang {
            return self.translated[lang]
        } else {
            return self.summary
        }
    }
}
