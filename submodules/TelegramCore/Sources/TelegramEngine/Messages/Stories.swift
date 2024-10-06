import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum EngineStoryInputMedia {
    case image(dimensions: PixelDimensions, data: Data, stickers: [TelegramMediaFile])
    case video(dimensions: PixelDimensions, duration: Double, resource: TelegramMediaResource, firstFrameFile: TempBoxFile?, stickers: [TelegramMediaFile], coverTime: Double?)
    case existing(media: Media)
    
    var embeddedStickers: [TelegramMediaFile] {
        switch self {
        case let .image(_, _, stickers), let .video(_, _, _, _, stickers, _):
            return stickers
        case .existing:
            return []
        }
    }
}

public struct EngineStoryPrivacy: Codable, Equatable {
    public typealias Base = Stories.Item.Privacy.Base
    
    public var base: Base
    public var additionallyIncludePeers: [EnginePeer.Id]
    
    public init(base: Stories.Item.Privacy.Base, additionallyIncludePeers: [EnginePeer.Id]) {
        self.base = base
        self.additionallyIncludePeers = additionallyIncludePeers
    }
}

public extension EngineStoryPrivacy {
    init(_ privacy: Stories.Item.Privacy) {
        self.init(
            base: privacy.base,
            additionallyIncludePeers: privacy.additionallyIncludePeers
        )
    }
}

public extension EngineStoryItem.ForwardInfo {
    init?(_ forwardInfo: Stories.Item.ForwardInfo, transaction: Transaction) {
        switch forwardInfo {
        case let .known(peerId, storyId, isModified):
            if let peer = transaction.getPeer(peerId) {
                self = .known(peer: EnginePeer(peer), storyId: storyId, isModified: isModified)
            } else {
                return nil
            }
        case let .unknown(name, isModified):
            self = .unknown(name: name, isModified: isModified)
        }
    }
    
    init?(_ forwardInfo: Stories.Item.ForwardInfo, peers: [PeerId: Peer]) {
        switch forwardInfo {
        case let .known(peerId, storyId, isModified):
            if let peer = peers[peerId] {
                self = .known(peer: EnginePeer(peer), storyId: storyId, isModified: isModified)
            } else {
                return nil
            }
        case let .unknown(name, isModified):
            self = .unknown(name: name, isModified: isModified)
        }
    }
}

public enum Stories {
    public final class Item: Codable, Equatable {
        public struct Views: Codable, Equatable {
            private enum CodingKeys: String, CodingKey {
                case seenCount = "seenCount"
                case reactedCount = "reactedCount"
                case forwardCount = "forwardCount"
                case seenPeerIds = "seenPeerIds"
                case reactions = "reactions"
                case hasList = "hasList"
            }
            
            public var seenCount: Int
            public var reactedCount: Int
            public var forwardCount: Int
            public var seenPeerIds: [PeerId]
            public var reactions: [MessageReaction]
            public var hasList: Bool
            
            public var isEmpty: Bool {
                if self.seenCount != 0 {
                    return false
                }
                if self.reactedCount != 0 {
                    return false
                }
                if self.forwardCount != 0 {
                    return false
                }
                if !self.seenPeerIds.isEmpty {
                    return false
                }
                if !self.reactions.isEmpty {
                    return false
                }
                if self.hasList {
                    return false
                }
                
                return true
            }
            
            public init(seenCount: Int, reactedCount: Int, forwardCount: Int, seenPeerIds: [PeerId], reactions: [MessageReaction], hasList: Bool) {
                self.seenCount = seenCount
                self.reactedCount = reactedCount
                self.forwardCount = forwardCount
                self.seenPeerIds = seenPeerIds
                self.reactions = reactions
                self.hasList = hasList
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.seenCount = Int(try container.decode(Int32.self, forKey: .seenCount))
                self.reactedCount = Int(try container.decodeIfPresent(Int32.self, forKey: .reactedCount) ?? 0)
                self.forwardCount = Int(try container.decodeIfPresent(Int32.self, forKey: .forwardCount) ?? 0)
                self.seenPeerIds = try container.decode([Int64].self, forKey: .seenPeerIds).map(PeerId.init)
                self.reactions = try container.decodeIfPresent([MessageReaction].self, forKey: .reactions) ?? []
                self.hasList = try container.decodeIfPresent(Bool.self, forKey: .hasList) ?? true
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(Int32(clamping: self.seenCount), forKey: .seenCount)
                try container.encode(Int32(clamping: self.reactedCount), forKey: .reactedCount)
                try container.encode(Int32(clamping: self.forwardCount), forKey: .forwardCount)
                try container.encode(self.seenPeerIds.map { $0.toInt64() }, forKey: .seenPeerIds)
                try container.encode(self.reactions, forKey: .reactions)
                try container.encode(self.hasList, forKey: .hasList)
            }
        }
        
        public struct Privacy: Codable, Equatable {
            private enum CodingKeys: String, CodingKey {
                case base = "base"
                case additionallyIncludePeers = "addPeers"
            }
            
            public enum Base: Int32, Codable {
                private enum CodingKeys: CodingKey {
                    case value
                }
                
                case everyone = 0
                case contacts = 1
                case closeFriends = 2
                case nobody = 3
                
                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    self.init(rawValue: try container.decode(Int32.self, forKey: .value))!
                }
                
                public func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    
                    try container.encode(self.rawValue, forKey: .value)
                }
            }
            
            public var base: Base
            public var additionallyIncludePeers: [PeerId]
            
