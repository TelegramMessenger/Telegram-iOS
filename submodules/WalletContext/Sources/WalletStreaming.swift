import Foundation
import Dispatch
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI

let walletStreamingMaximumFrameBytes = 4 * 1024 * 1024

@available(macOS 10.15, *)
enum WalletStreamingError: Error, Equatable {
    case invalidURL
    case expiredURL
    case notConnected
    case invalidResponse
    case frameTooLarge
}

@available(macOS 10.15, *)
actor WalletStreamingURLProvider {
    private struct CachedValue {
        let url: URL
        let expires: Int64
    }

    private let engine: TelegramEngine
    private let logger: WalletLogger
    private var cached: CachedValue?

    init(engine: TelegramEngine, logger: WalletLogger) {
        self.engine = engine
        self.logger = logger
    }

    func url() async throws -> URL {
        do {
            let value = try await WalletSignalRequestContext<WalletStreamingUrl>().run(
                self.engine.wallet.getStreamingUrl()
            )
            try Task.checkCancellation()
            let parsed = try Self.parse(value, now: Int64(Date().timeIntervalSince1970))
            self.cached = parsed
            return parsed.url
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            let fallbackTimestamp = Int64(Date().timeIntervalSince1970)
            if let cached = self.cached, cached.expires > fallbackTimestamp {
                self.logger.error("wallet_stream_url_fetch_failed_using_cache", error, context: "expires_in=\(cached.expires - fallbackTimestamp)")
                return cached.url
            }
            self.logger.error("wallet_stream_url_fetch_failed", error)
            throw error
        }
    }

    private static func parse(_ value: WalletStreamingUrl, now: Int64) throws -> CachedValue {
        let expires = Int64(value.expires)
        guard expires > now,
              let components = URLComponents(string: value.url),
              components.scheme == "wss",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.fragment == nil else {
            if expires <= now {
                throw WalletStreamingError.expiredURL
            }
            throw WalletStreamingError.invalidURL
        }
        guard components.percentEncodedQuery?.isEmpty == false,
              let url = components.url else {
            throw WalletStreamingError.invalidURL
        }
        return CachedValue(url: url, expires: expires)
    }
}

@available(macOS 10.15, *)
private final class WalletStreamingSessionDelegate: NSObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    private let expectedURL: URL
    private let logger: WalletLogger

    init(
        expectedURL: URL,
        logger: WalletLogger
    ) {
        self.expectedURL = expectedURL
        self.logger = logger
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        self.logger.log("event=wallet_stream_redirect_rejected status_code=\(response.statusCode)")
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        guard webSocketTask.originalRequest?.url == self.expectedURL else {
            self.logger.log("event=wallet_stream_response_rejected")
            webSocketTask.cancel(with: .policyViolation, reason: nil)
            return
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        self.logger.log("event=wallet_stream_socket_closed close_code=\(closeCode.rawValue)")
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            self.logger.error("wallet_stream_socket_completed", error)
        }
    }
}

@available(macOS 10.15, *)
actor WalletURLSessionStreamingTransport {
    private let provider: WalletStreamingURLProvider
    private let logger: WalletLogger
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var connectionId: UUID?

    init(provider: WalletStreamingURLProvider, logger: WalletLogger) {
        self.provider = provider
        self.logger = logger
    }

    func connect(subscription: Data) async throws {
        guard subscription.count <= walletStreamingMaximumFrameBytes else {
            throw WalletStreamingError.frameTooLarge
        }
        let url = try await self.provider.url()
        try Task.checkCancellation()

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 60
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 24 * 60 * 60

        let delegate = WalletStreamingSessionDelegate(expectedURL: url, logger: self.logger)
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = walletStreamingMaximumFrameBytes
        let connectionId = UUID()
        self.connectionId = connectionId
        self.session = session
        self.task = task
        task.resume()

        do {
            try await self.send(message: subscription)
        } catch {
            if self.connectionId == connectionId {
                self.connectionId = nil
                self.task = nil
                self.session = nil
            }
            task.cancel(with: .goingAway, reason: nil)
            session.invalidateAndCancel()
            throw error
        }
    }

    func send(message: Data) async throws {
        guard message.count <= walletStreamingMaximumFrameBytes else {
            throw WalletStreamingError.frameTooLarge
        }
        guard let task = self.task,
              self.connectionId != nil,
              let string = String(data: message, encoding: .utf8) else {
            throw WalletStreamingError.notConnected
        }
        try await task.send(.string(string))
    }

    func receive() async throws -> Data {
        guard let connectionId = self.connectionId, let task = self.task else {
            throw WalletStreamingError.notConnected
        }
        let message = try await task.receive()
        guard self.connectionId == connectionId else {
            throw CancellationError()
        }
        let data: Data
        switch message {
        case let .data(value):
            data = value
        case let .string(value):
            data = Data(value.utf8)
        @unknown default:
            throw WalletStreamingError.invalidResponse
        }
        guard data.count <= walletStreamingMaximumFrameBytes else {
            self.logger.log("event=wallet_stream_event_too_large")
            throw WalletStreamingError.frameTooLarge
        }
        return data
    }

    func close() async {
        self.connectionId = nil
        let task = self.task
        let session = self.session
        self.task = nil
        self.session = nil
        task?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
    }
}

@available(macOS 10.15, *)
enum WalletStreamingFinality: Int, Sendable, Equatable {
    case pending = 0
    case confirmed = 1
    case finalized = 2

    var diagnosticName: String {
        switch self {
        case .pending:
            return "pending"
        case .confirmed:
            return "confirmed"
        case .finalized:
            return "finalized"
        }
    }
}

@available(macOS 10.15, *)
enum WalletStreamingParsedEvent: Sendable, Equatable {
    case connecting
    case subscribed
    case disconnected
    case pong
    case accountStateChanged(balance: Int64, finality: WalletStreamingFinality, stateHash: String? = nil)
    case transactionsChanged(
        traceId: String,
        finality: WalletStreamingFinality,
        transactions: [WalletContext.Transaction],
        evidence: [WalletStreamingTransferEvidence] = [],
        balanceEvidence: [WalletStreamingBalanceEvidence] = []
    )
    case traceInvalidated(traceId: String)
}

@available(macOS 10.15, *)
enum WalletStreamingConnectionState: Sendable, Equatable {
    case inactive
    case connecting
    case subscribed
    case disconnected
}

@available(macOS 10.15, *)
enum WalletStreamingDemand {
    static func isActive(
        foreground: Bool,
        accountIsCurrent: Bool,
        networkAvailable: Bool,
        walletScreenCount: Int,
        hasPendingTransfer: Bool
    ) -> Bool {
        foreground
            && accountIsCurrent
            && networkAvailable
            && (walletScreenCount > 0 || hasPendingTransfer)
    }

    static func needsPolling(connection: WalletStreamingConnectionState, hasPendingTransfer: Bool, hasUnreconciledBalance: Bool = false) -> Bool {
        connection != .subscribed || hasPendingTransfer || hasUnreconciledBalance
    }

    static func acceptsEvent(
        generation: UInt64,
        rawAddress: String,
        currentGeneration: UInt64,
        currentRawAddress: String?,
        isActive: Bool
    ) -> Bool {
        isActive && generation == currentGeneration && rawAddress == currentRawAddress
    }
}

@available(macOS 10.15, *)
struct WalletStreamingRefreshTracker {
    private var finalizedBalance: Int64?
    private var remainingRetryCount = 0
    private var finalizedTraceIds = Set<String>()
    private var invalidatedTraceIds = Set<String>()
    private var traceOrder: [String] = []

    mutating func takeRetry() -> Bool {
        guard self.remainingRetryCount > 0 else { return false }
        self.remainingRetryCount -= 1
        return true
    }

    func hasFinalizedTrace(_ traceId: String) -> Bool {
        self.finalizedTraceIds.contains(traceId)
    }

    private mutating func remember(_ traceId: String) {
        self.traceOrder.removeAll(where: { $0 == traceId })
        self.traceOrder.append(traceId)
        if self.traceOrder.count > 256 {
            let removed = self.traceOrder.removeFirst()
            self.finalizedTraceIds.remove(removed)
            self.invalidatedTraceIds.remove(removed)
        }
    }

