import Foundation
import Postbox
import MtProtoKit
import SwiftSignalKit
import TelegramApi

public struct StarsTopUpOption: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case count
        case storeProductId
        case currency
        case amount
    }
    
    public let count: Int64
    public let storeProductId: String?
    public let currency: String
    public let amount: Int64
    
    public init(count: Int64, storeProductId: String?, currency: String, amount: Int64) {
        self.count = count
        self.storeProductId = storeProductId
        self.currency = currency
        self.amount = amount
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.count = try container.decode(Int64.self, forKey: .count)
        self.storeProductId = try container.decodeIfPresent(String.self, forKey: .storeProductId)
        self.currency = try container.decode(String.self, forKey: .currency)
        self.amount = try container.decode(Int64.self, forKey: .amount)

    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.count, forKey: .count)
        try container.encodeIfPresent(self.storeProductId, forKey: .storeProductId)
        try container.encode(self.currency, forKey: .currency)
        try container.encode(self.amount, forKey: .amount)
    }
}

extension StarsTopUpOption {
    init(apiStarsTopupOption: Api.StarsTopupOption) {
        switch apiStarsTopupOption {
        case let .starsTopupOption(_, stars, storeProduct, currency, amount):
            self.init(count: stars, storeProductId: storeProduct, currency: currency, amount: amount)
        }
    }
}

func _internal_starsTopUpOptions(account: Account) -> Signal<[StarsTopUpOption], NoError> {
    return account.network.request(Api.functions.payments.getStarsTopupOptions())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<[Api.StarsTopupOption]?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { results -> Signal<[StarsTopUpOption], NoError> in
        if let results = results {
            return .single(results.map { StarsTopUpOption(apiStarsTopupOption: $0) })
        } else {
            return .single([])
        }
    }
}

struct InternalStarsStatus {
    let balance: Int64
    let transactions: [StarsContext.State.Transaction]
    let nextOffset: String?
}

private enum RequestStarsStateError {
    case generic
}

private func _internal_requestStarsState(account: Account, peerId: EnginePeer.Id, subject: StarsTransactionsContext.Subject, offset: String?) -> Signal<InternalStarsStatus, RequestStarsStateError> {
    return account.postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    } 
    |> castError(RequestStarsStateError.self)
    |> mapToSignal { peer -> Signal<InternalStarsStatus, RequestStarsStateError> in
        guard let peer, let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
                
        let signal: Signal<Api.payments.StarsStatus, MTRpcError>
        if let offset {
            var flags: Int32 = 0
            switch subject {
            case .incoming:
                flags = 1 << 0
            case .outgoing:
                flags = 1 << 1
            default:
                break
            }
            signal = account.network.request(Api.functions.payments.getStarsTransactions(flags: flags, peer: inputPeer, offset: offset))
        } else {
            signal = account.network.request(Api.functions.payments.getStarsStatus(peer: inputPeer))
        }
        
        return signal
        |> retryRequest
        |> castError(RequestStarsStateError.self)
        |> mapToSignal { result -> Signal<InternalStarsStatus, RequestStarsStateError> in
            return account.postbox.transaction { transaction -> InternalStarsStatus in
                switch result {
                case let .starsStatus(_, balance, history, nextOffset, chats, users):
                    let peers = AccumulatedPeers(chats: chats, users: users)
                    updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: peers)
                    
                    var parsedTransactions: [StarsContext.State.Transaction] = []
                    for entry in history {
                        if let parsedTransaction = StarsContext.State.Transaction(apiTransaction: entry, transaction: transaction) {
                            parsedTransactions.append(parsedTransaction)
                        }
                    }
                    return InternalStarsStatus(balance: balance, transactions: parsedTransactions, nextOffset: nextOffset)
                }
            }
            |> castError(RequestStarsStateError.self)
        }
    }
}

private final class StarsContextImpl {
    private let account: Account
    fileprivate let peerId: EnginePeer.Id
    
    fileprivate var _state: StarsContext.State?
    private let _statePromise = Promise<StarsContext.State?>()
    var state: Signal<StarsContext.State?, NoError> {
        return self._statePromise.get()
    }
    private var nextOffset: String?
    
    private let disposable = MetaDisposable()
    private var updateDisposable: Disposable?
    
    init(account: Account, peerId: EnginePeer.Id) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self.peerId = peerId
        
        self._state = nil
        self._statePromise.set(.single(nil))
        
        self.load(force: true)
        
