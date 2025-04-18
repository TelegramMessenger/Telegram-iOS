import Postbox
import FlatBuffers
import FlatSerialization

public enum TelegramGroupRole: Equatable, PostboxCoding {
    case creator(rank: String?)
    case admin(TelegramChatAdminRights, rank: String?)
    case member
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_v", orElse: 0) {
            case 0:
                self = .creator(rank: decoder.decodeOptionalStringForKey("rank"))
            case 1:
                self = .admin(decoder.decodeObjectForKey("r", decoder: { TelegramChatAdminRights(decoder: $0) }) as! TelegramChatAdminRights, rank: decoder.decodeOptionalStringForKey("rank"))
            case 2:
                self = .member
            default:
                assertionFailure()
                self = .member
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .creator(rank):
                encoder.encodeInt32(0, forKey: "_v")
                if let rank = rank {
                    encoder.encodeString(rank, forKey: "rank")
                } else {
                    encoder.encodeNil(forKey: "rank")
                }
            case let .admin(rights, rank):
                encoder.encodeInt32(1, forKey: "_v")
                encoder.encodeObject(rights, forKey: "r")
                if let rank = rank {
                    encoder.encodeString(rank, forKey: "rank")
                } else {
                    encoder.encodeNil(forKey: "rank")
                }
            case .member:
                encoder.encodeInt32(2, forKey: "_v")
        }
    }
    
    public init(flatBuffersObject: TelegramCore_TelegramGroupRole) throws {
        switch flatBuffersObject.valueType {
        case .telegramgrouproleCreator:
            guard let creator = flatBuffersObject.value(type: TelegramCore_TelegramGroupRole_Creator.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .creator(rank: creator.rank)
        case .telegramgrouproleAdmin:
            guard let admin = flatBuffersObject.value(type: TelegramCore_TelegramGroupRole_Admin.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .admin(try TelegramChatAdminRights(flatBuffersObject: admin.rights), rank: admin.rank)
        case .telegramgrouproleMember:
            self = .member
        case .none_:
            throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
        }
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let valueOffset: Offset
        let valueType: TelegramCore_TelegramGroupRole_Value
        
        switch self {
        case let .creator(rank):
            let rankOffset = rank.map { builder.create(string: $0) }
            let start = TelegramCore_TelegramGroupRole_Creator.startTelegramGroupRole_Creator(&builder)
            if let rankOffset {
                TelegramCore_TelegramGroupRole_Creator.add(rank: rankOffset, &builder)
            }
            valueOffset = TelegramCore_TelegramGroupRole_Creator.endTelegramGroupRole_Creator(&builder, start: start)
            valueType = .telegramgrouproleCreator
        case let .admin(rights, rank):
            let rankOffset = rank.map { builder.create(string: $0) }
            let rightsOffset = rights.encodeToFlatBuffers(builder: &builder)
            
            let start = TelegramCore_TelegramGroupRole_Admin.startTelegramGroupRole_Admin(&builder)
            TelegramCore_TelegramGroupRole_Admin.add(rights: rightsOffset, &builder)
            if let rankOffset {
                TelegramCore_TelegramGroupRole_Admin.add(rank: rankOffset, &builder)
            }
            valueOffset = TelegramCore_TelegramGroupRole_Admin.endTelegramGroupRole_Admin(&builder, start: start)
            valueType = .telegramgrouproleAdmin
        case .member:
            let start = TelegramCore_TelegramGroupRole_Member.startTelegramGroupRole_Member(&builder)
            valueOffset = TelegramCore_TelegramGroupRole_Member.endTelegramGroupRole_Member(&builder, start: start)
            valueType = .telegramgrouproleMember
        }
        
        let start = TelegramCore_TelegramGroupRole.startTelegramGroupRole(&builder)
        TelegramCore_TelegramGroupRole.add(value: valueOffset, &builder)
        TelegramCore_TelegramGroupRole.add(valueType: valueType, &builder)
        return TelegramCore_TelegramGroupRole.endTelegramGroupRole(&builder, start: start)
    }
}

public enum TelegramGroupMembership: Int32 {
    case Member
    case Left
    case Removed
}

public struct TelegramGroupFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let deactivated = TelegramGroupFlags(rawValue: 1 << 1)
    public static let hasVoiceChat = TelegramGroupFlags(rawValue: 1 << 2)
    public static let hasActiveVoiceChat = TelegramGroupFlags(rawValue: 1 << 3)
    public static let copyProtectionEnabled = TelegramGroupFlags(rawValue: 1 << 4)
}

public struct TelegramGroupToChannelMigrationReference: Equatable {
    public let peerId: PeerId
    public let accessHash: Int64
    
    public init(peerId: PeerId, accessHash: Int64) {
        self.peerId = peerId
        self.accessHash = accessHash
    }
    
