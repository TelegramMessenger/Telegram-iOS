import Postbox

public final class TelegramMediaGiveawayResults: Media, Equatable {
    public struct Flags: OptionSet {
        public var rawValue: Int32
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let refunded = Flags(rawValue: 1 << 0)
        public static let onlyNewSubscribers = Flags(rawValue: 1 << 1)
    }
    
    public enum Prize: Equatable {
        case premium(months: Int32)
        case stars(amount: Int64)
    }
    
    public var id: MediaId? {
        return nil
    }
    public var peerIds: [PeerId] {
        return self.winnersPeerIds
    }
    
    public let flags: Flags
    public let launchMessageId: MessageId
    public let additionalChannelsCount: Int32
    public let winnersPeerIds: [PeerId]
    public let winnersCount: Int32
    public let unclaimedCount: Int32
    public let prize: Prize
    public let untilDate: Int32
    public let prizeDescription: String?
    
    public init(flags: Flags, launchMessageId: MessageId, additionalChannelsCount: Int32, winnersPeerIds: [PeerId], winnersCount: Int32, unclaimedCount: Int32, prize: Prize, untilDate: Int32, prizeDescription: String?) {
        self.flags = flags
        self.launchMessageId = launchMessageId
        self.additionalChannelsCount = additionalChannelsCount
        self.winnersPeerIds = winnersPeerIds
        self.winnersCount = winnersCount
        self.unclaimedCount = unclaimedCount
        self.prize = prize
        self.untilDate = untilDate
        self.prizeDescription = prizeDescription
    }
    
    public init(decoder: PostboxDecoder) {
        self.flags = Flags(rawValue: decoder.decodeInt32ForKey("flg", orElse: 0))
        self.launchMessageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("msgp", orElse: 0)), namespace: Namespaces.Message.Cloud, id: decoder.decodeInt32ForKey("msgi", orElse: 0))
        self.additionalChannelsCount = decoder.decodeInt32ForKey("chn", orElse: 0)
        self.winnersPeerIds = decoder.decodeInt64ArrayForKey("wnr").map { PeerId($0) }
        self.winnersCount = decoder.decodeInt32ForKey("wnc", orElse: 0)
        self.unclaimedCount = decoder.decodeInt32ForKey("unc", orElse: 0)
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
        encoder.encodeInt64(self.launchMessageId.peerId.toInt64(), forKey: "msgp")
        encoder.encodeInt32(self.launchMessageId.id, forKey: "msgi")
        encoder.encodeInt32(self.additionalChannelsCount, forKey: "chn")
        encoder.encodeInt64Array(self.winnersPeerIds.map { $0.toInt64() }, forKey: "wnr")
        encoder.encodeInt32(self.winnersCount, forKey: "wnc")
        encoder.encodeInt32(self.unclaimedCount, forKey: "unc")
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
        guard let other = other as? TelegramMediaGiveawayResults else {
            return false
        }
        if self.flags != other.flags {
            return false
        }
        if self.launchMessageId != other.launchMessageId {
            return false
        }
        if self.additionalChannelsCount != other.additionalChannelsCount {
            return false
        }
        if self.winnersPeerIds != other.winnersPeerIds {
            return false
        }
        if self.winnersCount != other.winnersCount {
            return false
        }
        if self.unclaimedCount != other.unclaimedCount {
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
    
    public static func ==(lhs: TelegramMediaGiveawayResults, rhs: TelegramMediaGiveawayResults) -> Bool {
        return lhs.isEqual(to: rhs)
    }
}
