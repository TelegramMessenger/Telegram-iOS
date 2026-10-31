import XCTest
import UIKit
import TelegramUIPreferences
import ChatMessageItemCommon
import MessageWidget
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
        return try self.bubbleLines(until: ready)
    }

    /// The readout's bubble lines once `ready` holds for them, or after 20 s.
    private func bubbleLines(until ready: ([String]) -> Bool) throws -> [String] {
        let root = try self.root()
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

    /// A widget message has no share button beside it and may take the chat's full width, as a channel post does (the
    /// user, 2026-10-26). A bot's incoming widget is the case that otherwise gets both the button and the narrower bubble.
    func testAWidgetBubbleHasNoShareButtonAndTheFullWidth() throws {
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "box-240"
        options.incoming = true
        options.botChat = true
        options.captions = false
        let root = try self.root()
        let lines = try self.load(options, until: { lines in lines.contains { $0.contains("box-240") && $0.contains(" widget") } })
        let line = try XCTUnwrap(lines.first { $0.contains("box-240") }, lines.joined(separator: "\n"))
        XCTAssertFalse(line.contains("+share"), line)
        // Without the full width a bubble is at most `maximumWidthFill` of the list (the list's width less 36 pt on a
        // phone), and the widget fills its bubble: a wider widget area is a full-width bubble.
        let narrowMaximum = ChatMessageItemLayoutConstants.default.bubble.maximumWidthFill.widthFor(root.view.bounds.width)
        XCTAssertGreaterThan(CGFloat(self.parse(line).width), narrowMaximum, line)
    }

    func testTheKillSwitchShowsThePillWithTheCaption() throws {
        defer {
            MessageWidgetKillSwitch.isEngaged = false
        }
        var options = WidgetHarnessLaunchOptions()
        options.set = .conformance
        options.postFilter = "visual/01-boxes"
        options.killSwitch = true
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

    /// SDK v1 §2.4 (v0.1.1): Settings ▸ Appearance ▸ Text Size reaches an open chat's widget as its font-size token, and
    /// the widget lays out again: a widget with no CSS of its own (`text.html`) grows with the chat's text.
    func testATextSizeChangeRelaysTheWidgetOut() throws {
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "text.html"
        let root = try self.root()
        let lines = try self.load(options, until: { lines in lines.count == 1 && lines[0].contains(" widget") && !lines[0].contains("x160 ") })
        let before = try XCTUnwrap(lines.first.map(self.parse), "\(lines)")
        root.setTextSize(.extraLargeX2)
        let after = try XCTUnwrap(self.centredBubble(root, "fixture/text.html", until: { self.parse($0).height > before.height }).map(self.parse))
        XCTAssertGreaterThan(after.height, before.height)
        XCTAssertEqual(after.state, "widget")
    }

    /// SDK v1 §5.1 (v0.1.1): the widget fills the bubble, with no padding of the bubble's own around it (the widget's body
    /// margin is the inset), so a background it paints reaches the bubble's edges.
    func testTheWidgetFillsItsBubble() throws {
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "box-240"
        let root = try self.root()
        _ = try self.load(options, until: { lines in lines.count == 1 && lines[0].contains(" widget") && !lines[0].contains("x160 ") })
        let areas = root.widgetAreas()
        XCTAssertEqual(areas.count, 1)
        guard let widget = areas.first else {
            return
        }
        XCTAssertEqual(widget.area, widget.content, widget.path)
    }

    /// v0.1.1 plan, Task 6 (Review Focus 3): a widget's background reaches every edge of its bubble, the tail too, as a
    /// photo fills its tail; box-240 is #33aa88 to its edges, alone in its bubble on either side.
    func testABackgroundFillsTheTail() throws {
        for incoming in [false, true] {
            var options = WidgetHarnessLaunchOptions()
            options.set = .fixture
            options.postFilter = "box-240"
            options.captions = false
            options.incoming = incoming
            let root = try self.root()
            _ = try self.load(options, until: { lines in lines.count == 1 && lines[0].contains(" widget") && !lines[0].contains("x160 ") })
            // The tiles land after the layout pass (a task of their own).
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
            let area = try XCTUnwrap(root.widgetAreas().first).area
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            // 8 bits per channel, which `pixel` reads.
            format.preferredRange = .standard
            let image = UIGraphicsImageRenderer(bounds: root.view.bounds, format: format).image { _ in
                root.view.drawHierarchy(in: root.view.bounds, afterScreenUpdates: true)
            }
            // 1 pt past the body's edge, 2 pt above its bottom: inside the tail.
            let x = incoming ? area.minX - 1.5 : area.maxX + 1.0
            let pixel = try XCTUnwrap(self.pixel(image, CGPoint(x: x, y: area.maxY - 2.0)))
            // The box's colour, not the bubble's (within the colour conversion's rounding).
            XCTAssertTrue(zip(pixel, [0x33, 0xaa, 0x88]).allSatisfy { abs($0 - $1) <= 2 }, "incoming \(incoming): \(pixel)")
        }
    }

    /// The colour at `point` (points, at the image's 1x scale), or nil outside the image.
    private func pixel(_ image: UIImage, _ point: CGPoint) -> [Int]? {
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
            return nil
        }
        let x = Int(point.x), y = Int(point.y)
        guard x >= 0, y >= 0, x < cg.width, y < cg.height else {
            return nil
        }
        let offset = y * cg.bytesPerRow + x * (cg.bitsPerPixel / 8)
        let littleEndian = cg.bitmapInfo.contains(.byteOrder32Little)
        let (r, g, b) = littleEndian ? (bytes[offset + 2], bytes[offset + 1], bytes[offset]) : (bytes[offset], bytes[offset + 1], bytes[offset + 2])
        return [Int(r), Int(g), Int(b)]
    }

    /// A bubble that scrolls away and back opens at its last reported height, never the 160 pt placeholder.
    func testScrollingAwayAndBackKeepsTheHeight() throws {
        var options = WidgetHarnessLaunchOptions()
        options.set = .conformance
        let root = try self.root()
        // The channel ends with widget-sandbox v0.3.0's auto/28–35, so auto/27 is off screen at load: go to it first.
        _ = try self.load(options, until: { lines in !lines.isEmpty })
        let host = try XCTUnwrap(root.listHost)
        host.scrollTo(messageIndex: try XCTUnwrap(host.messageIndices(pathContaining: "auto/27-haptics-no-touch").first))
        // Its boot has reported a height (until then the bubble is the 160 pt placeholder).
        let first = try self.bubbleLines(until: { lines in lines.contains { $0.contains("auto/27-haptics-no-touch") && $0.contains(" widget") && !$0.contains("x160 ") } })
        let before = try XCTUnwrap(first.first { $0.contains("auto/27-haptics-no-touch") }.map(self.parse), first.joined(separator: "\n"))
        XCTAssertNotEqual(before.height, 160)
        host.scrollTo(messageIndex: 0)
        root.view.layoutIfNeeded()
        let farAway = root.readoutLines().filter { $0.hasPrefix("bubble ") }
        XCTAssertFalse(farAway.contains { $0.contains("auto/27-haptics-no-touch") }, "still on screen: \(farAway)")
        // Back to the post itself: the channel's newest posts are no longer it (widget-sandbox v0.3.0 added auto/28–35).
        host.scrollTo(messageIndex: try XCTUnwrap(host.messageIndices(pathContaining: "auto/27-haptics-no-touch").first))
        root.view.layoutIfNeeded()
        let back = root.readoutLines().filter { $0.hasPrefix("bubble ") }
        let after = try XCTUnwrap(back.first { $0.contains("auto/27-haptics-no-touch") }.map(self.parse), back.joined(separator: "\n"))
        XCTAssertEqual(after.height, before.height)
    }
}