            public init(base: Base, additionallyIncludePeers: [PeerId]) {
                self.base = base
                self.additionallyIncludePeers = additionallyIncludePeers
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.base = Base(rawValue: try container.decode(Int32.self, forKey: .base)) ?? .nobody
                self.additionallyIncludePeers = try container.decode([Int64].self, forKey: .additionallyIncludePeers).map(PeerId.init)
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(self.base.rawValue, forKey: .base)
                try container.encode(self.additionallyIncludePeers.map { $0.toInt64() }, forKey: .additionallyIncludePeers)
            }
        }
        
        public enum ForwardInfo: Codable, Equatable {
            public enum DecodingError: Error {
                case generic
            }
            
            private enum CodingKeys: CodingKey {
                case discriminator
                case authorPeerId
                case storyId
                case authorName
                case isModified
            }
            
            case known(peerId: EnginePeer.Id, storyId: Int32, isModified: Bool)
            case unknown(name: String, isModified: Bool)
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                                
                switch try container.decode(Int32.self, forKey: .discriminator) {
                case 0:
                    self = .known(peerId: EnginePeer.Id(try container.decode(Int64.self, forKey: .authorPeerId)), storyId: try container.decode(Int32.self, forKey: .storyId), isModified: try container.decodeIfPresent(Bool.self, forKey: .isModified) ?? false)
                case 1:
                    self = .unknown(name: try container.decode(String.self, forKey: .authorName), isModified: try container.decodeIfPresent(Bool.self, forKey: .isModified) ?? false)
                default:
                    throw DecodingError.generic
                }
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                switch self {
                case let .known(peerId, storyId, isModified):
                    try container.encode(0 as Int32, forKey: .discriminator)
                    try container.encode(peerId.toInt64(), forKey: .authorPeerId)
                    try container.encode(storyId, forKey: .storyId)
                    try container.encode(isModified, forKey: .isModified)
                case let .unknown(name, isModified):
                    try container.encode(1 as Int32, forKey: .discriminator)
                    try container.encode(name, forKey: .authorName)
                    try container.encode(isModified, forKey: .isModified)
                }
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case id
            case timestamp
            case expirationTimestamp
            case media
            case alternativeMedia
            case alternativeMediaList
            case mediaAreas
            case text
            case entities
            case views
            case privacy
            case isPinned
            case isExpired
            case isPublic
            case isCloseFriends
            case isContacts
            case isSelectedContacts
            case isForwardingDisabled
            case isEdited
            case isMy
            case myReaction
            case forwardInfo
            case authorId
        }
        
        public let id: Int32
        public let timestamp: Int32
        public let expirationTimestamp: Int32
        public let media: Media?
        public let alternativeMediaList: [Media]
        public let mediaAreas: [MediaArea]
        public let text: String
        public let entities: [MessageTextEntity]
        public let views: Views?
        public let privacy: Privacy?
        public let isPinned: Bool
        public let isExpired: Bool
        public let isPublic: Bool
        public let isCloseFriends: Bool
        public let isContacts: Bool
        public let isSelectedContacts: Bool
        public let isForwardingDisabled: Bool
        public let isEdited: Bool
        public let isMy: Bool
        public let myReaction: MessageReaction.Reaction?
        public let forwardInfo: ForwardInfo?
        public let authorId: PeerId?
        
        public init(
            id: Int32,
            timestamp: Int32,
            expirationTimestamp: Int32,
            media: Media?,
            alternativeMediaList: [Media],
            mediaAreas: [MediaArea],
            text: String,
            entities: [MessageTextEntity],
            views: Views?,
            privacy: Privacy?,
            isPinned: Bool,
            isExpired: Bool,
            isPublic: Bool,
            isCloseFriends: Bool,
            isContacts: Bool,
            isSelectedContacts: Bool,
            isForwardingDisabled: Bool,
            isEdited: Bool,
            isMy: Bool,
            myReaction: MessageReaction.Reaction?,
            forwardInfo: ForwardInfo?,
            authorId: PeerId?
        ) {
            self.id = id
            self.timestamp = timestamp
            self.expirationTimestamp = expirationTimestamp
            self.media = media
            self.alternativeMediaList = alternativeMediaList
            self.mediaAreas = mediaAreas
            self.text = text
            self.entities = entities
            self.views = views
            self.privacy = privacy
            self.isPinned = isPinned
            self.isExpired = isExpired
            self.isPublic = isPublic
            self.isCloseFriends = isCloseFriends
            self.isContacts = isContacts
            self.isSelectedContacts = isSelectedContacts
            self.isForwardingDisabled = isForwardingDisabled
            self.isEdited = isEdited
            self.isMy = isMy
            self.myReaction = myReaction
            self.forwardInfo = forwardInfo
            self.authorId = authorId
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(Int32.self, forKey: .id)
            self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
            self.expirationTimestamp = try container.decode(Int32.self, forKey: .expirationTimestamp)
            
            if let mediaData = try container.decodeIfPresent(Data.self, forKey: .media) {
                self.media = PostboxDecoder(buffer: MemoryBuffer(data: mediaData)).decodeRootObject() as? Media
            } else {
                self.media = nil
            }
            
            if let alternativeMediaListData = try container.decodeIfPresent([Data].self, forKey: .alternativeMediaList) {
                self.alternativeMediaList = alternativeMediaListData.compactMap { data -> Media? in
                    return PostboxDecoder(buffer: MemoryBuffer(data: data)).decodeRootObject() as? Media
                }
            } else if let alternativeMediaData = try container.decodeIfPresent(Data.self, forKey: .alternativeMedia) {
                if let value = PostboxDecoder(buffer: MemoryBuffer(data: alternativeMediaData)).decodeRootObject() as? Media {
                    self.alternativeMediaList = [value]
                } else {
                    self.alternativeMediaList = []
                }
            } else {
                self.alternativeMediaList = []
            }
            
            self.mediaAreas = try container.decodeIfPresent([MediaArea].self, forKey: .mediaAreas) ?? []
            
            self.text = try container.decode(String.self, forKey: .text)
            self.entities = try container.decode([MessageTextEntity].self, forKey: .entities)
            self.views = try container.decodeIfPresent(Views.self, forKey: .views)
            self.privacy = try container.decodeIfPresent(Privacy.self, forKey: .privacy)
            self.isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
            self.isExpired = try container.decodeIfPresent(Bool.self, forKey: .isExpired) ?? false
            self.isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? false
            self.isCloseFriends = try container.decodeIfPresent(Bool.self, forKey: .isCloseFriends) ?? false
            self.isContacts = try container.decodeIfPresent(Bool.self, forKey: .isContacts) ?? false
            self.isSelectedContacts = try container.decodeIfPresent(Bool.self, forKey: .isSelectedContacts) ?? false
            self.isForwardingDisabled = try container.decodeIfPresent(Bool.self, forKey: .isForwardingDisabled) ?? false
            self.isEdited = try container.decodeIfPresent(Bool.self, forKey: .isEdited) ?? false
            self.isMy = try container.decodeIfPresent(Bool.self, forKey: .isMy) ?? false
            self.myReaction = try container.decodeIfPresent(MessageReaction.Reaction.self, forKey: .myReaction)
            self.forwardInfo = try container.decodeIfPresent(ForwardInfo.self, forKey: .forwardInfo)
            self.authorId = try container.decodeIfPresent(Int64.self, forKey: .authorId).flatMap { PeerId($0) }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.id, forKey: .id)
            try container.encode(self.timestamp, forKey: .timestamp)
            try container.encode(self.expirationTimestamp, forKey: .expirationTimestamp)
            
            if let media = self.media {
                let encoder = PostboxEncoder()
                encoder.encodeRootObject(media)
                let mediaData = encoder.makeData()
                try container.encode(mediaData, forKey: .media)
            }
            
            let alternativeMediaListData = self.alternativeMediaList.map { alternativeMediaValue -> Data in
                let encoder = PostboxEncoder()
                encoder.encodeRootObject(alternativeMediaValue)
                return encoder.makeData()
            }
            try container.encode(alternativeMediaListData, forKey: .alternativeMediaList)
            
            try container.encode(self.mediaAreas, forKey: .mediaAreas)
            
            try container.encode(self.text, forKey: .text)
            try container.encode(self.entities, forKey: .entities)
            try container.encodeIfPresent(self.views, forKey: .views)
            try container.encodeIfPresent(self.privacy, forKey: .privacy)
            try container.encode(self.isPinned, forKey: .isPinned)
            try container.encode(self.isExpired, forKey: .isExpired)
            try container.encode(self.isPublic, forKey: .isPublic)
            try container.encode(self.isCloseFriends, forKey: .isCloseFriends)
            try container.encode(self.isContacts, forKey: .isContacts)
            try container.encode(self.isSelectedContacts, forKey: .isSelectedContacts)
            try container.encode(self.isForwardingDisabled, forKey: .isForwardingDisabled)
            try container.encode(self.isEdited, forKey: .isEdited)
            try container.encode(self.isMy, forKey: .isMy)
            try container.encodeIfPresent(self.myReaction, forKey: .myReaction)
            try container.encodeIfPresent(self.forwardInfo, forKey: .forwardInfo)
            try container.encodeIfPresent(self.authorId?.toInt64(), forKey: .authorId)
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.timestamp != rhs.timestamp {
                return false
            }
            if lhs.expirationTimestamp != rhs.expirationTimestamp {
                return false
            }
            
            if let lhsMedia = lhs.media, let rhsMedia = rhs.media {
                if !lhsMedia.isEqual(to: rhsMedia) {
                    return false
                }
            } else {
                if (lhs.media == nil) != (rhs.media == nil) {
                    return false
                }
            }
            
            if !areMediaArraysEqual(lhs.alternativeMediaList, rhs.alternativeMediaList) {
                return false
            }
            
            if lhs.mediaAreas != rhs.mediaAreas {
                return false
            }
            if lhs.text != rhs.text {
                return false
            }
            if lhs.entities != rhs.entities {
                return false
            }
            if lhs.views != rhs.views {
                return false
            }
            if lhs.privacy != rhs.privacy {
                return false
            }
            if lhs.isPinned != rhs.isPinned {
                return false
            }
            if lhs.isExpired != rhs.isExpired {
                return false
            }
            if lhs.isPublic != rhs.isPublic {
                return false
            }
            if lhs.isCloseFriends != rhs.isCloseFriends {
                return false
            }
            if lhs.isContacts != rhs.isContacts {
                return false
            }
            if lhs.isSelectedContacts != rhs.isSelectedContacts {
                return false
            }
            if lhs.isForwardingDisabled != rhs.isForwardingDisabled {
                return false
            }
            if lhs.isEdited != rhs.isEdited {
                return false
            }
            if lhs.myReaction != rhs.myReaction {
                return false
            }
            if lhs.forwardInfo != rhs.forwardInfo {
                return false
            }
            if lhs.authorId != rhs.authorId {
                return false
            }
            return true
        }
    }
    
    public final class Placeholder: Codable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case id
            case timestamp
            case expirationTimestamp
            case isCloseFriends = "clf"
        }
        
        public let id: Int32
        public let timestamp: Int32
        public let expirationTimestamp: Int32
        public let isCloseFriends: Bool
        
        public init(
            id: Int32,
            timestamp: Int32,
            expirationTimestamp: Int32,
            isCloseFriends: Bool
        ) {
            self.id = id
            self.timestamp = timestamp
            self.expirationTimestamp = expirationTimestamp
            self.isCloseFriends = isCloseFriends
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(Int32.self, forKey: .id)
            self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
            self.expirationTimestamp = try container.decode(Int32.self, forKey: .expirationTimestamp)
            self.isCloseFriends = try container.decodeIfPresent(Bool.self, forKey: .isCloseFriends) ?? false
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.id, forKey: .id)
            try container.encode(self.timestamp, forKey: .timestamp)
            try container.encode(self.expirationTimestamp, forKey: .expirationTimestamp)
            try container.encode(self.isCloseFriends, forKey: .isCloseFriends)
        }
        
        public static func ==(lhs: Placeholder, rhs: Placeholder) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.timestamp != rhs.timestamp {
                return false
            }
            if lhs.expirationTimestamp != rhs.expirationTimestamp {
                return false
            }
            if lhs.isCloseFriends != rhs.isCloseFriends {
                return false
            }
            return true
        }
    }
    
    public enum StoredItem: Codable, Equatable {
        public enum DecodingError: Error {
            case generic
        }
        
        private enum CodingKeys: String, CodingKey {
            case discriminator = "d"
            case item = "i"
            case placeholder = "p"
        }
        
        case item(Item)
        case placeholder(Placeholder)
        
        public var id: Int32 {
            switch self {
            case let .item(item):
                return item.id
            case let .placeholder(placeholder):
                return placeholder.id
            }
        }
        
        public var timestamp: Int32 {
            switch self {
            case let .item(item):
                return item.timestamp
            case let .placeholder(placeholder):
                return placeholder.timestamp
            }
        }
        
        public var expirationTimestamp: Int32 {
            switch self {
            case let .item(item):
                return item.expirationTimestamp
            case let .placeholder(placeholder):
                return placeholder.expirationTimestamp
            }
        }
        
        public var isCloseFriends: Bool {
            switch self {
            case let .item(item):
                return item.isCloseFriends
            case let .placeholder(placeholder):
                return placeholder.isCloseFriends
            }
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            switch try container.decode(Int32.self, forKey: .discriminator) {
            case 0:
                self = .item(try container.decode(Item.self, forKey: .item))
            case 1:
                self = .placeholder(try container.decode(Placeholder.self, forKey: .placeholder))
            default:
                throw DecodingError.generic
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case let .item(item):
                try container.encode(0 as Int32, forKey: .discriminator)
                try container.encode(item, forKey: .item)
            case let .placeholder(placeholder):
                try container.encode(1 as Int32, forKey: .discriminator)
                try container.encode(placeholder, forKey: .placeholder)
            }
        }
    }
    
    public final class PeerState: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case maxReadId = "rid"
        }
        
        public let maxReadId: Int32
        
        public init(
            maxReadId: Int32
        ){
            self.maxReadId = maxReadId
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.maxReadId = try container.decode(Int32.self, forKey: .maxReadId)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.maxReadId, forKey: .maxReadId)
        }
        
        public static func ==(lhs: PeerState, rhs: PeerState) -> Bool {
            if lhs.maxReadId != rhs.maxReadId {
                return false
            }
            return true
        }
    }
    
    public struct StealthModeState: Equatable, Codable {
        public var activeUntilTimestamp: Int32?
        public var cooldownUntilTimestamp: Int32?
        
        public init(
            activeUntilTimestamp: Int32?,
            cooldownUntilTimestamp: Int32?
        ) {
            self.activeUntilTimestamp = activeUntilTimestamp
            self.cooldownUntilTimestamp = cooldownUntilTimestamp
        }
    }
    
    public struct ConfigurationState: Equatable, Codable {
        public var stealthModeState: StealthModeState
        
        public init(stealthModeState: StealthModeState) {
            self.stealthModeState = stealthModeState
        }
    }
    
    public final class SubscriptionsState: Equatable, Codable {
        private enum CodingKeys: CodingKey {
            case opaqueState
            case hasMore
            case refreshId
        }
        
        public let opaqueState: String
        public let refreshId: UInt64
        public let hasMore: Bool
        
        public init(
            opaqueState: String,
            refreshId: UInt64,
            hasMore: Bool
        ) {
            self.opaqueState = opaqueState
            self.refreshId = refreshId
            self.hasMore = hasMore
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.opaqueState = try container.decode(String.self, forKey: .opaqueState)
            self.refreshId = UInt64(bitPattern: (try container.decodeIfPresent(Int64.self, forKey: .refreshId)) ?? 0)
            self.hasMore = try container.decode(Bool.self, forKey: .hasMore)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.opaqueState, forKey: .opaqueState)
            try container.encode(Int64(bitPattern: self.refreshId), forKey: .refreshId)
            try container.encode(self.hasMore, forKey: .hasMore)
        }
        
        public static func ==(lhs: SubscriptionsState, rhs: SubscriptionsState) -> Bool {
            if lhs.opaqueState != rhs.opaqueState {
                return false
            }
            if lhs.refreshId != rhs.refreshId {
                return false
            }
            if lhs.hasMore != rhs.hasMore {
                return false
            }
            
            return true
        }
    }
}

public final class EngineStorySubscriptions: Equatable {    
    public final class Item: Equatable {
        public let peer: EnginePeer
        public let hasUnseen: Bool
        public let hasUnseenCloseFriends: Bool
        public let hasPending: Bool
        public let storyCount: Int
        public let unseenCount: Int
        public let lastTimestamp: Int32
        
        public init(
            peer: EnginePeer,
            hasUnseen: Bool,
            hasUnseenCloseFriends: Bool,
            hasPending: Bool,
            storyCount: Int,
            unseenCount: Int,
            lastTimestamp: Int32
        ) {
            self.peer = peer
            self.hasUnseen = hasUnseen
            self.hasUnseenCloseFriends = hasUnseenCloseFriends
            self.hasPending = hasPending
            self.storyCount = storyCount
            self.unseenCount = unseenCount
            self.lastTimestamp = lastTimestamp
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.hasUnseen != rhs.hasUnseen {
                return false
            }
            if lhs.hasUnseenCloseFriends != rhs.hasUnseenCloseFriends {
                return false
            }
            if lhs.storyCount != rhs.storyCount {
                return false
            }
            if lhs.unseenCount != rhs.unseenCount {
                return false
            }
            if lhs.lastTimestamp != rhs.lastTimestamp {
                return false
            }
            return true
        }
    }
    
    public let accountItem: Item?
    public let items: [Item]
    public let hasMoreToken: String?
    
    public init(accountItem: Item?, items: [Item], hasMoreToken: String?) {
        self.accountItem = accountItem
        self.items = items
        self.hasMoreToken = hasMoreToken
    }
    
