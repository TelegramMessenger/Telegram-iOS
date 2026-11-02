import Foundation
import XCTest
import SwiftSignalKit
import MtProtoKit
@testable import TelegramApi
@testable import TelegramCore

/// What `ScriptedServer` does with one request.
enum ScriptedAnswer {
    /// Succeeds with `value`, which must be exactly the function's result type: `Api.updates.Difference`
    /// for `updates.getDifference`, `Api.updates.State` for `updates.getState`, `Api.Bool` for
    /// `help.test`, `[Api.User]` for `users.getUsers`. It reaches `Network` as `BoxedMessage(value)`,
    /// which is what `request.parse` returns and what both engines hand over as the response.
    /// A value of another type completes the request with `500 TL_VERIFICATION_ERROR` in
    /// `Network.request`, which `retryRequest` retries.
    case result(Any)
    /// Fails with this `rpc_error`, as an engine reports it once the request's own error policy
    /// (`shouldContinueAfterError`) stopped waiting. Flood waits are not emulated.
    case error(code: Int32, text: String)
    /// Stays pending until `release(_:with:)` answers it or its subscriber disposes it.
    case hold
}

/// One request, as `Network` handed it to the engine.
struct ScriptedRequest {
    /// Position in the server's log, from 0.
    let index: Int
    /// The API method: `FunctionDescription.name`, for example `"updates.getDifference"`.
    let name: String
    /// The boxed function exactly as `Network` serialized it (`data.1.makeData()`), without the
    /// `invokeWithLayer`/`initConnection` wrapper an engine adds. Compare it with
    /// `Api.functions.….1.makeData()` to check every argument.
    let payload: Data
    let metadata: WrappedRequestMetadata

    /// The logger's rendering with arguments (`updates.getDifference(flags: 0, pts: 10, …)`). Redacts
    /// what `Serialization.swift` lists while `Logger.shared.redactSensitiveData` is set.
    var arguments: String {
        return self.metadata.description
    }
}

/// A fake engine whose one main session is the server: it records every request in order, answers
/// from a per-test script and pushes updates through the real `NetworkEngineUpdateSink`.
///
/// Threading follows the real engines. MtProtoKit completes requests and calls its sinks on MTProto's
/// serial queue; the Rust engine on its session queue (`org.telegram.MTProtoRust.session`). Neither
/// ever completes a request inside `add`, and `Network.request` does not hop: it calls
/// `subscriber.putNext` on whatever thread `completed` runs, and callers `deliverOn` themselves. So
/// every completion and every sink call here leaves on `engineQueue`, in the order it was scheduled,
/// always through a real dispatch (`justDispatch`, never `Queue.async`, which runs inline on the
/// target queue).
final class ScriptedServer: NetworkEngine, NetworkEngineSession, NetworkEngineRequestService {
    typealias Handler = (NetworkEngineRequest) -> ScriptedAnswer

    private final class Entry {
        let request: NetworkEngineRequest
        let index: Int
        let name: String
        /// On `engineQueue`: disposed by its caller, so a delayed answer is not delivered.
        var cancelled = false

        init(request: NetworkEngineRequest, index: Int, name: String) {
            self.request = request
            self.index = index
            self.name = name
        }
    }

    private final class WorkerSession: NetworkEngineSession, NetworkEngineRequestService {
        let datacenterId: Int
        private weak var server: ScriptedServer?

        init(datacenterId: Int, server: ScriptedServer) {
            self.datacenterId = datacenterId
            self.server = server
        }

        var requestService: NetworkEngineRequestService {
            return self
        }

        func setPaused(_ paused: Bool) {
        }

        func setOnline(_ online: Bool) {
        }

        func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
        }

        func stop() {
        }

        func movePendingRequests(to service: NetworkEngineRequestService, deadline: Double, completion: @escaping () -> Void) {
            completion()
        }

