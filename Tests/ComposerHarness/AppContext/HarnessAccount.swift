import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import PasscodeCore
import OpenSSLEncryptionProvider

/// A genuine `Account` over a disposable Postbox, with networking switched off.
///
/// **Why this is not a mock.** `Account` is a concrete class whose designated initialiser
/// (`TelegramCore/Sources/Account/Account.swift:95`) is internal, so it can be neither constructed
/// directly nor stubbed. It is reachable through public API only by seeding a fresh postbox with an
/// `AuthorizedAccountState`: `accountWithId` decides between `.unauthorized` and `.authorized` by
/// reading that stored state's peerId (`Account.swift:352`). Hence the two passes below.
///
/// `shouldKeepAutoConnection: false` is load-bearing, and so is the loopback proxy written before the
/// first open (below) — the harness must be hermetic.
/// `supplementary: true` matches what SiriIntents/NotificationService use for a non-syncing
/// account, and keeps the main state manager out of the picture.
public final class HarnessAccount {
    public let rootPath: String
    public let account: Account
    /// The manager the account was opened through. `SharedAccountContext.accountManager` hands
    /// out this one, so shared-data reads (emoji suggestions read theirs on every keystroke that
    /// produces an emoji) go to the same store the account lives in.
    public let accountManager: AccountManager<TelegramAccountManagerTypes>

    private init(rootPath: String, account: Account, accountManager: AccountManager<TelegramAccountManagerTypes>) {
        self.rootPath = rootPath
        self.account = account
        self.accountManager = accountManager
    }

    /// A synthetic self-peer. Nothing resolves it; the panel only ever reads its id.
    public static let harnessPeerId = PeerId(
        namespace: Namespaces.Peer.CloudUser,
        id: PeerId.Id._internalFromInt64Value(777000)
    )