    mutating func requiresRefresh(_ event: WalletStreamingParsedEvent, knownTrace: Bool = false) -> Bool {
        switch event {
        case let .accountStateChanged(balance, finality, _):
            guard finality == .finalized, balance != self.finalizedBalance else { return false }
            self.finalizedBalance = balance
            self.remainingRetryCount = 2
            return true
        case let .transactionsChanged(traceId, finality, _, _, _):
            guard finality == .finalized, self.finalizedTraceIds.insert(traceId).inserted else { return false }
            self.invalidatedTraceIds.remove(traceId)
            self.remember(traceId)
            self.remainingRetryCount = 2
            return true
        case let .traceInvalidated(traceId):
            guard !self.invalidatedTraceIds.contains(traceId) else { return false }
            let wasFinalized = self.finalizedTraceIds.remove(traceId) != nil
            guard knownTrace || wasFinalized else { return false }
            self.invalidatedTraceIds.insert(traceId)
            self.remember(traceId)
            self.finalizedBalance = nil
            self.remainingRetryCount = 2
            return true
        case .connecting, .subscribed, .disconnected, .pong:
            return false
        }
    }
}

@available(macOS 10.15, *)
struct WalletSynchronizationScope: OptionSet, Sendable {
    let rawValue: Int

    static let account = WalletSynchronizationScope(rawValue: 1 << 0)
    static let transactions = WalletSynchronizationScope(rawValue: 1 << 1)
    static let nfts = WalletSynchronizationScope(rawValue: 1 << 2)
    static let all: WalletSynchronizationScope = [.account, .transactions, .nfts]
}

@available(macOS 10.15, *)
struct WalletSynchronizationRequestGate {
    private(set) var runningScope: WalletSynchronizationScope = []
    private(set) var isRunning = false
    var pendingScope: WalletSynchronizationScope { self.runningScope.union(self.queuedScope) }
    private(set) var queuedScope: WalletSynchronizationScope = []

    mutating func beginOrQueue(_ scope: WalletSynchronizationScope) -> WalletSynchronizationScope? {
        guard !scope.isEmpty else {
            return nil
        }
        if self.isRunning {
            self.queuedScope.formUnion(scope)
            return nil
        }
        self.isRunning = true
        self.runningScope = scope
        return scope
    }

    mutating func completedResource(_ scope: WalletSynchronizationScope) {
        self.runningScope.subtract(scope)
    }

    mutating func complete() -> WalletSynchronizationScope {
        self.isRunning = false
        self.runningScope = []
        let queuedScope = self.queuedScope
        self.queuedScope = []
        return queuedScope
    }

    mutating func cancel() {
        self.isRunning = false
        self.runningScope = []
        self.queuedScope = []
    }
}

@available(macOS 10.15, *)
enum WalletStreamingEventParser {
    private struct Envelope: Decodable {
        let type: String?
        let status: String?
        let error: String?
    }

    private struct AccountStateChange: Decodable {
        let account: String
        let finality: String
        let state: AccountState
    }

    private struct AccountState: Decodable {
        let balance: String
        let hash: String?
    }

    private struct StreamingMessage: Decodable {
        struct Content: Decodable { let hash: String? }
        let message_content: Content?
        let source: String?
        let destination: String?
        let value: String?
        let bounced: Bool?
    }

    private struct StreamingTransaction: Decodable {
        struct Description: Decodable {
            struct Phase: Decodable { let success: Bool? }
            let aborted: Bool?
            let compute_ph: Phase?
            let action: Phase?
        }
        let emulated: Bool?
        let description: Description?
        let traceId: String?
        let account: String
        let hash: String
        let lt: String
        let now: Int64
        let totalFees: String
        let inMessage: StreamingMessage?
        let outMessages: [StreamingMessage]

        enum CodingKeys: String, CodingKey {
            case account
            case hash
            case lt
            case now
            case emulated, description
            case traceId = "trace_id"
            case totalFees = "total_fees"
            case inMessage = "in_msg"
            case outMessages = "out_msgs"
        }
    }

    private struct TransactionsChange: Decodable {
        let transactions: [StreamingTransaction]
    }

    private struct TransactionsHeader: Decodable {
        struct Transaction: Decodable {
            struct AccountState: Decodable { let hash: String? }
            let account: String
            let hash: String?
            let lt: String?
            let emulated: Bool?
            let account_state_after: AccountState?
        }

        let finality: String
        let traceExternalHashNorm: String
        let transactions: [Transaction]

        enum CodingKeys: String, CodingKey {
            case finality
            case traceExternalHashNorm = "trace_external_hash_norm"
            case transactions
        }
    }

    private struct TraceInvalidated: Decodable {
        let traceExternalHashNorm: String

        enum CodingKeys: String, CodingKey {
            case traceExternalHashNorm = "trace_external_hash_norm"
        }
    }

