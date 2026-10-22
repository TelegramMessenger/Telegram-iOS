import XCTest
import UIKit
import MessageWidget
@testable import WidgetHarnessLib

/// Tier 1: switching widgets off or on while a chat is open re-lays its widget bubbles out (the V1 final review's I1,
/// Review Focus 2). Seen by code reading: a bubble decided per layout pass, and nothing asked a widget whose size never
/// changes to lay out again, so a switched-off widget kept running and taking taps, and switched-on pills stayed pills.
/// In the harness because the observation lives in the real widget bubble.
final class WidgetHarnessAvailabilityTests: XCTestCase {
    private func root() throws -> WidgetHarnessRootViewController {
        let root = try XCTUnwrap(AppDelegate.widgetHarnessRootViewController)
        root.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0)
        let deadline = Date(timeIntervalSinceNow: 30.0)
        while root.listHost == nil && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertNotNil(root.listHost, "the harness account never opened")
        return root
    }

    /// The readout's bubble lines once `ready` holds for them (or after 20 s).
    private func bubbles(_ root: WidgetHarnessRootViewController, until ready: ([String]) -> Bool) -> [String] {
        let deadline = Date(timeIntervalSinceNow: 20.0)
        var lines: [String] = []
        while Date() < deadline {
            root.view.layoutIfNeeded()
            lines = root.readoutLines().filter { $0.hasPrefix("bubble ") }
            if ready(lines) {
                break
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return lines
    }

    private func liveWidgetViews(in view: UIView) -> Int {
        return (view is MessageWidgetView ? 1 : 0) + view.subviews.reduce(0) { $0 + self.liveWidgetViews(in: $1) }
    }

    private func all(_ state: String) -> ([String]) -> Bool {
        return { lines in !lines.isEmpty && lines.allSatisfy { $0.contains(" \(state)") } }
    }

    /// Widget messages are on by default (the user, 2026-10-22): with the app's own settings, no debug switch turned on,
    /// a widget runs; only the server's kill switch turns them off.
    func testWidgetsRunWithTheAppsDefaultSettings() throws {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "box-240"
        root.reload(options: options)
        let lines = self.bubbles(root, until: self.all("widget"))
        XCTAssertTrue(self.all("widget")(lines), lines.joined(separator: "\n"))
    }

    func testSwitchingWidgetsOffAndOnRelaysOutAnOpenChat() throws {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "box-240"
        root.reload(options: options)
        defer {
            MessageWidgetKillSwitch.isEngaged = false
        }
        // Settled: its boot has reported a height (no relayout of its own is still due, which would read the new flag
        // by itself) and a moment has passed.
        let settled: ([String]) -> Bool = { lines in self.all("widget")(lines) && !lines.contains { $0.contains("x160 ") } }
        XCTAssertTrue(settled(self.bubbles(root, until: settled)), "the widget never ran")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))

        // The server's kill switch engaged: the running widget stops and the pill takes its place.
        MessageWidgetKillSwitch.isEngaged = true
        let killed = self.bubbles(root, until: self.all("pill"))
        XCTAssertTrue(self.all("pill")(killed), killed.joined(separator: "\n"))
        XCTAssertEqual(self.liveWidgetViews(in: root.view), 0)

        // Released: the pill becomes the widget.
        MessageWidgetKillSwitch.isEngaged = false
        let restored = self.bubbles(root, until: self.all("widget"))
        XCTAssertTrue(self.all("widget")(restored), restored.joined(separator: "\n"))
    }
}
