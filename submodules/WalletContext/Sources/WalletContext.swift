import PasscodeCore
import Foundation
import SwiftSignalKit
import TelegramCore
#if canImport(TelegramUIPreferences)
import TelegramUIPreferences
#endif

@available(macOS 10.15, *)
final class WalletContextOutput {
    private let stateValue: Atomic<WalletContext.State>
    let tonConnectStatePromise = ValuePromise<WalletContext.TonConnectState>(.empty, ignoreRepeated: true)
    let statePromise: ValuePromise<WalletContext.State>
    private let cancelOperationImpl: (UUID) -> Void

    init(initialState: WalletContext.State, cancelOperation: @escaping (UUID) -> Void) {
        self.stateValue = Atomic(value: initialState)
        self.statePromise = ValuePromise(initialState, ignoreRepeated: true)
        self.cancelOperationImpl = cancelOperation
    }

    func publish(state: WalletContext.State) {
        _ = self.stateValue.swap(state)
        self.statePromise.set(state)
    }

    func currentState() -> WalletContext.State {
        self.stateValue.with { $0 }
    }

    func cancelOperation(id: UUID) {
        self.cancelOperationImpl(id)
    }
}

@available(macOS 10.15, *)
private struct WalletSubscriberDemand: Sendable {
    var count: Int = 0
    var revision: UInt64 = 0
}

@available(macOS 10.15, *)
struct WalletScreenDemand: Sendable {
    var walletCount = 0
    var collectiblesCount = 0
    var walletOpenRevision: UInt64 = 0
    var collectiblesOpenRevision: UInt64 = 0
    var gaslessInfoRequests = Set<UUID>()
    var balanceRequests = Set<UUID>()
    var revision: UInt64 = 0

    var visibleScope: WalletSynchronizationScope {
        if self.walletCount > 0 {
            return .all
        }
        if self.collectiblesCount > 0 {
            return .nfts
        }
        return []
    }

    func openedScope(since previous: WalletScreenDemand) -> WalletSynchronizationScope {
        guard self.revision > previous.revision else { return [] }
        var scope: WalletSynchronizationScope = []
        if self.walletCount > 0, self.walletOpenRevision > previous.walletOpenRevision {
            scope = .all
        }
        if self.collectiblesCount > 0, self.collectiblesOpenRevision > previous.collectiblesOpenRevision {
            scope.insert(.nfts)
        }
        if !self.balanceRequests.subtracting(previous.balanceRequests).isEmpty {
            scope.insert(.account)
        }
        return scope
    }
}

@available(macOS 10.15, *)
public final class WalletContext {
    static let useWalletTransferApi = true

    let authorization: WalletAuthorizationContext
    private let credentialChangesDisposable = MetaDisposable()
    let impl: WalletContextImpl
    let logger: WalletLogger
    let output: WalletContextOutput
    private let environmentDisposable = MetaDisposable()
    private let walletConfigurationDisposable = MetaDisposable()
    private let walletStateUpdatesDisposable = MetaDisposable()
    private let tonConnectUpdatesDisposable = MetaDisposable()
    private var tonConnectUpdatesTask: Task<Void, Never>?
    private let walletTransferUpdatesDisposable = MetaDisposable()
    private var walletTransferUpdatesTask: Task<Void, Never>?
    private let storedStateDisposable = MetaDisposable()
    private let operationTaskRegistry: WalletOperationTaskRegistry
    private let environmentRevision = Atomic<UInt64>(value: 0)
    private let walletConfigurationRevision = Atomic<UInt64>(value: 0)
    private let walletStateRevision = Atomic<UInt64>(value: 0)
    private let subscriberDemand = Atomic<WalletSubscriberDemand>(value: WalletSubscriberDemand())
    private let walletScreenDemand = Atomic<WalletScreenDemand>(value: WalletScreenDemand())
    let fiatCurrencyRevision = Atomic<UInt64>(value: 0)

    public func setAuthorizationPresenter(_ presenter: @escaping @Sendable (WalletAuthorizationRequest) async throws -> PasscodeSession) {
        self.authorization.setPresenter(presenter)
    }