    public static func ==(lhs: EngineStorySubscriptions, rhs: EngineStorySubscriptions) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.accountItem != rhs.accountItem {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        if lhs.hasMoreToken != rhs.hasMoreToken {
            return false
        }
        return true
    }
}

extension Stories.PeerState {
    var postboxRepresentation: StoredStoryPeerState {
        return StoredStoryPeerState(entry: CodableEntry(self)!, maxSeenId: self.maxReadId)
    }
}

public enum StoryUploadResult {
    case progress(Float)
    case completed(Int32?)
}

private func prepareUploadStoryContent(account: Account, media: EngineStoryInputMedia) -> Media {
    switch media {
    case let .image(dimensions, data, _):
        let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
        account.postbox.mediaBox.storeResourceData(resource.id, data: data)
        
        let imageMedia = TelegramMediaImage(
            imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: MediaId.Id.random(in: MediaId.Id.min ... MediaId.Id.max)),
            representations: [TelegramMediaImageRepresentation(dimensions: dimensions, resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)],
            immediateThumbnailData: nil,
            reference: nil,
            partialReference: nil,
            flags: []
        )
        return imageMedia
    case let .video(dimensions, duration, resource, firstFrameFile, _, coverTime):
        var previewRepresentations: [TelegramMediaImageRepresentation] = []
        if let firstFrameFile = firstFrameFile {
            account.postbox.mediaBox.storeCachedResourceRepresentation(resource.id.stringRepresentation, representationId: "first-frame", keepDuration: .general, tempFile: firstFrameFile)
            
            if let data = try? Data(contentsOf: URL(fileURLWithPath: firstFrameFile.path), options: .mappedIfSafe) {
                let localResource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max), size: nil, isSecretRelated: false)
                account.postbox.mediaBox.storeResourceData(localResource.id, data: data)
                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: dimensions, resource: localResource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
            }
        }
        
        let fileMedia = TelegramMediaFile(
            fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: MediaId.Id.random(in: MediaId.Id.min ... MediaId.Id.max)),
            partialReference: nil,
            resource: resource,
            previewRepresentations: previewRepresentations,
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "video/mp4",
            size: nil,
            attributes: [
                TelegramMediaFileAttribute.Video(duration: duration, size: dimensions, flags: .supportsStreaming, preloadSize: nil, coverTime: coverTime, videoCodec: nil)
            ],
            alternativeRepresentations: []
        )
        
        return fileMedia
    case let .existing(media):
        return media
    }
}

private func uploadedStoryContent(postbox: Postbox, network: Network, media: Media, mediaReference: AnyMediaReference?, embeddedStickers: [TelegramMediaFile], accountPeerId: PeerId, messageMediaPreuploadManager: MessageMediaPreuploadManager, revalidationContext: MediaReferenceRevalidationContext, auxiliaryMethods: AccountAuxiliaryMethods, passFetchProgress: Bool) -> (signal: Signal<PendingMessageUploadedContentResult?, NoError>, media: Media) {
    let originalMedia: Media = media
    let contentToUpload: MessageContentToUpload
    
    var attributes: [MessageAttribute] = []
    if !embeddedStickers.isEmpty {
        attributes.append(EmbeddedMediaStickersMessageAttribute(files: embeddedStickers))
    }
    
    contentToUpload = messageContentToUpload(
        accountPeerId: accountPeerId,
        network: network,
        postbox: postbox,
        auxiliaryMethods: auxiliaryMethods,
        transformOutgoingMessageMedia: nil,
        messageMediaPreuploadManager: messageMediaPreuploadManager,
        revalidationContext: revalidationContext,
        forceReupload: true,
        isGrouped: false,
        passFetchProgress: passFetchProgress,
        forceNoBigParts: true,
        peerId: accountPeerId,
        messageId: nil,
        attributes: attributes,
        text: "",
        media: [media],
        mediaReference: mediaReference
    )
        
    let contentSignal: Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>
    switch contentToUpload {
    case let .immediate(result, _):
        contentSignal = .single(result)
    case let .signal(signal, _):
        contentSignal = signal
    }
    
    return (
        contentSignal
        |> map(Optional.init)
        |> `catch` { _ -> Signal<PendingMessageUploadedContentResult?, NoError> in
            return .single(nil)
        },
        originalMedia
    )
}

private func apiInputPrivacyRules(privacy: EngineStoryPrivacy, transaction: Transaction) -> [Api.InputPrivacyRule] {
    var privacyRules: [Api.InputPrivacyRule]
    switch privacy.base {
    case .everyone:
        privacyRules = [.inputPrivacyValueAllowAll]
    case .contacts:
        privacyRules = [.inputPrivacyValueAllowContacts]
    case .closeFriends:
        privacyRules = [.inputPrivacyValueAllowCloseFriends]
    case .nobody:
        if privacy.additionallyIncludePeers.isEmpty {
            privacyRules = [.inputPrivacyValueAllowUsers(users: [.inputUserSelf])]
        } else {
            privacyRules = []
        }
    }
    var privacyUsers: [Api.InputUser] = []
    var privacyChats: [Int64] = []
    for peerId in privacy.additionallyIncludePeers {
        if let peer = transaction.getPeer(peerId) {
            if let _ = peer as? TelegramUser {
                if let inputUser = apiInputUser(peer) {
                    privacyUsers.append(inputUser)
                }
            } else if peer is TelegramGroup || peer is TelegramChannel {
                privacyChats.append(peer.id.id._internalGetInt64Value())
            }
        }
    }
    if !privacyUsers.isEmpty {
        if case .contacts = privacy.base {
            privacyRules.append(.inputPrivacyValueDisallowUsers(users: privacyUsers))
        } else if case .everyone = privacy.base {
            privacyRules.append(.inputPrivacyValueDisallowUsers(users: privacyUsers))
        } else {
            privacyRules.append(.inputPrivacyValueAllowUsers(users: privacyUsers))
        }
    }
    if !privacyChats.isEmpty {
        privacyRules.append(.inputPrivacyValueAllowChatParticipants(chats: privacyChats))
    }
    return privacyRules
}

func _internal_uploadStory(account: Account, target: Stories.PendingTarget, media: EngineStoryInputMedia, mediaAreas: [MediaArea], text: String, entities: [MessageTextEntity], pin: Bool, privacy: EngineStoryPrivacy, isForwardingDisabled: Bool, period: Int, randomId: Int64, forwardInfo: Stories.PendingForwardInfo?) -> Signal<Int32, NoError> {
    let inputMedia = prepareUploadStoryContent(account: account, media: media)
    
    return (account.postbox.transaction { transaction in
        var currentState: Stories.LocalState
        if let value = transaction.getLocalStoryState()?.get(Stories.LocalState.self) {
            currentState = value
        } else {
            currentState = Stories.LocalState(items: [])
        }
        var stableId: Int32 = Int32.random(in: 2000000 ..< Int32.max)
        while currentState.items.contains(where: { $0.stableId == stableId }) {
            stableId = Int32.random(in: 2000000 ..< Int32.max)
        }
        currentState.items.append(Stories.PendingItem(
            target: target,
            stableId: stableId,
            timestamp: Int32(Date().timeIntervalSince1970),
            media: inputMedia,
            mediaAreas: mediaAreas,
            text: text,
            entities: entities,
            embeddedStickers: media.embeddedStickers,
            pin: pin,
            privacy: privacy,
            isForwardingDisabled: isForwardingDisabled,
            period: Int32(period),
            randomId: randomId,
            forwardInfo: forwardInfo
        ))
        transaction.setLocalStoryState(state: CodableEntry(currentState))
        return stableId
    })
}

func _internal_cancelStoryUpload(account: Account, stableId: Int32) {
    let _ = (account.postbox.transaction { transaction in
        var currentState: Stories.LocalState
        if let value = transaction.getLocalStoryState()?.get(Stories.LocalState.self) {
            currentState = value
        } else {
            currentState = Stories.LocalState(items: [])
        }
        if let index = currentState.items.firstIndex(where: { $0.stableId == stableId }) {
            currentState.items.remove(at: index)
            transaction.setLocalStoryState(state: CodableEntry(currentState))
        }
    }).start()
}

private struct PendingStoryIdMappingKey: Hashable {
    var peerId: PeerId
    var stableId: Int32
}

private let pendingStoryIdMapping = Atomic<[PendingStoryIdMappingKey: Int32]>(value: [:])
private let pendingBotPreviewIdMapping = Atomic<[PendingStoryIdMappingKey: MediaId]>(value: [:])

func _internal_lookUpPendingStoryIdMapping(peerId: PeerId, stableId: Int32) -> Int32? {
    return pendingStoryIdMapping.with { dict in
        return dict[PendingStoryIdMappingKey(peerId: peerId, stableId: stableId)]
    }
}

private func _internal_putPendingStoryIdMapping(peerId: PeerId, stableId: Int32, id: Int32) {
    let _ = pendingStoryIdMapping.modify { dict in
        var dict = dict
        
        dict[PendingStoryIdMappingKey(peerId: peerId, stableId: stableId)] = id
        
        return dict
    }
}

func _internal_lookUpPendingBotPreviewIdMapping(peerId: PeerId, stableId: Int32) -> MediaId? {
    return pendingBotPreviewIdMapping.with { dict in
        return dict[PendingStoryIdMappingKey(peerId: peerId, stableId: stableId)]
    }
}

private func _internal_putPendingBotPreviewIdMapping(peerId: PeerId, stableId: Int32, id: MediaId) {
    let _ = pendingBotPreviewIdMapping.modify { dict in
        var dict = dict
        
        dict[PendingStoryIdMappingKey(peerId: peerId, stableId: stableId)] = id
        
        return dict
    }
}

