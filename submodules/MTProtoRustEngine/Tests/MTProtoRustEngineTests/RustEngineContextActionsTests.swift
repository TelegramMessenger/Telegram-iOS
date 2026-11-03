import XCTest
import SwiftSignalKit
import MtProtoKit
import EncryptionProvider
import MTProtoEngineFFI
@testable import TelegramCore
@testable import MTProtoRustEngine
import MTProtoRustEngineMapping

/// Counts the TCP connections MtProtoKit opens for a context: every `MTTcpConnection` asks the context's
/// factory first. The counter says it is a WEB proxy carrier, so for an ordinary address MtProtoKit then
/// opens its own socket as usual.
final class MtProtoKitTcpCounter: NSObject, MTTcpConnectionInterface {
    static func install(on context: MTContext) -> Atomic<Int> {
        let count = Atomic<Int>(value: 0)
        context.makeTcpConnectionInterface = { _, _ in
            let _ = count.modify { $0 + 1 }
            return MtProtoKitTcpCounter()
        }
        return count
    }

    func setGetLogPrefix(_ getLogPrefix: (() -> String)?) {
    }

    func setUsageCalculationInfo(_ usageCalculationInfo: MTNetworkUsageCalculationInfo?) {
    }

    func connect(toHost inHost: String, onPort port: UInt16, viaInterface inInterface: String?, withTimeout timeout: TimeInterval, error errPtr: NSErrorPointer) -> Bool {
        return false
    }

    func write(_ data: Data) {
    }

    func readData(toLength length: UInt, withTimeout timeout: TimeInterval, tag: Int) {
    }

    func disconnect() {
    }

    func resetDelegate() {
    }

    func isWebProxyCarrier() -> Bool {
        return true
    }
}

/// D1, D3 and D8 of the B2 batch: with the Rust engine active, MTContext's permanent keys, its logout check
/// and its authorization transfers go over the engine, so over HTTP or Telegram Web when TCP is blocked.
extension RustEngineEndToEndTests {
    private func restartServer(_ arguments: [String]) throws {
        guard let binary = TestServerProcess.binaryPath() else {
            throw XCTSkip("no test server")
        }
        self.server = try TestServerProcess(binary: binary, extraArguments: arguments)
    }

    private func setForeignAddress(of context: MTContext, datacenterId: Int) {
        guard let foreign = self.server.foreign else {
            XCTFail("the test server runs no foreign datacenter")
            return
        }
        let address = MTDatacenterAddress(ip: foreign.host, port: foreign.port, preferForMedia: false, restrictToTcp: false, cdn: false, preferForProxy: false, secret: nil)
        context.updateAddressSetForDatacenter(withId: datacenterId, addressSet: MTDatacenterAddressSet(addressList: [address]), forceUpdateSchemes: true)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
    }

    /// Counts the key actions MTContext makes with the installed factory.
    private func countAuthActions(on context: MTContext) -> Atomic<Int> {
        let count = Atomic<Int>(value: 0)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        guard let installed = context.authActionFactory else {
            XCTFail("no key factory installed")
            return count
        }
        context.authActionFactory = { selector, isCdn, skipBind, completion in
            let _ = count.modify { $0 + 1 }
            return installed(selector, isCdn, skipBind, completion)
        }
        return count
    }

    /// Counts the transfer actions MTContext makes with the installed factory.
    private func countTransfers(on context: MTContext) -> Atomic<Int> {
        let count = Atomic<Int>(value: 0)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        guard let installed = context.transferAuthActionFactory else {
            XCTFail("no transfer factory installed")
            return count
        }
        context.transferAuthActionFactory = {
            let _ = count.modify { $0 + 1 }
            return installed()
        }
        return count
    }

    private func permanentHandshakes(_ stats: [String: Any]) -> [Int] {
        return ((stats["handshake_dcs"] as? [[String: Any]]) ?? []).filter { ($0["temporary"] as? Bool) == false }.map { ($0["dc"] as? NSNumber)?.intValue ?? 0 }
    }

    private func call(_ tag: UInt32, on session: NetworkEngineSession, outcome: Atomic<String?>) -> Disposable {
        return session.requestService.add(self.request(tag: tag) { result in
            switch result {
            case .success:
                let _ = outcome.swap("completed")
            case let .failure(failure):
                let _ = outcome.swap("failed \(failure.error.errorCode) \(failure.error.errorDescription ?? "")")
            }
        })
    }

    // MARK: D1 — permanent keys over the engine

