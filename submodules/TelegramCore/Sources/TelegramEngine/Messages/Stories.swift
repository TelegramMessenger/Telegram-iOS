import Foundation
import SwiftSignalKit
import Postbox
internal import TelegramApi

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
            case music
            case authorId
            case folderIds
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
        public let music: TelegramMediaFile?
        public let authorId: PeerId?
        public let folderIds: [Int64]?
        
        public var isLiveStream: Bool {
            return self.media is TelegramMediaLiveStream
        }
        
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
            music: TelegramMediaFile?,
            authorId: PeerId?,
            folderIds: [Int64]?
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
            self.music = music
            self.authorId = authorId
            self.folderIds = folderIds
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
            
            if let musicData = try container.decodeIfPresent(Data.self, forKey: .music) {
                self.music = PostboxDecoder(buffer: MemoryBuffer(data: musicData)).decodeRootObject() as? TelegramMediaFile
            } else {
                self.music = nil
            }
            
            self.authorId = try container.decodeIfPresent(Int64.self, forKey: .authorId).flatMap { PeerId($0) }
            self.folderIds = try container.decodeIfPresent([Int64].self, forKey: .folderIds)
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
            
            if let music = self.music {
                let encoder = PostboxEncoder()
                encoder.encodeRootObject(music)
                let musicData = encoder.makeData()
                try container.encode(musicData, forKey: .music)
            }
            
            try container.encodeIfPresent(self.authorId?.toInt64(), forKey: .authorId)
            try container.encodeIfPresent(self.folderIds, forKey: .folderIds)
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
            if let lhsMusic = lhs.music, let rhsMusic = rhs.music {
                if !lhsMusic.isEqual(to: rhsMusic) {
                    return false
                }
            } else {
                if (lhs.music == nil) != (rhs.music == nil) {
                    return false
                }
            }
            if lhs.authorId != rhs.authorId {
                return false
            }
            if lhs.folderIds != rhs.folderIds {
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
            case isLiveItem = "liv"
        }
        
        public let id: Int32
        public let timestamp: Int32
        public let expirationTimestamp: Int32
        public let isCloseFriends: Bool
        public let isLiveItem: Bool
        
        public init(
            id: Int32,
            timestamp: Int32,
            expirationTimestamp: Int32,
            isCloseFriends: Bool,
            isLiveItem: Bool
        ) {
            self.id = id
            self.timestamp = timestamp
            self.expirationTimestamp = expirationTimestamp
            self.isCloseFriends = isCloseFriends
            self.isLiveItem = isLiveItem
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(Int32.self, forKey: .id)
            self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
            self.expirationTimestamp = try container.decode(Int32.self, forKey: .expirationTimestamp)
            self.isCloseFriends = try container.decodeIfPresent(Bool.self, forKey: .isCloseFriends) ?? false
            self.isLiveItem = try container.decodeIfPresent(Bool.self, forKey: .isLiveItem) ?? false
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.id, forKey: .id)
            try container.encode(self.timestamp, forKey: .timestamp)
            try container.encode(self.expirationTimestamp, forKey: .expirationTimestamp)
            try container.encode(self.isCloseFriends, forKey: .isCloseFriends)
            try container.encode(self.isLiveItem, forKey: .isLiveItem)
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
            if lhs.isLiveItem != rhs.isLiveItem {
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
        
        public var isLiveStream: Bool {
            switch self {
            case let .item(item):
                return item.media is TelegramMediaLiveStream
            case let .placeholder(placeholder):
                return placeholder.isLiveItem
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
        public let hasLiveItems: Bool
        public let hasPending: Bool
        public let storyCount: Int
        public let unseenCount: Int
        public let lastTimestamp: Int32
        
        public init(
            peer: EnginePeer,
            hasUnseen: Bool,
            hasUnseenCloseFriends: Bool,
            hasLiveItems: Bool,
            hasPending: Bool,
            storyCount: Int,
            unseenCount: Int,
            lastTimestamp: Int32
        ) {
            self.peer = peer
            self.hasUnseen = hasUnseen
            self.hasUnseenCloseFriends = hasUnseenCloseFriends
            self.hasLiveItems = hasLiveItems
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
            if lhs.hasLiveItems != rhs.hasLiveItems {
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

enum PendingStoryUploadInternalPhase {
    case processing
    case uploading
}

enum PendingStoryUploadResult {
    case progress(Float, PendingStoryUploadInternalPhase)
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

private func apiInputPrivacyRules(privacy: EngineStoryPrivacy, transaction: Transaction) -> [Api.InputPrivacyRule]? {
    var privacyUsers: [Api.InputUser] = []
    var privacyChats: [Int64] = []
    var seenPeerIds = Set<PeerId>()
    for peerId in privacy.additionallyIncludePeers where seenPeerIds.insert(peerId).inserted {
        guard let peer = transaction.getPeer(peerId) else {
            return nil
        }
        if peer is TelegramUser {
            guard let inputUser = apiInputUser(peer) else {
                return nil
            }
            privacyUsers.append(inputUser)
        } else if peer is TelegramGroup {
            privacyChats.append(peer.id.id._internalGetInt64Value())
        } else if let channel = peer as? TelegramChannel, case .group = channel.info {
            privacyChats.append(peer.id.id._internalGetInt64Value())
        } else {
            return nil
        }
    }
    let excludesPeers = privacy.base == .contacts || privacy.base == .everyone
    var privacyRules: [Api.InputPrivacyRule] = []
    if !privacyUsers.isEmpty {
        if excludesPeers {
            privacyRules.append(.inputPrivacyValueDisallowUsers(.init(users: privacyUsers)))
        } else {
            privacyRules.append(.inputPrivacyValueAllowUsers(.init(users: privacyUsers)))
        }
    }
    if !privacyChats.isEmpty {
        if excludesPeers {
            privacyRules.append(.inputPrivacyValueDisallowChatParticipants(.init(chats: privacyChats)))
        } else {
            privacyRules.append(.inputPrivacyValueAllowChatParticipants(.init(chats: privacyChats)))
        }
    }
    switch privacy.base {
    case .everyone:
        privacyRules.append(.inputPrivacyValueAllowAll)
    case .contacts:
        privacyRules.append(.inputPrivacyValueAllowContacts)
    case .closeFriends:
        privacyRules.append(.inputPrivacyValueAllowCloseFriends)
    case .nobody:
        if privacyRules.isEmpty {
            privacyRules.append(.inputPrivacyValueAllowUsers(.init(users: [.inputUserSelf])))
        }
    }
    return privacyRules
}

public struct StoryUploadInfo: Codable, Equatable {
    public var groupingId: Int32
    public var index: Int32
    public var total: Int32
    
    public init(groupingId: Int32, index: Int32, total: Int32) {
        self.groupingId = groupingId
        self.index = index
        self.total = total
    }
}

func _internal_uploadStory(
    account: Account,
    target: Stories.PendingTarget,
    media: EngineStoryInputMedia,
    mediaAreas: [MediaArea],
    text: String,
    entities: [MessageTextEntity],
    pin: Bool,
    privacy: EngineStoryPrivacy,
    isForwardingDisabled: Bool,
    period: Int,
    randomId: Int64,
    forwardInfo: Stories.PendingForwardInfo?,
    folders: [Int64],
    music: TelegramMediaFile?,
    uploadInfo: StoryUploadInfo? = nil
) -> Signal<Int32, NoError> {
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
            forwardInfo: forwardInfo,
            folders: folders,
            music: music,
            uploadInfo: uploadInfo
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
            let cancelledItem = currentState.items[index]
            if let uploadInfo = cancelledItem.uploadInfo {
                let groupingId = uploadInfo.groupingId
                let total = uploadInfo.total - 1
                
                currentState.items.remove(at: index)
                
                for i in 0..<currentState.items.count {
                    if let itemUploadInfo = currentState.items[i].uploadInfo, itemUploadInfo.groupingId == groupingId {
                        let newIndex: Int32
                        if itemUploadInfo.index > uploadInfo.index {
                            newIndex = itemUploadInfo.index - 1
                        } else {
                            newIndex = itemUploadInfo.index
                        }
                        
                        let updatedItem = Stories.PendingItem(
                            target: currentState.items[i].target,
                            stableId: currentState.items[i].stableId,
                            timestamp: currentState.items[i].timestamp,
                            media: currentState.items[i].media,
                            mediaAreas: currentState.items[i].mediaAreas,
                            text: currentState.items[i].text,
                            entities: currentState.items[i].entities,
                            embeddedStickers: currentState.items[i].embeddedStickers,
                            pin: currentState.items[i].pin,
                            privacy: currentState.items[i].privacy,
                            isForwardingDisabled: currentState.items[i].isForwardingDisabled,
                            period: currentState.items[i].period,
                            randomId: currentState.items[i].randomId,
                            forwardInfo: currentState.items[i].forwardInfo,
                            folders: currentState.items[i].folders,
                            music: currentState.items[i].music,
                            uploadInfo: StoryUploadInfo(
                                groupingId: groupingId,
                                index: newIndex,
                                total: total
                            )
                        )
                        
                        currentState.items[i] = updatedItem
                    }
                }
            } else {
                currentState.items.remove(at: index)
            }
            transaction.setLocalStoryState(state: CodableEntry(currentState))
        }
    }).start()
}

func _internal_beginStoryLivestream(account: Account, peerId: EnginePeer.Id, rtmp: Bool, privacy: EngineStoryPrivacy, isForwardingDisabled: Bool, messagesEnabled: Bool, sendPaidMessageStars: Int64?) -> Signal<EngineStoryItem?, NoError> {
    return account.postbox.transaction { transaction in
        var flags: Int32 = 0
        if rtmp {
            flags |= 1 << 5
        }
        if isForwardingDisabled {
            flags |= 1 << 4
        }
        
        let inputPeer: Api.InputPeer
        if peerId.namespace == Namespaces.Peer.CloudChannel, let peer = transaction.getPeer(peerId).flatMap(apiInputPeer) {
            inputPeer = peer
        } else {
            inputPeer = .inputPeerSelf
        }
        
        flags |= 1 << 6
        if let sendPaidMessageStars, sendPaidMessageStars > 0 {
            flags |= 1 << 7
        }
        
        guard let privacyRules = apiInputPrivacyRules(privacy: privacy, transaction: transaction) else {
            return Signal<EngineStoryItem?, NoError>.single(nil)
        }
        
        return account.network.request(Api.functions.stories.startLive(flags: flags, peer: inputPeer, caption: nil, entities: nil, privacyRules: privacyRules, randomId: Int64.random(in: Int64.min ... Int64.max), messagesEnabled: messagesEnabled ? .boolTrue : .boolFalse, sendPaidMessagesStars: sendPaidMessageStars))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<EngineStoryItem?, NoError> in
            if let updates {
                account.stateManager.addUpdates(updates)

                for update in updates.allUpdates {
                    if case let .updateStory(updateStoryData) = update, case .storyItem = updateStoryData.story {
                        let apiStory = updateStoryData.story
                        return account.postbox.transaction { transaction in
                            if let storedItem = Stories.StoredItem(apiStoryItem: apiStory, peerId: peerId, transaction: transaction), case let .item(item) = storedItem, let media = item.media {
                                let mappedItem = EngineStoryItem(
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
                                    music: item.music.flatMap(EngineMedia.init),
                                    author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) },
                                    folderIds: item.folderIds
                                )
                                return mappedItem
                            }
                            return nil
                        }
                    }
                }
            }
            return .single(nil)
        }
    }
    |> switchToLatest
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
    folders: [Int64],
    music: TelegramMediaFile?,
    randomId: Int64,
    forwardInfo: Stories.PendingForwardInfo?
) -> Signal<PendingStoryUploadResult, NoError> {
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
    |> mapToSignal { inputPeerAndForwardInfoPeer -> Signal<PendingStoryUploadResult, NoError> in
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
        |> mapToSignal { result -> Signal<PendingStoryUploadResult, NoError> in
            switch result {
            case let .progress(progress):
                let phase: PendingStoryUploadInternalPhase
                switch progress.phase {
                case .processing:
                    phase = .processing
                case .uploading:
                    phase = .uploading
                }
                return .single(.progress(progress.progress, phase))
            case let .content(content):
                return postbox.transaction { transaction -> Signal<PendingStoryUploadResult, NoError> in
                    guard let privacyRules = apiInputPrivacyRules(privacy: privacy, transaction: transaction) else {
                        return .single(.completed(nil))
                    }
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
                        
                        if !folders.isEmpty {
                            flags |= 1 << 8
                        }
                        
                        var apiMusic: Api.InputDocument?
                        if let resource = music?.resource as? CloudDocumentMediaResource, let fileReference = resource.fileReference {
                            flags |= 1 << 9
                            apiMusic = .inputDocument(.init(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: fileReference)))
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
                            fwdFromStory: fwdFromStory,
                            albums: folders.isEmpty ? nil : folders.map(Int32.init(clamping:)),
                            music: apiMusic
                        ))
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                            return .single(nil)
                        }
                        |> mapToSignal { updates -> Signal<PendingStoryUploadResult, NoError> in
                            return postbox.transaction { transaction -> PendingStoryUploadResult in
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
                                        if case let .updateStory(updateStoryData) = update {
                                            let story = updateStoryData.story
                                            switch story {
                                            case let .storyItem(storyItemData):
                                                let (idValue, fromId, media) = (storyItemData.id, storyItemData.fromId, storyItemData.media)
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
                                                            music: item.music,
                                                            authorId: fromId?.peerId,
                                                            folderIds: item.folderIds
                                                        )
                                                        if let entry = CodableEntry(Stories.StoredItem.item(updatedItem)) {
                                                            items.append(StoryItemsTableEntry(value: entry, id: item.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends, isLiveStream: updatedItem.isLiveStream))
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
                                                let parsedMedia = textMediaAndExpirationTimerFromApiMedia(media, toPeerId).media
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
) -> Signal<PendingStoryUploadResult, NoError> {
    return postbox.transaction { transaction -> Api.InputUser? in
        if let peer = transaction.getPeer(toPeerId) {
            return apiInputUser(peer)
        }
        return nil
    }
    |> mapToSignal { inputUser -> Signal<PendingStoryUploadResult, NoError> in
        guard let inputUser else {
            return .single(.completed(nil))
        }
        
        let passFetchProgress = media is TelegramMediaFile
        let (contentSignal, originalMedia) = uploadedStoryContent(postbox: postbox, network: network, media: media, mediaReference: nil, embeddedStickers: embeddedStickers, accountPeerId: accountPeerId, messageMediaPreuploadManager: messageMediaPreuploadManager, revalidationContext: revalidationContext, auxiliaryMethods: auxiliaryMethods, passFetchProgress: passFetchProgress)
        return contentSignal
        |> mapToSignal { result -> Signal<PendingStoryUploadResult, NoError> in
            switch result {
            case let .progress(progress):
                let phase: PendingStoryUploadInternalPhase
                switch progress.phase {
                case .processing:
                    phase = .processing
                case .uploading:
                    phase = .uploading
                }
                return .single(.progress(progress.progress, phase))
            case let .content(content):
                return postbox.transaction { transaction -> Signal<PendingStoryUploadResult, NoError> in
                    switch content.content {
                    case let .media(inputMedia, _):
                        return network.request(Api.functions.bots.addPreviewMedia(bot: inputUser, langCode: language ?? "", media: inputMedia))
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<Api.BotPreviewMedia?, NoError> in
                            return .single(nil)
                        }
                        |> mapToSignal { resultPreviewMedia -> Signal<PendingStoryUploadResult, NoError> in
                            guard let resultPreviewMedia else {
                                return .single(.completed(nil))
                            }
                            switch resultPreviewMedia {
                            case let .botPreviewMedia(botPreviewMediaData):
                                let (date, resultMedia) = (botPreviewMediaData.date, botPreviewMediaData.media)
                                return postbox.transaction { transaction -> PendingStoryUploadResult in
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
                inputMedia.append(.inputMediaPhoto(.init(flags: 0, id: .inputPhoto(.init(id: resource.photoId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))), ttlSeconds: nil, video: nil)))
                inputMedia.append(Api.InputMedia.inputMediaPhoto(.init(flags: 0, id: Api.InputPhoto.inputPhoto(.init(id: resource.photoId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))), ttlSeconds: nil, video: nil)))
            } else if let file = item as? TelegramMediaFile, let resource = file.resource as? CloudDocumentMediaResource {
                inputMedia.append(.inputMediaDocument(.init(flags: 0, id: .inputDocument(.init(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference ?? Data()))), videoCover: nil, videoTimestamp: nil, ttlSeconds: nil, query: nil)))
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
                inputMedia.append(.inputMediaPhoto(.init(flags: 0, id: .inputPhoto(.init(id: resource.photoId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))), ttlSeconds: nil, video: nil)))
                inputMedia.append(Api.InputMedia.inputMediaPhoto(.init(flags: 0, id: Api.InputPhoto.inputPhoto(.init(id: resource.photoId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))), ttlSeconds: nil, video: nil)))
            } else if let file = item as? TelegramMediaFile, let resource = file.resource as? CloudDocumentMediaResource {
                inputMedia.append(.inputMediaDocument(.init(flags: 0, id: .inputDocument(.init(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference ?? Data()))), videoCover: nil, videoTimestamp: nil, ttlSeconds: nil, query: nil)))
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
            inputMedia = .inputMediaUploadedDocument(.init(flags: 0, file: .inputFileStoryDocument(.init(id: .inputDocument(.init(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))))), thumb: nil, mimeType: file.mimeType, attributes: inputDocumentAttributesFromFileAttributes(file.attributes), stickers: nil, videoCover: nil, videoTimestamp: nil, ttlSeconds: nil))
            updatingCoverTime = true
        } else {
            inputMedia = nil
        }

        if media != nil && inputMedia == nil {
            return .single(.completed(nil))
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
                apiEntities = []
                
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
                guard let inputRules = apiInputPrivacyRules(privacy: privacy, transaction: transaction) else {
                    return .single(.completed(nil))
                }
                privacyRules = inputRules
                flags |= 1 << 2
            }
            
            let inputMediaAreas: [Api.MediaArea]? = mediaAreas.flatMap { apiMediaAreasFromMediaAreas($0, transaction: transaction) }
            if let mediaAreas, let inputMediaAreas {
                guard inputMediaAreas.count == mediaAreas.count else {
                    return .single(.completed(nil))
                }
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
                privacyRules: privacyRules,
                music: nil
            ))
            |> map { updates -> StoryUploadResult in
                for update in updates.allUpdates {
                    if case let .updateStory(updateStoryData) = update, updateStoryData.peer.peerId == peerId {
                        let story = updateStoryData.story
                        switch story {
                        case let .storyItem(storyItemData) where storyItemData.id == id:
                            let media = storyItemData.media
                            let parsedMedia = textMediaAndExpirationTimerFromApiMedia(media, peerId).media
                            if let parsedMedia = parsedMedia, let originalMedia = originalMedia {
                                applyMediaResourceChanges(from: originalMedia, to: parsedMedia, postbox: account.postbox, force: false, skipPreviews: updatingCoverTime)
                            }
                        default:
                            break
                        }
                    }
                }
                account.stateManager.addUpdates(updates)

                return .completed(id)
            }
            |> `catch` { error -> Signal<StoryUploadResult, NoError> in
                return .single(.completed(error.errorDescription == "STORY_NOT_MODIFIED" ? id : nil))
            }
        }
        |> switchToLatest
    }
}

public enum EditStoryPrivacyError {
    case generic
}

func _internal_editStoryPrivacy(account: Account, id: Int32, privacy: EngineStoryPrivacy) -> Signal<Never, EditStoryPrivacyError> {
    return account.postbox.transaction { transaction -> [Api.InputPrivacyRule]? in
        return apiInputPrivacyRules(privacy: privacy, transaction: transaction)
    }
    |> castError(EditStoryPrivacyError.self)
    |> mapToSignal { inputRules -> Signal<Never, EditStoryPrivacyError> in
        guard let inputRules else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.stories.editStory(flags: 1 << 2, peer: .inputPeerSelf, id: id, media: nil, mediaAreas: nil, caption: nil, entities: nil, privacyRules: inputRules, music: nil))
        |> map(Optional.init)
        |> `catch` { error -> Signal<Api.Updates?, EditStoryPrivacyError> in
            if error.errorDescription == "STORY_NOT_MODIFIED" {
                return .single(nil)
            }
            return .fail(.generic)
        }
        |> mapToSignal { updates -> Signal<Never, EditStoryPrivacyError> in
            return account.postbox.transaction { transaction in
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
                        music: item.music,
                        authorId: item.authorId,
                        folderIds: item.folderIds
                    )
                    if let entry = CodableEntry(Stories.StoredItem.item(updatedItem)) {
                        transaction.setStory(id: storyId, value: entry)
                    }
                }

                var items = transaction.getStoryItems(peerId: account.peerId)
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
                        music: item.music,
                        authorId: item.authorId,
                        folderIds: item.folderIds
                    )
                    if let entry = CodableEntry(Stories.StoredItem.item(updatedItem)) {
                        items[index] = StoryItemsTableEntry(value: entry, id: item.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends, isLiveStream: updatedItem.isLiveStream)
                    }

                }
                transaction.setStoryItems(peerId: account.peerId, items: items)

            }
            |> castError(EditStoryPrivacyError.self)
            |> afterNext { _ in
                if let updates {
                    account.stateManager.addUpdates(updates)
                }
            }
            |> ignoreValues
        }
    }
}

