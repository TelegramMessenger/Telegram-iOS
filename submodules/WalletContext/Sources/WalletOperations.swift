import PasscodeCore
import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox
import WalletEngineFFI

@available(macOS 10.15, *)
final class WalletImportRequestState {
    private(set) var preserveCandidate: Bool

    init(preserveCandidate: Bool) {
        self.preserveCandidate = preserveCandidate
    }

    func submit<Value>(
        verify: () async throws -> Void,
        persist: () async throws -> Void,
        request: () async throws -> Value
    ) async throws -> Value {
        try await verify()
        try await persist()
        try Task.checkCancellation()
        let previouslyPending = self.preserveCandidate
        self.preserveCandidate = true
        do {
            return try await request()
        } catch let error as TelegramCore.WalletOperationError {
            // Password preflight and explicit RPC rejections did not accept
            // this replacement. A transport failure leaves the outcome unknown.
            self.preserveCandidate = previouslyPending || error == .network
            throw error
        }
    }

    func shouldDiscard(after error: Error) -> Bool {
        !self.preserveCandidate || error as? WalletContext.WalletError == .recoveryPhraseOutdated
    }
}

@available(macOS 10.15, *)
func withWalletOwnershipProofRequest<Value>(
    prepare: () async throws -> Void,
    validate: () throws -> Void,
    challenge: () async throws -> TelegramCore.WalletProofChallenge,
    sign: (TelegramCore.WalletProofChallenge) async throws -> Data,
    request: (TelegramCore.WalletOwnershipProof) async throws -> Value
) async throws -> Value {
    for attempt in 0 ..< 2 {
        do {
            try await prepare()
            try validate()
            let startedAt = ProcessInfo.processInfo.systemUptime
            let challenge = try await challenge()
            guard challenge.domain == "telegram.org", challenge.timestamp > 0 else {
                throw WalletContext.WalletError.proofInvalid
            }
            guard challenge.expires > challenge.timestamp else { throw WalletContext.WalletError.proofExpired }
            let signature = try await sign(challenge)
            guard signature.count == 64 else { throw WalletContext.WalletError.proofInvalid }
            let elapsed = max(0, ProcessInfo.processInfo.systemUptime - startedAt)
            guard Double(challenge.timestamp) + elapsed < Double(challenge.expires) else {
                throw WalletContext.WalletError.proofExpired
            }
            try validate()
            return try await request(TelegramCore.WalletOwnershipProof(timestamp: challenge.timestamp, signature: signature))
        } catch {
            let expired = error as? WalletContext.WalletError == .proofExpired
                || error as? TelegramCore.WalletOperationError == .proofExpired
            guard attempt == 0, expired else { throw error }
        }
    }
    throw WalletContext.WalletError.proofExpired
}

@available(macOS 10.15, *)
private func walletCommentEncryptionError(_ error: Error) -> WalletContext.WalletError {
    if let error = error as? WalletClientError {
        switch error {
        case .EncryptedCommentUnavailable: return .commentEncryptionRecipientUnavailable
        case .EncryptedCommentLookupFailed: return .network
        default: break
        }
    }
    return .commentEncryptionFailed
}

@available(macOS 10.15, *)
func walletPreviewNeedsSeqnoRetry(_ error: Error) -> Bool {
    guard let error = error as? WalletClientError else {
        return false
    }
    let diagnostic: String
    switch error {
    case let .EmulationFailed(value), let .EmulationMessageNotAccepted(value):
        diagnostic = value
    default:
        return false
    }
    return diagnostic.range(
        of: #"\bEmulationExternalNotAccepted:\s*133\b(?!\.[0-9])"#,
        options: .regularExpression
    ) != nil
}

@available(macOS 10.15, *)
func walletKeyRotationPreparationIsExpired(_ error: Error, seqno: UInt32) -> Bool {
    guard let error = error as? WalletClientError else { return false }
    let diagnostic: String
    switch error {
    case let .SendPreviewFailed(value), let .SendFailed(value): diagnostic = value
    default: return false
    }
    if diagnostic == "transfer expiration timestamp is not after fresh provider time" { return true }
    let prefix = "prepared BOC seqno \(seqno) does not match current wallet seqno "
    guard diagnostic.hasPrefix(prefix), let current = UInt32(diagnostic.dropFirst(prefix.count)) else { return false }
    return current != seqno
}

@available(macOS 10.15, *)
func acceptedWalletTransferSubmission(
    pending: WalletContext.PendingTransfer,
    messageHash: String?,
    phase: SendPhase,
    acceptedAt: Int32,
    sentTransfer: WalletSentTransfer? = nil
) -> WalletContext.PendingTransfer? {
    let status: WalletContext.PendingTransfer.Status
    switch phase {
    case .submitted:
        status = .pending
    case .submissionUnknown:
        status = .submissionUnknown
    case .confirmed:
        status = .confirmed
    case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
         .submitting, .handedOff, .replaced, .sequenceNumberConsumed, .expired,
         .superseded, .failed, .cancelled:
        return nil
    }
    let transfer = sentTransfer ?? pending.sentTransfer
    return WalletContext.PendingTransfer(
        id: pending.id,
        recipient: pending.recipient,
        amount: pending.amount,
        comment: pending.comment,
        commentEncrypted: pending.commentEncrypted,
        collectibleAddress: pending.collectibleAddress,
        normalizedHash: transfer?.gasless == true ? nil : (messageHash ?? pending.normalizedHash),
        sentTransfer: transfer,
        expectedGasless: pending.expectedGasless,
        pendingMessage: pending.pendingMessage,
        streamingData: pending.streamingData,
        fee: pending.fee,
        transactionHash: pending.transactionHash,
        transactionLt: pending.transactionLt,
        uiExpiresAt: walletPendingTransferUIExpirationTimestamp(from: acceptedAt),
        createdAt: pending.createdAt,
        status: pending.status == .confirmed ? .confirmed : status
    )
}

@available(macOS 10.15, *)
private func walletEngineSendPhaseIsTerminal(_ phase: SendPhase) -> Bool {
    switch phase {
    case .replaced, .sequenceNumberConsumed, .expired, .superseded, .failed, .cancelled:
        return true
    case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
         .submitting, .submissionUnknown, .submitted, .confirmed, .handedOff:
        return false
    }
}

