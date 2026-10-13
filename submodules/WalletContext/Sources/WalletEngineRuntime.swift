import Foundation
import TelegramCore
import PasscodeCore
import WalletEngineFFI

@available(macOS 10.15, *)
func verifyWalletImportKey(
    anchorPublicKey: Data,
    signingPublicKey: Data,
    accountState: () async throws -> WalletContext.WalletAccountState,
    publicKey: () async throws -> Data
) async throws {
    guard anchorPublicKey.count == 32, signingPublicKey.count == 32 else {
        throw WalletContext.WalletError.publicKeyInvalid
    }
    do {
        try Task.checkCancellation()
        let currentKey: Data
        switch try await accountState() {
        case .active:
            currentKey = try await publicKey()
            guard currentKey.count == 32 else { throw WalletContext.WalletError.network }
        case .undeployed:
            currentKey = anchorPublicKey
        case .unavailable:
            throw WalletContext.WalletError.unavailable
        }
        try Task.checkCancellation()
        guard currentKey == signingPublicKey else { throw WalletContext.WalletError.recoveryPhraseOutdated }
    } catch is CancellationError {
        throw CancellationError()
    } catch let error as WalletContext.WalletError {
        throw error
    } catch {
        throw WalletContext.WalletError.network
    }
}

@available(macOS 10.15, *)
enum WalletImportCandidateDisposition: Equatable {
    case promote
    case discard
    case retain
}

@available(macOS 10.15, *)
func walletImportCandidateDisposition(
    sameAddress: Bool,
    sameSigningKey: Bool,
    hasPendingKeyRotation: Bool,
    discardMismatch: Bool,
    verify: () async throws -> Void,
    validateRevision: () throws -> Void
) async throws -> WalletImportCandidateDisposition {
    try validateRevision()
    guard !hasPendingKeyRotation else { return .retain }
    guard sameAddress else { return discardMismatch ? .discard : .retain }
    do {
        try await verify()
    } catch WalletContext.WalletError.recoveryPhraseOutdated {
        try validateRevision()
        return discardMismatch ? .discard : .retain
    }
    try validateRevision()
    return sameSigningKey ? .promote : .retain
}

@available(macOS 10.15, *)
struct WalletEngineActivation: @unchecked Sendable {
    let snapshot: WalletSnapshot
    let canSign: Bool
}

@available(macOS 10.15, *)
struct WalletEngineStagedWallet: Equatable, Sendable {
    let recordId: String
    let address: String
    let publicKey: Data
    let signingPublicKey: Data
    let isPersisted: Bool
}

@available(macOS 10.15, *)
struct WalletEngineSendExecution: @unchecked Sendable {
    let result: SendResult
    let didRecreateClient: Bool

    init(result: SendResult, didRecreateClient: Bool) {
        self.result = result
        self.didRecreateClient = didRecreateClient
    }
}

@available(macOS 10.15, *)
enum WalletEngineKeyRotationResolution: Equatable, Sendable {
    case none
    case pending(operationId: String, retryAfterMilliseconds: UInt64?)
    case confirmed(operationId: String)
    case rolledBack(operationId: String, phase: SendPhase)
}

@available(macOS 10.15, *)
private enum WalletEngineKeyRotationChainState: Equatable {
    case replacement
    case previous
    case different
}

