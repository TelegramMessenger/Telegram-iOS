import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit
import MtProtoKit

enum InternalStoryUpdate {
    case deleted(peerId: PeerId, id: Int32)
    case added(peerId: PeerId, item: Stories.StoredItem)
    case read(peerId: PeerId, maxId: Int32)
}

public final class EngineStoryItem: Equatable {
    public final class Views: Equatable {
        public let seenCount: Int
        public let seenPeers: [EnginePeer]
        
        public init(seenCount: Int, seenPeers: [EnginePeer]) {
            self.seenCount = seenCount
            self.seenPeers = seenPeers
        }
        
        public static func ==(lhs: Views, rhs: Views) -> Bool {
            if lhs.seenCount != rhs.seenCount {
                return false
            }
            if lhs.seenPeers != rhs.seenPeers {
                return false
            }
            return true
        }
    }
    
    public let id: Int32
    public let timestamp: Int32
    public let expirationTimestamp: Int32
    public let media: EngineMedia
    public let text: String
    public let entities: [MessageTextEntity]
    public let views: Views?
    public let privacy: EngineStoryPrivacy?
    public let isPinned: Bool
    public let isExpired: Bool
    public let isPublic: Bool
    
    public init(id: Int32, timestamp: Int32, expirationTimestamp: Int32, media: EngineMedia, text: String, entities: [MessageTextEntity], views: Views?, privacy: EngineStoryPrivacy?, isPinned: Bool, isExpired: Bool, isPublic: Bool) {
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
        return true
    }
}