    public var state: Signal<State, NoError> {
        Signal { [weak self] subscriber in
            guard let self else {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let impl = self.impl
            let subscriberDemand = self.subscriberDemand
            let demand = subscriberDemand.modify { value in
                var value = value
                value.count += 1
                value.revision &+= 1
                return value
            }
            Task {
                await impl.updateStateSubscriberDemand(count: demand.count, revision: demand.revision)
            }
            let disposable = (self.output.statePromise.get()
            |> deliverOnMainQueue).start(next: subscriber.putNext)
            return ActionDisposable {
                disposable.dispose()
                let demand = subscriberDemand.modify { value in
                    var value = value
                    value.count = max(0, value.count - 1)
                    value.revision &+= 1
                    return value
                }
                Task {
                    await impl.updateStateSubscriberDemand(count: demand.count, revision: demand.revision)
                }
            }
        }
    }

    public var stateValue: State {
        self.output.currentState()
    }

    public func beginWalletScreenUpdates() -> Disposable {
        return self.beginScreenUpdates(collectiblesOnly: false)
    }

    public func beginCollectiblesScreenUpdates() -> Disposable {
        return self.beginScreenUpdates(collectiblesOnly: true)
    }

    public func beginGaslessInfoUpdates() -> Disposable {
        let id = UUID()
        self.updateScreenDemand { $0.gaslessInfoRequests.insert(id) }
        return ActionDisposable { [weak self] in
            self?.updateScreenDemand { $0.gaslessInfoRequests.remove(id) }
        }
    }

    public func ensureGaslessInfo() {
        let impl = self.impl
        Task {
            await impl.requestGaslessInfoIfNeeded()
        }
    }

    public func refreshBalance() -> Disposable {
        let id = UUID()
        self.updateScreenDemand { $0.balanceRequests.insert(id) }
        return ActionDisposable { [weak self] in
            self?.updateScreenDemand { $0.balanceRequests.remove(id) }
        }
    }

    private func beginScreenUpdates(collectiblesOnly: Bool) -> Disposable {
        self.updateScreenDemand {
            if collectiblesOnly {
                $0.collectiblesCount += 1
                $0.collectiblesOpenRevision &+= 1
            } else {
                $0.walletCount += 1
                $0.walletOpenRevision &+= 1
            }
        }
        return ActionDisposable { [weak self] in
            self?.updateScreenDemand {
                if collectiblesOnly {
                    $0.collectiblesCount -= 1
                } else {
                    $0.walletCount -= 1
                }
            }
        }
    }

    private func updateScreenDemand(_ update: (inout WalletScreenDemand) -> Void) {
        let demand = self.walletScreenDemand.modify { value in
            var value = value
            update(&value)
            value.revision &+= 1
            return value
        }
        let impl = self.impl
        Task {
            await impl.updateWalletScreenDemand(demand)
        }
    }

    public init(
        engine: TelegramEngine,
        storageNamespace: String,
        applicationInForeground: Signal<Bool, NoError>,
        accountIsCurrent: Signal<Bool, NoError>,
        networkAvailable: Signal<Bool, NoError>,
        applicationIsPasscodeLocked: Signal<Bool, NoError> = .single(false),
        log: @escaping (String) -> Void = { Logger.shared.log("WalletContext", $0) }
    ) {
        let initialState = State(
            phase: .restoring,
            balance: .idle,
            transactions: TransactionsState(items: [], offset: 0, canLoadMore: false, isLoadingMore: false, error: nil),
            pendingTransfers: [],
            activeOperation: nil
        )
        let operationTaskRegistry = WalletOperationTaskRegistry()
        let output = WalletContextOutput(
            initialState: initialState,
            cancelOperation: { operationTaskRegistry.cancel(id: $0) }
        )
        let logger = WalletLogger(log)
        let authorization = WalletAuthorizationContext(namespace: storageNamespace)
        self.authorization = authorization
        let impl = WalletContextImpl(
            engine: engine,
            storageNamespace: storageNamespace,
            authorization: authorization,
            initialState: initialState,
            output: output,
            logger: logger
        )
        self.output = output
        self.logger = logger
        self.impl = impl
        self.operationTaskRegistry = operationTaskRegistry
        self.credentialChangesDisposable.set(PasscodeCredentialStore.shared.changes.start(next: { [weak authorization] _ in
            authorization?.invalidate()
        }))

        self.walletConfigurationDisposable.set((engine.data.subscribe(
            TelegramEngine.EngineData.Item.Configuration.App()
        )
        |> map { WalletConfiguration.with(appConfiguration: $0) }
        |> distinctUntilChanged).start(next: { [weak self] configuration in
            guard let self else { return }
            let revision = self.walletConfigurationRevision.modify { value in
                let next = value &+ 1
                return next
            }
            Task {
                await impl.updateWalletConfiguration(configuration, revision: revision)
            }
        }))

        self.walletStateUpdatesDisposable.set(engine.wallet.stateUpdates().start(next: { [weak self] value in
            guard let self else { return }
            let revision = self.walletStateRevision.modify { value in
                let next = value &+ 1
                return next
            }
            Task {
                await impl.receiveServerWalletState(value, revision: revision)
            }
        }))

        let transferUpdates = AsyncStream<([WalletTransferUpdate], String?)> { continuation in
            self.walletTransferUpdatesDisposable.set(engine.wallet.transferUpdates().start(next: { [weak self] updates in
                guard let self else { return }
                let address: String?
                if case let .wallet(info) = self.stateValue.phase {
                    address = info.address
                } else {
                    address = nil
                }
                continuation.yield((updates, address))
            }, completed: {
                continuation.finish()
            }))
        }
        self.walletTransferUpdatesTask = Task {
            for await (updates, address) in transferUpdates {
                guard !Task.isCancelled else { return }
                await impl.receiveWalletTransferUpdates(updates, walletAddress: address)
            }
        }

        let tonConnectUpdates = AsyncStream<[WalletTonConnectEvent]> { continuation in
            self.tonConnectUpdatesDisposable.set(engine.wallet.tonConnectUpdates().start(next: {
                continuation.yield($0)
            }, completed: { continuation.finish() }))
        }
        self.tonConnectUpdatesTask = Task {
            for await updates in tonConnectUpdates {
                guard !Task.isCancelled else { return }
                await impl.receiveTonConnectUpdates(updates)
            }
        }

        self.environmentDisposable.set(combineLatest(
            applicationInForeground |> distinctUntilChanged,
            accountIsCurrent |> distinctUntilChanged,
            networkAvailable |> distinctUntilChanged,
            applicationIsPasscodeLocked |> distinctUntilChanged
        ).start(next: { [weak self] foreground, current, network, locked in
            guard let self else { return }
            authorization.setAvailable(foreground && current && !locked)
            if !current { authorization.invalidate() }
            let revision = self.environmentRevision.modify { value in
                let next = value &+ 1
                return next
            }
            Task {
                await impl.updateEnvironment(
                    foreground: foreground,
                    accountIsCurrent: current,
                    networkAvailable: network,
                    revision: revision
                )
            }
        }))

        self.storedStateDisposable.set((engine.data.get(
            TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(
                key: ApplicationSpecificPreferencesKeys.walletState
            )
        )).start(next: { entry in
            let storedState: WalletStoredState?
            let isInvalid: Bool
            if let entry {
                if let value = entry.get(WalletStoredState.self),
                   value.schemaVersion == WalletStoredState.currentSchemaVersion {
                    storedState = value
                    isInvalid = false
                } else {
                    storedState = nil
                    isInvalid = true
                }
            } else {
                storedState = nil
                isInvalid = false
            }
            Task {
                await impl.restoreStoredState(storedState, removeInvalidEntry: isInvalid)
            }
        }))
    }

    deinit {
        self.authorization.invalidate()
        self.credentialChangesDisposable.dispose()
        self.environmentDisposable.dispose()
        self.walletConfigurationDisposable.dispose()
        self.walletStateUpdatesDisposable.dispose()
        self.walletTransferUpdatesDisposable.dispose()
        self.walletTransferUpdatesTask?.cancel()
        self.tonConnectUpdatesDisposable.dispose()
        self.tonConnectUpdatesTask?.cancel()
        self.storedStateDisposable.dispose()
        self.operationTaskRegistry.shutdown()
        let impl = self.impl
        Task {
            await impl.shutdown()
        }
    }

    func signal<Value: Sendable>(
        name: String,
        cancelOnDispose: Bool = true,
        submissionControl: WalletTransferSubmissionControl? = nil,
        deliverWhenAvailable: Bool = false,
        discardResult: (@Sendable (Value) -> Void)? = nil,
        discardOnCancel: (@Sendable () -> Void)? = nil,
        validateResult: (@Sendable (Value) throws -> Void)? = nil,
        operation: @escaping @Sendable (WalletContextImpl, UUID) async throws -> Value
    ) -> Signal<Value, WalletError> {
        let source = Signal<Value, WalletError> { [weak self] subscriber in
            guard let self else {
                subscriber.putError(.unavailable)
                return EmptyDisposable
            }
            let operationId = UUID()
            let cancellation = WalletOperationCancellation()
            let registry = self.operationTaskRegistry
            let logger = self.logger
            let impl = self.impl
            let authorization = self.authorization
            let deliveryCancellation = WalletOperationCancellation()
            let lock = NSRecursiveLock()
            var cancelled = false
            var delivered = false
            var pending: Result<Value, WalletError>?
            let discard: (Result<Value, WalletError>) -> Void = { result in
                if case let .success(value) = result { discardResult?(value) }
            }
            let enqueue: (Result<Value, WalletError>) -> Bool = { result in
                lock.lock(); defer { lock.unlock() }
                guard !cancelled else { return false }
                pending = result
                return true
            }
            let receive: (Result<Value, WalletError>, UInt64) async throws -> Void = { result, generation in
                while true {
                    if deliverWhenAvailable { try await authorization.waitUntilAvailable(generation: generation) }
                    let finished = await withCheckedContinuation { continuation in
                        Queue.mainQueue().async {
                            lock.lock(); defer { lock.unlock() }
                            guard !cancelled, let result = pending else { continuation.resume(returning: true); return }
                            if deliverWhenAvailable && !authorization.isAvailable {
                                continuation.resume(returning: false)
                                return
                            }
                            pending = nil
                            do {
                                if deliverWhenAvailable { try authorization.validateGeneration(generation, requireAvailable: false) }
                                switch result {
                                case let .success(value):
                                    try validateResult?(value)
                                    delivered = true
                                    subscriber.putNext(value)
                                    subscriber.putCompletion()
                                case let .failure(error):
                                    subscriber.putError(error)
                                }
                            } catch {
                                discard(result)
                                subscriber.putError(walletError(error))
                            }
                            continuation.resume(returning: true)
                        }
                    }
                    if finished { return }
                }
            }
            let cancelDelivery: () -> Void = {
                Queue.mainQueue().async {
                    lock.lock(); defer { lock.unlock() }
                    guard !cancelled else { return }
                    if let result = pending { pending = nil; discard(result) }
                    subscriber.putError(.authorizationCancelled)
                }
            }
            if deliverWhenAvailable { authorization.beginResultDelivery(id: operationId) }
            registry.register(id: operationId, cancellation: cancellation)
            let task = Task {
                defer {
                    registry.remove(id: operationId)
                    if deliverWhenAvailable { authorization.finishResultDelivery(id: operationId) }
                }
                let result: Result<Value, WalletError>
                do {
                    try Task.checkCancellation()
                    let value = try await operation(impl, operationId)
                    if Task.isCancelled {
                        discardResult?(value)
                        throw CancellationError()
                    }
                    result = .success(value)
                } catch let error as CancellationError {
                    logger.error("wallet_operation_cancelled", error, context: "operation=\(name)")
                    result = .failure(.authorizationCancelled)
                } catch {
                    logger.error("wallet_operation_failed", error, context: "operation=\(name)")
                    result = .failure(walletError(error))
                }
                let deliver: () async -> Void = {
                    guard enqueue(result) else { discard(result); return }
                    do {
                        let generation = deliverWhenAvailable ? try authorization.resultDeliveryGeneration(id: operationId) : 0
                        try await receive(result, generation)
                    } catch {
                        cancelDelivery()
                    }
                }
                if deliverWhenAvailable {
                    let delivery = Task { await deliver() }
                    deliveryCancellation.setTask(delivery)
                    await delivery.value
                } else {
                    await deliver()
                }
            }
            cancellation.setTask(task)
            return ActionDisposable {
                lock.lock(); defer { lock.unlock() }
                cancelled = true
                deliveryCancellation.cancel()
                if cancelOnDispose || submissionControl?.cancelBeforeCommit() == true {
                    registry.cancel(id: operationId)
                }
                if !delivered {
                    if let result = pending {
                        pending = nil
                        discard(result)
                    }
                    discardOnCancel?()
                }
            }
        }
        return source |> deliverOnMainQueue
    }

    func noErrorSignal(
        operation: @escaping @Sendable (WalletContextImpl) async -> Void
    ) -> Signal<Void, NoError> {
        let impl = self.impl
        let source = Signal<Void, NoError> { subscriber in
            let task = Task {
                await operation(impl)
                guard !Task.isCancelled else { return }
                subscriber.putNext(Void())
                subscriber.putCompletion()
            }
            return ActionDisposable { task.cancel() }
        }
        return source |> deliverOnMainQueue
    }
}

@available(macOS 10.15, *)
public struct WalletConfiguration: Equatable, Sendable {
    public static var defaultValue: WalletConfiguration {
        return WalletConfiguration(
            isAvailable: false,
            explorerUrl: "https://tonscan.org",
            transferMinAmount: 100_000_000,
            transferGaslessMinAmount: 100_000_000,
            transferGaslessDailyLimit: 5
        )
    }

