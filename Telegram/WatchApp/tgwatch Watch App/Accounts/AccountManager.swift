import Foundation
import Observation
import OSLog
import TDShim

/// App-root orchestrator: owns the account registry and the single live
/// `TDClient`. Inactive accounts are merely on-disk database dirs.
@Observable
@MainActor
final class AccountManager: TDClientLifecycleDelegate {

    private(set) var accounts: [Account]
    private(set) var activeAccountId: UUID?
    private(set) var activeClient: TDClient?
    private(set) var lastError: String?

    private let registry: AccountRegistry
    private let factory: TDClientFactory
    private let environment: [String: String]
    private let accountDirectoryRemover: (UUID) -> Void
    private let now: () -> Foundation.Date
    private let logger = Logger(subsystem: "com.isaac.tgwatch", category: "accounts")

    init(
        registry: AccountRegistry,
        factory: TDClientFactory,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        accountDirectoryRemover: ((UUID) -> Void)? = nil,
        now: @escaping () -> Foundation.Date = { Foundation.Date() }
    ) {
        self.registry = registry
        self.factory = factory
        self.environment = environment
        self.now = now
        self.accountDirectoryRemover = accountDirectoryRemover ?? { id in
            let url = TDClient.databaseDirectory(accountId: id)
            try? FileManager.default.removeItem(at: url)
        }
        self.accounts = []
        self.activeAccountId = nil
    }

    /// Loads the registry and brings up the active client (if any). On a
    /// truly fresh launch with `TGWATCH_USE_TEST_DC=1` set, seeds and starts
    /// a test-DC account so the smoke harness sees QR immediately. All
    /// work here is synchronous so callers (and tests) can read post-state
    /// without awaiting.
    func bootstrap() {
        guard activeClient == nil, accounts.isEmpty, activeAccountId == nil else {
            logger.warning("bootstrap called twice — ignoring")
            return
        }
        let state: AccountRegistryState
        do {
            state = try registry.load()
        } catch {
            logger.warning("registry load failed: \(error.localizedDescription, privacy: .public) — starting empty")
            self.accounts = []
            self.activeAccountId = nil
            return
        }
        self.accounts = state.accounts
        self.activeAccountId = state.activeAccountId

        if accounts.isEmpty, shouldSeedTestDcAccountFromEnv() {
            appendAndStart(account: makeNewAccount(useTestDc: true))
            return
        }

        if let id = activeAccountId, let account = accounts.first(where: { $0.id == id }) {
            startClient(for: account)
        }
    }

    /// Ensures at least one account exists by creating and starting a fresh
    /// **Production** account when the registry is empty and no client is
    /// active. Idempotent — the guard makes repeat calls safe — and
    /// synchronous like `bootstrap()` so callers/tests can read post-state
    /// without awaiting. Drives the no-welcome auto-QR flow: whenever
    /// `activeClient` is nil, `AccountBootstrapView` calls this to land the
    /// app on QR login. Persist-failure handling (revert + `lastError`) is
    /// inherited from `appendAndStart`.
    func ensureAccountExists() {
        guard accounts.isEmpty, activeClient == nil else { return }
        appendAndStart(account: makeNewAccount(useTestDc: false))
    }

    /// Adds a new account, persists, makes it active, and brings up a
    /// fresh `TDClient` against its (empty) database directory. The
    /// previous active account (if any) is **closed**, not logged out —
    /// its server-side session and on-disk db stay intact.
    func addAccount(useTestDc: Bool) async {
        await closePreviousIfAny()
        appendAndStart(account: makeNewAccount(useTestDc: useTestDc))
    }

    /// Closes the current client and starts the chosen account's client.
    /// Same close-not-logOut semantics as `addAccount`.
    func switchTo(accountId: UUID) async {
        guard accountId != activeAccountId else { return }
        guard let account = accounts.first(where: { $0.id == accountId }) else { return }
        await closePreviousIfAny()
        activeAccountId = account.id
        updateLastActive(account.id)
        persist()
        startClient(for: account)
    }

