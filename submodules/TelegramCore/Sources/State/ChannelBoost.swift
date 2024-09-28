import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit

public struct MyBoostStatus: Equatable {
    public struct Boost: Equatable {
        public let slot: Int32
        public let peer: EnginePeer?
        public let date: Int32
        public let expires: Int32
        public let cooldownUntil: Int32?
        
        public init(slot: Int32, peer: EnginePeer?, date: Int32, expires: Int32, cooldownUntil: Int32?) {
            self.slot = slot
            self.peer = peer
            self.date = date
            self.expires = expires
            self.cooldownUntil = cooldownUntil
        }
    }
    
    public let boosts: [Boost]
}

public struct ChannelBoostStatus: Equatable {
    public let level: Int
    public let boosts: Int
    public let giftBoosts: Int?
    public let currentLevelBoosts: Int
    public let nextLevelBoosts: Int?
    public let premiumAudience: StatsPercentValue?
    public let url: String
    public let prepaidGiveaways: [PrepaidGiveaway]
    public let boostedByMe: Bool
    
    public init(level: Int, boosts: Int, giftBoosts: Int?, currentLevelBoosts: Int, nextLevelBoosts: Int?, premiumAudience: StatsPercentValue?, url: String, prepaidGiveaways: [PrepaidGiveaway], boostedByMe: Bool) {
        self.level = level
        self.boosts = boosts
        self.giftBoosts = giftBoosts
        self.currentLevelBoosts = currentLevelBoosts
        self.nextLevelBoosts = nextLevelBoosts
        self.premiumAudience = premiumAudience
        self.url = url
        self.prepaidGiveaways = prepaidGiveaways
        self.boostedByMe = boostedByMe
    }
    
    public static func ==(lhs: ChannelBoostStatus, rhs: ChannelBoostStatus) -> Bool {
        if lhs.level != rhs.level {
            return false
        }
        if lhs.boosts != rhs.boosts {
            return false
        }
        if lhs.giftBoosts != rhs.giftBoosts {
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
        if lhs.url != rhs.url {
            return false
        }
        if lhs.prepaidGiveaways != rhs.prepaidGiveaways {
            return false
        }
        if lhs.boostedByMe != rhs.boostedByMe {
            return false
        }
        return true
    }
    
    public func withUpdated(boosts: Int) -> ChannelBoostStatus {
        return ChannelBoostStatus(level: self.level, boosts: boosts, giftBoosts: self.giftBoosts, currentLevelBoosts: self.currentLevelBoosts, nextLevelBoosts: self.nextLevelBoosts, premiumAudience: self.premiumAudience, url: self.url, prepaidGiveaways: self.prepaidGiveaways, boostedByMe: self.boostedByMe)
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
        return account.network.request(Api.functions.premium.getBoostsStatus(peer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.premium.BoostsStatus?, NoError> in
            return .single(nil)
        }
        |> map { result -> ChannelBoostStatus? in
            guard let result = result else {
                return nil
            }
            switch result {
            case let .boostsStatus(flags, level, currentLevelBoosts, boosts, giftBoosts, nextLevelBoosts, premiumAudience, boostUrl, prepaidGiveaways, myBoostSlots):
                let _ = myBoostSlots
                return ChannelBoostStatus(level: Int(level), boosts: Int(boosts), giftBoosts: giftBoosts.flatMap(Int.init), currentLevelBoosts: Int(currentLevelBoosts), nextLevelBoosts: nextLevelBoosts.flatMap(Int.init), premiumAudience: premiumAudience.flatMap({ StatsPercentValue(apiPercentValue: $0) }), url: boostUrl, prepaidGiveaways: prepaidGiveaways?.map({ PrepaidGiveaway(apiPrepaidGiveaway: $0) }) ?? [], boostedByMe: (flags & (1 << 2)) != 0)
            }
        }
    }
}

func _internal_applyChannelBoost(account: Account, peerId: PeerId, slots: [Int32]) -> Signal<MyBoostStatus?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<MyBoostStatus?, NoError> in
        guard let inputPeer = inputPeer else {
            return .complete()
        }
        var flags: Int32 = 0
        if !slots.isEmpty {
            flags |= (1 << 0)
        }
        
        return account.network.request(Api.functions.premium.applyBoost(flags: flags, slots: !slots.isEmpty ? slots : nil, peer: inputPeer))
        |> map (Optional.init)
        |> `catch` { error -> Signal<Api.premium.MyBoosts?, NoError> in
            return .complete()
        } 
        |> mapToSignal { result -> Signal<MyBoostStatus?, NoError> in
            if let result = result {
                return account.postbox.transaction { transaction -> MyBoostStatus? in
                    let myStatus = MyBoostStatus(apiMyBoostStatus: result, accountPeerId: account.peerId, transaction: transaction)
                    let peerIds = myStatus.boosts.reduce(Set<PeerId>(), { current, value in
                        var current = current
                        if let peerId = value.peer?.id {
                            current.insert(peerId)
                        }
                        return current
                    })
                    transaction.updatePeerCachedData(peerIds: peerIds, update: { peerId, cachedData in
                        let cachedData = cachedData as? CachedChannelData ?? CachedChannelData()
                        let count = myStatus.boosts.filter { $0.peer?.id == peerId }.count
                        return cachedData.withUpdatedAppliedBoosts(count != 0 ? Int32(count) : nil)
                    })
                    return myStatus
                }
            } else {
                return .single(nil)
            }
        }
    }
}

