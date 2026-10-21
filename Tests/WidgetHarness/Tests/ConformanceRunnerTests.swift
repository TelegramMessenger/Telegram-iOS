import XCTest
import UIKit
@testable import WidgetHarnessLib

/// Tier 1: the conformance runner (widget-sandbox v0.1.0, `conformance/CLIENTS.md`) loads a widget through the app's
/// widget path and reads the result its harness publishes on `<html data-conformance>`. Fixtures stand in for the auto
/// set's widgets: one that publishes, one whose harness throws before it can.
final class ConformanceRunnerTests: XCTestCase {
    private func runner() throws -> ConformanceRunner {
        let root = try XCTUnwrap(AppDelegate.widgetHarnessRootViewController)
        return ConformanceRunner(host: root.view)
    }

    private func fixture(_ name: String, actions: [[String: Any]] = []) throws -> ConformanceTest {
        let url = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("Fixtures/Conformance/\(name).html"))
        return ConformanceTest(id: "fixture/\(name)", fileURL: url, themes: ["light"], actions: actions, stages: [], host: [])
    }

    func testTheManifestLoadsTheAutomaticSet() throws {
        let tests = try ConformanceManifest.loadAutomaticSet()
        XCTAssertEqual(tests.count, 38)
        XCTAssertEqual(tests.reduce(0) { $0 + $1.themes.count }, 40)
        XCTAssertTrue(tests.allSatisfy { FileManager.default.fileExists(atPath: $0.fileURL.path) })
        let taps = try XCTUnwrap(tests.first { $0.id == "auto/16-sdk-taps-a" })
        XCTAssertEqual(taps.actions.count, 3)
        XCTAssertEqual(taps.host.first?.id, "tw.open-link")
        XCTAssertEqual(taps.host.first?.bridge?.count, 1)
        XCTAssertEqual(taps.host.first?.gesture, true)
        // Host checks without a bridge call: the bubble's height and the chat input's focus.
        let behaviour = try XCTUnwrap(tests.first { $0.id == "auto/20-client-behaviour" }?.host.first)
        XCTAssertEqual(behaviour.id, "behaviour.auto-height")
        XCTAssertNil(behaviour.bridge)
        XCTAssertEqual(behaviour.minHeight, 599.0)
        XCTAssertEqual(behaviour.maxHeight, 601.0)
        let focus = try XCTUnwrap(tests.first { $0.id == "auto/21-no-keyboard" }?.host.first { $0.id == "js.focus" })
        XCTAssertTrue(focus.focusChat)
    }

    func testAWidgetThatPublishesIsRead() throws {
        let run = try self.runner().run(self.fixture("conformance-done"), theme: "light", timeout: 5.0)
        XCTAssertTrue(run.loaded)
        XCTAssertNil(run.dead)
        XCTAssertEqual(run.status, "done")
        XCTAssertEqual(run.checks, [["css.display.block", "a block is a block", "pass", ""], ["css.display.flex", "flex", "fail", "why"]])
        // CLIENTS.md step 2: the chat input (a stand-in field) has the focus before loading, and keeps it.
        XCTAssertTrue(run.observed.chatFocused)
    }

    func testAWidgetThatNeverPublishesIsRecorded() throws {
        let started = Date()
        let run = try self.runner().run(self.fixture("conformance-throws"), theme: "light", timeout: 1.0)
        XCTAssertLessThan(Date().timeIntervalSince(started), 3.0)
        XCTAssertTrue(run.loaded)
        XCTAssertNil(run.dead)
        XCTAssertNil(run.status)
        XCTAssertTrue(run.checks.isEmpty)
        XCTAssertTrue(run.errors.contains { $0.contains("getComputedStyleThatDoesNotExist") }, "\(run.errors)")
    }

    /// CLIENTS.md step 6: a scripted tap lands at the centre of the target the widget published, through the widget's
    /// own touch path, and carries the tap's permission (its openLink reaches the host).
    func testAScriptedTapReachesTheWidget() throws {
        let run = try self.runner().run(self.fixture("conformance-tap", actions: [["tap": "button"]]), theme: "light", timeout: 5.0)
        XCTAssertEqual(run.status, "done")
        XCTAssertEqual(run.checks, [["tw.open-link", "a tap clicks the button", "pass", ""]])
        XCTAssertEqual(run.observed.bridge, [ConformanceRun.BridgeCall(method: "openLink", args: ["https://example.org/conformance/tap"])])
        XCTAssertFalse(run.observed.syntheticInput)
        XCTAssertEqual(run.skippedActions, [])
    }

    /// An action the runner cannot perform for real is reported as not performed, never as done: hover (a touch
    /// platform), a key (no keyboard, D4), a double tap (the bubble's). `wait` is performed.
    func testActionsTheRunnerCannotPerformAreSkipped() throws {
        let actions: [[String: Any]] = [["hover": "button"], ["key": "Enter"], ["dblclick": "button"], ["wait": 10]]
        let run = try self.runner().run(self.fixture("conformance-tap", actions: actions), theme: "light", timeout: 3.0)
        XCTAssertEqual(run.skippedActions, [0, 1, 2])
        XCTAssertEqual(run.status, "awaiting")
        XCTAssertEqual(run.observed.bridge, [])
    }

    /// A target the widget never published is the widget's failure, not input the runner cannot deliver: skipping it
    /// would report its checks as not applicable.
    func testATargetTheWidgetNeverPublishedIsAnErrorNotASkip() throws {
        let run = try self.runner().run(self.fixture("conformance-tap", actions: [["tap": "nope"]]), theme: "light", timeout: 3.0)
        XCTAssertEqual(run.skippedActions, [])
        XCTAssertTrue(run.errors.contains { $0.contains("nope") }, "\(run.errors)")
    }
}
