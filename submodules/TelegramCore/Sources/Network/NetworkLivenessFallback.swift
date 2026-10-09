import Foundation
import SwiftSignalKit
import MtProtoKit

/// The local health check of a network that runs the Rust engine (macOS, live switching only).
///
/// When the main session has heard nothing from the server for `silence` seconds while the device was
/// awake, the session was resumed, the network carried Rust and the engine said the network is
/// available, and the session has no answered connection, MtProtoKit's TCP asks
/// the same datacenter for a res_pq (`MTProxyConnectivity.probeDatacenter`, `probeTimeout`). If
/// MtProtoKit gets an answer and the engine still heard nothing, the engine is what fails: the network
/// reports it (with the engine's recent connection drops) and moves to MtProtoKit until the next launch
/// (`Network.disableRustEngine`, an exactly-once live switch). At most one probe per network the device
/// is on per `probeInterval`. No probe through a WEB proxy, which MtProtoKit's probe cannot use.
///
/// What it must never do is switch a working Rust session. Every condition errs that way:
/// - only awake time counts (sleep does not look like silence), and every reachability or pause change
///   starts the window again (wake, a VPN coming up, a network change), as do a switch to Rust and a
///   wake that changed nothing else (the session's own silence also counts the time asleep);
/// - a session on an answered connection is never judged, however long it is quiet and whatever it
///   waits for (a flood wait, a slow call): the engine itself drops a connection the server stops
///   answering (pings), and only then is the session judged;
/// - any packet from the server (an answer, an update, a pong, a bind's answer) ends the silence, and
///   so does losing an answered connection (a key rotation's reconnect of an idle session that pings
///   once a minute): the silence counts from there;
/// - a network where MtProtoKit's TCP gets no answer either (HTTP only, a captive portal, the
///   datacenter down) gives no verdict, as does a probe after which the engine heard something;
/// - MtProtoKit's answer comes from a fresh connection, while the engine may be waiting out the retry
///   backoff it built up while the network was failing (a key handshake's waits reach 60 s): the
///   verdict waits `engineRetryGrace` after the probe so that the engine gets its own next attempt.
///
/// A verdict holds for the whole launch: networks still on the engine leave it at their next check, and
/// networks made later (a sign-in, a login moved to another datacenter, another account) start on
/// MtProtoKit (`networkLivenessDisabledReason`).
public struct NetworkLivenessPolicy {
    public static let silence: Double = 45.0
    public static let probeTimeout: Double = 10.0
    public static let engineRetryGrace: Double = 90.0
    public static let probeInterval: Double = 600.0
    public static let checkInterval: Double = 5.0
    public static let dropsReported: Int = 8
}

/// Whether the session is silent in the window that began at `windowStart` (the latest time the
/// network came up, the session was resumed, the network moved to Rust or the device woke), at `now`,
/// both in awake seconds. The activity's own durations also count time asleep (the bridge's clock runs
/// through sleep), which is why a wake starts the window again.
public func networkLivenessIsSilent(_ activity: NetworkEngineServerActivity?, windowStart: Double, now: Double, silence: Double = NetworkLivenessPolicy.silence) -> Bool {
    guard let activity = activity else {
        return false
    }
    if now - windowStart < silence {
        return false
    }
    if let silentFor = activity.silentFor, silentFor < silence {
        return false
    }
    return !activity.connected
}

/// One probe per network key per `NetworkLivenessPolicy.probeInterval`, for the whole process: the
/// accounts share the device's network.
public final class NetworkLivenessProbeLimiter {
    public static let shared = NetworkLivenessProbeLimiter()

    private let lock = NSLock()
    private var lastProbes: [String: Double] = [:]

    public init() {
    }

    public func mayProbe(key: String, now: Double, interval: Double = NetworkLivenessPolicy.probeInterval) -> Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if let last = self.lastProbes[key], now - last < interval, now >= last {
            return false
        }
        self.lastProbes[key] = now
        return true
    }

    private var failedEngine = false

    /// A network of this process found the engine failing: latched until the next launch.
    public func noteEngineFailed() {
        self.lock.lock()
        self.failedEngine = true
        self.lock.unlock()
    }

    public var engineFailed: Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.failedEngine
    }
}

