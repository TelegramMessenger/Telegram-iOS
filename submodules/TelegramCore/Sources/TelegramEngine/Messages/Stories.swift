import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public enum EngineStoryInputMedia {
    case image(dimensions: PixelDimensions, data: Data)
    case video(dimensions: PixelDimensions, duration: Int, resource: TelegramMediaResource)
}

public struct EngineStoryPrivacy: Equatable {
    public enum Base {
        case everyone
        case contacts
        case closeFriends
        case nobody
    }
    
    public var base: Base
    public var additionallyIncludePeers: [EnginePeer.Id]
    
    public init(base: Base, additionallyIncludePeers: [EnginePeer.Id]) {
        self.base = base
        self.additionallyIncludePeers = additionallyIncludePeers
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
            
            public enum Base: Int32 {
                case everyone = 0
                case contacts = 1
                case closeFriends = 2
                case nobody = 3
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
            case media
            case text
            case entities
            case views
            case privacy
        }
        
        public let id: Int32
        public let timestamp: Int32
        public let media: Media?
        public let text: String
        public let entities: [MessageTextEntity]
        public let views: Views?
        public let privacy: Privacy?
        
        public init(
            id: Int32,
            timestamp: Int32,
            media: Media?,
            text: String,
            entities: [MessageTextEntity],
            views: Views?,
            privacy: Privacy?
        ) {
            self.id = id
            self.timestamp = timestamp
            self.media = media
            self.text = text
            self.entities = entities
            self.views = views
            self.privacy = privacy
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(Int32.self, forKey: .id)
            self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
            
            if let mediaData = try container.decodeIfPresent(Data.self, forKey: .media) {
                self.media = PostboxDecoder(buffer: MemoryBuffer(data: mediaData)).decodeRootObject() as? Media
            } else {
                self.media = nil
            }
            
            self.text = try container.decode(String.self, forKey: .text)
            self.entities = try container.decode([MessageTextEntity].self, forKey: .entities)
            self.views = try container.decodeIfPresent(Views.self, forKey: .views)
            self.privacy = try container.decodeIfPresent(Privacy.self, forKey: .privacy)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.id, forKey: .id)
            try container.encode(self.timestamp, forKey: .timestamp)
            
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
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.timestamp != rhs.timestamp {
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
            
            return true
        }
    }
    
    public final class Placeholder: Codable, Equatable {
        private enum CodingKeys: String, CodingKey {
            case id
            case timestamp
        }
        
        public let id: Int32
        public let timestamp: Int32
        
        public init(
            id: Int32,
            timestamp: Int32
        ) {
            self.id = id
            self.timestamp = timestamp
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.id = try container.decode(Int32.self, forKey: .id)
            self.timestamp = try container.decode(Int32.self, forKey: .timestamp)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(self.id, forKey: .id)
            try container.encode(self.timestamp, forKey: .timestamp)
        }
        
