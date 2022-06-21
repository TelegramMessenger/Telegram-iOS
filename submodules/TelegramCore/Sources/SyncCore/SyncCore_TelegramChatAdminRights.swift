import Postbox

public struct TelegramChatAdminRightsFlags: OptionSet, Hashable {
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
    public static let canBeAnonymous = TelegramChatAdminRightsFlags(rawValue: 1 << 10)
    public static let canManageCalls = TelegramChatAdminRightsFlags(rawValue: 1 << 11)
    
    public static var all: TelegramChatAdminRightsFlags {
        return [.canChangeInfo, .canPostMessages, .canEditMessages, .canDeleteMessages, .canBanUsers, .canInviteUsers, .canPinMessages, .canAddAdmins, .canBeAnonymous, .canManageCalls]
    }
    
    public static var allChannel: TelegramChatAdminRightsFlags {
        return [.canChangeInfo, .canPostMessages, .canEditMessages, .canDeleteMessages, .canBanUsers, .canInviteUsers, .canPinMessages, .canAddAdmins, .canManageCalls]
    }

    
    public static var groupSpecific: TelegramChatAdminRightsFlags = [
        .canChangeInfo,
        .canDeleteMessages,
        .canBanUsers,
        .canInviteUsers,
        .canPinMessages,
        .canManageCalls,
        .canBeAnonymous,
        .canAddAdmins
    ]
    
    public static var broadcastSpecific: TelegramChatAdminRightsFlags = [
        .canChangeInfo,
        .canPostMessages,
        .canEditMessages,
        .canDeleteMessages,
        .canManageCalls,
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
    public let rights: TelegramChatAdminRightsFlags
    
    public init(rights: TelegramChatAdminRightsFlags) {
        self.rights = rights
    }
    
    public init(decoder: PostboxDecoder) {
        self.rights = TelegramChatAdminRightsFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.rights.rawValue, forKey: "f")
    }
    
    public static func ==(lhs: TelegramChatAdminRights, rhs: TelegramChatAdminRights) -> Bool {
        return lhs.rights == rhs.rights
    }
}
