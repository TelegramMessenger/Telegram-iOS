import Postbox

public struct TelegramChatBannedRightsFlags: OptionSet, Hashable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let banReadMessages = TelegramChatBannedRightsFlags(rawValue: 1 << 0)
    public static let banSendMessages = TelegramChatBannedRightsFlags(rawValue: 1 << 1)
    public static let banSendMedia = TelegramChatBannedRightsFlags(rawValue: 1 << 2)
    public static let banSendStickers = TelegramChatBannedRightsFlags(rawValue: 1 << 3)
    public static let banSendGifs = TelegramChatBannedRightsFlags(rawValue: 1 << 4)
    public static let banSendGames = TelegramChatBannedRightsFlags(rawValue: 1 << 5)
    public static let banSendInline = TelegramChatBannedRightsFlags(rawValue: 1 << 6)
    public static let banEmbedLinks = TelegramChatBannedRightsFlags(rawValue: 1 << 7)
    public static let banSendPolls = TelegramChatBannedRightsFlags(rawValue: 1 << 8)
    public static let banChangeInfo = TelegramChatBannedRightsFlags(rawValue: 1 << 10)
    public static let banAddMembers = TelegramChatBannedRightsFlags(rawValue: 1 << 15)
    public static let banPinMessages = TelegramChatBannedRightsFlags(rawValue: 1 << 17)
}

public struct TelegramChatBannedRights: PostboxCoding, Equatable {
    public let flags: TelegramChatBannedRightsFlags
    public let untilDate: Int32
    
    public init(flags: TelegramChatBannedRightsFlags, untilDate: Int32) {
        self.flags = flags
        self.untilDate = untilDate
    }
    
    public init(decoder: PostboxDecoder) {
        self.flags = TelegramChatBannedRightsFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.untilDate = decoder.decodeInt32ForKey("d", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        encoder.encodeInt32(self.untilDate, forKey: "d")
    }
    
    public static func ==(lhs: TelegramChatBannedRights, rhs: TelegramChatBannedRights) -> Bool {
        return lhs.flags == rhs.flags && lhs.untilDate == rhs.untilDate
    }
}
