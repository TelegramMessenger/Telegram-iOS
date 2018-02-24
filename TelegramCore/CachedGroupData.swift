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

public final class CachedGroupData: CachedPeerData {
    public let participants: CachedGroupParticipants?
    public let exportedInvitation: ExportedInvitation?
    public let botInfos: [CachedPeerBotInfo]
    public let reportStatus: PeerReportStatus
    
    public let peerIds: Set<PeerId>
    public let messageIds = Set<MessageId>()
    public let associatedHistoryMessageId: MessageId? = nil
    
    init() {
        self.participants = nil
        self.exportedInvitation = nil
        self.botInfos = []
        self.reportStatus = .unknown
        self.peerIds = Set()
    }
    
    public init(participants: CachedGroupParticipants?, exportedInvitation: ExportedInvitation?, botInfos: [CachedPeerBotInfo], reportStatus: PeerReportStatus) {
        self.participants = participants
        self.exportedInvitation = exportedInvitation
        self.botInfos = botInfos
        self.reportStatus = reportStatus
        
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
        self.reportStatus = PeerReportStatus(rawValue: decoder.decodeInt32ForKey("r", orElse: 0))!
        
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
        encoder.encodeInt32(self.reportStatus.rawValue, forKey: "r")
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedGroupData else {
            return false
        }
        
        return self.participants == other.participants && self.exportedInvitation == other.exportedInvitation && self.botInfos == other.botInfos && self.reportStatus == other.reportStatus
    }
    
    func withUpdatedParticipants(_ participants: CachedGroupParticipants?) -> CachedGroupData {
        return CachedGroupData(participants: participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, reportStatus: self.reportStatus)
    }
    
    func withUpdatedExportedInvitation(_ exportedInvitation: ExportedInvitation?) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: exportedInvitation, botInfos: self.botInfos, reportStatus: self.reportStatus)
    }
    
    func withUpdatedBotInfos(_ botInfos: [CachedPeerBotInfo]) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: botInfos, reportStatus: self.reportStatus)
    }
    
    func withUpdatedReportStatus(_ reportStatus: PeerReportStatus) -> CachedGroupData {
        return CachedGroupData(participants: self.participants, exportedInvitation: self.exportedInvitation, botInfos: self.botInfos, reportStatus: reportStatus)
    }
}
