import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

public final class ChannelBoostStatus: Equatable {
    public let level: Int
    public let boosts: Int
    public let currentLevelBoosts: Int
    public let nextLevelBoosts: Int?
    public let premiumAudience: StatsPercentValue?
    
    public init(level: Int, boosts: Int, currentLevelBoosts: Int, nextLevelBoosts: Int?, premiumAudience: StatsPercentValue?) {
        self.level = level
        self.boosts = boosts
        self.currentLevelBoosts = currentLevelBoosts
        self.nextLevelBoosts = nextLevelBoosts
        self.premiumAudience = premiumAudience
    }
    
    public static func ==(lhs: ChannelBoostStatus, rhs: ChannelBoostStatus) -> Bool {
        if lhs.level != rhs.level {
            return false
        }
        if lhs.boosts != rhs.boosts {
            return false
        }
        if lhs.currentLevelBoosts != rhs.currentLevelBoosts {
            return false
        }
        if lhs.nextLevelBoosts != rhs.nextLevelBoosts {
            return false
        }
        if lhs.premiumAudience != rhs.premiumAudience {
            return false
        }
        return true
    }
}

func _internal_getChannelBoostStatus(account: Account, peerId: PeerId) -> Signal<ChannelBoostStatus?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<ChannelBoostStatus?, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(nil)
        }
        return account.network.request(Api.functions.stories.getBoostsStatus(peer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.stories.BoostsStatus?, NoError> in
            return .single(nil)
        }
        |> map { result -> ChannelBoostStatus? in
            guard let result = result else {
                return nil
            }
            
            switch result {
            case let .boostsStatus(_, level, currentLevelBoosts, boosts, nextLevelBoosts, premiumAudience):
                return ChannelBoostStatus(level: Int(level), boosts: Int(boosts), currentLevelBoosts: Int(currentLevelBoosts), nextLevelBoosts: nextLevelBoosts.flatMap(Int.init), premiumAudience: premiumAudience.flatMap({ StatsPercentValue(apiPercentValue: $0) }))
            }
        }
    }
}

public enum CanApplyBoostStatus {
    public enum ErrorReason {
        case generic
        case premiumRequired
        case floodWait(Int32)
        case peerBoostAlreadyActive
        case giftedPremiumNotAllowed
    }
    
    case ok
    case replace(currentBoost: EnginePeer)
    case error(ErrorReason)
}

func _internal_canApplyChannelBoost(account: Account, peerId: PeerId) -> Signal<CanApplyBoostStatus, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<CanApplyBoostStatus, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(.error(.generic))
        }
        return account.network.request(Api.functions.stories.canApplyBoost(peer: inputPeer), automaticFloodWait: false)
        |> map { result -> (Api.stories.CanApplyBoostResult?, CanApplyBoostStatus.ErrorReason?) in
            return (result, nil)
        }
        |> `catch` { error -> Signal<(Api.stories.CanApplyBoostResult?, CanApplyBoostStatus.ErrorReason?), NoError> in
            let reason: CanApplyBoostStatus.ErrorReason
            if error.errorDescription == "PREMIUM_ACCOUNT_REQUIRED" {
                reason = .premiumRequired
            } else if error.errorDescription.hasPrefix("FLOOD_WAIT_") {
                let errorText = error.errorDescription ?? ""
                if let underscoreIndex = errorText.lastIndex(of: "_") {
                    let timeoutText = errorText[errorText.index(after: underscoreIndex)...]
                    if let timeoutValue = Int32(String(timeoutText)) {
                        reason = .floodWait(timeoutValue)
                    } else {
                        reason = .generic
                    }
                } else {
                    reason = .generic
                }
            } else if error.errorDescription == "SAME_BOOST_ALREADY_ACTIVE" || error.errorDescription == "BOOST_NOT_MODIFIED" {
                reason = .peerBoostAlreadyActive
            } else if error.errorDescription == "PREMIUM_GIFTED_NOT_ALLOWED" {
                reason = .giftedPremiumNotAllowed
            } else {
                reason = .generic
            }

            return .single((nil, reason))
        }
        |> mapToSignal { result, errorReason -> Signal<CanApplyBoostStatus, NoError> in
            guard let result = result else {
                return .single(.error(errorReason ?? .generic))
            }
            
            return account.postbox.transaction { transaction -> CanApplyBoostStatus in
                switch result {
                case .canApplyBoostOk:
                    return .ok
                case let .canApplyBoostReplace(currentBoost, chats):
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(transaction: transaction, chats: chats, users: []))
                    
                    if let peer = transaction.getPeer(currentBoost.peerId) {
                        return .replace(currentBoost: EnginePeer(peer))
                    } else {
                        return .error(.generic)
                    }
                }
            }
        }
    }
}

