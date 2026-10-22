import UIKit
import XCTest
@testable import MessageWidget

/// widget-sandbox's corpus (every folder but `attacks`, which InstanceTests scans) through the whole pipeline.
final class CorpusTests: MessageWidgetTestCase {
    static let folders = ["common", "compat", "defaults", "generated", "htmlbubbles-ported", "out-of-profile", "showcase"]
    /// Deliberate misbehaviour, by widget-sandbox's own README (htmlbubbles-ported, "Status"): the Hang button runs
    /// `for (;;) {}` (the tap grid presses it) and the Buggy button throws on purpose.
    static let runaways: Set<String> = ["htmlbubbles-ported/11-live-scripts/15-pixel-bare.html"]
    static let throwsOnPurpose: Set<String> = ["htmlbubbles-ported/11-live-scripts/17-pixel-bare.html"]
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

    /// Spec 2026-10-15 D7: every honest widget's boot, and its largest later task (a tap on a 4×6 grid, then 1.2 s of
    /// timers and frames), each stay under a quarter of their budgets. Measured on budgets of 200,000,000 units, so the
    /// table shows what each widget needs rather than where it was stopped.
    func testEveryCorpusWidgetStaysWellInsideItsBudget() throws {
        MessageWidgetCore.budgetsForTesting = (parse: MessageWidgetCore.parseWorkUnits, boot: 200_000_000, task: 200_000_000)
        defer { MessageWidgetCore.budgetsForTesting = nil }
        var rows: [(path: String, parse: UInt64, boot: UInt64, later: UInt64)] = []
        var stopped: Set<String> = []
        for file in self.files() {
            let (instance, view) = self.booted(file.source)
            let size = view.bounds.size
            for row in 0 ..< 6 {
                for column in 0 ..< 4 {
                    let point = CGPoint(x: size.width * (CGFloat(column) + 0.5) / 4.0, y: size.height * (CGFloat(row) + 0.5) / 6.0)
                    instance.touch(action: 0, at: point, pointer: 0, primary: true)
                    instance.touch(action: 2, at: point, pointer: 0, primary: true)
                }
            }
            for _ in 0 ..< 12 {
                self.pump(0.1)
                self.deliverFrame(instance)
            }
            if instance.deadReason != nil {
                stopped.insert(file.path)
            }
            rows.append((file.path, instance.parseWorkForTesting, instance.bootWorkForTesting, instance.largestTaskWorkForTesting))
            instance.destroy()
        }
        rows.sort { max(Double($0.boot) / Double(MessageWidgetCore.bootWorkUnits), Double($0.later) / Double(MessageWidgetCore.taskWorkUnits)) > max(Double($1.boot) / Double(MessageWidgetCore.bootWorkUnits), Double($1.later) / Double(MessageWidgetCore.taskWorkUnits)) }
        print("units of work: parse (not charged), boot (budget \(MessageWidgetCore.bootWorkUnits)), largest later task (budget \(MessageWidgetCore.taskWorkUnits))")
        for row in rows {
            print(String(format: "%-64@ parse %11llu   boot %11llu %6.1f%%   later %11llu %6.1f%%", row.path as NSString, row.parse, row.boot, 100.0 * Double(row.boot) / Double(MessageWidgetCore.bootWorkUnits), row.later, 100.0 * Double(row.later) / Double(MessageWidgetCore.taskWorkUnits)))
        }
        XCTAssertEqual(stopped, CorpusTests.runaways)
        for row in rows where !CorpusTests.runaways.contains(row.path) && !CorpusTests.attackDemos.contains(row.path) {
            XCTAssertLessThan(row.boot, MessageWidgetCore.bootWorkUnits / 4, "\(row.path): its boot did \(row.boot) units")
            XCTAssertLessThan(row.later, MessageWidgetCore.taskWorkUnits / 4, "\(row.path): a later task did \(row.later) units")
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
                    let (units, step) = instance.onCoreForTesting { ($0.lastTaskWork, $0.lastStepMilliseconds) } ?? (0, 0)
                    print(String(format: "poll row %d column %d %@: %.1f ms, %llu units, step %.1f ms", row, column, action == 0 ? "down" : "up", ms, units, step))
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

    /// The user, 2026-10-15: the parse of a widget's markup is not charged at all. What it costs per byte of source, in
    /// every folder, `attacks` included (on the default budgets: only the parse is read, and it is not charged).
    func testWhatTheParseCostsPerByte() throws {
        var all: [(path: String, units: UInt64, bytes: Int)] = []
        for folder in WidgetCorpus.folders {
            var rows: [(path: String, units: UInt64, bytes: Int)] = []
            for file in WidgetCorpus.files(in: folder) {
                let instance = self.make(file.source)
                _ = instance.layout(width: 360.0)
                rows.append((file.path, instance.parseWorkForTesting, file.source.utf8.count))
                instance.destroy()
            }
            let perByte = rows.map { Double($0.units) / Double(max($0.bytes, 1)) }.sorted()
            print(String(format: "parse %-20@ files %3d   units/byte median %6.1f max %6.1f   units max %11llu", folder as NSString, rows.count, perByte[perByte.count / 2], perByte.last ?? 0, rows.map(\.units).max() ?? 0))
            all.append(contentsOf: rows)
        }
        for row in all.sorted(by: { Double($0.units) / Double(max($0.bytes, 1)) > Double($1.units) / Double(max($1.bytes, 1)) }).prefix(12) {
            print(String(format: "parse %-64@ %11llu units %7d bytes %7.1f units/byte", row.path as NSString, row.units, row.bytes, Double(row.units) / Double(max(row.bytes, 1))))
        }
    }
}
