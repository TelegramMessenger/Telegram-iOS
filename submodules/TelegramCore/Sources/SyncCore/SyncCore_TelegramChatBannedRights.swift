import Postbox
import FlatBuffers
import FlatSerialization

public struct TelegramChatBannedRightsFlags: OptionSet, Hashable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let banReadMessages = TelegramChatBannedRightsFlags(rawValue: 1 << 0)
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
    public static let banManageTopics = TelegramChatBannedRightsFlags(rawValue: 1 << 18)
    public static let banSendPhotos = TelegramChatBannedRightsFlags(rawValue: 1 << 19)
    public static let banSendVideos = TelegramChatBannedRightsFlags(rawValue: 1 << 20)
    public static let banSendInstantVideos = TelegramChatBannedRightsFlags(rawValue: 1 << 21)
    public static let banSendMusic = TelegramChatBannedRightsFlags(rawValue: 1 << 22)
    public static let banSendVoice = TelegramChatBannedRightsFlags(rawValue: 1 << 23)
    public static let banSendFiles = TelegramChatBannedRightsFlags(rawValue: 1 << 24)
    public static let banSendText = TelegramChatBannedRightsFlags(rawValue: 1 << 25)
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
    
    public init(flatBuffersObject: TelegramCore_TelegramChatBannedRights) throws {
        self.flags = TelegramChatBannedRightsFlags(rawValue: flatBuffersObject.flags)
        self.untilDate = flatBuffersObject.untilDate
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let start = TelegramCore_TelegramChatBannedRights.startTelegramChatBannedRights(&builder)
        TelegramCore_TelegramChatBannedRights.add(flags: self.flags.rawValue, &builder)
        TelegramCore_TelegramChatBannedRights.add(untilDate: self.untilDate, &builder)
        return TelegramCore_TelegramChatBannedRights.endTelegramChatBannedRights(&builder, start: start)
    }
}
