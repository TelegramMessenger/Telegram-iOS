import Foundation
import SwiftSignalKit
import MtProtoKit

private final class SwitchingLock {
    private let pointer: UnsafeMutablePointer<os_unfair_lock>

    init() {
        self.pointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self.pointer.initialize(to: os_unfair_lock())
    }

    deinit {
        self.pointer.deinitialize(count: 1)
        self.pointer.deallocate()
    }

    @inline(__always)
    func lock() {
        os_unfair_lock_lock(self.pointer)
    }

    @inline(__always)
    func unlock() {
        os_unfair_lock_unlock(self.pointer)
    }
}

private final class SwitchingDelegateBox {
    weak var delegate: NetworkEngineSessionDelegate?
    private let lock = SwitchingLock()
    private let generation: UnsafeMutablePointer<Int>

    init(delegate: NetworkEngineSessionDelegate?) {
        self.delegate = delegate
        self.generation = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        self.generation.initialize(to: 0)
    }

    deinit {
        self.generation.deinitialize(count: 1)
        self.generation.deallocate()
    }

    func setGeneration(_ value: Int) {
        self.lock.lock()
        self.generation.pointee = value
        self.lock.unlock()
    }

    func isCurrent(_ value: Int) -> Bool {
        self.lock.lock()
        let current = self.generation.pointee
        self.lock.unlock()
        return current == value
    }
}

private final class SwitchingSessionDelegate: NetworkEngineSessionDelegate {
    private let box: SwitchingDelegateBox
    private let generation: Int

    init(box: SwitchingDelegateBox, generation: Int) {
        self.box = box
        self.generation = generation
    }

    func networkSessionAuthorizationRequired() {
        if self.box.isCurrent(self.generation) {
            self.box.delegate?.networkSessionAuthorizationRequired()
        }
    }

    func networkSessionSoftAuthReset() {
        if self.box.isCurrent(self.generation) {
            self.box.delegate?.networkSessionSoftAuthReset()
        }
    }

    func networkSessionConnectionStateChanged(_ state: NetworkEngineConnectionState) {
        if self.box.isCurrent(self.generation) {
            self.box.delegate?.networkSessionConnectionStateChanged(state)
        }
    }
}

private struct SwitchingState {
    var current: NetworkEngineSession?
    var currentService: NetworkEngineRequestService?
    var currentDelegate: SwitchingSessionDelegate?
    var generation = 0
    var draining: [Int: NetworkEngineSession] = [:]
    var isPaused = true
    var isOnline = false
    var isStopped = false
    var sinks: [NetworkEngineUpdateSink] = []
    var dropObservers: [(NetworkEngineConnectionDrop) -> Void] = []
}

private final class SwitchingCore {
    let datacenterId: Int
    private let role: NetworkEngineSessionRole
    private let usageCalculationInfo: MTNetworkUsageCalculationInfo?
    private let delegateBox: SwitchingDelegateBox?
    private let lock = SwitchingLock()
    private let state: UnsafeMutablePointer<SwitchingState>

    init(engine: NetworkEngine, datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) {
        self.datacenterId = datacenterId
        self.role = role
        self.usageCalculationInfo = usageCalculationInfo
        self.delegateBox = delegate.map { SwitchingDelegateBox(delegate: $0) }
        self.state = UnsafeMutablePointer<SwitchingState>.allocate(capacity: 1)
        self.state.initialize(to: SwitchingState())
        let sessionDelegate = self.delegateBox.map { SwitchingSessionDelegate(box: $0, generation: 0) }
        let session = engine.makeSession(datacenterId: datacenterId, role: role, usageCalculationInfo: usageCalculationInfo, delegate: sessionDelegate)
        self.state.pointee.current = session
        self.state.pointee.currentService = session.requestService
        self.state.pointee.currentDelegate = sessionDelegate
    }

    deinit {
        self.state.deinitialize(count: 1)
        self.state.deallocate()
    }

    func add(_ request: NetworkEngineRequest) -> Disposable {
        self.lock.lock()
        let service = self.state.pointee.isStopped ? nil : self.state.pointee.currentService
        self.lock.unlock()
        guard let service = service else {
            return EmptyDisposable
        }
        return service.add(request)
    }

