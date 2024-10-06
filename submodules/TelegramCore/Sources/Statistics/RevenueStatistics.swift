import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit

public struct RevenueStats: Equatable, Codable {
    private enum CodingKeys: String, CodingKey {
        case topHoursGraph
        case revenueGraph
        case balances
        case usdRate
    }
    
    static func key(peerId: PeerId) -> ValueBoxKey {
        let key = ValueBoxKey(length: 8 + 4)
        key.setInt64(0, value: peerId.toInt64())
        return key
    }
    
    public struct Balances: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case currentBalance
            case availableBalance
            case overallRevenue
            case withdrawEnabled
        }
        
        public let currentBalance: Int64
        public let availableBalance: Int64
        public let overallRevenue: Int64
        public let withdrawEnabled: Bool
        
        init(
            currentBalance: Int64,
            availableBalance: Int64,
            overallRevenue: Int64,
            withdrawEnabled: Bool
        ) {
            self.currentBalance = currentBalance
            self.availableBalance = availableBalance
            self.overallRevenue = overallRevenue
            self.withdrawEnabled = withdrawEnabled
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.currentBalance = try container.decode(Int64.self, forKey: .currentBalance)
            self.availableBalance = try container.decode(Int64.self, forKey: .availableBalance)
            self.overallRevenue = try container.decode(Int64.self, forKey: .overallRevenue)
            self.withdrawEnabled = try container.decode(Bool.self, forKey: .withdrawEnabled)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.currentBalance, forKey: .currentBalance)
            try container.encode(self.availableBalance, forKey: .availableBalance)
            try container.encode(self.overallRevenue, forKey: .overallRevenue)
            try container.encode(self.withdrawEnabled, forKey: .withdrawEnabled)
        }
    }
    
    public let topHoursGraph: StatsGraph
    public let revenueGraph: StatsGraph
    public let balances: Balances
    public let usdRate: Double
    
    init(topHoursGraph: StatsGraph, revenueGraph: StatsGraph, balances: Balances, usdRate: Double) {
        self.topHoursGraph = topHoursGraph
        self.revenueGraph = revenueGraph
        self.balances = balances
        self.usdRate = usdRate
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.topHoursGraph = try container.decode(StatsGraph.self, forKey: .topHoursGraph)
        self.revenueGraph = try container.decode(StatsGraph.self, forKey: .revenueGraph)
        self.balances = try container.decode(Balances.self, forKey: .balances)
        self.usdRate = try container.decode(Double.self, forKey: .usdRate)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.topHoursGraph, forKey: .topHoursGraph)
        try container.encode(self.revenueGraph, forKey: .revenueGraph)
        try container.encode(self.balances, forKey: .balances)
        try container.encode(self.usdRate, forKey: .usdRate)
    }
    
    public static func == (lhs: RevenueStats, rhs: RevenueStats) -> Bool {
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

public extension RevenueStats {
    func withUpdated(balances: RevenueStats.Balances) -> RevenueStats {
        return RevenueStats(
            topHoursGraph: self.topHoursGraph,
            revenueGraph: self.revenueGraph,
            balances: balances,
            usdRate: self.usdRate
        )
    }
}

extension RevenueStats {
    init(apiRevenueStats: Api.stats.BroadcastRevenueStats, peerId: PeerId) {
        switch apiRevenueStats {
        case let .broadcastRevenueStats(topHoursGraph, revenueGraph, balances, usdRate):
            self.init(topHoursGraph: StatsGraph(apiStatsGraph: topHoursGraph), revenueGraph: StatsGraph(apiStatsGraph: revenueGraph), balances: RevenueStats.Balances(apiRevenueBalances: balances), usdRate: usdRate)
        }
    }
}

extension RevenueStats.Balances {
    init(apiRevenueBalances: Api.BroadcastRevenueBalances) {
        switch apiRevenueBalances {
        case let .broadcastRevenueBalances(flags, currentBalance, availableBalance, overallRevenue):
            self.init(currentBalance: currentBalance, availableBalance: availableBalance, overallRevenue: overallRevenue, withdrawEnabled: ((flags & (1 << 0)) != 0))
        }
    }
}

public struct RevenueStatsContextState: Equatable {
    public var stats: RevenueStats?
}

private func requestRevenueStats(postbox: Postbox, network: Network, peerId: PeerId, dark: Bool = false) -> Signal<RevenueStats?, NoError> {
    return postbox.transaction { transaction -> Peer? in
        if let peer = transaction.getPeer(peerId) {
            return peer
        }
        return nil
    } |> mapToSignal { peer -> Signal<RevenueStats?, NoError> in
        guard let peer, let inputChannel = apiInputChannel(peer) else {
            return .never()
        }
        
        var flags: Int32 = 0
        if dark {
            flags |= (1 << 1)
        }
        
        return network.request(Api.functions.stats.getBroadcastRevenueStats(flags: flags, channel: inputChannel))
        |> map { result -> RevenueStats? in
            return RevenueStats(apiRevenueStats: result, peerId: peerId)
        }
        |> retryRequest
    }
}

private final class RevenueStatsContextImpl {
    private let account: Account
    private let peerId: PeerId
    
    private var _state: RevenueStatsContextState {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
    private let _statePromise = Promise<RevenueStatsContextState>()
    var state: Signal<RevenueStatsContextState, NoError> {
        return self._statePromise.get()
    }
    
    private let disposable = MetaDisposable()
    
    init(account: Account, peerId: PeerId) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self.peerId = peerId
        self._state = RevenueStatsContextState(stats: nil)
        self._statePromise.set(.single(self._state))
        
        self.load()
        
        let _ = (account.postbox.transaction { transaction -> RevenueStats? in
            return transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedRevenueStats, key: StarsRevenueStats.key(peerId: peerId)))?.get(RevenueStats.self)
        }
        |> deliverOnMainQueue).start(next: { [weak self] cachedResult in
            guard let self, let cachedResult else {
                return
            }
            self._state = RevenueStatsContextState(stats: cachedResult)
            self._statePromise.set(.single(self._state))
        })
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
    }
    
    fileprivate func load() {
        assert(Queue.mainQueue().isCurrent())
        
        let account = self.account
        let peerId = self.peerId
        let signal = requestRevenueStats(postbox: self.account.postbox, network: self.account.network, peerId: self.peerId)
        |> mapToSignal { initial -> Signal<RevenueStats?, NoError> in
            guard let initial else {
                return .single(nil)
            }
            return .single(initial)
            |> then(
                account.stateManager.updatedRevenueBalances()
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
                self._state = RevenueStatsContextState(stats: stats)
                self._statePromise.set(.single(self._state))
                
                if let stats {
                    let _ = (self.account.postbox.transaction { transaction in
                        if let entry = CodableEntry(stats) {
                            transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedRevenueStats, key: StarsRevenueStats.key(peerId: peerId)), entry: entry)
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

public final class RevenueStatsContext {
    private let impl: QueueLocalObject<RevenueStatsContextImpl>
    
    public var state: Signal<RevenueStatsContextState, NoError> {
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
    
    public init(account: Account, peerId: PeerId) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return RevenueStatsContextImpl(account: account, peerId: peerId)
        })
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

private final class RevenueStatsTransactionsContextImpl {
    private let queue: Queue
    private let account: Account
    private let peerId: EnginePeer.Id
    private let disposable = MetaDisposable()
    private var updateDisposable: Disposable?
    private var isLoadingMore: Bool = false
    private var hasLoadedOnce: Bool = false
    private var canLoadMore: Bool = true
    private var results: [RevenueStatsTransactionsContext.State.Transaction] = []
    private var count: Int32
    private var lastOffset: Int32?
    
    let state = Promise<RevenueStatsTransactionsContext.State>()
    
    init(queue: Queue, account: Account, peerId: EnginePeer.Id) {
        self.queue = queue
        self.account = account
        self.peerId = peerId
                
        self.count = 0
            
        self.loadMore()
        
        self.updateDisposable = (account.stateManager.updatedRevenueBalances()
        |> deliverOn(self.queue)).startStrict(next: { [weak self] _ in
            self?.reload()
        })
    }
    
    deinit {
        self.disposable.dispose()
        self.updateDisposable?.dispose()
    }
    
    func reload() {
        self.lastOffset = nil
        
        self.loadMore()
    }
    
    func loadMore() {
        if self.isLoadingMore || !self.canLoadMore {
            return
        }
        self.isLoadingMore = true
        let account = self.account
        let peerId = self.peerId
        let lastOffset = self.lastOffset
        
        self.disposable.set((self.account.postbox.transaction { transaction -> Peer? in
            guard let peer = transaction.getPeer(peerId) else {
                return nil
            }
            return peer
        }
        |> mapToSignal { peer -> Signal<([RevenueStatsTransactionsContext.State.Transaction], Int32, Int32?), NoError> in
            if let peer {
                guard let inputChannel = apiInputChannel(peer) else {
                    return .complete()
                }
                let offset = lastOffset ?? 0
                let limit: Int32 = lastOffset == nil ? 25 : 50
                
                return account.network.request(Api.functions.stats.getBroadcastRevenueTransactions(channel: inputChannel, offset: offset, limit: limit), automaticFloodWait: false)
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.stats.BroadcastRevenueTransactions?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<([RevenueStatsTransactionsContext.State.Transaction], Int32, Int32?), NoError> in
                    return account.postbox.transaction { transaction -> ([RevenueStatsTransactionsContext.State.Transaction], Int32, Int32?) in
                        guard let result = result else {
                            return ([], 0, nil)
                        }
                        switch result {
                        case let .broadcastRevenueTransactions(count, transactions):
                            let nextOffset = offset + Int32(transactions.count)
                            var resultTransactions: [RevenueStatsTransactionsContext.State.Transaction] = []
                            for transaction in transactions {
                                switch transaction {
                                case let .broadcastRevenueTransactionProceeds(amount, fromDate, toDate):
                                    resultTransactions.append(.proceeds(amount: amount, fromDate: fromDate, toDate: toDate))
                                case let .broadcastRevenueTransactionRefund(amount, date, provider):
                                    resultTransactions.append(.refund(amount: amount, date: date, provider: provider))
                                case let .broadcastRevenueTransactionWithdrawal(flags, amount, date, provider, transactionDate, transactionUrl):
                                    let status: RevenueStatsTransactionsContext.State.Transaction.WithdrawalStatus
                                    if (flags & (1 << 0)) != 0 {
                                        status = .pending
                                    } else if (flags & (1 << 2)) != 0 {
                                        status = .failed
                                    } else {
                                        status = .succeed
                                    }
                                    resultTransactions.append(.withdrawal(status: status, amount: amount, date: date, provider: provider, transactionDate: transactionDate, transactionUrl: transactionUrl))
                                }
                            }
                            return (resultTransactions, count, nextOffset)
                        }
                    }
                }
            } else {
                return .single(([], 0, nil))
            }
        }
        |> deliverOn(self.queue)).start(next: { [weak self] transactions, updatedCount, nextOffset in
            guard let strongSelf = self else {
                return
            }
            strongSelf.lastOffset = nextOffset
            for transaction in transactions {
                strongSelf.results.append(transaction)
            }
            strongSelf.isLoadingMore = false
            strongSelf.hasLoadedOnce = true
            strongSelf.canLoadMore = !transactions.isEmpty && nextOffset != nil
            if strongSelf.canLoadMore {
                strongSelf.count = max(updatedCount, Int32(strongSelf.results.count))
            } else {
                strongSelf.count = Int32(strongSelf.results.count)
            }
            strongSelf.updateState()
        }))
        self.updateState()
    }
        
    private func updateState() {
        self.state.set(.single(RevenueStatsTransactionsContext.State(transactions: self.results, isLoadingMore: self.isLoadingMore, hasLoadedOnce: self.hasLoadedOnce, canLoadMore: self.canLoadMore, count: self.count)))
    }
}

public final class RevenueStatsTransactionsContext {
    public struct State: Equatable {
        public enum Transaction: Equatable {
            public enum WithdrawalStatus {
                case succeed
                case pending
                case failed
            }
            case proceeds(amount: Int64, fromDate: Int32, toDate: Int32)
            case withdrawal(status: WithdrawalStatus, amount: Int64, date: Int32, provider: String, transactionDate: Int32?, transactionUrl: String?)
            case refund(amount: Int64, date: Int32, provider: String)
            
            public var amount: Int64 {
                switch self {
                case let .proceeds(amount, _, _), let .withdrawal(_, amount, _, _, _, _), let .refund(amount, _, _):
                    return amount
                }
            }
        }
        public var transactions: [Transaction]
        public var isLoadingMore: Bool
        public var hasLoadedOnce: Bool
        public var canLoadMore: Bool
        public var count: Int32
        
        public static var Empty = State(transactions: [], isLoadingMore: false, hasLoadedOnce: true, canLoadMore: false, count: 0)
        public static var Loading = State(transactions: [], isLoadingMore: false, hasLoadedOnce: false, canLoadMore: false, count: 0)
    }

    
    private let queue: Queue = Queue()
    private let impl: QueueLocalObject<RevenueStatsTransactionsContextImpl>
    
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

    public init(account: Account, peerId: EnginePeer.Id) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return RevenueStatsTransactionsContextImpl(queue: queue, account: account, peerId: peerId)
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

public enum RequestRevenueWithdrawalError : Equatable {
    case generic
    case twoStepAuthMissing
    case twoStepAuthTooFresh(Int32)
    case authSessionTooFresh(Int32)
    case limitExceeded
    case requestPassword
    case invalidPassword
}

func _internal_checkChannelRevenueWithdrawalAvailability(account: Account) -> Signal<Never, RequestRevenueWithdrawalError> {
    return account.network.request(Api.functions.stats.getBroadcastRevenueWithdrawalUrl(channel: .inputChannelEmpty, password: .inputCheckPasswordEmpty))
    |> mapError { error -> RequestRevenueWithdrawalError in
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

func _internal_requestChannelRevenueWithdrawalUrl(account: Account, peerId: PeerId, password: String) -> Signal<String, RequestRevenueWithdrawalError> {
    guard !password.isEmpty else {
        return .fail(.invalidPassword)
    }
    
    return account.postbox.transaction { transaction -> Signal<String, RequestRevenueWithdrawalError> in
        guard let channel = transaction.getPeer(peerId) as? TelegramChannel, let inputChannel = apiInputChannel(channel) else {
            return .fail(.generic)
        }
            
        let checkPassword = _internal_twoStepAuthData(account.network)
        |> mapError { error -> RequestRevenueWithdrawalError in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .limitExceeded
            } else {
                return .generic
            }
        }
        |> mapToSignal { authData -> Signal<Api.InputCheckPasswordSRP, RequestRevenueWithdrawalError> in
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
        |> mapToSignal { password -> Signal<String, RequestRevenueWithdrawalError> in
            return account.network.request(Api.functions.stats.getBroadcastRevenueWithdrawalUrl(channel: inputChannel, password: password), automaticFloodWait: false)
            |> mapError { error -> RequestRevenueWithdrawalError in
                if error.errorDescription.hasPrefix("FLOOD_WAIT") {
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
                case let .broadcastRevenueWithdrawalUrl(url):
                    return url
                }
            }
        }
    }
    |> mapError { _ -> RequestRevenueWithdrawalError in }
    |> switchToLatest
}
