import Foundation
import PasscodeCore
import SwiftSignalKit
import TelegramCore

@available(macOS 10.15, *)
struct WalletPendingTransferRegistrationRecord {
    let registration: WalletContext.PendingTransferRegistration
    let session: PasscodeSession
    let peerId: EnginePeer.Id
    let randomId: Int64
    let requestedAmount: Int64
    let sendAll: Bool
    let comment: String?
    var pending: WalletContext.PendingTransfer
    var renewalTask: Task<Void, Never>?
}

@available(macOS 10.15, *)
public extension WalletContext {
    func registerPendingTransfer(
        walletAddress: String, walletPublicKey: String, peerId: EnginePeer.Id,
        address: String, amount: Int64, sendAll: Bool, estimatedFee: Int64?,
        comment: String?, commentEncrypted: Bool, session: PasscodeSession
    ) -> Signal<PendingTransferRegistration, WalletError> {
        self.signal(name: "registering_pending_transfer", discardResult: { [impl = self.impl] registration in
            Task { await impl.discardPendingTransferRegistration(registration) }
        }) { impl, _ in
            try await impl.registerPendingTransfer(
                walletAddress: walletAddress, walletPublicKey: walletPublicKey, peerId: peerId,
                address: address, amount: amount, sendAll: sendAll, estimatedFee: estimatedFee,
                comment: comment, commentEncrypted: commentEncrypted, session: session
            )
        }
    }

