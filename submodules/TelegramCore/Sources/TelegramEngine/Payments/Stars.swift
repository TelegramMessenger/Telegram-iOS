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

private struct InternalStarsStatus {
    let balance: Int64
    let transactions: [StarsContext.State.Transaction]
    let nextOffset: String?
}

private func requestStarsState(account: Account, peerId: EnginePeer.Id, offset: String?) -> Signal<InternalStarsStatus?, NoError> {
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
                        switch entry {
                        case let .starsTransaction(id, stars, date, peer):
                            if let peer = transaction.getPeer(peer.peerId) {
                                parsedTransactions.append(StarsContext.State.Transaction(id: id, count: stars, date: date, peer: EnginePeer(peer)))
                            }
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
    
    init(account: Account, peerId: EnginePeer.Id) {
        assert(Queue.mainQueue().isCurrent())
        
        self.account = account
        self.peerId = peerId
        
        self._state = nil
        self._statePromise.set(.single(nil))
        
        self.load()
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.disposable.dispose()
    }
    
    func load() {
        assert(Queue.mainQueue().isCurrent())
        
        self.disposable.set((requestStarsState(account: self.account, peerId: self.peerId, offset: nil)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let self {
                if let status {
                    self._state = StarsContext.State(balance: status.balance, transactions: status.transactions)
                    self.nextOffset = status.nextOffset
                } else {
                    self._state = nil
                }
            }
        }))
    }
    
    func loadMore() {
        assert(Queue.mainQueue().isCurrent())
        
        guard let currentState = self._state, let nextOffset = self.nextOffset else {
            return
        }
        self.disposable.set((requestStarsState(account: self.account, peerId: self.peerId, offset: nextOffset)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let self {
                if let status {
                    self._state = StarsContext.State(balance: status.balance, transactions: currentState.transactions + status.transactions)
                    self.nextOffset = status.nextOffset
                } else {
                    self.nextOffset = nil
                }
            }
        }))
    }
}

public final class StarsContext {
    public struct State: Equatable {
        public struct Transaction: Equatable {
            public let id: String
            public let count: Int64
            public let date: Int32
            public let peer: EnginePeer
            
            init(id: String, count: Int64, date: Int32, peer: EnginePeer) {
                self.id = id
                self.count = count
                self.date = date
                self.peer = peer
            }
        }
        
        public let balance: Int64
        public let transactions: [Transaction]
        
        init(balance: Int64, transactions: [Transaction]) {
            self.balance = balance
            self.transactions = transactions
        }
        
        public static func == (lhs: State, rhs: State) -> Bool {
            if lhs.balance != rhs.balance {
                return false
            }
            if lhs.transactions != rhs.transactions {
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
    
    init(account: Account, peerId: EnginePeer.Id) {
        self.impl = QueueLocalObject(queue: Queue.mainQueue(), generate: {
            return StarsContextImpl(account: account, peerId: peerId)
        })
    }
}