public enum StoriesUploadAvailability {
    case available(remainingCount: Int32)
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
            switch result {
            case let .canSendStoryCount(canSendStoryCountData):
                let countRemains = canSendStoryCountData.countRemains
                return .available(remainingCount: countRemains)
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

public enum DeleteStoriesError {
    case generic
}

func _internal_deleteStories(account: Account, peerId: PeerId, ids: [Int32]) -> Signal<Never, DeleteStoriesError> {
    var seenIds = Set<Int32>()
    let ids = ids.filter { seenIds.insert($0).inserted }
    if ids.isEmpty {
        return .complete()
    }
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(DeleteStoriesError.self)
    |> mapToSignal { inputPeer -> Signal<Never, DeleteStoriesError> in
        guard let inputPeer else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.stories.deleteStories(peer: inputPeer, id: ids))
        |> mapError { _ in DeleteStoriesError.generic }
        |> mapToSignal { _ -> Signal<Never, DeleteStoriesError> in
            return account.postbox.transaction { transaction in
                _internal_removeStoriesFromListCaches(transaction: transaction, peerId: peerId, ids: seenIds)
                _internal_invalidateStoryResolution(postbox: account.postbox, peerId: peerId, ids: ids)
                account.storyRefreshContext.invalidate(peerId: peerId, ids: ids)
                account.storyViewRefreshContext.invalidate(peerId: peerId, ids: ids)
                let items = transaction.getStoryItems(peerId: peerId)
                let updatedItems = items.filter { !seenIds.contains($0.id) }
                if updatedItems.count != items.count {
                    transaction.setStoryItems(peerId: peerId, items: updatedItems)
                }
                for id in ids {
                    account.storyReactionContext.markDeleted(StoryId(peerId: peerId, id: id))
                    transaction.setStory(id: StoryId(peerId: peerId, id: id), value: CodableEntry(data: Data()))
                }
            }
            |> castError(DeleteStoriesError.self)
            |> afterNext { _ in
                account.stateManager.injectStoryUpdates(updates: ids.map { .deleted(peerId: peerId, id: $0) })
            }
            |> ignoreValues
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

public enum UpdateStoriesArePinnedError {
    case generic
}

func _internal_updateStoriesArePinned(account: Account, peerId: PeerId, ids: [Int32: EngineStoryItem], isPinned: Bool) -> Signal<Never, UpdateStoriesArePinnedError> {
    guard ids.allSatisfy({ $0.key == $0.value.id }) else {
        return .fail(.generic)
    }
    if ids.isEmpty {
        return .complete()
    }
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(UpdateStoriesArePinnedError.self)
    |> mapToSignal { inputPeer -> Signal<Never, UpdateStoriesArePinnedError> in
        guard let inputPeer else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.stories.togglePinned(peer: inputPeer, id: ids.keys.sorted(), pinned: isPinned ? .boolTrue : .boolFalse))
        |> mapError { _ in UpdateStoriesArePinnedError.generic }
        |> mapToSignal { _ -> Signal<Never, UpdateStoriesArePinnedError> in
            return account.postbox.transaction { transaction -> [Stories.Item] in
                func updated(_ item: Stories.Item) -> Stories.Item {
                    return Stories.Item(
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
                        music: item.music,
                        authorId: item.authorId,
                        folderIds: item.folderIds
                    )
                }
                var items = transaction.getStoryItems(peerId: peerId)
                var listChanged = false
                var updatedItems: [Stories.Item] = []
                for id in ids.keys.sorted() {
                    guard let referenceItem = ids[id] else { continue }
                    let storyId = StoryId(peerId: peerId, id: id)
                    let cachedEntry = transaction.getStory(id: storyId)
                    let cachedStory = cachedEntry?.get(Stories.StoredItem.self)
                    if cachedEntry != nil && cachedStory == nil { continue }
                    var publishedItem: Stories.Item?
                    if let index = items.firstIndex(where: { $0.id == id }), case let .item(item) = items[index].value.get(Stories.StoredItem.self) {
                        let updatedItem = updated(item)
                        if let entry = CodableEntry(Stories.StoredItem.item(updatedItem)) {
                            items[index] = StoryItemsTableEntry(value: entry, id: item.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends, isLiveStream: updatedItem.isLiveStream)
                            listChanged = true
                        }
                        publishedItem = updatedItem
                    }
                    if case let .item(item) = cachedStory {
                        let updatedItem = updated(item)
                        if let entry = CodableEntry(Stories.StoredItem.item(updatedItem)) {
                            transaction.setStory(id: storyId, value: entry)
                        }
                        if publishedItem == nil { publishedItem = updatedItem }
                    }
                    updatedItems.append(publishedItem ?? updated(referenceItem.asStoryItem()))
                }
                if listChanged {
                    transaction.setStoryItems(peerId: peerId, items: items)
                }
                return updatedItems
            }
            |> castError(UpdateStoriesArePinnedError.self)
            |> deliverOnMainQueue
            |> afterNext { updatedItems in
                if !updatedItems.isEmpty {
                    account.stateManager.injectStoryUpdates(updates: updatedItems.map { .added(peerId: peerId, item: .item($0)) })
                }
            }
            |> ignoreValues
        }
    }
}

public enum UpdatePinnedToTopStoriesError {
    case generic
}

func _internal_updatePinnedToTopStories(account: Account, peerId: PeerId, ids: [Int32]) -> Signal<Never, UpdatePinnedToTopStoriesError> {
    var seenIds = Set<Int32>()
    let ids = ids.filter { seenIds.insert($0).inserted }
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(UpdatePinnedToTopStoriesError.self)
    |> mapToSignal { inputPeer -> Signal<Never, UpdatePinnedToTopStoriesError> in
        guard let inputPeer else {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.stories.togglePinnedToTop(peer: inputPeer, id: ids))
        |> mapError { _ in UpdatePinnedToTopStoriesError.generic }
        |> deliverOnMainQueue
        |> mapToSignal { result -> Signal<Never, UpdatePinnedToTopStoriesError> in
            guard case .boolTrue = result else {
                return .fail(.generic)
            }
            account.stateManager.injectStoryUpdates(updates: [.updatePinnedToTopList(peerId: peerId, ids: ids)])
            return .complete()
        }
    }
}

extension Api.StoryItem {
    var id: Int32 {
        switch self {
        case let .storyItem(storyItemData):
            let id = storyItemData.id
            return id
        case let .storyItemDeleted(storyItemDeletedData):
            let id = storyItemDeletedData.id
            return id
        case let .storyItemSkipped(storyItemSkippedData):
            let id = storyItemSkippedData.id
            return id
        }
    }
}

extension Stories.Item.Views {
    init(apiViews: Api.StoryViews) {
        switch apiViews {
        case let .storyViews(storyViewsData):
            let (flags, viewsCount, forwardsCount, reactions, reactionsCount, recentViewers) = (storyViewsData.flags, storyViewsData.viewsCount, storyViewsData.forwardsCount, storyViewsData.reactions, storyViewsData.reactionsCount, storyViewsData.recentViewers)
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
                    case let .reactionCount(reactionCountData):
                        let (chosenOrder, reaction, count) = (reactionCountData.chosenOrder, reactionCountData.reaction, reactionCountData.count)
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
        case let .storyFwdHeader(storyFwdHeaderData):
            let (flags, from, fromName, storyId) = (storyFwdHeaderData.flags, storyFwdHeaderData.from, storyFwdHeaderData.fromName, storyFwdHeaderData.storyId)
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
        case let .storyItem(storyItemData):
            let (flags, id, date, fromId, forwardFrom, expireDate, caption, entities, media, mediaAreas, privacy, views, sentReaction, albums, music) = (storyItemData.flags, storyItemData.id, storyItemData.date, storyItemData.fromId, storyItemData.fwdFrom, storyItemData.expireDate, storyItemData.caption, storyItemData.entities, storyItemData.media, storyItemData.mediaAreas, storyItemData.privacy, storyItemData.views, storyItemData.sentReaction, storyItemData.albums, storyItemData.music)
            var folderIds: [Int64]?
            if let albums {
                folderIds = albums.map(Int64.init)
            }
            
            let parsedMedia = textMediaAndExpirationTimerFromApiMedia(media, peerId).media
            if let parsedMedia = parsedMedia {
                var parsedPrivacy: Stories.Item.Privacy?
                if let privacy = privacy {
                    var base: Stories.Item.Privacy.Base = .nobody
                    var additionalPeerIds: [PeerId] = []
                    for rule in privacy {
                        var additionalChatIds: [Int64] = []
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
                        case let .privacyValueAllowUsers(privacyValueAllowUsersData):
                            let users = privacyValueAllowUsersData.users
                            for id in users {
                                additionalPeerIds.append(EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)))
                            }
                        case let .privacyValueDisallowUsers(privacyValueDisallowUsersData):
                            let users = privacyValueDisallowUsersData.users
                            for id in users {
                                additionalPeerIds.append(EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id)))
                            }
                        case let .privacyValueAllowChatParticipants(privacyValueAllowChatParticipantsData):
                            additionalChatIds = privacyValueAllowChatParticipantsData.chats
                        case let .privacyValueDisallowChatParticipants(privacyValueDisallowChatParticipantsData):
                            additionalChatIds = privacyValueDisallowChatParticipantsData.chats
                        default:
                            break
                        }
                        for id in additionalChatIds {
                            if let peer = transaction.getPeer(EnginePeer.Id(namespace: Namespaces.Peer.CloudGroup, id: EnginePeer.Id.Id._internalFromInt64Value(id))) {
                                additionalPeerIds.append(peer.id)
                            } else if let peer = transaction.getPeer(EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(id))) {
                                additionalPeerIds.append(peer.id)
                            }
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
                case let .messageMediaDocument(messageMediaDocumentData):
                    let altDocuments = messageMediaDocumentData.altDocuments
                    if let altDocuments {
                        parsedAlternativeMedia = altDocuments.compactMap { telegramMediaFileFromApiDocument($0, altDocuments: []) }
                    }
                default:
                    break
                }
                
                
                var parsedMusic: TelegramMediaFile?
                if let music {
                    parsedMusic = telegramMediaFileFromApiDocument(music, altDocuments: nil)
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
                    music: parsedMusic,
                    authorId: fromId?.peerId,
                    folderIds: folderIds
                )
                self = .item(item)
            } else {
                return nil
            }
        case let .storyItemSkipped(storyItemSkippedData):
            let (flags, id, date, expireDate) = (storyItemSkippedData.flags, storyItemSkippedData.id, storyItemSkippedData.date, storyItemSkippedData.expireDate)
            let isCloseFriends = (flags & (1 << 8)) != 0
            let isLiveItem = (flags & (1 << 9)) != 0
            self = .placeholder(Stories.Placeholder(id: id, timestamp: date, expirationTimestamp: expireDate, isCloseFriends: isCloseFriends, isLiveItem: isLiveItem))
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
                case let .stories(storiesData):
                    let (stories, chats, users) = (storiesData.stories, storiesData.chats, storiesData.users)
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
                                music: item.music.flatMap(EngineMedia.init),
                                author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) },
                                folderIds: item.folderIds
                            )
                        }
                    }
                    return nil
                }
            }
        }
    }
}