func _internal_getMyBoostStatus(account: Account) -> Signal<MyBoostStatus?, NoError> {
    return account.network.request(Api.functions.premium.getMyBoosts())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.premium.MyBoosts?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<MyBoostStatus?, NoError> in
        guard let result = result else {
            return .single(nil)
        }
        return account.postbox.transaction { transaction -> MyBoostStatus? in
            return MyBoostStatus(apiMyBoostStatus: result, accountPeerId: account.peerId, transaction: transaction)
        }
    }
}

private final class ChannelBoostersContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: PeerId
    private let gift: Bool
    private let disposable = MetaDisposable()
    private let updateDisposables = DisposableSet()
    private var isLoadingMore: Bool = false
    private var hasLoadedOnce: Bool = false
    private var canLoadMore: Bool = true
    private var loadedFromCache = false
    private var results: [ChannelBoostersContext.State.Boost] = []
    private var count: Int32
    private var lastOffset: String?
    private var populateCache: Bool = true
    
    let state = Promise<ChannelBoostersContext.State>()
    
    init(queue: Queue, account: Account, peerId: PeerId, gift: Bool) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
        self.gift = gift
                
        self.count = 0
            
        self.isLoadingMore = true
        self.disposable.set((account.postbox.transaction { transaction -> (peers: [ChannelBoostersContext.State.Boost], count: Int32, canLoadMore: Bool)? in
            let cachedResult = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedChannelBoosts, key: CachedChannelBoosters.key(peerId: peerId)))?.get(CachedChannelBoosters.self)
            if let cachedResult = cachedResult, !gift {
                var result: [ChannelBoostersContext.State.Boost] = []
                for boost in cachedResult.boosts {
                    let peer = boost.peerId.flatMap { transaction.getPeer($0) }
                    result.append(ChannelBoostersContext.State.Boost(flags: ChannelBoostersContext.State.Boost.Flags(rawValue: boost.flags), id: boost.id, peer: peer.flatMap { EnginePeer($0) }, date: boost.date, expires: boost.expires, multiplier: boost.multiplier, stars: boost.stars, slug: boost.slug, giveawayMessageId: boost.giveawayMessageId))
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
        if self.isLoadingMore || !self.canLoadMore {
            return
        }
        self.isLoadingMore = true
        let account = self.account
        let accountPeerId = account.peerId
        let peerId = self.peerId
        let gift = self.gift
        let populateCache = self.populateCache
        
        if self.loadedFromCache {
            self.loadedFromCache = false
        }
        let lastOffset = self.lastOffset
        
        self.disposable.set((self.account.postbox.transaction { transaction -> Api.InputPeer? in
            return transaction.getPeer(peerId).flatMap(apiInputPeer)
        }
        |> mapToSignal { inputPeer -> Signal<([ChannelBoostersContext.State.Boost], Int32, String?), NoError> in
            if let inputPeer = inputPeer {
                let offset = lastOffset ?? ""
                let limit: Int32 = lastOffset == nil ? 25 : 50
                
                var flags: Int32 = 0
                if gift {
                    flags |= (1 << 0)
                }
                let signal = account.network.request(Api.functions.premium.getBoostsList(flags: flags, peer: inputPeer, offset: offset, limit: limit))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.premium.BoostsList?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([ChannelBoostersContext.State.Boost], Int32, String?), NoError> in
                    return account.postbox.transaction { transaction -> ([ChannelBoostersContext.State.Boost], Int32, String?) in
                        guard let result = result else {
                            return ([], 0, nil)
                        }
                        switch result {
                        case let .boostsList(_, count, boosts, nextOffset, users):
                            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: AccumulatedPeers(users: users))
                            var resultBoosts: [ChannelBoostersContext.State.Boost] = []
                            for boost in boosts {
                                switch boost {
                                case let .boost(flags, id, userId, giveawayMessageId, date, expires, usedGiftSlug, multiplier, stars):
                                    var boostFlags: ChannelBoostersContext.State.Boost.Flags = []
                                    var boostPeer: EnginePeer?
                                    if let userId = userId {
                                        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId))
                                        if let peer = transaction.getPeer(peerId) {
                                            boostPeer = EnginePeer(peer)
                                        }
                                    }
                                    if (flags & (1 << 1)) != 0 {
                                        boostFlags.insert(.isGift)
                                    }
                                    if (flags & (1 << 2)) != 0 {
                                        boostFlags.insert(.isGiveaway)
                                    }
                                    if (flags & (1 << 3)) != 0 {
                                        boostFlags.insert(.isUnclaimed)
                                    }
                                    resultBoosts.append(ChannelBoostersContext.State.Boost(flags: boostFlags, id: id, peer: boostPeer, date: date, expires: expires, multiplier: multiplier ?? 1, stars: stars, slug: usedGiftSlug, giveawayMessageId: giveawayMessageId.flatMap { EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Cloud, id: $0) }))
                                }
                            }
                            if populateCache {
                                if let entry = CodableEntry(CachedChannelBoosters(channelPeerId: peerId, boosts: resultBoosts, count: count)) {
                                    transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedChannelBoosts, key: CachedChannelBoosters.key(peerId: peerId)), entry: entry)
                                }
                            }
                            return (resultBoosts, count, nextOffset)
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
            for booster in boosters {
                strongSelf.results.append(booster)
            }
            strongSelf.isLoadingMore = false
            strongSelf.hasLoadedOnce = true
            strongSelf.canLoadMore = !boosters.isEmpty && nextOffset != nil
            if strongSelf.canLoadMore {
                var resultsCount: Int32 = 0
                for result in strongSelf.results {
                    resultsCount += result.multiplier
                }
                strongSelf.count = max(updatedCount, resultsCount)
            } else {
                var resultsCount: Int32 = 0
                for result in strongSelf.results {
                    resultsCount += result.multiplier
                }
                strongSelf.count = resultsCount
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
        let resultBoosts = Array(self.results.prefix(50))
        let count = self.count
        self.updateDisposables.add(self.account.postbox.transaction({ transaction in
            if let entry = CodableEntry(CachedChannelBoosters(channelPeerId: peerId, boosts: resultBoosts, count: count)) {
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedChannelBoosts, key: CachedChannelBoosters.key(peerId: peerId)), entry: entry)
            }
        }).start())
    }
    
    private func updateState() {
        self.state.set(.single(ChannelBoostersContext.State(boosts: self.results, isLoadingMore: self.isLoadingMore, hasLoadedOnce: self.hasLoadedOnce, canLoadMore: self.canLoadMore, count: self.count)))
    }
}