    static func parse(_ data: Data, expectedRawAddress: String, log: ((String) -> Void)? = nil) -> WalletStreamingParsedEvent? {
        guard data.count <= walletStreamingMaximumFrameBytes else {
            log?("reason=frame_too_large bytes=\(data.count)")
            return nil
        }
        let decoder = JSONDecoder()
        guard let envelope = self.decode(Envelope.self, from: data, decoder: decoder, log: log) else {
            return nil
        }
        if envelope.status == "subscribed" {
            return .subscribed
        }
        if envelope.status == "pong" {
            return .pong
        }
        let expected = expectedRawAddress.lowercased()
        switch envelope.type {
        case "account_state_change":
            guard let value = self.decode(AccountStateChange.self, from: data, decoder: decoder, log: log) else {
                return nil
            }
            guard value.account.lowercased() == expected else {
                log?("reason=account_mismatch account=\(value.account) expected=\(expected)")
                return nil
            }
            guard let finality = self.finality(value.finality), finality != .pending else {
                log?("reason=unsupported_account_finality finality=\(value.finality)")
                return nil
            }
            guard let balance = self.unsignedInt64(value.state.balance) else {
                log?("reason=invalid_balance")
                return nil
            }
            return .accountStateChanged(balance: balance, finality: finality,
                stateHash: walletStreamingHash(value.state.hash)?.base64EncodedString())
        case "transactions":
            guard let header = self.decode(TransactionsHeader.self, from: data, decoder: decoder, log: log) else {
                return nil
            }
            guard !header.traceExternalHashNorm.isEmpty else {
                log?("reason=missing_trace_hash")
                return nil
            }
            guard let finality = self.finality(header.finality) else {
                log?("reason=unsupported_transaction_finality finality=\(header.finality)")
                return nil
            }
            guard header.transactions.contains(where: { $0.account.lowercased() == expected }) else {
                log?("reason=no_matching_account expected=\(expected) trace_id=\(header.traceExternalHashNorm) transaction_count=\(header.transactions.count)")
                return nil
            }
            // Finalized changes still need authoritative history when their payload
            // cannot be represented by the lightweight streaming transaction model.
            let value = self.decode(TransactionsChange.self, from: data, decoder: decoder, log: log)
            let matchingTransactions = value?.transactions.filter { $0.account.lowercased() == expected } ?? []
            // Balance evidence must survive unsupported transaction presentation (e.g. key changes).
            let balanceEvidence = header.transactions.compactMap { value -> WalletStreamingBalanceEvidence? in
                guard finality != .pending, value.account.lowercased() == expected, value.emulated != true,
                      let stateHash = walletStreamingHash(value.account_state_after?.hash),
                      let transactionHash = walletStreamingHash(value.hash),
                      let lt = value.lt, let logicalTime = UInt64(lt), logicalTime > 0 else { return nil }
                return WalletStreamingBalanceEvidence(stateHash: stateHash.base64EncodedString(),
                    transactionHash: transactionHash.base64EncodedString(), logicalTime: logicalTime)
            }
            var transactions: [WalletContext.Transaction] = []
            var evidence: [WalletStreamingTransferEvidence] = []
            for value in matchingTransactions {
                guard let transaction = self.transaction(value, walletRawAddress: expected, finality: finality, log: log) else {
                    continue
                }
                if transaction.direction == .incoming, transaction.status != .pending {
                    transactions.append(transaction)
                }
                guard transaction.direction == .outgoing, transaction.status != .failed,
                      let bodyHash = value.inMessage?.message_content?.hash,
                      value.inMessage?.destination?.lowercased() == expected,
                      value.inMessage?.bounced != true,
                      value.description?.aborted == false,
                      value.description?.compute_ph?.success == true,
                      value.description?.action?.success == true,
                      value.emulated == false || finality == .pending else { continue }
                evidence.append(WalletStreamingTransferEvidence(
                    walletAddress: value.account, bodyHash: bodyHash,
                    chainTraceId: value.traceId, transaction: transaction
                ))
            }
            return .transactionsChanged(
                traceId: header.traceExternalHashNorm,
                finality: finality,
                transactions: transactions,
                evidence: evidence,
                balanceEvidence: balanceEvidence
            )
        case "trace_invalidated":
            guard let value = self.decode(TraceInvalidated.self, from: data, decoder: decoder, log: log) else {
                return nil
            }
            guard !value.traceExternalHashNorm.isEmpty else {
                log?("reason=missing_trace_hash")
                return nil
            }
            return .traceInvalidated(traceId: value.traceExternalHashNorm)
        default:
            log?("reason=unsupported_envelope type=\(envelope.type ?? "nil") status=\(envelope.status ?? "nil")")
            return nil
        }
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, decoder: JSONDecoder, log: ((String) -> Void)?) -> T? {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            let reason: String
            let path: [CodingKey]
            switch error {
            case let DecodingError.keyNotFound(key, context):
                reason = "missing_key"
                path = context.codingPath + [key]
            case let DecodingError.valueNotFound(_, context):
                reason = "missing_value"
                path = context.codingPath
            case let DecodingError.typeMismatch(_, context):
                reason = "type_mismatch"
                path = context.codingPath
            case let DecodingError.dataCorrupted(context):
                reason = "invalid_data"
                path = context.codingPath
            default:
                reason = "unknown"
                path = []
            }
            log?("reason=decode_failed model=\(type) detail=\(reason) path=\(path.map(\.stringValue).joined(separator: "."))")
            return nil
        }
    }

    private static func finality(_ value: String) -> WalletStreamingFinality? {
        switch value {
        case "pending": return .pending
        case "confirmed": return .confirmed
        case "finalized": return .finalized
        default: return nil
        }
    }

    private static func unsignedInt64(_ value: String) -> Int64? {
        guard !value.isEmpty, value.allSatisfy(\.isNumber) else {
            return nil
        }
        return Int64(value)
    }

    private static func transaction(
        _ value: StreamingTransaction,
        walletRawAddress: String,
        finality: WalletStreamingFinality,
        log: ((String) -> Void)?
    ) -> WalletContext.Transaction? {
        guard !value.hash.isEmpty,
              !value.lt.isEmpty,
              value.lt.allSatisfy(\.isNumber),
              let timestamp = Int32(exactly: value.now),
              let fee = self.unsignedInt64(value.totalFees) else {
            log?("reason=invalid_transaction_metadata transaction_hash=\(value.hash) lt=\(value.lt)")
            return nil
        }

        struct Candidate {
            let direction: WalletContext.Transaction.Direction
            let amount: Int64
            let address: String
            let bounced: Bool
        }

        var candidates: [Candidate] = []
        if let message = value.inMessage,
           message.destination?.lowercased() == walletRawAddress,
           let source = message.source,
           !source.isEmpty,
           let amountValue = message.value,
           let amount = self.unsignedInt64(amountValue),
           amount > 0 {
            candidates.append(Candidate(
                direction: .incoming,
                amount: amount,
                address: source,
                bounced: message.bounced == true
            ))
        }
        for message in value.outMessages {
            guard message.source?.lowercased() == walletRawAddress,
                  let destination = message.destination,
                  !destination.isEmpty,
                  let amountValue = message.value,
                  let amount = self.unsignedInt64(amountValue),
                  amount > 0 else {
                continue
            }
            candidates.append(Candidate(
                direction: .outgoing,
                amount: amount,
                address: destination,
                bounced: message.bounced == true
            ))
        }

        let outgoing = candidates.filter { $0.direction == .outgoing }
        let supported = outgoing.isEmpty ? candidates : outgoing
        guard supported.count == 1, let candidate = supported.first,
              value.outMessages.count <= 1 else {
            log?("reason=unsupported_transfer_count transaction_hash=\(value.hash) incoming=\(candidates.filter { $0.direction == .incoming }.count) outgoing=\(candidates.filter { $0.direction == .outgoing }.count)")
            return nil
        }
        
        let status: WalletContext.Transaction.Status
        if (candidate.bounced || value.description?.aborted == true
            || value.description?.compute_ph?.success == false || value.description?.action?.success == false) && candidate.direction != .incoming {
            return nil
        } else if finality == .pending || value.emulated == true {
            status = .pending
        } else {
            status = .completed
        }
        let peerAddress = WalletContext.transferAddress(from: candidate.address, preserveBounce: true) ?? candidate.address
        return WalletContext.Transaction(
            id: "\(value.lt):\(value.hash):\(candidate.direction == .incoming ? "in" : "out")",
            transactionHash: value.hash,
            logicalTime: value.lt,
            timestamp: timestamp,
            direction: candidate.direction,
            amount: candidate.direction == .outgoing ? -candidate.amount : candidate.amount,
            fee: fee,
            peer: .address(peerAddress, domain: nil),
            comment: nil,
            status: status
        )
    }

    static func isServerError(_ data: Data) -> Bool {
        guard data.count <= walletStreamingMaximumFrameBytes,
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else {
            return false
        }
        return envelope.error?.isEmpty == false
    }
}

@available(macOS 10.15, *)
struct WalletStreamingBalanceEvidence: Sendable, Equatable {
    let stateHash: String
    let transactionHash: String
    let logicalTime: UInt64
}

@available(macOS 10.15, *)
struct WalletStreamingPresentationOverlay {
    private struct BalanceTransaction {
        let transactionHash: String
        let logicalTime: UInt64
    }

    private struct BalanceValue {
        let revision: UInt64
        let value: Int64
        let updatedAt: Int32
        let stateHash: String?
        let finality: WalletStreamingFinality
        var transaction: BalanceTransaction?
    }

    private struct BalanceEvidenceValue {
        let traceId: String
        let finality: WalletStreamingFinality
        let evidence: WalletStreamingBalanceEvidence
    }

    private struct TraceValue {
        let revision: UInt64
        let finality: WalletStreamingFinality
        let transactions: [WalletContext.Transaction]
    }

    private(set) var revision: UInt64 = 0
    private var balance: BalanceValue?
    private var balanceEvidence: [String: BalanceEvidenceValue] = [:]
    private var balanceEvidenceOrder: [String] = []
    private var reconciledBalanceLogicalTime: UInt64 = 0
    private var traces: [String: TraceValue] = [:]

    var hasUnreconciledBalance: Bool { self.balance != nil }

    var isEmpty: Bool {
        self.balance == nil && self.traces.isEmpty
    }