private final class StoryResolutionContextRegistry {
    static let shared = StoryResolutionContextRegistry()
    private let lock = NSLock()
    private let pollContexts = NSMapTable<Postbox, PeerStoryPollContext>(keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: .weakMemory)
    private let contexts = NSMapTable<Postbox, StoryRefreshContext>(keyOptions: [.weakMemory, .objectPointerPersonality], valueOptions: .weakMemory)

    func pollContext(for postbox: Postbox, create: Bool) -> PeerStoryPollContext? {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let context = self.pollContexts.object(forKey: postbox) { return context }
        guard create else { return nil }
        let context = PeerStoryPollContext()
        self.pollContexts.setObject(context, forKey: postbox)
        return context
    }

    func context(for postbox: Postbox, create: Bool) -> StoryRefreshContext? {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let context = self.contexts.object(forKey: postbox) { return context }
        guard create else { return nil }
        let context = StoryRefreshContext()
        self.contexts.setObject(context, forKey: postbox)
        return context
    }
}

final class PeerStoryPollContext {
    private struct Entry {
        let id: UUID
        var items: [StoryItemsTableEntry]
    }

    private let pending = Atomic<[PeerId: [Entry]]>(value: [:])

    func begin(peerId: PeerId, id: UUID, items: [StoryItemsTableEntry]) {
        let _ = self.pending.modify { pending in
            var pending = pending
            pending[peerId, default: []].append(Entry(id: id, items: items))
            return pending
        }
    }

