import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class CachedPeerBotInfo: PostboxCoding, Equatable {
    public let peerId: PeerId
    public let botInfo: BotInfo
    
    init(peerId: PeerId, botInfo: BotInfo) {
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
    public let peerContactSettings: PeerContactSettings?
    public let pinnedMessageId: MessageId?
    public let about: String?
    public let flags: CachedGroupFlags
    
    public let peerIds: Set<PeerId>
    public let messageIds: Set<MessageId>
    public let associatedHistoryMessageId: MessageId? = nil
    
    init() {
        self.participants = nil
        self.exportedInvitation = nil
        self.botInfos = []
        self.peerContactSettings = nil
        self.pinnedMessageId = nil
        self.messageIds = Set()
        self.peerIds = Set()
        self.about = nil
        self.flags = CachedGroupFlags()
    }
    
    public init(participants: CachedGroupParticipants?, exportedInvitation: ExportedInvitation?, botInfos: [CachedPeerBotInfo], peerContactSettings: PeerContactSettings?, pinnedMessageId: MessageId?, about: String?, flags: CachedGroupFlags) {
        self.participants = participants
        self.exportedInvitation = exportedInvitation
        self.botInfos = botInfos
        self.peerContactSettings = peerContactSettings
        self.pinnedMessageId = pinnedMessageId
        self.about = about
        self.flags = flags
        
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
        self.peerIds = peerIds
    }
    
    public init(decoder: PostboxDecoder) {
        let participants = decoder.decodeObjectForKey("p", decoder: { CachedGroupParticipants(decoder: $0) }) as? CachedGroupParticipants
        self.participants = participants
        self.exportedInvitation = decoder.decodeObjectForKey("i", decoder: { ExportedInvitation(decoder: $0) }) as? ExportedInvitation
        self.botInfos = decoder.decodeObjectArrayWithDecoderForKey("b") as [CachedPeerBotInfo]
        if let value = decoder.decodeOptionalInt32ForKey("pcs") {
            self.peerContactSettings = PeerContactSettings(rawValue: value)
        } else {
            self.peerContactSettings = nil
        }
        if let pinnedMessagePeerId = decoder.decodeOptionalInt64ForKey("pm.p"), let pinnedMessageNamespace = decoder.decodeOptionalInt32ForKey("pm.n"), let pinnedMessageId = decoder.decodeOptionalInt32ForKey("pm.i") {
            self.pinnedMessageId = MessageId(peerId: PeerId(pinnedMessagePeerId), namespace: pinnedMessageNamespace, id: pinnedMessageId)
        } else {
            self.pinnedMessageId = nil
        }
        self.about = decoder.decodeOptionalStringForKey("ab")
        self.flags = CachedGroupFlags(rawValue: decoder.decodeInt32ForKey("fl", orElse: 0))
        
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
            encoder.encodeObject(exportedInvitation, forKey: "i")
        } else {
            encoder.encodeNil(forKey: "i")
        }
        encoder.encodeObjectArray(self.botInfos, forKey: "b")
        if let peerContactSettings = self.peerContactSettings {
            encoder.encodeInt32(peerContactSettings.rawValue, forKey: "pcs")
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
        if let about = self.about {
            encoder.encodeString(about, forKey: "ab")
        } else {
            encoder.encodeNil(forKey: "ab")
        }
        encoder.encodeInt32(self.flags.rawValue, forKey: "fl")
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedGroupData else {
            return false
        }
        
        return self.participants == other.participants && self.exportedInvitation == other.exportedInvitation && self.botInfos == other.botInfos && self.peerContactSettings == other.peerContactSettings && self.pinnedMessageId == other.pinnedMessageId && self.about == other.about && self.flags == other.flags
    }
    
    func withUpdatedParticipants(_ participants: CachedGroupParticipants?) -> CachedGroupData {
        return CachedGroupData(participants: participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerContactSettings: self.peerContactSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags)
    }
    
    func withUpdatedExportedInvitation(_ exportedInvitation: ExportedInvitation?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: exportedInvitation, botInfos: self.botInfos, peerContactSettings: self.peerContactSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags)
    }
    
    func withUpdatedBotInfos(_ botInfos: [CachedPeerBotInfo]) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: botInfos, peerContactSettings: self.peerContactSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags)
    }
    
    func withUpdatedPeerContactSettings(_ peerContactSettings: PeerContactSettings?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerContactSettings: peerContactSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: self.flags)
    }

    func withUpdatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerContactSettings: self.peerContactSettings, pinnedMessageId: pinnedMessageId, about: self.about, flags: self.flags)
    }
    
    func withUpdatedAbout(_ about: String?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerContactSettings: self.peerContactSettings, pinnedMessageId: self.pinnedMessageId, about: about, flags: self.flags)
    }
    
    func withUpdatedFlags(_ flags: CachedGroupFlags) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, peerContactSettings: self.peerContactSettings, pinnedMessageId: self.pinnedMessageId, about: self.about, flags: flags)
    }
}
