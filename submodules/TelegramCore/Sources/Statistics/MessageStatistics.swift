import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit

public struct MessageStats: Equatable {
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
    
    public static func == (lhs: MessageStats, rhs: MessageStats) -> Bool {
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
    
    public func withUpdatedInteractionsGraph(_ interactionsGraph: StatsGraph) -> MessageStats {
        return MessageStats(views: self.views, forwards: self.forwards, reactions: self.reactions, interactionsGraph: interactionsGraph, interactionsGraphDelta: self.interactionsGraphDelta, reactionsGraph: self.reactionsGraph)
    }
}

public struct MessageStatsContextState: Equatable {
    public var stats: MessageStats?
}

private func requestMessageStats(postbox: Postbox, network: Network, messageId: MessageId, dark: Bool = false) -> Signal<MessageStats?, NoError> {
    return postbox.transaction { transaction -> (Int32, Peer, Message)? in
        if let peer = transaction.getPeer(messageId.peerId), let message = transaction.getMessage(messageId), let cachedData = transaction.getPeerCachedData(peerId: messageId.peerId) as? CachedChannelData {
            return (cachedData.statsDatacenterId, peer, message)
        } else {
            return nil
        }
    } |> mapToSignal { data -> Signal<MessageStats?, NoError> in
        guard let (datacenterId, peer, message) = data, let inputChannel = apiInputChannel(peer) else {
            return .never()
        }
        
        var flags: Int32 = 0
        if dark {
            flags |= (1 << 1)
        }
        
        let request = Api.functions.stats.getMessageStats(flags: flags, channel: inputChannel, msgId: messageId.id)
        let signal: Signal<Api.stats.MessageStats, MTRpcError>
        if network.datacenterId != datacenterId {
            signal = network.download(datacenterId: Int(datacenterId), isMedia: false, tag: nil)
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
        for attribute in message.attributes {
            if let viewsAttribute = attribute as? ViewCountMessageAttribute {
                views = viewsAttribute.count
            } else if let forwardsAttribute = attribute as? ForwardCountMessageAttribute {
                forwards = forwardsAttribute.count
            } else if let reactionsAttribute = attribute as? ReactionsMessageAttribute {
                reactions = Int(reactionsAttribute.reactions.reduce(0, { partialResult, reaction in
                    return partialResult + reaction.count
                }))
            }
        }
        
        return signal
        |> mapToSignal { result -> Signal<MessageStats?, MTRpcError> in
            if case let .messageStats(apiInteractionsGraph, apiReactionsGraph) = result {
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
                return .single(MessageStats(
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

private final class MessageStatsContextImpl {
    private let postbox: Postbox
    private let network: Network
    private let messageId: MessageId
    
    private var _state: MessageStatsContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<MessageStatsContextState>()
    var state: Signal<MessageStatsContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    private let disposables = DisposableDict<String>()
    
    init(postbox: Postbox, network: Network, messageId: MessageId) {
        assert(Queue.mainQueue().isCurrent())
        
        self.postbox = postbox
        self.network = network
        self.messageId = messageId
        self._state = MessageStatsContextState(stats: nil)
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
        
        self.disposable.set((requestMessageStats(postbox: self.postbox, network: self.network, messageId: self.messageId)
        |> deliverOnMainQueue).start(next: { [weak self] stats in
            if let strongSelf = self {
                strongSelf._state = MessageStatsContextState(stats: stats)
                strongSelf._statePromise.set(.single(strongSelf._state))
            }
        }))
    }
    
    func loadDetailedGraph(_ graph: StatsGraph, x: Int64) -> Signal<StatsGraph?, NoError> {
        if let token = graph.token {
            return requestGraph(postbox: self.postbox, network: self.network, peerId: self.messageId.peerId, token: token, x: x)
        } else {
            return .single(nil)
        }
    }
}

public final class MessageStatsContext {
    private let impl: QueueLocalObject<MessageStatsContextImpl>
    
    public var state: Signal<MessageStatsContextState, NoError> {
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
            return MessageStatsContextImpl(postbox: account.postbox, network: account.network, messageId: messageId)
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
