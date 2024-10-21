import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit
import MtProtoKit

enum InternalStoryUpdate {
    case deleted(peerId: PeerId, id: Int32)
    case added(peerId: PeerId, item: Stories.StoredItem)
    case read(peerId: PeerId, maxId: Int32)
    case updatePinnedToTopList(peerId: PeerId, ids: [Int32])
    case updateMyReaction(peerId: PeerId, id: Int32, reaction: MessageReaction.Reaction?)
}

enum InternalBotPreviewUpdate {
    case added(peerId: PeerId, language: String?, item: CachedUserData.BotPreview.Item)
    case deleted(peerId: PeerId, language: String?, ids: [MediaId])
}

public final class EngineStoryItem: Equatable {
    public final class Views: Equatable {
        public let seenCount: Int
        public let reactedCount: Int
        public var forwardCount: Int
        public let seenPeers: [EnginePeer]
        public let reactions: [MessageReaction]
        public let hasList: Bool
        
        public init(seenCount: Int, reactedCount: Int, forwardCount: Int, seenPeers: [EnginePeer], reactions: [MessageReaction], hasList: Bool) {
            self.seenCount = seenCount
            self.reactedCount = reactedCount
            self.forwardCount = forwardCount
            self.seenPeers = seenPeers
            self.reactions = reactions
            self.hasList = hasList
        }
        
        public static func ==(lhs: Views, rhs: Views) -> Bool {
            if lhs.seenCount != rhs.seenCount {
                return false
            }
            if lhs.reactedCount != rhs.reactedCount {
                return false
            }
            if lhs.forwardCount != rhs.forwardCount {
                return false
            }
            if lhs.seenPeers != rhs.seenPeers {
                return false
            }
            if lhs.reactions != rhs.reactions {
                return false
            }
            if lhs.hasList != rhs.hasList {
                return false
            }
            return true
        }
    }
    
    public enum ForwardInfo: Equatable {
        case known(peer: EnginePeer, storyId: Int32, isModified: Bool)
        case unknown(name: String, isModified: Bool)
    }
    
    public let id: Int32
    public let timestamp: Int32
    public let expirationTimestamp: Int32
    public let media: EngineMedia
    public let alternativeMediaList: [EngineMedia]
    public let mediaAreas: [MediaArea]
    public let text: String
    public let entities: [MessageTextEntity]
    public let views: Views?
    public let privacy: EngineStoryPrivacy?
    public let isPinned: Bool
    public let isExpired: Bool
    public let isPublic: Bool
    public let isPending: Bool
    public let isCloseFriends: Bool
    public let isContacts: Bool
    public let isSelectedContacts: Bool
    public let isForwardingDisabled: Bool
    public let isEdited: Bool
    public let isMy: Bool
    public let myReaction: MessageReaction.Reaction?
    public let forwardInfo: ForwardInfo?
    public let author: EnginePeer?
    
    public init(id: Int32, timestamp: Int32, expirationTimestamp: Int32, media: EngineMedia, alternativeMediaList: [EngineMedia], mediaAreas: [MediaArea], text: String, entities: [MessageTextEntity], views: Views?, privacy: EngineStoryPrivacy?, isPinned: Bool, isExpired: Bool, isPublic: Bool, isPending: Bool, isCloseFriends: Bool, isContacts: Bool, isSelectedContacts: Bool, isForwardingDisabled: Bool, isEdited: Bool, isMy: Bool, myReaction: MessageReaction.Reaction?, forwardInfo: ForwardInfo?, author: EnginePeer?) {
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
        self.isPending = isPending
        self.isCloseFriends = isCloseFriends
        self.isContacts = isContacts
        self.isSelectedContacts = isSelectedContacts
        self.isForwardingDisabled = isForwardingDisabled
        self.isEdited = isEdited
        self.isMy = isMy
        self.myReaction = myReaction
        self.forwardInfo = forwardInfo
        self.author = author
    }
    
    public static func ==(lhs: EngineStoryItem, rhs: EngineStoryItem) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.timestamp != rhs.timestamp {
            return false
        }
        if lhs.expirationTimestamp != rhs.expirationTimestamp {
            return false
        }
        if lhs.media != rhs.media {
            return false
        }
        if lhs.alternativeMediaList != rhs.alternativeMediaList {
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
        if lhs.isPending != rhs.isPending {
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
        if lhs.isMy != rhs.isMy {
            return false
        }
        if lhs.myReaction != rhs.myReaction {
            return false
        }
        if lhs.forwardInfo != rhs.forwardInfo {
            return false
        }
        if lhs.author != rhs.author {
            return false
        }
        return true
    }
}

extension EngineStoryItem.ForwardInfo {
    var storedForwardInfo: Stories.Item.ForwardInfo {
        switch self {
        case let .known(peer, storyId, isModified):
            return .known(peerId: peer.id, storyId: storyId, isModified: isModified)
        case let .unknown(name, isModified):
            return .unknown(name: name, isModified: isModified)
        }
    }
}

public extension EngineStoryItem {
    func asStoryItem() -> Stories.Item {
        return Stories.Item(
            id: self.id,
            timestamp: self.timestamp,
            expirationTimestamp: self.expirationTimestamp,
            media: self.media._asMedia(),
            alternativeMediaList: self.alternativeMediaList.map { $0._asMedia() },
            mediaAreas: self.mediaAreas,
            text: self.text,
            entities: self.entities,
            views: self.views.flatMap { views in
                return Stories.Item.Views(
                    seenCount: views.seenCount,
                    reactedCount: views.reactedCount,
                    forwardCount: views.forwardCount,
                    seenPeerIds: views.seenPeers.map(\.id),
                    reactions: views.reactions,
                    hasList: views.hasList
                )
            },
            privacy: self.privacy.flatMap { privacy in
                return Stories.Item.Privacy(
                    base: privacy.base,
                    additionallyIncludePeers: privacy.additionallyIncludePeers
                )
            },
            isPinned: self.isPinned,
            isExpired: self.isExpired,
            isPublic: self.isPublic,
            isCloseFriends: self.isCloseFriends,
            isContacts: self.isContacts,
            isSelectedContacts: self.isSelectedContacts,
            isForwardingDisabled: self.isForwardingDisabled,
            isEdited: self.isEdited,
            isMy: self.isMy,
            
            myReaction: self.myReaction,
            forwardInfo: self.forwardInfo?.storedForwardInfo,
            authorId: self.author?.id
        )
    }
}

public final class StorySubscriptionsContext {
    private enum OpaqueStateMark: Equatable {
        case empty
        case value(String)
    }
    
    private struct TaskState {
        var isRefreshScheduled: Bool = false
        var isLoadMoreScheduled: Bool = false
    }
    
    private final class Impl {
        private let accountPeerId: PeerId
        private let queue: Queue
        private let postbox: Postbox
        private let network: Network
        private let isHidden: Bool
        
        private var taskState = TaskState()
        
        private var isLoading: Bool = false
        
        private var loadedStateMark: OpaqueStateMark?
        private var stateDisposable: Disposable?
        private let loadMoreDisposable = MetaDisposable()
        private let refreshTimerDisposable = MetaDisposable()
        
        init(queue: Queue, accountPeerId: PeerId, postbox: Postbox, network: Network, isHidden: Bool) {
            self.accountPeerId = accountPeerId
            self.queue = queue
            self.postbox = postbox
            self.network = network
            self.isHidden = isHidden
            
            self.taskState.isRefreshScheduled = true
            
            self.updateTasks()
        }
        
        deinit {
            self.stateDisposable?.dispose()
            self.loadMoreDisposable.dispose()
            self.refreshTimerDisposable.dispose()
        }
        
        func loadMore() {
            self.taskState.isLoadMoreScheduled = true
            self.updateTasks()
        }
        
        private func updateTasks() {
            if self.isLoading {
                return
            }
            
            let subscriptionsKey: PostboxStorySubscriptionsKey = self.isHidden ? .hidden : .filtered
            
            if self.taskState.isRefreshScheduled {
                self.isLoading = true
                
                self.stateDisposable = (postbox.combinedView(keys: [PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))])
                |> take(1)
                |> deliverOn(self.queue)).start(next: { [weak self] views in
                    guard let `self` = self else {
                        return
                    }
                    guard let storiesStateView = views.views[PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))] as? StoryStatesView else {
                        return
                    }
                    
                    let stateMark: OpaqueStateMark
                    if let subscriptionsState = storiesStateView.value?.get(Stories.SubscriptionsState.self) {
                        stateMark = .value(subscriptionsState.opaqueState)
                    } else {
                        stateMark = .empty
                    }
                    
