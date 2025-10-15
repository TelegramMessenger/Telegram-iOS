import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit

public struct StarsRevenueStats: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case topHoursGraph
        case revenueGraph
        case balances
        case usdRate
    }
    
    static func key(peerId: PeerId, ton: Bool) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        key.setInt32(8, value: ton ? 1 : 0)
        return key
    }
    
    public struct Balances: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case currentBalance
            case availableBalance
            case overallRevenue
            case withdrawEnabled
            case nextWithdrawalTimestamp
            
            case currentBalanceStars
            case availableBalanceStars
            case overallRevenueStars
        }
        
        public let currentBalance: CurrencyAmount
        public let availableBalance: CurrencyAmount
        public let overallRevenue: CurrencyAmount
        public let withdrawEnabled: Bool
        public let nextWithdrawalTimestamp: Int32?
        
        public init(
            currentBalance: CurrencyAmount,
            availableBalance: CurrencyAmount,
            overallRevenue: CurrencyAmount,
            withdrawEnabled: Bool,
            nextWithdrawalTimestamp: Int32?
        ) {
            self.currentBalance = currentBalance
            self.availableBalance = availableBalance
            self.overallRevenue = overallRevenue
            self.withdrawEnabled = withdrawEnabled
            self.nextWithdrawalTimestamp = nextWithdrawalTimestamp
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            if let legacyCurrentBalance = try container.decodeIfPresent(StarsAmount.self, forKey: .currentBalanceStars) {
                self.currentBalance = CurrencyAmount(amount: legacyCurrentBalance, currency: .stars)
            } else {
                self.currentBalance = try container.decode(CurrencyAmount.self, forKey: .currentBalance)
            }
            
            if let legacyAvailableBalance = try container.decodeIfPresent(StarsAmount.self, forKey: .availableBalanceStars) {
                self.availableBalance = CurrencyAmount(amount: legacyAvailableBalance, currency: .stars)
            } else {
                self.availableBalance = try container.decode(CurrencyAmount.self, forKey: .availableBalance)
            }
            
            if let legacyOverallRevenue = try container.decodeIfPresent(StarsAmount.self, forKey: .overallRevenueStars) {
                self.overallRevenue = CurrencyAmount(amount: legacyOverallRevenue, currency: .stars)
            } else {
                self.overallRevenue = try container.decode(CurrencyAmount.self, forKey: .overallRevenue)
            }
            
            self.withdrawEnabled = try container.decode(Bool.self, forKey: .withdrawEnabled)
            self.nextWithdrawalTimestamp = try container.decodeIfPresent(Int32.self, forKey: .nextWithdrawalTimestamp)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.currentBalance, forKey: .currentBalance)
            try container.encode(self.availableBalance, forKey: .availableBalance)
            try container.encode(self.overallRevenue, forKey: .overallRevenue)
            try container.encode(self.withdrawEnabled, forKey: .withdrawEnabled)
            try container.encodeIfPresent(self.nextWithdrawalTimestamp, forKey: .nextWithdrawalTimestamp)
        }
    }
    
    public let topHoursGraph: StatsGraph?
    public let revenueGraph: StatsGraph
    public let balances: Balances
    public let usdRate: Double
    
    init(topHoursGraph: StatsGraph?, revenueGraph: StatsGraph, balances: Balances, usdRate: Double) {
        self.topHoursGraph = topHoursGraph
        self.revenueGraph = revenueGraph
        self.balances = balances
        self.usdRate = usdRate
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.topHoursGraph = try container.decodeIfPresent(StatsGraph.self, forKey: .topHoursGraph)
        self.revenueGraph = try container.decode(StatsGraph.self, forKey: .revenueGraph)
        self.balances = try container.decode(Balances.self, forKey: .balances)
        self.usdRate = try container.decode(Double.self, forKey: .usdRate)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.topHoursGraph, forKey: .topHoursGraph)
        try container.encode(self.revenueGraph, forKey: .revenueGraph)
        try container.encode(self.balances, forKey: .balances)
        try container.encode(self.usdRate, forKey: .usdRate)
    }
    
    public static func == (lhs: StarsRevenueStats, rhs: StarsRevenueStats) -> Bool {
        if lhs.topHoursGraph != rhs.topHoursGraph {
            return false
        }
        if lhs.revenueGraph != rhs.revenueGraph {
            return false
        }
        if lhs.balances != rhs.balances {
            return false
        }
        if lhs.usdRate != rhs.usdRate {
            return false
        }
        return true
    }
}