    func take(peerId: PeerId, id: UUID, items: [StoryItemsTableEntry]) -> Bool {
        var accepted = false
        let _ = self.pending.modify { pending in
            var pending = pending
            guard var entries = pending[peerId], let index = entries.firstIndex(where: { $0.id == id }), entries[index].items == items else { return pending }
            entries.removeSubrange(...index)
            if entries.isEmpty { pending.removeValue(forKey: peerId) } else { pending[peerId] = entries }
            accepted = true
            return pending
        }
        return accepted
    }

    func advance(peerId: PeerId, from previous: [StoryItemsTableEntry], to updated: [StoryItemsTableEntry]) {
        let _ = self.pending.modify { pending in
            var pending = pending
            guard var entries = pending[peerId] else { return pending }
            for index in entries.indices where entries[index].items == previous { entries[index].items = updated }
            pending[peerId] = entries
            return pending
        }
    }

    func invalidate(peerId: PeerId) {
        let _ = self.pending.modify { pending in
            var pending = pending
            pending.removeValue(forKey: peerId)
            return pending
        }
    }

    func finish(peerId: PeerId, id: UUID) {
        let _ = self.pending.modify { pending in
            var pending = pending
            guard var entries = pending[peerId] else { return pending }
            entries.removeAll(where: { $0.id == id })
            if entries.isEmpty { pending.removeValue(forKey: peerId) } else { pending[peerId] = entries }
            return pending
        }
    }
}

final class PeerStoryPollLease {
    let context: PeerStoryPollContext
    let id = UUID()
    private let peerId: PeerId

    init(postbox: Postbox, peerId: PeerId, items: [StoryItemsTableEntry]) {
        self.context = StoryResolutionContextRegistry.shared.pollContext(for: postbox, create: true)!
        self.peerId = peerId
        self.context.begin(peerId: peerId, id: self.id, items: items)
    }

    deinit { self.context.finish(peerId: self.peerId, id: self.id) }
}

func _internal_invalidatePeerStoryPoll(postbox: Postbox, peerId: PeerId) {
    StoryResolutionContextRegistry.shared.pollContext(for: postbox, create: false)?.invalidate(peerId: peerId)
}

final class StoryResolutionLease {
    let context: StoryRefreshContext
    let request: StoryRefreshContext.Request

    init(postbox: Postbox, peerId: PeerId, snapshots: [Int32: StoryRefreshSnapshot]) {
        self.context = StoryResolutionContextRegistry.shared.context(for: postbox, create: true)!
        self.request = StoryRefreshContext.Request(storyIds: snapshots.keys.map { StoryId(peerId: peerId, id: $0) })
        self.context.begin(self.request)
        self.context.prepare(self.request, snapshots: snapshots)
    }

    deinit { self.context.finish(self.request) }
}

func _internal_invalidateStoryResolution(postbox: Postbox, peerId: PeerId, ids: [Int32], invalidatePeerPoll: Bool = true) {
    if invalidatePeerPoll { _internal_invalidatePeerStoryPoll(postbox: postbox, peerId: peerId) }
    StoryResolutionContextRegistry.shared.context(for: postbox, create: false)?.invalidate(peerId: peerId, ids: ids)
}

struct StoriesByIdResult {
    let items: [Stories.StoredItem]
    let missingIds: Set<Int32>
}

struct StoryResolutionResult {
    let stories: Api.stories.Stories
    let lease: StoryResolutionLease
}

func _internal_existingStoryItem(transaction: Transaction, peerId: PeerId, id: Int32) -> Stories.Item? {
    for row in transaction.getStoryItems(peerId: peerId) where row.id == id {
        if case let .item(item) = row.value.get(Stories.StoredItem.self), item.id == id { return item }
    }
    if case let .item(item) = transaction.getStory(id: StoryId(peerId: peerId, id: id))?.get(Stories.StoredItem.self), item.id == id { return item }
    return _internal_cachedStoryItemValue(transaction: transaction, peerId: peerId, id: id)
}

func _internal_parseStoriesById(transaction: Transaction, peerId: PeerId, ids: [Int32], stories: [Api.StoryItem]) -> StoriesByIdResult {
    let grouped = Dictionary(grouping: stories, by: { $0.id })
    var items: [Stories.StoredItem] = []
    var missingIds = Set<Int32>()
    for id in ids {
        guard let matches = grouped[id] else { missingIds.insert(id); continue }
        guard matches.count == 1 else { continue }
        if case .storyItemDeleted = matches[0] { missingIds.insert(id); continue }
        let existingItem = _internal_existingStoryItem(transaction: transaction, peerId: peerId, id: id)
        guard let parsed = Stories.StoredItem(apiStoryItem: matches[0], existingItem: existingItem, peerId: peerId, transaction: transaction), case .item = parsed else { continue }
        items.append(parsed)
    }
    return StoriesByIdResult(items: items, missingIds: missingIds)
}

