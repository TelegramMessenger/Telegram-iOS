import XCTest
import UIKit
import MessageWidget
import MessageWidgetStress
@testable import WidgetHarnessLib

/// widget-sandbox v0.3.0's stress kit runner (MessageWidgetStress, packages/stress CLIENTS.md), a smoke run of a few of
/// its widgets with short windows: the run file has run.schema.json's shape and what each widget measured, and the
/// production pass stops a level past a strict cap with upstream's reason.
final class WidgetHarnessStressTests: XCTestCase {
    private func run(_ pass: MessageWidgetStressRunner.Pass, ids: Set<String>) throws -> [String: Any] {
        let root = try XCTUnwrap(AppDelegate.widgetHarnessRootViewController)
        let kitRoot = try XCTUnwrap(Bundle.main.url(forResource: "WidgetStress", withExtension: "bundle").flatMap(Bundle.init(url:))?.resourceURL)
        let kit = try MessageWidgetStressKit(root: kitRoot)
        XCTAssertEqual(kit.entries.count, 127)
        let host = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 400.0))
        root.view.addSubview(host)
        defer {
            host.removeFromSuperview()
        }
        var options = MessageWidgetStressRunner.Options(pass: pass)
        options.warmupMs = 300.0
        options.measureMs = 1200.0
        options.pauseMs = 100.0
        options.cooldownMs = 100.0
        options.include = { ids.contains($0.id) }
        let runner = MessageWidgetStressRunner(kit: kit, host: host, options: options)
        var result: Data?
        runner.start { result = $0 }
        let deadline = Date(timeIntervalSinceNow: 60.0)
        while result == nil && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        let data = try XCTUnwrap(result, "the run did not finish")
        return try XCTUnwrap((try JSONSerialization.jsonObject(with: data)) as? [String: Any])
    }

    /// CLIENTS.md measures frames against `UIScreen.maximumFramesPerSecond`, so the display link must run at it: on a
    /// ProMotion iPhone a link left at its default, or an app without `CADisableMinimumFrameDurationOnPhone`, runs at
    /// 60 Hz, and every interval would count as a dropped frame at 120.
    func testTheFramesAreTakenAtTheDisplaysRate() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CADisableMinimumFrameDurationOnPhone") as? Bool, true)
        let rate = Float(UIScreen.main.maximumFramesPerSecond)
        let range = MessageWidgetStressRunner.frameRateRange(screen: UIScreen.main)
        XCTAssertEqual(range.minimum, rate)
        XCTAssertEqual(range.maximum, rate)
        XCTAssertEqual(range.preferred, rate)
    }

    func testAMeasureRunWritesTheRunFile() throws {
        let file = try self.run(.measure, ids: ["dom-static/100", "canvas-cmds/200"])
        XCTAssertEqual(file["platform"] as? String, "ios")
        XCTAssertEqual(file["rendererKind"] as? String, "own")
        XCTAssertEqual(file["pass"] as? String, "measure")
        XCTAssertEqual(file["framework"] as? String, "v0.5.0")
        XCTAssertNotNil(file["device"] as? [String: Any])
        let applied = (file["config"] as? [String: Any])?["applied"] as? [String: Any]
        XCTAssertEqual(applied?["policy"] as? String, "compat")
        // CLIENTS.md's measure pass: the quotas out of the way, as requested.
        XCTAssertEqual((applied?["cpuQuotaMs"] as? NSNumber)?.doubleValue, 10000.0)
        XCTAssertEqual((applied?["mainThreadQuotaMs"] as? NSNumber)?.doubleValue, 10000.0)
        let runs = try XCTUnwrap(file["runs"] as? [[String: Any]])
        XCTAssertEqual(runs.map { $0["id"] as? String }, ["dom-static/100", "canvas-cmds/200"])
        for run in runs {
            let id = run["id"] as? String ?? "?"
            XCTAssertEqual(run["loaded"] as? Bool, true, id)
            XCTAssertTrue(run["dead"] is NSNull, id)
            XCTAssertGreaterThan(((run["frames"] as? [String: Any])?["count"] as? Int) ?? 0, 0, id)
            XCTAssertGreaterThan(((run["widget"] as? [String: Any])?["fps"] as? Double) ?? 0.0, 0.0, id)
            XCTAssertGreaterThan(((run["host"] as? [String: Any])?["nodes"] as? Int) ?? 0, 0, id)
            XCTAssertNotNil((run["renderer"] as? [String: Any])?["msPerFrame"] as? Double, id)
        }
    }

    func testAProductionRunStopsALevelPastAStrictCap() throws {
        let file = try self.run(.production, ids: ["css-rules/800"])
        let applied = (file["config"] as? [String: Any])?["applied"] as? [String: Any]
        XCTAssertEqual((applied?["cpuQuotaMs"] as? NSNumber)?.doubleValue, 300.0)
        XCTAssertEqual((applied?["mainThreadQuotaMs"] as? NSNumber)?.doubleValue, 100.0)
        let run = try XCTUnwrap((file["runs"] as? [[String: Any]])?.first)
        XCTAssertTrue((run["dead"] as? String)?.hasPrefix("CSS limit exceeded") ?? false, "\(run["dead"] ?? "nil")")
    }
}