        /// Recorded; answered only when `ScriptedServer.onWorker` scripted an answer for its name. State
        /// sync uses a download session only for a preload history fill (`.download` source).
        func add(_ request: NetworkEngineRequest) -> Disposable {
            guard let server = self.server else {
                return ActionDisposable {
                }
            }
            return server.addWorkerRequest(request, datacenterId: self.datacenterId)
        }
    }

    let kind: NetworkEngineKind = .mtProtoKit
    let datacenterId: Int
    let engineQueue = Queue(name: "ScriptedServer.engine")

    /// A delay before each answer and push is delivered, in seconds, by the request's name (\"push\" for a push); nil
    /// or 0: none. An answer is still produced when its request arrives, as a server produces it, and delivered after
    /// the delay, so a push can land while a request is in flight and answers can overtake each other. `flush()` waits
    /// for every scheduled delivery. Set it before the first request.
    var deliveryDelay: ((String) -> Double)?

    // Guarded by `condition`.
    private let condition = NSCondition()
    private var log: [ScriptedRequest] = []
    private var oneShotHandlers: [String: [Handler]] = [:]
    private var persistentHandlers: [String: Handler] = [:]
    private var earlyAnswerBarriers: [String: [() -> Void]] = [:]
    private var unscriptedIndices: [Int] = []
    private var cancelledIndices: [Int] = []
    private var workerLog: [(datacenterId: Int, name: String)] = []
    private var workerPayloadLog: [Data] = []
    private var workerOneShotAnswers: [String: [ScriptedAnswer]] = [:]
    private var sinks: [NetworkEngineUpdateSink] = []
    private var droppedPushCount = 0
    /// Answers and pushes waiting out `deliveryDelay`.
    private var scheduledDeliveries = 0
    private var pausedValue: Bool?
    private var onlineValue: Bool?
    private weak var delegate: NetworkEngineSessionDelegate?

    // Owned by `engineQueue`.
    private var held: [Entry] = []

    init(datacenterId: Int = 2) {
        self.datacenterId = datacenterId
    }

    // MARK: - Script

    /// Answers the next request named `name` that no earlier `on` registration answered. Registrations
    /// for one name are used in order and each answers one request, so "fail once, then succeed" is two
    /// calls. `retryRequest` re-sends a failed `getDifference`/`getState` after 0.2 s and more, and
    /// that retry is a new request here.
    func on(_ name: String, _ answer: @escaping Handler) {
        self.condition.lock()
        self.oneShotHandlers[name, default: []].append(answer)
        self.condition.unlock()
    }

    func on(_ name: String, _ answer: ScriptedAnswer) {
        self.on(name, { _ in answer })
    }

    /// Answers every request named `name` that no `on` registration is left for.
    func always(_ name: String, _ answer: @escaping Handler) {
        self.condition.lock()
        self.persistentHandlers[name] = answer
        self.condition.unlock()
    }

    /// Makes the next request named `name` complete before its `add` returns: `add` blocks the thread
    /// that sent the request until `engineQueue` has run `barrier` and then handed the request its
    /// scripted answer (a `.hold` answer is only registered, nothing completes), together with everything
    /// that answer runs synchronously. The wait is bounded (5 s); on a timeout the test fails, naming the
    /// request, and the sender continues. Must not be used for a request sent from `Postbox.sharedQueue`
    /// or from `engineQueue` (the barrier needs both). No real engine answers
    /// that fast. It forces the one interleaving in which an answer arrives before the requesting queue
    /// has run the blocks already queued behind the one that sent the request. `barrier` runs first, on
    /// `engineQueue`; `{ Postbox.sharedQueue.sync {} }` lets a transaction that is still dispatching to
    /// the requesting queue finish doing so. One-shot per name, like `on`. A request sent from
    /// `engineQueue` itself is answered in order but cannot be waited for.
    func answerBeforeCallerContinues(_ name: String, after barrier: @escaping () -> Void) {
        self.condition.lock()
        self.earlyAnswerBarriers[name, default: []].append(barrier)
        self.condition.unlock()
    }

    /// Answers the next request named `name` sent on a worker (download or upload) session, which is
    /// otherwise recorded and never answered. One-shot per name, used in order, like `on`; the answer is
    /// delivered on `engineQueue` like a main-session answer. `.hold` is not supported: such a request is
    /// never answered, as an unscripted one.
    func onWorker(_ name: String, _ answer: ScriptedAnswer) {
        self.condition.lock()
        self.workerOneShotAnswers[name, default: []].append(answer)
        self.condition.unlock()
    }

    // MARK: - Observation

    var requests: [ScriptedRequest] {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.log
    }

    var requestNames: [String] {
        return self.requests.map { $0.name }
    }

    /// Requests that arrived with no answer scripted; they are held, so a test sees them here instead
    /// of in a retry loop.
    var unscripted: [ScriptedRequest] {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.unscriptedIndices.map { self.log[$0] }
    }

    /// Indices of requests whose subscriber disposed them while they were held.
    var cancelled: [Int] {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.cancelledIndices
    }

    var workerRequests: [(datacenterId: Int, name: String)] {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.workerLog
    }

    /// The payloads of `workerRequests`, in the same order.
    var workerRequestPayloads: [Data] {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.workerPayloadLog
    }

    var droppedPushes: Int {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.droppedPushCount
    }

    var isPaused: Bool? {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.pausedValue
    }

    /// Names of the requests held right now, oldest first. Waits for what `engineQueue` already has.
    var heldNames: [String] {
        var result: [String] = []
        self.engineQueue.sync {
            result = self.held.map { $0.name }
        }
        return result
    }

    /// Blocks until `count` requests named `name` have arrived, or `timeout` passes.
    @discardableResult
    func waitForRequest(_ name: String, count: Int = 1, timeout: Double = 5.0) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        while self.log.filter({ $0.name == name }).count < count {
            if !self.condition.wait(until: deadline) {
                return self.log.filter({ $0.name == name }).count >= count
            }
        }
        return true
    }

    /// Blocks until a sink is registered (`AccountStateManager.reset()` does it on its queue).
    @discardableResult
    func waitForUpdateSink(timeout: Double = 5.0) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        while self.sinks.isEmpty {
            if !self.condition.wait(until: deadline) {
                return !self.sinks.isEmpty
            }
        }
        return true
    }

    /// Returns once everything already scheduled on `engineQueue` (answers, pushes), and every delivery waiting out
    /// `deliveryDelay` (at most 10 s), has been handed to `Network` and the sinks. What the receivers then dispatch
    /// elsewhere is not waited for.
    func flush() {
        // A request logged a moment ago may not have scheduled its delayed answer yet: that happens on `engineQueue`.
        self.engineQueue.sync {
        }
        self.condition.lock()
        let deadline = Date().addingTimeInterval(10.0)
        while self.scheduledDeliveries > 0 && Date() < deadline {
            let _ = self.condition.wait(until: deadline)
        }
        self.condition.unlock()
        self.engineQueue.sync {
        }
    }

    /// For `tearDown`: forgets every held request without answering it. A held request keeps its
    /// subscriber chain alive, and with it the `Network`, the `MTContext` and whatever Postbox the
    /// chain captured.
    func dropHeld() {
        self.engineQueue.sync {
            self.held.removeAll()
        }
    }

    // MARK: - Control

    /// Answers the oldest held request named `name`. False when none is held.
    @discardableResult
    func release(_ name: String, with answer: ScriptedAnswer) -> Bool {
        var found = false
        self.engineQueue.sync {
            guard let index = self.held.firstIndex(where: { $0.name == name }) else {
                return
            }
            let entry = self.held.remove(at: index)
            found = true
            self.deliver(answer, to: entry)
        }
        return found
    }

    /// Pushes `updates` as a server message on the main session, after every answer scheduled so far.
    func push(_ updates: Api.Updates) {
        let message = BoxedMessage(updates)
        self.engineQueue.justDispatch {
            self.afterDeliveryDelay(name: "push") {
                self.deliverPush(message)
            }
        }
    }

    /// On `engineQueue`.
    private func deliverPush(_ message: BoxedMessage) {
        let sinks = self.currentSinks()
        if sinks.isEmpty {
            self.condition.lock()
            self.droppedPushCount += 1
            self.condition.unlock()
            return
        }
        for sink in sinks {
            sink.networkSessionDidReceive(message: message)
        }
    }

    /// Pushes `updates` synchronously on the CALLER's thread, bypassing `engineQueue`. Only for a test
    /// that must land a push at an exact point of the state manager's operation queue: called from a
    /// callback that runs on the manager's queue (an event pipe), `UpdateMessageService` hands the
    /// groups to `addUpdateGroups`, whose `queue.async` then runs inline (Queue.swift:60-66), so the
    /// groups join the queue before that callback returns. Real engines never do this; use `push` for
    /// everything else.
    func pushInline(_ updates: Api.Updates) {
        let message = BoxedMessage(updates)
        let sinks = self.currentSinks()
        if sinks.isEmpty {
            self.condition.lock()
            self.droppedPushCount += 1
            self.condition.unlock()
            return
        }
        for sink in sinks {
            sink.networkSessionDidReceive(message: message)
        }
    }

    /// Forgets every registered update sink, so no push reaches the managers that registered them: an app restart
    /// in the truth server's sessions, before the relaunched manager's `reset()` registers its own.
    func dropUpdateSinks() {
        self.condition.lock()
        self.sinks.removeAll()
        self.condition.unlock()
    }

    /// The session was reset on either side (`new_session_created`): `UpdateMessageService` turns it
    /// into a `[.reset]` group.
    func pushSessionReset() {
        self.engineQueue.justDispatch {
            for sink in self.currentSinks() {
                sink.networkSessionDidReset()
            }
        }
    }

    func reportConnectionState(_ state: NetworkEngineConnectionState) {
        self.engineQueue.justDispatch {
            self.currentDelegate()?.networkSessionConnectionStateChanged(state)
        }
    }

    // MARK: - NetworkEngine

    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
        switch role {
        case .main:
            self.condition.lock()
            self.delegate = delegate
            self.condition.unlock()
            return self
        case .worker:
            return WorkerSession(datacenterId: datacenterId, server: self)
        }
    }

    // MARK: - NetworkEngineSession

    var requestService: NetworkEngineRequestService {
        return self
    }

    /// Recorded only. A real engine holds requests while paused; `Network` pauses the main session
    /// right after it is made (`shouldKeepConnection` starts false), so a test that wants a faithful
    /// app sets `network.shouldKeepConnection.set(.single(true))`.
    func setPaused(_ paused: Bool) {
        self.condition.lock()
        self.pausedValue = paused
        self.condition.unlock()
    }

    func setOnline(_ online: Bool) {
        self.condition.lock()
        self.onlineValue = online
        self.condition.unlock()
    }

    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
        self.condition.lock()
        self.sinks.append(sink)
        self.condition.broadcast()
        self.condition.unlock()
    }

    func stop() {
    }

    /// Only a live engine switch calls this (macOS `SwitchingNetworkEngine`); held requests move as
    /// if added to `service`.
    func movePendingRequests(to service: NetworkEngineRequestService, deadline: Double, completion: @escaping () -> Void) {
        self.engineQueue.justDispatch {
            let moved = self.held
            self.held.removeAll()
            for entry in moved {
                let _ = service.add(entry.request)
            }
            completion()
        }
    }

    // MARK: - NetworkEngineRequestService

    func add(_ request: NetworkEngineRequest) -> Disposable {
        let name = request.shortMetadata.functionName ?? request.shortMetadata.description
        self.condition.lock()
        let index = self.log.count
        self.log.append(ScriptedRequest(index: index, name: name, payload: request.payload, metadata: request.metadata))
        let handler: Handler?
        if var queued = self.oneShotHandlers[name], !queued.isEmpty {
            handler = queued.removeFirst()
            self.oneShotHandlers[name] = queued
        } else {
            handler = self.persistentHandlers[name]
        }
        if handler == nil {
            self.unscriptedIndices.append(index)
        }
        var earlyAnswerBarrier: (() -> Void)?
        if var barriers = self.earlyAnswerBarriers[name], !barriers.isEmpty {
            earlyAnswerBarrier = barriers.removeFirst()
            self.earlyAnswerBarriers[name] = barriers
        }
        let answered: DispatchSemaphore? = earlyAnswerBarrier != nil && !self.engineQueue.isCurrent() ? DispatchSemaphore(value: 0) : nil
        let entry = Entry(request: request, index: index, name: name)
        // Scheduled under the lock: a test that saw this request in the log and then calls
        // `release` is ordered after it on `engineQueue`.
        self.engineQueue.justDispatch {
            earlyAnswerBarrier?()
            let answer = handler?(request) ?? .hold
            if case .hold = answer {
                self.deliver(answer, to: entry)
            } else {
                self.afterDeliveryDelay(name: name) {
                    if !entry.cancelled {
                        self.deliver(answer, to: entry)
                    }
                }
            }
            answered?.signal()
        }
        self.condition.broadcast()
        self.condition.unlock()
        // Outside the lock: the answer may send further requests from `engineQueue`.
        if let answered = answered, answered.wait(timeout: .now() + 5.0) == .timedOut {
            XCTFail("answerBeforeCallerContinues: \(name) (request #\(index)) was not answered within 5 s; the sender continues")
        }

        return ActionDisposable { [weak self] in
            self?.cancel(entry)
        }
    }

    // MARK: - Private

    /// On `engineQueue`: runs `f` now, or on `engineQueue` after `deliveryDelay` for `name`, counted in
    /// `scheduledDeliveries` until it has run.
    private func afterDeliveryDelay(name: String, _ f: @escaping () -> Void) {
        let delay = self.deliveryDelay?(name) ?? 0.0
        if delay <= 0.0 {
            f()
            return
        }
        self.condition.lock()
        self.scheduledDeliveries += 1
        self.condition.unlock()
        self.engineQueue.after(delay) {
            f()
            self.condition.lock()
            self.scheduledDeliveries -= 1
            self.condition.broadcast()
            self.condition.unlock()
        }
    }

    /// On `engineQueue`.
    private func deliver(_ answer: ScriptedAnswer, to entry: Entry) {
        let info = NetworkEngineResponseInfo(timestamp: 0.0, networkType: 0, duration: 0.0)
        switch answer {
        case .hold:
            self.held.append(entry)
        case let .result(value):
            entry.request.completed(.success(NetworkEngineResponse(result: BoxedMessage(value), info: info)))
        case let .error(code, text):
            entry.request.completed(.failure(NetworkEngineRequestFailure(error: MTRpcError(errorCode: code, errorDescription: text), info: info)))
        }
    }

    /// Processed on `engineQueue`, so no completion runs after it: an answer scheduled before the
    /// cancellation may still be delivered, as with a real engine whose answer arrived first.
    private func cancel(_ entry: Entry) {
        self.engineQueue.async {
            entry.cancelled = true
            guard let index = self.held.firstIndex(where: { $0 === entry }) else {
                return
            }
            self.held.remove(at: index)
            self.condition.lock()
            self.cancelledIndices.append(entry.index)
            self.condition.unlock()
        }
    }

    /// A worker session's request: recorded, then answered on `engineQueue` from `onWorker`, or never
    /// answered when nothing (or `.hold`) is scripted for its name.
    fileprivate func addWorkerRequest(_ request: NetworkEngineRequest, datacenterId: Int) -> Disposable {
        let name = request.shortMetadata.functionName ?? request.shortMetadata.description
        self.condition.lock()
        self.workerLog.append((datacenterId: datacenterId, name: name))
        self.workerPayloadLog.append(request.payload)
        var answer: ScriptedAnswer?
        if var queued = self.workerOneShotAnswers[name], !queued.isEmpty {
            answer = queued.removeFirst()
            self.workerOneShotAnswers[name] = queued
        }
        self.condition.broadcast()
        self.condition.unlock()
        guard let scripted = answer else {
            return ActionDisposable {
            }
        }
        if case .hold = scripted {
            return ActionDisposable {
            }
        }
        let entry = Entry(request: request, index: -1, name: name)
        self.engineQueue.justDispatch {
            self.deliver(scripted, to: entry)
        }
        return ActionDisposable {
        }
    }

    private func currentSinks() -> [NetworkEngineUpdateSink] {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.sinks
    }

    private func currentDelegate() -> NetworkEngineSessionDelegate? {
        self.condition.lock()
        defer {
            self.condition.unlock()
        }
        return self.delegate
    }
}
