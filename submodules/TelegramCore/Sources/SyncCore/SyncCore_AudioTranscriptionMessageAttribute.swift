import Postbox

public class AudioTranscriptionMessageAttribute: MessageAttribute, Equatable {
    public enum TranscriptionError: Int32, Error {
        case generic = 0
        case tooLong = 1
    }
    
    public let id: Int64
    public let text: String
    public let isPending: Bool
    public let didRate: Bool
    public let error: TranscriptionError?

    public var associatedPeerIds: [PeerId] {
        return []
    }
    
    public init(id: Int64, text: String, isPending: Bool, didRate: Bool, error: TranscriptionError?) {
        self.id = id
        self.text = text
        self.isPending = isPending
        self.didRate = didRate
        self.error = error
    }
    
    required public init(decoder: PostboxDecoder) {
        self.id = decoder.decodeInt64ForKey("id", orElse: 0)
        self.text = decoder.decodeStringForKey("text", orElse: "")
        self.isPending = decoder.decodeBoolForKey("isPending", orElse: false)
        self.didRate = decoder.decodeBoolForKey("didRate", orElse: false)
        if let errorValue = decoder.decodeOptionalInt32ForKey("error") {
            self.error = TranscriptionError(rawValue: errorValue)
        } else {
            self.error = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id, forKey: "id")
        encoder.encodeString(self.text, forKey: "text")
        encoder.encodeBool(self.isPending, forKey: "isPending")
        encoder.encodeBool(self.didRate, forKey: "didRate")
        if let error = self.error {
            encoder.encodeInt32(error.rawValue, forKey: "error")
        } else {
            encoder.encodeNil(forKey: "error")
        }
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
        if lhs.didRate != rhs.didRate {
            return false
        }
        if lhs.error != rhs.error {
            return false
        }
        return true
    }
    
    func merge(withPrevious other: AudioTranscriptionMessageAttribute) -> AudioTranscriptionMessageAttribute {
        return AudioTranscriptionMessageAttribute(id: self.id, text: self.text, isPending: self.isPending, didRate: self.didRate || other.didRate, error: self.error)
    }
    
    func withDidRate() -> AudioTranscriptionMessageAttribute {
        return AudioTranscriptionMessageAttribute(id: self.id, text: self.text, isPending: self.isPending, didRate: true, error: self.error)
    }
}