@available(macOS 10.15, *)
private func walletServerIdentity(_ state: TelegramCore.WalletState) throws -> (address: String, publicKey: Data) {
    switch state {
    case let .ready(_, _, _, address, publicKey, _):
        guard publicKey.count == 32 else {
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        return (address, publicKey)
    case .empty:
        throw WalletContext.WalletError.replacementInvalid
    }
}

@available(macOS 10.15, *)
func stageRecoveryPhraseImport(
    runtime: WalletEngineRuntime,
    words: [String],
    sourceAddress: String,
    sourcePublicKey: Data
) async throws -> WalletContext.PreparedRecoveryPhraseImport {
    let normalizedWords = normalizedEngineMnemonic(words)
    guard detectMnemonicSchemes(words: normalizedWords).contains(.rotation) else {
        throw WalletContext.WalletError.invalidMnemonic
    }
    let staged = try await runtime.stageVerifiedReplacement(words: normalizedWords)
    let disposition: WalletContext.PreparedRecoveryPhraseImport.Disposition
    if walletEngineAddressesEqual(staged.address, sourceAddress) {
        guard staged.signingPublicKey == sourcePublicKey else {
            if !staged.isPersisted {
                try await runtime.discardReplacement(recordId: staged.recordId)
            }
            throw WalletContext.WalletError.storage(.identityMismatch)
        }
        disposition = .currentWallet
    } else {
        disposition = .replacement
    }
    return WalletContext.PreparedRecoveryPhraseImport(
        disposition: disposition,
        recordId: staged.recordId,
        sourceAddress: sourceAddress,
        sourcePublicKey: sourcePublicKey,
        candidateAddress: staged.address,
        candidatePublicKey: staged.publicKey,
        candidateSigningPublicKey: staged.signingPublicKey
    )
}

@available(macOS 10.15, *)
public extension WalletContext {
    func beginWalletFlow(reason: String) -> Signal<PasscodeSession, WalletError> {
        self.signal(
            name: "begin_wallet_flow",
            deliverWhenAvailable: true,
            discardResult: { [authorization = self.authorization] in authorization.finish($0) },
            validateResult: { [authorization = self.authorization] in
                try authorization.validate($0, requireAvailable: false)
            }
        ) { impl, operationId in
            try await impl.beginWalletFlow(reason: reason, operationId: operationId)
        }
    }

    static func transferAddress(from value: String, preserveBounce: Bool = false) -> String? {
        normalizedMainnetAddress(value, preserveBounce: preserveBounce)
    }

    static func isSelfTransfer(recipient: String, walletAddress: String?) -> Bool {
        guard let walletAddress,
              let normalizedRecipient = normalizedMainnetAddress(recipient),
              let normalizedWalletAddress = normalizedMainnetAddress(walletAddress) else {
            return false
        }
        return normalizedRecipient == normalizedWalletAddress
    }

    static func transferRecipient(from value: String) -> ResolvedTransferRecipient? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let address = normalizedMainnetAddress(value, preserveBounce: true) else {
            return nil
        }
        return ResolvedTransferRecipient(
            address: address,
            displayName: nil,
            transferLink: value.lowercased().hasPrefix("ton://") ? value : nil
        )
    }

    func rememberWalletPeer(_ peer: EnginePeer, address: String) {
        let mapping = WalletPeerAddressMapping(peer: peer, address: address)
        Task { [impl = self.impl, mapping] in
            await impl.rememberWalletPeer(mapping)
        }
    }

    func resolveTransferRecipient(_ value: String) -> Signal<ResolvedTransferRecipient?, WalletError> {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .single(nil) }
        if let recipient = Self.transferRecipient(from: value) {
            return .single(recipient)
        }
        let lowercaseValue = value.lowercased()
        guard (lowercaseValue.hasSuffix(".ton") || lowercaseValue.hasSuffix(".t.me")),
              !value.unicodeScalars.contains(where: CharacterSet.whitespacesAndNewlines.contains) else {
            return .single(nil)
        }
        return self.signal(name: "resolve_transfer_recipient") { impl, _ in
            try await impl.resolveTransferRecipient(value)
        }
    }

    func setFiatCurrency(_ currency: FiatCurrency) {
        let revision = self.fiatCurrencyRevision.modify { $0 &+ 1 }
        Task { [impl = self.impl] in
            await impl.setFiatCurrency(currency, revision: revision)
        }
    }

    func isMnemonicWord(_ word: String) -> Bool {
        let word = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return mnemonicWordlist().contains(word)
    }

    func mnemonicWordSuggestions(for prefix: String, limit: Int) -> [String] {
        let prefix = prefix.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty, limit > 0 else { return [] }
        return Array(mnemonicWordlist().lazy.filter { $0.hasPrefix(prefix) }.prefix(limit))
    }

    func isMnemonicValid(words: [String]) -> Bool {
        detectMnemonicSchemes(words: normalizedEngineMnemonic(words)).contains(.rotation)
    }

    func createWallet(password: String? = nil, session: PasscodeSession? = nil) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "creating", cancelOnDispose: false, deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.createWallet(password: password, session: session, operationId: operationId)
        }
    }

    func completeWalletCreation(_ created: WalletInfo, password: String? = nil, session: PasscodeSession? = nil) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "completing_wallet_creation", cancelOnDispose: false, deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.completeWalletCreation(created, password: password, session: session, operationId: operationId)
        }
    }

    func importWallet(words: [String], password: String? = nil, session: PasscodeSession? = nil) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "importing", cancelOnDispose: false, deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.importWallet(words: words, password: password, session: session, operationId: operationId)
        }
    }

    func previousWallets(refreshBalances: Bool = false) -> Signal<[PreviousWallet], WalletError> {
        let cached = self.state
        |> filter { state in
            if case .restoring = state.phase {
                return state.walletAddress != nil
            }
            return true
        }
        |> take(1)
        |> castError(WalletError.self)
        |> mapToSignal { _ -> Signal<[PreviousWallet], WalletError> in
            return self.signal(name: "previous_wallets") { impl, _ in
                try await impl.previousWallets()
            }
        }
        guard refreshBalances else { return cached }
        return cached |> then(self.signal(name: "refreshing_previous_wallet_balances", cancelOnDispose: false) { impl, _ in
            try await impl.refreshPreviousWalletBalances()
        })
    }

    func forgetPreviousWallet(id: String) -> Signal<Void, WalletError> {
        self.signal(name: "forgetting_previous_wallet") { impl, _ in
            try await impl.forgetPreviousWallet(id: id)
        }
    }

    func previousWalletRecoveryPhrase(id: String, session: PasscodeSession? = nil) -> Signal<[String], WalletError> {
        self.signal(name: "recovering_previous_phrase", cancelOnDispose: false, deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.previousWalletRecoveryPhrase(id: id, session: session, operationId: operationId)
        }
    }

    func recoveryPhrase(password: String? = nil, session: PasscodeSession? = nil) -> Signal<[String], WalletError> {
        self.signal(name: "recovering_phrase", cancelOnDispose: false, deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.recoveryPhrase(password: password, session: session, operationId: operationId)
        }
    }

    func debugRemoveMnemonicFromKeychain() -> Signal<Void, WalletError> {
        self.signal(name: "debug_removing_mnemonic_from_keychain", cancelOnDispose: false) { impl, _ in
            try await impl.storage.debugRemoveMnemonicFromKeychain()
        }
    }

    func prepareRecoveryPhraseImport(words: [String], session: PasscodeSession? = nil) -> Signal<PreparedRecoveryPhraseImport, WalletError> {
        self.signal(name: "preparing_recovery_phrase_import", deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.prepareRecoveryPhraseImport(words: words, session: session, operationId: operationId)
        }
    }

    func completeRecoveryPhraseImport(
        _ prepared: PreparedRecoveryPhraseImport,
        password: String? = nil,
        session: PasscodeSession? = nil
    ) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "completing_recovery_phrase_import", cancelOnDispose: false, deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.completeRecoveryPhraseImport(prepared, password: password, session: session, operationId: operationId)
        }
    }

    func discardRecoveryPhraseImport(_ prepared: PreparedRecoveryPhraseImport) -> Signal<Void, WalletError> {
        self.signal(name: "discard_recovery_phrase_import", cancelOnDispose: false) { impl, _ in
            try await impl.discardRecoveryPhraseImport(prepared)
        }
    }

    func enableBackup(expectedAddress: String, words: [String]? = nil, session: PasscodeSession? = nil) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "enabling_backup", cancelOnDispose: false, deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.enableBackup(expectedAddress: expectedAddress, words: words, session: session, operationId: operationId)
        }
    }

    func prepareDisableBackup(updateSecretPhrase: Bool = true, session: PasscodeSession? = nil) -> Signal<PreparedBackupDisable, WalletError> {
        self.signal(name: "preparing_backup_disable", deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.prepareDisableBackup(updateSecretPhrase: updateSecretPhrase, session: session, operationId: operationId)
        }
    }

    func refreshPreparedBackupDisable(_ prepared: PreparedBackupDisable, session: PasscodeSession? = nil) -> Signal<PreparedBackupDisable, WalletError> {
        self.signal(name: "refreshing_backup_disable", deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.refreshPreparedBackupDisable(prepared, session: session, operationId: operationId)
        }
    }

    func disableBackup(_ prepared: PreparedBackupDisable, password: String? = nil, session: PasscodeSession? = nil) -> Signal<WalletInfo, WalletError> {
        self.signal(name: "disabling_backup", cancelOnDispose: false, deliverWhenAvailable: session?.lifetime == .ownerManaged) { impl, operationId in
            try await impl.disableBackup(prepared, password: password, session: session, operationId: operationId)
        }
    }

    func discardPreparedBackupDisable(_ prepared: PreparedBackupDisable) {
        Task { [impl = self.impl] in await impl.discardPreparedBackupAuthorization(id: prepared.id) }
    }

    func beginCommentEncryptionSession() -> Signal<PasscodeSession, WalletError> {
        self.signal(
            name: "begin_comment_encryption_session",
            discardResult: { [authorization = self.authorization] session in
                authorization.finish(session)
            },
            validateResult: { session in
                guard session.isValid else { throw PasscodeError.staleAuthorization }
            }
        ) { impl, operationId in
            try await impl.beginCommentEncryptionSession(operationId: operationId)
        }
    }

    func adoptCommentEncryptionSession(_ prepared: PreparedTransfer) -> Signal<PasscodeSession?, WalletError> {
        self.signal(
            name: "adopt_comment_encryption_session",
            discardResult: { [impl = self.impl, authorization = self.authorization] session in
                authorization.finish(session)
                Task { await impl.discardCommentEncryptionTransfer(prepared, sessionId: session?.id) }
            },
            discardOnCancel: { [impl = self.impl] in
                Task { await impl.discardCommentEncryptionTransfer(prepared, sessionId: nil) }
            },
            validateResult: { session in
                if let session, !session.isValid { throw PasscodeError.staleAuthorization }
            }
        ) { impl, _ in
            try await impl.adoptCommentEncryptionSession(prepared)
        }
    }

    func prepareTransfer(address: String, amount: Int64, sendAll: Bool = false, comment: String?, commentEncrypted: Bool = false, recipientPublicKey: Data? = nil, session: PasscodeSession? = nil, pendingRegistration: PendingTransferRegistration? = nil, estimatedFee: Int64? = nil) -> Signal<PreparedTransfer, WalletError> {
        self.signal(
            name: "preparing_transfer",
            discardResult: { [impl = self.impl] prepared in
                Task { await impl.discardPreparedTransfer(prepared) }
            }
        ) { impl, operationId in
            try await impl.prepareTransfer(
                address: address,
                amount: amount,
                sendAll: sendAll,
                comment: comment,
                commentEncrypted: commentEncrypted,
                recipientPublicKey: recipientPublicKey,
                session: session,
                pendingRegistration: pendingRegistration,
                estimatedFee: estimatedFee,
                operationId: operationId
            )
        }
    }

    func decryptTransactionComment(_ transaction: Transaction) -> Signal<String, WalletError> {
        self.signal(name: "decrypting_comment") { impl, operationId in
            try await impl.decryptTransactionComment(transaction, operationId: operationId)
        }
    }

    func prepareCollectibleTransfer(
        address: String,
        collectible: Collectible,
        comment: String?
    ) -> Signal<PreparedTransfer, WalletError> {
        self.signal(
            name: "preparing_transfer",
            discardResult: { [impl = self.impl] prepared in
                Task { await impl.discardPreparedTransfer(prepared) }
            }
        ) { impl, operationId in
            try await impl.prepareCollectibleTransfer(
                address: address,
                collectible: collectible,
                comment: comment,
                operationId: operationId
            )
        }
    }

    func submitTransfer(
        _ prepared: PreparedTransfer,
        recipientPeerId: EnginePeer.Id? = nil,
        pendingMessageCreated: (@MainActor @Sendable () -> Void)? = nil,
        session: PasscodeSession? = nil,
        stageUpdated: (@MainActor @Sendable (TransferSubmissionStage) -> Void)? = nil
    ) -> Signal<PendingTransfer, WalletError> {
        Signal { subscriber in
            let control = WalletTransferSubmissionControl()
            return self.signal(name: "submitting_transfer", cancelOnDispose: false, submissionControl: control) { impl, operationId in
                try await impl.submitTransfer(prepared, recipientPeerId: recipientPeerId, pendingMessageCreated: pendingMessageCreated, session: session, operationId: operationId, control: control, stageUpdated: stageUpdated)
            }.start(next: subscriber.putNext, error: subscriber.putError, completed: subscriber.putCompletion)
        }
    }

    func discardPreparedTransfer(_ prepared: PreparedTransfer) -> Signal<Void, WalletError> {
        self.signal(name: "discarding_prepared_transfer", cancelOnDispose: false) { impl, _ in
            await impl.discardPreparedTransfer(prepared)
        }
    }

    func loadMoreTransactions() -> Signal<Void, WalletError> {
        self.signal(name: "loading_more_transactions") { impl, operationId in
            try await impl.loadMoreTransactions(operationId: operationId)
        }
    }

    func loadMoreCollectibles() -> Signal<Void, WalletError> {
        self.signal(name: "loading_more_collectibles") { impl, operationId in
            try await impl.loadMoreCollectibles(operationId: operationId)
        }
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    func beginWalletFlow(reason: String, operationId: UUID) async throws -> PasscodeSession {
        guard !self.isShutdown else { throw WalletError.unavailable }
        return try await self.authorization.beginSession(id: operationId, reason: reason, lifetime: .ownerManaged)
    }

    func discardPreparedBackupAuthorization(id: String) {
        self.authorization.finish(self.preparedAuthorizations.removeValue(forKey: "backup:" + id))
    }

    private func replaceWalletWithImportedCandidate(
        recordId: String,
        anchorPublicKey: Data,
        signingPublicKey: Data,
        password: String?,
        requestState: WalletImportRequestState
    ) async throws -> TelegramCore.WalletState {
        guard anchorPublicKey.count == 32, signingPublicKey.count == 32 else {
            throw WalletError.publicKeyInvalid
        }
        return try await self.withWalletOwnershipProof(prepare: {
            try await self.runtime.verifyReplacement(recordId: recordId)
        }, sign: { challenge in
            try await self.runtime.signOwnershipProof(
                replacementRecordId: recordId,
                expectedAnchorPublicKey: anchorPublicKey,
                expectedSigningPublicKey: signingPublicKey,
                domain: challenge.domain, timestamp: UInt64(challenge.timestamp), payload: challenge.payload
            )
        }, request: { proof in
            try await requestState.submit(verify: {
                try Task.checkCancellation()
            }, persist: {
                try await self.runtime.persistReplacementCandidate(recordId: recordId)
            }, request: {
                try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                    self.engine.wallet.replaceWallet(
                        replacement: .imported(publicKey: signingPublicKey, anchorPublicKey: anchorPublicKey, proof: proof),
                        password: password
                    )
                )
            })
        })
    }

    private func withWalletOwnershipProof<Value: Sendable>(
        prepare: () async throws -> Void = {},
        validate: () throws -> Void = {},
        sign: (TelegramCore.WalletProofChallenge) async throws -> Data,
        request: (TelegramCore.WalletOwnershipProof) async throws -> Value
    ) async throws -> Value {
        try await withWalletOwnershipProofRequest(
            prepare: prepare,
            validate: validate,
            challenge: {
                try await WalletSignalRequestContext<TelegramCore.WalletProofChallenge>().run(self.engine.wallet.getProofChallenge())
            },
            sign: sign,
            request: request
        )
    }

    func resolveTransferRecipient(_ value: String) async throws -> ResolvedTransferRecipient? {
        guard !self.isShutdown else { throw WalletError.unavailable }
        guard let address = try await self.runtime.resolveDns(value.lowercased()),
              let normalized = normalizedMainnetAddress(address) else {
            return nil
        }
        return ResolvedTransferRecipient(address: normalized, displayName: value)
    }

    func setFiatCurrency(_ currency: FiatCurrency, revision: UInt64) {
        guard !self.isShutdown else { return }
        guard revision > self.latestFiatCurrencyRevision else { return }
        self.latestFiatCurrencyRevision = revision
        guard self.currentState.fiat.selectedCurrency != currency else { return }
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation,
            fiat: FiatState(selectedCurrency: currency, rates: self.currentState.fiat.rates)
        )
    }

    private func replacementStateAfterRequest(
        _ response: TelegramCore.WalletState,
        startedAt revision: UInt64
    ) throws -> (state: TelegramCore.WalletState, revision: UInt64) {
        guard self.serverStateMutationRevision != revision else { return (response, revision) }
        guard let latest = self.deferredServerWalletState?.state ?? self.serverWalletState else {
            throw WalletError.noWallet
        }
        return (latest, self.serverStateMutationRevision)
    }

    func createWallet(password: String?, session: PasscodeSession? = nil, operationId: UUID) async throws -> WalletInfo {
        return try await self.performOperation(.creating, operationId: operationId, session: session) {
            let requestRevision = self.serverStateMutationRevision
            let response = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                self.engine.wallet.replaceWallet(replacement: .new, password: password)
            )
            let selected = try self.replacementStateAfterRequest(response, startedAt: requestRevision)
            let state = selected.state
            let identity = try walletServerIdentity(state)
            let serverStateRevision = selected.revision
            self.deferredServerWalletState = (
                state,
                self.deferredServerWalletState?.refreshIfStreamingUnavailable ?? false,
                self.deferredServerWalletState?.balanceOverlayRevision
            )
            self.automaticPhraseRecoveryAttemptIdentity = (identity.address, identity.publicKey)
            let generation = await self.prepareForRuntimeIdentityChange()
            let activation = try await self.runtime.activate(
                serverAddress: identity.address,
                serverPublicKey: identity.publicKey,
                serverStateRevision: serverStateRevision
            )
            guard self.serverStateMutationRevision == serverStateRevision else { throw CancellationError() }
            return self.installRuntimeActivation(
                state: self.deferredServerWalletState?.state ?? state,
                activation: activation,
                generation: generation
            )
        }
    }

    func completeWalletCreation(_ created: WalletInfo, password: String?, session: PasscodeSession?, operationId: UUID) async throws -> WalletInfo {
        guard case let .wallet(current) = self.currentState.phase,
              walletEngineAddressesEqual(current.address, created.address),
              current.publicKey == created.publicKey else { throw WalletError.storage(.identityMismatch) }
        _ = try await self.recoveryPhrase(password: password, session: session, operationId: operationId, expectedWallet: created)
        guard case let .wallet(updated) = self.currentState.phase,
              walletEngineAddressesEqual(updated.address, created.address),
              updated.publicKey == created.publicKey, updated.canSign else { throw WalletError.storage(.identityMismatch) }
        return updated
    }

    private func reconcileReplacementBeforeImport() async throws {
        guard try await self.runtime.hasReplacementCandidate() else { return }
        let revision = self.serverStateMutationRevision
        let state: TelegramCore.WalletState
        do {
            state = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(self.engine.wallet.getState())
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw WalletError.network
        }
        guard !self.isShutdown, self.serverStateMutationRevision == revision else { throw CancellationError() }
        let promoted: Bool
        switch state {
        case let .ready(_, _, _, address, publicKey, _):
            promoted = try await self.runtime.reconcileReplacementCandidate(
                serverAddress: address, serverPublicKey: publicKey, discardMismatch: true,
                archivePreviousWallet: !self.isChangingWalletLocally, serverStateRevision: revision
            )
        case let .empty(creating):
            if !creating {
                try await self.runtime.discardReplacementAfterAuthoritativeEmptyState(serverStateRevision: revision)
            }
            promoted = false
        }
        guard !self.isShutdown, self.serverStateMutationRevision == revision else { throw CancellationError() }
        self.applyServerWalletState(state, forceActivation: promoted)
        if case let .ready(_, _, _, address, publicKey, _) = state {
            await self.runtime.updateServerWalletIdentity(address: address, publicKey: publicKey, revision: self.serverStateMutationRevision)
        } else {
            await self.runtime.invalidateServerWalletIdentity(revision: self.serverStateMutationRevision)
        }
    }

    func importWallet(words: [String], password: String?, session: PasscodeSession? = nil, operationId: UUID) async throws -> WalletInfo {
        return try await self.performOperation(.importing, operationId: operationId, session: session) {
            let normalizedWords = normalizedEngineMnemonic(words)
            guard detectMnemonicSchemes(words: normalizedWords).contains(.rotation) else {
                throw WalletError.invalidMnemonic
            }
            try await self.reconcileReplacementBeforeImport()
            let staged = try await self.runtime.stageVerifiedReplacement(words: normalizedWords)
            let requestState = WalletImportRequestState(preserveCandidate: staged.isPersisted)
            let requestRevision = self.serverStateMutationRevision
            do {
                let response = try await self.replaceWalletWithImportedCandidate(
                    recordId: staged.recordId,
                    anchorPublicKey: staged.publicKey,
                    signingPublicKey: staged.signingPublicKey,
                    password: password,
                    requestState: requestState
                )
                let selected = try self.replacementStateAfterRequest(response, startedAt: requestRevision)
                let state = selected.state
                let identity = try walletServerIdentity(state)
                guard walletEngineAddressesEqual(staged.address, identity.address),
                      staged.signingPublicKey == identity.publicKey else {
                    try await self.runtime.verifyReplacement(recordId: staged.recordId)
                    throw WalletError.storage(.identityMismatch)
                }
                let serverStateRevision = selected.revision
                let generation = await self.prepareForRuntimeIdentityChange()
                let activation = try await self.runtime.commitReplacement(
                    recordId: staged.recordId,
                    serverAddress: identity.address,
                    serverPublicKey: identity.publicKey,
                    serverStateRevision: serverStateRevision
                )
                guard self.serverStateMutationRevision == serverStateRevision else { throw CancellationError() }
                return self.installRuntimeActivation(state: state, activation: activation, generation: generation)
            } catch {
                if requestState.shouldDiscard(after: error) {
                    await self.discardReplacementForCleanup(recordId: staged.recordId)
                }
                throw error
            }
        }
    }

    func previousWallets() async throws -> [WalletContext.PreviousWallet] {
        self.previousWalletsExcludingCurrent(try await self.runtime.archivedWallets())
    }

    private func previousWalletsExcludingCurrent(_ wallets: [WalletContext.PreviousWallet]) -> [WalletContext.PreviousWallet] {
        guard let walletAddress = self.currentState.walletAddress else { return wallets }
        return wallets.filter { !walletEngineAddressesEqual($0.address, walletAddress) }
    }

    func refreshPreviousWalletBalances() async throws -> [WalletContext.PreviousWallet] {
        if let task = self.previousWalletBalancesTask {
            return self.previousWalletsExcludingCurrent(try await task.value)
        }
        let task = Task {
            defer { self.previousWalletBalancesTask = nil }
            let wallets = try await self.previousWallets()
            guard !wallets.isEmpty, self.canUseNetworkRuntime else { return wallets }
            let now = ProcessInfo.processInfo.systemUptime
            if let lastAttemptAt = self.previousWalletBalancesLastAttemptAt, now - lastAttemptAt < 10 * 60 {
                return wallets
            }
            self.previousWalletBalancesLastAttemptAt = now
            return try await self.runtime.refreshArchivedWalletBalances(wallets)
        }
        self.previousWalletBalancesTask = task
        return self.previousWalletsExcludingCurrent(try await task.value)
    }

    func forgetPreviousWallet(id: String) async throws {
        try await self.runtime.forgetArchivedWallet(recordId: id)
    }

    func previousWalletRecoveryPhrase(id: String, session: PasscodeSession? = nil, operationId: UUID) async throws -> [String] {
        return try await self.performOperation(.recoveringPhrase, operationId: operationId, session: session) {
            let serverStateRevision = self.serverStateMutationRevision
            let words = try await self.runtime.revealArchivedRecoveryPhrase(recordId: id)
            guard self.serverStateMutationRevision == serverStateRevision else { throw CancellationError() }
            return words
        }
    }

    func recoveryPhrase(password: String?, session: PasscodeSession? = nil, operationId: UUID, expectedWallet: WalletInfo? = nil) async throws -> [String] {
        return try await self.performOperation(.recoveringPhrase, operationId: operationId, session: session) {
            guard case let .wallet(info) = self.currentState.phase, info.canRevealPhrase else {
                throw WalletError.unavailable
            }
            if let expectedWallet {
                guard walletEngineAddressesEqual(info.address, expectedWallet.address),
                      info.publicKey == expectedWallet.publicKey else { throw WalletError.storage(.identityMismatch) }
            }
            let serverStateRevision = self.serverStateMutationRevision
            if info.canSign {
                let words = try await self.runtime.revealRecoveryPhrase()
                guard self.serverStateMutationRevision == serverStateRevision else { throw CancellationError() }
                return words
            }
            guard info.canExportPhrase,
                  case let .ready(_, _, _, address, publicKey, _) = self.serverWalletState else {
                throw WalletError.unavailable
            }
            let words = try await exportWalletSecretPhrase(
                engine: self.engine,
                password: password,
                expectedPublicKey: publicKey
            )
            let prepared = try await stageRecoveryPhraseImport(
                runtime: self.runtime,
                words: words,
                sourceAddress: address,
                sourcePublicKey: publicKey
            )
            guard prepared.disposition == .currentWallet else {
                await self.discardReplacementForCleanup(recordId: prepared.recordId)
                throw WalletError.storage(.identityMismatch)
            }
            do {
                guard self.serverStateMutationRevision == serverStateRevision else { throw CancellationError() }
                let generation = await self.prepareForRuntimeIdentityChange(
                    preserveCurrentWalletState: true
                )
                let activation = try await self.runtime.commitReplacement(
                    recordId: prepared.recordId,
                    serverAddress: address,
                    serverPublicKey: publicKey,
                    serverStateRevision: serverStateRevision
                )
                guard self.serverStateMutationRevision == serverStateRevision else { throw CancellationError() }
                if let state = self.serverWalletState {
                    _ = self.installRuntimeActivation(
                        state: state,
                        activation: activation,
                        generation: generation,
                        preserveCurrentWalletState: true
                    )
                }
            } catch {
                await self.discardReplacementForCleanup(recordId: prepared.recordId)
                throw error
            }
            return words
        }
    }

    func prepareRecoveryPhraseImport(words: [String], session: PasscodeSession? = nil, operationId: UUID) async throws -> PreparedRecoveryPhraseImport {
        return try await self.performOperation(.preparingRecoveryPhraseImport, operationId: operationId, session: session) {
            try await self.reconcileReplacementBeforeImport()
            guard let state = self.deferredServerWalletState?.state ?? self.serverWalletState else {
                throw WalletError.noWallet
            }
            let sourceIdentity = try walletServerIdentity(state)
            let prepared = try await stageRecoveryPhraseImport(
                runtime: self.runtime,
                words: words,
                sourceAddress: sourceIdentity.address,
                sourcePublicKey: sourceIdentity.publicKey
            )
            self.preparedRecoveryPhraseImportRecordId = prepared.recordId
            return prepared
        }
    }

    func completeRecoveryPhraseImport(
        _ prepared: PreparedRecoveryPhraseImport,
        password: String?,
        session: PasscodeSession? = nil,
        operationId: UUID
    ) async throws -> WalletInfo {
        return try await self.performOperation(.completingRecoveryPhraseImport, operationId: operationId, session: session) {
            guard let currentServerState = self.deferredServerWalletState?.state ?? self.serverWalletState else {
                throw WalletError.noWallet
            }
            let serverStateRevision = self.serverStateMutationRevision
            let currentIdentity: (address: String, publicKey: Data)
            do {
                currentIdentity = try walletServerIdentity(currentServerState)
            } catch {
                if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    self.preparedRecoveryPhraseImportRecordId = nil
                }
                await self.discardReplacementForCleanup(recordId: prepared.recordId)
                throw error
            }
            guard walletEngineAddressesEqual(currentIdentity.address, prepared.sourceAddress),
                  currentIdentity.publicKey == prepared.sourcePublicKey else {
                if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    self.preparedRecoveryPhraseImportRecordId = nil
                }
                await self.discardReplacementForCleanup(recordId: prepared.recordId)
                throw WalletError.storage(.identityMismatch)
            }

            switch prepared.disposition {
            case .currentWallet:
                guard walletEngineAddressesEqual(prepared.candidateAddress, currentIdentity.address),
                      prepared.candidateSigningPublicKey == currentIdentity.publicKey else {
                    if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                        self.preparedRecoveryPhraseImportRecordId = nil
                    }
                    await self.discardReplacementForCleanup(recordId: prepared.recordId)
                    throw WalletError.storage(.identityMismatch)
                }
                if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    self.preparedRecoveryPhraseImportRecordId = nil
                }
                let generation = await self.prepareForRuntimeIdentityChange(
                    preserveCurrentWalletState: true
                )
                let activation: WalletEngineActivation
                do {
                    activation = try await self.runtime.commitReplacement(
                        recordId: prepared.recordId,
                        serverAddress: currentIdentity.address,
                        serverPublicKey: currentIdentity.publicKey,
                        serverStateRevision: serverStateRevision
                    )
                } catch {
                    await self.discardReplacementForCleanup(recordId: prepared.recordId)
                    throw error
                }
                guard self.serverStateMutationRevision == serverStateRevision else { throw CancellationError() }
                return self.installRuntimeActivation(
                    state: currentServerState,
                    activation: activation,
                    generation: generation,
                    preserveCurrentWalletState: true
                )

            case .replacement:
                let requestState = WalletImportRequestState(preserveCandidate: try await self.runtime.isPersistedReplacementCandidate(recordId: prepared.recordId))
                let requestRevision = self.serverStateMutationRevision
                do {
                    let response = try await self.replaceWalletWithImportedCandidate(
                        recordId: prepared.recordId,
                        anchorPublicKey: prepared.candidatePublicKey,
                        signingPublicKey: prepared.candidateSigningPublicKey,
                        password: password,
                        requestState: requestState
                    )
                    if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                        self.preparedRecoveryPhraseImportRecordId = nil
                    }
                    let selected = try self.replacementStateAfterRequest(response, startedAt: requestRevision)
                    let state = selected.state
                    let replacementIdentity = try walletServerIdentity(state)
                    guard walletEngineAddressesEqual(prepared.candidateAddress, replacementIdentity.address),
                          prepared.candidateSigningPublicKey == replacementIdentity.publicKey else {
                        try await self.runtime.verifyReplacement(recordId: prepared.recordId)
                        throw WalletError.storage(.identityMismatch)
                    }
                    let replacementRevision = selected.revision
                    let generation = await self.prepareForRuntimeIdentityChange()
                    let activation = try await self.runtime.commitReplacement(
                        recordId: prepared.recordId,
                        serverAddress: replacementIdentity.address,
                        serverPublicKey: replacementIdentity.publicKey,
                        serverStateRevision: replacementRevision
                    )
                    guard self.serverStateMutationRevision == replacementRevision else { throw CancellationError() }
                    return self.installRuntimeActivation(state: state, activation: activation, generation: generation)
                } catch {
                    if let operationError = error as? TelegramCore.WalletOperationError,
                       operationError == .requestPassword || operationError == .invalidPassword || operationError == .twoStepAuthMissing {
                        if !requestState.preserveCandidate {
                            try await self.runtime.retainReplacementForRetry(recordId: prepared.recordId)
                        }
                    } else {
                        if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                            self.preparedRecoveryPhraseImportRecordId = nil
                        }
                        if requestState.shouldDiscard(after: error) {
                            await self.discardReplacementForCleanup(recordId: prepared.recordId)
                        }
                    }
                    throw error
                }
            }
        }
    }

    func discardRecoveryPhraseImport(_ prepared: PreparedRecoveryPhraseImport) async throws {
        self.authorization.finish(self.preparedAuthorizations.removeValue(forKey: "import:" + prepared.recordId))
        guard !self.isShutdown else { throw WalletError.unavailable }
        if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
            self.preparedRecoveryPhraseImportRecordId = nil
        }
        try await self.runtime.discardReplacement(recordId: prepared.recordId, discardPersisted: false)
    }

    func enableBackup(expectedAddress: String, words suppliedWords: [String]?, session: PasscodeSession? = nil, operationId: UUID) async throws -> WalletInfo {
        return try await self.performOperation(.enablingBackup, operationId: operationId, session: session) {
            guard case let .wallet(info) = self.currentState.phase,
                  walletEngineAddressesEqual(info.address, expectedAddress),
                  info.canEnableBackup else {
                throw WalletError.unavailable
            }
            let generation = self.activationGeneration
            let authorizationSession = WalletAuthorizationScope.session
            let authorizationGeneration = try self.authorization.operationGeneration()
            func validateAuthorization() throws {
                try Task.checkCancellation()
                guard !self.isShutdown, self.activationGeneration == generation,
                      self.activeOperationId == operationId else { throw WalletError.unavailable }
                try self.authorization.validateGeneration(authorizationGeneration)
                if let authorizationSession { try self.authorization.validate(authorizationSession) }
            }

            var words: [String]
            if let suppliedWords {
                words = normalizedEngineMnemonic(suppliedWords)
            } else {
                guard info.canSign else { throw WalletError.walletKeyMismatch }
                guard try await self.runtime.keyRotationRecord() == nil else { throw WalletError.operationInProgress }
                words = normalizedEngineMnemonic(try await self.runtime.revealRecoveryPhrase())
            }
            defer { words.removeAll(keepingCapacity: false) }
            guard words.count == 12 || words.count == 24 else { throw WalletError.invalidMnemonic }
            let signingPublicKey = try walletMnemonicSigningPublicKey(words: words)
            let anchorPublicKey = try rotationMnemonicPublicKey(phrase: words.joined(separator: " "))
            try validateAuthorization()

            let refreshRevision = self.serverStateMutationRevision
            let freshState: TelegramCore.WalletState
            do {
                freshState = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(self.engine.wallet.getState())
            } catch is CancellationError {
                throw CancellationError()
            } catch { throw WalletError.network }
            try validateAuthorization()
            if self.serverStateMutationRevision == refreshRevision { self.applyServerWalletState(freshState) }
            guard case let .ready(backupEnabled, _, canEnableBackup, address, serverPublicKey, _)? =
                    self.deferredServerWalletState?.state ?? self.serverWalletState,
                  walletEngineAddressesEqual(address, expectedAddress) else { throw WalletError.unavailable }
            guard canEnableBackup || (backupEnabled && serverPublicKey == signingPublicKey) else {
                throw WalletError.backupNotAvailable
            }
            if suppliedWords == nil, signingPublicKey != serverPublicKey { throw WalletError.walletKeyMismatch }

            func currentState() throws -> TelegramCore.WalletState {
                try validateAuthorization()
                let serverState = self.serverWalletState
                guard let state = self.deferredServerWalletState?.state ?? serverState,
                      case let .ready(_, _, _, address, publicKey, _) = state,
                      walletEngineAddressesEqual(address, expectedAddress) else { throw WalletError.unavailable }
                guard publicKey == serverPublicKey || publicKey == signingPublicKey else { throw WalletError.walletKeyMismatch }
                return state
            }
            func isComplete(_ state: TelegramCore.WalletState) -> Bool {
                if case let .ready(backupEnabled, _, _, address, publicKey, _) = state {
                    return backupEnabled && walletEngineAddressesEqual(address, expectedAddress) && publicKey == signingPublicKey
                }
                return false
            }

            var candidate: WalletEngineStagedWallet?
            var preserveCandidate = false
            do {
                if suppliedWords != nil {
                    guard try await self.runtime.keyRotationRecord() == nil else { throw WalletError.operationInProgress }
                    let staged = try await self.runtime.stageTransientReplacement(words: words)
                    candidate = staged
                    guard walletEngineAddressesEqual(staged.address, expectedAddress),
                          staged.publicKey == anchorPublicKey, staged.signingPublicKey == signingPublicKey else {
                        throw WalletError.walletKeyMismatch
                    }
                    _ = try currentState()
                    try await self.runtime.persistReplacementCandidate(recordId: staged.recordId)
                }
                if !isComplete(try currentState()) {
                    let parts = try await encryptedWalletBackupParts(engine: self.engine, words: words)
                    _ = try await withWalletBackupRotationRetry { checkDeadline in
                        try await self.withWalletOwnershipProof(validate: {
                            _ = try currentState()
                            try checkDeadline()
                        }, sign: { challenge in
                            _ = try currentState()
                            return try await self.runtime.signOwnershipProof(
                                replacementRecordId: candidate?.recordId, expectedAnchorPublicKey: anchorPublicKey,
                                expectedSigningPublicKey: signingPublicKey,
                                domain: challenge.domain, timestamp: UInt64(challenge.timestamp), payload: challenge.payload
                            )
                        }, request: { proof in
                            let latest = try currentState()
                            if isComplete(latest) { return latest }
                            guard case let .ready(_, _, canEnableBackup, _, _, _) = latest, canEnableBackup else {
                                throw WalletError.backupNotAvailable
                            }
                            let revision = self.serverStateMutationRevision
                            let response: TelegramCore.WalletState
                            do {
                                response = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                                    self.engine.wallet.enableBackup(encryptedParts: parts, newPublicKey: signingPublicKey, proof: proof)
                                )
                            } catch let error as TelegramCore.WalletOperationError {
                                if error == .network { preserveCandidate = candidate != nil }
                                throw error
                            } catch {
                                preserveCandidate = candidate != nil
                                throw error
                            }
                            preserveCandidate = candidate != nil
                            if self.serverStateMutationRevision == revision { self.applyServerWalletState(response) }
                            return try currentState()
                        })
                    }
                }
                let state = try currentState()
                guard isComplete(state) else { throw WalletError.walletKeyMismatch }
                let revision = self.serverStateMutationRevision
                if let candidate {
                    preserveCandidate = true
                    let activationGeneration = await self.prepareForRuntimeIdentityChange(preserveCurrentWalletState: true)
                    let activation = try await self.runtime.commitReplacement(
                        recordId: candidate.recordId, serverAddress: expectedAddress,
                        serverPublicKey: signingPublicKey, serverStateRevision: revision
                    )
                    guard self.serverStateMutationRevision == revision, activation.canSign else { throw CancellationError() }
                    self.deferredServerWalletState = nil
                    return self.installRuntimeActivation(state: state, activation: activation, generation: activationGeneration, preserveCurrentWalletState: true)
                } else {
                    return self.installBackupEnabledState(state)
                }
            } catch {
                if let candidate, !preserveCandidate {
                    await self.discardReplacementForCleanup(recordId: candidate.recordId)
                }
                throw error
            }
        }
    }

    private func installBackupEnabledState(_ state: TelegramCore.WalletState) -> WalletInfo {
        self.deferredServerWalletState = (state, false, nil)
        guard case let .ready(backupEnabled, canExportPhrase, canEnableBackup, address, publicKey, _) = state else {
            preconditionFailure("Expected a verified wallet backup state")
        }
        return WalletInfo(address: address, publicKey: publicKey.walletHexString, backupEnabled: backupEnabled,
            canExportPhrase: canExportPhrase, canEnableBackup: canEnableBackup, canSign: true)
    }

    func prepareDisableBackup(updateSecretPhrase: Bool, session: PasscodeSession? = nil, operationId: UUID) async throws -> PreparedBackupDisable {
        if updateSecretPhrase, case let .wallet(wallet) = self.currentState.phase {
            _ = try await self.waitForPreviousWalletTransfer(wallet: wallet, generation: self.activationGeneration,
                operationId: operationId, expiresAt: currentWalletTimestamp() + 300, requireAuthorizationAvailable: session?.lifetime != .ownerManaged)
        }
        return try await self.performOperation(.preparingBackupDisable, operationId: operationId, session: session) {
            guard case let .wallet(info) = self.currentState.phase, info.canSign, info.backupEnabled else {
                throw WalletError.unavailable
            }
            if !updateSecretPhrase {
                guard try await self.runtime.keyRotationRecord() == nil else { throw WalletError.operationInProgress }
                let words = try await self.runtime.revealRecoveryPhrase()
                guard try walletMnemonicSigningPublicKey(words: words).walletHexString == info.publicKey else {
                    throw WalletError.storage(.identityMismatch)
                }
                return PreparedBackupDisable(
                    id: UUID().uuidString.lowercased(), walletAddress: info.address,
                    walletPublicKey: info.publicKey, words: words
                )
            }

            if let existing = try await self.runtime.keyRotationRecord() {
                guard walletEngineAddressesEqual(existing.walletAddress, info.address),
                      [existing.previousPublicKey.walletHexString, existing.newPublicKey.walletHexString].contains(info.publicKey),
                      existing.newPublicKey.count == 32, existing.validUntil <= UInt64(Int32.max) else {
                    throw WalletError.storage(.identityMismatch)
                }
                if existing.phase == .candidateStored || existing.phase == .previousRestored {
                    _ = try await self.runtime.resolveKeyRotation()
                } else {
                    if existing.phase == .submissionStarted {
                        do { _ = try await self.runtime.resolveKeyRotation() }
                        catch { self.logger.error("wallet_key_rotation_resolution_failed", error) }
                    }
                    if let current = try await self.runtime.keyRotationRecord() {
                        let words = try await self.runtime.keyRotationRecoveryPhrase(operationId: current.operationId)
                        guard words.count == 24 else { throw WalletError.invalidBackupData }
                        return PreparedBackupDisable(
                            id: current.operationId, walletAddress: info.address,
                            walletPublicKey: current.previousPublicKey.walletHexString,
                            words: words, newPublicKey: current.newPublicKey, signedBoc: "", seqno: 0,
                            expiresAt: Int32(current.validUntil), networkFeeNanograms: nil,
                            keyRotationPhase: current.phase == .chainApplied || current.phase == .backupDisabled ? .confirmed : .pending
                        )
                    }
                }
            }
            return try await self.prepareBackupDisableMaterial(id: UUID().uuidString.lowercased(), info: info)
        }
    }

    private func prepareBackupDisableMaterial(id: String, info: WalletInfo) async throws -> PreparedBackupDisable {
        let expiresAt = currentWalletTimestamp() + 300
        let prepared = try await self.runtime.prepareKeyRotation(validUntil: UInt64(expiresAt))
        let words = prepared.replacementRecoveryPhrase.phrase.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard words.count == 24, prepared.newPublicKey.count == 32,
              try walletMnemonicSigningPublicKey(words: words) == prepared.newPublicKey,
              prepared.validUntil == UInt64(expiresAt), !prepared.signedBoc.isEmpty else {
            throw WalletError.engine("Wallet engine returned invalid key-rotation material")
        }
        let preview = try await self.runtime.previewKeyRotation(
            operationId: id, signedBoc: prepared.signedBoc, seqno: prepared.seqno, validUntil: prepared.validUntil
        )
        guard preview.messageBocBase64 == prepared.signedBoc, preview.validUntil == prepared.validUntil,
              !preview.emulation.isIncomplete,
              let networkFeeNanograms = Int64(preview.emulation.walletFeesNanograms) else {
            throw WalletError.previewFailed
        }
        return PreparedBackupDisable(
            id: id, walletAddress: info.address, walletPublicKey: info.publicKey, words: words,
            newPublicKey: prepared.newPublicKey, signedBoc: prepared.signedBoc, seqno: prepared.seqno,
            expiresAt: expiresAt, networkFeeNanograms: networkFeeNanograms, keyRotationPhase: .prepared
        )
    }

    func refreshPreparedBackupDisable(_ prepared: PreparedBackupDisable, session: PasscodeSession? = nil, operationId: UUID) async throws -> PreparedBackupDisable {
        try await self.performOperation(.preparingBackupDisable, operationId: operationId, session: session) {
            try await self.refreshBackupDisableMaterial(prepared)
        }
    }

    private func backupDisableState(_ prepared: PreparedBackupDisable) throws -> TelegramCore.WalletState {
        guard let state = self.deferredServerWalletState?.state ?? self.serverWalletState,
              case let .ready(_, _, _, address, publicKey, _) = state,
              walletEngineAddressesEqual(address, prepared.walletAddress),
              publicKey.walletHexString == prepared.walletPublicKey || publicKey == prepared.rotation?.newPublicKey else {
            throw WalletError.storage(.identityMismatch)
        }
        return state
    }

    private func backupDisableIsComplete(_ state: TelegramCore.WalletState, prepared: PreparedBackupDisable) -> Bool {
        guard case let .ready(backupEnabled, _, _, address, publicKey, _) = state,
              !backupEnabled, walletEngineAddressesEqual(address, prepared.walletAddress) else { return false }
        if let rotation = prepared.rotation { return publicKey == rotation.newPublicKey }
        return publicKey.walletHexString == prepared.walletPublicKey
    }

    private func refreshBackupDisableMaterial(_ prepared: PreparedBackupDisable) async throws -> PreparedBackupDisable {
        let state = try self.backupDisableState(prepared)
        guard case let .wallet(info) = self.currentState.phase, info.canSign,
              walletEngineAddressesEqual(info.address, prepared.walletAddress) else { throw WalletError.unavailable }
        let signingKey = try walletMnemonicSigningPublicKey(words: prepared.words)
        guard let material = prepared.rotation else {
            guard signingKey.walletHexString == prepared.walletPublicKey,
                  try await self.runtime.keyRotationRecord() == nil else { throw WalletError.operationInProgress }
            return prepared
        }
        guard prepared.words.count == 24, signingKey == material.newPublicKey else { throw WalletError.invalidBackupData }
        if let rotation = try await self.runtime.keyRotationRecord() {
            guard rotation.operationId == prepared.id,
                  walletEngineAddressesEqual(rotation.walletAddress, prepared.walletAddress),
                  rotation.previousPublicKey.walletHexString == prepared.walletPublicKey,
                  rotation.newPublicKey == material.newPublicKey else {
                throw WalletError.storage(.identityMismatch)
            }
            return prepared
        }
        if self.backupDisableIsComplete(state, prepared: prepared) {
            guard try await self.runtime.revealRecoveryPhrase() == prepared.words else {
                throw WalletError.storage(.identityMismatch)
            }
            return prepared
        }
        guard material.phase == .prepared else { throw WalletError.operationInProgress }
        guard material.expiresAt > currentWalletTimestamp() else { throw WalletError.preparedBackupDisableExpired }
        let preview = try await self.runtime.previewKeyRotation(
            operationId: prepared.id, signedBoc: material.signedBoc, seqno: material.seqno,
            validUntil: UInt64(material.expiresAt)
        )
        guard preview.messageBocBase64 == material.signedBoc, preview.validUntil == UInt64(material.expiresAt),
              !preview.emulation.isIncomplete, let fee = Int64(preview.emulation.walletFeesNanograms) else {
            throw WalletError.previewFailed
        }
        if let balance = self.currentState.balance.currentValue, balance < fee {
            throw WalletError.insufficientBalance(required: fee)
        }
        return PreparedBackupDisable(
            id: prepared.id, walletAddress: prepared.walletAddress, walletPublicKey: prepared.walletPublicKey,
            words: prepared.words, newPublicKey: material.newPublicKey, signedBoc: material.signedBoc,
            seqno: material.seqno, expiresAt: material.expiresAt, networkFeeNanograms: fee, keyRotationPhase: material.phase
        )
    }

    private func refreshBackupDisableServerState(_ prepared: PreparedBackupDisable) async throws -> TelegramCore.WalletState {
        let revision = self.serverStateMutationRevision
        let state: TelegramCore.WalletState
        do {
            state = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(self.engine.wallet.getState())
        } catch { throw WalletError.network }
        if self.serverStateMutationRevision == revision { self.applyServerWalletState(state) }
        return try self.backupDisableState(prepared)
    }

    private func finishBackupDisable(_ prepared: PreparedBackupDisable) async throws -> WalletInfo {
        let state = try self.backupDisableState(prepared)
        guard self.backupDisableIsComplete(state, prepared: prepared) else { throw WalletError.invalidBackupData }
        let identity = try walletServerIdentity(state)
        let revision = self.serverStateMutationRevision
        self.serverStateNeedsActivation = true
        if prepared.rotation != nil {
            try await self.runtime.reconcileKeyRotation(
                serverAddress: identity.address, serverPublicKey: identity.publicKey,
                backupEnabled: false, serverStateRevision: revision
            )
        }
        let generation = await self.prepareForRuntimeIdentityChange(preserveCurrentWalletState: true)
        let activation = try await self.runtime.activate(
            serverAddress: identity.address, serverPublicKey: identity.publicKey, serverStateRevision: revision
        )
        let latest = try self.backupDisableState(prepared)
        guard self.backupDisableIsComplete(latest, prepared: prepared), activation.canSign else {
            throw WalletError.storage(.identityMismatch)
        }
        self.deferredServerWalletState = nil
        return self.installRuntimeActivation(
            state: latest, activation: activation, generation: generation, preserveCurrentWalletState: true
        )
    }

    func disableBackup(_ prepared: PreparedBackupDisable, password: String?, session: PasscodeSession? = nil, operationId: UUID) async throws -> WalletInfo {
        if prepared.rotation != nil, case let .wallet(wallet) = self.currentState.phase {
            _ = try await self.waitForPreviousWalletTransfer(wallet: wallet, generation: self.activationGeneration,
                operationId: operationId, expiresAt: currentWalletTimestamp() + 300, requireAuthorizationAvailable: session?.lifetime != .ownerManaged)
        }
        return try await self.performOperation(.disablingBackup, operationId: operationId, session: session) {
            let initialState = try self.backupDisableState(prepared)
            let signingPublicKey = try walletMnemonicSigningPublicKey(words: prepared.words)
            let proofPublicKey: Data
            if let rotation = prepared.rotation {
                guard signingPublicKey == rotation.newPublicKey else {
                    throw WalletError.storage(.identityMismatch)
                }
                proofPublicKey = signingPublicKey
            } else {
                guard signingPublicKey.walletHexString == prepared.walletPublicKey else {
                    throw WalletError.storage(.identityMismatch)
                }
                proofPublicKey = signingPublicKey
            }
            if self.backupDisableIsComplete(initialState, prepared: prepared) {
                return try await self.finishBackupDisable(prepared)
            }
            guard case let .wallet(info) = self.currentState.phase, info.canSign else { throw WalletError.unavailable }

            if let material = prepared.rotation {
                var rotation = try await self.runtime.keyRotationRecord()
                if rotation == nil {
                    let refreshed = try await self.refreshBackupDisableMaterial(prepared)
                    guard refreshed.networkFeeNanograms == prepared.networkFeeNanograms else {
                        throw WalletError.backupDisableNeedsConfirmation(refreshed)
                    }
                    guard material.expiresAt > currentWalletTimestamp() else { throw WalletError.preparedBackupDisableExpired }
                    let state = try self.backupDisableState(prepared)
                    if self.backupDisableIsComplete(state, prepared: prepared) {
                        return try await self.finishBackupDisable(prepared)
                    }
                    guard case let .ready(backupEnabled, _, _, _, publicKey, _) = state,
                          backupEnabled, publicKey.walletHexString == prepared.walletPublicKey,
                          material.phase == .prepared, !material.signedBoc.isEmpty else { throw WalletError.unavailable }
                    do {
                        let result = try await self.runtime.sendKeyRotation(
                            operationId: prepared.id, words: prepared.words,
                            previousPublicKey: publicKey, newPublicKey: material.newPublicKey,
                            signedBoc: material.signedBoc, seqno: material.seqno, validUntil: UInt64(material.expiresAt)
                        )
                        switch result.phase {
                        case .submitted, .submissionUnknown, .confirmed: break
                        default: throw WalletError.keyRotationFailed
                        }
                    } catch {
                        let sendError = error
                        self.logger.error("wallet_key_rotation_send_failed", sendError)
                        if let state = try? self.backupDisableState(prepared), self.backupDisableIsComplete(state, prepared: prepared) {
                            return try await self.finishBackupDisable(prepared)
                        }
                        if try await self.runtime.keyRotationRecord() == nil {
                            if sendError as? WalletError == .preparedBackupDisableExpired ||
                                walletKeyRotationPreparationIsExpired(sendError, seqno: material.seqno) {
                                throw WalletError.preparedBackupDisableExpired
                            }
                            throw WalletError.keyRotationFailed
                        }
                        throw sendError
                    }
                    rotation = try await self.runtime.keyRotationRecord()
                }
                guard let rotation, rotation.operationId == prepared.id,
                      walletEngineAddressesEqual(rotation.walletAddress, prepared.walletAddress),
                      rotation.previousPublicKey.walletHexString == prepared.walletPublicKey,
                      rotation.newPublicKey == material.newPublicKey else { throw WalletError.operationInProgress }
                let (deadline, overflow) = rotation.validUntil.addingReportingOverflow(120)
                guard !overflow else { throw WalletError.invalidBackupData }
                while true {
                    let state = try self.backupDisableState(prepared)
                    if self.backupDisableIsComplete(state, prepared: prepared) {
                        return try await self.finishBackupDisable(prepared)
                    }
                    let resolution = try await self.runtime.resolveKeyRotation()
                    switch resolution {
                    case let .confirmed(id):
                        guard id == prepared.id else { throw WalletError.operationInProgress }
                    case let .pending(id, retryAfterMilliseconds):
                        guard id == prepared.id else { throw WalletError.operationInProgress }
                        guard UInt64(max(0, Date().timeIntervalSince1970.rounded(.down))) <= deadline else {
                            throw WalletError.rotationNotFound
                        }
                        let delay = min(5_000, max(500, retryAfterMilliseconds ?? 1_000))
                        try await Task.sleep(nanoseconds: delay * 1_000_000)
                        continue
                    case .rolledBack: throw WalletError.keyRotationFailed
                    case .none:
                        let latest = try self.backupDisableState(prepared)
                        if self.backupDisableIsComplete(latest, prepared: prepared) {
                            return try await self.finishBackupDisable(prepared)
                        }
                        throw WalletError.operationInProgress
                    }
                    break
                }
            } else {
                _ = try await self.refreshBackupDisableMaterial(prepared)
            }

            do {
                _ = try await self.withWalletOwnershipProof(sign: { challenge in
                    _ = try self.backupDisableState(prepared)
                    let signature = try await self.runtime.signBackupDisableProof(
                        expectedAddress: prepared.walletAddress, expectedPublicKey: proofPublicKey,
                        rotationOperationId: prepared.rotation == nil ? nil : prepared.id,
                        domain: challenge.domain, timestamp: UInt64(challenge.timestamp), payload: challenge.payload
                    )
                    _ = try self.backupDisableState(prepared)
                    return signature
                }, request: { proof in
                    let latest = try self.backupDisableState(prepared)
                    if self.backupDisableIsComplete(latest, prepared: prepared) { return latest }
                    let revision = self.serverStateMutationRevision
                    let response = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                        self.engine.wallet.disableBackup(password: password, newPublicKey: proofPublicKey, proof: proof)
                    )
                    if self.serverStateMutationRevision == revision { self.applyServerWalletState(response) }
                    return try self.backupDisableState(prepared)
                })
                return try await self.finishBackupDisable(prepared)
            } catch {
                let failure = error
                if let state = try? await self.refreshBackupDisableServerState(prepared),
                   self.backupDisableIsComplete(state, prepared: prepared) {
                    return try await self.finishBackupDisable(prepared)
                }
                throw failure
            }
        }
    }

    func beginCommentEncryptionSession(operationId: UUID) async throws -> PasscodeSession {
        guard !self.isShutdown,
              case let .wallet(info) = self.currentState.phase, info.canSign else {
            throw WalletError.unavailable
        }
        let generation = self.activationGeneration
        let session = try await self.authorization.beginSession(id: operationId, reason: "Encrypt wallet comment")
        do {
            try Task.checkCancellation()
            guard !self.isShutdown, self.activationGeneration == generation else { throw WalletError.unavailable }
            try self.authorization.validate(session)
            return session
        } catch {
            self.authorization.finish(session)
            throw error
        }
    }

    func adoptCommentEncryptionSession(_ prepared: PreparedTransfer) throws -> PasscodeSession? {
        try Task.checkCancellation()
        guard !self.isShutdown, prepared.commentEncrypted,
              case let .wallet(info) = self.currentState.phase,
              var record = self.preparedTransfers[prepared.id], record.transfer == prepared,
              record.walletAddress == info.address, record.sessionId == nil else { return nil }
        let existing = self.preparedAuthorizations.removeValue(forKey: "transfer:" + prepared.id)
        guard let session = try self.authorization.adoptSession(existing) else { return nil }
        record.sessionId = session.id
        self.preparedTransfers[prepared.id] = record
        return session
    }

    func discardCommentEncryptionTransfer(_ prepared: PreparedTransfer, sessionId: UUID?) {
        guard let record = self.preparedTransfers[prepared.id], record.transfer == prepared,
              record.sessionId == sessionId else { return }
        self.discardPreparedTransfer(prepared)
    }

    func prepareTransfer(
        address: String,
        amount: Int64,
        sendAll: Bool,
        comment: String?,
        commentEncrypted: Bool,
        recipientPublicKey: Data? = nil,
        session: PasscodeSession? = nil,
        pendingRegistration: WalletContext.PendingTransferRegistration? = nil,
        estimatedFee: Int64? = nil,
        operationId: UUID
    ) async throws -> PreparedTransfer {
        let resolved = try resolveTransferInput(address: address, amount: amount, comment: comment)
        let encryptComment = commentEncrypted && resolved.comment?.isEmpty == false
        let activationGeneration = self.activationGeneration
        var encryptionPublicKey = recipientPublicKey
        if encryptComment, let comment = resolved.comment {
            guard comment.utf8.count <= 960 else { throw WalletError.commentTooLong }
            guard !self.isShutdown, case let .wallet(info) = self.currentState.phase, info.canSign else {
                throw WalletError.unavailable
            }
            if encryptionPublicKey == nil {
                do {
                    encryptionPublicKey = try await WalletSignalRequestContext<Data?>().run(
                        self.engine.wallet.getUserAddresses(addresses: [resolved.address], force: false)
                        |> map { addresses -> Data? in
                            addresses.first(where: { walletEngineAddressesEqual($0.address, resolved.address) })?.publicKey
                        }
                    )
                } catch let error as CancellationError {
                    throw error
                } catch {
                    try Task.checkCancellation()
                    self.logger.error("wallet_comment_recipient_key_lookup_failed", error)
                }
            }
            try Task.checkCancellation()
            guard !self.isShutdown, self.activationGeneration == activationGeneration else { throw WalletError.unavailable }
            do {
                _ = try await self.runtime.resolveEncryptedCommentRecipient(recipient: resolved.address, recipientPublicKey: encryptionPublicKey)
            } catch {
                try Task.checkCancellation()
                self.logger.error("wallet_comment_recipient_resolution_failed", error)
                throw walletCommentEncryptionError(error)
            }
        }
        try Task.checkCancellation()
        guard !self.isShutdown, self.activationGeneration == activationGeneration else { throw WalletError.unavailable }
        let resolvedRecipientPublicKey = encryptionPublicKey
        return try await self.performOperation(.preparingTransfer, operationId: operationId, requiresAuthorization: encryptComment, session: session) {
            guard !self.isShutdown, self.activationGeneration == activationGeneration,
                  case let .wallet(info) = self.currentState.phase,
                  info.canSign else {
                throw WalletError.unavailable
            }
            if let pendingRegistration {
                try self.validatePendingTransferRegistration(
                    pendingRegistration, session: session, address: resolved.address, amount: resolved.amount,
                    sendAll: sendAll && !resolved.hasLinkAmount, comment: resolved.comment, commentEncrypted: commentEncrypted
                )
            }
            self.requestGaslessInfo()
            let body: SendMessageBody
            if encryptComment, let comment = resolved.comment {
                let boc: String
                do {
                    boc = try await self.runtime.createEncryptedComment(
                        recipient: resolved.address,
                        comment: comment,
                        recipientPublicKey: resolvedRecipientPublicKey
                    )
                } catch {
                    try Task.checkCancellation()
                    self.logger.error("wallet_comment_encryption_failed", error)
                    throw walletCommentEncryptionError(error)
                }
                try Task.checkCancellation()
                guard let data = Data(base64Encoded: boc) else {
                    throw WalletError.commentEncryptionFailed
                }
                guard data.count <= 1024 else {
                    throw WalletError.commentTooLong
                }
                body = .rawPayload(boc: boc)
            } else {
                body = resolved.body
            }
            let feesAreCovered = WalletContext.useWalletTransferApi
                && !WalletContext.isSelfTransfer(recipient: resolved.address, walletAddress: info.address)
                && WalletContext.isGaslessEligible(amount: resolved.amount, gaslessInfo: self.currentState.gaslessInfo.currentValue, minimumAmount: self.transferGaslessMinAmount)
            let resolvedSendAll = sendAll && !resolved.hasLinkAmount && !feesAreCovered
            let sendAmount: SendAmount = resolvedSendAll
                ? .all
                : .exact(nanograms: String(resolved.amount))
            let intent = SendIntent(
                expiration: resolved.expiration,
                messages: [resolved.destination.message(amount: sendAmount, body: body)]
            )
            try Task.checkCancellation()
            guard !self.isShutdown, self.activationGeneration == activationGeneration else { throw WalletError.unavailable }
            let canUseEstimatedFee: Bool
            switch body {
            case .empty, .comment:
                canUseEstimatedFee = true
            case .rawPayload:
                canUseEstimatedFee = encryptComment
            }
            let fee: Int64
            let expiresAt: Int32
            if WalletContext.useWalletTransferApi, !resolvedSendAll, canUseEstimatedFee,
               case .engineDefault = resolved.expiration,
               let estimatedFee, estimatedFee >= 0,
               let balance = self.currentState.balance.currentValue,
               resolved.amount <= balance,
               feesAreCovered || (resolved.amount < balance && estimatedFee < balance - resolved.amount) {
                fee = estimatedFee
                // Bound the local request; signing still obtains fresh chain state and its own validUntil.
                expiresAt = Int32(clamping: Int64(currentWalletTimestamp()) + 300)
            } else {
                // External-message emulation requires funds for fees. Estimate with zero value
                // when gasless covers them; the signed intent keeps the exact requested amount.
                let previewIntent = feesAreCovered ? SendIntent(
                    expiration: resolved.expiration,
                    messages: [resolved.destination.message(amount: .exact(nanograms: "0"), body: body)]
                ) : intent
                let preview: SendPreview
                do {
                    preview = try await self.runtime.previewSend(intent: previewIntent)
                } catch {
                    try Task.checkCancellation()
                    guard !self.isShutdown, self.activationGeneration == activationGeneration else { throw WalletError.unavailable }
                    guard walletPreviewNeedsSeqnoRetry(error) else { throw error }
                    self.logger.log("event=wallet_preview_seqno_retry operation_id=\(operationId.uuidString.lowercased()) error_code=133 retry_delay_ms=1000")
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    try Task.checkCancellation()
                    guard !self.isShutdown, self.activationGeneration == activationGeneration else { throw WalletError.unavailable }
                    preview = try await self.runtime.previewSend(intent: previewIntent)
                }
                try Task.checkCancellation()
                guard !self.isShutdown, self.activationGeneration == activationGeneration else { throw WalletError.unavailable }
                guard !preview.emulation.isIncomplete else { throw WalletError.previewIncomplete }
                guard let previewFee = Int64(preview.emulation.walletFeesNanograms) else { throw WalletError.previewFailed }
                fee = previewFee
                expiresAt = Int32(clamping: preview.validUntil)
            }
            let effectiveAmount: Int64
            if resolvedSendAll {
                guard fee < resolved.amount else {
                    throw WalletError.insufficientBalance(required: resolved.amount)
                }
                effectiveAmount = resolved.amount - fee
            } else {
                if let balance = self.currentState.balance.currentValue,
                   resolved.amount > balance || (!feesAreCovered && fee > balance - resolved.amount) {
                    let (required, overflow) = resolved.amount.addingReportingOverflow(fee)
                    throw WalletError.insufficientBalance(required: overflow ? Int64.max : required)
                }
                effectiveAmount = resolved.amount
            }
            let transfer = PreparedTransfer(
                id: pendingRegistration?.id ?? UUID().uuidString.lowercased(),
                recipient: resolved.address,
                amount: effectiveAmount,
                requestedAmount: resolved.amount,
                isSendAll: resolvedSendAll,
                comment: resolved.comment,
                commentEncrypted: encryptComment,
                fee: fee,
                expiresAt: expiresAt
            )
            if let pendingRegistration {
                let encryptedComment: String?
                if encryptComment, case let .rawPayload(boc) = body { encryptedComment = boc }
                else { encryptedComment = nil }
                try await self.updateRegisteredPendingTransfer(pendingRegistration, prepared: transfer, encryptedComment: encryptedComment)
            }
            self.preparedTransfers[transfer.id] = PreparedEngineTransferRecord(
                walletAddress: info.address,
                transfer: transfer,
                request: .send(intent),
                sessionId: session?.id
            )
            self.removeExpiredPreparedTransfers()
            return transfer
        }
    }

    func decryptTransactionComment(
        _ transaction: WalletContext.Transaction,
        operationId: UUID
    ) async throws -> String {
        try await self.performOperation(.decryptingComment, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase, info.canSign else {
                throw WalletError.unavailable
            }
            guard transaction.commentEncrypted,
                  let encryptedComment = transaction.comment,
                  let body = encryptedCommentBoc(encryptedComment) else {
                throw WalletError.commentDecryptionFailed
            }
            let sender: String
            switch transaction.direction {
            case .incoming:
                guard let address = transaction.peer.address else { throw WalletError.commentDecryptionFailed }
                sender = address
            case .outgoing:
                sender = info.address
            case .unknown:
                throw WalletError.commentDecryptionFailed
            }
            let activationGeneration = self.activationGeneration
            let comment: String
            do {
                comment = try await self.runtime.decryptComment(sender: sender, body: body)
            } catch {
                try Task.checkCancellation()
                self.logger.error("wallet_comment_decryption_failed", error)
                throw WalletError.commentDecryptionFailed
            }
            try Task.checkCancellation()
            guard self.activationGeneration == activationGeneration else { throw WalletError.unavailable }
            return comment
        }
    }

    func prepareCollectibleTransfer(
        address: String,
        collectible: Collectible,
        comment: String?,
        operationId: UUID
    ) async throws -> PreparedTransfer {
        return try await self.performOperation(.preparingTransfer, operationId: operationId) {
            guard case let .wallet(info) = self.currentState.phase, info.canSign else {
                throw WalletError.unavailable
            }
            guard let recipient = normalizedMainnetAddress(address),
                  let nft = normalizedMainnetAddress(collectible.address) else {
                throw WalletError.invalidAddress
            }
            let normalizedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
            let payload: NftTransferPayload = normalizedComment?.isEmpty == false
                ? .comment(text: normalizedComment!)
                : .empty
            let intent = NftTransferIntent(
                nftAddress: nft,
                recipient: recipient,
                funding: .exact(attachedNanograms: "100000001", forwardNanograms: "1"),
                payload: payload,
                expiration: .engineDefault
            )
            let id = UUID().uuidString.lowercased()
            let preview = try await self.runtime.previewNft(operationId: id, intent: intent)
            try Task.checkCancellation()
            guard !preview.emulation.isIncomplete else { throw WalletError.previewIncomplete }
            guard let fee = Int64(preview.emulation.walletFeesNanograms) else { throw WalletError.previewFailed }
            let transfer = PreparedTransfer(
                id: id,
                recipient: recipient,
                amount: 0,
                comment: normalizedComment?.isEmpty == false ? normalizedComment : nil,
                collectible: collectible,
                fee: fee,
                expiresAt: Int32(clamping: preview.validUntil)
            )
            self.preparedTransfers[id] = PreparedEngineTransferRecord(
                walletAddress: info.address,
                transfer: transfer,
                request: .nft(intent)
            )
            self.removeExpiredPreparedTransfers()
            return transfer
        }
    }

    func submitTransfer(
        _ prepared: PreparedTransfer,
        recipientPeerId: EnginePeer.Id? = nil,
        pendingMessageCreated: (@MainActor @Sendable () -> Void)? = nil,
        session: PasscodeSession? = nil,
        operationId: UUID,
        control: WalletTransferSubmissionControl,
        stageUpdated: (@MainActor @Sendable (WalletContext.TransferSubmissionStage) -> Void)? = nil
    ) async throws -> PendingTransfer {
        let generation = self.activationGeneration
        guard case let .wallet(wallet) = self.currentState.phase else { throw WalletError.unavailable }
        let requireAuthorizationAvailable = session?.lifetime != .ownerManaged
        let authorizationGeneration = try self.authorization.operationGeneration(requireAvailable: requireAuthorizationAvailable)
        await stageUpdated?(.waitingForPreviousTransfer)
        try await self.transferSubmissionCoordinator.acquire(operationId)
        let submission: WalletTransferSubmission
        do {
            while true {
                try self.authorization.validateGeneration(authorizationGeneration, requireAvailable: requireAuthorizationAvailable)
                let allowResolvedWithoutChainCheck: Bool
                if WalletContext.useWalletTransferApi, let record = self.preparedTransfers[prepared.id], case .send = record.request {
                    allowResolvedWithoutChainCheck = true
                } else {
                    allowResolvedWithoutChainCheck = false
                }
                let minimumSeqno = try await self.waitForPreviousWalletTransfer(wallet: wallet, generation: generation,
                    operationId: operationId, expiresAt: prepared.expiresAt, requireAuthorizationAvailable: requireAuthorizationAvailable,
                    allowResolvedWithoutChainCheck: allowResolvedWithoutChainCheck)
                try Task.checkCancellation()
                await stageUpdated?(.signing)
                do {
                    submission = try await self.prepareTransferSubmission(prepared, recipientPeerId: recipientPeerId, pendingMessageCreated: pendingMessageCreated, session: session, operationId: operationId, control: control, minimumSeqno: minimumSeqno)
                    break
                } catch WalletTransferSubmissionError.staleSequenceNumber {
                    await stageUpdated?(.waitingForPreviousTransfer)
                    try await self.transferSubmissionClock.sleep(1_000_000_000)
                }
            }
        } catch {
            await self.transferSubmissionCoordinator.release(operationId)
            if let registration = self.pendingTransferRegistrations[prepared.id]?.registration {
                self.discardPendingTransferRegistration(registration)
            }
            throw error
        }
        await self.transferSubmissionCoordinator.release(operationId)
        await stageUpdated?(.submitted)
        switch submission {
        case let .completed(pending): return pending
        case let .api(submission):
            self.logger.log("event=wallet_transfer_wallet_released operation_id=\(prepared.id) elapsed_ms=\(Int((ProcessInfo.processInfo.systemUptime - submission.startedAt) * 1000.0))")
            return try await self.finishWalletApiSubmission(submission)
        }
    }

    private func prepareTransferSubmission(
        _ prepared: PreparedTransfer,
        recipientPeerId: EnginePeer.Id?,
        pendingMessageCreated: (@MainActor @Sendable () -> Void)?,
        session: PasscodeSession?,
        operationId: UUID,
        control: WalletTransferSubmissionControl,
        minimumSeqno: UInt32?
    ) async throws -> WalletTransferSubmission {
        if let session {
            guard let record = self.preparedTransfers[prepared.id],
                  record.transfer == prepared, record.sessionId == session.id else { throw PasscodeError.staleAuthorization }
            try self.authorization.validate(session, boundTo: record.sessionId)
        } else if self.preparedTransfers[prepared.id]?.sessionId != nil {
            throw PasscodeError.authenticationRequired
        }
        return try await self.performOperation(.submittingTransfer, operationId: operationId, authorizationId: "transfer:" + prepared.id, session: session) {
            guard case let .wallet(info) = self.currentState.phase,
                  info.canSign,
                  let record = self.preparedTransfers[prepared.id],
                  record.walletAddress == info.address,
                  record.transfer == prepared else {
                throw WalletError.preparedTransferNotFound
            }
            guard prepared.expiresAt > currentWalletTimestamp() else {
                self.preparedTransfers[prepared.id] = nil
                throw WalletError.preparedTransferExpired
            }
            let pendingComment: String?
            if prepared.commentEncrypted {
                guard case let .send(intent) = record.request,
                      let message = intent.messages.first,
                      case let .rawPayload(boc) = message.body else {
                    throw WalletError.preparedTransferNotFound
                }
                pendingComment = boc
            } else {
                pendingComment = prepared.comment
            }
            let activationGenerationBeforeSend = self.activationGeneration
            let registration = self.pendingTransferRegistrations[prepared.id]
            if let registration {
                guard registration.peerId == recipientPeerId,
                      registration.registration.sessionId == session?.id,
                      self.isCurrentPendingTransferRegistration(registration.registration) else { throw WalletError.unavailable }
            }
            let createdAt = registration?.pending.createdAt ?? currentWalletTimestamp()
            let randomId = registration?.randomId ?? Int64.random(in: Int64.min ... Int64.max)
            let pendingMessage: WalletPendingTransferMessageReference?
            if let registration {
                pendingMessage = registration.pending.pendingMessage
            } else if let recipientPeerId, prepared.collectible == nil, WalletContext.useWalletTransferApi {
                pendingMessage = try await WalletSignalRequestContext<WalletPendingTransferMessageReference?>().run(
                    self.engine.wallet.createPendingTransferMessage(
                        peerId: recipientPeerId,
                        operationId: prepared.id,
                        randomId: randomId,
                        amount: prepared.amount,
                        address: prepared.recipient,
                        comment: pendingComment,
                        commentEncrypted: prepared.commentEncrypted,
                        timestamp: createdAt
                    )
                    |> castError(WalletError.self)
                )
            } else {
                pendingMessage = nil
            }
            guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == activationGenerationBeforeSend else {
                if let pendingMessage {
                    let _ = self.engine.wallet.removePendingTransferMessage(pendingMessage).start()
                }
                throw WalletError.unavailable
            }
            let expectedGasless: Bool
            if WalletContext.useWalletTransferApi, case .send = record.request,
               !WalletContext.isSelfTransfer(recipient: prepared.recipient, walletAddress: info.address) {
                expectedGasless = WalletContext.isGaslessEligible(
                    amount: prepared.amount,
                    gaslessInfo: self.currentState.gaslessInfo.currentValue,
                    minimumAmount: self.transferGaslessMinAmount
                )
            } else {
                expectedGasless = false
            }
            let pending = PendingTransfer(
                id: prepared.id,
                recipient: prepared.recipient,
                amount: prepared.amount,
                comment: pendingComment,
                commentEncrypted: prepared.commentEncrypted,
                collectibleAddress: prepared.collectible?.address,
                expectedGasless: expectedGasless,
                pendingMessage: pendingMessage,
                fee: prepared.fee,
                uiExpiresAt: registration == nil ? nil : walletPendingTransferUIExpirationTimestamp(from: currentWalletTimestamp()),
                createdAt: createdAt,
                status: .broadcasting
            )
            if WalletContext.useWalletTransferApi, case let .send(intent) = record.request {
                let submission = try await self.beginWalletApiSubmission(
                    prepared: prepared,
                    intent: intent,
                    pending: pending,
                    recipientPeerId: recipientPeerId,
                    randomId: randomId,
                    walletAddress: record.walletAddress,
                    generation: activationGenerationBeforeSend,
                    control: control,
                    minimumSeqno: minimumSeqno,
                    pendingRegistration: registration?.registration,
                    registrationSession: registration?.session
                )
                if pendingMessage != nil { await pendingMessageCreated?() }
                return .api(submission)
            }
            self.stopPendingTransferRegistration(prepared.id)
            self.refreshRegisteredTransferMessage(pending)
            var values = self.currentState.pendingTransfers.filter { $0.id != pending.id }
            values.append(pending)
            self.replaceState(
                phase: self.currentState.phase,
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: values,
                activeOperation: self.currentState.activeOperation
            )
            try control.commit()
            let clientRevisionBeforeSend = await self.runtime.currentClientRevision()

            let applyAcceptedSubmission: (SendPhase, String?) -> PendingTransfer? = { phase, messageHash in
                guard self.activationGeneration == activationGenerationBeforeSend,
                      case let .wallet(currentInfo) = self.currentState.phase,
                      walletEngineAddressesEqual(currentInfo.address, record.walletAddress),
                      let accepted = acceptedWalletTransferSubmission(
                    pending: pending,
                    messageHash: messageHash,
                    phase: phase,
                    acceptedAt: currentWalletTimestamp()
                ) else {
                    return nil
                }
                var updated = self.currentState.pendingTransfers.filter { $0.id != accepted.id }
                updated.append(accepted)
                self.preparedTransfers[prepared.id] = nil
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: updated,
                    activeOperation: self.currentState.activeOperation
                )
                if phase != .submitted || accepted.collectibleAddress != nil || self.streamingConnectionState != .subscribed {
                    self.requestSynchronization(scope: accepted.collectibleAddress == nil ? [.account, .transactions] : .all, force: true)
                }
                return accepted
            }

            do {
                let execution: WalletEngineSendExecution
                switch record.request {
                case let .send(intent):
                    execution = try await self.runtime.send(operationId: pending.id, intent: intent)
                case let .nft(intent):
                    execution = try await self.runtime.sendNft(operationId: prepared.id, intent: intent)
                }
                if execution.didRecreateClient {
                    await self.rebindRuntimeObservationAfterClientRecreation(
                        previousClientRevision: clientRevisionBeforeSend,
                        activationGeneration: activationGenerationBeforeSend,
                        walletAddress: record.walletAddress
                    )
                }
                let result = execution.result
                guard let submitted = applyAcceptedSubmission(result.phase, result.messageHash) else {
                    if walletEngineSendPhaseIsTerminal(result.phase) {
                        self.preparedTransfers[prepared.id] = nil
                        if let pendingMessage = pending.pendingMessage {
                            let _ = self.engine.wallet.removePendingTransferMessage(pendingMessage).start()
                        }
                        throw WalletError.preparedTransferNotFound
                    }
                    throw WalletError.engine("wallet-engine send ended in \(result.phase)")
                }
                return .completed(submitted)
            } catch {
                self.logger.error("wallet_send_failed", error)
                var preparedTransferWasInvalidated = false
                let snapshot: WalletSnapshot?
                do {
                    snapshot = try await self.runtime.snapshot()
                } catch {
                    self.logger.error("wallet_send_recovery_snapshot_failed", error)
                    snapshot = nil
                }
                if let snapshot {
                    await self.rebindRuntimeObservationAfterClientRecreation(
                        previousClientRevision: clientRevisionBeforeSend,
                        activationGeneration: activationGenerationBeforeSend,
                        walletAddress: record.walletAddress,
                        snapshot: snapshot
                    )
                    if snapshot.send.operationId == pending.id,
                       let submitted = applyAcceptedSubmission(snapshot.send.phase, nil) {
                        return .completed(submitted)
                    }
                    if snapshot.send.operationId == pending.id,
                       walletEngineSendPhaseIsTerminal(snapshot.send.phase) {
                        self.preparedTransfers[prepared.id] = nil
                        preparedTransferWasInvalidated = true
                    }
                }
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers.filter { $0.id != pending.id },
                    activeOperation: self.currentState.activeOperation
                )
                if preparedTransferWasInvalidated {
                    if let pendingMessage = pending.pendingMessage {
                        let _ = self.engine.wallet.removePendingTransferMessage(pendingMessage).start()
                    }
                    throw WalletError.preparedTransferNotFound
                }
                throw error
            }
        }
    }

    func discardPreparedTransfer(_ prepared: PreparedTransfer) {
        self.authorization.finish(self.preparedAuthorizations.removeValue(forKey: "transfer:" + prepared.id))
        guard let record = self.preparedTransfers[prepared.id], record.transfer == prepared else {
            return
        }
        self.preparedTransfers[prepared.id] = nil
        self.resumeDeferredSynchronizationIfNeeded()
    }

    func rebindRuntimeObservationAfterClientRecreation(
        previousClientRevision: UInt64,
        activationGeneration: UInt64,
        walletAddress: String,
        snapshot suppliedSnapshot: WalletSnapshot? = nil
    ) async {
        let currentClientRevision = await self.runtime.currentClientRevision()
        guard currentClientRevision != previousClientRevision,
              self.activationGeneration == activationGeneration,
              case let .wallet(info) = self.currentState.phase,
              walletEngineAddressesEqual(info.address, walletAddress) else {
            return
        }
        do {
            let snapshot: WalletSnapshot
            if let suppliedSnapshot {
                snapshot = suppliedSnapshot
            } else {
                snapshot = try await self.runtime.snapshot()
            }
            self.beginObserving(snapshot: snapshot, generation: activationGeneration)
        } catch {
            self.logger.error("wallet_engine_client_rebind_failed", error)
        }
    }

    func loadMoreTransactions(operationId: UUID) async throws {
        try await self.performOperation(.loadingMoreTransactions, operationId: operationId) {
            guard self.currentState.transactions.canLoadMore,
                  self.transactionHistory.nextPageRequest != nil else { return Void() }
            let generation = self.activationGeneration
            let streamingOverlayWatermark = self.streamingPresentationOverlay.revision
            self.updateTransactionsPagination(isLoadingMore: true, error: nil)
            do {
                try await loadWalletTransactionHistoryPages(nextRequest: {
                    try self.checkPaginationOperation(operationId, generation: generation)
                    return self.transactionHistory.nextPageRequest
                }, fetch: { offset in
                    let response = try await WalletSignalRequestContext<TelegramCore.WalletTransactions>().run(
                        self.engine.wallet.getTransactions(
                            inbound: true,
                            outbound: true,
                            offset: offset,
                            limit: Int32(walletTransactionFetchLimit)
                        )
                    )
                    return WalletTransactionHistory.Page(
                        items: walletTransactions(from: response.items),
                        nextOffset: response.nextOffset
                    )
                }, apply: { request, page in
                    try self.checkPaginationOperation(operationId, generation: generation)
                    let result = self.transactionHistory.applyPage(
                        page, request: request, previous: self.currentState.transactions, log: self.logger.log
                    )
                    let historyReconciliation = self.pendingTransfers(
                        self.currentState.pendingTransfers,
                        reconcilingWith: result.state.items
                    )
                    let removedStreamingTraceCount = self.streamingPresentationOverlay.clearTransactions(
                        through: streamingOverlayWatermark,
                        presentIn: result.state.items,
                        resolvedTraceIds: historyReconciliation.resolvedStreamingTraceIds
                    )
                    self.logPendingTransferHistoryReconciliation(
                        historyReconciliation,
                        removedStreamingTraceCount: removedStreamingTraceCount
                    )
                    let previousState = self.currentState
                    self.replaceState(
                        phase: self.currentState.phase,
                        balance: self.currentState.balance,
                        transactions: result.state,
                        pendingTransfers: historyReconciliation.pendingTransfers,
                        activeOperation: self.currentState.activeOperation
                    )
                    if removedStreamingTraceCount != 0 && self.currentState == previousState {
                        self.publishPresentationState()
                    }
                    return result.shouldContinue
                })
            } catch {
                guard self.isCurrentPaginationOperation(operationId, generation: generation) else {
                    throw CancellationError()
                }
                let isCancelled = Task.isCancelled || error is CancellationError
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.transactionHistory.failed(
                        isCancelled ? CancellationError() : error,
                        previous: self.currentState.transactions,
                        pagination: true
                    ),
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
                if isCancelled { throw CancellationError() }
                throw error
            }
        }
    }

    func loadMoreCollectibles(operationId: UUID) async throws {
        try await self.performOperation(.loadingMoreCollectibles, operationId: operationId) {
            guard let pageId = self.currentState.collectibles.nextPage,
                  !self.currentState.collectibles.isRefreshing,
                  !self.currentState.collectibles.isLoadingMore else { return Void() }
            let generation = self.activationGeneration
            let observationId = self.runtimeObservationId
            let request = WalletSignalRequestContext<WalletNfts>()
            self.collectiblesPaginationRequest = request
            defer {
                if self.collectiblesPaginationRequest === request {
                    self.collectiblesPaginationRequest = nil
                }
            }
            self.updateCollectiblesPagination(isLoadingMore: true, error: nil)
            do {
                guard self.canUseNetworkRuntime else { throw WalletError.network }
                let page = try await request.run(self.engine.wallet.getNfts(
                    offset: pageId.offset, limit: walletCollectiblesFetchLimit
                ))
                try self.checkPaginationOperation(operationId, generation: generation)
                guard self.runtimeObservationId == observationId,
                      self.currentState.collectibles.acceptsPage(pageId) else { throw CancellationError() }
                self.replaceCollectibles(try self.currentState.collectibles.applying(page, offset: pageId.offset, refresh: false))
            } catch {
                guard self.isCurrentPaginationOperation(operationId, generation: generation),
                      self.runtimeObservationId == observationId,
                      self.currentState.collectibles.acceptsPage(pageId) else { throw CancellationError() }
                let failure: Error = Task.isCancelled ? CancellationError() : error
                self.replaceCollectibles(self.currentState.collectibles.failing(failure))
                throw failure
            }
        }
    }
}

