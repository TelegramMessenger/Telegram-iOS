import Postbox

public struct CachedChannelFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let canDisplayParticipants = CachedChannelFlags(rawValue: 1 << 0)
    public static let canChangeUsername = CachedChannelFlags(rawValue: 1 << 1)
    public static let canSetStickerSet = CachedChannelFlags(rawValue: 1 << 2)
    public static let preHistoryEnabled = CachedChannelFlags(rawValue: 1 << 3)
    public static let canViewStats = CachedChannelFlags(rawValue: 1 << 4)
    public static let canChangePeerGeoLocation = CachedChannelFlags(rawValue: 1 << 5)
}

public struct CachedChannelParticipantsSummary: PostboxCoding, Equatable {
    public let memberCount: Int32?
    public let adminCount: Int32?
    public let bannedCount: Int32?
    public let kickedCount: Int32?
    
    public init(memberCount: Int32?, adminCount: Int32?, bannedCount: Int32?, kickedCount: Int32?) {
        self.memberCount = memberCount
        self.adminCount = adminCount
        self.bannedCount = bannedCount
        self.kickedCount = kickedCount
    }
    
    public init(decoder: PostboxDecoder) {
        if let memberCount = decoder.decodeOptionalInt32ForKey("p.m") {
            self.memberCount = memberCount
        } else {
            self.memberCount = nil
        }
        if let adminCount = decoder.decodeOptionalInt32ForKey("p.a") {
            self.adminCount = adminCount
        } else {
            self.adminCount = nil
        }
        if let bannedCount = decoder.decodeOptionalInt32ForKey("p.b") {
            self.bannedCount = bannedCount
        } else {
            self.bannedCount = nil
        }
        if let kickedCount = decoder.decodeOptionalInt32ForKey("p.k") {
            self.kickedCount = kickedCount
        } else {
            self.kickedCount = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let memberCount = self.memberCount {
            encoder.encodeInt32(memberCount, forKey: "p.m")
        } else {
            encoder.encodeNil(forKey: "p.m")
        }
        if let adminCount = self.adminCount {
            encoder.encodeInt32(adminCount, forKey: "p.a")
        } else {
            encoder.encodeNil(forKey: "p.a")
        }
        if let bannedCount = self.bannedCount {
            encoder.encodeInt32(bannedCount, forKey: "p.b")
        } else {
            encoder.encodeNil(forKey: "p.b")
        }
        if let kickedCount = self.kickedCount {
            encoder.encodeInt32(kickedCount, forKey: "p.k")
        } else {
            encoder.encodeNil(forKey: "p.k")
        }
    }
    
    public static func ==(lhs: CachedChannelParticipantsSummary, rhs: CachedChannelParticipantsSummary) -> Bool {
        return lhs.memberCount == rhs.memberCount && lhs.adminCount == rhs.adminCount && lhs.bannedCount == rhs.bannedCount && lhs.kickedCount == rhs.kickedCount
    }
    
    public func withUpdatedMemberCount(_ memberCount: Int32?) -> CachedChannelParticipantsSummary {
        return CachedChannelParticipantsSummary(memberCount: memberCount, adminCount: self.adminCount, bannedCount: self.bannedCount, kickedCount: self.kickedCount)
    }
    
    public func withUpdatedAdminCount(_ adminCount: Int32?) -> CachedChannelParticipantsSummary {
        return CachedChannelParticipantsSummary(memberCount: self.memberCount, adminCount: adminCount, bannedCount: self.bannedCount, kickedCount: self.kickedCount)
    }
    
    public func withUpdatedBannedCount(_ bannedCount: Int32?) -> CachedChannelParticipantsSummary {
        return CachedChannelParticipantsSummary(memberCount: self.memberCount, adminCount: self.adminCount, bannedCount: bannedCount, kickedCount: self.kickedCount)
    }
    
    public func withUpdatedKickedCount(_ kickedCount: Int32?) -> CachedChannelParticipantsSummary {
        return CachedChannelParticipantsSummary(memberCount: self.memberCount, adminCount: self.adminCount, bannedCount: self.bannedCount, kickedCount: kickedCount)
    }
}

public struct ChannelMigrationReference: PostboxCoding, Equatable {
    public let maxMessageId: MessageId
    
    public init(maxMessageId: MessageId) {
        self.maxMessageId = maxMessageId
    }
    
    public init(decoder: PostboxDecoder) {
        self.maxMessageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("p", orElse: 0)), namespace: decoder.decodeInt32ForKey("n", orElse: 0), id: decoder.decodeInt32ForKey("i", orElse: 0))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.maxMessageId.peerId.toInt64(), forKey: "p")
        encoder.encodeInt32(self.maxMessageId.namespace, forKey: "n")
        encoder.encodeInt32(self.maxMessageId.id, forKey: "i")
    }
    
    public static func ==(lhs: ChannelMigrationReference, rhs: ChannelMigrationReference) -> Bool {
        return lhs.maxMessageId == rhs.maxMessageId
    }
}

