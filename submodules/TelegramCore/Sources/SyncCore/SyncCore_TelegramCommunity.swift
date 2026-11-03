import Postbox
import FlatBuffers
import FlatSerialization

public enum TelegramCommunityParticipationStatus: Int32 {
    case member
    case left
    case kicked
}

public struct TelegramCommunityFlags: OptionSet {
    public var rawValue: Int32

    public init() {
        self.rawValue = 0
    }

    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    public static let isCreator = TelegramCommunityFlags(rawValue: 1 << 0)
    public static let isMin = TelegramCommunityFlags(rawValue: 1 << 1)
}

public enum TelegramCommunityPermission {
    case changeInfo
    case banUsers
    case manageLinkedPeers
    case addAdmins
}

public final class TelegramCommunity: Peer, Equatable {
    public let id: PeerId
    public let accessHash: TelegramPeerAccessHash?
    public let title: String
    public let photo: [TelegramMediaImageRepresentation]
    public let creationDate: Int32
    public let participationStatus: TelegramCommunityParticipationStatus
    public let flags: TelegramCommunityFlags
    public let collapsedInDialogs: Bool?
    public let adminRights: TelegramChatAdminRights?
    public let defaultBannedRights: TelegramChatBannedRights?

    public var indexName: PeerIndexNameRepresentation {
        return .title(title: self.title, addressNames: [])
    }

    public let associatedPeerId: PeerId? = nil
    public let notificationSettingsPeerId: PeerId? = nil
    public let associatedMediaIds: [MediaId]? = nil
    public let timeoutAttribute: UInt32? = nil

    public init(
        id: PeerId,
        accessHash: TelegramPeerAccessHash?,
        title: String,
        photo: [TelegramMediaImageRepresentation],
        creationDate: Int32,
        participationStatus: TelegramCommunityParticipationStatus,
        flags: TelegramCommunityFlags,
        collapsedInDialogs: Bool?,
        adminRights: TelegramChatAdminRights?,
        defaultBannedRights: TelegramChatBannedRights?
    ) {
        self.id = id
        self.accessHash = accessHash
        self.title = title
        self.photo = photo
        self.creationDate = creationDate
        self.participationStatus = participationStatus
        self.flags = flags
        self.collapsedInDialogs = collapsedInDialogs
        self.adminRights = adminRights
        self.defaultBannedRights = defaultBannedRights
    }

    public init(decoder: PostboxDecoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i", orElse: 0))
        let accessHash = decoder.decodeOptionalInt64ForKey("ah")
        let accessHashType = decoder.decodeInt32ForKey("aht", orElse: 0)
        if let accessHash {
            if accessHashType == 0 {
                self.accessHash = .personal(accessHash)
            } else {
                self.accessHash = .genericPublic(accessHash)
            }
        } else {
            self.accessHash = nil
        }
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.photo = decoder.decodeObjectArrayForKey("ph")
        self.creationDate = decoder.decodeInt32ForKey("d", orElse: 0)
        self.participationStatus = TelegramCommunityParticipationStatus(rawValue: decoder.decodeInt32ForKey("ps", orElse: 0)) ?? .member
        self.flags = TelegramCommunityFlags(rawValue: decoder.decodeInt32ForKey("fl", orElse: 0))
        self.collapsedInDialogs = decoder.decodeOptionalBoolForKey("cid")
        self.adminRights = decoder.decodeObjectForKey("ar", decoder: { TelegramChatAdminRights(decoder: $0) }) as? TelegramChatAdminRights
        self.defaultBannedRights = decoder.decodeObjectForKey("dbr", decoder: { TelegramChatBannedRights(decoder: $0) }) as? TelegramChatBannedRights
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
        encoder.encodeObjectArray(self.photo, forKey: "ph")
        encoder.encodeInt32(self.creationDate, forKey: "d")
        encoder.encodeInt32(self.participationStatus.rawValue, forKey: "ps")
        encoder.encodeInt32(self.flags.rawValue, forKey: "fl")
        if let collapsedInDialogs = self.collapsedInDialogs {
            encoder.encodeBool(collapsedInDialogs, forKey: "cid")
        } else {
            encoder.encodeNil(forKey: "cid")
        }
        if let adminRights = self.adminRights {
            encoder.encodeObject(adminRights, forKey: "ar")
        } else {
            encoder.encodeNil(forKey: "ar")
        }
        if let defaultBannedRights = self.defaultBannedRights {
            encoder.encodeObject(defaultBannedRights, forKey: "dbr")
        } else {
            encoder.encodeNil(forKey: "dbr")
        }
    }

