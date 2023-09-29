import Postbox

public final class TelegramMediaGiveaway: Media, Equatable {
    public var id: MediaId? {
        return nil
    }
    public var peerIds: [PeerId] {
        return self.channelPeerIds
    }
    
    public let channelPeerIds: [PeerId]
    public let quantity: Int32
    public let months: Int32
    public let untilDate: Int32

    public init(channelPeerIds: [PeerId], quantity: Int32, months: Int32, untilDate: Int32) {
        self.channelPeerIds = channelPeerIds
        self.quantity = quantity
        self.months = months
        self.untilDate = untilDate
    }
    
    public init(decoder: PostboxDecoder) {
        self.channelPeerIds = decoder.decodeInt64ArrayForKey("cns").map { PeerId($0) }
        self.quantity = decoder.decodeInt32ForKey("qty", orElse: 0)
        self.months = decoder.decodeInt32ForKey("mts", orElse: 0)
        self.untilDate = decoder.decodeInt32ForKey("unt", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64Array(self.channelPeerIds.map { $0.toInt64() }, forKey: "cns")
        encoder.encodeInt32(self.quantity, forKey: "qty")
        encoder.encodeInt32(self.months, forKey: "mts")
        encoder.encodeInt32(self.untilDate, forKey: "unt")
    }
    
    public func isLikelyToBeUpdated() -> Bool {
        return false
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaGiveaway else {
            return false
        }
        if self.channelPeerIds != other.channelPeerIds {
            return false
        }
        if self.quantity != other.quantity {
            return false
        }
        if self.months != other.months {
            return false
        }
        if self.untilDate != other.untilDate {
            return false
        }
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
    
    public static func ==(lhs: TelegramMediaGiveaway, rhs: TelegramMediaGiveaway) -> Bool {
        return lhs.isEqual(to: rhs)
    }
}
