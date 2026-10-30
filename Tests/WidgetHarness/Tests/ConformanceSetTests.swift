import XCTest
import UIKit
@testable import WidgetHarnessLib

/// Tier 1: widget-sandbox v0.1.1's automatic conformance set, every test in every theme its manifest lists, through the
/// app's widget path (`conformance/CLIENTS.md`), then the visual set, loaded only. Writes the run file, the crops and the new baseline into the test's
/// undeclared outputs, then fails on a regression against the committed baseline, or on an improvement not yet
/// recorded (`Tools/conformance_report.sh --record`).
final class ConformanceSetTests: XCTestCase {
    func testTheAutomaticSet() throws {
        let root = try XCTUnwrap(AppDelegate.widgetHarnessRootViewController)
        let deadline = Date(timeIntervalSinceNow: 30.0)
        while root.listHost == nil && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        // An empty list, so the harness's own widgets do not run beside the set's.
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "no post matches this"
        root.reload(options: options)

        let tests = try ConformanceManifest.loadAutomaticSet() + ConformanceManifest.loadVisualSet()
        let runs = ConformanceRunner(host: root.view).runAll(tests)
        let pairs = zip(tests.flatMap { test in test.themes.map { _ in test } }, runs).map { (test: $0.0, run: $0.1) }
        XCTAssertEqual(runs.count, 113)

        let outputs = URL(fileURLWithPath: ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] ?? NSTemporaryDirectory()).appendingPathComponent("conformance", isDirectory: true)
        try? FileManager.default.removeItem(at: outputs)
        try FileManager.default.createDirectory(at: outputs.appendingPathComponent("crops", isDirectory: true), withIntermediateDirectories: true)
        var crops: [String: [String: String]] = [:]
        for pair in pairs {
            for (stage, png) in pair.run.crops {
                let path = "crops/\(pair.test.baseName).\(pair.run.theme).\(stage).png"
                try png.write(to: outputs.appendingPathComponent(path))
                crops[pair.run.key, default: [:]][stage] = path
            }
        }
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"].map { "\($0) simulator" } ?? UIDevice.current.model
        let engine = "iOS \(UIDevice.current.systemVersion), \(model)"
        try ConformanceRunFile.encode(runs: runs, crops: crops, engine: engine, date: Date()).write(to: outputs.appendingPathComponent("\(ConformanceRunFile.platform)-\(ConformanceRunFile.renderer).json"))
        let current = ConformanceBaseline.record(pairs)
        try current.encoded().write(to: outputs.appendingPathComponent("baseline.new.json"))

        let published = runs.filter { $0.status != nil }.count
        let done = runs.filter { $0.status == "done" }.count
        print("CONFORMANCE runs \(runs.count), published \(published), done \(done), statuses \(current.counts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))")

        let recorded = Bundle.main.url(forResource: "baseline", withExtension: "json", subdirectory: "Conformance")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? ConformanceBaseline.decode($0) } ?? ConformanceBaseline(runs: [:])
        let comparison = recorded.compare(current)
        XCTAssertEqual(comparison.regressions, [], "checks that passed and no longer do")
        XCTAssertEqual(comparison.improvements, [], "checks that pass now: record them with Tests/WidgetHarness/Tools/conformance_report.sh --record")
        XCTAssertEqual(comparison.retired, [], "checks the manifest no longer has (an upstream rename): record them away with Tests/WidgetHarness/Tools/conformance_report.sh --record")
    }
}
