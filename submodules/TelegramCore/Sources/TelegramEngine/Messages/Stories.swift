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
                TelegramMediaFileAttribute.Video(duration: duration, size: dimensions, flags: .supportsStreaming)
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
                                    case let .userStories(_, userId, _, apiStories, _):
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
        return transaction.getPeer(peerId).flatMap(apiInputUser)
    }
    |> mapToSignal { inputUser -> Signal<Never, NoError> in
        guard let inputUser = inputUser else {
            return .complete()
        }
        
        account.stateManager.injectStoryUpdates(updates: [.read(peerId: peerId, maxId: id)])
        
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
