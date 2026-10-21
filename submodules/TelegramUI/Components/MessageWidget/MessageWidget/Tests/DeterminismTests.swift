import XCTest
@testable import MessageWidget

/// Spec 2026-10-15 D5.1 (final review I3): whether a widget is stopped, and where, depends on its work alone.
class DeterminismTests: MessageWidgetTestCase {
    /// A runaway that mixes JS, allocation, a sort, a regex, DOM ops through the validator and the renderer, and
    /// queries stops at the same unit count, with the same reason, on a pool of one thread, on a pool of two (its
    /// tasks on either), and while four other threads keep the machine busy.
    func testAMixedRunawayStopsAtTheSameWorkOnAnyThreadAndUnderLoad() {
        // No canvas until M3: the mix is arrays, sorting, regexes and the DOM.
        let source = "<!doctype html><p id=p>x</p><script>var p = document.getElementById('p'); for (var i = 0; ; i++) { var a = []; for (var j = 0; j < 50; j++) a.push(String((i * 7919 + j) % 1000)); a.sort(); /x+y/.test('xxxx' + i); p.textContent = 'n' + i; }</script>"
        func run(threads: Int) -> (units: UInt64, reason: String?) {
            let pool = MessageWidgetPool(threadCount: threads)
            defer {
                pool.stop()
            }
            guard let instance = MessageWidgetInstance(source: source, theme: .light, stoppedLabel: "Widget stopped", maxMessageLength: 4096, pool: pool, waitPolicy: .unbounded, turn: self.turn, scale: 1.0) else {
                XCTFail("no instance")
                return (0, nil)
            }
            defer {
                instance.destroy()
            }
            _ = instance.layout(width: 360.0)
            return (instance.lastTaskWorkForTesting, instance.deadReason)
        }
        // Four runs on each pool (a dictionary-ordered answer had split one run in four), then one under load.
        var results: [(units: UInt64, reason: String?)] = []
        for _ in 0 ..< 4 {
            results.append(run(threads: 1))
            results.append(run(threads: 2))
        }
        let load = Load()
        load.start(threads: 4)
        results.append(run(threads: 2))
        load.stop()
        let first = results[0]
        XCTAssertTrue(first.reason?.contains("Work limit") ?? false, first.reason ?? "nil")
        for (index, result) in results.enumerated() {
            XCTAssertEqual(result.units, first.units, "run \(index)")
            XCTAssertEqual(result.reason, first.reason, "run \(index)")
        }
    }

}

/// Busy threads, to run a test under machine load.
private final class Load {
    private let lock = NSLock()
    private var running = false
    private var threads: [Thread] = []

    func start(threads count: Int) {
        self.lock.lock()
        self.running = true
        self.lock.unlock()
        for _ in 0 ..< count {
            let thread = Thread { [weak self] in
                var x: UInt64 = 1
                while self?.isRunning ?? false {
                    for _ in 0 ..< 100_000 {
                        x = x &* 6364136223846793005 &+ 1442695040888963407
                    }
                }
                _ = x
            }
            thread.start()
            self.threads.append(thread)
        }
    }

    var isRunning: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.running
    }

    func stop() {
        self.lock.lock()
        self.running = false
        self.lock.unlock()
    }
}