public struct PeerGeoLocation: PostboxCoding, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let address: String
    
    public init(latitude: Double, longitude: Double, address: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
    }
    
    public init(decoder: PostboxDecoder) {
        self.latitude = decoder.decodeDoubleForKey("la", orElse: 0.0)
        self.longitude = decoder.decodeDoubleForKey("lo", orElse: 0.0)
        self.address = decoder.decodeStringForKey("a", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeDouble(self.latitude, forKey: "la")
        encoder.encodeDouble(self.longitude, forKey: "lo")
        encoder.encodeString(self.address, forKey: "a")
    }
    
    public static func ==(lhs: PeerGeoLocation, rhs: PeerGeoLocation) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude && lhs.address == rhs.address
    }
}

public final class CachedChannelData: CachedPeerData {
    public let isNotAccessible: Bool
    public let flags: CachedChannelFlags
    public let about: String?
    public let participantsSummary: CachedChannelParticipantsSummary
    public let exportedInvitation: ExportedInvitation?
    public let botInfos: [CachedPeerBotInfo]
    public let peerStatusSettings: PeerStatusSettings?
    public let pinnedMessageId: MessageId?
    public let stickerPack: StickerPackCollectionInfo?
    public let minAvailableMessageId: MessageId?
    public let migrationReference: ChannelMigrationReference?
    public let linkedDiscussionPeerId: PeerId?
    public let peerGeoLocation: PeerGeoLocation?
    public let slowModeTimeout: Int32?
    public let slowModeValidUntilTimestamp: Int32?
    public let hasScheduledMessages: Bool
    
    public let peerIds: Set<PeerId>
    public let messageIds: Set<MessageId>
    public var associatedHistoryMessageId: MessageId? {
        return self.migrationReference?.maxMessageId
    }
    
    public init() {
        self.isNotAccessible = false
        self.flags = []
        self.about = nil
        self.participantsSummary = CachedChannelParticipantsSummary(memberCount: nil, adminCount: nil, bannedCount: nil, kickedCount: nil)
        self.exportedInvitation = nil
        self.botInfos = []
        self.peerStatusSettings = nil
        self.pinnedMessageId = nil
        self.peerIds = Set()
        self.messageIds = Set()
        self.stickerPack = nil
        self.minAvailableMessageId = nil
        self.migrationReference = nil
        self.linkedDiscussionPeerId = nil
        self.peerGeoLocation = nil
        self.slowModeTimeout = nil
        self.slowModeValidUntilTimestamp = nil
        self.hasScheduledMessages = false
    }
    
    public init(isNotAccessible: Bool, flags: CachedChannelFlags, about: String?, participantsSummary: CachedChannelParticipantsSummary, exportedInvitation: ExportedInvitation?, botInfos: [CachedPeerBotInfo], peerStatusSettings: PeerStatusSettings?, pinnedMessageId: MessageId?, stickerPack: StickerPackCollectionInfo?, minAvailableMessageId: MessageId?, migrationReference: ChannelMigrationReference?, linkedDiscussionPeerId: PeerId?, peerGeoLocation: PeerGeoLocation?, slowModeTimeout: Int32?, slowModeValidUntilTimestamp: Int32?, hasScheduledMessages: Bool) {
        self.isNotAccessible = isNotAccessible
        self.flags = flags
        self.about = about
        self.participantsSummary = participantsSummary
        self.exportedInvitation = exportedInvitation
        self.botInfos = botInfos
        self.peerStatusSettings = peerStatusSettings
        self.pinnedMessageId = pinnedMessageId
        self.stickerPack = stickerPack
        self.minAvailableMessageId = minAvailableMessageId
        self.migrationReference = migrationReference
        self.linkedDiscussionPeerId = linkedDiscussionPeerId
        self.peerGeoLocation = peerGeoLocation
        self.slowModeTimeout = slowModeTimeout
        self.slowModeValidUntilTimestamp = slowModeValidUntilTimestamp
        self.hasScheduledMessages = hasScheduledMessages
        
        var peerIds = Set<PeerId>()
        for botInfo in botInfos {
            peerIds.insert(botInfo.peerId)
        }
        
        if let linkedDiscussionPeerId = linkedDiscussionPeerId {
            peerIds.insert(linkedDiscussionPeerId)
        }
        
        self.peerIds = peerIds
        
        var messageIds = Set<MessageId>()
        if let pinnedMessageId = self.pinnedMessageId {
            messageIds.insert(pinnedMessageId)
        }
        self.messageIds = messageIds
    }
    
