import Foundation
import CoreFoundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI
import PasscodeCore

private let walletTransferResolutionInterval: Int32 = 15
private let walletTransferSubmissionTimeout: UInt64 = 45_000_000_000

@available(macOS 10.15, *)
struct WalletTransferSubmissionClock: Sendable {
    var now: @Sendable () -> Int32 = { Int32(clamping: Int64(Date().timeIntervalSince1970)) }
    var sleep: @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
}

@available(macOS 10.15, *)
struct WalletTransferSubmissionRecord: Codable, Equatable, Sendable {
    enum Resolution: String, Codable, Sendable {
        case pending, consumed, rejected, expired
    }

    let operationId: String
    let recordId: String
    let walletAddress: String
    let seqno: UInt32
    let validUntil: UInt64
    let recipient: String
    let normalBodyHash: String?
    let gaslessBodyHash: String?
    var resolution: Resolution

    var minimumSeqno: UInt64 {
        UInt64(self.seqno) + (self.resolution == .consumed ? 1 : 0)
    }

    func resolved(seqno: UInt32, providerTime: UInt64) -> Resolution {
        if self.resolution != .pending { return self.resolution }
        if seqno > self.seqno { return .consumed }
        if seqno == self.seqno && providerTime > self.validUntil { return .expired }
        return .pending
    }
}

@available(macOS 10.15, *)
enum WalletTransferSubmissionError: Error {
    case staleSequenceNumber
    case invalidChainState
}

@available(macOS 10.15, *)
struct WalletTransferChainState: Equatable, Sendable {
    let seqno: UInt32
    let providerTime: UInt64

    static func parse(account: Data, seqno: Data?) throws -> WalletTransferChainState {
        guard let json = try JSONSerialization.jsonObject(with: account) as? [String: Any],
              json["ok"] as? Bool == true,
              let result = json["result"] as? [String: Any],
              let time = result["sync_utime"] as? NSNumber,
              CFGetTypeID(time) != CFBooleanGetTypeID(),
              time.doubleValue >= 0, time.doubleValue < Double(UInt64.max),
              time.doubleValue.rounded(.down) == time.doubleValue,
              let state = result["state"] as? String else {
            throw WalletTransferSubmissionError.invalidChainState
        }
        let value: UInt32
        let status = state.lowercased()
        if status == "uninitialized" || status == "uninit" || status == "nonexist" {
            value = 0
        } else {
            guard status == "active", let seqno,
                  let json = try JSONSerialization.jsonObject(with: seqno) as? [String: Any],
                  json["ok"] as? Bool != false, json["error"] == nil,
                  let result = json["result"] as? [String: Any],
                  let exitCode = result["exit_code"] as? Int, exitCode == 0 || exitCode == 1,
                  let stack = result["stack"] as? [Any], stack.count == 1,
                  let number = Self.stackNumber(stack[0]),
                  let parsed = number.hasPrefix("0x")
                    ? UInt32(number.dropFirst(2), radix: 16) : UInt32(number) else {
                throw WalletTransferSubmissionError.invalidChainState
            }
            value = parsed
        }
        return WalletTransferChainState(seqno: value, providerTime: time.uint64Value)
    }

    private static func stackNumber(_ item: Any) -> String? {
        if let pair = item as? [Any], pair.count == 2, pair[0] as? String == "num" {
            return pair[1] as? String
        }
        if let object = item as? [String: Any], object["type"] as? String == "num" {
            return object["value"] as? String
        }
        return nil
    }
}

@available(macOS 10.15, *)
struct WalletTransferSubmissionRegistry {
    struct Entry {
        var record: WalletTransferSubmissionRecord
        var confirmed = false
        var processingRPC = false
        var isCurrent = true
    }

    private(set) var entries: [String: Entry] = [:]

    func current(recordId: String, walletAddress: String) -> WalletTransferSubmissionRecord? {
        self.entries.values.first {
            $0.isCurrent && ($0.record.recordId == recordId || walletEngineAddressesEqual($0.record.walletAddress, walletAddress))
        }?.record
    }

    mutating func register(_ record: WalletTransferSubmissionRecord) {
        for (id, entry) in self.entries where entry.record.recordId == record.recordId
            || walletEngineAddressesEqual(entry.record.walletAddress, record.walletAddress) {
            if entry.processingRPC {
                self.entries[id]?.isCurrent = false
            } else {
                self.entries[id] = nil
            }
        }
        self.entries[record.operationId] = Entry(record: record)
    }

    mutating func restore(_ records: [WalletTransferSubmissionRecord]) {
        for record in records {
            if self.entries[record.operationId] != nil {
                self.resolve(record.operationId, as: record.resolution)
            } else if self.current(recordId: record.recordId, walletAddress: record.walletAddress) == nil {
                self.register(record)
            }
        }
    }

    @discardableResult
    mutating func resolve(_ id: String, as resolution: WalletTransferSubmissionRecord.Resolution, confirmed: Bool = false) -> Bool {
        guard var entry = self.entries[id] else { return false }
        entry.confirmed = entry.confirmed || confirmed
        let changed = entry.record.resolution != resolution
            && (entry.record.resolution == .pending || resolution == .consumed)
        if changed { entry.record.resolution = resolution }
        self.entries[id] = entry
        return changed
    }

    mutating func startedRPC(_ id: String) {
        self.entries[id]?.processingRPC = true
    }

    mutating func finishedRPC(_ id: String) {
        guard self.entries[id]?.isCurrent == true else {
            self.entries[id] = nil
            return
        }
        self.entries[id]?.processingRPC = false
    }
}