func _internal_uploadStoryImpl(
    postbox: Postbox,
    network: Network,
    accountPeerId: PeerId,
    stateManager: AccountStateManager,
    messageMediaPreuploadManager: MessageMediaPreuploadManager,
    revalidationContext: MediaReferenceRevalidationContext,
    auxiliaryMethods: AccountAuxiliaryMethods,
    toPeerId: PeerId,
    stableId: Int32,
    media: Media,
    mediaAreas: [MediaArea],
    text: String,
    entities: [MessageTextEntity],
    embeddedStickers: [TelegramMediaFile],
    pin: Bool,
    privacy: EngineStoryPrivacy,
    isForwardingDisabled: Bool,
    period: Int,
    randomId: Int64,
    forwardInfo: Stories.PendingForwardInfo?
) -> Signal<StoryUploadResult, NoError> {
    return postbox.transaction { transaction -> (Peer, Peer?)? in
        if let peer = transaction.getPeer(toPeerId) {
            if let forwardInfo = forwardInfo {
                return (peer, transaction.getPeer(forwardInfo.peerId))
            } else {
                return (peer, nil)
            }
        }
        return nil
    }
    |> mapToSignal { inputPeerAndForwardInfoPeer -> Signal<StoryUploadResult, NoError> in
        guard let (inputPeer, forwardInfoPeer) = inputPeerAndForwardInfoPeer, let inputPeer = apiInputPeer(inputPeer) else {
            return .single(.completed(nil))
        }
        
        var mediaReference: AnyMediaReference?
        if let forwardInfo = forwardInfo, let forwardInfoPeer = forwardInfoPeer.flatMap(PeerReference.init) {
            mediaReference = .story(peer: forwardInfoPeer, id: forwardInfo.storyId, media: media)
        }
        
        let passFetchProgress = media is TelegramMediaFile
        let (contentSignal, originalMedia) = uploadedStoryContent(postbox: postbox, network: network, media: media, mediaReference: mediaReference, embeddedStickers: embeddedStickers, accountPeerId: accountPeerId, messageMediaPreuploadManager: messageMediaPreuploadManager, revalidationContext: revalidationContext, auxiliaryMethods: auxiliaryMethods, passFetchProgress: passFetchProgress)
        return contentSignal
        |> mapToSignal { result -> Signal<StoryUploadResult, NoError> in
            switch result {
            case let .progress(progress):
                return .single(.progress(progress.progress))
            case let .content(content):
                return postbox.transaction { transaction -> Signal<StoryUploadResult, NoError> in
                    let privacyRules = apiInputPrivacyRules(privacy: privacy, transaction: transaction)
                    switch content.content {
                    case let .media(inputMedia, _):
                        var flags: Int32 = 0
                        var apiCaption: String?
                        var apiEntities: [Api.MessageEntity]?
                        
                        if pin {
                            flags |= 1 << 2
                        }
                        if !text.isEmpty {
                            flags |= 1 << 0
                            apiCaption = text
                            
                            if !entities.isEmpty {
                                flags |= 1 << 1
                                
                                var associatedPeers: [PeerId: Peer] = [:]
                                for entity in entities {
                                    for entityPeerId in entity.associatedPeerIds {
                                        if let peer = transaction.getPeer(entityPeerId) {
                                            associatedPeers[peer.id] = peer
                                        }
                                    }
                                }
                                apiEntities = apiEntitiesFromMessageTextEntities(entities, associatedPeers: SimpleDictionary(associatedPeers))
                            }
                        }
                        
                        flags |= 1 << 3
                        
                        if isForwardingDisabled {
                            flags |= 1 << 4
                        }
                        
                        let inputMediaAreas: [Api.MediaArea] = apiMediaAreasFromMediaAreas(mediaAreas, transaction: transaction)
                        if !inputMediaAreas.isEmpty {
                            flags |= 1 << 5
                        }
                        
                        var fwdFromId: Api.InputPeer?
                        var fwdFromStory: Int32?
                        if let forwardInfo = forwardInfo, let inputPeer = transaction.getPeer(forwardInfo.peerId).flatMap({ apiInputPeer($0) }) {
                            flags |= 1 << 6
                            if forwardInfo.isModified {
                                flags |= 1 << 7
                            }
                            fwdFromId = inputPeer
                            fwdFromStory = forwardInfo.storyId
                        }
                        
                        return network.request(Api.functions.stories.sendStory(
                            flags: flags,
                            peer: inputPeer,
                            media: inputMedia,
                            mediaAreas: inputMediaAreas,
                            caption: apiCaption,
                            entities: apiEntities,
                            privacyRules: privacyRules,
                            randomId: randomId,
                            period: Int32(period),
                            fwdFromId: fwdFromId,
                            fwdFromStory: fwdFromStory
                        ))
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                            return .single(nil)
                        }
                        |> mapToSignal { updates -> Signal<StoryUploadResult, NoError> in
                            return postbox.transaction { transaction -> StoryUploadResult in
                                var currentState: Stories.LocalState
                                if let value = transaction.getLocalStoryState()?.get(Stories.LocalState.self) {
                                    currentState = value
                                } else {
                                    currentState = Stories.LocalState(items: [])
                                }
                                if let index = currentState.items.firstIndex(where: { $0.stableId == stableId }) {
                                    currentState.items.remove(at: index)
                                    transaction.setLocalStoryState(state: CodableEntry(currentState))
                                }
                                
                                var id: Int32?
                                if let updates = updates {
                                    for update in updates.allUpdates {
                                        if case let .updateStory(_, story) = update {
                                            switch story {
                                            case let .storyItem(_, idValue, _, fromId, _, _, _, _, media, _, _, _, _):
                                                if let parsedStory = Stories.StoredItem(apiStoryItem: story, peerId: toPeerId, transaction: transaction) {
                                                    var items = transaction.getStoryItems(peerId: toPeerId)
                                                    var updatedItems: [Stories.Item] = []
                                                    if items.firstIndex(where: { $0.id == id }) == nil, case let .item(item) = parsedStory {
                                                        let updatedItem = Stories.Item(
                                                            id: item.id,
                                                            timestamp: item.timestamp,
                                                            expirationTimestamp: item.expirationTimestamp,
                                                            media: item.media,
                                                            alternativeMediaList: item.alternativeMediaList,
                                                            mediaAreas: item.mediaAreas,
                                                            text: item.text,
                                                            entities: item.entities,
                                                            views: item.views,
                                                            privacy: Stories.Item.Privacy(base: privacy.base, additionallyIncludePeers: privacy.additionallyIncludePeers),
                                                            isPinned: item.isPinned,
                                                            isExpired: item.isExpired,
                                                            isPublic: item.isPublic,
                                                            isCloseFriends: item.isCloseFriends,
                                                            isContacts: item.isContacts,
                                                            isSelectedContacts: item.isSelectedContacts,
                                                            isForwardingDisabled: item.isForwardingDisabled,
                                                            isEdited: item.isEdited,
                                                            isMy: item.isMy,
                                                            myReaction: item.myReaction,
                                                            forwardInfo: item.forwardInfo,
                                                            authorId: fromId?.peerId
                                                        )
                                                        if let entry = CodableEntry(Stories.StoredItem.item(updatedItem)) {
                                                            items.append(StoryItemsTableEntry(value: entry, id: item.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends))
                                                        }
                                                        updatedItems.append(updatedItem)
                                                    }
                                                    transaction.setStoryItems(peerId: toPeerId, items: items)
                                                    
                                                    if let peer = transaction.getPeer(toPeerId) as? TelegramChannel, let storiesHidden = peer.storiesHidden {
                                                        let subscriptionsKey: PostboxStorySubscriptionsKey = storiesHidden ? .hidden : .filtered
                                                        var (state, peerIds) = transaction.getAllStorySubscriptions(key: subscriptionsKey)
                                                        if !peerIds.contains(toPeerId) {
                                                            peerIds.append(toPeerId)
                                                        }
                                                        transaction.replaceAllStorySubscriptions(key: subscriptionsKey, state: state, peerIds: peerIds)
                                                    }
                                                }
                                                
                                                id = idValue
                                                let (parsedMedia, _, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, toPeerId)
                                                if let parsedMedia = parsedMedia {
                                                    applyMediaResourceChanges(from: originalMedia, to: parsedMedia, postbox: postbox, force: originalMedia is TelegramMediaFile && parsedMedia is TelegramMediaFile)
                                                }
                                            default:
                                                break
                                            }
                                        }
                                    }
                                    
                                    if let id = id {
                                        _internal_putPendingStoryIdMapping(peerId: toPeerId, stableId: stableId, id: id)
                                    }
                                    
                                    stateManager.addUpdates(updates)
                                }
                                
                                return .completed(id)
                            }
                        }
                    default:
                        return .complete()
                    }
                }
                |> switchToLatest
            default:
                return .complete()
            }
        }
    }
}

func _internal_uploadBotPreviewImpl(
    postbox: Postbox,
    network: Network,
    accountPeerId: PeerId,
    stateManager: AccountStateManager,
    messageMediaPreuploadManager: MessageMediaPreuploadManager,
    revalidationContext: MediaReferenceRevalidationContext,
    auxiliaryMethods: AccountAuxiliaryMethods,
    toPeerId: PeerId,
    language: String?,
    stableId: Int32,
    media: Media,
    mediaAreas: [MediaArea],
    text: String,
    entities: [MessageTextEntity],
    embeddedStickers: [TelegramMediaFile],
    randomId: Int64
) -> Signal<StoryUploadResult, NoError> {
    return postbox.transaction { transaction -> Api.InputUser? in
        if let peer = transaction.getPeer(toPeerId) {
            return apiInputUser(peer)
        }
        return nil
    }
    |> mapToSignal { inputUser -> Signal<StoryUploadResult, NoError> in
        guard let inputUser else {
            return .single(.completed(nil))
        }
        
        let passFetchProgress = media is TelegramMediaFile
        let (contentSignal, originalMedia) = uploadedStoryContent(postbox: postbox, network: network, media: media, mediaReference: nil, embeddedStickers: embeddedStickers, accountPeerId: accountPeerId, messageMediaPreuploadManager: messageMediaPreuploadManager, revalidationContext: revalidationContext, auxiliaryMethods: auxiliaryMethods, passFetchProgress: passFetchProgress)
        return contentSignal
        |> mapToSignal { result -> Signal<StoryUploadResult, NoError> in
            switch result {
            case let .progress(progress):
                return .single(.progress(progress.progress))
            case let .content(content):
                return postbox.transaction { transaction -> Signal<StoryUploadResult, NoError> in
                    switch content.content {
                    case let .media(inputMedia, _):
                        return network.request(Api.functions.bots.addPreviewMedia(bot: inputUser, langCode: language ?? "", media: inputMedia))
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<Api.BotPreviewMedia?, NoError> in
                            return .single(nil)
                        }
                        |> mapToSignal { resultPreviewMedia -> Signal<StoryUploadResult, NoError> in
                            guard let resultPreviewMedia else {
                                return .single(.completed(nil))
                            }
                            switch resultPreviewMedia {
                            case let .botPreviewMedia(date, resultMedia):
                                return postbox.transaction { transaction -> StoryUploadResult in
                                    var currentState: Stories.LocalState
                                    if let value = transaction.getLocalStoryState()?.get(Stories.LocalState.self) {
                                        currentState = value
                                    } else {
                                        currentState = Stories.LocalState(items: [])
                                    }
                                    if let index = currentState.items.firstIndex(where: { $0.stableId == stableId }) {
                                        currentState.items.remove(at: index)
                                        transaction.setLocalStoryState(state: CodableEntry(currentState))
                                    }
                                    
                                    if let resultMediaValue = textMediaAndExpirationTimerFromApiMedia(resultMedia, toPeerId).media {
                                        applyMediaResourceChanges(from: originalMedia, to: resultMediaValue, postbox: postbox, force: originalMedia is TelegramMediaFile && resultMediaValue is TelegramMediaFile)
                                        
                                        let addedItem = CachedUserData.BotPreview.Item(media: resultMediaValue, timestamp: date)
                                        
                                        if let mediaId = resultMediaValue.id {
                                            _internal_putPendingBotPreviewIdMapping(peerId: toPeerId, stableId: stableId, id: mediaId)
                                        }
                                        
                                        if language == nil {
                                            transaction.updatePeerCachedData(peerIds: Set([toPeerId]), update: { _, current in
                                                guard var current = current as? CachedUserData else {
                                                    return current
                                                }
                                                guard let currentBotPreview = current.botPreview else {
                                                    return current
                                                }
                                                var items = currentBotPreview.items
                                                if let index = items.firstIndex(where: { $0.media.id == resultMediaValue.id }) {
                                                    items.remove(at: index)
                                                }
                                                items.insert(addedItem, at: 0)
                                                let botPreview = CachedUserData.BotPreview(items: items, alternativeLanguageCodes: currentBotPreview.alternativeLanguageCodes)
                                                current = current.withUpdatedBotPreview(botPreview)
                                                return current
                                            })
                                        }
                                        stateManager.injectBotPreviewUpdates(updates: [
                                            .added(peerId: toPeerId, language: language, item: addedItem)
                                        ])
                                    }
                                    
                                    return .completed(nil)
                                }
                            }
                        }
                    default:
                        return .complete()
                    }
                }
                |> switchToLatest
            default:
                return .complete()
            }
        }
    }
}

