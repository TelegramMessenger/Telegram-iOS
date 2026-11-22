import XCTest
import SwiftSignalKit
import MtProtoKit
@testable import TelegramCore

private final class B3FinalClock {
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

/// One account's network in virtual time. The engine side is a model of the Rust main session after an
/// upstream outage that reachability never saw: silent and unconnected until `engineRecoversAt` (its
/// next connection attempt after the backoff it built up during the outage), answered from then on.
private final class B3FinalWorld {
    let clock = B3FinalClock()
    let queue = Queue(name: "B3FinalLivenessWorld")
    var upstreamUpAt: Double = 0.0
    var engineRecoversAt: Double = .infinity
    var kind: NetworkEngineKind = .rust
    private(set) var probes = 0
    private(set) var probesAnswered = 0
    private(set) var switches: [Double] = []
    private(set) var reports: [NetworkLivenessReport] = []
    var monitor: NetworkLivenessMonitor!

    init(limiter: NetworkLivenessProbeLimiter) {
        let start = self.clock.now
        self.monitor = NetworkLivenessMonitor(queue: self.queue, datacenterId: 2, dependencies: NetworkLivenessMonitor.Dependencies(
            clock: { [clock] in clock.now },
            activity: { [weak self] reply in
                guard let self = self else {
                    reply(nil)
                    return
                }
                let now = self.clock.now - start
                if now >= self.engineRecoversAt {
                    reply(NetworkEngineServerActivity(silentFor: 0.1, waitingFor: nil, connected: true))
                } else {
                    reply(NetworkEngineServerActivity(silentFor: now + 600.0, waitingFor: nil, connected: false))
                }
            },
            engineKind: { [weak self] in self?.kind ?? .mtProtoKit },
            networkIdentity: { "hotel" },
            probeUnavailable: { nil },
            probe: { [weak self] _ in
                guard let self = self else {
                    return .single(false)
                }
                self.probes += 1
                self.clock.advance(0.2)
                let answered = self.clock.now - start >= self.upstreamUpAt
                if answered {
                    self.probesAnswered += 1
                }
                return .single(answered)
            },
            report: { [weak self] report in
                self?.reports.append(report)
            },
            switchToMtProtoKit: { [weak self] _ in
                guard let self = self else {
                    return
                }
                self.switches.append(self.clock.now - start)
                self.kind = .mtProtoKit
            },
            limiter: limiter,
            slept: { 0.0 }
        ))
        self.monitor.setResumed(true)
        self.monitor.connectionStateChanged(NetworkEngineConnectionState(isNetworkAvailable: true, isConnected: false, isUpdatingConnectionContext: false, isPerformingServiceTasks: false, proxyAddress: nil, proxyHasConnectionIssues: false))
        self.settle()
    }

    func settle() {
        for _ in 0 ..< 4 {
            self.queue.sync {}
        }
    }

    func step() {
        self.clock.advance(NetworkLivenessPolicy.checkInterval)
        self.queue.sync {
            self.monitor.check()
        }
        self.settle()
    }
}

final class B3FinalLivenessTests: XCTestCase {
    private static let logger: Logger = {
        let path = NSTemporaryDirectory() + "b3final-liveness-logs-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        let logger = Logger(rootPath: path, basePath: path)
        logger.logToFile = false
        logger.logToConsole = false
        return logger
    }()

    override func setUp() {
        super.setUp()
        Logger.setSharedLogger(B3FinalLivenessTests.logger)
    }

    /// A hotel network: Wi-Fi up (reachability never changes) but the upstream blocked behind a captive
    /// portal for 11 minutes. The engine's attempts fail meanwhile and its key handshake backoff grows to
    /// its 60 s cap (`note_handshake_failure`, `HANDSHAKE_RETRY_MAX`); the guest logs in at 645 s and the
    /// engine's next attempt, at 700 s, connects. The first probe at ~50 s got no answer and blocked
    /// the network for ten minutes; the next one, at ~650 s, is answered by MtProtoKit's fresh
    /// connection while the engine still waits out its backoff. The engine was never broken: it must
    /// not be moved off (nor reported) for losing a race it was not allowed to run.
    func testAnEngineWaitingOutItsBackoffWhenTheNetworkComesBackIsNotMovedOff() {
        let world = B3FinalWorld(limiter: NetworkLivenessProbeLimiter())
        world.upstreamUpAt = 645.0
        world.engineRecoversAt = 700.0
        for _ in 0 ..< 200 where world.switches.isEmpty {
            world.step()
        }
        XCTAssertGreaterThanOrEqual(world.probesAnswered, 1, "MtProtoKit answered a probe while the engine waited")
        XCTAssertEqual(world.switches, [], "moved off a working engine at \(world.switches) s; it heard the server at 700 s")
        XCTAssertEqual(world.reports.count, 0, "an engine_fallback report for an engine that was not broken")
    }

    /// The engine really is broken (it never hears the server) and the device has two accounts on one
    /// network. The first account's probe is answered and it moves to MtProtoKit; the second account's
    /// session is just as silent but the process-wide limiter (one probe per network per ten minutes)
    /// keeps it on the broken engine, without a connection, for ten more minutes.
    func testASecondAccountOnTheSameNetworkLeavesABrokenEngineSoonAfterTheFirst() {
        let limiter = NetworkLivenessProbeLimiter()
        let first = B3FinalWorld(limiter: limiter)
        let second = B3FinalWorld(limiter: limiter)
        for _ in 0 ..< 200 where first.switches.isEmpty || second.switches.isEmpty {
            first.step()
            second.step()
        }
        XCTAssertEqual(first.switches.count, 1)
        XCTAssertEqual(second.switches.count, 1)
        if let firstAt = first.switches.first, let secondAt = second.switches.first {
            XCTAssertLessThanOrEqual(secondAt - firstAt, 120.0, "the second account stayed on a broken engine \(Int(secondAt - firstAt)) s longer than the first")
        }
        XCTAssertEqual(first.reports.count + second.reports.count, 1, "one verdict, reported once")
    }

    /// "Latched until the next launch": a network made after the verdict (the authorized network after a
    /// sign-in, a login moved to another datacenter by PHONE_MIGRATE, an account added) must not start on
    /// the engine again, where the limiter would then keep it from probing for ten minutes.
    func testANetworkMadeLaterInTheLaunchStartsOnMtProtoKit() {
        let limiter = NetworkLivenessProbeLimiter()
        XCTAssertNil(networkLivenessDisabledReason(limiter: limiter))
        let world = B3FinalWorld(limiter: limiter)
        for _ in 0 ..< 200 where world.switches.isEmpty {
            world.step()
        }
        XCTAssertEqual(world.switches.count, 1)
        XCTAssertNotNil(networkLivenessDisabledReason(limiter: limiter), "a later network would resolve to the engine just judged failing")
    }
}
