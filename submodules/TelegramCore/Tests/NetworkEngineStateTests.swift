import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramApi
@testable import TelegramCore

final class NetworkEngineStateTests: XCTestCase {
    private let build = "12.1 BETA (283290)"
    private let now: Int32 = 1_760_000_000
    private let accounts: Set<Int64> = [1, 2, 3]

    private func configuration(_ values: [String: Any]?) -> AppConfiguration {
        return AppConfiguration(data: values.flatMap { JSON(dictionary: $0) }, hash: values == nil ? 0 : 1)
    }

    private func shared(_ flags: [(Int64, Bool)], build: String? = nil) -> NetworkEngineState {
        var state = NetworkEngineState()
        for (accountId, rustDisabled) in flags {
            state = state.withServerFlag(accountId: accountId, rustDisabled: rustDisabled, build: build ?? self.build, timestamp: self.now, accountIds: self.accounts)
        }
        return state
    }

    func testAnyAccountsServerFlagCounts() {
        XCTAssertTrue(self.shared([(1, true)]).serverDisabledRust(build: self.build))
        XCTAssertTrue(self.shared([(1, true), (2, false)]).serverDisabledRust(build: self.build), "another account's false does not erase it")
        XCTAssertTrue(self.shared([(2, false), (1, true)]).serverDisabledRust(build: self.build), "in either order")
        XCTAssertFalse(self.shared([(1, true), (1, false)]).serverDisabledRust(build: self.build), "an account's own false replaces its true")
        XCTAssertFalse(self.shared([(1, false), (2, false)]).serverDisabledRust(build: self.build))
    }

    func testTheServerFlagCountsOnlyForTheBuildThatGotIt() {
        let state = self.shared([(1, true)])
        XCTAssertFalse(state.serverDisabledRust(build: "12.1 BETA (283291)"), "a fixed build does not inherit it")
        let next = state.withServerFlag(accountId: 2, rustDisabled: false, build: "12.1 BETA (283291)", timestamp: self.now + 60, accountIds: self.accounts)
        XCTAssertEqual(next.serverFlags.map { $0.accountId }, [2], "values of another build are dropped")
    }

    func testValuesOfAccountsThatAreGoneAreDropped() {
        let state = self.shared([(1, true), (2, false)])
        let next = state.withServerFlag(accountId: 2, rustDisabled: false, build: self.build, timestamp: self.now + 60, accountIds: [2])
        XCTAssertFalse(next.serverDisabledRust(build: self.build), "a logged-out account's true no longer counts")
    }

    func testAnAccountThatIsGoneRecordsNothing() {
        let state = NetworkEngineState().withServerFlag(accountId: 4, rustDisabled: true, build: self.build, timestamp: self.now, accountIds: self.accounts)
        XCTAssertFalse(state.serverDisabledRust(build: self.build), "a fetch that ends after its account logged out")
    }

    func testAnUnchangedServerFlagKeepsItsTime() {
        let state = self.shared([(1, true)])
        XCTAssertEqual(state.withServerFlag(accountId: 1, rustDisabled: true, build: self.build, timestamp: self.now + 3600, accountIds: self.accounts), state)
        XCTAssertEqual(state.withServerFlag(accountId: 1, rustDisabled: false, build: self.build, timestamp: self.now + 3600, accountIds: self.accounts).serverFlags.first?.updatedAt, self.now + 3600)
    }

    func testOneEngineCrashIsNotALoop() {
        let state = NetworkEngineState().withEngineCrash(build: self.build, timestamp: self.now)
        XCTAssertFalse(state.locallyDisabledRust(build: self.build, timestamp: self.now))
    }

    func testTwoEngineCrashesWithinADayTurnRustOffForADay() {
        let state = NetworkEngineState().withEngineCrash(build: self.build, timestamp: self.now).withEngineCrash(build: self.build, timestamp: self.now + 600)
        XCTAssertTrue(state.locallyDisabledRust(build: self.build, timestamp: self.now + 600))
        XCTAssertTrue(state.locallyDisabledRust(build: self.build, timestamp: self.now + 600 + NetworkEngineState.crashLoopFallbackDuration - 1))
        XCTAssertFalse(state.locallyDisabledRust(build: self.build, timestamp: self.now + 600 + NetworkEngineState.crashLoopFallbackDuration), "the fallback ends")
        XCTAssertFalse(state.locallyDisabledRust(build: "12.1 BETA (283291)", timestamp: self.now + 600), "another build starts clean")
    }