    public static func make() -> Signal<HarnessAccount, NoError> {
        let rootPath = NSTemporaryDirectory() + "composer-harness-" + UUID().uuidString
        try? FileManager.default.createDirectory(
            atPath: rootPath, withIntermediateDirectories: true, attributes: nil)

        // `Logger.shared` traps through `assertionFailure()` when no shared logger has been
        // installed (`TelegramCore/Sources/Utils/Log.swift:120`), and Postbox logs while it opens,
        // so without this the very first `accountWithId` dies with a bare "Fatal error". The app
        // installs a logger at startup; a harness has to do the same.
        // Both sinks are off: the harness's signal is the model readout, not a log flood. Flip
        // `logToConsole` when you need `simctl launch --console-pty` to show TelegramCore's own log.
        let logger = Logger(rootPath: rootPath, basePath: rootPath + "/logs")
        logger.logToFile = false
        logger.logToConsole = false
        Logger.setSharedLogger(logger)
        // Process-scoped for the same reason the account is: a replaced shared logger is released
        // wherever the replacement happens to run. See HarnessProcessRetainer.
        HarnessProcessRetainer.retain(logger)

        initializeAccountManagement()
        let accountManager: AccountManager<TelegramAccountManagerTypes> = setupAccountManager(
            basePath: rootPath + "/accounts-metadata",
            isTemporary: true,
            isReadOnly: false,
            useCaches: false,
            removeDatabaseOnError: true
        )
        // The account manager owns a value box of its own, and was originally held only by the
        // `open()` closure below — so it died the moment the signal completed. Same rule.
        HarnessProcessRetainer.retain(accountManager)

        // Fixed key/salt: the database is thrown away, and a constant keeps launches reproducible.
        // Key must be exactly 32 bytes and salt exactly 16 (Postbox/Sources/SqliteValueBox.swift).
        let encryptionParameters = ValueBoxEncryptionParameters(
            forceEncryptionIfNoSet: false,
            key: ValueBoxEncryptionParameters.Key(data: Data(repeating: 0xA5, count: 32))!,
            salt: ValueBoxEncryptionParameters.Salt(data: Data(repeating: 0x5A, count: 16))!
        )

        let recordId = generateAccountRecordId()

        func open() -> Signal<AccountResult, NoError> {
            return accountWithId(
                accountManager: accountManager,
                networkArguments: harnessNetworkArguments,
                id: recordId,
                encryptionParameters: encryptionParameters,
                supplementary: true,
                isSupportUser: false,
                rootPath: rootPath,
                beginWithTestingEnvironment: false,
                backupData: nil,
                auxiliaryMethods: harnessAuxiliaryMethods,
                shouldKeepAutoConnection: false
            )
        }

        // **Hermetic: every MTProto connection goes to a closed LOOPBACK port.** `shouldKeepAutoConnection:
        // false` keeps the account from holding a connection, but it does not stop one being opened:
        // MTProto still dialled the seed data centres (149.154.x.x, 95.161.76.100; ports 80 / 443 /
        // 5222) within seconds of launch (p19, seen in the Tier 2 simulator's log). The network's
        // transport is chosen from the account manager's proxy settings when `accountWithId` builds it
        // (`initializedNetwork`), so a SOCKS5 proxy at 127.0.0.1:1 (nothing listens there) turns every
        // dial into a local refusal; nothing leaves the machine and nothing a server answers can reach
        // the harness. Written before the first `open()`, so both passes' networks see it.
        let hermeticProxy = accountManager.transaction { transaction -> Void in
            let _ = updateProxySettingsInteractively(transaction: transaction) { _ in
                let loopback = ProxyServerSettings(host: "127.0.0.1", port: 1,
                                                   connection: .socks5(username: nil, password: nil))
                return ProxySettings(enabled: true, servers: [loopback], activeServer: loopback, useForCalls: false)
            }
        }

        return hermeticProxy
        |> mapToSignal { _ -> Signal<AccountResult, NoError> in
            return open()
        }
        |> mapToSignal { first -> Signal<AccountResult, NoError> in
            // First pass: an empty postbox has no state, so this is `.unauthorized`. Write the
            // state through that account's own postbox, then re-open.
            guard case let .unauthorized(unauthorized) = first else {
                return .single(first)
            }
            return unauthorized.postbox.transaction { transaction -> Void in
                transaction.setState(AuthorizedAccountState(
                    isTestingEnvironment: false,
                    masterDatacenterId: 2,
                    peerId: HarnessAccount.harnessPeerId,
                    state: nil,
                    invalidatedChannels: []
                ))
            }
            |> mapToSignal { _ -> Signal<AccountResult, NoError> in
                return open()
            }
        }
        |> mapToSignal { result -> Signal<HarnessAccount, NoError> in
            guard case let .authorized(account) = result else {
                // Never completing is deliberate: the caller's expectation times out with a clear
                // message, rather than the harness booting into a half-built screen.
                return .never()
            }
            let value = HarnessAccount(rootPath: rootPath, account: account, accountManager: accountManager)
            // Process-scoped; see HarnessProcessRetainer for why this is not optional.
            HarnessProcessRetainer.retain(value)
            return .single(value)
        }
    }
}

/// Throwaway credentials. The harness never connects, so none of these reach a server.
private let harnessNetworkArguments = NetworkInitializationArguments(
    apiId: 1,
    apiHash: "composer-harness",
    languagesCategory: "ios",
    appVersion: "harness",
    voipMaxLayer: 0,
    voipVersions: [],
    appData: .single(nil),
    externalRequestVerificationStream: .never(),
    externalRecaptchaRequestVerification: { _, _ in return .never() },
    autolockDeadine: .single(nil),
    encryptionProvider: OpenSSLEncryptionProvider(),
    deviceModelName: nil,
    useBetaFeatures: false,
    isICloudEnabled: false
)

/// The same shape SiriIntents uses for a non-fetching account.
private let harnessAuxiliaryMethods = AccountAuxiliaryMethods(
    fetchResource: { _, _, _, _ in
        return nil
    }, fetchResourceMediaReferenceHash: { _ in
        return .single(nil)
    }, prepareSecretThumbnailData: { _ in
        return nil
    }, backgroundUpload: { _, _, _ in
        return .single(nil)
    }
)