/// Why a network made now must not start on the engine: the local health check judged it failing earlier
/// in this launch.
public func networkLivenessDisabledReason(limiter: NetworkLivenessProbeLimiter = NetworkLivenessProbeLimiter.shared) -> String? {
    return limiter.engineFailed ? "local-health earlier in this launch" : nil
}

/// What the health check found before it moved the network off the engine.
public struct NetworkLivenessReport: Equatable {
    public var datacenterId: Int
    public var activity: NetworkEngineServerActivity
    /// The engine's latest connection drops of the main session, oldest first, with seconds before the report.
    public var drops: [(ago: Double, drop: NetworkEngineConnectionDrop)]

    public static func ==(lhs: NetworkLivenessReport, rhs: NetworkLivenessReport) -> Bool {
        return lhs.datacenterId == rhs.datacenterId && lhs.activity == rhs.activity && lhs.drops.map(\.ago) == rhs.drops.map(\.ago) && lhs.drops.map(\.drop) == rhs.drops.map(\.drop)
    }
}

func networkLivenessUptime() -> Double {
    return Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1_000_000_000.0
}

/// Seconds the device slept since boot: grows across every sleep, also one that no reachability change
/// marks (a dark wake, wired networking with wake for network access).
public func networkLivenessSleptSeconds() -> Double {
    return Double(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW)) / 1_000_000_000.0 - networkLivenessUptime()
}

/// MtProtoKit's TCP probe of the datacenter (see `NetworkLivenessPolicy`).
func networkLivenessMtProtoKitProbe(context: MTContext, datacenterId: Int, timeout: Double) -> Signal<Bool, NoError> {
    return Signal { subscriber in
        let disposable = MTProxyConnectivity.probeDatacenter(with: context, datacenterId: datacenterId, timeout: timeout).start(next: { value in
            subscriber.putNext((value as? NSNumber)?.boolValue ?? false)
            subscriber.putCompletion()
        }, error: { _ in
            subscriber.putNext(false)
            subscriber.putCompletion()
        }, completed: {
            subscriber.putCompletion()
        })
        return ActionDisposable {
            disposable?.dispose()
        }
    }
}

public final class NetworkLivenessMonitor {
    public struct Dependencies {
        /// Seconds the device was awake.
        public var clock: () -> Double
        public var activity: (@escaping (NetworkEngineServerActivity?) -> Void) -> Void
        public var engineKind: () -> NetworkEngineKind
        public var networkIdentity: () -> String?
        /// Why MtProtoKit cannot probe the way the network connects now (a WEB proxy), or nil.
        public var probeUnavailable: () -> String?
        public var probe: (Double) -> Signal<Bool, NoError>
        public var report: (NetworkLivenessReport) -> Void
        public var switchToMtProtoKit: (String) -> Void
        public var limiter: NetworkLivenessProbeLimiter
        /// Seconds slept so far (`networkLivenessSleptSeconds`): a wake starts the window again, since the
        /// session's own silence also counts the time asleep.
        public var slept: () -> Double

        public init(clock: @escaping () -> Double, activity: @escaping (@escaping (NetworkEngineServerActivity?) -> Void) -> Void, engineKind: @escaping () -> NetworkEngineKind, networkIdentity: @escaping () -> String?, probeUnavailable: @escaping () -> String?, probe: @escaping (Double) -> Signal<Bool, NoError>, report: @escaping (NetworkLivenessReport) -> Void, switchToMtProtoKit: @escaping (String) -> Void, limiter: NetworkLivenessProbeLimiter, slept: @escaping () -> Double = networkLivenessSleptSeconds) {
            self.slept = slept
            self.clock = clock
            self.activity = activity
            self.engineKind = engineKind
            self.networkIdentity = networkIdentity
            self.probeUnavailable = probeUnavailable
            self.probe = probe
            self.report = report
            self.switchToMtProtoKit = switchToMtProtoKit
            self.limiter = limiter
        }
    }

    public static let switchReason = "local-health"