                    self.loadImpl(isRefresh: true, stateMark: stateMark)
                })
            } else if self.taskState.isLoadMoreScheduled {
                self.isLoading = true
                
                self.stateDisposable = (postbox.combinedView(keys: [PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))])
                |> take(1)
                |> deliverOn(self.queue)).start(next: { [weak self] views in
                    guard let `self` = self else {
                        return
                    }
                    guard let storiesStateView = views.views[PostboxViewKey.storiesState(key: .subscriptions(subscriptionsKey))] as? StoryStatesView else {
                        return
                    }
                    
                    let hasMore: Bool
                    let stateMark: OpaqueStateMark
                    if let subscriptionsState = storiesStateView.value?.get(Stories.SubscriptionsState.self) {
                        hasMore = subscriptionsState.hasMore
                        stateMark = .value(subscriptionsState.opaqueState)
                    } else {
                        stateMark = .empty
                        hasMore = true
                    }
                    
                    if hasMore && self.loadedStateMark != stateMark {
                        self.loadImpl(isRefresh: false, stateMark: stateMark)
                    } else {
                        self.isLoading = false
                        self.taskState.isLoadMoreScheduled = false
                        self.updateTasks()
                    }
                })
            }
        }
        
        private func loadImpl(isRefresh: Bool, stateMark: OpaqueStateMark) {
            var flags: Int32 = 0
            
            if self.isHidden {
                flags |= 1 << 2
            }
            
            var state: String?
            switch stateMark {
            case .empty:
                break
            case let .value(value):
                state = value
                flags |= 1 << 0
                
                if !isRefresh {
                    flags |= 1 << 1
                } else {
                    #if DEBUG
                    if "".isEmpty {
                        state = nil
                        flags &= ~(1 << 0)
                    }
                    #endif
                }
            }
            
            let accountPeerId = self.accountPeerId
            
            let isHidden = self.isHidden
            let subscriptionsKey: PostboxStorySubscriptionsKey = self.isHidden ? .hidden : .filtered
            
            self.loadMoreDisposable.set((self.network.request(Api.functions.stories.getAllStories(flags: flags, state: state))
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let `self` = self else {
                    return
                }
                
                let _ = (self.postbox.transaction { transaction -> Void in
                    var updatedStealthMode: Api.StoriesStealthMode?
                    switch result {
                    case let .allStoriesNotModified(_, state, stealthMode):
                        self.loadedStateMark = .value(state)
                        let (currentStateValue, _) = transaction.getAllStorySubscriptions(key: subscriptionsKey)
                        let currentState = currentStateValue.flatMap { $0.get(Stories.SubscriptionsState.self) }
                        
                        var hasMore = false
                        if let currentState = currentState {
                            hasMore = currentState.hasMore
                        }
                        
                        transaction.setSubscriptionsStoriesState(key: subscriptionsKey, state: CodableEntry(Stories.SubscriptionsState(
                            opaqueState: state,
                            refreshId: currentState?.refreshId ?? UInt64.random(in: 0 ... UInt64.max),
                            hasMore: hasMore
                        )))
                        
                        if isRefresh && !isHidden {
                            updatedStealthMode = stealthMode
                        }
                    case let .allStories(flags, _, state, peerStories, chats, users, stealthMode):
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        
                        let hasMore: Bool = (flags & (1 << 0)) != 0
                        
                        let (_, currentPeerItems) = transaction.getAllStorySubscriptions(key: subscriptionsKey)
                        var peerEntries: [PeerId] = []
                        
                        for peerStorySet in peerStories {
                            switch peerStorySet {
                            case let .peerStories(_, peerIdValue, maxReadId, stories):
                                let peerId = peerIdValue.peerId
                                
                                let previousPeerEntries: [StoryItemsTableEntry] = transaction.getStoryItems(peerId: peerId)
                                
                                var updatedPeerEntries: [StoryItemsTableEntry] = []
                                for story in stories {
                                    if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peerId, transaction: transaction) {
                                        if case .placeholder = storedItem, let previousEntry = previousPeerEntries.first(where: { $0.id == storedItem.id }) {
                                            updatedPeerEntries.append(previousEntry)
                                        } else {
                                            if let codedEntry = CodableEntry(storedItem) {
                                                updatedPeerEntries.append(StoryItemsTableEntry(value: codedEntry, id: storedItem.id, expirationTimestamp: storedItem.expirationTimestamp, isCloseFriends: storedItem.isCloseFriends))
                                            }
                                        }
                                    }
                                }
                                
                                peerEntries.append(peerId)
                                
                                transaction.setStoryItems(peerId: peerId, items: updatedPeerEntries)
                                transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(
                                    maxReadId: maxReadId ?? 0
                                ).postboxRepresentation)
                            }
                        }
                        
                        if isRefresh {
                            if !isHidden {
                                if !peerEntries.contains(where: { $0 == accountPeerId }) {
                                    transaction.setStoryItems(peerId: accountPeerId, items: [])
                                }
                            }
                        } else {
                            let leftPeerIds = currentPeerItems.filter({ !peerEntries.contains($0) })
                            if !leftPeerIds.isEmpty {
                                peerEntries = leftPeerIds + peerEntries
                            }
                        }
                        
                        if isRefresh && !isHidden {
                            updatedStealthMode = stealthMode
                        }
                        
                        transaction.replaceAllStorySubscriptions(key: subscriptionsKey, state: CodableEntry(Stories.SubscriptionsState(
                            opaqueState: state,
                            refreshId: UInt64.random(in: 0 ... UInt64.max),
                            hasMore: hasMore
                        )), peerIds: peerEntries)
                        
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                    }
                    
                    if let updatedStealthMode = updatedStealthMode {
                        var configuration = _internal_getStoryConfigurationState(transaction: transaction)
                        configuration.stealthModeState = Stories.StealthModeState(apiMode: updatedStealthMode)
                        _internal_setStoryConfigurationState(transaction: transaction, state: configuration)
                    }
                }
                |> deliverOn(self.queue)).start(completed: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    
                    self.isLoading = false
                    if isRefresh {
                        self.taskState.isRefreshScheduled = false
                        self.refreshTimerDisposable.set((Signal<Never, NoError>.complete()
                        |> suspendAwareDelay(60.0, queue: self.queue)).start(completed: { [weak self] in
                            guard let `self` = self else {
                                return
                            }
                            self.taskState.isRefreshScheduled = true
                            self.updateTasks()
                        }))
                    } else {
                        self.taskState.isLoadMoreScheduled = false
                    }
                    
                    self.updateTasks()
                })
            }))
        }
    }
    
    private let queue = Queue(name: "StorySubscriptionsContext")
    private let impl: QueueLocalObject<Impl>
    
    init(accountPeerId: PeerId, postbox: Postbox, network: Network, isHidden: Bool) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            Impl(queue: queue, accountPeerId: accountPeerId, postbox: postbox, network: network, isHidden: isHidden)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
}

private final class CachedPeerStoryListHead: Codable {
    let items: [Stories.StoredItem]
    let pinnedIds: [Int32]
    let totalCount: Int32
    
    init(items: [Stories.StoredItem], pinnedIds: [Int32], totalCount: Int32) {
        self.items = items
        self.pinnedIds = pinnedIds
        self.totalCount = totalCount
    }
}

public struct StoryListContextState: Equatable {
    public final class Item: Equatable {
        public let id: StoryId
        public let storyItem: EngineStoryItem
        public let peer: EnginePeer?
        
        public init(id: StoryId, storyItem: EngineStoryItem, peer: EnginePeer?) {
            self.id = id
            self.storyItem = storyItem
            self.peer = peer
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.id != rhs.id {
                return false
            }
            if lhs.storyItem != rhs.storyItem {
                return false
            }
            if lhs.peer != rhs.peer {
                return false
            }
            return true
        }
    }
    
    public struct Language: Equatable {
        public let id: String
        public let name: String
        
        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }
    
    public var peerReference: PeerReference?
    public var items: [Item]
    public var availableLanguages: [Language]
    public var pinnedIds: [Int32]
    public var totalCount: Int
    public var loadMoreToken: AnyHashable?
    public var isCached: Bool
    public var hasCache: Bool
    public var allEntityFiles: [MediaId: TelegramMediaFile]
    public var isLoading: Bool
    public init(
        peerReference: PeerReference?,
        items: [Item],
        availableLanguages: [Language],
        pinnedIds: [Int32],
        totalCount: Int,
        loadMoreToken: AnyHashable?,
        isCached: Bool,
        hasCache: Bool,
        allEntityFiles: [MediaId: TelegramMediaFile],
        isLoading: Bool
    ) {
        self.peerReference = peerReference
        self.items = items
        self.availableLanguages = availableLanguages
        self.pinnedIds = pinnedIds
        self.totalCount = totalCount
        self.loadMoreToken = loadMoreToken
        self.isCached = isCached
        self.hasCache = hasCache
        self.allEntityFiles = allEntityFiles
        self.isLoading = isLoading
    }
}

public protocol StoryListContext: AnyObject {
    typealias State = StoryListContextState
    
    var state: Signal<State, NoError> { get }
    
    func loadMore(completion: (() -> Void)?)
}

public final class PeerStoryListContext: StoryListContext {
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let peerId: EnginePeer.Id
        private let isArchived: Bool
        
        private let statePromise = Promise<State>()
        private var stateValue: State {
            didSet {
                self.statePromise.set(.single(self.stateValue))
            }
        }
        var state: Signal<State, NoError> {
            return self.statePromise.get()
        }
        
        private var isLoadingMore: Bool = false
        private var requestDisposable: Disposable?
        
        private var updatesDisposable: Disposable?
        
        private var completionCallbacksByToken: [AnyHashable: [() -> Void]] = [:]
        
        init(queue: Queue, account: Account, peerId: EnginePeer.Id, isArchived: Bool) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.isArchived = isArchived
            
            self.stateValue = State(peerReference: nil, items: [], availableLanguages: [], pinnedIds: [], totalCount: 0, loadMoreToken: AnyHashable(0 as Int), isCached: true, hasCache: false, allEntityFiles: [:], isLoading: false)
            
