import XCTest
import SwiftSignalKit
import MtProtoKit
import EncryptionProvider
import MTProtoEngineFFI
@testable import TelegramCore
@testable import MTProtoRustEngine
import MTProtoRustEngineMapping

extension RustEngineEndToEndTests {
    private func finalProbingContext(permanentKey: Data) -> (MTContext, NetworkEngine, LoggedOutListener) {
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

    private func finalCall(_ tag: UInt32, on session: NetworkEngineSession) -> Disposable {
        return session.requestService.add(self.request(tag: tag) { _ in
        })
    }

    private func waitFast(seconds: Double, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if condition() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.005)
        }
        return false
    }

    /// The validation's first -404 has come; an answer under the key arrives on another session before the
    /// second: the re-check after AuthKeyInvalid vetoes the logout.
    func testFinalAnAnswerBetweenTheValidationsRejectionsKeepsTheAccount() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.finalProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        self.server.refuseBinds(code: 400, error: "ENCRYPTED_MESSAGE_INVALID")
        self.server.send("hide-permanent-keys on")
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        let disposable = self.finalCall(400, on: main)
        defer { disposable.dispose() }
        XCTAssertTrue(self.waitFast(seconds: 40.0, until: { self.server.hiddenKeyRejections() >= 1 }), "the validation was sent")
        RustContextRegistry.of(context).noteAnswered(datacenterId: datacenterId, keyId: self.permanentKeyId, at: rustEngineMonotonicNow())
        XCTAssertTrue(self.wait(seconds: 10.0, until: { self.server.hiddenKeyRejections() >= 2 }), "the second -404 came")
        XCTAssertFalse(self.wait(seconds: 5.0, until: { listener.logouts > 0 }), "the answer between the -404s must veto")
    }

    /// The kill switch flips while the validation runs: the action is abandoned, no verdict.
    func testFinalADeactivationDuringTheValidationGivesNoVerdict() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.finalProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
        }
        self.server.refuseBinds(code: 400, error: "ENCRYPTED_MESSAGE_INVALID")
        self.server.send("hide-permanent-keys on")
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        let disposable = self.finalCall(401, on: main)
        defer { disposable.dispose() }
        XCTAssertTrue(self.waitFast(seconds: 40.0, until: { self.server.hiddenKeyRejections() >= 1 }), "the validation was sent")
        engine.deactivate()
        XCTAssertFalse(self.wait(seconds: 8.0, until: { listener.logouts > 0 }))
    }

    /// The validation's help.test is answered with a flood wait or a server error: both are answers under the
    /// key, nobody is logged out.
    func testFinalAValidationAnsweredWithAFloodWaitKeepsTheAccount() {
        self.finalValidationAnswered(with: "help-test error 420 FLOOD_WAIT_7", tag: 402)
    }

    func testFinalAValidationAnsweredWithAServerErrorKeepsTheAccount() {
        self.finalValidationAnswered(with: "help-test error 500 INTERNAL_SERVER_ERROR", tag: 403)
    }

    private func finalValidationAnswered(with reply: String, tag: UInt32) {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (context, engine, listener) = self.finalProbingContext(permanentKey: self.server.key)
        defer {
            context.remove(listener)
            engine.deactivate()
        }
        self.server.refuseBinds(code: 400, error: "ENCRYPTED_MESSAGE_INVALID")
        self.server.send(reply)
        let main = engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        main.setPaused(false)
        defer { main.stop() }
        let disposable = self.finalCall(tag, on: main)
        defer { disposable.dispose() }
        XCTAssertTrue(self.wait(seconds: RustEnginePermanentKeyEvidence.observationWindow + 30.0, until: { self.server.helpTests() > 0 }), "the key was validated under itself")
        XCTAssertFalse(self.wait(seconds: 6.0, until: { listener.logouts > 0 }))
    }

    /// Two accounts in one process on one datacenter: one key the server forgot, one it knows. Only the first
    /// logs out, once; the second's sessions and evidence are untouched.
    func testFinalTwoAccountsOnlyTheForgottenKeyLogsOut() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let (forgottenContext, forgottenEngine, forgottenListener) = self.finalProbingContext(permanentKey: RustEngineEndToEndTests.randomKey())
        let (knownContext, knownEngine, knownListener) = self.finalProbingContext(permanentKey: self.server.key)
        defer {
            forgottenContext.remove(forgottenListener)
            knownContext.remove(knownListener)
            forgottenEngine.deactivate()
            knownEngine.deactivate()
        }
        let forgottenMain = forgottenEngine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        forgottenMain.setPaused(false)
        defer { forgottenMain.stop() }
        let knownMain = knownEngine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        knownMain.setPaused(false)
        defer { knownMain.stop() }
        let first = self.finalCall(404, on: forgottenMain)
        defer { first.dispose() }
        XCTAssertTrue(self.completes(tag: 405, on: knownMain))
        XCTAssertTrue(self.wait(seconds: 40.0, until: { forgottenListener.logouts > 0 }))
        XCTAssertFalse(self.wait(seconds: 5.0, until: { knownListener.logouts > 0 || forgottenListener.logouts > 1 }))
        XCTAssertTrue(self.completes(tag: 406, on: knownMain))
        XCTAssertEqual(knownContext.authInfoForDatacenter(withId: datacenterId, selector: .persistent)?.authKeyId, self.permanentKeyId)
    }
}
