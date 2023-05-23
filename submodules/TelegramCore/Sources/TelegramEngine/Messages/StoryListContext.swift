import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

enum InternalStoryUpdate {
    case deleted(peerId: PeerId, id: Int32)
    case added(peerId: PeerId, item: StoryListContext.Item)
    case read(peerId: PeerId, maxId: Int32)
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
        
        private var taskState = TaskState()
        
        private var isLoading: Bool = false
        
        private var loadedStateMark: OpaqueStateMark?
        private var stateDisposable: Disposable?
        private let loadMoreDisposable = MetaDisposable()
        private let refreshTimerDisposable = MetaDisposable()
        
        init(queue: Queue, accountPeerId: PeerId, postbox: Postbox, network: Network) {
            self.accountPeerId = accountPeerId
            self.queue = queue
            self.postbox = postbox
            self.network = network
            
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
            
            if self.taskState.isRefreshScheduled {
                self.isLoading = true
                
                self.stateDisposable = (postbox.combinedView(keys: [PostboxViewKey.storiesState(key: .subscriptions)])
                |> take(1)
                |> deliverOn(self.queue)).start(next: { [weak self] views in
                    guard let `self` = self else {
                        return
                    }
                    guard let storiesStateView = views.views[PostboxViewKey.storiesState(key: .subscriptions)] as? StoryStatesView else {
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
                
                self.stateDisposable = (postbox.combinedView(keys: [PostboxViewKey.storiesState(key: .subscriptions)])
                |> take(1)
                |> deliverOn(self.queue)).start(next: { [weak self] views in
                    guard let `self` = self else {
                        return
                    }
                    guard let storiesStateView = views.views[PostboxViewKey.storiesState(key: .subscriptions)] as? StoryStatesView else {
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
            var state: String?
            switch stateMark {
            case .empty:
                break
            case let .value(value):
                state = value
                flags |= 1 << 0
                
                if !isRefresh {
                    flags |= 1 << 1
                }
            }
            
            let accountPeerId = self.accountPeerId
            
            self.loadMoreDisposable.set((self.network.request(Api.functions.stories.getAllStories(flags: flags, state: state))
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let self else {
                    return
                }
                
                let _ = (self.postbox.transaction { transaction -> Void in
                    switch result {
                    case let .allStoriesNotModified(state):
                        self.loadedStateMark = .value(state)
                        let (currentStateValue, _) = transaction.getAllStorySubscriptions()
                        let currentState = currentStateValue.flatMap { $0.get(Stories.SubscriptionsState.self) }
                        
                        var hasMore = false
                        if let currentState = currentState {
                            hasMore = currentState.hasMore
                        }
                        
                        transaction.setSubscriptionsStoriesState(state: CodableEntry(Stories.SubscriptionsState(
                            opaqueState: state,
                            refreshId: currentState?.refreshId ?? UInt64.random(in: 0 ... UInt64.max),
                            hasMore: hasMore
                        )))
                    case let .allStories(flags, state, userStories, users):
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
                        
                        let hasMore: Bool = (flags & (1 << 0)) != 0
                        
                        let (_, currentPeerItems) = transaction.getAllStorySubscriptions()
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
                                    subscriptionsOpaqueState: state,
                                    maxReadId: maxReadId ?? 0
                                )))
                            }
                        }
                        
                        if !isRefresh {
                            let leftPeerIds = currentPeerItems.filter({ !peerEntries.contains($0) })
                            if !leftPeerIds.isEmpty {
                                peerEntries = leftPeerIds + peerEntries
                            }
                        }
                        
                        transaction.replaceAllStorySubscriptions(state: CodableEntry(Stories.SubscriptionsState(
                            opaqueState: state,
                            refreshId: UInt64.random(in: 0 ... UInt64.max),
                            hasMore: hasMore
                        )), peerIds: peerEntries)
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
    
    init(accountPeerId: PeerId, postbox: Postbox, network: Network) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            Impl(queue: queue, accountPeerId: accountPeerId, postbox: postbox, network: network)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
}

public final class PeerStoryFocusContext {
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let peerId: PeerId
        private let focusItemId: Int32?
        
        let state = Promise<State>()
        private var disposable: Disposable?
        
        private var isLoadingPlaceholder: Bool = false
        private let loadDisposable = MetaDisposable()
        private var placeholderLoadWasUnsuccessful: Bool = false
        
        init(
            queue: Queue,
            account: Account,
            peerId: PeerId,
            focusItemId: Int32?
        ) {
            self.queue = queue
            self.account = account
            self.peerId = peerId
            self.focusItemId = focusItemId
            
            self.disposable = (account.postbox.combinedView(keys: [
                PostboxViewKey.storiesState(key: .peer(peerId)),
                PostboxViewKey.storyItems(peerId: peerId)
            ])
            |> deliverOn(self.queue)).start(next: { [weak self] views in
                guard let `self` = self else {
                    return
                }
                guard let peerStateView = views.views[PostboxViewKey.storiesState(key: .peer(peerId))] as? StoryStatesView else {
                    return
                }
                guard let itemsView = views.views[PostboxViewKey.storyItems(peerId: peerId)] as? StoryItemsView else {
                    return
                }
                
                let peerState = peerStateView.value?.get(Stories.PeerState.self)
                
                let items = itemsView.items.compactMap { $0.value.get(Stories.StoredItem.self) }
                var item: (value: Stories.StoredItem, position: Int, previousId: Int32?, nextId: Int32?)?
                
                var focusItemId = self.focusItemId
                if focusItemId == nil {
                    if let peerState = peerState {
                        focusItemId = peerState.maxReadId + 1
                    }
                }
                
                if let focusItemId = focusItemId {
                    if let index = items.firstIndex(where: { $0.id >= focusItemId }) {
                        var previousId: Int32?
                        var nextId: Int32?
                        if index != 0 {
                            previousId = items[index - 1].id
                        }
                        if index != items.count - 1 {
                            nextId = items[index + 1].id
                        }
                        
                        item = (items[index], index, previousId, nextId)
                    } else {
                        if !items.isEmpty {
                            var nextId: Int32?
                            if 0 != items.count - 1 {
                                nextId = items[0 + 1].id
                            }
                            item = (items[0], 0, nil, nextId)
                        }
                    }
                } else {
                    if !items.isEmpty {
                        var nextId: Int32?
                        if 0 != items.count - 1 {
                            nextId = items[0 + 1].id
                        }
                        item = (items[0], 0, nil, nextId)
                    }
                }
                
                if let (item, position, previousId, nextId) = item {
                    switch item {
                    case let .item(item):
                        self.state.set(.single(State(item: item, previousId: previousId, nextId: nextId, isLoading: false, count: items.count, position: position)))
                    case .placeholder:
                        let count = items.count
                        
                        if !self.isLoadingPlaceholder {
                            self.isLoadingPlaceholder = true
                            self.loadDisposable.set((_internal_getStoriesById(
                                accountPeerId: self.account.peerId,
                                postbox: self.account.postbox,
                                network: self.account.network,
                                peerId: self.peerId,
                                ids: [item.id]
                            )
                            |> deliverOn(self.queue)).start(next: { [weak self] result in
                                guard let self else {
                                    return
                                }
                                if let loadedItem = result.first, case let .item(item) = loadedItem {
                                    self.state.set(.single(State(item: item, previousId: previousId, nextId: nextId, isLoading: false, count: count, position: position)))
                                } else {
                                    self.placeholderLoadWasUnsuccessful = false
                                    self.state.set(.single(State(item: nil, previousId: nil, nextId: nil, isLoading: !self.placeholderLoadWasUnsuccessful, count: count, position: position)))
                                }
                            }))
                        }
                        self.state.set(.single(State(item: nil, previousId: nil, nextId: nil, isLoading: !self.placeholderLoadWasUnsuccessful, count: count, position: position)))
                    }
                } else {
                    self.state.set(.single(State(item: nil, previousId: nil, nextId: nil, isLoading: false, count: 0, position: 0)))
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
            self.loadDisposable.dispose()
        }
    }
    
    public final class State: Equatable {
        public let item: Stories.Item?
        public let previousId: Int32?
        public let nextId: Int32?
        public let isLoading: Bool
        public let count: Int
        public let position: Int
        
        public init(
            item: Stories.Item?,
            previousId: Int32?,
            nextId: Int32?,
            isLoading: Bool,
            count: Int,
            position: Int
        ) {
            self.item = item
            self.previousId = previousId
            self.nextId = nextId
            self.isLoading = isLoading
            self.count = count
            self.position = position
        }
        
        public static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.item != rhs.item {
                return false
            }
            if lhs.previousId != rhs.previousId {
                return false
            }
            if lhs.nextId != rhs.nextId {
                return false
            }
            if lhs.isLoading != rhs.isLoading {
                return false
            }
            if lhs.count != rhs.count {
                return false
            }
            if lhs.position != rhs.position {
                return false
            }
            return true
        }
    }
    
    private static let sharedQueue = Queue(name: "PeerStoryFocusContext")
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.state.get().start(next: subscriber.putNext)
        }
    }
    
    init(
        account: Account,
        peerId: PeerId,
        focusItemId: Int32?
    ) {
        let queue = PeerStoryFocusContext.sharedQueue
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, peerId: peerId, focusItemId: focusItemId)
        })
    }
}

public final class StoryListContext {
    public enum Scope {
        case all
        case peer(EnginePeer.Id)
    }
    
    public struct Views: Equatable {
        public var seenCount: Int
        public var seenPeers: [EnginePeer]
        
        public init(seenCount: Int, seenPeers: [EnginePeer]) {
            self.seenCount = seenCount
            self.seenPeers = seenPeers
        }
    }
    
    public final class Item: Equatable {
        public let id: Int32
        public let timestamp: Int32
        public let media: EngineMedia
        public let text: String
        public let entities: [MessageTextEntity]
        public let views: Views?
        public let privacy: EngineStoryPrivacy?
        
        public init(id: Int32, timestamp: Int32, media: EngineMedia, text: String, entities: [MessageTextEntity], views: Views?, privacy: EngineStoryPrivacy?) {
            self.id = id
            self.timestamp = timestamp
            self.media = media
            self.text = text
            self.entities = entities
            self.views = views
            self.privacy = privacy
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.timestamp != rhs.timestamp {
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
            return true
        }
    }
    
    public final class PeerItemSet: Equatable {
        public let peerId: EnginePeer.Id
        public let peer: EnginePeer?
        public var maxReadId: Int32
        public fileprivate(set) var items: [Item]
        public fileprivate(set) var totalCount: Int?
        
        public init(peerId: EnginePeer.Id, peer: EnginePeer?, maxReadId: Int32, items: [Item], totalCount: Int?) {
            self.peerId = peerId
            self.peer = peer
            self.maxReadId = maxReadId
            self.items = items
            self.totalCount = totalCount
        }
        
        public static func ==(lhs: PeerItemSet, rhs: PeerItemSet) -> Bool {
            if lhs.peerId != rhs.peerId {
                return false
            }
            if lhs.peer != rhs.peer {
                return false
            }
            if lhs.maxReadId != rhs.maxReadId {
                return false
            }
            if lhs.items != rhs.items {
                return false
            }
            if lhs.totalCount != rhs.totalCount {
                return false
            }
            return true
        }
    }
    
    public final class LoadMoreToken: Equatable {
        fileprivate let value: String?
        
        init(value: String?) {
            self.value = value
        }
        
        public static func ==(lhs: LoadMoreToken, rhs: LoadMoreToken) -> Bool {
            if lhs.value != rhs.value {
                return false
            }
            return true
        }
    }
    
    public struct State: Equatable {
        public var itemSets: [PeerItemSet]
        public var uploadProgress: CGFloat?
        public var loadMoreToken: LoadMoreToken?
        
        public init(itemSets: [PeerItemSet], uploadProgress: CGFloat?, loadMoreToken: LoadMoreToken?) {
            self.itemSets = itemSets
            self.uploadProgress = uploadProgress
            self.loadMoreToken = loadMoreToken
        }
    }
    
    private final class UploadContext {
        let disposable = MetaDisposable()
        
        init() {
        }
    }
    
    private final class Impl {
        private let queue: Queue
        private let account: Account
        private let scope: Scope
        
        private let loadMoreDisposable = MetaDisposable()
        private var isLoadingMore = false
        
        private var pollDisposable: Disposable?
        private var updatesDisposable: Disposable?
        private var peerDisposables: [PeerId: Disposable] = [:]
        
        private var uploadContexts: [UploadContext] = [] {
            didSet {
                self.stateValue.uploadProgress = self.uploadContexts.isEmpty ? nil : 0.0
            }
        }
        
        private var stateValue: State {
            didSet {
                self.state.set(.single(self.stateValue))
            }
        }
        let state = Promise<State>()
        
        init(queue: Queue, account: Account, scope: Scope) {
            self.queue = queue
            self.account = account
            self.scope = scope
            
            self.stateValue = State(itemSets: [], uploadProgress: nil, loadMoreToken: LoadMoreToken(value: nil))
            self.state.set(.single(self.stateValue))
            
            if case .all = scope {
                let _ = (account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(account.peerId)
                }
                |> deliverOnMainQueue).start(next: { [weak self] peer in
                    guard let `self` = self, let peer = peer else {
                        return
                    }
                    self.stateValue = State(itemSets: [
                        PeerItemSet(peerId: peer.id, peer: EnginePeer(peer), maxReadId: 0, items: [], totalCount: 0)
                    ], uploadProgress: nil, loadMoreToken: LoadMoreToken(value: nil))
                })
            }
            
            self.updatesDisposable = (account.stateManager.storyUpdates
            |> deliverOn(queue)).start(next: { [weak self] updates in
                if updates.isEmpty {
                    return
                }
                
                let _ = account.postbox.transaction({ transaction -> [PeerId: Peer] in
                    var peers: [PeerId: Peer] = [:]
                    
                    if let peer = transaction.getPeer(account.peerId) {
                        peers[peer.id] = peer
                    }
                    
                    for update in updates {
                        switch update {
                        case let .added(peerId, _):
                            if peers[peerId] == nil, let peer = transaction.getPeer(peerId) {
                                peers[peer.id] = peer
                            }
                        case .deleted:
                            break
                        case .read:
                            break
                        }
                    }
                    return peers
                }).start(next: { peers in
                    guard let `self` = self else {
                        return
                    }
                    if self.isLoadingMore {
                        return
                    }
                    
                    var itemSets: [PeerItemSet] = self.stateValue.itemSets
                    
                    for update in updates {
                        switch update {
                        case let .deleted(peerId, id):
                            for i in 0 ..< itemSets.count {
                                if itemSets[i].peerId == peerId {
                                    if let index = itemSets[i].items.firstIndex(where: { $0.id == id }) {
                                        var items = itemSets[i].items
                                        items.remove(at: index)
                                        itemSets[i] = PeerItemSet(
                                            peerId: itemSets[i].peerId,
                                            peer: itemSets[i].peer,
                                            maxReadId: itemSets[i].maxReadId,
                                            items: items,
                                            totalCount: items.count
                                        )
                                    }
                                }
                            }
                        case let .added(peerId, item):
                            var found = false
                            for i in 0 ..< itemSets.count {
                                if itemSets[i].peerId == peerId {
                                    found = true
                                    
                                    var items = itemSets[i].items
                                    if let index = items.firstIndex(where: { $0.id == item.id }) {
                                        items.remove(at: index)
                                    }
                                    
                                    items.append(item)
                                    
                                    items.sort(by: { lhsItem, rhsItem in
                                        if lhsItem.timestamp != rhsItem.timestamp {
                                            switch scope {
                                            case .all:
                                                return lhsItem.timestamp < rhsItem.timestamp
                                            case .peer:
                                                return lhsItem.timestamp < rhsItem.timestamp
                                            }
                                        }
                                        return lhsItem.id < rhsItem.id
                                    })
                                    itemSets[i] = PeerItemSet(
                                        peerId: itemSets[i].peerId,
                                        peer: itemSets[i].peer,
                                        maxReadId: itemSets[i].maxReadId,
                                        items: items,
                                        totalCount: items.count
                                    )
                                }
                            }
                            if !found, let peer = peers[peerId] {
                                let matchesScope: Bool
                                if case .all = scope {
                                    matchesScope = true
                                } else if case .peer(peerId) = scope {
                                    matchesScope = true
                                } else {
                                    matchesScope = false
                                }
                                if matchesScope {
                                    itemSets.insert(PeerItemSet(
                                        peerId: peerId,
                                        peer: EnginePeer(peer),
                                        maxReadId: 0,
                                        items: [item],
                                        totalCount: 1
                                    ), at: 0)
                                }
                            }
                        case let .read(peerId, maxId):
                            for i in 0 ..< itemSets.count {
                                if itemSets[i].peerId == peerId {
                                    let items = itemSets[i].items
                                    itemSets[i] = PeerItemSet(
                                        peerId: itemSets[i].peerId,
                                        peer: itemSets[i].peer,
                                        maxReadId: max(itemSets[i].maxReadId, maxId),
                                        items: items,
                                        totalCount: items.count
                                    )
                                }
                            }
                        }
                    }
                    
                    itemSets.sort(by: { lhs, rhs in
                        guard let lhsItem = lhs.items.last, let rhsItem = rhs.items.last else {
                            if lhs.items.first != nil {
                                return false
                            } else {
                                return true
                            }
                        }
                        
                        if lhsItem.timestamp != rhsItem.timestamp {
                            switch scope {
                            case .all:
                                return lhsItem.timestamp > rhsItem.timestamp
                            case .peer:
                                return lhsItem.timestamp < rhsItem.timestamp
                            }
                        }
                        return lhsItem.id > rhsItem.id
                    })
                    
                    if !itemSets.contains(where: { $0.peerId == self.account.peerId }) {
                        if let peer = peers[self.account.peerId] {
                            itemSets.insert(PeerItemSet(peerId: peer.id, peer: EnginePeer(peer), maxReadId: 0, items: [], totalCount: 0), at: 0)
                        }
                    }
                    
                    self.stateValue.itemSets = itemSets
                })
            })
            
            self.loadMore(refresh: true)
        }
        
        deinit {
            self.loadMoreDisposable.dispose()
            self.pollDisposable?.dispose()
            for (_, disposable) in self.peerDisposables {
                disposable.dispose()
            }
        }
        
        func loadPeer(id: EnginePeer.Id) {
            if self.peerDisposables[id] == nil {
                let disposable = MetaDisposable()
                self.peerDisposables[id] = disposable
                
                let account = self.account
                let queue = self.queue
                
                disposable.set((self.account.postbox.transaction { transaction -> Api.InputUser? in
                    return transaction.getPeer(id).flatMap(apiInputUser)
                }
                |> mapToSignal { inputPeer -> Signal<PeerItemSet?, NoError> in
                    guard let inputPeer = inputPeer else {
                        return .single(nil)
                    }
                    return account.network.request(Api.functions.stories.getUserStories(flags: 0, userId: inputPeer, offsetId: 0, limit: 30))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { stories -> Signal<PeerItemSet?, NoError> in
                        guard let stories = stories else {
                            return .single(nil)
                        }
                        return account.postbox.transaction { transaction -> PeerItemSet? in
                            switch stories {
                            case let .stories(_, apiStories, users):
                                var parsedItemSets: [PeerItemSet] = []
                                
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
                                
                                let peerId = id
                                
                                for apiStory in apiStories {
                                    if let item = _internal_parseApiStoryItem(transaction: transaction, peerId: peerId, apiStory: apiStory) {
                                        if !parsedItemSets.isEmpty && parsedItemSets[parsedItemSets.count - 1].peerId == peerId {
                                            parsedItemSets[parsedItemSets.count - 1].items.append(item)
                                            parsedItemSets[parsedItemSets.count - 1].totalCount = parsedItemSets[parsedItemSets.count - 1].items.count
                                        } else {
                                            parsedItemSets.append(StoryListContext.PeerItemSet(peerId: peerId, peer: transaction.getPeer(peerId).flatMap(EnginePeer.init), maxReadId: 0, items: [item], totalCount: 1))
                                        }
                                    }
                                }
                                
                                return parsedItemSets.first
                            }
                        }
                    }
                }
                |> deliverOn(queue)).start(next: { [weak self] itemSet in
                    guard let `self` = self, let itemSet = itemSet else {
                        return
                    }
                    var itemSets = self.stateValue.itemSets
                    if let index = itemSets.firstIndex(where: { $0.peerId == id }) {
                        itemSets[index] = itemSet
                    } else {
                        itemSets.append(itemSet)
                    }
                    self.stateValue.itemSets = itemSets
                }))
            }
        }
        
        func upload(media: EngineStoryInputMedia, text: String, entities: [MessageTextEntity], privacy: EngineStoryPrivacy) {
            let uploadContext = UploadContext()
            self.uploadContexts.append(uploadContext)
            uploadContext.disposable.set((_internal_uploadStory(account: self.account, media: media, text: text, entities: entities, privacy: privacy)
            |> deliverOn(self.queue)).start(next: { _ in
            }, completed: { [weak self, weak uploadContext] in
                guard let `self` = self, let uploadContext = uploadContext else {
                    return
                }
                if let index = self.uploadContexts.firstIndex(where: { $0 === uploadContext }) {
                    self.uploadContexts.remove(at: index)
                }
            }))
        }
        
        func loadMore(refresh: Bool) {
            if self.isLoadingMore {
                return
            }
            
            var effectiveLoadMoreToken: String?
            if refresh {
                effectiveLoadMoreToken = ""
            } else if let loadMoreToken = self.stateValue.loadMoreToken {
                effectiveLoadMoreToken = loadMoreToken.value ?? ""
            }
            guard let loadMoreToken = effectiveLoadMoreToken else {
                return
            }
            let _ = loadMoreToken
            
            self.isLoadingMore = true
            let account = self.account
            let scope = self.scope
            
            self.pollDisposable?.dispose()
            self.pollDisposable = nil
            
            switch scope {
            case .all:
                self.loadMoreDisposable.set((account.network.request(Api.functions.stories.getAllStories(flags: 0, state: nil))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stories.AllStories?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([PeerItemSet], LoadMoreToken?), NoError> in
                    guard let result = result else {
                        return .single(([], nil))
                    }
                    return account.postbox.transaction { transaction -> ([PeerItemSet], LoadMoreToken?) in
                        switch result {
                        case let .allStories(_, state, userStorySets, users):
                            let _ = state
                            var parsedItemSets: [PeerItemSet] = []
                            
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
                            
                            for userStories in userStorySets {
                                let apiUserId: Int64
                                let apiStories: [Api.StoryItem]
                                var apiTotalCount: Int32?
                                var apiMaxReadId: Int32 = 0
                                switch userStories {
                                case let .userStories(_, userId, maxReadId, stories):
                                    apiUserId = userId
                                    apiStories = stories
                                    apiTotalCount = Int32(stories.count)
                                    apiMaxReadId = maxReadId ?? 0
                                }
                                
                                let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(apiUserId))
                                for apiStory in apiStories {
                                    if let item = _internal_parseApiStoryItem(transaction: transaction, peerId: peerId, apiStory: apiStory) {
                                        if !parsedItemSets.isEmpty && parsedItemSets[parsedItemSets.count - 1].peerId == peerId {
                                            parsedItemSets[parsedItemSets.count - 1].items.append(item)
                                        } else {
                                            parsedItemSets.append(StoryListContext.PeerItemSet(
                                                peerId: peerId,
                                                peer: transaction.getPeer(peerId).flatMap(EnginePeer.init),
                                                maxReadId: apiMaxReadId,
                                                items: [item],
                                                totalCount: apiTotalCount.flatMap(Int.init)
                                            ))
                                        }
                                    }
                                }
                            }
                            
                            if !parsedItemSets.contains(where: { $0.peerId == account.peerId }) {
                                if let peer = transaction.getPeer(account.peerId) {
                                    parsedItemSets.insert(PeerItemSet(peerId: peer.id, peer: EnginePeer(peer), maxReadId: 0, items: [], totalCount: 0), at: 0)
                                }
                            }
                            
                            return (parsedItemSets, nil)
                        case .allStoriesNotModified:
                            return ([], nil)
                        }
                    }
                }
                |> deliverOn(self.queue)).start(next: { [weak self] result in
                    guard let `self` = self else {
                        return
                    }
                    self.isLoadingMore = false
                    
                    var itemSets = self.stateValue.itemSets
                    for itemSet in result.0 {
                        if let index = itemSets.firstIndex(where: { $0.peerId == itemSet.peerId }) {
                            let currentItemSet = itemSets[index]
                            
                            var items = currentItemSet.items
                            for item in itemSet.items {
                                if !items.contains(where: { $0.id == item.id }) {
                                    items.append(item)
                                }
                            }
                            
                            items.sort(by: { lhsItem, rhsItem in
                                if lhsItem.timestamp != rhsItem.timestamp {
                                    switch scope {
                                    case .all:
                                        return lhsItem.timestamp < rhsItem.timestamp
                                    case .peer:
                                        return lhsItem.timestamp < rhsItem.timestamp
                                    }
                                }
                                return lhsItem.id < rhsItem.id
                            })
                            
                            itemSets[index] = PeerItemSet(
                                peerId: itemSet.peerId,
                                peer: itemSet.peer,
                                maxReadId: itemSet.maxReadId,
                                items: items,
                                totalCount: items.count
                            )
                        } else {
                            itemSet.items.sort(by: { lhsItem, rhsItem in
                                if lhsItem.timestamp != rhsItem.timestamp {
                                    switch scope {
                                    case .all:
                                        return lhsItem.timestamp < rhsItem.timestamp
                                    case .peer:
                                        return lhsItem.timestamp < rhsItem.timestamp
                                    }
                                }
                                return lhsItem.id < rhsItem.id
                            })
                            itemSets.append(itemSet)
                        }
                    }
                    
                    itemSets.sort(by: { lhs, rhs in
                        guard let lhsItem = lhs.items.last, let rhsItem = rhs.items.last else {
                            if lhs.items.last != nil {
                                return false
                            } else {
                                return true
                            }
                        }
                        
                        if lhsItem.timestamp != rhsItem.timestamp {
                            switch scope {
                            case .all:
                                return lhsItem.timestamp > rhsItem.timestamp
                            case .peer:
                                return lhsItem.timestamp < rhsItem.timestamp
                            }
                        }
                        return lhsItem.id > rhsItem.id
                    })
                    
                    self.stateValue = State(itemSets: itemSets, uploadProgress: self.stateValue.uploadProgress, loadMoreToken: result.1)
                }))
            case let .peer(peerId):
                let account = self.account
                let queue = self.queue
                
                self.loadMoreDisposable.set((self.account.postbox.transaction { transaction -> Api.InputUser? in
                    return transaction.getPeer(peerId).flatMap(apiInputUser)
                }
                |> mapToSignal { inputPeer -> Signal<PeerItemSet?, NoError> in
                    guard let inputPeer = inputPeer else {
                        return .single(nil)
                    }
                    return account.network.request(Api.functions.stories.getUserStories(flags: 0, userId: inputPeer, offsetId: 0, limit: 30))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.stories.Stories?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { stories -> Signal<PeerItemSet?, NoError> in
                        guard let stories = stories else {
                            return .single(nil)
                        }
                        return account.postbox.transaction { transaction -> PeerItemSet? in
                            switch stories {
                            case let .stories(_, apiStories, users):
                                var parsedItemSets: [PeerItemSet] = []
                                
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
                                
                                for apiStory in apiStories {
                                    if let item = _internal_parseApiStoryItem(transaction: transaction, peerId: peerId, apiStory: apiStory) {
                                        if !parsedItemSets.isEmpty && parsedItemSets[parsedItemSets.count - 1].peerId == peerId {
                                            parsedItemSets[parsedItemSets.count - 1].items.append(item)
                                            parsedItemSets[parsedItemSets.count - 1].totalCount = parsedItemSets[parsedItemSets.count - 1].items.count
                                        } else {
                                            parsedItemSets.append(StoryListContext.PeerItemSet(peerId: peerId, peer: transaction.getPeer(peerId).flatMap(EnginePeer.init), maxReadId: 0, items: [item], totalCount: 1))
                                        }
                                    }
                                }
                                
                                return parsedItemSets.first
                            }
                        }
                    }
                }
                |> deliverOn(queue)).start(next: { [weak self] itemSet in
                    guard let `self` = self, let itemSet = itemSet else {
                        return
                    }
                    self.isLoadingMore = false
                    self.stateValue.itemSets = [itemSet]
                }))
            }
        }
        
        func delete(id: Int32) {
            let _ = _internal_deleteStory(account: self.account, id: id).start()
            
            var itemSets: [PeerItemSet] = self.stateValue.itemSets
            for i in (0 ..< itemSets.count).reversed() {
                if let index = itemSets[i].items.firstIndex(where: { $0.id == id }) {
                    var items = itemSets[i].items
                    items.remove(at: index)
                    if items.isEmpty {
                        itemSets.remove(at: i)
                    } else {
                        itemSets[i] = PeerItemSet(
                            peerId: itemSets[i].peerId,
                            peer: itemSets[i].peer,
                            maxReadId: itemSets[i].maxReadId,
                            items: items,
                            totalCount: items.count
                        )
                    }
                }
            }
            self.stateValue.itemSets = itemSets
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public var state: Signal<State, NoError> {
        return self.impl.signalWith { impl, subscriber in
            return impl.state.get().start(next: subscriber.putNext)
        }
    }
    
    init(account: Account, scope: Scope) {
        let queue = Queue.mainQueue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, account: account, scope: scope)
        })
    }
    
    public func delete(id: Int32) {
        self.impl.with { impl in
            impl.delete(id: id)
        }
    }
    
    public func upload(media: EngineStoryInputMedia, text: String, entities: [MessageTextEntity], privacy: EngineStoryPrivacy) {
        self.impl.with { impl in
            impl.upload(media: media, text: text, entities: entities, privacy: privacy)
        }
    }
    
    public func loadPeer(id: EnginePeer.Id) {
        self.impl.with { impl in
            impl.loadPeer(id: id)
        }
    }
}
