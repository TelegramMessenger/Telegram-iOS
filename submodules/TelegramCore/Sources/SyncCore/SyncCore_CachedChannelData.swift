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
    public static let antiSpamEnabled = CachedChannelFlags(rawValue: 1 << 7)
    public static let translationHidden = CachedChannelFlags(rawValue: 1 << 8)
    public static let adsRestricted = CachedChannelFlags(rawValue: 1 << 9)
    public static let canViewRevenue = CachedChannelFlags(rawValue: 1 << 10)
    public static let paidMediaAllowed = CachedChannelFlags(rawValue: 1 << 11)
    public static let canViewStarsRevenue = CachedChannelFlags(rawValue: 1 << 12)
    public static let starGiftsAvailable = CachedChannelFlags(rawValue: 1 << 13)
    public static let paidMessagesAvailable = CachedChannelFlags(rawValue: 1 << 14)
}

public struct CachedChannelParticipantsSummary: PostboxCoding, Equatable {
    public var memberCount: Int32?
    public var adminCount: Int32?
    public var bannedCount: Int32?
    public var kickedCount: Int32?
    
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

public struct PeerMembersHidden: Codable, Equatable {
    public var value: Bool
    
    public init(value: Bool) {
        self.value = value
    }
}

private struct PeerViewForumAsMessages: Codable {
    public var value: Bool
    