public extension StarsRevenueStats {
    func withUpdated(balances: StarsRevenueStats.Balances) -> StarsRevenueStats {
        return StarsRevenueStats(
            topHoursGraph: self.topHoursGraph,
            revenueGraph: self.revenueGraph,
            balances: balances,
            usdRate: self.usdRate
        )
    }
}

extension StarsRevenueStats {
    init(apiStarsRevenueStats: Api.payments.StarsRevenueStats, peerId: PeerId) {
        switch apiStarsRevenueStats {
        case let .starsRevenueStats(_, topHoursGraph, revenueGraph, balances, usdRate):
            self.init(topHoursGraph: topHoursGraph.flatMap { StatsGraph(apiStatsGraph: $0) }, revenueGraph: StatsGraph(apiStatsGraph: revenueGraph), balances: StarsRevenueStats.Balances(apiStarsRevenueStatus: balances), usdRate: usdRate)
        }
    }
}

extension StarsRevenueStats.Balances {
    init(apiStarsRevenueStatus: Api.StarsRevenueStatus) {
        switch apiStarsRevenueStatus {
        case let .starsRevenueStatus(flags, currentBalance, availableBalance, overallRevenue, nextWithdrawalAt):
            self.init(currentBalance: CurrencyAmount(apiAmount: currentBalance), availableBalance: CurrencyAmount(apiAmount: availableBalance), overallRevenue: CurrencyAmount(apiAmount: overallRevenue), withdrawEnabled: ((flags & (1 << 0)) != 0), nextWithdrawalTimestamp: nextWithdrawalAt)
        }
    }
}

public struct StarsRevenueStatsContextState: Equatable {
    public var stats: StarsRevenueStats?
}

private func requestStarsRevenueStats(postbox: Postbox, network: Network, peerId: PeerId, ton: Bool, dark: Bool = false) -> Signal<StarsRevenueStats?, NoError> {
    return postbox.transaction { transaction -> Peer? in
        if let peer = transaction.getPeer(peerId) {
            return peer
        }
        return nil
    } |> mapToSignal { peer -> Signal<StarsRevenueStats?, NoError> in
        guard let peer, let inputPeer = apiInputPeer(peer) else {
            return .never()
        }
        
        var flags: Int32 = 0
        if ton {
            flags |= (1 << 1)
        }
        if dark {
            flags |= (1 << 0)
        }
        
        return network.request(Api.functions.payments.getStarsRevenueStats(flags: flags, peer: inputPeer))
        |> retryRequestIfNotFrozen
        |> map { result -> StarsRevenueStats? in
            guard let result else {
                return nil
            }
            return StarsRevenueStats(apiStarsRevenueStats: result, peerId: peerId)
        }
        
    }
}

private final class StarsRevenueStatsContextImpl {
    private let account: Account
    private let peerId: PeerId
    private let ton: Bool
    
    private var _state: StarsRevenueStatsContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<StarsRevenueStatsContextState>()
    var state: Signal<StarsRevenueStatsContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    private let updateDisposable = MetaDisposable()
    
    init(account: Account, peerId: PeerId, ton: Bool) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self.peerId = peerId
        self.ton = ton
        self._state = StarsRevenueStatsContextState(stats: nil)
        self._statePromise.set(.single(self._state))
        
        self.load()
        