func _internal_deleteBotPreviews(account: Account, peerId: PeerId, language: String?, media: [Media]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Api.InputUser?, [Api.InputMedia]) in
        guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputUser) else {
            return (nil, [])
        }
        
        var inputMedia: [Api.InputMedia] = []
        for item in media {
            if let image = item as? TelegramMediaImage, let resource = image.representations.last?.resource as? CloudPhotoSizeMediaResource {
                inputMedia.append(.inputMediaPhoto(flags: 0, id: .inputPhoto(id: resource.photoId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference)), ttlSeconds: nil))
                inputMedia.append(Api.InputMedia.inputMediaPhoto(flags: 0, id: Api.InputPhoto.inputPhoto(id: resource.photoId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference)), ttlSeconds: nil))
            } else if let file = item as? TelegramMediaFile, let resource = file.resource as? CloudDocumentMediaResource {
                inputMedia.append(.inputMediaDocument(flags: 0, id: .inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference ?? Data())), ttlSeconds: nil, query: nil))
            }
        }
        if language == nil {
            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current -> CachedPeerData? in
                guard var current = current as? CachedUserData else {
                    return current
                }
                guard let currentBotPreview = current.botPreview else {
                    return current
                }
                var items = currentBotPreview.items
                
                items = items.filter({ item in
                    guard let id = item.media.id else {
                        return false
                    }
                    return !media.contains(where: { $0.id == id })
                })
                let botPreview = CachedUserData.BotPreview(items: items, alternativeLanguageCodes: currentBotPreview.alternativeLanguageCodes)
                current = current.withUpdatedBotPreview(botPreview)
                return current
            })
        }
        
        return (inputPeer, inputMedia)
    }
    |> mapToSignal { inputPeer, inputMedia -> Signal<Never, NoError> in
        guard let inputPeer else {
            return .complete()
        }
        
        account.stateManager.injectBotPreviewUpdates(updates: [
            .deleted(peerId: peerId, language: language, ids: media.compactMap(\.id))
        ])
        
        return account.network.request(Api.functions.bots.deletePreviewMedia(bot: inputPeer, langCode: language ?? "", media: inputMedia))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Never, NoError> in
            return .complete()
        }
    }
}

func _internal_deleteBotPreviewsLanguage(account: Account, peerId: PeerId, language: String, media: [Media]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Api.InputUser?, [Api.InputMedia]) in
        guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputUser) else {
            return (nil, [])
        }
        
        var inputMedia: [Api.InputMedia] = []
        for item in media {
            if let image = item as? TelegramMediaImage, let resource = image.representations.last?.resource as? CloudPhotoSizeMediaResource {
                inputMedia.append(.inputMediaPhoto(flags: 0, id: .inputPhoto(id: resource.photoId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference)), ttlSeconds: nil))
                inputMedia.append(Api.InputMedia.inputMediaPhoto(flags: 0, id: Api.InputPhoto.inputPhoto(id: resource.photoId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference)), ttlSeconds: nil))
            } else if let file = item as? TelegramMediaFile, let resource = file.resource as? CloudDocumentMediaResource {
                inputMedia.append(.inputMediaDocument(flags: 0, id: .inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference ?? Data())), ttlSeconds: nil, query: nil))
            }
        }
        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current -> CachedPeerData? in
            guard var current = current as? CachedUserData else {
                return current
            }
            guard let currentBotPreview = current.botPreview else {
                return current
            }
            var alternativeLanguageCodes = currentBotPreview.alternativeLanguageCodes
            alternativeLanguageCodes = alternativeLanguageCodes.filter { item in
                return item != language
            }
            let botPreview = CachedUserData.BotPreview(items: currentBotPreview.items, alternativeLanguageCodes: alternativeLanguageCodes)
            current = current.withUpdatedBotPreview(botPreview)
            return current
        })
        
        return (inputPeer, inputMedia)
    }
    |> mapToSignal { inputPeer, inputMedia -> Signal<Never, NoError> in
        guard let inputPeer else {
            return .complete()
        }
        
        account.stateManager.injectBotPreviewUpdates(updates: [
            .deleted(peerId: peerId, language: language, ids: media.compactMap(\.id))
        ])
        
        return account.network.request(Api.functions.bots.deletePreviewMedia(bot: inputPeer, langCode: language, media: inputMedia))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ -> Signal<Never, NoError> in
            return .complete()
        }
    }
}

func _internal_editStory(account: Account, peerId: PeerId, id: Int32, media: EngineStoryInputMedia?, mediaAreas: [MediaArea]?, text: String?, entities: [MessageTextEntity]?, privacy: EngineStoryPrivacy?) -> Signal<StoryUploadResult, NoError> {
    let contentSignal: Signal<PendingMessageUploadedContentResult?, NoError>
    let originalMedia: Media?
    if let media = media {
        var passFetchProgress = false
        if case .video = media {
            passFetchProgress = true
        }
        (contentSignal, originalMedia) = uploadedStoryContent(postbox: account.postbox, network: account.network, media: prepareUploadStoryContent(account: account, media: media), mediaReference: nil, embeddedStickers: media.embeddedStickers, accountPeerId: account.peerId, messageMediaPreuploadManager: account.messageMediaPreuploadManager, revalidationContext: account.mediaReferenceRevalidationContext, auxiliaryMethods: account.auxiliaryMethods, passFetchProgress: passFetchProgress)
    } else {
        contentSignal = .single(nil)
        originalMedia = nil
    }
    
    return contentSignal
    |> mapToSignal { result -> Signal<StoryUploadResult, NoError> in
        if let result = result, case let .progress(progress) = result {
            return .single(.progress(progress.progress))
        }
        
        var updatingCoverTime = false
        let inputMedia: Api.InputMedia?
        if let result = result, case let .content(uploadedContent) = result, case let .media(media, _) = uploadedContent.content {
            inputMedia = media
        } else if case let .existing(media) = media, let file = media as? TelegramMediaFile, let resource = file.resource as? CloudDocumentMediaResource {
            inputMedia = .inputMediaUploadedDocument(flags: 0, file: .inputFileStoryDocument(id: .inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))), thumb: nil, mimeType: file.mimeType, attributes: inputDocumentAttributesFromFileAttributes(file.attributes), stickers: nil, ttlSeconds: nil)
            updatingCoverTime = true
        } else {
            inputMedia = nil
        }
        
        return account.postbox.transaction { transaction -> Signal<StoryUploadResult, NoError> in
            guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) else {
                return .single(.completed(nil))
            }
            
            var flags: Int32 = 0
            var apiCaption: String?
            var apiEntities: [Api.MessageEntity]?
            var privacyRules: [Api.InputPrivacyRule]?
            
            if let _ = inputMedia {
                flags |= 1 << 0
            }
            if let text = text  {
                flags |= 1 << 1
                apiCaption = text
                
                if let entities = entities {
                    var associatedPeers: [PeerId: Peer] = [:]
                    for entity in entities {
                        for entityPeerId in entity.associatedPeerIds {
                            if let peer = transaction.getPeer(entityPeerId) {
                                associatedPeers[peer.id] = peer
                            }
                        }
                    }
                    apiEntities = apiEntitiesFromMessageTextEntities(entities, associatedPeers: SimpleDictionary(associatedPeers))
                }
            }
            if let privacy = privacy {
                privacyRules = apiInputPrivacyRules(privacy: privacy, transaction: transaction)
                flags |= 1 << 2
            }
            
            let inputMediaAreas: [Api.MediaArea]? = mediaAreas.flatMap { apiMediaAreasFromMediaAreas($0, transaction: transaction) }
            if let inputMediaAreas = inputMediaAreas, !inputMediaAreas.isEmpty {
                flags |= 1 << 3
            }
            
            return account.network.request(Api.functions.stories.editStory(
                flags: flags,
                peer: inputPeer,
                id: id,
                media: inputMedia,
                mediaAreas: inputMediaAreas,
                caption: apiCaption,
                entities: apiEntities,
                privacyRules: privacyRules
            ))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { updates -> Signal<StoryUploadResult, NoError> in
                if let updates = updates {
                    for update in updates.allUpdates {
                        if case let .updateStory(_, story) = update {
                            switch story {
                            case let .storyItem(_, _, _, _, _, _, _, _, media, _, _, _, _):
                                let (parsedMedia, _, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, account.peerId)
                                if let parsedMedia = parsedMedia, let originalMedia = originalMedia {
                                    applyMediaResourceChanges(from: originalMedia, to: parsedMedia, postbox: account.postbox, force: false, skipPreviews: updatingCoverTime)
                                }
                            default:
                                break
                            }
                        }
                    }
                    account.stateManager.addUpdates(updates)
                }
                
                return .single(.completed(id))
            }
        }
        |> switchToLatest
    }
}

func _internal_editStoryPrivacy(account: Account, id: Int32, privacy: EngineStoryPrivacy) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> [Api.InputPrivacyRule] in
        let storyId = StoryId(peerId: account.peerId, id: id)
        if let storyItem = transaction.getStory(id: storyId)?.get(Stories.StoredItem.self), case let .item(item) = storyItem {
            let updatedItem = Stories.Item(
                id: item.id,
                timestamp: item.timestamp,
                expirationTimestamp: item.expirationTimestamp,
                media: item.media,
                alternativeMediaList: item.alternativeMediaList,
                mediaAreas: item.mediaAreas,
                text: item.text,
                entities: item.entities,
                views: item.views,
                privacy: Stories.Item.Privacy(base: privacy.base, additionallyIncludePeers: privacy.additionallyIncludePeers),
                isPinned: item.isPinned,
                isExpired: item.isExpired,
                isPublic: item.isPublic,
                isCloseFriends: item.isCloseFriends,
                isContacts: item.isContacts,
                isSelectedContacts: item.isSelectedContacts,
                isForwardingDisabled: item.isForwardingDisabled,
                isEdited: item.isEdited,
                isMy: item.isMy,
                myReaction: item.myReaction,
                forwardInfo: item.forwardInfo,
                authorId: item.authorId
            )
            if let entry = CodableEntry(Stories.StoredItem.item(updatedItem)) {
                transaction.setStory(id: storyId, value: entry)
            }
        }
        
        var items = transaction.getStoryItems(peerId: account.peerId)
        var updatedItems: [Stories.Item] = []
        if let index = items.firstIndex(where: { $0.id == id }), case let .item(item) = items[index].value.get(Stories.StoredItem.self) {
            let updatedItem = Stories.Item(
                id: item.id,
                timestamp: item.timestamp,
                expirationTimestamp: item.expirationTimestamp,
                media: item.media,
                alternativeMediaList: item.alternativeMediaList,
                mediaAreas: item.mediaAreas,
                text: item.text,
                entities: item.entities,
                views: item.views,
                privacy: Stories.Item.Privacy(base: privacy.base, additionallyIncludePeers: privacy.additionallyIncludePeers),
                isPinned: item.isPinned,
                isExpired: item.isExpired,
                isPublic: item.isPublic,
                isCloseFriends: item.isCloseFriends,
                isContacts: item.isContacts,
                isSelectedContacts: item.isSelectedContacts,
                isForwardingDisabled: item.isForwardingDisabled,
                isEdited: item.isEdited,
                isMy: item.isMy,
                myReaction: item.myReaction,
                forwardInfo: item.forwardInfo,
                authorId: item.authorId
            )
            if let entry = CodableEntry(Stories.StoredItem.item(updatedItem)) {
                items[index] = StoryItemsTableEntry(value: entry, id: item.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends)
            }
            
            updatedItems.append(updatedItem)
        }
        transaction.setStoryItems(peerId: account.peerId, items: items)
        
        return apiInputPrivacyRules(privacy: privacy, transaction: transaction)
    }
    |> mapToSignal { inputRules -> Signal<Never, NoError> in
        var flags: Int32 = 0
        flags |= 1 << 2
        
        return account.network.request(Api.functions.stories.editStory(flags: flags, peer: .inputPeerSelf, id: id, media: nil, mediaAreas: nil, caption: nil, entities: nil, privacyRules: inputRules))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Never, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
            }
            
            return .complete()
        }
    }
}

