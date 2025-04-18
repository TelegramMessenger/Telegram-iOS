import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit

public struct StoryStats: Equatable {
    public let interactionsGraph: StatsGraph
    public let interactionsGraphDelta: Int64
    public let reactionsGraph: StatsGraph
    
    init(interactionsGraph: StatsGraph, interactionsGraphDelta: Int64, reactionsGraph: StatsGraph) {
        self.interactionsGraph = interactionsGraph
        self.interactionsGraphDelta = interactionsGraphDelta
        self.reactionsGraph = reactionsGraph
    }
    
    public static func == (lhs: StoryStats, rhs: StoryStats) -> Bool {
        if lhs.interactionsGraph != rhs.interactionsGraph {
            return false
        }
        if lhs.interactionsGraphDelta != rhs.interactionsGraphDelta {
            return false
        }
        if lhs.reactionsGraph != rhs.reactionsGraph {
            return false
        }
        return true
    }
    
    public func withUpdatedInteractionsGraph(_ interactionsGraph: StatsGraph) -> StoryStats {
        return StoryStats(interactionsGraph: interactionsGraph, interactionsGraphDelta: self.interactionsGraphDelta, reactionsGraph: self.reactionsGraph)
    }
}

public struct StoryStatsContextState: Equatable {
    public var stats: StoryStats?
}

private func requestStoryStats(accountPeerId: PeerId, postbox: Postbox, network: Network, peerId: EnginePeer.Id, storyId: Int32, dark: Bool = false) -> Signal<StoryStats?, NoError> {
    return postbox.transaction { transaction -> (Int32, Peer)? in
        if let peer = transaction.getPeer(peerId), let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData  {
            return (cachedData.statsDatacenterId, peer)
        } else {
            return nil
        }
    }
    |> mapToSignal { data -> Signal<StoryStats?, NoError> in
        guard let (statsDatacenterId, peer) = data, let inputPeer = apiInputPeer(peer) else {
            return .never()
        }
        var flags: Int32 = 0
        if dark {
            flags |= (1 << 1)
        }
        
        let request = Api.functions.stats.getStoryStats(flags: flags, peer: inputPeer, id: storyId)
        let signal: Signal<Api.stats.StoryStats, MTRpcError>
        if network.datacenterId != statsDatacenterId {
            signal = network.download(datacenterId: Int(statsDatacenterId), isMedia: false, tag: nil)
            |> castError(MTRpcError.self)
            |> mapToSignal { worker in
                return worker.request(request)
            }
        } else {
            signal = network.request(request)
        }
        
        return signal
        |> mapToSignal { result -> Signal<StoryStats?, MTRpcError> in
            if case let .storyStats(apiInteractionsGraph, apiReactionsGraph) = result {
                let interactionsGraph = StatsGraph(apiStatsGraph: apiInteractionsGraph)
                var interactionsGraphDelta: Int64 = 86400
                if case let .Loaded(_, data) = interactionsGraph {
                    if let start = data.range(of: "[\"x\",") {
                        let substring = data.suffix(from: start.upperBound)
                        if let end = substring.range(of: "],") {
                            let valuesString = substring.prefix(through: substring.index(before: end.lowerBound))
                            let values = valuesString.components(separatedBy: ",").compactMap { Int64($0) }
                            if values.count > 1 {
                                let first = values[0]
                                let second = values[1]
                                let delta = abs(second - first) / 1000
                                interactionsGraphDelta = delta
                            }
                        }
                    }
                }
                let reactionsGraph = StatsGraph(apiStatsGraph: apiReactionsGraph)
                return .single(StoryStats(
                    interactionsGraph: interactionsGraph,
                    interactionsGraphDelta: interactionsGraphDelta,
                    reactionsGraph: reactionsGraph
                ))
            } else {
                return .single(nil)
            }
        }
        |> retryRequest
    }
}

private final class StoryStatsContextImpl {
    private let accountPeerId: EnginePeer.Id
    private let postbox: Postbox
    private let network: Network
    private let peerId: EnginePeer.Id
    private let storyId: Int32
    
    private var _state: StoryStatsContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<StoryStatsContextState>()
    var state: Signal<StoryStatsContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    private let disposables = DisposableDict<String>()
    
