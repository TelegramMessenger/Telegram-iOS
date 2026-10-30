import Foundation

/// Every check's status per run, committed (`Tests/WidgetHarness/Conformance/baseline.json`), which makes the conformance
/// set a ratchet: a check that passed and no longer does is a regression; a check that passes now and did not is an
/// improvement, which must be recorded (`conformance_report.sh --record`) so the baseline never drifts silently.
public struct ConformanceBaseline: Codable, Equatable {
    /// Statuses that count as passing (`xpass`: expected to fail, passed).
    public static let passing: Set<String> = ["pass", "xpass"]
    /// The status of an expected check its run never published.
    public static let missing = "missing"

    /// Run key (`"<id>/<theme>"`) → check key (`"<catalogue id> · <name>"`) → status.
    public var runs: [String: [String: String]]

    public init(runs: [String: [String: String]]) {
        self.runs = runs
    }

    /// The run's statuses, judged as report.mjs judges them (a load-only run: whether it loaded): what it published, `missing` for every check the manifest
    /// expects that it did not, `skip` for every check an action the runner could not perform feeds (the action's `ids`),
    /// `fail` for every check a run that did not load or was stopped published (`harness` checks aside), and the
    /// manifest's host checks (`"host · <id> · <name>"`) from what the host saw.
    public static func statuses(of run: ConformanceRun, test: ConformanceTest) -> [String: String] {
        let failed = !run.loaded || run.dead != nil
        // A visual widget, run to see that it loads.
        if test.loadOnly {
            return ["load · loads": failed ? "fail" : "pass"]
        }
        // widget-sandbox v0.3.0: a test the host must stop passes each of its covers only on a stop whose reason starts
        // with `stops`, and fails on any other end, alive or dead; what it published is not judged (report.mjs).
        if let stops = test.stops {
            let stopped = run.dead?.hasPrefix(stops) ?? false
            var statuses: [String: String] = [:]
            for id in test.covers {
                statuses["\(id) · stopped with \"\(stops)…\""] = stopped ? "pass" : "fail"
            }
            return statuses
        }
        var skipped = Set<String>()
        for index in run.skippedActions where index < test.actions.count {
            for id in (test.actions[index]["ids"] as? [String]) ?? [] {
                skipped.insert(id)
            }
        }
        var statuses: [String: String] = [:]
        for check in test.expectedChecks {
            statuses["\(check.id) · \(check.name)"] = skipped.contains(check.id) ? "skip" : ConformanceBaseline.missing
        }
        for check in run.checks where check.count >= 3 {
            let key = "\(check[0]) · \(check[1])"
            if failed && check[0] != "harness" {
                statuses[key] = "fail"
            } else if skipped.contains(check[0]) {
                statuses[key] = "skip"
            } else if statuses[key] == nil || statuses[key] == ConformanceBaseline.missing {
                statuses[key] = check[2]
            }
        }
        for check in test.host {
            statuses["host · \(check.id) · \(check.name)"] = self.status(of: check, observed: run.observed)
        }
        return statuses
    }

    /// report.mjs `hostChecks`. The runner always observes the height and the focus, so neither is ever skipped here.
    static func status(of check: ConformanceHostCheck, observed: ConformanceRun.Observed) -> String {
        if check.gesture && observed.syntheticInput {
            return "skip"
        }
        var ok = true
        if let bridge = check.bridge {
            let calls = observed.bridge.filter { $0.method == bridge.method && (bridge.argument == nil || $0.args.first == bridge.argument) }
            ok = ok && calls.count == bridge.count
        }
        if check.minHeight != nil || check.maxHeight != nil {
            ok = ok && observed.height >= (check.minHeight ?? -Double.infinity) && observed.height <= (check.maxHeight ?? Double.infinity)
        }
        if check.focusChat {
            ok = ok && observed.chatFocused
        }
        if check.xfail {
            return ok ? "xpass" : "xfail"
        }
        return ok ? "pass" : "fail"
    }

    /// The baseline of a whole run of the set.
    public static func record(_ results: [(test: ConformanceTest, run: ConformanceRun)]) -> ConformanceBaseline {
        var runs: [String: [String: String]] = [:]
        for result in results {
            runs[result.run.key] = ConformanceBaseline.statuses(of: result.run, test: result.test)
        }
        return ConformanceBaseline(runs: runs)
    }

    /// Against `current`: regressions (passing here, not there; a run gone counts as `missing`), improvements (passing
    /// there, not here), each `"<run> <check>: <was> → <is>"`, and the retired checks (`"<run> <check>"`): a recorded
    /// check of a run `current` has that `current` does not list at all. `statuses` lists every check the manifest
    /// expects (`missing` at worst), so such a check is one the manifest no longer has (an upstream tag renamed or removed
    /// it), not one the widget stopped publishing. All sorted.
    public func compare(_ current: ConformanceBaseline) -> (regressions: [String], improvements: [String], retired: [String]) {
        var regressions: [String] = []
        var improvements: [String] = []
        var retired: [String] = []
        for (run, checks) in self.runs {
            for (check, was) in checks where ConformanceBaseline.passing.contains(was) {
                if let now = current.runs[run], now[check] == nil {
                    retired.append("\(run) \(check)")
                    continue
                }
                let now = current.runs[run]?[check] ?? ConformanceBaseline.missing
                if !ConformanceBaseline.passing.contains(now) {
                    regressions.append("\(run) \(check): \(was) → \(now)")
                }
            }
        }
        for (run, checks) in current.runs {
            for (check, now) in checks where ConformanceBaseline.passing.contains(now) {
                let was = self.runs[run]?[check] ?? ConformanceBaseline.missing
                if !ConformanceBaseline.passing.contains(was) {
                    improvements.append("\(run) \(check): \(was) → \(now)")
                }
            }
        }
        return (regressions.sorted(), improvements.sorted(), retired.sorted())
    }

    /// Counts per status over every run, for the ledger and the test's print-out.
    public var counts: [String: Int] {
        var counts: [String: Int] = [:]
        for (_, checks) in self.runs {
            for (_, status) in checks {
                counts[status, default: 0] += 1
            }
        }
        return counts
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> ConformanceBaseline {
        return try JSONDecoder().decode(ConformanceBaseline.self, from: data)
    }
}