    mutating func apply(_ event: WalletStreamingParsedEvent, updatedAt: Int32) -> Bool {
        switch event {
        case .connecting, .subscribed, .disconnected, .pong:
            return false
        case let .accountStateChanged(balance, finality, stateHash):
            let transaction = stateHash.flatMap { self.balanceEvidence[$0]?.evidence }.map {
                BalanceTransaction(transactionHash: $0.transactionHash, logicalTime: $0.logicalTime)
            }
            if let transaction, transaction.logicalTime <= self.reconciledBalanceLogicalTime {
                return false
            }
            if let current = self.balance {
                if let transaction, let currentTransaction = current.transaction,
                   transaction.logicalTime < currentTransaction.logicalTime {
                    return false
                }
                if let stateHash, stateHash == current.stateHash, finality.rawValue < current.finality.rawValue {
                    return false
                }
            }
            self.revision &+= 1
            self.balance = BalanceValue(revision: self.revision, value: balance, updatedAt: updatedAt,
                stateHash: stateHash, finality: finality, transaction: transaction)
            return true
        case let .transactionsChanged(traceId, finality, transactions, _, balanceEvidence):
            self.rememberBalanceTransactions(balanceEvidence, traceId: traceId, finality: finality)
            if let current = self.traces[traceId], current.finality.rawValue > finality.rawValue {
                return false
            }
            self.revision &+= 1
            if transactions.isEmpty {
                return self.traces.removeValue(forKey: traceId) != nil
            } else {
                self.traces[traceId] = TraceValue(
                    revision: self.revision,
                    finality: finality,
                    transactions: transactions
                )
                return true
            }
        case let .traceInvalidated(traceId):
            let invalidatedHashes = Set(self.balanceEvidence.compactMap { hash, value in
                value.traceId == traceId && value.finality != .finalized ? hash : nil
            })
            self.balanceEvidence = self.balanceEvidence.filter { !invalidatedHashes.contains($0.key) }
            self.balanceEvidenceOrder.removeAll(where: invalidatedHashes.contains)
            var balanceChanged = false
            if let balance = self.balance, let stateHash = balance.stateHash,
               balance.finality != .finalized, invalidatedHashes.contains(stateHash) {
                // An explicitly invalidated confirmed state is no longer a balance to protect.
                self.balance = nil
                balanceChanged = true
            }
            self.revision &+= 1
            let traceChanged = self.traces.removeValue(forKey: traceId) != nil
            return balanceChanged || traceChanged
        }
    }

    var hasFinalizedTransactions: Bool {
        self.traces.values.contains(where: { $0.finality == .finalized })
    }

    mutating func rememberBalanceTransactions(_ evidence: [WalletStreamingBalanceEvidence], traceId: String, finality: WalletStreamingFinality) {
        guard finality != .pending else { return }
        for value in evidence {
            if let current = self.balanceEvidence[value.stateHash], current.finality.rawValue > finality.rawValue {
                continue
            }
            self.balanceEvidence[value.stateHash] = BalanceEvidenceValue(traceId: traceId, finality: finality, evidence: value)
            self.balanceEvidenceOrder.removeAll(where: { $0 == value.stateHash })
            self.balanceEvidenceOrder.append(value.stateHash)
            if self.balance?.stateHash == value.stateHash {
                self.balance?.transaction = BalanceTransaction(transactionHash: value.transactionHash, logicalTime: value.logicalTime)
            }
        }
        while self.balanceEvidenceOrder.count > 256 {
            self.balanceEvidence.removeValue(forKey: self.balanceEvidenceOrder.removeFirst())
        }
    }

    mutating func reconcileBalance(_ serverBalance: Int64, through revision: UInt64, log: ((String) -> Void)? = nil) -> Bool {
        guard let balance = self.balance else { return false }
        guard balance.revision <= revision else {
            self.logBalanceReconciliation(source: "state", revision: revision, accepted: false, reason: "newer_balance", log: log)
            return false
        }
        guard balance.value == serverBalance else {
            self.logBalanceReconciliation(source: "state", revision: revision, accepted: false, reason: "balance_mismatch", log: log)
            return false
        }
        self.logBalanceReconciliation(source: "state", revision: revision, accepted: true, reason: "balance_matched", log: log)
        if let transaction = balance.transaction {
            self.reconciledBalanceLogicalTime = max(self.reconciledBalanceLogicalTime, transaction.logicalTime)
        }
        self.balance = nil
        return true
    }

    mutating func reconcileBalanceWithHistory(_ serverBalance: Int64, transactions: [WalletContext.Transaction], through revision: UInt64,
        updatedAt: Int32, log: ((String) -> Void)? = nil) -> Bool {
        guard let balance = self.balance else { return false }
        guard balance.revision <= revision else {
            self.logBalanceReconciliation(source: "history", revision: revision, accepted: false, reason: "newer_balance", log: log)
            return false
        }
        // Only the raw response can prove that its balance includes this account state.
        // Merged/cached history can contain the transaction even while the server is behind.
        let confirmedTransactions: [(hash: String, lt: UInt64)] = transactions.compactMap { transaction in
            guard transaction.status == .completed || transaction.status == .failed,
                  let hash = walletStreamingHash(transaction.transactionHash),
                  let lt = UInt64(transaction.logicalTime), lt > 0 else { return nil }
            return (hash.base64EncodedString(), lt)
        }
        guard let anchor = balance.transaction,
              confirmedTransactions.contains(where: { $0.hash == anchor.transactionHash && $0.lt == anchor.logicalTime }),
              var latest = confirmedTransactions.max(by: { $0.lt < $1.lt }) else {
            self.logBalanceReconciliation(source: "history", revision: revision, accepted: false, reason: "transaction_missing", log: log)
            return false
        }
        guard latest.lt > anchor.logicalTime || serverBalance == balance.value else {
            self.logBalanceReconciliation(source: "history", revision: revision, accepted: false, reason: "balance_mismatch", log: log)
            return false
        }
        if latest.lt == anchor.logicalTime {
            latest = (anchor.transactionHash, anchor.logicalTime)
        }
        self.logBalanceReconciliation(source: "history", revision: revision, accepted: true, reason: "transaction_matched", log: log)
        self.reconciledBalanceLogicalTime = max(self.reconciledBalanceLogicalTime, latest.lt)
        guard serverBalance != balance.value || latest.hash != anchor.transactionHash || latest.lt != anchor.logicalTime else { return false }
        self.revision &+= 1
        // Keep protecting the history balance until getState catches up too. Otherwise a
        // concurrently running account refresh could immediately undo this reconciliation.
        self.balance = BalanceValue(revision: self.revision, value: serverBalance, updatedAt: updatedAt,
            stateHash: nil, finality: balance.finality,
            transaction: BalanceTransaction(transactionHash: latest.hash, logicalTime: latest.lt))
        return true
    }

    private func logBalanceReconciliation(source: String, revision: UInt64, accepted: Bool, reason: String, log: ((String) -> Void)?) {
        log?("event=wallet_balance_reconciled source=\(source) request_revision=\(revision) balance_revision=\(self.balance?.revision ?? 0) accepted=\(accepted ? 1 : 0) reason=\(reason)")
    }

    mutating func clearTransactions(
        through revision: UInt64,
        presentIn authoritativeTransactions: [WalletContext.Transaction],
        resolvedTraceIds: Set<String>
    ) -> Int {
        let authoritativeIdentities = WalletTransactionIdentityIndex(authoritativeTransactions)
        let previousCount = self.traces.count
        self.traces = self.traces.filter { traceId, trace in
            guard trace.revision <= revision else {
                return true
            }
            if resolvedTraceIds.contains(traceId) {
                return false
            }
            return !trace.transactions.allSatisfy(authoritativeIdentities.contains)
        }
        return previousCount - self.traces.count
    }

    func transactionHashes(forTraceId traceId: String) -> [String]? {
        guard let trace = self.traces[traceId] else {
            return nil
        }
        let hashes = trace.transactions.compactMap(\.transactionHash)
        guard !hashes.isEmpty, hashes.count == trace.transactions.count else {
            return nil
        }
        return hashes
    }

    func containsTrace(_ traceId: String) -> Bool {
        self.traces[traceId] != nil
    }

    mutating func expirePendingTraces(
        _ traceIds: Set<String>
    ) -> (removedCount: Int, suppressedTraceIds: Set<String>) {
        var removedCount = 0
        var suppressedTraceIds = Set<String>()
        for traceId in traceIds {
            guard let trace = self.traces[traceId] else {
                suppressedTraceIds.insert(traceId)
                continue
            }
            guard trace.finality == .pending else {
                continue
            }
            self.traces.removeValue(forKey: traceId)
            suppressedTraceIds.insert(traceId)
            removedCount += 1
        }
        if removedCount != 0 {
            self.revision &+= 1
        }
        return (removedCount, suppressedTraceIds)
    }