            let _ = (account.postbox.transaction { transaction -> (PeerReference?, [State.Item], [Int32], Int, [MediaId: TelegramMediaFile], Bool) in
                let key = ValueBoxKey(length: 8 + 1)
                key.setInt64(0, value: peerId.toInt64())
                key.setInt8(8, value: isArchived ? 1 : 0)
                let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))?.get(CachedPeerStoryListHead.self)
                guard let cached = cached else {
                    return (nil, [], [], 0, [:], false)
                }
                var items: [State.Item] = []
                var allEntityFiles: [MediaId: TelegramMediaFile] = [:]
                for storedItem in cached.items {
                    if case let .item(item) = storedItem, let media = item.media {
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
                            author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) }
                        )
                        items.append(State.Item(
                            id: StoryId(peerId: peerId, id: mappedItem.id),
                            storyItem: mappedItem,
                            peer: nil
                        ))
                        
                        for entity in mappedItem.entities {
                            if case let .CustomEmoji(_, fileId) = entity.type {
                                let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                if allEntityFiles[mediaId] == nil {
                                    if let file = transaction.getMedia(mediaId) as? TelegramMediaFile {
                                        allEntityFiles[file.fileId] = file
                                    }
                                }
                            }
                        }
                        for mediaArea in mappedItem.mediaAreas {
                            if case let .reaction(_, reaction, _) = mediaArea {
                                if case let .custom(fileId) = reaction {
                                    let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                    if allEntityFiles[mediaId] == nil {
                                        if let file = transaction.getMedia(mediaId) as? TelegramMediaFile {
                                            allEntityFiles[file.fileId] = file
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                let peerReference = transaction.getPeer(peerId).flatMap(PeerReference.init)
                
                return (peerReference, items, cached.pinnedIds, Int(cached.totalCount), allEntityFiles, true)
            }
            |> deliverOn(self.queue)).start(next: { [weak self] peerReference, items, pinnedIds, totalCount, allEntityFiles, hasCache in
                guard let `self` = self else {
                    return
                }
                
                var updatedState = State(peerReference: peerReference, items: items, availableLanguages: [], pinnedIds: pinnedIds, totalCount: totalCount, loadMoreToken: AnyHashable(0 as Int), isCached: true, hasCache: hasCache, allEntityFiles: allEntityFiles, isLoading: false)
                updatedState.items.sort(by: { lhs, rhs in
                    let lhsPinned = updatedState.pinnedIds.firstIndex(of: lhs.storyItem.id)
                    let rhsPinned = updatedState.pinnedIds.firstIndex(of: rhs.storyItem.id)
                    
                    if let lhsPinned, let rhsPinned {
                        if lhsPinned != rhsPinned {
                            return lhsPinned < rhsPinned
                        }
                    } else if (lhsPinned == nil) != (rhsPinned == nil) {
                        return lhsPinned != nil
                    }
                    
                    return lhs.storyItem.timestamp > rhs.storyItem.timestamp
                })
                self.stateValue = updatedState
                
                self.loadMore(completion: nil)
            })
        }
        
        deinit {
            self.requestDisposable?.dispose()
            self.updatesDisposable?.dispose()
        }
        
        func loadMore(completion: (() -> Void)?) {
            guard let loadMoreTokenValue = self.stateValue.loadMoreToken, let loadMoreToken = loadMoreTokenValue.base as? Int else {
                return
            }
            
            if let completion = completion {
                if self.completionCallbacksByToken[loadMoreToken] == nil {
                    self.completionCallbacksByToken[loadMoreToken] = []
                }
                self.completionCallbacksByToken[loadMoreToken]?.append(completion)
            }
            
            if self.isLoadingMore {
                return
            }
            
            self.isLoadingMore = true
            
            let limit = 100
            
            let peerId = self.peerId
            let account = self.account
            let accountPeerId = account.peerId
            let isArchived = self.isArchived
            self.requestDisposable = (self.account.postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(peerId).flatMap(apiInputPeer)
            }
            |> mapToSignal { inputPeer -> Signal<([State.Item], Int, PeerReference?, Bool), NoError> in
                guard let inputPeer = inputPeer else {
                    return .single(([], 0, nil, false))
                }
                
                let signal: Signal<Api.stories.Stories, MTRpcError>
                if isArchived {
                    signal = account.network.request(Api.functions.stories.getStoriesArchive(peer: inputPeer, offsetId: Int32(loadMoreToken), limit: Int32(limit)))
                } else {
                    signal = account.network.request(Api.functions.stories.getPinnedStories(peer: inputPeer, offsetId: Int32(loadMoreToken), limit: Int32(limit)))
                }
                return signal
                |> map { result -> Api.stories.Stories? in
                    return result
                }
                |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([State.Item], Int, PeerReference?, Bool), NoError> in
                    guard let result = result else {
                        return .single(([], 0, nil, false))
                    }
                    
                    return account.postbox.transaction { transaction -> ([State.Item], Int, PeerReference?, Bool) in
                        var storyItems: [State.Item] = []
                        var totalCount: Int = 0
                        var hasMore: Bool = false
                        
                        switch result {
                        case let .stories(_, count, stories, pinnedStories, chats, users):
                            totalCount = Int(count)
                            hasMore = stories.count >= limit
                            
                            let pinnedIds = pinnedStories ?? []
                            
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: users))
                            
                            for story in stories {
                                if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peerId, transaction: transaction) {
                                    if case let .item(item) = storedItem, let media = item.media {
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
                                            author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) }
                                        )
                                        storyItems.append(State.Item(
                                            id: StoryId(peerId: peerId, id: mappedItem.id),
                                            storyItem: mappedItem,
                                            peer: nil
                                        ))
                                    }
                                }
                            }
                            
                            if loadMoreToken == 0 {
                                let key = ValueBoxKey(length: 8 + 1)
                                key.setInt64(0, value: peerId.toInt64())
                                key.setInt8(8, value: isArchived ? 1 : 0)
                                if let entry = CodableEntry(CachedPeerStoryListHead(items: storyItems.prefix(100).map { .item($0.storyItem.asStoryItem()) }, pinnedIds: pinnedIds, totalCount: count)) {
                                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key), entry: entry)
                                }
                            }
                        }
                        
                        return (storyItems, totalCount, transaction.getPeer(peerId).flatMap(PeerReference.init), hasMore)
                    }
                }
            }
            |> deliverOn(self.queue)).start(next: { [weak self] storyItems, totalCount, peerReference, hasMore in
                guard let self else {
                    return
                }
                
                self.isLoadingMore = false
                
                var updatedState = self.stateValue
                if updatedState.isCached {
                    updatedState.items.removeAll()
                    updatedState.isCached = false
                }
                updatedState.hasCache = true
                
                var existingIds = Set(updatedState.items.map { $0.storyItem.id })
                for item in storyItems {
                    if existingIds.contains(item.storyItem.id) {
                        continue
                    }
                    existingIds.insert(item.storyItem.id)
                    
                    updatedState.items.append(item)
                }
                
                if updatedState.peerReference == nil {
                    updatedState.peerReference = peerReference
                }
                
                if hasMore {
                    updatedState.loadMoreToken = (storyItems.last?.storyItem.id).flatMap(Int.init).flatMap({ AnyHashable($0) })
                } else {
                    updatedState.loadMoreToken = nil
                }
                if updatedState.loadMoreToken != nil {
                    updatedState.totalCount = max(totalCount, updatedState.items.count)
                } else {
                    updatedState.totalCount = updatedState.items.count
                }
                self.stateValue = updatedState
                
                if let callbacks = self.completionCallbacksByToken.removeValue(forKey: AnyHashable(loadMoreToken)) {
                    for f in callbacks {
                        f()
                    }
                }
                
                if self.updatesDisposable == nil {
                    self.updatesDisposable = (self.account.stateManager.storyUpdates
                    |> deliverOn(self.queue)).start(next: { [weak self] updates in
                        guard let `self` = self else {
                            return
                        }
                        let selfPeerId = self.peerId
                        let _ = (self.account.postbox.transaction { transaction -> [PeerId: Peer] in
                            var peers: [PeerId: Peer] = [:]
                            
                            for update in updates {
                                switch update {
                                case let .added(peerId, item):
                                    if selfPeerId == peerId {
                                        if case let .item(item) = item {
                                            if let views = item.views {
                                                for id in views.seenPeerIds {
                                                    if let peer = transaction.getPeer(id) {
                                                        peers[peer.id] = peer
                                                    }
                                                }
                                            }
                                            if let forwardInfo = item.forwardInfo, case let .known(peerId, _, _) = forwardInfo {
                                                if let peer = transaction.getPeer(peerId) {
                                                    peers[peer.id] = peer
                                                }
                                            }
                                            if let peerId = item.authorId {
                                                if let peer = transaction.getPeer(peerId) {
                                                    peers[peer.id] = peer
                                                }
                                            }
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                            
                            return peers
                        }
                        |> deliverOn(self.queue)).start(next: { [weak self] peers in
                            guard let self else {
                                return
                            }
                            
                            var finalUpdatedState: State?
                            finalUpdatedState = nil
                            let _ = finalUpdatedState
                            
                            for update in updates {
                                switch update {
                                case let .deleted(peerId, id):
                                    if self.peerId == peerId {
                                        if let index = (finalUpdatedState ?? self.stateValue).items.firstIndex(where: { $0.storyItem.id == id }) {
                                            var updatedState = finalUpdatedState ?? self.stateValue
                                            updatedState.items.remove(at: index)
                                            updatedState.totalCount = max(0, updatedState.totalCount - 1)
                                            finalUpdatedState = updatedState
                                        }
                                    }
                                case let .added(peerId, item):
                                    if self.peerId == peerId {
                                        if let index = (finalUpdatedState ?? self.stateValue).items.firstIndex(where: { $0.storyItem.id == item.id }) {
                                            if !self.isArchived {
                                                if case let .item(item) = item {
                                                    if item.isPinned {
                                                        if let media = item.media {
                                                            var updatedState = finalUpdatedState ?? self.stateValue
                                                            updatedState.items[index] = State.Item(id: StoryId(peerId: peerId, id: item.id), storyItem: EngineStoryItem(
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
                                                                            return peers[id].flatMap(EnginePeer.init)
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
                                                                forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, peers: peers) },
                                                                author: item.authorId.flatMap { peers[$0].flatMap(EnginePeer.init) }
                                                            ), peer: nil)
                                                            finalUpdatedState = updatedState
                                                        }
                                                    } else {
                                                        var updatedState = finalUpdatedState ?? self.stateValue
                                                        updatedState.items.remove(at: index)
                                                        updatedState.totalCount = max(0, updatedState.totalCount - 1)
                                                        finalUpdatedState = updatedState
                                                    }
                                                }
                                            } else {
                                                if case let .item(item) = item {
                                                    if let media = item.media {
                                                        var updatedState = finalUpdatedState ?? self.stateValue
                                                        updatedState.items[index] = State.Item(id: StoryId(peerId: peerId, id: item.id), storyItem: EngineStoryItem(
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
                                                                        return peers[id].flatMap(EnginePeer.init)
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
                                                            forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, peers: peers) },
                                                            author: item.authorId.flatMap { peers[$0].flatMap(EnginePeer.init) }
                                                        ), peer: nil)
                                                        finalUpdatedState = updatedState
                                                    } else {
                                                        var updatedState = finalUpdatedState ?? self.stateValue
                                                        updatedState.items.remove(at: index)
                                                        updatedState.totalCount = max(0, updatedState.totalCount - 1)
                                                        finalUpdatedState = updatedState
                                                    }
                                                }
                                            }
                                        } else {
                                            if !self.isArchived {
                                                if case let .item(item) = item {
                                                    if item.isPinned {
                                                        if let media = item.media {
                                                            var updatedState = finalUpdatedState ?? self.stateValue
                                                            updatedState.items.append(State.Item(id: StoryId(peerId: peerId, id: item.id), storyItem: EngineStoryItem(
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
                                                                            return peers[id].flatMap(EnginePeer.init)
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
                                                                forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, peers: peers) },
                                                                author: item.authorId.flatMap { peers[$0].flatMap(EnginePeer.init) }
                                                            ), peer: nil))
                                                            updatedState.items.sort(by: { lhs, rhs in
                                                                let lhsPinned = updatedState.pinnedIds.firstIndex(of: lhs.storyItem.id)
                                                                let rhsPinned = updatedState.pinnedIds.firstIndex(of: rhs.storyItem.id)
                                                                
                                                                if let lhsPinned, let rhsPinned {
                                                                    if lhsPinned != rhsPinned {
                                                                        return lhsPinned < rhsPinned
                                                                    }
                                                                } else if (lhsPinned == nil) != (rhsPinned == nil) {
                                                                    return lhsPinned != nil
                                                                }
                                                                return lhs.storyItem.timestamp > rhs.storyItem.timestamp
                                                            })
                                                            finalUpdatedState = updatedState
                                                        }
                                                    }
                                                }
                                            } else {
                                                if case let .item(item) = item {
                                                    if let media = item.media {
                                                        var updatedState = finalUpdatedState ?? self.stateValue
                                                        updatedState.items.append(State.Item(id: StoryId(peerId: peerId, id: item.id), storyItem: EngineStoryItem(
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
                                                                        return peers[id].flatMap(EnginePeer.init)
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
                                                            forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, peers: peers) },
                                                            author: item.authorId.flatMap { peers[$0].flatMap(EnginePeer.init) }
                                                        ), peer: nil))
                                                        updatedState.items.sort(by: { lhs, rhs in
                                                            let lhsPinned = updatedState.pinnedIds.firstIndex(of: lhs.storyItem.id)
                                                            let rhsPinned = updatedState.pinnedIds.firstIndex(of: rhs.storyItem.id)
                                                            
                                                            if let lhsPinned, let rhsPinned {
                                                                if lhsPinned != rhsPinned {
                                                                    return lhsPinned < rhsPinned
                                                                }
                                                            } else if (lhsPinned == nil) != (rhsPinned == nil) {
                                                                return lhsPinned != nil
                                                            }
                                                            return lhs.storyItem.timestamp > rhs.storyItem.timestamp
                                                        })
                                                        finalUpdatedState = updatedState
                                                    }
                                                }
                                            }
                                        }
                                    }
                                case .read:
                                    break
                                case .updateMyReaction:
                                    break
                                case let .updatePinnedToTopList(peerId, ids):
                                    if self.peerId == peerId && !self.isArchived {
                                        let previousIds = (finalUpdatedState ?? self.stateValue).pinnedIds
                                        if previousIds != ids {
                                            var updatedState = finalUpdatedState ?? self.stateValue
                                            updatedState.pinnedIds = ids
                                            updatedState.items.sort(by: { lhs, rhs in
                                                let lhsPinned = updatedState.pinnedIds.firstIndex(of: lhs.storyItem.id)
                                                let rhsPinned = updatedState.pinnedIds.firstIndex(of: rhs.storyItem.id)
                                                
                                                if let lhsPinned, let rhsPinned {
                                                    if lhsPinned != rhsPinned {
                                                        return lhsPinned < rhsPinned
                                                    }
                                                } else if (lhsPinned == nil) != (rhsPinned == nil) {
                                                    return lhsPinned != nil
                                                }
                                                return lhs.storyItem.timestamp > rhs.storyItem.timestamp
                                            })
                                            finalUpdatedState = updatedState
                                        }
                                    }
                                }
                            }
                            
                            if let finalUpdatedState = finalUpdatedState {
                                self.stateValue = finalUpdatedState
                                
                                let items = finalUpdatedState.items
                                let pinnedIds = finalUpdatedState.pinnedIds
                                let totalCount = finalUpdatedState.totalCount
                                let _ = (self.account.postbox.transaction { transaction -> Void in
                                    let key = ValueBoxKey(length: 8 + 1)
                                    key.setInt64(0, value: peerId.toInt64())
                                    key.setInt8(8, value: isArchived ? 1 : 0)
                                    if let entry = CodableEntry(CachedPeerStoryListHead(items: items.prefix(100).map { .item($0.storyItem.asStoryItem()) }, pinnedIds: pinnedIds, totalCount: Int32(totalCount))) {
                                        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key), entry: entry)
                                    }
                                }).start()
                            }
                        })
                    })
                }
            })
        }
    }
    
    public var state: Signal<State, NoError> {
        return impl.signalWith { impl, subscriber in
            return impl.state.start(next: subscriber.putNext)
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public init(account: Account, peerId: EnginePeer.Id, isArchived: Bool) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId, isArchived: isArchived)
        })
    }
    
    public func loadMore(completion: (() -> Void)? = nil) {
        self.impl.with { impl in
            impl.loadMore(completion : completion)
        }
    }
}