    public init(value: Bool) {
        self.value = value
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
    public let reactionSettings: EnginePeerCachedInfoItem<PeerReactionSettings>
    public let membersHidden: EnginePeerCachedInfoItem<PeerMembersHidden>
    public let viewForumAsMessages: EnginePeerCachedInfoItem<Bool>
    public let wallpaper: TelegramWallpaper?
    public let boostsToUnrestrict: Int32?
    public let appliedBoosts: Int32?
    public let emojiPack: StickerPackCollectionInfo?
    public let verification: PeerVerification?
    public let starGiftsCount: Int32?
    public let sendPaidMessageStars: StarsAmount?
    
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
        self.reactionSettings = .unknown
        self.membersHidden = .unknown
        self.viewForumAsMessages = .unknown
        self.wallpaper = nil
        self.boostsToUnrestrict = nil
        self.appliedBoosts = nil
        self.emojiPack = nil
        self.verification = nil
        self.starGiftsCount = nil
        self.sendPaidMessageStars = nil
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
        reactionSettings: EnginePeerCachedInfoItem<PeerReactionSettings>,
        membersHidden: EnginePeerCachedInfoItem<PeerMembersHidden>,
        viewForumAsMessages: EnginePeerCachedInfoItem<Bool>,
        wallpaper: TelegramWallpaper?,
        boostsToUnrestrict: Int32?,
        appliedBoosts: Int32?,
        emojiPack: StickerPackCollectionInfo?,
        verification: PeerVerification?,
        starGiftsCount: Int32?,
        sendPaidMessageStars: StarsAmount?
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
        self.reactionSettings = reactionSettings
        self.membersHidden = membersHidden
        self.viewForumAsMessages = viewForumAsMessages
        self.wallpaper = wallpaper
        self.boostsToUnrestrict = boostsToUnrestrict
        self.appliedBoosts = appliedBoosts
        self.emojiPack = emojiPack
        self.verification = verification
        self.starGiftsCount = starGiftsCount
        self.sendPaidMessageStars = sendPaidMessageStars
        
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
        return CachedChannelData(isNotAccessible: isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedFlags(_ flags: CachedChannelFlags) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedAbout(_ about: String?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedParticipantsSummary(_ participantsSummary: CachedChannelParticipantsSummary) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedExportedInvitation(_ exportedInvitation: ExportedInvitation?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedBotInfos(_ botInfos: [CachedPeerBotInfo]) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedPeerStatusSettings(_ peerStatusSettings: PeerStatusSettings?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedStickerPack(_ stickerPack: StickerPackCollectionInfo?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedMinAvailableMessageId(_ minAvailableMessageId: MessageId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedMigrationReference(_ migrationReference: ChannelMigrationReference?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedLinkedDiscussionPeerId(_ linkedDiscussionPeerId: LinkedDiscussionPeerId) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedPeerGeoLocation(_ peerGeoLocation: PeerGeoLocation?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }

    public func withUpdatedSlowModeTimeout(_ slowModeTimeout: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedSlowModeValidUntilTimestamp(_ slowModeValidUntilTimestamp: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedHasScheduledMessages(_ hasScheduledMessages: Bool) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedStatsDatacenterId(_ statsDatacenterId: Int32) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedInvitedBy(_ invitedBy: PeerId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedInvitedOn(_ invitedOn: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedPhoto(_ photo: TelegramMediaImage?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedActiveCall(_ activeCall: ActiveCall?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedCallJoinPeerId(_ callJoinPeerId: PeerId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedAutoremoveTimeout(_ autoremoveTimeout: CachedPeerAutoremoveTimeout) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: autoremoveTimeout, pendingSuggestions: self.pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedPendingSuggestions(_ pendingSuggestions: [String]) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedThemeEmoticon(_ themeEmoticon: String?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedInviteRequestsPending(_ inviteRequestsPending: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedSendAsPeerId(_ sendAsPeerId: PeerId?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedReactionSettings(_ reactionSettings: EnginePeerCachedInfoItem<PeerReactionSettings>) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedMembersHidden(_ membersHidden: EnginePeerCachedInfoItem<PeerMembersHidden>) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedViewForumAsMessages(_ viewForumAsMessages: EnginePeerCachedInfoItem<Bool>) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedWallpaper(_ wallpaper: TelegramWallpaper?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedBoostsToUnrestrict(_ boostsToUnrestrict: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedAppliedBoosts(_ appliedBoosts: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedEmojiPack(_ emojiPack: StickerPackCollectionInfo?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedVerification(_ verification: PeerVerification?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedStarGiftsCount(_ starGiftsCount: Int32?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: starGiftsCount, sendPaidMessageStars: self.sendPaidMessageStars)
    }
    
    public func withUpdatedSendPaidMessageStars(_ sendPaidMessageStars: StarsAmount?) -> CachedChannelData {
        return CachedChannelData(isNotAccessible: self.isNotAccessible, flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, stickerPack: self.stickerPack, minAvailableMessageId: self.minAvailableMessageId, migrationReference: self.migrationReference, linkedDiscussionPeerId: self.linkedDiscussionPeerId, peerGeoLocation: self.peerGeoLocation, slowModeTimeout: self.slowModeTimeout, slowModeValidUntilTimestamp: self.slowModeValidUntilTimestamp, hasScheduledMessages: self.hasScheduledMessages, statsDatacenterId: self.statsDatacenterId, invitedBy: self.invitedBy, invitedOn: self.invitedOn, photo: self.photo, activeCall: self.activeCall, callJoinPeerId: self.callJoinPeerId, autoremoveTimeout: self.autoremoveTimeout, pendingSuggestions: pendingSuggestions, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, sendAsPeerId: self.sendAsPeerId, reactionSettings: self.reactionSettings, membersHidden: self.membersHidden, viewForumAsMessages: self.viewForumAsMessages, wallpaper: self.wallpaper, boostsToUnrestrict: self.boostsToUnrestrict, appliedBoosts: self.appliedBoosts, emojiPack: self.emojiPack, verification: self.verification, starGiftsCount: self.starGiftsCount, sendPaidMessageStars: sendPaidMessageStars)
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
            self.peerStatusSettings = PeerStatusSettings(flags: PeerStatusSettings.Flags(rawValue: legacyValue), geoDistance: nil, managingBot: nil)
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
        
        if let reactionSettings = decoder.decode(PeerReactionSettings.self, forKey: "reactionSettings") {
            self.reactionSettings = .known(reactionSettings)
        } else if let legacyAllowedReactions = decoder.decodeOptionalStringArrayForKey("allowedReactions") {
            let allowedReactions: PeerAllowedReactions = .limited(legacyAllowedReactions.map(MessageReaction.Reaction.builtin))
            self.reactionSettings = .known(PeerReactionSettings(allowedReactions: allowedReactions, maxReactionCount: nil, starsAllowed: nil))
        } else if let allowedReactions = decoder.decode(PeerAllowedReactions.self, forKey: "allowedReactionSet") {
            let allowedReactions = allowedReactions
            self.reactionSettings = .known(PeerReactionSettings(allowedReactions: allowedReactions, maxReactionCount: nil, starsAllowed: nil))
        } else {
            self.reactionSettings = .unknown
        }
        
        if let membersHidden = decoder.decode(PeerMembersHidden.self, forKey: "membersHidden") {
            self.membersHidden = .known(membersHidden)
        } else {
            self.membersHidden = .unknown
        }
        
        if let viewForumAsMessages = decoder.decode(PeerViewForumAsMessages.self, forKey: "viewForumAsMessages") {
            self.viewForumAsMessages = .known(viewForumAsMessages.value)
        } else {
            self.viewForumAsMessages = .unknown
        }
        
        self.wallpaper = decoder.decode(TelegramWallpaperNativeCodable.self, forKey: "wp")?.value
        
        if case let .known(linkedDiscussionPeerIdValue) = self.linkedDiscussionPeerId {
            if let linkedDiscussionPeerIdValue = linkedDiscussionPeerIdValue {
                peerIds.insert(linkedDiscussionPeerIdValue)
            }
        }
        
        self.boostsToUnrestrict = decoder.decodeOptionalInt32ForKey("bu")
        
        self.appliedBoosts = decoder.decodeOptionalInt32ForKey("ab")
        
        if let emojiPack = decoder.decodeObjectForKey("ep", decoder: { StickerPackCollectionInfo(decoder: $0) }) as? StickerPackCollectionInfo {
            self.emojiPack = emojiPack
        } else {
            self.emojiPack = nil
        }
        
        self.starGiftsCount = decoder.decodeOptionalInt32ForKey("starGiftsCount")
        
        self.verification = decoder.decodeCodable(PeerVerification.self, forKey: "vf")
        
        self.sendPaidMessageStars = decoder.decodeCodable(StarsAmount.self, forKey: "sendPaidMessageStars")
        
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
        
        switch self.reactionSettings {
        case .unknown:
            encoder.encodeNil(forKey: "reactionSettings")
        case let .known(value):
            encoder.encode(value, forKey: "reactionSettings")
        }
        
        switch self.membersHidden {
        case .unknown:
            encoder.encodeNil(forKey: "membersHidden")
        case let .known(value):
            encoder.encode(value, forKey: "membersHidden")
        }
        
        switch self.viewForumAsMessages {
        case .unknown:
            encoder.encodeNil(forKey: "viewForumAsMessages")
        case let .known(value):
            encoder.encode(PeerViewForumAsMessages(value: value), forKey: "viewForumAsMessages")
        }
        
        if let wallpaper = self.wallpaper {
            encoder.encode(TelegramWallpaperNativeCodable(wallpaper), forKey: "wp")
        } else {
            encoder.encodeNil(forKey: "wp")
        }
        
        if let boostsToUnrestrict = self.boostsToUnrestrict {
            encoder.encodeInt32(boostsToUnrestrict, forKey: "bu")
        } else {
            encoder.encodeNil(forKey: "bu")
        }
        
        if let appliedBoosts = self.appliedBoosts {
            encoder.encodeInt32(appliedBoosts, forKey: "ab")
        } else {
            encoder.encodeNil(forKey: "ab")
        }
        
        if let emojiPack = self.emojiPack {
            encoder.encodeObject(emojiPack, forKey: "ep")
        } else {
            encoder.encodeNil(forKey: "ep")
        }
        
        if let verification = self.verification {
            encoder.encodeCodable(verification, forKey: "vf")
        } else {
            encoder.encodeNil(forKey: "vf")
        }
        
        if let starGiftsCount = self.starGiftsCount {
            encoder.encodeInt32(starGiftsCount, forKey: "starGiftsCount")
        } else {
            encoder.encodeNil(forKey: "starGiftsCount")
        }
        
        if let sendPaidMessageStars = self.sendPaidMessageStars {
            encoder.encodeCodable(sendPaidMessageStars, forKey: "sendPaidMessageStars")
        } else {
            encoder.encodeNil(forKey: "sendPaidMessageStars")
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
        
        if other.reactionSettings != self.reactionSettings {
            return false
        }
        
        if other.membersHidden != self.membersHidden {
            return false
        }
        
        if other.viewForumAsMessages != self.viewForumAsMessages {
            return false
        }
        
        if other.wallpaper != self.wallpaper {
            return false
        }
        
        if other.boostsToUnrestrict != self.boostsToUnrestrict {
            return false
        }
        
        if other.appliedBoosts != self.appliedBoosts {
            return false
        }
        
        if other.emojiPack != self.emojiPack {
            return false
        }
        
        if other.verification != self.verification {
            return false
        }
        
        if other.sendPaidMessageStars != self.sendPaidMessageStars {
            return false
        }
                
        return true
    }
}