    func testAClockSetBackDoesNotStretchTheFallback() {
        let state = NetworkEngineState().withEngineCrash(build: self.build, timestamp: self.now).withEngineCrash(build: self.build, timestamp: self.now + 60)
        XCTAssertTrue(state.locallyDisabledRust(build: self.build, timestamp: self.now + 60 - 30 * 60), "a clock correction keeps the fallback")
        XCTAssertFalse(state.locallyDisabledRust(build: self.build, timestamp: self.now + 60 - NetworkEngineState.crashLoopClockTolerance - 1))
        XCTAssertFalse(state.locallyDisabledRust(build: self.build, timestamp: self.now - 60 * 24 * 60 * 60), "two months back would stretch it to two months")
    }

    func testOnlyTheServerFlagsOfAccountsStillThereCount() {
        let state = self.shared([(1, true), (2, false)])
        XCTAssertTrue(state.keepingServerFlags(of: [1, 2]).serverDisabledRust(build: self.build))
        XCTAssertFalse(state.keepingServerFlags(of: [2, 3]).serverDisabledRust(build: self.build), "account 1 is gone and account 2 has its own value")
    }

    func testTheLastAccountsTrueStillCountsForALogin() {
        let state = self.shared([(1, true)])
        XCTAssertTrue(state.keepingServerFlags(of: []).serverDisabledRust(build: self.build), "nobody is left to say otherwise")
        XCTAssertTrue(state.keepingServerFlags(of: [3]).serverDisabledRust(build: self.build), "a live account without a value of its own says nothing")
    }

    func testALiveAccountsOwnFlagOverridesAGoneAccountsTrue() {
        let state = self.shared([(1, true), (2, false)])
        XCTAssertFalse(state.keepingServerFlags(of: [2]).serverDisabledRust(build: self.build))
    }

    func testAGoneAccountsFlagOfAnotherBuildNeverCounts() {
        let oldBuild = "12.1 BETA (283289)"
        let state = NetworkEngineState().withServerFlag(accountId: 1, rustDisabled: true, build: oldBuild, timestamp: self.now, accountIds: self.accounts)
        XCTAssertFalse(state.keepingServerFlags(of: []).serverDisabledRust(build: self.build))
        XCTAssertFalse(state.keepingServerFlags(of: [2]).serverDisabledRust(build: self.build))
    }

    func testAGoneAccountsLateFetchChangesNothing() {
        let state = self.shared([(1, true)])
        XCTAssertEqual(state.withServerFlag(accountId: 1, rustDisabled: false, build: self.build, timestamp: self.now + 60, accountIds: []), state, "a fetch that ended after the last logout neither records nor drops")
    }

    func testCrashesMoreThanADayApartAreNotALoop() {
        let state = NetworkEngineState().withEngineCrash(build: self.build, timestamp: self.now).withEngineCrash(build: self.build, timestamp: self.now + NetworkEngineState.crashLoopWindow + 1)
        XCTAssertFalse(state.locallyDisabledRust(build: self.build, timestamp: self.now + NetworkEngineState.crashLoopWindow + 1))
    }

    func testCrashesOfAnotherBuildDoNotCount() {
        let state = NetworkEngineState().withEngineCrash(build: "12.1 BETA (283289)", timestamp: self.now).withEngineCrash(build: self.build, timestamp: self.now + 60)
        XCTAssertFalse(state.locallyDisabledRust(build: self.build, timestamp: self.now + 60))
    }

