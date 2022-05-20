import Postbox

public class AudioTranscriptionMessageAttribute: MessageAttribute, Equatable {
    public let id: Int64
    public let text: String

    public var associatedPeerIds: [PeerId] {
        return []
    }
    
    public init(id: Int64, text: String) {
        self.id = id
        self.text = text
    }
    
    required public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey("id", orElse: 0)
        self.text = decoder.decodeStringForKey("text", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: "id")
        encoder.encodeString(self.text, forKey: "text")
    }
    
    public static func ==(lhs: AudioTranscriptionMessageAttribute, rhs: AudioTranscriptionMessageAttribute) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        return true
    }
}