    mutating func removeAll() -> Bool {
        let changed = !self.isEmpty
        self.balance = nil
        self.balanceEvidence.removeAll()
        self.balanceEvidenceOrder.removeAll()
        self.reconciledBalanceLogicalTime = 0
        self.traces.removeAll()
        return changed
    }

    private func transactionsWithPendingDetails(
        _ transactions: [WalletContext.Transaction],
        traceId: String,
        pendingTransfers: [WalletContext.PendingTransfer]
    ) -> [WalletContext.Transaction] {
        var pendingByRecipient: [String: [WalletContext.PendingTransfer]] = [:]
        for pending in pendingTransfers where pending.streamingTraceId == traceId
            && pending.collectibleAddress == nil && pending.amount > 0 {
            guard let recipient = walletAddressMappingKey(pending.recipient) else {
                continue
            }
            pendingByRecipient[recipient, default: []].append(pending)
        }
        guard !pendingByRecipient.isEmpty else {
            return transactions
        }

        var transactionIndicesByRecipient: [String: [Int]] = [:]
        for (index, transaction) in transactions.enumerated() {
            guard transaction.direction == .outgoing,
                  transaction.currency == .ton,
                  transaction.collectible == nil,
                  transaction.kind == .transfer,
                  let address = transaction.peer.address,
                  let recipient = walletAddressMappingKey(address) else {
                continue
            }
            transactionIndicesByRecipient[recipient, default: []].append(index)
        }

        var result = transactions
        // A trace can contain several transfers, so match uniquely on both sides.
        for (recipient, indices) in transactionIndicesByRecipient {
            guard indices.count == 1,
                  let index = indices.first,
                  let matchingPending = pendingByRecipient[recipient],
                  matchingPending.count == 1,
                  let pending = matchingPending.first else {
                continue
            }
            let transaction = transactions[index]
            let hasPendingComment = transaction.comment == nil && pending.comment != nil
            let gasless = transaction.gasless || pending.gasless
            guard hasPendingComment || gasless != transaction.gasless else {
                continue
            }
            result[index] = WalletContext.Transaction(
                id: transaction.id,
                presentationId: transaction.presentationId,
                transactionHash: transaction.transactionHash,
                logicalTime: transaction.logicalTime,
                timestamp: transaction.timestamp,
                direction: transaction.direction,
                amount: transaction.amount,
                fee: transaction.fee,
                gasless: gasless,
                peer: transaction.peer,
                comment: hasPendingComment ? pending.comment : transaction.comment,
                commentEncrypted: hasPendingComment ? pending.commentEncrypted : transaction.commentEncrypted,
                currency: transaction.currency,
                collectible: transaction.collectible,
                status: transaction.status,
                kind: transaction.kind
            )
        }
        return result
    }

    func applying(
        to state: WalletContext.State,
        peerByAddress: [String: EnginePeer],
        presentationIdByTraceId: [String: String],
        presentationIdByTransactionHash: [String: String],
        log: ((String) -> Void)? = nil
    ) -> WalletContext.State {
        let balance: WalletContext.Resource<Int64>
        if let overlayBalance = self.balance {
            balance = .value(overlayBalance.value, updatedAt: overlayBalance.updatedAt)
        } else {
            balance = state.balance
        }

        let authoritativeTransactions = state.transactions.items.map { transaction in
            guard let transactionHash = transaction.transactionHash,
                  let presentationId = presentationIdByTransactionHash[transactionHash] else {
                return transaction
            }
            return walletTransactionWithPresentationId(
                transaction,
                presentationId: presentationId
            )
        }
        let localTransactions = state.pendingTransfers.compactMap { pending -> WalletContext.Transaction? in
            if let traceId = pending.streamingTraceId, self.traces[traceId] != nil {
                return nil
            }
            return walletPendingTransferTransaction(pending)
        }
        let streamingTransactions = self.traces.sorted(by: { $0.key < $1.key }).flatMap { traceId, trace in
            let transactions = self.transactionsWithPendingDetails(
                trace.transactions,
                traceId: traceId,
                pendingTransfers: state.pendingTransfers
            )
            return transactions.map { transaction in
                let presentationId: String?
                if trace.transactions.count == 1,
                   let value = presentationIdByTraceId[traceId] {
                    presentationId = value
                } else if let transactionHash = transaction.transactionHash {
                    presentationId = presentationIdByTransactionHash[transactionHash]
                } else {
                    presentationId = nil
                }
                guard let presentationId else {
                    return transaction
                }
                return walletTransactionWithPresentationId(
                    transaction,
                    presentationId: presentationId
                )
            }
        }
        let overlayTransactions = streamingTransactions + localTransactions
        let presentedTransactions = transactionsWithStreamingOverlay(
            authoritative: authoritativeTransactions,
            streaming: overlayTransactions,
            peerByAddress: peerByAddress,
            log: log
        )
        let transactions: WalletContext.TransactionsState
        if presentedTransactions == state.transactions.items {
            transactions = state.transactions
        } else {
            transactions = WalletContext.TransactionsState(
                items: presentedTransactions,
                offset: state.transactions.offset,
                canLoadMore: state.transactions.canLoadMore,
                isLoadingMore: state.transactions.isLoadingMore,
                error: state.transactions.error
            )
        }
        return WalletContext.State(
            phase: state.phase,
            walletAddress: state.walletAddress,
            balance: balance,
            transactions: transactions,
            collectibles: state.collectibles,
            pendingTransfers: state.pendingTransfers,
            activeOperation: state.activeOperation,
            fiat: state.fiat,
            gaslessInfo: state.gaslessInfo
        )
    }
}

@available(macOS 10.15, *)
private struct WalletStreamingSubscribeRequest: Encodable {
    let operation = "subscribe"
    let types = ["account_state_change", "transactions"]
    let addresses: [String]
    let minFinality = "pending"
    let includeAddressBook = false
    let includeMetadata = false
    let id: String

    enum CodingKeys: String, CodingKey {
        case operation
        case types
        case addresses
        case minFinality = "min_finality"
        case includeAddressBook = "include_address_book"
        case includeMetadata = "include_metadata"
        case id
    }
}

@available(macOS 10.15, *)
private struct WalletStreamingPingRequest: Encodable {
    let operation = "ping"
}