    public init(flatBuffersObject: TelegramCore_TelegramCommunity) throws {
        self.id = PeerId(flatBuffersObject: flatBuffersObject.id)
        self.accessHash = try flatBuffersObject.accessHash.flatMap(TelegramPeerAccessHash.init)
        self.title = flatBuffersObject.title
        self.photo = try (0 ..< flatBuffersObject.photoCount).map { try TelegramMediaImageRepresentation(flatBuffersObject: flatBuffersObject.photo(at: $0)!) }
        self.creationDate = flatBuffersObject.creationDate
        self.participationStatus = TelegramCommunityParticipationStatus(rawValue: flatBuffersObject.participationStatus) ?? .member
        self.flags = TelegramCommunityFlags(rawValue: flatBuffersObject.flags)
        self.collapsedInDialogs = flatBuffersObject.collapsedInDialogs?.value
        self.adminRights = try flatBuffersObject.adminRights.flatMap { try TelegramChatAdminRights(flatBuffersObject: $0) }
        self.defaultBannedRights = try flatBuffersObject.defaultBannedRights.flatMap { try TelegramChatBannedRights(flatBuffersObject: $0) }
    }

    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let accessHashOffset = self.accessHash.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
        let titleOffset = builder.create(string: self.title)
        let photoOffsets = self.photo.map { $0.encodeToFlatBuffers(builder: &builder) }
        let photoOffset = builder.createVector(ofOffsets: photoOffsets, len: photoOffsets.count)
        let adminRightsOffset = self.adminRights?.encodeToFlatBuffers(builder: &builder)
        let defaultBannedRightsOffset = self.defaultBannedRights?.encodeToFlatBuffers(builder: &builder)

        let start = TelegramCore_TelegramCommunity.startTelegramCommunity(&builder)
        TelegramCore_TelegramCommunity.add(id: self.id.asFlatBuffersObject(), &builder)
        if let accessHashOffset {
            TelegramCore_TelegramCommunity.add(accessHash: accessHashOffset, &builder)
        }
        TelegramCore_TelegramCommunity.add(title: titleOffset, &builder)
        TelegramCore_TelegramCommunity.addVectorOf(photo: photoOffset, &builder)
        TelegramCore_TelegramCommunity.add(creationDate: self.creationDate, &builder)
        TelegramCore_TelegramCommunity.add(participationStatus: self.participationStatus.rawValue, &builder)
        TelegramCore_TelegramCommunity.add(flags: self.flags.rawValue, &builder)
        if let collapsedInDialogs = self.collapsedInDialogs {
            TelegramCore_TelegramCommunity.add(collapsedInDialogs: TelegramCore_OptionalBool(value: collapsedInDialogs), &builder)
        }
        if let adminRightsOffset {
            TelegramCore_TelegramCommunity.add(adminRights: adminRightsOffset, &builder)
        }
        if let defaultBannedRightsOffset {
            TelegramCore_TelegramCommunity.add(defaultBannedRights: defaultBannedRightsOffset, &builder)
        }
        return TelegramCore_TelegramCommunity.endTelegramCommunity(&builder, start: start)
    }

    public func isEqual(_ other: Peer) -> Bool {
        guard let other = other as? TelegramCommunity else {
            return false
        }
        return self == other
    }

    public static func ==(lhs: TelegramCommunity, rhs: TelegramCommunity) -> Bool {
        if lhs.id != rhs.id || lhs.accessHash != rhs.accessHash || lhs.title != rhs.title || lhs.photo != rhs.photo {
            return false
        }
        if lhs.creationDate != rhs.creationDate || lhs.participationStatus != rhs.participationStatus {
            return false
        }
        if lhs.flags != rhs.flags || lhs.collapsedInDialogs != rhs.collapsedInDialogs {
            return false
        }
        if lhs.adminRights != rhs.adminRights || lhs.defaultBannedRights != rhs.defaultBannedRights {
            return false
        }
        return true
    }

    public func withUpdatedCollapsedInDialogs(_ collapsedInDialogs: Bool?) -> TelegramCommunity {
        return TelegramCommunity(id: self.id, accessHash: self.accessHash, title: self.title, photo: self.photo, creationDate: self.creationDate, participationStatus: self.participationStatus, flags: self.flags, collapsedInDialogs: collapsedInDialogs, adminRights: self.adminRights, defaultBannedRights: self.defaultBannedRights)
    }

    public func withUpdatedDefaultBannedRights(_ defaultBannedRights: TelegramChatBannedRights?) -> TelegramCommunity {
        return TelegramCommunity(id: self.id, accessHash: self.accessHash, title: self.title, photo: self.photo, creationDate: self.creationDate, participationStatus: self.participationStatus, flags: self.flags, collapsedInDialogs: self.collapsedInDialogs, adminRights: self.adminRights, defaultBannedRights: defaultBannedRights)
    }

    public func hasPermission(_ permission: TelegramCommunityPermission, ignoreDefault: Bool = false) -> Bool {
        if self.flags.contains(.isCreator) {
            return true
        }
        switch permission {
        case .changeInfo:
            if let adminRights = self.adminRights, adminRights.rights.contains(.canChangeInfo) {
                return true
            }
            if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(.banChangeInfo) && !ignoreDefault {
                return false
            }
            return true
        case .banUsers:
            if let adminRights = self.adminRights {
                return adminRights.rights.contains(.canBanUsers)
            }
            return false
        case .manageLinkedPeers:
            if let adminRights = self.adminRights, adminRights.rights.contains(.canManageLinkedPeers) {
                return true
            }
            if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(.banManageLinkedPeers) && !ignoreDefault {
                return false
            }
            return true
        case .addAdmins:
            if let adminRights = self.adminRights {
                return adminRights.rights.contains(.canAddAdmins)
            }
            return false
        }
    }
}