@available(macOS 10.15, *)
actor WalletTransferSubmissionCoordinator {
    private var owner: UUID?
    private var waiters: [(UUID, CheckedContinuation<Void, Error>)] = []

    func acquire(_ id: UUID) async throws {
        try Task.checkCancellation()
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else if self.owner == nil {
                    self.owner = id
                    continuation.resume()
                } else {
                    self.waiters.append((id, continuation))
                }
            }
            if Task.isCancelled {
                self.release(id)
                throw CancellationError()
            }
        }, onCancel: {
            Task { await self.cancel(id) }
        })
    }

    func release(_ id: UUID) {
        guard self.owner == id else { return }
        if self.waiters.isEmpty {
            self.owner = nil
        } else {
            let (nextId, continuation) = self.waiters.removeFirst()
            self.owner = nextId
            continuation.resume()
        }
    }

    private func cancel(_ id: UUID) {
        guard let index = self.waiters.firstIndex(where: { $0.0 == id }) else { return }
        let (_, continuation) = self.waiters.remove(at: index)
        continuation.resume(throwing: CancellationError())
    }
}

@available(macOS 10.15, *)
final class WalletTransferSubmissionControl: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var committed = false

    func commit() throws {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard !self.cancelled else { throw CancellationError() }
        self.committed = true
    }

    func cancelBeforeCommit() -> Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard !self.committed else { return false }
        self.cancelled = true
        return true
    }
}

@available(macOS 10.15, *)
struct WalletTransferData: Sendable {
    let normal: Data
    let gasless: Data?

    init(prepared: WalletEngineFFI.PreparedTransfer, includeInternalBoc: Bool) throws {
        self.normal = try Self.decodeBoc(prepared.externalBoc)
        self.gasless = includeInternalBoc ? try Self.decodeBoc(prepared.internalBoc) : nil
    }

    func streamingData(operationId: String, logger: WalletLogger) -> WalletContext.PendingTransfer.StreamingData {
        func bodyHash(_ data: Data, kind: WalletBocMessageKind) -> String? {
            do {
                return try walletBocBodyHash(data, kind: kind)
            } catch {
                let reason = (error as? WalletBocError)?.rawValue ?? "unknown"
                logger.log("event=wallet_transfer_boc_hash_failed operation_id=\(operationId) kind=\(kind == .external ? "normal" : "gasless") reason=\(reason)")
                return nil
            }
        }
        return WalletContext.PendingTransfer.StreamingData(
            normalBodyHash: bodyHash(self.normal, kind: .external),
            gaslessBodyHash: self.gasless.flatMap { bodyHash($0, kind: .internalMessage) }
        )
    }

    private static func decodeBoc(_ value: String) throws -> Data {
        guard value.utf8.count <= ((16 * 1024 + 2) / 3) * 4,
              let data = Data(base64Encoded: value),
              !data.isEmpty, data.count <= 16 * 1024 else {
            throw WalletSendTransferError.invalidData
        }
        return data
    }
}

@available(macOS 10.15, *)
struct WalletAPISubmission: Sendable {
    let generation: UInt64
    let startedAt: TimeInterval
    let task: Task<WalletContext.PendingTransfer, Error>
}

@available(macOS 10.15, *)
enum WalletTransferSubmission: Sendable {
    case api(WalletAPISubmission)
    case completed(WalletContext.PendingTransfer)
}

@available(macOS 10.15, *)
func walletPendingTransferAfterRestart(_ pending: WalletContext.PendingTransfer) -> WalletContext.PendingTransfer {
    guard pending.status == .broadcasting, pending.streamingData != nil else { return pending }
    return acceptedWalletTransferSubmission(
        pending: pending, messageHash: nil, phase: .submissionUnknown, acceptedAt: pending.createdAt
    ) ?? pending
}

@available(macOS 10.15, *)
struct WalletTransferHashState {
    let expiresAt: Int32
    var nextAttemptAt: Int32
    var transactions: [WalletContext.Transaction]
}

@available(macOS 10.15, *)
struct WalletTransferResolution {
    let pending: WalletContext.PendingTransfer
    let expiresAt: Int32
    var nextAttemptAt: Int32
}

@available(macOS 10.15, *)
func walletTransferResolutionCandidate(_ pending: WalletContext.PendingTransfer, transactions: [WalletContext.Transaction], history: [WalletContext.Transaction] = []) -> WalletContext.Transaction? {
    let matches = transactions.filter {
        $0.direction == .outgoing
            && $0.peer.address.map { walletEngineAddressesEqual($0, pending.recipient) } == true
    }
    guard matches.count == 1, let transaction = matches.first, !transaction.id.isEmpty,
          transaction.status == .failed || transaction.status == .completed else { return nil }
    guard !history.contains(where: {
        ($0.id == transaction.id || (transaction.transactionHash != nil && $0.transactionHash == transaction.transactionHash))
            && $0.presentationId.hasPrefix("pending:") && $0.presentationId != "pending:\(pending.id)"
    }) else { return nil }
    return transaction
}

