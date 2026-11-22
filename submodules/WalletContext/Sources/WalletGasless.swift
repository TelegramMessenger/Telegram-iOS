import Foundation
import SwiftSignalKit
import TelegramCore

@available(macOS 10.15, *)
public extension WalletContext {
    static func isGaslessEligible(amount: Int64, gaslessInfo: WalletGaslessInfo?, minimumAmount: Int64) -> Bool {
        guard let gaslessInfo else { return false }
        return gaslessInfo.available && gaslessInfo.left > 0
            && amount >= max(gaslessInfo.minAmount, minimumAmount)
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func requestGaslessInfoIfNeeded() {
        guard case .idle = self.currentState.gaslessInfo else { return }
        self.requestGaslessInfo()
    }

    func requestGaslessInfo() {
        guard WalletContext.useWalletTransferApi, self.canUseNetworkRuntime, case .wallet = self.currentState.phase,
              self.gaslessInfoTask == nil else { return }
        let taskId = UUID()
        let generation = self.activationGeneration
        let quotaRevision = self.gaslessQuotaRevision
        self.gaslessInfoTaskId = taskId
        self.replaceGaslessInfo(.loading(previous: self.currentState.gaslessInfo.currentValue))
        self.gaslessInfoTask = Task { [weak self] in
            await self?.fetchGaslessInfo(taskId: taskId, generation: generation, quotaRevision: quotaRevision)
        }
    }

    private func fetchGaslessInfo(taskId: UUID, generation: UInt64, quotaRevision: UInt64) async {
        defer {
            if self.gaslessInfoTaskId == taskId {
                self.gaslessInfoTask = nil
                self.gaslessInfoTaskId = nil
            }
        }
        do {
            let engine = self.engine
            let info = try await withThrowingTaskGroup(of: WalletGaslessInfo.self) { group in
                group.addTask {
                    try await WalletSignalRequestContext<WalletGaslessInfo>().run(engine.wallet.getGaslessInfo())
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: 15_000_000_000)
                    throw WalletError.network
                }
                defer { group.cancelAll() }
                guard let value = try await group.next() else { throw WalletError.network }
                return value
            }
            try Task.checkCancellation()
            guard self.activationGeneration == generation, self.gaslessInfoTaskId == taskId else {
                return
            }
            guard quotaRevision == self.gaslessQuotaRevision else { return }
            self.applyGaslessInfo(info)
        } catch is CancellationError {
        } catch {
            guard self.activationGeneration == generation, self.gaslessInfoTaskId == taskId else {
                return
            }
            guard quotaRevision == self.gaslessQuotaRevision else { return }
            self.logger.error("wallet_gasless_info_failed", error)
            self.replaceGaslessInfo(.stale(previous: self.currentState.gaslessInfo.currentValue, error: synchronizationError(error), lastSuccessfulAt: self.currentState.gaslessInfo.lastSuccessfulAt))
        }
    }

    func cancelGaslessInfoRequest() {
        self.gaslessInfoTask?.cancel()
        self.gaslessInfoTask = nil
        self.gaslessInfoTaskId = nil
        if case let .loading(previous) = self.currentState.gaslessInfo {
            self.replaceGaslessInfo(.stale(previous: previous, error: .network, lastSuccessfulAt: nil))
        }
    }

    func applyGaslessInfo(_ info: WalletGaslessInfo) {
        self.gaslessInfoTask?.cancel()
        self.gaslessInfoTask = nil
        self.gaslessInfoTaskId = nil
        self.gaslessQuotaRevision &+= 1
        self.replaceGaslessInfo(.value(info, updatedAt: currentWalletTimestamp()))
    }

    private func replaceGaslessInfo(_ value: Resource<WalletGaslessInfo>) {
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation,
            gaslessInfo: value
        )
    }

    func restorePendingTransfers(generation: UInt64) async {
        guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
        do {
            for pending in self.currentState.pendingTransfers {
                if let reference = pending.pendingMessage, let transfer = pending.sentTransfer {
                    let receivedAt = pending.uiExpiresAt.map {
                        Int32(clamping: Int64($0) - Int64(walletPendingTransferUILifetime))
                    } ?? pending.createdAt
                    try await WalletSignalRequestContext<Void>().run(
                        self.engine.wallet.acceptPendingTransferMessage(reference, transfer: transfer, receivedAt: receivedAt)
                        |> castError(WalletError.self)
                    )
                    guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
                }
                if let transaction = walletHistoryTransactionForPending(pending, transactions: self.currentState.transactions.items) {
                    if let transfer = pending.sentTransfer {
                        self.rememberWalletFinalTransaction(transaction, msgHash: transfer.msgHash)
                    }
                    await self.applyWalletFinalTransaction(transaction, pending: pending, generation: generation)
                    guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
                } else {
                    self.resolveStreamingPendingMessage(pending)
                }
            }
        } catch {
            self.logger.error("wallet_pending_transfers_restore_failed", error)
        }
        guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
        for transfer in self.currentState.pendingTransfers {
            self.trackWalletTransferResolution(transfer, receivedAt: transfer.status == .confirmed ? currentWalletTimestamp() : nil)
        }
    }
}