    /// Logs out + removes the on-disk dir for the active account, picks
    /// the next-most-recently-active among the survivors, brings it up.
    /// Uses `logOut()` (not `close()`) so the server-side session is
    /// destroyed for the removed account.
    func removeActive() async {
        guard let id = activeAccountId else { return }
        if let current = activeClient {
            await current.logOut()
            await current.awaitClosed()
        }
        activeClient = nil
        accounts.removeAll { $0.id == id }
        accountDirectoryRemover(id)
        if let next = accounts.sorted(by: { $0.lastActiveAt > $1.lastActiveAt }).first {
            activeAccountId = next.id
            persist()
            startClient(for: next)
        } else {
            activeAccountId = nil
            persist()
        }
    }

    /// Removes an inactive account. No client teardown needed.
    func remove(accountId: UUID) async {
        guard accountId != activeAccountId else {
            await removeActive()
            return
        }
        accounts.removeAll { $0.id == accountId }
        accountDirectoryRemover(accountId)
        persist()
    }

    // MARK: TDClientLifecycleDelegate

    func tdClient(_ client: TDClient, didFetchMe me: User) {
        // Guard against stale callbacks from a previously-active client
        // (e.g., a getMe in flight when the user switched accounts).
        guard client.account.id == activeAccountId else { return }
        guard let idx = accounts.firstIndex(where: { $0.id == client.account.id }) else { return }
        var updated = accounts[idx]
        let first = me.firstName
        let last = me.lastName
        let combined = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
        updated.displayName = combined.isEmpty ? nil : combined
        updated.phoneNumber = me.phoneNumber.isEmpty ? nil : me.phoneNumber
        updated.userId = Int64(me.id)
        accounts[idx] = updated
        persist()
    }

    func tdClient(_ client: TDClient, didDestroyItselfWithReason reason: TDClientDestroyReason) {
        switch reason {
        case .stuckLoggingOut:
            // Identity-check: the watchdog can fire after switchTo already moved
            // on. Only act if the destroyed client is still the active account.
            guard client.account.id == activeAccountId else { return }
            // Capture target id at delegate time, then re-verify inside the
            // Task body: `Task { await ... }` suspends, and activeAccountId
            // can flip between scheduling and execution.
            let target = client.account.id
            Task { [weak self] in
                guard let self else { return }
                guard self.activeAccountId == target else { return }
                await self.removeActive()
            }
        }
    }

    // MARK: Private

    private func startClient(for account: Account) {
        let client = factory.make(account: account, delegate: self)
        activeClient = client
        client.start()
    }

    private func closePreviousIfAny() async {
        guard let current = activeClient else { return }
        await current.close()
        await current.awaitClosed()
        activeClient = nil
    }

    private func makeNewAccount(useTestDc: Bool) -> Account {
        Account(
            id: UUID(),
            useTestDc: useTestDc,
            displayName: nil,
            phoneNumber: nil,
            userId: nil,
            createdAt: now(),
            lastActiveAt: now()
        )
    }

    /// Appends the account, makes it active, persists, and starts its
    /// `TDClient`. On persist failure, reverts in-memory state to match
    /// the (failed) disk write so the user doesn't see a phantom account
    /// that disappears on next launch. The user sees `lastError` in
    /// `AccountsListView` / `AccountBootstrapView` and can retry.
    private func appendAndStart(account: Account) {
        let previousAccounts = accounts
        let previousActiveId = activeAccountId
        accounts.append(account)
        activeAccountId = account.id
        guard persist() else {
            accounts = previousAccounts
            activeAccountId = previousActiveId
            return
        }
        startClient(for: account)
    }

    /// Returns true on success, false on save failure. On failure
    /// `lastError` is set to a user-facing string. On success `lastError`
    /// is cleared so transient hiccups don't show forever.
    @discardableResult
    private func persist() -> Bool {
        let state = AccountRegistryState(version: 1, activeAccountId: activeAccountId, accounts: accounts)
        do {
            try registry.save(state)
            lastError = nil
            return true
        } catch {
            logger.warning("registry save failed: \(error.localizedDescription, privacy: .public)")
            lastError = "Couldn't save account list."
            return false
        }
    }

    private func updateLastActive(_ id: UUID) {
        guard let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[idx].lastActiveAt = now()
    }

    private func shouldSeedTestDcAccountFromEnv() -> Bool {
#if DEBUG
        return environment["TGWATCH_USE_TEST_DC"] == "1"
#else
        return false
#endif
    }
}
