import Postbox
import FlatBuffers
import FlatSerialization

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
    public static let isPremium = UserInfoFlags(rawValue: (1 << 4))
    public static let isCloseFriend = UserInfoFlags(rawValue: (1 << 5))
    public static let requirePremium = UserInfoFlags(rawValue: (1 << 6))
    public static let mutualContact = UserInfoFlags(rawValue: (1 << 7))
    public static let requireStars = UserInfoFlags(rawValue: (1 << 8))
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
    public static let canEdit = BotUserInfoFlags(rawValue: (1 << 5))
    public static let isBusiness = BotUserInfoFlags(rawValue: (1 << 6))
    public static let hasWebApp = BotUserInfoFlags(rawValue: (1 << 7))
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
    
    public init(flatBuffersObject: TelegramCore_BotUserInfo) throws {
        self.flags = BotUserInfoFlags(rawValue: flatBuffersObject.flags)
        self.inlinePlaceholder = flatBuffersObject.inlinePlaceholder
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let inlinePlaceholderOffset = self.inlinePlaceholder.map { builder.create(string: $0) }
        
        let start = TelegramCore_BotUserInfo.startBotUserInfo(&builder)
        TelegramCore_BotUserInfo.add(flags: self.flags.rawValue, &builder)
        if let inlinePlaceholderOffset {
            TelegramCore_BotUserInfo.add(inlinePlaceholder: inlinePlaceholderOffset, &builder)
        }
        return TelegramCore_BotUserInfo.endBotUserInfo(&builder, start: start)
    }
}

public struct TelegramPeerUsername: PostboxCoding, Equatable {
    public struct Flags: OptionSet {
        public var rawValue: Int32
        
        public init() {
            self.rawValue = 0
        }
        
        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public static let isEditable = Flags(rawValue: (1 << 0))
        public static let isActive = Flags(rawValue: (1 << 1))
    }
    
    public let flags: Flags
    public let username: String
    
    public init(flags: Flags, username: String) {
        self.flags = flags
        self.username = username
    }
    
    public init(decoder: PostboxDecoder) {
        self.flags = Flags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.username = decoder.decodeStringForKey("un", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        encoder.encodeString(self.username, forKey: "un")
    }
    
    public init(flatBuffersObject: TelegramCore_TelegramPeerUsername) throws {
        self.flags = Flags(rawValue: flatBuffersObject.flags)
        self.username = flatBuffersObject.username
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let usernameOffset = builder.create(string: self.username)
        
        let start = TelegramCore_TelegramPeerUsername.startTelegramPeerUsername(&builder)
        TelegramCore_TelegramPeerUsername.add(flags: self.flags.rawValue, &builder)
        TelegramCore_TelegramPeerUsername.add(username: usernameOffset, &builder)
        return TelegramCore_TelegramPeerUsername.endTelegramPeerUsername(&builder, start: start)
    }
}

public struct PeerVerification: Codable, Equatable {
    public let botId: PeerId
    public let iconFileId: Int64
    public let description: String
    
    public init(
        botId: PeerId,
        iconFileId: Int64,
        description: String
    ) {
        self.botId = botId
        self.iconFileId = iconFileId
        self.description = description
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
    public let emojiStatus: PeerEmojiStatus?
    public let usernames: [TelegramPeerUsername]
    public let storiesHidden: Bool?
    public let nameColor: PeerNameColor?
    public let backgroundEmojiId: Int64?
    public let profileColor: PeerNameColor?
    public let profileBackgroundEmojiId: Int64?
    public let subscriberCount: Int32?
    public let verificationIconFileId: Int64?
    
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
        var addressNames = self.usernames.map { $0.username }
        if addressNames.isEmpty, let username = self.username, !username.isEmpty {
            addressNames = [username]
        }
        return .personName(first: self.firstName ?? "", last: self.lastName ?? "", addressNames: addressNames, phoneNumber: self.phone)
    }
    
    public var associatedMediaIds: [MediaId]? {
        var mediaIds: [MediaId] = []
        if let emojiStatus = self.emojiStatus {
            switch emojiStatus.content {
            case let .emoji(fileId):
                mediaIds.append(MediaId(namespace: Namespaces.Media.CloudFile, id: fileId))
            case let .starGift(_, fileId, _, _, patternFileId, _, _, _, _):
                mediaIds.append(MediaId(namespace: Namespaces.Media.CloudFile, id: fileId))
                mediaIds.append(MediaId(namespace: Namespaces.Media.CloudFile, id: patternFileId))
            }
        }
        if let backgroundEmojiId = self.backgroundEmojiId {
            mediaIds.append(MediaId(namespace: Namespaces.Media.CloudFile, id: backgroundEmojiId))
        }
        if let profileBackgroundEmojiId = self.profileBackgroundEmojiId {
            mediaIds.append(MediaId(namespace: Namespaces.Media.CloudFile, id: profileBackgroundEmojiId))
        }
        guard !mediaIds.isEmpty else {
            return nil
        }
        return mediaIds
    }
    
