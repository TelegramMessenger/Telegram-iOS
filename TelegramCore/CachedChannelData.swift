import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

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
}

public struct CachedChannelParticipantsSummary: Coding, Equatable {
    public let memberCount: Int32?
    public let adminCount: Int32?
    public let bannedCount: Int32?
    
    init(memberCount: Int32?, adminCount: Int32?, bannedCount: Int32?) {
        self.memberCount = memberCount
        self.adminCount = adminCount
        self.bannedCount = bannedCount
    }
    
    public init(decoder: Decoder) {
        if let memberCount = decoder.decodeInt32ForKey("p.m") as Int32? {
            self.memberCount = memberCount
        } else {
            self.memberCount = 0
        }
        if let adminCount = decoder.decodeInt32ForKey("p.a") as Int32? {
            self.adminCount = adminCount
        } else {
            self.adminCount = 0
        }
        if let bannedCount = decoder.decodeInt32ForKey("p.b") as Int32? {
            self.bannedCount = bannedCount
        } else {
            self.bannedCount = 0
        }
    }
    
    public func encode(_ encoder: Encoder) {
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
    }
    
    public static func ==(lhs: CachedChannelParticipantsSummary, rhs: CachedChannelParticipantsSummary) -> Bool {
        return lhs.memberCount == rhs.memberCount && lhs.adminCount == rhs.adminCount && lhs.bannedCount == rhs.bannedCount
    }
    
    public func withUpdatedMemberCount(_ memberCount: Int32?) -> CachedChannelParticipantsSummary {
        return CachedChannelParticipantsSummary(memberCount: memberCount, adminCount: self.adminCount, bannedCount: self.bannedCount)
    }
    
    public func withUpdatedAdminCount(_ adminCount: Int32?) -> CachedChannelParticipantsSummary {
        return CachedChannelParticipantsSummary(memberCount: self.memberCount, adminCount: adminCount, bannedCount: self.bannedCount)
    }
    
    public func withUpdatedBannedCount(_ bannedCount: Int32?) -> CachedChannelParticipantsSummary {
        return CachedChannelParticipantsSummary(memberCount: self.memberCount, adminCount: self.adminCount, bannedCount: bannedCount)
    }
}

public final class CachedChannelData: CachedPeerData {
    public let flags: CachedChannelFlags
    public let about: String?
    public let participantsSummary: CachedChannelParticipantsSummary
    public let exportedInvitation: ExportedInvitation?
    public let botInfos: [CachedPeerBotInfo]
    public let topParticipants: CachedChannelParticipants?
    public let reportStatus: PeerReportStatus
    public let pinnedMessageId: MessageId?
    
    public let peerIds: Set<PeerId>
    
    init() {
        self.flags = []
        self.about = nil
        self.participantsSummary = CachedChannelParticipantsSummary(memberCount: nil, adminCount: nil, bannedCount: nil)
        self.exportedInvitation = nil
        self.botInfos = []
        self.topParticipants = nil
        self.reportStatus = .unknown
        self.pinnedMessageId = nil
        self.peerIds = Set()
    }
    
    init(flags: CachedChannelFlags, about: String?, participantsSummary: CachedChannelParticipantsSummary, exportedInvitation: ExportedInvitation?, botInfos: [CachedPeerBotInfo], topParticipants: CachedChannelParticipants?, reportStatus: PeerReportStatus, pinnedMessageId: MessageId?) {
        self.flags = flags
        self.about = about
        self.participantsSummary = participantsSummary
        self.exportedInvitation = exportedInvitation
        self.botInfos = botInfos
        self.topParticipants = topParticipants
        self.reportStatus = reportStatus
        self.pinnedMessageId = pinnedMessageId
        
        var peerIds = Set<PeerId>()
        if let topParticipants = topParticipants {
            for participant in topParticipants.participants {
                peerIds.insert(participant.peerId)
            }
        }
        for botInfo in botInfos {
            peerIds.insert(botInfo.peerId)
        }
        self.peerIds = peerIds
    }
    
    func withUpdatedFlags(_ flags: CachedChannelFlags) -> CachedChannelData {
        return CachedChannelData(flags: flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, topParticipants: self.topParticipants, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId)
    }
    
    func withUpdatedAbout(_ about: String?) -> CachedChannelData {
        return CachedChannelData(flags: self.flags, about: about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, topParticipants: self.topParticipants, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId)
    }
    