@available(macOS 10.15, *)
actor WalletEngineRuntime {
    private enum FfiPriority {
        case background
        case userInitiated
    }

    private enum FfiCancellation: Equatable {
        case none
        case sendPreview
        case send
    }

    let storage: WalletEngineStorage
    private var lastKnownBalance: Int64?
    private let engine: TelegramEngine
    private let logger: WalletLogger
    private let platformHost: WalletEnginePlatformHost
    private var statuslessHost: WalletEngineStatuslessHost
    private let lifecycle: WalletLifecycle
    private var client: WalletClient?
    private var clientConfig: WalletClientConfig?
    private var clientRevision: UInt64 = 0
    private var descriptor: WalletDescriptor?
    private var serverWalletIdentity: (address: String, publicKey: Data)?
    private var serverStateRevision: UInt64 = 0
    private var requiresWalletKeyReconciliation = false
    private var transientReplacementDescriptor: WalletDescriptor?
    private var ffiBusy = false
    private var userInitiatedFfiWaiters: [CheckedContinuation<Void, Never>] = []
    private var backgroundFfiWaiters: [CheckedContinuation<Void, Never>] = []
    private var activeFfiOperation: (id: UUID, cancellation: FfiCancellation)?

    init(engine: TelegramEngine, storage: WalletEngineStorage, logger: WalletLogger) {
        self.storage = storage
        self.engine = engine
        self.logger = logger
        self.platformHost = WalletEnginePlatformHost(storage: storage, logger: logger)
        self.statuslessHost = WalletEngineStatuslessHost(engine: engine, logger: logger)
        self.lifecycle = WalletLifecycle(platformHost: self.platformHost)
    }

    func activate(
        serverAddress: String,
        serverPublicKey: Data,
        archivePreviousWallet: Bool = false,
        serverStateRevision: UInt64? = nil
    ) async throws -> WalletEngineActivation {
        let revision = serverStateRevision ?? self.serverStateRevision
        return try await self.withFfi {
            try await self.activateUnlocked(
                serverAddress: serverAddress,
                serverPublicKey: serverPublicKey,
                archivePreviousWallet: archivePreviousWallet,
                serverStateRevision: revision
            )
        }
    }

    func requireWalletKeyReconciliation(revision: UInt64) {
        guard revision > self.serverStateRevision else { return }
        self.requiresWalletKeyReconciliation = true
        self.invalidateServerWalletIdentity(revision: revision)
    }

    func updateServerWalletIdentity(address: String, publicKey: Data, revision: UInt64) {
        guard revision > self.serverStateRevision else { return }
        self.serverStateRevision = revision
        self.serverWalletIdentity = (address, publicKey)
    }

    func invalidateServerWalletIdentity(revision: UInt64) {
        guard revision > self.serverStateRevision else { return }
        self.serverStateRevision = revision
        self.serverWalletIdentity = nil
    }

    private func adoptServerWalletIdentity(address: String, publicKey: Data, revision: UInt64) throws {
        guard revision >= self.serverStateRevision else { throw CancellationError() }
        self.serverStateRevision = revision
        self.serverWalletIdentity = (address, publicKey)
    }

    func hasReplacementCandidate() async throws -> Bool {
        try await self.storage.loadReplacementCandidate() != nil
    }

    func isPersistedReplacementCandidate(recordId: String) async throws -> Bool {
        try await self.storage.loadReplacementCandidate()?.recordId == recordId
    }

    private func verifyImportKey(address: String, anchorPublicKey: Data, signingPublicKey: Data) async throws {
        try await verifyWalletImportKey(
            anchorPublicKey: anchorPublicKey,
            signingPublicKey: signingPublicKey,
            accountState: { try await self.statuslessHost.walletAccountState(address: address) },
            publicKey: { try await self.statuslessHost.walletPublicKey(address: address) }
        )
    }

    func verifyReplacement(recordId: String) async throws {
        try await self.withFfi {
            guard try await self.storage.loadKeyRotation() == nil else {
                throw WalletContext.WalletError.operationInProgress
            }
            let revision = self.serverStateRevision
            let record: WalletEngineDescriptorRecord
            if let descriptor = self.transientReplacementDescriptor, descriptor.recordId == recordId {
                record = WalletEngineDescriptorRecord(descriptor: descriptor)
            } else if let candidate = try await self.storage.loadReplacementCandidate(), candidate.recordId == recordId {
                record = candidate
            } else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            let signingPublicKey = try await self.signingPublicKey(for: record)
            do {
                try await self.verifyImportKey(address: record.address, anchorPublicKey: record.publicKey, signingPublicKey: signingPublicKey)
            } catch {
                guard self.serverStateRevision == revision else { throw CancellationError() }
                throw error
            }
            guard self.serverStateRevision == revision else { throw CancellationError() }
        }
    }

    func stageTransientReplacement(words: [String]) async throws -> WalletEngineStagedWallet {
        let recordId = UUID().uuidString.lowercased()
        do {
            return try await self.withFfi {
                guard try await self.storage.loadKeyRotation() == nil else {
                    throw WalletContext.WalletError.operationInProgress
                }
                if let candidate = try await self.storage.loadReplacementCandidate() {
                    guard let descriptor = candidate.descriptor else { throw WalletContext.WalletError.storage(.corrupted) }
                    let existing = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
                    guard normalizedEngineMnemonic(existing.phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init)) == normalizedEngineMnemonic(words) else {
                        throw WalletContext.WalletError.operationInProgress
                    }
                    return WalletEngineStagedWallet(
                        recordId: candidate.recordId, address: candidate.address, publicKey: candidate.publicKey,
                        signingPublicKey: try walletMnemonicSigningPublicKey(words: words), isPersisted: true
                    )
                }
                guard self.transientReplacementDescriptor == nil else {
                    throw WalletContext.WalletError.operationInProgress
                }
                let words = normalizedEngineMnemonic(words)
                guard detectMnemonicSchemes(words: words).contains(.rotation) else {
                    throw WalletContext.WalletError.invalidMnemonic
                }
                await self.platformHost.beginTransientProtectedSecretCapture()
                let imported: WalletDescriptor
                do {
                    imported = try await self.lifecycle.importWallet(request: ImportWalletRequest(
                        recordId: recordId,
                        network: .mainnet,
                        recoveryWords: words
                    ))
                } catch {
                    await self.platformHost.cancelTransientProtectedSecretCapture()
                    await self.platformHost.removeAllTransientProtectedSecrets()
                    throw error
                }
                await self.platformHost.cancelTransientProtectedSecretCapture()
                guard await self.platformHost.containsTransientProtectedSecret(secretRef: imported.secretRef) else {
                    throw WalletContext.WalletError.storage(.corrupted)
                }
                self.transientReplacementDescriptor = imported
                return WalletEngineStagedWallet(
                    recordId: imported.recordId,
                    address: imported.address,
                    publicKey: imported.publicKey,
                    signingPublicKey: try walletMnemonicSigningPublicKey(words: words),
                    isPersisted: false
                )
            }
        } catch {
            if self.transientReplacementDescriptor?.recordId == recordId {
                await self.discardTransientReplacementUnlocked(recordId: recordId)
            }
            throw error
        }
    }

    func stageVerifiedReplacement(words: [String]) async throws -> WalletEngineStagedWallet {
        let staged = try await self.stageTransientReplacement(words: words)
        do {
            try await self.verifyReplacement(recordId: staged.recordId)
            return staged
        } catch {
            let discardPersisted = error as? WalletContext.WalletError == .recoveryPhraseOutdated
            await Task {
                do { try await self.discardReplacement(recordId: staged.recordId, discardPersisted: discardPersisted) }
                catch { self.logger.error("wallet_replacement_cleanup_failed", error) }
            }.value
            throw error
        }
    }

    func retainReplacementForRetry(recordId: String) async throws {
        try await self.withFfi {
            guard let candidate = try await self.storage.loadReplacementCandidate(), candidate.recordId == recordId,
                  let descriptor = candidate.descriptor else { return }
            let secret = try await self.storage.readProtectedSecret(ProtectedSecretRead(
                secretRef: descriptor.secretRef, reason: .revealRecoveryPhrase, prompt: "Authenticate to import wallet"
            ))
            try await self.platformHost.retainTransientProtectedSecret(secretRef: descriptor.secretRef, bytes: secret)
            self.transientReplacementDescriptor = descriptor
            try await self.storage.discardReplacementCandidate(recordId: recordId)
        }
    }

    func signOwnershipProof(
        replacementRecordId: String? = nil,
        expectedAnchorPublicKey: Data,
        expectedSigningPublicKey: Data,
        domain: String,
        timestamp: UInt64,
        payload: String
    ) async throws -> Data {
        try await self.withFfi {
            let descriptor: WalletDescriptor?
            if let replacementRecordId {
                guard try await self.storage.loadKeyRotation() == nil else {
                    throw WalletContext.WalletError.operationInProgress
                }
                if let transient = self.transientReplacementDescriptor, transient.recordId == replacementRecordId {
                    descriptor = transient
                } else {
                    descriptor = try await self.storage.loadReplacementCandidate()?.descriptor
                }
                guard descriptor?.recordId == replacementRecordId else {
                    throw WalletContext.WalletError.storage(.identityMismatch)
                }
            } else {
                try await self.ensureKeyRotationAllowsSigning()
                descriptor = self.descriptor
            }
            guard expectedAnchorPublicKey.count == 32, expectedSigningPublicKey.count == 32, let descriptor,
                  descriptor.publicKey == expectedAnchorPublicKey else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            let proof = try await self.lifecycle.signTonConnectProof(request: TonConnectProofSignRequest(
                descriptor: descriptor,
                domain: domain,
                timestamp: timestamp,
                payload: payload
            ))
            guard proof.publicKey == expectedSigningPublicKey else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            guard proof.signature.count == 64 else {
                throw WalletContext.WalletError.proofInvalid
            }
            if replacementRecordId == nil {
                guard let serverIdentity = self.serverWalletIdentity,
                      walletEngineAddressesEqual(serverIdentity.address, descriptor.address),
                      serverIdentity.publicKey == expectedSigningPublicKey,
                      self.descriptor == descriptor else {
                    throw WalletContext.WalletError.storage(.identityMismatch)
                }
            }
            return proof.signature
        }
    }

    func persistReplacementCandidate(recordId: String) async throws {
        try await self.withFfi {
            if let candidate = try await self.storage.loadReplacementCandidate(), candidate.recordId == recordId { return }
            _ = try await self.materializeTransientReplacementUnlocked(recordId: recordId)
        }
    }

    func commitReplacement(
        recordId: String,
        serverAddress: String,
        serverPublicKey: Data,
        archivePreviousWallet: Bool = false,
        serverStateRevision: UInt64? = nil
    ) async throws -> WalletEngineActivation {
        let revision = serverStateRevision ?? self.serverStateRevision
        return try await self.withFfi {
            try self.adoptServerWalletIdentity(address: serverAddress, publicKey: serverPublicKey, revision: revision)
            if self.transientReplacementDescriptor?.recordId == recordId {
                _ = try await self.materializeTransientReplacementUnlocked(recordId: recordId)
            }
            guard let candidate = try await self.storage.loadReplacementCandidate(),
                  candidate.recordId == recordId,
                  walletEngineAddressesEqual(candidate.address, serverAddress),
                  candidate.descriptor != nil else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            let signingPublicKey = try await self.signingPublicKey(for: candidate)
            guard self.serverStateRevision == revision else { throw CancellationError() }
            guard signingPublicKey == serverPublicKey else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            do {
                try await self.verifyImportKey(address: candidate.address, anchorPublicKey: candidate.publicKey, signingPublicKey: signingPublicKey)
            } catch {
                guard self.serverStateRevision == revision else { throw CancellationError() }
                throw error
            }
            guard self.serverStateRevision == revision else { throw CancellationError() }
            try await self.promoteReplacementCandidate(candidate.withSigningPublicKey(signingPublicKey), archivePreviousWallet: archivePreviousWallet)
            let activation = try await self.activateUnlocked(
                serverAddress: serverAddress,
                serverPublicKey: serverPublicKey,
                archivePreviousWallet: false,
                serverStateRevision: revision
            )
            guard activation.canSign else { throw WalletContext.WalletError.storage(.identityMismatch) }
            return activation
        }
    }

    func reconcileReplacementCandidate(
        serverAddress: String,
        serverPublicKey: Data,
        discardMismatch: Bool,
        archivePreviousWallet: Bool = false,
        serverStateRevision: UInt64? = nil
    ) async throws -> Bool {
        let revision = serverStateRevision ?? self.serverStateRevision
        return try await self.withFfi {
            guard self.serverStateRevision <= revision else { throw CancellationError() }
            guard let candidate = try await self.storage.loadReplacementCandidate() else {
                return false
            }
            guard try await self.storage.loadKeyRotation() == nil else { return false }
            guard let descriptor = candidate.descriptor else {
                throw WalletContext.WalletError.storage(.corrupted)
            }
            // A crash during cleanup may leave only the marker. A Keychain
            // access failure throws; it must not be treated as a missing secret.
            let hasSecret = try await self.storage.containsProtectedSecret(descriptor.secretRef)
            guard self.serverStateRevision <= revision else { throw CancellationError() }
            if !hasSecret {
                try await self.storage.discardReplacementCandidate(recordId: candidate.recordId)
                return false
            }
            let signingPublicKey: Data
            if let known = candidate.signingPublicKey {
                signingPublicKey = known
            } else {
                signingPublicKey = try await self.signingPublicKey(for: candidate)
            }
            let disposition = try await walletImportCandidateDisposition(
                sameAddress: walletEngineAddressesEqual(candidate.address, serverAddress),
                sameSigningKey: signingPublicKey == serverPublicKey,
                hasPendingKeyRotation: false,
                discardMismatch: discardMismatch,
                verify: {
                    try await self.verifyImportKey(address: candidate.address, anchorPublicKey: candidate.publicKey, signingPublicKey: signingPublicKey)
                },
                validateRevision: {
                    guard self.serverStateRevision <= revision else { throw CancellationError() }
                }
            )
            switch disposition {
            case .promote:
                try await self.promoteReplacementCandidate(candidate.withSigningPublicKey(signingPublicKey), archivePreviousWallet: archivePreviousWallet)
                return true
            case .discard:
                try await self.storage.discardReplacementCandidate(recordId: candidate.recordId)
            case .retain:
                break
            }
            return false
        }
    }

    func discardReplacement(recordId: String, discardPersisted: Bool = true) async throws {
        try await self.withFfi {
            if self.transientReplacementDescriptor?.recordId == recordId {
                await self.discardTransientReplacementUnlocked(recordId: recordId)
            }
            guard discardPersisted else { return }
            guard let candidate = try await self.storage.loadReplacementCandidate(),
                  candidate.recordId == recordId else {
                return
            }
            try await self.storage.discardReplacementCandidate(recordId: candidate.recordId)
        }
    }

    func discardReplacementAfterAuthoritativeEmptyState(serverStateRevision: UInt64? = nil) async throws {
        let revision = serverStateRevision ?? self.serverStateRevision
        try await self.withFfi {
            guard try await self.storage.loadKeyRotation() == nil else { return }
            guard self.serverStateRevision <= revision else { throw CancellationError() }
            await self.discardTransientReplacementUnlocked()
            guard let candidate = try await self.storage.loadReplacementCandidate() else {
                return
            }
            try await self.storage.discardReplacementCandidate(recordId: candidate.recordId)
        }
    }

    private func activateUnlocked(
        serverAddress: String,
        serverPublicKey: Data,
        archivePreviousWallet: Bool,
        serverStateRevision: UInt64
    ) async throws -> WalletEngineActivation {
        guard serverPublicKey.count == 32 else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        try self.adoptServerWalletIdentity(address: serverAddress, publicKey: serverPublicKey, revision: serverStateRevision)
        try await self.shutdownClient()

        _ = try await self.reconcileKeyRotationUnlocked(
            serverAddress: serverAddress, serverPublicKey: serverPublicKey, backupEnabled: true
        )

        let stored = try await self.storage.loadDescriptor()
        var selectedRecord: WalletEngineDescriptorRecord?
        var canSign = false
        if let stored,
           stored.schemaVersion == 2,
           stored.network == "mainnet",
           walletEngineAddressesEqual(stored.address, serverAddress),
           stored.signingPublicKey == serverPublicKey {
            selectedRecord = stored
            if let secretRef = stored.secretRef,
               try await self.storage.containsProtectedSecret(ProtectedSecretRef(value: secretRef)) {
                let verifiedKey = try? await self.signingPublicKey(for: stored)
                if let verifiedKey {
                    guard verifiedKey == serverPublicKey else {
                        throw WalletContext.WalletError.storage(.identityMismatch)
                    }
                    selectedRecord = stored.withSigningPublicKey(verifiedKey)
                }
                canSign = true
            }
        }

        let record = selectedRecord ?? WalletEngineDescriptorRecord(
            recordId: UUID().uuidString.lowercased(),
            address: serverAddress,
            publicKey: serverPublicKey,
            secretRef: nil
        )
        guard let currentIdentity = self.serverWalletIdentity,
              self.serverStateRevision == serverStateRevision,
              walletEngineAddressesEqual(currentIdentity.address, serverAddress),
              currentIdentity.publicKey == serverPublicKey else {
            throw CancellationError()
        }
        let config = WalletClientConfig(
            recordId: record.recordId,
            address: record.address,
            publicKey: record.publicKey,
            localSecretRef: canSign ? record.secretRef.map(ProtectedSecretRef.init(value:)) : nil,
            network: .mainnet,
            sendValiditySeconds: 300,
            resolutionMarginSeconds: 60,
            providers: ProviderConfig(
                toncenterBaseUrl: "https://toncenter.com",
                dnsRootAddress: nil,
                requestTimeoutMs: 15_000
            )
        )
        let client = try self.makeClient(config: config)
        do {
            try await self.storage.saveDescriptor(record)
            if archivePreviousWallet, let stored,
               !walletEngineAddressesEqual(stored.address, serverAddress),
               stored.recordId != record.recordId,
               stored.secretRef != record.secretRef {
                try await self.archiveLocalWallet(stored)
            }
        } catch {
            try? await client.shutdown()
            throw error
        }
        self.client = client
        self.clientConfig = config
        self.clientRevision &+= 1
        self.descriptor = record.descriptor
        try await self.recoverKeyRotationAfterActivation(record: record, client: client)
        guard self.serverStateRevision == serverStateRevision else { throw CancellationError() }
        self.requiresWalletKeyReconciliation = false
        return WalletEngineActivation(
            snapshot: try client.snapshot(),
            canSign: canSign
        )
    }

    private func promoteReplacementCandidate(_ candidate: WalletEngineDescriptorRecord, archivePreviousWallet: Bool) async throws {
        let previous = try await self.storage.loadDescriptor()
        try await self.storage.saveDescriptor(candidate)
        try await self.storage.removeReplacementCandidate()
        if archivePreviousWallet, let previous,
           !walletEngineAddressesEqual(previous.address, candidate.address),
           previous.recordId != candidate.recordId,
           previous.secretRef != candidate.secretRef {
            try await self.archiveLocalWallet(previous)
        }
    }

    private func materializeTransientReplacementUnlocked(recordId: String) async throws -> WalletEngineDescriptorRecord {
        guard let descriptor = self.transientReplacementDescriptor,
              descriptor.recordId == recordId,
              let secret = try await self.platformHost.transientProtectedSecret(secretRef: descriptor.secretRef),
              !secret.isEmpty else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        guard let phrase = String(data: secret, encoding: .utf8) else {
            throw WalletContext.WalletError.invalidMnemonic
        }
        let signingPublicKey = try walletMnemonicSigningPublicKey(words: phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        let record = WalletEngineDescriptorRecord(descriptor: descriptor, signingPublicKey: signingPublicKey)
        try await self.storage.installReplacementCandidate(record, secret: secret)
        await self.platformHost.removeTransientProtectedSecret(secretRef: descriptor.secretRef)
        self.transientReplacementDescriptor = nil
        return record
    }

    private func discardTransientReplacementUnlocked(recordId: String? = nil) async {
        guard let descriptor = self.transientReplacementDescriptor,
              recordId == nil || descriptor.recordId == recordId else {
            return
        }
        await self.platformHost.removeTransientProtectedSecret(secretRef: descriptor.secretRef)
        self.transientReplacementDescriptor = nil
    }

    private func deleteLocalWallet(_ record: WalletEngineDescriptorRecord) async throws {
        if let secretRef = record.secretRef {
            try await self.storage.deleteProtectedSecret(ProtectedSecretRef(value: secretRef))
        }
    }

    func setLastKnownBalance(_ value: Int64?) {
        self.lastKnownBalance = value
    }

    private func archiveLocalWallet(_ record: WalletEngineDescriptorRecord) async throws {
        let balance = self.lastKnownBalance
        self.lastKnownBalance = nil
        do {
            try await self.storage.archiveWallet(record, balance: balance, archivedAt: currentWalletTimestamp())
        } catch {
            try await self.deleteLocalWallet(record)
        }
    }

    func archivedWallets() async throws -> [WalletContext.PreviousWallet] {
        try await self.storage.availableArchivedWallets().map {
            WalletContext.PreviousWallet(
                id: $0.descriptor.recordId,
                address: $0.descriptor.address,
                balance: $0.balance,
                lastUsedAt: $0.archivedAt
            )
        }
    }

    func refreshArchivedWalletBalances(_ wallets: [WalletContext.PreviousWallet]) async throws -> [WalletContext.PreviousWallet] {
        var balances: [String: Int64] = [:]
        for address in Set(wallets.map(\.address)) {
            try Task.checkCancellation()
            do {
                balances[address] = try await self.statuslessHost.walletBalance(address: address)
            } catch {
                try Task.checkCancellation()
                self.logger.error("wallet_archived_balance_refresh_failed", error)
            }
        }
        try Task.checkCancellation()
        try await self.storage.updateArchivedWalletBalances(balances)
        return try await self.archivedWallets()
    }

    func forgetArchivedWallet(recordId: String) async throws {
        try await self.storage.removeArchivedWallet(recordId: recordId)
    }

    func removeArchivedWallets() async throws {
        try await self.storage.removeArchivedWallets()
    }

    func revealArchivedRecoveryPhrase(recordId: String) async throws -> [String] {
        try await self.withFfi {
            guard let record = try await self.storage.loadArchivedWallets()
                .first(where: { $0.descriptor.recordId == recordId }),
                  let descriptor = record.descriptor.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            let phrase = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
            return phrase.phrase.split(separator: " ").map(String.init)
        }
    }

    private func signingPublicKey(for record: WalletEngineDescriptorRecord) async throws -> Data {
        guard let descriptor = record.descriptor else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        let phrase = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
        var words = normalizedEngineMnemonic(phrase.phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        defer { words.removeAll(keepingCapacity: false) }
        guard try rotationMnemonicPublicKey(phrase: words.joined(separator: " ")) == record.publicKey else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        return try walletMnemonicSigningPublicKey(words: words)
    }

    func resolvePending() async throws -> SendSnapshot {
        try await self.withFfi(priority: .background) {
            try await self.requireClient().resolvePending()
        }
    }

    func snapshot() async throws -> WalletSnapshot {
        try await self.withFfi { try self.requireClient().snapshot() }
    }

    func waitForChange(afterRevision: UInt64) async throws -> WalletSnapshot {
        try await self.requireClient().waitForChange(afterRevision: afterRevision)
    }

    func currentClientRevision() -> UInt64 {
        self.clientRevision
    }

    func resolveDns(_ name: String) async throws -> String? {
        try await self.withFfi(priority: .userInitiated) {
            try await self.requireClient().resolveDns(name: name)
        }
    }

    func previewSend(intent: SendIntent) async throws -> SendPreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            try await self.requireClient().previewSend(request: SendPreviewRequest(intent: intent))
        }
    }

    func createEncryptedComment(recipient: String, comment: String, recipientPublicKey: Data? = nil) async throws -> String {
        try await self.withFfi(priority: .userInitiated) {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().createEncryptedComment(request: CreateEncryptedCommentRequest(
                recipient: recipient,
                comment: comment,
                recipientPublicKey: recipientPublicKey
            ))
        }
    }

    func resolveEncryptedCommentRecipient(recipient: String, recipientPublicKey: Data?) async throws -> Data {
        try await self.withFfi(priority: .userInitiated) {
            try await self.requireClient().resolveEncryptedCommentRecipient(request: EncryptedCommentRecipientRequest(
                recipient: recipient, recipientPublicKey: recipientPublicKey
            ))
        }
    }

    func decryptComment(sender: String, body: String) async throws -> String {
        try await self.withFfi(priority: .userInitiated) {
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().decryptComment(request: DecryptCommentRequest(
                sender: sender,
                body: body
            ))
        }
    }

    func prepareTransfer(operationId: String, intent: SendIntent) async throws -> (recordId: String, data: WalletEngineFFI.PreparedTransfer) {
        try await self.withFfi(priority: .userInitiated) {
            try await self.ensureApiTransferAllowsSigning()
            try await self.ensureKeyRotationAllowsSigning()
            guard let config = self.clientConfig else {
                throw WalletContext.WalletError.unavailable
            }
            let data = try await self.requireClient().prepareTransfer(request: PrepareTransferRequest(
                operationId: operationId,
                intent: intent
            ))
            return (config.recordId, data)
        }
    }

    func send(operationId: String, intent: SendIntent) async throws -> WalletEngineSendExecution {
        try await self.withFfi(priority: .userInitiated, cancellation: .send) {
            try await self.ensureApiTransferAllowsSigning()
            try await self.ensureKeyRotationAllowsSigning()
            let request = SendRequest(operationId: operationId, force: false, intent: intent)
            return try await self.sendRecoveringStuckClient { client in
                try await client.send(request: request)
            }
        }
    }

    func previewNft(operationId: String, intent: NftTransferIntent) async throws -> SendPreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            try await self.requireClient().previewNftTransfer(request: NftTransferPreviewRequest(
                operationId: operationId,
                intent: intent
            ))
        }
    }

    func sendNft(operationId: String, intent: NftTransferIntent) async throws -> WalletEngineSendExecution {
        try await self.withFfi(priority: .userInitiated, cancellation: .send) {
            try await self.ensureApiTransferAllowsSigning()
            try await self.ensureKeyRotationAllowsSigning()
            let request = NftTransferRequest(
                operationId: operationId,
                force: false,
                intent: intent
            )
            return try await self.sendRecoveringStuckClient { client in
                try await client.sendNftTransfer(request: request)
            }
        }
    }

    func revealRecoveryPhrase() async throws -> [String] {
        try await self.withFfi {
            try await self.ensureCurrentWalletIdentity()
            guard let descriptor = self.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            let phrase = try await self.lifecycle.revealRecoveryPhrase(descriptor: descriptor)
            return phrase.phrase.split(separator: " ").map(String.init)
        }
    }

    func prepareKeyRotation(validUntil: UInt64) async throws -> PreparedKeyRotation {
        try await self.withFfi {
            try await self.ensureApiTransferAllowsSigning()
            try await self.ensureKeyRotationAllowsSigning()
            return try await self.requireClient().prepareKeyRotation(request: PrepareKeyRotationRequest(
                validUntil: validUntil,
                messageKind: .external
            ))
        }
    }

    func previewKeyRotation(
        operationId: String,
        signedBoc: String,
        seqno: UInt32,
        validUntil: UInt64
    ) async throws -> SendPreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            guard validUntil > UInt64(max(0, currentWalletTimestamp())) else {
                throw WalletContext.WalletError.preparedBackupDisableExpired
            }
            do {
                return try await self.requireClient().previewSendBoc(request: SendBocRequest(
                    operationId: operationId,
                    force: false,
                    signedBoc: signedBoc,
                    seqno: seqno,
                    validUntil: validUntil
                ))
            } catch {
                if walletKeyRotationPreparationIsExpired(error, seqno: seqno) {
                    throw WalletContext.WalletError.preparedBackupDisableExpired
                }
                throw error
            }
        }
    }

    func keyRotationRecord() async throws -> WalletEngineKeyRotationRecord? {
        try await self.storage.loadKeyRotation()
    }

    @discardableResult
    func reconcileKeyRotation(serverAddress: String, serverPublicKey: Data, backupEnabled: Bool, serverStateRevision: UInt64? = nil) async throws -> WalletEngineKeyRotationResolution {
        let revision = serverStateRevision ?? self.serverStateRevision
        return try await self.withFfi {
            try self.adoptServerWalletIdentity(address: serverAddress, publicKey: serverPublicKey, revision: revision)
            let result = try await self.reconcileKeyRotationUnlocked(
                serverAddress: serverAddress, serverPublicKey: serverPublicKey, backupEnabled: backupEnabled
            )
            guard self.serverStateRevision == revision else { throw CancellationError() }
            return result
        }
    }

    private func reconcileKeyRotationUnlocked(serverAddress: String, serverPublicKey: Data, backupEnabled: Bool) async throws -> WalletEngineKeyRotationResolution {
        guard let record = try await self.storage.loadKeyRotation(),
              walletEngineAddressesEqual(record.walletAddress, serverAddress),
              record.newPublicKey == serverPublicKey,
              record.phase == .submissionStarted || record.phase == .chainApplied || record.phase == .backupDisabled else {
            return .none
        }
        _ = try await self.storage.markKeyRotationChainApplied(
            operationId: record.operationId, verifiedPublicKey: serverPublicKey
        )
        if !backupEnabled {
            try await self.storage.completeKeyRotation(operationId: record.operationId)
        }
        return .confirmed(operationId: record.operationId)
    }

    func signBackupDisableProof(
        expectedAddress: String,
        expectedPublicKey: Data,
        rotationOperationId: String?,
        domain: String,
        timestamp: UInt64,
        payload: String
    ) async throws -> Data {
        try await self.withFfi {
            guard let descriptor = self.descriptor,
                  walletEngineAddressesEqual(descriptor.address, expectedAddress),
                  expectedPublicKey.count == 32 else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            let allowedServerPublicKeys: [Data]
            if let rotationOperationId {
                guard let rotation = try await self.storage.loadKeyRotation(),
                      rotation.operationId == rotationOperationId,
                      rotation.recordId == descriptor.recordId,
                      walletEngineAddressesEqual(rotation.walletAddress, expectedAddress),
                      rotation.walletPublicKey == descriptor.publicKey,
                      rotation.activeSecretRef == descriptor.secretRef.value,
                      rotation.newPublicKey == expectedPublicKey,
                      rotation.phase == .chainApplied || rotation.phase == .backupDisabled else {
                    throw WalletContext.WalletError.storage(.identityMismatch)
                }
                // markKeyRotationChainApplied has already promoted the new
                // mnemonic to descriptor.secretRef, so the engine signs with it.
                // The chain may already use the new signing key while the server
                // still reports the previous one until disableBackup completes.
                allowedServerPublicKeys = [rotation.previousPublicKey, rotation.newPublicKey]
            } else {
                try await self.ensureKeyRotationAllowsSigning()
                allowedServerPublicKeys = [expectedPublicKey]
            }
            func validateIdentity() throws {
                guard let serverIdentity = self.serverWalletIdentity,
                      walletEngineAddressesEqual(serverIdentity.address, expectedAddress),
                      allowedServerPublicKeys.contains(serverIdentity.publicKey),
                      self.descriptor == descriptor else {
                    throw WalletContext.WalletError.storage(.identityMismatch)
                }
            }
            try validateIdentity()
            try Task.checkCancellation()
            let proof = try await self.lifecycle.signTonConnectProof(request: TonConnectProofSignRequest(
                descriptor: descriptor, domain: domain, timestamp: timestamp, payload: payload
            ))
            try validateIdentity()
            guard proof.publicKey == expectedPublicKey else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            guard proof.signature.count == 64 else {
                throw WalletContext.WalletError.proofInvalid
            }
            return proof.signature
        }
    }

    func keyRotationRecoveryPhrase(operationId: String) async throws -> [String] {
        let secret = try await self.storage.keyRotationCandidateSecret(operationId: operationId)
        guard let phrase = String(data: secret, encoding: .utf8) else {
            throw WalletContext.WalletError.storage(.corrupted)
        }
        let words = normalizedEngineMnemonic(phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init))
        guard words.count == 24, detectMnemonicSchemes(words: words).contains(.rotation) else {
            throw WalletContext.WalletError.invalidMnemonic
        }
        return words
    }

    func sendKeyRotation(
        operationId: String,
        words: [String],
        previousPublicKey: Data,
        newPublicKey: Data,
        signedBoc: String,
        seqno: UInt32,
        validUntil: UInt64
    ) async throws -> SendResult {
        try await self.withFfi {
            try await self.ensureApiTransferAllowsSigning()
            try await self.ensureKeyRotationAllowsSigning()
            guard let descriptor = try await self.storage.loadDescriptor(),
                  descriptor.recordId == self.descriptor?.recordId,
                  descriptor.address == self.descriptor?.address,
                  descriptor.publicKey == self.descriptor?.publicKey,
                  descriptor.secretRef == self.descriptor?.secretRef.value else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            let normalizedWords = normalizedEngineMnemonic(words)
            guard normalizedWords.count == 24,
                  detectMnemonicSchemes(words: normalizedWords).contains(.rotation),
                  newPublicKey.count == 32,
                  try walletMnemonicSigningPublicKey(words: normalizedWords) == newPublicKey,
                  !signedBoc.isEmpty else {
                throw WalletContext.WalletError.invalidMnemonic
            }
            guard let replacementSecret = normalizedWords.joined(separator: " ").data(using: .utf8) else {
                throw WalletContext.WalletError.invalidMnemonic
            }
            let client = try self.requireClient()
            try await self.ensureKeyRotationAllowsSigning()
            guard previousPublicKey.count == 32,
                  let signingIdentity = self.serverWalletIdentity,
                  walletEngineAddressesEqual(signingIdentity.address, descriptor.address),
                  signingIdentity.publicKey == previousPublicKey else {
                throw WalletContext.WalletError.storage(.identityMismatch)
            }
            guard validUntil > UInt64(max(0, currentWalletTimestamp())) else {
                throw WalletContext.WalletError.preparedBackupDisableExpired
            }
            let record = try await self.storage.installKeyRotationCandidate(
                operationId: operationId,
                descriptor: descriptor,
                previousPublicKey: previousPublicKey,
                newPublicKey: newPublicKey,
                validUntil: validUntil,
                candidateSecret: replacementSecret
            )
            guard record.phase == .candidateStored else {
                throw WalletContext.WalletError.unavailable
            }
            _ = try await self.storage.markKeyRotationSubmissionStarted(operationId: operationId)
            do {
                guard let currentIdentity = self.serverWalletIdentity,
                      walletEngineAddressesEqual(currentIdentity.address, signingIdentity.address),
                      currentIdentity.publicKey == signingIdentity.publicKey else {
                    throw WalletContext.WalletError.storage(.identityMismatch)
                }
                let result = try await client.sendBoc(request: SendBocRequest(
                    operationId: operationId,
                    force: false,
                    signedBoc: signedBoc,
                    seqno: seqno,
                    validUntil: validUntil
                ))
                _ = try await self.reconcileKeyRotation(
                    operationId: result.operationId,
                    phase: result.phase,
                    retryAfterMilliseconds: nil
                )
                return result
            } catch {
                let snapshot: WalletSnapshot?
                do {
                    snapshot = try client.snapshot()
                } catch {
                    self.logger.error("wallet_key_rotation_snapshot_failed", error)
                    snapshot = nil
                }
                if let snapshot {
                    do {
                        _ = try await self.reconcileKeyRotation(send: snapshot.send)
                    } catch {
                        self.logger.error("wallet_key_rotation_reconciliation_failed", error)
                    }
                }
                throw error
            }
        }
    }

    func resolveKeyRotation() async throws -> WalletEngineKeyRotationResolution {
        try await self.withFfi {
            guard let record = try await self.storage.loadKeyRotation() else {
                return .none
            }
            if record.phase == .candidateStored {
                try await self.storage.discardUnsubmittedKeyRotation(operationId: record.operationId)
                return .rolledBack(operationId: record.operationId, phase: .cancelled)
            }
            if record.phase == .previousRestored {
                try await self.storage.cleanupRestoredKeyRotation(operationId: record.operationId)
                return .rolledBack(operationId: record.operationId, phase: .cancelled)
            }
            if record.phase == .chainApplied || record.phase == .backupDisabled {
                return try await self.resolveAppliedKeyRotation(record)
            }
            do {
                let send = try await self.requireClient().resolvePending()
                return try await self.reconcileKeyRotation(send: send)
            } catch {
                let snapshot: WalletSnapshot?
                do {
                    snapshot = try self.requireClient().snapshot()
                } catch {
                    self.logger.error("wallet_key_rotation_snapshot_failed", error)
                    snapshot = nil
                }
                if let snapshot, snapshot.send.operationId == record.operationId {
                    return try await self.reconcileKeyRotation(send: snapshot.send)
                }
                throw error
            }
        }
    }

    func reconcileKeyRotation(send: SendSnapshot) async throws -> WalletEngineKeyRotationResolution {
        try await self.reconcileKeyRotation(
            operationId: send.operationId,
            phase: send.phase,
            retryAfterMilliseconds: send.resolution?.retryAfterHintMs
        )
    }

    private func reconcileKeyRotation(
        operationId: String?,
        phase: SendPhase,
        retryAfterMilliseconds: UInt64?
    ) async throws -> WalletEngineKeyRotationResolution {
        guard let record = try await self.storage.loadKeyRotation() else {
            return .none
        }
        if record.phase == .previousRestored {
            try await self.storage.cleanupRestoredKeyRotation(operationId: record.operationId)
            return .rolledBack(operationId: record.operationId, phase: .cancelled)
        }
        if record.phase == .chainApplied || record.phase == .backupDisabled {
            return try await self.resolveAppliedKeyRotation(record)
        }
        guard operationId == record.operationId else {
            if phase == .idle {
                return try await self.resolveTerminalKeyRotation(record, phase: .cancelled)
            }
            return .pending(operationId: record.operationId, retryAfterMilliseconds: nil)
        }
        switch phase {
        case .confirmed:
            return try await self.resolveAppliedKeyRotation(record)
        case .replaced, .sequenceNumberConsumed, .expired, .superseded, .failed, .cancelled:
            return try await self.resolveTerminalKeyRotation(record, phase: phase)
        case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
             .submitting, .submissionUnknown, .submitted, .handedOff:
            return .pending(
                operationId: record.operationId,
                retryAfterMilliseconds: retryAfterMilliseconds
            )
        }
    }

    private func resolveAppliedKeyRotation(
        _ record: WalletEngineKeyRotationRecord
    ) async throws -> WalletEngineKeyRotationResolution {
        switch try await self.keyRotationChainState(record) {
        case .replacement:
            _ = try await self.storage.markKeyRotationChainApplied(
                operationId: record.operationId,
                verifiedPublicKey: record.newPublicKey
            )
            return .confirmed(operationId: record.operationId)
        case .previous:
            let expired = self.keyRotationValidityHasElapsed(record)
            try await self.storage.restorePreviousKeyRotationSecret(
                operationId: record.operationId,
                verifiedPublicKey: record.previousPublicKey,
                removeRecord: expired
            )
            if expired {
                return .rolledBack(operationId: record.operationId, phase: .expired)
            }
            return .pending(operationId: record.operationId, retryAfterMilliseconds: 1_000)
        case .different, nil:
            return .pending(operationId: record.operationId, retryAfterMilliseconds: 1_000)
        }
    }

    private func resolveTerminalKeyRotation(
        _ record: WalletEngineKeyRotationRecord,
        phase: SendPhase
    ) async throws -> WalletEngineKeyRotationResolution {
        switch try await self.keyRotationChainState(record) {
        case .replacement:
            _ = try await self.storage.markKeyRotationChainApplied(
                operationId: record.operationId,
                verifiedPublicKey: record.newPublicKey
            )
            return .confirmed(operationId: record.operationId)
        case .previous:
            try await self.storage.restorePreviousKeyRotationSecret(
                operationId: record.operationId,
                verifiedPublicKey: record.previousPublicKey,
                removeRecord: true
            )
            return .rolledBack(operationId: record.operationId, phase: phase)
        case .different, nil:
            return .pending(operationId: record.operationId, retryAfterMilliseconds: 1_000)
        }
    }

    private func keyRotationChainState(
        _ record: WalletEngineKeyRotationRecord
    ) async throws -> WalletEngineKeyRotationChainState? {
        if let serverIdentity = self.serverWalletIdentity,
           walletEngineAddressesEqual(serverIdentity.address, record.walletAddress) {
            if serverIdentity.publicKey == record.newPublicKey {
                return .replacement
            }
            if serverIdentity.publicKey != record.previousPublicKey {
                return .different
            }
        }
        do {
            let publicKey = try await self.statuslessHost.walletPublicKey(address: record.walletAddress)
            guard let latestIdentity = self.serverWalletIdentity,
                  walletEngineAddressesEqual(latestIdentity.address, record.walletAddress) else {
                return .different
            }
            if latestIdentity.publicKey == record.newPublicKey {
                return .replacement
            }
            if latestIdentity.publicKey != record.previousPublicKey {
                return .different
            }
            if publicKey == record.newPublicKey {
                return .replacement
            }
            if publicKey == record.previousPublicKey {
                return .previous
            }
            self.logger.log("event=wallet_key_rotation_public_key_mismatch")
            return .different
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            self.logger.error("wallet_key_rotation_public_key_check_failed", error)
            return nil
        }
    }

    private func keyRotationValidityHasElapsed(_ record: WalletEngineKeyRotationRecord) -> Bool {
        let (deadline, overflow) = record.validUntil.addingReportingOverflow(120)
        guard !overflow else {
            return false
        }
        return UInt64(max(0, Date().timeIntervalSince1970.rounded(.down))) > deadline
    }

    func completeKeyRotationAfterBackupDisabled(operationId: String) async throws {
        try await self.withFfi {
            guard let record = try await self.storage.loadKeyRotation() else {
                return
            }
            guard record.operationId == operationId,
                  (record.phase == .chainApplied || record.phase == .backupDisabled) else {
                throw WalletContext.WalletError.storage(.corrupted)
            }
            let serverConfirmed = self.serverWalletIdentity.map {
                walletEngineAddressesEqual($0.address, record.walletAddress) && $0.publicKey == record.newPublicKey
            } ?? false
            if !serverConfirmed {
                guard try await self.keyRotationChainState(record) == .replacement else {
                    throw WalletContext.WalletError.operationInProgress
                }
            }
            _ = try await self.storage.markKeyRotationChainApplied(
                operationId: record.operationId,
                verifiedPublicKey: record.newPublicKey
            )
            try await self.storage.completeKeyRotation(operationId: operationId)
        }
    }

    func tonConnectIdentity() async throws -> TonConnectWalletIdentity {
        try await self.withFfi {
            try self.currentTonConnectIdentity()
        }
    }

    private func currentTonConnectIdentity() throws -> TonConnectWalletIdentity {
        guard let descriptor = self.descriptor, let serverIdentity = self.serverWalletIdentity,
              serverIdentity.publicKey.count == 32,
              walletEngineAddressesEqual(descriptor.address, serverIdentity.address) else {
            throw TonConnectFailure.keyMismatch
        }
        let account = try self.lifecycle.tonConnectAccount(descriptor: descriptor)
        return TonConnectWalletIdentity(recordId: descriptor.recordId, address: account.address, network: account.network, publicKey: serverIdentity.publicKey)
    }

    private func validateTonConnectWallet(_ wallet: TonConnectWalletIdentity) throws {
        guard try self.currentTonConnectIdentity() == wallet else { throw TonConnectFailure.keyMismatch }
    }

    func tonConnectAccount(wallet: TonConnectWalletIdentity) async throws -> TonConnectAccountInfo {
        try await self.withFfi {
            try self.validateTonConnectWallet(wallet)
            guard let descriptor = self.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            let account = try self.lifecycle.tonConnectAccount(descriptor: descriptor)
            return TonConnectAccountInfo(
                address: account.address,
                network: account.network,
                walletStateInit: account.walletStateInit,
                publicKey: wallet.publicKey
            )
        }
    }

    func signTonConnectProof(
        wallet: TonConnectWalletIdentity,
        manifestUrl: String,
        timestamp: UInt64,
        payload: String,
        beforeSigning: @escaping @Sendable () throws -> Void = {}
    ) async throws -> TonConnectProofReply {
        let domain = try TonConnectWireCodec.proofDomain(manifestUrl: manifestUrl)
        return try await self.withFfi(beforeSigning: beforeSigning) {
            try self.validateTonConnectWallet(wallet)
            try await self.ensureKeyRotationAllowsSigning()
            guard let descriptor = self.descriptor else {
                throw WalletContext.WalletError.unavailable
            }
            try beforeSigning()
            let proof = try await self.lifecycle.signTonConnectProof(request: TonConnectProofSignRequest(
                descriptor: descriptor,
                domain: domain,
                timestamp: timestamp,
                payload: payload
            ))
            try self.validateTonConnectWallet(wallet)
            guard proof.publicKey == wallet.publicKey else { throw TonConnectFailure.keyMismatch }
            return TonConnectProofReply(timestamp: timestamp, domain: domain, payload: payload, signature: proof.signature)
        }
    }

    func previewTonConnect(_ request: SendRequest, wallet: TonConnectWalletIdentity) async throws -> SendPreview {
        try await self.withFfi(priority: .userInitiated, cancellation: .sendPreview) {
            try self.validateTonConnectWallet(wallet)
            return try await self.requireClient().previewTonConnect(request: request)
        }
    }

    func sendTonConnect(_ request: SendRequest, wallet: TonConnectWalletIdentity, beforeSigning: @escaping @Sendable () throws -> Void = {}) async throws -> SendResult {
        try await self.withFfi(priority: .userInitiated, cancellation: .send, beforeSigning: beforeSigning) {
            try await self.ensureApiTransferAllowsSigning()
            try self.validateTonConnectWallet(wallet)
            try await self.ensureKeyRotationAllowsSigning()
            let client = try self.requireClient()
            try beforeSigning()
            return try await client.send(request: request)
        }
    }

    func shutdown() async {
        do {
            try await self.withFfi {
                await self.discardTransientReplacementUnlocked()
                await self.platformHost.removeAllTransientProtectedSecrets()
                try await self.shutdownClient()
            }
        } catch {
            self.logger.error("wallet_engine_shutdown_failed", error)
        }
    }

    private func recoverKeyRotationAfterActivation(
        record descriptor: WalletEngineDescriptorRecord,
        client: WalletClient
    ) async throws {
        guard let rotation = try await self.storage.loadKeyRotation() else {
            return
        }
        guard rotation.recordId == descriptor.recordId,
              walletEngineAddressesEqual(rotation.walletAddress, descriptor.address),
              rotation.walletPublicKey == descriptor.publicKey,
              rotation.activeSecretRef == descriptor.secretRef else {
            if rotation.recordId == descriptor.recordId || rotation.activeSecretRef == descriptor.secretRef {
                throw WalletContext.WalletError.storage(.corrupted)
            }
            try await self.storage.discardOrphanedKeyRotation(
                operationId: rotation.operationId,
                activeSecretRef: descriptor.secretRef
            )
            return
        }
        if let serverIdentity = self.serverWalletIdentity,
           walletEngineAddressesEqual(serverIdentity.address, rotation.walletAddress),
           serverIdentity.publicKey == rotation.newPublicKey,
           rotation.phase == .submissionStarted || rotation.phase == .chainApplied || rotation.phase == .backupDisabled {
            _ = try await self.storage.markKeyRotationChainApplied(
                operationId: rotation.operationId, verifiedPublicKey: rotation.newPublicKey
            )
            return
        }
        switch rotation.phase {
        case .candidateStored:
            try await self.storage.discardUnsubmittedKeyRotation(operationId: rotation.operationId)
        case .submissionStarted:
            do {
                let send = try await client.resolvePending()
                _ = try await self.reconcileKeyRotation(send: send)
            } catch {
                self.logger.error("wallet_key_rotation_recovery_failed", error)
            }
        case .chainApplied, .backupDisabled:
            _ = try await self.resolveAppliedKeyRotation(rotation)
        case .previousRestored:
            try await self.storage.cleanupRestoredKeyRotation(operationId: rotation.operationId)
        }
    }

    private func shutdownClient() async throws {
        if let client = self.client {
            self.client = nil
            self.clientConfig = nil
            try await client.shutdown()
        }
    }

    private func makeClient(
        config: WalletClientConfig,
        statuslessHost: WalletEngineStatuslessHost? = nil
    ) throws -> WalletClient {
        try WalletClient.newStatusless(
            config: config,
            statuslessHost: statuslessHost ?? self.statuslessHost,
            platformHost: self.platformHost
        )
    }

    private func sendRecoveringStuckClient(
        _ operation: (WalletClient) async throws -> SendResult
    ) async throws -> WalletEngineSendExecution {
        let client = try self.requireClient()
        do {
            return WalletEngineSendExecution(
                result: try await operation(client),
                didRecreateClient: false
            )
        } catch {
            guard walletEngineIsSendAlreadyInProgress(error) else {
                throw error
            }
            guard self.client === client, let config = self.clientConfig else {
                throw error
            }

            self.logger.error("wallet_engine_stuck_send_recovery_started", error)
            try await client.shutdown()
            self.client = nil
            let replacementStatuslessHost = WalletEngineStatuslessHost(
                engine: self.engine,
                logger: self.logger
            )
            let replacement: WalletClient
            do {
                replacement = try self.makeClient(
                    config: config,
                    statuslessHost: replacementStatuslessHost
                )
            } catch {
                self.clientConfig = nil
                throw error
            }
            self.statuslessHost = replacementStatuslessHost
            self.client = replacement
            self.clientRevision &+= 1
            return WalletEngineSendExecution(
                result: try await operation(replacement),
                didRecreateClient: true
            )
        }
    }

    func ensureApiTransferAllowsSigning() async throws {
        guard !self.requiresWalletKeyReconciliation else { throw WalletContext.WalletError.walletKeyMismatch }
        guard let descriptor = self.descriptor else { throw WalletContext.WalletError.unavailable }
        if let record = try await self.storage.loadTransferSubmissions().first(where: {
            $0.recordId == descriptor.recordId || walletEngineAddressesEqual($0.walletAddress, descriptor.address)
        }),
           record.resolution == .pending {
            throw WalletContext.WalletError.operationInProgress
        }
    }

    private func ensureKeyRotationAllowsSigning() async throws {
        if try await self.storage.loadKeyRotation() != nil {
            throw WalletContext.WalletError.operationInProgress
        }
        try await self.ensureCurrentWalletIdentity()
    }

    private func ensureCurrentWalletIdentity() async throws {
        guard !self.requiresWalletKeyReconciliation else { throw WalletContext.WalletError.walletKeyMismatch }
        guard let descriptor = self.descriptor,
              let serverIdentity = self.serverWalletIdentity,
              walletEngineAddressesEqual(descriptor.address, serverIdentity.address),
              let stored = try await self.storage.loadDescriptor(),
              stored.recordId == descriptor.recordId,
              stored.publicKey == descriptor.publicKey,
              stored.signingPublicKey == serverIdentity.publicKey,
              stored.secretRef == descriptor.secretRef.value else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        let signingPublicKey = try await self.signingPublicKey(for: stored)
        guard let currentIdentity = self.serverWalletIdentity,
              walletEngineAddressesEqual(currentIdentity.address, descriptor.address),
              currentIdentity.publicKey == signingPublicKey,
              self.descriptor?.recordId == descriptor.recordId,
              self.descriptor?.publicKey == descriptor.publicKey,
              self.descriptor?.secretRef == descriptor.secretRef else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        if stored.signingPublicKey != signingPublicKey {
            try await self.storage.saveDescriptor(stored.withSigningPublicKey(signingPublicKey))
        }
        guard let latestIdentity = self.serverWalletIdentity,
              walletEngineAddressesEqual(latestIdentity.address, descriptor.address),
              latestIdentity.publicKey == signingPublicKey,
              self.descriptor?.recordId == descriptor.recordId,
              self.descriptor?.publicKey == descriptor.publicKey,
              self.descriptor?.secretRef == descriptor.secretRef else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
    }

    private func requireClient() throws -> WalletClient {
        guard let client = self.client else {
            throw WalletContext.WalletError.unavailable
        }
        return client
    }

    private func withFfi<Value>(
        priority: FfiPriority = .userInitiated,
        cancellation: FfiCancellation = .none,
        beforeSigning: (@Sendable () throws -> Void)? = nil,
        _ operation: @escaping () async throws -> Value
    ) async throws -> Value {
        if let session = WalletAuthorizationScope.session {
            try await session.waitUntilAvailable()
        }
        await self.acquireFfi(priority: priority)
        defer {
            self.activeFfiOperation = nil
            self.releaseFfi()
        }
        if let session = WalletAuthorizationScope.session {
            try await session.waitUntilAvailable()
        }
        try Task.checkCancellation()
        let operationId = UUID()
        self.activeFfiOperation = (operationId, cancellation)
        await self.platformHost.setAuthorization(WalletAuthorizationScope.session)
        await self.platformHost.setTonConnectSigningGuard(beforeSigning)
        let operationTask = Task { () -> Result<Value, Error> in
            do {
                return .success(try await operation())
            } catch {
                return .failure(error)
            }
        }
        let result = await withTaskCancellationHandler(operation: {
            await operationTask.value
        }, onCancel: { [weak self] in
            Task {
                await self?.cancelActiveFfiOperation(id: operationId, cancellation: cancellation)
            }
        })
        await self.platformHost.setTonConnectSigningGuard(nil)
        await self.platformHost.setAuthorization(nil)
        try Task.checkCancellation()
        return try result.get()
    }

    private func acquireFfi(priority: FfiPriority = .userInitiated) async {
        if !self.ffiBusy {
            self.ffiBusy = true
            return
        }
        await withCheckedContinuation { continuation in
            switch priority {
            case .userInitiated:
                self.userInitiatedFfiWaiters.append(continuation)
            case .background:
                self.backgroundFfiWaiters.append(continuation)
            }
        }
    }

    private func releaseFfi() {
        if !self.userInitiatedFfiWaiters.isEmpty {
            self.userInitiatedFfiWaiters.removeFirst().resume()
        } else if !self.backgroundFfiWaiters.isEmpty {
            self.backgroundFfiWaiters.removeFirst().resume()
        } else {
            self.ffiBusy = false
        }
    }

    private func cancelActiveFfiOperation(id: UUID, cancellation: FfiCancellation) async {
        guard cancellation != .none,
              self.activeFfiOperation?.id == id,
              self.activeFfiOperation?.cancellation == cancellation,
              let client = self.client else {
            return
        }
        do {
            switch cancellation {
            case .none:
                return
            case .sendPreview:
                try await client.cancelSendPreview()
            case .send:
                try await client.cancelSend()
            }
        } catch {
            self.logger.error("wallet_engine_operation_cancellation_failed", error)
        }
    }
}