    public let isAvailable: Bool
    public let explorerUrl: String
    public let transferMinAmount: Int64
    public let transferGaslessMinAmount: Int64
    public let transferGaslessDailyLimit: Int32

    private init(
        isAvailable: Bool,
        explorerUrl: String,
        transferMinAmount: Int64,
        transferGaslessMinAmount: Int64,
        transferGaslessDailyLimit: Int32
    ) {
        self.isAvailable = isAvailable
        self.explorerUrl = explorerUrl
        self.transferMinAmount = transferMinAmount
        self.transferGaslessMinAmount = transferGaslessMinAmount
        self.transferGaslessDailyLimit = transferGaslessDailyLimit
    }

    public static func with(appConfiguration: AppConfiguration) -> WalletConfiguration {
        let isAvailable = appConfiguration.data?["wallet_available"] as? Bool ?? self.defaultValue.isAvailable
        var explorerUrl = self.defaultValue.explorerUrl
        if let value = appConfiguration.data?["ton_blockchain_explorer_url"] as? String {
            explorerUrl = value
        }
        var transferMinAmount = self.defaultValue.transferMinAmount
        if let value = appConfiguration.data?["wallet_transfer_min_nanos"] as? Double,
           let intValue = Int64(exactly: value) {
            transferMinAmount = intValue
        }
        var transferGaslessMinAmount = self.defaultValue.transferGaslessMinAmount
        if let value = appConfiguration.data?["wallet_gasless_min_nanos"] as? Double,
           let intValue = Int64(exactly: value), intValue >= 0 {
            transferGaslessMinAmount = intValue
        }
        var transferGaslessDailyLimit = self.defaultValue.transferGaslessDailyLimit
        if let value = appConfiguration.data?["wallet_gasless_daily_transfers"] as? Double {
            transferGaslessDailyLimit = Int32(value)
        }
        return WalletConfiguration(
            isAvailable: isAvailable,
            explorerUrl: explorerUrl,
            transferMinAmount: transferMinAmount,
            transferGaslessMinAmount: transferGaslessMinAmount,
            transferGaslessDailyLimit: transferGaslessDailyLimit
        )
    }
}
