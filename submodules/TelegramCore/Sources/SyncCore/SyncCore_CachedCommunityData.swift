import Postbox

public final class CachedCommunityData: CachedPeerData {
    public struct CommunityLinkedPeer: PostboxCoding, Equatable {
        public let peerId: PeerId
        public let visible: Bool?
        public let canViewHistory: Bool

        public init(peerId: PeerId, visible: Bool?, canViewHistory: Bool = false) {
            self.peerId = peerId
            self.visible = visible
            self.canViewHistory = canViewHistory
        }

        public init(decoder: PostboxDecoder) {
            self.peerId = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
            self.visible = decoder.decodeOptionalBoolForKey("v")
            self.canViewHistory = decoder.decodeBoolForKey("cvh", orElse: false)
        }

        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeInt64(self.peerId.toInt64(), forKey: "p")
            if let visible = self.visible {
                encoder.encodeBool(visible, forKey: "v")
            } else {
                encoder.encodeNil(forKey: "v")
            }
            encoder.encodeBool(self.canViewHistory, forKey: "cvh")
        }
    }
    
    public let about: String?
    public let photo: TelegramMediaImage?
    public let linkedPeers: [CommunityLinkedPeer]
    public let adminsCount: Int32?
    public let kickedCount: Int32?
    public let pendingRequests: Int32?
    public let peerStatusSettings: PeerStatusSettings?
    
    public let peerIds: Set<PeerId>
    public let messageIds: Set<MessageId>
    public let associatedHistoryMessageId: MessageId? = nil
    
    public init() {
        self.about = nil
        self.photo = nil
        self.linkedPeers = []
        self.adminsCount = nil
        self.kickedCount = nil
        self.pendingRequests = nil
        self.peerStatusSettings = nil
        self.peerIds = Set()
        self.messageIds = Set()
    }
    
    public init(
        about: String?,
        photo: TelegramMediaImage?,
        linkedPeers: [CommunityLinkedPeer],
        adminsCount: Int32?,
        kickedCount: Int32? = nil,
        pendingRequests: Int32?,
        peerStatusSettings: PeerStatusSettings?
    ) {
        self.about = about
        self.photo = photo
        self.linkedPeers = linkedPeers
        self.adminsCount = adminsCount
        self.kickedCount = kickedCount
        self.pendingRequests = pendingRequests
        self.peerStatusSettings = peerStatusSettings
        self.peerIds = Set(linkedPeers.map(\.peerId))
        self.messageIds = Set()
    }
    
    public init(decoder: PostboxDecoder) {
        self.about = decoder.decodeOptionalStringForKey("a")
        self.photo = decoder.decodeObjectForKey("ph", decoder: { TelegramMediaImage(decoder: $0) }) as? TelegramMediaImage
        self.linkedPeers = decoder.decodeObjectArrayWithDecoderForKey("lp")
        self.adminsCount = decoder.decodeOptionalInt32ForKey("ac")
        self.kickedCount = decoder.decodeOptionalInt32ForKey("kc")
        self.pendingRequests = decoder.decodeOptionalInt32ForKey("pr")
        self.peerStatusSettings = decoder.decodeObjectForKey("pss", decoder: { PeerStatusSettings(decoder: $0) }) as? PeerStatusSettings
        self.peerIds = Set(self.linkedPeers.map(\.peerId))
        self.messageIds = Set()
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let about = self.about {
            encoder.encodeString(about, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
        if let photo = self.photo {
            encoder.encodeObject(photo, forKey: "ph")
        } else {
            encoder.encodeNil(forKey: "ph")
        }
        encoder.encodeObjectArray(self.linkedPeers, forKey: "lp")
        if let adminsCount = self.adminsCount {
            encoder.encodeInt32(adminsCount, forKey: "ac")
        } else {
            encoder.encodeNil(forKey: "ac")
        }
        if let kickedCount = self.kickedCount {
            encoder.encodeInt32(kickedCount, forKey: "kc")
        } else {
            encoder.encodeNil(forKey: "kc")
        }
        if let pendingRequests = self.pendingRequests {
            encoder.encodeInt32(pendingRequests, forKey: "pr")
        } else {
            encoder.encodeNil(forKey: "pr")
        }
        if let peerStatusSettings = self.peerStatusSettings {
            encoder.encodeObject(peerStatusSettings, forKey: "pss")
        } else {
            encoder.encodeNil(forKey: "pss")
        }
    }
    
    public func withUpdatedAbout(_ about: String?) -> CachedCommunityData {
        return CachedCommunityData(about: about, photo: self.photo, linkedPeers: self.linkedPeers, adminsCount: self.adminsCount, kickedCount: self.kickedCount, pendingRequests: self.pendingRequests, peerStatusSettings: self.peerStatusSettings)
    }
    
    public func withUpdatedPhoto(_ photo: TelegramMediaImage?) -> CachedCommunityData {
        return CachedCommunityData(about: self.about, photo: photo, linkedPeers: self.linkedPeers, adminsCount: self.adminsCount, kickedCount: self.kickedCount, pendingRequests: self.pendingRequests, peerStatusSettings: self.peerStatusSettings)
    }
    
    public func withUpdatedLinkedPeers(_ linkedPeers: [CommunityLinkedPeer]) -> CachedCommunityData {
        return CachedCommunityData(about: self.about, photo: self.photo, linkedPeers: linkedPeers, adminsCount: self.adminsCount, kickedCount: self.kickedCount, pendingRequests: self.pendingRequests, peerStatusSettings: self.peerStatusSettings)
    }
    
    public func withUpdatedAdminsCount(_ adminsCount: Int32?) -> CachedCommunityData {
        return CachedCommunityData(about: self.about, photo: self.photo, linkedPeers: self.linkedPeers, adminsCount: adminsCount, kickedCount: self.kickedCount, pendingRequests: self.pendingRequests, peerStatusSettings: self.peerStatusSettings)
    }

    public func withUpdatedKickedCount(_ kickedCount: Int32?) -> CachedCommunityData {
        return CachedCommunityData(about: self.about, photo: self.photo, linkedPeers: self.linkedPeers, adminsCount: self.adminsCount, kickedCount: kickedCount, pendingRequests: self.pendingRequests, peerStatusSettings: self.peerStatusSettings)
    }
    
    public func withUpdatedPendingRequests(_ pendingRequests: Int32?) -> CachedCommunityData {
        return CachedCommunityData(about: self.about, photo: self.photo, linkedPeers: self.linkedPeers, adminsCount: self.adminsCount, kickedCount: self.kickedCount, pendingRequests: pendingRequests, peerStatusSettings: self.peerStatusSettings)
    }
    
    public func withUpdatedPeerStatusSettings(_ peerStatusSettings: PeerStatusSettings?) -> CachedCommunityData {
        return CachedCommunityData(about: self.about, photo: self.photo, linkedPeers: self.linkedPeers, adminsCount: self.adminsCount, kickedCount: self.kickedCount, pendingRequests: self.pendingRequests, peerStatusSettings: peerStatusSettings)
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedCommunityData else {
            return false
        }
        return self.about == other.about
            && self.photo == other.photo
            && self.linkedPeers == other.linkedPeers
            && self.adminsCount == other.adminsCount
            && self.kickedCount == other.kickedCount
            && self.pendingRequests == other.pendingRequests
            && self.peerStatusSettings == other.peerStatusSettings
    }
}