@available(macOS 10.15, *)
func walletEngineIsSendAlreadyInProgress(_ error: Error) -> Bool {
    guard let error = error as? WalletClientError else {
        return false
    }
    if case .SendAlreadyInProgress = error {
        return true
    }
    return false
}

@available(macOS 10.15, *)
func normalizedEngineMnemonic(_ words: [String]) -> [String] {
    words.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .filter { !$0.isEmpty }
}

@available(macOS 10.15, *)
func walletEngineAddressesEqual(_ lhs: String, _ rhs: String) -> Bool {
    guard let left = try? convertTonAddress(value: lhs, format: .raw),
          let right = try? convertTonAddress(value: rhs, format: .raw) else {
        return lhs == rhs
    }
    return left == right
}

@available(macOS 10.15, *)
extension WalletEngineRuntime {
    func validateTonConnectAccess(wallet: TonConnectWalletIdentity) async throws {
        try await self.withFfi {
            try await self.ensureKeyRotationAllowsSigning()
            try self.validateTonConnectWallet(wallet)
        }
    }

    func tonConnectSessionPublicKey(wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession) async throws -> String {
        try await self.withTonConnectSession(wallet: wallet, session: session, allowPendingRegistration: true) {
            $0.publicKeyHex()
        }
    }

    func openTonConnectChallenge(_ data: Data, wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        try await self.withTonConnectSession(wallet: wallet, session: session, allowPendingRegistration: true) {
            try $0.openChallenge(challenge: data)
        }
    }