@available(macOS 10.15, *)
actor WalletToncenterStreamingClient {
    struct Configuration: Sendable {
        let initialBackoff: TimeInterval
        let maximumBackoff: TimeInterval
        let pingInterval: TimeInterval
        let inactivityTimeout: TimeInterval

        init(
            initialBackoff: TimeInterval = 1,
            maximumBackoff: TimeInterval = 60,
            pingInterval: TimeInterval = 15,
            inactivityTimeout: TimeInterval = 45
        ) {
            self.initialBackoff = initialBackoff
            self.maximumBackoff = maximumBackoff
            self.pingInterval = pingInterval
            self.inactivityTimeout = inactivityTimeout
        }
    }

    private let provider: WalletStreamingURLProvider
    private let configuration: Configuration
    private let logger: WalletLogger
    private var transport: WalletURLSessionStreamingTransport?
    private var pump: Task<Void, Never>?
    private var continuation: AsyncStream<WalletStreamingParsedEvent>.Continuation?
    private var connectionSubscribed = false
    private var lastConnectionActivityNanoseconds: UInt64?

    init(
        provider: WalletStreamingURLProvider,
        configuration: Configuration = Configuration(),
        logger: WalletLogger
    ) {
        self.provider = provider
        self.configuration = configuration
        self.logger = logger
    }

    func events(rawAddress: String) -> AsyncStream<WalletStreamingParsedEvent> {
        if self.pump != nil {
            return AsyncStream { $0.finish() }
        }
        var continuation: AsyncStream<WalletStreamingParsedEvent>.Continuation!
        let stream = AsyncStream<WalletStreamingParsedEvent>(bufferingPolicy: .bufferingNewest(64)) {
            continuation = $0
        }
        self.continuation = continuation
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop() }
        }
        self.pump = Task { [weak self] in
            await self?.run(rawAddress: rawAddress)
        }
        return stream
    }

    func stop() async {
        self.pump?.cancel()
        self.pump = nil
        await self.transport?.close()
        self.transport = nil
        self.connectionSubscribed = false
        self.lastConnectionActivityNanoseconds = nil
        self.continuation?.finish()
        self.continuation = nil
    }

    private func run(rawAddress: String) async {
        var attempt = 0
        while !Task.isCancelled {
            if attempt > 0 {
                let exponential = min(
                    self.configuration.initialBackoff * pow(2, Double(attempt - 1)),
                    self.configuration.maximumBackoff
                )
                let delay = min(
                    max(exponential * Double.random(in: 0.85 ... 1.15), self.configuration.initialBackoff),
                    self.configuration.maximumBackoff
                )
                do {
                    self.logger.log("event=wallet_stream_reconnect_wait attempt=\(attempt) delay_ms=\(Int(delay * 1000))")
                    try await Task.sleep(nanoseconds: UInt64(max(0, delay) * 1_000_000_000))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }

            self.connectionSubscribed = false
            self.lastConnectionActivityNanoseconds = nil
            self.continuation?.yield(.connecting)
            do {
                try await self.runConnection(rawAddress: rawAddress)
            } catch is CancellationError {
                if Task.isCancelled {
                    return
                }
            } catch {
                self.logger.error("wallet_stream_connection_failed", error, context: "attempt=\(attempt) subscribed=\(self.connectionSubscribed ? 1 : 0)")
            }
            let wasSubscribed = self.connectionSubscribed
            await self.transport?.close()
            self.transport = nil
            self.connectionSubscribed = false
            self.lastConnectionActivityNanoseconds = nil
            if !Task.isCancelled {
                self.continuation?.yield(.disconnected)
            }
            attempt = wasSubscribed ? 1 : min(attempt + 1, 16)
        }
    }

    private func runConnection(rawAddress: String) async throws {
        let transport = WalletURLSessionStreamingTransport(provider: self.provider, logger: self.logger)
        self.transport = transport
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let subscriptionId = UUID().uuidString.lowercased()
        let subscription = try encoder.encode(WalletStreamingSubscribeRequest(
            addresses: [rawAddress],
            id: subscriptionId
        ))
        let ping = try encoder.encode(WalletStreamingPingRequest())
        try await transport.connect(subscription: subscription)
        self.logger.log("event=wallet_stream_subscription_sent subscription_id=\(subscriptionId) account=\(rawAddress)")

        let pingInterval = self.configuration.pingInterval
        let inactivityTimeout = self.configuration.inactivityTimeout
        let logger = self.logger
        let pingTask = Task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(max(0, pingInterval) * 1_000_000_000))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                do {
                    try await transport.send(message: ping)
                } catch {
                    logger.error("wallet_stream_ping_failed", error)
                    await transport.close()
                    return
                }
            }
        }
        defer {
            pingTask.cancel()
        }

        let watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(max(0, pingInterval) * 1_000_000_000))
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                if await self.connectionIsStale(
                    nowNanoseconds: DispatchTime.now().uptimeNanoseconds,
                    timeout: inactivityTimeout
                ) {
                    logger.log("event=wallet_stream_inactivity_timeout")
                    await transport.close()
                    return
                }
            }
        }
        defer {
            watchdogTask.cancel()
        }

        while !Task.isCancelled {
            let data = try await transport.receive()
            self.lastConnectionActivityNanoseconds = DispatchTime.now().uptimeNanoseconds
            if WalletStreamingEventParser.isServerError(data) {
                self.logger.log("event=wallet_stream_server_rejected")
                throw WalletStreamingError.invalidResponse
            }
            guard let event = WalletStreamingEventParser.parse(data, expectedRawAddress: rawAddress, log: {
                logger.log("event=wallet_stream_parse \($0)")
            }) else {
                continue
            }
            if case .subscribed = event {
                self.connectionSubscribed = true
                self.logger.log("event=wallet_stream_subscribed")
            }
            self.continuation?.yield(event)
        }
        throw CancellationError()
    }

    private func connectionIsStale(nowNanoseconds: UInt64, timeout: TimeInterval) -> Bool {
        guard self.connectionSubscribed,
              let lastConnectionActivityNanoseconds = self.lastConnectionActivityNanoseconds else {
            return false
        }
        let timeoutNanoseconds = UInt64(max(0, timeout) * 1_000_000_000)
        return nowNanoseconds >= lastConnectionActivityNanoseconds
            && nowNanoseconds - lastConnectionActivityNanoseconds >= timeoutNanoseconds
    }
}

@available(macOS 10.15, *)
struct WalletStreamingTransferEvidence: Equatable, Sendable {
    let walletAddress: String
    let bodyHash: String
    let chainTraceId: String?
    let transaction: WalletContext.Transaction
}

@available(macOS 10.15, *)
private func walletStreamingHash(_ hash: String?) -> Data? {
    guard let hash, hash.utf8.count == 44,
          let data = Data(base64Encoded: hash), data.count == 32 else { return nil }
    return data
}

@available(macOS 10.15, *)
func walletHistoryTransactionForPending(_ pending: WalletContext.PendingTransfer, transactions: [WalletContext.Transaction]) -> WalletContext.Transaction? {
    let matches = transactions.filter {
        ($0.presentationId == "pending:\(pending.id)" || (pending.transactionHash != nil && $0.transactionHash == pending.transactionHash))
            && !$0.id.isEmpty
            && ($0.status == .failed || $0.status == .completed)
            && $0.direction == .outgoing
            && $0.peer.address.map { walletEngineAddressesEqual($0, pending.recipient) } == true
    }
    return matches.count == 1 ? matches.first : nil
}

@available(macOS 10.15, *)
struct WalletStreamingTransferIdentity {
    let id: String
    let recipient: String
    let normalBodyHash: String?
    let gaslessBodyHash: String?

    init?(pending: WalletContext.PendingTransfer) {
        guard pending.collectibleAddress == nil, let data = pending.streamingData else { return nil }
        self.id = pending.id
        self.recipient = pending.recipient
        self.normalBodyHash = data.normalBodyHash
        self.gaslessBodyHash = data.gaslessBodyHash
    }

    init(record: WalletTransferSubmissionRecord) {
        self.id = record.operationId
        self.recipient = record.recipient
        self.normalBodyHash = record.normalBodyHash
        self.gaslessBodyHash = record.gaslessBodyHash
    }
}

@available(macOS 10.15, *)
func walletTransferBodyMatches(
    _ identities: [WalletStreamingTransferIdentity],
    walletAddress: String,
    evidence: [WalletStreamingTransferEvidence]
) -> [String: WalletStreamingTransferEvidence] {
    func matches(_ identity: WalletStreamingTransferIdentity, _ evidence: WalletStreamingTransferEvidence) -> Bool {
        guard let bodyHash = walletStreamingHash(evidence.bodyHash),
              walletEngineAddressesEqual(walletAddress, evidence.walletAddress),
              evidence.transaction.direction == .outgoing,
              evidence.transaction.status != .failed,
              let recipient = evidence.transaction.peer.address,
              walletEngineAddressesEqual(identity.recipient, recipient) else { return false }
        return [identity.normalBodyHash, identity.gaslessBodyHash].contains { walletStreamingHash($0) == bodyHash }
    }
    var result: [String: WalletStreamingTransferEvidence] = [:]
    for identity in identities {
        let candidates = evidence.filter { matches(identity, $0) }
        guard candidates.count == 1, let match = candidates.first,
              identities.filter({ matches($0, match) }).count == 1 else { continue }
        result[identity.id] = match
    }
    return result
}

