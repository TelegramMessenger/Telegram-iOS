import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class CachedPeerBotInfo: Coding, Equatable {
    public let peerId: PeerId
    public let botInfo: BotInfo
    
    init(peerId: PeerId, botInfo: BotInfo) {
        self.peerId = peerId
        self.botInfo = botInfo
    }
    
    public init(decoder: Decoder) {
        self.peerId = PeerId(decoder.decodeInt64ForKey("p"))
        self.botInfo = decoder.decodeObjectForKey("i", decoder: { return BotInfo(decoder: $0) }) as! BotInfo
    }
    
    public func encode(_ encoder: Encoder) {
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
    
    public let peerIds: Set<PeerId>
    
    public init(participants: CachedGroupParticipants?, exportedInvitation: ExportedInvitation?, botInfos: [CachedPeerBotInfo]) {
        self.participants = participants
        self.exportedInvitation = exportedInvitation
        self.botInfos = botInfos
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
    
    public init(decoder: Decoder) {
        let participants = decoder.decodeObjectForKey("p", decoder: { CachedGroupParticipants(decoder: $0) }) as? CachedGroupParticipants
        self.participants = participants
        self.exportedInvitation = decoder.decodeObjectForKey("i", decoder: { ExportedInvitation(decoder: $0) }) as? ExportedInvitation
        self.botInfos = decoder.decodeObjectArrayWithDecoderForKey("b") as [CachedPeerBotInfo]
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
    
    public func encode(_ encoder: Encoder) {
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
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedGroupData else {
            return false
        }
        
        return self.participants == other.participants && self.exportedInvitation == other.exportedInvitation && self.botInfos == other.botInfos
    }
}

extension CachedGroupData {
    convenience init?(apiChatFull: Api.ChatFull) {
        switch apiChatFull {
            case let .chatFull(_, apiParticipants, _, _, apiExportedInvite, apiBotInfos):
                var botInfos: [CachedPeerBotInfo] = []
                for botInfo in apiBotInfos {
                    switch botInfo {
                        case let .botInfo(userId, _, _):
                            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)
                            let parsedBotInfo = BotInfo(apiBotInfo: botInfo)
                            botInfos.append(CachedPeerBotInfo(peerId: peerId, botInfo: parsedBotInfo))
                    }
                }
                self.init(participants: CachedGroupParticipants(apiParticipants: apiParticipants), exportedInvitation: ExportedInvitation(apiExportedInvite: apiExportedInvite), botInfos: botInfos)
                break
            case .channelFull:
                return nil
        }
    }
}