@available(macOS 10.15, *)
extension WalletContextImpl {
    private func isCurrentPaginationOperation(_ operationId: UUID, generation: UInt64) -> Bool {
        !self.isShutdown
            && self.activationGeneration == generation
            && self.activeOperationId == operationId
    }

    private func checkPaginationOperation(_ operationId: UUID, generation: UInt64) throws {
        try Task.checkCancellation()
        guard self.isCurrentPaginationOperation(operationId, generation: generation) else {
            throw CancellationError()
        }
    }

    private func updateTransactionsPagination(isLoadingMore: Bool, error: SynchronizationError?) {
        let transactions = self.currentState.transactions
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: TransactionsState(
                items: transactions.items,
                offset: transactions.offset,
                canLoadMore: transactions.canLoadMore,
                isLoadingMore: isLoadingMore,
                error: error
            ),
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
    }

    private func updateCollectiblesPagination(isLoadingMore: Bool, error: SynchronizationError?) {
        let collectibles = self.currentState.collectibles
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            collectibles: CollectiblesState(
                items: collectibles.items,
                nextOffset: collectibles.nextOffset,
                generation: collectibles.generation,
                isRefreshing: collectibles.isRefreshing,
                isLoadingMore: isLoadingMore,
                error: error
            ),
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
    }

