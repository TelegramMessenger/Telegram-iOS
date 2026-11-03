import Foundation
import Observation
import OSLog
import TDShim

/// Receives lifecycle events from a `TDClient` that need to be reflected in
/// the wider app (registry updates, account removal). Held weakly by TDClient.
@MainActor
protocol TDClientLifecycleDelegate: AnyObject {
    /// `getMe()` returned. Implementor should harvest display name, phone,
    /// user id into the account record.
    func tdClient(_ client: TDClient, didFetchMe me: User)
    /// TDClient self-destructed (stuck-loggingOut watchdog forced a local
    /// `destroy()`). Implementor should drop the account record + dir,
    /// mirroring user-initiated removal.
    ///
    /// **Re-entrancy contract:** the watchdog can fire AFTER an
    /// `awaitClosed()` timeout, by which time the controller may have
    /// already moved on to a different active account. Implementors MUST
    /// identity-check `client` (e.g. `client.account.id == activeAccountId`)
    /// before acting, or they'll remove the wrong account.
    func tdClient(_ client: TDClient, didDestroyItselfWithReason reason: TDClientDestroyReason)
}

enum TDClientDestroyReason: Equatable {
    case stuckLoggingOut
}

@Observable
@MainActor
final class TDClient {

    let account: Account
    var useTestDc: Bool { account.useTestDc }

    private(set) var authState: AuthState = .starting
    private(set) var me: User? = nil
    private(set) var lastError: String? = nil
    let userNames = UserNamesStore()
    private(set) var chatList: ChatListStore? = nil
    private(set) var activeHistory: ChatHistoryStore? = nil

    func setActiveHistory(_ store: ChatHistoryStore?) {
        activeHistory = store
    }

    func makeChatHistoryLoader() -> ChatHistoryLoader? {
        guard let client else { return nil }
        return TDLibChatHistoryLoader(client: client)
    }

    private(set) var activeStickerPicker: StickerPickerStore? = nil

    func setActiveStickerPicker(_ store: StickerPickerStore?) {
        activeStickerPicker = store
    }

    func makeStickerPickerLoader() -> StickerPickerLoader? {
        guard let client else { return nil }
        return TDLibStickerPickerLoader(client: client)
    }

    /// Auth-state transitions and user-initiated lifecycle calls log at `.notice`
    /// (default level). `.notice` is reliably persisted by Apple's unified log;
    /// `.info` is memory-only for non-system subsystems and disappears from
    /// `log show` after a brief window. Without persistence it's impossible to
    /// tell post-hoc whether a logging-out transition came from the user or from
    /// a server-initiated kick.
    private let logger = Logger(subsystem: "com.isaac.tgwatch", category: "tdlib")
    private let manager: TDLibClientManager
    private weak var delegate: TDClientLifecycleDelegate?
    private let qrLinkPublisher: QrLinkPublisher = .defaultProduction()
    /// Per-process UUID exposed to QrLinkPublisher so the CLI can detect a
    /// watch restart mid-poll.
    private let sessionId = UUID()
    private var client: TDLibClient?

    private var hasSentTdlibParameters = false
    private var hasFetchedMe = false

    /// Resumed when the active TDLib client reaches `authorizationStateClosed`.
    /// Multiple waiters are supported so concurrent callers (e.g.
    /// `awaitClosed()` from `AccountManager.switchTo` overlapping with the
    /// stuck-loggingOut watchdog inside `forceDestroy()`) don't clobber each
    /// other's continuation.
    private var closingContinuations: [CheckedContinuation<Void, Never>] = []

    /// Watchdog armed when authState enters `.loggingOut`. If the state hasn't
    /// changed after `kStuckLoggingOutTimeout` it calls `client.destroy()` to
    /// force a local-only logout. Cancelled on any other auth-state transition.
    private var stuckLoggingOutTask: Task<Void, Never>?

    init(account: Account, manager: TDLibClientManager, delegate: TDClientLifecycleDelegate) {
        self.account = account
        self.manager = manager
        self.delegate = delegate
    }

    /// Submits the cloud password. Returns `nil` on success, or a user-facing
    /// error message (see `passwordSubmitErrorMessage`) on failure. Does not
    /// touch the shared `lastError` — the password screen owns its own alert.
    func submitPassword(_ password: String) async -> String? {
        guard let client else { return nil }
        do {
            _ = try await client.checkAuthenticationPassword(password: password)
            return nil
        } catch {
            logger.warning("checkAuthenticationPassword failed: \(error.localizedDescription, privacy: .public)")
            return passwordSubmitErrorMessage(error)
        }
    }