    public let associatedPeerId: PeerId? = nil
    public let notificationSettingsPeerId: PeerId? = nil
    
    public var timeoutAttribute: UInt32? {
        if let emojiStatus = self.emojiStatus {
            if let expirationDate = emojiStatus.expirationDate {
                return UInt32(max(0, expirationDate))
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    public init(
        id: PeerId,
        accessHash: TelegramPeerAccessHash?,
        firstName: String?,
        lastName: String?,
        username: String?,
        phone: String?,
        photo: [TelegramMediaImageRepresentation], 
        botInfo: BotUserInfo?,
        restrictionInfo: PeerAccessRestrictionInfo?,
        flags: UserInfoFlags,
        emojiStatus: PeerEmojiStatus?,
        usernames: [TelegramPeerUsername],
        storiesHidden: Bool?,
        nameColor: PeerNameColor?,
        backgroundEmojiId: Int64?,
        profileColor: PeerNameColor?,
        profileBackgroundEmojiId: Int64?,
        subscriberCount: Int32?,
        verificationIconFileId: Int64?
    ) {
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
        self.emojiStatus = emojiStatus
        self.usernames = usernames
        self.storiesHidden = storiesHidden
        self.nameColor = nameColor
        self.backgroundEmojiId = backgroundEmojiId
        self.profileColor = profileColor
        self.profileBackgroundEmojiId = profileBackgroundEmojiId
        self.subscriberCount = subscriberCount
        self.verificationIconFileId = verificationIconFileId
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
        
        self.emojiStatus = decoder.decode(PeerEmojiStatus.self, forKey: "emjs")
        
        self.usernames = decoder.decodeObjectArrayForKey("uns")
        self.storiesHidden = decoder.decodeOptionalBoolForKey("sth")
        
        self.nameColor = decoder.decodeOptionalInt32ForKey("nclr").flatMap { PeerNameColor(rawValue: $0) }
        self.backgroundEmojiId = decoder.decodeOptionalInt64ForKey("bgem")
        self.profileColor = decoder.decodeOptionalInt32ForKey("pclr").flatMap { PeerNameColor(rawValue: $0) }
        self.profileBackgroundEmojiId = decoder.decodeOptionalInt64ForKey("pgem")
        self.subscriberCount = decoder.decodeOptionalInt32ForKey("ssc")
        self.verificationIconFileId = decoder.decodeOptionalInt64ForKey("vfid")
        
        #if DEBUG
        var builder = FlatBufferBuilder(initialSize: 1024)
        let offset = self.encodeToFlatBuffers(builder: &builder)
        builder.finish(offset: offset)
        let serializedData = builder.data
        var byteBuffer = ByteBuffer(data: serializedData)
        let deserializedValue = FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_TelegramUser
        let parsedValue = try! TelegramUser(flatBuffersObject: deserializedValue)
        assert(self == parsedValue)
        #endif
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
        
        if let emojiStatus = self.emojiStatus {
            encoder.encode(emojiStatus, forKey: "emjs")
        } else {
            encoder.encodeNil(forKey: "emjs")
        }
        
        encoder.encodeObjectArray(self.usernames, forKey: "uns")
        
        if let storiesHidden = self.storiesHidden {
            encoder.encodeBool(storiesHidden, forKey: "sth")
        } else {
            encoder.encodeNil(forKey: "sth")
        }
        
        if let nameColor = self.nameColor {
            encoder.encodeInt32(nameColor.rawValue, forKey: "nclr")
        } else {
            encoder.encodeNil(forKey: "nclr")
        }
        
        if let backgroundEmojiId = self.backgroundEmojiId {
            encoder.encodeInt64(backgroundEmojiId, forKey: "bgem")
        } else {
            encoder.encodeNil(forKey: "bgem")
        }
        
        if let profileColor = self.profileColor {
            encoder.encodeInt32(profileColor.rawValue, forKey: "pclr")
        } else {
            encoder.encodeNil(forKey: "pclr")
        }
        
        if let profileBackgroundEmojiId = self.profileBackgroundEmojiId {
            encoder.encodeInt64(profileBackgroundEmojiId, forKey: "pgem")
        } else {
            encoder.encodeNil(forKey: "pgem")
        }
        
        if let subscriberCount = self.subscriberCount {
            encoder.encodeInt32(subscriberCount, forKey: "ssc")
        } else {
            encoder.encodeNil(forKey: "ssc")
        }
        
        if let verificationIconFileId = self.verificationIconFileId {
            encoder.encodeInt64(verificationIconFileId, forKey: "vfid")
        } else {
            encoder.encodeNil(forKey: "vfid")
        }
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
        if lhs.emojiStatus != rhs.emojiStatus {
            return false
        }
        if lhs.usernames != rhs.usernames {
            return false
        }
        if lhs.storiesHidden != rhs.storiesHidden {
            return false
        }
        if lhs.nameColor != rhs.nameColor {
            return false
        }
        if lhs.backgroundEmojiId != rhs.backgroundEmojiId {
            return false
        }
        if lhs.profileColor != rhs.profileColor {
            return false
        }
        if lhs.profileBackgroundEmojiId != rhs.profileBackgroundEmojiId {
            return false
        }
        if lhs.subscriberCount != rhs.subscriberCount {
            return false
        }
        if lhs.verificationIconFileId != rhs.verificationIconFileId {
            return false
        }
        return true
    }
    
    public func withUpdatedUsername(_ username: String?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: self.emojiStatus, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedUsernames(_ usernames: [TelegramPeerUsername]) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: self.emojiStatus, usernames: usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedNames(firstName: String?, lastName: String?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: firstName, lastName: lastName, username: self.username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: self.emojiStatus, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedPhone(_ phone: String?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: self.emojiStatus, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedPhoto(_ representations: [TelegramMediaImageRepresentation]) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: phone, photo: representations, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: self.emojiStatus, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedEmojiStatus(_ emojiStatus: PeerEmojiStatus?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: emojiStatus, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedFlags(_ flags: UserInfoFlags) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: flags, emojiStatus: self.emojiStatus, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedStoriesHidden(_ storiesHidden: Bool?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: self.emojiStatus, usernames: self.usernames, storiesHidden: storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedNameColor(_ nameColor: PeerNameColor) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: self.emojiStatus, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedBackgroundEmojiId(_ backgroundEmojiId: Int64?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: self.emojiStatus, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedProfileColor(_ profileColor: PeerNameColor?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: self.emojiStatus, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public func withUpdatedProfileBackgroundEmojiId(_ profileBackgroundEmojiId: Int64?) -> TelegramUser {
        return TelegramUser(id: self.id, accessHash: self.accessHash, firstName: self.firstName, lastName: self.lastName, username: self.username, phone: self.phone, photo: self.photo, botInfo: self.botInfo, restrictionInfo: self.restrictionInfo, flags: self.flags, emojiStatus: self.emojiStatus, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId, subscriberCount: self.subscriberCount, verificationIconFileId: self.verificationIconFileId)
    }
    
    public init(flatBuffersObject: TelegramCore_TelegramUser) throws {
        self.id = PeerId(flatBuffersObject.id)
        self.accessHash = try flatBuffersObject.accessHash.flatMap(TelegramPeerAccessHash.init)
        self.firstName = flatBuffersObject.firstName
        self.lastName = flatBuffersObject.lastName
        self.username = flatBuffersObject.username
        self.phone = flatBuffersObject.phone
        self.photo = try (0 ..< flatBuffersObject.photoCount).map { try TelegramMediaImageRepresentation(flatBuffersObject: flatBuffersObject.photo(at: $0)!) }
        self.botInfo = try flatBuffersObject.botInfo.flatMap { try BotUserInfo(flatBuffersObject: $0) }
        self.restrictionInfo = try flatBuffersObject.restrictionInfo.flatMap { try PeerAccessRestrictionInfo(flatBuffersObject: $0) }
        self.flags = UserInfoFlags(rawValue: flatBuffersObject.flags)
        self.emojiStatus = try flatBuffersObject.emojiStatus.flatMap { try PeerEmojiStatus(flatBuffersObject: $0) }
        self.usernames = try (0 ..< flatBuffersObject.usernamesCount).map { try TelegramPeerUsername(flatBuffersObject: flatBuffersObject.usernames(at: $0)!) }
        self.storiesHidden = flatBuffersObject.storiesHidden?.value
        self.nameColor = try flatBuffersObject.nameColor.flatMap(PeerNameColor.init)
        self.backgroundEmojiId = flatBuffersObject.backgroundEmojiId == Int64.min ? nil : flatBuffersObject.backgroundEmojiId
        self.profileColor = try flatBuffersObject.profileColor.flatMap(PeerNameColor.init)
        self.profileBackgroundEmojiId = flatBuffersObject.profileBackgroundEmojiId == Int64.min ? nil : flatBuffersObject.profileBackgroundEmojiId
        self.subscriberCount = flatBuffersObject.subscriberCount == Int32.min ? nil : flatBuffersObject.subscriberCount
        self.verificationIconFileId = flatBuffersObject.verificationIconFileId == Int64.min ? nil : flatBuffersObject.verificationIconFileId
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let accessHashOffset = self.accessHash.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
        
        let firstNameOffset = self.firstName.map { builder.create(string: $0) }
        let lastNameOffset = self.lastName.map { builder.create(string: $0) }
        let usernameOffset = self.username.map { builder.create(string: $0) }
        let phoneOffset = self.phone.map { builder.create(string: $0) }
        
        let photoOffsets = self.photo.map { $0.encodeToFlatBuffers(builder: &builder) }
        let photoOffset = builder.createVector(ofOffsets: photoOffsets, len: photoOffsets.count)
        
        let botInfoOffset = self.botInfo?.encodeToFlatBuffers(builder: &builder)
        let restrictionInfoOffset = self.restrictionInfo?.encodeToFlatBuffers(builder: &builder)
        
        let usernamesOffsets = self.usernames.map { $0.encodeToFlatBuffers(builder: &builder) }
        let usernamesOffset = builder.createVector(ofOffsets: usernamesOffsets, len: usernamesOffsets.count)
        
        let nameColorOffset = self.nameColor.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
        let profileColorOffset = self.profileColor.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
        let emojiStatusOffset = self.emojiStatus?.encodeToFlatBuffers(builder: &builder)
        
        let start = TelegramCore_TelegramUser.startTelegramUser(&builder)
        
        TelegramCore_TelegramUser.add(id: self.id.asFlatBuffersObject(), &builder)
        if let accessHashOffset {
            TelegramCore_TelegramUser.add(accessHash: accessHashOffset, &builder)
        }
        if let firstNameOffset {
            TelegramCore_TelegramUser.add(firstName: firstNameOffset, &builder)
        }
        if let lastNameOffset {
            TelegramCore_TelegramUser.add(lastName: lastNameOffset, &builder)
        }
        if let usernameOffset {
            TelegramCore_TelegramUser.add(username: usernameOffset, &builder)
        }
        if let phoneOffset {
            TelegramCore_TelegramUser.add(phone: phoneOffset, &builder)
        }
        TelegramCore_TelegramUser.addVectorOf(photo: photoOffset, &builder)
        if let botInfoOffset {
            TelegramCore_TelegramUser.add(botInfo: botInfoOffset, &builder)
        }
        if let restrictionInfoOffset {
            TelegramCore_TelegramUser.add(restrictionInfo: restrictionInfoOffset, &builder)
        }
        TelegramCore_TelegramUser.add(flags: self.flags.rawValue, &builder)
        if let emojiStatusOffset {
            TelegramCore_TelegramUser.add(emojiStatus: emojiStatusOffset, &builder)
        }
        TelegramCore_TelegramUser.addVectorOf(usernames: usernamesOffset, &builder)
        
        if let storiesHidden = self.storiesHidden {
            TelegramCore_TelegramUser.add(storiesHidden: TelegramCore_OptionalBool(value: storiesHidden), &builder)
        }
        if let nameColorOffset {
            TelegramCore_TelegramUser.add(nameColor: nameColorOffset, &builder)
        }
        TelegramCore_TelegramUser.add(backgroundEmojiId: self.backgroundEmojiId ?? Int64.min, &builder)
        if let profileColorOffset {
            TelegramCore_TelegramUser.add(profileColor: profileColorOffset, &builder)
        }
        TelegramCore_TelegramUser.add(profileBackgroundEmojiId: self.profileBackgroundEmojiId ?? Int64.min, &builder)
        TelegramCore_TelegramUser.add(subscriberCount: self.subscriberCount ?? Int32.min, &builder)
        TelegramCore_TelegramUser.add(verificationIconFileId: self.verificationIconFileId ?? Int64.min, &builder)
        
        return TelegramCore_TelegramUser.endTelegramUser(&builder, start: start)
    }
}