public final class SearchStoryListContext: StoryListContext {
    public enum Source {
        case hashtag(EnginePeer.Id?, String)
        case mediaArea(MediaArea)
    }
    
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let source: Source
        
        private let statePromise = Promise<State>()
        private var stateValue: State {
            didSet {
                self.statePromise.set(.single(self.stateValue))
            }
        }
        var state: Signal<State, NoError> {
            return self.statePromise.get()
        }
        
        private var isLoadingMore: Bool = false {
            didSet {
                self.stateValue.isLoading = isLoadingMore
            }
        }
        private var requestDisposable: Disposable?
        
        private var updatesDisposable: Disposable?
        
        private var completionCallbacksByToken: [AnyHashable: [() -> Void]] = [:]
        
        init(queue: Queue, account: Account, source: Source) {
            self.queue = queue
            self.account = account
            self.source = source
            
            self.stateValue = State(peerReference: nil, items: [], availableLanguages: [], pinnedIds: [], totalCount: 0, loadMoreToken: AnyHashable(""), isCached: false, hasCache: false, allEntityFiles: [:], isLoading: false)
            self.statePromise.set(.single(self.stateValue))
                
            self.loadMore(completion: nil)
        }
        
        deinit {
            self.requestDisposable?.dispose()
        }
        
        func loadMore(completion: (() -> Void)?) {
            guard let loadMoreTokenValue = self.stateValue.loadMoreToken, let loadMoreToken = loadMoreTokenValue.base as? String else {
                return
            }
            
            if let completion = completion {
                if self.completionCallbacksByToken[loadMoreToken] == nil {
                    self.completionCallbacksByToken[loadMoreToken] = []
                }
                self.completionCallbacksByToken[loadMoreToken]?.append(completion)
            }
            
            if self.isLoadingMore {
                return
            }
            
            self.isLoadingMore = true
            
            let limit = 100
            
            let account = self.account
            let accountPeerId = account.peerId
            
            var searchHashtag: String? = nil
            var area: Api.MediaArea? = nil
            
            var peer: Signal<Api.InputPeer?, NoError> = .single(nil)
            var flags: Int32 = 0
            switch source {
            case let .hashtag(peerId, query):
                if query.hasPrefix("#") {
                    searchHashtag = String(query[query.index(after: query.startIndex)...])
                } else {
                    searchHashtag = query
                }
                flags |= (1 << 0)
                
                if let peerId {
                    peer = account.postbox.transaction { transaction in
                        return transaction.getPeer(peerId).flatMap(apiInputPeer)
                    }
                    flags |= (1 << 2)
                }
            case let .mediaArea(mediaArea):
                area = apiMediaAreasFromMediaAreas([mediaArea], transaction: nil).first
                flags |= (1 << 1)
            }
            
            self.requestDisposable = (peer
            |> castError(MTRpcError.self)
            |> mapToSignal { inputPeer in
                return account.network.request(Api.functions.stories.searchPosts(flags: flags, hashtag: searchHashtag, area: area, peer: inputPeer, offset: loadMoreToken, limit: Int32(limit)))
            }
            |> map { result -> Api.stories.FoundStories? in
                return result
            }
            |> `catch` { _ -> Signal<Api.stories.FoundStories?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<([State.Item], Int, String?), NoError> in
                guard let result else {
                    return .single(([], 0, nil))
                }
                
                return account.postbox.transaction { transaction -> ([State.Item], Int, String?) in
                    var storyItems: [State.Item] = []
                    var totalCount: Int = 0
                    var nextOffsetValue: String?
                    
                    switch result {
                    case let .foundStories(_, count, stories, nextOffset, chats, users):
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: users))
                        
                        totalCount = Int(count)
                        nextOffsetValue = nextOffset
                        
                        for story in stories {
                            switch story {
                            case let .foundStory(peer, story):
                                if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peer.peerId, transaction: transaction) {
                                    if case let .item(item) = storedItem, let media = item.media {
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
                                            author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) }
                                        )
                                        storyItems.append(State.Item(
                                            id: StoryId(peerId: peer.peerId, id: mappedItem.id),
                                            storyItem: mappedItem,
                                            peer: transaction.getPeer(peer.peerId).flatMap(EnginePeer.init)
                                        ))
                                    }
                                }
                            }
                        }
                    }
                    
                    return (storyItems, totalCount, nextOffsetValue)
                }
            }
            |> deliverOn(self.queue)).start(next: { [weak self] storyItems, totalCount, nextOffset in
                guard let `self` = self else {
                    return
                }
                
                self.isLoadingMore = false
                
                var updatedState = self.stateValue
                updatedState.hasCache = true
                
                var existingIds = Set(updatedState.items.map { $0.id })
                for item in storyItems {
                    if existingIds.contains(item.id) {
                        continue
                    }
                    existingIds.insert(item.id)
                    
                    updatedState.items.append(item)
                }
                
                if let nextOffset {
                    updatedState.loadMoreToken = AnyHashable(nextOffset)
                } else {
                    updatedState.loadMoreToken = nil
                }
                if updatedState.loadMoreToken != nil {
                    updatedState.totalCount = max(totalCount, updatedState.items.count)
                } else {
                    updatedState.totalCount = updatedState.items.count
                }
                self.stateValue = updatedState
                
                if let callbacks = self.completionCallbacksByToken.removeValue(forKey: loadMoreToken) {
                    for f in callbacks {
                        f()
                    }
                }
                
                if self.updatesDisposable == nil {
                    self.updatesDisposable = (self.account.stateManager.storyUpdates
                    |> deliverOn(self.queue)).start(next: { [weak self] updates in
                        guard let self else {
                            return
                        }
                        let _ = (self.account.postbox.transaction { transaction -> [PeerId: Peer] in
                            var peers: [PeerId: Peer] = [:]
                            
                            for update in updates {
                                switch update {
                                case let .added(_, item):
                                    if case let .item(item) = item {
                                        if let views = item.views {
                                            for id in views.seenPeerIds {
                                                if let peer = transaction.getPeer(id) {
                                                    peers[peer.id] = peer
                                                }
                                            }
                                        }
                                        if let forwardInfo = item.forwardInfo, case let .known(peerId, _, _) = forwardInfo {
                                            if let peer = transaction.getPeer(peerId) {
                                                peers[peer.id] = peer
                                            }
                                        }
                                        if let peerId = item.authorId {
                                            if let peer = transaction.getPeer(peerId) {
                                                peers[peer.id] = peer
                                            }
                                        }
                                    }
                                case let .updateMyReaction(_, _, reaction):
                                    if reaction != nil {
                                        if let peer = transaction.getPeer(accountPeerId) {
                                            peers[peer.id] = peer
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                            
                            return peers
                        }
                        |> deliverOn(self.queue)).start(next: { [weak self] peers in
                            guard let self else {
                                return
                            }
                            
                            var finalUpdatedState: State?
                            for update in updates {
                                switch update {
                                case .deleted:
                                    break
                                case let .added(peerId, item):
                                    if let index = (finalUpdatedState ?? self.stateValue).items.firstIndex(where: { $0.id == StoryId(peerId: peerId, id: item.id) }) {
                                        let currentItem = (finalUpdatedState ?? self.stateValue).items[index]
                                        if case let .item(item) = item, let media = item.media {
                                            var updatedState = finalUpdatedState ?? self.stateValue
                                            updatedState.items[index] = State.Item(
                                                id: StoryId(peerId: peerId, id: item.id),
                                                storyItem: EngineStoryItem(
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
                                                                return peers[id].flatMap(EnginePeer.init)
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
                                                    forwardInfo: item.forwardInfo.flatMap { EngineStoryItem.ForwardInfo($0, peers: peers) },
                                                    author: item.authorId.flatMap { peers[$0].flatMap(EnginePeer.init) }
                                                ),
                                                peer: currentItem.peer
                                            )
                                            finalUpdatedState = updatedState
                                        }
                                    }
                                case let .updateMyReaction(peerId, id, reaction):
                                    if let index = (finalUpdatedState ?? self.stateValue).items.firstIndex(where: { $0.id == StoryId(peerId: peerId, id: id) }) {
                                        let item = (finalUpdatedState ?? self.stateValue).items[index]
                                        var updatedState = finalUpdatedState ?? self.stateValue
                                        
                                        let previousViews: Stories.Item.Views? = item.storyItem.views.flatMap { views in
                                            return Stories.Item.Views(
                                                seenCount: views.seenCount,
                                                reactedCount: views.reactedCount,
                                                forwardCount: views.forwardCount,
                                                seenPeerIds: views.seenPeers.map(\.id),
                                                reactions: views.reactions,
                                                hasList: views.hasList
                                            )
                                        }
                                        let updatedViews = _internal_updateStoryViewsForMyReaction(isChannel: peerId.namespace == Namespaces.Peer.CloudChannel, views: previousViews, previousReaction: item.storyItem.myReaction, reaction: reaction)
                                        let mappedViews = updatedViews.flatMap { views in
                                            return EngineStoryItem.Views(
                                                seenCount: views.seenCount,
                                                reactedCount: views.reactedCount,
                                                forwardCount: views.forwardCount,
                                                seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                                    return peers[id].flatMap(EnginePeer.init)
                                                },
                                                reactions: views.reactions,
                                                hasList: views.hasList
                                            )
                                        }
                                        
                                        updatedState.items[index] = State.Item(
                                            id: item.id,
                                            storyItem: EngineStoryItem(
                                                id: item.storyItem.id,
                                                timestamp: item.storyItem.timestamp,
                                                expirationTimestamp: item.storyItem.expirationTimestamp,
                                                media: item.storyItem.media,
                                                alternativeMediaList: item.storyItem.alternativeMediaList,
                                                mediaAreas: item.storyItem.mediaAreas,
                                                text: item.storyItem.text,
                                                entities: item.storyItem.entities,
                                                views: mappedViews,
                                                privacy: item.storyItem.privacy,
                                                isPinned: item.storyItem.isPinned,
                                                isExpired: item.storyItem.isExpired,
                                                isPublic: item.storyItem.isPublic,
                                                isPending: item.storyItem.isPending,
                                                isCloseFriends: item.storyItem.isCloseFriends,
                                                isContacts: item.storyItem.isContacts,
                                                isSelectedContacts: item.storyItem.isSelectedContacts,
                                                isForwardingDisabled: item.storyItem.isForwardingDisabled,
                                                isEdited: item.storyItem.isEdited,
                                                isMy: item.storyItem.isMy,
                                                myReaction: reaction,
                                                forwardInfo: item.storyItem.forwardInfo,
                                                author: item.storyItem.author
                                            ),
                                            peer: item.peer
                                        )
                                        finalUpdatedState = updatedState
                                    }
                                case .read:
                                    break
                                case .updatePinnedToTopList:
                                    break
                                }
                            }
                            
                            if let finalUpdatedState {
                                self.stateValue = finalUpdatedState
                            }
                        })
                    })
                }
            })
        }
    }
    
    public var state: Signal<State, NoError> {
        return impl.signalWith { impl, subscriber in
            return impl.state.start(next: subscriber.putNext)
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public init(account: Account, source: Source) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, source: source)
        })
    }
    
    public func loadMore(completion: (() -> Void)? = nil) {
        self.impl.with { impl in
            impl.loadMore(completion : completion)
        }
    }
}

