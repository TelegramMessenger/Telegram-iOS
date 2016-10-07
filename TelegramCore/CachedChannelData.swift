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
    public let memberCount: Int?
    public let adminCount: Int?
    public let bannedCount: Int?
    
    init(memberCount: Int?, adminCount: Int?, bannedCount: Int?) {
        self.memberCount = memberCount
        self.adminCount = adminCount
        self.bannedCount = bannedCount
    }
    
    public init(decoder: Decoder) {
        if let memberCount = decoder.decodeInt32ForKey("p.m") as Int32? {
            self.memberCount = Int(memberCount)
        } else {
            self.memberCount = 0
        }
        if let adminCount = decoder.decodeInt32ForKey("p.a") as Int32? {
            self.adminCount = Int(adminCount)
        } else {
            self.adminCount = 0
        }
        if let bannedCount = decoder.decodeInt32ForKey("p.b") as Int32? {
            self.bannedCount = Int(bannedCount)
        } else {
            self.bannedCount = 0
        }
    }
    
    public func encode(_ encoder: Encoder) {
        if let memberCount = self.memberCount {
            encoder.encodeInt32(Int32(memberCount), forKey: "p.m")
        } else {
            encoder.encodeNil(forKey: "p.m")
        }
        if let adminCount = self.adminCount {
            encoder.encodeInt32(Int32(adminCount), forKey: "p.a")
        } else {
            encoder.encodeNil(forKey: "p.a")
        }
        if let bannedCount = self.bannedCount {
            encoder.encodeInt32(Int32(bannedCount), forKey: "p.b")
        } else {
            encoder.encodeNil(forKey: "p.b")
        }
    }
    
    public static func ==(lhs: CachedChannelParticipantsSummary, rhs: CachedChannelParticipantsSummary) -> Bool {
        return lhs.memberCount == rhs.memberCount && lhs.adminCount == rhs.adminCount && lhs.bannedCount == rhs.bannedCount
    }
}

public final class CachedChannelData: CachedPeerData {
    public let flags: CachedChannelFlags
    public let about: String?
    public let participantsSummary: CachedChannelParticipantsSummary
    public let exportedInvitation: ExportedInvitation?
    
    public let peerIds: Set<PeerId> = Set<PeerId>()
    
    init(flags: CachedChannelFlags, about: String?, participantsSummary: CachedChannelParticipantsSummary, exportedInvitation: ExportedInvitation?) {
        self.flags = flags
        self.about = about
        self.participantsSummary = participantsSummary
        self.exportedInvitation = exportedInvitation
    }
    
    public init(decoder: Decoder) {
        self.flags = CachedChannelFlags(rawValue: decoder.decodeInt32ForKey("f"))
        self.about = decoder.decodeStringForKey("a")
        self.participantsSummary = CachedChannelParticipantsSummary(decoder: decoder)
        self.exportedInvitation = decoder.decodeObjectForKey("i", decoder: { ExportedInvitation(decoder: $0) }) as? ExportedInvitation
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
        
        return true
    }
}

extension CachedChannelData {
    convenience init?(apiChatFull: Api.ChatFull) {
        switch apiChatFull {
            case let .channelFull(flags, _, about, participantsCount, adminsCount, kickedCount, _, _, _, _, _, apiExportedInvite, _, migratedFromChatId, _, pinnedMsgId):
                var channelFlags = CachedChannelFlags()
                if (flags & (1 << 3)) != 0 {
                    channelFlags.insert(.canDisplayParticipants)
                }
                if (flags & (1 << 6)) != 0 {
                    channelFlags.insert(.canChangeUsername)
                }
                var intParticipantsCount: Int?
                if let participantsCount = participantsCount {
                    intParticipantsCount = Int(participantsCount)
                }
                var intAdminsCount: Int?
                if let adminsCount = adminsCount {
                    intAdminsCount = Int(adminsCount)
                }
                var intKickedCount: Int?
                if let kickedCount = kickedCount {
                    intKickedCount = Int(kickedCount)
                }
                self.init(flags: channelFlags, about: about, participantsSummary: CachedChannelParticipantsSummary(memberCount: intParticipantsCount, adminCount: intAdminsCount, bannedCount: intKickedCount), exportedInvitation: ExportedInvitation(apiExportedInvite: apiExportedInvite))
            case .chatFull:
                return nil
        }
    }
}