func _internal_getStoriesById(accountPeerId: PeerId, postbox: Postbox, network: Network, peer: PeerReference, ids: [Int32]) -> Signal<[Stories.StoredItem], NoError> {
    var seenIds = Set<Int32>()
    let ids = ids.filter { $0 > 0 && seenIds.insert($0).inserted }
    guard !ids.isEmpty else { return .single([]) }
    return network.request(Api.functions.stories.getStoriesByID(peer: peer.inputPeer, id: ids))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in .single(nil) }
    |> mapToSignal { result -> Signal<[Stories.StoredItem], NoError> in
        guard let result else { return .single([]) }
        return postbox.transaction { transaction -> [Stories.StoredItem] in
            switch result {
            case let .stories(data):
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: data.chats, users: data.users))
                return _internal_parseStoriesById(transaction: transaction, peerId: peer.id, ids: ids, stories: data.stories).items
            }
        }
    }
}

func _internal_getStoriesById(accountPeerId: PeerId, postbox: Postbox, source: FetchMessageHistoryHoleSource, peerId: PeerId, peerReference: PeerReference?, ids: [Int32], allowFloodWait: Bool) -> Signal<StoryResolutionResult?, NoError> {
    var seenIds = Set<Int32>()
    let ids = ids.filter { $0 > 0 && seenIds.insert($0).inserted }
    guard !ids.isEmpty else { return .single(nil) }
    return postbox.transaction { transaction -> (Api.InputPeer, StoryResolutionLease)? in
        let reference = peerReference.flatMap { $0.id == peerId ? $0.inputPeer : nil }
        guard let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) ?? reference else { return nil }
        var snapshots: [Int32: StoryRefreshSnapshot] = [:]
        for id in ids { snapshots[id] = StoryRefreshSnapshot(transaction: transaction, peerId: peerId, id: id) }
        return (inputPeer, StoryResolutionLease(postbox: postbox, peerId: peerId, snapshots: snapshots))
    }
    |> mapToSignal { prepared -> Signal<StoryResolutionResult?, NoError> in
        guard let (inputPeer, lease) = prepared else { return .single(nil) }
        return source.request(Api.functions.stories.getStoriesByID(peer: inputPeer, id: ids), automaticFloodWait: allowFloodWait)
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in .single(nil) }
        |> take(1)
        |> map { result -> StoryResolutionResult? in
            return result.map { StoryResolutionResult(stories: $0, lease: lease) }
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
                case let .storyViews(storyViewsData):
                    let (views, users) = (storyViewsData.views, storyViewsData.users)
                    guard views.count == ids.count else { return [:] }
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                    
                    for i in 0 ..< views.count {
                        parsedViews[ids[i]] = Stories.Item.Views(apiViews: views[i])
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
            if isHidden {
                if !transaction.isPeerContact(peerId: user.id) {
                    let _ = _internal_removeRecentPeer(account: account, peerId: id).startStandalone()
                }
            }
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
            case let .exportedStoryLink(exportedStoryLinkData):
                let link = exportedStoryLinkData.link
                return link
            }
        }
    }
}

final class StoryRefreshContext {
    struct Request {
        let id = UUID()
        let storyIds: [StoryId]
    }

    struct Resolution {
        let views: Stories.Item.Views?
    }

    private struct Entry {
        let id: UUID
        var snapshot: StoryRefreshSnapshot?
        var views: Stories.Item.Views?
    }

    private let pending = Atomic<[StoryId: [Entry]]>(value: [:])

    func begin(_ request: Request) {
        let _ = self.pending.modify { pending in
            var pending = pending
            for id in request.storyIds { pending[id, default: []].append(Entry(id: request.id, snapshot: nil, views: nil)) }
            return pending
        }
    }

    func prepare(_ request: Request, snapshots: [Int32: StoryRefreshSnapshot]) {
        let _ = self.pending.modify { pending in
            var pending = pending
            for id in request.storyIds {
                guard let snapshot = snapshots[id.id], var requests = pending[id], let index = requests.firstIndex(where: { $0.id == request.id }) else { continue }
                requests[index].snapshot = snapshot
                pending[id] = requests
            }
            return pending
        }
    }

    func isPending(_ id: StoryId) -> Bool {
        return self.pending.with { $0[id] != nil }
    }

    func take(_ snapshots: [Int32: StoryRefreshSnapshot], for request: Request) -> [Int32: Resolution] {
        var accepted: [Int32: Resolution] = [:]
        let _ = self.pending.modify { pending in
            var pending = pending
            for id in request.storyIds {
                guard var requests = pending[id], let index = requests.firstIndex(where: { $0.id == request.id }),
                      let snapshot = requests[index].snapshot, snapshot == snapshots[id.id] else { continue }
                accepted[id.id] = Resolution(views: requests[index].views)
                requests.removeSubrange(...index)
                if requests.isEmpty { pending.removeValue(forKey: id) } else { pending[id] = requests }
            }
            return pending
        }
        return accepted
    }

    func advance(peerId: PeerId, id: Int32, from previous: StoryRefreshSnapshot, to updated: StoryRefreshSnapshot, views: Stories.Item.Views? = nil) {
        let _ = self.pending.modify { pending in
            var pending = pending
            let storyId = StoryId(peerId: peerId, id: id)
            guard var requests = pending[storyId] else { return pending }
            for index in requests.indices where requests[index].snapshot == previous || requests[index].snapshot == nil {
                if requests[index].snapshot != nil { requests[index].snapshot = updated }
                if let views { requests[index].views = views }
            }
            pending[storyId] = requests
            return pending
        }
    }

    func invalidate(peerId: PeerId, ids: [Int32]) {
        let _ = self.pending.modify { pending in
            var pending = pending
            for id in ids { pending.removeValue(forKey: StoryId(peerId: peerId, id: id)) }
            return pending
        }
    }

    func finish(_ request: Request) {
        let _ = self.pending.modify { pending in
            var pending = pending
            for id in request.storyIds {
                guard var requests = pending[id], let index = requests.firstIndex(where: { $0.id == request.id }) else { continue }
                requests.remove(at: index)
                if requests.isEmpty { pending.removeValue(forKey: id) } else { pending[id] = requests }
            }
            return pending
        }
    }
}

struct StoryRefreshSnapshot: Equatable {
    let entries: [StoryItemsTableEntry]
    let individual: CodableEntry?
    let cachedItems: [ItemCacheEntryId: [Stories.StoredItem]]

    init(transaction: Transaction, peerId: PeerId, id: Int32) {
        self.entries = transaction.getStoryItems(peerId: peerId).filter { $0.id == id }
        self.individual = transaction.getStory(id: StoryId(peerId: peerId, id: id))
        self.cachedItems = _internal_storyListCacheSnapshot(transaction: transaction, peerId: peerId, id: id)
    }
}

