import Postbox

public final class TelegramMediaDice: Media {
    public let value: Int32?
    
    public let id: MediaId? = nil
    public let peerIds: [PeerId] = []
    
    public init(value: Int32? = nil) {
        self.value = value
    }
    
    public init(decoder: PostboxDecoder) {
        self.value = decoder.decodeOptionalInt32ForKey("v")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let value = self.value {
            encoder.encodeInt32(value, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
    }
    
    public func isEqual(to other: Media) -> Bool {
        if let other = other as? TelegramMediaDice {
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