public enum StoriesUploadAvailability {
    case available
    case weeklyLimit
    case monthlyLimit
    case expiringLimit
    case premiumRequired
    case unknownLimit
    case channelBoostRequired
}

func _internal_checkStoriesUploadAvailability(account: Account, target: Stories.PendingTarget) -> Signal<StoriesUploadAvailability, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        switch target {
        case .myStories:
            return .inputPeerSelf
        case let .peer(peerId):
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        case .botPreview:
            return nil
        }
    }
    |> mapToSignal { inputPeer -> Signal<StoriesUploadAvailability, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(.unknownLimit)
        }
        
        return account.network.request(Api.functions.stories.canSendStory(peer: inputPeer))
        |> map { result -> StoriesUploadAvailability in
            if result == .boolTrue {
                return .available
            } else {
                return .unknownLimit
            }
        }
        |> `catch` { error -> Signal<StoriesUploadAvailability, NoError> in
            if error.errorDescription.hasPrefix("STORY_SEND_FLOOD_WEEKLY_") {
                return .single(.weeklyLimit)
            } else if error.errorDescription.hasPrefix("STORY_SEND_FLOOD_MONTHLY_") {
                return .single(.monthlyLimit)
            } else if error.errorDescription.hasPrefix("PREMIUM_ACCOUNT_REQUIRED") {
                return .single(.premiumRequired)
            } else if error.errorDescription.hasPrefix("STORIES_TOO_MUCH") {
                return .single(.expiringLimit)
            } else if error.errorDescription.hasPrefix("BOOSTS_REQUIRED") {
                return .single(.channelBoostRequired)
            }
            return .single(.unknownLimit)
        }
    }
}

func _internal_deleteStories(account: Account, peerId: PeerId, ids: [Int32]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) else {
            return nil
        }
        
        var items = transaction.getStoryItems(peerId: peerId)
        var updated = false
        for id in ids {
            if let index = items.firstIndex(where: { $0.id == id }) {
                items.remove(at: index)
                updated = true
            }
        }
        if updated {
            transaction.setStoryItems(peerId: peerId, items: items)
        }
        account.stateManager.injectStoryUpdates(updates: ids.map { id in
            return .deleted(peerId: peerId, id: id)
        })
        
        return inputPeer
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        
        return account.network.request(Api.functions.stories.deleteStories(peer: inputPeer, id: ids))
        |> `catch` { _ -> Signal<[Int32], NoError> in
            return .single([])
        }
        |> mapToSignal { _ -> Signal<Never, NoError> in
            return .complete()
        }
    }
}

func _internal_markStoryAsSeen(account: Account, peerId: PeerId, id: Int32, asPinned: Bool) -> Signal<Never, NoError> {
    if asPinned {
        return account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<Never, NoError> in
            guard let inputPeer = inputPeer else {
                return .complete()
            }
            
            #if DEBUG && false
            if "".isEmpty {
                return .complete()
            }
            #endif
            
            return account.network.request(Api.functions.stories.incrementStoryViews(peer: inputPeer, id: [id]))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
        }
    } else {
        return account.postbox.transaction { transaction -> Api.InputUser? in
            if let peerStoryState = transaction.getPeerStoryState(peerId: peerId)?.entry.get(Stories.PeerState.self) {
                transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(
                    maxReadId: max(peerStoryState.maxReadId, id)
                ).postboxRepresentation)
            }
            
            #if DEBUG && false
            #else
            _internal_addSynchronizeViewStoriesOperation(peerId: peerId, storyId: id, transaction: transaction)
            #endif
            
            return transaction.getPeer(peerId).flatMap(apiInputUser)
        }
        |> mapToSignal { _ -> Signal<Never, NoError> in
            account.stateManager.injectStoryUpdates(updates: [.read(peerId: peerId, maxId: id)])
            
            return .complete()
        }
    }
}

func _internal_updateStoriesArePinned(account: Account, peerId: PeerId, ids: [Int32: EngineStoryItem], isPinned: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) else {
            return nil
        }
        
        var items = transaction.getStoryItems(peerId: peerId)
        var updatedItems: [Stories.Item] = []
        for (id, referenceItem) in ids {
            if let index = items.firstIndex(where: { $0.id == id }), case let .item(item) = items[index].value.get(Stories.StoredItem.self) {
                let updatedItem = Stories.Item(
                    id: item.id,
                    timestamp: item.timestamp,
                    expirationTimestamp: item.expirationTimestamp,
                    media: item.media,
                    alternativeMediaList: item.alternativeMediaList,
                    mediaAreas: item.mediaAreas,
                    text: item.text,
                    entities: item.entities,
                    views: item.views,
                    privacy: item.privacy,
                    isPinned: isPinned,
                    isExpired: item.isExpired,
                    isPublic: item.isPublic,
                    isCloseFriends: item.isCloseFriends,
                    isContacts: item.isContacts,
                    isSelectedContacts: item.isSelectedContacts,
                    isForwardingDisabled: item.isForwardingDisabled,
                    isEdited: item.isEdited,
                    isMy: item.isMy,
                    myReaction: item.myReaction,
                    forwardInfo: item.forwardInfo,
                    authorId: item.authorId
                )
                if let entry = CodableEntry(Stories.StoredItem.item(updatedItem)) {
                    items[index] = StoryItemsTableEntry(value: entry, id: item.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends)
                }
                
                updatedItems.append(updatedItem)
            } else {
                let item = referenceItem.asStoryItem()
                let updatedItem = Stories.Item(
                    id: item.id,
                    timestamp: item.timestamp,
                    expirationTimestamp: item.expirationTimestamp,
                    media: item.media,
                    alternativeMediaList: item.alternativeMediaList,
                    mediaAreas: item.mediaAreas,
                    text: item.text,
                    entities: item.entities,
                    views: item.views,
                    privacy: item.privacy,
                    isPinned: isPinned,
                    isExpired: item.isExpired,
                    isPublic: item.isPublic,
                    isCloseFriends: item.isCloseFriends,
                    isContacts: item.isContacts,
                    isSelectedContacts: item.isSelectedContacts,
                    isForwardingDisabled: item.isForwardingDisabled,
                    isEdited: item.isEdited,
                    isMy: item.isMy,
                    myReaction: item.myReaction,
                    forwardInfo: item.forwardInfo,
                    authorId: item.authorId
                )
                updatedItems.append(updatedItem)
            }
        }
        transaction.setStoryItems(peerId: peerId, items: items)
        if !updatedItems.isEmpty {
            DispatchQueue.main.async {
                account.stateManager.injectStoryUpdates(updates: updatedItems.map { updatedItem in
                    return .added(peerId: peerId, item: Stories.StoredItem.item(updatedItem))
                })
            }
        }
        
        return inputPeer
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        
        return account.network.request(Api.functions.stories.togglePinned(peer: inputPeer, id: ids.keys.sorted(), pinned: isPinned ? .boolTrue : .boolFalse))
        |> `catch` { _ -> Signal<[Int32], NoError> in
            return .single([])
        }
        |> ignoreValues
    }
}

func _internal_updatePinnedToTopStories(account: Account, peerId: PeerId, ids: [Int32]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) else {
            return nil
        }
        
        DispatchQueue.main.async {
            account.stateManager.injectStoryUpdates(updates: [.updatePinnedToTopList(peerId: peerId, ids: ids)])
        }
        
        return inputPeer
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer else {
            return .complete()
        }
        return account.network.request(Api.functions.stories.togglePinnedToTop(peer: inputPeer, id: ids))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> ignoreValues
    }
}

extension Api.StoryItem {
    var id: Int32 {
        switch self {
        case let .storyItem(_, id, _, _, _, _, _, _, _, _, _, _, _):
            return id
        case let .storyItemDeleted(id):
            return id
        case let .storyItemSkipped(_, id, _, _):
            return id
        }
    }
}

extension Stories.Item.Views {
    init(apiViews: Api.StoryViews) {
        switch apiViews {
        case let .storyViews(flags, viewsCount, forwardsCount, reactions, reactionsCount, recentViewers):
            //storyViews#8d595cd6 flags:# has_viewers:flags.1?true views_count:int forwards_count:flags.2?int reactions:flags.3?Vector<ReactionCount> reactions_count:flags.4?int recent_viewers:flags.0?Vector<long> = StoryViews;
            let hasList = (flags & (1 << 1)) != 0
            var seenPeerIds: [PeerId] = []
            if let recentViewers = recentViewers {
                seenPeerIds = recentViewers.map { PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) }
            }
            var mappedReactions: [MessageReaction] = []
            if let reactions = reactions {
                for result in reactions {
                    switch result {
                    case let .reactionCount(_, chosenOrder, reaction, count):
                        if let reaction = MessageReaction.Reaction(apiReaction: reaction) {
                            mappedReactions.append(MessageReaction(value: reaction, count: count, chosenOrder: chosenOrder.flatMap(Int.init)))
                        }
                    }
                }
            }
            self.init(
                seenCount: Int(viewsCount),
                reactedCount: Int(reactionsCount ?? 0),
                forwardCount: Int(forwardsCount ?? 0),
                seenPeerIds: seenPeerIds,
                reactions: mappedReactions,
                hasList: hasList
            )
        }
    }
}

extension Stories.Item.ForwardInfo {
    init?(apiForwardInfo: Api.StoryFwdHeader) {
        switch apiForwardInfo {
        case let .storyFwdHeader(flags, from, fromName, storyId):
            let isModified = (flags & (1 << 3)) != 0
            if let from = from, let storyId = storyId {
                self = .known(peerId: from.peerId, storyId: storyId, isModified: isModified)
                return
            } else if let fromName = fromName {
                self = .unknown(name: fromName, isModified: isModified)
                return
            }
        }
        return nil
    }
}

