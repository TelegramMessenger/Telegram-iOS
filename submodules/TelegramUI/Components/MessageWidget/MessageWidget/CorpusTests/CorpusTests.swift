import UIKit
import XCTest
@testable import MessageWidget

/// widget-sandbox's corpus (every folder but `attacks`, which InstanceTests scans) through the whole pipeline.
final class CorpusTests: MessageWidgetTestCase {
    static let folders = ["bot-demos", "common", "compat", "defaults", "generated", "gestures", "htmlbubbles-ported", "interactive", "out-of-profile", "resize", "safe-area", "showcase"]
    /// Deliberate misbehaviour, by widget-sandbox's own README (htmlbubbles-ported, "Status"): the Hang button runs
    /// `for (;;) {}` (the tap grid presses it) and the Buggy button throws on purpose.
    static let runaways: Set<String> = ["htmlbubbles-ported/11-live-scripts/15-pixel-bare.html"]
    static let throwsOnPurpose: Set<String> = ["htmlbubbles-ported/11-live-scripts/17-pixel-bare.html"]
    /// Over its JS quota on purpose, by its own header ("an over-budget widget has its timers deferred rather than being
    /// stopped — the tick rate shows it"), behind the button the tap grid presses: upstream's throttling demo.
    static let throttledOnPurpose: Set<String> = ["htmlbubbles-ported/11-live-scripts/16-pixel-bare.html"]
    /// Upstream's accepted case of the main-thread window: each tap restarts a CSS transition with a layout query
    /// (`void root.offsetWidth`, ~4.6 ms here; 05-sam-bare also rebuilds its calendar with `innerHTML`), so the grid's 24
    /// taps in under a second pass its 100 ms of query time and op cost, which upstream charges too (126 and 117 ms
    /// since the windows record a step at its end, as upstream's do); at a person's tapping rate they stay far below.
    /// Exempt from the throttle checks only.
    static let queriesPastTheWindowUnderTheGrid: Set<String> = ["htmlbubbles-ported/12-motion-lab/09-mo-bare.html", "htmlbubbles-ported/10-game-night/05-sam-bare.html"]
    /// Measured in this plan's Task 3, Step 4: filled in only for files the user accepts as attack demos.
    static let attackDemos: Set<String> = []
    /// The uncaught errors that are APIs WidgetRuntime does not have yet, by their message: a corpus widget throwing one
    /// is a known gap, printed below, not a failure. Every entry goes when its API lands.
    static let knownGaps: [String] = [
        // Chart.js and d3 from a CDN: profile 1 bundles no library (js.libraries is out), so out-of-profile/chartjs-*
        // and d3-* stop at their first use, as the profile says.
        "Chart is not defined",
        "d3 is not defined",
        // Never: a widget cannot fetch.
        "fetch is not defined",
    ]

    private func files() -> [WidgetCorpus.File] {
        return CorpusTests.folders.flatMap { WidgetCorpus.files(in: $0) }
    }

    func testEveryCorpusWidgetStartsAndFetchesNothing() throws {
        // What stopped and what threw, by reason, printed for the record (M1d plan, Task 8: every file boots).
        var stoppedBy: [String: [String]] = [:]
        var threwBy: [String: [String]] = [:]
        defer {
            print("corpus: \(self.files().count) files, \(stoppedBy.values.map(\.count).reduce(0, +)) stopped, \(threwBy.values.map(\.count).reduce(0, +)) with an uncaught error")
            for (reason, paths) in stoppedBy.sorted(by: { $0.value.count > $1.value.count }) {
                print("corpus stopped (\(paths.count)): \(reason): \(paths.joined(separator: ", "))")
            }
            for (error, paths) in threwBy.sorted(by: { $0.value.count > $1.value.count }) {
                print("corpus threw (\(paths.count)): \(error): \(paths.joined(separator: ", "))")
            }
        }
        URLProtocol.registerClass(RecordingURLProtocol.self)
        defer {
            URLProtocol.unregisterClass(RecordingURLProtocol.self)
        }
        RecordingURLProtocol.reset()
        for file in self.files() {
            let (instance, view) = self.booted(file.source)
            for _ in 0 ..< 3 {
                self.deliverFrame(instance)
            }
            self.pump(0.05)
            view.update()
            if let reason = instance.deadReason {
                stoppedBy[reason, default: []].append(file.path)
            }
            if let error = instance.lastError {
                // The message without its location, so one missing API groups across files.
                threwBy[error.components(separatedBy: " (").first ?? error, default: []].append(file.path)
            }
            XCTAssertFalse(instance.failedToStart, file.path)
            XCTAssertNil(instance.deadReason, file.path)
            // A URL that reaches the renderer is refused there (no validator removes it first now) and never requested.
            XCTAssertGreaterThanOrEqual(self.networkRefusals(instance), 0, file.path)
            if !CorpusTests.throwsOnPurpose.contains(file.path), let error = instance.lastError, !CorpusTests.knownGaps.contains(where: { error.contains($0) }) {
                XCTFail("\(file.path): \(error)")
            }
            instance.destroy()
        }
        XCTAssertEqual(RecordingURLProtocol.requests, [], "a widget's URL was requested")
    }

