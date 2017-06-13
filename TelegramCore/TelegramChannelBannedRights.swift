import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct TelegramChannelBannedRightsFlags: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let banReadMessages = TelegramChannelBannedRightsFlags(rawValue: 1 << 0)
    public static let banSendMessages = TelegramChannelBannedRightsFlags(rawValue: 1 << 1)
    public static let banSendMedia = TelegramChannelBannedRightsFlags(rawValue: 1 << 2)
    public static let banSendStickers = TelegramChannelBannedRightsFlags(rawValue: 1 << 3)
    public static let banSendGifs = TelegramChannelBannedRightsFlags(rawValue: 1 << 4)
    public static let banSendGames = TelegramChannelBannedRightsFlags(rawValue: 1 << 5)
    public static let banSendInline = TelegramChannelBannedRightsFlags(rawValue: 1 << 6)
    public static let banEmbedLinks = TelegramChannelBannedRightsFlags(rawValue: 1 << 7)
}

public struct TelegramChannelBannedRights: Coding, Equatable {
    public let flags: TelegramChannelBannedRightsFlags
    public let untilDate: Int32
    
    public init(flags: TelegramChannelBannedRightsFlags, untilDate: Int32) {
        self.flags = flags
        self.untilDate = untilDate
    }
    
    public init(decoder: Decoder) {
        self.flags = TelegramChannelBannedRightsFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.untilDate = decoder.decodeInt32ForKey("d", orElse: 0)
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        encoder.encodeInt32(self.untilDate, forKey: "d")
    }
    
    public static func ==(lhs: TelegramChannelBannedRights, rhs: TelegramChannelBannedRights) -> Bool {
        return lhs.flags == rhs.flags && lhs.untilDate == rhs.untilDate
    }
}

extension TelegramChannelBannedRights {
    init(apiBannedRights: Api.ChannelBannedRights) {
        switch apiBannedRights {
        case let .channelBannedRights(flags, untilDate):
            self.init(flags: TelegramChannelBannedRightsFlags(rawValue: flags), untilDate: untilDate)
        }
    }
    
    var apiBannedRights: Api.ChannelBannedRights {
        return Api.ChannelBannedRights.channelBannedRights(flags: self.flags.rawValue, untilDate: self.untilDate)
    }
}
