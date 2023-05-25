import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

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
    
    public static func ==(lhs: EngineStoryItem, rhs: EngineStoryItem) -> Bool {
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
                    case let .allStories(flags, _, state, userStories, users):
                        //TODO:count
                        
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