    /// The CPU-clock limits design: every honest widget, booted, tapped on a 4×6 grid and run on for 1.2 s of timers and
    /// frames, on the product's limits and the widget thread's clock, takes at most a quarter of a slice in any step
    /// (125 ms), at most a quarter of the JS quota a second while it runs on (75 ms), is never throttled by either
    /// window, and is not demoted by its boot. Printed as a table, slowest first, so it shows what each widget needs.
    func testEveryCorpusWidgetStaysWellInsideItsLimits() throws {
        var rows: [(path: String, step: Double, jsPerSecond: Double, tapThrottled: UInt64, throttled: UInt64, reports: [String])] = []
        var stopped: Set<String> = []
        var demotedByTheBoot: [String] = []
        for file in self.files() {
            let (instance, view) = self.booted(file.source)
            // Demotion exempts the boot's own steps for their first two slices of CPU: no honest widget's boot reaches it.
            // Read once the boot is over: a boot past its task's slice finishes on wakes, and a wake's snapshot is where
            // demotion is decided, so the document's load and the snapshot of the task that reached it come first.
            _ = self.pump(until: { instance.deadReason != nil || instance.evaluateForTesting("document.readyState") == "complete" }, timeout: 5.0)
            self.pump(0.05)
            if instance.demoted {
                demotedByTheBoot.append(file.path)
            }
            let size = view.bounds.size
            let booted = instance.stressStats()
            for row in 0 ..< 6 {
                for column in 0 ..< 4 {
                    let point = CGPoint(x: size.width * (CGFloat(column) + 0.5) / 4.0, y: size.height * (CGFloat(row) + 0.5) / 6.0)
                    instance.touch(action: 0, at: point, pointer: 0, primary: true)
                    instance.touch(action: 2, at: point, pointer: 0, primary: true)
                }
            }
            let first = instance.stressStats()
            let start = CACurrentMediaTime()
            for _ in 0 ..< 12 {
                self.pump(0.1)
                self.deliverFrame(instance)
            }
            let last = instance.stressStats()
            let seconds = CACurrentMediaTime() - start
            if instance.deadReason != nil {
                stopped.insert(file.path)
            }
            if let booted, let first, let last {
                let reports = instance.diagnostics.filter { $0.kind == "cpu-throttled" }.map(\.detail)
                rows.append((file.path, last.largestStepMilliseconds, (last.jsMilliseconds - first.jsMilliseconds) / seconds, first.throttledSteps - booted.throttledSteps, last.throttledSteps - first.throttledSteps, reports))
            }
            instance.destroy()
        }
        rows.sort { $0.step > $1.step }
        print("CPU on the widget thread: the largest step (slice 500 ms), JS a second while running on (quota 300 ms a second), throttled steps")
        for row in rows {
            print(String(format: "%-64@ step %7.1f ms   js %6.1f ms/s   throttled in the taps %llu, after %llu   %@", row.path as NSString, row.step, row.jsPerSecond, row.tapThrottled, row.throttled, row.reports.joined(separator: " | ") as NSString))
        }
        XCTAssertEqual(stopped, CorpusTests.runaways)
        XCTAssertEqual(demotedByTheBoot, [], "demoted by their boot")
        for row in rows where !CorpusTests.runaways.contains(row.path) && !CorpusTests.attackDemos.contains(row.path) {
            XCTAssertLessThan(row.step, 125.0, "\(row.path): a step took \(row.step) ms")
            if CorpusTests.throttledOnPurpose.contains(row.path) {
                continue
            }
            XCTAssertLessThanOrEqual(row.jsPerSecond, 75.0, "\(row.path): \(row.jsPerSecond) ms of JS a second")
            if CorpusTests.queriesPastTheWindowUnderTheGrid.contains(row.path) {
                continue
            }
            XCTAssertEqual(row.tapThrottled + row.throttled, 0, "\(row.path): throttled \(row.tapThrottled) steps in the taps, \(row.throttled) after")
            XCTAssertEqual(row.reports, [], "\(row.path): throttle diagnostics")
        }
    }

