import Postbox
import TelegramApi

public struct MessageReaction: Equatable, PostboxCoding {
    public enum Reaction: Hashable, Codable, PostboxCoding {
        case builtin(String)
        case custom(Int64)
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)
            
            if let value = try container.decodeIfPresent(String.self, forKey: "v") {
                self = .builtin(value)
            } else {
                self = .custom(try container.decode(Int64.self, forKey: "cfid"))
            }
        }
        
        public init(decoder: PostboxDecoder) {
            if let value = decoder.decodeOptionalStringForKey("v") {
                self = .builtin(value)
            } else {
                self = .custom(decoder.decodeInt64ForKey("cfid", orElse: 0))
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)
            
            switch self {
            case let .builtin(value):
                try container.encode(value, forKey: "v")
            case let .custom(fileId):
                try container.encode(fileId, forKey: "cfid")
            }
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            switch self {
            case let .builtin(value):
                encoder.encodeString(value, forKey: "v")
            case let .custom(fileId):
                encoder.encodeInt64(fileId, forKey: "cfid")
            }
        }
    }
    
    public var value: Reaction
    public var count: Int32
    public var chosenOrder: Int?
    
    public var isSelected: Bool {
        return self.chosenOrder != nil
    }
    
    public init(value: Reaction, count: Int32, chosenOrder: Int?) {
        self.value = value
        self.count = count
        self.chosenOrder = chosenOrder
    }
    
    public init(decoder: PostboxDecoder) {
        if let value = decoder.decodeOptionalStringForKey("v") {
            self.value = .builtin(value)
        } else {
            self.value = .custom(decoder.decodeInt64ForKey("cfid", orElse: 0))
        }
        self.count = decoder.decodeInt32ForKey("c", orElse: 0)
        if let chosenOrder = decoder.decodeOptionalInt32ForKey("cord") {
            self.chosenOrder = Int(chosenOrder)
        } else if let isSelected = decoder.decodeOptionalInt32ForKey("s"), isSelected != 0 {
            self.chosenOrder = 0
        } else {
            self.chosenOrder = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self.value {
        case let .builtin(value):
            encoder.encodeString(value, forKey: "v")
        case let .custom(fileId):
            encoder.encodeInt64(fileId, forKey: "cfid")
        }
        encoder.encodeInt32(self.count, forKey: "c")
        if let chosenOrder = self.chosenOrder {
            encoder.encodeInt32(Int32(chosenOrder), forKey: "cord")
        } else {
            encoder.encodeNil(forKey: "cord")
        }
    }
}

extension MessageReaction.Reaction {
    init?(apiReaction: Api.Reaction) {
        switch apiReaction {
        case .reactionEmpty:
            return nil
        case let .reactionEmoji(emoticon):
            self = .builtin(emoticon)
        case let .reactionCustomEmoji(documentId):
            self = .custom(documentId)
        }
    }
    
    var apiReaction: Api.Reaction {
        switch self {
        case let .builtin(value):
            return .reactionEmoji(emoticon: value)
        case let .custom(fileId):
            return .reactionCustomEmoji(documentId: fileId)
        }
    }
}

public final class ReactionsMessageAttribute: Equatable, MessageAttribute {
    public struct RecentPeer: Equatable, PostboxCoding {
        public var value: MessageReaction.Reaction
        public var isLarge: Bool
        public var isUnseen: Bool
        public var peerId: PeerId
        
        public init(value: MessageReaction.Reaction, isLarge: Bool, isUnseen: Bool, peerId: PeerId) {
            self.value = value
            self.isLarge = isLarge
            self.isUnseen = isUnseen
            self.peerId = peerId
        }
        
        public init(decoder: PostboxDecoder) {
            if let value = decoder.decodeOptionalStringForKey("v") {
                self.value = .builtin(value)
            } else {
                self.value = .custom(decoder.decodeInt64ForKey("cfid", orElse: 0))
            }
            self.isLarge = decoder.decodeInt32ForKey("l", orElse: 0) != 0
            self.isUnseen = decoder.decodeInt32ForKey("u", orElse: 0) != 0
            self.peerId = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            switch self.value {
            case let .builtin(value):
                encoder.encodeString(value, forKey: "v")
            case let .custom(fileId):
                encoder.encodeInt64(fileId, forKey: "cfid")
            }
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
    
    public var associatedMediaIds: [MediaId] {
        var result: [MediaId] = []
        
        for reaction in self.reactions {
            switch reaction.value {
            case .builtin:
                break
            case let .custom(fileId):
                let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                if !result.contains(mediaId) {
                    result.append(mediaId)
                }
            }
        }
        
        return result
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
    public struct PendingReaction: Equatable, PostboxCoding {
        public var value: MessageReaction.Reaction
        
        public init(value: MessageReaction.Reaction) {
            self.value = value
        }
        
        public init(decoder: PostboxDecoder) {
            self.value = decoder.decodeObjectForKey("val", decoder: { MessageReaction.Reaction(decoder: $0) }) as! MessageReaction.Reaction
        }
        
        public func encode(_ encoder: PostboxEncoder) {
            encoder.encodeObject(self.value, forKey: "val")
        }
    }
    
    public let accountPeerId: PeerId?
    public let reactions: [PendingReaction]
    public let isLarge: Bool
    public let storeAsRecentlyUsed: Bool
    
    public var associatedPeerIds: [PeerId] {
        if let accountPeerId = self.accountPeerId {
            return [accountPeerId]
        } else {
            return []
        }
    }
    
    public var associatedMediaIds: [MediaId] {
        var result: [MediaId] = []
        
        for reaction in self.reactions {
            switch reaction.value {
            case .builtin:
                break
            case let .custom(fileId):
                let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                if !result.contains(mediaId) {
                    result.append(mediaId)
                }
            }
        }
        
        return result
    }
    
    public init(accountPeerId: PeerId?, reactions: [PendingReaction], isLarge: Bool, storeAsRecentlyUsed: Bool) {
        self.accountPeerId = accountPeerId
        self.reactions = reactions
        self.isLarge = isLarge
        self.storeAsRecentlyUsed = storeAsRecentlyUsed
    }
    
    required public init(decoder: PostboxDecoder) {
        self.accountPeerId = decoder.decodeOptionalInt64ForKey("ap").flatMap(PeerId.init)
        self.reactions = decoder.decodeObjectArrayWithDecoderForKey("reac")
        self.isLarge = decoder.decodeInt32ForKey("l", orElse: 0) != 0
        self.storeAsRecentlyUsed = decoder.decodeInt32ForKey("used", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let accountPeerId = self.accountPeerId {
            encoder.encodeInt64(accountPeerId.toInt64(), forKey: "ap")
        } else {
            encoder.encodeNil(forKey: "ap")
        }
        
        encoder.encodeObjectArray(self.reactions, forKey: "reac")
        
        encoder.encodeInt32(self.isLarge ? 1 : 0, forKey: "l")
        encoder.encodeInt32(self.storeAsRecentlyUsed ? 1 : 0, forKey: "used")
    }
}