    func switchEngine(to engine: NetworkEngine, drainTimeout: Double) {
        self.lock.lock()
        if self.state.pointee.isStopped {
            self.lock.unlock()
            return
        }
        let generation = self.state.pointee.generation + 1
        self.lock.unlock()

        let sessionDelegate = self.delegateBox.map { SwitchingSessionDelegate(box: $0, generation: generation) }
        let replacement = engine.makeSession(datacenterId: self.datacenterId, role: self.role, usageCalculationInfo: self.usageCalculationInfo, delegate: sessionDelegate)

        self.lock.lock()
        guard !self.state.pointee.isStopped, self.state.pointee.generation + 1 == generation, let previous = self.state.pointee.current else {
            self.lock.unlock()
            replacement.stop()
            return
        }
        let previousGeneration = generation - 1
        self.state.pointee.generation = generation
        self.state.pointee.current = replacement
        self.state.pointee.currentService = replacement.requestService
        self.state.pointee.currentDelegate = sessionDelegate
        self.state.pointee.draining[previousGeneration] = previous
        let sinks = self.state.pointee.sinks
        let dropObservers = self.state.pointee.dropObservers
        let isPaused = self.state.pointee.isPaused
        let isOnline = self.state.pointee.isOnline
        self.lock.unlock()

        self.delegateBox?.setGeneration(generation)
        for sink in sinks {
            replacement.addUpdateSink(sink)
        }
        for observer in dropObservers {
            replacement.observeConnectionDrops(observer)
        }
        replacement.setPaused(isPaused)
        replacement.setOnline(isOnline)

        Queue.concurrentDefaultQueue().after(max(drainTimeout, 0.0), { [core = self] in
            core.finishDraining(generation: previousGeneration)
        })
    }

    private func finishDraining(generation drainedGeneration: Int) {
        self.lock.lock()
        guard let session = self.state.pointee.draining.removeValue(forKey: drainedGeneration) else {
            self.lock.unlock()
            return
        }
        let target = self.state.pointee.isStopped ? nil : self.state.pointee.currentService
        let sinks = self.state.pointee.sinks
        self.lock.unlock()

        guard let target = target else {
            session.stop()
            return
        }
        session.movePendingRequests(to: target, completion: {
            session.stop()
            for sink in sinks {
                sink.networkSessionDidReset()
            }
        })
    }

    func movePendingRequests(to service: NetworkEngineRequestService, completion: @escaping () -> Void) {
        self.lock.lock()
        let sessions = (self.state.pointee.current.map { [$0] } ?? []) + Array(self.state.pointee.draining.values)
        self.lock.unlock()
        if sessions.isEmpty {
            completion()
            return
        }
        let remaining = Atomic<Int>(value: sessions.count)
        for session in sessions {
            session.movePendingRequests(to: service, completion: {
                if remaining.modify({ $0 - 1 }) == 0 {
                    completion()
                }
            })
        }
    }

    func setPaused(_ paused: Bool) {
        self.lock.lock()
        if self.state.pointee.isStopped {
            self.lock.unlock()
            return
        }
        self.state.pointee.isPaused = paused
        let sessions = (self.state.pointee.current.map { [$0] } ?? []) + Array(self.state.pointee.draining.values)
        self.lock.unlock()
        for session in sessions {
            session.setPaused(paused)
        }
    }

    func setOnline(_ online: Bool) {
        self.lock.lock()
        if self.state.pointee.isStopped {
            self.lock.unlock()
            return
        }
        self.state.pointee.isOnline = online
        let sessions = (self.state.pointee.current.map { [$0] } ?? []) + Array(self.state.pointee.draining.values)
        self.lock.unlock()
        for session in sessions {
            session.setOnline(online)
        }
    }

    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
        self.lock.lock()
        self.state.pointee.sinks.append(sink)
        let session = self.state.pointee.current
        self.lock.unlock()
        session?.addUpdateSink(sink)
    }

    func observeConnectionDrops(_ observer: @escaping (NetworkEngineConnectionDrop) -> Void) {
        self.lock.lock()
        self.state.pointee.dropObservers.append(observer)
        let session = self.state.pointee.current
        self.lock.unlock()
        session?.observeConnectionDrops(observer)
    }

    func stop() {
        self.lock.lock()
        if self.state.pointee.isStopped {
            self.lock.unlock()
            return
        }
        self.state.pointee.isStopped = true
        let sessions = (self.state.pointee.current.map { [$0] } ?? []) + Array(self.state.pointee.draining.values)
        self.state.pointee.current = nil
        self.state.pointee.currentService = nil
        self.state.pointee.currentDelegate = nil
        self.state.pointee.draining.removeAll()
        self.state.pointee.sinks.removeAll()
        self.state.pointee.dropObservers.removeAll()
        self.lock.unlock()
        for session in sessions {
            session.stop()
        }
    }
}

