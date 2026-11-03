import XCTest
import SwiftSignalKit
import MtProtoKit
@testable import TelegramCore

private final class LivenessClock {
    private let lock = NSLock()
    private var value: Double = 1000.0

    var now: Double {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.value
    }

    func advance(_ seconds: Double) {
        self.lock.lock()
        self.value += seconds
        self.lock.unlock()
    }
}

/// A virtual-time world for one monitor: the session's activity, MtProtoKit's probe and what the
/// monitor did, every `checkInterval` seconds of virtual time.
private final class LivenessWorld {
    let clock = LivenessClock()
    let queue = Queue(name: "LivenessWorld")
    var activity: NetworkEngineServerActivity? = NetworkEngineServerActivity(silentFor: nil, waitingFor: nil, connected: false)
    var activityAfterProbe: NetworkEngineServerActivity?
    var probeAnswers = true
    var networkKey: String? = "home"
    var probeUnavailable: String?
    var kind: NetworkEngineKind = .rust
    var slept: Double = 0.0
    var sleepDuringProbe = false
    private(set) var probes = 0
    private(set) var switches: [String] = []
    private(set) var reports: [NetworkLivenessReport] = []
    private var probedAt: Double?
    var monitor: NetworkLivenessMonitor!
    var onSwitch: ((String) -> Void)?

    init(limiter: NetworkLivenessProbeLimiter = NetworkLivenessProbeLimiter()) {
        self.monitor = NetworkLivenessMonitor(queue: self.queue, datacenterId: 2, dependencies: NetworkLivenessMonitor.Dependencies(
            clock: { [clock] in clock.now },
            activity: { [weak self] reply in
                guard let self = self else {
                    reply(nil)
                    return
                }
                if let probedAt = self.probedAt, let after = self.activityAfterProbe {
                    reply(NetworkEngineServerActivity(silentFor: after.silentFor.map { $0 + (self.clock.now - probedAt) }, waitingFor: after.waitingFor, connected: after.connected))
                } else {
                    reply(self.activity)
                }
            },
            engineKind: { [weak self] in self?.kind ?? .mtProtoKit },
            networkIdentity: { [weak self] in self?.networkKey },
            probeUnavailable: { [weak self] in self?.probeUnavailable },
            probe: { [weak self] timeout in
                guard let self = self else {
                    return .single(false)
                }
                XCTAssertEqual(timeout, NetworkLivenessPolicy.probeTimeout)
                self.probes += 1
                self.clock.advance(2.0)
                self.probedAt = self.clock.now
                if self.sleepDuringProbe {
                    self.slept += 600.0
                }
                return .single(self.probeAnswers)
            },
            report: { [weak self] report in
                self?.reports.append(report)
            },
            switchToMtProtoKit: { [weak self] reason in
                self?.switches.append(reason)
                self?.kind = .mtProtoKit
                self?.onSwitch?(reason)
            },
            limiter: limiter,
            slept: { [weak self] in self?.slept ?? 0.0 }
        ))
    }

    func up(at state: NetworkEngineConnectionState = NetworkEngineConnectionState(isNetworkAvailable: true, isConnected: false, isUpdatingConnectionContext: false, isPerformingServiceTasks: false, proxyAddress: nil, proxyHasConnectionIssues: false)) {
        self.monitor.setResumed(true)
        self.monitor.connectionStateChanged(state)
        self.settle()
    }

    func down() {
        self.monitor.connectionStateChanged(NetworkEngineConnectionState(isNetworkAvailable: false, isConnected: false, isUpdatingConnectionContext: false, isPerformingServiceTasks: false, proxyAddress: nil, proxyHasConnectionIssues: false))
        self.settle()
    }

    func settle() {
        for _ in 0 ..< 4 {
            self.queue.sync {}
        }
    }

    /// Runs the checks for `seconds` of virtual time; the seconds when the network moved, if it did.
    @discardableResult
    func run(for seconds: Double, start: Double = 0.0) -> Double? {
        var elapsed = start
        while elapsed < start + seconds {
            self.clock.advance(NetworkLivenessPolicy.checkInterval)
            elapsed += NetworkLivenessPolicy.checkInterval
            self.queue.sync {
                self.monitor.check()
            }
            self.settle()
            if !self.switches.isEmpty {
                return elapsed
            }
        }
        return nil
    }
}