    func decodeTonConnectRequest(_ data: Data, wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession, now: UInt64, operationId: String) async throws -> TonConnectWireRequest {
        guard !data.isEmpty, data.count <= TonConnectWireCodec.maximumPacketBytes, !operationId.isEmpty else {
            throw TonConnectWireFailure(code: .badRequest)
        }
        return try await self.withTonConnectSession(wallet: wallet, session: session, allowPendingRegistration: false) { derived in
            switch try derived.decryptRequest(body: data, now: now).request {
            case let .sendTransaction(id, _, request):
                return .sendTransaction(id: try TonConnectRequestId(id), request: SendRequest(
                    operationId: operationId, force: false, intent: request.intent
                ))
            case let .signData(rawId, _, request):
                let id = try TonConnectRequestId(rawId)
                do {
                    return .signData(id: id, payload: try TonConnectSignDataPayload(request))
                } catch let failure as TonConnectWireFailure {
                    throw TonConnectWireFailure(requestId: id, code: failure.code, message: failure.message)
                }
            case let .disconnect(id, _):
                return .disconnect(id: try TonConnectRequestId(id))
            case let .unsupported(id, _, code, message):
                throw TonConnectWireFailure(requestId: try TonConnectRequestId(id), code: TonConnectWireErrorCode(code), message: message)
            case let .signMessage(id, _, _):
                throw TonConnectWireFailure(requestId: try TonConnectRequestId(id), code: .methodNotSupported)
            }
        }
    }