    func discardReplacementForCleanup(recordId: String, discardPersisted: Bool = true) async {
        await Task { [runtime = self.runtime, logger = self.logger] in
            do {
                try await runtime.discardReplacement(recordId: recordId, discardPersisted: discardPersisted)
            } catch {
                logger.error("wallet_replacement_cleanup_failed", error)
            }
        }.value
    }

    func prepareForRuntimeIdentityChange(
        preserveCurrentWalletState: Bool = false
    ) async -> UInt64 {
        if !preserveCurrentWalletState {
            self.resetPendingTransferExpiration(clearSuppressedTraceIds: true)
            self.outgoingTransactionPresentationIdentities.removeAll()
        }
        self.clearStreamingPresentationOverlay()
        self.streamingRefreshTracker = WalletStreamingRefreshTracker()
        self.discardPendingTransferRegistrations()
        self.activationGeneration &+= 1
        let generation = self.activationGeneration
        self.activationTask?.cancel()
        self.activationTask = nil
        self.observationTask?.cancel()
        self.observationTask = nil
        self.cancelSynchronization()
        self.stopStreaming()
        self.cancelWalletStateFallbackRefresh()
        self.preparedTransfers.removeAll()
        self.deferredSynchronizationScope = []
        return generation
    }

    @discardableResult
    func installRuntimeActivation(
        state: TelegramCore.WalletState,
        activation: WalletEngineActivation,
        generation: UInt64,
        preserveCurrentWalletState: Bool = false
    ) -> WalletInfo {
        let identity: (backupEnabled: Bool, canExportPhrase: Bool, canEnableBackup: Bool, address: String, publicKey: Data, balance: Int64)
        switch state {
        case let .ready(backupEnabled, canExportPhrase, canEnableBackup, address, publicKey, balance):
            identity = (backupEnabled, canExportPhrase, canEnableBackup, address, publicKey, balance)
        case .empty:
            preconditionFailure("A runtime activation requires a ready server wallet")
        }
        self.serverStateMutationRevision &+= 1
        self.serverStateNeedsActivation = false
        self.serverWalletState = state
        let info = WalletInfo(
            address: identity.address,
            publicKey: identity.publicKey.map { String(format: "%02x", $0) }.joined(),
            backupEnabled: identity.backupEnabled,
            canExportPhrase: identity.canExportPhrase,
            canEnableBackup: identity.canEnableBackup,
            canSign: activation.canSign
        )
        if !preserveCurrentWalletState {
            self.transactionHistory.reset()
        }
        self.replaceState(
            phase: .wallet(info),
            balance: .value(identity.balance, updatedAt: currentWalletTimestamp()),
            transactions: preserveCurrentWalletState
                ? self.currentState.transactions
                : TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
            collectibles: preserveCurrentWalletState ? self.currentState.collectibles : .empty,
            pendingTransfers: preserveCurrentWalletState ? self.currentState.pendingTransfers : [],
            activeOperation: self.currentState.activeOperation
        )
        self.beginObserving(snapshot: activation.snapshot, generation: generation)
        if !preserveCurrentWalletState {
            self.pendingScreenSynchronizationScope.formUnion(self.visibleScreenSynchronizationScope)
        }
        if self.hasActiveWalletRefreshDemand {
            self.deferredSynchronizationScope.formUnion([.account, .transactions])
        }
        self.resumeDeferredSynchronizationIfNeeded()
        return info
    }