final class NetworkLivenessMonitorTests: XCTestCase {
    private static let logger: Logger = {
        let path = NSTemporaryDirectory() + "network-liveness-logs-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        let logger = Logger(rootPath: path, basePath: path)
        logger.logToFile = false
        logger.logToConsole = false
        return logger
    }()

    override func setUp() {
        super.setUp()
        Logger.setSharedLogger(NetworkLivenessMonitorTests.logger)
    }

    func testTheSilenceRule() {
        let silent = NetworkEngineServerActivity(silentFor: nil, waitingFor: nil, connected: false)
        XCTAssertTrue(networkLivenessIsSilent(silent, windowStart: 0.0, now: 45.0))
        XCTAssertFalse(networkLivenessIsSilent(silent, windowStart: 0.0, now: 44.0), "not before 45 s of the window")
        XCTAssertFalse(networkLivenessIsSilent(nil, windowStart: 0.0, now: 100.0), "an engine that does not tell is never judged")
        XCTAssertFalse(networkLivenessIsSilent(NetworkEngineServerActivity(silentFor: 44.0, waitingFor: 100.0, connected: false), windowStart: 0.0, now: 100.0), "anything from the server ends the silence")
        XCTAssertFalse(networkLivenessIsSilent(NetworkEngineServerActivity(silentFor: 300.0, waitingFor: nil, connected: true), windowStart: 0.0, now: 300.0), "an idle session on an answered connection is not judged")
        XCTAssertFalse(networkLivenessIsSilent(NetworkEngineServerActivity(silentFor: 300.0, waitingFor: 30.0, connected: true), windowStart: 0.0, now: 300.0))
        XCTAssertFalse(networkLivenessIsSilent(NetworkEngineServerActivity(silentFor: 300.0, waitingFor: 200.0, connected: true), windowStart: 0.0, now: 300.0), "a call in a flood wait or a slow one on an answered connection: the engine drops the connection itself if the server stops answering pings")
    }

    func testASessionThatNeverConnectsMovesWhenMtProtoKitAnswersAndTheEngineStaysSilentThroughItsRetries() {
        let world = LivenessWorld()
        world.monitor.connectionDropped(NetworkEngineConnectionDrop(reason: "connect_timeout", answered: false, age: 10.0))
        world.up()
        let movedAt = world.run(for: 240.0)
        XCTAssertNotNil(movedAt)
        XCTAssertTrue((movedAt ?? 0.0) >= NetworkLivenessPolicy.silence + NetworkLivenessPolicy.engineRetryGrace && (movedAt ?? 999.0) <= 60.0 + NetworkLivenessPolicy.engineRetryGrace, "\(String(describing: movedAt))")
        XCTAssertEqual(world.switches, ["local-health"])
        XCTAssertEqual(world.probes, 1)
        XCTAssertEqual(world.reports.count, 1, "reported first")
        XCTAssertEqual(world.reports.first?.drops.map(\.drop.reason), ["connect_timeout"])
        world.run(for: 60.0, start: movedAt ?? 0.0)
        XCTAssertEqual(world.switches.count, 1, "once")
        XCTAssertEqual(world.probes, 1)
    }

    func testNoSwitchWhenMtProtoKitGetsNoAnswerEitherAndOneProbePerTenMinutes() {
        let world = LivenessWorld()
        world.probeAnswers = false
        world.up()
        XCTAssertNil(world.run(for: 300.0))
        XCTAssertEqual(world.probes, 1, "one probe per network per ten minutes")
        XCTAssertNil(world.run(for: 380.0, start: 300.0))
        XCTAssertEqual(world.probes, 2, "the next one after ten minutes")
        XCTAssertTrue(world.switches.isEmpty)
        XCTAssertTrue(world.reports.isEmpty)
    }

