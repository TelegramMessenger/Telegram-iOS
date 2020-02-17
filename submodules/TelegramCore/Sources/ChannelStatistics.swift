import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit
import SyncCore

public struct ChannelStatsDateRange: Equatable {
    public let minDate: Int32
    public let maxDate: Int32
}

public struct ChannelStatsValue: Equatable {
    public let current: Double
    public let previous: Double
}

public struct ChannelStatsPercentValue: Equatable {
    public let fraction: Double
    public let total: Double
}

public struct ChannelStatsNamedValue: Equatable {
    public let id: String
    public let title: String
    public let shortTitle: String
    public let value: ChannelStatsValue
}

public enum ChannelStatsGraph: Equatable {
    case OnDemand(token: String)
    case Failed(error: String)
    case Loaded(data: String)
}

public final class ChannelStats: Equatable {
    public let period: ChannelStatsDateRange
    public let followers: ChannelStatsValue
    public let viewsPerPost: ChannelStatsValue
    public let sharesPerPost: ChannelStatsValue
    public let enabledNotifications: ChannelStatsPercentValue
    public let viewsBySource: [ChannelStatsNamedValue]
    public let newFollowersBySource: [ChannelStatsNamedValue]
    public let languages: [ChannelStatsNamedValue]
    public let growthGraph: ChannelStatsGraph
    public let followersGraph: ChannelStatsGraph
    public let muteGraph: ChannelStatsGraph
    public let topHoursGraph: ChannelStatsGraph
    public let interactionsGraph: ChannelStatsGraph
        
    public init(period: ChannelStatsDateRange, followers: ChannelStatsValue, viewsPerPost: ChannelStatsValue, sharesPerPost: ChannelStatsValue, enabledNotifications: ChannelStatsPercentValue, viewsBySource: [ChannelStatsNamedValue], newFollowersBySource: [ChannelStatsNamedValue], languages: [ChannelStatsNamedValue], growthGraph: ChannelStatsGraph, followersGraph: ChannelStatsGraph, muteGraph: ChannelStatsGraph, topHoursGraph: ChannelStatsGraph, interactionsGraph: ChannelStatsGraph) {
        self.period = period
        self.followers = followers
        self.viewsPerPost = viewsPerPost
        self.sharesPerPost = sharesPerPost
        self.enabledNotifications = enabledNotifications
        self.viewsBySource = viewsBySource
        self.newFollowersBySource = newFollowersBySource
        self.languages = languages
        self.growthGraph = growthGraph
        self.followersGraph = followersGraph
        self.muteGraph = muteGraph
        self.topHoursGraph = topHoursGraph
        self.interactionsGraph = interactionsGraph
    }
    
    public static func == (lhs: ChannelStats, rhs: ChannelStats) -> Bool {
        if lhs.period != rhs.period {
            return false
        }
        if lhs.followers != rhs.followers {
            return false
        }
        if lhs.viewsPerPost != rhs.viewsPerPost {
            return false
        }
        if lhs.sharesPerPost != rhs.sharesPerPost {
            return false
        }
        if lhs.enabledNotifications != rhs.enabledNotifications {
            return false
        }
        if lhs.viewsBySource != rhs.viewsBySource {
            return false
        }
        if lhs.newFollowersBySource != rhs.newFollowersBySource {
            return false
        }
        if lhs.languages != rhs.languages {
            return false
        }
        if lhs.growthGraph != rhs.growthGraph {
            return false
        }
        if lhs.followersGraph != rhs.followersGraph {
            return false
        }
        if lhs.muteGraph != rhs.muteGraph {
            return false
        }
        if lhs.topHoursGraph != rhs.topHoursGraph {
            return false
        }
        if lhs.interactionsGraph != rhs.interactionsGraph {
            return false
        }
        return true
    }
    
    public func withUpdatedGrowthGraph(_ growthGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySource: self.viewsBySource, newFollowersBySource: self.newFollowersBySource, languages: self.languages, growthGraph: growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph)
    }
    
    public func withUpdatedFollowersGraph(_ followersGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySource: self.viewsBySource, newFollowersBySource: self.newFollowersBySource, languages: self.languages, growthGraph: self.growthGraph, followersGraph: followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph)
    }
    
    public func withUpdatedMuteGraph(_ muteGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySource: self.viewsBySource, newFollowersBySource: self.newFollowersBySource, languages: self.languages, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph)
    }
    
    public func withUpdatedTopHoursGraph(_ viewsByHourGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySource: self.viewsBySource, newFollowersBySource: self.newFollowersBySource, languages: self.languages, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: viewsByHourGraph, interactionsGraph: self.interactionsGraph)
    }
    
    public func withUpdatedInteractionsGraph(_ interactionsGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySource: self.viewsBySource, newFollowersBySource: self.newFollowersBySource, languages: self.languages, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: interactionsGraph)
    }
}

