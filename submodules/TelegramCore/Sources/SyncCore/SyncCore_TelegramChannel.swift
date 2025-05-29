import Postbox
import FlatBuffers
import FlatSerialization

public enum TelegramChannelParticipationStatus: Int32 {
    case member = 0
    case left = 1
    case kicked = 2
    
    public init(rawValue: Int32) {
        switch rawValue {
        case 0:
            self = .member
        case 1:
            self = .left
        case 2:
            self = .kicked
        default:
            self = .left
        }
    }
}

public struct TelegramChannelBroadcastFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let messagesShouldHaveSignatures = TelegramChannelBroadcastFlags(rawValue: 1 << 0)
    public static let hasDiscussionGroup = TelegramChannelBroadcastFlags(rawValue: 1 << 1)
    public static let messagesShouldHaveProfiles = TelegramChannelBroadcastFlags(rawValue: 1 << 2)
    public static let hasMonoforum = TelegramChannelBroadcastFlags(rawValue: 1 << 3)
}

public struct TelegramChannelBroadcastInfo: Equatable {
    public let flags: TelegramChannelBroadcastFlags
    
    public init(flags: TelegramChannelBroadcastFlags) {
        self.flags = flags
    }
    
    public static func ==(lhs: TelegramChannelBroadcastInfo, rhs: TelegramChannelBroadcastInfo) -> Bool {
        return lhs.flags == rhs.flags
    }
}

public struct TelegramChannelGroupFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    public static let slowModeEnabled = TelegramChannelGroupFlags(rawValue: 1 << 0)
}

public struct TelegramChannelGroupInfo: Equatable {
    public let flags: TelegramChannelGroupFlags
    
    public init(flags: TelegramChannelGroupFlags) {
        self.flags = flags
    }

    public static func ==(lhs: TelegramChannelGroupInfo, rhs: TelegramChannelGroupInfo) -> Bool {
        return lhs.flags == rhs.flags
    }
}

public enum TelegramChannelInfo: Equatable {
    case broadcast(TelegramChannelBroadcastInfo)
    case group(TelegramChannelGroupInfo)
    
    public static func ==(lhs: TelegramChannelInfo, rhs: TelegramChannelInfo) -> Bool {
        switch lhs {
            case let .broadcast(lhsInfo):
                switch rhs {
                    case .broadcast(lhsInfo):
                        return true
                    default:
                        return false
                }
            case let .group(lhsInfo):
                switch rhs {
                    case .group(lhsInfo):
                        return true
                    default:
                        return false
                }
        }
    }
    
    fileprivate func encode(encoder: PostboxEncoder) {
        switch self {
            case let .broadcast(info):
                encoder.encodeInt32(0, forKey: "i.t")
                encoder.encodeInt32(info.flags.rawValue, forKey: "i.f")
            case let .group(info):
                encoder.encodeInt32(1, forKey: "i.t")
                encoder.encodeInt32(info.flags.rawValue, forKey: "i.f")
        }
    }
    
    fileprivate static func decode(decoder: PostboxDecoder) -> TelegramChannelInfo {
        let type: Int32 = decoder.decodeInt32ForKey("i.t", orElse: 0)
        if type == 0 {
            return .broadcast(TelegramChannelBroadcastInfo(flags: TelegramChannelBroadcastFlags(rawValue: decoder.decodeInt32ForKey("i.f", orElse: 0))))
        } else {
            return .group(TelegramChannelGroupInfo(flags: TelegramChannelGroupFlags(rawValue: decoder.decodeInt32ForKey("i.f", orElse: 0))))
        }
    }
    