extension EngineStoryItem {
    func asStoryItem() -> Stories.Item {
        return Stories.Item(
            id: self.id,
            timestamp: self.timestamp,
            expirationTimestamp: self.expirationTimestamp,
            media: self.media._asMedia(),
            text: self.text,
            entities: self.entities,
            views: self.views.flatMap { views in
                return Stories.Item.Views(
                    seenCount: views.seenCount,
                    seenPeerIds: views.seenPeers.map(\.id)
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
            isPublic: self.isPublic
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
        private let includesHidden: Bool
        
        private var taskState = TaskState()
        
        private var isLoading: Bool = false
        
        private var loadedStateMark: OpaqueStateMark?
        private var stateDisposable: Disposable?
        private let loadMoreDisposable = MetaDisposable()
        private let refreshTimerDisposable = MetaDisposable()
        
        init(queue: Queue, accountPeerId: PeerId, postbox: Postbox, network: Network, includesHidden: Bool) {
            self.accountPeerId = accountPeerId
            self.queue = queue
            self.postbox = postbox
            self.network = network
            self.includesHidden = includesHidden
            
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
            
            let subscriptionsKey: PostboxStorySubscriptionsKey = self.includesHidden ? .all : .filtered
            
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
            
            if self.includesHidden {
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
            
            let includesHidden = self.includesHidden
            let subscriptionsKey: PostboxStorySubscriptionsKey = self.includesHidden ? .all : .filtered
            
            self.loadMoreDisposable.set((self.network.request(Api.functions.stories.getAllStories(flags: flags, state: state))
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let `self` = self else {
                    return
                }
                
                let _ = (self.postbox.transaction { transaction -> Void in
                    switch result {
                    case let .allStoriesNotModified(state):
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
                    case let .allStories(flags, _, state, userStories, users):
                        //TODO:count
                        
                        var peers: [Peer] = []
                        var peerPresences: [PeerId: Api.User] = [:]
                        
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            peerPresences[telegramUser.id] = user
                        }
                        
                        let hasMore: Bool = (flags & (1 << 0)) != 0
                        
                        let (_, currentPeerItems) = transaction.getAllStorySubscriptions(key: subscriptionsKey)
                        var peerEntries: [PeerId] = []
                        
                        for userStorySet in userStories {
                            switch userStorySet {
                            case let .userStories(_, userId, maxReadId, stories):
                                let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                
                                let previousPeerEntries: [StoryItemsTableEntry] = transaction.getStoryItems(peerId: peerId)
                                
                                var updatedPeerEntries: [StoryItemsTableEntry] = []
                                for story in stories {
                                    if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peerId, transaction: transaction) {
                                        if case .placeholder = storedItem, let previousEntry = previousPeerEntries.first(where: { $0.id == storedItem.id }) {
                                            updatedPeerEntries.append(previousEntry)
                                        } else {
                                            if let codedEntry = CodableEntry(storedItem) {
                                                updatedPeerEntries.append(StoryItemsTableEntry(value: codedEntry, id: storedItem.id))
                                            }
                                        }
                                    }
                                }
                                
                                peerEntries.append(peerId)
                                
                                transaction.setStoryItems(peerId: peerId, items: updatedPeerEntries)
                                transaction.setPeerStoryState(peerId: peerId, state: CodableEntry(Stories.PeerState(
                                    maxReadId: maxReadId ?? 0
                                )))
                            }
                        }
                        
                        if isRefresh {
                            if !includesHidden {
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
                        
                        transaction.replaceAllStorySubscriptions(key: subscriptionsKey, state: CodableEntry(Stories.SubscriptionsState(
                            opaqueState: state,
                            refreshId: UInt64.random(in: 0 ... UInt64.max),
                            hasMore: hasMore
                        )), peerIds: peerEntries)
                        
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
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
    
    init(accountPeerId: PeerId, postbox: Postbox, network: Network, includesHidden: Bool) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            Impl(queue: queue, accountPeerId: accountPeerId, postbox: postbox, network: network, includesHidden: includesHidden)
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
    let totalCount: Int32
    
    init(items: [Stories.StoredItem], totalCount: Int32) {
        self.items = items
        self.totalCount = totalCount
    }
}

public final class PeerStoryListContext {
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
        
        init(queue: Queue, account: Account, peerId: EnginePeer.Id, isArchived: Bool) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.isArchived = isArchived
            
            self.stateValue = State(peerReference: nil, items: [], totalCount: 0, loadMoreToken: 0, isCached: true)
            
            let _ = (account.postbox.transaction { transaction -> (PeerReference?, [EngineStoryItem], Int) in
                let key = ValueBoxKey(length: 8 + 1)
                key.setInt64(0, value: peerId.toInt64())
                key.setInt8(8, value: isArchived ? 1 : 0)
                let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key))?.get(CachedPeerStoryListHead.self)
                guard let cached = cached else {
                    return (nil, [], 0)
                }
                var items: [EngineStoryItem] = []
                for storedItem in cached.items {
                    if case let .item(item) = storedItem, let media = item.media {
                        let mappedItem = EngineStoryItem(
                            id: item.id,
                            timestamp: item.timestamp,
                            expirationTimestamp: item.expirationTimestamp,
                            media: EngineMedia(media),
                            text: item.text,
                            entities: item.entities,
                            views: item.views.flatMap { views in
                                return EngineStoryItem.Views(
                                    seenCount: views.seenCount,
                                    seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                        return transaction.getPeer(id).flatMap(EnginePeer.init)
                                    }
                                )
                            },
                            privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                            isPinned: item.isPinned,
                            isExpired: item.isExpired,
                            isPublic: item.isPublic
                        )
                        items.append(mappedItem)
                    }
                }
                
                let peerReference = transaction.getPeer(peerId).flatMap(PeerReference.init)
                
                return (peerReference, items, Int(cached.totalCount))
            }
            |> deliverOn(self.queue)).start(next: { [weak self] peerReference, items, totalCount in
                guard let self else {
                    return
                }
                
                self.stateValue = State(peerReference: peerReference, items: items, totalCount: totalCount, loadMoreToken: 0, isCached: true)
                self.loadMore()
            })
        }
        
        deinit {
            self.requestDisposable?.dispose()
        }
        
        func loadMore() {
            if self.isLoadingMore {
                return
            }
            guard let loadMoreToken = self.stateValue.loadMoreToken else {
                return
            }
            
            self.isLoadingMore = true
            
            let peerId = self.peerId
            let account = self.account
            let isArchived = self.isArchived
            self.requestDisposable = (self.account.postbox.transaction { transaction -> Api.InputUser? in
                return transaction.getPeer(peerId).flatMap(apiInputUser)
            }
            |> mapToSignal { inputUser -> Signal<([EngineStoryItem], Int, PeerReference?), NoError> in
                guard let inputUser = inputUser else {
                    return .single(([], 0, nil))
                }
                
                let signal: Signal<Api.stories.Stories, MTRpcError>
                if isArchived {
                    signal = account.network.request(Api.functions.stories.getStoriesArchive(offsetId: Int32(loadMoreToken), limit: 100))
                } else {
                    signal = account.network.request(Api.functions.stories.getPinnedStories(userId: inputUser, offsetId: Int32(loadMoreToken), limit: 100))
                }
                return signal
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([EngineStoryItem], Int, PeerReference?), NoError> in
                    guard let result = result else {
                        return .single(([], 0, nil))
                    }
                    
                    return account.postbox.transaction { transaction -> ([EngineStoryItem], Int, PeerReference?) in
                        var storyItems: [EngineStoryItem] = []
                        var totalCount: Int = 0
                        
                        switch result {
                        case let .stories(count, stories, users):
                            totalCount = Int(count)
                            
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
                            
                            for story in stories {
                                if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peerId, transaction: transaction) {
                                    if case let .item(item) = storedItem, let media = item.media {
                                        let mappedItem = EngineStoryItem(
                                            id: item.id,
                                            timestamp: item.timestamp,
                                            expirationTimestamp: item.expirationTimestamp,
                                            media: EngineMedia(media),
                                            text: item.text,
                                            entities: item.entities,
                                            views: item.views.flatMap { views in
                                                return EngineStoryItem.Views(
                                                    seenCount: views.seenCount,
                                                    seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                                        return transaction.getPeer(id).flatMap(EnginePeer.init)
                                                    }
                                                )
                                            },
                                            privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                                            isPinned: item.isPinned,
                                            isExpired: item.isExpired,
                                            isPublic: item.isPublic
                                        )
                                        storyItems.append(mappedItem)
                                    }
                                }
                            }
                            
                            if loadMoreToken == 0 {
                                let key = ValueBoxKey(length: 8 + 1)
                                key.setInt64(0, value: peerId.toInt64())
                                key.setInt8(8, value: isArchived ? 1 : 0)
                                if let entry = CodableEntry(CachedPeerStoryListHead(items: storyItems.prefix(100).map { .item($0.asStoryItem()) }, totalCount: count)) {
                                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedPeerStoryListHeads, key: key), entry: entry)
                                }
                            }
                        }
                        
                        return (storyItems, totalCount, transaction.getPeer(peerId).flatMap(PeerReference.init))
                    }
                }
            }
            |> deliverOn(self.queue)).start(next: { [weak self] storyItems, totalCount, peerReference in
                guard let `self` = self else {
                    return
                }
                
                self.isLoadingMore = false
                
                var updatedState = self.stateValue
                if updatedState.isCached {
                    updatedState.items.removeAll()
                    updatedState.isCached = false
                }
                
                var existingIds = Set(updatedState.items.map { $0.id })
                for item in storyItems {
                    if existingIds.contains(item.id) {
                        continue
                    }
                    existingIds.insert(item.id)
                    
                    updatedState.items.append(item)
                }
                
                if updatedState.peerReference == nil {
                    updatedState.peerReference = peerReference
                }
                
                updatedState.loadMoreToken = (storyItems.last?.id).flatMap(Int.init)
                if updatedState.loadMoreToken != nil {
                    updatedState.totalCount = max(totalCount, updatedState.items.count)
                } else {
                    updatedState.totalCount = updatedState.items.count
                }
                self.stateValue = updatedState
                
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
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                            
                            return peers
                        }
                        |> deliverOn(self.queue)).start(next: { [weak self] peers in
                            guard let `self` = self else {
                                return
                            }
                            
                            var finalUpdatedState: State?
                            
                            for update in updates {
                                switch update {
                                case let .deleted(peerId, id):
                                    if self.peerId == peerId {
                                        if let index = self.stateValue.items.firstIndex(where: { $0.id == id }) {
                                            var updatedState = finalUpdatedState ?? self.stateValue
                                            updatedState.items.remove(at: index)
                                            updatedState.totalCount = max(0, updatedState.totalCount - 1)
                                            finalUpdatedState = updatedState
                                        }
                                    }
                                case let .added(peerId, item):
                                    if self.peerId == peerId {
                                        if let index = self.stateValue.items.firstIndex(where: { $0.id == item.id }) {
                                            if !self.isArchived {
                                                if case let .item(item) = item {
                                                    if item.isPinned {
                                                        if let media = item.media {
                                                            var updatedState = finalUpdatedState ?? self.stateValue
                                                            updatedState.items[index] = EngineStoryItem(
                                                                id: item.id,
                                                                timestamp: item.timestamp,
                                                                expirationTimestamp: item.expirationTimestamp,
                                                                media: EngineMedia(media),
                                                                text: item.text,
                                                                entities: item.entities,
                                                                views: item.views.flatMap { views in
                                                                    return EngineStoryItem.Views(
                                                                        seenCount: views.seenCount,
                                                                        seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                                                            return peers[id].flatMap(EnginePeer.init)
                                                                        }
                                                                    )
                                                                },
                                                                privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                                                                isPinned: item.isPinned,
                                                                isExpired: item.isExpired,
                                                                isPublic: item.isPublic
                                                            )
                                                            finalUpdatedState = updatedState
                                                        }
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
                                                            updatedState.items.append(EngineStoryItem(
                                                                id: item.id,
                                                                timestamp: item.timestamp,
                                                                expirationTimestamp: item.expirationTimestamp,
                                                                media: EngineMedia(media),
                                                                text: item.text,
                                                                entities: item.entities,
                                                                views: item.views.flatMap { views in
                                                                    return EngineStoryItem.Views(
                                                                        seenCount: views.seenCount,
                                                                        seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                                                            return peers[id].flatMap(EnginePeer.init)
                                                                        }
                                                                    )
                                                                },
                                                                privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                                                                isPinned: item.isPinned,
                                                                isExpired: item.isExpired,
                                                                isPublic: item.isPublic
                                                            ))
                                                            updatedState.items.sort(by: { lhs, rhs in
                                                                return lhs.timestamp > rhs.timestamp
                                                            })
                                                            finalUpdatedState = updatedState
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                case .read:
                                    break
                                }
                            }
                            
                            if let finalUpdatedState = finalUpdatedState {
                                self.stateValue = finalUpdatedState
                                
                                let items = finalUpdatedState.items
                                let totalCount = finalUpdatedState.totalCount
                                let _ = (self.account.postbox.transaction { transaction -> Void in
                                    let key = ValueBoxKey(length: 8 + 1)
                                    key.setInt64(0, value: peerId.toInt64())
                                    key.setInt8(8, value: isArchived ? 1 : 0)
                                    if let entry = CodableEntry(CachedPeerStoryListHead(items: items.prefix(100).map { .item($0.asStoryItem()) }, totalCount: Int32(totalCount))) {
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
    
    public struct State: Equatable {
        public var peerReference: PeerReference?
        public var items: [EngineStoryItem]
        public var totalCount: Int
        public var loadMoreToken: Int?
        public var isCached: Bool
        
        init(
            peerReference: PeerReference?,
            items: [EngineStoryItem],
            totalCount: Int,
            loadMoreToken: Int?,
            isCached: Bool
        ) {
            self.peerReference = peerReference
            self.items = items
            self.totalCount = totalCount
            self.loadMoreToken = loadMoreToken
            self.isCached = isCached
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
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
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
        
        init(queue: Queue, account: Account, peerId: EnginePeer.Id) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            
            self.listDisposable = (account.postbox.combinedView(keys: [
                PostboxViewKey.storiesState(key: .peer(peerId)),
                PostboxViewKey.storyItems(peerId: peerId)
            ])
            |> deliverOn(self.queue)).start(next: { [weak self] views in
                guard let self else {
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
                                        text: item.text,
                                        entities: item.entities,
                                        views: item.views.flatMap { views in
                                            return EngineStoryItem.Views(
                                                seenCount: views.seenCount,
                                                seenPeers: views.seenPeerIds.compactMap { id -> EnginePeer? in
                                                    return transaction.getPeer(id).flatMap(EnginePeer.init)
                                                }
                                            )
                                        },
                                        privacy: item.privacy.flatMap(EngineStoryPrivacy.init),
                                        isPinned: item.isPinned,
                                        isExpired: item.isExpired,
                                        isPublic: item.isPublic
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
                        maxReadId: state?.maxReadId ?? 0
                    )
                }
                |> deliverOn(self.queue)).start(next: { [weak self] state in
                    guard let self else {
                        return
                    }
                    guard let state else {
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
            let peerId = self.peerId
            self.pollDisposable = (self.account.postbox.transaction { transaction -> Api.InputUser? in
                return transaction.getPeer(peerId).flatMap(apiInputUser)
            }
            |> mapToSignal { inputUser -> Signal<Never, NoError> in
                guard let inputUser else {
                    return .complete()
                }
                return account.network.request(Api.functions.stories.getUserStories(userId: inputUser))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stories.UserStories?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Never, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        var updatedPeerEntries: [StoryItemsTableEntry] = []
                        updatedPeerEntries.removeAll()
                        
                        if let result = result, case let .userStories(stories, users) = result {
                            var peers: [Peer] = []
                            var peerPresences: [PeerId: Api.User] = [:]
                            
                            for user in users {
                                let telegramUser = TelegramUser(user: user)
                                peers.append(telegramUser)
                                peerPresences[telegramUser.id] = user
                            }
                            
                            switch stories {
                            case let .userStories(_, userId, maxReadId, stories):
                                let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                
                                let previousPeerEntries: [StoryItemsTableEntry] = transaction.getStoryItems(peerId: peerId)
                                
                                for story in stories {
                                    if let storedItem = Stories.StoredItem(apiStoryItem: story, peerId: peerId, transaction: transaction) {
                                        if case .placeholder = storedItem, let previousEntry = previousPeerEntries.first(where: { $0.id == storedItem.id }) {
                                            updatedPeerEntries.append(previousEntry)
                                        } else {
                                            if let codedEntry = CodableEntry(storedItem) {
                                                updatedPeerEntries.append(StoryItemsTableEntry(value: codedEntry, id: storedItem.id))
                                            }
                                        }
                                    }
                                }
                                
                                transaction.setPeerStoryState(peerId: peerId, state: CodableEntry(Stories.PeerState(
                                    maxReadId: maxReadId ?? 0
                                )))
                            }
                            
                            updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                                return updated
                            })
                            updatePeerPresences(transaction: transaction, accountPeerId: account.peerId, peerPresences: peerPresences)
                        }
                        
                        transaction.setStoryItems(peerId: peerId, items: updatedPeerEntries)
                    }
                    |> ignoreValues
                }
            }).start(completed: { [weak self] in
                guard let `self` = self else {
                    return
                }
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
    }
    
    public final class State: Equatable {
        public let items: [Item]
        public let isCached: Bool
        public let maxReadId: Int32
        
        public init(items: [Item], isCached: Bool, maxReadId: Int32) {
            self.items = items
            self.isCached = isCached
            self.maxReadId = maxReadId
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
            return true
        }
        
        public var hasUnseen: Bool {
            for item in items {
                switch item {
                case let .item(item):
                    if item.id > maxReadId {
                        return true
                    }
                case let .placeholder(id, _, _):
                    if id > maxReadId {
                        return true
                    }
                }
            }
            return false
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
