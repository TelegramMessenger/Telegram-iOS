import Foundation
import SwiftSignalKit
import Postbox
internal import TelegramApi
import MtProtoKit

public struct PollStats: Equatable {
    public let votesGraph: StatsGraph
    
    init(votesGraph: StatsGraph) {
        self.votesGraph = votesGraph
    }
    
    public static func == (lhs: PollStats, rhs: PollStats) -> Bool {
        if lhs.votesGraph != rhs.votesGraph {
            return false
        }
        return true
    }
    
    public func withUpdatedVotesGraph(_ votesGraph: StatsGraph) -> PollStats {
        return PollStats(votesGraph: votesGraph)
    }
}

public struct PollStatsContextState: Equatable {
    public var stats: PollStats?
}

private func requestPollStats(postbox: Postbox, network: Network, messageId: MessageId, dark: Bool = false) -> Signal<PollStats?, NoError> {
    return postbox.transaction { transaction -> (Int32, Peer)? in
        if let peer = transaction.getPeer(messageId.peerId){
            if let cachedData = transaction.getPeerCachedData(peerId: messageId.peerId) as? CachedChannelData, cachedData.statsDatacenterId != 0 {
                return (cachedData.statsDatacenterId, peer)
            } else {
                return (Int32(network.datacenterId), peer)
            }
        } else {
            return nil
        }
    } |> mapToSignal { data -> Signal<PollStats?, NoError> in
        guard let (datacenterId, peer) = data, let inputPeer = apiInputPeer(peer) else {
            return .never()
        }
        
        var flags: Int32 = 0
        if dark {
            flags |= (1 << 1)
        }
        
        let request = Api.functions.stats.getPollStats(flags: flags, peer: inputPeer, msgId: messageId.id)
        let signal: Signal<Api.stats.PollStats, MTRpcError>
        if network.datacenterId != datacenterId {
            signal = network.download(datacenterId: Int(datacenterId), isMedia: false, tag: nil)
            |> castError(MTRpcError.self)
            |> mapToSignal { worker in
                return worker.request(request)
            }
        } else {
            signal = network.request(request)
        }
        
        return signal
        |> mapToSignal { result -> Signal<PollStats?, MTRpcError> in
            switch result {
            case let .pollStats(pollStatsData):
                let votesGraph = StatsGraph(apiStatsGraph: pollStatsData.votesGraph)
                return .single(PollStats(votesGraph: votesGraph))
            }
        }
        |> retryRequest
    }
}

private final class PollStatsContextImpl {
    private let postbox: Postbox
    private let network: Network
    private let messageId: MessageId
    
    private var _state: PollStatsContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<PollStatsContextState>()
    var state: Signal<PollStatsContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    private let disposables = DisposableDict<String>()
    
    init(postbox: Postbox, network: Network, messageId: MessageId) {
        assert(Queue.mainQueue().isCurrent())
        
        self.postbox = postbox
        self.network = network
        self.messageId = messageId
        self._state = PollStatsContextState(stats: nil)
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
        
        self.disposable.set((requestPollStats(postbox: self.postbox, network: self.network, messageId: self.messageId)
        |> deliverOnMainQueue).start(next: { [weak self] stats in
            if let strongSelf = self {
                strongSelf._state = PollStatsContextState(stats: stats)
                strongSelf._statePromise.set(.single(strongSelf._state))
            }
        }))
    }
    
    func loadVotesGraph() {
        assert(Queue.mainQueue().isCurrent())
        
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.votesGraph {
            guard !token.isEmpty else {
                return
            }
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.messageId.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = PollStatsContextState(stats: strongSelf._state.stats?.withUpdatedVotesGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadDetailedGraph(_ graph: StatsGraph, x: Int64) -> Signal<StatsGraph?, NoError> {
        if let token = graph.token {
            return requestGraph(postbox: self.postbox, network: self.network, peerId: self.messageId.peerId, token: token, x: x)
        } else {
            return .single(nil)
        }
    }
}

public final class PollStatsContext {
    private let impl: QueueLocalObject<PollStatsContextImpl>
    
    public var state: Signal<PollStatsContextState, NoError> {
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
    
    public init(account: Account, messageId: MessageId) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return PollStatsContextImpl(postbox: account.postbox, network: account.network, messageId: messageId)
        })
    }
    
    public func loadVotesGraph() {
        self.impl.with { impl in
            impl.loadVotesGraph()
        }
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
