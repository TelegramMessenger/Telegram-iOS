import XCTest
import SwiftSignalKit
import MtProtoKit
@testable import TelegramCore

private final class DrainRequestService: NetworkEngineRequestService {
    private let lock = NSLock()
    private var added: [NetworkEngineRequest] = []
    private var cancelled: [NetworkEngineRequest] = []

    func add(_ request: NetworkEngineRequest) -> Disposable {
        self.lock.lock()
        self.added.append(request)
        self.lock.unlock()
        return ActionDisposable { [weak self] in
            guard let self = self else {
                return
            }
            self.lock.lock()
            self.cancelled.append(request)
            self.lock.unlock()
        }
    }

    var requests: [NetworkEngineRequest] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.added
    }

    var cancelledRequests: [NetworkEngineRequest] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.cancelled
    }
}

private final class DrainSession: NetworkEngineSession {
    let datacenterId: Int
    let service = DrainRequestService()
    private(set) var stopped = false
    private(set) var drainTarget: NetworkEngineRequestService?
    private(set) var drainDeadline: Double?
    private var drainCompletion: (() -> Void)?
    var activity: NetworkEngineServerActivity?

    init(datacenterId: Int) {
        self.datacenterId = datacenterId
    }

    var requestService: NetworkEngineRequestService {
        return self.service
    }

    func setPaused(_ paused: Bool) {
    }

    func setOnline(_ online: Bool) {
    }

    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
    }

    func stop() {
        self.stopped = true
    }

    func movePendingRequests(to service: NetworkEngineRequestService, deadline: Double, completion: @escaping () -> Void) {
        self.drainTarget = service
        self.drainDeadline = deadline
        self.drainCompletion = completion
    }

    func serverActivity(_ reply: @escaping (NetworkEngineServerActivity?) -> Void) {
        reply(self.activity)
    }

    /// The engine lets a request go to the session that replaces this one.
    func release(_ request: NetworkEngineRequest) -> Disposable? {
        return self.drainTarget?.add(request)
    }

    func finishDrain() {
        let completion = self.drainCompletion
        self.drainCompletion = nil
        completion?()
    }
}

private final class DrainEngine: NetworkEngine {
    let kind: NetworkEngineKind
    private(set) var sessions: [DrainSession] = []
    var sessionActivity: NetworkEngineServerActivity?

    init(kind: NetworkEngineKind) {
        self.kind = kind
    }

    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
        let session = DrainSession(datacenterId: datacenterId)
        session.activity = self.sessionActivity
        self.sessions.append(session)
        return session
    }
}

private final class ResetCounter: NetworkEngineUpdateSink {
    private(set) var resets = 0

    func networkSessionDidReset() {
        self.resets += 1
    }

    func networkSessionDidReceive(message: Any) {
    }
}

private func drainRequest(_ name: String, policy: @escaping (NetworkEngineErrorContext) -> Bool = { _ in false }, completed: @escaping (Result<NetworkEngineResponse, NetworkEngineRequestFailure>) -> Void = { _ in }) -> NetworkEngineRequest {
    return NetworkEngineRequest(payload: Data([1, 2, 3, 4]), name: name, parse: { $0 }, shouldContinueAfterError: policy, completed: completed)
}

