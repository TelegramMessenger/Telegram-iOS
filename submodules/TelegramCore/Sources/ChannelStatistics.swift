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
    public let value: Double
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
    case Loaded(data: String, zoomToken: String?)
}

public final class ChannelStats: Equatable {
    public let period: ChannelStatsDateRange
    public let followers: ChannelStatsValue
    public let viewsPerPost: ChannelStatsValue
    public let sharesPerPost: ChannelStatsValue
    public let enabledNotifications: ChannelStatsPercentValue
    public let viewsBySourceGraph: ChannelStatsGraph
    public let newFollowersBySourceGraph: ChannelStatsGraph
    public let languagesGraph: ChannelStatsGraph
    public let growthGraph: ChannelStatsGraph
    public let followersGraph: ChannelStatsGraph
    public let muteGraph: ChannelStatsGraph
    public let topHoursGraph: ChannelStatsGraph
    public let interactionsGraph: ChannelStatsGraph
        
    public init(period: ChannelStatsDateRange, followers: ChannelStatsValue, viewsPerPost: ChannelStatsValue, sharesPerPost: ChannelStatsValue, enabledNotifications: ChannelStatsPercentValue, viewsBySourceGraph: ChannelStatsGraph, newFollowersBySourceGraph: ChannelStatsGraph, languagesGraph: ChannelStatsGraph, growthGraph: ChannelStatsGraph, followersGraph: ChannelStatsGraph, muteGraph: ChannelStatsGraph, topHoursGraph: ChannelStatsGraph, interactionsGraph: ChannelStatsGraph) {
        self.period = period
        self.followers = followers
        self.viewsPerPost = viewsPerPost
        self.sharesPerPost = sharesPerPost
        self.enabledNotifications = enabledNotifications
        self.viewsBySourceGraph = viewsBySourceGraph
        self.newFollowersBySourceGraph = newFollowersBySourceGraph
        self.languagesGraph = languagesGraph
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
        if lhs.viewsBySourceGraph != rhs.viewsBySourceGraph {
            return false
        }
        if lhs.newFollowersBySourceGraph != rhs.newFollowersBySourceGraph {
            return false
        }
        if lhs.languagesGraph != rhs.languagesGraph {
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
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, growthGraph: growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph)
    }
    
    public func withUpdatedFollowersGraph(_ followersGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, growthGraph: self.growthGraph, followersGraph: followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph)
    }
    
    public func withUpdatedMuteGraph(_ muteGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph)
    }
    
    public func withUpdatedTopHoursGraph(_ viewsByHourGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: viewsByHourGraph, interactionsGraph: self.interactionsGraph)
    }
    
    public func withUpdatedInteractionsGraph(_ interactionsGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: interactionsGraph)
    }
    public func withUpdatedViewsBySourceGraph(_ viewsBySourceGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySourceGraph: viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph)
    }
    public func withUpdatedNewFollowersBySourceGraph(_ newFollowersBySourceGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: newFollowersBySourceGraph, languagesGraph: self.languagesGraph, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph)
    }
    public func withUpdatedLanguageGraph(_ languagesGraph: ChannelStatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, enabledNotifications: self.enabledNotifications, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: newFollowersBySourceGraph, languagesGraph: languagesGraph, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph)
    }
}

public struct ChannelStatsContextState: Equatable {
    public var stats: ChannelStats?
}

