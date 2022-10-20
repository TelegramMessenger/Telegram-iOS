import Postbox

public final class TelegramMediaDice: Media {
    public let emoji: String
    public let value: Int32?
    
    public let id: MediaId? = nil
    public let peerIds: [PeerId] = []
    
    public init(emoji: String, value: Int32? = nil) {
        self.emoji = emoji
        self.value = value
    }
    
    public init(decoder: PostboxDecoder) {
        self.emoji = decoder.decodeStringForKey("e", orElse: "🎲")
        self.value = decoder.decodeOptionalInt32ForKey("v")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.emoji, forKey: "e")
        if let value = self.value {
            encoder.encodeInt32(value, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
    }
    
    public func isEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaDice {
            if self.emoji != other.emoji {
                return false
            }
            if self.value != other.value {
                return false
            }
            return true
        }
        return false
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