func _internal_applyChannelBoost(account: Account, peerId: PeerId) -> Signal<Bool, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Bool, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(false)
        }
        return account.network.request(Api.functions.stories.applyBoost(peer: inputPeer))
        |> `catch` { error -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> map { result -> Bool in
            if case .boolTrue = result {
                return true
            }
            return false
        }
    }
}

private final class ChannelBoostersContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: PeerId
    private let disposable = MetaDisposable()
    private let updateDisposables = DisposableSet()
    private var isLoadingMore: Bool = false
    private var hasLoadedOnce: Bool = false
    private var canLoadMore: Bool = true
    private var loadedFromCache = false
    private var results: [ChannelBoostersContext.State.Booster] = []
    private var count: Int32
    private var lastOffset: String?
    private var populateCache: Bool = true
    
    let state = Promise<ChannelBoostersContext.State>()
    
    init(queue: Queue, account: Account, peerId: PeerId) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
                
        self.count = 0
            
        self.isLoadingMore = true
        self.disposable.set((account.postbox.transaction { transaction -> (peers: [ChannelBoostersContext.State.Booster], count: Int32, canLoadMore: Bool)? in
            let cachedResult = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedChannelBoosters, key: CachedChannelBoosters.key(peerId: peerId)))?.get(CachedChannelBoosters.self)
            if let cachedResult = cachedResult {
                var result: [ChannelBoostersContext.State.Booster] = []
                for peerId in cachedResult.peerIds {
                    if let peer = transaction.getPeer(peerId), let expires = cachedResult.dates[peerId] {
                        result.append(ChannelBoostersContext.State.Booster(peer: EnginePeer(peer), expires: expires))
                    } else {
                        return nil
                    }
                }
                return (result, cachedResult.count, true)
            } else {
                return nil
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] cachedPeersCountAndCanLoadMore in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isLoadingMore = false
            if let (cachedPeers, cachedCount, canLoadMore) = cachedPeersCountAndCanLoadMore {
                strongSelf.results = cachedPeers
                strongSelf.count = cachedCount
                strongSelf.hasLoadedOnce = true
                strongSelf.canLoadMore = canLoadMore
                strongSelf.loadedFromCache = true
            }
            strongSelf.loadMore()
        }))
                
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    func reload() {
        self.loadedFromCache = true
        self.populateCache = true
        self.loadMore()
    }
    
    func loadMore() {
        if self.isLoadingMore {
            return
        }
        self.isLoadingMore = true
        let account = self.account
        let accountPeerId = account.peerId
        let peerId = self.peerId
        let populateCache = self.populateCache
        
        if self.loadedFromCache {
            self.loadedFromCache = false
        }
        let lastOffset = self.lastOffset
        
        self.disposable.set((self.account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<([ChannelBoostersContext.State.Booster], Int32, String?), NoError> in
            if let inputPeer = inputPeer {
                let offset = lastOffset ?? ""
                let limit: Int32 = lastOffset == nil ? 25 : 50
                
                let signal = account.network.request(Api.functions.stories.getBoostersList(peer: inputPeer, offset: offset, limit: limit))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stories.BoostersList?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([ChannelBoostersContext.State.Booster], Int32, String?), NoError> in
                    return account.postbox.transaction { transaction -> ([ChannelBoostersContext.State.Booster], Int32, String?) in
                        guard let result = result else {
                            return ([], 0, nil)
                        }
                        switch result {
                        case let .boostersList(_, count, boosters, nextOffset, users):
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                            var resultBoosters: [ChannelBoostersContext.State.Booster] = []
                            for booster in boosters {
                                let peerId: EnginePeer.Id
                                let expires: Int32
                                switch booster {
                                    case let .booster(userId, expiresValue):
                                        peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                        expires = expiresValue
                                }
                                if let peer = transaction.getPeer(peerId) {
                                    resultBoosters.append(ChannelBoostersContext.State.Booster(peer: EnginePeer(peer), expires: expires))
                                }
                            }
                            if populateCache {
                                if let entry = CodableEntry(CachedChannelBoosters(boosters: resultBoosters, count: count)) {
                                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedChannelBoosters, key: CachedChannelBoosters.key(peerId: peerId)), entry: entry)
                                }
                            }
                            return (resultBoosters, count, nextOffset)
                        }
                    }
                }
                return signal
            } else {
                return .single(([], 0, nil))
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] boosters, updatedCount, nextOffset in
            guard let strongSelf = self else {
                return
            }
            strongSelf.lastOffset = nextOffset
            if strongSelf.populateCache {
                strongSelf.populateCache = false
                strongSelf.results.removeAll()
            }
            var existingIds = Set(strongSelf.results.map { $0.peer.id })
            for booster in boosters {
                if !existingIds.contains(booster.peer.id) {
                    strongSelf.results.append(booster)
                    existingIds.insert(booster.peer.id)
                }
            }
            strongSelf.isLoadingMore = false
            strongSelf.hasLoadedOnce = true
            strongSelf.canLoadMore = !boosters.isEmpty
            if strongSelf.canLoadMore {
                strongSelf.count = max(updatedCount, Int32(strongSelf.results.count))
            } else {
                strongSelf.count = Int32(strongSelf.results.count)
            }
            strongSelf.updateState()
        }))
        self.updateState()
    }
        
    private func updateCache() {
        guard self.hasLoadedOnce && !self.isLoadingMore else {
            return
        }
        
        let peerId = self.peerId
        let resultBoosters = Array(self.results.prefix(50))
        let count = self.count
        self.updateDisposables.add(self.account.postbox.transaction({ transaction in
            if let entry = CodableEntry(CachedChannelBoosters(boosters: resultBoosters, count: count)) {
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedChannelBoosters, key: CachedChannelBoosters.key(peerId: peerId)), entry: entry)
            }
        }).start())
    }
    
    private func updateState() {
        self.state.set(.single(ChannelBoostersContext.State(boosters: self.results, isLoadingMore: self.isLoadingMore, hasLoadedOnce: self.hasLoadedOnce, canLoadMore: self.canLoadMore, count: self.count)))
    }
}

