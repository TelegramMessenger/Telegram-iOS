import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public final class EngineStoryViewListContext {
    public struct LoadMoreToken: Equatable {
        var value: String
    }
    
    public enum ListMode {
        case everyone
        case contacts
    }
    
    public enum SortMode {
        case reactionsFirst
        case recentFirst
    }
    
    public final class Item: Equatable {
        public let peer: EnginePeer
        public let timestamp: Int32
        public let storyStats: PeerStoryStats?
        public let reaction: MessageReaction.Reaction?
        public let reactionFile: TelegramMediaFile?
        
        public init(
            peer: EnginePeer,
            timestamp: Int32,
            storyStats: PeerStoryStats?,
            reaction: MessageReaction.Reaction?,
            reactionFile: TelegramMediaFile?
        ) {
            self.peer = peer
            self.timestamp = timestamp
            self.storyStats = storyStats
            self.reaction = reaction
            self.reactionFile = reactionFile
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
            if lhs.reaction != rhs.reaction {
                return false
            }
            if lhs.reactionFile?.fileId != rhs.reactionFile?.fileId {
                return false
            }
            return true
        }
    }
    
    public struct State: Equatable {
        public var totalCount: Int
        public var totalReactedCount: Int
        public var items: [Item]
        public var loadMoreToken: LoadMoreToken?
        
        public init(
            totalCount: Int,
            totalReactedCount: Int,
            items: [Item],
            loadMoreToken: LoadMoreToken?
        ) {
            self.totalCount = totalCount
            self.totalReactedCount = totalReactedCount
            self.items = items
            self.loadMoreToken = loadMoreToken
        }
    }
    
    private final class Impl {
        struct NextOffset: Equatable {
            var value: String
        }
        
        struct InternalState: Equatable {
            var totalCount: Int
            var totalReactedCount: Int
            var items: [Item]
            var canLoadMore: Bool
            var nextOffset: NextOffset?
        }
        
        let queue: Queue
        
        let account: Account
        let storyId: Int32
        let listMode: ListMode
        let sortMode: SortMode
        let searchQuery: String?
        
        let disposable = MetaDisposable()
        let storyStatsDisposable = MetaDisposable()
        
        var state: InternalState?
        let statePromise = Promise<InternalState>()
        
        private var parentSource: Impl?
        var isLoadingMore: Bool = false
        
        init(queue: Queue, account: Account, storyId: Int32, views: EngineStoryItem.Views, listMode: ListMode, sortMode: SortMode, searchQuery: String?, parentSource: Impl?) {
            self.queue = queue
            self.account = account
            self.storyId = storyId
            self.listMode = listMode
            self.sortMode = sortMode
            self.searchQuery = searchQuery
            
            if let parentSource = parentSource, (parentSource.listMode == .everyone || parentSource.listMode == listMode), let parentState = parentSource.state, parentState.totalCount <= 100 {
                self.parentSource = parentSource
                
                self.disposable.set((parentSource.statePromise.get()
                |> mapToSignal { state -> Signal<InternalState, NoError> in
                    let needUpdate: Signal<Void, NoError>
                    if listMode == .contacts {
                        var keys: [PostboxViewKey] = []
                        for item in state.items {
                            keys.append(.isContact(id: item.peer.id))
                        }
                        needUpdate = account.postbox.combinedView(keys: keys)
                        |> map { views -> [Bool] in
                            var result: [Bool] = []
                            for item in state.items {
                                if let view = views.views[.isContact(id: item.peer.id)] as? IsContactView {
                                    result.append(view.isContact)
                                }
                            }
                            return result
                        }
                        |> distinctUntilChanged
                        |> map { _ -> Void in
                            return Void()
                        }
                    } else {
                        needUpdate = .single(Void())
                    }
                    
                    return needUpdate
                    |> mapToSignal { _ -> Signal<InternalState, NoError> in
                        return account.postbox.transaction { transaction -> InternalState in
                            if state.canLoadMore {
                                return InternalState(
                                    totalCount: 0, totalReactedCount: 0, items: [], canLoadMore: true, nextOffset: state.nextOffset)
                            }
                            
                            var items: [Item] = []
                            switch listMode {
                            case .everyone:
                                items = state.items
                            case .contacts:
                                items = state.items.filter { item in
                                    return transaction.isPeerContact(peerId: item.peer.id)
                                }
                            }
                            if let searchQuery = searchQuery, !searchQuery.isEmpty {
                                let normalizedQuery = searchQuery.lowercased()
                                items = state.items.filter { item in
                                    return item.peer.indexName.matchesByTokens(normalizedQuery)
                                }
                            }
                            switch sortMode {
                            case .reactionsFirst:
                                items.sort(by: { lhs, rhs in
                                    if (lhs.reaction == nil) != (rhs.reaction == nil) {
                                        return lhs.reaction != nil
                                    }
                                    if lhs.timestamp != rhs.timestamp {
                                        return lhs.timestamp > rhs.timestamp
                                    }
                                    return lhs.peer.id < rhs.peer.id
                                })
                            case .recentFirst:
                                items.sort(by: { lhs, rhs in
                                    if lhs.timestamp != rhs.timestamp {
                                        return lhs.timestamp > rhs.timestamp
                                    }
                                    return lhs.peer.id < rhs.peer.id
                                })
                            }
                            
                            var totalReactedCount = 0
                            for item in items {
                                if item.reaction != nil {
                                    totalReactedCount += 1
                                }
                            }
                            
                            return InternalState(
                                totalCount: items.count, totalReactedCount: totalReactedCount, items: items, canLoadMore: false)
                        }
                    }
                }
                |> deliverOn(self.queue)).start(next: { [weak self] state in
                    guard let `self` = self else {
                        return
                    }
                    self.updateInternalState(state: state)
                }))
            } else {
                let initialState = State(totalCount: views.seenCount, totalReactedCount: views.reactedCount, items: [], loadMoreToken: LoadMoreToken(value: ""))
                let state = InternalState(totalCount: initialState.totalCount, totalReactedCount: initialState.totalReactedCount, items: initialState.items, canLoadMore: initialState.loadMoreToken != nil, nextOffset: nil)
                self.state = state
                self.statePromise.set(.single(state))
                
                if initialState.loadMoreToken != nil {
                    self.loadMore()
                }
            }
        }
        
        deinit {
            assert(self.queue.isCurrent())
            
            self.disposable.dispose()
            self.storyStatsDisposable.dispose()
        }
        
        func loadMore() {
            if let parentSource = self.parentSource {
                parentSource.loadMore()
                return
            }
            
            guard let state = self.state else {
                return
            }
            
            if !state.canLoadMore {
                return
            }
            if self.isLoadingMore {
                return
            }
            self.isLoadingMore = true
            
            let account = self.account
            let accountPeerId = account.peerId
            let storyId = self.storyId
            let listMode = self.listMode
            let sortMode = self.sortMode
            let searchQuery = self.searchQuery
            let currentOffset = state.nextOffset
            let limit = state.items.isEmpty ? 50 : 100
            let signal: Signal<InternalState, NoError> = self.account.postbox.transaction { transaction -> Void in
            }
            |> mapToSignal { _ -> Signal<InternalState, NoError> in
                var flags: Int32 = 0
                switch listMode {
                case .everyone:
                    break
                case .contacts:
                    flags |= (1 << 0)
                }
                switch sortMode {
                case .reactionsFirst:
                    flags |= (1 << 2)
                case .recentFirst:
                    break
                }
                if searchQuery != nil {
                    flags |= (1 << 1)
                }
                
                return account.network.request(Api.functions.stories.getStoryViewsList(flags: flags, q: searchQuery, id: storyId, offset: currentOffset?.value ?? "", limit: Int32(limit)))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stories.StoryViewsList?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<InternalState, NoError> in
                    return account.postbox.transaction { transaction -> InternalState in
                        switch result {
                        case let .storyViewsList(_, count, reactionsCount, views, users, nextOffset):
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                            
                            var items: [Item] = []
                            for view in views {
                                switch view {
                                case let .storyView(flags, userId, date, reaction):
                                    let isBlocked = (flags & (1 << 0)) != 0
                                    let isBlockedFromStories = (flags & (1 << 1)) != 0
                                                                        
                                    let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData in
                                        let previousData: CachedUserData
                                        if let current = cachedData as? CachedUserData {
                                            previousData = current
                                        } else {
                                            previousData = CachedUserData()
                                        }
                                        var updatedFlags = previousData.flags
                                        if isBlockedFromStories {
                                            updatedFlags.insert(.isBlockedFromStories)
                                        } else {
                                            updatedFlags.remove(.isBlockedFromStories)
                                        }
                                        return previousData.withUpdatedIsBlocked(isBlocked).withUpdatedFlags(updatedFlags)
                                    })
                                    if let peer = transaction.getPeer(peerId) {
                                        let parsedReaction = reaction.flatMap(MessageReaction.Reaction.init(apiReaction:))
                                        items.append(Item(
                                            peer: EnginePeer(peer),
                                            timestamp: date,
                                            storyStats: transaction.getPeerStoryStats(peerId: peerId),
                                            reaction: parsedReaction,
                                            reactionFile: parsedReaction.flatMap { reaction -> TelegramMediaFile? in
                                                switch reaction {
                                                case .builtin:
                                                    return nil
                                                case let .custom(fileId):
                                                    return transaction.getMedia(MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)) as? TelegramMediaFile
                                                }
                                            }
                                        ))
                                    }
                                }
                            }
                            
                            if listMode == .everyone, searchQuery == nil {
                                if let storedItem = transaction.getStory(id: StoryId(peerId: account.peerId, id: storyId))?.get(Stories.StoredItem.self), case let .item(item) = storedItem, let currentViews = item.views {
                                    let updatedItem: Stories.StoredItem = .item(Stories.Item(
                                        id: item.id,
                                        timestamp: item.timestamp,
                                        expirationTimestamp: item.expirationTimestamp,
                                        media: item.media,
                                        mediaAreas: item.mediaAreas,
                                        text: item.text,
                                        entities: item.entities,
                                        views: Stories.Item.Views(seenCount: Int(count), reactedCount: Int(reactionsCount), seenPeerIds: currentViews.seenPeerIds, hasList: currentViews.hasList),
                                        privacy: item.privacy,
                                        isPinned: item.isPinned,
                                        isExpired: item.isExpired,
                                        isPublic: item.isPublic,
                                        isCloseFriends: item.isCloseFriends,
                                        isContacts: item.isContacts,
                                        isSelectedContacts: item.isSelectedContacts,
                                        isForwardingDisabled: item.isForwardingDisabled,
                                        isEdited: item.isEdited,
                                        myReaction: item.myReaction
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
                                                mediaAreas: item.mediaAreas,
                                                text: item.text,
                                                entities: item.entities,
                                                views: Stories.Item.Views(seenCount: Int(count), reactedCount: Int(reactionsCount), seenPeerIds: currentViews.seenPeerIds, hasList: currentViews.hasList),
                                                privacy: item.privacy,
                                                isPinned: item.isPinned,
                                                isExpired: item.isExpired,
                                                isPublic: item.isPublic,
                                                isCloseFriends: item.isCloseFriends,
                                                isContacts: item.isContacts,
                                                isSelectedContacts: item.isSelectedContacts,
                                                isForwardingDisabled: item.isForwardingDisabled,
                                                isEdited: item.isEdited,
                                                myReaction: item.myReaction
                                            ))
                                            if let entry = CodableEntry(updatedItem) {
                                                currentItems[i] = StoryItemsTableEntry(value: entry, id: updatedItem.id, expirationTimestamp: updatedItem.expirationTimestamp, isCloseFriends: updatedItem.isCloseFriends)
                                            }
                                        }
                                    }
                                }
                                transaction.setStoryItems(peerId: account.peerId, items: currentItems)
                            }
                            
                            return InternalState(totalCount: Int(count), totalReactedCount: Int(reactionsCount), items: items, canLoadMore: nextOffset != nil, nextOffset: nextOffset.flatMap { NextOffset(value: $0) })
                        case .none:
                            return InternalState(totalCount: 0, totalReactedCount: 0, items: [], canLoadMore: false, nextOffset: nil)
                        }
                    }
                }
            }
            self.disposable.set((signal
            |> deliverOn(self.queue)).start(next: { [weak self] state in
                guard let `self` = self else {
                    return
                }
                self.updateInternalState(state: state)
            }))
        }
        
        private func updateInternalState(state: InternalState) {
            var currentState = self.state ?? InternalState(
                totalCount: 0, totalReactedCount: 0, items: [], canLoadMore: false, nextOffset: nil)
            
            struct ItemHash: Hashable {
                var peerId: EnginePeer.Id
            }
            
            if self.parentSource != nil {
                currentState.items.removeAll()
            }
            
            var existingItems = Set<ItemHash>()
            for item in currentState.items {
                existingItems.insert(ItemHash(peerId: item.peer.id))
            }
            
            for item in state.items {
                let itemHash = ItemHash(peerId: item.peer.id)
                if existingItems.contains(itemHash) {
                    continue
                }
                existingItems.insert(itemHash)
                currentState.items.append(item)
            }
            
            var allReactedCount = 0
            for item in currentState.items {
                if item.reaction != nil {
                    allReactedCount += 1
                } else {
                    break
                }
            }
            
            if state.canLoadMore {
                currentState.totalCount = max(state.totalCount, currentState.items.count)
                currentState.totalReactedCount = max(state.totalReactedCount, allReactedCount)
            } else {
                currentState.totalCount = currentState.items.count
                currentState.totalReactedCount = allReactedCount
            }
            currentState.canLoadMore = state.canLoadMore
            currentState.nextOffset = state.nextOffset
            
            self.isLoadingMore = false
            self.state = currentState
            self.statePromise.set(.single(currentState))
            
            let statsKey: PostboxViewKey = .peerStoryStats(peerIds: Set(currentState.items.map(\.peer.id)))
            self.storyStatsDisposable.set((self.account.postbox.combinedView(keys: [statsKey])
            |> deliverOn(self.queue)).start(next: { [weak self] views in
                guard let `self` = self, var state = self.state else {
                    return
                }
                guard let view = views.views[statsKey] as? PeerStoryStatsView else {
                    return
                }
                var updated = false
                var items = state.items
                for i in 0 ..< state.items.count {
                    let item = items[i]
                    let value = view.storyStats[item.peer.id]
                    if item.storyStats != value {
                        updated = true
                        items[i] = Item(
                            peer: item.peer,
                            timestamp: item.timestamp,
                            storyStats: value,
                            reaction: item.reaction,
                            reactionFile: item.reactionFile
                        )
                    }
                }
                if updated {
                    state.items = items
                    self.state = state
                    self.statePromise.set(.single(state))
                }
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
                        loadMoreToken = LoadMoreToken(value: nextOffset.value)
                    }
                    subscriber.putNext(State(
                        totalCount: state.totalCount,
                        totalReactedCount: state.totalReactedCount,
                        items: state.items,
                        loadMoreToken: loadMoreToken
                    ))
                }))
            }
            return disposable
        }
    }
    
    init(account: Account, storyId: Int32, views: EngineStoryItem.Views, listMode: ListMode, sortMode: SortMode, searchQuery: String?, parentSource: EngineStoryViewListContext?) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, storyId: storyId, views: views, listMode: listMode, sortMode: sortMode, searchQuery: searchQuery, parentSource: parentSource?.impl.syncWith { $0 })
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
}