    public init(flatBuffersObject: TelegramCore_TelegramGroupToChannelMigrationReference) throws {
        self.peerId = PeerId(flatBuffersObject.peerId)
        self.accessHash = flatBuffersObject.accessHash
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let start = TelegramCore_TelegramGroupToChannelMigrationReference.startTelegramGroupToChannelMigrationReference(&builder)
        TelegramCore_TelegramGroupToChannelMigrationReference.add(peerId: self.peerId.toInt64(), &builder)
        TelegramCore_TelegramGroupToChannelMigrationReference.add(accessHash: self.accessHash, &builder)
        return TelegramCore_TelegramGroupToChannelMigrationReference.endTelegramGroupToChannelMigrationReference(&builder, start: start)
    }
}

public final class TelegramGroup: Peer, Equatable {
    public let id: PeerId
    public let title: String
    public let photo: [TelegramMediaImageRepresentation]
    public let participantCount: Int
    public let role: TelegramGroupRole
    public let membership: TelegramGroupMembership
    public let flags: TelegramGroupFlags
    public let defaultBannedRights: TelegramChatBannedRights?
    public let migrationReference: TelegramGroupToChannelMigrationReference?
    public let creationDate: Int32
    public let version: Int
    
    public var indexName: PeerIndexNameRepresentation {
        return .title(title: self.title, addressNames: [])
    }
    
    public var associatedMediaIds: [MediaId]? { return nil }
    
    public let associatedPeerId: PeerId? = nil
    public let notificationSettingsPeerId: PeerId? = nil
    
    public var timeoutAttribute: UInt32? { return nil }
    
    public init(id: PeerId, title: String, photo: [TelegramMediaImageRepresentation], participantCount: Int, role: TelegramGroupRole, membership: TelegramGroupMembership, flags: TelegramGroupFlags, defaultBannedRights: TelegramChatBannedRights?, migrationReference: TelegramGroupToChannelMigrationReference?, creationDate: Int32, version: Int) {
        self.id = id
        self.title = title
        self.photo = photo
        self.participantCount = participantCount
        self.role = role
        self.membership = membership
        self.flags = flags
        self.defaultBannedRights = defaultBannedRights
        self.migrationReference = migrationReference
        self.creationDate = creationDate
        self.version = version
    }
    
