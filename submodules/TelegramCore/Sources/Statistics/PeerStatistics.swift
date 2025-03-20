import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit

public struct StatsDateRange: Equatable {
    public let minDate: Int32
    public let maxDate: Int32
}

public struct StatsValue: Equatable {
    public let current: Double
    public let previous: Double
}

public struct StatsPercentValue: Equatable {
    public let value: Double
    public let total: Double
}

public enum StatsGraph: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case token
        case error
        case data
    }
    
    private enum TypeKey: Int32 {
        case onDemand
        case failed
        case loaded
        case empty
    }
    
    case OnDemand(token: String)
    case Failed(error: String)
    case Loaded(token: String?, data: String)
    case Empty
    
    public var isEmpty: Bool {
        switch self {
            case .Empty:
                return true
            case .Failed:
                return true
            default:
                return false
        }
    }
    
    var token: String? {
        switch self {
            case let .OnDemand(token):
                return token
            case let .Loaded(token, _):
                return token
            default:
                return nil
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = TypeKey(rawValue: try container.decode(Int32.self, forKey: .type)) ?? .empty
        switch type {
        case .onDemand:
            self = .OnDemand(token: try container.decode(String.self, forKey: .token))
        case .failed:
            self = .Failed(error: try container.decode(String.self, forKey: .error))
        case .loaded:
            self = .Loaded(token: try container.decodeIfPresent(String.self, forKey: .token), data: try container.decode(String.self, forKey: .data))
        case .empty:
            self = .Empty
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case let .OnDemand(token):
            try container.encode(TypeKey.empty.rawValue, forKey: .type)
            try container.encode(token, forKey: .token)
        case let .Failed(error):
            try container.encode(TypeKey.failed.rawValue, forKey: .type)
            try container.encode(error, forKey: .error)
        case let .Loaded(token, data):
            try container.encode(TypeKey.loaded.rawValue, forKey: .type)
            try container.encodeIfPresent(token, forKey: .token)
            try container.encode(data, forKey: .data)
        case .Empty:
            try container.encode(TypeKey.empty.rawValue, forKey: .type)
        }
    }
}

public struct ChannelStatsPostInteractions: Equatable {
    public enum PostId: Hashable {
        case message(id: EngineMessage.Id)
        case story(peerId: EnginePeer.Id, id: Int32)
    }
    
    public let postId: PostId
    public let views: Int32
    public let forwards: Int32
    public let reactions: Int32
    
    public init(postId: PostId, views: Int32, forwards: Int32, reactions: Int32) {
        self.postId = postId
        self.views = views
        self.forwards = forwards
        self.reactions = reactions
    }
}

public struct ChannelStats: Equatable {
    public let period: StatsDateRange
    public let followers: StatsValue
    public let viewsPerPost: StatsValue
    public let sharesPerPost: StatsValue
    public let reactionsPerPost: StatsValue
    public let viewsPerStory: StatsValue
    public let sharesPerStory: StatsValue
    public let reactionsPerStory: StatsValue
    public let enabledNotifications: StatsPercentValue
    public let growthGraph: StatsGraph
    public let followersGraph: StatsGraph
    public let muteGraph: StatsGraph
    public let topHoursGraph: StatsGraph
    public let interactionsGraph: StatsGraph
    public let instantPageInteractionsGraph: StatsGraph
    public let viewsBySourceGraph: StatsGraph
    public let newFollowersBySourceGraph: StatsGraph
    public let languagesGraph: StatsGraph
    public let reactionsByEmotionGraph: StatsGraph
    public let storyInteractionsGraph: StatsGraph
    public let storyReactionsByEmotionGraph: StatsGraph
    public let postInteractions: [ChannelStatsPostInteractions]
    
