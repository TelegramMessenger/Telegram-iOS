import Postbox

public final class TelegramMediaGiveaway: Media, Equatable {
    public struct Flags: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let onlyNewSubscribers = Flags(rawValue: 1 << 0)
        public static let showWinners = Flags(rawValue: 1 << 1)
    }
    
    public enum Prize: Equatable {
        case premium(months: Int32)
        case stars(amount: Int64)
    }
    
    public var id: MediaId? {
        return nil
    }
    public var peerIds: [PeerId] {
        return self.channelPeerIds
    }
    
    public let flags: Flags
    public let channelPeerIds: [PeerId]
    public let countries: [String]
    public let quantity: Int32
    public let prize: Prize
    public let untilDate: Int32
    public let prizeDescription: String?
    
    public init(flags: Flags, channelPeerIds: [PeerId], countries: [String], quantity: Int32, prize: Prize, untilDate: Int32, prizeDescription: String?) {
        self.flags = flags
        self.channelPeerIds = channelPeerIds
        self.countries = countries
        self.quantity = quantity
        self.prize = prize
        self.untilDate = untilDate
        self.prizeDescription = prizeDescription
    }
    
    public init(decoder: PostboxDecoder) {
        self.flags = Flags(rawValue: decoder.decodeInt32ForKey("flg", orElse: 0))
        self.channelPeerIds = decoder.decodeInt64ArrayForKey("cns").map { PeerId($0) }
        self.countries = decoder.decodeStringArrayForKey("cnt")
        self.quantity = decoder.decodeInt32ForKey("qty", orElse: 0)
        if let months = decoder.decodeOptionalInt32ForKey("mts") {
            self.prize = .premium(months: months)
        } else if let stars = decoder.decodeOptionalInt64ForKey("str") {
            self.prize = .stars(amount: stars)
        } else {
            self.prize = .premium(months: 0)
        }
        self.untilDate = decoder.decodeInt32ForKey("unt", orElse: 0)
        self.prizeDescription = decoder.decodeOptionalStringForKey("des")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "flg")
        encoder.encodeInt64Array(self.channelPeerIds.map { $0.toInt64() }, forKey: "cns")
        encoder.encodeStringArray(self.countries, forKey: "cnt")
        encoder.encodeInt32(self.quantity, forKey: "qty")
        switch self.prize {
        case let .premium(months):
            encoder.encodeInt32(months, forKey: "mts")
        case let .stars(amount):
            encoder.encodeInt64(amount, forKey: "str")
        }
        encoder.encodeInt32(self.untilDate, forKey: "unt")
        if let prizeDescription = self.prizeDescription {
            encoder.encodeString(prizeDescription, forKey: "des")
        } else {
            encoder.encodeNil(forKey: "des")
        }
    }
    
    public func isLikelyToBeUpdated() -> Bool {
        return false
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? TelegramMediaGiveaway else {
            return false
        }
        if self.flags != other.flags {
            return false
        }
        if self.channelPeerIds != other.channelPeerIds {
            return false
        }
        if self.countries != other.countries {
            return false
        }
        if self.quantity != other.quantity {
            return false
        }
        if self.prize != other.prize {
            return false
        }
        if self.untilDate != other.untilDate {
            return false
        }
        if self.prizeDescription != other.prizeDescription {
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