@available(macOS 10.15, *)
private func walletTransferConfirmed(_ pending: WalletContext.PendingTransfer, transaction: WalletContext.Transaction) -> WalletContext.PendingTransfer {
    WalletContext.PendingTransfer(
        id: pending.id, recipient: pending.recipient, amount: pending.amount,
        comment: pending.comment, commentEncrypted: pending.commentEncrypted,
        collectibleAddress: pending.collectibleAddress, normalizedHash: pending.normalizedHash,
        sentTransfer: pending.sentTransfer, expectedGasless: pending.expectedGasless,
        pendingMessage: pending.pendingMessage,
        streamingData: pending.streamingData, fee: transaction.fee,
        transactionHash: transaction.transactionHash, transactionLt: transaction.logicalTime,
        uiExpiresAt: pending.uiExpiresAt, createdAt: pending.createdAt, status: .confirmed
    )
}

@available(macOS 10.15, *)
func walletTransferChainState(engine: TelegramEngine, address: String) async throws -> WalletTransferChainState {
    try await withThrowingTaskGroup(of: WalletTransferChainState.self) { group in
        group.addTask {
            var query = URLComponents()
            query.queryItems = [URLQueryItem(name: "address", value: address)]
            let account = try await WalletSignalRequestContext<String>().run(
                engine.wallet.performGetRequest(endpoint: "/api/v2/getAddressInformation", query: query.percentEncodedQuery)
            )
            let accountData = Data(account.utf8)
            let json = try JSONSerialization.jsonObject(with: accountData) as? [String: Any]
            let result = json?["result"] as? [String: Any]
            var seqnoData: Data?
            if (result?["state"] as? String)?.lowercased() == "active" {
                let payload = try JSONSerialization.data(withJSONObject: [
                    "id": 1, "jsonrpc": "2.0", "method": "runGetMethod",
                    "params": ["address": address, "method": "seqno", "stack": []] as [String: Any]
                ])
                let seqno = try await WalletSignalRequestContext<String>().run(
                    engine.wallet.performPostRequest(endpoint: "/api/v2/jsonRPC", payload: String(decoding: payload, as: UTF8.self))
                )
                seqnoData = Data(seqno.utf8)
            }
            return try WalletTransferChainState.parse(account: accountData, seqno: seqnoData)
        }
        group.addTask {
            try await Task.sleep(nanoseconds: 15_000_000_000)
            throw WalletContext.WalletError.network
        }
        defer { group.cancelAll() }
        guard let result = try await group.next() else { throw WalletContext.WalletError.network }
        return result
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func waitForPreviousWalletTransfer(wallet: WalletInfo, generation: UInt64, operationId: UUID, expiresAt: Int32, requireAuthorizationAvailable: Bool = true, allowResolvedWithoutChainCheck: Bool = false) async throws -> UInt32? {
        let startedAt = ProcessInfo.processInfo.systemUptime
        let authorizationGeneration = try self.authorization.operationGeneration(requireAvailable: requireAuthorizationAvailable)
        guard let descriptor = try await self.storage.loadDescriptor(),
              walletEngineAddressesEqual(descriptor.address, wallet.address) else { throw WalletError.unavailable }
        var loggedOperation: String?
        while true {
            try Task.checkCancellation()
            try self.authorization.validateGeneration(authorizationGeneration, requireAvailable: requireAuthorizationAvailable)
            guard !self.isShutdown, self.activationGeneration == generation,
                  case let .wallet(current) = self.currentState.phase,
                  current.address == wallet.address, current.publicKey == wallet.publicKey else { throw WalletError.unavailable }
            guard expiresAt > self.transferSubmissionClock.now() else { throw WalletError.preparedTransferExpired }
            if self.currentState.activeOperation != nil {
                try await self.transferSubmissionClock.sleep(100_000_000)
                continue
            }
            guard let previous = self.transferSubmissions.current(recordId: descriptor.recordId, walletAddress: wallet.address) else {
                return nil
            }
            if allowResolvedWithoutChainCheck && previous.resolution != .pending {
                try await self.persistWalletTransferResolution(previous.operationId)
                try Task.checkCancellation()
                try self.authorization.validateGeneration(authorizationGeneration, requireAvailable: requireAuthorizationAvailable)
                guard !self.isShutdown, self.activationGeneration == generation,
                      case let .wallet(current) = self.currentState.phase,
                      current.address == wallet.address, current.publicKey == wallet.publicKey else { throw WalletError.unavailable }
                guard expiresAt > self.transferSubmissionClock.now() else { throw WalletError.preparedTransferExpired }
                guard self.currentState.activeOperation == nil,
                      self.transferSubmissions.current(recordId: descriptor.recordId, walletAddress: wallet.address) == previous else { continue }
                return nil
            }
            var record = previous
            if loggedOperation != record.operationId {
                loggedOperation = record.operationId
                self.logger.log("event=wallet_transfer_waiting_for_previous operation_id=\(operationId) previous_operation_id=\(record.operationId)")
            }
            do {
                let chain = try await walletTransferChainState(engine: self.engine, address: wallet.address)
                try Task.checkCancellation()
                guard !self.isShutdown, self.activationGeneration == generation else { throw WalletError.unavailable }
                guard let latest = self.transferSubmissions.entries[record.operationId] else { continue }
                record = latest.record
                self.transferSubmissions.resolve(record.operationId, as: record.resolved(seqno: chain.seqno, providerTime: chain.providerTime))
                record = self.transferSubmissions.entries[record.operationId]!.record
                if record.resolution != .pending && UInt64(chain.seqno) >= record.minimumSeqno {
                    try await self.persistWalletTransferResolution(record.operationId)
                    guard !self.isShutdown, self.activationGeneration == generation else { throw WalletError.unavailable }
                    guard let current = self.transferSubmissions.current(recordId: descriptor.recordId, walletAddress: wallet.address),
                          current.operationId == record.operationId,
                          UInt64(chain.seqno) >= current.minimumSeqno else { continue }
                    record = current
                    if self.currentState.activeOperation == nil {
                        self.logger.log("event=wallet_transfer_previous_resolved operation_id=\(operationId) previous_operation_id=\(record.operationId) resolution=\(record.resolution.rawValue) elapsed_ms=\(Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1000.0))")
                        return chain.seqno
                    }
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try Task.checkCancellation()
                guard !self.isShutdown, self.activationGeneration == generation else { throw WalletError.unavailable }
            }
            try await self.transferSubmissionClock.sleep(1_000_000_000)
        }
    }

    func markWalletTransferConsumed(_ operationId: String, successful: Bool = true) {
        guard self.transferSubmissions.resolve(operationId, as: .consumed, confirmed: successful) else { return }
        Task {
            do { try await self.persistWalletTransferResolution(operationId) }
            catch { self.logger.error("wallet_transfer_confirmation_persist_failed", error) }
        }
    }

    func persistWalletTransferResolution(_ operationId: String) async throws {
        while let record = self.transferSubmissions.entries[operationId]?.record, record.resolution != .pending {
            try await self.storage.resolveTransferSubmission(operationId: operationId, resolution: record.resolution)
            if self.transferSubmissions.entries[operationId]?.record.resolution == record.resolution { return }
        }
    }

    func beginWalletApiSubmission(
        prepared: PreparedTransfer,
        intent: SendIntent,
        pending: PendingTransfer,
        recipientPeerId: EnginePeer.Id?,
        randomId: Int64,
        walletAddress: String,
        generation: UInt64,
        control: WalletTransferSubmissionControl,
        minimumSeqno: UInt32?,
        pendingRegistration: WalletContext.PendingTransferRegistration? = nil,
        registrationSession: PasscodeSession? = nil
    ) async throws -> WalletAPISubmission {
        let startedAt = ProcessInfo.processInfo.systemUptime
        do {
            let preparedData = try await self.runtime.prepareTransfer(
                operationId: prepared.id,
                intent: intent
            )
            try Task.checkCancellation()
            guard !self.isShutdown, self.activationGeneration == generation,
                  case let .wallet(info) = self.currentState.phase,
                  walletEngineAddressesEqual(info.address, walletAddress),
                  preparedData.data.operationId == pending.id else {
                throw WalletError.unavailable
            }
            guard preparedData.data.validUntil > UInt64(max(0, self.transferSubmissionClock.now())) else {
                throw WalletError.preparedTransferExpired
            }
            if let pendingRegistration {
                guard self.pendingTransferRegistrations[pending.id]?.registration == pendingRegistration,
                      let registrationSession else { throw WalletError.unavailable }
                try self.authorization.validate(registrationSession, boundTo: pendingRegistration.sessionId, requireAvailable: false)
            }
            let data = try WalletTransferData(
                prepared: preparedData.data,
                includeInternalBoc: prepared.amount >= self.transferGaslessMinAmount
                    && !WalletContext.isSelfTransfer(recipient: prepared.recipient, walletAddress: walletAddress)
            )
            var persistedPending = pending
            if pendingRegistration != nil {
                persistedPending.uiExpiresAt = walletPendingTransferUIExpirationTimestamp(from: self.transferSubmissionClock.now())
            }
            persistedPending.streamingData = data.streamingData(operationId: pending.id, logger: self.logger)
            let previous = self.transferSubmissions.current(recordId: preparedData.recordId, walletAddress: walletAddress)
            guard preparedData.data.seqno >= (minimumSeqno ?? 0),
                  previous == nil || (previous!.resolution != .pending && UInt64(preparedData.data.seqno) >= previous!.minimumSeqno) else {
                throw WalletTransferSubmissionError.staleSequenceNumber
            }
            self.stopPendingTransferRegistration(pending.id)
            self.refreshRegisteredTransferMessage(persistedPending)
            self.replaceState(phase: self.currentState.phase, balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: self.currentState.pendingTransfers.filter { $0.id != pending.id } + [persistedPending],
                activeOperation: self.currentState.activeOperation)
            try await self.persistPendingTransferBeforeSend(persistedPending, generation: generation)
            let record = WalletTransferSubmissionRecord(
                operationId: pending.id, recordId: preparedData.recordId, walletAddress: walletAddress,
                seqno: preparedData.data.seqno, validUntil: preparedData.data.validUntil,
                recipient: pending.recipient, normalBodyHash: persistedPending.streamingData?.normalBodyHash,
                gaslessBodyHash: persistedPending.streamingData?.gaslessBodyHash, resolution: .pending
            )
            try await self.storage.saveTransferSubmission(record)
            self.transferSubmissions.register(record)
            do {
                try Task.checkCancellation()
                guard !self.isShutdown, self.activationGeneration == generation else { throw WalletError.unavailable }
                if let pendingRegistration {
                    guard self.isCurrentPendingTransferRegistration(pendingRegistration), let registrationSession else { throw WalletError.unavailable }
                    try self.authorization.validate(registrationSession, boundTo: pendingRegistration.sessionId, requireAvailable: false)
                }
                try control.commit()
            } catch {
                self.transferSubmissions.resolve(pending.id, as: .rejected)
                try await self.persistWalletTransferResolution(pending.id)
                throw error
            }
            self.preparedTransfers[prepared.id] = nil
            let submittedPending = persistedPending
            let request = WalletSignalRequestContext<WalletSendTransferResult>()
            let requestStartedAt = ProcessInfo.processInfo.systemUptime
            self.transferSubmissions.startedRPC(pending.id)
            let task = WalletAuthorizationScope.$session.withValue(nil) {
                request.start(self.engine.wallet.sendTransfer(dataNormal: data.normal, dataGasless: data.gasless,
                    recipientPeerId: recipientPeerId, randomId: randomId, pendingMessage: submittedPending.pendingMessage))
                return Task {
                    try await self.submitTransferData(request, pending: submittedPending,
                        generation: generation, startedAt: startedAt, requestStartedAt: requestStartedAt)
                }
            }
            return WalletAPISubmission(generation: generation, startedAt: startedAt, task: task)
        } catch {
            self.logger.error("wallet_transfer_api_failed", error)
            if case WalletTransferSubmissionError.staleSequenceNumber = error,
               self.pendingTransferRegistrations[pending.id] != nil {
                throw error
            }
            if let registration = self.pendingTransferRegistrations[pending.id]?.registration {
                self.discardPendingTransferRegistration(registration)
            }
            if self.activationGeneration == generation {
                if case WalletTransferSubmissionError.staleSequenceNumber = error {

                } else {
                    self.preparedTransfers[prepared.id] = nil
                }
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers.filter { $0.id != pending.id },
                    activeOperation: self.currentState.activeOperation
                )
            }
            if let pendingMessage = pending.pendingMessage {
                let _ = self.engine.wallet.removePendingTransferMessage(pendingMessage).start()
            }
            throw error
        }
    }

    func finishWalletApiSubmission(_ submission: WalletAPISubmission) async throws -> PendingTransfer {
        let generation = submission.generation
        let accepted = try await submission.task.value
        guard !self.isShutdown, self.activationGeneration == generation else {
            throw WalletError.unavailable
        }
        return accepted
    }

    private func submitTransferData(
        _ request: WalletSignalRequestContext<WalletSendTransferResult>,
        pending: PendingTransfer,
        generation: UInt64,
        startedAt: TimeInterval,
        requestStartedAt: TimeInterval
    ) async throws -> PendingTransfer {
        defer {
            let event = self.transferSubmissions.entries[pending.id]?.confirmed == true ? "wallet_transfer_late_response" : "wallet_transfer_rpc_finished"
            self.logger.log("event=\(event) operation_id=\(pending.id) elapsed_ms=\(Int((ProcessInfo.processInfo.systemUptime - startedAt) * 1000.0))")
            self.transferSubmissions.finishedRPC(pending.id)
        }
        let pendingMessage = pending.pendingMessage
        let clock = self.transferSubmissionClock
        let response: WalletSendTransferResult?
        do {
            response = try await withThrowingTaskGroup(of: WalletSendTransferResult.self) { group in
                group.addTask {
                    try await request.value()
                }
                group.addTask {
                    let elapsed = max(0, ProcessInfo.processInfo.systemUptime - requestStartedAt)
                    let remaining = max(0, Double(walletTransferSubmissionTimeout) - elapsed * 1_000_000_000)
                    try await clock.sleep(UInt64(remaining))
                    throw WalletSendTransferError.network
                }
                defer { group.cancelAll() }
                guard let result = try await group.next() else {
                    throw WalletSendTransferError.network
                }
                return result
            }
        } catch let error as WalletSendTransferError where error == .invalidData || error == .sendFailed || error == .keyMismatch {
            if self.transferSubmissions.entries[pending.id]?.confirmed != true && self.latestPendingTransfer(pending).status != .confirmed {
                if error == .keyMismatch, self.activationGeneration == generation {
                    self.preparedTransfers.removeAll()
                    self.preparedAuthorizations.removeAll()
                    self.serverStateNeedsActivation = true
                    self.serverStateMutationRevision &+= 1
                    await self.runtime.requireWalletKeyReconciliation(revision: self.serverStateMutationRevision)
                }
                defer {
                    if error == .keyMismatch, self.activationGeneration == generation {
                        self.requestServerWalletState(forceRefreshAfterCurrent: true)
                    }
                }
                self.transferSubmissions.resolve(pending.id, as: .rejected)
                try await self.persistWalletTransferResolution(pending.id)
                if self.transferSubmissions.entries[pending.id]?.confirmed != true && self.latestPendingTransfer(pending).status != .confirmed {
                    if self.activationGeneration == generation {
                        self.replaceState(phase: self.currentState.phase, balance: self.currentState.balance,
                            transactions: self.currentState.transactions,
                            pendingTransfers: self.currentState.pendingTransfers.filter { $0.id != pending.id },
                            activeOperation: self.currentState.activeOperation)
                    }
                    if let pendingMessage { let _ = self.engine.wallet.removePendingTransferMessage(pendingMessage).start() }
                    throw error
                }
            }
            response = nil
        } catch {
            response = nil
        }
        guard !self.isShutdown, self.activationGeneration == generation else { throw WalletError.unavailable }
        let transfer = response?.transfer
        if let transfer {
            self.logger.log("event=wallet_transfer_accepted operation_id=\(pending.id) msg_hash=\(transfer.msgHash) gasless=\(transfer.gasless ? 1 : 0)")
        }
        let receivedAt = currentWalletTimestamp()
        guard let accepted = acceptedWalletTransferSubmission(
            pending: self.latestPendingTransfer(pending),
            messageHash: nil,
            phase: self.transferSubmissions.entries[pending.id]?.confirmed == true ? .confirmed : (transfer == nil ? .submissionUnknown : .submitted),
            acceptedAt: receivedAt,
            sentTransfer: transfer
        ) else {
            throw WalletContext.WalletError.unavailable
        }
        self.preparedTransfers[pending.id] = nil
        let candidate = walletHistoryTransactionForPending(accepted, transactions: self.currentState.transactions.items)
            ?? response?.transaction.flatMap { walletTransactions(from: [$0]).first }
            ?? accepted.sentTransfer.flatMap { self.cachedWalletTransferTransaction(accepted, msgHash: $0.msgHash) }
        let finalTransaction = accepted.status == .confirmed && candidate?.status == .failed ? nil : candidate
        if let finalTransaction {
            await self.applyWalletFinalTransaction(finalTransaction, pending: accepted, generation: generation, source: "send_response")
            guard !self.isShutdown, self.activationGeneration == generation else { throw WalletError.unavailable }
            if let sent = accepted.sentTransfer {
                self.rememberWalletFinalTransaction(finalTransaction, msgHash: sent.msgHash)
            }
            self.requestSynchronization(scope: [.account], force: true)
            try await self.persistWalletTransferState(generation: generation)
            if finalTransaction.status == .failed { throw WalletSendTransferError.sendFailed }
            return walletTransferConfirmed(accepted, transaction: finalTransaction)
        }
        self.trackWalletTransferResolution(accepted, receivedAt: receivedAt)
        var values = self.currentState.pendingTransfers.filter { $0.id != accepted.id }
        values.append(accepted)
        self.resolveStreamingPendingMessage(accepted)
        let reconciliation = self.pendingTransfers(values, reconcilingWith: self.currentState.transactions.items)
        self.replaceState(
            phase: self.currentState.phase, balance: self.currentState.balance,
            transactions: self.currentState.transactions, pendingTransfers: reconciliation.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
        if transfer == nil || self.streamingConnectionState != .subscribed {
            self.requestSynchronization(scope: [.account, .transactions], force: true)
        }
        try await self.persistWalletTransferState(generation: generation)
        return accepted
    }

    func persistWalletTransferState(generation: UInt64) async throws {
        guard !self.isShutdown, self.activationGeneration == generation,
              await self.storedStateWriter.storeAndWait(self.storedState, revision: self.storedStateMutationRevision),
              !self.isShutdown, self.activationGeneration == generation else { throw WalletError.unavailable }
    }

    func trackWalletTransferResolution(_ pending: PendingTransfer, receivedAt: Int32? = nil) {
        guard self.walletTransferResolutions[pending.id] == nil,
              let sent = pending.sentTransfer, !sent.msgHash.isEmpty, pending.collectibleAddress == nil else { return }
        let acceptedAt = receivedAt ?? pending.uiExpiresAt.map {
            Int32(clamping: Int64($0) - Int64(walletPendingTransferUILifetime))
        } ?? pending.createdAt
        let expiresAt = walletPendingTransferUIExpirationTimestamp(from: acceptedAt)
        guard expiresAt > currentWalletTimestamp() else { return }
        self.walletTransferResolutions[pending.id] = WalletTransferResolution(
            pending: pending, expiresAt: expiresAt,
            nextAttemptAt: Int32(clamping: Int64(acceptedAt) + Int64(walletTransferResolutionInterval))
        )
    }

    func cancelWalletTransferResolution() {
        self.walletTransferResolutionTask?.cancel()
    }

    func evaluateWalletTransferResolution() {
        let now = currentWalletTimestamp()
        self.walletTransferResolutions = self.walletTransferResolutions.filter { $0.value.expiresAt > now }
        self.walletTransferHashStates = self.walletTransferHashStates.filter { $0.value.expiresAt > now }
        let remoteDeadlines = self.walletTransferHashStates.values.filter { $0.transactions.isEmpty }.map(\.nextAttemptAt)
        guard self.canUseNetworkRuntime, case .wallet = self.currentState.phase else {
            self.cancelWalletTransferResolution()
            return
        }
        guard let deadline = (self.walletTransferResolutions.values.map(\.nextAttemptAt) + remoteDeadlines).min() else {
            if self.walletTransferResolutionScheduledAt != nil {
                self.cancelWalletTransferResolution()
            }
            return
        }
        if self.walletTransferResolutionTask != nil {
            if let scheduled = self.walletTransferResolutionScheduledAt, deadline < scheduled {
                self.cancelWalletTransferResolution()
            }
            return
        }
        let generation = self.activationGeneration
        self.walletTransferResolutionScheduledAt = deadline
        self.walletTransferResolutionTask = Task { [weak self] in
            await self?.runWalletTransferResolution(generation: generation, deadline: deadline)
        }
    }

    private func isCurrentWalletTransferResolution(_ generation: UInt64) -> Bool {
        !Task.isCancelled && self.canUseNetworkRuntime && self.activationGeneration == generation
    }

    private func pendingWalletTransferResolution(_ operationId: String) -> PendingTransfer? {
        guard let resolution = self.walletTransferResolutions[operationId],
              resolution.expiresAt > currentWalletTimestamp() else { return nil }
        return self.latestPendingTransfer(resolution.pending)
    }

    private func runWalletTransferResolution(generation: UInt64, deadline: Int32) async {
        var attemptedHash: String?
        defer {
            if let attemptedHash, self.isCurrentWalletTransferResolution(generation) {
                let nextAttemptAt = Int32(clamping: Int64(currentWalletTimestamp()) + Int64(walletTransferResolutionInterval))
                if self.walletTransferHashStates[attemptedHash]?.transactions.isEmpty == true {
                    self.walletTransferHashStates[attemptedHash]?.nextAttemptAt = nextAttemptAt
                }
                for id in Array(self.walletTransferResolutions.keys) where self.walletTransferResolutions[id]?.pending.sentTransfer?.msgHash == attemptedHash {
                    self.walletTransferResolutions[id]?.nextAttemptAt = nextAttemptAt
                }
            }
            self.walletTransferResolutionTask = nil
            self.walletTransferResolutionScheduledAt = nil
            self.evaluateWalletTransferResolution()
        }
        do {
            let delay = max(0, Double(deadline) - Date().timeIntervalSince1970)
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard self.isCurrentWalletTransferResolution(generation) else { return }
            self.walletTransferResolutionScheduledAt = nil
            let now = currentWalletTimestamp()
            let due = self.walletTransferResolutions.values.filter {
                $0.expiresAt > now && $0.nextAttemptAt <= now
            }.sorted {
                $0.nextAttemptAt == $1.nextAttemptAt ? $0.pending.id < $1.pending.id : $0.nextAttemptAt < $1.nextAttemptAt
            }
            let remoteHash = self.walletTransferHashStates.filter {
                $0.value.transactions.isEmpty && $0.value.nextAttemptAt <= now
            }.min { $0.value.nextAttemptAt < $1.value.nextAttemptAt }?.key
            guard let hash = due.first?.pending.sentTransfer?.msgHash ?? remoteHash else { return }
            attemptedHash = hash
            var unresolvedIds: [String] = []
            for resolution in due where resolution.pending.sentTransfer?.msgHash == hash {
                let id = resolution.pending.id
                guard self.isCurrentWalletTransferResolution(generation),
                      let pending = self.pendingWalletTransferResolution(id) else { continue }
                if let transaction = walletHistoryTransactionForPending(pending, transactions: self.currentState.transactions.items) {
                    if try await self.applyWalletTransferResolution(operationId: id, transaction: transaction, generation: generation) {
                        self.walletTransferResolutions[id] = nil
                        continue
                    }
                }
                unresolvedIds.append(id)
            }
            var deadlines = unresolvedIds.compactMap { self.walletTransferResolutions[$0]?.expiresAt }
            if let state = self.walletTransferHashStates[hash], state.transactions.isEmpty {
                deadlines.append(state.expiresAt)
            }
            guard self.isCurrentWalletTransferResolution(generation),
                  let expiresAt = deadlines.max(),
                  expiresAt > currentWalletTimestamp() else { return }
            self.logger.log("event=wallet_transfer_fallback_requested operation_count=\(unresolvedIds.count)")
            let transactions = try await WalletSignalRequestContext<[Transaction]>().run(
                self.engine.wallet.getTransactionsByMsgHash(msgHash: [hash])
                |> timeout(min(Double(walletTransferResolutionInterval), Double(expiresAt) - Date().timeIntervalSince1970), queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
                |> map { walletTransactions(from: $0.items) }
            )
            guard self.isCurrentWalletTransferResolution(generation) else { return }
            for transaction in transactions {
                self.rememberWalletFinalTransaction(transaction, msgHash: hash)
                await self.applyWalletFinalTransaction(transaction, pending: nil, generation: generation, source: "message_lookup")
                guard self.isCurrentWalletTransferResolution(generation) else { return }
            }
            for id in unresolvedIds {
                guard self.isCurrentWalletTransferResolution(generation),
                      let pending = self.pendingWalletTransferResolution(id),
                      let transaction = walletTransferResolutionCandidate(pending, transactions: transactions, history: self.currentState.transactions.items) else { continue }
                let sameRecipient = self.walletTransferResolutions.values.filter {
                    $0.expiresAt > currentWalletTimestamp() && $0.pending.sentTransfer?.msgHash == hash
                        && walletEngineAddressesEqual($0.pending.recipient, pending.recipient)
                }
                guard sameRecipient.count == 1 else { continue }
                if try await self.applyWalletTransferResolution(operationId: id, transaction: transaction, generation: generation) {
                    self.walletTransferResolutions[id] = nil
                }
            }
        } catch {
            if !(error is CancellationError) {
                self.logger.error("wallet_transfer_resolution_failed", error)
            }
        }
    }

    private func applyWalletTransferResolution(operationId: String, transaction: Transaction, generation: UInt64) async throws -> Bool {
        guard self.isCurrentWalletTransferResolution(generation),
              let pending = self.pendingWalletTransferResolution(operationId) else { return false }
        if transaction.status == .failed,
           pending.status == .confirmed || self.transferSubmissions.entries[pending.id]?.confirmed == true {
            return false
        }
        await self.applyWalletFinalTransaction(transaction, pending: pending, generation: generation, source: "transfer_resolution")
        return !self.isShutdown && self.activationGeneration == generation
    }

    func applyWalletFinalTransaction(_ transaction: Transaction, pending: PendingTransfer?, generation: UInt64, source: String = "transfer_resolution") async {
        guard !self.isShutdown, self.activationGeneration == generation, !transaction.id.isEmpty else { return }
        if transaction.status == .failed, let pending,
           pending.status == .confirmed || self.transferSubmissions.entries[pending.id]?.confirmed == true {
            return
        }
        var values = self.currentState.pendingTransfers
        var resolvedTraceIds = Set<String>()
        var overlayChanged = false
        if let pending {
            if transaction.status == .completed || transaction.status == .failed { self.markWalletTransferConsumed(pending.id, successful: transaction.status == .completed) }
            self.walletTransferResolutions[pending.id] = nil
            values.removeAll { $0.id == pending.id }
            if let traceId = pending.streamingTraceId {
                resolvedTraceIds.insert(traceId)
                if transaction.status == .failed {
                    let expired = self.streamingPresentationOverlay.expirePendingTraces([traceId])
                    self.expiredPendingStreamingTraceIds.formUnion(expired.suppressedTraceIds)
                    overlayChanged = expired.removedCount != 0
                }
            }
            if transaction.status != .failed {
                self.rememberOutgoingTransactionPresentationIdentities([walletTransferConfirmed(pending, transaction: transaction)])
            }
        }
        let value = pending.map {
            walletTransactionWithPresentationId(transaction, presentationId: "pending:\($0.id)")
        } ?? transaction
        let items = mergeTransactions(
            existing: self.currentState.transactions.items, new: [value], source: source, log: self.logger.log
        )
        let reconciliation = self.pendingTransfers(values, reconcilingWith: items)
        resolvedTraceIds.formUnion(reconciliation.resolvedStreamingTraceIds)
        let removed = self.streamingPresentationOverlay.clearTransactions(
            through: self.streamingPresentationOverlay.revision,
            presentIn: items, resolvedTraceIds: resolvedTraceIds
        )
        let previousState = self.currentState
        self.replaceState(
            phase: self.currentState.phase, balance: self.currentState.balance,
            transactions: TransactionsState(
                items: items, offset: items.count,
                canLoadMore: self.currentState.transactions.canLoadMore,
                isLoadingMore: self.currentState.transactions.isLoadingMore, error: self.currentState.transactions.error
            ),
            pendingTransfers: reconciliation.pendingTransfers, activeOperation: self.currentState.activeOperation
        )
        if previousState == self.currentState && (overlayChanged || removed != 0) {
            self.publishPresentationState()
        }
        self.logPendingTransferHistoryReconciliation(reconciliation, removedStreamingTraceCount: removed)
        if let reference = pending?.pendingMessage,
           case let .user(peer, _, _) = transaction.peer, peer.id.toInt64() == reference.peerId {
            do {
                try await WalletSignalRequestContext<Void>().run(
                    self.engine.wallet.resolvePendingTransferMessage(reference, transactionId: transaction.id, failed: transaction.status == .failed)
                    |> castError(WalletError.self)
                )
            } catch {
                self.logger.error("wallet_transfer_message_resolution_failed", error)
            }
        }
    }

    func cachedWalletTransferTransaction(_ pending: PendingTransfer, msgHash: String) -> Transaction? {
        guard let state = self.walletTransferHashStates[msgHash], state.expiresAt > currentWalletTimestamp() else { return nil }
        return walletTransferResolutionCandidate(pending, transactions: state.transactions, history: self.currentState.transactions.items)
    }

    func rememberWalletFinalTransaction(_ transaction: Transaction, msgHash: String) {
        let now = currentWalletTimestamp()
        let existing = self.walletTransferHashStates[msgHash].flatMap { $0.expiresAt > now ? $0 : nil }
        var state = existing ?? WalletTransferHashState(
            expiresAt: walletPendingTransferUIExpirationTimestamp(from: now), nextAttemptAt: now, transactions: []
        )
        state.transactions = mergeTransactions(existing: state.transactions, new: [transaction])
        self.walletTransferHashStates[msgHash] = state
    }

    func receiveWalletTransferUpdates(_ updates: [WalletTransferUpdate], walletAddress: String?) async {
        guard !self.isShutdown, let walletAddress, case let .wallet(info) = self.currentState.phase,
              walletEngineAddressesEqual(info.address, walletAddress) else { return }
        let generation = self.activationGeneration
        for update in updates {
            guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
            switch update {
            case let .gaslessInfo(info):
                self.applyGaslessInfo(info)
            case let .sentTransaction(transfer, apiTransaction):
                let now = currentWalletTimestamp()
                if let state = self.walletTransferHashStates[transfer.msgHash], state.expiresAt <= now {
                    self.walletTransferHashStates[transfer.msgHash] = nil
                }
                if let apiTransaction, let transaction = walletTransactions(from: [apiTransaction]).first {
                    self.rememberWalletFinalTransaction(transaction, msgHash: transfer.msgHash)
                    let candidates = self.currentState.pendingTransfers.filter {
                        $0.sentTransfer?.msgHash == transfer.msgHash
                            && walletTransferResolutionCandidate($0, transactions: [transaction], history: self.currentState.transactions.items) != nil
                    }
                    await self.applyWalletFinalTransaction(transaction, pending: candidates.count == 1 ? candidates[0] : nil, generation: generation, source: "server_update")
                    guard !self.isShutdown, self.activationGeneration == generation else { return }
                    self.requestSynchronization(scope: [.account], force: true)
                } else if self.walletTransferHashStates[transfer.msgHash] == nil {
                    self.walletTransferHashStates[transfer.msgHash] = WalletTransferHashState(
                        expiresAt: walletPendingTransferUIExpirationTimestamp(from: now),
                        nextAttemptAt: Int32(clamping: Int64(now) + Int64(walletTransferResolutionInterval)), transactions: []
                    )
                }
            }
        }
        self.evaluateWalletTransferResolution()
    }
}
