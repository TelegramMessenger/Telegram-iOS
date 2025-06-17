import Postbox
import FlatBuffers
import FlatSerialization

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
    public static let canManageTopics = TelegramChatAdminRightsFlags(rawValue: 1 << 13)
    public static let canPostStories = TelegramChatAdminRightsFlags(rawValue: 1 << 14)
    public static let canEditStories = TelegramChatAdminRightsFlags(rawValue: 1 << 15)
    public static let canDeleteStories = TelegramChatAdminRightsFlags(rawValue: 1 << 16)
    public static let canManageDirect = TelegramChatAdminRightsFlags(rawValue: 1 << 17)
    
    public static var all: TelegramChatAdminRightsFlags {
        return [.canChangeInfo, .canPostMessages, .canEditMessages, .canDeleteMessages, .canBanUsers, .canInviteUsers, .canPinMessages, .canAddAdmins, .canBeAnonymous, .canManageCalls, .canManageTopics, .canPostStories, .canEditStories, .canDeleteStories]
    }
    
    public static var allChannel: TelegramChatAdminRightsFlags {
        return [.canChangeInfo, .canPostMessages, .canEditMessages, .canDeleteMessages, .canBanUsers, .canInviteUsers, .canPinMessages, .canAddAdmins, .canManageCalls, .canManageTopics, .canPostStories, .canEditStories, .canDeleteStories, .canManageDirect]
    }
    
    public static let internal_groupSpecific: TelegramChatAdminRightsFlags = [
        .canChangeInfo,
        .canDeleteMessages,
        .canBanUsers,
        .canInviteUsers,
        .canPinMessages,
        .canManageCalls,
        .canBeAnonymous,
        .canAddAdmins,
        .canPostStories,
        .canEditStories,
        .canDeleteStories
    ]
    
    public static let internal_broadcastSpecific: TelegramChatAdminRightsFlags = [
        .canChangeInfo,
        .canPostMessages,
        .canEditMessages,
        .canDeleteMessages,
        .canManageCalls,
        .canInviteUsers,
        .canAddAdmins,
        .canPostStories,
        .canEditStories,
        .canDeleteStories,
        .canManageDirect
    ]
    
    public static func peerSpecific(peer: EnginePeer) -> TelegramChatAdminRightsFlags {
        if case let .channel(channel) = peer {
            if channel.flags.contains(.isForum) {
                return internal_groupSpecific.union(.canManageTopics)
            } else if case .broadcast = channel.info {
                return internal_broadcastSpecific
            } else {
                return internal_groupSpecific
            }
        } else {
            return internal_groupSpecific
        }
    }
    
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

public struct TelegramChatAdminRights: PostboxCoding, Codable, Equatable {
    public let rights: TelegramChatAdminRightsFlags
    
    public init(rights: TelegramChatAdminRightsFlags) {
        self.rights = rights
    }
    
    public init(decoder: PostboxDecoder) {
        self.rights = TelegramChatAdminRightsFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)
        
        self.rights = TelegramChatAdminRightsFlags(rawValue: try container.decode(Int32.self, forKey: "f"))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.rights.rawValue, forKey: "f")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: StringCodingKey.self)
        
        try container.encode(self.rights.rawValue, forKey: "f")
    }
    
    public static func ==(lhs: TelegramChatAdminRights, rhs: TelegramChatAdminRights) -> Bool {
        return lhs.rights == rhs.rights
    }
    
    public init(flatBuffersObject: TelegramCore_TelegramChatAdminRights) throws {
        self.rights = TelegramChatAdminRightsFlags(rawValue: flatBuffersObject.rights)
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let start = TelegramCore_TelegramChatAdminRights.startTelegramChatAdminRights(&builder)
        TelegramCore_TelegramChatAdminRights.add(rights: self.rights.rawValue, &builder)
        return TelegramCore_TelegramChatAdminRights.endTelegramChatAdminRights(&builder, start: start)
    }
}