    public init(decoder: PostboxDecoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i", orElse: 0))
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.photo = decoder.decodeObjectArrayForKey("ph")
        self.participantCount = Int(decoder.decodeInt32ForKey("pc", orElse: 0))
        if let role = decoder.decodeObjectForKey("rv", decoder: { TelegramGroupRole(decoder: $0) }) as? TelegramGroupRole {
            self.role = role
        } else if let roleValue = decoder.decodeOptionalInt32ForKey("r"), roleValue == 0 {
            self.role = .creator(rank: nil)
        } else {
            self.role = .member
        }
        self.membership = TelegramGroupMembership(rawValue: decoder.decodeInt32ForKey("m", orElse: 0))!
        self.flags = TelegramGroupFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.defaultBannedRights = decoder.decodeObjectForKey("dbr", decoder: { TelegramChatBannedRights(decoder: $0) }) as? TelegramChatBannedRights
        let migrationPeerId: Int64? = decoder.decodeOptionalInt64ForKey("mr.i")
        let migrationAccessHash: Int64? = decoder.decodeOptionalInt64ForKey("mr.a")
        if let migrationPeerId = migrationPeerId, let migrationAccessHash = migrationAccessHash {
            self.migrationReference = TelegramGroupToChannelMigrationReference(peerId: PeerId(migrationPeerId), accessHash: migrationAccessHash)
        } else {
            self.migrationReference = nil
        }
        self.creationDate = decoder.decodeInt32ForKey("d", orElse: 0)
        self.version = Int(decoder.decodeInt32ForKey("v", orElse: 0))
        
        #if DEBUG
        var builder = FlatBufferBuilder(initialSize: 1024)
        let offset = self.encodeToFlatBuffers(builder: &builder)
        builder.finish(offset: offset)
        let serializedData = builder.data
        var byteBuffer = ByteBuffer(data: serializedData)
        let deserializedValue = FlatBuffers_getRoot(byteBuffer: &byteBuffer) as TelegramCore_TelegramGroup
        let parsedValue = try! TelegramGroup(flatBuffersObject: deserializedValue)
        assert(self == parsedValue)
        #endif
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.id.toInt64(), forKey: "i")
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeObjectArray(self.photo, forKey: "ph")
        encoder.encodeInt32(Int32(self.participantCount), forKey: "pc")
        encoder.encodeObject(self.role, forKey: "rv")
        encoder.encodeInt32(self.membership.rawValue, forKey: "m")
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        if let defaultBannedRights = self.defaultBannedRights {
            encoder.encodeObject(defaultBannedRights, forKey: "dbr")
        } else {
            encoder.encodeNil(forKey: "dbr")
        }
        if let migrationReference = self.migrationReference {
            encoder.encodeInt64(migrationReference.peerId.toInt64(), forKey: "mr.i")
            encoder.encodeInt64(migrationReference.accessHash, forKey: "mr.a")
        } else {
            encoder.encodeNil(forKey: "mr.i")
            encoder.encodeNil(forKey: "mr.a")
        }
        encoder.encodeInt32(self.creationDate, forKey: "d")
        encoder.encodeInt32(Int32(self.version), forKey: "v")
    }

    public init(flatBuffersObject: TelegramCore_TelegramGroup) throws {
        self.id = PeerId(flatBuffersObject.id)
        self.title = flatBuffersObject.title
        self.photo = try (0 ..< flatBuffersObject.photoCount).map { try TelegramMediaImageRepresentation(flatBuffersObject: flatBuffersObject.photo(at: $0)!) }
        self.participantCount = Int(flatBuffersObject.participantCount)
        
        guard let role = flatBuffersObject.role else {
            throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
        }
        self.role = try TelegramGroupRole(flatBuffersObject: role)
        
        self.membership = TelegramGroupMembership(rawValue: flatBuffersObject.membership)!
        self.flags = TelegramGroupFlags(rawValue: flatBuffersObject.flags)
        self.defaultBannedRights = try flatBuffersObject.defaultBannedRights.flatMap { try TelegramChatBannedRights(flatBuffersObject: $0) }
        
        if let migrationReference = flatBuffersObject.migrationReference {
            self.migrationReference = try TelegramGroupToChannelMigrationReference(flatBuffersObject: migrationReference)
        } else {
            self.migrationReference = nil
        }
        
        self.creationDate = flatBuffersObject.creationDate
        self.version = Int(flatBuffersObject.version)
    }
    
    public func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        let titleOffset = builder.create(string: self.title)
        
        let photoOffsets = self.photo.map { $0.encodeToFlatBuffers(builder: &builder) }
        let photoOffset = builder.createVector(ofOffsets: photoOffsets, len: photoOffsets.count)
        
        let roleOffset = self.role.encodeToFlatBuffers(builder: &builder)
        let defaultBannedRightsOffset = self.defaultBannedRights?.encodeToFlatBuffers(builder: &builder)
        
        let migrationReferenceOffset = self.migrationReference?.encodeToFlatBuffers(builder: &builder)
        
        let start = TelegramCore_TelegramGroup.startTelegramGroup(&builder)
        
        TelegramCore_TelegramGroup.add(id: self.id.asFlatBuffersObject(), &builder)
        TelegramCore_TelegramGroup.add(title: titleOffset, &builder)
        TelegramCore_TelegramGroup.addVectorOf(photo: photoOffset, &builder)
        TelegramCore_TelegramGroup.add(participantCount: Int32(self.participantCount), &builder)
        TelegramCore_TelegramGroup.add(role: roleOffset, &builder)
        TelegramCore_TelegramGroup.add(membership: self.membership.rawValue, &builder)
        TelegramCore_TelegramGroup.add(flags: self.flags.rawValue, &builder)
        
        if let defaultBannedRightsOffset {
            TelegramCore_TelegramGroup.add(defaultBannedRights: defaultBannedRightsOffset, &builder)
        }
        if let migrationReferenceOffset {
            TelegramCore_TelegramGroup.add(migrationReference: migrationReferenceOffset, &builder)
        }
        
        TelegramCore_TelegramGroup.add(creationDate: self.creationDate, &builder)
        TelegramCore_TelegramGroup.add(version: Int32(self.version), &builder)
        
        return TelegramCore_TelegramGroup.endTelegramGroup(&builder, start: start)
    }
    
    public func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TelegramGroup {
            return self == other
        } else {
            return false
        }
    }

    public static func ==(lhs: TelegramGroup, rhs: TelegramGroup) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.photo != rhs.photo {
            return false
        }
        if lhs.membership != rhs.membership {
            return false
        }
        if lhs.version != rhs.version {
            return false
        }
        if lhs.participantCount != rhs.participantCount {
            return false
        }
        if lhs.role != rhs.role {
            return false
        }
        if lhs.defaultBannedRights != rhs.defaultBannedRights {
            return false
        }
        if lhs.migrationReference != rhs.migrationReference {
            return false
        }
        if lhs.creationDate != rhs.creationDate {
            return false
        }
        if lhs.flags != rhs.flags {
            return false
        }
        return true
    }

    public func updateFlags(flags: TelegramGroupFlags, version: Int) -> TelegramGroup {
        return TelegramGroup(id: self.id, title: self.title, photo: self.photo, participantCount: self.participantCount, role: self.role, membership: self.membership, flags: flags, defaultBannedRights: self.defaultBannedRights, migrationReference: self.migrationReference, creationDate: self.creationDate, version: version)
    }
    
    public func updateDefaultBannedRights(_ defaultBannedRights: TelegramChatBannedRights?, version: Int) -> TelegramGroup {
        return TelegramGroup(id: self.id, title: self.title, photo: self.photo, participantCount: self.participantCount, role: self.role, membership: self.membership, flags: self.flags, defaultBannedRights: defaultBannedRights, migrationReference: self.migrationReference, creationDate: self.creationDate, version: version)
    }
    
    public func updateParticipantCount(_ participantCount: Int) -> TelegramGroup {
        return TelegramGroup(id: self.id, title: self.title, photo: self.photo, participantCount: participantCount, role: self.role, membership: self.membership, flags: self.flags, defaultBannedRights: self.defaultBannedRights, migrationReference: self.migrationReference, creationDate: self.creationDate, version: version)
    }
}