    func encryptTonConnectEvent(eventId: Int64, account: TonConnectAccountInfo, proof: TonConnectProofReply?, device: TonConnectDevice,
                                wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        let eventId = try Self.tonConnectEventId(eventId)
        return try await self.encryptTonConnectPacket(wallet: wallet, session: session) {
            try $0.encryptConnectEvent(eventId: eventId, account: account, proof: proof, device: device)
        }
    }

    func encryptTonConnectConnectError(eventId: Int64, code: TonConnectConnectErrorCode, message: String,
                                       wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        let eventId = try Self.tonConnectEventId(eventId)
        return try await self.encryptTonConnectPacket(wallet: wallet, session: session) {
            try $0.encryptConnectError(eventId: eventId, code: code, message: message)
        }
    }

    func encryptTonConnectSendSuccess(id: TonConnectRequestId, signedBoc: String, wallet: TonConnectWalletIdentity,
                                      session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        try await self.encryptTonConnectPacket(wallet: wallet, session: session) {
            try $0.encryptSendSuccess(requestId: id.rawValue, signedBoc: signedBoc)
        }
    }

    func encryptTonConnectSignDataSuccess(id: TonConnectRequestId, signedData: TonConnectSignedData, wallet: TonConnectWalletIdentity,
                                          session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        try await self.encryptTonConnectPacket(wallet: wallet, session: session) {
            try $0.encryptSignDataSuccess(requestId: id.rawValue, signedData: signedData)
        }
    }

