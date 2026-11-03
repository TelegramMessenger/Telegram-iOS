import Foundation
import SwiftSignalKit
import TelegramCore
import WalletEngineFFI
#if canImport(TelegramUIPreferences)
import TelegramUIPreferences
#endif

@available(macOS 10.15, *)
private struct WalletLogoutWallet {
    let address: String
    let publicKey: String
    var balance: Int64? = nil
}

@available(macOS 10.15, *)
private func walletLogoutBackupEnabled(_ wallet: WalletLogoutWallet, state: TelegramCore.WalletState?) -> Bool? {
    guard let state else { return nil }
    switch state {
    case .empty:
        return false
    case let .ready(backupEnabled, _, _, address, publicKey, _):
        return backupEnabled
            && walletEngineAddressesEqual(wallet.address, address)
            && wallet.publicKey == publicKey.map { String(format: "%02x", $0) }.joined()
    }
}

@available(macOS 10.15, *)
public extension WalletContext {
    func logoutWarningBalance() -> Signal<Int64?, NoError> {
        return self.signal(name: "logout_warning_balance") { impl, _ in
            try await impl.logoutWarningBalance()
        }
        |> `catch` { _ -> Signal<Int64?, NoError> in
            return .single(0)
        }
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func logoutWarningBalance() async throws -> Int64? {
        var readFailed = false
        var currentWallet: WalletLogoutWallet?
        do {
            if let descriptor = try await self.storage.loadDescriptor(),
               let secretRef = descriptor.secretRef, !secretRef.isEmpty {
                let hasSecret: Bool
                do {
                    hasSecret = try await self.storage.containsProtectedSecret(ProtectedSecretRef(value: secretRef))
                } catch {
                    readFailed = true
                    hasSecret = true
                    self.logger.error("wallet_logout_secret_check_failed", error)
                }
                if hasSecret {
                    currentWallet = WalletLogoutWallet(
                        address: descriptor.address,
                        publicKey: descriptor.publicKey.map { String(format: "%02x", $0) }.joined()
                    )
                }
            }
        } catch {
            readFailed = true
            self.logger.error("wallet_logout_descriptor_read_failed", error)
            if case let .wallet(info) = self.currentState.phase, info.canSign {
                currentWallet = WalletLogoutWallet(address: info.address, publicKey: info.publicKey)
            }
        }

        var previousWallets: [WalletLogoutWallet] = []
        do {
            let records = try await self.storage.loadArchivedWallets()
            for record in records.sorted(by: { $0.archivedAt > $1.archivedAt }) {
                guard let secretRef = record.descriptor.secretRef, !secretRef.isEmpty else { continue }
                let hasSecret: Bool
                do {
                    hasSecret = try await self.storage.containsProtectedSecret(ProtectedSecretRef(value: secretRef))
                } catch {
                    readFailed = true
                    hasSecret = true
                    self.logger.error("wallet_logout_archived_secret_check_failed", error)
                }
                if hasSecret {
                    previousWallets.append(WalletLogoutWallet(
                        address: record.descriptor.address,
                        publicKey: record.descriptor.publicKey.map { String(format: "%02x", $0) }.joined(),
                        balance: record.balance
                    ))
                }
            }
        } catch {
            readFailed = true
            self.logger.error("wallet_logout_archived_wallets_read_failed", error)
        }
        try Task.checkCancellation()

        var wallets: [WalletLogoutWallet] = []
        if var wallet = currentWallet {
            var cachedState = self.storedState
            if !self.isStoredStateRestored {
                do {
                    cachedState = try await WalletSignalRequestContext<WalletStoredState?>().run(
                        self.engine.data.get(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(
                            key: ApplicationSpecificPreferencesKeys.walletState
                        ))
                        |> map { entry -> WalletStoredState? in
                            guard let state = entry?.get(WalletStoredState.self),
                                  state.schemaVersion == WalletStoredState.currentSchemaVersion else { return nil }
                            return state
                        }
                        |> castError(WalletContext.WalletError.self)
                    ) ?? cachedState
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    readFailed = true
                    self.logger.error("wallet_logout_cached_state_read_failed", error)
                }
            }
            if cachedState.walletAddress.map({ walletEngineAddressesEqual($0, wallet.address) }) == true {
                wallet.balance = cachedState.balance
            }
            if case let .wallet(info) = self.currentState.phase,
               walletEngineAddressesEqual(info.address, wallet.address),
               let balance = self.currentState.balance.currentValue {
                wallet.balance = balance
            }

            let knownServerState = self.deferredServerWalletState?.state
                ?? self.pendingInitialServerWalletState?.state
                ?? self.serverWalletState
            if wallet.balance == nil, case let .ready(_, _, _, address, _, balance)? = knownServerState,
               walletEngineAddressesEqual(address, wallet.address) {
                wallet.balance = balance
            }
            var backupEnabled = walletLogoutBackupEnabled(wallet, state: knownServerState)
            if backupEnabled == nil, case let .wallet(info) = self.currentState.phase,
               walletEngineAddressesEqual(info.address, wallet.address), info.publicKey == wallet.publicKey {
                backupEnabled = info.backupEnabled
            }
            if backupEnabled == nil {
                do {
                    let state = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                        self.engine.wallet.getState()
                        |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
                    )
                    backupEnabled = walletLogoutBackupEnabled(wallet, state: state)
                    if case let .ready(_, _, _, address, _, balance) = state,
                       walletEngineAddressesEqual(address, wallet.address) {
                        wallet.balance = balance
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    self.logger.error("wallet_logout_backup_status_failed", error)
                }
            }
            if wallet.balance == nil {
                wallet.balance = previousWallets.first(where: {
                    walletEngineAddressesEqual($0.address, wallet.address) && $0.balance != nil
                })?.balance
            }
            if backupEnabled != true {
                wallets.append(wallet)
            }
            previousWallets.removeAll { walletEngineAddressesEqual($0.address, wallet.address) }
        }
        wallets.append(contentsOf: previousWallets)
        try Task.checkCancellation()

        var uniqueWallets: [WalletLogoutWallet] = []
        for wallet in wallets {
            if let index = uniqueWallets.firstIndex(where: { walletEngineAddressesEqual($0.address, wallet.address) }) {
                if uniqueWallets[index].balance == nil {
                    uniqueWallets[index].balance = wallet.balance
                }
            } else {
                uniqueWallets.append(wallet)
            }
        }
        guard readFailed || !uniqueWallets.isEmpty else { return nil }
        return uniqueWallets.reduce(Int64(0)) { total, wallet in
            let (sum, overflow) = total.addingReportingOverflow(max(0, wallet.balance ?? 0))
            return overflow ? Int64.max : sum
        }
    }
}