public final class PeerExpiringStoryListContext {
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let peerId: EnginePeer.Id
        
        private var listDisposable: Disposable?
        private var pollDisposable: Disposable?
        
        private let statePromise = Promise<State>()
        var state: Signal<State, NoError> {
            return self.statePromise.get()
        }
        
        private let polledOnce = ValuePromise<Bool>(false, ignoreRepeated: true)
        
        init(queue: Queue, account: Account, peerId: EnginePeer.Id) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            
            self.listDisposable = (combineLatest(queue: self.queue,
                account.postbox.combinedView(keys: [
                    PostboxViewKey.storiesState(key: .peer(peerId)),
                    PostboxViewKey.storyItems(peerId: peerId)
                ]),
                self.polledOnce.get()
            )
            |> deliverOn(self.queue)).start(next: { [weak self] views, polledOnce in
                guard let `self` = self else {
                    return
                }
                guard let stateView = views.views[PostboxViewKey.storiesState(key: .peer(peerId))] as? StoryStatesView else {
                    return
                }
                guard let itemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView else {
                    return
                }
                
                let _ = (self.account.postbox.transaction { transaction -> State? in
                    let state = stateView.value?.get(Stories.PeerState.self)
                    
                    var items: [Item] = []
                    for item in itemsView.items {
                        if let item = item.value.get(Stories.StoredItem.self) {
                            switch item {
                            case let .item(item):
                                if let media = item.media {
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
                                        author: item.authorId.flatMap { transaction.getPeer($0).flatMap(EnginePeer.init) }
                                    )
                                    items.append(.item(mappedItem))
                                }
                            case let .placeholder(placeholder):
                                items.append(.placeholder(id: placeholder.id, timestamp: placeholder.timestamp, expirationTimestamp: placeholder.expirationTimestamp))
                            }
                        }
                    }
                    
                    return State(
                        items: items,
                        isCached: false,
                        maxReadId: state?.maxReadId ?? 0,
                        isLoading: items.isEmpty && !polledOnce
                    )
                }
                |> deliverOn(self.queue)).start(next: { [weak self] state in
                    guard let `self` = self else {
                        return
                    }
                    guard let state = state else {
                        return
                    }
                    self.statePromise.set(.single(state))
                })
            })
            
            self.poll()
        }
        
        deinit {
            self.listDisposable?.dispose()
            self.pollDisposable?.dispose()
        }
        
        private func poll() {
            self.pollDisposable?.dispose()
            
            let account = self.account
            let accountPeerId = account.peerId
            let peerId = self.peerId
            self.pollDisposable = (self.account.postbox.transaction { transaction -> Api.InputPeer? in
                return transaction.getPeer(peerId).flatMap(apiInputPeer)
            }
            |> mapToSignal { inputPeer -> Signal<Never, NoError> in
                guard let inputPeer = inputPeer else {
                    return .complete()
                }
                return account.network.request(Api.functions.stories.getPeerStories(peer: inputPeer))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stories.PeerStories?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Never, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        var updatedPeerEntries: [StoryItemsTableEntry] = []
                        updatedPeerEntries.removeAll()
                        
                        if let result = result, case let .peerStories(stories, chats, users) = result {
                            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                            
                            switch stories {
                            case let .peerStories(_, peerIdValue, maxReadId, stories):
                                let peerId = peerIdValue.peerId
                                
                                let previousPeerEntries: [StoryItemsTableEntry] = transaction.getStoryItems(peerId: peerId)
                                
                                for story in stories {
                                    if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peerId, transaction: transaction) {
                                        if case .placeholder = storedItem, let previousEntry = previousPeerEntries.first(where: { $0.id == storedItem.id }) {
                                            updatedPeerEntries.append(previousEntry)
                                        } else {
                                            if let codedEntry = CodableEntry(storedItem) {
                                                updatedPeerEntries.append(StoryItemsTableEntry(value: codedEntry, id: storedItem.id, expirationTimestamp: storedItem.expirationTimestamp, isCloseFriends: storedItem.isCloseFriends))
                                            }
                                        }
                                    }
                                }
                                
                                transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(
                                    maxReadId: maxReadId ?? 0
                                ).postboxRepresentation)
                            }
                            
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        }
                        
                        transaction.setStoryItems(peerId: peerId, items: updatedPeerEntries)
                    }
                    |> ignoreValues
                }
            }).start(completed: { [weak self] in
                guard let `self` = self else {
                    return
                }
                
                self.polledOnce.set(true)
                
                self.pollDisposable = (Signal<Never, NoError>.complete() |> suspendAwareDelay(60.0, queue: self.queue) |> deliverOn(self.queue)).start(completed: { [weak self] in
                    guard let `self` = self else {
                        return
                    }
                    self.poll()
                })
            })
        }
    }
    
    public enum Item: Equatable {
        case item(EngineStoryItem)
        case placeholder(id: Int32, timestamp: Int32, expirationTimestamp: Int32)
        
        public var id: Int32 {
            switch self {
            case let .item(item):
                return item.id
            case let .placeholder(id, _, _):
                return id
            }
        }
        
        public var timestamp: Int32 {
            switch self {
            case let .item(item):
                return item.timestamp
            case let .placeholder(_, timestamp, _):
                return timestamp
            }
        }
        
        public var isCloseFriends: Bool {
            switch self {
            case let .item(item):
                return item.isCloseFriends
            case .placeholder:
                return false
            }
        }
    }
    
    public final class State: Equatable {
        public let items: [Item]
        public let isCached: Bool
        public let maxReadId: Int32
        public let isLoading: Bool
        
        public var hasUnseen: Bool {
            return self.items.contains(where: { $0.id > self.maxReadId })
        }
        
        public var unseenCount: Int {
            var count: Int = 0
            for item in items {
                if item.id > maxReadId {
                    count += 1
                }
            }
            return count
        }
        
        public var hasUnseenCloseFriends: Bool {
            return self.items.contains(where: { $0.id > self.maxReadId && $0.isCloseFriends })
        }
        
        public init(items: [Item], isCached: Bool, maxReadId: Int32, isLoading: Bool) {
            self.items = items
            self.isCached = isCached
            self.maxReadId = maxReadId
            self.isLoading = isLoading
        }
        
        public static func ==(lhs: State, rhs: State) -> Bool {
            if lhs === rhs {
                return true
            }
            if lhs.items != rhs.items {
                return false
            }
            if lhs.maxReadId != rhs.maxReadId {
                return false
            }
            if lhs.isLoading != rhs.isLoading {
                return false
            }
            return true
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return impl.signalWith { impl, subscriber in
            return impl.state.start(next: subscriber.putNext)
        }
    }
    
    public init(account: Account, peerId: EnginePeer.Id) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId)
        })
    }
}