public struct ChannelStatsContextState: Equatable {
    public var stats: ChannelStats?
}

private func requestStats(network: Network, datacenterId: Int32, peer: Peer, dark: Bool = false) -> Signal<ChannelStats?, NoError> {
    return .never()
    /*guard let inputChannel = apiInputChannel(peer) else {
        return .never()
    }
    
    var flags: Int32 = 0
    if dark {
        flags |= (1 << 1)
    }
    
    let signal: Signal<Api.stats.BroadcastStats, MTRpcError>
    if network.datacenterId != datacenterId {
        signal = network.download(datacenterId: Int(datacenterId), isMedia: false, tag: nil)
        |> castError(MTRpcError.self)
        |> mapToSignal { worker in
            return worker.request(Api.functions.stats.getBroadcastStats(flags: flags, channel: inputChannel))
        }
    } else {
        signal = network.request(Api.functions.stats.getBroadcastStats(flags: flags, channel: inputChannel))
    }
    
    return signal
    |> map { result -> ChannelStats? in
        return ChannelStats(apiBroadcastStats: result)
    }
    |> `catch` { _ -> Signal<ChannelStats?, NoError> in
        return .single(nil)
    }*/
}

private func requestGraph(network: Network, datacenterId: Int32, token: String) -> Signal<ChannelStatsGraph?, NoError> {
    return .never()
    /*let signal: Signal<Api.StatsGraph, MTRpcError>
    if network.datacenterId != datacenterId {
        signal = network.download(datacenterId: Int(datacenterId), isMedia: false, tag: nil)
        |> castError(MTRpcError.self)
        |> mapToSignal { worker in
            return worker.request(Api.functions.stats.loadAsyncGraph(token: token))
        }
    } else {
        signal = network.request(Api.functions.stats.loadAsyncGraph(token: token))
    }
    
    return signal
    |> map { result -> ChannelStatsGraph? in
        return ChannelStatsGraph(apiStatsGraph: result)
    }
    |> `catch` { _ -> Signal<ChannelStatsGraph?, NoError> in
        return .single(nil)
    }*/
}

private final class ChannelStatsContextImpl {
    private let network: Network
    private let peer: Peer
    private let datacenterId: Int32
    
    private var _state: ChannelStatsContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<ChannelStatsContextState>()
    var state: Signal<ChannelStatsContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    private let disposables = DisposableDict<String>()
    
    init(network: Network, datacenterId: Int32, peer: Peer) {
        assert(Queue.mainQueue().isCurrent())
        
        self.network = network
        self.peer = peer
        self.datacenterId = datacenterId
        self._state = ChannelStatsContextState(stats: nil)
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
        
        self.disposable.set((requestStats(network: self.network, datacenterId: self.datacenterId, peer: self.peer)
        |> deliverOnMainQueue).start(next: { [weak self] stats in
            if let strongSelf = self {
                strongSelf._state = ChannelStatsContextState(stats: stats)
                strongSelf._statePromise.set(.single(strongSelf._state))
            }
        }))
    }
    
