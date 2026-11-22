import Foundation
import TDShim

/// Builds a `TDClient` for a given account. Abstracted so `AccountManager`
/// can be unit-tested with a stub factory that never touches TDLib.
@MainActor
protocol TDClientFactory {
    func make(account: Account, delegate: TDClientLifecycleDelegate) -> TDClient
}

/// Production factory: passes the shared `TDLibClientManager` through to
/// every `TDClient` it creates. One manager per process is the documented
/// rule; we honor it by giving everyone the same instance.
@MainActor
struct LiveTDClientFactory: TDClientFactory {
    let manager: TDLibClientManager

    func make(account: Account, delegate: TDClientLifecycleDelegate) -> TDClient {
        TDClient(account: account, manager: manager, delegate: delegate)
    }
}

/// No-op factory used by `TgwatchApp` when running under XCTest. The test
/// process loads the app target so `@main` `init()` still fires, but tests
/// don't drive the SwiftUI scene — so `make` is never called. Allocating a
/// `TDLibClientManager` at all in the test process would conflict with the
/// one tests create themselves (TDLib's `td_receive` is single-thread-global).
@MainActor
struct NoopTDClientFactory: TDClientFactory {
    func make(account: Account, delegate: TDClientLifecycleDelegate) -> TDClient {
        preconditionFailure("NoopTDClientFactory.make called — production code should not see this factory")
    }
}