    public init(flatBuffersObject: TelegramCore_TelegramChannelInfo) throws {
        switch flatBuffersObject.valueType {
        case .telegramchannelinfoBroadcast:
            guard let value = flatBuffersObject.value(type: TelegramCore_TelegramChannelInfo_Broadcast.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .broadcast(TelegramChannelBroadcastInfo(flags: TelegramChannelBroadcastFlags(rawValue: value.flags)))
        case .telegramchannelinfoGroup:
            guard let value = flatBuffersObject.value(type: TelegramCore_TelegramChannelInfo_Group.self) else {
                throw FlatBuffersError.missingRequiredField()
            }
            self = .group(TelegramChannelGroupInfo(flags: TelegramChannelGroupFlags(rawValue: value.flags)))
        case .none_:
            throw FlatBuffersError.missingRequiredField()
        }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let valueType: TelegramCore_TelegramChannelInfo_Value
        let valueOffset: Offset
        
        switch self {
        case let .broadcast(info):
            valueType = .telegramchannelinfoBroadcast
            let start = TelegramCore_TelegramChannelInfo_Broadcast.startTelegramChannelInfo_Broadcast(&builder)
            TelegramCore_TelegramChannelInfo_Broadcast.add(flags: info.flags.rawValue, &builder)
            valueOffset = TelegramCore_TelegramChannelInfo_Broadcast.endTelegramChannelInfo_Broadcast(&builder, start: start)
        case let .group(info):
            valueType = .telegramchannelinfoGroup
            let start = TelegramCore_TelegramChannelInfo_Group.startTelegramChannelInfo_Group(&builder)
            TelegramCore_TelegramChannelInfo_Group.add(flags: info.flags.rawValue, &builder)
            valueOffset = TelegramCore_TelegramChannelInfo_Group.endTelegramChannelInfo_Group(&builder, start: start)
        }
        
        let start = TelegramCore_TelegramChannelInfo.startTelegramChannelInfo(&builder)
        TelegramCore_TelegramChannelInfo.add(valueType: valueType, &builder)
        TelegramCore_TelegramChannelInfo.add(value: valueOffset, &builder)
        return TelegramCore_TelegramChannelInfo.endTelegramChannelInfo(&builder, start: start)
    }
}

public struct TelegramChannelFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let isVerified = TelegramChannelFlags(rawValue: 1 << 0)
    public static let isCreator = TelegramChannelFlags(rawValue: 1 << 1)
    public static let isScam = TelegramChannelFlags(rawValue: 1 << 2)
    public static let hasGeo = TelegramChannelFlags(rawValue: 1 << 3)
    public static let hasVoiceChat = TelegramChannelFlags(rawValue: 1 << 4)
    public static let hasActiveVoiceChat = TelegramChannelFlags(rawValue: 1 << 5)
    public static let isFake = TelegramChannelFlags(rawValue: 1 << 6)
    public static let isGigagroup = TelegramChannelFlags(rawValue: 1 << 7)
    public static let copyProtectionEnabled = TelegramChannelFlags(rawValue: 1 << 8)
    public static let joinToSend = TelegramChannelFlags(rawValue: 1 << 9)
    public static let requestToJoin = TelegramChannelFlags(rawValue: 1 << 10)
    public static let isForum = TelegramChannelFlags(rawValue: 1 << 11)
    public static let autoTranslateEnabled = TelegramChannelFlags(rawValue: 1 << 12)
    public static let isMonoforum = TelegramChannelFlags(rawValue: 1 << 13)
    public static let displayForumAsTabs = TelegramChannelFlags(rawValue: 1 << 14)
}

public final class TelegramChannel: Peer, Equatable {
    public let id: PeerId
    public let accessHash: TelegramPeerAccessHash?
    public let title: String
    public let username: String?
    public let photo: [TelegramMediaImageRepresentation]
    public let creationDate: Int32
    public let version: Int32
    public let participationStatus: TelegramChannelParticipationStatus
    public let info: TelegramChannelInfo
    public let flags: TelegramChannelFlags
    public let restrictionInfo: PeerAccessRestrictionInfo?
    public let adminRights: TelegramChatAdminRights?
    public let bannedRights: TelegramChatBannedRights?
    public let defaultBannedRights: TelegramChatBannedRights?
    public let usernames: [TelegramPeerUsername]
    public let storiesHidden: Bool?
    public let nameColor: PeerNameColor?
    public let backgroundEmojiId: Int64?
    public let profileColor: PeerNameColor?
    public let profileBackgroundEmojiId: Int64?
    public let emojiStatus: PeerEmojiStatus?
    public let approximateBoostLevel: Int32?
    public let subscriptionUntilDate: Int32?
    public let verificationIconFileId: Int64?
    public let sendPaidMessageStars: StarsAmount?
    public let linkedMonoforumId: PeerId?
    