        self.updateDisposable = (account.stateManager.updatedStarsBalance()
        |> deliverOnMainQueue).startStrict(next: { [weak self] balances in
            guard let self, let state = self._state, let balance = balances[peerId] else {
                return
            }
            self.updateState(StarsContext.State(flags: [], balance: balance, transactions: state.transactions, canLoadMore: nextOffset != nil, isLoading: false))
            self.load(force: true)
        })
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
        self.updateDisposable?.dispose()
    }
    
    private var previousLoadTimestamp: Double?
    func load(force: Bool) {
        assert(Queue.mainQueue().isCurrent())
        
        let currentTimestamp = CFAbsoluteTimeGetCurrent()
        if let previousLoadTimestamp = self.previousLoadTimestamp, currentTimestamp - previousLoadTimestamp < 60 && !force {
            return
        }
        self.previousLoadTimestamp = currentTimestamp
        
        self.disposable.set((_internal_requestStarsState(account: self.account, peerId: self.peerId, subject: .all, offset: nil)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let self else {
                return
            }
            self.updateState(StarsContext.State(flags: [], balance: status.balance, transactions: status.transactions, canLoadMore: status.nextOffset != nil, isLoading: false))
            self.nextOffset = status.nextOffset
        }, error: { [weak self] _ in
            guard let self else {
                return
            }
            Queue.mainQueue().after(2.5, {
                self.load(force: true)
            })
        }))
    }
    
    func add(balance: Int64) {
        guard let state = self._state else {
            return
        }
        var transactions = state.transactions
        transactions.insert(.init(flags: [.isLocal], id: "\(arc4random())", count: balance, date: Int32(Date().timeIntervalSince1970), peer: .appStore, title: nil, description: nil, photo: nil), at: 0)
        
        self.updateState(StarsContext.State(flags: [.isPendingBalance], balance: state.balance + balance, transactions: transactions, canLoadMore: state.canLoadMore, isLoading: state.isLoading))
    }
    
    func loadMore() {
        assert(Queue.mainQueue().isCurrent())
        
        guard let currentState = self._state, let nextOffset = self.nextOffset else {
            return
        }

        self._state?.isLoading = true
        
        self.disposable.set((_internal_requestStarsState(account: self.account, peerId: self.peerId, subject: .all, offset: nextOffset)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let self {
                self.updateState(StarsContext.State(flags: [], balance: status.balance, transactions: currentState.transactions + status.transactions, canLoadMore: status.nextOffset != nil, isLoading: false))
                self.nextOffset = status.nextOffset
            }
        }))
    }
    
    private func updateState(_ state: StarsContext.State) {
        self._state = state
        self._statePromise.set(.single(state))
    }
}

private extension StarsContext.State.Transaction {
    init?(apiTransaction: Api.StarsTransaction, transaction: Transaction) {
        switch apiTransaction {
        case let .starsTransaction(apiFlags, id, stars, date, transactionPeer, title, description, photo):
            let parsedPeer: StarsContext.State.Transaction.Peer
            switch transactionPeer {
            case .starsTransactionPeerAppStore:
                parsedPeer = .appStore
            case .starsTransactionPeerPlayMarket:
                parsedPeer = .playMarket
            case .starsTransactionPeerFragment:
                parsedPeer = .fragment
            case .starsTransactionPeerPremiumBot:
                parsedPeer = .premiumBot
            case .starsTransactionPeerUnsupported:
                parsedPeer = .unsupported
            case let .starsTransactionPeer(apiPeer):
                guard let peer = transaction.getPeer(apiPeer.peerId) else {
                    return nil
                }
                parsedPeer = .peer(EnginePeer(peer))
            }
            
            var flags: Flags = []
            if (apiFlags & (1 << 3)) != 0 {
                flags.insert(.isRefund)
            }
            self.init(flags: flags, id: id, count: stars, date: date, peer: parsedPeer, title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init))
        }
    }
}

public final class StarsContext {
    public struct State: Equatable {
        public struct Transaction: Equatable {
            public struct Flags: OptionSet {
                public var rawValue: Int32
                
                public init(rawValue: Int32) {
                    self.rawValue = rawValue
                }
                
                public static let isRefund = Flags(rawValue: 1 << 0)
                public static let isLocal = Flags(rawValue: 1 << 1)
            }
            
            public enum Peer: Equatable {
                case appStore
                case playMarket
                case fragment
                case premiumBot
                case unsupported
                case peer(EnginePeer)
            }
            
            public let flags: Flags
            public let id: String
            public let count: Int64
            public let date: Int32
            public let peer: Peer
            public let title: String?
            public let description: String?
            public let photo: TelegramMediaWebFile?
            
            public init(
                flags: Flags,
                id: String,
                count: Int64,
                date: Int32,
                peer: Peer,
                title: String?,
                description: String?,
                photo: TelegramMediaWebFile?
            ) {
                self.flags = flags
                self.id = id
                self.count = count
                self.date = date
                self.peer = peer
                self.title = title
                self.description = description
                self.photo = photo
            }
        }
        