        public static func ==(lhs: Placeholder, rhs: Placeholder) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.timestamp != rhs.timestamp {
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
        private enum CodingKeys: CodingKey {
            case subscriptionsOpaqueState
            case maxReadId
        }
        
        public let subscriptionsOpaqueState: String?
        public let maxReadId: Int32
        
        public init(
            subscriptionsOpaqueState: String?,
            maxReadId: Int32
        ){
            self.subscriptionsOpaqueState = subscriptionsOpaqueState
            self.maxReadId = maxReadId
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.subscriptionsOpaqueState = try container.decodeIfPresent(String.self, forKey: .subscriptionsOpaqueState)
            self.maxReadId = try container.decode(Int32.self, forKey: .maxReadId)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encodeIfPresent(self.subscriptionsOpaqueState, forKey: .subscriptionsOpaqueState)
            try container.encode(self.maxReadId, forKey: .maxReadId)
        }
        
        public static func ==(lhs: PeerState, rhs: PeerState) -> Bool {
            if lhs.subscriptionsOpaqueState != rhs.subscriptionsOpaqueState {
                return false
            }
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
        public let storyCount: Int
        public let lastTimestamp: Int32
        
        public init(
            peer: EnginePeer,
            hasUnseen: Bool,
            storyCount: Int,
            lastTimestamp: Int32
        ) {
            self.peer = peer
            self.hasUnseen = hasUnseen
            self.storyCount = storyCount
            self.lastTimestamp = lastTimestamp
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.hasUnseen != rhs.hasUnseen {
                return false
            }
            if lhs.storyCount != rhs.storyCount {
                return false
            }
            if lhs.lastTimestamp != rhs.lastTimestamp {
                return false
            }
            return true
        }
    }
    
    public let items: [Item]
    public let hasMoreToken: String?
    
    public init(items: [Item], hasMoreToken: String?) {
        self.items = items
        self.hasMoreToken = hasMoreToken
    }
    
    public static func ==(lhs: EngineStorySubscriptions, rhs: EngineStorySubscriptions) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.hasMoreToken != rhs.hasMoreToken {
            return false
        }
        return true
    }
}

func _internal_uploadStory(account: Account, media: EngineStoryInputMedia, text: String, entities: [MessageTextEntity], privacy: EngineStoryPrivacy) -> Signal<Never, NoError> {
    let originalMedia: Media
    let contentToUpload: MessageContentToUpload
    
    switch media {
    case let .image(dimensions, data):
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
        originalMedia = imageMedia
        
        contentToUpload = messageContentToUpload(
            accountPeerId: account.peerId,
            network: account.network,
            postbox: account.postbox,
            auxiliaryMethods: account.auxiliaryMethods,
            transformOutgoingMessageMedia: nil,
            messageMediaPreuploadManager: account.messageMediaPreuploadManager,
            revalidationContext: account.mediaReferenceRevalidationContext,
            forceReupload: true,
            isGrouped: false,
            peerId: account.peerId,
            messageId: nil,
            attributes: [],
            text: "",
            media: [imageMedia]
        )
    case let .video(dimensions, duration, resource):
        let fileMedia = TelegramMediaFile(
            fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: MediaId.Id.random(in: MediaId.Id.min ... MediaId.Id.max)),
            partialReference: nil,
            resource: resource,
            previewRepresentations: [],
            videoThumbnails: [],
            immediateThumbnailData: nil,
            mimeType: "video/mp4",
            size: nil,
            attributes: [
                TelegramMediaFileAttribute.Video(duration: duration, size: dimensions, flags: .supportsStreaming, preloadSize: nil)
            ]
        )
        originalMedia = fileMedia
        
        contentToUpload = messageContentToUpload(
            accountPeerId: account.peerId,
            network: account.network,
            postbox: account.postbox,
            auxiliaryMethods: account.auxiliaryMethods,
            transformOutgoingMessageMedia: nil,
            messageMediaPreuploadManager: account.messageMediaPreuploadManager,
            revalidationContext: account.mediaReferenceRevalidationContext,
            forceReupload: true,
            isGrouped: false,
            peerId: account.peerId,
            messageId: nil,
            attributes: [],
            text: "",
            media: [fileMedia]
        )
    }
        
    let contentSignal: Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>
    switch contentToUpload {
    case let .immediate(result, _):
        contentSignal = .single(result)
    case let .signal(signal, _):
        contentSignal = signal
    }
    
    return contentSignal
    |> map(Optional.init)
    |> `catch` { _ -> Signal<PendingMessageUploadedContentResult?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Never, NoError> in
        return account.postbox.transaction { transaction -> Signal<Never, NoError> in
            var privacyRules: [Api.InputPrivacyRule]
            switch privacy.base {
            case .everyone:
                privacyRules = [.inputPrivacyValueAllowAll]
            case .contacts:
                privacyRules = [.inputPrivacyValueAllowContacts]
            case .closeFriends:
                privacyRules = [.inputPrivacyValueAllowCloseFriends]
            case .nobody:
                privacyRules = [.inputPrivacyValueDisallowAll]
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
                privacyRules.append(.inputPrivacyValueAllowUsers(users: privacyUsers))
            }
            if !privacyChats.isEmpty {
                privacyRules.append(.inputPrivacyValueAllowChatParticipants(chats: privacyChats))
            }
            
            switch result {
            case let .content(content):
                switch content.content {
                case let .media(inputMedia, _):
                    var flags: Int32 = 0
                    var apiCaption: String?
                    var apiEntities: [Api.MessageEntity]?
                    
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
                    
                    return account.network.request(Api.functions.stories.sendStory(
                        flags: flags,
                        media: inputMedia,
                        caption: apiCaption,
                        entities: apiEntities,
                        privacyRules: privacyRules
                    ))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { updates -> Signal<Never, NoError> in
                        if let updates = updates {
                            for update in updates.allUpdates {
                                if case let .updateStories(stories) = update {
                                    switch stories {
                                    case let .userStories(_, userId, _, apiStories):
                                        if PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)) == account.peerId, apiStories.count == 1 {
                                            switch apiStories[0] {
                                            case let .storyItem(_, _, _, _, _, media, _, _):
                                                let (parsedMedia, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, account.peerId)
                                                if let parsedMedia = parsedMedia {
                                                    applyMediaResourceChanges(from: originalMedia, to: parsedMedia, postbox: account.postbox, force: false)
                                                }
                                            default:
                                                break
                                            }
                                        }
                                    }
                                }
                            }
                            
                            account.stateManager.addUpdates(updates)
                        }
                        
                        return .complete()
                    }
                default:
                    return .complete()
                }
            default:
                return .complete()
            }
        }
        |> switchToLatest
    }
}