func _internal_refreshStories(account: Account, peerId: PeerId, ids: [Int32], skipDeleted: Bool = false) -> Signal<Never, NoError> {
    var seenIds = Set<Int32>()
    let ids = ids.filter { $0 > 0 && seenIds.insert($0).inserted }
    guard !ids.isEmpty else { return .complete() }
    let postbox = account.postbox
    let network = account.network
    let accountPeerId = account.peerId
    let storyReactionContext = account.storyReactionContext
    let context = account.storyRefreshContext
    let viewContext = account.storyViewRefreshContext
    let stateManager: AccountStateManager = account.stateManager
    return Signal { [weak account, weak stateManager] subscriber in
        guard account != nil else { subscriber.putCompletion(); return EmptyDisposable }
        let lifecycle = Atomic<(cancelled: Bool, committed: Bool)>(value: (false, false))
        let viewRequest = viewContext.begin(peerId: peerId, ids: ids)
        let request = StoryRefreshContext.Request(storyIds: ids.map { StoryId(peerId: peerId, id: $0) })
        context.begin(request)
        let disposable = (postbox.transaction { transaction -> Api.InputPeer? in
            guard account != nil, !lifecycle.with({ $0.cancelled }), let inputPeer = transaction.getPeer(peerId).flatMap(apiInputPeer) else { return nil }
            var snapshots: [Int32: StoryRefreshSnapshot] = [:]
            for id in ids {
                if skipDeleted && transaction.getStory(id: StoryId(peerId: peerId, id: id)) == CodableEntry(data: Data()) { continue }
                snapshots[id] = StoryRefreshSnapshot(transaction: transaction, peerId: peerId, id: id)
            }
            guard !snapshots.isEmpty else { return nil }
            context.prepare(request, snapshots: snapshots)
            guard !lifecycle.with({ $0.cancelled }) else { context.finish(request); return nil }
            return inputPeer
        }
        |> mapToSignal { prepared -> Signal<[InternalStoryUpdate], NoError> in
            guard let inputPeer = prepared, !lifecycle.with({ $0.cancelled }) else { return .complete() }
            return network.request(Api.functions.stories.getStoriesByID(peer: inputPeer, id: ids))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in .single(nil) }
            |> take(1)
            |> mapToSignal { result -> Signal<[InternalStoryUpdate], NoError> in
                guard let result else { return .complete() }
                return postbox.transaction { transaction -> [InternalStoryUpdate] in
                    var canCommit = false
                    let _ = lifecycle.modify { state in
                        guard !state.cancelled else { return state }
                        canCommit = true
                        return (false, true)
                    }
                    guard canCommit, account != nil else { return [] }
                    switch result {
                    case let .stories(data):
                        let stories = Dictionary(grouping: data.stories, by: { $0.id })
                        var snapshots: [Int32: StoryRefreshSnapshot] = [:]
                        for id in ids where (stories[id]?.count ?? 0) <= 1 {
                            snapshots[id] = StoryRefreshSnapshot(transaction: transaction, peerId: peerId, id: id)
                        }
                        let accepted = context.take(snapshots, for: request)
                        guard !accepted.isEmpty else { return [] }
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: data.chats, users: data.users))
                        let deletedIds = Set(ids.filter { id in
                            guard accepted[id] != nil else { return false }
                            guard let matching = stories[id] else { return true }
                            if matching.count == 1, case .storyItemDeleted = matching[0] { return true }
                            return false
                        })
                        _internal_removeStoriesFromListCaches(transaction: transaction, peerId: peerId, ids: deletedIds)
                        var updates: [InternalStoryUpdate] = []
                        for id in ids where accepted[id] != nil {
                            let story: Api.StoryItem
                            if let matching = stories[id] {
                                guard matching.count == 1 else { continue }
                                story = matching[0]
                            } else {
                                story = .storyItemDeleted(.init(id: id))
                            }
                            let acceptsViews = viewContext.contains(peerId: peerId, id: id, request: viewRequest)
                            let viewsOverride: Stories.Item.Views?? = acceptsViews ? nil : accepted[id]?.views.map { .some($0) }
                            let applied = _internal_applyStoryUpdate(transaction: transaction, peerId: peerId, story: story, storyReactionContext: storyReactionContext, addToActive: false, viewsOverride: viewsOverride)
                            if !applied.isEmpty && _internal_storyUpdatesViews(story) { _ = viewContext.take(Set([id]), for: viewRequest) }
                            if !applied.isEmpty { _internal_invalidateStoryResolution(postbox: postbox, peerId: peerId, ids: [id]) }
                            updates.append(contentsOf: applied)
                            if case .storyItemDeleted = story {
                                viewContext.invalidate(peerId: peerId, ids: [id])
                                let storyId = StoryId(peerId: peerId, id: id)
                                let empty = CodableEntry(data: Data())
                                if transaction.getStory(id: storyId) != empty { transaction.setStory(id: storyId, value: empty) }
                            }
                            if let previous = snapshots[id] {
                                context.advance(peerId: peerId, id: id, from: previous, to: StoryRefreshSnapshot(transaction: transaction, peerId: peerId, id: id))
                            }
                        }
                        return updates
                    }
                }
            }
        }).start(next: { updates in
            if !updates.isEmpty { stateManager?.injectStoryUpdates(updates: updates) }
        }, completed: {
            context.finish(request)
            viewContext.finish(viewRequest)
            subscriber.putCompletion()
        })
        return ActionDisposable {
            var committed = false
            let _ = lifecycle.modify { state in
                committed = state.committed
                return (true, state.committed)
            }
            context.finish(request)
            viewContext.finish(viewRequest)
            if !committed { disposable.dispose() }
        }
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
                case let .updateReadStories(updateReadStoriesData):
                    let (peerIdValue, maxId) = (updateReadStoriesData.peer, updateReadStoriesData.maxId)
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