    func performOperation<Value: Sendable>(
        _ activeOperation: ActiveOperation,
        operationId: UUID,
        requiresAuthorization: Bool? = nil,
        authorizationId: String? = nil,
        session borrowedSession: PasscodeSession? = nil,
        _ operation: () async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()
        if let borrowedSession {
            try await borrowedSession.waitUntilAvailable()
            try self.authorization.validate(borrowedSession)
        }
        guard !self.isShutdown else {
            throw WalletError.unavailable
        }
        guard self.currentState.activeOperation == nil else {
            self.logger.error(
                "wallet_operation_rejected",
                WalletError.operationInProgress,
                context: "operation=\(activeOperation)"
            )
            throw WalletError.operationInProgress
        }
        switch activeOperation {
        case .preparingTransfer, .submittingTransfer, .tonConnect, .decryptingComment:
            if !self.activeSynchronizationScope.isEmpty {
                self.deferredSynchronizationScope.formUnion(self.activeSynchronizationScope.subtracting(self.pendingScreenSynchronizationScope))
                self.cancelSynchronization()
            }
        case .creating, .importing, .recoveringPhrase, .preparingRecoveryPhraseImport,
             .completingRecoveryPhraseImport, .enablingBackup, .preparingBackupDisable,
             .disablingBackup, .loadingMoreTransactions, .loadingMoreCollectibles:
            break
        }
        let initialActivationGeneration = self.activationGeneration
        self.activeOperationId = operationId
        let changesWalletLocally = activeOperation == .creating
            || activeOperation == .importing
            || activeOperation == .completingRecoveryPhraseImport
            || activeOperation == .enablingBackup
        if changesWalletLocally {
            self.isChangingWalletLocally = true
        }
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: activeOperation
        )
        var operationCompleted = false
        defer {
            if self.activationGeneration != initialActivationGeneration {
                self.authorization.invalidate(preservingResultFor: operationId)
                self.preparedAuthorizations.removeAll()
            }
            if self.activeOperationId == operationId {
                self.activeOperationId = nil
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: self.currentState.balance,
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: nil
                )
                if activeOperation.defersServerWalletState {
                    if (activeOperation == .disablingBackup || activeOperation == .recoveringPhrase || !operationCompleted),
                       let deferred = self.deferredServerWalletState {
                        self.applyServerWalletState(deferred.state, refreshIfStreamingUnavailable: deferred.refreshIfStreamingUnavailable,
                            balanceOverlayRevision: deferred.balanceOverlayRevision)
                    } else {
                        self.applyCompatibleDeferredServerWalletState()
                    }
                    self.requestServerWalletState(forceRefreshAfterCurrent: true)
                }
                self.resumeDeferredSynchronizationIfNeeded()
                self.scheduleAutomaticPhraseRecoveryIfNeeded()
            }
            if changesWalletLocally {
                self.isChangingWalletLocally = false
            }
        }
        let needsAuthorization: Bool
        switch activeOperation {
        case .loadingMoreTransactions, .loadingMoreCollectibles, .preparingTransfer:
            needsAuthorization = false
        default:
            needsAuthorization = true
        }
        var session = borrowedSession
        let authorizationGeneration = borrowedSession != nil || (requiresAuthorization ?? needsAuthorization)
            ? try self.authorization.operationGeneration(requireAvailable: borrowedSession?.lifetime != .ownerManaged) : nil
        if let borrowedSession {
            try self.authorization.validate(borrowedSession)
        } else if let authorizationId, let existing = self.preparedAuthorizations.removeValue(forKey: authorizationId) {
            if (try? self.authorization.validate(existing)) != nil { session = existing }
            else { self.authorization.finish(existing) }
        }
        if session == nil, requiresAuthorization ?? needsAuthorization {
            session = try await self.authorization.authorize(id: operationId, reason: String(describing: activeOperation))
        }
        var retained = false
        defer { if borrowedSession == nil && !retained { self.authorization.finish(session) } }
        if activeOperation == .submittingTransfer {
            if let authorizationGeneration {
                try self.authorization.validateGeneration(authorizationGeneration, requireAvailable: session?.lifetime != .ownerManaged)
            }
            if let session { try self.authorization.validate(session) }
        }
        let result = try await self.authorization.withSession(session) { try await operation() }
        do {
            if activeOperation != .submittingTransfer {
                try Task.checkCancellation()
                let requireAvailable = session?.lifetime != .ownerManaged
                if let authorizationGeneration {
                    try self.authorization.validateGeneration(authorizationGeneration, requireAvailable: requireAvailable)
                }
                if let session { try self.authorization.validate(session, requireAvailable: requireAvailable) }
            }
        } catch {
            if let prepared = result as? PreparedTransfer {
                self.discardPreparedTransfer(prepared)
            } else if let prepared = result as? PreparedRecoveryPhraseImport {
                if self.preparedRecoveryPhraseImportRecordId == prepared.recordId {
                    self.preparedRecoveryPhraseImportRecordId = nil
                }
                await self.discardReplacementForCleanup(recordId: prepared.recordId, discardPersisted: false)
            }
            throw error
        }
        if borrowedSession == nil, let session {
            let flowId: String?
            if let prepared = result as? PreparedTransfer { flowId = "transfer:" + prepared.id }
            else { flowId = nil }
            if let flowId {
                self.authorization.finish(self.preparedAuthorizations.updateValue(session, forKey: flowId))
                retained = true
            }
        }
        operationCompleted = true
        return result
    }

    func removeExpiredPreparedTransfers() {
        let now = currentWalletTimestamp()
        for (id, record) in self.preparedTransfers where record.transfer.expiresAt <= now {
            self.authorization.finish(self.preparedAuthorizations.removeValue(forKey: "transfer:" + id))
        }
        self.preparedTransfers = self.preparedTransfers.filter { $0.value.transfer.expiresAt > now }
    }

    var isTransferFlowBlockingSynchronization: Bool {
        if !self.preparedTransfers.isEmpty {
            return true
        }
        switch self.currentState.activeOperation {
        case .preparingTransfer, .submittingTransfer, .tonConnect, .decryptingComment:
            return true
        case .none, .creating, .importing, .recoveringPhrase, .preparingRecoveryPhraseImport,
             .completingRecoveryPhraseImport, .enablingBackup, .preparingBackupDisable,
             .disablingBackup, .loadingMoreTransactions, .loadingMoreCollectibles:
            return false
        }
    }

    func resumeDeferredSynchronizationIfNeeded() {
        let scope = self.deferredSynchronizationScope.union(self.pendingScreenSynchronizationScope)
            .subtracting(self.activeSynchronizationScope)
        guard !scope.isEmpty, !self.isTransferFlowBlockingSynchronization else { return }
        self.requestSynchronization(scope: scope)
    }
}