    func testAnotherNetworkMayBeProbedAtOnce() {
        let limiter = NetworkLivenessProbeLimiter()
        XCTAssertTrue(limiter.mayProbe(key: "home", now: 100.0))
        XCTAssertFalse(limiter.mayProbe(key: "home", now: 650.0))
        XCTAssertTrue(limiter.mayProbe(key: "office", now: 650.0))
        XCTAssertTrue(limiter.mayProbe(key: "home", now: 700.1))
        XCTAssertTrue(limiter.mayProbe(key: "home", now: 50.0), "a clock that went back does not block for ever")
    }

    func testASessionThatHearsTheServerIsNeverJudged() {
        let world = LivenessWorld()
        world.activity = NetworkEngineServerActivity(silentFor: 3.0, waitingFor: 200.0, connected: false)
        world.up()
        XCTAssertNil(world.run(for: 600.0))
        XCTAssertEqual(world.probes, 0)
    }

    func testASessionOnAnAnsweredConnectionIsNeverJudged() {
        for waitingFor in [nil, 120.0] as [Double?] {
            let world = LivenessWorld()
            world.activity = NetworkEngineServerActivity(silentFor: 1000.0, waitingFor: waitingFor, connected: true)
            world.up()
            XCTAssertNil(world.run(for: 600.0))
            XCTAssertEqual(world.probes, 0, "waiting \(String(describing: waitingFor))")
        }
    }

    func testASwitchToRustStartsTheWindowAgain() {
        let world = LivenessWorld()
        world.kind = .mtProtoKit
        world.up()
        XCTAssertNil(world.run(for: 300.0))
        world.kind = .rust
        XCTAssertNil(world.run(for: 40.0, start: 300.0), "a session the network just moved to is given the whole 45 s")
        XCTAssertEqual(world.probes, 0)
        XCTAssertNotNil(world.run(for: 60.0 + NetworkLivenessPolicy.engineRetryGrace, start: 340.0))
    }

    func testNoSwitchWhenTheEngineHeardTheServerDuringTheProbe() {
        let world = LivenessWorld()
        world.activityAfterProbe = NetworkEngineServerActivity(silentFor: 0.5, waitingFor: 60.0, connected: false)
        world.up()
        XCTAssertNil(world.run(for: 120.0 + NetworkLivenessPolicy.engineRetryGrace))
        XCTAssertEqual(world.probes, 1)
        XCTAssertTrue(world.switches.isEmpty)
    }

    func testSleepAndNetworkChangesStartTheWindowAgain() {
        let world = LivenessWorld()
        world.up()
        XCTAssertNil(world.run(for: 40.0))
        world.down()
        world.clock.advance(3600.0)
        world.up()
        XCTAssertNil(world.run(for: 40.0), "a wake or a network change starts the 45 s again")
        world.monitor.setResumed(false)
        world.settle()
        XCTAssertNil(world.run(for: 100.0), "a paused session is not judged")
        XCTAssertEqual(world.probes, 0)
        world.up()
        XCTAssertNotNil(world.run(for: 60.0 + NetworkLivenessPolicy.engineRetryGrace))
    }

    func testAWakeThatChangesNothingElseStartsTheWindowAgain() {
        let world = LivenessWorld()
        world.up()
        XCTAssertNil(world.run(for: 40.0))
        world.slept += 3600.0
        XCTAssertNil(world.run(for: 40.0, start: 40.0), "the session's silence counts the night; the window starts at the wake")
        XCTAssertEqual(world.probes, 0)
        XCTAssertNotNil(world.run(for: 30.0 + NetworkLivenessPolicy.engineRetryGrace, start: 80.0))
    }

    func testAWakeDuringTheProbeGivesNoVerdict() {
        let world = LivenessWorld()
        world.sleepDuringProbe = true
        world.activityAfterProbe = NetworkEngineServerActivity(silentFor: 700.0, waitingFor: nil, connected: false)
        world.up()
        XCTAssertNil(world.run(for: 120.0 + NetworkLivenessPolicy.engineRetryGrace), "the silence the session reports after the wake counts the night")
        XCTAssertEqual(world.probes, 1)
        XCTAssertTrue(world.switches.isEmpty)
    }

