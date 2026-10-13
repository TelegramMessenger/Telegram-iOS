import Foundation
import SwiftSignalKit
import TelegramCore
#if canImport(TelegramUIPreferences)
import TelegramUIPreferences
#endif

@available(macOS 10.15, *)
struct WalletStoredTransaction: Codable, Equatable, Sendable {
    enum Peer: Codable, Equatable, @unchecked Sendable {
        case user(id: EnginePeer.Id)
        case address(String)
        case onramp(address: String, providerName: String)
        case unsupported

        private enum Kind: Int32 {
            case user = 0
            case address = 1
            case unsupported = 2
            case onramp = 3
        }

        private enum CodingKeys: String, CodingKey {
            case kind
            case userId
            case address
            case providerName
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let rawKind = try container.decode(Int32.self, forKey: .kind)
            guard let kind = Kind(rawValue: rawKind) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .kind,
                    in: container,
                    debugDescription: "Unknown stored wallet peer kind"
                )
            }
            switch kind {
            case .user:
                self = .user(
                    id: EnginePeer.Id(try container.decode(Int64.self, forKey: .userId))
                )
            case .address:
                self = .address(try container.decode(String.self, forKey: .address))
            case .onramp:
                self = .onramp(
                    address: try container.decode(String.self, forKey: .address),
                    providerName: try container.decode(String.self, forKey: .providerName)
                )
            case .unsupported:
                self = .unsupported
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case let .user(id):
                try container.encode(Kind.user.rawValue, forKey: .kind)
                try container.encode(id.toInt64(), forKey: .userId)
            case let .address(address):
                try container.encode(Kind.address.rawValue, forKey: .kind)
                try container.encode(address, forKey: .address)
            case let .onramp(address, providerName):
                try container.encode(Kind.onramp.rawValue, forKey: .kind)
                try container.encode(address, forKey: .address)
                try container.encode(providerName, forKey: .providerName)
            case .unsupported:
                try container.encode(Kind.unsupported.rawValue, forKey: .kind)
            }
        }

        var userId: EnginePeer.Id? {
            if case let .user(id) = self {
                return id
            }
            return nil
        }
    }

    let id: String
    let presentationId: String?
    let transactionHash: String?
    let logicalTime: String
    let timestamp: Int32
    let kind: WalletContext.Transaction.Kind
    let direction: WalletContext.Transaction.Direction
    let amount: Int64
    let fee: Int64
    let gasless: Bool?
    let peer: Peer
    let peerAddress: String?
    let peerDomain: String?
    let comment: String?
    let commentEncrypted: Bool?
    let currency: WalletContext.Transaction.Currency
    let collectible: WalletContext.Transaction.CollectibleTransfer?
    let status: WalletContext.Transaction.Status

    init(_ transaction: WalletContext.Transaction) {
        self.id = transaction.id
        self.presentationId = transaction.presentationId
        self.transactionHash = transaction.transactionHash
        self.logicalTime = transaction.logicalTime
        self.timestamp = transaction.timestamp
        self.kind = transaction.kind
        self.direction = transaction.direction
        self.amount = transaction.amount
        self.fee = transaction.fee
        self.gasless = transaction.gasless
        switch transaction.peer {
        case let .user(peer, address, domain):
            self.peer = .user(id: peer.id)
            self.peerAddress = address
            self.peerDomain = domain
        case let .address(address, domain):
            self.peer = .address(address)
            self.peerAddress = nil
            self.peerDomain = domain
        case let .onramp(address, domain, providerName):
            self.peer = .onramp(address: address, providerName: providerName)
            self.peerAddress = nil
            self.peerDomain = domain
        case .unsupported:
            self.peer = .unsupported
            self.peerAddress = nil
            self.peerDomain = nil
        }
        self.comment = transaction.comment
        self.commentEncrypted = transaction.commentEncrypted
        self.currency = transaction.currency
        self.collectible = transaction.collectible
        self.status = transaction.status
    }

    func transaction(peers: [EnginePeer.Id: EnginePeer]) -> WalletContext.Transaction {
        let peer: WalletContext.Transaction.Peer
        switch self.peer {
        case let .user(id):
            if let value = peers[id] {
                peer = .user(value, address: self.peerAddress ?? "", domain: self.peerDomain)
            } else if let peerAddress = self.peerAddress, !peerAddress.isEmpty {
                peer = .address(peerAddress, domain: self.peerDomain)
            } else {
                peer = .unsupported
            }
        case let .address(address):
            peer = .address(address, domain: self.peerDomain)
        case let .onramp(address, providerName):
            peer = .onramp(address: address, domain: self.peerDomain, providerName: providerName)
        case .unsupported:
            peer = .unsupported
        }
        return WalletContext.Transaction(
            id: self.id,
            presentationId: self.presentationId,
            transactionHash: self.transactionHash,
            logicalTime: self.logicalTime,
            timestamp: self.timestamp,
            direction: self.direction,
            amount: self.amount,
            fee: self.fee,
            gasless: self.gasless ?? false,
            peer: peer,
            comment: self.comment,
            commentEncrypted: self.commentEncrypted ?? false,
            currency: self.currency,
            collectible: self.collectible,
            status: self.status,
            kind: self.kind
        )
    }
}