    public var associatedPeerId: PeerId? {
        if self.flags.contains(.isMonoforum) {
            return self.linkedMonoforumId
        } else {
            return nil
        }
    }
    
    public var additionalAssociatedPeerId: PeerId? {
        self.linkedMonoforumId
    }
    
    public var indexName: PeerIndexNameRepresentation {
        var addressNames = self.usernames.map { $0.username }
        if addressNames.isEmpty, let username = self.username, !username.isEmpty {
            addressNames = [username]
        }
        return .title(title: self.title, addressNames: addressNames)
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
        title: String,
        username: String?,
        photo: [TelegramMediaImageRepresentation],
        creationDate: Int32,
        version: Int32,
        participationStatus: TelegramChannelParticipationStatus,
        info: TelegramChannelInfo,
        flags: TelegramChannelFlags,
        restrictionInfo: PeerAccessRestrictionInfo?,
        adminRights: TelegramChatAdminRights?,
        bannedRights: TelegramChatBannedRights?,
        defaultBannedRights: TelegramChatBannedRights?,
        usernames: [TelegramPeerUsername],
        storiesHidden: Bool?,
        nameColor: PeerNameColor?,
        backgroundEmojiId: Int64?,
        profileColor: PeerNameColor?,
        profileBackgroundEmojiId: Int64?,
        emojiStatus: PeerEmojiStatus?,
        approximateBoostLevel: Int32?,
        subscriptionUntilDate: Int32?,
        verificationIconFileId: Int64?,
        sendPaidMessageStars: StarsAmount?,
        linkedMonoforumId: PeerId?
    ) {
        self.id = id
        self.accessHash = accessHash
        self.title = title
        self.username = username
        self.photo = photo
        self.creationDate = creationDate
        self.version = version
        self.participationStatus = participationStatus
        self.info = info
        self.flags = flags
        self.restrictionInfo = restrictionInfo
        self.adminRights = adminRights
        self.bannedRights = bannedRights
        self.defaultBannedRights = defaultBannedRights
        self.usernames = usernames
        self.storiesHidden = storiesHidden
        self.nameColor = nameColor
        self.backgroundEmojiId = backgroundEmojiId
        self.profileColor = profileColor
        self.profileBackgroundEmojiId = profileBackgroundEmojiId
        self.emojiStatus = emojiStatus
        self.approximateBoostLevel = approximateBoostLevel
        self.subscriptionUntilDate = subscriptionUntilDate
        self.verificationIconFileId = verificationIconFileId
        self.sendPaidMessageStars = sendPaidMessageStars
        self.linkedMonoforumId = linkedMonoforumId
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i", orElse: 0))
        let accessHash = decoder.decodeOptionalInt64ForKey("ah")
        let accessHashType: Int32 = decoder.decodeInt32ForKey("aht", orElse: 0)
        if let accessHash = accessHash {
            if accessHashType == 0 {
                self.accessHash = .personal(accessHash)
            } else {
                self.accessHash = .genericPublic(accessHash)
            }
        } else {
            self.accessHash = nil
        }
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.username = decoder.decodeOptionalStringForKey("un")
        self.photo = decoder.decodeObjectArrayForKey("ph")
        self.creationDate = decoder.decodeInt32ForKey("d", orElse: 0)
        self.version = decoder.decodeInt32ForKey("v", orElse: 0)
        self.participationStatus = TelegramChannelParticipationStatus(rawValue: decoder.decodeInt32ForKey("ps", orElse: 0))
        self.info = TelegramChannelInfo.decode(decoder: decoder)
        self.flags = TelegramChannelFlags(rawValue: decoder.decodeInt32ForKey("fl", orElse: 0))
        self.restrictionInfo = decoder.decodeObjectForKey("ri") as? PeerAccessRestrictionInfo
        self.adminRights = decoder.decodeObjectForKey("ar", decoder: { TelegramChatAdminRights(decoder: $0) }) as? TelegramChatAdminRights
        self.bannedRights = decoder.decodeObjectForKey("br", decoder: { TelegramChatBannedRights(decoder: $0) }) as? TelegramChatBannedRights
        self.defaultBannedRights = decoder.decodeObjectForKey("dbr", decoder: { TelegramChatBannedRights(decoder: $0) }) as? TelegramChatBannedRights
        self.usernames = decoder.decodeObjectArrayForKey("uns")
        self.storiesHidden = decoder.decodeOptionalBoolForKey("sth")
        self.nameColor = decoder.decodeOptionalInt32ForKey("nclr").flatMap { PeerNameColor(rawValue: $0) }
        self.backgroundEmojiId = decoder.decodeOptionalInt64ForKey("bgem")
        self.profileColor = decoder.decodeOptionalInt32ForKey("pclr").flatMap { PeerNameColor(rawValue: $0) }
        self.profileBackgroundEmojiId = decoder.decodeOptionalInt64ForKey("pgem")
        self.emojiStatus = decoder.decode(PeerEmojiStatus.self, forKey: "emjs")
        self.approximateBoostLevel = decoder.decodeOptionalInt32ForKey("abl")
        self.subscriptionUntilDate = decoder.decodeOptionalInt32ForKey("sud")
        self.verificationIconFileId = decoder.decodeOptionalInt64ForKey("vfid")
        self.sendPaidMessageStars = decoder.decodeCodable(StarsAmount.self, forKey: "sendPaidMessageStars")
        self.linkedMonoforumId = decoder.decodeOptionalInt64ForKey("lmid").flatMap(PeerId.init)
        
        #if DEBUG && false
        var builder = FlatBufferBuilder(initialSize: 1024)
        let offset = self.encodeToFlatBuffers(builder: &builder)
        builder.finish(offset: offset)
        let serializedData = builder.data
        var byteBuffer = ByteBuffer(data: serializedData)
        let deserializedValue = FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_TelegramChannel
        let parsedValue = try! TelegramChannel(flatBuffersObject: deserializedValue)
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
        } else {
            encoder.encodeNil(forKey: "ah")
        }
        encoder.encodeString(self.title, forKey: "t")
        if let username = self.username {
            encoder.encodeString(username, forKey: "un")
        } else {
            encoder.encodeNil(forKey: "un")
        }
        encoder.encodeObjectArray(self.photo, forKey: "ph")
        encoder.encodeInt32(self.creationDate, forKey: "d")
        encoder.encodeInt32(self.version, forKey: "v")
        encoder.encodeInt32(self.participationStatus.rawValue, forKey: "ps")
        self.info.encode(encoder: encoder)
        encoder.encodeInt32(self.flags.rawValue, forKey: "fl")
        if let restrictionInfo = self.restrictionInfo {
            encoder.encodeObject(restrictionInfo, forKey: "ri")
        } else {
            encoder.encodeNil(forKey: "ri")
        }
        if let adminRights = self.adminRights {
            encoder.encodeObject(adminRights, forKey: "ar")
        } else {
            encoder.encodeNil(forKey: "ar")
        }
        if let bannedRights = self.bannedRights {
            encoder.encodeObject(bannedRights, forKey: "br")
        } else {
            encoder.encodeNil(forKey: "br")
        }
        if let defaultBannedRights = self.defaultBannedRights {
            encoder.encodeObject(defaultBannedRights, forKey: "dbr")
        } else {
            encoder.encodeNil(forKey: "dbr")
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
        
        if let emojiStatus = self.emojiStatus {
            encoder.encode(emojiStatus, forKey: "emjs")
        } else {
            encoder.encodeNil(forKey: "emjs")
        }
        
        if let approximateBoostLevel = self.approximateBoostLevel {
            encoder.encodeInt32(approximateBoostLevel, forKey: "abl")
        } else {
            encoder.encodeNil(forKey: "abl")
        }
        
        if let subscriptionUntilDate = self.subscriptionUntilDate {
            encoder.encodeInt32(subscriptionUntilDate, forKey: "sud")
        } else {
            encoder.encodeNil(forKey: "sud")
        }
        
        if let verificationIconFileId = self.verificationIconFileId {
            encoder.encodeInt64(verificationIconFileId, forKey: "vfid")
        } else {
            encoder.encodeNil(forKey: "vfid")
        }
        
        if let sendPaidMessageStars = self.sendPaidMessageStars {
            encoder.encodeCodable(sendPaidMessageStars, forKey: "sendPaidMessageStars")
        } else {
            encoder.encodeNil(forKey: "sendPaidMessageStars")
        }
        
        if let linkedMonoforumId = self.linkedMonoforumId {
            encoder.encodeInt64(linkedMonoforumId.toInt64(), forKey: "lmid")
        } else {
            encoder.encodeNil(forKey: "lmid")
        }
    }
    