@available(macOS 10.15, *)
func walletPendingTransferMatchingBody(
    _ transfer: WalletContext.PendingTransfer,
    match: WalletStreamingTransferEvidence,
    traceId: String,
    finality: WalletStreamingFinality
) -> WalletContext.PendingTransfer {
    if transfer.status == .confirmed,
       finality == .pending || transfer.transactionHash != match.transaction.transactionHash {
        return transfer
    }
    var streamingData = transfer.streamingData
    streamingData?.traceId = traceId
    var updated = transfer
    updated.streamingData = streamingData
    guard finality != .pending, match.transaction.status == .completed,
          walletStreamingHash(match.transaction.transactionHash) != nil else {
        return updated
    }
    if let chainTraceId = walletStreamingHash(match.chainTraceId) {
        if let previous = streamingData?.chainTraceId, walletStreamingHash(previous) != chainTraceId {
            return transfer
        }
        streamingData?.chainTraceId = chainTraceId.base64EncodedString()
    }
    return WalletContext.PendingTransfer(
        id: transfer.id, recipient: transfer.recipient, amount: transfer.amount,
        comment: transfer.comment, commentEncrypted: transfer.commentEncrypted,
        collectibleAddress: transfer.collectibleAddress, normalizedHash: transfer.normalizedHash,
        sentTransfer: transfer.sentTransfer, expectedGasless: transfer.expectedGasless,
        pendingMessage: transfer.pendingMessage,
        streamingData: streamingData, fee: transfer.fee,
        transactionHash: match.transaction.transactionHash, transactionLt: match.transaction.logicalTime,
        uiExpiresAt: transfer.uiExpiresAt, createdAt: transfer.createdAt, status: .confirmed
    )
}