    public func withUpdatedIsNotAccessible(_ isNotAccessible: Bool) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedFlags(_ flags: CachedChannelFlags) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedAbout(_ about: String?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedParticipantsSummary(_ participantsSummary: CachedChannelParticipantsSummary) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedExportedInvitation(_ exportedInvitation: ExportedInvitation?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedBotInfos(_ botInfos: [CachedPeerBotInfo]) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedPeerStatusSettings(_ peerStatusSettings: PeerStatusSettings?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedStickerPack(_ stickerPack: StickerPackCollectionInfo?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedMinAvailableMessageId(_ minAvailableMessageId: MessageId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedMigrationReference(_ migrationReference: ChannelMigrationReference?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedLinkedDiscussionPeerId(_ linkedDiscussionPeerId: PeerId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedPeerGeoLocation(_ peerGeoLocation: PeerGeoLocation?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }

    public func withUpdatedSlowModeTimeout(_ slowModeTimeout: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedSlowModeValidUntilTimestamp(_ slowModeValidUntilTimestamp: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages)
    }
    
    public func withUpdatedHasScheduledMessages(_ hasScheduledMessages: Bool) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: hasScheduledMessages)
    }
    
    public init(decoder: PostboxDecoder) {
        self.isNotAccessible = decoder.decodeInt32ForKey("isNotAccessible", orElse: 0) != 0
        self.flags = CachedChannelFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.about = decoder.decodeOptionalStringForKey("a")
        self.participantsSummary = CachedChannelParticipantsSummary(decoder: decoder)
        self.exportedInvitation = decoder.decodeObjectForKey("i", decoder: { ExportedInvitation(decoder: $0) }) as? ExportedInvitation
        self.botInfos = decoder.decodeObjectArrayWithDecoderForKey("b") as [CachedPeerBotInfo]
        var peerIds = Set<PeerId>()
        if let value = decoder.decodeOptionalInt32ForKey("pcs") {
            self.peerStatusSettings = PeerStatusSettings(rawValue: value)
        } else {
            self.peerStatusSettings = nil
        }
        if let pinnedMessagePeerId = decoder.decodeOptionalInt64ForKey("pm.p"), let pinnedMessageNamespace = decoder.decodeOptionalInt32ForKey("pm.n"), let pinnedMessageId = decoder.decodeOptionalInt32ForKey("pm.i") {
            self.pinnedMessageId = MessageId(peerId: PeerId(pinnedMessagePeerId), namespace: pinnedMessageNamespace, id: pinnedMessageId)
        } else {
            self.pinnedMessageId = nil
        }
        
        if let stickerPack = decoder.decodeObjectForKey("sp", decoder: { StickerPackCollectionInfo(decoder: $0) }) as? StickerPackCollectionInfo {
            self.stickerPack = stickerPack
        } else {
            self.stickerPack = nil
        }
        
        if let minAvailableMessagePeerId = decoder.decodeOptionalInt64ForKey("ma.p"), let minAvailableMessageNamespace = decoder.decodeOptionalInt32ForKey("ma.n"), let minAvailableMessageId = decoder.decodeOptionalInt32ForKey("ma.i") {
            self.minAvailableMessageId = MessageId(peerId: PeerId(minAvailableMessagePeerId), namespace: minAvailableMessageNamespace, id: minAvailableMessageId)
        } else {
            self.minAvailableMessageId = nil
        }
        
        self.migrationReference = decoder.decodeObjectForKey("mr", decoder: { ChannelMigrationReference(decoder: $0) }) as? ChannelMigrationReference
        
        for botInfo in self.botInfos {
            peerIds.insert(botInfo.peerId)
        }
        
        if let linkedDiscussionPeerId = decoder.decodeOptionalInt64ForKey("dgi") {
            self.linkedDiscussionPeerId = PeerId(linkedDiscussionPeerId)
        } else {
            self.linkedDiscussionPeerId = nil
        }
        
        if let peerGeoLocation = decoder.decodeObjectForKey("pgl", decoder: { PeerGeoLocation(decoder: $0) }) as? PeerGeoLocation {
            self.peerGeoLocation = peerGeoLocation
        } else {
            self.peerGeoLocation = nil
        }
        
        self.slowModeTimeout = decoder.decodeOptionalInt32ForKey("smt")
        self.slowModeValidUntilTimestamp = decoder.decodeOptionalInt32ForKey("smv")
        self.hasScheduledMessages = decoder.decodeBoolForKey("hsm", orElse: false)
        
        if let linkedDiscussionPeerId = self.linkedDiscussionPeerId {
            peerIds.insert(linkedDiscussionPeerId)
        }
        
        self.peerIds = peerIds
        
        var messageIds = Set<MessageId>()
        if let pinnedMessageId = self.pinnedMessageId {
            messageIds.insert(pinnedMessageId)
        }
        self.messageIds = messageIds
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.isNotAccessible ? 1 : 0, forKey: "isNotAccessible")
        encoder.encodeInt32(self.flags.rawValue, forKey: "f")
        if let about = self.about {
            encoder.encodeString(about, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
        self.participantsSummary.encode(encoder)
        if let exportedInvitation = self.exportedInvitation {
            encoder.encodeObject(exportedInvitation, forKey: "i")
        } else {
            encoder.encodeNil(forKey: "i")
        }
        encoder.encodeObjectArray(self.botInfos, forKey: "b")
        if let peerStatusSettings = self.peerStatusSettings {
            encoder.encodeInt32(peerStatusSettings.rawValue, forKey: "pcs")
        } else {
            encoder.encodeNil(forKey: "pcs")
        }
        if let pinnedMessageId = self.pinnedMessageId {
            encoder.encodeInt64(pinnedMessageId.peerId.toInt64(), forKey: "pm.p")
            encoder.encodeInt32(pinnedMessageId.namespace, forKey: "pm.n")
            encoder.encodeInt32(pinnedMessageId.id, forKey: "pm.i")
        } else {
            encoder.encodeNil(forKey: "pm.p")
            encoder.encodeNil(forKey: "pm.n")
            encoder.encodeNil(forKey: "pm.i")
        }
        if let stickerPack = self.stickerPack {
            encoder.encodeObject(stickerPack, forKey: "sp")
        } else {
            encoder.encodeNil(forKey: "sp")
        }
        if let minAvailableMessageId = self.minAvailableMessageId {
            encoder.encodeInt64(minAvailableMessageId.peerId.toInt64(), forKey: "ma.p")
            encoder.encodeInt32(minAvailableMessageId.namespace, forKey: "ma.n")
            encoder.encodeInt32(minAvailableMessageId.id, forKey: "ma.i")
        } else {
            encoder.encodeNil(forKey: "ma.p")
            encoder.encodeNil(forKey: "ma.n")
            encoder.encodeNil(forKey: "ma.i")
        }
        if let migrationReference = self.migrationReference {
            encoder.encodeObject(migrationReference, forKey: "mr")
        } else {
            encoder.encodeNil(forKey: "mr")
        }
        if let linkedDiscussionPeerId = self.linkedDiscussionPeerId {
            encoder.encodeInt64(linkedDiscussionPeerId.toInt64(), forKey: "dgi")
        } else {
            encoder.encodeNil(forKey: "dgi")
        }
        if let peerGeoLocation = self.peerGeoLocation {
            encoder.encodeObject(peerGeoLocation, forKey: "pgl")
        } else {
            encoder.encodeNil(forKey: "pgl")
        }
        
        if let slowModeTimeout = self.slowModeTimeout {
            encoder.encodeInt32(slowModeTimeout, forKey: "smt")
        } else {
            encoder.encodeNil(forKey: "smt")
        }
        if let slowModeValidUntilTimestamp = self.slowModeValidUntilTimestamp {
            encoder.encodeInt32(slowModeValidUntilTimestamp, forKey: "smv")
        } else {
            encoder.encodeNil(forKey: "smv")
        }
        encoder.encodeBool(self.hasScheduledMessages, forKey: "hsm")
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedChannelData else {
            return false
        }
        
        if other.isNotAccessible != self.isNotAccessible {
            return false
        }
        
        if other.flags != self.flags {
            return false
        }
        
        if other.linkedDiscussionPeerId != self.linkedDiscussionPeerId {
            return false
        }
        
        if other.about != self.about {
            return false
        }
        
        if other.participantsSummary != self.participantsSummary {
            return false
        }
        
        if other.exportedInvitation != self.exportedInvitation {
            return false
        }
        
        if other.botInfos != self.botInfos {
            return false
        }
        
        if other.peerStatusSettings != self.peerStatusSettings {
            return false
        }
        
        if other.pinnedMessageId != self.pinnedMessageId {
            return false
        }
        
        if other.stickerPack != self.stickerPack {
            return false
        }
        
        if other.minAvailableMessageId != self.minAvailableMessageId {
            return false
        }
        
        if other.migrationReference != self.migrationReference {
            return false
        }
        
        if other.peerGeoLocation != self.peerGeoLocation {
            return false
        }
        
        if other.slowModeTimeout != self.slowModeTimeout {
            return false
        }
        
        if other.slowModeValidUntilTimestamp != self.slowModeValidUntilTimestamp {
            return false
        }
        
        return true
    }
}