    func testCrashesBeforeAFallbackDoNotCountTowardsTheNextOne() {
        let fallback = NetworkEngineState().withEngineCrash(build: self.build, timestamp: self.now).withEngineCrash(build: self.build, timestamp: self.now + 60)
        let afterFallback = self.now + 60 + NetworkEngineState.crashLoopFallbackDuration + 1
        let state = fallback.withEngineCrash(build: self.build, timestamp: afterFallback)
        XCTAssertFalse(state.locallyDisabledRust(build: self.build, timestamp: afterFallback))
    }

    func testTheStateSurvivesTheSharedDataEncoding() {
        let state = self.shared([(1, true), (2, false)]).withEngineCrash(build: self.build, timestamp: self.now)
        XCTAssertEqual(PreferencesEntry(state)?.get(NetworkEngineState.self), state)
        let locallyOff = state.withEngineCrash(build: self.build, timestamp: self.now + 1)
        XCTAssertEqual(PreferencesEntry(locallyOff)?.get(NetworkEngineState.self), locallyOff)
        XCTAssertEqual(PreferencesEntry(NetworkEngineState())?.get(NetworkEngineState.self), NetworkEngineState())
    }

    func testAnAccountsOwnConfigurationDecidesForIt() {
        let appVersion = "12.1 BETA"
        let othersDisabled = NetworkEngineState().withServerFlag(accountId: 1, rustDisabled: true, build: networkEngineStateBuild(appVersion: appVersion), timestamp: self.now, accountIds: self.accounts)
        XCTAssertEqual(networkEngineRustDisabledReason(appConfiguration: self.configuration(["mtproto_engine_rust_disabled": true]), engineState: nil, appVersion: appVersion, timestamp: self.now), "mtproto_engine_rust_disabled")
        XCTAssertNil(networkEngineRustDisabledReason(appConfiguration: self.configuration(["mtproto_engine_rust_disabled": false]), engineState: othersDisabled, appVersion: appVersion, timestamp: self.now), "another account's value does not override a configuration of its own")
        XCTAssertNil(networkEngineRustDisabledReason(appConfiguration: self.configuration(["other": 1]), engineState: othersDisabled, appVersion: appVersion, timestamp: self.now))
    }

    func testALoginFollowsWhatOtherAccountsGot() {
        let appVersion = "12.1 BETA"
        let build = networkEngineStateBuild(appVersion: appVersion)
        let disabled = NetworkEngineState().withServerFlag(accountId: 1, rustDisabled: true, build: build, timestamp: self.now, accountIds: self.accounts)
        XCTAssertNotNil(networkEngineRustDisabledReason(appConfiguration: .defaultValue, engineState: disabled, appVersion: appVersion, timestamp: self.now))
        XCTAssertNil(networkEngineRustDisabledReason(appConfiguration: .defaultValue, engineState: disabled, appVersion: "12.2 BETA", timestamp: self.now), "an update starts clean")
        XCTAssertNil(networkEngineRustDisabledReason(appConfiguration: .defaultValue, engineState: disabled.withServerFlag(accountId: 1, rustDisabled: false, build: build, timestamp: self.now + 60, accountIds: self.accounts), appVersion: appVersion, timestamp: self.now + 60), "false enables Rust again")
        XCTAssertNil(networkEngineRustDisabledReason(appConfiguration: .defaultValue, engineState: nil, appVersion: appVersion, timestamp: self.now))
    }

    func testTheCrashLoopCountsForEveryNetwork() {
        let appVersion = "12.1 BETA"
        let build = networkEngineStateBuild(appVersion: appVersion)
        let crashLoop = NetworkEngineState().withEngineCrash(build: build, timestamp: self.now).withEngineCrash(build: build, timestamp: self.now + 1)
        XCTAssertEqual(networkEngineRustDisabledReason(appConfiguration: self.configuration(["mtproto_engine_rust_disabled": false]), engineState: crashLoop, appVersion: appVersion, timestamp: self.now + 2), "engine crash loop")
        XCTAssertEqual(networkEngineRustDisabledReason(appConfiguration: .defaultValue, engineState: crashLoop, appVersion: appVersion, timestamp: self.now + 2), "engine crash loop")
    }