    func encryptTonConnectError(id: TonConnectRequestId, code: TonConnectWireErrorCode, message: String? = nil,
                                wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        try await self.encryptTonConnectPacket(wallet: wallet, session: session) {
            try $0.encryptError(requestId: id.rawValue, code: code.engineCode, message: message ?? code.message)
        }
    }

    func encryptTonConnectDisconnectSuccess(id: TonConnectRequestId, wallet: TonConnectWalletIdentity,
                                            session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        try await self.encryptTonConnectPacket(wallet: wallet, session: session) {
            try $0.encryptDisconnectSuccess(requestId: id.rawValue)
        }
    }

    func encryptTonConnectDisconnectEvent(eventId: Int64, wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession) async throws -> Data {
        let eventId = try Self.tonConnectEventId(eventId)
        return try await self.encryptTonConnectPacket(wallet: wallet, session: session) {
            try $0.encryptDisconnectEvent(eventId: eventId)
        }
    }

    private func encryptTonConnectPacket(wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession,
                                         _ encrypt: @escaping (TonConnectDerivedSession) throws -> Data) async throws -> Data {
        try await self.withTonConnectSession(wallet: wallet, session: session, allowPendingRegistration: true) { derived in
            let body = try encrypt(derived)
            guard body.count <= TonConnectWireCodec.maximumPacketBytes else { throw TonConnectWireFailure(code: .badRequest) }
            return body
        }
    }