    private let queue: Queue
    private let datacenterId: Int
    private let dependencies: Dependencies
    private var networkUpSince: Double?
    private var resumedSince: Double?
    private var engineKind: NetworkEngineKind?
    private var engineSince: Double?
    private var lastSlept: Double?
    private var wokeAt: Double?
    private var drops: [(at: Double, drop: NetworkEngineConnectionDrop)] = []
    private var checking = false
    private var finished = false
    private var answeredProbeAt: Double?
    private var lastSkipReason: String?
    private var timer: SwiftSignalKit.Timer?
    private let probeDisposable = MetaDisposable()

    public init(queue: Queue, datacenterId: Int, dependencies: Dependencies) {
        self.queue = queue
        self.datacenterId = datacenterId
        self.dependencies = dependencies
    }

    deinit {
        self.timer?.invalidate()
        self.probeDisposable.dispose()
    }

    public func start(checkEvery interval: Double = NetworkLivenessPolicy.checkInterval) {
        self.queue.async { [weak self] in
            guard let self = self, self.timer == nil else {
                return
            }
            let timer = SwiftSignalKit.Timer(timeout: interval, repeat: true, completion: { [weak self] in
                self?.check()
            }, queue: self.queue)
            self.timer = timer
            timer.start()
        }
    }

    public func stop() {
        self.queue.async { [weak self] in
            self?.finished = true
            self?.timer?.invalidate()
            self?.timer = nil
            self?.probeDisposable.set(nil)
        }
    }

    /// The main session's connection status: its `isNetworkAvailable` is the engine's reachability (and
    /// false while paused).
    public func connectionStateChanged(_ state: NetworkEngineConnectionState) {
        let now = self.dependencies.clock()
        self.queue.async { [weak self] in
            guard let self = self else {
                return
            }
            if state.isNetworkAvailable {
                if self.networkUpSince == nil {
                    self.networkUpSince = now
                }
            } else {
                self.networkUpSince = nil
            }
        }
    }

    public func setResumed(_ resumed: Bool) {
        let now = self.dependencies.clock()
        self.queue.async { [weak self] in
            guard let self = self else {
                return
            }
            if resumed {
                if self.resumedSince == nil {
                    self.resumedSince = now
                }
            } else {
                self.resumedSince = nil
            }
        }
    }