func _internal_pollAndGetLiveStory(account: Account, peerId: PeerId) -> Signal<Int32?, NoError> {
    return _internal_pollPeerStories(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: peerId, stateManager: account.stateManager)
    |> map { _ -> Int32? in }
    |> then(account.postbox.transaction { transaction -> Int32? in
        for item in transaction.getStoryItems(peerId: peerId) {
            if item.isLiveStream {
                return item.id
            }
        }
        
        return nil
    })
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
        case let .storiesStealthMode(storiesStealthModeData):
            let (activeUntilDate, cooldownUntilDate) = (storiesStealthModeData.activeUntilDate, storiesStealthModeData.cooldownUntilDate)
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

func _internal_updateStoryViewsForMyReaction(isChannel: Bool, views: Stories.Item.Views?, previousReaction: MessageReaction.Reaction?, reaction: MessageReaction.Reaction?, addedCount: Int = 1) -> Stories.Item.Views? {
    if !isChannel && reaction != .stars {
        return views
    }
    if reaction != .stars && previousReaction == reaction {
        return views
    }
    let increment: Int32
    if reaction == .stars {
        guard let count = Int32(exactly: addedCount), count > 0 else { return views }
        increment = count
    } else {
        increment = 1
    }

    var views = views ?? Stories.Item.Views(seenCount: 0, reactedCount: 0, forwardCount: 0, seenPeerIds: [], reactions: [], hasList: false)
    if previousReaction == nil && reaction != nil {
        if views.reactedCount < Int.max { views.reactedCount = max(0, views.reactedCount) + 1 }
    } else if previousReaction != nil && previousReaction != .stars && reaction == nil {
        views.reactedCount = views.reactedCount > 0 ? views.reactedCount - 1 : 0
    }

    var reactions = views.reactions
    if reaction != .stars {
        if let previousReaction, previousReaction != .stars,
           let index = reactions.firstIndex(where: { $0.value == previousReaction }) {
            reactions[index].count = reactions[index].count > 0 ? reactions[index].count - 1 : 0
            if reactions[index].count == 0 { reactions.remove(at: index) }
        }
        for index in reactions.indices where reactions[index].value != .stars {
            reactions[index].chosenOrder = nil
        }
    }
    if let reaction {
        if let index = reactions.firstIndex(where: { $0.value == reaction }) {
            reactions[index].chosenOrder = 0
            let current = max(0, reactions[index].count)
            reactions[index].count = current > Int32.max - increment ? Int32.max : current + increment
        } else {
            reactions.append(MessageReaction(value: reaction, count: increment, chosenOrder: 0))
        }
    }
    views.reactions = reactions
    return views.isEmpty ? nil : views
}

final class StoryReactionRequestDependencyTag: NetworkRequestDependencyTag {
    let storyId: StoryId

    init(storyId: StoryId) {
        self.storyId = storyId
    }

    func shouldDependOn(other: NetworkRequestDependencyTag) -> Bool {
        guard let other = other as? StoryReactionRequestDependencyTag else { return false }
        return self.storyId == other.storyId
    }
}

final class StoryReactionContext {
    struct Request {
        let id = UUID()
        let storyId: StoryId
        let reaction: MessageReaction.Reaction?
    }

    struct Resolution {
        let expectedReaction: MessageReaction.Reaction?
        let reaction: MessageReaction.Reaction??
        let needsRefresh: Bool
    }

    private struct Entry {
        var baseline: MessageReaction.Reaction??
        var requests: [Request]
        var supersededIds = Set<UUID>()
        var needsRefresh = false
        var wasDeleted = false

        var reaction: MessageReaction.Reaction?? {
            if let last = requests.last(where: { !supersededIds.contains($0.id) }) { return .some(last.reaction) }
            return baseline
        }
    }

    private let entries = Atomic<[StoryId: Entry]>(value: [:])

    func begin(_ request: Request, previousReaction: MessageReaction.Reaction??) {
        let _ = self.entries.modify { entries in
            var entries = entries
            var entry = entries[request.storyId] ?? Entry(baseline: previousReaction, requests: [])
            entry.requests.append(request)
            entries[request.storyId] = entry
            return entries
        }
    }

    func finish(_ request: Request, success: Bool, refreshOnFailure: Bool = true) -> Resolution? {
        var resolution: Resolution?
        let _ = self.entries.modify { entries in
            var entries = entries
            guard var entry = entries[request.storyId], let index = entry.requests.firstIndex(where: { $0.id == request.id }) else { return entries }
            let expected = entry.reaction ?? nil
            if success && !entry.supersededIds.contains(request.id) {
                entry.baseline = .some(request.reaction)
                entry.supersededIds.formUnion(entry.requests[..<index].map(\.id))
            }
            entry.requests.remove(at: index)
            entry.supersededIds.remove(request.id)
            entry.needsRefresh = entry.needsRefresh || (!success && refreshOnFailure)
            resolution = Resolution(expectedReaction: expected, reaction: entry.reaction, needsRefresh: entry.requests.isEmpty && entry.needsRefresh && !entry.wasDeleted)
            if entry.requests.isEmpty { entries.removeValue(forKey: request.storyId) } else { entries[request.storyId] = entry }
            return entries
        }
        return resolution
    }

    func markDeleted(_ id: StoryId) {
        let _ = self.entries.modify { entries in
            var entries = entries
            if var entry = entries[id] { entry.wasDeleted = true; entries[id] = entry }
            return entries
        }
    }

    func requireRefresh(for id: StoryId) {
        let _ = self.entries.modify { entries in
            var entries = entries
            if var entry = entries[id] { entry.needsRefresh = true; entries[id] = entry }
            return entries
        }
    }

    func isPending(_ id: StoryId) -> Bool {
        return self.entries.with { $0[id] != nil }
    }

    func pendingReaction(for id: StoryId) -> MessageReaction.Reaction?? {
        return self.entries.with { $0[id]?.reaction }
    }
}

final class StoryReactionReconciliationContext {
    private struct Entry {
        let id = UUID()
        let disposable = MetaDisposable()
        var needsRepeat = false
    }

    private let entries = Atomic<[StoryId: Entry]>(value: [:])

    deinit {
        let disposables = self.entries.with { $0.values.map { $0.disposable } }
        for disposable in disposables { disposable.dispose() }
    }

    func isPending(_ storyId: StoryId) -> Bool {
        return self.entries.with { $0[storyId] != nil }
    }

    func begin(_ storyId: StoryId) -> (UUID, MetaDisposable)? {
        var result: (UUID, MetaDisposable)?
        let _ = self.entries.modify { entries in
            var entries = entries
            if var entry = entries[storyId] {
                entry.needsRepeat = true
                entries[storyId] = entry
            } else {
                let entry = Entry()
                entries[storyId] = entry
                result = (entry.id, entry.disposable)
            }
            return entries
        }
        return result
    }

    func finish(_ storyId: StoryId, id: UUID) -> Bool {
        var completed: Entry?
        let _ = self.entries.modify { entries in
            var entries = entries
            if let entry = entries[storyId], entry.id == id { completed = entries.removeValue(forKey: storyId) }
            return entries
        }
        completed?.disposable.dispose()
        return completed?.needsRepeat == true
    }
}

private func _internal_scheduleStoryReactionReconciliation(account: Account, storyId: StoryId) {
    if account.storyReactionContext.isPending(storyId) {
        account.storyReactionContext.requireRefresh(for: storyId)
        return
    }
    let context = account.storyReactionReconciliationContext
    guard let (id, disposable) = context.begin(storyId) else { return }
    disposable.set(_internal_refreshStories(account: account, peerId: storyId.peerId, ids: [storyId.id], skipDeleted: true).start(completed: { [weak account, weak context] in
        guard let context, context.finish(storyId, id: id), let account else { return }
        _internal_scheduleStoryReactionReconciliation(account: account, storyId: storyId)
    }))
}

func _internal_storyWithReaction(_ item: Stories.Item, isChannel: Bool, reaction: MessageReaction.Reaction?, views: Stories.Item.Views?? = nil) -> Stories.Item {
    let updatedViews: Stories.Item.Views?
    if let views {
        updatedViews = views
    } else {
        updatedViews = _internal_updateStoryViewsForMyReaction(isChannel: isChannel, views: item.views, previousReaction: item.myReaction, reaction: reaction)
    }
    return Stories.Item(
        id: item.id,
        timestamp: item.timestamp,
        expirationTimestamp: item.expirationTimestamp,
        media: item.media,
        alternativeMediaList: item.alternativeMediaList,
        mediaAreas: item.mediaAreas,
        text: item.text,
        entities: item.entities,
        views: updatedViews,
        privacy: item.privacy,
        isPinned: item.isPinned,
        isExpired: item.isExpired,
        isPublic: item.isPublic,
        isCloseFriends: item.isCloseFriends,
        isContacts: item.isContacts,
        isSelectedContacts: item.isSelectedContacts,
        isForwardingDisabled: item.isForwardingDisabled,
        isEdited: item.isEdited,
        isMy: item.isMy,
        myReaction: reaction,
        forwardInfo: item.forwardInfo,
        music: item.music,
        authorId: item.authorId,
        folderIds: item.folderIds
    )
}

func _internal_storyUpdatesViews(_ story: Api.StoryItem) -> Bool {
    switch story {
    case let .storyItem(data):
        return data.flags & (1 << 9) == 0
    case .storyItemDeleted:
        return true
    default:
        return false
    }
}

func _internal_applyStoryUpdate(transaction: Transaction, peerId: PeerId, story: Api.StoryItem, storyReactionContext: StoryReactionContext?, addToActive: Bool = true, viewsOverride: Stories.Item.Views?? = nil) -> [InternalStoryUpdate] {
    let originalEntries = transaction.getStoryItems(peerId: peerId)
    let storyId = StoryId(peerId: peerId, id: story.id)
    if case .storyItemDeleted = story {
        storyReactionContext?.markDeleted(storyId)
        _internal_removeStoryFromListCaches(transaction: transaction, peerId: peerId, id: story.id)
        let updatedEntries = originalEntries.filter { $0.id != story.id }
        if updatedEntries != originalEntries { transaction.setStoryItems(peerId: peerId, items: updatedEntries) }
        let empty = CodableEntry(data: Data())
        if let current = transaction.getStory(id: storyId), current != empty { transaction.setStory(id: storyId, value: empty) }
        return [.deleted(peerId: peerId, id: story.id)]
    }
    var previousItem: Stories.Item?
    for row in originalEntries where row.id == story.id {
        if case let .item(item) = row.value.get(Stories.StoredItem.self), item.id == story.id { previousItem = item; break }
    }
    if previousItem == nil, case let .item(item) = transaction.getStory(id: storyId)?.get(Stories.StoredItem.self), item.id == story.id {
        previousItem = item
    }
    if previousItem == nil { previousItem = _internal_cachedStoryItemValue(transaction: transaction, peerId: peerId, id: story.id) }
    guard var storedItem = Stories.StoredItem(apiStoryItem: story, existingItem: previousItem, peerId: peerId, transaction: transaction) else { return [] }
    switch storedItem {
    case let .item(item):
        if let viewsOverride {
            storedItem = .item(_internal_storyWithReaction(item, isChannel: peerId.namespace == Namespaces.Peer.CloudChannel, reaction: item.myReaction, views: .some(viewsOverride)))
        }
        if let storyReactionContext, let reaction = storyReactionContext.pendingReaction(for: storyId) {
            let current = previousItem ?? item
            let isChannel = peerId.namespace == Namespaces.Peer.CloudChannel
            let views = _internal_updateStoryViewsForMyReaction(isChannel: isChannel, views: current.views, previousReaction: current.myReaction, reaction: reaction)
            if item.myReaction != reaction || item.views != views { storyReactionContext.requireRefresh(for: storyId) }
            storedItem = .item(_internal_storyWithReaction(item, isChannel: isChannel, reaction: reaction, views: .some(views)))
        }
    case .placeholder:
        if previousItem != nil { return [] }
    }
    guard let entry = CodableEntry(storedItem) else { return [] }
    if case let .item(item) = storedItem { _internal_updateStoryListCacheItem(transaction: transaction, peerId: peerId, item: item) }
    var updatedEntries = originalEntries
    let row = StoryItemsTableEntry(value: entry, id: storedItem.id, expirationTimestamp: storedItem.expirationTimestamp, isCloseFriends: storedItem.isCloseFriends, isLiveStream: storedItem.isLiveStream)
    var replaced = false
    for index in updatedEntries.indices where updatedEntries[index].id == storedItem.id {
        updatedEntries[index] = row
        replaced = true
    }
    if !replaced && addToActive { updatedEntries.append(row) }
    if updatedEntries != originalEntries { transaction.setStoryItems(peerId: peerId, items: updatedEntries) }
    if case .item = storedItem, transaction.getStory(id: storyId) != entry { transaction.setStory(id: storyId, value: entry) }
    if addToActive && transaction.getPeerStoryState(peerId: peerId) == nil {
        transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(maxReadId: 0).postboxRepresentation)
    }
    return [.added(peerId: peerId, item: storedItem)]
}

func _internal_applyStoryReaction(transaction: Transaction, peerId: PeerId, id: Int32, reaction: MessageReaction.Reaction?, expectedReaction: MessageReaction.Reaction?? = nil) -> Stories.StoredItem? {
    var updatedItemValue: Stories.StoredItem?
    func updated(_ item: Stories.Item) -> Stories.StoredItem? {
        guard item.id == id, item.myReaction != reaction, expectedReaction == nil || item.myReaction == expectedReaction! else { return nil }
        return .item(_internal_storyWithReaction(item, isChannel: peerId.namespace == Namespaces.Peer.CloudChannel, reaction: reaction))
    }
    var currentItems = transaction.getStoryItems(peerId: peerId)
    var didUpdateItems = false
    for index in currentItems.indices where currentItems[index].id == id {
        if case let .item(item) = currentItems[index].value.get(Stories.StoredItem.self), let value = updated(item), let entry = CodableEntry(value) {
            updatedItemValue = value
            didUpdateItems = true
            currentItems[index] = StoryItemsTableEntry(value: entry, id: value.id, expirationTimestamp: value.expirationTimestamp, isCloseFriends: value.isCloseFriends, isLiveStream: value.isLiveStream)
        }
    }
    if didUpdateItems { transaction.setStoryItems(peerId: peerId, items: currentItems) }
    let storyId = StoryId(peerId: peerId, id: id)
    if case let .item(item) = transaction.getStory(id: storyId)?.get(Stories.StoredItem.self), let value = updated(item), let entry = CodableEntry(value) {
        updatedItemValue = value
        transaction.setStory(id: storyId, value: entry)
    }
    _internal_transformStoryListCacheItems(transaction: transaction, peerId: peerId, id: id) { item in
        guard let value = updated(item), case let .item(updatedItem) = value else { return nil }
        return updatedItem
    }
    return updatedItemValue
}

private func _internal_storyReactionValue(transaction: Transaction, storyId: StoryId) -> MessageReaction.Reaction?? {
    for row in transaction.getStoryItems(peerId: storyId.peerId) where row.id == storyId.id {
        if case let .item(item) = row.value.get(Stories.StoredItem.self), item.id == storyId.id { return .some(item.myReaction) }
    }
    if case let .item(item) = transaction.getStory(id: storyId)?.get(Stories.StoredItem.self), item.id == storyId.id { return .some(item.myReaction) }
    return nil
}