@available(macOS 10.15, *)
func walletPendingTransfersReconciledWithHistory(
    _ pendingTransfers: [WalletContext.PendingTransfer],
    transactions: [WalletContext.Transaction],
    streamingTransactionHashes: (String) -> [String]?
) -> WalletContextImpl.PendingTransferHistoryReconciliation {
    let authoritativeHashes = Set(transactions.compactMap(\.transactionHash))
    guard !authoritativeHashes.isEmpty else {
        return WalletContextImpl.PendingTransferHistoryReconciliation(
            pendingTransfers: pendingTransfers,
            resolvedStreamingTraceIds: [],
            removedPendingCount: 0
        )
    }
    var remaining: [WalletContext.PendingTransfer] = []
    remaining.reserveCapacity(pendingTransfers.count)
    var resolvedStreamingTraceIds = Set<String>()
    for pending in pendingTransfers {
        if let transactionHash = pending.transactionHash,
           authoritativeHashes.contains(transactionHash) {
            if let traceId = pending.streamingTraceId {
                resolvedStreamingTraceIds.insert(traceId)
            }
            continue
        }
        guard let traceId = pending.streamingTraceId,
              pending.streamingData == nil || pending.status == .confirmed,
              let streamingHashes = streamingTransactionHashes(traceId) else {
            remaining.append(pending)
            continue
        }
        if streamingHashes.allSatisfy(authoritativeHashes.contains) {
            resolvedStreamingTraceIds.insert(traceId)
        } else {
            remaining.append(pending)
        }
    }
    return WalletContextImpl.PendingTransferHistoryReconciliation(
        pendingTransfers: remaining,
        resolvedStreamingTraceIds: resolvedStreamingTraceIds,
        removedPendingCount: pendingTransfers.count - remaining.count
    )
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func evaluateStreamingDemand() {
        let demandIsActive = WalletStreamingDemand.isActive(
            foreground: self.isApplicationInForeground,
            accountIsCurrent: self.isAccountCurrent,
            networkAvailable: self.isNetworkAvailable,
            walletScreenCount: self.walletScreenCount,
            hasPendingTransfer: !self.currentState.pendingTransfers.isEmpty
        )
        guard demandIsActive else {
            if self.streamingTask != nil || self.streamingClient != nil {
                self.logger.log("event=wallet_stream_demand_inactive foreground=\(self.isApplicationInForeground ? 1 : 0) account_current=\(self.isAccountCurrent ? 1 : 0) network_available=\(self.isNetworkAvailable ? 1 : 0) wallet_screen_visible=\(self.walletScreenCount > 0 ? 1 : 0) has_pending_transfer=\(self.currentState.pendingTransfers.isEmpty ? 0 : 1)")
            }
            self.stopStreaming()
            return
        }
        guard case let .wallet(info) = self.currentState.phase else {
            if self.streamingTask != nil || self.streamingClient != nil {
                self.logger.log("event=wallet_stream_wallet_inactive")
            }
            self.stopStreaming()
            return
        }
        guard let rawAddress = try? convertTonAddress(value: info.address, format: .raw) else {
            self.logger.log("event=wallet_stream_address_conversion_failed")
            self.stopStreaming()
            return
        }

        let generation = self.activationGeneration
        if self.streamingTask != nil,
           self.streamingAddress == rawAddress,
           self.streamingGeneration == generation {
            return
        }

        self.stopStreaming()
        self.logger.log("event=wallet_stream_start generation=\(generation)")
        let client = WalletToncenterStreamingClient(provider: self.streamingURLProvider, logger: self.logger)
        self.streamingClient = client
        self.streamingAddress = rawAddress
        self.streamingGeneration = generation
        self.streamingConnectionState = .connecting
        self.streamingHasSubscribed = false
        self.streamingTask = Task { [weak self] in
            await self?.runStreaming(client: client, generation: generation, rawAddress: rawAddress)
        }
    }

    private func runStreaming(
        client: WalletToncenterStreamingClient,
        generation: UInt64,
        rawAddress: String
    ) async {
        let events = await client.events(rawAddress: rawAddress)
        for await event in events {
            guard !Task.isCancelled,
                  !self.isShutdown,
                  self.streamingGeneration == generation,
                  WalletStreamingDemand.acceptsEvent(
                    generation: generation,
                    rawAddress: rawAddress,
                    currentGeneration: self.activationGeneration,
                    currentRawAddress: self.streamingAddress,
                    isActive: WalletStreamingDemand.isActive(
                        foreground: self.isApplicationInForeground,
                        accountIsCurrent: self.isAccountCurrent,
                        networkAvailable: self.isNetworkAvailable,
                        walletScreenCount: self.walletScreenCount,
                        hasPendingTransfer: !self.currentState.pendingTransfers.isEmpty
                    )
                  ) else {
                break
            }
            switch event {
            case .connecting:
                self.streamingConnectionState = .connecting
            case .subscribed:
                let isReconnect = self.streamingHasSubscribed
                self.streamingHasSubscribed = true
                self.streamingConnectionState = .subscribed
                self.cancelWalletStateFallbackRefresh()
                if isReconnect {
                    self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
                }
            case .disconnected:
                self.streamingConnectionState = .disconnected
            case .pong:
                break
            case let .accountStateChanged(_, finality, _):
                let changed = self.streamingPresentationOverlay.apply(
                    event,
                    updatedAt: currentWalletTimestamp()
                )
                if changed {
                    self.publishPresentationState()
                }
                self.logger.log("event=wallet_balance_stream source=stream revision=\(self.streamingPresentationOverlay.revision) finality=\(finality.diagnosticName) accepted=\(changed ? 1 : 0) reason=\(changed ? "state_updated" : "obsolete_state")")
                if self.streamingRefreshTracker.requiresRefresh(event) {
                    self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
                }
            case let .transactionsChanged(traceId, finality, transactions, evidence, balanceEvidence):
                if finality == .pending,
                   self.expiredPendingStreamingTraceIds.contains(traceId) {
                    continue
                }
                let pending = self.reconcileStreamingPendingTransfers(
                    traceId: traceId, finality: finality, evidence: evidence, walletAddress: rawAddress
                )
                if self.streamingRefreshTracker.hasFinalizedTrace(traceId) {
                    self.streamingPresentationOverlay.rememberBalanceTransactions(balanceEvidence, traceId: traceId, finality: finality)
                    let changed = pending != self.currentState.pendingTransfers
                        && self.streamingPresentationOverlay.apply(event, updatedAt: currentWalletTimestamp())
                    self.applyStreamingPendingTransfers(pending, overlayChanged: changed)
                    continue
                }
                if finality != .pending {
                    self.expiredPendingStreamingTraceIds.remove(traceId)
                }
                let filteredTransactions = transactions.filter {
                    $0.direction != .incoming || $0.amount >= self.transferMinAmount
                }
                let changed = self.streamingPresentationOverlay.apply(
                    .transactionsChanged(traceId: traceId, finality: finality, transactions: filteredTransactions, balanceEvidence: balanceEvidence),
                    updatedAt: currentWalletTimestamp()
                )
                self.applyStreamingPendingTransfers(pending, overlayChanged: changed)
                if self.streamingRefreshTracker.requiresRefresh(event) {
                    self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
                }
            case let .traceInvalidated(traceId):
                let knownTrace = self.streamingPresentationOverlay.containsTrace(traceId)
                    || self.currentState.pendingTransfers.contains(where: { $0.streamingTraceId == traceId })
                self.expiredPendingStreamingTraceIds.remove(traceId)
                let changed = self.streamingPresentationOverlay.apply(
                    event,
                    updatedAt: currentWalletTimestamp()
                )
                if changed {
                    self.publishPresentationState()
                }
                if self.streamingRefreshTracker.requiresRefresh(event, knownTrace: knownTrace) {
                    self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress)
                }
            }
            self.evaluatePollingDemand()
        }
        await client.stop()
        if self.streamingClient === client {
            self.streamingClient = nil
            self.streamingTask = nil
            self.streamingAddress = nil
            self.streamingGeneration = nil
            self.streamingConnectionState = .inactive
            self.streamingHasSubscribed = false
            self.evaluatePollingDemand()
        }
    }

    func stopStreaming() {
        if self.streamingTask != nil || self.streamingClient != nil {
            self.logger.log("event=wallet_stream_stop")
        }
        self.streamingTask?.cancel()
        self.streamingTask = nil
        self.streamingRefreshTask?.cancel()
        self.streamingRefreshTask = nil
        self.streamingRefreshTaskId = nil
        self.streamingRefreshScope = []
        self.streamingAddress = nil
        self.streamingGeneration = nil
        self.streamingConnectionState = .inactive
        self.streamingHasSubscribed = false
        let client = self.streamingClient
        self.streamingClient = nil
        if let client {
            Task { await client.stop() }
        }
    }

    func retryStreamingSynchronizationIfNeeded(scope: WalletSynchronizationScope) {
        guard self.streamingConnectionState == .subscribed,
              let generation = self.streamingGeneration,
              let rawAddress = self.streamingAddress else { return }
        if self.streamingRefreshTask == nil {
            guard self.streamingRefreshTracker.takeRetry() else { return }
        }
        self.scheduleStreamingRefresh(generation: generation, rawAddress: rawAddress, scope: scope, delay: 3_000_000_000)
    }

    private func scheduleStreamingRefresh(generation: UInt64, rawAddress: String, scope: WalletSynchronizationScope = [.account, .transactions], delay: UInt64 = 1_000_000_000) {
        guard self.activationGeneration == generation,
              self.streamingGeneration == generation,
              self.streamingAddress == rawAddress else {
            return
        }
        self.streamingRefreshScope.formUnion(scope)
        guard self.streamingRefreshTask == nil else { return }
        let taskId = UUID()
        self.streamingRefreshTaskId = taskId
        self.streamingRefreshTask = Task { [weak self] in
            await self?.runStreamingRefreshDelay(
                taskId: taskId,
                generation: generation,
                rawAddress: rawAddress,
                delay: delay
            )
        }
    }

    private func runStreamingRefreshDelay(taskId: UUID, generation: UInt64, rawAddress: String, delay: UInt64) async {
        defer {
            if self.streamingRefreshTaskId == taskId {
                self.streamingRefreshTask = nil
                self.streamingRefreshTaskId = nil
                self.streamingRefreshScope = []
            }
        }
        do {
            try await Task.sleep(nanoseconds: delay)
        } catch {
            return
        }
        guard !self.isShutdown,
              self.streamingRefreshTaskId == taskId,
              self.activationGeneration == generation,
              self.streamingGeneration == generation,
              self.streamingAddress == rawAddress,
              self.canUseNetworkRuntime,
              self.walletScreenCount > 0 || !self.currentState.pendingTransfers.isEmpty else {
            return
        }
        let scope = self.streamingRefreshScope
        self.streamingRefreshTask = nil
        self.streamingRefreshTaskId = nil
        self.streamingRefreshScope = []
        self.requestSynchronization(scope: scope)
    }

    func applyStreamingPendingTransfers(_ pending: [PendingTransfer], overlayChanged: Bool) {
        let reconciliation = self.pendingTransfers(pending, reconcilingWith: self.currentState.transactions.items)
        let removed = self.streamingPresentationOverlay.clearTransactions(
            through: self.streamingPresentationOverlay.revision,
            presentIn: self.currentState.transactions.items,
            resolvedTraceIds: reconciliation.resolvedStreamingTraceIds
        )
        let previousState = self.currentState
        self.replaceState(
            phase: self.currentState.phase, balance: self.currentState.balance,
            transactions: self.currentState.transactions, pendingTransfers: reconciliation.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
        if previousState == self.currentState && (overlayChanged || removed != 0) {
            self.publishPresentationState()
        }
    }

    func resolveStreamingPendingMessage(_ pending: PendingTransfer) {
        guard pending.status == .confirmed,
              let reference = pending.pendingMessage,
              let chainTraceId = pending.streamingData?.chainTraceId else { return }
        let _ = self.engine.wallet.resolvePendingTransferMessage(reference, chainTraceId: chainTraceId).start()
    }

    func reconcileStreamingPendingTransfers(traceId: String, finality: WalletStreamingFinality, evidence: [WalletStreamingTransferEvidence], walletAddress: String) -> [PendingTransfer] {
        guard walletStreamingHash(traceId) != nil else { return self.currentState.pendingTransfers }
        let activeIds = Set(self.currentState.pendingTransfers.map(\.id))
        let awaitingChatTrace = self.outgoingTransactionPresentationIdentities.values.compactMap { identity -> PendingTransfer? in
            let pending = identity.pendingTransfer
            guard !activeIds.contains(pending.id), pending.status == .confirmed,
                  pending.pendingMessage != nil, pending.streamingData?.chainTraceId == nil else { return nil }
            return pending
        }
        let visible = self.currentState.pendingTransfers + awaitingChatTrace
        let visibleIds = Set(visible.map(\.id))
        let retained = self.transferSubmissions.entries.values.compactMap { entry -> WalletStreamingTransferIdentity? in
            let record = entry.record
            guard record.resolution == .pending, !visibleIds.contains(record.operationId),
                  walletEngineAddressesEqual(record.walletAddress, walletAddress) else { return nil }
            return WalletStreamingTransferIdentity(record: record)
        }
        let identities = visible.compactMap(WalletStreamingTransferIdentity.init(pending:)) + retained
        let matches = walletTransferBodyMatches(identities, walletAddress: walletAddress, evidence: evidence)
        let updated = visible.map { transfer in
            matches[transfer.id].map {
                walletPendingTransferMatchingBody(transfer, match: $0, traceId: traceId, finality: finality)
            } ?? transfer
        }
        for identity in retained {
            guard let match = matches[identity.id], finality != .pending,
                  match.transaction.status == .completed,
                  walletStreamingHash(match.transaction.transactionHash) != nil else { continue }
            self.markWalletTransferConsumed(identity.id)
        }
        for (previous, transfer) in zip(visible, updated) where previous != transfer {
            if let previousTrace = previous.streamingTraceId, previousTrace != transfer.streamingTraceId {
                let expired = self.streamingPresentationOverlay.expirePendingTraces([previousTrace])
                self.expiredPendingStreamingTraceIds.formUnion(expired.suppressedTraceIds)
            }
            self.logger.log("event=wallet_pending_body_matched operation_id=\(transfer.id) trace_id=\(traceId) finality=\(finality.diagnosticName) transaction_hash=\(transfer.transactionHash ?? "nil") chain_trace_id=\(transfer.streamingData?.chainTraceId ?? "nil")")
            if transfer.status == .confirmed { self.markWalletTransferConsumed(transfer.id) }
            self.resolveStreamingPendingMessage(transfer)
        }
        self.rememberOutgoingTransactionPresentationIdentities(Array(updated.prefix(visible.count).dropFirst(self.currentState.pendingTransfers.count)))
        return Array(updated.prefix(self.currentState.pendingTransfers.count))
    }
}
