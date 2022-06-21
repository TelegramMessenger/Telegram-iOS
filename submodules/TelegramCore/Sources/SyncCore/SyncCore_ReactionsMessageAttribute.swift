import Postbox

public struct MessageReaction: Equatable, PostboxCoding {
    public var value: String
    public var count: Int32
    public var isSelected: Bool
    
    public init(value: String, count: Int32, isSelected: Bool) {
        self.value = value
        self.count = count
        self.isSelected = isSelected
    }
    
    public init(decoder: PostboxDecoder) {
        self.value = decoder.decodeStringForKey("v", orElse: "")
        self.count = decoder.decodeInt32ForKey("c", orElse: 0)
        self.isSelected = decoder.decodeInt32ForKey("s", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.value, forKey: "v")
        encoder.encodeInt32(self.count, forKey: "c")
        encoder.encodeInt32(self.isSelected ? 1 : 0, forKey: "s")
    }
}

public final class ReactionsMessageAttribute: Equatable, MessageAttribute {
    public struct RecentPeer: Equatable, PostboxCoding {
        public var value: String
        public var isLarge: Bool
        public var isUnseen: Bool
        public var peerId: PeerId
        
        public init(value: String, isLarge: Bool, isUnseen: Bool, peerId: PeerId) {
            self.value = value
            self.isLarge = isLarge
            self.isUnseen = isUnseen
            self.peerId = peerId
        }
        
        public init(decoder: PostboxDecoder) {
            self.value = decoder.decodeStringForKey("v", orElse: "")
            self.isLarge = decoder.decodeInt32ForKey("l", orElse: 0) != 0
            self.isUnseen = decoder.decodeInt32ForKey("u", orElse: 0) != 0
            self.peerId = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeString(self.value, forKey: "v")
            encoder.encodeInt32(self.isLarge ? 1 : 0, forKey: "l")
            encoder.encodeInt32(self.isUnseen ? 1 : 0, forKey: "u")
            encoder.encodeInt64(self.peerId.toInt64(), forKey: "p")
        }
    }
    
    public let canViewList: Bool
    public let reactions: [MessageReaction]
    public let recentPeers: [RecentPeer]
    
    public var associatedPeerIds: [PeerId] {
        return self.recentPeers.map(\.peerId)
    }
    
    public init(canViewList: Bool, reactions: [MessageReaction], recentPeers: [RecentPeer]) {
        self.canViewList = canViewList
        self.reactions = reactions
        self.recentPeers = recentPeers
    }
    
    required public init(decoder: PostboxDecoder) {
        self.canViewList = decoder.decodeBoolForKey("vl", orElse: true)
        self.reactions = decoder.decodeObjectArrayWithDecoderForKey("r")
        self.recentPeers = decoder.decodeObjectArrayWithDecoderForKey("rp")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeBool(self.canViewList, forKey: "vl")
        encoder.encodeObjectArray(self.reactions, forKey: "r")
        encoder.encodeObjectArray(self.recentPeers, forKey: "rp")
    }
    
    public static func ==(lhs: ReactionsMessageAttribute, rhs: ReactionsMessageAttribute) -> Bool {
        if lhs.canViewList != rhs.canViewList {
            return false
        }
        if lhs.reactions != rhs.reactions {
            return false
        }
        if lhs.recentPeers != rhs.recentPeers {
            return false
        }
        return true
    }
    
    public var hasUnseen: Bool {
        for recentPeer in self.recentPeers {
            if recentPeer.isUnseen {
                return true
            }
        }
        return false
    }
    
    public func withAllSeen() -> ReactionsMessageAttribute {
        return ReactionsMessageAttribute(
            canViewList: self.canViewList,
            reactions: self.reactions,
            recentPeers: self.recentPeers.map { recentPeer in
                var recentPeer = recentPeer
                recentPeer.isUnseen = false
                return recentPeer
            }
        )
    }
}

public final class PendingReactionsMessageAttribute: MessageAttribute {
    public let accountPeerId: PeerId?
    public let value: String?
    public let isLarge: Bool
    
    public var associatedPeerIds: [PeerId] {
        if let accountPeerId = self.accountPeerId {
            return [accountPeerId]
        } else {
            return []
        }
    }
    
    public init(accountPeerId: PeerId?, value: String?, isLarge: Bool) {
        self.accountPeerId = accountPeerId
        self.value = value
        self.isLarge = isLarge
    }
    
    required public init(decoder: PostboxDecoder) {
        self.accountPeerId = decoder.decodeOptionalInt64ForKey("ap").flatMap(PeerId.init)
        self.value = decoder.decodeOptionalStringForKey("v")
        self.isLarge = decoder.decodeInt32ForKey("l", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let accountPeerId = self.accountPeerId {
            encoder.encodeInt64(accountPeerId.toInt64(), forKey: "ap")
        } else {
            encoder.encodeNil(forKey: "ap")
        }
        if let value = self.value {
            encoder.encodeString(value, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
        encoder.encodeInt32(self.isLarge ? 1 : 0, forKey: "l")
    }
}
