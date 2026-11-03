import SwiftUI
import TDShim

@main
struct TgwatchApp: App {
    @State private var manager: AccountManager
    /// True when running inside an XCTest process. Computed once and stored so
    /// both `init()` and `body` can reference the same value without repeating
    /// the `NSClassFromString` lookup.
    private let isUnderXCTest: Bool = NSClassFromString("XCTestCase") != nil

    @MainActor
    init() {
        TgwatchApp.wipeMessageDatabaseIfRequested()
        // Under XCTest the app's `@main` `init()` still runs inside the test
        // process. Instantiating a `TDLibClientManager` here would conflict
        // with the one tests create via `SharedTestTDLibManager` (TDLib's
        // `td_receive` is single-thread-global — see CLAUDE.md gotcha). Hand
        // the test process a no-bootstrap manager; tests never drive the
        // SwiftUI scene, so its `factory` is never invoked.
        let factory: any TDClientFactory
        if isUnderXCTest {
            factory = NoopTDClientFactory()
        } else {
            factory = LiveTDClientFactory(manager: TDLibClientManager())
        }
        let mgr = AccountManager(
            registry: .defaultProduction(),
            factory: factory
        )
        if !isUnderXCTest {
            mgr.bootstrap()
        }
        _manager = State(initialValue: mgr)
    }

    var body: some Scene {
        WindowGroup {
            if let client = manager.activeClient {
                ContentView()
                    .environment(client)
                    .environment(manager)
                    .id(manager.activeAccountId)
            } else if !isUnderXCTest {
                // Under XCTest the scene is not test-driven; suppress
                // AccountBootstrapView so its .task doesn't call
                // ensureAccountExists() → factory.make() via NoopTDClientFactory.
                AccountBootstrapView()
                    .environment(manager)
            }
        }
    }

    /// DEBUG-only: deletes TDLib's sqlite message-database files (keeping
    /// `td.binlog`, which holds auth keys) for every existing account dir
    /// when `TGWATCH_WIPE_MESSAGE_DB=1`. Each launch then re-fetches chat
    /// history from the server cold.
    private static func wipeMessageDatabaseIfRequested() {
#if DEBUG
        guard ProcessInfo.processInfo.environment["TGWATCH_WIPE_MESSAGE_DB"] == "1" else { return }
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("tdlib", isDirectory: true)
        guard let entries = try? fm.contentsOfDirectory(at: base, includingPropertiesForKeys: nil) else { return }
        for entry in entries {
            guard UUID(uuidString: entry.lastPathComponent) != nil else { continue }
            for name in ["db.sqlite", "db.sqlite-shm", "db.sqlite-wal"] {
                try? fm.removeItem(at: entry.appendingPathComponent(name))
            }
        }
#endif
    }
}
