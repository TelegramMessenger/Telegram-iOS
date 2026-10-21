import XCTest
import UIKit
@testable import WidgetHarnessLib

/// Tier 1 (in the app process): the widget bubble's size from its anchors, the fallback pill, the hard clip and the
/// per-message height cache, through the REAL chat bubbles (widget-sandbox v0.1.0, integration.md "Bubble sizing").
final class WidgetHarnessSizingTests: XCTestCase {
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

    /// Reloads with `options` and waits until `ready` holds for the readout's bubble lines.
    private func load(_ options: WidgetHarnessLaunchOptions, until ready: ([String]) -> Bool) throws -> [String] {
        let root = try self.root()
        root.reload(options: options)
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

    /// `bubble <i> <path> <w>x<h> @<x>,<y> <state>[ +caption]` → its fields.
    private func parse(_ line: String) -> (path: String, width: Int, height: Int, state: String, caption: Bool) {
        let parts = line.split(separator: " ").map(String.init)
        let size = parts[3].split(separator: "x").compactMap { Int($0) }
        return (parts[2], size[0], size[1], parts[5], parts.count > 6 && parts[6] == "+caption")
    }

    /// The bubble line nearest the screen's centre whose path contains `part`, once `ready` holds for it.
    private func centredBubble(_ root: WidgetHarnessRootViewController, _ part: String, until ready: (String) -> Bool) -> String? {
        let deadline = Date(timeIntervalSinceNow: 20.0)
        var best: String?
        while Date() < deadline {
            root.view.layoutIfNeeded()
            let centre = root.view.bounds.midY
            best = root.readoutLines().filter { $0.hasPrefix("bubble ") && $0.contains(part) }.min(by: { a, b in
                abs(self.centreY(a) - centre) < abs(self.centreY(b) - centre)
            })
            if let best, ready(best) {
                return best
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return best
    }

    private func centreY(_ line: String) -> CGFloat {
        guard let at = line.split(separator: " ").first(where: { $0.hasPrefix("@") }) else {
            return .infinity
        }
        return CGFloat(Double(at.split(separator: ",").last ?? "") ?? .infinity)
    }

    func testTheSizeHintPostsTakeTheirAnchors() throws {
        var options = WidgetHarnessLaunchOptions()
        options.set = .conformance
        options.postFilter = "17-size-hint"
        let root = try self.root()
        _ = try self.load(options, until: { lines in !lines.isEmpty })
        let host = try XCTUnwrap(root.listHost)
        let indices = host.messageIndices(pathContaining: "17-size-hint")
        XCTAssertEqual(indices.count, 4)
        // channel.json posts it at (0,0), (0,300), (300,0), (300,300): auto heights settle at the reported 240.
        let expectedHeights = [240, 300, 240, 300]
        var bubbles: [(path: String, width: Int, height: Int, state: String, caption: Bool)] = []
        for (n, index) in indices.enumerated() {
            host.scrollTo(messageIndex: index)
            let line = self.centredBubble(root, "17-size-hint", until: { line in
                line.contains(" widget") && self.parse(line).height == expectedHeights[min(n, 3)]
            })
            let bubble = try XCTUnwrap(line.map(self.parse))
            XCTAssertEqual(bubble.height, expectedHeights[min(n, 3)], line ?? "")
            bubbles.append(bubble)
        }
        guard bubbles.count == 4 else {
            return
        }
        XCTAssertEqual(bubbles[2].width, 300)
        XCTAssertEqual(bubbles[3].width, 300)
        XCTAssertGreaterThan(bubbles[0].width, 300)
        XCTAssertEqual(bubbles[0].width, bubbles[1].width)
    }

    func testTheFlagOffShowsThePillWithTheCaption() throws {
        var options = WidgetHarnessLaunchOptions()
        options.set = .conformance
        options.postFilter = "visual/01-boxes"
        options.widgetMessages = false
        let lines = try self.load(options, until: { lines in !lines.isEmpty && lines.allSatisfy { $0.contains(" pill") } })
        XCTAssertFalse(lines.isEmpty)
        for line in lines {
            let bubble = self.parse(line)
            XCTAssertEqual(bubble.state, "pill", line)
            XCTAssertTrue(bubble.caption, line)
        }
    }

    func testAFixedHeightClipsTallerContent() throws {
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "tall-box"
        options.anchors = (0, 300)
        let lines = try self.load(options, until: { lines in lines.count == 1 && lines[0].contains(" widget") })
        XCTAssertEqual(lines.count, 1)
        guard let line = lines.first else {
            return
        }
        XCTAssertEqual(self.parse(line).height, 300, line)
    }

    /// A bubble that scrolls away and back opens at its last reported height, never the 160 pt placeholder.
    func testScrollingAwayAndBackKeepsTheHeight() throws {
        var options = WidgetHarnessLaunchOptions()
        options.set = .conformance
        let root = try self.root()
        // Its boot has reported a height (until then the bubble is the 160 pt placeholder).
        let first = try self.load(options, until: { lines in lines.contains { $0.contains("auto/21-no-keyboard") && $0.contains(" widget") && !$0.contains("x160 ") } })
        let before = try XCTUnwrap(first.first { $0.contains("auto/21-no-keyboard") }.map(self.parse))
        XCTAssertNotEqual(before.height, 160)
        let host = try XCTUnwrap(root.listHost)
        host.scrollTo(messageIndex: 0)
        root.view.layoutIfNeeded()
        let farAway = root.readoutLines().filter { $0.hasPrefix("bubble ") }
        XCTAssertFalse(farAway.contains { $0.contains("auto/21-no-keyboard") }, "still on screen: \(farAway)")
        host.scrollTo(messageIndex: Int.max)
        root.view.layoutIfNeeded()
        let back = root.readoutLines().filter { $0.hasPrefix("bubble ") }
        let after = try XCTUnwrap(back.first { $0.contains("auto/21-no-keyboard") }.map(self.parse), back.joined(separator: "\n"))
        XCTAssertEqual(after.height, before.height)
    }
}