    init(accountPeerId: EnginePeer.Id, postbox: Postbox, network: Network, peerId: EnginePeer.Id, storyId: Int32) {
        assert(Queue.mainQueue().isCurrent())
        
        self.accountPeerId = accountPeerId
        self.postbox = postbox
        self.network = network
        self.peerId = peerId
        self.storyId = storyId
        self._state = StoryStatsContextState(stats: nil)
        self._statePromise.set(.single(self._state))
        
        self.load()
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
        self.disposables.dispose()
    }
    
    private func load() {
        assert(Queue.mainQueue().isCurrent())
        
        self.disposable.set((requestStoryStats(accountPeerId: self.accountPeerId, postbox: self.postbox, network: self.network, peerId: self.peerId, storyId: self.storyId)
        |> deliverOnMainQueue).start(next: { [weak self] stats in
            if let strongSelf = self {
                strongSelf._state = StoryStatsContextState(stats: stats)
                strongSelf._statePromise.set(.single(strongSelf._state))
            }
        }))
    }
    
    func loadDetailedGraph(_ graph: StatsGraph, x: Int64) -> Signal<StatsGraph?, NoError> {
        if let token = graph.token {
            return requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token, x: x)
        } else {
            return .single(nil)
        }
    }
}

public final class StoryStatsContext {
    private let impl: QueueLocalObject<StoryStatsContextImpl>
    