    func withUpdatedParticipantsSummary(_ participantsSummary: CachedChannelParticipantsSummary) -> CachedChannelData {
        return CachedChannelData(flags: self.flags, about: self.about, participantsSummary: participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, topParticipants: self.topParticipants, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId)
    }
    
    func withUpdatedExportedInvitation(_ exportedInvitation: ExportedInvitation?) -> CachedChannelData {
        return CachedChannelData(flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: exportedInvitation, botInfos: self.botInfos, topParticipants: self.topParticipants, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId)
    }
    
    func withUpdatedBotInfos(_ botInfos: [CachedPeerBotInfo]) -> CachedChannelData {
        return CachedChannelData(flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: botInfos, topParticipants: self.topParticipants, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId)
    }
    
    func withUpdatedTopParticipants(_ topParticipants: CachedChannelParticipants?) -> CachedChannelData {
        return CachedChannelData(flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, topParticipants: topParticipants, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId)
    }
    
    func withUpdatedReportStatus(_ reportStatus: PeerReportStatus) -> CachedChannelData {
        return CachedChannelData(flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, topParticipants: self.topParticipants, reportStatus: reportStatus, pinnedMessageId: self.pinnedMessageId)
    }
    
    func withUpdatedPinnedMessageId(_ pinnedMessageId: MessageId?) -> CachedChannelData {
        return CachedChannelData(flags: self.flags, about: self.about, participantsSummary: self.participantsSummary, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, topParticipants: self.topParticipants, reportStatus: self.reportStatus, pinnedMessageId: pinnedMessageId)
    }
    
    public init(decoder: Decoder) {
        self.flags = CachedChannelFlags(rawValue: decoder.decodeInt32ForKey("f"))
        self.about = decoder.decodeStringForKey("a")
        self.participantsSummary = CachedChannelParticipantsSummary(decoder: decoder)
        self.exportedInvitation = decoder.decodeObjectForKey("i", decoder: { ExportedInvitation(decoder: $0) }) as? ExportedInvitation
        self.botInfos = decoder.decodeObjectArrayWithDecoderForKey("b") as [CachedPeerBotInfo]
        var peerIds = Set<PeerId>()
        self.topParticipants = decoder.decodeObjectForKey("p", decoder: { CachedChannelParticipants(decoder: $0) }) as? CachedChannelParticipants
        self.reportStatus = PeerReportStatus(rawValue: decoder.decodeInt32ForKey("r"))!
        if let pinnedMessagePeerId = (decoder.decodeInt64ForKey("pm.p") as Int64?), let pinnedMessageNamespace = (decoder.decodeInt32ForKey("pm.n") as Int32?), let pinnedMessageId = (decoder.decodeInt32ForKey("pm.i") as Int32?) {
            self.pinnedMessageId = MessageId(peerId: PeerId(pinnedMessagePeerId), namespace: pinnedMessageNamespace, id: pinnedMessageId)
        } else {
            self.pinnedMessageId = nil
        }
        
        if let topParticipants = self.topParticipants {
            for participant in topParticipants.participants {
                peerIds.insert(participant.peerId)
            }
        }
        for botInfo in self.botInfos {
            peerIds.insert(botInfo.peerId)
        }
        
        self.peerIds = peerIds
    }
    
    public func encode(_ encoder: Encoder) {
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
        if let topParticipants = self.topParticipants {
            encoder.encodeObject(topParticipants, forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
        encoder.encodeInt32(self.reportStatus.rawValue, forKey: "r")
        if let pinnedMessageId = self.pinnedMessageId {
            encoder.encodeInt64(pinnedMessageId.peerId.toInt64(), forKey: "pm.p")
            encoder.encodeInt32(pinnedMessageId.namespace, forKey: "pm.n")
            encoder.encodeInt32(pinnedMessageId.id, forKey: "pm.i")
        } else {
            encoder.encodeNil(forKey: "pm.p")
            encoder.encodeNil(forKey: "pm.n")
            encoder.encodeNil(forKey: "pm.i")
        }
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedChannelData else {
            return false
        }
        
        if other.flags != self.flags {
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
        
        if other.topParticipants != self.topParticipants {
            return false
        }
        
        if other.reportStatus != self.reportStatus {
            return false
        }
        
        if other.pinnedMessageId != self.pinnedMessageId {
            return false
        }
        
        return true
    }
}