    func testNoProbeThroughAWebProxyOrOnceOffTheEngine() {
        let world = LivenessWorld()
        world.probeUnavailable = "a WEB proxy"
        world.up()
        XCTAssertNil(world.run(for: 120.0))
        XCTAssertEqual(world.probes, 0)
        world.probeUnavailable = nil
        world.kind = .mtProtoKit
        XCTAssertNil(world.run(for: 120.0, start: 120.0))
        XCTAssertEqual(world.probes, 0)
    }

    /// The whole path with live switching: a Rust-kind engine whose main session never connects, the
    /// monitor reading it through `SwitchingNetworkEngine`, and the switch it makes.
    func testANeverConnectingEngineIsLeftThroughTheSwitchingEngine() {
        final class SilentSession: NetworkEngineSession {
            let datacenterId = 2
            let requestService: NetworkEngineRequestService
            private(set) var drained = false

            init(service: NetworkEngineRequestService) {
                self.requestService = service
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
                self.drained = true
                completion()
            }

            func serverActivity(_ reply: @escaping (NetworkEngineServerActivity?) -> Void) {
                reply(NetworkEngineServerActivity(silentFor: nil, waitingFor: 60.0, connected: false))
            }
        }
        final class Service: NetworkEngineRequestService {
            func add(_ request: NetworkEngineRequest) -> Disposable {
                return EmptyDisposable
            }
        }
        final class Engine: NetworkEngine {
            let kind: NetworkEngineKind
            var sessions: [SilentSession] = []

            init(kind: NetworkEngineKind) {
                self.kind = kind
            }

            func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
                let session = SilentSession(service: Service())
                self.sessions.append(session)
                return session
            }

            func networkIdentity() -> String? {
                return "lab"
            }
        }
        let rust = Engine(kind: .rust)
        let mtProtoKit = Engine(kind: .mtProtoKit)
        let switching = SwitchingNetworkEngine(engine: rust)
        let session = switching.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: nil)
        defer { session.stop() }
        let clock = LivenessClock()
        let queue = Queue(name: "LivenessEndToEnd")
        let switched = Atomic<Double?>(value: nil)
        var started = 0.0
        let monitor = NetworkLivenessMonitor(queue: queue, datacenterId: 2, dependencies: NetworkLivenessMonitor.Dependencies(
            clock: { clock.now },
            activity: { reply in session.serverActivity(reply) },
            engineKind: { switching.kind },
            networkIdentity: { switching.networkIdentity() },
            probeUnavailable: { nil },
            probe: { _ in .single(true) },
            report: { _ in },
            switchToMtProtoKit: { reason in
                XCTAssertEqual(reason, "local-health")
                let _ = switched.swap(clock.now - started)
                let _ = switching.switchEngine(to: .mtProtoKit, drainTimeout: 5.0, makeEngine: { mtProtoKit })
            },
            limiter: NetworkLivenessProbeLimiter()
        ))
        started = clock.now
        monitor.setResumed(true)
        monitor.connectionStateChanged(NetworkEngineConnectionState(isNetworkAvailable: true, isConnected: false, isUpdatingConnectionContext: false, isPerformingServiceTasks: false, proxyAddress: nil, proxyHasConnectionIssues: false))
        for _ in 0 ..< 48 where switched.with({ $0 }) == nil {
            clock.advance(NetworkLivenessPolicy.checkInterval)
            queue.sync {
                monitor.check()
            }
            for _ in 0 ..< 4 {
                queue.sync {}
            }
        }
        let after = switched.with { $0 }
        XCTAssertNotNil(after)
        XCTAssertLessThanOrEqual(after ?? 999.0, 60.0 + NetworkLivenessPolicy.engineRetryGrace)
        XCTAssertEqual(switching.kind, .mtProtoKit)
        XCTAssertTrue(rust.sessions[0].drained, "the switch drains the silent session")
        XCTAssertEqual(mtProtoKit.sessions.count, 1)
    }
}