public func _internal_pollPeerStories(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId, peerReference: PeerReference? = nil) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer) ?? peerReference?.inputPeer
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        
        return network.request(Api.functions.stories.getPeerStories(peer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.stories.PeerStories?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            return postbox.transaction { transaction -> Void in
                var updatedPeerEntries: [StoryItemsTableEntry] = []
                updatedPeerEntries.removeAll()
                
                if let result = result, case let .peerStories(stories, chats, users) = result {
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                    
                    switch stories {
                    case let .peerStories(_, peerIdValue, maxReadId, stories):
                        let peerId = peerIdValue.peerId
                        
                        let previousPeerEntries: [StoryItemsTableEntry] = transaction.getStoryItems(peerId: peerId)
                        
                        for story in stories {
                            if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peerId, transaction: transaction) {
                                if case .placeholder = storedItem, let previousEntry = previousPeerEntries.first(where: { $0.id == storedItem.id }) {
                                    updatedPeerEntries.append(previousEntry)
                                } else {
                                    if let codedEntry = CodableEntry(storedItem) {
                                        updatedPeerEntries.append(StoryItemsTableEntry(value: codedEntry, id: storedItem.id, expirationTimestamp: storedItem.expirationTimestamp, isCloseFriends: storedItem.isCloseFriends))
                                    }
                                }
                            }
                        }
                        
                        transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(
                            maxReadId: maxReadId ?? 0
                        ).postboxRepresentation)
                    }
                    
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                }
                
                transaction.setStoryItems(peerId: peerId, items: updatedPeerEntries)
                
                var isContactOrMember = false
                if transaction.isPeerContact(peerId: peerId) {
                    isContactOrMember = true
                } else if let peer = transaction.getPeer(peerId) as? TelegramChannel {
                    if peer.participationStatus == .member {
                        isContactOrMember = true
                    }
                } else if let peer = transaction.getPeer(peerId) as? TelegramGroup {
                    if case .Member = peer.membership {
                        isContactOrMember = true
                    }
                }
                
                if !updatedPeerEntries.isEmpty, shouldKeepUserStoriesInFeed(peerId: peerId, isContactOrMember: isContactOrMember) {
                    if let user = transaction.getPeer(peerId) as? TelegramUser, let storiesHidden = user.storiesHidden {
                        if storiesHidden {
                            if !transaction.storySubscriptionsContains(key: .hidden, peerId: peerId) {
                                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                                peerIds.append(peerId)
                                transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
                            }
                        } else {
                            if !transaction.storySubscriptionsContains(key: .filtered, peerId: peerId) {
                                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                                peerIds.append(peerId)
                                transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
                            }
                        }
                    } else if let channel = transaction.getPeer(peerId) as? TelegramChannel, let storiesHidden = channel.storiesHidden {
                        if storiesHidden {
                            if !transaction.storySubscriptionsContains(key: .hidden, peerId: peerId) {
                                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .hidden)
                                peerIds.append(peerId)
                                transaction.replaceAllStorySubscriptions(key: .hidden, state: state, peerIds: peerIds)
                            }
                        } else {
                            if !transaction.storySubscriptionsContains(key: .filtered, peerId: peerId) {
                                var (state, peerIds) = transaction.getAllStorySubscriptions(key: .filtered)
                                peerIds.append(peerId)
                                transaction.replaceAllStorySubscriptions(key: .filtered, state: state, peerIds: peerIds)
                            }
                        }
                    }
                }
            }
            |> ignoreValues
        }
    }
}

