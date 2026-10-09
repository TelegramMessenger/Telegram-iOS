import Foundation
import ObjectiveC
import SwiftSignalKit
import MtProtoKit
import MTProtoRustEngineMapping

/// Seconds on a clock that never steps (`CLOCK_MONOTONIC_RAW`, ≈ 7 ns to read, as `CLOCK_UPTIME_RAW`):
/// what the logout evidence is timed with, so a wall clock set forward or back cannot move an answer in or
/// out of a window. It counts time asleep, so a day-long immunity also ends while the Mac sleeps, as
/// tdlib's (`steady_clock`) does.
func rustEngineMonotonicNow() -> Double {
    return Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000.0
}

/// The engine reported the home datacenter's permanent key unknown (`PermanentKeyInvalid`). Decided on
/// MTContext's queue: only while an engine's actions run the context's key actions (the registry names
/// them and the factories set on that queue are theirs) is the report noted and `start` (MTContext's
/// `checkIfLoggedOut`) called, in the same block, so the check reads that engine's factory, never
/// MtProtoKit's, whose probe would decide on one refused bind, nor one deactivated before the gate
/// decided (an engine deactivated on another thread while the block runs makes an action that ends at
/// once, without a verdict). Otherwise refused binds are no verdict and nothing starts.
func rustEngineStartLogoutCheck(context: MTContext, registry: RustContextRegistry, datacenterId: Int, keyId: Int64, reportedAt: Double, logPrefix: String, start: @escaping (MTContext, Int) -> Void = { context, datacenterId in
    context.checkIfLoggedOut(datacenterId)
}) {
    MTContext.contextQueue().dispatch(onQueue: {
        if registry.activeActionsOwnTheFactories() && context.authActionFactory != nil {
            registry.noteReportedUnknown(datacenterId: datacenterId, keyId: keyId, at: reportedAt)
            start(context, datacenterId)
        } else {
            rustEngineImportantLog("\(logPrefix) permanent key \(keyId) reported unknown on the home datacenter while the engine's actions do not run the key actions: refused binds are no verdict, binding again")
        }
    }, synchronous: false)
}

private final class RustWeakSession {
    weak var value: RustNetworkSession?

    init(_ value: RustNetworkSession) {
        self.value = value
    }
}

/// What the bridge knows about one MTContext across its sessions: the main session (an authorization is
/// exported through it), and the evidence about each datacenter's permanent key that the logout check
/// weighs (`rustEnginePermanentKeyUnknownDenial`). Kept on the context itself, so every engine of the
/// context (a live switch makes a new one) sees the same state. Times are `rustEngineMonotonicNow()`.
final class RustContextRegistry {
    private static var associationKey: UInt8 = 0
    private static let creationLock = RustEngineLock()
    /// Permanent keys per datacenter whose last sign of being known is remembered.
    private static let knownKeysKept = 8

    static func of(_ context: MTContext) -> RustContextRegistry {
        RustContextRegistry.creationLock.lock()
        defer {
            RustContextRegistry.creationLock.unlock()
        }
        if let existing = objc_getAssociatedObject(context, &RustContextRegistry.associationKey) as? RustContextRegistry {
            return existing
        }
        let registry = RustContextRegistry()
        objc_setAssociatedObject(context, &RustContextRegistry.associationKey, registry, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return registry
    }

    private struct KeyEvent {
        var keyId: Int64
        var at: Double
    }

    private struct RefusalEpisode {
        var keyId: Int64
        var firstAt: Double
        var lastAt: Double
    }

    private let lock = RustEngineLock()
    private var sessions: [RustWeakSession] = []
    private var reports: [Int: KeyEvent] = [:]
    private var refusals: [Int: RefusalEpisode] = [:]
    private var known: [Int: [Int64: Double]] = [:]
    private weak var activeEngine: RustEngineActions?
    /// The actions whose factories MTContext has; written only on MTContext's queue, with the factories.
    private weak var factoryOwner: RustEngineActions?

    private init() {
    }

    // MARK: Sessions

    func register(_ session: RustNetworkSession) {
        self.lock.lock()
        self.sessions.removeAll(where: { $0.value == nil })
        self.sessions.append(RustWeakSession(session))
        self.lock.unlock()
    }

    func unregister(_ session: RustNetworkSession) {
        self.lock.lock()
        self.sessions.removeAll(where: { $0.value == nil || $0.value === session })
        self.lock.unlock()
    }

    /// The server answered a call under `keyId` (or a temporary key bound to it) at `at`, as seen by a session
    /// that stopped since, or by the logout check's own call: the evidence outlives the session.
    func noteAnswered(datacenterId: Int, keyId: Int64, at: Double) {
        self.lock.lock()
        self.noteKnownLocked(datacenterId: datacenterId, keyId: keyId, at: at)
        self.lock.unlock()
    }

    /// One slot per key, the latest sign that the server knows it.
    private func noteKnownLocked(datacenterId: Int, keyId: Int64, at: Double) {
        var keys = self.known[datacenterId] ?? [:]
        if (keys[keyId] ?? -Double.infinity) < at {
            keys[keyId] = at
        }
        if keys.count > RustContextRegistry.knownKeysKept, let oldest = keys.min(by: { $0.value < $1.value })?.key {
            keys.removeValue(forKey: oldest)
        }
        self.known[datacenterId] = keys
    }

    private func liveSessions() -> [RustNetworkSession] {
        self.lock.lock()
        self.sessions.removeAll(where: { $0.value == nil })
        let sessions = self.sessions.compactMap(\.value)
        self.lock.unlock()
        return sessions
    }

    /// The session an authorization is exported through: a running main session of this datacenter.
    func mainSession(datacenterId: Int) -> RustNetworkSession? {
        return self.liveSessions().first(where: { $0.servesExports && $0.datacenterId == datacenterId })
    }

    // MARK: Installed actions

    /// Whether the registry names any engine's actions. The logout check's gate uses
    /// `activeActionsOwnTheFactories`, which also needs MTContext to have their factories.
    func hasActiveActions() -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.activeEngine != nil
    }