func _internal_deleteStory(account: Account, id: Int32) -> Signal<Never, NoError> {
    return account.network.request(Api.functions.stories.deleteStories(id: [id]))
    |> `catch` { _ -> Signal<[Int32], NoError> in
        return .single([])
    }
    |> mapToSignal { _ -> Signal<Never, NoError> in
        return .complete()
    }
}

func _internal_markStoryAsSeen(account: Account, peerId: PeerId, id: Int32) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputUser? in
        if let peerStoryState = transaction.getPeerStoryState(peerId: peerId)?.get(Stories.PeerState.self) {
            transaction.setPeerStoryState(peerId: peerId, state: CodableEntry(Stories.PeerState(
                subscriptionsOpaqueState: peerStoryState.subscriptionsOpaqueState,
                maxReadId: max(peerStoryState.maxReadId, id)
            )))
        }
        
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<Never, NoError> in
        guard let inputUser = inputUser else {
            return .complete()
        }
        
        account.stateManager.injectStoryUpdates(updates: [.read(peerId: peerId, maxId: id)])
        
        #if DEBUG
        if "".isEmpty {
            return .complete()
        }
        #endif
        
        return account.network.request(Api.functions.stories.readStories(userId: inputUser, maxId: id))
        |> `catch` { _ -> Signal<[Int32], NoError> in
            return .single([])
        }
        |> ignoreValues
    }
}

extension Api.StoryItem {
    var id: Int32 {
        switch self {
        case let .storyItem(_, id, _, _, _, _, _, _):
            return id
        case let .storyItemDeleted(id):
            return id
        case let .storyItemSkipped(id, _):
            return id
        }
    }
}

extension Stories.Item.Views {
    init(apiViews: Api.StoryViews) {
        switch apiViews {
        case let .storyViews(recentViewers, viewsCount):
            self.init(seenCount: Int(viewsCount), seenPeerIds: recentViewers.map { PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value($0)) })
        }
    }
}

extension Stories.StoredItem {
    init?(apiStoryItem: Api.StoryItem, peerId: PeerId, transaction: Transaction) {
        switch apiStoryItem {
        case let .storyItem(flags, id, date, caption, entities, media, privacy, views):
            let _ = flags
            let (parsedMedia, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
            if let parsedMedia = parsedMedia {
                var parsedPrivacy: Stories.Item.Privacy?
                if let privacy = privacy {
                    var base: Stories.Item.Privacy.Base = .everyone
                    var additionalPeerIds: [PeerId] = []
                    for rule in privacy {
                        switch rule {
                        case .privacyValueAllowAll:
                            base = .everyone
                        case .privacyValueAllowContacts:
                            base = .contacts
                        case .privacyValueAllowCloseFriends:
                            base = .closeFriends
                        case let .privacyValueAllowUsers(users):
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
                
                let item = Stories.Item(
                    id: id,
                    timestamp: date,
                    media: parsedMedia,
                    text: caption ?? "",
                    entities: entities.flatMap { entities in return messageTextEntitiesFromApiEntities(entities) } ?? [],
                    views: views.flatMap(Stories.Item.Views.init(apiViews:)),
                    privacy: parsedPrivacy
                )
                self = .item(item)
            } else {
                return nil
            }
        case let .storyItemSkipped(id, date):
            self = .placeholder(Stories.Placeholder(id: id, timestamp: date))
        case .storyItemDeleted:
            return nil
        }
    }
}

func _internal_parseApiStoryItem(transaction: Transaction, peerId: PeerId, apiStory: Api.StoryItem) -> StoryListContext.Item? {
    switch apiStory {
    case let .storyItem(flags, id, date, caption, entities, media, privacy, views):
        let _ = flags
        let (parsedMedia, _, _, _) = textMediaAndExpirationTimerFromApiMedia(media, peerId)
        if let parsedMedia = parsedMedia {
            var parsedPrivacy: EngineStoryPrivacy?
            if let privacy = privacy {
                var base: EngineStoryPrivacy.Base = .everyone
                var additionalPeerIds: [EnginePeer.Id] = []
                for rule in privacy {
                    switch rule {
                    case .privacyValueAllowAll:
                        base = .everyone
                    case .privacyValueAllowContacts:
                        base = .contacts
                    case .privacyValueAllowCloseFriends:
                        base = .closeFriends
                    case let .privacyValueAllowUsers(users):
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
                parsedPrivacy = EngineStoryPrivacy(base: base, additionallyIncludePeers: additionalPeerIds)
            }
            
            let item = StoryListContext.Item(
                id: id,
                timestamp: date,
                media: EngineMedia(parsedMedia),
                text: caption ?? "",
                entities: entities.flatMap { entities in return messageTextEntitiesFromApiEntities(entities) } ?? [],
                views: views.flatMap { _internal_parseApiStoryViews(transaction: transaction, views: $0) },
                privacy: parsedPrivacy
            )
            return item
        } else {
            return nil
        }
    case .storyItemSkipped:
        return nil
    case .storyItemDeleted:
        return nil
    }
}

func _internal_parseApiStoryViews(transaction: Transaction, views: Api.StoryViews) -> StoryListContext.Views {
    switch views {
    case let .storyViews(recentViewers, viewsCount):
        return StoryListContext.Views(seenCount: Int(viewsCount), seenPeers: recentViewers.compactMap { id -> EnginePeer? in
            return transaction.getPeer(PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))).flatMap(EnginePeer.init)
        })
    }
}

func _internal_getStoriesById(accountPeerId: PeerId, postbox: Postbox, network: Network, peerId: PeerId, ids: [Int32]) -> Signal<[Stories.StoredItem], NoError> {
    return postbox.transaction { transaction -> Api.InputUser? in
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<[Stories.StoredItem], NoError> in
        guard let inputUser = inputUser else {
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
                    var peers: [Peer] = []
                    var peerPresences: [PeerId: Api.User] = [:]
                    
                    for user in users {
                        let telegramUser = TelegramUser(user: user)
                        peers.append(telegramUser)
                        peerPresences[telegramUser.id] = user
                    }
                    
                    updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                        return updated
                    })
                    updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                    
                    return stories.compactMap { apiStoryItem -> Stories.StoredItem? in
                        return Stories.StoredItem(apiStoryItem: apiStoryItem, peerId: peerId, transaction: transaction)
                    }
                }
            }
        }
    }
}

