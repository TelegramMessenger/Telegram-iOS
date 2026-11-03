import XCTest
import SwiftSignalKit
import MtProtoKit
@testable import TelegramCore
@testable import MTProtoRustEngine
import MTProtoRustEngineMapping

/// The evidence the logout check weighs, kept per MTContext (`RustContextRegistry`), without sessions:
/// each test records what sessions would have seen and asks for a verdict.
final class RustContextRegistryTests: XCTestCase {
    private static let datacenterId = 2
    private static let keyId: Int64 = 0x1234

    override func setUp() {
        super.setUp()
        Logger.setSharedLogger(RustEngineBridgeTests.logger)
    }

    private func makeContext() -> MTContext {
        var apiEnvironment = MTApiEnvironment(deviceModelName: "registry tests")
        apiEnvironment.apiId = 9
        return MTContext(serialization: Serialization(), encryptionProvider: UnusedEncryptionProvider(), apiEnvironment: apiEnvironment, isTestingEnvironment: false, useTempAuthKeys: true)
    }

    private func verdict(_ registry: RustContextRegistry, keyId: Int64 = RustContextRegistryTests.keyId) -> String? {
        let done = XCTestExpectation(description: "verdict")
        let result = Atomic<String?>(value: "none")
        registry.confirmUnknown(datacenterId: RustContextRegistryTests.datacenterId, keyId: keyId, queue: Queue(), completion: { denial in
            let _ = result.swap(denial)
            done.fulfill()
        })
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: RustEnginePermanentKeyEvidence.observationWindow + 5.0), .completed)
        return result.with { $0 }
    }

    private func reportedAndRefused(_ registry: RustContextRegistry, refusedAgo: Double = 30.0) {
        let now = rustEngineMonotonicNow()
        registry.noteRefusedBind(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: now - refusedAgo)
        registry.noteReportedUnknown(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: now - 1.0)
    }

    func testAReportedAndRefusedKeyIsConfirmed() {
        let context = self.makeContext()
        let registry = RustContextRegistry.of(context)
        XCTAssertTrue(registry === RustContextRegistry.of(context), "one registry per context")
        self.reportedAndRefused(registry)
        XCTAssertNil(self.verdict(registry))
    }

    func testABindAcceptedSinceEndsTheEpisodeAndTheReport() {
        let registry = RustContextRegistry.of(self.makeContext())
        let now = rustEngineMonotonicNow()
        registry.noteRefusedBind(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: now - 40.0)
        registry.noteReportedUnknown(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: now - 30.0)
        registry.noteBound(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: now - 25.0)
        XCTAssertEqual(self.verdict(registry), "the engine did not report the key unknown")
        registry.noteRefusedBind(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: now - 20.0)
        XCTAssertEqual(self.verdict(registry), "the engine did not report the key unknown", "a refusal after the bind does not bring back the report the bind ended")
    }

    func testAKeyBoundWithinADayIsNeverValidated() {
        let registry = RustContextRegistry.of(self.makeContext())
        registry.noteBound(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: rustEngineMonotonicNow() - 3_600.0)
        self.reportedAndRefused(registry)
        XCTAssertTrue(self.verdict(registry)?.hasPrefix("the server answered under the key or bound it") ?? false, "tdlib's immunity: refusals during an incident log nobody out")
    }

    func testACallCompletedOnASessionThatStoppedStillCounts() {
        let registry = RustContextRegistry.of(self.makeContext())
        self.reportedAndRefused(registry)
        registry.noteAnswered(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: rustEngineMonotonicNow() - 5.0)
        XCTAssertNotNil(self.verdict(registry))
    }

    func testAnAnswerBeforeTheRefusalsWithinADayCounts() {
        let registry = RustContextRegistry.of(self.makeContext())
        self.reportedAndRefused(registry)
        registry.noteAnswered(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: rustEngineMonotonicNow() - 60.0)
        XCTAssertNotNil(self.verdict(registry))
    }

    func testAnAnswerMoreThanADayAgoOrOnAnotherDatacenterSaysNothing() {
        let registry = RustContextRegistry.of(self.makeContext())
        self.reportedAndRefused(registry)
        registry.noteAnswered(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: rustEngineMonotonicNow() - RustEnginePermanentKeyEvidence.immunity - 60.0)
        registry.noteAnswered(datacenterId: RustContextRegistryTests.datacenterId + 2, keyId: RustContextRegistryTests.keyId, at: rustEngineMonotonicNow())
        XCTAssertNil(self.verdict(registry))
    }

    func testAReportAboutAnotherKeyOrNoRefusalIsNoVerdict() {
        let registry = RustContextRegistry.of(self.makeContext())
        registry.noteReportedUnknown(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: rustEngineMonotonicNow())
        XCTAssertNotNil(self.verdict(registry), "no session saw a refusal")
        registry.noteRefusedBind(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: rustEngineMonotonicNow() - 30.0)
        XCTAssertNotNil(self.verdict(registry, keyId: RustContextRegistryTests.keyId + 1), "the evidence is about another key")
    }

    func testTheVerdictWaitsForTheObservationWindow() {
        let registry = RustContextRegistry.of(self.makeContext())
        self.reportedAndRefused(registry, refusedAgo: 0.0)
        let started = Date()
        XCTAssertNil(self.verdict(registry))
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), RustEnginePermanentKeyEvidence.observationWindow - 0.5)
    }

    func testAnAnswerUnderAnotherKeyKeepsThisKeysEvidence() {
        let registry = RustContextRegistry.of(self.makeContext())
        self.reportedAndRefused(registry)
        registry.noteAnswered(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, at: rustEngineMonotonicNow() - 5.0)
        registry.noteAnswered(datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId + 1, at: rustEngineMonotonicNow())
        XCTAssertNotNil(self.verdict(registry), "the answer under this key still counts")
    }

    func testAnActionStartedAfterTheEngineWasDeactivatedEndsAtOnce() {
        let context = self.makeContext()
        let actions = RustEngineActions(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [], httpPort: 0)
        actions.install()
        let running = AbandonRecorder()
        actions.track(running)
        XCTAssertEqual(running.abandoned, 0)
        actions.uninstall()
        XCTAssertEqual(running.abandoned, 1, "deactivation ends what runs on the engine")
        let late = AbandonRecorder()
        actions.track(late)
        XCTAssertEqual(late.abandoned, 1, "made from the factory just before it was cleared")
    }

    /// Holds MTContext's queue until `release` is called, so that what is queued meanwhile runs after.
    private func blockContextQueue() -> () -> Void {
        let blocked = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        MTContext.contextQueue().dispatch(onQueue: {
            blocked.signal()
            let _ = release.wait(timeout: .now() + 30.0)
        }, synchronous: false)
        XCTAssertEqual(blocked.wait(timeout: .now() + 10.0), .success, "MTContext's queue is stuck")
        return {
            release.signal()
            MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        }
    }

    private func installed(on context: MTContext) -> RustEngineActions {
        let actions = RustEngineActions(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [], httpPort: 0)
        actions.install()
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        return actions
    }

    /// Records each check the gate starts, and whether the engine's factory was set when it did.
    private func gate(_ context: MTContext, starts: Atomic<[Bool]>) {
        rustEngineStartLogoutCheck(context: context, registry: RustContextRegistry.of(context), datacenterId: RustContextRegistryTests.datacenterId, keyId: RustContextRegistryTests.keyId, reportedAt: rustEngineMonotonicNow(), logPrefix: "[test]", start: { context, _ in
            let _ = starts.modify { $0 + [context.authActionFactory != nil] }
        })
    }

    func testTheGateStartsTheCheckWhileTheEnginesActionsRunTheKeyActions() {
        let context = self.makeContext()
        let actions = self.installed(on: context)
        defer { actions.uninstall() }
        let starts = Atomic<[Bool]>(value: [])
        self.gate(context, starts: starts)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        XCTAssertEqual(starts.with { $0 }, [true], "one check, with the engine's factory")
    }

    /// The gate is decided on MTContext's queue, not when the report comes: a deactivation between the two
    /// leaves no check, rather than one that would get MtProtoKit's action.
    func testAReportJustBeforeDeactivationStartsNoCheck() {
        let context = self.makeContext()
        let actions = self.installed(on: context)
        let release = self.blockContextQueue()
        let starts = Atomic<[Bool]>(value: [])
        self.gate(context, starts: starts)
        actions.uninstall()
        release()
        XCTAssertEqual(starts.with { $0 }, [])
        XCTAssertNil(context.authActionFactory)
    }

    /// Between `install` naming the actions and their factory being set on MTContext's queue, the gate
    /// starts no check: MTContext would make MtProtoKit's action for it.
    func testAReportBeforeTheFactoryIsSetStartsNoCheck() {
        let context = self.makeContext()
        let release = self.blockContextQueue()
        let starts = Atomic<[Bool]>(value: [])
        self.gate(context, starts: starts)
        let actions = RustEngineActions(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [], httpPort: 0)
        actions.install()
        XCTAssertTrue(RustContextRegistry.of(context).hasActiveActions())
        release()
        XCTAssertEqual(starts.with { $0 }, [])
        XCTAssertNotNil(context.authActionFactory)
        actions.uninstall()
    }

    /// A switch from one engine to another while a report is queued: when the gate runs, the registry names
    /// the new engine but MTContext still has the old one's factories. The gate starts no check (the old
    /// engine's action would end without a verdict) and notes no report.
    func testAReportWhileTheFactoriesAreAnotherEnginesStartsNoCheck() {
        let context = self.makeContext()
        let first = self.installed(on: context)
        let release = self.blockContextQueue()
        let starts = Atomic<[Bool]>(value: [])
        self.gate(context, starts: starts)
        first.uninstall()
        let second = RustEngineActions(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [], httpPort: 0)
        second.install()
        release()
        XCTAssertEqual(starts.with { $0 }, [])
        XCTAssertEqual(self.verdict(RustContextRegistry.of(context)), "the engine did not report the key unknown", "a refused gate notes no report")
        self.gate(context, starts: starts)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        XCTAssertEqual(starts.with { $0 }, [true], "once the second engine's factories are set")
        second.uninstall()
    }

    /// Every factory write runs on MTContext's queue: deactivation clears the registry at once and the
    /// factories only there, after any block already running there.
    func testDeactivationClearsTheFactoriesOnMTContextsQueueAfterTheRegistry() {
        let context = self.makeContext()
        let registry = RustContextRegistry.of(context)
        let actions = self.installed(on: context)
        XCTAssertTrue(registry.hasActiveActions())
        XCTAssertNotNil(context.authActionFactory)
        let release = self.blockContextQueue()
        actions.uninstall()
        XCTAssertFalse(registry.hasActiveActions(), "the registry stops naming the actions at once")
        XCTAssertNotNil(context.authActionFactory, "the factories wait for MTContext's queue")
        release()
        XCTAssertNil(context.authActionFactory)
        XCTAssertNil(context.transferAuthActionFactory)
    }

    /// A reinstall while the previous engine's clear is still queued: the clear and the new factories run
    /// in order on MTContext's queue, and the new factories stay.
    func testAReinstallBeforeTheQueuedClearKeepsTheNewFactories() {
        let context = self.makeContext()
        let first = self.installed(on: context)
        let release = self.blockContextQueue()
        first.uninstall()
        let second = RustEngineActions(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [], httpPort: 0)
        second.install()
        release()
        XCTAssertNotNil(context.authActionFactory, "the first engine's queued clear leaves the second's factories")
        XCTAssertNotNil(context.transferAuthActionFactory)
        second.uninstall()
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        XCTAssertNil(context.authActionFactory)
    }

    func testOnlyTheCurrentEnginesActionsAreRemoved() {
        let context = self.makeContext()
        let registry = RustContextRegistry.of(context)
        let first = RustEngineActions(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [], httpPort: 0)
        let second = RustEngineActions(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [], httpPort: 0)
        XCTAssertTrue(registry.setActiveActions(first, replacing: nil))
        XCTAssertTrue(registry.setActiveActions(second, replacing: nil))
        XCTAssertFalse(registry.setActiveActions(nil, replacing: first), "a deactivated engine cannot remove its successor's actions")
        XCTAssertTrue(registry.setActiveActions(nil, replacing: second))
    }

    func testTheRegistryDoesNotKeepTheActionsAlive() {
        let context = self.makeContext()
        weak var weakActions: RustEngineActions?
        do {
            let actions = RustEngineActions(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [], httpPort: 0)
            weakActions = actions
            let _ = RustContextRegistry.of(context).setActiveActions(actions, replacing: nil)
        }
        XCTAssertNil(weakActions)
    }
}

private final class AbandonRecorder: RustEngineAbandonableAction {
    var abandoned = 0

    func abandon() {
        self.abandoned += 1
    }
}
