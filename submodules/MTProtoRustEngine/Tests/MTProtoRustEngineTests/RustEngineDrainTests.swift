import XCTest
import SwiftSignalKit
import MtProtoKit
@testable import TelegramCore
@testable import MTProtoRustEngine
import MTProtoRustEngineMapping

let tagSlow: UInt32 = 1006

extension TestServerProcess {
    /// The client session (MTProto session id) of every call the server ran, by tag.
    func executionSessions(tag: UInt32) -> [Int64] {
        let executed = (self.stats(command: "sessions")["executed"] as? [[String: Any]]) ?? []
        return executed.compactMap { row in
            guard (row["tag"] as? NSNumber)?.uint32Value == tag else {
                return nil
            }
            return (row["session"] as? NSNumber)?.int64Value
        }
    }
}

/// B3: a live engine switch (`SwitchingNetworkEngine.switchEngine`) hands the old session's requests over
/// without running any of them twice (`mt_session_drain`, `movePendingRequests(to:deadline:)`). The tests
/// about the Rust session's drain take a second Rust engine as the replacement (the switch is told
/// `.mtProtoKit`; what runs next does not matter to the drain); the ones named after MtProtoKit use a
/// real MtProtoKit engine.
extension RustEngineEndToEndTests {
    private func outcome(_ result: Result<NetworkEngineResponse, NetworkEngineRequestFailure>) -> String {
        switch result {
        case .success:
            return "completed"
        case let .failure(failure):
            return "failed \(failure.error.errorCode) \(failure.error.errorDescription ?? "")"
        }
    }

