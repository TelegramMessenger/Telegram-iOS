import Foundation
import Postbox

public final class CachedPeerBotInfo: PostboxCoding, Equatable {
    public let peerId: PeerId
    public let botInfo: BotInfo
    
    public init(peerId: PeerId, botInfo: BotInfo) {
        self.peerId = peerId
        self.botInfo = botInfo
    }
    
    public init(decoder: PostboxDecoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        self.botInfo = decoder.decodeObjectForKey("i", decoder: { return BotInfo(decoder: $0) }) as! BotInfo
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.peerId.toInt64(), forKey: "p")
        encoder.encodeObject(self.botInfo, forKey: "i")
    }
    
    public static func ==(lhs: CachedPeerBotInfo, rhs: CachedPeerBotInfo) -> Bool {
        return lhs.peerId == rhs.peerId && lhs.botInfo == rhs.botInfo
    }
}

public struct CachedGroupFlags: OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let canChangeUsername = CachedGroupFlags(rawValue: 1 << 0)
}

public final class CachedGroupData: CachedPeerData {
    public let participants: CachedGroupParticipants?
    public let exportedInvitation: ExportedInvitation?
    public let botInfos: [CachedPeerBotInfo]
    public let peerStatusSettings: PeerStatusSettings?
    public let pinnedMessageId: MessageId?
    public let about: String?
    public let flags: CachedGroupFlags
    public let hasScheduledMessages: Bool
    public let invitedBy: PeerId?
    public let photo: TelegramMediaImage?
    public let autoremoveTimeout: CachedPeerAutoremoveTimeout
    public let activeCall: CachedChannelData.ActiveCall?
    public let callJoinPeerId: PeerId?
    public let themeEmoticon: String?
    public let inviteRequestsPending: Int32?
    public let allowedReactions: [String]?
    
    public let peerIds: Set<PeerId>
    public let messageIds: Set<MessageId>
    public let associatedHistoryMessageId: MessageId? = nil
    
    public init() {
        self.participants = nil
        self.exportedInvitation = nil
        self.botInfos = []
        self.peerStatusSettings = nil
        self.pinnedMessageId = nil
        self.messageIds = Set()
        self.peerIds = Set()
        self.about = nil
        self.flags = CachedGroupFlags()
        self.hasScheduledMessages = false
        self.invitedBy = nil
        self.photo = nil
        self.autoremoveTimeout = .unknown
        self.activeCall = nil
        self.callJoinPeerId = nil
        self.themeEmoticon = nil
        self.inviteRequestsPending = nil
        self.allowedReactions = nil
    }
    
    public init(
        participants: CachedGroupParticipants?,
        exportedInvitation: ExportedInvitation?,
        botInfos: [CachedPeerBotInfo],
        peerStatusSettings: PeerStatusSettings?,
        pinnedMessageId: MessageId?,
        about: String?,
        flags: CachedGroupFlags,
        hasScheduledMessages: Bool,
        invitedBy: PeerId?,
        photo: TelegramMediaImage?,
        activeCall: CachedChannelData.ActiveCall?,
        autoremoveTimeout: CachedPeerAutoremoveTimeout,
        callJoinPeerId: PeerId?,
        themeEmoticon: String?,
        inviteRequestsPending: Int32?,
        allowedReactions: [String]?
    ) {
        self.participants = participants
        self.exportedInvitation = exportedInvitation
        self.botInfos = botInfos
        self.peerStatusSettings = peerStatusSettings
        self.pinnedMessageId = pinnedMessageId
        self.about = about
        self.flags = flags
        self.hasScheduledMessages = hasScheduledMessages
        self.invitedBy = invitedBy
        self.photo = photo
        self.activeCall = activeCall
        self.autoremoveTimeout = autoremoveTimeout
        self.callJoinPeerId = callJoinPeerId
        self.themeEmoticon = themeEmoticon
        self.inviteRequestsPending = inviteRequestsPending
        self.allowedReactions = allowedReactions
        
        var messageIds = Set<MessageId>()
        if let pinnedMessageId = self.pinnedMessageId {
            messageIds.insert(pinnedMessageId)
        }
        self.messageIds = messageIds
        
        var peerIds = Set<PeerId>()
        if let participants = participants {
            for participant in participants.participants {
                peerIds.insert(participant.peerId)
            }
        }
        for botInfo in botInfos {
            peerIds.insert(botInfo.peerId)
        }
        if let invitedBy = invitedBy {
            peerIds.insert(invitedBy)
        }
        self.peerIds = peerIds
    }
    
