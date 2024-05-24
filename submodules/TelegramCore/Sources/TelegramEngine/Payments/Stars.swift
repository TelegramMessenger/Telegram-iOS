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

func _internal_requestStarsState(account: Account, peerId: EnginePeer.Id, offset: String?) -> Signal<InternalStarsStatus?, NoError> {
    return account.postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    } |> mapToSignal { peer -> Signal<InternalStarsStatus?, NoError> in
        guard let peer, let inputPeer = apiInputPeer(peer) else {
            return .never()
        }
                
        let signal: Signal<Api.payments.StarsStatus, MTRpcError>
        if let offset {
            signal = account.network.request(Api.functions.payments.getStarsTransactions(flags: 0, peer: inputPeer, offset: offset))
        } else {
            signal = account.network.request(Api.functions.payments.getStarsStatus(peer: inputPeer))
        }
        
        return signal
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.payments.StarsStatus?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<InternalStarsStatus?, NoError> in
            guard let result else {
                return .single(nil)
            }
            return account.postbox.transaction { transaction -> InternalStarsStatus? in
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
        }
    }
}

private final class StarsContextImpl {
    private let account: Account
    private let peerId: EnginePeer.Id
    
    private var _state: StarsContext.State? {
        didSet {
            if self._state != oldValue {
                self._statePromise.set(.single(self._state))
            }
        }
    }
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
        
        self.load()
        
        self.updateDisposable = (account.stateManager.updatedStarsBalance()
        |> deliverOnMainQueue).startStrict(next: { [weak self] balances in
            guard let self, let state = self._state, let balance = balances[peerId] else {
                return
            }
            self._state = StarsContext.State(balance: balance, transactions: state.transactions, canLoadMore: nextOffset != nil, isLoading: false)
            self.load()
        })
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
        self.updateDisposable?.dispose()
    }
    
    func load() {
        assert(Queue.mainQueue().isCurrent())
        
        self.disposable.set((_internal_requestStarsState(account: self.account, peerId: self.peerId, offset: nil)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let self {
                if let status {
                    self._state = StarsContext.State(balance: status.balance, transactions: status.transactions, canLoadMore: status.nextOffset != nil, isLoading: false)
                    self.nextOffset = status.nextOffset
                    
                    self.loadMore()
                } else {
                    self._state = nil
                }
            }
        }))
    }
    
    func add(balance: Int64) {
        if var state = self._state {
            var transactions = state.transactions
            transactions.insert(.init(id: "\(arc4random())", count: balance, date: Int32(Date().timeIntervalSince1970), peer: .appStore, title: nil, description: nil, photo: nil), at: 0)
            
            state.balance = state.balance + balance
            self._state = state
        }
    }
    
    func loadMore() {
        assert(Queue.mainQueue().isCurrent())
        
        guard let currentState = self._state, let nextOffset = self.nextOffset else {
            return
        }

        self._state?.isLoading = true
        
        self.disposable.set((_internal_requestStarsState(account: self.account, peerId: self.peerId, offset: nextOffset)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let self {
                if let status {
                    self._state = StarsContext.State(balance: status.balance, transactions: currentState.transactions + status.transactions, canLoadMore: status.nextOffset != nil, isLoading: false)
                    self.nextOffset = status.nextOffset
                } else {
                    self.nextOffset = nil
                }
            }
        }))
    }
}

private extension StarsContext.State.Transaction {
    init?(apiTransaction: Api.StarsTransaction, transaction: Transaction) {
        switch apiTransaction {
        case let .starsTransaction(_, id, stars, date, transactionPeer, title, description, photo):
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
            self.init(id: id, count: stars, date: date, peer: parsedPeer, title: title, description: description, photo: photo.flatMap(TelegramMediaWebFile.init))
        }
    }
}

public final class StarsContext {
    public struct State: Equatable {
        public struct Transaction: Equatable {
            public enum Peer: Equatable {
                case appStore
                case playMarket
                case fragment
                case premiumBot
                case unsupported
                case peer(EnginePeer)
            }
            
            public let id: String
            public let count: Int64
            public let date: Int32
            public let peer: Peer
            public let title: String?
            public let description: String?
            public let photo: TelegramMediaWebFile?
            
            public init(
                id: String,
                count: Int64,
                date: Int32,
                peer: Peer,
                title: String?,
                description: String?,
                photo: TelegramMediaWebFile?
            ) {
                self.id = id
                self.count = count
                self.date = date
                self.peer = peer
                self.title = title
                self.description = description
                self.photo = photo
            }
        }
        
        public var balance: Int64
        public var transactions: [Transaction]
        public var canLoadMore: Bool
        public var isLoading: Bool
        init(balance: Int64, transactions: [Transaction], canLoadMore: Bool, isLoading: Bool) {
            self.balance = balance
            self.transactions = transactions
            self.canLoadMore = canLoadMore
            self.isLoading = isLoading
        }
        
        public static func == (lhs: State, rhs: State) -> Bool {
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
    
    public func add(balance: Int64) {
        self.impl.with {
            $0.add(balance: balance)
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