        public struct Flags: OptionSet {
            public var rawValue: Int32
            
            public init(rawValue: Int32) {
                self.rawValue = rawValue
            }
            
            public static let isPendingBalance = Flags(rawValue: 1 << 0)
        }
        
        public var flags: Flags
        public var balance: Int64
        public var transactions: [Transaction]
        public var canLoadMore: Bool
        public var isLoading: Bool
        
        init(flags: Flags, balance: Int64, transactions: [Transaction], canLoadMore: Bool, isLoading: Bool) {
            self.flags = flags
            self.balance = balance
            self.transactions = transactions
            self.canLoadMore = canLoadMore
            self.isLoading = isLoading
        }
        
        public static func == (lhs: State, rhs: State) -> Bool {
            if lhs.flags != rhs.flags {
                return true
            }
            if lhs.balance != rhs.balance {
                return false
            }
            if lhs.transactions != rhs.transactions {
                return false
            }
            if lhs.canLoadMore != rhs.canLoadMore {
                return false
            }
            if lhs.isLoading != rhs.isLoading {
                return false
            }
            return true
        }
    }
    
    private let impl: QueueLocalObject<StarsContextImpl>
    
    public var state: Signal<StarsContext.State?, NoError> {
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
    
    var peerId: EnginePeer.Id {
        var peerId: EnginePeer.Id?
        self.impl.syncWith { impl in
            peerId = impl.peerId
        }
        return peerId!
    }
    
    var currentState: StarsContext.State? {
        var state: StarsContext.State?
        self.impl.syncWith { impl in
            state = impl._state
        }
        return state
    }
    
    public func add(balance: Int64) {
        self.impl.with {
            $0.add(balance: balance)
        }
    }
    
    public func load(force: Bool) {
        self.impl.with {
            $0.load(force: force)
        }
    }
    
    public func loadMore() {
        self.impl.with {
            $0.loadMore()
        }
    }
    
    init(account: Account, peerId: EnginePeer.Id) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return StarsContextImpl(account: account, peerId: peerId)
        })
    }
}

private final class StarsTransactionsContextImpl {
    private let account: Account
    private let peerId: EnginePeer.Id
    private let subject: StarsTransactionsContext.Subject
    
    private var _state: StarsTransactionsContext.State
    private let _statePromise = Promise<StarsTransactionsContext.State>()
    var state: Signal<StarsTransactionsContext.State, NoError> {
        return self._statePromise.get()
    }
    private var nextOffset: String? = ""
    
    private let disposable = MetaDisposable()
    private var stateDisposable: Disposable?
    
    init(account: Account, starsContext: StarsContext, subject: StarsTransactionsContext.Subject) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self.peerId = starsContext.peerId
        self.subject = subject
        
        let currentTransactions = starsContext.currentState?.transactions ?? []
        let initialTransactions: [StarsContext.State.Transaction]
        switch subject {
        case .all:
            initialTransactions = currentTransactions
        case .incoming:
            initialTransactions = currentTransactions.filter { $0.count > 0 }
        case .outgoing:
            initialTransactions = currentTransactions.filter { $0.count < 0 }
        }
        
        self._state = StarsTransactionsContext.State(transactions: initialTransactions, canLoadMore: true, isLoading: false)
        self._statePromise.set(.single(self._state))
        
        self.stateDisposable = (starsContext.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self, let state else {
                return
            }
            
            let currentTransactions = state.transactions
            let filteredTransactions: [StarsContext.State.Transaction]
            switch subject {
            case .all:
                filteredTransactions = currentTransactions
            case .incoming:
                filteredTransactions = currentTransactions.filter { $0.count > 0 }
            case .outgoing:
                filteredTransactions = currentTransactions.filter { $0.count < 0 }
            }
            
            if filteredTransactions != initialTransactions {
                var existingIds = Set<String>()
                for transaction in self._state.transactions {
                    if !transaction.flags.contains(.isLocal) {
                        existingIds.insert(transaction.id)
                    }
                }
            
                var updatedState = self._state
                updatedState.transactions.removeAll(where: { $0.flags.contains(.isLocal) })
                for transaction in filteredTransactions.reversed() {
                    if !existingIds.contains(transaction.id) {
                        updatedState.transactions.insert(transaction, at: 0)
                    }
                }
                self.updateState(updatedState)
            }
        })
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
        self.stateDisposable?.dispose()
    }
    
    func loadMore(reload: Bool = false) {
        assert(Queue.mainQueue().isCurrent())
        
        if reload {
            self.nextOffset = ""
        }
        
        guard !self._state.isLoading, let nextOffset = self.nextOffset else {
            return
        }
        
        var updatedState = self._state
        updatedState.isLoading = true
        self.updateState(updatedState)
        
        self.disposable.set((_internal_requestStarsState(account: self.account, peerId: self.peerId, subject: self.subject, offset: nextOffset)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let self else {
                return
            }
            self.nextOffset = status.nextOffset
            
            var updatedState = self._state
            updatedState.transactions = nextOffset.isEmpty ? status.transactions : updatedState.transactions + status.transactions
            updatedState.isLoading = false
            updatedState.canLoadMore = self.nextOffset != nil
            self.updateState(updatedState)
        }))
    }
    
    private func updateState(_ state: StarsTransactionsContext.State) {
        self._state = state
        self._statePromise.set(.single(state))
    }
}
    