    func discardPendingTransferRegistration(_ registration: PendingTransferRegistration) -> Signal<Void, WalletError> {
        self.signal(name: "discarding_pending_transfer", cancelOnDispose: false) { impl, _ in
            await impl.discardPendingTransferRegistration(registration)
        }
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func registerPendingTransfer(
        walletAddress: String, walletPublicKey: String, peerId: EnginePeer.Id,
        address: String, amount: Int64, sendAll: Bool, estimatedFee: Int64?,
        comment: String?, commentEncrypted: Bool, session: PasscodeSession
    ) async throws -> WalletContext.PendingTransferRegistration {
        try Task.checkCancellation()
        try self.authorization.validate(session, requireAvailable: false)
        guard !self.isShutdown, case let .wallet(info) = self.currentState.phase,
              info.address == walletAddress, info.publicKey == walletPublicKey, info.canSign else {
            throw WalletError.unavailable
        }
        let resolved = try resolveTransferInput(address: address, amount: amount, comment: comment)
        let resolvedSendAll = sendAll && !resolved.hasLinkAmount
        let feesAreCovered = WalletContext.useWalletTransferApi
            && !WalletContext.isSelfTransfer(recipient: resolved.address, walletAddress: info.address)
            && WalletContext.isGaslessEligible(amount: resolved.amount, gaslessInfo: self.currentState.gaslessInfo.currentValue, minimumAmount: self.transferGaslessMinAmount)
        let fee = max(0, estimatedFee ?? 0)
        // An estimate cannot reject a transfer; preparation falls back to emulation if the estimate does not fit.
        let displayAmount = resolvedSendAll && !feesAreCovered && fee < resolved.amount ? resolved.amount - fee : resolved.amount
        let encrypted = commentEncrypted && resolved.comment?.isEmpty == false
        let pendingComment = encrypted ? nil : resolved.comment
        let registration = WalletContext.PendingTransferRegistration(
            id: UUID().uuidString.lowercased(), walletAddress: info.address, walletPublicKey: info.publicKey,
            sessionId: session.id, generation: self.activationGeneration
        )
        let randomId = Int64.random(in: Int64.min ... Int64.max)
        let createdAt = self.transferSubmissionClock.now()
        let pendingMessage: WalletPendingTransferMessageReference?
        if WalletContext.useWalletTransferApi {
            let creation = Task { [engine = self.engine] in
                try await WalletSignalRequestContext<WalletPendingTransferMessageReference?>().run(
                    engine.wallet.createPendingTransferMessage(
                        peerId: peerId, operationId: registration.id, randomId: randomId,
                        amount: displayAmount, address: resolved.address, comment: pendingComment,
                        commentEncrypted: encrypted, timestamp: createdAt
                    ) |> castError(WalletError.self)
                )
            }
            pendingMessage = try await creation.value
        } else {
            pendingMessage = nil
        }
        do {
            try Task.checkCancellation()
            try self.authorization.validate(session, boundTo: registration.sessionId, requireAvailable: false)
            guard self.isCurrentPendingTransferRegistration(registration) else { throw WalletError.unavailable }
        } catch {
            if let pendingMessage { self.removeRegisteredTransferMessage(pendingMessage) }
            throw error
        }
        let pending = PendingTransfer(
            id: registration.id, recipient: resolved.address, amount: displayAmount,
            comment: pendingComment, commentEncrypted: encrypted,
            expectedGasless: feesAreCovered,
            pendingMessage: pendingMessage, fee: estimatedFee,
            uiExpiresAt: walletPendingTransferUIExpirationTimestamp(from: self.transferSubmissionClock.now()),
            createdAt: createdAt, status: .broadcasting, isPreparing: true
        )
        self.pendingTransferRegistrations[registration.id] = WalletPendingTransferRegistrationRecord(
            registration: registration, session: session, peerId: peerId, randomId: randomId,
            requestedAmount: resolved.amount, sendAll: resolvedSendAll, comment: resolved.comment,
            pending: pending
        )
        self.publishRegisteredPendingTransfer(pending)
        let clock = self.transferSubmissionClock
        self.pendingTransferRegistrations[registration.id]?.renewalTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await clock.sleep(30_000_000_000) } catch { return }
                guard let self, await self.renewPendingTransferRegistration(registration) else { return }
            }
        }
        return registration
    }

    func isCurrentPendingTransferRegistration(_ registration: WalletContext.PendingTransferRegistration) -> Bool {
        guard !self.isShutdown, self.activationGeneration == registration.generation,
              case let .wallet(info) = self.currentState.phase else { return false }
        return info.address == registration.walletAddress && info.publicKey == registration.walletPublicKey
    }

    func validatePendingTransferRegistration(
        _ registration: WalletContext.PendingTransferRegistration, session: PasscodeSession?,
        address: String, amount: Int64, sendAll: Bool, comment: String?, commentEncrypted: Bool
    ) throws {
        guard let record = self.pendingTransferRegistrations[registration.id], record.registration == registration,
              self.isCurrentPendingTransferRegistration(registration), let session,
              record.pending.recipient == address, record.requestedAmount == amount,
              record.sendAll == sendAll, record.comment == comment,
              record.pending.commentEncrypted == (commentEncrypted && comment?.isEmpty == false) else {
            throw WalletError.preparedTransferNotFound
        }
        try self.authorization.validate(session, boundTo: registration.sessionId, requireAvailable: false)
    }

    func updateRegisteredPendingTransfer(_ registration: WalletContext.PendingTransferRegistration, prepared: PreparedTransfer, encryptedComment: String?) async throws {
        guard var record = self.pendingTransferRegistrations[registration.id], record.registration == registration,
              self.isCurrentPendingTransferRegistration(registration), prepared.id == registration.id else {
            throw WalletError.preparedTransferNotFound
        }
        let expiresAt = walletPendingTransferUIExpirationTimestamp(from: self.transferSubmissionClock.now())
        record.pending = PendingTransfer(
            id: prepared.id, recipient: prepared.recipient, amount: prepared.amount,
            comment: prepared.commentEncrypted ? encryptedComment : prepared.comment,
            commentEncrypted: prepared.commentEncrypted,
            expectedGasless: WalletContext.useWalletTransferApi
                && !WalletContext.isSelfTransfer(recipient: prepared.recipient, walletAddress: registration.walletAddress)
                && WalletContext.isGaslessEligible(amount: prepared.amount, gaslessInfo: self.currentState.gaslessInfo.currentValue, minimumAmount: self.transferGaslessMinAmount),
            pendingMessage: record.pending.pendingMessage, fee: prepared.fee,
            uiExpiresAt: expiresAt,
            createdAt: record.pending.createdAt, status: .broadcasting, isPreparing: true
        )
        self.pendingTransferRegistrations[registration.id] = record
        self.publishRegisteredPendingTransfer(record.pending)
        if let message = record.pending.pendingMessage {
            try await WalletSignalRequestContext<Void>().run(self.engine.wallet.updatePendingTransferMessage(
                message, amount: record.pending.amount, address: record.pending.recipient,
                comment: record.pending.comment, commentEncrypted: record.pending.commentEncrypted,
                expiresAt: expiresAt
            ) |> castError(WalletError.self))
        }
        try Task.checkCancellation()
        guard self.pendingTransferRegistrations[registration.id]?.registration == registration,
              self.isCurrentPendingTransferRegistration(registration) else { throw WalletError.unavailable }
    }

    private func renewPendingTransferRegistration(_ registration: WalletContext.PendingTransferRegistration) async -> Bool {
        guard var record = self.pendingTransferRegistrations[registration.id], record.registration == registration else { return false }
        guard self.isCurrentPendingTransferRegistration(registration),
              (try? self.authorization.validate(record.session, boundTo: registration.sessionId, requireAvailable: false)) != nil else {
            self.discardPendingTransferRegistration(registration)
            return false
        }
        let previous = record.pending
        record.pending = PendingTransfer(
            id: previous.id, recipient: previous.recipient, amount: previous.amount,
            comment: previous.comment, commentEncrypted: previous.commentEncrypted,
            expectedGasless: previous.expectedGasless, pendingMessage: previous.pendingMessage, fee: previous.fee,
            uiExpiresAt: walletPendingTransferUIExpirationTimestamp(from: self.transferSubmissionClock.now()),
            createdAt: previous.createdAt, status: .broadcasting, isPreparing: true
        )
        self.pendingTransferRegistrations[registration.id] = record
        self.publishRegisteredPendingTransfer(record.pending)
        self.refreshRegisteredTransferMessage(record.pending)
        return true
    }

    private func publishRegisteredPendingTransfer(_ pending: PendingTransfer) {
        self.replaceState(
            phase: self.currentState.phase, balance: self.currentState.balance, transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers.filter { $0.id != pending.id } + [pending],
            activeOperation: self.currentState.activeOperation
        )
    }

    func refreshRegisteredTransferMessage(_ pending: PendingTransfer) {
        guard let reference = pending.pendingMessage, let expiresAt = pending.uiExpiresAt else { return }
        let _ = self.engine.wallet.updatePendingTransferMessage(
            reference, amount: pending.amount, address: pending.recipient,
            comment: pending.comment, commentEncrypted: pending.commentEncrypted, expiresAt: expiresAt
        ).startStandalone()
    }

    func stopPendingTransferRegistration(_ id: String) {
        self.pendingTransferRegistrations.removeValue(forKey: id)?.renewalTask?.cancel()
    }

    func discardPendingTransferRegistration(_ registration: WalletContext.PendingTransferRegistration) {
        guard let record = self.pendingTransferRegistrations[registration.id], record.registration == registration else { return }
        self.stopPendingTransferRegistration(registration.id)
        if let message = record.pending.pendingMessage { self.removeRegisteredTransferMessage(message) }
        self.preparedTransfers[registration.id] = nil
        self.replaceState(
            phase: self.currentState.phase, balance: self.currentState.balance, transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers.filter { $0.id != registration.id || !$0.isPreparing },
            activeOperation: self.currentState.activeOperation
        )
    }

    func discardPendingTransferRegistrations() {
        for record in Array(self.pendingTransferRegistrations.values) {
            self.discardPendingTransferRegistration(record.registration)
        }
    }

    private func removeRegisteredTransferMessage(_ reference: WalletPendingTransferMessageReference) {
        let _ = self.engine.wallet.removePendingTransferMessage(reference).startStandalone()
    }
}