public final class ChannelBoostersContext {
    public struct State: Equatable {
        public struct Boost: Equatable {
            public struct Flags: OptionSet {
                public var rawValue: Int32
                
                public init(rawValue: Int32) {
                    self.rawValue = rawValue
                }
                
                public static let isGift = Flags(rawValue: 1 << 0)
                public static let isGiveaway = Flags(rawValue: 1 << 1)
                public static let isUnclaimed = Flags(rawValue: 1 << 2)
            }
            
            public var flags: Flags
            public var id: String
            public var peer: EnginePeer?
            public var date: Int32
            public var expires: Int32
            public var multiplier: Int32
            public var stars: Int64?
            public var slug: String?
            public var giveawayMessageId: EngineMessage.Id?
        }
        public var boosts: [Boost]
        public var isLoadingMore: Bool
        public var hasLoadedOnce: Bool
        public var canLoadMore: Bool
        public var count: Int32
        
        public static var Empty = State(boosts: [], isLoadingMore: false, hasLoadedOnce: true, canLoadMore: false, count: 0)
        public static var Loading = State(boosts: [], isLoadingMore: false, hasLoadedOnce: false, canLoadMore: false, count: 0)
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
    
    public init(account: Account, peerId: PeerId, gift: Bool) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ChannelBoostersContextImpl(queue: queue, account: account, peerId: peerId, gift: gift)
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
        case boosts
        case count
    }
    
