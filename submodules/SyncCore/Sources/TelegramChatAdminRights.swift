import Postbox

public struct TelegramChatAdminRightsFlags: OptionSet {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public static let canChangeInfo = TelegramChatAdminRightsFlags(rawValue: 1 << 0)
    public static let canPostMessages = TelegramChatAdminRightsFlags(rawValue: 1 << 1)
    public static let canEditMessages = TelegramChatAdminRightsFlags(rawValue: 1 << 2)
    public static let canDeleteMessages = TelegramChatAdminRightsFlags(rawValue: 1 << 3)
    public static let canBanUsers = TelegramChatAdminRightsFlags(rawValue: 1 << 4)
    public static let canInviteUsers = TelegramChatAdminRightsFlags(rawValue: 1 << 5)
    public static let canPinMessages = TelegramChatAdminRightsFlags(rawValue: 1 << 7)
    public static let canAddAdmins = TelegramChatAdminRightsFlags(rawValue: 1 << 9)
    
    public static var groupSpecific: TelegramChatAdminRightsFlags = [
        .canChangeInfo,
        .canDeleteMessages,
        .canBanUsers,
        .canInviteUsers,
        .canPinMessages,
        .canAddAdmins
    ]
    
    public static var broadcastSpecific: TelegramChatAdminRightsFlags = [
        .canChangeInfo,
        .canPostMessages,
        .canEditMessages,
        .canDeleteMessages,
        .canInviteUsers,
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

public struct TelegramChatAdminRights: PostboxCoding, Equatable {
    public let flags: TelegramChatAdminRightsFlags
    
    public init(flags: TelegramChatAdminRightsFlags) {
        self.flags = flags
    }
    
    public init(decoder: PostboxDecoder) {
        self.flags = TelegramChatAdminRightsFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
    }
    
    public static func ==(lhs: TelegramChatAdminRights, rhs: TelegramChatAdminRights) -> Bool {
        return lhs.flags == rhs.flags
    }
    
    public var isEmpty: Bool {
        return self.flags.isEmpty
    }
}
