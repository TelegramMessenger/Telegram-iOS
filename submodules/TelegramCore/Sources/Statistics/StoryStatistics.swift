import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit

public struct StoryStats: Equatable {
    public let views: Int
    public let forwards: Int
    public let interactionsGraph: StatsGraph
    public let interactionsGraphDelta: Int64
    public let reactionsGraph: StatsGraph
    
    init(views: Int, forwards: Int, interactionsGraph: StatsGraph, interactionsGraphDelta: Int64, reactionsGraph: StatsGraph) {
        self.views = views
        self.forwards = forwards
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
        return StoryStats(views: self.views, forwards: self.forwards, interactionsGraph: interactionsGraph, interactionsGraphDelta: self.interactionsGraphDelta, reactionsGraph: self.reactionsGraph)
    }
}

public struct StoryStatsContextState: Equatable {
    public var stats: StoryStats?
}

private func requestStoryStats(postbox: Postbox, network: Network, datacenterId: Int32, peerId: EnginePeer.Id, storyId: Int32, dark: Bool = false) -> Signal<StoryStats?, NoError> {
    return postbox.transaction { transaction -> Peer? in
        if let peer = transaction.getPeer(peerId) {
            return peer
        } else {
            return nil
        }
    } |> mapToSignal { peer -> Signal<StoryStats?, NoError> in
        guard let peer = peer, let inputPeer = apiInputPeer(peer) else {
            return .never()
        }
        
        var flags: Int32 = 0
        if dark {
            flags |= (1 << 1)
        }
        
        let request = Api.functions.stats.getStoryStats(flags: flags, peer: inputPeer, id: storyId)
        let signal: Signal<Api.stats.StoryStats, MTRpcError>
        if network.datacenterId != datacenterId {
            signal = network.download(datacenterId: Int(datacenterId), isMedia: false, tag: nil)
            |> castError(MTRpcError.self)
            |> mapToSignal { worker in
                return worker.request(request)
            }
        } else {
            signal = network.request(request)
        }
        
        let views: Int = 0
        let forwards: Int = 0
//        for attribute in story.attributes {
//            if let viewsAttribute = attribute as? ViewCountStoryAttribute {
//                views = viewsAttribute.count
//            } else if let forwardsAttribute = attribute as? ForwardCountStoryAttribute {
//                forwards = forwardsAttribute.count
//            }
//        }
        
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
    private let postbox: Postbox
    private let network: Network
    private let datacenterId: Int32
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
    
    init(postbox: Postbox, network: Network, datacenterId: Int32, peerId: EnginePeer.Id, storyId: Int32) {
        assert(Queue.mainQueue().isCurrent())
        
        self.postbox = postbox
        self.network = network
        self.datacenterId = datacenterId
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
        
        self.disposable.set((requestStoryStats(postbox: self.postbox, network: self.network, datacenterId: self.datacenterId, peerId: self.peerId, storyId: self.storyId)
        |> deliverOnMainQueue).start(next: { [weak self] stats in
            if let strongSelf = self {
                strongSelf._state = StoryStatsContextState(stats: stats)
                strongSelf._statePromise.set(.single(strongSelf._state))
            }
        }))
    }
    
    func loadDetailedGraph(_ graph: StatsGraph, x: Int64) -> Signal<StatsGraph?, NoError> {
        if let token = graph.token {
            return requestGraph(network: self.network, datacenterId: self.datacenterId, token: token, x: x)
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
    
    public init(postbox: Postbox, network: Network, datacenterId: Int32, peerId: EnginePeer.Id, storyId: Int32) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return StoryStatsContextImpl(postbox: postbox, network: network, datacenterId: datacenterId, peerId: peerId, storyId: storyId)
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