    fileprivate struct CachedBoost: Codable, Hashable {
        private enum CodingKeys: String, CodingKey {
            case flags
            case id
            case peerId
            case date
            case expires
            case multiplier
            case stars
            case slug
            case channelPeerId
            case giveawayMessageId
        }
        
        var flags: Int32
        var id: String
        var peerId: EnginePeer.Id?
        var date: Int32
        var expires: Int32
        var multiplier: Int32
        var stars: Int64?
        var slug: String?
        var channelPeerId: EnginePeer.Id
        var giveawayMessageId: EngineMessage.Id?
        
        init(flags: Int32, id: String, peerId: EnginePeer.Id?, date: Int32, expires: Int32, multiplier: Int32, stars: Int64?, slug: String?, channelPeerId: EnginePeer.Id, giveawayMessageId: EngineMessage.Id?) {
            self.flags = flags
            self.id = id
            self.peerId = peerId
            self.date = date
            self.expires = expires
            self.multiplier = multiplier
            self.stars = stars
            self.slug = slug
            self.channelPeerId = channelPeerId
            self.giveawayMessageId = giveawayMessageId
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.flags = try container.decode(Int32.self, forKey: .flags)
            self.id = try container.decode(String.self, forKey: .id)
            self.peerId = try container.decodeIfPresent(Int64.self, forKey: .peerId).flatMap { EnginePeer.Id($0) }
            self.date = try container.decode(Int32.self, forKey: .date)
            self.expires = try container.decode(Int32.self, forKey: .expires)
            self.multiplier = try container.decode(Int32.self, forKey: .multiplier)
            self.stars = try container.decodeIfPresent(Int64.self, forKey: .stars)
            self.slug = try container.decodeIfPresent(String.self, forKey: .slug)
            self.channelPeerId = EnginePeer.Id(try container.decode(Int64.self, forKey: .channelPeerId))
            self.giveawayMessageId = try container.decodeIfPresent(Int32.self, forKey: .giveawayMessageId).flatMap { EngineMessage.Id(peerId: self.channelPeerId, namespace: Namespaces.Message.Cloud, id: $0) }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            try container.encode(self.flags, forKey: .flags)
            try container.encode(self.id, forKey: .id)
            try container.encodeIfPresent(self.peerId?.toInt64(), forKey: .peerId)
            try container.encode(self.date, forKey: .date)
            try container.encode(self.expires, forKey: .expires)
            try container.encode(self.multiplier, forKey: .multiplier)
            try container.encodeIfPresent(self.stars, forKey: .stars)
            try container.encodeIfPresent(self.slug, forKey: .slug)
            try container.encode(self.channelPeerId.toInt64(), forKey: .channelPeerId)
            try container.encodeIfPresent(self.giveawayMessageId?.id, forKey: .giveawayMessageId)
        }
    }
    
    fileprivate let boosts: [CachedBoost]
    fileprivate let count: Int32
    
    static func key(peerId: EnginePeer.Id) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    init(channelPeerId: EnginePeer.Id, boosts: [ChannelBoostersContext.State.Boost], count: Int32) {
        self.boosts = boosts.map { CachedBoost(flags: $0.flags.rawValue, id: $0.id, peerId: $0.peer?.id, date: $0.date, expires: $0.expires, multiplier: $0.multiplier, stars: $0.stars, slug: $0.slug, channelPeerId: channelPeerId, giveawayMessageId: $0.giveawayMessageId) }
        self.count = count
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.boosts = (try container.decode([CachedBoost].self, forKey: .boosts))
        self.count = try container.decode(Int32.self, forKey: .count)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.boosts, forKey: .boosts)
        try container.encode(self.count, forKey: .count)
    }
}

extension MyBoostStatus {
    init(apiMyBoostStatus: Api.premium.MyBoosts, accountPeerId: PeerId, transaction: Transaction) {
        var boostsResult: [MyBoostStatus.Boost] = []
        switch apiMyBoostStatus {
        case let .myBoosts(myBoosts, chats, users):
            let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
            for boost in myBoosts {
                switch boost {
                case let .myBoost(_, slot, peer, date, expires, cooldownUntilDate):
                    var boostPeer: EnginePeer?
                    if let peerId = peer?.peerId, let peer = transaction.getPeer(peerId) {
                        boostPeer = EnginePeer(peer)
                    }
                    boostsResult.append(MyBoostStatus.Boost(slot: slot, peer: boostPeer, date: date, expires: expires, cooldownUntil: cooldownUntilDate))
                }
            }
        }
        self.boosts = boostsResult
    }
}