    public var state: Signal<StoryStatsContextState, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.state.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public init(account: Account, peerId: EnginePeer.Id, storyId: Int32) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return StoryStatsContextImpl(accountPeerId: account.peerId, postbox: account.postbox, network: account.network, peerId: peerId, storyId: storyId)
        })
    }
        
    public func loadDetailedGraph(_ graph: StatsGraph, x: Int64) -> Signal<StatsGraph?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.loadDetailedGraph(graph, x: x).start(next: { value in
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
}

private final class StoryStatsPublicForwardsContextImpl {
    private let queue: Queue
    private let account: Account
    private let subject: StoryStatsPublicForwardsContext.Subject
    private let disposable = MetaDisposable()
    private var isLoadingMore: Bool = false
    private var hasLoadedOnce: Bool = false
    private var canLoadMore: Bool = true
    private var results: [StoryStatsPublicForwardsContext.State.Forward] = []
    private var count: Int32
    private var lastOffset: String?
    
    let state = Promise<StoryStatsPublicForwardsContext.State>()
    
    init(queue: Queue, account: Account, subject: StoryStatsPublicForwardsContext.Subject) {
        self.queue = queue
        self.account = account
        self.subject = subject
                
        self.count = 0
            
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func reload() {
        self.loadMore()
    }
    
    func loadMore() {
        if self.isLoadingMore || !self.canLoadMore {
            return
        }
        self.isLoadingMore = true
        let account = self.account
        let accountPeerId = account.peerId
        let subject = self.subject
        let lastOffset = self.lastOffset
        
        self.disposable.set((self.account.postbox.transaction { transaction -> (Peer, Int32?)? in
            let peerId: PeerId
            switch subject {
            case let .story(peerIdValue, _):
                peerId = peerIdValue
            case let .message(messageId):
                peerId = messageId.peerId
            }
            let statsDatacenterId = (transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData)?.statsDatacenterId
            guard let peer = transaction.getPeer(peerId) else {
                return nil
            }
            return (peer, statsDatacenterId)
        }
        |> mapToSignal { data -> Signal<([StoryStatsPublicForwardsContext.State.Forward], Int32, String?), NoError> in
            if let (peer, statsDatacenterId) = data {
                let offset = lastOffset ?? ""
                
                let request: (FunctionDescription, Buffer, DeserializeFunctionResponse<Api.stats.PublicForwards>)
                switch subject {
                case let .story(_, id):
                    guard let inputPeer = apiInputPeer(peer) else {
                        return .complete()
                    }
                    request = Api.functions.stats.getStoryPublicForwards(peer: inputPeer, id: id, offset: offset, limit: 50)
                case let .message(messageId):
                    guard let inputChannel = apiInputChannel(peer) else {
                        return .complete()
                    }
                    request = Api.functions.stats.getMessagePublicForwards(channel: inputChannel, msgId: messageId.id, offset: offset, limit: 50)
                }

                let signal: Signal<Api.stats.PublicForwards, MTRpcError>
                if let statsDatacenterId = statsDatacenterId, account.network.datacenterId != statsDatacenterId {
                    signal = account.network.download(datacenterId: Int(statsDatacenterId), isMedia: false, tag: nil)
                    |> castError(MTRpcError.self)
                    |> mapToSignal { worker in
                        return worker.request(request)
                    }
                } else {
                    signal = account.network.request(request, automaticFloodWait: false)
                }
                
                return signal
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stats.PublicForwards?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([StoryStatsPublicForwardsContext.State.Forward], Int32, String?), NoError> in
                    return account.postbox.transaction { transaction -> ([StoryStatsPublicForwardsContext.State.Forward], Int32, String?) in
                        guard let result = result else {
                            return ([], 0, nil)
                        }
                        switch result {
                        case let .publicForwards(_, count, forwards, nextOffset, chats, users):
                            var peers: [PeerId: Peer] = [:]
                            for user in users {
                                if let user = TelegramUser.merge(transaction.getPeer(user.peerId) as? TelegramUser, rhs: user) {
                                    peers[user.id] = user
                                }
                            }
                            for chat in chats {
                                if let groupOrChannel = mergeGroupOrChannel(lhs: transaction.getPeer(chat.peerId), rhs: chat) {
                                    peers[groupOrChannel.id] = groupOrChannel
                                }
                            }
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(peers: Array(peers.values)))
                            var resultForwards: [StoryStatsPublicForwardsContext.State.Forward] = []
                            for forward in forwards {
                                switch forward {
                                case let .publicForwardMessage(apiMessage):
                                    if let message = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: false), let renderedMessage = locallyRenderedMessage(message: message, peers: peers) {
                                        resultForwards.append(.message(EngineMessage(renderedMessage)))
                                    }
                                case let .publicForwardStory(apiPeer, apiStory):
                                    if let storedItem = Stories.StoredItem(apiStoryItem: apiStory, peerId: apiPeer.peerId, transaction: transaction), case let .item(item) = storedItem, let media = item.media, let peer = peers[apiPeer.peerId] {
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
                                        resultForwards.append(.story(EnginePeer(peer), mappedItem))
                                    }
                                }
                            }
                            return (resultForwards, count, nextOffset)
                        }
                    }
                }
            } else {
                return .single(([], 0, nil))
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] forwards, updatedCount, nextOffset in
            guard let strongSelf = self else {
                return
            }
            strongSelf.lastOffset = nextOffset
            for forward in forwards {
                strongSelf.results.append(forward)
            }
            strongSelf.isLoadingMore = false
            strongSelf.hasLoadedOnce = true
            strongSelf.canLoadMore = !forwards.isEmpty && nextOffset != nil
            if strongSelf.canLoadMore {
                strongSelf.count = max(updatedCount, Int32(strongSelf.results.count))
            } else {
                strongSelf.count = Int32(strongSelf.results.count)
            }
            strongSelf.updateState()
        }))
        self.updateState()
    }
        
    private func updateState() {
        self.state.set(.single(StoryStatsPublicForwardsContext.State(forwards: self.results, isLoadingMore: self.isLoadingMore, hasLoadedOnce: self.hasLoadedOnce, canLoadMore: self.canLoadMore, count: self.count)))
    }
}

public final class StoryStatsPublicForwardsContext {
    public struct State: Equatable {
        public enum Forward: Equatable {
            case message(EngineMessage)
            case story(EnginePeer, EngineStoryItem)
        }
        public var forwards: [Forward]
        public var isLoadingMore: Bool
        public var hasLoadedOnce: Bool
        public var canLoadMore: Bool
        public var count: Int32
        
        public static var Empty = State(forwards: [], isLoadingMore: false, hasLoadedOnce: true, canLoadMore: false, count: 0)
        public static var Loading = State(forwards: [], isLoadingMore: false, hasLoadedOnce: false, canLoadMore: false, count: 0)
    }

    
    private let queue: Queue = Queue()
    private let impl: QueueLocalObject<StoryStatsPublicForwardsContextImpl>
    
    public var state: Signal<State, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.state.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public enum Subject {
        case story(peerId: EnginePeer.Id, id: Int32)
        case message(messageId: EngineMessage.Id)
    }
    
    public init(account: Account, subject: Subject) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return StoryStatsPublicForwardsContextImpl(queue: queue, account: account, subject: subject)
        })
    }
    
    public func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    public func reload() {
        self.impl.with { impl in
            impl.reload()
        }
    }
}