public final class BotPreviewStoryListContext: StoryListContext {
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let engine: TelegramEngine
        private let peerId: EnginePeer.Id
        private let language: String?
        private let isArchived: Bool
        
        private let statePromise = Promise<State>()
        private var stateValue: State {
            didSet {
                self.statePromise.set(.single(self.stateValue))
            }
        }
        var state: Signal<State, NoError> {
            return self.statePromise.get()
        }
        
        private var isLoadingMore: Bool = false
        private var requestDisposable: Disposable?
        private var updatesDisposable: Disposable?
        private var eventsDisposable: Disposable?
        private let reorderDisposable = MetaDisposable()
        
        private var completionCallbacksByToken: [AnyHashable: [() -> Void]] = [:]
        
        private var nextId: Int32 = 1
        private var pendingIdMapping: [Int32: Int32] = [:]
        private var idMapping: [MediaId: Int32] = [:]
        private var reverseIdMapping: [Int32: MediaId] = [:]
        
        private var localItems: [State.Item] = []
        private var remoteItems: [State.Item] = []
        
        init(queue: Queue, account: Account, engine: TelegramEngine, peerId: EnginePeer.Id, language: String?, assumeEmpty: Bool) {
            self.queue = queue
            self.account = account
            self.engine = engine
            self.peerId = peerId
            self.language = language
            
            let isArchived = false
            
            self.isArchived = isArchived
            
            self.stateValue = State(peerReference: nil, items: [], availableLanguages: [], pinnedIds: [], totalCount: 0, loadMoreToken: AnyHashable(0 as Int), isCached: true, hasCache: false, allEntityFiles: [:], isLoading: false)
            
            let localStateKey: PostboxViewKey = .storiesState(key: .local)
            
            if let language {
                let _ = (account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(peerId)
                }
                |> deliverOn(self.queue)).start(next: { [weak self] peer in
                    guard let self else {
                        return
                    }
                    
                    self.stateValue = State(
                        peerReference: peer.flatMap(PeerReference.init),
                        items: [],
                        availableLanguages: [],
                        pinnedIds: [],
                        totalCount: 0,
                        loadMoreToken: AnyHashable(0),
                        isCached: assumeEmpty,
                        hasCache: assumeEmpty,
                        allEntityFiles: [:],
                        isLoading: !assumeEmpty
                    )
                    
                    self.loadLanguage(language: language, assumeEmpty: assumeEmpty)
                })
            } else {
                self.requestDisposable = (combineLatest(queue: queue,
                    engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: peerId),
                        TelegramEngine.EngineData.Item.Peer.BotPreview(id: peerId),
                        TelegramEngine.EngineData.Item.Configuration.LocalizationList()
                    ),
                    account.postbox.combinedView(keys: [
                        localStateKey
                    ])
                )
                |> deliverOn(self.queue)).start(next: { [weak self] peerAndBotPreview, combinedView in
                    guard let self else {
                        return
                    }
                    
                    let (peer, botPreview, localizationList) = peerAndBotPreview
                    
                    var items: [State.Item] = []
                    var availableLanguages: [StoryListContextState.Language] = []
                    
                    if let stateView = combinedView.views[localStateKey] as? StoryStatesView, let localState = stateView.value?.get(Stories.LocalState.self) {
                        for item in localState.items.reversed() {
                            let mappedId: Int32
                            if let current = self.pendingIdMapping[item.stableId] {
                                mappedId = current
                            } else {
                                mappedId = self.nextId
                                self.nextId += 1
                                self.pendingIdMapping[item.stableId] = mappedId
                            }
                            
                            if let mediaId = _internal_lookUpPendingBotPreviewIdMapping(peerId: self.peerId, stableId: item.stableId) {
                                if let botPreview, botPreview.items.contains(where: { $0.media.id == mediaId }) {
                                    continue
                                }
                            }
                            
                            if case let .botPreview(itemPeerId, itemLanguage) = item.target, itemPeerId == peerId, itemLanguage == language {
                                items.append(State.Item(
                                    id: StoryId(peerId: peerId, id: mappedId),
                                    storyItem: EngineStoryItem(
                                        id: mappedId,
                                        timestamp: 0,
                                        expirationTimestamp: Int32.max,
                                        media: EngineMedia(item.media),
                                        alternativeMediaList: [],
                                        mediaAreas: [],
                                        text: "",
                                        entities: [],
                                        views: nil,
                                        privacy: nil,
                                        isPinned: false,
                                        isExpired: false,
                                        isPublic: false,
                                        isPending: true,
                                        isCloseFriends: false,
                                        isContacts: false,
                                        isSelectedContacts: false,
                                        isForwardingDisabled: false,
                                        isEdited: false,
                                        isMy: false,
                                        myReaction: nil,
                                        forwardInfo: nil,
                                        author: nil
                                    ),
                                    peer: nil
                                ))
                            }
                        }
                    }
                    
                    if let botPreview {
                        for item in botPreview.items {
                            guard let mediaId = item.media.id else {
                                continue
                            }
                            
                            let id: Int32
                            if let current = self.idMapping[mediaId] {
                                id = current
                            } else {
                                id = self.nextId
                                self.nextId += 1
                                self.idMapping[mediaId] = id
                                self.reverseIdMapping[id] = mediaId
                            }
                            
                            items.append(State.Item(
                                id: StoryId(peerId: peerId, id: id),
                                storyItem: EngineStoryItem(
                                    id: id,
                                    timestamp: item.timestamp,
                                    expirationTimestamp: Int32.max,
                                    media: EngineMedia(item.media),
                                    alternativeMediaList: [],
                                    mediaAreas: [],
                                    text: "",
                                    entities: [],
                                    views: nil,
                                    privacy: nil,
                                    isPinned: false,
                                    isExpired: false,
                                    isPublic: false,
                                    isPending: false,
                                    isCloseFriends: false,
                                    isContacts: false,
                                    isSelectedContacts: false,
                                    isForwardingDisabled: false,
                                    isEdited: false,
                                    isMy: false,
                                    myReaction: nil,
                                    forwardInfo: nil,
                                    author: nil
                                ),
                                peer: nil
                            ))
                        }
                        
                        for id in botPreview.alternativeLanguageCodes {
                            inner: for localization in localizationList.availableOfficialLocalizations {
                                if localization.languageCode == id {
                                    availableLanguages.append(StoryListContextState.Language(
                                        id: localization.languageCode,
                                        name: localization.title
                                    ))
                                    break inner
                                }
                            }
                        }
                    }
                    
                    self.stateValue = State(
                        peerReference: (peer?._asPeer()).flatMap(PeerReference.init),
                        items: items,
                        availableLanguages: availableLanguages,
                        pinnedIds: [],
                        totalCount: items.count,
                        loadMoreToken: nil,
                        isCached: botPreview != nil,
                        hasCache: botPreview != nil,
                        allEntityFiles: [:],
                        isLoading: botPreview == nil
                    )
                })
            }
        }
        
        deinit {
            self.requestDisposable?.dispose()
            self.updatesDisposable?.dispose()
            self.eventsDisposable?.dispose()
            self.reorderDisposable.dispose()
        }
        
        func loadMore(completion: (() -> Void)?) {
        }
        
        private func loadLanguage(language: String, assumeEmpty: Bool) {
            let account = self.account
            let peerId = self.peerId
            let signal: Signal<(CachedUserData.BotPreview?, Peer?), NoError> = (self.account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
            }
            |> mapToSignal { peer -> Signal<(CachedUserData.BotPreview?, Peer?), NoError> in
                guard let peer, let inputUser = apiInputUser(peer) else {
                    return .single((nil, nil))
                }
                return _internal_requestBotAdminPreview(network: account.network, peerId: peerId, inputUser: inputUser, language: language)
                |> map { botPreview in
                    return (botPreview, peer)
                }
            })
            
            self.requestDisposable?.dispose()
            self.requestDisposable = (signal
            |> deliverOn(self.queue)).startStrict(next: { [weak self] botPreview, peer in
                guard let self, let peer else {
                    return
                }
                
                var items: [State.Item] = []
                
                if let botPreview {
                    for item in botPreview.items {
                        guard let mediaId = item.media.id else {
                            continue
                        }
                        
                        let id: Int32
                        if let current = self.idMapping[mediaId] {
                            id = current
                        } else {
                            id = self.nextId
                            self.nextId += 1
                            self.idMapping[mediaId] = id
                            self.reverseIdMapping[id] = mediaId
                        }
                        
                        items.append(State.Item(
                            id: StoryId(peerId: peerId, id: id),
                            storyItem: EngineStoryItem(
                                id: id,
                                timestamp: item.timestamp,
                                expirationTimestamp: Int32.max,
                                media: EngineMedia(item.media),
                                alternativeMediaList: [],
                                mediaAreas: [],
                                text: "",
                                entities: [],
                                views: nil,
                                privacy: nil,
                                isPinned: false,
                                isExpired: false,
                                isPublic: false,
                                isPending: false,
                                isCloseFriends: false,
                                isContacts: false,
                                isSelectedContacts: false,
                                isForwardingDisabled: false,
                                isEdited: false,
                                isMy: false,
                                myReaction: nil,
                                forwardInfo: nil,
                                author: nil
                            ),
                            peer: nil
                        ))
                    }
                }
                
                self.remoteItems = items
                self.stateValue = State(
                    peerReference: PeerReference(peer),
                    items: items,
                    availableLanguages: [],
                    pinnedIds: [],
                    totalCount: items.count,
                    loadMoreToken: nil,
                    isCached: botPreview != nil,
                    hasCache: botPreview != nil,
                    allEntityFiles: [:],
                    isLoading: botPreview == nil
                )
                
                if botPreview != nil {
                    self.beginUpdates(language: language)
                }
            })
        }
        
        private func beginUpdates(language: String) {
            let localStateKey: PostboxViewKey = .storiesState(key: .local)
            
            self.updatesDisposable?.dispose()
            self.updatesDisposable = (self.account.postbox.combinedView(keys: [
                localStateKey
            ])
            |> deliverOn(self.queue)).startStrict(next: { [weak self] combinedView in
                guard let self else {
                    return
                }
                
                var items: [State.Item] = []
                if let stateView = combinedView.views[localStateKey] as? StoryStatesView, let localState = stateView.value?.get(Stories.LocalState.self) {
                    for item in localState.items.reversed() {
                        let mappedId: Int32
                        if let current = self.pendingIdMapping[item.stableId] {
                            mappedId = current
                        } else {
                            mappedId = self.nextId
                            self.nextId += 1
                            self.pendingIdMapping[item.stableId] = mappedId
                        }
                        if case let .botPreview(itemPeerId, itemLanguage) = item.target, itemPeerId == self.peerId, itemLanguage == language {
                            items.append(State.Item(
                                id: StoryId(peerId: peerId, id: mappedId),
                                storyItem: EngineStoryItem(
                                    id: mappedId,
                                    timestamp: 0,
                                    expirationTimestamp: Int32.max,
                                    media: EngineMedia(item.media),
                                    alternativeMediaList: [],
                                    mediaAreas: [],
                                    text: "",
                                    entities: [],
                                    views: nil,
                                    privacy: nil,
                                    isPinned: false,
                                    isExpired: false,
                                    isPublic: false,
                                    isPending: true,
                                    isCloseFriends: false,
                                    isContacts: false,
                                    isSelectedContacts: false,
                                    isForwardingDisabled: false,
                                    isEdited: false,
                                    isMy: false,
                                    myReaction: nil,
                                    forwardInfo: nil,
                                    author: nil
                                ),
                                peer: nil
                            ))
                        }
                    }
                }
                
                if self.localItems != items {
                    self.localItems = items
                    
                    if self.stateValue.peerReference != nil {
                        self.pushLanguageItems()
                    }
                }
            })
            
            self.eventsDisposable?.dispose()
            self.eventsDisposable = (self.account.stateManager.botPreviewUpdates
            |> deliverOn(self.queue)).startStrict(next: { [weak self] events in
                guard let self else {
                    return
                }
                var remoteItems = self.remoteItems
                for event in events {
                    switch event {
                    case let .added(peerId, language, item):
                        if let mediaId = item.media.id, self.peerId == peerId, self.language == language {
                            let id: Int32
                            if let current = self.idMapping[mediaId] {
                                id = current
                            } else {
                                id = self.nextId
                                self.nextId += 1
                                self.idMapping[mediaId] = id
                                self.reverseIdMapping[id] = mediaId
                            }
                            
                            let mappedItem = State.Item(
                                id: StoryId(peerId: peerId, id: id),
                                storyItem: EngineStoryItem(
                                    id: id,
                                    timestamp: item.timestamp,
                                    expirationTimestamp: Int32.max,
                                    media: EngineMedia(item.media),
                                    alternativeMediaList: [],
                                    mediaAreas: [],
                                    text: "",
                                    entities: [],
                                    views: nil,
                                    privacy: nil,
                                    isPinned: false,
                                    isExpired: false,
                                    isPublic: false,
                                    isPending: false,
                                    isCloseFriends: false,
                                    isContacts: false,
                                    isSelectedContacts: false,
                                    isForwardingDisabled: false,
                                    isEdited: false,
                                    isMy: false,
                                    myReaction: nil,
                                    forwardInfo: nil,
                                    author: nil
                                ),
                                peer: nil
                            )
                            
                            if let index = remoteItems.firstIndex(where: { $0.storyItem.media.id == item.media.id }) {
                                remoteItems[index] = mappedItem
                            } else {
                                remoteItems.insert(mappedItem, at: 0)
                            }
                        }
                    case let .deleted(peerId, language, ids):
                        if self.peerId == peerId && self.language == language {
                            remoteItems = remoteItems.filter { item in
                                guard let id = item.storyItem.media.id else {
                                    return false
                                }
                                return !ids.contains(id)
                            }
                        }
                    }
                }
                if self.remoteItems != remoteItems {
                    self.remoteItems = remoteItems
                    self.pushLanguageItems()
                }
            })
        }
        
        private func pushLanguageItems() {
            var items: [State.Item] = []
            for item in self.localItems {
                var stableId: Int32?
                inner: for (from, to) in self.pendingIdMapping {
                    if to == item.id.id {
                        stableId = from
                        break inner
                    }
                }
                if let stableId, let mediaId = _internal_lookUpPendingBotPreviewIdMapping(peerId: self.peerId, stableId: stableId) {
                    if self.remoteItems.contains(where: { $0.storyItem.media.id == mediaId }) {
                        continue
                    }
                }
                items.append(item)
            }
            items.append(contentsOf: self.remoteItems)
            
            self.stateValue = State(
                peerReference: self.stateValue.peerReference,
                items: items,
                availableLanguages: [],
                pinnedIds: [],
                totalCount: items.count,
                loadMoreToken: nil,
                isCached: true,
                hasCache: true,
                allEntityFiles: [:],
                isLoading: false
            )
        }
        
        func reorderItems(media: [Media]) {
            let peerId = self.peerId
            let language = self.language
            
            let _ = (self.account.postbox.transaction({ transaction -> (Api.InputUser?, [Api.InputMedia]) in
                let inputUser = transaction.getPeer(peerId).flatMap(apiInputUser)
                
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
                    transaction.updatePeerCachedData(peerIds: Set([self.peerId]), update: { _, current in
                        guard var current = current as? CachedUserData else {
                            return current
                        }
                        guard let currentBotPreview = current.botPreview else {
                            return current
                        }
                        
                        var items: [CachedUserData.BotPreview.Item] = []
                        
                        var seenIds = Set<MediaId>()
                        for item in media {
                            guard let mediaId = item.id else {
                                continue
                            }
                            if let index = currentBotPreview.items.firstIndex(where: { $0.media.id == mediaId }) {
                                seenIds.insert(mediaId)
                                items.append(currentBotPreview.items[index])
                            }
                        }
                        
                        for item in currentBotPreview.items {
                            guard let id = item.media.id else {
                                continue
                            }
                            if !seenIds.contains(id) {
                                items.append(item)
                            }
                        }
                        
                        let botPreview = CachedUserData.BotPreview(items: items, alternativeLanguageCodes: currentBotPreview.alternativeLanguageCodes)
                        current = current.withUpdatedBotPreview(botPreview)
                        return current
                    })
                }
                
                return (inputUser, inputMedia)
            })
            |> deliverOn(self.queue)).startStandalone(next: { [weak self] inputUser, inputMedia in
                guard let self, let inputUser else {
                    return
                }
                
                if language != nil {
                    var updatedItems: [State.Item] = []
                    
                    var seenIds = Set<MediaId>()
                    for item in media {
                        guard let mediaId = item.id else {
                            continue
                        }
                        if let index = self.remoteItems.firstIndex(where: { $0.storyItem.media.id == mediaId }) {
                            seenIds.insert(mediaId)
                            updatedItems.append(self.remoteItems[index])
                        }
                    }
                    
                    for item in self.remoteItems {
                        guard let id = item.storyItem.media.id else {
                            continue
                        }
                        if !seenIds.contains(id) {
                            updatedItems.append(item)
                        }
                    }
                    
                    if self.remoteItems != updatedItems {
                        self.remoteItems = updatedItems
                        self.pushLanguageItems()
                    }
                }
                
                let signal = self.account.network.request(Api.functions.bots.reorderPreviewMedias(bot: inputUser, langCode: language ?? "", order: inputMedia))
                self.reorderDisposable.set(signal.startStrict())
            })
        }
    }
    
    public var state: Signal<State, NoError> {
        return impl.signalWith { impl, subscriber in
            return impl.state.start(next: subscriber.putNext)
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public let language: String?
    
    public init(account: Account, engine: TelegramEngine, peerId: EnginePeer.Id, language: String?, assumeEmpty: Bool) {
        self.language = language
        
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, engine: engine, peerId: peerId, language: language, assumeEmpty: assumeEmpty)
        })
    }
    
    public func loadMore(completion: (() -> Void)? = nil) {
        self.impl.with { impl in
            impl.loadMore(completion: completion)
        }
    }
    
    public func reorderItems(media: [Media]) {
        self.impl.with { impl in
            impl.reorderItems(media: media)
        }
    }
}