    func testAConfigurationNeverFetchedSaysNothingAboutTheFlag() {
        XCTAssertNil(networkEngineServerFlag(appConfiguration: .defaultValue))
        XCTAssertEqual(networkEngineServerFlag(appConfiguration: self.configuration(["mtproto_engine_rust_disabled": true])), true)
        XCTAssertEqual(networkEngineServerFlag(appConfiguration: self.configuration(["other": 1])), false)
    }

    func testTheBuildIdentityTellsBuildsApart() {
        XCTAssertEqual(networkEngineStateBuild(appVersion: "12.1 BETA"), networkEngineStateBuild(appVersion: "12.1 BETA"))
        XCTAssertNotEqual(networkEngineStateBuild(appVersion: "12.1 BETA"), networkEngineStateBuild(appVersion: "12.1 STABLE"))
        XCTAssertEqual(networkEngineStateBuild(appVersion: "12.1 BETA", bundleVersion: "283290"), "12.1 BETA (283290)")
        XCTAssertNotEqual(networkEngineStateBuild(appVersion: "12.1 BETA", bundleVersion: "283290"), networkEngineStateBuild(appVersion: "12.1 BETA", bundleVersion: "283291"))
    }
}

final class NetworkEngineStateStoreTests: XCTestCase {
    private static let logger: Logger = {
        let path = NSTemporaryDirectory() + "network-engine-state-tests-\(getpid())"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        let logger = Logger(rootPath: path, basePath: path)
        logger.logToFile = false
        logger.logToConsole = false
        return logger
    }()

    private var path: String!
    private var accountManager: AccountManager<TelegramAccountManagerTypes>!
    private let appVersion = "12.1 BETA"
    private let now: Int32 = 1_760_000_000

    override func setUp() {
        super.setUp()
        Logger.setSharedLogger(NetworkEngineStateStoreTests.logger)
        self.path = NSTemporaryDirectory() + "network-engine-state-\(UUID().uuidString)"
        self.accountManager = AccountManager(basePath: self.path, isTemporary: true, isReadOnly: false, useCaches: false, removeDatabaseOnError: true, accessChallenge: AccountManagerAccessChallenge(prepare: { _ in
        }, resolve: { current, _ in
            return current
        }, finishInitialization: {
        }))
    }

    override func tearDown() {
        self.accountManager = nil
        try? FileManager.default.removeItem(atPath: self.path)
        super.tearDown()
    }

    private func wait<T>(_ signal: Signal<T, NoError>) -> T? {
        let result = Atomic<T?>(value: nil)
        let done = DispatchSemaphore(value: 0)
        let disposable = (signal |> take(1)).start(next: { value in
            let _ = result.swap(value)
        }, completed: {
            done.signal()
        })
        let _ = done.wait(timeout: .now() + 10.0)
        disposable.dispose()
        return result.with { $0 }
    }

    private var state: NetworkEngineState? {
        return self.wait(self.accountManager.transaction { transaction -> NetworkEngineState? in
            return transaction.getSharedData(SharedDataKeys.networkEngineState)?.get(NetworkEngineState.self)
        }) ?? nil
    }

    func testOnlyAccountsThatAreStillThereKeepTheirServerFlag() {
        guard let (first, second) = self.wait(self.accountManager.transaction { transaction -> (AccountRecordId, AccountRecordId) in
            return (transaction.createRecord([]), transaction.createRecord([]))
        }) else {
            XCTFail("no records")
            return
        }
        let build = networkEngineStateBuild(appVersion: self.appVersion)
        let _ = self.wait(updateNetworkEngineServerFlag(accountManager: self.accountManager, accountId: first, rustDisabled: true, appVersion: self.appVersion))
        let _ = self.wait(updateNetworkEngineServerFlag(accountManager: self.accountManager, accountId: second, rustDisabled: false, appVersion: self.appVersion))
        XCTAssertEqual(self.state?.serverDisabledRust(build: build), true)

        self.logOut(first)
        let _ = self.wait(updateNetworkEngineServerFlag(accountManager: self.accountManager, accountId: second, rustDisabled: false, appVersion: self.appVersion))
        XCTAssertEqual(self.state?.serverDisabledRust(build: build), false, "a logged-out account's true is dropped")
        let _ = self.wait(updateNetworkEngineServerFlag(accountManager: self.accountManager, accountId: first, rustDisabled: true, appVersion: self.appVersion))
        XCTAssertEqual(self.state?.serverDisabledRust(build: build), false, "and it cannot come back")
    }