        let _ = (account.postbox.transaction { transaction -> StarsRevenueStats? in
            return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStarsRevenueStats, key: StarsRevenueStats.key(peerId: peerId, ton: ton)))?.get(StarsRevenueStats.self)
        }
        |> deliverOnMainQueue).start(next: { [weak self] cachedResult in
            guard let self, let cachedResult else {
                return
            }
            self._state = StarsRevenueStatsContextState(stats: cachedResult)
            self._statePromise.set(.single(self._state))
        })
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
        self.updateDisposable.dispose()
    }
    
    public func setUpdated(_ f: @escaping () -> Void) {
        let peerId = self.peerId
        self.updateDisposable.set((account.stateManager.updatedStarsRevenueStatus()
        |> deliverOnMainQueue).startStrict(next: { updates in
            if let _ = updates[peerId] {
                f()
            }
        }))
    }
    
    fileprivate func load() {
        assert(Queue.mainQueue().isCurrent())
        
        let account = self.account
        let peerId = self.peerId
        let ton = self.ton
        let signal = requestStarsRevenueStats(postbox: self.account.postbox, network: self.account.network, peerId: self.peerId, ton: self.ton)
        |> mapToSignal { initial -> Signal<StarsRevenueStats?, NoError> in
            guard let initial else {
                return .single(nil)
            }
            return .single(initial)
            |> then(
                account.stateManager.updatedStarsRevenueStatus()
                |> mapToSignal { updates in
                    if let balances = updates[peerId] {
                        return .single(initial.withUpdated(balances: balances))
                    }
                    return .complete()
                }
            )
        }
        
        self.disposable.set((signal
        |> deliverOnMainQueue).start(next: { [weak self] stats in
            if let self {
                self._state = StarsRevenueStatsContextState(stats: stats)
                self._statePromise.set(.single(self._state))
                
                if let stats {
                    let _ = (self.account.postbox.transaction { transaction in
                        if let entry = CodableEntry(stats) {
                            transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedStarsRevenueStats, key: StarsRevenueStats.key(peerId: peerId, ton: ton)), entry: entry)
                        }
                    }).start()
                }
            }
        }))
    }
        
    func loadDetailedGraph(_ graph: StatsGraph, x: Int64) -> Signal<StatsGraph?, NoError> {
        if let token = graph.token {
            return requestGraph(postbox: self.account.postbox, network: self.account.network, peerId: self.peerId, token: token, x: x)
        } else {
            return .single(nil)
        }
    }
}

public final class StarsRevenueStatsContext {
    private let impl: QueueLocalObject<StarsRevenueStatsContextImpl>
    
    public var state: Signal<StarsRevenueStatsContextState, NoError> {
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
    
    public init(account: Account, peerId: PeerId, ton: Bool) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return StarsRevenueStatsContextImpl(account: account, peerId: peerId, ton: ton)
        })
    }
    
    public func setUpdated(_ f: @escaping () -> Void) {
        self.impl.with { impl in
            impl.setUpdated(f)
        }
    }
    
    public func reload() {
        self.impl.with { impl in
            impl.load()
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

public enum RequestStarsRevenueWithdrawalError : Equatable {
    case generic
    case twoStepAuthMissing
    case twoStepAuthTooFresh(Int32)
    case authSessionTooFresh(Int32)
    case limitExceeded
    case requestPassword
    case invalidPassword
    case serverProvided(text: String)
}

func _internal_checkStarsRevenueWithdrawalAvailability(account: Account) -> Signal<Never, RequestStarsRevenueWithdrawalError> {
    return account.network.request(Api.functions.payments.getStarsRevenueWithdrawalUrl(flags: 0, peer: .inputPeerEmpty, amount: nil, password: .inputCheckPasswordEmpty))
    |> mapError { error -> RequestStarsRevenueWithdrawalError in
        if error.errorDescription == "PASSWORD_HASH_INVALID" {
            return .requestPassword
        } else if error.errorDescription == "PASSWORD_MISSING" {
            return .twoStepAuthMissing
        } else if error.errorDescription.hasPrefix("PASSWORD_TOO_FRESH_") {
            let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "PASSWORD_TOO_FRESH_".count)...])
            if let value = Int32(timeout) {
                return .twoStepAuthTooFresh(value)
            }
        } else if error.errorDescription.hasPrefix("SESSION_TOO_FRESH_") {
            let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "SESSION_TOO_FRESH_".count)...])
            if let value = Int32(timeout) {
                return .authSessionTooFresh(value)
            }
        }
        return .generic
    }
    |> ignoreValues
}