private final class SwitchingRequestService: NetworkEngineRequestService {
    private let core: SwitchingCore

    init(core: SwitchingCore) {
        self.core = core
    }

    func add(_ request: NetworkEngineRequest) -> Disposable {
        return self.core.add(request)
    }
}

final class SwitchingNetworkSession: NetworkEngineSession {
    let datacenterId: Int
    let requestService: NetworkEngineRequestService
    private let core: SwitchingCore

    init(engine: NetworkEngine, datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) {
        self.datacenterId = datacenterId
        self.core = SwitchingCore(engine: engine, datacenterId: datacenterId, role: role, usageCalculationInfo: usageCalculationInfo, delegate: delegate)
        self.requestService = SwitchingRequestService(core: self.core)
    }

    deinit {
        self.core.stop()
    }

    func switchEngine(to engine: NetworkEngine, drainTimeout: Double) {
        self.core.switchEngine(to: engine, drainTimeout: drainTimeout)
    }

    func setPaused(_ paused: Bool) {
        self.core.setPaused(paused)
    }

    func setOnline(_ online: Bool) {
        self.core.setOnline(online)
    }

    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
        self.core.addUpdateSink(sink)
    }

    func observeConnectionDrops(_ observer: @escaping (NetworkEngineConnectionDrop) -> Void) {
        self.core.observeConnectionDrops(observer)
    }

    func stop() {
        self.core.stop()
    }

    func movePendingRequests(to service: NetworkEngineRequestService, completion: @escaping () -> Void) {
        self.core.movePendingRequests(to: service, completion: completion)
    }
}

private final class WeakSwitchingSession {
    weak var value: SwitchingNetworkSession?

    init(_ value: SwitchingNetworkSession) {
        self.value = value
    }
}

final class SwitchingNetworkEngine: NetworkEngine {
    private let lock = SwitchingLock()
    private let switchLock = NSLock()
    private var engine: NetworkEngine
    private var sessions: [WeakSwitchingSession] = []

    var kind: NetworkEngineKind {
        self.lock.lock()
        let kind = self.engine.kind
        self.lock.unlock()
        return kind
    }

    init(engine: NetworkEngine) {
        self.engine = engine
    }

    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
        self.lock.lock()
        let engine = self.engine
        self.lock.unlock()

        let session = SwitchingNetworkSession(engine: engine, datacenterId: datacenterId, role: role, usageCalculationInfo: usageCalculationInfo, delegate: delegate)

        self.lock.lock()
        self.sessions.removeAll(where: { $0.value == nil })
        self.sessions.append(WeakSwitchingSession(session))
        let latest = self.engine
        self.lock.unlock()

        if latest !== engine {
            session.switchEngine(to: latest, drainTimeout: 0.0)
        }
        return session
    }

    func switchEngine(to kind: NetworkEngineKind, drainTimeout: Double, makeEngine: () -> NetworkEngine?) -> Bool {
        self.switchLock.lock()
        defer {
            self.switchLock.unlock()
        }
        if self.kind == kind {
            return true
        }
        guard let engine = makeEngine() else {
            return false
        }
        self.lock.lock()
        self.engine = engine
        self.sessions.removeAll(where: { $0.value == nil })
        let sessions = self.sessions.compactMap(\.value)
        self.lock.unlock()
        for session in sessions {
            session.switchEngine(to: engine, drainTimeout: drainTimeout)
        }
        return true
    }
}
