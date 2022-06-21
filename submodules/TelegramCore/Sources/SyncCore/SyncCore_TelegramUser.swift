import Postbox

public struct UserInfoFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let isVerified = UserInfoFlags(rawValue: (1 << 0))
    public static let isSupport = UserInfoFlags(rawValue: (1 << 1))
    public static let isScam = UserInfoFlags(rawValue: (1 << 2))
    public static let isFake = UserInfoFlags(rawValue: (1 << 3))
}

public struct BotUserInfoFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let hasAccessToChatHistory = BotUserInfoFlags(rawValue: (1 << 0))
    public static let worksWithGroups = BotUserInfoFlags(rawValue: (1 << 1))
    public static let requiresGeolocationForInlineRequests = BotUserInfoFlags(rawValue: (1 << 3))
    public static let canBeAddedToAttachMenu = BotUserInfoFlags(rawValue: (1 << 4))
}

public struct BotUserInfo: PostboxCoding, Equatable {
    public let flags: BotUserInfoFlags
    public let inlinePlaceholder: String?
    
    public init(flags: BotUserInfoFlags, inlinePlaceholder: String?) {
        self.flags = flags
        self.inlinePlaceholder = inlinePlaceholder
    }
    
    public init(decoder: PostboxDecoder) {
        self.flags = BotUserInfoFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.inlinePlaceholder = decoder.decodeOptionalStringForKey("ip")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        if let inlinePlaceholder = self.inlinePlaceholder {
            encoder.encodeString(inlinePlaceholder, forKey: "ip")
        } else {
            encoder.encodeNil(forKey: "ip")
        }
    }
}

public final class TelegramUser: Peer, Equatable {
    public let id: PeerId
    public let accessHash: TelegramPeerAccessHash?
    public let firstName: String?
    public let lastName: String?
    public let username: String?
    public let phone: String?
    public let photo: [TelegramMediaImageRepresentation]
    public let botInfo: BotUserInfo?
    public let restrictionInfo: PeerAccessRestrictionInfo?
    public let flags: UserInfoFlags
    
    public var nameOrPhone: String {
        if let firstName = self.firstName {
            if let lastName = self.lastName {
                return "\(firstName) \(lastName)"
            } else {
                return firstName
            }
        } else if let lastName = self.lastName {
            return lastName
        } else if let phone = self.phone, !phone.isEmpty {
            return phone
        } else {
            return ""
        }
    }
    
    public var shortNameOrPhone: String {
        if let firstName = self.firstName {
            return firstName
        } else if let lastName = self.lastName {
            return lastName
        } else if let phone = self.phone, !phone.isEmpty {
            return phone
        } else {
            return ""
        }
    }
    
    public var indexName: PeerIndexNameRepresentation {
        return .personName(first: self.firstName ?? "", last: self.lastName ?? "", addressName: self.username, phoneNumber: self.phone)
    }
    
    public let associatedPeerId: PeerId? = nil
    public let notificationSettingsPeerId: PeerId? = nil
    
    public init(id: PeerId, accessHash: TelegramPeerAccessHash?, firstName: String?, lastName: String?, username: String?, phone: String?, photo: [TelegramMediaImageRepresentation], botInfo: BotUserInfo?, restrictionInfo: PeerAccessRestrictionInfo?, flags: UserInfoFlags) {
        self.id = id
        self.accessHash = accessHash
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.phone = phone
        self.photo = photo
        self.botInfo = botInfo
        self.restrictionInfo = restrictionInfo
        self.flags = flags
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i", orElse: 0))
        
        let accessHash: Int64 = decoder.decodeInt64ForKey("ah", orElse: 0)
        let accessHashType: Int32 = decoder.decodeInt32ForKey("aht", orElse: 0)
        if accessHash != 0 {
            if accessHashType == 0 {
                self.accessHash = .personal(accessHash)
            } else {
                self.accessHash = .genericPublic(accessHash)
            }
        } else {
            self.accessHash = nil
        }
        
        self.firstName = decoder.decodeOptionalStringForKey("fn")
        self.lastName = decoder.decodeOptionalStringForKey("ln")
        
        self.username = decoder.decodeOptionalStringForKey("un")
        self.phone = decoder.decodeOptionalStringForKey("p")
        
        self.photo = decoder.decodeObjectArrayForKey("ph")
        
        if let botInfo = decoder.decodeObjectForKey("bi", decoder: { return BotUserInfo(decoder: $0) }) as? BotUserInfo {
            self.botInfo = botInfo
        } else {
            self.botInfo = nil
        }
        
        self.restrictionInfo = decoder.decodeObjectForKey("ri") as? PeerAccessRestrictionInfo
        
        self.flags = UserInfoFlags(rawValue: decoder.decodeInt32ForKey("fl", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id.toInt64(), forKey: "i")
        
        if let accessHash = self.accessHash {
            switch accessHash {
            case let .personal(value):
                encoder.encodeInt64(value, forKey: "ah")
                encoder.encodeInt32(0, forKey: "aht")
            case let .genericPublic(value):
                encoder.encodeInt64(value, forKey: "ah")
                encoder.encodeInt32(1, forKey: "aht")
            }
        }
        
        if let firstName = self.firstName {
            encoder.encodeString(firstName, forKey: "fn")
        }
        if let lastName = self.lastName {
            encoder.encodeString(lastName, forKey: "ln")
        }
        
        if let username = self.username {
            encoder.encodeString(username, forKey: "un")
        }
        if let phone = self.phone {
            encoder.encodeString(phone, forKey: "p")
        }
        
        encoder.encodeObjectArray(self.photo, forKey: "ph")
        
        if let botInfo = self.botInfo {
            encoder.encodeObject(botInfo, forKey: "bi")
        } else {
            encoder.encodeNil(forKey: "bi")
        }
        
        if let restrictionInfo = self.restrictionInfo {
            encoder.encodeObject(restrictionInfo, forKey: "ri")
        } else {
            encoder.encodeNil(forKey: "ri")
        }
        
        encoder.encodeInt32(self.flags.rawValue, forKey: "fl")
    }
    
    public func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TelegramUser {
            return self == other
        } else {
            return false
        }
    }

    public static func ==(lhs: TelegramUser, rhs: TelegramUser) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.id != rhs.id {
            return false
        }
        if lhs.accessHash != rhs.accessHash {
            return false
        }
        if lhs.firstName != rhs.firstName {
            return false
        }
        if lhs.lastName != rhs.lastName {
            return false
        }
        if lhs.phone != rhs.phone {
            return false
        }
        if lhs.photo.count != rhs.photo.count {
            return false
        }
        for i in 0 ..< lhs.photo.count {
            if lhs.photo[i] != rhs.photo[i] {
                return false
            }
        }
        if lhs.botInfo != rhs.botInfo {
            return false
        }
        if lhs.restrictionInfo != rhs.restrictionInfo {
            return false
        }

        if lhs.flags != rhs.flags {
            return false
        }

        return true
    }
    
    public func withUpdatedUsername(_ username:String?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags)
    }
    
    public func withUpdatedNames(firstName: String?, lastName: String?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: firstName, lastName: lastName, username: self.username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags)
    }
    
    public func withUpdatedPhone(_ phone: String?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags)
    }
    
    public func withUpdatedPhoto(_ representations: [TelegramMediaImageRepresentation]) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: phone, photo: representations, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags)
    }
}