    public func isEqual(_ other: Peer) -> Bool {
        guard let other = other as? TelegramChannel else {
            return false
        }
        
        return self == other
    }

    public static func ==(lhs: TelegramChannel, rhs: TelegramChannel) -> Bool {
        if lhs.id != rhs.id || lhs.accessHash != rhs.accessHash || lhs.title != rhs.title || lhs.username != rhs.username || lhs.photo != rhs.photo {
            return false
        }

        if lhs.creationDate != rhs.creationDate || lhs.version != rhs.version || lhs.participationStatus != rhs.participationStatus {
            return false
        }

        if lhs.info != rhs.info || lhs.flags != rhs.flags || lhs.restrictionInfo != rhs.restrictionInfo {
            return false
        }

        if lhs.adminRights != rhs.adminRights {
            return false
        }

        if lhs.bannedRights != rhs.bannedRights {
            return false
        }

        if lhs.defaultBannedRights != rhs.defaultBannedRights {
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
        if lhs.emojiStatus != rhs.emojiStatus {
            return false
        }
        if lhs.approximateBoostLevel != rhs.approximateBoostLevel {
            return false
        }
        if lhs.subscriptionUntilDate != rhs.subscriptionUntilDate {
            return false
        }
        if lhs.verificationIconFileId != rhs.verificationIconFileId {
            return false
        }
        if lhs.sendPaidMessageStars != rhs.sendPaidMessageStars {
            return false
        }
        if lhs.linkedMonoforumId != rhs.linkedMonoforumId {
            return false
        }
        return true
    }
    
    public func withUpdatedAddressName(_ addressName: String?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: addressName, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedAddressNames(_ addressNames: [TelegramPeerUsername]) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: addressNames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedDefaultBannedRights(_ defaultBannedRights: TelegramChatBannedRights?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedFlags(_ flags: TelegramChannelFlags) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedInfo(_ info: TelegramChannelInfo) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedSendPaidMessageStars(_ sendPaidMessageStars: StarsAmount?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedStoriesHidden(_ storiesHidden: Bool?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedNameColor(_ nameColor: PeerNameColor?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedBackgroundEmojiId(_ backgroundEmojiId: Int64?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedProfileColor(_ profileColor: PeerNameColor?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedProfileBackgroundEmojiId(_ profileBackgroundEmojiId: Int64?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedEmojiStatus(_ emojiStatus: PeerEmojiStatus?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedApproximateBoostLevel(_ approximateBoostLevel: Int32?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedSubscriptionUntilDate(_ subscriptionUntilDate: Int32?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: subscriptionUntilDate, verificationIconFileId: self.verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public func withUpdatedVerificationIconFileId(_ verificationIconFileId: Int64?) -> TelegramChannel {
        return TelegramChannel(id: self.id, accessHash: self.accessHash, title: self.title, username: self.username, photo: self.photo, creationDate: self.creationDate, version: self.version, participationStatus: self.participationStatus, info: self.info, flags: self.flags, restrictionInfo: self.restrictionInfo, adminRights: self.adminRights, bannedRights: self.bannedRights, defaultBannedRights: self.defaultBannedRights, usernames: self.usernames, storiesHidden: self.storiesHidden, nameColor: self.nameColor, backgroundEmojiId: self.backgroundEmojiId, profileColor: self.profileColor, profileBackgroundEmojiId: self.profileBackgroundEmojiId, emojiStatus: self.emojiStatus, approximateBoostLevel: self.approximateBoostLevel, subscriptionUntilDate: self.subscriptionUntilDate, verificationIconFileId: verificationIconFileId, sendPaidMessageStars: self.sendPaidMessageStars, linkedMonoforumId: self.linkedMonoforumId)
    }
    
    public init(flatBuffersObject: TelegramCore_TelegramChannel) throws {
        self.id = PeerId(flatBuffersObject: flatBuffersObject.id)
        self.accessHash = try flatBuffersObject.accessHash.flatMap(TelegramPeerAccessHash.init)
        self.title = flatBuffersObject.title
        self.username = flatBuffersObject.username
        self.photo = try (0 ..< flatBuffersObject.photoCount).map { try TelegramMediaImageRepresentation(flatBuffersObject: flatBuffersObject.photo(at: $0)!) }
        self.creationDate = flatBuffersObject.creationDate
        self.version = flatBuffersObject.version
        self.participationStatus = TelegramChannelParticipationStatus(rawValue: flatBuffersObject.participationStatus)
        
        guard let infoObj = flatBuffersObject.info else {
            throw FlatBuffersError.missingRequiredField()
        }
        self.info = try TelegramChannelInfo(flatBuffersObject: infoObj)
        
        self.flags = TelegramChannelFlags(rawValue: flatBuffersObject.flags)
        self.restrictionInfo = try flatBuffersObject.restrictionInfo.flatMap { try PeerAccessRestrictionInfo(flatBuffersObject: $0) }
        self.adminRights = try flatBuffersObject.adminRights.flatMap { try TelegramChatAdminRights(flatBuffersObject: $0) }
        self.bannedRights = try flatBuffersObject.bannedRights.flatMap { try TelegramChatBannedRights(flatBuffersObject: $0) }
        self.defaultBannedRights = try flatBuffersObject.defaultBannedRights.map { try TelegramChatBannedRights(flatBuffersObject: $0) }
        self.usernames = try (0 ..< flatBuffersObject.usernamesCount).map { try TelegramPeerUsername(flatBuffersObject: flatBuffersObject.usernames(at: $0)!) }
        self.storiesHidden = flatBuffersObject.storiesHidden?.value
        self.nameColor = try flatBuffersObject.nameColor.flatMap(PeerNameColor.init(flatBuffersObject:))
        self.backgroundEmojiId = flatBuffersObject.backgroundEmojiId == Int64.min ? nil : flatBuffersObject.backgroundEmojiId
        self.profileColor = try flatBuffersObject.profileColor.flatMap(PeerNameColor.init)
        self.profileBackgroundEmojiId = flatBuffersObject.profileBackgroundEmojiId == Int64.min ? nil : flatBuffersObject.profileBackgroundEmojiId
        self.emojiStatus = try flatBuffersObject.emojiStatus.flatMap { try PeerEmojiStatus(flatBuffersObject: $0) }
        self.approximateBoostLevel = flatBuffersObject.approximateBoostLevel == Int32.min ? nil : flatBuffersObject.approximateBoostLevel
        self.subscriptionUntilDate = flatBuffersObject.subscriptionUntilDate == Int32.min ? nil : flatBuffersObject.subscriptionUntilDate
        self.verificationIconFileId = flatBuffersObject.verificationIconFileId == Int64.min ? nil : flatBuffersObject.verificationIconFileId
        self.sendPaidMessageStars = try flatBuffersObject.sendPaidMessageStars.flatMap { try StarsAmount(flatBuffersObject: $0) }
        self.linkedMonoforumId = flatBuffersObject.linkedMonoforumId.flatMap { PeerId(flatBuffersObject: $0) }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let accessHashOffset = self.accessHash.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
        
        let photoOffsets = self.photo.map { $0.encodeToFlatBuffers(builder: &builder) }
        let photoOffset = builder.createVector(ofOffsets: photoOffsets, len: photoOffsets.count)
        
        let usernamesOffsets = self.usernames.map { $0.encodeToFlatBuffers(builder: &builder) }
        let usernamesOffset = builder.createVector(ofOffsets: usernamesOffsets, len: usernamesOffsets.count)
        
        let titleOffset = builder.create(string: self.title)
        let usernameOffset = self.username.map { builder.create(string: $0) }
        let nameColorOffset = self.nameColor.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
        let profileColorOffset = self.profileColor.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
        
        let infoOffset = self.info.encodeToFlatBuffers(builder: &builder)
        
        let restrictionInfoOffset = self.restrictionInfo?.encodeToFlatBuffers(builder: &builder)
        let adminRightsOffset = self.adminRights?.encodeToFlatBuffers(builder: &builder)
        let bannedRightsOffset = self.bannedRights?.encodeToFlatBuffers(builder: &builder)
        let defaultBannedRightsOffset = self.defaultBannedRights?.encodeToFlatBuffers(builder: &builder)
        let emojiStatusOffset = self.emojiStatus?.encodeToFlatBuffers(builder: &builder)
        let sendPaidMessageStarsOffset = self.sendPaidMessageStars?.encodeToFlatBuffers(builder: &builder)
        
        let start = TelegramCore_TelegramChannel.startTelegramChannel(&builder)
        
        TelegramCore_TelegramChannel.add(id: self.id.asFlatBuffersObject(), &builder)
        if let accessHashOffset {
            TelegramCore_TelegramChannel.add(accessHash: accessHashOffset, &builder)
        }
        TelegramCore_TelegramChannel.add(title: titleOffset, &builder)
        if let usernameOffset {
            TelegramCore_TelegramChannel.add(username: usernameOffset, &builder)
        }
        TelegramCore_TelegramChannel.addVectorOf(photo: photoOffset, &builder)
        TelegramCore_TelegramChannel.add(creationDate: self.creationDate, &builder)
        TelegramCore_TelegramChannel.add(version: self.version, &builder)
        TelegramCore_TelegramChannel.add(participationStatus: self.participationStatus.rawValue, &builder)
        TelegramCore_TelegramChannel.add(info: infoOffset, &builder)
        TelegramCore_TelegramChannel.add(flags: self.flags.rawValue, &builder)
        
        if let restrictionInfoOffset {
            TelegramCore_TelegramChannel.add(restrictionInfo: restrictionInfoOffset, &builder)
        }
        if let adminRightsOffset {
            TelegramCore_TelegramChannel.add(adminRights: adminRightsOffset, &builder)
        }
        if let bannedRightsOffset {
            TelegramCore_TelegramChannel.add(bannedRights: bannedRightsOffset, &builder)
        }
        if let defaultBannedRightsOffset {
            TelegramCore_TelegramChannel.add(defaultBannedRights: defaultBannedRightsOffset, &builder)
        }
        
        TelegramCore_TelegramChannel.addVectorOf(usernames: usernamesOffset, &builder)
        
        if let storiesHidden = self.storiesHidden {
            TelegramCore_TelegramChannel.add(storiesHidden: TelegramCore_OptionalBool(value: storiesHidden), &builder)
        }
        if let nameColorOffset {
            TelegramCore_TelegramChannel.add(nameColor: nameColorOffset, &builder)
        }
        TelegramCore_TelegramChannel.add(backgroundEmojiId: self.backgroundEmojiId ?? Int64.min, &builder)
        if let profileColorOffset {
            TelegramCore_TelegramChannel.add(profileColor: profileColorOffset, &builder)
        }
        TelegramCore_TelegramChannel.add(profileBackgroundEmojiId: self.profileBackgroundEmojiId ?? Int64.min, &builder)
        if let emojiStatusOffset {
            TelegramCore_TelegramChannel.add(emojiStatus: emojiStatusOffset, &builder)
        }
        TelegramCore_TelegramChannel.add(approximateBoostLevel: self.approximateBoostLevel ?? Int32.min, &builder)
        TelegramCore_TelegramChannel.add(subscriptionUntilDate: self.subscriptionUntilDate ?? Int32.min, &builder)
        TelegramCore_TelegramChannel.add(verificationIconFileId: self.verificationIconFileId ?? Int64.min, &builder)
        if let sendPaidMessageStarsOffset {
            TelegramCore_TelegramChannel.add(sendPaidMessageStars: sendPaidMessageStarsOffset, &builder)
        }
        if let linkedMonoforumId = self.linkedMonoforumId {
            TelegramCore_TelegramChannel.add(linkedMonoforumId: linkedMonoforumId.asFlatBuffersObject(), &builder)
        }
        
        return TelegramCore_TelegramChannel.endTelegramChannel(&builder, start: start)
    }
}