func _internal_requestStarsRevenueWithdrawalUrl(account: Account, ton: Bool, peerId: PeerId, amount: Int64?, password: String) -> Signal<String, RequestStarsRevenueWithdrawalError> {
    guard !password.isEmpty else {
        return .fail(.invalidPassword)
    }
    
    return account.postbox.transaction { transaction -> Signal<String, RequestStarsRevenueWithdrawalError> in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
            
        let checkPassword = _internal_twoStepAuthData(account.network)
        |> mapError { error -> RequestStarsRevenueWithdrawalError in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .limitExceeded
            } else {
                return .generic
            }
        }
        |> mapToSignal { authData -> Signal<Api.InputCheckPasswordSRP, RequestStarsRevenueWithdrawalError> in
            if let currentPasswordDerivation = authData.currentPasswordDerivation, let srpSessionData = authData.srpSessionData {
                guard let kdfResult = passwordKDF(encryptionProvider: account.network.encryptionProvider, password: password, derivation: currentPasswordDerivation, srpSessionData: srpSessionData) else {
                    return .fail(.generic)
                }
                return .single(.inputCheckPasswordSRP(srpId: kdfResult.id, A: Buffer(data: kdfResult.A), M1: Buffer(data: kdfResult.M1)))
            } else {
                return .fail(.twoStepAuthMissing)
            }
        }
        
        return checkPassword
        |> mapToSignal { password -> Signal<String, RequestStarsRevenueWithdrawalError> in
            var flags: Int32 = 0
            if ton {
                flags |= 1 << 0
            } else {
                flags |= 1 << 1
            }
            return account.network.request(Api.functions.payments.getStarsRevenueWithdrawalUrl(flags: flags, peer: inputPeer, amount: amount, password: password), automaticFloodWait: false)
            |> mapError { error -> RequestStarsRevenueWithdrawalError in
                if error.errorCode == 406 {
                    return .serverProvided(text: error.errorDescription)
                } else if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                    return .limitExceeded
                } else if error.errorDescription == "PASSWORD_HASH_INVALID" {
                    return .invalidPassword
                } else if error.errorDescription == "PASSWORD_MISSING" {
                    return .twoStepAuthMissing
                } else if error.errorDescription.hasPrefix("PASSWORD_TOO_FRESH_") {
                    let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "PASSWORD_TOO_FRESH_".count)...])
                    if let value = Int32(timeout) {
                        return .twoStepAuthTooFresh(value)
                    }
                } else if error.errorDescription.hasPrefix("SESSION_TOO_FRESH_") {
                    let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "SESSION_TOO_FRESH_".count)...])
                    if let value = Int32(timeout) {
                        return .authSessionTooFresh(value)
                    }
                }
                return .generic
            }
            |> map { result -> String in
                switch result {
                case let .starsRevenueWithdrawalUrl(url):
                    return url
                }
            }
        }
    }
    |> mapError { _ -> RequestStarsRevenueWithdrawalError in }
    |> switchToLatest
}

func _internal_requestStarsRevenueAdsAccountlUrl(account: Account, peerId: EnginePeer.Id) -> Signal<String?, NoError> {
    return account.postbox.transaction { transaction -> Signal<String?, NoError> in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return .single(nil)
        }
        return account.network.request(Api.functions.payments.getStarsRevenueAdsAccountUrl(peer: inputPeer))
        |> map(Optional.init)
        |> `catch` { error -> Signal<Api.payments.StarsRevenueAdsAccountUrl?, NoError> in
            return .single(nil)
        }
        |> map { result -> String? in
            guard let result else {
                return nil
            }
            switch result {
            case let .starsRevenueAdsAccountUrl(url):
                return url
            }
        }
    }
    |> switchToLatest
}