    func loadGrowthGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.growthGraph {
            self.disposables.set((requestGraph(network: self.network, datacenterId: self.datacenterId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedGrowthGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadFollowersGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.followersGraph {
            self.disposables.set((requestGraph(network: self.network, datacenterId: self.datacenterId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedFollowersGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadMuteGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.muteGraph {
            self.disposables.set((requestGraph(network: self.network, datacenterId: self.datacenterId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedMuteGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadTopHoursGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.topHoursGraph {
            self.disposables.set((requestGraph(network: self.network, datacenterId: self.datacenterId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedTopHoursGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadInteractionsGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.interactionsGraph {
            self.disposables.set((requestGraph(network: self.network, datacenterId: self.datacenterId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedInteractionsGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
}

public final class ChannelStatsContext {
    private let impl: QueueLocalObject<ChannelStatsContextImpl>
    
    public var state: Signal<ChannelStatsContextState, NoError> {
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
    
    public init(network: Network, datacenterId: Int32, peer: Peer) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return ChannelStatsContextImpl(network: network, datacenterId: datacenterId, peer: peer)
        })
    }
    
    public func loadGrowthGraph() {
        self.impl.with { impl in
            impl.loadGrowthGraph()
        }
    }
       
    public func loadFollowersGraph() {
        self.impl.with { impl in
            impl.loadFollowersGraph()
        }
    }
       
    public func loadMuteGraph() {
        self.impl.with { impl in
            impl.loadMuteGraph()
        }
    }
       
    public func loadTopHoursGraph() {
        self.impl.with { impl in
            impl.loadTopHoursGraph()
        }
    }
       
    public func loadInteractionsGraph() {
        self.impl.with { impl in
            impl.loadInteractionsGraph()
        }
    }
}

/*extension ChannelStatsGraph {
    init(apiStatsGraph: Api.StatsGraph) {
        switch apiStatsGraph {
            case let .statsGraph(json):
                if case let .dataJSON(string) = json {
                    self = .Loaded(data: string)
                } else {
                    self = .Failed(error: "")
                }
            case let .statsGraphError(error):
                self = .Failed(error: error)
            case let .statsGraphAsync(token):
                self = .OnDemand(token: token)
        }
    }
}

extension ChannelStatsDateRange {
    init(apiStatsDateRangeDays: Api.StatsDateRangeDays) {
        switch apiStatsDateRangeDays {
            case let .statsDateRangeDays(minDate, maxDate):
                self = ChannelStatsDateRange(minDate: minDate, maxDate: maxDate)
        }
    }
}

extension ChannelStatsValue {
    init(apiStatsAbsValueAndPrev: Api.StatsAbsValueAndPrev) {
        switch apiStatsAbsValueAndPrev {
            case let .statsAbsValueAndPrev(current, previous):
                self = ChannelStatsValue(current: current, previous: previous)
        }
    }
}

extension ChannelStatsNamedValue {
    init(apiStatsRowAbsValueAndPrev: Api.StatsRowAbsValueAndPrev) {
        switch apiStatsRowAbsValueAndPrev {
            case let .statsRowAbsValueAndPrev(id, title, shortTitle, values):
                self = ChannelStatsNamedValue(id: id, title: title, shortTitle: shortTitle, value: ChannelStatsValue(apiStatsAbsValueAndPrev: values))
        }
    }
}

extension ChannelStatsPercentValue {
    init(apiPercentValue: Api.StatsPercentValue) {
        switch apiPercentValue {
            case let .statsPercentValue(part, total):
                self = ChannelStatsPercentValue(fraction: part, total: total)
        }
    }
}

extension ChannelStats {
    convenience init(apiBroadcastStats: Api.stats.BroadcastStats) {
        switch apiBroadcastStats {
            case let .broadcastStats(period, followers, viewsPerPost, sharesPerPost, enabledNotifications, viewsBySource, newFollowersBySource, languages, growthGraph, followersGraph, muteGraph, topHoursGraph, interactionsGraph):
                self.init(period: ChannelStatsDateRange(apiStatsDateRangeDays: period), followers: ChannelStatsValue(apiStatsAbsValueAndPrev: followers), viewsPerPost: ChannelStatsValue(apiStatsAbsValueAndPrev: viewsPerPost), sharesPerPost: ChannelStatsValue(apiStatsAbsValueAndPrev: sharesPerPost), enabledNotifications: ChannelStatsPercentValue(apiPercentValue: enabledNotifications), viewsBySource: viewsBySource.map { ChannelStatsNamedValue(apiStatsRowAbsValueAndPrev: $0) }, newFollowersBySource: newFollowersBySource.map { ChannelStatsNamedValue(apiStatsRowAbsValueAndPrev: $0) }, languages: languages.map { ChannelStatsNamedValue(apiStatsRowAbsValueAndPrev: $0) }, growthGraph: ChannelStatsGraph(apiStatsGraph: growthGraph), followersGraph: ChannelStatsGraph(apiStatsGraph: followersGraph), muteGraph: ChannelStatsGraph(apiStatsGraph: muteGraph), topHoursGraph: ChannelStatsGraph(apiStatsGraph: topHoursGraph), interactionsGraph: ChannelStatsGraph(apiStatsGraph: interactionsGraph))
        }
    }
}
*/