    private func makeRecords(_ count: Int) -> [AccountRecordId] {
        return self.wait(self.accountManager.transaction { transaction -> [AccountRecordId] in
            return (0 ..< count).map { _ in transaction.createRecord([]) }
        }) ?? []
    }

    private func logOut(_ id: AccountRecordId) {
        let _ = self.wait(self.accountManager.transaction { transaction -> Void in
            transaction.updateRecord(id, { record in
                return record.flatMap { AccountRecord(id: $0.id, attributes: $0.attributes + [.loggedOut(LoggedOutAccountAttribute())], temporarySessionId: nil) }
            })
        })
    }

    private var inputs: NetworkEngineInputs? {
        return self.wait(self.accountManager.transaction { transaction -> NetworkEngineInputs in
            return networkEngineInputs(transaction: transaction)
        })
    }

    /// Every network gets its engine inputs from `networkEngineInputs(transaction:)` (the type has no
    /// other initializer), so it always carries the shared state, filtered by the accounts still there.
    func testANetworkSeesTheSharedStateOfAccountsStillThere() {
        let records = self.makeRecords(2)
        guard records.count == 2 else {
            XCTFail("no records")
            return
        }
        let build = networkEngineStateBuild(appVersion: self.appVersion)
        let _ = self.wait(updateNetworkEngineSettings(accountManager: self.accountManager, { _ in NetworkEngineSettings(engine: .rust) }))
        let _ = self.wait(updateNetworkEngineServerFlag(accountManager: self.accountManager, accountId: records[0], rustDisabled: true, appVersion: self.appVersion))
        let _ = self.wait(updateNetworkEngineServerFlag(accountManager: self.accountManager, accountId: records[1], rustDisabled: false, appVersion: self.appVersion))
        XCTAssertEqual(self.inputs?.settings?.engine, .rust)
        XCTAssertEqual(self.inputs?.state?.serverDisabledRust(build: build), true)
        XCTAssertNotNil(networkEngineRustDisabledReason(appConfiguration: .defaultValue, engineState: self.inputs?.state, appVersion: self.appVersion, timestamp: self.now))

        self.logOut(records[0])
        XCTAssertEqual(self.inputs?.state?.serverDisabledRust(build: build), false, "a logged-out account stops counting before anyone writes again")
        XCTAssertNil(networkEngineRustDisabledReason(appConfiguration: .defaultValue, engineState: self.inputs?.state, appVersion: self.appVersion, timestamp: self.now))
        XCTAssertEqual(self.wait(networkEngineStateView(accountManager: self.accountManager))??.serverDisabledRust(build: build), false, "the live view filters the same way")
    }

    func testALoginAfterTheLastLogoutStillHonoursItsTrue() {
        let records = self.makeRecords(1)
        guard records.count == 1 else {
            XCTFail("no records")
            return
        }
        let build = networkEngineStateBuild(appVersion: self.appVersion)
        let _ = self.wait(updateNetworkEngineServerFlag(accountManager: self.accountManager, accountId: records[0], rustDisabled: true, appVersion: self.appVersion))
        self.logOut(records[0])
        XCTAssertEqual(self.inputs?.state?.serverDisabledRust(build: build), true)
        XCTAssertNotNil(networkEngineRustDisabledReason(appConfiguration: .defaultValue, engineState: self.inputs?.state, appVersion: self.appVersion, timestamp: self.now))
        XCTAssertEqual(self.wait(networkEngineStateView(accountManager: self.accountManager))??.serverDisabledRust(build: build), true, "the live view keeps it too")
        let _ = self.wait(updateNetworkEngineServerFlag(accountManager: self.accountManager, accountId: records[0], rustDisabled: false, appVersion: self.appVersion))
        XCTAssertEqual(self.inputs?.state?.serverDisabledRust(build: build), true, "a late fetch of the logged-out account changes nothing")
    }