extension Stories.StoredItem {
    init?(apiStoryItem: Api.StoryItem, existingItem: Stories.Item? = nil, peerId: PeerId, transaction: Transaction) {
        switch apiStoryItem {
        case let .storyItem(flags, id, date, fromId, forwardFrom, expireDate, caption, entities, media, mediaAreas, privacy, views, sentReaction):
            let (parsedMedia, _, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
            if let parsedMedia = parsedMedia {
                var parsedPrivacy: Stories.Item.Privacy?
                if let privacy = privacy {
                    var base: Stories.Item.Privacy.Base = .nobody
                    var additionalPeerIds: [PeerId] = []
                    for rule in privacy {
                        switch rule {
                        case .privacyValueAllowAll:
                            base = .everyone
                        case .privacyValueAllowContacts:
                            base = .contacts
                        case .privacyValueAllowCloseFriends:
                            base = .closeFriends
                        case .privacyValueAllowPremium:
                            base = .everyone
                        case .privacyValueDisallowAll:
                            base = .nobody
                        case let .privacyValueAllowUsers(users):
                            for id in users {
                                additionalPeerIds.append(EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)))
                            }
                        case let .privacyValueDisallowUsers(users):
                            for id in users {
                                additionalPeerIds.append(EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)))
                            }
                        case let .privacyValueAllowChatParticipants(chats):
                            for id in chats {
                                if let peer = transaction.getPeer(EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(id))) {
                                    additionalPeerIds.append(peer.id)
                                } else if let peer = transaction.getPeer(EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(id))) {
                                    additionalPeerIds.append(peer.id)
                                }
                            }
                        default:
                            break
                        }
                    }
                    parsedPrivacy = Stories.Item.Privacy(base: base, additionallyIncludePeers: additionalPeerIds)
                }
                
                let isPinned = (flags & (1 << 5)) != 0
                let isExpired = (flags & (1 << 6)) != 0
                let isPublic = (flags & (1 << 7)) != 0
                let isCloseFriends = (flags & (1 << 8)) != 0
                let isMin = (flags & (1 << 9)) != 0
                let isForwardingDisabled = (flags & (1 << 10)) != 0
                let isEdited = (flags & (1 << 11)) != 0
                let isContacts = (flags & (1 << 12)) != 0
                let isSelectedContacts = (flags & (1 << 13)) != 0
                
                var mergedViews: Stories.Item.Views?
                if isMin, let existingItem = existingItem {
                    mergedViews = existingItem.views
                } else {
                    mergedViews = views.flatMap(Stories.Item.Views.init(apiViews:))
                }
                
                var mergedMyReaction: MessageReaction.Reaction?
                if isMin, let existingItem = existingItem {
                    mergedMyReaction = existingItem.myReaction
                } else {
                    mergedMyReaction = sentReaction.flatMap(MessageReaction.Reaction.init(apiReaction:))
                }
                
                var mergedIsMy: Bool
                if isMin, let existingItem = existingItem {
                    mergedIsMy = existingItem.isMy
                } else {
                    mergedIsMy = (flags & (1 << 16)) != 0
                }
                
                var mergedForwardInfo: Stories.Item.ForwardInfo?
                if isMin, let existingItem = existingItem {
                    mergedForwardInfo = existingItem.forwardInfo
                } else {
                    mergedForwardInfo = forwardFrom.flatMap(Stories.Item.ForwardInfo.init(apiForwardInfo:))
                }
                
                var parsedAlternativeMedia: [Media] = []
                switch media {
                case let .messageMediaDocument(_, _, altDocuments, _):
                    if let altDocuments {
                        parsedAlternativeMedia = altDocuments.compactMap { telegramMediaFileFromApiDocument($0, altDocuments: []) }
                    }
                default:
                    break
                }
                
                let item = Stories.Item(
                    id: id,
                    timestamp: date,
                    expirationTimestamp: expireDate,
                    media: parsedMedia,
                    alternativeMediaList: parsedAlternativeMedia,
                    mediaAreas: mediaAreas?.compactMap(mediaAreaFromApiMediaArea) ?? [],
                    text: caption ?? "",
                    entities: entities.flatMap { entities in return messageTextEntitiesFromApiEntities(entities) } ?? [],
                    views: mergedViews,
                    privacy: parsedPrivacy,
                    isPinned: isPinned,
                    isExpired: isExpired,
                    isPublic: isPublic,
                    isCloseFriends: isCloseFriends,
                    isContacts: isContacts,
                    isSelectedContacts: isSelectedContacts,
                    isForwardingDisabled: isForwardingDisabled,
                    isEdited: isEdited,
                    isMy: mergedIsMy,
                    myReaction: mergedMyReaction,
                    forwardInfo: mergedForwardInfo,
                    authorId: fromId?.peerId
                )
                self = .item(item)
            } else {
                return nil
            }
        case let .storyItemSkipped(flags, id, date, expireDate):
            let isCloseFriends = (flags & (1 << 8)) != 0
            self = .placeholder(Stories.Placeholder(id: id, timestamp: date, expirationTimestamp: expireDate, isCloseFriends: isCloseFriends))
        case .storyItemDeleted:
            return nil
        }
    }
}

func _internal_getStoryById(accountPeerId: PeerId, postbox: Postbox, network: Network, peerId: EnginePeer.Id, id: Int32) -> Signal<EngineStoryItem?, NoError> {
    let storyId = StoryId(peerId: peerId, id: id)
    return postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> mapToSignal { peer -> Signal<EngineStoryItem?, NoError> in
        guard let inputPeer = peer.flatMap(apiInputPeer) else {
            return .single(nil)
        }
        return network.request(Api.functions.stories.getStoriesByID(peer: inputPeer, id: [id]))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<EngineStoryItem?, NoError> in
            guard let result = result else {
                return .single(nil)
            }
            return postbox.transaction { transaction -> EngineStoryItem? in
                switch result {
                case let .stories(_, _, stories, _, chats, users):
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: users))
                    
                    if let storyItem = stories.first.flatMap({ Stories.StoredItem(apiStoryItem: $0, peerId: peerId, transaction: transaction) }) {
                        if let entry = CodableEntry(storyItem) {
                            transaction.setStory(id: storyId, value: entry)
                        }
                        if case let .item(item) = storyItem, let media = item.media {
                            return EngineStoryItem(
                                id: item.id,
                                timestamp: item.timestamp,
                                expirationTimestamp: item.expirationTimestamp,
                                media: EngineMedia(media),
                                alternativeMediaList: item.alternativeMediaList.map(EngineMedia.init),
                                mediaAreas: item.mediaAreas,
                                text: item.text,
                                entities: item.entities,
                                views: item.views.flatMap { views in
                                    return EngineStoryItem.Views(
                                        seenCount: views.seenCount,
                                        reactedCount: views.reactedCount,
                                        forwardCount: views.forwardCount,
                                        seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                            return transaction.getPeer(id).flatMap(EnginePeer.init)
                                        },
                                        reactions: views.reactions,
                                        hasList: views.hasList
                                    )
                                },
                                privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                                isPinned: item.isPinned,
                                isExpired: item.isExpired,
                                isPublic: item.isPublic,
                                isPending: false,
                                isCloseFriends: item.isCloseFriends,
                                isContacts: item.isContacts,
                                isSelectedContacts: item.isSelectedContacts,
                                isForwardingDisabled: item.isForwardingDisabled,
                                isEdited: item.isEdited,
                                isMy: item.isMy,
                                myReaction: item.myReaction,
                                forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, transaction: transaction) },
                                author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) }
                            )
                        }
                    }
                    return nil
                }
            }
        }
    }
}

func _internal_getStoriesById(accountPeerId: PeerId, postbox: Postbox, network: Network, peer: PeerReference, ids: [Int32]) -> Signal<[Stories.StoredItem], NoError> {
    let inputPeer = peer.inputPeer
    
    return network.request(Api.functions.stories.getStoriesByID(peer: inputPeer, id: ids))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<[Stories.StoredItem], NoError> in
        guard let result = result else {
            return .single([])
        }
        return postbox.transaction { transaction -> [Stories.StoredItem] in
            switch result {
            case let .stories(_, _, stories, _, chats, users):
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: users))
                
                return stories.compactMap { apiStoryItem -> Stories.StoredItem? in
                    return Stories.StoredItem(apiStoryItem: apiStoryItem, peerId: peer.id, transaction: transaction)
                }
            }
        }
    }
}

func _internal_getStoriesById(accountPeerId: PeerId, postbox: Postbox, source: FetchMessageHistoryHoleSource, peerId: PeerId, peerReference: PeerReference?, ids: [Int32], allowFloodWait: Bool) -> Signal<[Stories.StoredItem]?, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<[Stories.StoredItem]?, NoError> in
        guard let inputPeer = inputPeer ?? peerReference?.inputPeer else {
            return .single([])
        }
        
        return source.request(Api.functions.stories.getStoriesByID(peer: inputPeer, id: ids), automaticFloodWait: allowFloodWait)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<[Stories.StoredItem]?, NoError> in
            guard let result = result else {
                return .single(nil)
            }
            return postbox.transaction { transaction -> [Stories.StoredItem]? in
                switch result {
                case let .stories(_, _, stories, _, chats, users):
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: users))
                    
                    return stories.compactMap { apiStoryItem -> Stories.StoredItem? in
                        return Stories.StoredItem(apiStoryItem: apiStoryItem, peerId: peerId, transaction: transaction)
                    }
                }
            }
        }
    }
}

public final class StoryViewList {
    public final class Item {
        public let peer: EnginePeer
        public let timestamp: Int32
        
        public init(peer: EnginePeer, timestamp: Int32) {
            self.peer = peer
            self.timestamp = timestamp
        }
    }
    
    public let items: [Item]
    public let totalCount: Int
    public let totalReactedCount: Int
    
    public init(items: [Item], totalCount: Int, totalReactedCount: Int) {
        self.items = items
        self.totalCount = totalCount
        self.totalReactedCount = totalReactedCount
    }
}

func _internal_getStoryViews(account: Account, peerId: PeerId, ids: [Int32]) -> Signal<[Int32: Stories.Item.Views], NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<[Int32: Stories.Item.Views], NoError> in
        guard let inputPeer = inputPeer else {
            return .single([:])
        }
        
        let accountPeerId = account.peerId
        return account.network.request(Api.functions.stories.getStoriesViews(peer: inputPeer, id: ids))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.stories.StoryViews?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<[Int32: Stories.Item.Views], NoError> in
            guard let result = result else {
                return .single([:])
            }
            return account.postbox.transaction { transaction -> [Int32: Stories.Item.Views] in
                var parsedViews: [Int32: Stories.Item.Views] = [:]
                switch result {
                case let .storyViews(views, users):
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                    
                    for i in 0 ..< views.count {
                        if i < ids.count {
                            parsedViews[ids[i]] = Stories.Item.Views(apiViews: views[i])
                        }
                    }
                }
                
                return parsedViews
            }
        }
    }
}

func _internal_updatePeerStoriesHidden(account: Account, id: PeerId, isHidden: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        guard let peer = transaction.getPeer(id) else {
            return nil
        }
        if let user = peer as? TelegramUser {
            updatePeersCustom(transaction: transaction, peers: [user.withUpdatedStoriesHidden(isHidden)], update: { _, updated in
                return updated
            })
        } else if let channel = peer as? TelegramChannel {
            updatePeersCustom(transaction: transaction, peers: [channel.withUpdatedStoriesHidden(isHidden)], update: { _, updated in
                return updated
            })
        }
        
        return apiInputPeer(peer)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        return account.network.request(Api.functions.stories.togglePeerStoriesHidden(peer: inputPeer, hidden: isHidden ? .boolTrue : .boolFalse))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> ignoreValues
    }
}

func _internal_exportStoryLink(account: Account, peerId: EnginePeer.Id, id: Int32) -> Signal<String?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<String?, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(nil)
        }
        return account.network.request(Api.functions.stories.exportStoryLink(peer: inputPeer, id: id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.ExportedStoryLink?, NoError> in
            return .single(nil)
        }
        |> map { result -> String? in
            guard let result = result else {
                return nil
            }
            switch result {
            case let .exportedStoryLink(link):
                return link
            }
        }
    }
}

func _internal_refreshStories(account: Account, peerId: PeerId, ids: [Int32]) -> Signal<Never, NoError> {
    return _internal_getStoriesById(accountPeerId: account.peerId, postbox: account.postbox, source: .network(account.network), peerId: peerId, peerReference: nil, ids: ids, allowFloodWait: true)
    |> mapToSignal { result -> Signal<Never, NoError> in
        guard let result = result else {
            return .complete()
        }
        return account.postbox.transaction { transaction -> Void in
            var currentItems = transaction.getStoryItems(peerId: peerId)
            for i in 0 ..< currentItems.count {
                if let updatedItem = result.first(where: { $0.id == currentItems[i].id }) {
                    if case .item = updatedItem {
                        if let entry = CodableEntry(updatedItem) {
                            currentItems[i] = StoryItemsTableEntry(value: entry, id: updatedItem.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends)
                        }
                    }
                }
            }
            transaction.setStoryItems(peerId: peerId, items: currentItems)
            
            for id in ids {
                let current = transaction.getStory(id: StoryId(peerId: peerId, id: id))
                var updated: CodableEntry?
                if let updatedItem = result.first(where: { $0.id == id }) {
                    if let entry = CodableEntry(updatedItem) {
                        updated = entry
                    }
                } else {
                    updated = CodableEntry(data: Data())
                }
                if current != updated {
                    transaction.setStory(id: StoryId(peerId: peerId, id: id), value: updated ?? CodableEntry(data: Data()))
                }
            }
        }
        |> ignoreValues
    }
}

