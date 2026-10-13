import PasscodeCore
import Foundation
import SwiftSignalKit
import TelegramCore
import Postbox
import WalletEngineFFI

let walletFiatRatesRefreshInterval: TimeInterval = 15 * 60

@available(macOS 10.15, *)
actor WalletContextImpl {
    typealias FiatCurrency = WalletContext.FiatCurrency
    typealias FiatRate = WalletContext.FiatRate
    typealias FiatState = WalletContext.FiatState
    typealias WalletInfo = WalletContext.WalletInfo
    typealias FatalStorageError = WalletContext.FatalStorageError
    typealias SynchronizationError = WalletContext.SynchronizationError
    typealias Resource<Value: Equatable & Sendable> = WalletContext.Resource<Value>
    typealias Transaction = WalletContext.Transaction
    typealias TransactionsState = WalletContext.TransactionsState
    typealias Collectible = WalletContext.Collectible
    typealias CollectiblesState = WalletContext.CollectiblesState
    typealias PendingTransfer = WalletContext.PendingTransfer
    typealias PreparedBackupDisable = WalletContext.PreparedBackupDisable
    typealias PreparedRecoveryPhraseImport = WalletContext.PreparedRecoveryPhraseImport
    typealias ActiveOperation = WalletContext.ActiveOperation
    typealias Phase = WalletContext.Phase
    typealias State = WalletContext.State
    typealias WalletError = WalletContext.WalletError
    typealias ResolvedTransferRecipient = WalletContext.ResolvedTransferRecipient
    typealias PreparedTransfer = WalletContext.PreparedTransfer

    enum PreparedEngineTransfer {
        case send(SendIntent)
        case nft(NftTransferIntent)
    }

    struct PreparedEngineTransferRecord {
        let walletAddress: String
        let transfer: PreparedTransfer
        let request: PreparedEngineTransfer
        var sessionId: UUID? = nil
    }

    struct PendingTransferHistoryReconciliation {
        let pendingTransfers: [PendingTransfer]
        let resolvedStreamingTraceIds: Set<String>
        let removedPendingCount: Int
    }

    struct OutgoingTransactionPresentationIdentity {
        let presentationId: String
        var traceId: String?
        var transactionHash: String?
        let pendingTransfer: PendingTransfer
    }

    let authorization: WalletAuthorizationContext
    let engine: TelegramEngine
    let logger: WalletLogger
    let storage: WalletEngineStorage
    let runtime: WalletEngineRuntime
    let streamingURLProvider: WalletStreamingURLProvider
    let storedStateWriter: WalletStoredStateWriter
    let output: WalletContextOutput
    
    var currentState: State
    var transferMinAmount = WalletConfiguration.defaultValue.transferMinAmount
    var transferGaslessMinAmount = WalletConfiguration.defaultValue.transferGaslessMinAmount
    
    var storedState = WalletStoredState()
    var serverWalletState: TelegramCore.WalletState?
    var isChangingWalletLocally = false
    var pendingInitialServerWalletState: (state: TelegramCore.WalletState, refreshIfStreamingUnavailable: Bool)?
    var deferredServerWalletState: (state: TelegramCore.WalletState, refreshIfStreamingUnavailable: Bool, balanceOverlayRevision: UInt64?)?
    var serverStateRefreshRequested = false
    var serverStateMutationRevision: UInt64 = 0
    var serverStateNeedsActivation = false
    
    var transactionHistory = WalletTransactionHistory()
    var preparedTransfers: [String: PreparedEngineTransferRecord] = [:]
    var pendingTransferRegistrations: [String: WalletPendingTransferRegistrationRecord] = [:]
    var outgoingTransactionPresentationIdentities: [String: OutgoingTransactionPresentationIdentity] = [:]
    
    var preparedAuthorizations: [String: PasscodeSession] = [:]
    
    var preparedRecoveryPhraseImportRecordId: String?
    var peerByWalletAddress: [String: EnginePeer] = [:]
    
    var isStoredStateRestored = false
    var isApplicationInForeground = false
    var isAccountCurrent = false
    var isNetworkAvailable = false
    var stateSubscriberCount = 0
    var screenDemand = WalletScreenDemand()
    var walletScreenCount: Int { self.screenDemand.walletCount }
    var hasGaslessInfoDemand: Bool { self.walletScreenCount > 0 || !self.screenDemand.gaslessInfoRequests.isEmpty }
    var pendingBalanceRequests = Set<UUID>()
    var pendingScreenSynchronizationScope: WalletSynchronizationScope = []
    var latestEnvironmentRevision: UInt64 = 0
    var latestWalletConfigurationRevision: UInt64 = 0
    var latestWalletStateRevision: UInt64 = 0
    var latestSubscriberDemandRevision: UInt64 = 0
    var latestFiatCurrencyRevision: UInt64 = 0
    var activeOperationId: UUID?
    let transferSubmissionCoordinator = WalletTransferSubmissionCoordinator()
    var transferSubmissionClock = WalletTransferSubmissionClock()
    var transferSubmissions = WalletTransferSubmissionRegistry()
    var isShutdown = false
    var previousWalletBalancesLastAttemptAt: TimeInterval?
    var previousWalletBalancesTask: Task<[WalletContext.PreviousWallet], Error>?
    var serverStateTask: Task<Void, Never>?
    var activationTask: Task<Void, Never>?
    
    var deferredSynchronizationScope: WalletSynchronizationScope = []
    var synchronizationTask: Task<Void, Never>?
    var synchronizationTaskId: UUID?
    var synchronizationGate = WalletSynchronizationRequestGate()
    
    var runtimeObservationId = UUID()
    var observationTask: Task<Void, Never>?
    var serverStateRetryTask: Task<Void, Never>?
            
    var pollingTask: Task<Void, Never>?
    var pollingTaskId: UUID?
    
    var walletStateFallbackRefreshTask: Task<Void, Never>?
    var walletStateFallbackRefreshTaskId: UUID?
    
    var pendingTransferExpirationTask: Task<Void, Never>?
    var pendingTransferExpirationTaskId: UUID?
    var pendingTransferExpirationDeadline: Int32?
    
    var walletTransferResolutions: [String: WalletTransferResolution] = [:]
    var walletTransferHashStates: [String: WalletTransferHashState] = [:]
    var walletTransferResolutionTask: Task<Void, Never>?
    var walletTransferResolutionScheduledAt: Int32?
    
    var fiatRefreshTask: Task<Void, Never>?
    var fiatRefreshTaskId: UUID?
    
    var gaslessInfoTask: Task<Void, Never>?
    var gaslessInfoTaskId: UUID?
    var gaslessQuotaRevision: UInt64 = 0
    
    var streamingClient: WalletToncenterStreamingClient?
    var streamingTask: Task<Void, Never>?
    var streamingRefreshTask: Task<Void, Never>?
    var streamingRefreshTaskId: UUID?
    var streamingRefreshScope: WalletSynchronizationScope = []
    var streamingAddress: String?
    var streamingGeneration: UInt64?
    var streamingConnectionState: WalletStreamingConnectionState = .inactive
    var streamingHasSubscribed = false
    var streamingPresentationOverlay = WalletStreamingPresentationOverlay()
    var streamingRefreshTracker = WalletStreamingRefreshTracker()
    var expiredPendingStreamingTraceIds = Set<String>()
    
    var activationGeneration: UInt64 = 0
    var automaticPhraseRecoveryAttemptIdentity: (address: String, publicKey: Data)?
    
    var balanceLastSuccessfulAt: Int32?
    var fiatLastSuccessfulAt: Int32?
    
    var storedStateMutationRevision: UInt64 = 0
    
    var collectiblesSynchronizationTask: Task<Void, Never>?
    var collectiblesSynchronizationTaskId: UUID?
    var collectiblesSynchronizationGate = WalletSynchronizationRequestGate()
    var collectiblesPaginationRequest: WalletSignalRequestContext<WalletNfts>?

    var tonConnectSessions: [Int64: WalletTonConnectSession] = [:]
    var tonConnectSessionRevisions: [Int64: UInt64] = [:]
    var tonConnectRevision: UInt64 = 0
    var tonConnectEpoch: UInt64 = 0
    var tonConnectQueue: [TonConnectPendingInteraction] = []
    var tonConnectActive: TonConnectPendingInteraction?
    var tonConnectHandledRequests = Set<TonConnectMessageKey>()
    var tonConnectProvenSessions = Set<Int64>()
    var tonConnectPendingDisconnects = Set<Int64>()
    var tonConnectDisconnectBodies: [Int64: Data] = [:]
    var tonConnectSessionErrors: [Int64: TonConnectFailure] = [:]
    var tonConnectDiagnostic: TonConnectDiagnostic?
    var tonConnectPreparationTask: Task<Void, Never>?
    var tonConnectRefreshTask: Task<Void, Never>?
    var tonConnectWalletIdentity: String?
    var tonConnectWasAvailable = false

    init(
        engine: TelegramEngine,
        storageNamespace: String,
        authorization: WalletAuthorizationContext,
        initialState: State,
        output: WalletContextOutput,
        logger: WalletLogger
    ) {
        self.authorization = authorization
        let storage = WalletEngineStorage(namespace: storageNamespace)
        self.engine = engine
        self.logger = logger
        self.storage = storage
        self.output = output
        self.runtime = WalletEngineRuntime(engine: engine, storage: storage, logger: logger)
        self.storedStateWriter = WalletStoredStateWriter(engine: engine)
        self.streamingURLProvider = WalletStreamingURLProvider(engine: engine, logger: logger)
        self.currentState = initialState
    }

    func shutdown() async {
        guard !self.isShutdown else { return }
        self.discardPendingTransferRegistrations()
        self.isShutdown = true
        self.resetTonConnect()
        self.authorization.invalidate()
        self.preparedAuthorizations.removeAll()
        self.streamingRefreshTracker = WalletStreamingRefreshTracker()
        self.activationGeneration &+= 1
        if let activeOperationId = self.activeOperationId {
            self.output.cancelOperation(id: activeOperationId)
            self.activeOperationId = nil
        }
        self.stateSubscriberCount = 0
        self.screenDemand = WalletScreenDemand()
        self.previousWalletBalancesTask?.cancel()
        self.serverStateTask?.cancel()
        self.activationTask?.cancel()
        self.synchronizationTask?.cancel()
        self.collectiblesSynchronizationTask?.cancel()
        self.collectiblesPaginationRequest?.cancel()
        self.collectiblesPaginationRequest = nil
        self.observationTask?.cancel()
        self.serverStateRetryTask?.cancel()
        self.pollingTask?.cancel()
        self.walletStateFallbackRefreshTask?.cancel()
        self.pendingTransferExpirationTask?.cancel()
        self.cancelWalletTransferResolution()
        self.cancelFiatRatesRefresh()
        self.gaslessInfoTask?.cancel()
        self.streamingTask?.cancel()
        self.streamingRefreshTask?.cancel()
        await self.streamingClient?.stop()
        await self.storedStateWriter.shutdown()
        await self.runtime.shutdown()
    }

    func updateEnvironment(
        foreground: Bool,
        accountIsCurrent: Bool,
        networkAvailable: Bool,
        revision: UInt64
    ) {
        guard !self.isShutdown else { return }
        guard revision > self.latestEnvironmentRevision else { return }
        let wasNetworkUsable = self.canUseNetworkRuntime
        let becameForeground = foreground && !self.isApplicationInForeground
        self.latestEnvironmentRevision = revision
        self.isApplicationInForeground = foreground
        self.isAccountCurrent = accountIsCurrent
        self.isNetworkAvailable = networkAvailable
        if !accountIsCurrent {
            self.discardPendingTransferRegistrations()
            self.authorization.invalidate()
            self.preparedAuthorizations.removeAll()
            if let recordId = self.preparedRecoveryPhraseImportRecordId {
                self.preparedRecoveryPhraseImportRecordId = nil
                Task { await self.discardReplacementForCleanup(recordId: recordId, discardPersisted: false) }
            }
        }
        if becameForeground {
            self.pendingScreenSynchronizationScope.formUnion(self.visibleScreenSynchronizationScope)
        }
        self.evaluateRuntimeDemand(refreshIfPollingBecomesActive: !wasNetworkUsable)
        self.updateTonConnectEnvironment(refresh: becameForeground || (!wasNetworkUsable && self.canUseNetworkRuntime))
    }

    func updateWalletConfiguration(_ configuration: WalletConfiguration, revision: UInt64) {
        guard !self.isShutdown else { return }
        guard revision > self.latestWalletConfigurationRevision else { return }
        self.latestWalletConfigurationRevision = revision
        self.transferMinAmount = configuration.transferMinAmount
        self.transferGaslessMinAmount = configuration.transferGaslessMinAmount
    }

    private func hasAttemptedAutomaticPhraseRecovery(address: String, publicKey: Data) -> Bool {
        guard let attempted = self.automaticPhraseRecoveryAttemptIdentity else { return false }
        return walletEngineAddressesEqual(attempted.address, address) && attempted.publicKey == publicKey
    }

    func scheduleAutomaticPhraseRecoveryIfNeeded() {
        guard (try? walletProtectionSettings().enabled) == false else { return }
        guard self.currentState.activeOperation == nil,
              case let .wallet(info) = self.currentState.phase,
              !info.canSign,
              info.canExportPhrase,
              let serverWalletState = self.serverWalletState,
              case let .ready(_, _, _, address, publicKey, _) = serverWalletState,
              walletEngineAddressesEqual(info.address, address),
              info.publicKey == publicKey.map({ String(format: "%02x", $0) }).joined(),
              !self.hasAttemptedAutomaticPhraseRecovery(address: address, publicKey: publicKey) else {
            return
        }
        self.applyServerWalletState(serverWalletState, forceActivation: true)
    }

    func receiveServerWalletState(_ value: TelegramCore.WalletState, revision: UInt64) {
        guard !self.isShutdown else { return }
        guard revision > self.latestWalletStateRevision else { return }
        self.latestWalletStateRevision = revision
        guard self.isStoredStateRestored else {
            self.pendingInitialServerWalletState = (value, true)
            return
        }
        self.applyServerWalletState(value, refreshIfStreamingUnavailable: true, balanceOverlayRevision: self.streamingPresentationOverlay.revision)
    }

    func updateStateSubscriberDemand(count: Int, revision: UInt64) {
        guard !self.isShutdown else { return }
        guard revision > self.latestSubscriberDemandRevision else { return }
        self.latestSubscriberDemandRevision = revision
        self.stateSubscriberCount = max(0, count)
        self.evaluateRuntimeDemand()
    }

    var visibleScreenSynchronizationScope: WalletSynchronizationScope {
        var scope = self.screenDemand.visibleScope
        if !self.pendingBalanceRequests.isEmpty {
            scope.insert(.account)
        }
        return scope
    }

    func updateWalletScreenDemand(_ demand: WalletScreenDemand) {
        guard !self.isShutdown, demand.revision > self.screenDemand.revision else { return }
        let openedScope = demand.openedScope(since: self.screenDemand)
        let hasNewGaslessInfoRequests = !demand.gaslessInfoRequests.subtracting(self.screenDemand.gaslessInfoRequests).isEmpty
        let newBalanceRequests = demand.balanceRequests.subtracting(self.screenDemand.balanceRequests)
        self.pendingBalanceRequests.formUnion(newBalanceRequests)
        self.pendingBalanceRequests.formIntersection(demand.balanceRequests)
        self.screenDemand = demand
        self.pendingScreenSynchronizationScope.formUnion(openedScope)
        self.pendingScreenSynchronizationScope.formIntersection(self.visibleScreenSynchronizationScope)
        if openedScope.contains(.transactions) || hasNewGaslessInfoRequests {
            self.requestGaslessInfo()
        }
        self.requestSynchronization(scope: openedScope)
        self.evaluateRuntimeDemand()
    }

    func restoreStoredState(_ storedState: WalletStoredState?, removeInvalidEntry: Bool) async {
        guard !self.isShutdown else { return }
        if removeInvalidEntry {
            self.logger.log("event=wallet_stored_state_invalid")
            self.storedStateMutationRevision &+= 1
            await self.storedStateWriter.remove(revision: self.storedStateMutationRevision)
        }
        guard let storedState else {
            self.completeStoredStateRestore()
            return
        }
        for pending in storedState.pendingTransfers where pending.isPreparing {
            if let message = pending.pendingMessage {
                let _ = self.engine.wallet.removePendingTransferMessage(message).startStandalone()
            }
        }
        var cachedTransactions: [Transaction]
        do {
            cachedTransactions = try await walletTransactions(
                from: storedState.transactions,
                engine: self.engine
            )
        } catch is CancellationError {
            return
        } catch {
            self.logger.error("wallet_stored_state_peer_restore_failed", error)
            cachedTransactions = storedState.transactions.map { $0.transaction(peers: [:]) }
        }
        guard !Task.isCancelled, !self.isShutdown else {
            return
        }
        guard case .restoring = self.currentState.phase, self.serverWalletState == nil else {
            self.completeStoredStateRestore()
            return
        }
        self.storedState = storedState
        self.balanceLastSuccessfulAt = storedState.balanceUpdatedAt
        self.fiatLastSuccessfulAt = storedState.fiatRatesUpdatedAt
        cachedTransactions = mergeTransactions(
            existing: cachedTransactions, new: [], source: "cache_restore", log: self.logger.log
        )
        let restoredState = State(
            phase: .restoring,
            balance: storedState.balance.map { .value($0, updatedAt: storedState.balanceUpdatedAt ?? 0) } ?? .idle,
            transactions: TransactionsState(
                items: Array(cachedTransactions.prefix(walletTransactionFetchLimit)),
                offset: cachedTransactions.count,
                canLoadMore: false,
                isLoadingMore: false,
                error: nil
            ),
            collectibles: CollectiblesState(
                items: Array(storedState.collectibles.prefix(walletTransactionFetchLimit)),
                nextOffset: nil,
                isLoadingMore: false,
                error: nil
            ),
            pendingTransfers: storedState.pendingTransfers.filter { !$0.isPreparing }.map(walletPendingTransferAfterRestart),
            activeOperation: nil,
            fiat: FiatState(
                selectedCurrency: storedState.selectedFiatCurrency,
                rates: storedState.fiatRates.map { .value($0, updatedAt: storedState.fiatRatesUpdatedAt ?? 0) } ?? .idle
            )
        )
        if self.pendingInitialServerWalletState != nil {
            self.currentState = restoredState
        } else {
            self.replaceState(
                phase: restoredState.phase,
                balance: restoredState.balance,
                transactions: restoredState.transactions,
                collectibles: restoredState.collectibles,
                pendingTransfers: restoredState.pendingTransfers,
                activeOperation: restoredState.activeOperation,
                fiat: restoredState.fiat
            )
        }
        self.completeStoredStateRestore()
    }

    private func completeStoredStateRestore() {
        self.isStoredStateRestored = true
        if let pendingInitialServerWalletState = self.pendingInitialServerWalletState {
            self.pendingInitialServerWalletState = nil
            self.applyServerWalletState(
                pendingInitialServerWalletState.state,
                refreshIfStreamingUnavailable: pendingInitialServerWalletState.refreshIfStreamingUnavailable
            )
        }
        self.evaluateRuntimeDemand(refreshIfPollingBecomesActive: true)
    }

    func evaluateRuntimeDemand(refreshIfPollingBecomesActive: Bool = false) {
        self.evaluateStreamingDemand()
        self.evaluatePollingDemand(refreshIfBecomingActive: refreshIfPollingBecomesActive)
        self.evaluateWalletTransferResolution()
        self.evaluateFiatRatesDemand()
        guard self.canUseNetworkRuntime else {
            self.cancelGaslessInfoRequest()
            self.pendingScreenSynchronizationScope.formUnion(
                self.activeSynchronizationScope.intersection(self.visibleScreenSynchronizationScope)
            )
            self.cancelSynchronization()
            self.serverStateRetryTask?.cancel()
            self.serverStateRetryTask = nil
            self.cancelWalletStateFallbackRefresh()
            return
        }
        self.resumeDeferredSynchronizationIfNeeded()
        if self.needsServerWalletStateRefresh {
            self.requestServerWalletState()
        }
        if refreshIfPollingBecomesActive, self.hasGaslessInfoDemand {
            self.requestGaslessInfo()
        }
    }

    var canUseNetworkRuntime: Bool {
        !self.isShutdown
            && self.isStoredStateRestored
            && self.isApplicationInForeground
            && self.isAccountCurrent
            && self.isNetworkAvailable
    }

    private var needsServerWalletStateRefresh: Bool {
        (self.serverWalletState == nil || self.serverStateNeedsActivation)
            && self.currentState.activeOperation?.defersServerWalletState != true
    }

    func requestServerWalletState(forceRefreshAfterCurrent: Bool = false) {
        guard self.canUseNetworkRuntime else { return }
        if self.serverStateTask != nil {
            if forceRefreshAfterCurrent {
                self.serverStateRefreshRequested = true
            }
            return
        }
        self.serverStateTask = Task { [weak self] in
            await self?.performServerWalletStateRequest()
        }
    }

    private func performServerWalletStateRequest() async {
        let revision = self.serverStateMutationRevision
        let walletStateRevision = self.latestWalletStateRevision
        let generation = self.activationGeneration
        let balanceOverlayRevision = self.streamingPresentationOverlay.revision
        defer {
            self.serverStateTask = nil
            if self.serverStateRefreshRequested {
                self.serverStateRefreshRequested = false
                self.requestServerWalletState()
            }
        }
        do {
            let value = try await WalletSignalRequestContext<TelegramCore.WalletState>().run(
                self.engine.wallet.getState()
            )
            try Task.checkCancellation()
            guard !self.isShutdown,
                  self.serverStateMutationRevision == revision,
                  self.latestWalletStateRevision == walletStateRevision,
                  self.activationGeneration == generation else {
                if self.needsServerWalletStateRefresh {
                    self.serverStateRefreshRequested = true
                }
                return
            }
            var promotedReplacement = false
            let isMutatingReplacementCandidate = self.preparedRecoveryPhraseImportRecordId != nil
                || self.currentState.activeOperation?.defersServerWalletState == true
            if !isMutatingReplacementCandidate {
                do {
                    if case let .ready(_, _, _, address, publicKey, _) = value {
                        promotedReplacement = try await self.runtime.reconcileReplacementCandidate(
                            serverAddress: address,
                            serverPublicKey: publicKey,
                            discardMismatch: true,
                            archivePreviousWallet: !self.isChangingWalletLocally,
                            serverStateRevision: revision
                        )
                    } else if case .empty(creating: false) = value {
                        try await self.runtime.discardReplacementAfterAuthoritativeEmptyState(serverStateRevision: revision)
                    }
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    self.logger.error("wallet_replacement_reconciliation_failed", error)
                }
            }
            if promotedReplacement {
                self.serverStateNeedsActivation = true
            }
            try Task.checkCancellation()
            guard !self.isShutdown,
                  self.serverStateMutationRevision == revision,
                  self.latestWalletStateRevision == walletStateRevision,
                  self.activationGeneration == generation else {
                if self.needsServerWalletStateRefresh {
                    self.serverStateRefreshRequested = true
                }
                return
            }
            self.serverStateRetryTask?.cancel()
            self.serverStateRetryTask = nil
            self.applyServerWalletState(value, forceActivation: promotedReplacement, balanceOverlayRevision: balanceOverlayRevision)
        } catch is CancellationError {
        } catch {
            self.logger.error("wallet_state_failed", error)
            if !self.isShutdown,
               self.serverStateMutationRevision == revision,
               self.latestWalletStateRevision == walletStateRevision,
               self.activationGeneration == generation,
               case .wallet = self.currentState.phase {
                self.replaceState(
                    phase: self.currentState.phase,
                    balance: .stale(previous: self.currentState.balance.currentValue, error: .network,
                        lastSuccessfulAt: self.balanceLastSuccessfulAt),
                    transactions: self.currentState.transactions,
                    pendingTransfers: self.currentState.pendingTransfers,
                    activeOperation: self.currentState.activeOperation
                )
            }
            self.scheduleServerStateRetry()
        }
    }

    func applyServerWalletState(
        _ value: TelegramCore.WalletState,
        forceActivation: Bool = false,
        refreshIfStreamingUnavailable: Bool = false,
        balanceOverlayRevision: UInt64? = nil
    ) {
        let operationWalletState: TelegramCore.WalletState?
        switch self.currentState.activeOperation {
        case .creating:
            operationWalletState = self.deferredServerWalletState?.state
        case .recoveringPhrase:
            operationWalletState = self.deferredServerWalletState?.state ?? self.serverWalletState
        default:
            operationWalletState = nil
        }
        if !forceActivation,
           case let .ready(_, _, _, pendingAddress, pendingPublicKey, _)? = operationWalletState,
           case let .ready(_, _, _, address, publicKey, _) = value,
           walletEngineAddressesEqual(pendingAddress, address),
           pendingPublicKey == publicKey {
            self.deferredServerWalletState = (
                value,
                refreshIfStreamingUnavailable || (self.deferredServerWalletState?.refreshIfStreamingUnavailable ?? false),
                balanceOverlayRevision
            )
            return
        }
        self.serverStateMutationRevision &+= 1
        if case let .ready(_, _, _, address, publicKey, _) = value {
            let revision = self.serverStateMutationRevision
            Task { [runtime = self.runtime] in
                await runtime.updateServerWalletIdentity(address: address, publicKey: publicKey, revision: revision)
            }
        } else {
            let revision = self.serverStateMutationRevision
            Task { [runtime = self.runtime] in
                await runtime.invalidateServerWalletIdentity(revision: revision)
            }
        }
        self.serverStateNeedsActivation = self.serverStateNeedsActivation || forceActivation
        if self.currentState.activeOperation?.defersServerWalletState == true {
            let shouldRefreshIfStreamingUnavailable = refreshIfStreamingUnavailable
                || (self.deferredServerWalletState?.refreshIfStreamingUnavailable ?? false)
            self.deferredServerWalletState = (value, shouldRefreshIfStreamingUnavailable, balanceOverlayRevision)
            return
        }
        self.deferredServerWalletState = nil
        self.serverStateRetryTask?.cancel()
        self.serverStateRetryTask = nil
        self.serverWalletState = value
        if case let .ready(backupEnabled, _, _, address, publicKey, _) = value, !backupEnabled {
            self.completeAppliedKeyRotationIfBackupDisabled(
                address: address, publicKey: publicKey, serverStateRevision: self.serverStateMutationRevision
            )
        }
        if !self.serverStateNeedsActivation,
           case let .ready(backupEnabled, canExportPhrase, canEnableBackup, address, publicKey, serverBalance) = value,
           case let .wallet(currentInfo) = self.currentState.phase,
           walletEngineAddressesEqual(currentInfo.address, address),
           currentInfo.publicKey == publicKey.map({ String(format: "%02x", $0) }).joined() {
            let overlayChanged = balanceOverlayRevision.map {
                self.streamingPresentationOverlay.reconcileBalance(serverBalance, through: $0, log: self.logger.log)
            } ?? false
            let previousState = self.currentState
            self.replaceState(
                phase: .wallet(WalletInfo(
                    address: currentInfo.address,
                    publicKey: currentInfo.publicKey,
                    backupEnabled: backupEnabled,
                    canExportPhrase: canExportPhrase,
                    canEnableBackup: canEnableBackup,
                    canSign: currentInfo.canSign
                )),
                balance: .value(serverBalance, updatedAt: currentWalletTimestamp()),
                transactions: self.currentState.transactions,
                pendingTransfers: self.currentState.pendingTransfers,
                activeOperation: self.currentState.activeOperation
            )
            if overlayChanged && self.currentState == previousState {
                self.publishPresentationState()
            }
            self.evaluatePollingDemand()
            if self.streamingPresentationOverlay.hasUnreconciledBalance {
                self.retryStreamingSynchronizationIfNeeded(scope: [.account, .transactions])
            }
            if refreshIfStreamingUnavailable {
                self.scheduleWalletStateFallbackRefreshIfNeeded()
            }
            return
        }
        self.serverStateNeedsActivation = false
        let shouldClearExpiredPendingTraceIds: Bool
        switch value {
        case .empty:
            shouldClearExpiredPendingTraceIds = true
        case let .ready(_, _, _, address, _, _):
            let previousAddress: String?
            if case let .wallet(info) = self.currentState.phase {
                previousAddress = info.address
            } else {
                previousAddress = self.storedState.walletAddress
            }
            shouldClearExpiredPendingTraceIds = previousAddress.map {
                !walletEngineAddressesEqual($0, address)
            } ?? true
        }
        _ = self.streamingPresentationOverlay.removeAll()
        self.resetPendingTransferExpiration(
            clearSuppressedTraceIds: shouldClearExpiredPendingTraceIds
        )
        self.outgoingTransactionPresentationIdentities.removeAll()
        self.cancelGaslessInfoRequest()
        self.streamingRefreshTracker = WalletStreamingRefreshTracker()
        self.discardPendingTransferRegistrations()
        self.activationGeneration &+= 1
        self.stopStreaming()
        self.cancelWalletTransferResolution()
        self.walletTransferResolutions.removeAll()
        self.walletTransferHashStates.removeAll()
        self.gaslessQuotaRevision &+= 1
        self.cancelWalletStateFallbackRefresh()
        if let activeOperationId = self.activeOperationId {
            self.output.cancelOperation(id: activeOperationId)
            self.activeOperationId = nil
        }
        self.authorization.invalidate()
        self.preparedAuthorizations.removeAll()
        self.preparedTransfers.removeAll()
        self.deferredSynchronizationScope = []
        let generation = self.activationGeneration
        let serverStateRevision = self.serverStateMutationRevision
        self.activationTask?.cancel()
        self.activationTask = nil

        switch value {
        case let .empty(creating):
            self.observationTask?.cancel()
            self.observationTask = nil
            self.cancelSynchronization()
            self.transactionHistory.reset()
            self.activationTask = Task { [runtime = self.runtime] in
                guard !Task.isCancelled else { return }
                await runtime.shutdown()
            }
            self.replaceState(
                phase: creating ? .creating : .empty,
                balance: .idle,
                transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
                collectibles: .empty,
                pendingTransfers: [],
                activeOperation: nil,
                gaslessInfo: .idle
            )
        case let .ready(backupEnabled, canExportPhrase, canEnableBackup, address, publicKey, serverBalance):
            let isSameCachedIdentity = self.storedState.walletAddress.map {
                walletEngineAddressesEqual($0, address)
            } ?? false
            let supersededBalance = isSameCachedIdentity ? nil : self.currentState.balance.currentValue
            let archivePreviousWallet = !self.isChangingWalletLocally
            self.observationTask?.cancel()
            self.observationTask = nil
            self.cancelSynchronization()
            if !isSameCachedIdentity {
                self.transactionHistory.reset()
                self.pendingScreenSynchronizationScope.formUnion(self.visibleScreenSynchronizationScope)
            }
            self.replaceState(
                phase: .restoring,
                balance: .value(serverBalance, updatedAt: currentWalletTimestamp()),
                transactions: isSameCachedIdentity
                    ? self.currentState.transactions
                    : TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
                collectibles: isSameCachedIdentity ? self.currentState.collectibles : .empty,
                pendingTransfers: isSameCachedIdentity ? self.currentState.pendingTransfers : [],
                activeOperation: nil
            )
            self.activationTask = Task { [weak self] in
                await self?.activateWallet(
                    backupEnabled: backupEnabled,
                    canExportPhrase: canExportPhrase,
                    canEnableBackup: canEnableBackup,
                    address: address,
                    publicKey: publicKey,
                    supersededBalance: supersededBalance,
                    archivePreviousWallet: archivePreviousWallet,
                    generation: generation,
                    serverStateRevision: serverStateRevision
                )
            }
        }
    }

    private func activateWallet(
        backupEnabled: Bool,
        canExportPhrase: Bool,
        canEnableBackup: Bool,
        address: String,
        publicKey: Data,
        supersededBalance: Int64?,
        archivePreviousWallet: Bool,
        generation: UInt64,
        serverStateRevision: UInt64
    ) async {
        do {
            let authorizationGeneration = try self.authorization.operationGeneration(requireAvailable: false)
            try await self.authorization.waitUntilAvailable(generation: authorizationGeneration)
            await self.runtime.setLastKnownBalance(supersededBalance)
            let stored = try await self.storage.loadDescriptor()
            let storedMatchesIdentity = stored.map {
                $0.schemaVersion == 2
                    && $0.network == "mainnet"
                    && walletEngineAddressesEqual($0.address, address)
                    && $0.signingPublicKey == publicKey
            } ?? false
            let hasStoredSecret: Bool
            if storedMatchesIdentity, let secretRef = stored?.secretRef {
                hasStoredSecret = try await self.storage.containsProtectedSecret(
                    ProtectedSecretRef(value: secretRef)
                )
            } else {
                hasStoredSecret = false
            }
            let needsSecret = !hasStoredSecret
            var words: [String]?
            if needsSecret && canExportPhrase,
               !self.hasAttemptedAutomaticPhraseRecovery(address: address, publicKey: publicKey),
               try !walletProtectionSettings().enabled {
                self.automaticPhraseRecoveryAttemptIdentity = (address, publicKey)
                do {
                    let exportedWords = try await exportWalletSecretPhrase(
                        engine: self.engine,
                        password: nil,
                        expectedPublicKey: publicKey
                    )
                    guard !self.isShutdown, self.activationGeneration == generation else {
                        return
                    }
                    words = exportedWords
                } catch TelegramCore.WalletOperationError.requestPassword {
                    
                } catch {
                    self.logger.error("wallet_automatic_phrase_export_failed", error)
                }
            }
            let activation: WalletEngineActivation
            if let words {
                do {
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
                    activation = try await self.runtime.commitReplacement(
                        recordId: prepared.recordId,
                        serverAddress: address,
                        serverPublicKey: publicKey,
                        archivePreviousWallet: archivePreviousWallet,
                        serverStateRevision: serverStateRevision
                    )
                } catch {
                    self.logger.error("wallet_automatic_phrase_install_failed", error)
                    activation = try await self.runtime.activate(
                        serverAddress: address,
                        serverPublicKey: publicKey,
                        archivePreviousWallet: archivePreviousWallet,
                        serverStateRevision: serverStateRevision
                    )
                }
            } else {
                activation = try await self.runtime.activate(
                    serverAddress: address,
                    serverPublicKey: publicKey,
                    archivePreviousWallet: archivePreviousWallet,
                    serverStateRevision: serverStateRevision
                )
            }
            try Task.checkCancellation()
            guard self.activationGeneration == generation else { return }
            let info = WalletInfo(
                address: address,
                publicKey: publicKey.map { String(format: "%02x", $0) }.joined(),
                backupEnabled: backupEnabled,
                canExportPhrase: canExportPhrase,
                canEnableBackup: canEnableBackup,
                canSign: activation.canSign
            )
            let submissions = try await self.storage.loadTransferSubmissions()
            guard !Task.isCancelled, self.activationGeneration == generation else { return }
            self.transferSubmissions.restore(submissions)
            await self.restorePendingTransfers(generation: generation)
            guard !Task.isCancelled, self.activationGeneration == generation else { return }
            self.replaceState(
                phase: .wallet(info),
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: self.currentState.pendingTransfers,
                activeOperation: nil
            )
            self.beginObserving(snapshot: activation.snapshot, generation: generation)
            self.resumeDeferredSynchronizationIfNeeded()
            if self.hasActiveWalletRefreshDemand {
                let scope: WalletSynchronizationScope = [.account, .transactions]
                self.requestSynchronization(scope: scope.subtracting(self.activeSynchronizationScope))
            }
            if self.hasGaslessInfoDemand {
                self.requestGaslessInfo()
            }
            self.scheduleAutomaticPhraseRecoveryIfNeeded()
        } catch is CancellationError {
        } catch let error as PasscodeError where error == .cancelled || (error == .unavailable && !self.authorization.isAvailable) {
            guard !self.isShutdown, self.activationGeneration == generation else { return }
            self.serverStateNeedsActivation = true
            self.evaluateRuntimeDemand(refreshIfPollingBecomesActive: false)
        } catch let error as WalletEngineStorageError {
            guard !self.isShutdown, self.activationGeneration == generation else { return }
            self.logger.error("wallet_engine_activation_failed", error)
            self.replaceState(
                phase: .failed(Self.storageError(error)),
                balance: self.currentState.balance,
                transactions: self.currentState.transactions,
                pendingTransfers: [],
                activeOperation: nil
            )
        } catch {
            guard !self.isShutdown, self.activationGeneration == generation else { return }
            self.logger.error("wallet_engine_activation_failed", error)
            self.replaceState(
                phase: .failed(.unsupportedVersion),
                balance: .idle,
                transactions: self.currentState.transactions,
                pendingTransfers: [],
                activeOperation: nil
            )
        }
    }

    func applyCompatibleDeferredServerWalletState() {
        guard let deferred = self.deferredServerWalletState else { return }
        let value = deferred.state

        let isCompatible: Bool
        switch (self.currentState.phase, value) {
        case let (.wallet(info), .ready(_, _, _, address, publicKey, _)):
            isCompatible = walletEngineAddressesEqual(info.address, address)
                && info.publicKey == publicKey.map { String(format: "%02x", $0) }.joined()
        case (.empty, .empty), (.creating, .empty):
            isCompatible = true
        case (.restoring, _), (.failed, _), (.empty, .ready), (.creating, .ready),
             (.wallet, .empty):
            isCompatible = false
        }
        guard isCompatible else { return }
        self.applyServerWalletState(
            value,
            refreshIfStreamingUnavailable: deferred.refreshIfStreamingUnavailable,
            balanceOverlayRevision: deferred.balanceOverlayRevision
        )
    }

    func beginObserving(snapshot: WalletSnapshot, generation: UInt64) {
        self.observationTask?.cancel()
        self.cancelSynchronization()
        self.runtimeObservationId = UUID()
        self.applyEngineSnapshot(snapshot)
        self.observationTask = Task { [weak self] in
            await self?.observeWallet(snapshot: snapshot, generation: generation)
        }
    }

    private func observeWallet(snapshot: WalletSnapshot, generation: UInt64) async {
        var revision = snapshot.revision
        while !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation {
            do {
                let value = try await self.runtime.waitForChange(afterRevision: revision)
                guard value.revision > revision else { continue }
                revision = value.revision
                guard !Task.isCancelled, !self.isShutdown, self.activationGeneration == generation else { return }
                self.applyEngineSnapshot(value)
            } catch is CancellationError {
                return
            } catch {
                guard self.activationGeneration == generation else { return }
                self.logger.error("wallet_engine_observation_failed", error)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    func applyEngineSnapshot(_ snapshot: WalletSnapshot) {
        self.reconcileKeyRotation(snapshot.send)
        let reconciledPending = self.reconcilePendingTransfers(snapshot.send)
        let historyReconciliation = self.pendingTransfers(
            reconciledPending,
            reconcilingWith: self.currentState.transactions.items
        )
        let removedStreamingTraceCount = self.streamingPresentationOverlay.clearTransactions(
            through: self.streamingPresentationOverlay.revision,
            presentIn: self.currentState.transactions.items,
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
            transactions: self.currentState.transactions,
            pendingTransfers: historyReconciliation.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
        if removedStreamingTraceCount != 0 && self.currentState == previousState {
            self.publishPresentationState()
        }
    }

    func recordBalanceTimestamp(_ balance: Resource<Int64>) {
        if case .loading = balance { return }
        self.balanceLastSuccessfulAt = balance.lastSuccessfulAt
    }

    func reconcilePendingTransfers(_ send: SendSnapshot) -> [PendingTransfer] {
        guard let id = send.operationId,
              let index = self.currentState.pendingTransfers.firstIndex(where: { $0.id == id }),
              !self.currentState.pendingTransfers[index].isPreparing else {
            return self.currentState.pendingTransfers
        }
        var values = self.currentState.pendingTransfers
        switch send.phase {
        case .submitted, .submissionUnknown, .confirmed:
            let current = values[index]
            let status: PendingTransfer.Status
            switch send.phase {
            case .submissionUnknown:
                status = .submissionUnknown
            case .confirmed:
                status = .confirmed
            case .submitted:
                status = .pending
            default:
                preconditionFailure()
            }
            let updated = PendingTransfer(
                id: current.id,
                recipient: current.recipient,
                amount: current.amount,
                comment: current.comment,
                commentEncrypted: current.commentEncrypted,
                collectibleAddress: current.collectibleAddress,
                normalizedHash: current.normalizedHash,
                sentTransfer: current.sentTransfer,
                expectedGasless: current.expectedGasless,
                pendingMessage: current.pendingMessage,
                streamingData: current.streamingData,
                fee: current.fee,
                transactionHash: send.phase == .confirmed
                    ? (send.resolution?.transactionHash ?? current.transactionHash)
                    : current.transactionHash,
                transactionLt: send.phase == .confirmed
                    ? (send.resolution?.transactionLt ?? current.transactionLt)
                    : current.transactionLt,
                uiExpiresAt: current.uiExpiresAt,
                createdAt: current.createdAt,
                status: status
            )
            values[index] = updated
            if send.phase == .confirmed, updated != current {
                self.requestSynchronization(scope: current.collectibleAddress == nil ? [.account, .transactions] : .all, force: true)
            }
        case .replaced, .sequenceNumberConsumed, .expired, .superseded, .failed, .cancelled:
            self.logger.log("event=wallet_pending_transfer_terminal_failure phase=\(send.phase)")
            let removed = values.remove(at: index)
            self.walletTransferResolutions[removed.id] = nil
            if let pendingMessage = removed.pendingMessage {
                let _ = self.engine.wallet.removePendingTransferMessage(pendingMessage).start()
            }
            self.requestSynchronization(scope: removed.collectibleAddress == nil ? [.account, .transactions] : .all, force: true)
        case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit, .submitting, .handedOff:
            break
        }
        return values
    }

    func pendingTransfers(
        _ pendingTransfers: [PendingTransfer],
        reconcilingWith transactions: [Transaction]
    ) -> PendingTransferHistoryReconciliation {
        self.rememberOutgoingTransactionPresentationIdentities(pendingTransfers)
        return walletPendingTransfersReconciledWithHistory(
            pendingTransfers, transactions: transactions,
            streamingTransactionHashes: { self.streamingPresentationOverlay.transactionHashes(forTraceId: $0) }
        )
    }

    func logPendingTransferHistoryReconciliation(
        _ reconciliation: PendingTransferHistoryReconciliation,
        removedStreamingTraceCount: Int
    ) {
        guard reconciliation.removedPendingCount != 0 || removedStreamingTraceCount != 0 else {
            return
        }
        self.logger.log(
            "event=wallet_pending_history_reconciled pending_removed=\(reconciliation.removedPendingCount) trace_removed=\(removedStreamingTraceCount)"
        )
    }

    func reconcileKeyRotation(_ send: SendSnapshot) {
        switch send.phase {
        case .confirmed, .replaced, .sequenceNumberConsumed, .expired, .superseded, .failed, .cancelled:
            let generation = self.activationGeneration
            Task { [weak self] in
                await self?.performKeyRotationReconciliation(send: send, generation: generation)
            }
        case .idle, .validating, .authorizing, .preparing, .persisting, .readyToSubmit,
             .submitting, .submissionUnknown, .submitted, .handedOff:
            break
        }
    }

    private func performKeyRotationReconciliation(send: SendSnapshot, generation: UInt64) async {
        guard !self.isShutdown else { return }
        do {
            let result = try await self.runtime.reconcileKeyRotation(send: send)
            guard self.activationGeneration == generation else { return }
            switch result {
            case let .confirmed(operationId):
                if case let .wallet(info) = self.currentState.phase, !info.backupEnabled {
                    do {
                        try await self.runtime.completeKeyRotationAfterBackupDisabled(operationId: operationId)
                    } catch {
                        self.logger.error("wallet_key_rotation_completion_failed", error)
                    }
                }
                self.requestSynchronization(scope: [.account, .transactions], force: true)
            case .rolledBack:
                self.requestSynchronization(scope: [.account, .transactions], force: true)
            case .none, .pending:
                break
            }
        } catch {
            self.logger.error("wallet_key_rotation_reconciliation_failed", error)
        }
    }

    func completeAppliedKeyRotationIfBackupDisabled(address: String, publicKey: Data, serverStateRevision: UInt64) {
        Task { [runtime = self.runtime, logger = self.logger] in
            do {
                try await runtime.reconcileKeyRotation(
                    serverAddress: address, serverPublicKey: publicKey, backupEnabled: false,
                    serverStateRevision: serverStateRevision
                )
            } catch {
                logger.error("wallet_applied_key_rotation_cleanup_failed", error)
            }
        }
    }

    func replaceState(
        phase: Phase,
        balance: Resource<Int64>,
        transactions: TransactionsState,
        collectibles: CollectiblesState? = nil,
        pendingTransfers: [PendingTransfer],
        activeOperation: ActiveOperation?,
        fiat: FiatState? = nil,
        gaslessInfo: Resource<WalletGaslessInfo>? = nil
    ) {
        defer { self.evaluateWalletTransferResolution() }
        self.recordBalanceTimestamp(balance)
        let expirationResult = self.removingExpiredPendingTransfers(
            pendingTransfers,
            now: currentWalletTimestamp()
        )
        let pendingTransfers = expirationResult.pendingTransfers
        let presentationIdentitiesChanged = self.rememberOutgoingTransactionPresentationIdentities(pendingTransfers)
        var presentationIds: [String: String] = [:]
        for item in self.currentState.transactions.items where item.presentationId != item.id {
            if let hash = item.transactionHash { presentationIds[hash] = item.presentationId }
        }
        presentationIds.merge(self.outgoingTransactionPresentationIds().byTransactionHash) { _, new in new }
        let transactions = TransactionsState(
            items: transactions.items.map { transaction in
                walletTransactionWithPresentationId(transaction, presentationId:
                    transaction.transactionHash.flatMap { presentationIds[$0] } ?? transaction.presentationId)
            },
            offset: transactions.offset, canLoadMore: transactions.canLoadMore,
            isLoadingMore: transactions.isLoadingMore, error: transactions.error
        )
        let walletAddress: String?
        if case let .ready(_, _, _, address, _, _)? = self.serverWalletState {
            walletAddress = address
        } else if self.serverWalletState == nil {
            walletAddress = self.storedState.walletAddress
        } else {
            walletAddress = nil
        }
        let value = State(
            phase: phase,
            walletAddress: walletAddress,
            balance: balance,
            transactions: transactions,
            collectibles: collectibles ?? self.currentState.collectibles,
            pendingTransfers: pendingTransfers,
            activeOperation: activeOperation,
            fiat: fiat ?? self.currentState.fiat,
            gaslessInfo: gaslessInfo ?? self.currentState.gaslessInfo
        )
        for transaction in value.transactions.items where transaction.status == .completed || transaction.status == .failed {
            if transaction.presentationId.hasPrefix("pending:") {
                self.markWalletTransferConsumed(String(transaction.presentationId.dropFirst("pending:".count)), successful: transaction.status == .completed)
            }
        }
        let peerMappingsChanged = self.rememberWalletPeers(in: value.transactions.items)
        let presentationIdentitiesPruned = self.pruneOutgoingTransactionPresentationIdentities(
            state: value
        )
        guard value != self.currentState else {
            self.updatePendingTransferExpirationSchedule(for: pendingTransfers)
            if peerMappingsChanged
                || presentationIdentitiesChanged
                || presentationIdentitiesPruned
                || expirationResult.streamingOverlayChanged {
                self.publishPresentationState()
            }
            return
        }
        self.currentState = value
        self.updateTonConnectWallet()
        self.updatePendingTransferExpirationSchedule(for: pendingTransfers)
        self.publishPresentationState()
        self.persistStoredState(value)
        self.evaluateStreamingDemand()
        self.evaluatePollingDemand()
    }

    func publishPresentationState() {
        _ = self.pruneOutgoingTransactionPresentationIdentities(state: self.currentState)
        let presentationIds = self.outgoingTransactionPresentationIds()
        self.output.publish(state: self.streamingPresentationOverlay.applying(
            to: self.currentState,
            peerByAddress: self.peerByWalletAddress,
            presentationIdByTraceId: presentationIds.byTraceId,
            presentationIdByTransactionHash: presentationIds.byTransactionHash,
            log: self.logger.log
        ))
    }

    private func pendingTransferUIExpirationDeadline(_ pending: PendingTransfer) -> Int32? {
        switch pending.status {
        case .broadcasting, .pending, .submissionUnknown:
            return pending.uiExpiresAt
                ?? walletPendingTransferUIExpirationTimestamp(from: pending.createdAt)
        case .confirmed:
            return nil
        }
    }

    private func removingExpiredPendingTransfers(
        _ pendingTransfers: [PendingTransfer],
        now: Int32
    ) -> (pendingTransfers: [PendingTransfer], streamingOverlayChanged: Bool) {
        var retained: [PendingTransfer] = []
        retained.reserveCapacity(pendingTransfers.count)
        var expiredTraceIds = Set<String>()
        var expiredCount = 0
        for pending in pendingTransfers {
            if let deadline = self.pendingTransferUIExpirationDeadline(pending), deadline <= now {
                expiredCount += 1
                if let traceId = pending.streamingTraceId {
                    expiredTraceIds.insert(traceId)
                }
            } else {
                retained.append(pending)
            }
        }
        guard expiredCount != 0 else {
            return (pendingTransfers, false)
        }

        let traceExpiration = self.streamingPresentationOverlay.expirePendingTraces(expiredTraceIds)
        self.expiredPendingStreamingTraceIds.formUnion(traceExpiration.suppressedTraceIds)
        self.logger.log(
            "event=wallet_pending_ui_expired pending_removed=\(expiredCount) trace_removed=\(traceExpiration.removedCount)"
        )
        return (retained, traceExpiration.removedCount != 0)
    }

    private func updatePendingTransferExpirationSchedule(for pendingTransfers: [PendingTransfer]) {
        let deadline = pendingTransfers.compactMap {
            self.pendingTransferUIExpirationDeadline($0)
        }.min()
        if deadline == self.pendingTransferExpirationDeadline,
           self.pendingTransferExpirationTask != nil {
            return
        }

        self.pendingTransferExpirationTask?.cancel()
        self.pendingTransferExpirationTask = nil
        self.pendingTransferExpirationTaskId = nil
        self.pendingTransferExpirationDeadline = deadline
        guard let deadline else {
            return
        }

        let taskId = UUID()
        self.pendingTransferExpirationTaskId = taskId
        self.pendingTransferExpirationTask = Task { [weak self] in
            await self?.waitForPendingTransferExpiration(deadline: deadline, taskId: taskId)
        }
    }

    private func waitForPendingTransferExpiration(deadline: Int32, taskId: UUID) async {
        let remainingSeconds = max(0, Int64(deadline) - Int64(currentWalletTimestamp()))
        do {
            try await Task.sleep(nanoseconds: UInt64(remainingSeconds) * 1_000_000_000)
        } catch {
            return
        }
        guard !self.isShutdown,
              self.pendingTransferExpirationTaskId == taskId else {
            return
        }
        self.pendingTransferExpirationTask = nil
        self.pendingTransferExpirationTaskId = nil
        self.pendingTransferExpirationDeadline = nil
        self.replaceState(
            phase: self.currentState.phase,
            balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers,
            activeOperation: self.currentState.activeOperation
        )
    }

    func resetPendingTransferExpiration(clearSuppressedTraceIds: Bool) {
        self.pendingTransferExpirationTask?.cancel()
        self.pendingTransferExpirationTask = nil
        self.pendingTransferExpirationTaskId = nil
        self.pendingTransferExpirationDeadline = nil
        if clearSuppressedTraceIds {
            self.expiredPendingStreamingTraceIds.removeAll()
        }
    }

    @discardableResult
    func rememberOutgoingTransactionPresentationIdentities(
        _ pendingTransfers: [PendingTransfer]
    ) -> Bool {
        var changed = false
        for pending in pendingTransfers where pending.collectibleAddress == nil && pending.amount > 0 {
            let current = self.outgoingTransactionPresentationIdentities[pending.id]
            let updated = OutgoingTransactionPresentationIdentity(
                presentationId: current?.presentationId ?? "pending:\(pending.id)",
                traceId: pending.streamingTraceId ?? current?.traceId,
                transactionHash: pending.transactionHash ?? current?.transactionHash,
                pendingTransfer: pending
            )
            if current?.presentationId != updated.presentationId
                || current?.traceId != updated.traceId
                || current?.transactionHash != updated.transactionHash
                || current?.pendingTransfer != updated.pendingTransfer {
                self.outgoingTransactionPresentationIdentities[pending.id] = updated
                changed = true
            }
        }
        return changed
    }

    @discardableResult
    private func pruneOutgoingTransactionPresentationIdentities(state: State) -> Bool {
        let pendingOperationIds = Set(state.pendingTransfers.map(\.id))
        let authoritativeTransactionHashes = Set(state.transactions.items.compactMap(\.transactionHash))
        let previousCount = self.outgoingTransactionPresentationIdentities.count
        self.outgoingTransactionPresentationIdentities = self.outgoingTransactionPresentationIdentities.filter { operationId, identity in
            if pendingOperationIds.contains(operationId) {
                return true
            }
            if let traceId = identity.traceId,
               self.streamingPresentationOverlay.containsTrace(traceId) {
                return true
            }
            if let transactionHash = identity.transactionHash,
               authoritativeTransactionHashes.contains(transactionHash) {
                return true
            }
            return false
        }
        return self.outgoingTransactionPresentationIdentities.count != previousCount
    }

    private func outgoingTransactionPresentationIds() -> (
        byTraceId: [String: String],
        byTransactionHash: [String: String]
    ) {
        var byTraceId: [String: String] = [:]
        var byTransactionHash: [String: String] = [:]
        for identity in self.outgoingTransactionPresentationIdentities.values {
            if let traceId = identity.traceId {
                byTraceId[traceId] = identity.presentationId
            }
            if let transactionHash = identity.transactionHash {
                byTransactionHash[transactionHash] = identity.presentationId
            }
        }
        return (byTraceId, byTransactionHash)
    }

    func rememberWalletPeer(_ mapping: WalletPeerAddressMapping) {
        guard let key = walletAddressMappingKey(mapping.address) else {
            return
        }
        let changed = self.peerByWalletAddress[key] != mapping.peer
        self.peerByWalletAddress[key] = mapping.peer
        if changed {
            self.publishPresentationState()
        }
    }

    private func rememberWalletPeers(in transactions: [Transaction]) -> Bool {
        var changed = false
        for transaction in transactions {
            guard case let .user(peer, address, _) = transaction.peer,
                  let key = walletAddressMappingKey(address) else {
                continue
            }
            if self.peerByWalletAddress[key] != peer {
                self.peerByWalletAddress[key] = peer
                changed = true
            }
        }
        return changed
    }

    @discardableResult
    func clearStreamingPresentationOverlay() -> Bool {
        guard self.streamingPresentationOverlay.removeAll() else {
            return false
        }
        self.publishPresentationState()
        return true
    }

    private func persistStoredState(_ state: State) {
        var storedState = WalletStoredState()
        storedState.tonConnectRequests = self.storedState.tonConnectRequests
        storedState.walletAddress = {
            if case .failed = state.phase { return self.storedState.walletAddress }
            return state.walletAddress
        }()
        storedState.pendingTransfers = state.pendingTransfers
        storedState.balance = state.balance.currentValue
        storedState.balanceUpdatedAt = state.balance.lastSuccessfulAt ?? self.balanceLastSuccessfulAt
        storedState.fiatRates = state.fiat.rates.currentValue
        storedState.fiatRatesUpdatedAt = state.fiat.rates.lastSuccessfulAt ?? self.fiatLastSuccessfulAt
        storedState.selectedFiatCurrency = state.fiat.selectedCurrency
        storedState.transactions = state.transactions.items
            .prefix(walletTransactionFetchLimit)
            .map(WalletStoredTransaction.init)
        storedState.collectibles = Array(state.collectibles.items.prefix(walletTransactionFetchLimit))
        guard storedState != self.storedState else {
            return
        }
        self.storedState = storedState
        self.storedStateMutationRevision &+= 1
        let revision = self.storedStateMutationRevision
        let storedStateWriter = self.storedStateWriter
        Task {
            await storedStateWriter.enqueue(storedState, revision: revision)
        }
    }

    func persistPendingTransferBeforeSend(_ pending: PendingTransfer, generation: UInt64) async throws {
        guard !self.isShutdown, self.activationGeneration == generation,
              self.currentState.pendingTransfers.contains(where: { $0.id == pending.id }) else { throw WalletError.unavailable }
        self.replaceState(
            phase: self.currentState.phase, balance: self.currentState.balance,
            transactions: self.currentState.transactions,
            pendingTransfers: self.currentState.pendingTransfers.map { $0.id == pending.id ? pending : $0 },
            activeOperation: self.currentState.activeOperation
        )
        guard await self.storedStateWriter.storeAndWait(self.storedState, revision: self.storedStateMutationRevision),
              !self.isShutdown, self.activationGeneration == generation,
              self.currentState.pendingTransfers.contains(where: { $0.id == pending.id }) else { throw WalletError.unavailable }
    }

    func latestPendingTransfer(_ fallback: PendingTransfer) -> PendingTransfer {
        return self.currentState.pendingTransfers.first(where: { $0.id == fallback.id })
            ?? self.outgoingTransactionPresentationIdentities[fallback.id]?.pendingTransfer
            ?? fallback
    }

    func scheduleServerStateRetry() {
        guard self.serverStateRetryTask == nil,
              self.canUseNetworkRuntime,
              self.needsServerWalletStateRefresh else {
            return
        }
        self.serverStateRetryTask = Task { [weak self] in
            await self?.performServerStateRetryDelay()
        }
    }

    private func performServerStateRetryDelay() async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        guard !Task.isCancelled,
              !self.isShutdown else {
            return
        }
        self.serverStateRetryTask = nil
        guard self.needsServerWalletStateRefresh else { return }
        self.requestServerWalletState()
    }

    var hasActiveWalletRefreshDemand: Bool {
        self.walletScreenCount > 0 || !self.currentState.pendingTransfers.isEmpty
    }

    var isPollingEligible: Bool {
        guard self.canUseNetworkRuntime,
              self.hasActiveWalletRefreshDemand,
              WalletStreamingDemand.needsPolling(
                connection: self.streamingConnectionState,
                hasPendingTransfer: !self.currentState.pendingTransfers.isEmpty,
                hasUnreconciledBalance: self.streamingPresentationOverlay.hasUnreconciledBalance
              ),
              case .wallet = self.currentState.phase else {
            return false
        }
        return true
    }

    func evaluatePollingDemand(refreshIfBecomingActive: Bool = false) {
        guard self.isPollingEligible else {
            self.pollingTask?.cancel()
            self.pollingTask = nil
            self.pollingTaskId = nil
            if !self.hasActiveWalletRefreshDemand || !self.canUseNetworkRuntime {
                self.cancelWalletStateFallbackRefresh()
            }
            return
        }
        let wasRunning = self.pollingTask != nil
        if !wasRunning {
            let taskId = UUID()
            self.pollingTaskId = taskId
            self.pollingTask = Task { [weak self] in
                await self?.runPolling(taskId: taskId)
            }
        }
        if refreshIfBecomingActive && !wasRunning {
            self.requestSynchronization(scope: [.account, .transactions])
        }
    }

    private func runPolling(taskId: UUID) async {
        defer {
            if self.pollingTaskId == taskId {
                self.pollingTask = nil
                self.pollingTaskId = nil
            }
        }
        while !Task.isCancelled,
              !self.isShutdown,
              self.pollingTaskId == taskId,
              self.isPollingEligible {
            let jitter = Double.random(in: 0.0 ... 0.2)
            let interval = 60.0 * (1.0 + jitter)
            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000.0))
            } catch {
                return
            }
            guard !Task.isCancelled,
                  !self.isShutdown,
                  self.pollingTaskId == taskId,
                  self.isPollingEligible else {
                return
            }
            self.requestSynchronization(scope: [.account, .transactions])
        }
    }

    func scheduleWalletStateFallbackRefreshIfNeeded() {
        guard self.canUseNetworkRuntime,
              self.hasActiveWalletRefreshDemand,
              self.streamingConnectionState != .subscribed,
              case .wallet = self.currentState.phase,
              self.walletStateFallbackRefreshTask == nil else {
            return
        }
        let taskId = UUID()
        self.walletStateFallbackRefreshTaskId = taskId
        self.walletStateFallbackRefreshTask = Task { [weak self] in
            await self?.runWalletStateFallbackRefreshDelay(taskId: taskId)
        }
    }

    private func runWalletStateFallbackRefreshDelay(taskId: UUID) async {
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            return
        }
        guard !self.isShutdown,
              self.walletStateFallbackRefreshTaskId == taskId else {
            return
        }
        self.walletStateFallbackRefreshTask = nil
        self.walletStateFallbackRefreshTaskId = nil
        guard self.canUseNetworkRuntime,
              self.hasActiveWalletRefreshDemand,
              self.streamingConnectionState != .subscribed,
              case .wallet = self.currentState.phase else {
            return
        }
        self.requestSynchronization(scope: [.account, .transactions], force: true)
    }

    func cancelWalletStateFallbackRefresh() {
        self.walletStateFallbackRefreshTask?.cancel()
        self.walletStateFallbackRefreshTask = nil
        self.walletStateFallbackRefreshTaskId = nil
    }

    static func storageError(_ error: WalletEngineStorageError) -> FatalStorageError {
        switch error {
        case let .keychainStatus(status): return .keychainStatus(status)
        case .corrupted: return .corrupted
        }
    }
}

@available(macOS 10.15, *)
func captureAsync<Value>(_ operation: () async throws -> Value) async -> Result<Value, Error> {
    do { return .success(try await operation()) } catch { return .failure(error) }
}

@available(macOS 10.15, *)
func currentWalletTimestamp() -> Int32 {
    Int32(clamping: Int64(Date().timeIntervalSince1970))
}

@available(macOS 10.15, *)
func walletEngineBalance(_ nanograms: String) -> Int64? {
    guard let value = Int64(nanograms), value >= 0 else { return nil }
    return value
}

@available(macOS 10.15, *)
func walletEngineAcceptsSubmission(_ phase: SendPhase) -> Bool {
    phase == .submitted || phase == .submissionUnknown || phase == .confirmed
}
