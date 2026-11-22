import XCTest
import UIKit
@testable import WidgetHarnessLib

/// Tier 1: what the conformance runner writes (widget-sandbox v0.1.0 `run.schema.json`) and the committed baseline
/// that makes the set a ratchet: a check that passed and no longer does fails the run, and so does a new pass until it
/// is recorded.
final class ConformanceRecordTests: XCTestCase {
    private func run(_ id: String, checks: [[String]], loaded: Bool = true) -> ConformanceRun {
        var run = ConformanceRun(id: id, theme: "light", width: 390.0)
        run.loaded = loaded
        run.status = checks.isEmpty ? nil : "done"
        run.checks = checks
        run.observed.height = 120.0
        run.observed.chatFocused = true
        run.observed.bridge = [ConformanceRun.BridgeCall(method: "openLink", args: ["https://example.org/conformance/tap"])]
        run.errors = checks.isEmpty ? ["Uncaught ReferenceError: getComputedStyle is not defined"] : []
        return run
    }

    private func object(_ data: Data) throws -> [String: Any] {
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testTheRunFileHasTheSchemasShape() throws {
        let published = self.run("auto/a", checks: [["css.display.flex", "row places children side by side", "pass", ""]])
        let silent = self.run("auto/b", checks: [])
        let data = try ConformanceRunFile.encode(runs: [published, silent], crops: ["auto/a/light": ["flex": "crops/a.light.flex.png"]], engine: "iOS 26.5, iPhone 17", date: Date(timeIntervalSince1970: 0))
        let file = try self.object(data)
        XCTAssertEqual(Set(file.keys), ["platform", "renderer", "engine", "framework", "commit", "policy", "features", "date", "runs"])
        XCTAssertEqual(file["platform"] as? String, "ios")
        XCTAssertEqual(file["renderer"] as? String, "telegram-native")
        XCTAssertEqual(file["framework"] as? String, "v0.5.0")
        XCTAssertEqual(file["policy"] as? String, "strict")
        XCTAssertEqual(file["features"] as? [String], ["webAnimations"])
        let runs = try XCTUnwrap(file["runs"] as? [[String: Any]])
        XCTAssertEqual(runs.count, 2)
        XCTAssertEqual(Set(runs[0].keys), ["id", "theme", "width", "loaded", "dead", "status", "checks", "stages", "observed", "skippedActions", "errors"])
        XCTAssertEqual(runs[0]["checks"] as? [[String]], [["css.display.flex", "row places children side by side", "pass", ""]])
        XCTAssertEqual((runs[0]["stages"] as? [[String: String]]) ?? [], [["name": "flex", "crop": "crops/a.light.flex.png"]])
        let observed = try XCTUnwrap(runs[0]["observed"] as? [String: Any])
        XCTAssertEqual(Set(observed.keys), ["bridge", "height", "chatFocused", "syntheticInput"])
        let bridge = try XCTUnwrap(observed["bridge"] as? [[String: Any]])
        XCTAssertEqual(bridge.first?["method"] as? String, "openLink")
        XCTAssertEqual(bridge.first?["args"] as? [String], ["https://example.org/conformance/tap"])
        // A run that never published: no status, its checks empty, its error kept, `dead` an explicit null.
        XCTAssertTrue(runs[1]["status"] is NSNull)
        XCTAssertTrue(runs[1]["dead"] is NSNull)
        XCTAssertEqual(runs[1]["checks"] as? [[String]], [])
        XCTAssertEqual(runs[1]["errors"] as? [String], ["Uncaught ReferenceError: getComputedStyle is not defined"])
    }

    private let expected = [ConformanceCheck(id: "css.a", name: "A"), ConformanceCheck(id: "css.b", name: "B")]

    private func test(actions: [[String: Any]] = [], host: [ConformanceHostCheck] = []) -> ConformanceTest {
        return ConformanceTest(id: "auto/x", fileURL: URL(fileURLWithPath: "/x.html"), themes: ["light"], actions: actions, stages: [], host: host, expectedChecks: self.expected)
    }

    /// widget-sandbox v0.3.0 (report.mjs): a test with `stops` passes its covers only when the host stopped it with a
    /// reason that starts with `stops`; not stopped, or stopped for another reason, it fails them.
    func testAStopTestPassesOnlyOnItsStop() {
        let test = ConformanceTest(id: "auto/31-stop-text", fileURL: URL(fileURLWithPath: "/x.html"), themes: ["light"], actions: [], stages: [], host: [], expectedChecks: [ConformanceCheck(id: "limit.text-node", name: "stops")], stops: "Text limit exceeded", covers: ["limit.text-node"])
        let key = "limit.text-node · stopped with \"Text limit exceeded…\""
        var run = self.run("auto/31-stop-text", checks: [["limit.text-node", "stops", "pass", ""]])
        run.dead = "Text limit exceeded: a text value of 40000 characters (max 32768)"
        XCTAssertEqual(ConformanceBaseline.statuses(of: run, test: test), [key: "pass"])
        run.dead = "CPU limit exceeded: more than 500 ms of continuous execution (event)"
        XCTAssertEqual(ConformanceBaseline.statuses(of: run, test: test), [key: "fail"])
        run.dead = nil
        XCTAssertEqual(ConformanceBaseline.statuses(of: run, test: test), [key: "fail"])
    }

    func testAnUnpublishedRunReportsEveryExpectedCheck() {
        let statuses = ConformanceBaseline.statuses(of: self.run("auto/x", checks: []), test: self.test())
        XCTAssertEqual(statuses, ["css.a · A": "missing", "css.b · B": "missing"])
    }

    /// report.mjs: the checks an action feeds (its `ids`) are not judged when the runner could not perform it, whatever
    /// the widget published for them; an expected check of that action it never published is not judged either.
    func testTheChecksOfASkippedActionAreSkipped() {
        var run = self.run("auto/x", checks: [["css.a", "A", "pass", ""], ["css.c", "C", "pass", ""]])
        run.skippedActions = [1]
        // Action 0 was performed: the check it feeds keeps what the widget published.
        let test = self.test(actions: [["tap": "t", "ids": ["css.c"]], ["hover": "h", "ids": ["css.a", "css.b"]]])
        XCTAssertEqual(ConformanceBaseline.statuses(of: run, test: test), ["css.a · A": "skip", "css.b · B": "skip", "css.c · C": "pass"])
    }

    /// report.mjs: a run that did not load, or that the runtime stopped, fails every check it published (after the skip
    /// mapping, so a skipped one too; `harness` checks aside); its host checks are judged as usual, and the expected
    /// checks it never published stay missing.
    func testADeadRunFailsWhatItPublished() {
        var run = self.run("auto/x", checks: [["css.a", "A", "pass", ""], ["css.c", "C", "pass", ""], ["harness", "step", "pass", ""]])
        run.dead = "CPU limit exceeded"
        run.skippedActions = [0]
        let host = [ConformanceHostCheck(id: "h.once", name: "once", bridge: .init(method: "openLink", argument: "https://example.org/conformance/tap", count: 1))]
        let statuses = ConformanceBaseline.statuses(of: run, test: self.test(actions: [["hover": "h", "ids": ["css.c"]]], host: host))
        XCTAssertEqual(statuses, [
            "css.a · A": "fail", "css.b · B": "missing", "css.c · C": "fail", "harness · step": "pass", "host · h.once · once": "pass",
        ])
        var unloaded = self.run("auto/x", checks: [["css.a", "A", "pass", ""]])
        unloaded.loaded = false
        XCTAssertEqual(ConformanceBaseline.statuses(of: unloaded, test: self.test())["css.a · A"], "fail")
    }

    /// report.mjs `hostChecks`, from what the host saw: a bridge call matched on method and first argument, counted
    /// exactly; the bubble's height in range; the chat input keeping the focus; a gesture check under synthetic input is
    /// not judged; an expected failure is xfail or xpass.
    func testTheHostChecksAreJudgedFromWhatTheHostSaw() {
        var run = self.run("auto/x", checks: [])
        run.observed.bridge = [ConformanceRun.BridgeCall(method: "openLink", args: ["https://a"]), ConformanceRun.BridgeCall(method: "haptic", args: []), ConformanceRun.BridgeCall(method: "haptic", args: [])]
        run.observed.height = 600.0
        run.observed.chatFocused = false
        let host = [
            ConformanceHostCheck(id: "h.once", name: "once", bridge: .init(method: "openLink", argument: "https://a", count: 1)),
            ConformanceHostCheck(id: "h.never", name: "never", bridge: .init(method: "openLink", argument: "https://b", count: 0)),
            ConformanceHostCheck(id: "h.rate", name: "rate", bridge: .init(method: "haptic", argument: nil, count: 5)),
            ConformanceHostCheck(id: "h.height", name: "height", minHeight: 599.0, maxHeight: 601.0),
            ConformanceHostCheck(id: "h.short", name: "short", maxHeight: 300.0),
            ConformanceHostCheck(id: "h.focus", name: "focus", focusChat: true),
            ConformanceHostCheck(id: "h.xfail", name: "xfail", bridge: .init(method: "haptic", argument: nil, count: 2), xfail: true),
        ]
        let statuses = ConformanceBaseline.statuses(of: run, test: self.test(host: host)).filter { $0.key.hasPrefix("host · ") }
        XCTAssertEqual(statuses, [
            "host · h.once · once": "pass", "host · h.never · never": "pass", "host · h.rate · rate": "fail",
            "host · h.height · height": "pass", "host · h.short · short": "fail", "host · h.focus · focus": "fail",
            "host · h.xfail · xfail": "xpass",
        ])
        run.observed.syntheticInput = true
        let gesture = [ConformanceHostCheck(id: "h.tap", name: "tap", bridge: .init(method: "openLink", argument: "https://a", count: 1), gesture: true)]
        XCTAssertEqual(ConformanceBaseline.statuses(of: run, test: self.test(host: gesture))["host · h.tap · tap"], "skip")
    }

    func testARegressionIsNamed() {
        let baseline = ConformanceBaseline(runs: ["auto/x/light": ["css.a · A": "pass", "css.b · B": "fail"]])
        let current = ConformanceBaseline(runs: ["auto/x/light": ["css.a · A": "fail", "css.b · B": "fail"]])
        let result = baseline.compare(current)
        XCTAssertEqual(result.regressions, ["auto/x/light css.a · A: pass → fail"])
        XCTAssertEqual(result.improvements, [])
    }

    func testAnImprovementMustBeRecorded() {
        let baseline = ConformanceBaseline(runs: ["auto/x/light": ["css.a · A": "missing"]])
        let current = ConformanceBaseline(runs: ["auto/x/light": ["css.a · A": "pass"]])
        let result = baseline.compare(current)
        XCTAssertEqual(result.regressions, [])
        XCTAssertEqual(result.improvements, ["auto/x/light css.a · A: missing → pass"])
    }

    func testAMissingRunIsARegression() {
        let baseline = ConformanceBaseline(runs: ["auto/x/light": ["css.a · A": "pass"], "auto/y/light": ["css.b · B": "xpass"]])
        let current = ConformanceBaseline(runs: ["auto/y/light": ["css.b · B": "xpass"]])
        XCTAssertEqual(baseline.compare(current).regressions, ["auto/x/light css.a · A: pass → missing"])
    }

    /// A tag that renames a check: the old name is neither expected by the manifest nor published (`statuses` lists every
    /// expected check, `missing` at worst), so it is retired, not a regression; a run that is gone still is one.
    func testACheckTheManifestNoLongerHasIsRetired() {
        let baseline = ConformanceBaseline(runs: ["auto/x/light": ["css.a · old name": "pass", "css.b · B": "pass"]])
        let current = ConformanceBaseline(runs: ["auto/x/light": ["css.a · new name": "pass", "css.b · B": "missing"]])
        let result = baseline.compare(current)
        XCTAssertEqual(result.regressions, ["auto/x/light css.b · B: pass → missing"])
        XCTAssertEqual(result.improvements, ["auto/x/light css.a · new name: missing → pass"])
        XCTAssertEqual(result.retired, ["auto/x/light css.a · old name"])
    }

    func testTheBaselineRoundTrips() throws {
        let baseline = ConformanceBaseline(runs: ["auto/x/light": ["css.a · A": "pass"]])
        let data = try baseline.encoded()
        XCTAssertEqual(try ConformanceBaseline.decode(data), baseline)
    }
}