func _internal_refreshSeenStories(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    return network.request(Api.functions.stories.getAllReadPeerStories())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { updates -> Signal<Never, NoError> in
        guard let updates = updates else {
            return .complete()
        }
        return postbox.transaction { transaction -> Void in
            for update in updates.allUpdates {
                switch update {
                case let .updateReadStories(peerIdValue, maxId):
                    let peerId = peerIdValue.peerId
                    var update = false
                    if let value = transaction.getPeerStoryState(peerId: peerId) {
                        update = value.maxSeenId < maxId
                    } else {
                        update = true
                    }
                    if update {
                        transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(maxReadId: maxId).postboxRepresentation)
                    }
                default:
                    break
                }
            }
        }
        |> ignoreValues
    }
}

extension Stories.ConfigurationState {
    static var `default`: Stories.ConfigurationState {
        return Stories.ConfigurationState(
            stealthModeState: Stories.StealthModeState(
                activeUntilTimestamp: nil,
                cooldownUntilTimestamp: nil
            )
        )
    }
}

extension Stories.StealthModeState {
    init(apiMode: Api.StoriesStealthMode) {
        switch apiMode {
        case let .storiesStealthMode(_, activeUntilDate, cooldownUntilDate):
            self.init(
                activeUntilTimestamp: activeUntilDate,
                cooldownUntilTimestamp: cooldownUntilDate
            )
        }
    }
}

public extension Stories.StealthModeState {
    func actualizedNow() -> Stories.StealthModeState {
        let timestamp = Int32(Date().timeIntervalSince1970)
        
        var activeUntilTimestamp = self.activeUntilTimestamp
        var cooldownUntilTimestamp = self.cooldownUntilTimestamp
        
        if let activeUntilTimestampValue = activeUntilTimestamp, activeUntilTimestampValue < timestamp {
            activeUntilTimestamp = nil
        }
        if let cooldownUntilTimestampValue = cooldownUntilTimestamp, cooldownUntilTimestampValue < timestamp {
            cooldownUntilTimestamp = nil
        }
        
        return Stories.StealthModeState(
            activeUntilTimestamp: activeUntilTimestamp,
            cooldownUntilTimestamp: cooldownUntilTimestamp
        )
    }
}

func _internal_getStoryConfigurationState(transaction: Transaction) -> Stories.ConfigurationState {
    return transaction.getPreferencesEntry(key: PreferencesKeys.storiesConfiguration)?.get(Stories.ConfigurationState.self) ?? .default
}

func _internal_setStoryConfigurationState(transaction: Transaction, state: Stories.ConfigurationState, force: Bool = false) {
    transaction.setPreferencesEntry(key: PreferencesKeys.storiesConfiguration, value: PreferencesEntry(state))
}

func _internal_enableStoryStealthMode(account: Account) -> Signal<Never, NoError> {
    var flags: Int32 = 0
    flags |= 1 << 0
    flags |= 1 << 1
    return account.network.request(Api.functions.stories.activateStealthMode(flags: flags))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        if let result = result {
            account.stateManager.addUpdates(result)
        }
        
        return account.postbox.transaction { transaction in
            let appConfig = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? .defaultValue
            
            if let data = appConfig.data {
                if let futurePeriod = data["stories_stealth_future_period"] as? Double, let cooldownPeriod = data["stories_stealth_cooldown_period"] as? Double {
                    
                    var futurePeriodInt32: Int32
                    futurePeriodInt32 = Int32(futurePeriod)
                    var cooldownPeriodInt32: Int32
                    cooldownPeriodInt32 = Int32(cooldownPeriod)
                    
                    #if DEBUG && false
                    futurePeriodInt32 = 30
                    cooldownPeriodInt32 = 60
                    #endif
                    
                    var config = _internal_getStoryConfigurationState(transaction: transaction)
                    config.stealthModeState.activeUntilTimestamp = Int32(Date().timeIntervalSince1970) + futurePeriodInt32
                    config.stealthModeState.cooldownUntilTimestamp = Int32(Date().timeIntervalSince1970) + cooldownPeriodInt32
                    _internal_setStoryConfigurationState(transaction: transaction, state: config, force: true)
                }
            }
        }
        |> ignoreValues
    }
}

public func _internal_getStoryNotificationWasDisplayed(transaction: Transaction, id: StoryId) -> Bool {
    let key = ValueBoxKey(length: 8 + 4)
    key.setInt64(0, value: id.peerId.toInt64())
    key.setInt32(8, value: id.id)
    return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.displayedStoryNotifications, key: key)) != nil
}

public func _internal_setStoryNotificationWasDisplayed(transaction: Transaction, id: StoryId) {
    let key = ValueBoxKey(length: 8 + 4)
    key.setInt64(0, value: id.peerId.toInt64())
    key.setInt32(8, value: id.id)
    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.displayedStoryNotifications, key: key), entry: CodableEntry(data: Data()))
}

public func _internal_getMessageNotificationWasDisplayed(transaction: Transaction, id: MessageId) -> Bool {
    let key = ValueBoxKey(length: 8 + 4)
    key.setInt64(0, value: id.peerId.toInt64())
    key.setInt32(8, value: id.id)
    return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.displayedMessageNotifications, key: key)) != nil
}

public func _internal_setMessageNotificationWasDisplayed(transaction: Transaction, id: MessageId) {
    let key = ValueBoxKey(length: 8 + 4)
    key.setInt64(0, value: id.peerId.toInt64())
    key.setInt32(8, value: id.id)
    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.displayedMessageNotifications, key: key), entry: CodableEntry(data: Data()))
}

func _internal_updateStoryViewsForMyReaction(isChannel: Bool, views: Stories.Item.Views?, previousReaction: MessageReaction.Reaction?, reaction: MessageReaction.Reaction?) -> Stories.Item.Views? {
    if !isChannel {
        return views
    }
    
    var views = views ?? Stories.Item.Views(seenCount: 0, reactedCount: 0, forwardCount: 0, seenPeerIds: [], reactions: [], hasList: false)
    
    if let reaction = reaction {
        if previousReaction == nil {
            views.reactedCount += 1
        }
        
        do {
            var reactions = views.reactions
            
            if let previousIndex = reactions.firstIndex(where: { $0.chosenOrder != nil }) {
                reactions[previousIndex].chosenOrder = nil
                reactions[previousIndex].count = max(0, reactions[previousIndex].count - 1)
            }
            if let reactionIndex = reactions.firstIndex(where: { $0.value == reaction }) {
                reactions[reactionIndex].chosenOrder = 0
                reactions[reactionIndex].count += 1
            } else {
                reactions.append(MessageReaction(
                    value: reaction,
                    count: 1,
                    chosenOrder: 0
                ))
            }
            views.reactions = reactions
        }
    } else {
        if previousReaction != nil {
            views.reactedCount = max(0, views.reactedCount - 1)
        }
        do {
            var reactions = views.reactions
            
            if let previousIndex = reactions.firstIndex(where: { $0.chosenOrder != nil }) {
                reactions[previousIndex].chosenOrder = nil
                reactions[previousIndex].count = max(0, reactions[previousIndex].count - 1)
                if reactions[previousIndex].count == 0 {
                    reactions.remove(at: previousIndex)
                }
            }
            views.reactions = reactions
        }
    }
    
    if views.isEmpty {
        return nil
    } else {
        return views
    }
}

func _internal_setStoryReaction(account: Account, peerId: EnginePeer.Id, id: Int32, reaction: MessageReaction.Reaction?) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Stories.StoredItem?, Api.InputPeer?) in
        guard let peer = transaction.getPeer(peerId) else {
            return (nil, nil)
        }
        guard let inputPeer = apiInputPeer(peer) else {
            return (nil, nil)
        }
        
        var updatedItemValue: Stories.StoredItem?
        
        let updateViews: (Stories.Item.Views?, MessageReaction.Reaction?) -> Stories.Item.Views? = { views, previousReaction in
            return _internal_updateStoryViewsForMyReaction(isChannel: peerId.namespace == Namespaces.Peer.CloudChannel, views: views, previousReaction: previousReaction, reaction: reaction)
        }
        
        var currentItems = transaction.getStoryItems(peerId: peerId)
        for i in 0 ..< currentItems.count {
            if currentItems[i].id == id {
                if case let .item(item) = currentItems[i].value.get(Stories.StoredItem.self) {
                    let updatedItem: Stories.StoredItem = .item(Stories.Item(
                        id: item.id,
                        timestamp: item.timestamp,
                        expirationTimestamp: item.expirationTimestamp,
                        media: item.media,
                        alternativeMediaList: item.alternativeMediaList,
                        mediaAreas: item.mediaAreas,
                        text: item.text,
                        entities: item.entities,
                        views: updateViews(item.views, item.myReaction),
                        privacy: item.privacy,
                        isPinned: item.isPinned,
                        isExpired: item.isEdited,
                        isPublic: item.isPublic,
                        isCloseFriends: item.isCloseFriends,
                        isContacts: item.isContacts,
                        isSelectedContacts: item.isSelectedContacts,
                        isForwardingDisabled: item.isForwardingDisabled,
                        isEdited: item.isEdited,
                        isMy: item.isMy,
                        myReaction: reaction,
                        forwardInfo: item.forwardInfo,
                        authorId: item.authorId
                    ))
                    updatedItemValue = updatedItem
                    if let entry = CodableEntry(updatedItem) {
                        currentItems[i] = StoryItemsTableEntry(value: entry, id: updatedItem.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends)
                    }
                }
            }
        }
        transaction.setStoryItems(peerId: peerId, items: currentItems)
        
        if let current = transaction.getStory(id: StoryId(peerId: peerId, id: id))?.get(Stories.StoredItem.self), case let .item(item) = current {
            let updatedItem: Stories.StoredItem = .item(Stories.Item(
                id: item.id,
                timestamp: item.timestamp,
                expirationTimestamp: item.expirationTimestamp,
                media: item.media,
                alternativeMediaList: item.alternativeMediaList,
                mediaAreas: item.mediaAreas,
                text: item.text,
                entities: item.entities,
                views: updateViews(item.views, item.myReaction),
                privacy: item.privacy,
                isPinned: item.isPinned,
                isExpired: item.isEdited,
                isPublic: item.isPublic,
                isCloseFriends: item.isCloseFriends,
                isContacts: item.isContacts,
                isSelectedContacts: item.isSelectedContacts,
                isForwardingDisabled: item.isForwardingDisabled,
                isEdited: item.isEdited,
                isMy: item.isMy,
                myReaction: reaction,
                forwardInfo: item.forwardInfo,
                authorId: item.authorId
            ))
            updatedItemValue = updatedItem
            if let entry = CodableEntry(updatedItem) {
                transaction.setStory(id: StoryId(peerId: peerId, id: id), value: entry)
            }
        }
        
        return (updatedItemValue, inputPeer)
    }
    |> mapToSignal { storyItem, inputPeer -> Signal<Never, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        
        if let storyItem {
            account.stateManager.injectStoryUpdates(updates: [InternalStoryUpdate.added(peerId: peerId, item: storyItem)])
        }
        account.stateManager.injectStoryUpdates(updates: [InternalStoryUpdate.updateMyReaction(peerId: peerId, id: id, reaction: reaction)])
        
        return account.network.request(Api.functions.stories.sendReaction(flags: 0, peer: inputPeer, storyId: id, reaction: reaction?.apiReaction ?? .reactionEmpty))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Never, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
            }
            
            return .complete()
        }
    }
}