    /// Re-requests QR authentication from the `waitPassword` state, driving
    /// TDLib back to `waitOtherDeviceConfirmation`. Valid because
    /// `requestQrCodeAuthentication` is callable from `authorizationStateWaitPassword`
    /// when no auth query is pending. Returns `nil` on success, or a user-facing
    /// error message on failure. Does not touch `authState` — the QR screen
    /// renders via the normal `updateAuthorizationState` path; on failure the
    /// caller (the password screen) shows the message in its own alert and stays
    /// put, so we deliberately avoid the `.failed` transition that
    /// `requestQrCodeAuthenticationIfNeeded()` performs.
    func returnToQrCode() async -> String? {
        guard let client else { return nil }
        logger.notice("returnToQrCode requested by UI")
        do {
            _ = try await client.requestQrCodeAuthentication(otherUserIds: [])
            return nil
        } catch {
            logger.warning("returnToQrCode failed: \(error.localizedDescription, privacy: .public)")
            return humanMessage(error)
        }
    }

    func logOut() async {
        guard let client else { return }
        lastError = nil
        logger.notice("logOut requested by UI")
        do {
            _ = try await client.logOut()
        } catch {
            logger.warning("logOut failed: \(error.localizedDescription, privacy: .public)")
            lastError = humanMessage(error)
        }
    }