    /// On MTContext's queue, right after `actions` set the context's factories, or nil after they were
    /// cleared.
    func noteFactories(of actions: RustEngineActions?) {
        self.lock.lock()
        self.factoryOwner = actions
        self.lock.unlock()
    }

    /// Whether the actions the registry names are the ones whose factories MTContext has; on MTContext's
    /// queue, where the factories are written.
    func activeActionsOwnTheFactories() -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.activeEngine != nil && self.activeEngine === self.factoryOwner
    }

    func isActive(_ actions: RustEngineActions) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.activeEngine === actions
    }

    /// The engine whose key and transfer actions the context runs; nil while none is (MtProtoKit's own).
    func setActiveActions(_ actions: RustEngineActions?, replacing previous: RustEngineActions?) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let previous = previous, self.activeEngine !== previous {
            return false
        }
        self.activeEngine = actions
        return true
    }

    // MARK: Permanent key evidence

    /// A fresh temporary key was refused with `ENCRYPTED_MESSAGE_INVALID` under `keyId`: it continues the
    /// key's episode of refusals, or starts one.
    func noteRefusedBind(datacenterId: Int, keyId: Int64, at: Double) {
        self.lock.lock()
        if var episode = self.refusals[datacenterId], episode.keyId == keyId, rustEngineRefusalContinuesEpisode(lastRefusalAt: episode.lastAt, at: at) {
            episode.lastAt = at
            self.refusals[datacenterId] = episode
        } else {
            self.refusals[datacenterId] = RefusalEpisode(keyId: keyId, firstAt: at, lastAt: at)
        }
        self.lock.unlock()
    }

    /// A temporary key was bound to `keyId`: the server knows it, so its refusals and any report about it
    /// are over.
    func noteBound(datacenterId: Int, keyId: Int64, at: Double) {
        self.lock.lock()
        self.noteKnownLocked(datacenterId: datacenterId, keyId: keyId, at: at)
        if self.refusals[datacenterId]?.keyId == keyId {
            self.refusals.removeValue(forKey: datacenterId)
        }
        if self.reports[datacenterId]?.keyId == keyId {
            self.reports.removeValue(forKey: datacenterId)
        }
        self.lock.unlock()
    }

    /// The engine reported `keyId` unknown to the server (`PermanentKeyInvalid`) past the bridge's own
    /// immunity, and the logout check is about to run.
    func noteReportedUnknown(datacenterId: Int, keyId: Int64, at: Double) {
        self.lock.lock()
        self.reports[datacenterId] = KeyEvent(keyId: keyId, at: at)
        self.lock.unlock()
    }

    /// A key probe was refused for `keyId`: decides, on `queue`, whether that confirms the key is unknown,
    /// once the observation window since the key's first refusal is over. `completion` gets nil when it
    /// does, otherwise why not.
    func confirmUnknown(datacenterId: Int, keyId: Int64, queue: Queue, completion: @escaping (String?) -> Void) {
        self.lock.lock()
        let firstRefusalAt = self.refusals[datacenterId].flatMap { $0.keyId == keyId ? $0.firstAt : nil }
        self.lock.unlock()
        let delay = rustEnginePermanentKeyDecisionDelay(firstRefusalAt: firstRefusalAt, now: rustEngineMonotonicNow())
        if delay > 0.0 {
            queue.after(delay, { [weak self] in
                self?.decideUnknown(datacenterId: datacenterId, keyId: keyId, queue: queue, completion: completion)
            })
        } else {
            self.decideUnknown(datacenterId: datacenterId, keyId: keyId, queue: queue, completion: completion)
        }
    }

    private func decideUnknown(datacenterId: Int, keyId: Int64, queue: Queue, completion: @escaping (String?) -> Void) {
        self.lock.lock()
        let firstRefusalAt = self.refusals[datacenterId].flatMap { $0.keyId == keyId ? $0.firstAt : nil }
        self.lock.unlock()

        let sessions = self.liveSessions().filter { $0.datacenterId == datacenterId }
        let remaining = Atomic<Int>(value: sessions.count)
        let lastCompletedAt = Atomic<Double?>(value: nil)
        let decide: () -> Void = { [weak self] in
            guard let self = self else {
                return
            }
            self.lock.lock()
            let report = self.reports[datacenterId]
            let currentFirstRefusalAt = self.refusals[datacenterId].flatMap { $0.keyId == keyId ? $0.firstAt : nil }
            let knownAt = self.known[datacenterId]?[keyId]
            self.lock.unlock()
            let lastKnownAt = [knownAt, lastCompletedAt.with { $0 }].compactMap { $0 }.max()
            let evidence = RustEnginePermanentKeyEvidence(reportedKeyId: report?.keyId, reportedAt: report?.at, firstRefusalAt: currentFirstRefusalAt == firstRefusalAt ? currentFirstRefusalAt : nil, lastKnownAt: lastKnownAt)
            let denial = rustEnginePermanentKeyUnknownDenial(evidence, probedKeyId: keyId, now: rustEngineMonotonicNow())
            queue.async {
                completion(denial)
            }
        }
        if sessions.isEmpty {
            decide()
            return
        }
        for session in sessions {
            session.lastCompletion { completed in
                if let completed = completed, completed.keyId == keyId {
                    let _ = lastCompletedAt.modify { current in
                        return max(current ?? completed.at, completed.at)
                    }
                }
                if remaining.modify({ $0 - 1 }) == 0 {
                    decide()
                }
            }
        }
    }
}