    /// R3-C, fixed: the kill switch moves a main session to another engine while a call the server ran
    /// waits for an answer that never comes. The old session keeps it under its message id until the
    /// deadline, then the call's own policy decides: this one may not run again, so it fails with
    /// `500 ENGINE_SWITCHED` and runs once, in one session.
    func testR3C_AnEngineSwitchRunsATransmittedCallOnlyOnce() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        let first = self.pfsEngine(context)
        let second = self.pfsEngine(context)
        let switching = SwitchingNetworkEngine(engine: first)
        let session = switching.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 82, on: session) else {
            return
        }
        let outcome = Atomic<String>(value: "pending")
        let asked = Atomic<[NetworkEngineErrorContext]>(value: [])
        let disposable = session.requestService.add(self.request(tag: tagNever, shouldContinueAfterError: { context in
            let _ = asked.modify { $0 + [context] }
            return false
        }, label: "non-idempotent call") { result in
            let _ = outcome.swap(self.outcome(result))
        })
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 5.0, until: { self.server.executions(tag: tagNever) == 1 }), "transmitted and run once")
        let switchedAt = Date()
        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 2.0, makeEngine: { second }))
        guard self.completes(tag: 83, on: session) else {
            return
        }
        XCTAssertTrue(self.wait(seconds: 10.0, until: { outcome.with { $0 } != "pending" }))
        let tookFor = Date().timeIntervalSince(switchedAt)
        XCTAssertFalse(self.wait(seconds: 3.0, until: { self.server.executions(tag: tagNever) >= 2 }), "a call the server may have must not run again under another session")
        XCTAssertEqual(self.server.executions(tag: tagNever), 1)
        XCTAssertEqual(Set(self.server.executionSessions(tag: tagNever)).count, 1)
        XCTAssertEqual(outcome.with { $0 }, "failed 500 ENGINE_SWITCHED", "the policy's error")
        XCTAssertEqual(asked.with { $0.map(\.internalServerErrorCount) }, [1], "asked once, as about a server error")
        XCTAssertTrue(tookFor >= 1.5 && tookFor < 8.0, "after the drain deadline: \(tookFor) s")
    }

    /// The same call with a policy that allows a server error (most of TelegramCore's): it moves after the
    /// deadline and runs again, as after a temporary key rotation. That is the documented policy.
    func testACallWhosePolicyAllowsAServerErrorMovesAtTheDeadline() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        let switching = SwitchingNetworkEngine(engine: self.pfsEngine(context))
        let second = self.pfsEngine(context)
        let session = switching.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 84, on: session) else {
            return
        }
        let asked = Atomic<Int>(value: 0)
        let disposable = session.requestService.add(self.request(tag: tagNever, shouldContinueAfterError: { _ in
            let _ = asked.modify { $0 + 1 }
            return true
        }) { _ in })
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 5.0, until: { self.server.executions(tag: tagNever) == 1 }))
        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 1.0, makeEngine: { second }))
        XCTAssertTrue(self.wait(seconds: 10.0, until: { self.server.executions(tag: tagNever) == 2 }), "moved after the deadline because its policy allows it")
        XCTAssertEqual(asked.with { $0 }, 1)
        XCTAssertEqual(Set(self.server.executionSessions(tag: tagNever)).count, 2)
    }

    /// A call whose answer comes while the old session drains completes there, once.
    func testACallAnsweredWhileTheOldSessionDrainsCompletesThere() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        let switching = SwitchingNetworkEngine(engine: self.pfsEngine(context))
        let second = self.pfsEngine(context)
        let session = switching.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 85, on: session) else {
            return
        }
        let outcome = Atomic<String>(value: "pending")
        let disposable = session.requestService.add(self.request(tag: tagSlow) { result in
            let _ = outcome.swap(self.outcome(result))
        })
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 5.0, until: { self.server.executions(tag: tagSlow) == 1 }))
        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 5.0, makeEngine: { second }))
        XCTAssertTrue(self.wait(seconds: 5.0, until: { outcome.with { $0 } != "pending" }))
        XCTAssertEqual(outcome.with { $0 }, "completed")
        XCTAssertFalse(self.wait(seconds: 1.0, until: { self.server.executions(tag: tagSlow) > 1 }))
        XCTAssertEqual(self.server.executions(tag: tagSlow), 1)
    }

    /// Requests that never went out move to the new session at once and run there once.
    func testRequestsThatNeverWentOutMoveAtOnceAndRunOnce() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        let switching = SwitchingNetworkEngine(engine: self.pfsEngine(context))
        let second = self.pfsEngine(context)
        let session = switching.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        defer { session.stop() }
        let completed = Atomic<[UInt32: Int]>(value: [:])
        var disposables: [Disposable] = []
        let tags: [UInt32] = [86, 87, 88]
        for tag in tags {
            disposables.append(session.requestService.add(self.request(tag: tag) { result in
                if case .success = result {
                    let _ = completed.modify { current in
                        var updated = current
                        updated[tag, default: 0] += 1
                        return updated
                    }
                }
            }))
        }
        defer { disposables.forEach { $0.dispose() } }
        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 5.0, makeEngine: { second }))
        session.setPaused(false)
        XCTAssertTrue(self.wait(seconds: 15.0, until: { completed.with { $0.values.reduce(0, +) } == tags.count }))
        for tag in tags {
            XCTAssertEqual(self.server.executions(tag: tag), 1)
            XCTAssertEqual(completed.with { $0[tag] }, 1)
        }
    }

    /// The replacement main session makes a temporary key of its own: two main sessions of the account
    /// never talk under one temporary key while the old one drains (here a second Rust engine; see
    /// `testMtProtoKitReplacingRustMakesAndBindsATemporaryKeyOfItsOwn` for MtProtoKit).
    func testTheReplacementMainSessionTalksUnderATemporaryKeyOfItsOwn() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        let first = self.pfsEngine(context)
        first.activate()
        let switching = SwitchingNetworkEngine(engine: first)
        let second = self.pfsEngine(context)
        let session = switching.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 89, on: session), self.eventually({ context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) != nil }), let oldKey = context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) else {
            XCTFail("the first session kept no key")
            return
        }
        let handshakes = self.server.handshakes().count
        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 1.0, makeEngine: { second }))
        guard self.completes(tag: 90, on: session) else {
            return
        }
        XCTAssertEqual(self.server.handshakes().count, handshakes + 1, "the replacement made its own temporary key")
        XCTAssertTrue(self.eventually { context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain).map { $0.authKeyId != oldKey.authKeyId } ?? false })
        second.deactivate()
    }

    /// The production direction with a real replacement: Rust drains into MtProtoKit. The call the server
    /// ran waits for its answer under its message id, then fails under a refusing policy; MtProtoKit runs
    /// the calls that come after.
    func testRustHandsATransmittedCallOverToMtProtoKitWithoutRunningItTwice() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.makeContext(useTempAuthKeys: false)
        self.setAddress(of: context, preferForMedia: false)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        guard let rust = RustNetworkEngineFactory().makeEngine(context: context, isAppExtension: false) else {
            XCTFail("factory declined")
            return
        }
        let switching = SwitchingNetworkEngine(engine: rust)
        let session = switching.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 98, on: session) else {
            return
        }
        let outcome = Atomic<String>(value: "pending")
        let disposable = session.requestService.add(self.request(tag: tagNever, shouldContinueAfterError: { _ in false }) { result in
            let _ = outcome.swap(self.outcome(result))
        })
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 5.0, until: { self.server.executions(tag: tagNever) == 1 }))
        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 2.0, makeEngine: { MtProtoKitEngine(context: context) }))
        guard self.completes(tag: 99, on: session) else {
            return
        }
        XCTAssertTrue(self.wait(seconds: 15.0, until: { outcome.with { $0 } != "pending" }))
        XCTAssertEqual(outcome.with { $0 }, "failed 500 ENGINE_SWITCHED")
        XCTAssertFalse(self.wait(seconds: 2.0, until: { self.server.executions(tag: tagNever) > 1 }))
        XCTAssertEqual(self.server.executions(tag: tagNever), 1)
        XCTAssertEqual(self.server.executions(tag: 99), 1, "run by MtProtoKit")
    }

    /// Rust → MtProtoKit with temporary keys, as in the app: `deactivate` takes the engine's temporary key
    /// out of the context, and MtProtoKit makes and binds a key of its own instead of talking under the
    /// key the draining session still uses. MtProtoKit's key exchange takes the test server's RSA key
    /// from the context, as in the logout-check tests.
    func testMtProtoKitReplacingRustMakesAndBindsATemporaryKeyOfItsOwn() throws {
        guard let encryptionProvider = LibCryptoEncryptionProvider() else {
            throw XCTSkip("MtProtoKit's key exchange needs libcrypto: install OpenSSL 3 or set MTPROTO_TEST_LIBCRYPTO")
        }
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.makeContext(useTempAuthKeys: true, encryptionProvider: encryptionProvider)
        self.setAddress(of: context, preferForMedia: false)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        let rust = self.pfsEngine(context)
        rust.activate()
        let switching = SwitchingNetworkEngine(engine: rust)
        let session = switching.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 102, on: session), self.eventually({ context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) != nil }), let rustKey = context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) else {
            XCTFail("the engine kept no temporary key")
            return
        }
        XCTAssertTrue(rustEngineMadeTemporaryKey(attributes: rustKey.authKeyAttributes))
        let handshakes = self.server.handshakes().count
        let binds = self.server.binds()
        session.setPaused(true)
        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 1.0, makeEngine: { MtProtoKitEngine(context: context) }))
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        XCTAssertTrue(context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain).map { $0.authKeyId != rustKey.authKeyId } ?? true, "the engine's key left with it")
        context.updatePublicKeysForDatacenter(withId: datacenterId, publicKeys: [["key": self.server.publicKeyPem]])
        let factory: @convention(block) (MTDatacenterAuthInfoSelector, Bool, Bool, @escaping (MTDatacenterAuthAction?, Bool) -> Void) -> MTDatacenterAuthAction = { selector, _, skipBind, completion in
            return MTDatacenterAuthAction(authKeyInfoSelector: selector, isCdn: true, skipBind: skipBind, completion: { action, success in
                completion(action, success)
            })
        }
        context.setValue(factory, forKey: "authActionFactory")
        session.setPaused(false)
        guard self.completes(tag: 103, on: session) else {
            return
        }
        XCTAssertGreaterThan(self.server.handshakes().count, handshakes, "MtProtoKit made a key")
        XCTAssertEqual(self.server.handshakes().last?.temporary, true, "a temporary one")
        XCTAssertGreaterThan(self.server.binds(), binds, "and bound it")
        XCTAssertTrue(self.eventually { context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain).map { $0.authKeyId != rustKey.authKeyId } ?? false })
    }

    /// A key rotation's reconnect on an idle session: the session worked until it lost its answered
    /// connection, so the local health check counts its silence from then, not from its last packet.
    func testLosingAnAnsweredConnectionStartsTheSessionsSilenceAgain() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        let engine = self.pfsEngine(context)
        let session = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer {
            self.server.setTcpBlackhole(false)
            session.stop()
        }
        guard self.completes(tag: 100, on: session) else {
            return
        }
        Thread.sleep(forTimeInterval: 3.0)
        self.server.setTcpBlackhole(true)
        self.server.dropTemporaryKeys()
        let _ = session.requestService.add(self.request(tag: 101) { _ in })
        var lost: NetworkEngineServerActivity?
        let deadline = Date().addingTimeInterval(3.0)
        while Date() < deadline, lost == nil {
            if case let .some(.some(activity)) = self.activity(of: session), !activity.connected {
                lost = activity
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard let activity = lost else {
            XCTFail("the session kept its answered connection")
            return
        }
        XCTAssertLessThan(activity.silentFor ?? 99.0, 2.0, "silent since it lost the connection, not since its last packet 3 s before")
    }

    private func activity(of session: NetworkEngineSession) -> NetworkEngineServerActivity?? {
        let done = XCTestExpectation(description: "activity")
        let reply = Atomic<NetworkEngineServerActivity??>(value: .none)
        session.serverActivity { activity in
            let _ = reply.swap(.some(activity))
            done.fulfill()
        }
        let _ = XCTWaiter().wait(for: [done], timeout: 5.0)
        return reply.with { $0 }
    }

    /// What the local health check reads: an answered connection and when it last heard the server; a
    /// session that cannot reach it has neither; a draining session is not judged at all.
    func testTheSessionTellsTheLocalHealthCheckWhenItLastHeardTheServer() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        let engine = self.pfsEngine(context)
        let session = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 93, on: session) else {
            return
        }
        guard case let .some(.some(heard)) = self.activity(of: session) else {
            XCTFail("no activity")
            return
        }
        XCTAssertTrue(heard.connected)
        XCTAssertLessThan(heard.silentFor ?? 99.0, 5.0)

        let unreachable = self.makeContext(useTempAuthKeys: true)
        let closed = MTDatacenterAddress(ip: "127.0.0.1", port: 9, preferForMedia: false, restrictToTcp: true, cdn: false, preferForProxy: false, secret: nil)
        unreachable.updateAddressSetForDatacenter(withId: datacenterId, addressSet: MTDatacenterAddressSet(addressList: [closed]), forceUpdateSchemes: true)
        unreachable.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        let silent = RustNetworkEngine(runtime: RustEngineRuntime.shared!, context: unreachable, serverPublicKeys: [self.server.publicKeyPem], httpPort: 0).makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        silent.setPaused(false)
        defer { silent.stop() }
        let _ = silent.requestService.add(self.request(tag: 94) { _ in })
        Thread.sleep(forTimeInterval: 1.5)
        guard case let .some(.some(nothing)) = self.activity(of: silent) else {
            XCTFail("no activity")
            return
        }
        XCTAssertNil(nothing.silentFor, "never heard the server")
        XCTAssertFalse(nothing.connected)
        XCTAssertNotNil(nothing.waitingFor)

        silent.movePendingRequests(to: session.requestService, deadline: 5.0, completion: {})
        guard case let .some(draining) = self.activity(of: silent) else {
            XCTFail("no reply")
            return
        }
        XCTAssertNil(draining, "a draining session is never judged")
    }

    /// The same hand-over from MtProtoKit (a switch to Rust): MtProtoKit keeps the call that went out
    /// under its message id until the deadline and the call's policy decides; it runs once.
    func testMtProtoKitHandsATransmittedCallOverWithoutRunningItTwice() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.makeContext(useTempAuthKeys: false)
        self.setAddress(of: context, preferForMedia: false)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        guard let rust = RustNetworkEngineFactory().makeEngine(context: context, isAppExtension: false) else {
            XCTFail("factory declined")
            return
        }
        let switching = SwitchingNetworkEngine(engine: MtProtoKitEngine(context: context))
        let session = switching.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 91, on: session) else {
            return
        }
        let outcome = Atomic<String>(value: "pending")
        let disposable = session.requestService.add(self.request(tag: tagNever, shouldContinueAfterError: { _ in false }) { result in
            let _ = outcome.swap(self.outcome(result))
        })
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 5.0, until: { self.server.executions(tag: tagNever) == 1 }))
        let fresh = Atomic<String>(value: "pending")
        XCTAssertTrue(switching.switchEngine(to: .rust, drainTimeout: 2.0, makeEngine: { rust }))
        let next = session.requestService.add(self.request(tag: 92) { result in
            let _ = fresh.swap(self.outcome(result))
        })
        defer { next.dispose() }
        XCTAssertTrue(self.wait(seconds: 15.0, until: { outcome.with { $0 } != "pending" && fresh.with { $0 } != "pending" }))
        XCTAssertEqual(outcome.with { $0 }, "failed 500 ENGINE_SWITCHED")
        XCTAssertEqual(fresh.with { $0 }, "completed")
        XCTAssertFalse(self.wait(seconds: 2.0, until: { self.server.executions(tag: tagNever) > 1 }))
        XCTAssertEqual(self.server.executions(tag: tagNever), 1)
    }
}