public final class StarsTransactionsContext {
    public struct State: Equatable {
        public var transactions: [StarsContext.State.Transaction]
        public var canLoadMore: Bool
        public var isLoading: Bool
        
        init(transactions: [StarsContext.State.Transaction], canLoadMore: Bool, isLoading: Bool) {
            self.transactions = transactions
            self.canLoadMore = canLoadMore
            self.isLoading = isLoading
        }
    }
    
    fileprivate let impl: QueueLocalObject<StarsTransactionsContextImpl>
    
    public enum Subject {
        case all
        case incoming
        case outgoing
    }
    
    public var state: Signal<StarsTransactionsContext.State, NoError> {
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
    
    public func reload() {
        self.impl.with {
            $0.loadMore(reload: true)
        }
    }
    
    public func loadMore() {
        self.impl.with {
            $0.loadMore()
        }
    }
    
    init(account: Account, starsContext: StarsContext, subject: Subject) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return StarsTransactionsContextImpl(account: account, starsContext: starsContext, subject: subject)
        })
    }
}

func _internal_sendStarsPaymentForm(account: Account, formId: Int64, source: BotPaymentInvoiceSource) -> Signal<SendBotPaymentResult, SendBotPaymentFormError> {
    return account.postbox.transaction { transaction -> Api.InputInvoice? in
        return _internal_parseInputInvoice(transaction: transaction, source: source)
    }
    |> castError(SendBotPaymentFormError.self)
    |> mapToSignal { invoice -> Signal<SendBotPaymentResult, SendBotPaymentFormError> in
        guard let invoice = invoice else {
            return .fail(.generic)
        }
        
        let flags: Int32 = 0

        return account.network.request(Api.functions.payments.sendStarsForm(flags: flags, formId: formId, invoice: invoice))
        |> map { result -> SendBotPaymentResult in
            switch result {
                case let .paymentResult(updates):
                    account.stateManager.addUpdates(updates)
                    var receiptMessageId: MessageId?
                    for apiMessage in updates.messages {
                        if let message = StoreMessage(apiMessage: apiMessage, accountPeerId: account.peerId, peerIsForum: false) {
                            for media in message.media {
                                if let action = media as? TelegramMediaAction {
                                    if case .paymentSent = action.action {
                                        switch source {
                                        case let .slug(slug):
                                            for media in message.media {
                                                if let action = media as? TelegramMediaAction, case let .paymentSent(_, _, invoiceSlug?, _, _) = action.action, invoiceSlug == slug {
                                                    if case let .Id(id) = message.id {
                                                        receiptMessageId = id
                                                    }
                                                }
                                            }
                                        case let .message(messageId):
                                            for attribute in message.attributes {
                                                if let reply = attribute as? ReplyMessageAttribute {
                                                    if reply.messageId == messageId {
                                                        if case let .Id(id) = message.id {
                                                            receiptMessageId = id
                                                        }
                                                    }
                                                }
                                            }
                                        case let .premiumGiveaway(_, _, _, _, _, _, randomId, _, _, _, _):
                                            if message.globallyUniqueId == randomId {
                                                if case let .Id(id) = message.id {
                                                    receiptMessageId = id
                                                }
                                            }
                                        case .giftCode:
                                            receiptMessageId = nil
                                        case .stars:
                                            receiptMessageId = nil
                                        }
                                    }
                                }
                            }
                        }
                    }
                    return .done(receiptMessageId: receiptMessageId)
                case let .paymentVerificationNeeded(url):
                    return .externalVerificationRequired(url: url)
            }
        }
        |> `catch` { error -> Signal<SendBotPaymentResult, SendBotPaymentFormError> in
            if error.errorDescription == "BOT_PRECHECKOUT_FAILED" {
                return .fail(.precheckoutFailed)
            } else if error.errorDescription == "PAYMENT_FAILED" {
                return .fail(.paymentFailed)
            } else if error.errorDescription == "INVOICE_ALREADY_PAID" {
                return .fail(.alreadyPaid)
            }
            return .fail(.generic)
        }
    }
}