private func requestStats(network: Network, postbox: Postbox, datacenterId: Int32, peerId: PeerId, dark: Bool = false) -> Signal<ChannelStats?, NoError> {
    //return .never()
    
    return postbox.transaction { transaction -> Api.InputChannel? in
        if let peer = transaction.getPeer(peerId) {
            return apiInputChannel(peer)
        } else {
            return nil
        }
    } |> mapToSignal { inputChannel -> Signal<ChannelStats?, NoError> in
        guard let inputChannel = inputChannel else {
            return .complete()
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
            |> `catch` { error -> Signal<ChannelStats?, NoError> in
                return .single(nil)
        }
    }
    
    
}

private func requestGraph(network: Network, datacenterId: Int32, token: String) -> Signal<ChannelStatsGraph?, NoError> {
    let signal: Signal<Api.StatsGraph, MTRpcError>
    if network.datacenterId != datacenterId {
        signal = network.download(datacenterId: Int(datacenterId), isMedia: false, tag: nil)
        |> castError(MTRpcError.self)
        |> mapToSignal { worker in
            return worker.request(Api.functions.stats.loadAsyncGraph(flags: 0, token: token, x: nil))
        }
    } else {
        signal = network.request(Api.functions.stats.loadAsyncGraph(flags: 0, token: token, x: nil))
    }
    
    return signal
    |> map { result -> ChannelStatsGraph? in
        return ChannelStatsGraph(apiStatsGraph: result)
    }
    |> `catch` { _ -> Signal<ChannelStatsGraph?, NoError> in
        return .single(nil)
    }
}

private final class ChannelStatsContextImpl {
    private let network: Network
    private let postbox: Postbox
    private let peerId: PeerId
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
    
    init(network: Network, postbox: Postbox, datacenterId: Int32, peerId: PeerId) {
        assert(Queue.mainQueue().isCurrent())
        self.postbox = postbox
        self.network = network
        self.peerId = peerId
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
        
        self.disposable.set((requestStats(network: self.network, postbox: self.postbox, datacenterId: self.datacenterId, peerId: self.peerId)
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
    
    func loadViewsBySourceGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.viewsBySourceGraph {
            self.disposables.set((requestGraph(network: self.network, datacenterId: self.datacenterId, token: token)
                |> deliverOnMainQueue).start(next: { [weak self] graph in
                    if let strongSelf = self, let graph = graph {
                        strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedViewsBySourceGraph(graph))
                        strongSelf._statePromise.set(.single(strongSelf._state))
                    }
                }), forKey: token)
        }
    }
    func loadNewFollowersBySourceGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.newFollowersBySourceGraph {
            self.disposables.set((requestGraph(network: self.network, datacenterId: self.datacenterId, token: token)
                |> deliverOnMainQueue).start(next: { [weak self] graph in
                    if let strongSelf = self, let graph = graph {
                        strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedNewFollowersBySourceGraph(graph))
                        strongSelf._statePromise.set(.single(strongSelf._state))
                    }
                }), forKey: token)
        }
    }
    func loadLanguageGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.languagesGraph {
            self.disposables.set((requestGraph(network: self.network, datacenterId: self.datacenterId, token: token)
                |> deliverOnMainQueue).start(next: { [weak self] graph in
                    if let strongSelf = self, let graph = graph {
                        strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedLanguageGraph(graph))
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
    
    public init(network: Network, postbox: Postbox, datacenterId: Int32, peerId: PeerId) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return ChannelStatsContextImpl(network: network, postbox: postbox, datacenterId: datacenterId, peerId: peerId)
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
    public func loadViewsBySourceGraph() {
        self.impl.with { impl in
            impl.loadViewsBySourceGraph()
        }
    }
    public func loadNewFollowersBySourceGraph() {
        self.impl.with { impl in
            impl.loadNewFollowersBySourceGraph()
        }
    }
    public func loadLanguageGraph() {
        self.impl.with { impl in
            impl.loadLanguageGraph()
        }
    }
}

extension ChannelStatsGraph {
    init(apiStatsGraph: Api.StatsGraph) {
        switch apiStatsGraph {
            case let .statsGraph(_, json, zoomToken):
                if case let .dataJSON(string) = json {
                    self = .Loaded(data: string, zoomToken: zoomToken)
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


extension ChannelStatsPercentValue {
    init(apiPercentValue: Api.StatsPercentValue) {
        switch apiPercentValue {
            case let .statsPercentValue(part, total):
                self = ChannelStatsPercentValue(value: part, total: total)
        }
    }
}

extension ChannelStats {
    convenience init(apiBroadcastStats: Api.stats.BroadcastStats) {
        switch apiBroadcastStats {
        case let .broadcastStats(period, followers, viewsPerPost, sharesPerPost, enabledNotifications, growthGraph, followersGraph, muteGraph, topHoursGraph, interactionsGraph, viewsBySourceGraph, newFollowersBySourceGraph, languagesGraph, recentMessageInteractions):
                self.init(period: ChannelStatsDateRange(apiStatsDateRangeDays: period), followers: ChannelStatsValue(apiStatsAbsValueAndPrev: followers), viewsPerPost: ChannelStatsValue(apiStatsAbsValueAndPrev: viewsPerPost), sharesPerPost: ChannelStatsValue(apiStatsAbsValueAndPrev: sharesPerPost), enabledNotifications: ChannelStatsPercentValue(apiPercentValue: enabledNotifications), viewsBySourceGraph: ChannelStatsGraph(apiStatsGraph: viewsBySourceGraph), newFollowersBySourceGraph: ChannelStatsGraph(apiStatsGraph: newFollowersBySourceGraph), languagesGraph: ChannelStatsGraph(apiStatsGraph: languagesGraph), growthGraph: ChannelStatsGraph(apiStatsGraph: growthGraph), followersGraph: ChannelStatsGraph(apiStatsGraph: followersGraph), muteGraph: ChannelStatsGraph(apiStatsGraph: muteGraph), topHoursGraph: ChannelStatsGraph(apiStatsGraph: topHoursGraph), interactionsGraph: ChannelStatsGraph(apiStatsGraph: interactionsGraph))
        }
    }
}