    /// R3-A: a fresh login on a network where TCP to Telegram gets no answer and plain HTTP works. The
    /// engine makes the permanent key over HTTP, MtProtoKit opens no connection, and the first call is done
    /// within seconds.
    func testR3A_AFreshLoginCompletesOverHttpWhenTcpIsBlocked() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        self.server.setTcpBlackhole(true)
        let context = self.pfsContext(permanentKey: false)
        let tcp = MtProtoKitTcpCounter.install(on: context)
        let engine = self.pfsEngine(context)
        engine.activate()
        defer { engine.deactivate() }
        let session = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        let started = Date()
        guard self.completes(tag: 80, on: session) else {
            return
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 10.0)
        XCTAssertNotNil(context.authInfoForDatacenter(withId: datacenterId, selector: .persistent), "the engine's key is the context's")
        let stats = self.server.stats()
        XCTAssertEqual(self.permanentHandshakes(stats), [datacenterId], "one permanent key, made by the engine")
        XCTAssertGreaterThan(self.server.httpRequests(), 0)
        XCTAssertEqual(tcp.with { $0 }, 0, "MtProtoKit opened no TCP connection")
    }

    /// The same with TCP and plain HTTP dead: the key is made over Telegram Web's WebSocket.
    func testAFreshLoginCompletesOverTelegramWebWhenTcpAndHttpAreBlocked() throws {
        guard #available(macOS 10.14, *), let front = self.server.webFront, let blackhole = self.server.blackhole else {
            throw XCTSkip("needs macOS 10.14 and the test server's web front")
        }
        let datacenterId = RustEngineEndToEndTests.datacenterId
        RustNetworkSession.webEndpointOverride = (host: "venus.web.test", port: front.port, path: "/apiw1", wsPath: "/apiws", address: front.host)
        defer {
            RustNetworkSession.webEndpointOverride = nil
        }
        let context = self.makeContext(useTempAuthKeys: true)
        let address = MTDatacenterAddress(ip: blackhole.host, port: blackhole.port, preferForMedia: false, restrictToTcp: false, cdn: false, preferForProxy: false, secret: nil)
        context.updateAddressSetForDatacenter(withId: datacenterId, addressSet: MTDatacenterAddressSet(addressList: [address]), forceUpdateSchemes: true)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        let tcp = MtProtoKitTcpCounter.install(on: context)
        let engine = self.pfsEngine(context)
        engine.activate()
        defer { engine.deactivate() }
        let session = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 81, on: session) else {
            return
        }
        XCTAssertNotNil(context.authInfoForDatacenter(withId: datacenterId, selector: .persistent))
        XCTAssertEqual(self.permanentHandshakes(self.server.stats()), [datacenterId])
        XCTAssertGreaterThan((self.server.webFrontStats()["websockets"] as? NSNumber)?.intValue ?? 0, 0)
        XCTAssertEqual(tcp.with { $0 }, 0)
    }

    /// A test-environment key carries the +10000 offset in its handshake, as MtProtoKit's.
    func testAKeyForTheTestEnvironmentCarriesTheTestOffset() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.makeContext(useTempAuthKeys: true, isTestingEnvironment: true)
        self.setAddress(of: context, preferForMedia: false)
        let engine = self.pfsEngine(context)
        engine.activate()
        defer { engine.deactivate() }
        context.authInfoForDatacenter(withIdRequired: datacenterId, isCdn: false, selector: .persistent, allowUnboundEphemeralKeys: false)
        XCTAssertTrue(self.eventually { context.authInfoForDatacenter(withId: datacenterId, selector: .persistent) != nil })
        XCTAssertEqual(self.permanentHandshakes(self.server.stats()), [10000 + datacenterId])
    }

    /// A key that reached the context while the engine was making one (another maker, a restored backup) is
    /// kept, and the engine's is dropped: a key sessions already use is never replaced.
    func testAKeyThatAppearedWhileTheEngineMadeOneIsKept() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        self.server.setTcpBlackhole(true)
        let context = self.pfsContext(permanentKey: false)
        let engine = self.pfsEngine(context)
        engine.activate()
        defer { engine.deactivate() }
        context.authInfoForDatacenter(withIdRequired: datacenterId, isCdn: false, selector: .persistent, allowUnboundEphemeralKeys: false)
        let existing = self.authInfo(key: self.server.key)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: existing, selector: .persistent)
        XCTAssertTrue(self.wait(seconds: 15.0, until: { self.permanentHandshakes(self.server.stats()).count == 1 }), "the engine finished its key")
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(context.authInfoForDatacenter(withId: datacenterId, selector: .persistent)?.authKeyId, existing.authKeyId)
    }

    /// MtProtoKit's own action finishing first or last for the same datacenter: whichever key reached the
    /// context first stays.
    func testOfTwoMakersTheFirstKeyStaysInEitherOrder() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        for mtProtoKitFirst in [true, false] {
            let context = self.pfsContext(permanentKey: false)
            let actions = RustEngineActions(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [self.server.publicKeyPem], httpPort: 0)
            actions.install()
            let mtProtoKitKey = RustEngineEndToEndTests.randomKey()
            let mtProtoKitKeyId = self.authInfo(key: mtProtoKitKey).authKeyId
            let finishMtProtoKit = {
                let action = MTDatacenterAuthAction(authKeyInfoSelector: .persistent, isCdn: false, skipBind: false, completion: { _, _ in })!
                action.attach(to: context, datacenterId: datacenterId)
                let now = Int64(Date().timeIntervalSince1970)
                action.complete(with: MTDatacenterAuthKey(authKey: mtProtoKitKey, authKeyId: mtProtoKitKeyId, validUntilTimestamp: Int32.max, notBound: false), timestamp: now << 32, serverSalt: 1)
                MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
            }
            if mtProtoKitFirst {
                finishMtProtoKit()
            }
            let handshakes = self.permanentHandshakes(self.server.stats()).count
            let action = RustDatacenterAuthAction(actions: actions, selector: .persistent, isCdn: false, skipBind: false, completion: { _, _ in })
            action.replacesExistingKey = true
            action.execute(context, datacenterId: datacenterId)
            XCTAssertTrue(self.wait(seconds: 15.0, until: { self.permanentHandshakes(self.server.stats()).count == handshakes + 1 }))
            Thread.sleep(forTimeInterval: 0.3)
            MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
            let rustKeyId = context.authInfoForDatacenter(withId: datacenterId, selector: .persistent)?.authKeyId
            if !mtProtoKitFirst {
                XCTAssertNotNil(rustKeyId)
                XCTAssertNotEqual(rustKeyId, mtProtoKitKeyId)
                finishMtProtoKit()
                XCTAssertEqual(context.authInfoForDatacenter(withId: datacenterId, selector: .persistent)?.authKeyId, rustKeyId, "MtProtoKit's later key is dropped")
            } else {
                XCTAssertEqual(rustKeyId, mtProtoKitKeyId, "the engine's later key is dropped")
            }
            actions.uninstall()
        }
    }

    /// The kill switch moves an account whose permanent key the engine made to MtProtoKit: MtProtoKit
    /// makes its own temporary key, binds it to that key and the calls go on.
    func testMtProtoKitTakesOverAKeyTheEngineMade() throws {
        guard let encryptionProvider = LibCryptoEncryptionProvider() else {
            throw XCTSkip("MtProtoKit's key exchange needs libcrypto: install OpenSSL 3 or set MTPROTO_TEST_LIBCRYPTO")
        }
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.makeContext(useTempAuthKeys: true, encryptionProvider: encryptionProvider)
        self.setAddress(of: context, preferForMedia: false)
        context.updatePublicKeysForDatacenter(withId: datacenterId, publicKeys: [["key": self.server.publicKeyPem]])
        let rust = self.pfsEngine(context)
        rust.activate()
        let switching = SwitchingNetworkEngine(engine: rust)
        let session = switching.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 82, on: session), let engineKey = context.authInfoForDatacenter(withId: datacenterId, selector: .persistent) else {
            XCTFail("the engine made no key")
            return
        }
        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 0.0, makeEngine: { MtProtoKitEngine(context: context) }))
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        XCTAssertNil(context.value(forKey: "authActionFactory"), "MtProtoKit makes keys again")
        let factory: @convention(block) (MTDatacenterAuthInfoSelector, Bool, Bool, @escaping (MTDatacenterAuthAction?, Bool) -> Void) -> MTDatacenterAuthAction = { selector, _, skipBind, completion in
            return MTDatacenterAuthAction(authKeyInfoSelector: selector, isCdn: true, skipBind: skipBind, completion: { action, success in
                completion(action, success)
            })
        }
        context.setValue(factory, forKey: "authActionFactory")
        XCTAssertTrue(self.completes(tag: 83, on: session), "MtProtoKit goes on under the temporary key the engine bound")
        let binds = self.server.binds()
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: nil, selector: .ephemeralMain)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        let relaunched = MtProtoKitEngine(context: context).makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        relaunched.setPaused(false)
        defer { relaunched.stop() }
        XCTAssertTrue(self.completes(tag: 84, on: relaunched), "after a relaunch on MtProtoKit, without the engine's temporary key")
        XCTAssertEqual(context.authInfoForDatacenter(withId: datacenterId, selector: .persistent)?.authKeyId, engineKey.authKeyId, "the engine's permanent key stays")
        XCTAssertGreaterThan(self.server.binds(), binds, "MtProtoKit bound a temporary key of its own to it")
        XCTAssertNotNil(context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain))
        XCTAssertTrue(self.server.bindFailures().isEmpty, "\(self.server.bindFailures())")
    }

    // MARK: D8 — the logout check over the engine

    private func rustProbingContext(permanentKey: Data) -> (MTContext, NetworkEngine, LoggedOutListener) {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.makeContext(useTempAuthKeys: true)
        self.setAddress(of: context, preferForMedia: false)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: self.authInfo(key: permanentKey), selector: .persistent)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        let engine = self.pfsEngine(context)
        engine.activate()
        let listener = LoggedOutListener()
        context.add(listener)
        return (context, engine, listener)
    }

    /// What the context registry says now about the home key (nil: the evidence holds).
    private func registryDenial(_ context: MTContext) -> String? {
        let done = XCTestExpectation(description: "decision")
        let denial = Atomic<String?>(value: "none")
        RustContextRegistry.of(context).confirmUnknown(datacenterId: RustEngineEndToEndTests.datacenterId, keyId: self.permanentKeyId, queue: Queue(), completion: { result in
            let _ = denial.swap(result)
            done.fulfill()
        })
        XCTAssertEqual(XCTWaiter().wait(for: [done], timeout: RustEnginePermanentKeyEvidence.observationWindow + 5.0), .completed)
        return denial.with { $0 }
    }

    /// R3-D with TCP blocked: the home permanent key is unknown to the server. The engine reports it over
    /// HTTP, the check binds its own fresh key over HTTP and is refused too, no call completed under the key:
    /// exactly one logout. A stale temporary key copy in the context does not answer the check.
    func testR3D_AnUnknownHomeKeyLogsOutExactlyOnceWhenOnlyHttpWorks() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        self.server.setTcpBlackhole(true)
        let forgotten = RustEngineEndToEndTests.randomKey()
        let (context, engine, listener) = self.rustProbingContext(permanentKey: forgotten)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        let tcp = MtProtoKitTcpCounter.install(on: context)
        let staleCopy = self.temporaryKeyCopy(boundTo: forgotten, validUntil: Int32(Date().timeIntervalSince1970) - 3600)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: staleCopy, selector: .ephemeralMain)
        let session = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        let outcome = Atomic<String?>(value: nil)
        let disposable = self.call(92, on: session, outcome: outcome)
        defer { disposable.dispose() }

        XCTAssertTrue(self.wait(seconds: 40.0, until: { listener.logouts > 0 }), "bind failures \(self.server.bindFailures())")
        XCTAssertFalse(self.wait(seconds: 5.0, until: { listener.logouts > 1 }))
        XCTAssertEqual(listener.logouts, 1)
        XCTAssertGreaterThanOrEqual(self.server.bindFailures().filter { $0 == "ENCRYPTED_MESSAGE_INVALID" }.count, 3, "two of the engine's binds and the check's")
        XCTAssertEqual(context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain)?.authKeyId, staleCopy.authKeyId, "the check stores nothing")
        XCTAssertNil(outcome.with { $0 })
        XCTAssertEqual(tcp.with { $0 }, 0, "the check went over the engine")
    }

    /// The check's bind succeeds (the engine's report was wrong): nobody is logged out, nothing is stored.
    func testACheckThatBindsKeepsTheAccount() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.rustProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        let binds = self.server.binds()
        context.checkIfLoggedOut(datacenterId)
        XCTAssertTrue(self.wait(seconds: 15.0, until: { self.server.binds() > binds }))
        XCTAssertFalse(self.wait(seconds: 3.0, until: { listener.logouts > 0 }))
        XCTAssertNil(context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain), "the check's key is never stored")
    }

    /// The check is refused, but the engine never reported the key: a refusal on its own logs nobody out.
    func testARefusedCheckWithoutTheEnginesReportDoesNotLogOut() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let forgotten = RustEngineEndToEndTests.randomKey()
        let (context, engine, listener) = self.rustProbingContext(permanentKey: forgotten)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        RustContextRegistry.of(context).noteRefusedBind(datacenterId: datacenterId, keyId: self.authInfo(key: forgotten).authKeyId, at: rustEngineMonotonicNow() - 30.0)
        context.checkIfLoggedOut(datacenterId)
        XCTAssertTrue(self.wait(seconds: 15.0, until: { self.server.bindFailures().contains("ENCRYPTED_MESSAGE_INVALID") }))
        XCTAssertFalse(self.wait(seconds: 3.0, until: { listener.logouts > 0 }))
    }

    /// Binds of fresh keys are refused while a live worker keeps completing calls under a key bound before:
    /// the engine reports the key unknown and the check is refused too, but the worker's last answer under
    /// the key, read from the live session when the check decides, keeps the account (the immunity).
    func testCallsCompletingUnderTheKeyOverruleRefusedBinds() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.rustProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        let worker = engine.makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: false, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        worker.setPaused(false)
        defer { worker.stop() }
        guard self.completes(tag: 93, on: worker), self.eventually({ context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) != nil }) else {
            return
        }
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: nil, selector: .ephemeralMain)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        self.server.refuseBinds(code: 400, error: "ENCRYPTED_MESSAGE_INVALID")
        let busy = Atomic<Bool>(value: true)
        let keepBusy = Thread {
            var tag: UInt32 = 200
            while busy.with({ $0 }) {
                let done = DispatchSemaphore(value: 0)
                let disposable = worker.requestService.add(self.request(tag: tag) { _ in
                    done.signal()
                })
                _ = done.wait(timeout: .now() + 2.0)
                disposable.dispose()
                tag += 1
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
        keepBusy.start()
        defer { let _ = busy.swap(false) }
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        let outcome = Atomic<String?>(value: nil)
        let disposable = self.call(94, on: main, outcome: outcome)
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 30.0, until: { self.server.bindFailures().count >= 3 }), "the engine's binds and the check's were refused: \(self.server.bindFailures())")
        XCTAssertFalse(self.wait(seconds: RustEnginePermanentKeyEvidence.observationWindow + 8.0, until: { listener.logouts > 0 }))
    }

    /// The check's bind keeps failing with server errors: no verdict, no logout.
    func testACheckThatOnlySeesServerErrorsDoesNotLogOut() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.rustProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        self.server.refuseBinds(code: 500, error: "INTERNAL_SERVER_ERROR")
        context.checkIfLoggedOut(datacenterId)
        XCTAssertTrue(self.wait(seconds: 30.0, until: { self.server.bindFailures().count >= rustEngineKeyProbeTransientFailures }))
        XCTAssertFalse(self.wait(seconds: 3.0, until: { listener.logouts > 0 }))
    }

    /// The check's bind is never answered: the check gives up at its deadline, without a verdict.
    func testACheckThatGetsNoAnswerDoesNotLogOut() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.rustProbingContext(permanentKey: RustEngineEndToEndTests.randomKey())
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        context.setValue(5.0, forKey: "loggedOutCheckTimeout")
        self.server.ignoreBinds()
        context.checkIfLoggedOut(datacenterId)
        XCTAssertFalse(self.wait(seconds: 10.0, until: { listener.logouts > 0 }))
    }

    /// The server knows the key: the main session bound a temporary key to it and completed a call moments
    /// ago. Then, for a few seconds, the server refuses fresh binds with ENCRYPTED_MESSAGE_INVALID and loses
    /// the temporary keys (a datacenter incident). The engine reports the key, the check is refused and no
    /// call completes, but the server answered under the key within the last day: nobody is logged out.
    func testATransientRefusalEpisodeDoesNotLogOutAKeyBoundMomentsAgo() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.rustProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        guard self.completes(tag: 300, on: main) else {
            return
        }
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: nil, selector: .ephemeralMain)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        self.server.refuseBinds(code: 400, error: "ENCRYPTED_MESSAGE_INVALID")
        self.server.dropTemporaryKeys()
        let outcome = Atomic<String?>(value: nil)
        let disposable = self.call(301, on: main, outcome: outcome)
        defer { disposable.dispose() }
        let helpTests = self.server.helpTests()
        XCTAssertTrue(self.wait(seconds: 30.0, until: { self.server.bindFailures().count >= 3 }), "the engine's two binds and the check's: \(self.server.bindFailures())")
        XCTAssertFalse(self.wait(seconds: RustEnginePermanentKeyEvidence.observationWindow + 10.0, until: { listener.logouts > 0 }), "logged out a key the server bound moments before")
        XCTAssertEqual(self.server.helpTests(), helpTests, "the immunity: the key is not even validated")
        XCTAssertEqual(context.authInfoForDatacenter(withId: datacenterId, selector: .persistent)?.authKeyId, self.permanentKeyId)
    }

    /// A datacenter incident in which the server cannot find the key at all for a while: fresh binds are
    /// refused, and calls under the key itself get -404, exactly as for a key it forgot. The main session
    /// completed a call under the key moments before, so tdlib's immunity holds: the key is not even
    /// validated (nothing reaches the server under the key itself), and nobody is logged out.
    func testAnIncidentThatHidesAKeyAnsweredUnderTodayLogsNobodyOut() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.rustProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        guard self.completes(tag: 304, on: main) else {
            return
        }
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: nil, selector: .ephemeralMain)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        self.server.refuseBinds(code: 400, error: "ENCRYPTED_MESSAGE_INVALID")
        self.server.send("hide-permanent-keys on")
        self.server.dropTemporaryKeys()
        let outcome = Atomic<String?>(value: nil)
        let disposable = self.call(305, on: main, outcome: outcome)
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 30.0, until: { self.server.bindFailures().filter { $0 == "ENCRYPTED_MESSAGE_INVALID" }.count >= 3 }), "the engine's two binds and the check's: \(self.server.bindFailures())")
        XCTAssertFalse(self.wait(seconds: RustEnginePermanentKeyEvidence.observationWindow + 10.0, until: { listener.logouts > 0 }), "logged out a key the server answered under moments before")
        XCTAssertEqual(self.server.hiddenKeyRejections(), 0, "the immunity: nothing was sent under the key itself")
        XCTAssertEqual(context.authInfoForDatacenter(withId: datacenterId, selector: .persistent)?.authKeyId, self.permanentKeyId)
    }

    /// The engine's own binds fail from the first one (a bind bug, or a server that refuses them) while the
    /// server knows the key: there is no accepted bind to compare with, but the call under the key itself
    /// is answered, so nobody is logged out.
    func testRefusedBindsFromTheStartDoNotLogOutAKeyTheServerKnows() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.rustProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        self.server.refuseBinds(code: 400, error: "ENCRYPTED_MESSAGE_INVALID")
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        let outcome = Atomic<String?>(value: nil)
        let disposable = self.call(302, on: main, outcome: outcome)
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 30.0, until: { self.server.bindFailures().count >= 3 }), "\(self.server.bindFailures())")
        XCTAssertTrue(self.wait(seconds: RustEnginePermanentKeyEvidence.observationWindow + 15.0, until: { self.server.helpTests() > 0 }), "the key was validated under itself")
        XCTAssertFalse(self.wait(seconds: 5.0, until: { listener.logouts > 0 }))
        XCTAssertTrue(self.registryDenial(context)?.hasPrefix("the server answered under the key") ?? false, "the validation's answer was taken as one, not waited out")
    }

    /// The same, but the call under the permanent key itself is answered with an error, here a 401: still
    /// an answer the server encrypted under the key, so nobody is logged out (a 401 is the session's own
    /// business, not this check's).
    func testAValidationAnsweredWithAnErrorKeepsTheAccount() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.rustProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        self.server.refuseBinds(code: 400, error: "ENCRYPTED_MESSAGE_INVALID")
        self.server.send("help-test error 401 AUTH_KEY_UNREGISTERED")
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        let outcome = Atomic<String?>(value: nil)
        let disposable = self.call(306, on: main, outcome: outcome)
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 30.0, until: { self.server.bindFailures().count >= 3 }), "\(self.server.bindFailures())")
        XCTAssertTrue(self.wait(seconds: RustEnginePermanentKeyEvidence.observationWindow + 15.0, until: { self.server.helpTests() > 0 }), "the key was validated under itself")
        XCTAssertFalse(self.wait(seconds: 5.0, until: { listener.logouts > 0 }))
        XCTAssertTrue(self.registryDenial(context)?.hasPrefix("the server answered under the key") ?? false, "the validation's answer was taken as one, not waited out")
    }

    /// The same, but the call under the permanent key is never answered: no verdict, the check gives up at
    /// MTContext's deadline (shortened here).
    func testAValidationWithoutAnAnswerGivesNoVerdict() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.rustProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        context.setValue(25.0, forKey: "loggedOutCheckTimeout")
        self.server.refuseBinds(code: 400, error: "ENCRYPTED_MESSAGE_INVALID")
        self.server.send("help-test silent")
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        let outcome = Atomic<String?>(value: nil)
        let disposable = self.call(303, on: main, outcome: outcome)
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 30.0, until: { self.server.bindFailures().count >= 3 }), "\(self.server.bindFailures())")
        XCTAssertTrue(self.wait(seconds: RustEnginePermanentKeyEvidence.observationWindow + 15.0, until: { self.server.helpTests() > 0 }), "the key was validated under itself")
        XCTAssertFalse(self.wait(seconds: 20.0, until: { listener.logouts > 0 }))
    }

    /// The accepted limit of the immunity, as in tdlib: in a context with no sign of the key yet (a fresh
    /// launch), a server that refuses fresh binds and answers -404 under the key itself is taken at its
    /// word, even if it merely cannot find the key for a while. The validation's -404s lead to the
    /// re-check, which finds no answer under the key either: exactly one logout.
    func testRefusedBindsAndAHiddenKeyLogOutAFreshContextAsInTdlib() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.rustProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        self.server.refuseBinds(code: 400, error: "ENCRYPTED_MESSAGE_INVALID")
        self.server.send("hide-permanent-keys on")
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        let outcome = Atomic<String?>(value: nil)
        let disposable = self.call(307, on: main, outcome: outcome)
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 40.0, until: { listener.logouts > 0 }), "bind failures \(self.server.bindFailures())")
        XCTAssertFalse(self.wait(seconds: 3.0, until: { listener.logouts > 1 }))
        XCTAssertEqual(listener.logouts, 1)
        XCTAssertEqual(self.server.helpTests(), 0, "the validation never reached a server that could read it")
        XCTAssertGreaterThanOrEqual(self.server.hiddenKeyRejections(), 2, "the validation's two -404s, the second on a fresh connection")
    }

    /// The true positive over Telegram Web only (TCP blackholed, no plain HTTP): a home key the server
    /// forgot. The engine's refusals, the check's refusal and the call under the key itself (-404 over the
    /// WebSocket) all go over WSS: exactly one logout.
    func testAnUnknownHomeKeyStillLogsOutOverTelegramWebOnly() throws {
        guard #available(macOS 10.14, *), let front = self.server.webFront, let blackhole = self.server.blackhole else {
            throw XCTSkip("needs macOS 10.14 and the test server's web front")
        }
        let datacenterId = RustEngineEndToEndTests.datacenterId
        RustNetworkSession.webEndpointOverride = (host: "venus.web.test", port: front.port, path: "/apiw1", wsPath: "/apiws", address: front.host)
        defer {
            RustNetworkSession.webEndpointOverride = nil
        }
        let context = self.makeContext(useTempAuthKeys: true)
        let address = MTDatacenterAddress(ip: blackhole.host, port: blackhole.port, preferForMedia: false, restrictToTcp: false, cdn: false, preferForProxy: false, secret: nil)
        context.updateAddressSetForDatacenter(withId: datacenterId, addressSet: MTDatacenterAddressSet(addressList: [address]), forceUpdateSchemes: true)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: self.authInfo(key: RustEngineEndToEndTests.randomKey()), selector: .persistent)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        let engine = self.pfsEngine(context)
        engine.activate()
        let listener = LoggedOutListener()
        context.add(listener)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        let outcome = Atomic<String?>(value: nil)
        let disposable = self.call(310, on: main, outcome: outcome)
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: 60.0, until: { listener.logouts > 0 }), "bind failures \(self.server.bindFailures())")
        XCTAssertFalse(self.wait(seconds: 3.0, until: { listener.logouts > 1 }))
        XCTAssertEqual(listener.logouts, 1)
        XCTAssertGreaterThan((self.server.webFrontStats()["websockets"] as? NSNumber)?.intValue ?? 0, 0)
    }

    /// A switch to MtProtoKit (the kill switch) ends a key maker the engine cannot finish, so MtProtoKit
    /// can make that key at once instead of waiting behind it until a restart.
    func testSwitchingToMtProtoKitEndsAKeyMakerTheEngineCannotFinish() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: false)
        let engine = RustNetworkEngine(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: MTDatacenterAuthDefaultPublicKeys(true), httpPort: 0)
        engine.activate()
        context.authInfoForDatacenter(withIdRequired: datacenterId, isCdn: false, selector: .persistent, allowUnboundEphemeralKeys: false)
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertTrue(self.server.handshakes().isEmpty, "the server's key is not one the engine was given")
        engine.deactivate()
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        let created = Atomic<Int>(value: 0)
        let factory: @convention(block) (MTDatacenterAuthInfoSelector, Bool, Bool, @escaping (MTDatacenterAuthAction?, Bool) -> Void) -> MTDatacenterAuthAction = { selector, isCdn, skipBind, completion in
            let _ = created.modify { $0 + 1 }
            return InertAuthAction(authKeyInfoSelector: selector, isCdn: isCdn, skipBind: skipBind, completion: { action, success in
                completion(action, success)
            })
        }
        context.setValue(factory, forKey: "authActionFactory")
        XCTAssertTrue(self.wait(seconds: 10.0, until: {
            context.authInfoForDatacenter(withIdRequired: datacenterId, isCdn: false, selector: .persistent, allowUnboundEphemeralKeys: false)
            return created.with { $0 } > 0
        }), "MtProtoKit's action takes the key over")
    }

    /// A key maker that makes no key in time gives up; MTContext asks again with its backoff and makes a new
    /// one, instead of keeping one stuck action for ever.
    func testAKeyMakerThatMakesNoKeyGivesUpAndIsAskedAgain() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        RustDatacenterAuthAction.permanentKeyTimeout = 1.5
        defer { RustDatacenterAuthAction.permanentKeyTimeout = 300.0 }
        let context = self.pfsContext(permanentKey: false)
        let engine = RustNetworkEngine(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: MTDatacenterAuthDefaultPublicKeys(true), httpPort: 0)
        engine.activate()
        defer { engine.deactivate() }
        let created = self.countAuthActions(on: context)
        XCTAssertTrue(self.wait(seconds: 12.0, until: {
            context.authInfoForDatacenter(withIdRequired: datacenterId, isCdn: false, selector: .persistent, allowUnboundEphemeralKeys: false)
            return created.with { $0 } >= 2
        }), "\(created.with { $0 }) key makers")
    }

    // MARK: D3 — authorization transfer over the engine

    /// A transfer cancelled before its export (`removeTokenForDatacenter`, a context going away) imports
    /// nothing, writes no token and never reports success.
    func testACancelledTransferImportsNothing() throws {
        try self.restartServer(["--api"])
        let master = RustEngineEndToEndTests.datacenterId
        let foreign = 4
        self.server.setTcpBlackhole(true)
        let context = self.pfsContext(permanentKey: true)
        self.setForeignAddress(of: context, datacenterId: foreign)
        context.updateAuthInfoForDatacenter(withId: foreign, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        let actions = RustEngineActions(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [self.server.publicKeyPem], httpPort: 0)
        actions.install()
        defer { actions.uninstall() }
        let recorder = TransferRecorder()
        let action = RustDatacenterTransferAuthAction(actions: actions)
        action.delegate = recorder
        action.execute(context, masterDatacenterId: master, destinationDatacenterId: foreign, authToken: foreign as NSNumber)
        Thread.sleep(forTimeInterval: 0.5)
        action.cancel()
        Thread.sleep(forTimeInterval: 6.0)
        let api = self.server.apiStats()
        XCTAssertEqual((api["exports"] as? NSNumber)?.intValue, 0)
        XCTAssertEqual((api["imports"] as? NSNumber)?.intValue, 0)
        XCTAssertNil(context.authTokenForDatacenter(withId: foreign))
        XCTAssertEqual(recorder.completed.with { $0 }, 0)
    }

    /// The import is answered with a server error: the bytes are not sent again; one fresh export and its
    /// import finish the same transfer.
    func testAnImportServerErrorIsExportedAgainOnce() throws {
        try self.restartServer(["--api", "--import-fails-once-500"])
        let master = RustEngineEndToEndTests.datacenterId
        let foreign = 4
        let context = self.pfsContext(permanentKey: true)
        self.setForeignAddress(of: context, datacenterId: foreign)
        context.updateAuthInfoForDatacenter(withId: foreign, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        let engine = self.pfsEngine(context)
        engine.activate()
        defer { engine.deactivate() }
        let transfers = self.countTransfers(on: context)
        let worker = engine.makeSession(datacenterId: foreign, role: .worker(masterDatacenterId: master, isMedia: false, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        worker.setPaused(false)
        defer { worker.stop() }
        guard self.completes(tag: 112, on: worker) else {
            return
        }
        let api = self.server.apiStats()
        XCTAssertEqual((api["exports"] as? NSNumber)?.intValue, 2)
        XCTAssertEqual((api["imports"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual((api["refused_imports"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual(transfers.with { $0 }, 1)
    }

    /// R3-B with TCP blocked, and first contact with the datacenter: the engine makes datacenter 4's
    /// permanent key, exports the authorization on datacenter 2 and imports it on 4, all over HTTP, and the
    /// waiting worker's call goes out. MtProtoKit opens no connection.
    func testR3B_AForeignWorkerGetsItsAuthorizationOverHttpWhenTcpIsBlocked() throws {
        try self.restartServer(["--api"])
        let master = RustEngineEndToEndTests.datacenterId
        let foreign = 4
        self.server.setTcpBlackhole(true)
        let context = self.pfsContext(permanentKey: true)
        self.setForeignAddress(of: context, datacenterId: foreign)
        let tcp = MtProtoKitTcpCounter.install(on: context)
        let engine = self.pfsEngine(context)
        engine.activate()
        defer { engine.deactivate() }
        let worker = engine.makeSession(datacenterId: foreign, role: .worker(masterDatacenterId: master, isMedia: false, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        worker.setPaused(false)
        defer { worker.stop() }
        guard self.completes(tag: 95, on: worker) else {
            return
        }
        XCTAssertTrue((foreign as NSNumber).isEqual(context.authTokenForDatacenter(withId: foreign)))
        let api = self.server.apiStats()
        XCTAssertEqual((api["exports"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual((api["imports"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual(self.permanentHandshakes(self.server.foreignStats()), [foreign], "the engine made datacenter 4's key")
        XCTAssertNotNil(context.authInfoForDatacenter(withId: foreign, selector: .persistent))
        XCTAssertEqual(tcp.with { $0 }, 0, "MtProtoKit opened no TCP connection")
    }

    /// The export goes through the account's running main session.
    func testTheAuthorizationIsExportedThroughTheMainSession() throws {
        try self.restartServer(["--api"])
        let master = RustEngineEndToEndTests.datacenterId
        let foreign = 4
        let context = self.pfsContext(permanentKey: true)
        self.setForeignAddress(of: context, datacenterId: foreign)
        context.updateAuthInfoForDatacenter(withId: foreign, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        let engine = self.pfsEngine(context)
        engine.activate()
        defer { engine.deactivate() }
        let main = engine.makeSession(datacenterId: master, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        guard self.completes(tag: 96, on: main) else {
            return
        }
        let mainConnections = (self.server.stats()["connections"] as? NSNumber)?.intValue ?? 0
        let worker = engine.makeSession(datacenterId: foreign, role: .worker(masterDatacenterId: master, isMedia: false, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        worker.setPaused(false)
        defer { worker.stop() }
        guard self.completes(tag: 97, on: worker) else {
            return
        }
        XCTAssertEqual((self.server.apiStats()["imports"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual((self.server.stats()["connections"] as? NSNumber)?.intValue ?? 0, mainConnections, "no new connection to the master datacenter")
    }

    /// The first import is refused with AUTH_BYTES_INVALID: the authorization is exported again, never
    /// sent twice, and the second import works.
    func testARefusedImportIsExportedAgain() throws {
        try self.restartServer(["--api", "--import-fails-once"])
        let master = RustEngineEndToEndTests.datacenterId
        let foreign = 4
        let context = self.pfsContext(permanentKey: true)
        self.setForeignAddress(of: context, datacenterId: foreign)
        context.updateAuthInfoForDatacenter(withId: foreign, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        let engine = self.pfsEngine(context)
        engine.activate()
        defer { engine.deactivate() }
        let transfers = self.countTransfers(on: context)
        let worker = engine.makeSession(datacenterId: foreign, role: .worker(masterDatacenterId: master, isMedia: true, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        worker.setPaused(false)
        defer { worker.stop() }
        guard self.completes(tag: 98, on: worker) else {
            return
        }
        let api = self.server.apiStats()
        XCTAssertEqual((api["exports"] as? NSNumber)?.intValue, 2)
        XCTAssertEqual((api["imports"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual((api["refused_imports"] as? NSNumber)?.intValue, 1)
        XCTAssertEqual(transfers.with { $0 }, 1, "the one transfer exported again by itself")
    }

    /// An export the server refuses fails the transfer; MTContext asks again with its backoff (1, 2, 4 s),
    /// not in a storm.
    func testARefusedExportIsRetriedOnlyWithBackoff() throws {
        try self.restartServer(["--api"])
        let foreign = 4
        let destination = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        self.setForeignAddress(of: context, datacenterId: foreign)
        context.updateAuthInfoForDatacenter(withId: foreign, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        let engine = self.pfsEngine(context)
        engine.activate()
        defer { engine.deactivate() }
        let transfers = self.countTransfers(on: context)
        let worker = engine.makeSession(datacenterId: destination, role: .worker(masterDatacenterId: foreign, isMedia: false, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        worker.setPaused(false)
        defer { worker.stop() }
        let outcome = Atomic<String?>(value: nil)
        let disposable = self.call(99, on: worker, outcome: outcome)
        defer { disposable.dispose() }
        Thread.sleep(forTimeInterval: 10.0)
        XCTAssertTrue((1 ... 5).contains(transfers.with { $0 }), "\(transfers.with { $0 }) transfers in 10 s")
        XCTAssertNil(outcome.with { $0 }, "the worker waits for its token")
        let api = self.server.apiStats()
        XCTAssertEqual((api["exports"] as? NSNumber)?.intValue, 0, "datacenter 4 refuses to export (DC_ID_INVALID)")
        let attempts = (api["refused_exports"] as? NSNumber)?.intValue ?? 0
        XCTAssertTrue((1 ... 5).contains(attempts), "\(attempts) export attempts in 10 s")
        XCTAssertNil(context.authTokenForDatacenter(withId: destination))
    }
}

/// A key action that does nothing: it stands for MtProtoKit's own in tests that only count actions.
final class InertAuthAction: MTDatacenterAuthAction {
    override func execute(_ context: MTContext!, datacenterId: Int) {
    }
}

final class TransferRecorder: NSObject, MTDatacenterTransferAuthActionDelegate {
    let completed = Atomic<Int>(value: 0)
    let failed = Atomic<Int>(value: 0)

    func datacenterTransferAuthActionCompleted(_ action: MTDatacenterTransferAuthAction!) {
        let _ = self.completed.modify { $0 + 1 }
    }

    func datacenterTransferAuthActionFailed(_ action: MTDatacenterTransferAuthAction!) {
        let _ = self.failed.modify { $0 + 1 }
    }
}

extension TestServerProcess {
    func refuseBinds(code: Int32, error: String) {
        self.send("refuse-binds \(code) \(error)")
    }

    func ignoreBinds() {
        self.send("ignore-binds")
    }
}