    func testOnlyCrashesOfTheRunningBuildCount() {
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        XCTAssertEqual(self.wait(recordRustEngineCrash(accountManager: self.accountManager, appVersion: self.appVersion, crashedBundleVersion: bundleVersion, timestamp: self.now)), false)
        XCTAssertEqual(self.wait(recordRustEngineCrash(accountManager: self.accountManager, appVersion: self.appVersion, crashedBundleVersion: bundleVersion + "-old", timestamp: self.now + 30)), false, "another build's crash is ignored")
        XCTAssertEqual(self.wait(recordRustEngineCrash(accountManager: self.accountManager, appVersion: self.appVersion, crashedBundleVersion: bundleVersion, timestamp: self.now + 60)), true)
        XCTAssertEqual(self.state?.locallyDisabledRust(build: networkEngineStateBuild(appVersion: self.appVersion), timestamp: self.now + 61), true)
    }
}

final class AppConfigurationFetchTests: XCTestCase {
    private let stored = AppConfiguration(data: JSON(dictionary: ["mtproto_engine_rust_disabled": true]), hash: 7)

    private func run(answer: Api.help.AppConfig?, storeParses: Bool = true, withConfirmed: Bool = true) -> (confirmed: [AppConfiguration], stores: Int, storedReads: Int) {
        let confirmed = Atomic<[AppConfiguration]>(value: [])
        let stores = Atomic<Int>(value: 0)
        let storedReads = Atomic<Int>(value: 0)
        let stored = self.stored
        let fetched = AppConfiguration(data: JSON(dictionary: ["mtproto_engine_rust_disabled": false]), hash: 8)
        let done = DispatchSemaphore(value: 0)
        let disposable = fetchAppConfiguration(
            storedHash: .single(stored.hash),
            request: { hash in
                XCTAssertEqual(hash, stored.hash)
                return .single(answer)
            },
            store: { _, _ in
                let _ = stores.modify { $0 + 1 }
                return .single(storeParses ? fetched : nil)
            },
            stored: Signal { subscriber in
                let _ = storedReads.modify { $0 + 1 }
                subscriber.putNext(stored)
                subscriber.putCompletion()
                return EmptyDisposable
            },
            confirmed: withConfirmed ? { configuration in
                let _ = confirmed.modify { $0 + [configuration] }
                return .complete()
            } : nil
        ).start(completed: {
            done.signal()
        })
        let _ = done.wait(timeout: .now() + 5.0)
        disposable.dispose()
        return (confirmed.with { $0 }, stores.with { $0 }, storedReads.with { $0 })
    }

    func testANotModifiedAnswerConfirmsTheStoredConfiguration() {
        let result = self.run(answer: .appConfigNotModified)
        XCTAssertEqual(result.confirmed, [self.stored])
        XCTAssertEqual(result.stores, 0)
    }

    func testANewConfigurationIsStoredAndConfirmed() {
        let result = self.run(answer: .appConfig(.init(hash: 8, config: .jsonNull)))
        XCTAssertEqual(result.stores, 1)
        XCTAssertEqual(result.confirmed.map { $0.hash }, [8])
    }

    func testAFailedRequestConfirmsNothing() {
        let result = self.run(answer: nil)
        XCTAssertEqual(result.confirmed, [])
        XCTAssertEqual(result.stores, 0)
        XCTAssertEqual(result.storedReads, 0)
    }

    func testAConfigurationThatCannotBeParsedConfirmsNothing() {
        let result = self.run(answer: .appConfig(.init(hash: 8, config: .jsonNull)), storeParses: false)
        XCTAssertEqual(result.stores, 1)
        XCTAssertEqual(result.confirmed, [])
    }

    func testWithoutAListenerANotModifiedAnswerReadsNothing() {
        let result = self.run(answer: .appConfigNotModified, withConfirmed: false)
        XCTAssertEqual(result.storedReads, 0)
    }
}
