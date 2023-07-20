import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum EngineStoryInputMedia {
    case image(dimensions: PixelDimensions, data: Data, stickers: [TelegramMediaFile])
    case video(dimensions: PixelDimensions, duration: Double, resource: TelegramMediaResource, firstFrameFile: TempBoxFile?, stickers: [TelegramMediaFile])
    
    var embeddedStickers: [TelegramMediaFile] {
        switch self {
        case let .image(_, _, stickers), let .video(_, _, _, _, stickers):
            return stickers
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

public enum Stories {
    public final class Item: Codable, Equatable {
        public struct Views: Codable, Equatable {
            private enum CodingKeys: String, CodingKey {
                case seenCount = "seenCount"
                case seenPeerIds = "seenPeerIds"
            }
            
            public var seenCount: Int
            public var seenPeerIds: [PeerId]
            
            public init(seenCount: Int, seenPeerIds: [PeerId]) {
                self.seenCount = seenCount
                self.seenPeerIds = seenPeerIds
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.seenCount = Int(try container.decode(Int32.self, forKey: .seenCount))
                self.seenPeerIds = try container.decode([Int64].self, forKey: .seenPeerIds).map(PeerId.init)
            }
            
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(Int32(clamping: self.seenCount), forKey: .seenCount)
                try container.encode(self.seenPeerIds.map { $0.toInt64() }, forKey: .seenPeerIds)
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
        
        private enum CodingKeys: String, CodingKey {
            case id
            case timestamp
            case expirationTimestamp
            case media
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
        }
        
        public let id: Int32
        public let timestamp: Int32
        public let expirationTimestamp: Int32
        public let media: Media?
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
        
        public init(
            id: Int32,
            timestamp: Int32,
            expirationTimestamp: Int32,
            media: Media?,
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
            isEdited: Bool
        ) {
            self.id = id
            self.timestamp = timestamp
            self.expirationTimestamp = expirationTimestamp
            self.media = media
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
    case let .video(dimensions, duration, resource, firstFrameFile, _):
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
                TelegramMediaFileAttribute.Video(duration: duration, size: dimensions, flags: .supportsStreaming, preloadSize: nil)
            ]
        )
        
        return fileMedia
    }
}

private func uploadedStoryContent(postbox: Postbox, network: Network, media: Media, embeddedStickers: [TelegramMediaFile], accountPeerId: PeerId, messageMediaPreuploadManager: MessageMediaPreuploadManager, revalidationContext: MediaReferenceRevalidationContext, auxiliaryMethods: AccountAuxiliaryMethods, passFetchProgress: Bool) -> (signal: Signal<PendingMessageUploadedContentResult?, NoError>, media: Media) {
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
        peerId: accountPeerId,
        messageId: nil,
        attributes: attributes,
        text: "",
        media: [media]
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
        } else {
            privacyRules.append(.inputPrivacyValueAllowUsers(users: privacyUsers))
        }
    }
    if !privacyChats.isEmpty {
        privacyRules.append(.inputPrivacyValueAllowChatParticipants(chats: privacyChats))
    }
    return privacyRules
}

func _internal_uploadStory(account: Account, media: EngineStoryInputMedia, text: String, entities: [MessageTextEntity], pin: Bool, privacy: EngineStoryPrivacy, isForwardingDisabled: Bool, period: Int, randomId: Int64) {
    let inputMedia = prepareUploadStoryContent(account: account, media: media)
    
    let _ = (account.postbox.transaction { transaction in
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
            stableId: stableId,
            timestamp: Int32(Date().timeIntervalSince1970),
            media: inputMedia,
            text: text,
            entities: entities,
            embeddedStickers: media.embeddedStickers,
            pin: pin,
            privacy: privacy,
            isForwardingDisabled: isForwardingDisabled,
            period: Int32(period),
            randomId: randomId
        ))
        Logger.shared.log("UploadStory", "Appended new pending item stableId: \(stableId) randomId: \(randomId)")
        transaction.setLocalStoryState(state: CodableEntry(currentState))
    }).start()
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
    var accountPeerId: PeerId
    var stableId: Int32
}

