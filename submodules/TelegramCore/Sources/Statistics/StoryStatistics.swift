import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit

public struct StoryStats: Equatable {
    public let views: Int
    public let forwards: Int
    public let reactions: Int
    public let interactionsGraph: StatsGraph
    public let interactionsGraphDelta: Int64
    public let reactionsGraph: StatsGraph
    
    init(views: Int, forwards: Int, reactions: Int, interactionsGraph: StatsGraph, interactionsGraphDelta: Int64, reactionsGraph: StatsGraph) {
        self.views = views
        self.forwards = forwards
        self.reactions = reactions
        self.interactionsGraph = interactionsGraph
        self.interactionsGraphDelta = interactionsGraphDelta
        self.reactionsGraph = reactionsGraph
    }
    
    public static func == (lhs: StoryStats, rhs: StoryStats) -> Bool {
        if lhs.views != rhs.views {
            return false
        }
        if lhs.forwards != rhs.forwards {
            return false
        }
        if lhs.reactions != rhs.reactions {
            return false
        }
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
        return StoryStats(views: self.views, forwards: self.forwards, reactions: self.reactions, interactionsGraph: interactionsGraph, interactionsGraphDelta: self.interactionsGraphDelta, reactionsGraph: self.reactionsGraph)
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
        guard let (statsDatacenterId, peer) = data, let peerReference = PeerReference(peer) else {
            return .never()
        }
        return _internal_getStoriesById(accountPeerId: accountPeerId, postbox: postbox, network: network, peer: peerReference, ids: [storyId])
        |> mapToSignal { stories -> Signal<StoryStats?, NoError> in
            guard let storyItem = stories.first, case let .item(story) = storyItem, let inputPeer = apiInputPeer(peer) else {
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
            
            var views: Int = 0
            var forwards: Int = 0
            var reactions: Int = 0
            if let storyViews = story.views {
                views = storyViews.seenCount
                forwards = storyViews.forwardCount
                reactions = storyViews.reactedCount
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
                        views: views,
                        forwards: forwards,
                        reactions: reactions,
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

