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
    public static let canDeleteHistory = CachedChannelFlags(rawValue: 1 << 6)
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
    public enum LinkedDiscussionPeerId: Equatable {
        case unknown
        case known(PeerId?)
    }
    
    public struct ActiveCall: Equatable, PostboxCoding {
        public var id: Int64
        public var accessHash: Int64
        public var title: String?
        public var scheduleTimestamp: Int32?
        public var subscribedToScheduled: Bool
        public var isStream: Bool?
        
        public init(
            id: Int64,
            accessHash: Int64,
            title: String?,
            scheduleTimestamp: Int32?,
            subscribedToScheduled: Bool,
            isStream: Bool?
        ) {
            self.id = id
            self.accessHash = accessHash
            self.title = title
            self.scheduleTimestamp = scheduleTimestamp
            self.subscribedToScheduled = subscribedToScheduled
            self.isStream = isStream
        }
        
        public init(decoder: PostboxDecoder) {
            self.id = decoder.decodeInt64ForKey("id", orElse: 0)
            self.accessHash = decoder.decodeInt64ForKey("accessHash", orElse: 0)
            self.title = decoder.decodeOptionalStringForKey("title")
            self.scheduleTimestamp = decoder.decodeOptionalInt32ForKey("scheduleTimestamp")
            self.subscribedToScheduled = decoder.decodeBoolForKey("subscribed", orElse: false)
            self.isStream = decoder.decodeOptionalBoolForKey("isStream_v2")
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt64(self.id, forKey: "id")
            encoder.encodeInt64(self.accessHash, forKey: "accessHash")
            if let title = self.title {
                encoder.encodeString(title, forKey: "title")
            } else {
                encoder.encodeNil(forKey: "title")
            }
            if let scheduleTimestamp = self.scheduleTimestamp {
                encoder.encodeInt32(scheduleTimestamp, forKey: "scheduleTimestamp")
            } else {
                encoder.encodeNil(forKey: "scheduleTimestamp")
            }
            encoder.encodeBool(self.subscribedToScheduled, forKey: "subscribed")
            if let isStream = self.isStream {
                encoder.encodeBool(isStream, forKey: "isStream")
            } else {
                encoder.encodeNil(forKey: "isStream")
            }
        }
    }
    
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
    public let linkedDiscussionPeerId: LinkedDiscussionPeerId
    public let peerGeoLocation: PeerGeoLocation?
    public let slowModeTimeout: Int32?
    public let slowModeValidUntilTimestamp: Int32?
    public let hasScheduledMessages: Bool
    public let autoremoveTimeout: CachedPeerAutoremoveTimeout
    public let statsDatacenterId: Int32
    public let invitedBy: PeerId?
    public let invitedOn: Int32?
    public let photo: TelegramMediaImage?
    public let activeCall: ActiveCall?
    public let callJoinPeerId: PeerId?
    public let pendingSuggestions: [String]
    public let themeEmoticon: String?
    public let inviteRequestsPending: Int32?
    public let sendAsPeerId: PeerId?
    public let allowedReactions: [String]?
    
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
        self.linkedDiscussionPeerId = .unknown
        self.peerGeoLocation = nil
        self.slowModeTimeout = nil
        self.slowModeValidUntilTimestamp = nil
        self.hasScheduledMessages = false
        self.autoremoveTimeout = .unknown
        self.statsDatacenterId = 0
        self.invitedBy = nil
        self.invitedOn = nil
        self.photo = nil
        self.activeCall = nil
        self.callJoinPeerId = nil
        self.pendingSuggestions = []
        self.themeEmoticon = nil
        self.inviteRequestsPending = nil
        self.sendAsPeerId = nil
        self.allowedReactions = nil
    }
    
    public init(
        isNotAccessible: Bool,
        flags: CachedChannelFlags,
        about: String?,
        participantsSummary: CachedChannelParticipantsSummary,
        exportedInvitation: ExportedInvitation?,
        botInfos: [CachedPeerBotInfo],
        peerStatusSettings: PeerStatusSettings?,
        pinnedMessageId: MessageId?,
        stickerPack: StickerPackCollectionInfo?,
        minAvailableMessageId: MessageId?,
        migrationReference: ChannelMigrationReference?,
        linkedDiscussionPeerId: LinkedDiscussionPeerId,
        peerGeoLocation: PeerGeoLocation?,
        slowModeTimeout: Int32?,
        slowModeValidUntilTimestamp: Int32?,
        hasScheduledMessages: Bool,
        statsDatacenterId: Int32,
        invitedBy: PeerId?,
        invitedOn: Int32?,
        photo: TelegramMediaImage?,
        activeCall: ActiveCall?,
        callJoinPeerId: PeerId?,
        autoremoveTimeout: CachedPeerAutoremoveTimeout,
        pendingSuggestions: [String],
        themeEmoticon: String?,
        inviteRequestsPending: Int32?,
        sendAsPeerId: PeerId?,
        allowedReactions: [String]?
    ) {
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
        self.statsDatacenterId = statsDatacenterId
        self.invitedBy = invitedBy
        self.invitedOn = invitedOn
        self.photo = photo
        self.activeCall = activeCall
        self.callJoinPeerId = callJoinPeerId
        self.autoremoveTimeout = autoremoveTimeout
        self.pendingSuggestions = pendingSuggestions
        self.themeEmoticon = themeEmoticon
        self.inviteRequestsPending = inviteRequestsPending
        self.sendAsPeerId = sendAsPeerId
        self.allowedReactions = allowedReactions
        
        var peerIds = Set<PeerId>()
        for botInfo in botInfos {
            peerIds.insert(botInfo.peerId)
        }
        
        if case let .known(linkedDiscussionPeerIdValue) = linkedDiscussionPeerId {
            if let linkedDiscussionPeerIdValue = linkedDiscussionPeerIdValue {
                peerIds.insert(linkedDiscussionPeerIdValue)
            }
        }
        
        if let invitedBy = invitedBy {
            peerIds.insert(invitedBy)
        }
        
        self.peerIds = peerIds
        
        var messageIds = Set<MessageId>()
        if let pinnedMessageId = self.pinnedMessageId {
            messageIds.insert(pinnedMessageId)
        }
        
        self.messageIds = messageIds
    }
    
    public func withUpdatedIsNotAccessible(_ isNotAccessible: Bool) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedFlags(_ flags: CachedChannelFlags) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedAbout(_ about: String?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedParticipantsSummary(_ participantsSummary: CachedChannelParticipantsSummary) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedExportedInvitation(_ exportedInvitation: ExportedInvitation?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedBotInfos(_ botInfos: [CachedPeerBotInfo]) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedPeerStatusSettings(_ peerStatusSettings: PeerStatusSettings?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedStickerPack(_ stickerPack: StickerPackCollectionInfo?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedMinAvailableMessageId(_ minAvailableMessageId: MessageId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedMigrationReference(_ migrationReference: ChannelMigrationReference?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedLinkedDiscussionPeerId(_ linkedDiscussionPeerId: LinkedDiscussionPeerId) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedPeerGeoLocation(_ peerGeoLocation: PeerGeoLocation?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }

    public func withUpdatedSlowModeTimeout(_ slowModeTimeout: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedSlowModeValidUntilTimestamp(_ slowModeValidUntilTimestamp: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedHasScheduledMessages(_ hasScheduledMessages: Bool) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedStatsDatacenterId(_ statsDatacenterId: Int32) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedInvitedBy(_ invitedBy: PeerId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedInvitedOn(_ invitedOn: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedPhoto(_ photo: TelegramMediaImage?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedActiveCall(_ activeCall: ActiveCall?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedCallJoinPeerId(_ callJoinPeerId: PeerId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedAutoremoveTimeout(_ autoremoveTimeout: CachedPeerAutoremoveTimeout) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedPendingSuggestions(_ pendingSuggestions: [String]) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedThemeEmoticon(_ themeEmoticon: String?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedInviteRequestsPending(_ inviteRequestsPending: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedSendAsPeerId(_ sendAsPeerId: PeerId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: sendAsPeerId, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedAllowedReactions(_ allowedReactions: [String]?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, allowedReactions: allowedReactions)
    }
    
    public init(decoder: PostboxDecoder) {
        self.isNotAccessible = decoder.decodeInt32ForKey("isNotAccessible", orElse: 0) != 0
        self.flags = CachedChannelFlags(rawValue: decoder.decodeInt32ForKey("f", orElse: 0))
        self.about = decoder.decodeOptionalStringForKey("a")
        self.participantsSummary = CachedChannelParticipantsSummary(decoder: decoder)
        self.exportedInvitation = decoder.decode(ExportedInvitation.self, forKey: "i")
        self.botInfos = decoder.decodeObjectArrayWithDecoderForKey("b") as [CachedPeerBotInfo]
        var peerIds = Set<PeerId>()
        
        if let legacyValue = decoder.decodeOptionalInt32ForKey("pcs") {
            self.peerStatusSettings = PeerStatusSettings(flags: PeerStatusSettings.Flags(rawValue: legacyValue), geoDistance: nil)
        } else if let peerStatusSettings = decoder.decodeObjectForKey("pss", decoder: { PeerStatusSettings(decoder: $0) }) as? PeerStatusSettings {
            self.peerStatusSettings = peerStatusSettings
        } else {
            self.peerStatusSettings = nil
        }
        if let pinnedMessagePeerId = decoder.decodeOptionalInt64ForKey("pm.p"), let pinnedMessageNamespace = decoder.decodeOptionalInt32ForKey("pm.n"), let pinnedMessageId = decoder.decodeOptionalInt32ForKey("pm.i") {
            self.pinnedMessageId = MessageId(peerId: PeerId(pinnedMessagePeerId), namespace: pinnedMessageNamespace, id: pinnedMessageId)
        } else {
            self.pinnedMessageId = nil
        }
        
        if let activeCall = decoder.decodeObjectForKey("activeCall", decoder: { ActiveCall(decoder: $0) }) as? ActiveCall {
            self.activeCall = activeCall
        } else {
            self.activeCall = nil
        }
        
        self.callJoinPeerId = decoder.decodeOptionalInt64ForKey("callJoinPeerId").flatMap(PeerId.init)
        
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
            if linkedDiscussionPeerId == 0 {
                self.linkedDiscussionPeerId = .known(nil)
            } else {
                self.linkedDiscussionPeerId = .known(PeerId(linkedDiscussionPeerId))
            }
        } else {
            self.linkedDiscussionPeerId = .unknown
        }
        
        if let peerGeoLocation = decoder.decodeObjectForKey("pgl", decoder: { PeerGeoLocation(decoder: $0) }) as? PeerGeoLocation {
            self.peerGeoLocation = peerGeoLocation
        } else {
            self.peerGeoLocation = nil
        }
        
        self.slowModeTimeout = decoder.decodeOptionalInt32ForKey("smt")
        self.slowModeValidUntilTimestamp = decoder.decodeOptionalInt32ForKey("smv")
        self.hasScheduledMessages = decoder.decodeBoolForKey("hsm", orElse: false)
        self.autoremoveTimeout = decoder.decodeObjectForKey("artv", decoder: CachedPeerAutoremoveTimeout.init(decoder:)) as? CachedPeerAutoremoveTimeout ?? .unknown
        self.statsDatacenterId = decoder.decodeInt32ForKey("sdi", orElse: 0)
        
        self.invitedBy = decoder.decodeOptionalInt64ForKey("invBy").flatMap(PeerId.init)
        self.invitedOn = decoder.decodeOptionalInt32ForKey("invOn")
        
        self.pendingSuggestions = decoder.decodeStringArrayForKey("sug")
        
        self.themeEmoticon = decoder.decodeOptionalStringForKey("te")
        
        if let photo = decoder.decodeObjectForKey("ph", decoder: { TelegramMediaImage(decoder: $0) }) as? TelegramMediaImage {
            self.photo = photo
        } else {
            self.photo = nil
        }
        
        self.inviteRequestsPending = decoder.decodeOptionalInt32ForKey("irp")
        
        self.sendAsPeerId = decoder.decodeOptionalInt64ForKey("sendAsPeerId").flatMap(PeerId.init)
        
        self.allowedReactions = decoder.decodeOptionalStringArrayForKey("allowedReactions")
        
        if case let .known(linkedDiscussionPeerIdValue) = self.linkedDiscussionPeerId {
            if let linkedDiscussionPeerIdValue = linkedDiscussionPeerIdValue {
                peerIds.insert(linkedDiscussionPeerIdValue)
            }
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
            encoder.encode(exportedInvitation, forKey: "i")
        } else {
            encoder.encodeNil(forKey: "i")
        }
        encoder.encodeObjectArray(self.botInfos, forKey: "b")
        if let peerStatusSettings = self.peerStatusSettings {
            encoder.encodeObject(peerStatusSettings, forKey: "pss")
        } else {
            encoder.encodeNil(forKey: "pss")
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
        
        if let activeCall = self.activeCall {
            encoder.encodeObject(activeCall, forKey: "activeCall")
        } else {
            encoder.encodeNil(forKey: "activeCall")
        }
        
        if let callJoinPeerId = self.callJoinPeerId {
            encoder.encodeInt64(callJoinPeerId.toInt64(), forKey: "callJoinPeerId")
        } else {
            encoder.encodeNil(forKey: "callJoinPeerId")
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
        switch self.linkedDiscussionPeerId {
        case .unknown:
            encoder.encodeNil(forKey: "dgi")
        case let .known(value):
            if let value = value {
                encoder.encodeInt64(value.toInt64(), forKey: "dgi")
            } else {
                encoder.encodeInt64(0, forKey: "dgi")
            }
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
        encoder.encodeObject(self.autoremoveTimeout, forKey: "artv")
        encoder.encodeInt32(self.statsDatacenterId, forKey: "sdi")
        
        if let invitedBy = self.invitedBy {
            encoder.encodeInt64(invitedBy.toInt64(), forKey: "invBy")
        } else {
            encoder.encodeNil(forKey: "invBy")
        }
        
        if let invitedOn = self.invitedOn {
            encoder.encodeInt32(invitedOn, forKey: "invOn")
        } else {
            encoder.encodeNil(forKey: "invOn")
        }
        
        if let photo = self.photo {
            encoder.encodeObject(photo, forKey: "ph")
        } else {
            encoder.encodeNil(forKey: "ph")
        }
        
        encoder.encodeStringArray(self.pendingSuggestions, forKey: "sug")
        
        if let themeEmoticon = self.themeEmoticon, !themeEmoticon.isEmpty {
            encoder.encodeString(themeEmoticon, forKey: "te")
        } else {
            encoder.encodeNil(forKey: "te")
        }
        
        if let inviteRequestsPending = self.inviteRequestsPending {
            encoder.encodeInt32(inviteRequestsPending, forKey: "irp")
        } else {
            encoder.encodeNil(forKey: "irp")
        }
        
        
        if let sendAsPeerId = self.sendAsPeerId {
            encoder.encodeInt64(sendAsPeerId.toInt64(), forKey: "sendAsPeerId")
        } else {
            encoder.encodeNil(forKey: "sendAsPeerId")
        }
        
        if let allowedReactions = self.allowedReactions {
            encoder.encodeStringArray(allowedReactions, forKey: "allowedReactions")
        } else {
            encoder.encodeNil(forKey: "allowedReactions")
        }
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
        
        if other.hasScheduledMessages != self.hasScheduledMessages {
            return false
        }
        
        if other.autoremoveTimeout != self.autoremoveTimeout {
            return false
        }
        
        if other.statsDatacenterId != self.statsDatacenterId {
            return false
        }
        
        if other.invitedBy != self.invitedBy {
            return false
        }
        
        if other.invitedOn != self.invitedOn {
            return false
        }
        
        if other.photo != self.photo {
            return false
        }
        
        if other.activeCall != self.activeCall {
            return false
        }
        
        if other.callJoinPeerId != self.callJoinPeerId {
            return false
        }
        
        if other.pendingSuggestions != self.pendingSuggestions {
            return false
        }
        
        if other.themeEmoticon != self.themeEmoticon {
            return false
        }
        
        if other.inviteRequestsPending != self.inviteRequestsPending {
            return false
        }
        
        if other.sendAsPeerId != self.sendAsPeerId {
            return false
        }
        
        if other.allowedReactions != self.allowedReactions {
            return false
        }
        
        return true
    }
}