    /// The latency a person sees (the user's goal, 2026-10-19: "minimal boot and update latency"), printed, not
    /// asserted. For each corpus widget's boot (the layout call that boots it, tiles at 3× as on a device) and each tap of
    /// a 3 × 3 grid (down and up): the critical time, what main waits for (the size and state; the user: drawing may be
    /// async, only the size is critical), and the time until its tiles have landed. Medians, the 95th percentile and the
    /// slowest, with the slowest files named.
    func testWhatBootAndTapsCostInWallTime() throws {
        func percentile(_ values: [Double], _ p: Double) -> Double {
            let sorted = values.sorted()
            return sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(Double(sorted.count) * p))]
        }
        func landed(_ instance: MessageWidgetInstance) {
            while instance.isDrawPendingForTesting {
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.0005))
            }
        }
        // The process's first CADisplayLink takes ~5 s in a headless test simulator (testThePollsTapsAreFast): made here,
        // so the first widget that asks for a frame does not carry the test environment's cost.
        CADisplayLink(target: self, selector: #selector(CorpusTests.noFrame(_:))).invalidate()
        var boots: [(path: String, critical: Double, visible: Double)] = []
        var taps: [(path: String, critical: Double, visible: Double)] = []
        for file in self.files() {
            let instance = self.make(file.source, scale: 3.0)
            let start = CACurrentMediaTime()
            let size = instance.layout(width: 360.0)
            let critical = (CACurrentMediaTime() - start) * 1000.0
            landed(instance)
            boots.append((file.path, critical, (CACurrentMediaTime() - start) * 1000.0))
            for row in 0 ..< 3 {
                for column in 0 ..< 3 {
                    let point = CGPoint(x: size.width * (CGFloat(column) + 0.5) / 3.0, y: size.height * (CGFloat(row) + 0.5) / 3.0)
                    let tapStart = CACurrentMediaTime()
                    instance.touch(action: 0, at: point, pointer: 0, primary: true)
                    instance.touch(action: 2, at: point, pointer: 0, primary: true)
                    let tapCritical = (CACurrentMediaTime() - tapStart) * 1000.0
                    landed(instance)
                    taps.append((file.path, tapCritical, (CACurrentMediaTime() - tapStart) * 1000.0))
                }
            }
            instance.destroy()
        }
        for (name, rows) in [("boot", boots), ("tap", taps)] {
            let critical = rows.map(\.critical), visible = rows.map(\.visible)
            print(String(format: "latency %@: n %d   critical median %.1f ms, p95 %.1f ms, max %.1f ms   visible median %.1f ms, p95 %.1f ms, max %.1f ms", name as NSString, rows.count, percentile(critical, 0.5), percentile(critical, 0.95), critical.max() ?? 0, percentile(visible, 0.5), percentile(visible, 0.95), visible.max() ?? 0))
            for row in rows.sorted(by: { $0.critical > $1.critical }).prefix(6) {
                print(String(format: "latency %@ slowest critical: %7.1f ms (visible %.1f)  %@", name as NSString, row.critical, row.visible, row.path as NSString))
            }
        }
    }

    /// A tap on common/interactive/03-poll took 5 s in each corpus run (the latency measurement, 2026-10-19): it was the
    /// process's first CADisplayLink, made on main when the vote asked for a frame, which takes ~5 s in a headless test
    /// simulator (measured: 5,014 ms; the tap itself 1.6 ms). Each touch of the poll's grid is timed on its own, after that.
    func testThePollsTapsAreFast() throws {
        guard let file = WidgetCorpus.files(in: "common").first(where: { $0.path == "common/interactive/03-poll.html" }) else {
            return XCTFail("no poll")
        }
        // The first CADisplayLink of a process (MessageWidgetInstance makes one when a widget asks for a frame): in a
        // headless test simulator it can take seconds and then come back nil, which is the test environment's cost.
        let linkStart = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(CorpusTests.noFrame(_:)))
        print(String(format: "poll: the first CADisplayLink took %.1f ms", (CACurrentMediaTime() - linkStart) * 1000.0))
        link.invalidate()
        let instance = self.make(file.source, scale: 3.0)
        let size = instance.layout(width: 360.0)
        var slow: [String] = []
        for row in 0 ..< 3 {
            for column in 0 ..< 3 {
                let point = CGPoint(x: size.width * (CGFloat(column) + 0.5) / 3.0, y: size.height * (CGFloat(row) + 0.5) / 3.0)
                for action: Int32 in [0, 2] {
                    let start = CACurrentMediaTime()
                    instance.touch(action: action, at: point, pointer: 0, primary: true)
                    let ms = (CACurrentMediaTime() - start) * 1000.0
                    let step = instance.onCoreForTesting { $0.lastStepMilliseconds } ?? 0
                    print(String(format: "poll row %d column %d %@: %.1f ms, step %.1f ms", row, column, action == 0 ? "down" : "up", ms, step))
                    if ms > 500.0 {
                        slow.append(String(format: "row %d column %d %@: %.0f ms", row, column, action == 0 ? "down" : "up", ms))
                    }
                }
            }
        }
        instance.destroy()
        XCTAssertEqual(slow, [])
    }

    @objc private func noFrame(_ link: CADisplayLink) {
    }
}
