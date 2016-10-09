import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class CachedGroupData: CachedPeerData {
    public let participants: CachedGroupParticipants?
    public let exportedInvitation: ExportedInvitation?
    
    public let peerIds: Set<PeerId>
    
    public init(participants: CachedGroupParticipants?, exportedInvitation: ExportedInvitation?) {
        self.participants = participants
        self.exportedInvitation = exportedInvitation
        if let participants = participants {
            var peerIds = Set<PeerId>()
            for participant in participants.participants {
                peerIds.insert(participant.peerId)
            }
            self.peerIds = peerIds
        } else {
            self.peerIds = Set()
        }
    }
    
    public init(decoder: Decoder) {
        let participants = decoder.decodeObjectForKey("p", decoder: { CachedGroupParticipants(decoder: $0) }) as? CachedGroupParticipants
        self.participants = participants
        self.exportedInvitation = decoder.decodeObjectForKey("i", decoder: { ExportedInvitation(decoder: $0) }) as? ExportedInvitation
        if let participants = participants {
            var peerIds = Set<PeerId>()
            for participant in participants.participants {
                peerIds.insert(participant.peerId)
            }
            self.peerIds = peerIds
        } else {
            self.peerIds = Set()
        }
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
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedGroupData else {
            return false
        }
        
        return self.participants == other.participants && self.exportedInvitation == other.exportedInvitation
    }
}

extension CachedGroupData {
    convenience init?(apiChatFull: Api.ChatFull) {
        switch apiChatFull {
            case let .chatFull(_, apiParticipants, _, _, apiExportedInvite, _):
                self.init(participants: CachedGroupParticipants(apiParticipants: apiParticipants), exportedInvitation: ExportedInvitation(apiExportedInvite: apiExportedInvite))
                break
            case .channelFull:
                return nil
        }
    }
}
