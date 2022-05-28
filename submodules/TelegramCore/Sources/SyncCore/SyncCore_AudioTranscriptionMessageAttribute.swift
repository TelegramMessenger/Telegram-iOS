import Postbox

public class AudioTranscriptionMessageAttribute: MessageAttribute, Equatable {
    public let id: Int64
    public let text: String
    public let isPending: Bool

    public var associatedPeerIds: [PeerId] {
        return []
    }
    
    public init(id: Int64, text: String, isPending: Bool) {
        self.id = id
        self.text = text
        self.isPending = isPending
    }
    
    required public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey("id", orElse: 0)
        self.text = decoder.decodeStringForKey("text", orElse: "")
        self.isPending = decoder.decodeBoolForKey("isPending", orElse: false)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: "id")
        encoder.encodeString(self.text, forKey: "text")
        encoder.encodeBool(self.isPending, forKey: "isPending")
    }
    
    public static func ==(lhs: AudioTranscriptionMessageAttribute, rhs: AudioTranscriptionMessageAttribute) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.isPending != rhs.isPending {
            return false
        }
        return true
    }
}