public final class ChannelBoostersContext {
    public struct State: Equatable {
        public struct Booster: Equatable {
            public var peer: EnginePeer
            public var expires: Int32
        }
        public var boosters: [Booster]
        public var isLoadingMore: Bool
        public var hasLoadedOnce: Bool
        public var canLoadMore: Bool
        public var count: Int32
        
        public static var Empty = State(boosters: [], isLoadingMore: false, hasLoadedOnce: true, canLoadMore: false, count: 0)
        public static var Loading = State(boosters: [], isLoadingMore: false, hasLoadedOnce: false, canLoadMore: false, count: 0)
    }

    
    private let queue: Queue = Queue()
    private let impl: QueueLocalObject<ChannelBoostersContextImpl>
    
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
    
    public init(account: Account, peerId: PeerId) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ChannelBoostersContextImpl(queue: queue, account: account, peerId: peerId)
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

private final class CachedChannelBoosters: Codable {
    private enum CodingKeys: String, CodingKey {
        case peerIds
        case expires
        case count
    }
    
    private struct DictionaryPair: Codable, Hashable {
        var key: Int64
        var value: String
        
        init(_ key: Int64, value: String) {
            self.key = key
            self.value = value
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: StringCodingKey.self)

            self.key = try container.decode(Int64.self, forKey: "k")
            self.value = try container.decode(String.self, forKey: "v")
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: StringCodingKey.self)

            try container.encode(self.key, forKey: "k")
            try container.encode(self.value, forKey: "v")
        }
    }
    
    let peerIds: [EnginePeer.Id]
    let dates: [EnginePeer.Id: Int32]
    let count: Int32
    
    static func key(peerId: EnginePeer.Id) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    init(boosters: [ChannelBoostersContext.State.Booster], count: Int32) {
        self.peerIds = boosters.map { $0.peer.id }
        self.dates = boosters.reduce(into: [EnginePeer.Id: Int32]()) {
            $0[$1.peer.id] = $1.expires
        }
        self.count = count
    }
    
    init(peerIds: [PeerId], dates: [PeerId: Int32], count: Int32) {
        self.peerIds = peerIds
        self.dates = dates
        self.count = count
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.peerIds = (try container.decode([Int64].self, forKey: .peerIds)).map(EnginePeer.Id.init)
        
        var dates: [EnginePeer.Id: Int32] = [:]
        let datesArray = try container.decode([Int64].self, forKey: .expires)
        for index in stride(from: 0, to: datesArray.endIndex, by: 2) {
            let userId = datesArray[index]
            let date = datesArray[index + 1]
            let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
            dates[peerId] = Int32(clamping: date)
        }
        self.dates = dates
        
        self.count = try container.decode(Int32.self, forKey: .count)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.peerIds.map { $0.toInt64() }, forKey: .peerIds)
        
        var dates: [Int64] = []
        for (peerId, date) in self.dates {
            dates.append(peerId.id._internalGetInt64Value())
            dates.append(Int64(date))
        }
        
        try container.encode(dates, forKey: .expires)
        try container.encode(self.count, forKey: .count)
    }
}
