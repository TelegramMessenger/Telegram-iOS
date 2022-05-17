import Postbox

public class AudioTranscriptionMessageAttribute: MessageAttribute, Equatable {
    public let locale: String
    public let text: String

    public var associatedPeerIds: [PeerId] {
        return []
    }
    
    public init(locale: String, text: String) {
        self.locale = locale
        self.text = text
    }
    
    required public init(decoder: PostboxDecoder) {
        self.locale = decoder.decodeStringForKey("locale", orElse: "")
        self.text = decoder.decodeStringForKey("text", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.locale, forKey: "locale")
        encoder.encodeString(self.text, forKey: "text")
    }
    
    public static func ==(lhs: AudioTranscriptionMessageAttribute, rhs: AudioTranscriptionMessageAttribute) -> Bool {
        if lhs.locale != rhs.locale {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
}