    public func connectionDropped(_ drop: NetworkEngineConnectionDrop) {
        let now = self.dependencies.clock()
        self.queue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.drops.append((now, drop))
            if self.drops.count > NetworkLivenessPolicy.dropsReported {
                self.drops.removeFirst(self.drops.count - NetworkLivenessPolicy.dropsReported)
            }
        }
    }

    private var windowStart: Double? {
        guard let up = self.networkUpSince, let resumed = self.resumedSince, let engineSince = self.engineSince else {
            return nil
        }
        return max(up, resumed, engineSince, self.wokeAt ?? -Double.infinity)
    }

    /// Runs on `queue`, every `checkInterval`.
    public func check() {
        let kind = self.dependencies.engineKind()
        if kind != self.engineKind {
            self.engineKind = kind
            self.engineSince = self.dependencies.clock()
        }
        self.noteWake()
        guard !self.finished, !self.checking else {
            return
        }
        if kind == .rust && self.dependencies.limiter.engineFailed {
            self.finished = true
            self.timer?.invalidate()
            self.timer = nil
            Logger.shared.log("Network", "Local health: another network of this launch found the engine failing; moving dc\(self.datacenterId) to MtProtoKit until the next launch")
            self.dependencies.switchToMtProtoKit(NetworkLivenessMonitor.switchReason)
            return
        }
        guard kind == .rust, let windowStart = self.windowStart else {
            self.answeredProbeAt = nil
            return
        }
        if let answeredAt = self.answeredProbeAt {
            if windowStart > answeredAt {
                self.answeredProbeAt = nil
                Logger.shared.log("Network", "Local health: the network changed or the device slept after MtProtoKit's TCP answered; no verdict")
                return
            }
            if self.dependencies.clock() - answeredAt < NetworkLivenessPolicy.engineRetryGrace {
                return
            }
            self.checking = true
            self.dependencies.activity { [weak self] activity in
                guard let self = self else {
                    return
                }
                self.queue.async {
                    self.decide(activity, startedAt: answeredAt)
                }
            }
            return
        }
        if self.dependencies.clock() - windowStart < NetworkLivenessPolicy.silence {
            return
        }
        self.checking = true
        self.dependencies.activity { [weak self] activity in
            guard let self = self else {
                return
            }
            self.queue.async {
                self.evaluate(activity)
            }
        }
    }

    /// A wake starts the window again: the session's silence also counts the time asleep.
    private func noteWake() {
        let slept = self.dependencies.slept()
        if let lastSlept = self.lastSlept, slept - lastSlept > 1.0 {
            self.wokeAt = self.dependencies.clock()
        }
        self.lastSlept = slept
    }

    private func evaluate(_ activity: NetworkEngineServerActivity?) {
        self.noteWake()
        let now = self.dependencies.clock()
        guard !self.finished, let windowStart = self.windowStart, networkLivenessIsSilent(activity, windowStart: windowStart, now: now) else {
            self.checking = false
            return
        }
        if let reason = self.dependencies.probeUnavailable() {
            if self.lastSkipReason != reason {
                self.lastSkipReason = reason
                Logger.shared.log("Network", "Local health: the engine heard nothing for \(Int(now - windowStart)) s; no probe: \(reason)")
            }
            self.checking = false
            return
        }
        self.lastSkipReason = nil
        let key = self.dependencies.networkIdentity() ?? ""
        guard self.dependencies.limiter.mayProbe(key: key, now: now) else {
            self.checking = false
            return
        }
        Logger.shared.log("Network", "Local health: the engine heard nothing on dc\(self.datacenterId) for \(Int(now - windowStart)) s; asking MtProtoKit's TCP")
        let probeStarted = now
        self.probeDisposable.set((self.dependencies.probe(NetworkLivenessPolicy.probeTimeout)
        |> take(1)
        |> deliverOn(self.queue)).start(next: { [weak self] answered in
            self?.probed(answered: answered, startedAt: probeStarted)
        }, completed: { [weak self] in
            guard let self = self, self.checking else {
                return
            }
            self.checking = false
        }))
    }

    private func probed(answered: Bool, startedAt: Double) {
        self.checking = false
        guard answered else {
            Logger.shared.log("Network", "Local health: MtProtoKit's TCP got no answer either; the engine stays")
            return
        }
        guard !self.finished, self.dependencies.engineKind() == .rust else {
            return
        }
        Logger.shared.log("Network", "Local health: MtProtoKit's TCP answered; the engine has \(Int(NetworkLivenessPolicy.engineRetryGrace)) s to hear the server itself")
        self.answeredProbeAt = startedAt
    }

    private func decide(_ activity: NetworkEngineServerActivity?, startedAt: Double) {
        self.checking = false
        self.answeredProbeAt = nil
        self.noteWake()
        let now = self.dependencies.clock()
        guard !self.finished, let windowStart = self.windowStart, windowStart <= startedAt, let activity = activity, networkLivenessIsSilent(activity, windowStart: windowStart, now: now), (activity.silentFor ?? Double.infinity) >= now - startedAt else {
            Logger.shared.log("Network", "Local health: MtProtoKit's TCP answered, but the engine heard from the server meanwhile; it stays")
            return
        }
        self.finished = true
        self.timer?.invalidate()
        self.timer = nil
        let report = NetworkLivenessReport(datacenterId: self.datacenterId, activity: activity, drops: self.drops.map { (now - $0.at, $0.drop) })
        Logger.shared.log("Network", "Local health: MtProtoKit's TCP answered while the engine heard nothing on dc\(self.datacenterId) (silent \(activity.silentFor.map { "\(Int($0)) s" } ?? "always"), waiting \(activity.waitingFor.map { "\(Int($0)) s" } ?? "none"), connected \(activity.connected), drops \(report.drops.map { "\($0.drop.reason)\($0.drop.answered ? "" : "_unanswered")" })); moving to MtProtoKit until the next launch")
        self.dependencies.limiter.noteEngineFailed()
        self.dependencies.report(report)
        self.dependencies.switchToMtProtoKit(NetworkLivenessMonitor.switchReason)
    }
}