    init(
        period: StatsDateRange,
        followers: StatsValue,
        viewsPerPost: StatsValue,
        sharesPerPost: StatsValue,
        reactionsPerPost: StatsValue,
        viewsPerStory: StatsValue,
        sharesPerStory: StatsValue,
        reactionsPerStory: StatsValue,
        enabledNotifications: StatsPercentValue,
        growthGraph: StatsGraph,
        followersGraph: StatsGraph,
        muteGraph: StatsGraph,
        topHoursGraph: StatsGraph,
        interactionsGraph: StatsGraph,
        instantPageInteractionsGraph: StatsGraph,
        viewsBySourceGraph: StatsGraph,
        newFollowersBySourceGraph: StatsGraph,
        languagesGraph: StatsGraph,
        reactionsByEmotionGraph: StatsGraph,
        storyInteractionsGraph: StatsGraph,
        storyReactionsByEmotionGraph: StatsGraph,
        postInteractions: [ChannelStatsPostInteractions]
    ) {
        self.period = period
        self.followers = followers
        self.viewsPerPost = viewsPerPost
        self.sharesPerPost = sharesPerPost
        self.reactionsPerPost = reactionsPerPost
        self.viewsPerStory = viewsPerStory
        self.sharesPerStory = sharesPerStory
        self.reactionsPerStory = reactionsPerStory
        self.enabledNotifications = enabledNotifications
        self.growthGraph = growthGraph
        self.followersGraph = followersGraph
        self.muteGraph = muteGraph
        self.topHoursGraph = topHoursGraph
        self.interactionsGraph = interactionsGraph
        self.instantPageInteractionsGraph = instantPageInteractionsGraph
        self.viewsBySourceGraph = viewsBySourceGraph
        self.newFollowersBySourceGraph = newFollowersBySourceGraph
        self.languagesGraph = languagesGraph
        self.reactionsByEmotionGraph = reactionsByEmotionGraph
        self.storyInteractionsGraph = storyInteractionsGraph
        self.storyReactionsByEmotionGraph = storyReactionsByEmotionGraph
        self.postInteractions = postInteractions
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
        if lhs.instantPageInteractionsGraph != rhs.instantPageInteractionsGraph {
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
        if lhs.reactionsByEmotionGraph != rhs.reactionsByEmotionGraph {
            return false
        }
        if lhs.storyInteractionsGraph != rhs.storyInteractionsGraph {
            return false
        }
        if lhs.storyReactionsByEmotionGraph != rhs.storyReactionsByEmotionGraph {
            return false
        }
        if lhs.postInteractions != rhs.postInteractions {
            return false
        }
        return true
    }
    
    public func withUpdatedGrowthGraph(_ growthGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    
    public func withUpdatedFollowersGraph(_ followersGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    
    public func withUpdatedMuteGraph(_ muteGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    
    public func withUpdatedTopHoursGraph(_ viewsByHourGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: viewsByHourGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    
    public func withUpdatedInteractionsGraph(_ interactionsGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    
    public func withUpdatedInstantPageInteractionsGraph(_ instantPageInteractionsGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    
    public func withUpdatedViewsBySourceGraph(_ viewsBySourceGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    
    public func withUpdatedNewFollowersBySourceGraph(_ newFollowersBySourceGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    
    public func withUpdatedLanguagesGraph(_ languagesGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    
    public func withUpdatedReactionsByEmotionGraph(_ reactionsByEmotionGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    public func withUpdatedStoryInteractionsGraph(_ storyInteractionsGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: storyInteractionsGraph, storyReactionsByEmotionGraph: self.storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
    public func withUpdatedStoryReactionsByEmotionGraph(_ storyReactionsByEmotionGraph: StatsGraph) -> ChannelStats {
        return ChannelStats(period: self.period, followers: self.followers, viewsPerPost: self.viewsPerPost, sharesPerPost: self.sharesPerPost, reactionsPerPost: self.reactionsPerPost, viewsPerStory: self.viewsPerStory, sharesPerStory: self.sharesPerStory, reactionsPerStory: self.reactionsPerStory, enabledNotifications: self.enabledNotifications, growthGraph: self.growthGraph, followersGraph: self.followersGraph, muteGraph: self.muteGraph, topHoursGraph: self.topHoursGraph, interactionsGraph: self.interactionsGraph, instantPageInteractionsGraph: self.instantPageInteractionsGraph, viewsBySourceGraph: self.viewsBySourceGraph, newFollowersBySourceGraph: self.newFollowersBySourceGraph, languagesGraph: self.languagesGraph, reactionsByEmotionGraph: self.reactionsByEmotionGraph, storyInteractionsGraph: self.storyInteractionsGraph, storyReactionsByEmotionGraph: storyReactionsByEmotionGraph, postInteractions: self.postInteractions)
    }
}

public struct ChannelStatsContextState: Equatable {
    public var stats: ChannelStats?
}

private func requestChannelStats(postbox: Postbox, network: Network, peerId: PeerId, dark: Bool = false) -> Signal<ChannelStats?, NoError> {
    return postbox.transaction { transaction -> (Int32, Peer)? in
        if let peer = transaction.getPeer(peerId), let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData {
            return (cachedData.statsDatacenterId, peer)
        }
        return nil
    } |> mapToSignal { data -> Signal<ChannelStats?, NoError> in
        guard let (statsDatacenterId, peer) = data, let channel = peer as? TelegramChannel, case .broadcast = channel.info, let inputChannel = apiInputChannel(peer) else {
            return .never()
        }
        
        var flags: Int32 = 0
        if dark {
            flags |= (1 << 1)
        }
        
        let request = Api.functions.stats.getBroadcastStats(flags: flags, channel: inputChannel)
        let signal: Signal<Api.stats.BroadcastStats, MTRpcError>
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
        |> map { result -> ChannelStats? in
            return ChannelStats(apiBroadcastStats: result, peerId: peerId)
        }
        |> retryRequest
    }
}

func requestGraph(postbox: Postbox, network: Network, peerId: EnginePeer.Id, token: String, x: Int64? = nil) -> Signal<StatsGraph?, NoError> {
    var flags: Int32 = 0
    if let _ = x {
        flags |= (1 << 0)
    }
    let signal: Signal<Api.StatsGraph, MTRpcError>
    signal = postbox.transaction { transaction -> Int32? in
        if let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData {
            return cachedData.statsDatacenterId
        }
        return nil
    }
    |> castError(MTRpcError.self)
    |> mapToSignal { statsDatacenterId in
        if let statsDatacenterId = statsDatacenterId {
            if network.datacenterId != statsDatacenterId {
                return network.download(datacenterId: Int(statsDatacenterId), isMedia: false, tag: nil)
                |> castError(MTRpcError.self)
                |> mapToSignal { worker in
                    return worker.request(Api.functions.stats.loadAsyncGraph(flags: flags, token: token, x: x))
                }
            } else {
                return network.request(Api.functions.stats.loadAsyncGraph(flags: flags, token: token, x: x))
            }
        } else {
            return .complete()
        }
    }
    
    return signal
    |> map { result -> StatsGraph? in
        return StatsGraph(apiStatsGraph: result)
    }
    |> `catch` { _ -> Signal<StatsGraph?, NoError> in
        return .single(nil)
    }
}

private final class ChannelStatsContextImpl {
    private let postbox: Postbox
    private let network: Network
    private let peerId: PeerId
    
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
    
    init(postbox: Postbox, network: Network, peerId: PeerId) {
        assert(Queue.mainQueue().isCurrent())
        
        self.postbox = postbox
        self.network = network
        self.peerId = peerId
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
        
        self.disposable.set((requestChannelStats(postbox: self.postbox, network: self.network, peerId: self.peerId)
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
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
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
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
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
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
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
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
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
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedInteractionsGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadInstantPageInteractionsGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.instantPageInteractionsGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedInstantPageInteractionsGraph(graph))
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
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
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
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedNewFollowersBySourceGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadLanguagesGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.languagesGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedLanguagesGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadReactionsByEmotionGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.reactionsByEmotionGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedReactionsByEmotionGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadStoryInteractionsGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.storyInteractionsGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedStoryInteractionsGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadStoryReactionsByEmotionGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.storyReactionsByEmotionGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = ChannelStatsContextState(stats: strongSelf._state.stats?.withUpdatedStoryReactionsByEmotionGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadDetailedGraph(_ graph: StatsGraph, x: Int64) -> Signal<StatsGraph?, NoError> {
        if let token = graph.token {
            return requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token, x: x)
        } else {
            return .single(nil)
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
    
    public init(postbox: Postbox, network: Network, peerId: PeerId) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return ChannelStatsContextImpl(postbox: postbox, network: network, peerId: peerId)
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
    
    public func loadInstantPageInteractionsGraph() {
        self.impl.with { impl in
            impl.loadInstantPageInteractionsGraph()
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
    
    public func loadLanguagesGraph() {
        self.impl.with { impl in
            impl.loadLanguagesGraph()
        }
    }
    public func loadReactionsByEmotionGraph() {
        self.impl.with { impl in
            impl.loadReactionsByEmotionGraph()
        }
    }
    public func loadStoryInteractionsGraph() {
        self.impl.with { impl in
            impl.loadStoryInteractionsGraph()
        }
    }
    public func loadStoryReactionsByEmotionGraph() {
        self.impl.with { impl in
            impl.loadStoryReactionsByEmotionGraph()
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

public struct GroupStatsTopPoster: Equatable {
    public let peerId: PeerId
    public let messageCount: Int32
    public let averageChars: Int32
}

public struct GroupStatsTopAdmin: Equatable {
    public let peerId: PeerId
    public let deletedCount: Int32
    public let kickedCount: Int32
    public let bannedCount: Int32
}

public struct GroupStatsTopInviter: Equatable {
    public let peerId: PeerId
    public let inviteCount: Int32
}

public struct GroupStats: Equatable {
    public let period: StatsDateRange
    public let members: StatsValue
    public let messages: StatsValue
    public let viewers: StatsValue
    public let posters: StatsValue
    public let growthGraph: StatsGraph
    public let membersGraph: StatsGraph
    public let newMembersBySourceGraph: StatsGraph
    public let languagesGraph: StatsGraph
    public let messagesGraph: StatsGraph
    public let actionsGraph: StatsGraph
    public let topHoursGraph: StatsGraph
    public let topWeekdaysGraph: StatsGraph
    public let topPosters: [GroupStatsTopPoster]
    public let topAdmins: [GroupStatsTopAdmin]
    public let topInviters: [GroupStatsTopInviter]
    
    init(period: StatsDateRange, members: StatsValue, messages: StatsValue, viewers: StatsValue, posters: StatsValue, growthGraph: StatsGraph, membersGraph: StatsGraph, newMembersBySourceGraph: StatsGraph, languagesGraph: StatsGraph, messagesGraph: StatsGraph, actionsGraph: StatsGraph, topHoursGraph: StatsGraph, topWeekdaysGraph: StatsGraph, topPosters: [GroupStatsTopPoster], topAdmins: [GroupStatsTopAdmin], topInviters: [GroupStatsTopInviter]) {
        self.period = period
        self.members = members
        self.messages = messages
        self.viewers = viewers
        self.posters = posters
        self.growthGraph = growthGraph
        self.membersGraph = membersGraph
        self.newMembersBySourceGraph = newMembersBySourceGraph
        self.languagesGraph = languagesGraph
        self.messagesGraph = messagesGraph
        self.actionsGraph = actionsGraph
        self.topHoursGraph = topHoursGraph
        self.topWeekdaysGraph = topWeekdaysGraph
        self.topPosters = topPosters
        self.topAdmins = topAdmins
        self.topInviters = topInviters
    }
    
    public func withUpdatedGrowthGraph(_ growthGraph: StatsGraph) -> GroupStats {
        return GroupStats(period: self.period, members: self.members, messages: self.messages, viewers: self.viewers, posters: self.posters, growthGraph: growthGraph, membersGraph: self.membersGraph, newMembersBySourceGraph: self.newMembersBySourceGraph, languagesGraph: self.languagesGraph, messagesGraph: self.messagesGraph, actionsGraph: self.actionsGraph, topHoursGraph: self.topHoursGraph, topWeekdaysGraph: self.topWeekdaysGraph, topPosters: self.topPosters, topAdmins: self.topAdmins, topInviters: self.topInviters)
    }
    
    public func withUpdatedMembersGraph(_ membersGraph: StatsGraph) -> GroupStats {
        return GroupStats(period: self.period, members: self.members, messages: self.messages, viewers: self.viewers, posters: self.posters, growthGraph: self.growthGraph, membersGraph: membersGraph, newMembersBySourceGraph: self.newMembersBySourceGraph, languagesGraph: self.languagesGraph, messagesGraph: self.messagesGraph, actionsGraph: self.actionsGraph, topHoursGraph: self.topHoursGraph, topWeekdaysGraph: self.topWeekdaysGraph, topPosters: self.topPosters, topAdmins: self.topAdmins, topInviters: self.topInviters)
    }

    public func withUpdatedNewMembersBySourceGraph(_ newMembersBySourceGraph: StatsGraph) -> GroupStats {
        return GroupStats(period: self.period, members: self.members, messages: self.messages, viewers: self.viewers, posters: self.posters, growthGraph: self.growthGraph, membersGraph: self.membersGraph, newMembersBySourceGraph: newMembersBySourceGraph, languagesGraph: self.languagesGraph, messagesGraph: self.messagesGraph, actionsGraph: self.actionsGraph, topHoursGraph: self.topHoursGraph, topWeekdaysGraph: self.topWeekdaysGraph, topPosters: self.topPosters, topAdmins: self.topAdmins, topInviters: self.topInviters)
    }
    
    public func withUpdatedLanguagesGraph(_ languagesGraph: StatsGraph) -> GroupStats {
        return GroupStats(period: self.period, members: self.members, messages: self.messages, viewers: self.viewers, posters: self.posters, growthGraph: self.growthGraph, membersGraph: self.membersGraph, newMembersBySourceGraph: self.newMembersBySourceGraph, languagesGraph: languagesGraph, messagesGraph: self.messagesGraph, actionsGraph: self.actionsGraph, topHoursGraph: self.topHoursGraph, topWeekdaysGraph: self.topWeekdaysGraph, topPosters: self.topPosters, topAdmins: self.topAdmins, topInviters: self.topInviters)
    }
    
    public func withUpdatedMessagesGraph(_ messagesGraph: StatsGraph) -> GroupStats {
        return GroupStats(period: self.period, members: self.members, messages: self.messages, viewers: self.viewers, posters: self.posters, growthGraph: self.growthGraph, membersGraph: self.membersGraph, newMembersBySourceGraph: self.newMembersBySourceGraph, languagesGraph: self.languagesGraph, messagesGraph: messagesGraph, actionsGraph: self.actionsGraph, topHoursGraph: self.topHoursGraph, topWeekdaysGraph: self.topWeekdaysGraph, topPosters: self.topPosters, topAdmins: self.topAdmins, topInviters: self.topInviters)
    }
    
    public func withUpdatedActionsGraph(_ actionsGraph: StatsGraph) -> GroupStats {
        return GroupStats(period: self.period, members: self.members, messages: self.messages, viewers: self.viewers, posters: self.posters, growthGraph: self.growthGraph, membersGraph: self.membersGraph, newMembersBySourceGraph: self.newMembersBySourceGraph, languagesGraph: self.languagesGraph, messagesGraph: self.messagesGraph, actionsGraph: actionsGraph, topHoursGraph: self.topHoursGraph, topWeekdaysGraph: self.topWeekdaysGraph, topPosters: self.topPosters, topAdmins: self.topAdmins, topInviters: self.topInviters)
    }
    
    public func withUpdatedTopHoursGraph(_ topHoursGraph: StatsGraph) -> GroupStats {
        return GroupStats(period: self.period, members: self.members, messages: self.messages, viewers: self.viewers, posters: self.posters, growthGraph: self.growthGraph, membersGraph: self.membersGraph, newMembersBySourceGraph: self.newMembersBySourceGraph, languagesGraph: self.languagesGraph, messagesGraph: self.messagesGraph, actionsGraph: self.actionsGraph, topHoursGraph: topHoursGraph, topWeekdaysGraph: self.topWeekdaysGraph, topPosters: self.topPosters, topAdmins: self.topAdmins, topInviters: self.topInviters)
    }
    
    public func withUpdatedTopWeekdaysGraph(_ topWeekdaysGraph: StatsGraph) -> GroupStats {
        return GroupStats(period: self.period, members: self.members, messages: self.messages, viewers: self.viewers, posters: self.posters, growthGraph: self.growthGraph, membersGraph: self.membersGraph, newMembersBySourceGraph: self.newMembersBySourceGraph, languagesGraph: self.languagesGraph, messagesGraph: self.messagesGraph, actionsGraph: self.actionsGraph, topHoursGraph: self.topHoursGraph, topWeekdaysGraph: topWeekdaysGraph, topPosters: self.topPosters, topAdmins: self.topAdmins, topInviters: self.topInviters)
    }
}

public struct GroupStatsContextState: Equatable {
    public var stats: GroupStats?
}

private func requestGroupStats(accountPeerId: PeerId, postbox: Postbox, network: Network, peerId: PeerId, dark: Bool = false) -> Signal<GroupStats?, NoError> {
    return postbox.transaction { transaction -> (Int32, Peer)? in
        if let peer = transaction.getPeer(peerId), let cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData {
            return (cachedData.statsDatacenterId, peer)
        }
        return nil
    } |> mapToSignal { data -> Signal<GroupStats?, NoError> in
        guard let (statsDatacenterId, peer) = data, let channel = peer as? TelegramChannel, case .group = channel.info, let inputChannel = apiInputChannel(peer) else {
            return .never()
        }
        
        var flags: Int32 = 0
        if dark {
            flags |= (1 << 1)
        }
        
        let signal: Signal<Api.stats.MegagroupStats, MTRpcError>
        if network.datacenterId != statsDatacenterId {
            signal = network.download(datacenterId: Int(statsDatacenterId), isMedia: false, tag: nil)
            |> castError(MTRpcError.self)
            |> mapToSignal { worker in
                return worker.request(Api.functions.stats.getMegagroupStats(flags: flags, channel: inputChannel))
            }
        } else {
            signal = network.request(Api.functions.stats.getMegagroupStats(flags: flags, channel: inputChannel))
        }
        
        return signal
        |> mapToSignal { result -> Signal<GroupStats?, MTRpcError> in
            return postbox.transaction { transaction -> GroupStats? in
                if case let .megagroupStats(_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, users) = result {
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                }
                return GroupStats(apiMegagroupStats: result)
            }
            |> castError(MTRpcError.self)
        }
        |> retryRequest
    }
}

private final class GroupStatsContextImpl {
    private let postbox: Postbox
    private let network: Network
    private let accountPeerId: PeerId
    private let peerId: PeerId
    
    private var _state: GroupStatsContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<GroupStatsContextState>()
    var state: Signal<GroupStatsContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    private let disposables = DisposableDict<String>()
    
    init(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId) {
        assert(Queue.mainQueue().isCurrent())
        
        self.postbox = postbox
        self.network = network
        self.accountPeerId = accountPeerId
        self.peerId = peerId
        self._state = GroupStatsContextState(stats: nil)
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
        
        self.disposable.set((requestGroupStats(accountPeerId: self.accountPeerId, postbox: self.postbox, network: self.network, peerId: self.peerId)
        |> deliverOnMainQueue).start(next: { [weak self] stats in
            if let strongSelf = self {
                strongSelf._state = GroupStatsContextState(stats: stats)
                strongSelf._statePromise.set(.single(strongSelf._state))
            }
        }))
    }
    
    func loadGrowthGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.growthGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = GroupStatsContextState(stats: strongSelf._state.stats?.withUpdatedGrowthGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadMembersGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.membersGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = GroupStatsContextState(stats: strongSelf._state.stats?.withUpdatedMembersGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadNewMembersBySourceGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.newMembersBySourceGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = GroupStatsContextState(stats: strongSelf._state.stats?.withUpdatedNewMembersBySourceGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadLanguagesGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.languagesGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = GroupStatsContextState(stats: strongSelf._state.stats?.withUpdatedLanguagesGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadMessagesGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.messagesGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = GroupStatsContextState(stats: strongSelf._state.stats?.withUpdatedMessagesGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadActionsGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.actionsGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = GroupStatsContextState(stats: strongSelf._state.stats?.withUpdatedActionsGraph(graph))
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
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = GroupStatsContextState(stats: strongSelf._state.stats?.withUpdatedTopHoursGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadTopWeekdaysGraph() {
        guard let stats = self._state.stats else {
            return
        }
        if case let .OnDemand(token) = stats.topWeekdaysGraph {
            self.disposables.set((requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token)
            |> deliverOnMainQueue).start(next: { [weak self] graph in
                if let strongSelf = self, let graph = graph {
                    strongSelf._state = GroupStatsContextState(stats: strongSelf._state.stats?.withUpdatedTopWeekdaysGraph(graph))
                    strongSelf._statePromise.set(.single(strongSelf._state))
                }
            }), forKey: token)
        }
    }
    
    func loadDetailedGraph(_ graph: StatsGraph, x: Int64) -> Signal<StatsGraph?, NoError> {
        if let token = graph.token {
            return requestGraph(postbox: self.postbox, network: self.network, peerId: self.peerId, token: token, x: x)
        } else {
            return .single(nil)
        }
    }
}

public final class GroupStatsContext {
    private let impl: QueueLocalObject<GroupStatsContextImpl>
    
    public var state: Signal<GroupStatsContextState, NoError> {
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
    
    public init(postbox: Postbox, network: Network, accountPeerId: PeerId, peerId: PeerId) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return GroupStatsContextImpl(postbox: postbox, network: network, accountPeerId: accountPeerId, peerId: peerId)
        })
    }
        
    public func loadGrowthGraph() {
        self.impl.with { impl in
            impl.loadGrowthGraph()
        }
    }
       
    public func loadMembersGraph() {
        self.impl.with { impl in
            impl.loadMembersGraph()
        }
    }
       
    public func loadNewMembersBySourceGraph() {
        self.impl.with { impl in
            impl.loadNewMembersBySourceGraph()
        }
    }
    
    public func loadLanguagesGraph() {
        self.impl.with { impl in
            impl.loadLanguagesGraph()
        }
    }
    
    public func loadMessagesGraph() {
        self.impl.with { impl in
            impl.loadMessagesGraph()
        }
    }
    
    public func loadActionsGraph() {
        self.impl.with { impl in
            impl.loadActionsGraph()
        }
    }
          
    public func loadTopHoursGraph() {
        self.impl.with { impl in
            impl.loadTopHoursGraph()
        }
    }
    
    public func loadTopWeekdaysGraph() {
        self.impl.with { impl in
            impl.loadTopWeekdaysGraph()
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

extension StatsGraph {
    init(apiStatsGraph: Api.StatsGraph) {
        switch apiStatsGraph {
            case let .statsGraph(_, json, zoomToken):
                if case let .dataJSON(string) = json, let data = string.data(using: .utf8) {
                    do {
                        let decodedData = try JSONSerialization.jsonObject(with: data, options: [])
                        guard let item = decodedData as? [String: Any] else {
                            self = .Failed(error: "")
                            return
                        }
                        if let columns = item["columns"] as? [[Any]] {
                            if columns.isEmpty {
                                self = .Empty
                            } else {
                                self = .Loaded(token: zoomToken, data: string)
                            }
                        } else {
                            self = .Empty
                        }
                    } catch {
                        self = .Failed(error: "")
                    }
                } else {
                    self = .Failed(error: "")
                }
            case let .statsGraphError(error):
                self = .Failed(error: error)
            case let .statsGraphAsync(token):
                if !token.isEmpty {
                    self = .OnDemand(token: token)
                } else {
                    self = .Failed(error: "An error occured. Please try again later.")
                }
        }
    }
}

extension StatsDateRange {
    init(apiStatsDateRangeDays: Api.StatsDateRangeDays) {
        switch apiStatsDateRangeDays {
            case let .statsDateRangeDays(minDate, maxDate):
                self = StatsDateRange(minDate: minDate, maxDate: maxDate)
        }
    }
}

extension StatsValue {
    init(apiStatsAbsValueAndPrev: Api.StatsAbsValueAndPrev) {
        switch apiStatsAbsValueAndPrev {
            case let .statsAbsValueAndPrev(current, previous):
                self = StatsValue(current: current, previous: previous)
        }
    }
}

extension StatsPercentValue {
    init(apiPercentValue: Api.StatsPercentValue) {
        switch apiPercentValue {
            case let .statsPercentValue(part, total):
                self = StatsPercentValue(value: part, total: total)
        }
    }
}

extension ChannelStatsPostInteractions {
    init(apiPostInteractionCounters: Api.PostInteractionCounters, peerId: PeerId) {
        switch apiPostInteractionCounters {
        case let .postInteractionCountersMessage(msgId, views, forwards, reactions):
            self = ChannelStatsPostInteractions(postId: .message(id: EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Cloud, id: msgId)), views: views, forwards: forwards, reactions: reactions)
        case let .postInteractionCountersStory(storyId, views, forwards, reactions):
            self = ChannelStatsPostInteractions(postId: .story(peerId: peerId, id: storyId), views: views, forwards: forwards, reactions: reactions)
        }
    }
}

extension ChannelStats {
    init(apiBroadcastStats: Api.stats.BroadcastStats, peerId: PeerId) {
        switch apiBroadcastStats {
        case let .broadcastStats(period, followers, viewsPerPost, sharesPerPost, reactionsPerPost, viewsPerStory, sharesPerStory, reactionsPerStory, enabledNotifications, apiGrowthGraph, apiFollowersGraph, apiMuteGraph, apiTopHoursGraph, apiInteractionsGraph, apiInstantViewInteractionsGraph, apiViewsBySourceGraph, apiNewFollowersBySourceGraph, apiLanguagesGraph, apiReactionsByEmotionGraph, apiStoryInteractionsGraph, apiStoryReactionsByEmotionGraph, recentPostInteractions):
            let growthGraph = StatsGraph(apiStatsGraph: apiGrowthGraph)
            let isEmpty = growthGraph.isEmpty
        
            self.init(
                period: StatsDateRange(apiStatsDateRangeDays: period),
                followers: StatsValue(apiStatsAbsValueAndPrev: followers),
                viewsPerPost: StatsValue(apiStatsAbsValueAndPrev: viewsPerPost),
                sharesPerPost: StatsValue(apiStatsAbsValueAndPrev: sharesPerPost),
                reactionsPerPost: StatsValue(apiStatsAbsValueAndPrev: reactionsPerPost),
                viewsPerStory: StatsValue(apiStatsAbsValueAndPrev: viewsPerStory),
                sharesPerStory: StatsValue(apiStatsAbsValueAndPrev: sharesPerStory),
                reactionsPerStory: StatsValue(apiStatsAbsValueAndPrev: reactionsPerStory),
                enabledNotifications: StatsPercentValue(apiPercentValue: enabledNotifications),
                growthGraph: growthGraph,
                followersGraph: StatsGraph(apiStatsGraph: apiFollowersGraph),
                muteGraph: StatsGraph(apiStatsGraph: apiMuteGraph),
                topHoursGraph: StatsGraph(apiStatsGraph: apiTopHoursGraph),
                interactionsGraph: isEmpty ? .Empty : StatsGraph(apiStatsGraph: apiInteractionsGraph),
                instantPageInteractionsGraph: isEmpty ? .Empty : StatsGraph(apiStatsGraph: apiInstantViewInteractionsGraph),
                viewsBySourceGraph: isEmpty ? .Empty : StatsGraph(apiStatsGraph: apiViewsBySourceGraph),
                newFollowersBySourceGraph: isEmpty ? .Empty : StatsGraph(apiStatsGraph: apiNewFollowersBySourceGraph),
                languagesGraph: isEmpty ? .Empty : StatsGraph(apiStatsGraph: apiLanguagesGraph),
                reactionsByEmotionGraph: isEmpty ? .Empty : StatsGraph(apiStatsGraph: apiReactionsByEmotionGraph),
                storyInteractionsGraph: isEmpty ? .Empty : StatsGraph(apiStatsGraph: apiStoryInteractionsGraph),
                storyReactionsByEmotionGraph: isEmpty ? .Empty : StatsGraph(apiStatsGraph: apiStoryReactionsByEmotionGraph),
                postInteractions: recentPostInteractions.map { ChannelStatsPostInteractions(apiPostInteractionCounters: $0, peerId: peerId) })
        }
    }
}

extension GroupStatsTopPoster {
    init(apiStatsGroupTopPoster: Api.StatsGroupTopPoster) {
        switch apiStatsGroupTopPoster {
            case let .statsGroupTopPoster(userId, messages, avgChars):
                self = GroupStatsTopPoster(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), messageCount: messages, averageChars: avgChars)
        }
    }
}

extension GroupStatsTopAdmin {
    init(apiStatsGroupTopAdmin: Api.StatsGroupTopAdmin) {
        switch apiStatsGroupTopAdmin {
            case let .statsGroupTopAdmin(userId, deleted, kicked, banned):
                self = GroupStatsTopAdmin(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), deletedCount: deleted, kickedCount: kicked, bannedCount: banned)
        }
    }
}

extension GroupStatsTopInviter {
    init(apiStatsGroupTopInviter: Api.StatsGroupTopInviter) {
        switch apiStatsGroupTopInviter {
            case let .statsGroupTopInviter(userId, invitations):
                self = GroupStatsTopInviter(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), inviteCount: invitations)
        }
    }
}

extension GroupStats {
    init(apiMegagroupStats: Api.stats.MegagroupStats) {
        switch apiMegagroupStats {
            case let .megagroupStats(period, members, messages, viewers, posters, apiGrowthGraph, apiMembersGraph, apiNewMembersBySourceGraph, apiLanguagesGraph, apiMessagesGraph, apiActionsGraph, apiTopHoursGraph, apiTopWeekdaysGraph, topPosters, topAdmins, topInviters, _):
                let growthGraph = StatsGraph(apiStatsGraph: apiGrowthGraph)
                
                self.init(period: StatsDateRange(apiStatsDateRangeDays: period), members: StatsValue(apiStatsAbsValueAndPrev: members), messages: StatsValue(apiStatsAbsValueAndPrev: messages), viewers: StatsValue(apiStatsAbsValueAndPrev: viewers), posters: StatsValue(apiStatsAbsValueAndPrev: posters), growthGraph: growthGraph, membersGraph: StatsGraph(apiStatsGraph: apiMembersGraph), newMembersBySourceGraph: StatsGraph(apiStatsGraph: apiNewMembersBySourceGraph), languagesGraph: StatsGraph(apiStatsGraph: apiLanguagesGraph), messagesGraph: StatsGraph(apiStatsGraph: apiMessagesGraph), actionsGraph: StatsGraph(apiStatsGraph: apiActionsGraph), topHoursGraph: StatsGraph(apiStatsGraph: apiTopHoursGraph), topWeekdaysGraph: StatsGraph(apiStatsGraph: apiTopWeekdaysGraph), topPosters: topPosters.map { GroupStatsTopPoster(apiStatsGroupTopPoster: $0) }, topAdmins: topAdmins.map { GroupStatsTopAdmin(apiStatsGroupTopAdmin: $0) }, topInviters: topInviters.map { GroupStatsTopInviter(apiStatsGroupTopInviter: $0) })
        }
    }
}