@available(macOS 10.15, *)
private func normalizedMainnetAddress(_ input: String, preserveBounce: Bool = false) -> String? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    let address: String
    if trimmed.lowercased().hasPrefix("ton://") {
        guard let value = try? parseTonTransferLink(value: trimmed) else { return nil }
        address = value.recipient
    } else {
        address = trimmed
    }
    guard let destination = try? WalletTransferDestination(address) else { return nil }
    if preserveBounce || !destination.bounce {
        return destination.address
    }
    return try? convertTonAddress(
        value: address,
        format: .userFriendly(bounceable: false, testnet: false)
    )
}

@available(macOS 10.15, *)
private func encryptedCommentBoc(_ comment: String) -> String? {
    guard let data = Data(base64Encoded: comment), !data.isEmpty, data.count <= 1024 else {
        return nil
    }
    let bocMagic: [UInt8] = [0xb5, 0xee, 0x9c, 0x72]
    if data.starts(with: bocMagic) {
        return comment
    }

    let opcode: [UInt8] = [0x21, 0x67, 0xda, 0x4b]
    let hasOpcode = data.starts(with: opcode) && data.count % 16 == 4
    let payload = Array(data.dropFirst(hasOpcode ? opcode.count : 0))
    guard payload.count >= 64, (payload.count - 48) % 16 == 0 else {
        return nil
    }

    var chunks: [[UInt8]] = [opcode + Array(payload.prefix(35))]
    for offset in stride(from: 35, to: payload.count, by: 127) {
        chunks.append(Array(payload[offset ..< min(offset + 127, payload.count)]))
    }
    var cells = Data()
    for (index, chunk) in chunks.enumerated() {
        let hasNext = index + 1 < chunks.count
        cells.append(hasNext ? 1 : 0)
        cells.append(UInt8(chunk.count * 2))
        cells.append(contentsOf: chunk)
        if hasNext {
            cells.append(UInt8(index + 1))
        }
    }

    let offsetBytes: UInt8 = cells.count > 255 ? 2 : 1
    var boc = Data(bocMagic + [0x01, offsetBytes, UInt8(chunks.count), 1, 0])
    if offsetBytes == 2 {
        boc.append(UInt8(cells.count >> 8))
    }
    boc.append(UInt8(cells.count & 0xff))
    boc.append(0)
    boc.append(cells)
    return boc.base64EncodedString()
}