private let pendingStoryIdMapping = Atomic<[PendingStoryIdMappingKey: Int32]>(value: [:])

func _internal_lookUpPendingStoryIdMapping(accountPeerId: PeerId, stableId: Int32) -> Int32? {
    return pendingStoryIdMapping.with { dict in
        return dict[PendingStoryIdMappingKey(accountPeerId: accountPeerId, stableId: stableId)]
    }
}

private func _internal_putPendingStoryIdMapping(accountPeerId: PeerId, stableId: Int32, id: Int32) {
    let _ = pendingStoryIdMapping.modify { dict in
        var dict = dict
        
        dict[PendingStoryIdMappingKey(accountPeerId: accountPeerId, stableId: stableId)] = id
        
        return dict
    }
}

func _internal_uploadStoryImpl(postbox: Postbox, network: Network, accountPeerId: PeerId, stateManager: AccountStateManager, messageMediaPreuploadManager: MessageMediaPreuploadManager, revalidationContext: MediaReferenceRevalidationContext, auxiliaryMethods: AccountAuxiliaryMethods, stableId: Int32, media: Media, text: String, entities: [MessageTextEntity], embeddedStickers: [TelegramMediaFile], pin: Bool, privacy: EngineStoryPrivacy, isForwardingDisabled: Bool, period: Int, randomId: Int64) -> Signal<StoryUploadResult, NoError> {
    Logger.shared.log("UploadStory", "uploadStoryImpl for stableId: \(stableId) randomId: \(randomId)")
    let passFetchProgress = media is TelegramMediaFile
    let (contentSignal, originalMedia) = uploadedStoryContent(postbox: postbox, network: network, media: media, embeddedStickers: embeddedStickers, accountPeerId: accountPeerId, messageMediaPreuploadManager: messageMediaPreuploadManager, revalidationContext: revalidationContext, auxiliaryMethods: auxiliaryMethods, passFetchProgress: passFetchProgress)
    return contentSignal
    |> mapToSignal { result -> Signal<StoryUploadResult, NoError> in
        switch result {
        case let .progress(progress):
            return .single(.progress(progress))
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
                                        
                    return network.request(Api.functions.stories.sendStory(
                        flags: flags,
                        media: inputMedia,
                        caption: apiCaption,
                        entities: apiEntities,
                        privacyRules: privacyRules,
                        randomId: randomId,
                        period: Int32(period)
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
                                        case let .storyItem(_, idValue, _, _, _, _, media, _, _):
                                            if let parsedStory = Stories.StoredItem(apiStoryItem: story, peerId: accountPeerId, transaction: transaction) {
                                                var items = transaction.getStoryItems(peerId: accountPeerId)
                                                var updatedItems: [Stories.Item] = []
                                                if items.firstIndex(where: { $0.id == id }) == nil, case let .item(item) = parsedStory {
                                                    let updatedItem = Stories.Item(
                                                        id: item.id,
                                                        timestamp: item.timestamp,
                                                        expirationTimestamp: item.expirationTimestamp,
                                                        media: item.media,
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
                                                        isEdited: item.isEdited
                                                    )
                                                    if let entry = CodableEntry(Stories.StoredItem.item(updatedItem)) {
                                                        items.append(StoryItemsTableEntry(value: entry, id: item.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends))
                                                    }
                                                    updatedItems.append(updatedItem)
                                                }
                                                transaction.setStoryItems(peerId: accountPeerId, items: items)
                                            }
                                            
                                            id = idValue
                                            let (parsedMedia, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, accountPeerId)
                                            if let parsedMedia = parsedMedia {
                                                applyMediaResourceChanges(from: originalMedia, to: parsedMedia, postbox: postbox, force: originalMedia is TelegramMediaFile && parsedMedia is TelegramMediaFile)
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                                
                                if let id = id {
                                    _internal_putPendingStoryIdMapping(accountPeerId: accountPeerId, stableId: stableId, id: id)
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

func _internal_editStory(account: Account, id: Int32, media: EngineStoryInputMedia?, text: String?, entities: [MessageTextEntity]?, privacy: EngineStoryPrivacy?) -> Signal<StoryUploadResult, NoError> {
    let contentSignal: Signal<PendingMessageUploadedContentResult?, NoError>
    let originalMedia: Media?
    if let media = media {
        var passFetchProgress = false
        if case .video = media {
            passFetchProgress = true
        }
        (contentSignal, originalMedia) = uploadedStoryContent(postbox: account.postbox, network: account.network, media: prepareUploadStoryContent(account: account, media: media), embeddedStickers: media.embeddedStickers, accountPeerId: account.peerId, messageMediaPreuploadManager: account.messageMediaPreuploadManager, revalidationContext: account.mediaReferenceRevalidationContext, auxiliaryMethods: account.auxiliaryMethods, passFetchProgress: passFetchProgress)
    } else {
        contentSignal = .single(nil)
        originalMedia = nil
    }
    
    return contentSignal
    |> mapToSignal { result -> Signal<StoryUploadResult, NoError> in
        if let result = result, case let .progress(progress) = result {
            return .single(.progress(progress))
        }
        
        let inputMedia: Api.InputMedia?
        if let result = result, case let .content(uploadedContent) = result, case let .media(media, _) = uploadedContent.content {
            inputMedia = media
        } else {
            inputMedia = nil
        }
        
        return account.postbox.transaction { transaction -> Signal<StoryUploadResult, NoError> in
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
            
            return account.network.request(Api.functions.stories.editStory(
                flags: flags,
                id: id,
                media: inputMedia,
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
                            case let .storyItem(_, _, _, _, _, _, media, _, _):
                                let (parsedMedia, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, account.peerId)
                                if let parsedMedia = parsedMedia, let originalMedia = originalMedia {
                                    applyMediaResourceChanges(from: originalMedia, to: parsedMedia, postbox: account.postbox, force: false)
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
                isEdited: item.isEdited
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
                isEdited: item.isEdited
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
        
        return account.network.request(Api.functions.stories.editStory(flags: flags, id: id, media: nil, caption: nil, entities: nil, privacyRules: inputRules))
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

func _internal_deleteStories(account: Account, ids: [Int32]) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        var items = transaction.getStoryItems(peerId: account.peerId)
        var updated = false
        for id in ids {
            if let index = items.firstIndex(where: { $0.id == id }) {
                items.remove(at: index)
                updated = true
            }
        }
        if updated {
            transaction.setStoryItems(peerId: account.peerId, items: items)
        }
        account.stateManager.injectStoryUpdates(updates: ids.map { id in
            return .deleted(peerId: account.peerId, id: id)
        })
    }
    |> mapToSignal { _ -> Signal<Never, NoError> in
        return account.network.request(Api.functions.stories.deleteStories(id: ids))
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
        return account.postbox.transaction { transaction -> Api.InputUser? in
            return transaction.getPeer(peerId).flatMap(apiInputUser)
        }
        |> mapToSignal { inputUser -> Signal<Never, NoError> in
            guard let inputUser = inputUser else {
                return .complete()
            }
            
            #if DEBUG && false
            if "".isEmpty {
                return .complete()
            }
            #endif
            
            return account.network.request(Api.functions.stories.incrementStoryViews(userId: inputUser, id: [id]))
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

func _internal_updateStoriesArePinned(account: Account, ids: [Int32: EngineStoryItem], isPinned: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Void in
        var items = transaction.getStoryItems(peerId: account.peerId)
        var updatedItems: [Stories.Item] = []
        for (id, referenceItem) in ids {
            if let index = items.firstIndex(where: { $0.id == id }), case let .item(item) = items[index].value.get(Stories.StoredItem.self) {
                let updatedItem = Stories.Item(
                    id: item.id,
                    timestamp: item.timestamp,
                    expirationTimestamp: item.expirationTimestamp,
                    media: item.media,
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
                    isEdited: item.isEdited
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
                    isEdited: item.isEdited
                )
                updatedItems.append(updatedItem)
            }
        }
        transaction.setStoryItems(peerId: account.peerId, items: items)
        if !updatedItems.isEmpty {
            DispatchQueue.main.async {
                account.stateManager.injectStoryUpdates(updates: updatedItems.map { updatedItem in
                    return .added(peerId: account.peerId, item: Stories.StoredItem.item(updatedItem))
                })
            }
        }
    }
    |> mapToSignal { _ -> Signal<Never, NoError> in
        return account.network.request(Api.functions.stories.togglePinned(id: ids.keys.sorted(), pinned: isPinned ? .boolTrue : .boolFalse))
        |> `catch` { _ -> Signal<[Int32], NoError> in
            return .single([])
        }
        |> ignoreValues
    }
}

extension Api.StoryItem {
    var id: Int32 {
        switch self {
        case let .storyItem(_, id, _, _, _, _, _, _, _):
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
        case let .storyViews(_, viewsCount, recentViewers):
            var seenPeerIds: [PeerId] = []
            if let recentViewers = recentViewers {
                seenPeerIds = recentViewers.map { PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) }
            }
            self.init(seenCount: Int(viewsCount), seenPeerIds: seenPeerIds)
        }
    }
}

extension Stories.StoredItem {
    init?(apiStoryItem: Api.StoryItem, peerId: PeerId, transaction: Transaction) {
        switch apiStoryItem {
        case let .storyItem(flags, id, date, expireDate, caption, entities, media, privacy, views):
            let (parsedMedia, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
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
                let isForwardingDisabled = (flags & (1 << 10)) != 0
                let isEdited = (flags & (1 << 11)) != 0
                let isContacts = (flags & (1 << 12)) != 0
                let isSelectedContacts = (flags & (1 << 13)) != 0
                
                let item = Stories.Item(
                    id: id,
                    timestamp: date,
                    expirationTimestamp: expireDate,
                    media: parsedMedia,
                    text: caption ?? "",
                    entities: entities.flatMap { entities in return messageTextEntitiesFromApiEntities(entities) } ?? [],
                    views: views.flatMap(Stories.Item.Views.init(apiViews:)),
                    privacy: parsedPrivacy,
                    isPinned: isPinned,
                    isExpired: isExpired,
                    isPublic: isPublic,
                    isCloseFriends: isCloseFriends,
                    isContacts: isContacts,
                    isSelectedContacts: isSelectedContacts,
                    isForwardingDisabled: isForwardingDisabled,
                    isEdited: isEdited
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

func _internal_getStoriesById(accountPeerId: PeerId, postbox: Postbox, network: Network, peer: PeerReference, ids: [Int32]) -> Signal<[Stories.StoredItem], NoError> {
    guard let inputUser = peer.inputUser else {
        return .single([])
    }
    
    return network.request(Api.functions.stories.getStoriesByID(userId: inputUser, id: ids))
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
            case let .stories(_, stories, users):
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                
                return stories.compactMap { apiStoryItem -> Stories.StoredItem? in
                    return Stories.StoredItem(apiStoryItem: apiStoryItem, peerId: peer.id, transaction: transaction)
                }
            }
        }
    }
}

func _internal_getStoriesById(accountPeerId: PeerId, postbox: Postbox, source: FetchMessageHistoryHoleSource, peerId: PeerId, peerReference: PeerReference?, ids: [Int32]) -> Signal<[Stories.StoredItem], NoError> {
    return postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<[Stories.StoredItem], NoError> in
        guard let inputUser = inputUser ?? peerReference?.inputUser else {
            return .single([])
        }
        
        return source.request(Api.functions.stories.getStoriesByID(userId: inputUser, id: ids))
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
                case let .stories(_, stories, users):
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                    
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
    
    public init(items: [Item], totalCount: Int) {
        self.items = items
        self.totalCount = totalCount
    }
}

func _internal_getStoryViewList(account: Account, id: Int32, offsetTimestamp: Int32?, offsetPeerId: PeerId?, limit: Int) -> Signal<StoryViewList?, NoError> {
    let accountPeerId = account.peerId
    return account.network.request(Api.functions.stories.getStoryViewsList(id: id, offsetDate: offsetTimestamp ?? 0, offsetId: offsetPeerId?.id._internalGetInt64Value() ?? 0, limit: Int32(limit)))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.stories.StoryViewsList?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<StoryViewList?, NoError> in
        guard let result = result else {
            return .single(nil)
        }
        return account.postbox.transaction { transaction -> StoryViewList? in
            switch result {
            case let .storyViewsList(count, views, users):
                updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                
                var items: [StoryViewList.Item] = []
                for view in views {
                    switch view {
                    case let .storyView(userId, date):
                        if let peer = transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))) {
                            items.append(StoryViewList.Item(peer: EnginePeer(peer), timestamp: date))
                        }
                    }
                }
                
                return StoryViewList(items: items, totalCount: Int(count))
            }
        }
    }
}

func _internal_getStoryViews(account: Account, ids: [Int32]) -> Signal<[Int32: Stories.Item.Views], NoError> {
    let accountPeerId = account.peerId
    return account.network.request(Api.functions.stories.getStoriesViews(id: ids))
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

public final class EngineStoryViewListContext {
    public struct LoadMoreToken: Equatable {
        var id: Int64
        var timestamp: Int32
    }
    
    public final class Item: Equatable {
        public let peer: EnginePeer
        public let timestamp: Int32
        public let storyStats: PeerStoryStats?
        
        public init(
            peer: EnginePeer,
            timestamp: Int32,
            storyStats: PeerStoryStats?
        ) {
            self.peer = peer
            self.timestamp = timestamp
            self.storyStats = storyStats
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.timestamp != rhs.timestamp {
                return false
            }
            if lhs.storyStats != rhs.storyStats {
                return false
            }
            return true
        }
    }
    
    public struct State: Equatable {
        public var totalCount: Int
        public var items: [Item]
        public var loadMoreToken: LoadMoreToken?
        
        public init(
            totalCount: Int,
            items: [Item],
            loadMoreToken: LoadMoreToken?
        ) {
            self.totalCount = totalCount
            self.items = items
            self.loadMoreToken = loadMoreToken
        }
    }
    
    private final class Impl {
        struct NextOffset: Equatable {
            var id: Int64
            var timestamp: Int32
        }
        
        struct InternalState: Equatable {
            var totalCount: Int
            var items: [Item]
            var canLoadMore: Bool
            var nextOffset: NextOffset?
        }
        
        let queue: Queue
        
        let account: Account
        let storyId: Int32
        
        let disposable = MetaDisposable()
        let storyStatsDisposable = MetaDisposable()
        
        var state: InternalState
        let statePromise = Promise<InternalState>()
        
        var isLoadingMore: Bool = false
        
        init(queue: Queue, account: Account, storyId: Int32, views: EngineStoryItem.Views) {
            self.queue = queue
            self.account = account
            self.storyId = storyId
            
            let initialState = State(totalCount: views.seenCount, items: [], loadMoreToken: LoadMoreToken(id: 0, timestamp: 0))
            self.state = InternalState(totalCount: initialState.totalCount, items: initialState.items, canLoadMore: initialState.loadMoreToken != nil, nextOffset: nil)
            self.statePromise.set(.single(self.state))
            
            if initialState.loadMoreToken != nil {
                self.loadMore()
            }
        }
        
        deinit {
            assert(self.queue.isCurrent())
            
            self.disposable.dispose()
            self.storyStatsDisposable.dispose()
        }
        
        func loadMore() {
            if !self.state.canLoadMore {
                return
            }
            if self.isLoadingMore {
                return
            }
            self.isLoadingMore = true
            
            let account = self.account
            let accountPeerId = account.peerId
            let storyId = self.storyId
            let currentOffset = self.state.nextOffset
            let limit = self.state.items.isEmpty ? 50 : 100
            let signal: Signal<InternalState, NoError> = self.account.postbox.transaction { transaction -> Void in
            }
            |> mapToSignal { _ -> Signal<InternalState, NoError> in
                return account.network.request(Api.functions.stories.getStoryViewsList(id: storyId, offsetDate: currentOffset?.timestamp ?? 0, offsetId: currentOffset?.id ?? 0, limit: Int32(limit)))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stories.StoryViewsList?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<InternalState, NoError> in
                    return account.postbox.transaction { transaction -> InternalState in
                        switch result {
                        case let .storyViewsList(count, views, users):
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                            
                            var items: [Item] = []
                            var nextOffset: NextOffset?
                            for view in views {
                                switch view {
                                case let .storyView(userId, date):
                                    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                    if let peer = transaction.getPeer(peerId) {
                                        items.append(Item(peer: EnginePeer(peer), timestamp: date, storyStats: transaction.getPeerStoryStats(peerId: peerId)))
                                        
                                        nextOffset = NextOffset(id: userId, timestamp: date)
                                    }
                                }
                            }
                            
                            if let storedItem = transaction.getStory(id: StoryId(peerId: account.peerId, id: storyId))?.get(Stories.StoredItem.self), case let .item(item) = storedItem, let currentViews = item.views {
                                let updatedItem: Stories.StoredItem = .item(Stories.Item(
                                    id: item.id,
                                    timestamp: item.timestamp,
                                    expirationTimestamp: item.expirationTimestamp,
                                    media: item.media,
                                    text: item.text,
                                    entities: item.entities,
                                    views: Stories.Item.Views(seenCount: Int(count), seenPeerIds: currentViews.seenPeerIds),
                                    privacy: item.privacy,
                                    isPinned: item.isPinned,
                                    isExpired: item.isExpired,
                                    isPublic: item.isPublic,
                                    isCloseFriends: item.isCloseFriends,
                                    isContacts: item.isContacts,
                                    isSelectedContacts: item.isSelectedContacts,
                                    isForwardingDisabled: item.isForwardingDisabled,
                                    isEdited: item.isEdited
                                ))
                                if let entry = CodableEntry(updatedItem) {
                                    transaction.setStory(id: StoryId(peerId: account.peerId, id: storyId), value: entry)
                                }
                            }
                            
                            var currentItems = transaction.getStoryItems(peerId: account.peerId)
                            for i in 0 ..< currentItems.count {
                                if currentItems[i].id == storyId {
                                    if case let .item(item) = currentItems[i].value.get(Stories.StoredItem.self), let currentViews = item.views {
                                        let updatedItem: Stories.StoredItem = .item(Stories.Item(
                                            id: item.id,
                                            timestamp: item.timestamp,
                                            expirationTimestamp: item.expirationTimestamp,
                                            media: item.media,
                                            text: item.text,
                                            entities: item.entities,
                                            views: Stories.Item.Views(seenCount: Int(count), seenPeerIds: currentViews.seenPeerIds),
                                            privacy: item.privacy,
                                            isPinned: item.isPinned,
                                            isExpired: item.isExpired,
                                            isPublic: item.isPublic,
                                            isCloseFriends: item.isCloseFriends,
                                            isContacts: item.isContacts,
                                            isSelectedContacts: item.isSelectedContacts,
                                            isForwardingDisabled: item.isForwardingDisabled,
                                            isEdited: item.isEdited
                                        ))
                                        if let entry = CodableEntry(updatedItem) {
                                            currentItems[i] = StoryItemsTableEntry(value: entry, id: updatedItem.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends)
                                        }
                                    }
                                }
                            }
                            transaction.setStoryItems(peerId: account.peerId, items: currentItems)
                            
                            return InternalState(totalCount: Int(count), items: items, canLoadMore: nextOffset != nil, nextOffset: nextOffset)
                        case .none:
                            return InternalState(totalCount: 0, items: [], canLoadMore: false, nextOffset: nil)
                        }
                    }
                }
            }
            self.disposable.set((signal
            |> deliverOn(self.queue)).start(next: { [weak self] state in
                guard let strongSelf = self else {
                    return
                }
                
                struct ItemHash: Hashable {
                    var peerId: EnginePeer.Id
                }
                
                var existingItems = Set<ItemHash>()
                for item in strongSelf.state.items {
                    existingItems.insert(ItemHash(peerId: item.peer.id))
                }
                
                for item in state.items {
                    let itemHash = ItemHash(peerId: item.peer.id)
                    if existingItems.contains(itemHash) {
                        continue
                    }
                    existingItems.insert(itemHash)
                    strongSelf.state.items.append(item)
                }
                if state.canLoadMore {
                    strongSelf.state.totalCount = max(state.totalCount, strongSelf.state.items.count)
                } else {
                    strongSelf.state.totalCount = strongSelf.state.items.count
                }
                strongSelf.state.canLoadMore = state.canLoadMore
                strongSelf.state.nextOffset = state.nextOffset
                
                strongSelf.isLoadingMore = false
                strongSelf.statePromise.set(.single(strongSelf.state))
                
                let statsKey: PostboxViewKey = .peerStoryStats(peerIds: Set(strongSelf.state.items.map(\.peer.id)))
                strongSelf.storyStatsDisposable.set((strongSelf.account.postbox.combinedView(keys: [statsKey])
                |> deliverOn(strongSelf.queue)).start(next: { views in
                    guard let `self` = self else {
                        return
                    }
                    guard let view = views.views[statsKey] as? PeerStoryStatsView else {
                        return
                    }
                    var updated = false
                    var items = self.state.items
                    for i in 0 ..< strongSelf.state.items.count {
                        let item = items[i]
                        let value = view.storyStats[item.peer.id]
                        if item.storyStats != value {
                            updated = true
                            items[i] = Item(
                                peer: item.peer,
                                timestamp: item.timestamp,
                                storyStats: value
                            )
                        }
                    }
                    if updated {
                        self.state.items = items
                        self.statePromise.set(.single(self.state))
                    }
                }))
            }))
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.statePromise.get().start(next: { state in
                    var loadMoreToken: LoadMoreToken?
                    if let nextOffset = state.nextOffset {
                        loadMoreToken = LoadMoreToken(id: nextOffset.id, timestamp: nextOffset.timestamp)
                    }
                    subscriber.putNext(State(
                        totalCount: state.totalCount,
                        items: state.items,
                        loadMoreToken: loadMoreToken
                    ))
                }))
            }
            return disposable
        }
    }
    
    init(account: Account, storyId: Int32, views: EngineStoryItem.Views) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, storyId: storyId, views: views)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
}

func _internal_updatePeerStoriesHidden(account: Account, id: PeerId, isHidden: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        guard let peer = transaction.getPeer(id) else {
            return nil
        }
        guard let user = peer as? TelegramUser else {
            return nil
        }
        updatePeersCustom(transaction: transaction, peers: [user.withUpdatedStoriesHidden(isHidden)], update: { _, updated in
            return updated
        })
        return apiInputUser(peer)
    }
    |> mapToSignal { inputUser -> Signal<Never, NoError> in
        guard let inputUser = inputUser else {
            return .complete()
        }
        return account.network.request(Api.functions.contacts.toggleStoriesHidden(id: inputUser, hidden: isHidden ? .boolTrue : .boolFalse))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> ignoreValues
    }
}

func _internal_exportStoryLink(account: Account, peerId: EnginePeer.Id, id: Int32) -> Signal<String?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<String?, NoError> in
        guard let inputUser = inputUser else {
            return .single(nil)
        }
        return account.network.request(Api.functions.stories.exportStoryLink(userId: inputUser, id: id))
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
    return _internal_getStoriesById(accountPeerId: account.peerId, postbox: account.postbox, source: .network(account.network), peerId: peerId, peerReference: nil, ids: ids)
    |> mapToSignal { result -> Signal<Never, NoError> in
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
    return network.request(Api.functions.stories.getAllReadUserStories())
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
                case let .updateReadStories(userId, maxId):
                    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
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