private func _internal_finishStoryReaction(account: Account, request: StoryReactionContext.Request, success: Bool, refreshOnFailure: Bool = true) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (reaction: MessageReaction.Reaction??, refresh: Bool) in
        guard let resolution = account.storyReactionContext.finish(request, success: success, refreshOnFailure: refreshOnFailure) else { return (nil, false) }
        account.storyViewRefreshContext.invalidate(peerId: request.storyId.peerId, ids: [request.storyId.id])
        _internal_invalidateStoryResolution(postbox: account.postbox, peerId: request.storyId.peerId, ids: [request.storyId.id])
        account.storyRefreshContext.invalidate(peerId: request.storyId.peerId, ids: [request.storyId.id])
        let refresh = resolution.needsRefresh && transaction.getStory(id: request.storyId) != CodableEntry(data: Data())
        guard let reaction = resolution.reaction, reaction != resolution.expectedReaction else { return (nil, refresh) }
        if let current = _internal_storyReactionValue(transaction: transaction, storyId: request.storyId), current != resolution.expectedReaction && current != reaction { return (nil, refresh) }
        _ = _internal_applyStoryReaction(transaction: transaction, peerId: request.storyId.peerId, id: request.storyId.id, reaction: reaction, expectedReaction: .some(resolution.expectedReaction))
        return (.some(reaction), refresh)
    }
    |> beforeNext { result in
        if let reaction = result.reaction {
            account.stateManager.injectStoryUpdates(updates: [.updateMyReaction(peerId: request.storyId.peerId, id: request.storyId.id, reaction: reaction)])
        }
        if result.refresh { _internal_scheduleStoryReactionReconciliation(account: account, storyId: request.storyId) }
    }
    |> ignoreValues
}

func _internal_setStoryReaction(account: Account, peerId: EnginePeer.Id, id: Int32, reaction: MessageReaction.Reaction?, knownPreviousReaction: MessageReaction.Reaction?? = nil) -> Signal<Never, NoError> {
    guard id > 0, reaction != .stars else { return .complete() }
    return Signal { subscriber in
        let lifecycle = Atomic<(ended: Bool, accepted: Bool)>(value: (false, false))
        let replayReady = ValuePromise<Bool>(false)
        let sent = Atomic<Bool>(value: false)
        let request = StoryReactionContext.Request(storyId: StoryId(peerId: peerId, id: id), reaction: reaction)
        let disposable = (account.postbox.transaction { transaction -> Api.InputPeer? in
            guard !lifecycle.with({ $0.ended }), let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else { return nil }
            let previousReaction: MessageReaction.Reaction??
            if let stored = _internal_storyReactionValue(transaction: transaction, storyId: request.storyId) {
                previousReaction = .some(stored)
            } else if let knownPreviousReaction {
                previousReaction = .some(knownPreviousReaction)
            } else {
                previousReaction = _internal_cachedStoryReactionValue(transaction: transaction, peerId: peerId, id: id)
            }
            account.storyReactionContext.begin(request, previousReaction: previousReaction)
            if account.storyReactionReconciliationContext.isPending(request.storyId) { account.storyReactionContext.requireRefresh(for: request.storyId) }
            account.storyViewRefreshContext.invalidate(peerId: peerId, ids: [id])
            _internal_invalidateStoryResolution(postbox: account.postbox, peerId: peerId, ids: [id])
            account.storyRefreshContext.invalidate(peerId: peerId, ids: [id])
            _ = _internal_applyStoryReaction(transaction: transaction, peerId: peerId, id: id, reaction: reaction)
            return inputPeer
        }
        |> mapToSignal { inputPeer -> Signal<Never, NoError> in
            guard let inputPeer, !lifecycle.with({ $0.ended }) else { return .complete() }
            account.stateManager.injectStoryUpdates(updates: [.updateMyReaction(peerId: peerId, id: id, reaction: reaction)])
            guard !lifecycle.with({ $0.ended }) else { return .complete() }
            _ = sent.swap(true)
            return account.network.request(Api.functions.stories.sendReaction(flags: 0, peer: inputPeer, storyId: id, reaction: reaction?.apiReaction ?? .reactionEmpty), tag: StoryReactionRequestDependencyTag(storyId: request.storyId))
            |> map { updates -> (updates: Api.Updates?, success: Bool) in (updates, true) }
            |> `catch` { error -> Signal<(updates: Api.Updates?, success: Bool), NoError> in
                return .single((nil, error.errorDescription == "STORY_NOT_MODIFIED"))
            }
            |> then(.single((nil, false)))
            |> take(1)
            |> mapToSignal { result -> Signal<Never, NoError> in
                guard !lifecycle.with({ $0.ended }) else { return .complete() }
                if result.success {
                    var accept = false
                    let _ = lifecycle.modify { state in
                        guard !state.ended else { return state }
                        accept = true
                        return (false, true)
                    }
                    guard accept else { return .complete() }
                }
                if let updates = result.updates {
                    account.stateManager.addUpdates(updates)
                    replayReady.set(true)
                    guard !lifecycle.with({ $0.ended }) else { return .complete() }
                    return (account.stateManager.pollStateUpdateCompletion()
                    |> take(1)
                    |> ignoreValues)
                    |> then(_internal_finishStoryReaction(account: account, request: request, success: true))
                }
                replayReady.set(true)
                return _internal_finishStoryReaction(account: account, request: request, success: result.success)
            }
        }).start(completed: {
            let _ = lifecycle.modify { (true, $0.accepted) }
            subscriber.putCompletion()
        })
        return ActionDisposable {
            var wasAccepted: Bool?
            let _ = lifecycle.modify { state in
                guard !state.ended else { return state }
                wasAccepted = state.accepted
                return (true, state.accepted)
            }
            if let wasAccepted {
                if wasAccepted {
                    let storyReactionContext = account.storyReactionContext
                    let stateManager: AccountStateManager = account.stateManager
                    weak let weakAccount = account
                    let _ = (replayReady.get()
                    |> filter { $0 }
                    |> take(1)
                    |> mapToSignal { [weak stateManager] _ in stateManager?.pollStateUpdateCompletion() ?? .complete() }
                    |> take(1)
                    |> mapToSignal { _ -> Signal<Never, NoError> in
                        guard let account = weakAccount else {
                            _ = storyReactionContext.finish(request, success: true)
                            return .complete()
                        }
                        return _internal_finishStoryReaction(account: account, request: request, success: true)
                    }).startStandalone()
                } else {
                    let _ = _internal_finishStoryReaction(account: account, request: request, success: false, refreshOnFailure: sent.with { $0 }).startStandalone()
                }
            }
            disposable.dispose()
        }
    }
}

func _internal_sendStoryStars(account: Account, peerId: EnginePeer.Id, id: Int32, count: Int) -> Signal<Never, NoError> {
    guard id > 0, let countValue = Int32(exactly: count), countValue > 0 else { return .complete() }
    return account.postbox.transaction { transaction -> (Stories.StoredItem?, Api.InputPeer?) in
        guard let peer = transaction.getPeer(peerId) else {
            return (nil, nil)
        }
        guard let inputPeer = apiInputPeer(peer) else {
            return (nil, nil)
        }
        
        var updatedItemValue: Stories.StoredItem?
        
        let updateViews: (Stories.Item.Views?, MessageReaction.Reaction?) -> Stories.Item.Views? = { views, previousReaction in
            return _internal_updateStoryViewsForMyReaction(isChannel: peerId.namespace == Namespaces.Peer.CloudChannel, views: views, previousReaction: previousReaction, reaction: .stars, addedCount: count)
        }
        
        var currentItems = transaction.getStoryItems(peerId: peerId)
        var didUpdateItems = false
        for i in 0 ..< currentItems.count {
            if currentItems[i].id == id {
                if case let .item(item) = currentItems[i].value.get(Stories.StoredItem.self), item.id == id {
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
                        isExpired: item.isExpired,
                        isPublic: item.isPublic,
                        isCloseFriends: item.isCloseFriends,
                        isContacts: item.isContacts,
                        isSelectedContacts: item.isSelectedContacts,
                        isForwardingDisabled: item.isForwardingDisabled,
                        isEdited: item.isEdited,
                        isMy: item.isMy,
                        myReaction: .stars,
                        forwardInfo: item.forwardInfo,
                        music: item.music,
                        authorId: item.authorId,
                        folderIds: item.folderIds
                    ))
                    if let entry = CodableEntry(updatedItem) {
                        updatedItemValue = updatedItem
                        didUpdateItems = true
                        currentItems[i] = StoryItemsTableEntry(value: entry, id: updatedItem.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends, isLiveStream: updatedItem.isLiveStream)
                    }
                }
            }
        }
        if didUpdateItems { transaction.setStoryItems(peerId: peerId, items: currentItems) }
        
        if let current = transaction.getStory(id: StoryId(peerId: peerId, id: id))?.get(Stories.StoredItem.self), case let .item(item) = current, item.id == id {
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
                isExpired: item.isExpired,
                isPublic: item.isPublic,
                isCloseFriends: item.isCloseFriends,
                isContacts: item.isContacts,
                isSelectedContacts: item.isSelectedContacts,
                isForwardingDisabled: item.isForwardingDisabled,
                isEdited: item.isEdited,
                isMy: item.isMy,
                myReaction: .stars,
                forwardInfo: item.forwardInfo,
                music: item.music,
                authorId: item.authorId,
                folderIds: item.folderIds
            ))
            if let entry = CodableEntry(updatedItem) {
                updatedItemValue = updatedItem
                transaction.setStory(id: StoryId(peerId: peerId, id: id), value: entry)
            }
        }
        
        return (updatedItemValue, inputPeer)
    }
    |> mapToSignal { storyItem, inputPeer -> Signal<Never, NoError> in
        guard let inputPeer else {
            return .complete()
        }
        
        if let storyItem {
            account.stateManager.injectStoryUpdates(updates: [InternalStoryUpdate.added(peerId: peerId, item: storyItem)])
        }
        account.stateManager.injectStoryUpdates(updates: [InternalStoryUpdate.updateMyReaction(peerId: peerId, id: id, reaction: .stars)])
        
        let _ = inputPeer
        
        //TODO:release
        return .complete()
        
        /*return account.network.request(Api.functions.stories.sendReaction(flags: 0, peer: inputPeer, storyId: id, reaction: .reactionPaid))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Updates?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { updates -> Signal<Never, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
            }
            
            return .complete()
        }*/
    }
}