@available(macOS 10.15, *)
struct WalletStoredTonConnectRequest: Codable, Equatable, Sendable {
    enum Phase: String, Codable, Sendable { case received, claiming, claimed, executing, prepared, closing }

    let accountId: Int64
    let authorizationId: Int64
    let wallet: TonConnectWalletIdentity
    let session: WalletTonConnectSession
    let envelope: WalletTonConnectRequest
    let appRequestId: TonConnectRequestId
    let operationId: String
    var returnTarget: TonConnectReturnTarget
    let validUntil: UInt64?
    var approved: Bool?
    var phase: Phase
    var response: Data?
    var closeSessionAfterResponse: Bool?

    var expires: Int32 { min(self.envelope.expires, Int32(clamping: self.validUntil ?? UInt64(Int32.max))) }
    var isFinishingDisconnect: Bool { self.closeSessionAfterResponse == true && (self.phase == .prepared || self.phase == .closing) }
    var key: TonConnectMessageKey { TonConnectMessageKey(sessionId: self.envelope.sessionId, msgId: self.envelope.msgId) }
}

@available(macOS 10.15, *)
struct WalletStoredState: Codable, Equatable, Sendable {
    private struct Payload: Codable {
        var walletAddress: String?
        var tonConnectRequests: [WalletStoredTonConnectRequest]?
        var pendingTransfers: [WalletContext.PendingTransfer]
        var balance: Int64?
        var balanceUpdatedAt: Int32?
        var fiatRates: [WalletContext.FiatCurrency: WalletContext.FiatRate]?
        var fiatRatesUpdatedAt: Int32?
        var selectedFiatCurrency: WalletContext.FiatCurrency
        var transactions: [WalletStoredTransaction]
        var collectibles: [WalletContext.Collectible]
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case payload
    }

    static let currentSchemaVersion: Int32 = 1

    var schemaVersion: Int32 = WalletStoredState.currentSchemaVersion
    var walletAddress: String?
    var tonConnectRequests: [WalletStoredTonConnectRequest] = []
    var pendingTransfers: [WalletContext.PendingTransfer] = []
    var balance: Int64?
    var balanceUpdatedAt: Int32?
    var fiatRates: [WalletContext.FiatCurrency: WalletContext.FiatRate]?
    var fiatRatesUpdatedAt: Int32?
    var selectedFiatCurrency: WalletContext.FiatCurrency = .usd
    var transactions: [WalletStoredTransaction] = []
    var collectibles: [WalletContext.Collectible] = []