    /// Closes the TDLib client without ending the server-side session. Used
    /// by `AccountManager` when switching to a different account: the
    /// previous account stays signed in, its db dir stays valid. Pair with
    /// `awaitClosed()`.
    func close() async {
        guard let client else { return }
        do {
            _ = try await client.close()
        } catch {
            logger.warning("client.close failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Awaits `authorizationStateClosed` (or 5s timeout). Used by
    /// `AccountManager` to orchestrate switch / removal. Safe to call when
    /// `client` is nil — resolves immediately.
    func awaitClosed(timeout: TimeInterval = 5) async {
        guard client != nil else { return }
        if case .closed = authState { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.closingContinuations.append(continuation)
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if !self.closingContinuations.isEmpty {
                        self.logger.warning("awaitClosed: timed out after \(Int(timeout))s; forcing recreate")
                        self.resumeClosingIfPending()
                    }
                }
            }
        }
    }

    func start() {
        switch validateSecrets(apiId: Secrets.apiId, apiHash: Secrets.apiHash) {
        case .failure(let err):
            authState = .failed(err.humanMessage)
            return
        case .success:
            break
        }

        qrLinkPublisher.clear()
        let logger = self.logger
        let client = manager.createClient { [weak self] data, callbackClient in
            let update: Update
            do {
                update = try callbackClient.decoder.decode(Update.self, from: data)
            } catch {
                logger.warning("update decode failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            DispatchQueue.main.async { [weak self] in
                self?.handle(update)
            }
        }
        self.client = client

        let verbosity: Int = ProcessInfo.processInfo.environment["TGWATCH_TDLIB_VERBOSITY"]
            .flatMap { Int($0) } ?? 1
        Task { [logger, client] in
            do {
                _ = try await client.setLogVerbosityLevel(newVerbosityLevel: verbosity)
            } catch {
                logger.warning("setLogVerbosityLevel failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func handle(_ update: Update) {
        if case .updateAuthorizationState(let upd) = update {
            lastError = nil
            let mapped = mapAuthState(upd.authorizationState)
            authState = mapped
            logger.notice("authState -> \(String(describing: mapped), privacy: .public)")

            switch mapped {
            case .waitOtherDeviceConfirmation(let link):
                qrLinkPublisher.publish(link: link, useTestDc: useTestDc, sessionId: sessionId)
            default:
                qrLinkPublisher.clear()
            }

            if case .waitTdlibParameters = mapped, !hasSentTdlibParameters {
                hasSentTdlibParameters = true
                sendTdlibParameters()
            }
            if case .waitPhoneNumber = mapped {
                requestQrCodeAuthenticationIfNeeded()
            }
            if case .ready = mapped {
                if !hasFetchedMe {
                    hasFetchedMe = true
                    fetchMe()
                }
                if chatList == nil, let client {
                    chatList = ChatListStore(
                        loader: TDLibChatListLoader(client: client),
                        selfUserId: me?.id,
                        userNames: userNames,
                        coalesceUpdates: true
                    )
                }
            }
            if case .loggingOut = mapped {
                chatList = nil
                activeHistory = nil
                activeStickerPicker = nil
                armStuckLoggingOutWatchdog()
            } else {
                stuckLoggingOutTask?.cancel()
                stuckLoggingOutTask = nil
            }
            if case .closed = mapped {
                chatList = nil
                activeHistory = nil
                activeStickerPicker = nil
                resumeClosingIfPending()
            }
            return
        }

        userNames.handle(update)
        chatList?.handle(update)
        activeHistory?.handle(update)
        activeStickerPicker?.handle(update)
    }

    /// Fired on every `waitPhoneNumber` transition. TDLib advances to
    /// `waitOtherDeviceConfirmation` immediately on success so we don't see
    /// `waitPhoneNumber` twice in one session; on the off chance we do (e.g.
    /// logout loop), TDLib treats the second call as idempotent or errors —
    /// both handled.
    private func requestQrCodeAuthenticationIfNeeded() {
        guard let client else { return }
        Task { [logger, client] in
            do {
                _ = try await client.requestQrCodeAuthentication(otherUserIds: [])
            } catch {
                logger.warning("requestQrCodeAuthentication failed: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor [weak self] in
                    self?.lastError = humanMessage(error)
                    self?.authState = .failed(humanMessage(error))
                }
            }
        }
    }

    /// Number of seconds we wait for `.loggingOut` to clear on its own before
    /// concluding that TDLib is stuck and forcing a local destroy. A normal
    /// client-initiated logout completes in well under 2s; we picked 15s to
    /// stay comfortably above that while still recovering quickly.
    private static let kStuckLoggingOutTimeout: TimeInterval = 15

    /// Recovery for the "TDLib is stuck on .loggingOut forever" failure mode
    /// we hit when Telegram's backend force-terminates the session unilaterally
    /// (e.g. anti-third-party-client heuristic kicks in). The local db is left
    /// marked "logging out, please confirm with server" but the corresponding
    /// auth_key is already gone server-side, so every reconnect to the home DC
    /// fails with `auth_key_id mismatch` and the logout never completes —
    /// TDLib has no built-in timeout for this loop.
    ///
    /// `client.destroy()` drops the local db without server confirmation, which
    /// breaks the loop. With multi-account, the destroy is followed by a
    /// delegate callback so `AccountManager` can drop this account's record +
    /// dir entirely (matching the "logout = remove" UX). See
    /// CLAUDE.md "TDLib gets stuck on authorizationStateLoggingOut" gotcha.
    private func armStuckLoggingOutWatchdog() {
        stuckLoggingOutTask?.cancel()
        let timeout = Self.kStuckLoggingOutTimeout
        stuckLoggingOutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            await self.forceDestroyIfStillStuck(timeout: timeout)
        }
    }

    private func forceDestroyIfStillStuck(timeout: TimeInterval) async {
        guard case .loggingOut = authState else { return }
        logger.notice("authState stuck on loggingOut for \(Int(timeout))s — calling destroy()")
        await forceDestroy()
    }

    /// Calls `destroy()` on the active TDLib client, awaits the resulting
    /// `authorizationStateClosed`, then signals the delegate so
    /// `AccountManager` can drop this account's record + dir.
    private func forceDestroy() async {
        guard let captured = client else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            self.closingContinuations.append(continuation)
            Task { [logger, captured] in
                do {
                    _ = try await captured.destroy()
                } catch {
                    logger.warning("destroy() failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    if !self.closingContinuations.isEmpty {
                        self.logger.warning("forceDestroy: timed out waiting for closed; forcing recreate")
                        self.resumeClosingIfPending()
                    }
                }
            }
        }

        me = nil
        chatList = nil
        activeHistory = nil
        activeStickerPicker = nil
        hasSentTdlibParameters = false
        hasFetchedMe = false
        lastError = nil
        qrLinkPublisher.clear()
        stuckLoggingOutTask = nil
        client = nil
        // authState was already moved to .closed by handle(update) when
        // TDLib emitted authorizationStateClosed after destroy().
        delegate?.tdClient(self, didDestroyItselfWithReason: .stuckLoggingOut)
    }

    private func sendTdlibParameters() {
        guard let client else { return }
        let useTest = self.useTestDc
        let dbDir = Self.databaseDirectory(accountId: account.id)
        Task { [logger, client] in
            do {
                _ = try await client.setTdlibParameters(
                    apiHash: Secrets.apiHash,
                    apiId: Secrets.apiId,
                    applicationVersion: "0.1",
                    databaseDirectory: dbDir.path,
                    databaseEncryptionKey: nil,
                    deviceModel: "Apple Watch",
                    filesDirectory: dbDir.path,
                    systemLanguageCode: "en",
                    systemVersion: nil,
                    useChatInfoDatabase: true,
                    useFileDatabase: true,
                    useMessageDatabase: true,
                    useSecretChats: false,
                    useTestDc: useTest
                )
            } catch {
                logger.error("setTdlibParameters failed: \(error.localizedDescription, privacy: .public)")
                Task { @MainActor [weak self] in
                    self?.authState = .failed(humanMessage(error))
                }
            }
        }
    }

    private func fetchMe() {
        guard let client else { return }
        Task { [logger, client] in
            do {
                let user = try await client.getMe()
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.me = user
                    self.chatList?.setSelfUserId(user.id)
                    self.delegate?.tdClient(self, didFetchMe: user)
                }
            } catch {
                logger.warning("getMe failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func resumeClosingIfPending() {
        let waiters = closingContinuations
        closingContinuations.removeAll()
        for c in waiters {
            c.resume()
        }
    }

    /// Per-account TDLib database directory:
    /// `<applicationSupport>/tdlib/<accountId.uuidString>/`.
    nonisolated static func databaseDirectory(accountId: UUID) -> URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("tdlib", isDirectory: true)
        let dir = base.appendingPathComponent(accountId.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
