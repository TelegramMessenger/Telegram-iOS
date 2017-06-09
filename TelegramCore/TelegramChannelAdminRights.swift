import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public struct TelegramChannelAdminRightsFlags: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let canChangeInfo = TelegramChannelAdminRightsFlags(rawValue: 1 << 0)
    public static let canPostMessages = TelegramChannelAdminRightsFlags(rawValue: 1 << 1)
    public static let canEditMessages = TelegramChannelAdminRightsFlags(rawValue: 1 << 2)
    public static let canDeleteMessages = TelegramChannelAdminRightsFlags(rawValue: 1 << 3)
    public static let canBanUsers = TelegramChannelAdminRightsFlags(rawValue: 1 << 4)
    public static let canInviteUsers = TelegramChannelAdminRightsFlags(rawValue: 1 << 5)
    public static let canChangeInviteLink = TelegramChannelAdminRightsFlags(rawValue: 1 << 6)
    public static let canPinMessages = TelegramChannelAdminRightsFlags(rawValue: 1 << 7)
    public static let canAddAdmins = TelegramChannelAdminRightsFlags(rawValue: 1 << 9)
    
    public static var groupSpecific: TelegramChannelAdminRightsFlags = [
        .canChangeInfo,
        .canDeleteMessages,
        .canBanUsers,
        .canInviteUsers,
        .canChangeInviteLink,
        .canPinMessages,
        .canAddAdmins
    ]
    
    public static var broadcastSpecific: TelegramChannelAdminRightsFlags = [
        .canChangeInfo,
        .canPostMessages,
        .canEditMessages,
        .canDeleteMessages,
        .canAddAdmins
    ]
    
    public var count: Int {
        var result = 0
        var index = 0
        while index < 31 {
            let currentValue = self.rawValue >> Int32(index)
            index += 1
            if currentValue == 0 {
                break
            }
            
            if (currentValue & 1) != 0 {
                result += 1
            }
        }
        return result
    }
}

public struct TelegramChannelAdminRights: Coding, Equatable {
    public let flags: TelegramChannelAdminRightsFlags
    
    public init(flags: TelegramChannelAdminRightsFlags) {
        self.flags = flags
    }
    
    public init(decoder: Decoder) {
        self.flags = TelegramChannelAdminRightsFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
    }
    
    public static func ==(lhs: TelegramChannelAdminRights, rhs: TelegramChannelAdminRights) -> Bool {
        return lhs.flags == rhs.flags
    }
    
    public var isEmpty: Bool {
        return self.flags.isEmpty
    }
}

extension TelegramChannelAdminRights {
    init(apiAdminRights: Api.ChannelAdminRights) {
        switch apiAdminRights {
            case let .channelAdminRights(flags):
                self.init(flags: TelegramChannelAdminRightsFlags(rawValue: flags))
        }
    }
    
    var apiAdminRights: Api.ChannelAdminRights {
        return Api.ChannelAdminRights.channelAdminRights(flags: self.flags.rawValue)
    }
}