    public init(decoder: PostboxDecoder) {
        let participants = decoder.decodeObjectForKey("p", decoder: { CachedGroupParticipants(decoder: $0) }) as? CachedGroupParticipants
        self.participants = participants
        self.exportedInvitation = decoder.decode(ExportedInvitation.self, forKey: "i")
        self.botInfos = decoder.decodeObjectArrayWithDecoderForKey("b") as [CachedPeerBotInfo]
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
        self.about = decoder.decodeOptionalStringForKey("ab")
        self.flags = CachedGroupFlags(rawValue: decoder.decodeInt32ForKey("fl", orElse: 0))
        self.hasScheduledMessages = decoder.decodeBoolForKey("hsm", orElse: false)
        self.autoremoveTimeout = decoder.decodeObjectForKey("artv", decoder: CachedPeerAutoremoveTimeout.init(decoder:)) as? CachedPeerAutoremoveTimeout ?? .unknown
        
        self.invitedBy = decoder.decodeOptionalInt64ForKey("invBy").flatMap(PeerId.init)
        
        if let photo = decoder.decodeObjectForKey("ph", decoder: { TelegramMediaImage(decoder: $0) }) as? TelegramMediaImage {
            self.photo = photo
        } else {
            self.photo = nil
        }
            
        if let activeCall = decoder.decodeObjectForKey("activeCall", decoder: { CachedChannelData.ActiveCall(decoder: $0) }) as? CachedChannelData.ActiveCall {
            self.activeCall = activeCall
        } else {
            self.activeCall = nil
        }
        
        self.callJoinPeerId = decoder.decodeOptionalInt64ForKey("callJoinPeerId").flatMap(PeerId.init)
        
        self.themeEmoticon = decoder.decodeOptionalStringForKey("te")
        
        self.inviteRequestsPending = decoder.decodeOptionalInt32ForKey("irp")
        
        self.allowedReactions = decoder.decodeOptionalStringArrayForKey("allowedReactions")
        
        var messageIds = Set<MessageId>()
        if let pinnedMessageId = self.pinnedMessageId {
            messageIds.insert(pinnedMessageId)
        }
        self.messageIds = messageIds
        
        var peerIds = Set<PeerId>()
        if let participants = participants {
            for participant in participants.participants {
                peerIds.insert(participant.peerId)
            }
        }
        for botInfo in self.botInfos {
            peerIds.insert(botInfo.peerId)
        }
        
        self.peerIds = peerIds
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let participants = self.participants {
            encoder.encodeObject(participants, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
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
        if let about = self.about {
            encoder.encodeString(about, forKey: "ab")
        } else {
            encoder.encodeNil(forKey: "ab")
        }
        encoder.encodeInt32(self.flags.rawValue, forKey: "fl")
        encoder.encodeBool(self.hasScheduledMessages, forKey: "hsm")
        encoder.encodeObject(self.autoremoveTimeout, forKey: "artv")
        
        if let invitedBy = self.invitedBy {
            encoder.encodeInt64(invitedBy.toInt64(), forKey: "invBy")
        } else {
            encoder.encodeNil(forKey: "invBy")
        }
        
        if let photo = self.photo {
            encoder.encodeObject(photo, forKey: "ph")
        } else {
            encoder.encodeNil(forKey: "ph")
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
        
        if let allowedReactions = self.allowedReactions {
            encoder.encodeStringArray(allowedReactions, forKey: "allowedReactions")
        } else {
            encoder.encodeNil(forKey: "allowedReactions")
        }
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedGroupData else {
            return false
        }
        
        if self.activeCall != other.activeCall {
            return false
        }
        
        if self.callJoinPeerId != other.callJoinPeerId {
            return false
        }
        
        if self.allowedReactions != other.allowedReactions {
            return false
        }
        
        return self.participants == other.participants && self.exportedInvitation == other.exportedInvitation && self.botInfos == other.botInfos && self.peerStatusSettings == other.peerStatusSettings && self.pinnedMessageId == other.pinnedMessageId && self.about == other.about && self.flags == other.flags && self.hasScheduledMessages == other.hasScheduledMessages && self.autoremoveTimeout == other.autoremoveTimeout && self.invitedBy == other.invitedBy && self.themeEmoticon == other.themeEmoticon && self.inviteRequestsPending == other.inviteRequestsPending
    }
    
    public func withUpdatedParticipants(_ participants: CachedGroupParticipants?) -> CachedGroupData {
        return CachedGroupData(participants: participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedExportedInvitation(_ exportedInvitation: ExportedInvitation?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedBotInfos(_ botInfos: [CachedPeerBotInfo]) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedPeerStatusSettings(_ peerStatusSettings: PeerStatusSettings?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }

    public func withUpdatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedAbout(_ about: String?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedFlags(_ flags: CachedGroupFlags) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedHasScheduledMessages(_ hasScheduledMessages: Bool) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedInvitedBy(_ invitedBy: PeerId?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedPhoto(_ photo: TelegramMediaImage?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedActiveCall(_ activeCall: CachedChannelData.ActiveCall?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedAutoremoveTimeout(_ autoremoveTimeout: CachedPeerAutoremoveTimeout) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedCallJoinPeerId(_ callJoinPeerId: PeerId?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedThemeEmoticon(_ themeEmoticon: String?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedInviteRequestsPending(_ inviteRequestsPending: Int32?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: inviteRequestsPending, allowedReactions: self.allowedReactions)
    }
    
    public func withUpdatedAllowedReactions(_ allowedReactions: [String]?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerStatusSettings: self.peerStatusSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags, hasScheduledMessages: self.hasScheduledMessages, invitedBy: self.invitedBy, photo: self.photo, activeCall: self.activeCall, autoremoveTimeout: self.autoremoveTimeout, callJoinPeerId: self.callJoinPeerId, themeEmoticon: self.themeEmoticon, inviteRequestsPending: self.inviteRequestsPending, allowedReactions: allowedReactions)
    }
}