    private static func tonConnectEventId(_ value: Int64) throws -> UInt64 {
        guard let value = UInt64(exactly: value) else { throw TonConnectWireFailure(code: .badRequest) }
        return value
    }

    func signTonConnectData(_ payload: TonConnectSignDataPayload, domain: String, timestamp: UInt64, wallet: TonConnectWalletIdentity, beforeSigning: @escaping @Sendable () throws -> Void = {}) async throws -> TonConnectSignedData {
        try await self.withFfi(beforeSigning: beforeSigning) {
            try await self.ensureKeyRotationAllowsSigning()
            try self.validateTonConnectWallet(wallet)
            guard let descriptor = self.descriptor else { throw WalletContext.WalletError.unavailable }
            try beforeSigning()
            let signed = try await self.lifecycle.signTonConnectData(request: TonConnectSignDataSignRequest(
                descriptor: descriptor, request: payload.engineRequest, domain: domain, timestamp: timestamp
            ))
            try self.validateTonConnectWallet(wallet)
            guard signed.publicKey == wallet.publicKey else { throw TonConnectFailure.keyMismatch }
            return signed
        }
    }

    private func withTonConnectSession<Value>(wallet: TonConnectWalletIdentity, session: TelegramCore.WalletTonConnectSession, allowPendingRegistration: Bool, _ operation: @escaping (TonConnectDerivedSession) throws -> Value) async throws -> Value {
        _ = try Self.tonConnectPublicKey(session.dappClientId)
        let registeredPublicKey = try session.clientId.map(Self.tonConnectPublicKey)
        guard !session.nonce.isEmpty, session.nonce.count <= TonConnectWireCodec.maximumPacketBytes,
              registeredPublicKey != nil || (allowPendingRegistration && session.isPending && !session.isClosing && !session.isClosed) else {
            throw TonConnectFailure.keyMismatch
        }
        return try await self.withFfi {
            try await self.ensureKeyRotationAllowsSigning()
            try self.validateTonConnectWallet(wallet)
            _ = try self.requireClient()
            guard let descriptor = self.descriptor else { throw WalletContext.WalletError.unavailable }
            let derived = try await self.lifecycle.deriveTonConnectSession(request: TonConnectDerivedSessionRequest(
                descriptor: descriptor, dappClientId: session.dappClientId.lowercased(), nonce: session.nonce
            ))
            try self.validateTonConnectWallet(wallet)
            guard self.descriptor?.secretRef == descriptor.secretRef,
                  derived.signingPublicKey() == wallet.publicKey else { throw TonConnectFailure.keyMismatch }
            if let registeredPublicKey, try Self.tonConnectPublicKey(derived.publicKeyHex()) != registeredPublicKey {
                throw TonConnectFailure.keyMismatch
            }
            try Task.checkCancellation()
            return try operation(derived)
        }
    }

    private static func tonConnectPublicKey(_ value: String) throws -> Data {
        guard value.utf8.count == 64 else { throw TonConnectFailure.unavailable }
        let bytes = Array(value.utf8)
        func nibble(_ byte: UInt8) throws -> UInt8 {
            switch byte {
            case 48...57: return byte - 48
            case 65...70: return byte - 55
            case 97...102: return byte - 87
            default: throw TonConnectFailure.unavailable
            }
        }
        var result = Data(capacity: 32)
        for index in stride(from: 0, to: bytes.count, by: 2) {
            result.append(try (nibble(bytes[index]) << 4) | nibble(bytes[index + 1]))
        }
        return result
    }
}