@available(macOS 10.15, *)
final class WalletOperationTaskRegistry {
    private let lock = NSLock()
    private var operations: [UUID: WalletOperationCancellation] = [:]
    private var isShutdown = false

    func register(id: UUID, cancellation: WalletOperationCancellation) {
        self.lock.lock()
        if self.isShutdown {
            self.lock.unlock()
            cancellation.cancel()
        } else {
            self.operations[id] = cancellation
            self.lock.unlock()
        }
    }

    func remove(id: UUID) {
        self.lock.lock()
        self.operations[id] = nil
        self.lock.unlock()
    }

    func cancel(id: UUID) {
        self.lock.lock()
        let cancellation = self.operations.removeValue(forKey: id)
        self.lock.unlock()
        cancellation?.cancel()
    }

    func shutdown() {
        self.lock.lock()
        self.isShutdown = true
        let operations = Array(self.operations.values)
        self.operations.removeAll()
        self.lock.unlock()
        for operation in operations {
            operation.cancel()
        }
    }
}

@available(macOS 10.15, *)
final class WalletOperationCancellation {
    private let lock = NSLock()
    private var task: Task<Void, Never>?
    private var cancelled = false
    func setTask(_ value: Task<Void, Never>) {
        self.lock.lock()
        if self.cancelled {
            self.lock.unlock()
            value.cancel()
        } else {
            self.task = value
            self.lock.unlock()
        }
    }
    func cancel() {
        self.lock.lock()
        self.cancelled = true
        let task = self.task
        self.task = nil
        self.lock.unlock()
        task?.cancel()
    }
}

@available(macOS 10.15, *)
private extension Data {
    var walletHexString: String { self.map { String(format: "%02x", $0) }.joined() }
}