/// A live switch hands the old session's requests over at once (`movePendingRequests` with the drain
/// timeout as its deadline); the old session lets each go when moving it cannot run it twice, and stops
/// once it let the last one go.
final class NetworkEngineDrainTests: XCTestCase {
    func testASwitchHandsTheRequestsOverAtOnceAndStopsTheOldSessionWhenItIsDone() {
        let rust = DrainEngine(kind: .rust)
        let mtProtoKit = DrainEngine(kind: .mtProtoKit)
        let switching = SwitchingNetworkEngine(engine: rust)
        let session = switching.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: nil)
        defer { session.stop() }
        let sink = ResetCounter()
        session.addUpdateSink(sink)
        let request = drainRequest("in flight")
        let _ = session.requestService.add(request)
        let old = rust.sessions[0]
        XCTAssertTrue(old.service.requests.first === request)

        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 5.0, makeEngine: { mtProtoKit }))
        XCTAssertEqual(old.drainDeadline, 5.0, "the drain starts at once, with the timeout as its deadline")
        XCTAssertFalse(old.stopped)
        let replacement = mtProtoKit.sessions[0]
        let fresh = drainRequest("fresh")
        let _ = session.requestService.add(fresh)
        XCTAssertTrue(replacement.service.requests.first === fresh, "new requests go to the replacement")

        let moved = old.release(request)
        XCTAssertNotNil(moved)
        XCTAssertTrue(replacement.service.requests.last === request, "a released request lands on the replacement")
        XCTAssertEqual(sink.resets, 0)

        old.finishDrain()
        XCTAssertTrue(old.stopped, "the old session stops once its requests are handed over")
        XCTAssertEqual(sink.resets, 1, "updates may have been lost between the sessions")
    }

    func testARequestReleasedAfterAnotherSwitchSkipsTheSessionDrainingInTurn() {
        let first = DrainEngine(kind: .rust)
        let second = DrainEngine(kind: .mtProtoKit)
        let third = DrainEngine(kind: .rust)
        let switching = SwitchingNetworkEngine(engine: first)
        let session = switching.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: nil)
        defer { session.stop() }
        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 5.0, makeEngine: { second }))
        XCTAssertTrue(switching.switchEngine(to: .rust, drainTimeout: 5.0, makeEngine: { third }))
        let late = drainRequest("late")
        let _ = first.sessions[0].release(late)
        XCTAssertTrue(third.sessions[0].service.requests.first === late)
        XCTAssertTrue(second.sessions[0].service.requests.isEmpty)
        XCTAssertNotNil(second.sessions[0].drainTarget, "the second session drains as well")
    }

    func testAReleaseAfterTheNetworkStoppedGoesNowhere() {
        let rust = DrainEngine(kind: .rust)
        let mtProtoKit = DrainEngine(kind: .mtProtoKit)
        let switching = SwitchingNetworkEngine(engine: rust)
        let session = switching.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: nil)
        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 5.0, makeEngine: { mtProtoKit }))
        let old = rust.sessions[0]
        session.stop()
        XCTAssertTrue(old.stopped)
        let late = drainRequest("late")
        let _ = old.release(late)
        XCTAssertTrue(mtProtoKit.sessions[0].service.requests.isEmpty)
    }

    func testTheActivityOfTheCurrentSessionIsReported() {
        let rust = DrainEngine(kind: .rust)
        rust.sessionActivity = NetworkEngineServerActivity(silentFor: 3.0, waitingFor: nil, connected: true)
        let switching = SwitchingNetworkEngine(engine: rust)
        let session = switching.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: nil)
        defer { session.stop() }
        var reported: NetworkEngineServerActivity?
        session.serverActivity { reported = $0 }
        XCTAssertEqual(reported, NetworkEngineServerActivity(silentFor: 3.0, waitingFor: nil, connected: true))
    }

    func testTheReleaseRule() {
        var asked = 0
        let allow: () -> Bool = {
            asked += 1
            return true
        }
        XCTAssertEqual(networkEngineReleaseDecision(mayHaveRun: false, retryAfter: 12.5, allowsServerError: allow), .move(after: 12.5))
        XCTAssertEqual(networkEngineReleaseDecision(mayHaveRun: false, retryAfter: -3.0, allowsServerError: allow), .move(after: 0.0))
        XCTAssertEqual(networkEngineReleaseDecision(mayHaveRun: false, retryAfter: .nan, allowsServerError: allow), .move(after: 0.0))
        XCTAssertEqual(asked, 0, "a request that never ran moves without asking its policy")
        XCTAssertEqual(networkEngineReleaseDecision(mayHaveRun: true, retryAfter: 30.0, allowsServerError: allow), .move(after: 0.0))
        XCTAssertEqual(asked, 1)
        XCTAssertEqual(networkEngineReleaseDecision(mayHaveRun: true, retryAfter: 0.0, allowsServerError: { false }), .fail)
        XCTAssertEqual(networkEngineSwitchedError.errorCode, 500)
        XCTAssertEqual(networkEngineSwitchedError.errorDescription, "ENGINE_SWITCHED")
    }

    func testAMoveAfterAWaitCanBeCancelledBeforeItHappens() {
        let target = DrainRequestService()
        let now = drainRequest("now")
        let _ = networkEngineMove(now, to: target, after: 0.0)
        XCTAssertTrue(target.requests.first === now)

        let later = drainRequest("later")
        let cancelled = drainRequest("cancelled")
        let _ = networkEngineMove(later, to: target, after: 0.2)
        let disposable = networkEngineMove(cancelled, to: target, after: 0.2)
        XCTAssertEqual(target.requests.count, 1, "nothing before the wait ends")
        disposable.dispose()
        let done = self.expectation(description: "the wait ended")
        Queue.concurrentDefaultQueue().after(0.5, {
            done.fulfill()
        })
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(target.requests.count, 2)
        XCTAssertTrue(target.requests.last === later)
        XCTAssertFalse(target.requests.contains(where: { $0 === cancelled }), "cancelled during its wait, it never arrives")
    }
}