func _internal_getStoryById(accountPeerId: PeerId, postbox: Postbox, network: Network, peer: PeerReference, id: Int32) -> Signal<StoryListContext.Item?, NoError> {
    guard let inputUser = peer.inputUser else {
        return .single(nil)
    }
    return network.request(Api.functions.stories.getStoriesByID(userId: inputUser, id: [id]))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<StoryListContext.Item?, NoError> in
        guard let result = result else {
            return .single(nil)
        }
        return postbox.transaction { transaction -> StoryListContext.Item? in
            switch result {
            case let .stories(_, stories, users):
                var peers: [Peer] = []
                var peerPresences: [PeerId: Api.User] = [:]
                
                for user in users {
                    let telegramUser = TelegramUser(user: user)
                    peers.append(telegramUser)
                    peerPresences[telegramUser.id] = user
                }
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
                
                return stories.first.flatMap { _internal_parseApiStoryItem(transaction: transaction, peerId: peer.id, apiStory: $0) }
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
                var peers: [Peer] = []
                var peerPresences: [PeerId: Api.User] = [:]
                
                for user in users {
                    let telegramUser = TelegramUser(user: user)
                    peers.append(telegramUser)
                    peerPresences[telegramUser.id] = user
                }
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                
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

func _internal_getStoryViews(account: Account, ids: [Int32]) -> Signal<[Int32: StoryListContext.Views], NoError> {
    return account.network.request(Api.functions.stories.getStoriesViews(id: ids))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.stories.StoryViews?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<[Int32: StoryListContext.Views], NoError> in
        guard let result = result else {
            return .single([:])
        }
        return account.postbox.transaction { transaction -> [Int32: StoryListContext.Views] in
            var parsedViews: [Int32: StoryListContext.Views] = [:]
            switch result {
            case let .storyViews(views, users):
                var peers: [Peer] = []
                var peerPresences: [PeerId: Api.User] = [:]
                
                for user in users {
                    let telegramUser = TelegramUser(user: user)
                    peers.append(telegramUser)
                    peerPresences[telegramUser.id] = user
                }
                
                updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                    return updated
                })
                updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                
                for i in 0 ..< views.count {
                    if i < ids.count {
                        parsedViews[ids[i]] = _internal_parseApiStoryViews(transaction: transaction, views: views[i])
                    }
                }
            }
            
            return parsedViews
        }
    }
}