    init() {
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schemaVersion = try container.decode(Int32.self, forKey: .schemaVersion)
        let data = try container.decode(Data.self, forKey: .payload)
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        self.walletAddress = payload.walletAddress
        self.tonConnectRequests = payload.tonConnectRequests ?? []
        self.pendingTransfers = payload.pendingTransfers
        self.balance = payload.balance
        self.balanceUpdatedAt = payload.balanceUpdatedAt
        self.fiatRates = payload.fiatRates
        self.fiatRatesUpdatedAt = payload.fiatRatesUpdatedAt
        self.selectedFiatCurrency = payload.selectedFiatCurrency
        self.transactions = payload.transactions
        self.collectibles = payload.collectibles
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.schemaVersion, forKey: .schemaVersion)
        let payload = Payload(
            walletAddress: self.walletAddress,
            tonConnectRequests: self.tonConnectRequests,
            pendingTransfers: self.pendingTransfers,
            balance: self.balance,
            balanceUpdatedAt: self.balanceUpdatedAt,
            fiatRates: self.fiatRates,
            fiatRatesUpdatedAt: self.fiatRatesUpdatedAt,
            selectedFiatCurrency: self.selectedFiatCurrency,
            transactions: self.transactions,
            collectibles: self.collectibles
        )
        try container.encode(try JSONEncoder().encode(payload), forKey: .payload)
    }
}

@available(macOS 10.15, *)
actor WalletStoredStateWriter {
    private enum Mutation: Sendable {
        case store(WalletStoredState)
        case remove
    }

    private let engine: TelegramEngine
    private var currentDisposable: Disposable?
    private var isWriting = false
    private var isShutdown = false
    private var latestRevision: UInt64 = 0
    private var pendingMutation: Mutation?
    private var completedRevision: UInt64 = 0
    private var waiters: [(revision: UInt64, continuation: CheckedContinuation<Bool, Never>)] = []

    init(engine: TelegramEngine) {
        self.engine = engine
    }

    func enqueue(_ state: WalletStoredState, revision: UInt64) {
        guard !self.isShutdown, revision > self.latestRevision else { return }
        self.latestRevision = revision
        self.pendingMutation = .store(state)
        self.beginWritingIfNeeded()
    }

    func remove(revision: UInt64) {
        guard !self.isShutdown, revision > self.latestRevision else { return }
        self.latestRevision = revision
        self.pendingMutation = .remove
        self.beginWritingIfNeeded()
    }

    func storeAndWait(_ state: WalletStoredState, revision: UInt64) async -> Bool {
        guard !self.isShutdown, let entry = EnginePreferencesEntry(state), entry.get(WalletStoredState.self) == state else { return false }
        self.enqueue(state, revision: revision)
        if self.completedRevision >= revision { return true }
        return await withCheckedContinuation { continuation in
            self.waiters.append((revision, continuation))
        }
    }

    func shutdown() {
        self.isShutdown = true
        self.pendingMutation = nil
        self.currentDisposable?.dispose()
        self.currentDisposable = nil
        self.isWriting = false
        let waiters = self.waiters
        self.waiters.removeAll()
        for waiter in waiters { waiter.continuation.resume(returning: false) }
    }

    private func beginWritingIfNeeded() {
        guard !self.isShutdown, !self.isWriting, let mutation = self.pendingMutation else {
            return
        }
        self.pendingMutation = nil
        self.isWriting = true
        let revision = self.latestRevision
        let disposable = MetaDisposable()
        self.currentDisposable = disposable
        disposable.set((self.engine.preferences.update(
            id: ApplicationSpecificPreferencesKeys.walletState,
            { current in
                switch mutation {
                case let .store(state):
                    if current?.get(WalletStoredState.self) == state {
                        return current
                    }
                    return EnginePreferencesEntry(state)
                case .remove:
                    return nil
                }
            }
        )).start(completed: { [weak self] in
            Task {
                await self?.writingCompleted(revision: revision)
            }
        }))
    }

    private func writingCompleted(revision: UInt64) {
        self.currentDisposable = nil
        self.isWriting = false
        self.completedRevision = max(self.completedRevision, revision)
        let completed = self.waiters.filter { $0.revision <= self.completedRevision }
        self.waiters.removeAll { $0.revision <= self.completedRevision }
        for waiter in completed { waiter.continuation.resume(returning: true) }
        self.beginWritingIfNeeded()
    }
}

#if !canImport(TelegramUIPreferences)
struct ApplicationSpecificPreferencesKeys {
    static let walletState: EngineDataBuffer = applicationSpecificPreferencesKey(23)
}
#endif
