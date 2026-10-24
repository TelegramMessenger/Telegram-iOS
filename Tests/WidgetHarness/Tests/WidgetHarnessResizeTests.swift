import XCTest
import UIKit
import Display
import MessageWidget
@testable import WidgetHarnessLib

/// Tier 1: widget-sandbox v0.1.3's resize anchor in the REAL chat bubbles on the chat's list (integration.md "Which edge
/// stays put", sdk-v1 §5.6): when a widget's auto height changes on screen, the bubble's anchored edge stays where it is
/// and the content on its other side moves; everywhere, at the chat's bottom too (the user's decision 1), but for a
/// widget's first height, which is placed as any new message is (decision 2), and the list never shows space past its
/// ends (decision 3). The fixtures are `Fixtures/resize/`: each sets its anchor first, then changes by 120 pt. Each chat
/// is taller than the screen (older filler posts): a chat that fits the screen cannot scroll, so nothing in it can keep
/// an edge the list's own placement does not.
final class WidgetHarnessResizeTests: XCTestCase {
    private struct Frame: CustomStringConvertible {
        let minY: Double
        let maxY: Double
        var height: Double { self.maxY - self.minY }
        var description: String { "\(self.minY)…\(self.maxY)" }
    }

    private static let growTop = "fixture/resize/grow-top.html"
    private static let growBottom = "fixture/resize/grow-bottom.html"
    private static let shrinkTop = "fixture/resize/shrink-top.html"
    private static let timerTop = "fixture/resize/timer-top.html"
    private static let timerBottom = "fixture/resize/timer-bottom.html"
    private static let text = "fixture/text.html"
    private static let box = "fixture/box-240.html"
    private static let tall = "fixture/tall-box.html"

    override func tearDown() {
        MessageWidgetKillSwitch.isEngaged = false
        super.tearDown()
    }

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

    /// The widget area of every loaded bubble, by path, in the root view's coordinates (the readout's bubble lines).
    private func frames(_ root: WidgetHarnessRootViewController) -> [String: Frame] {
        root.view.layoutIfNeeded()
        var result: [String: Frame] = [:]
        for line in root.readoutLines() where line.hasPrefix("bubble ") {
            let parts = line.split(separator: " ").map(String.init)
            guard parts.count > 4 else {
                continue
            }
            let size = parts[3].split(separator: "x").compactMap { Double($0) }
            let centre = parts[4].dropFirst().split(separator: ",").compactMap { Double($0) }
            guard size.count == 2, centre.count == 2 else {
                continue
            }
            result[parts[2]] = Frame(minY: centre[1] - size[1] / 2.0, maxY: centre[1] + size[1] / 2.0)
        }
        return result
    }

    /// Polls the frames until `ready` holds for them and they stay the same for 0.4 s (the list's height animation
    /// settled), at most 10 s; returns the last ones.
    private func settle(_ root: WidgetHarnessRootViewController, until ready: ([String: Frame]) -> Bool) -> [String: Frame] {
        let deadline = Date(timeIntervalSinceNow: 10.0)
        var last = self.frames(root)
        var stableSince = Date()
        while Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            let now = self.frames(root)
            if now.mapValues(\.description) != last.mapValues(\.description) {
                stableSince = Date()
                last = now
            } else if ready(now) && Date().timeIntervalSince(stableSince) >= 0.4 {
                return now
            }
        }
        return last
    }

    /// Loads `posts` (oldest first) into the chat at its newest end, and waits until every one is a live widget that has
    /// reported its height (past the 160 pt placeholder) and the list has settled.
    private func load(_ posts: [String]) throws -> (WidgetHarnessRootViewController, [String: Frame]) {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.posts = posts
        root.reload(options: options)
        let frames = self.settle(root) { frames in
            posts.allSatisfy { path in frames[path].map { abs($0.height - 160.0) > 0.5 } ?? false }
                && root.readoutLines().filter { $0.hasPrefix("bubble ") && $0.contains(" widget") }.count >= posts.count
        }
        return (root, frames)
    }

    /// A click in the widget at `path` (its top-left 50 px), through the widget's own pointer path.
    private func click(_ root: WidgetHarnessRootViewController, _ path: String) throws {
        let instance = try XCTUnwrap(root.listHost?.widgetView(path: path)?.instance, "no live widget at \(path)")
        instance.pointer(.down, at: CGPoint(x: 50.0, y: 50.0))
        instance.pointer(.up, at: CGPoint(x: 50.0, y: 50.0))
    }

    private func XCTAssertNear(_ a: Double?, _ b: Double?, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let a, let b else {
            return XCTFail("missing: \(String(describing: a)) vs \(String(describing: b)) — \(message)", file: file, line: line)
        }
        XCTAssertEqual(a, b, accuracy: 0.6, message, file: file, line: line)
    }

    func testATopAnchoredBubbleGrowsDownward() throws {
        let (root, before) = try self.load([Self.tall, Self.box, Self.growTop, Self.text])
        try self.click(root, Self.growTop)
        let after = self.settle(root) { ($0[Self.growTop]?.height ?? 0.0) > (before[Self.growTop]?.height ?? 0.0) + 100.0 }
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.growTop]?.minY, before[Self.growTop]?.minY, message)
        XCTAssertNear(after[Self.text]?.minY, before[Self.text].map { $0.minY + 120.0 }, message)
    }

    func testABottomAnchoredBubbleGrowsUpward() throws {
        let (root, before) = try self.load([Self.tall, Self.text, Self.growBottom, Self.box])
        try self.click(root, Self.growBottom)
        let after = self.settle(root) { ($0[Self.growBottom]?.height ?? 0.0) > (before[Self.growBottom]?.height ?? 0.0) + 100.0 }
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.growBottom]?.maxY, before[Self.growBottom]?.maxY, message)
        XCTAssertNear(after[Self.text]?.minY, before[Self.text].map { $0.minY - 120.0 }, message)
        XCTAssertNear(after[Self.box]?.minY, before[Self.box]?.minY, message)
    }

    /// Decision 1: at the chat's bottom a top-anchored newest widget grows downward too, under the input bar.
    func testAtTheBottomTheAnchorWins() throws {
        let (root, before) = try self.load([Self.tall, Self.box, Self.text, Self.growTop])
        try self.click(root, Self.growTop)
        let after = self.settle(root) { ($0[Self.growTop]?.height ?? 0.0) > (before[Self.growTop]?.height ?? 0.0) + 100.0 }
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.growTop]?.minY, before[Self.growTop]?.minY, message)
        XCTAssertNear(after[Self.text]?.minY, before[Self.text]?.minY, message)
    }

    /// Decision 3: a top-anchored newest widget that shrinks at the chat's bottom would leave space below it; the list
    /// clamps, so its bottom stays at the end and what is above it moves down.
    func testAShrinkAtTheBottomClamps() throws {
        let (root, before) = try self.load([Self.tall, Self.box, Self.text, Self.shrinkTop])
        try self.click(root, Self.shrinkTop)
        let after = self.settle(root) { ($0[Self.shrinkTop]?.height ?? 1000.0) < (before[Self.shrinkTop]?.height ?? 0.0) - 100.0 }
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.shrinkTop]?.maxY, before[Self.shrinkTop]?.maxY, message)
        XCTAssertNear(after[Self.text]?.minY, before[Self.text].map { $0.minY + 120.0 }, message)
    }

    /// Decision 2: a widget's first height, replacing the 160 pt placeholder with nothing cached, is placed as any new
    /// message is: at the chat's bottom the chat stays at its bottom.
    func testTheFirstHeightIsPlacement() throws {
        let (root, loaded) = try self.load([Self.tall, Self.box, Self.text, Self.growTop])
        root.listHost?.scrollTo(messageIndex: Int.max)
        let bottom = self.settle(root) { _ in true }
        XCTAssertNear(loaded[Self.growTop]?.maxY, bottom[Self.growTop]?.maxY, "loaded \(loaded), at the bottom \(bottom)")
    }

    /// A bubble entirely off screen that changes height leaves what is on screen where it is.
    func testAnOffscreenBubbleLeavesTheScreenStill() throws {
        let (root, before) = try self.load([Self.timerTop, Self.tall, Self.box, Self.text])
        XCTAssertLessThan(before[Self.timerTop]?.maxY ?? -1.0, 0.0, "not off screen: \(before)")
        // Its timer fires 2.5 s after its load; the frames of the others must not move.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 3.0))
        let after = self.settle(root) { _ in true }
        let message = "before \(before), after \(after)"
        for path in [Self.tall, Self.box, Self.text] {
            XCTAssertNear(after[path]?.minY, before[path]?.minY, path + ": " + message)
        }
    }

    /// The chat's jump to a message holds that row until a drag; a widget's height change on screen still keeps the
    /// widget's anchored edge, and the held row moves with its side (the design's call).
    func testAHeldJumpYieldsToTheAnchor() throws {
        let (root, _) = try self.load([Self.tall, Self.growTop, Self.text, Self.box])
        root.listHost?.scrollTo(messageIndex: 2, hold: .always)
        let before = self.settle(root) { _ in true }
        try self.click(root, Self.growTop)
        let after = self.settle(root) { ($0[Self.growTop]?.height ?? 0.0) > (before[Self.growTop]?.height ?? 0.0) + 100.0 }
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.growTop]?.minY, before[Self.growTop]?.minY, message)
        XCTAssertNear(after[Self.text]?.minY, before[Self.text].map { $0.minY + 120.0 }, message)
    }

    /// Review Focus 2: two widgets on screen grow in one pass with different anchors; each keeps its own edge, and the
    /// post between them stays.
    func testTwoBubblesResizingTogether() throws {
        let (root, before) = try self.load([Self.tall, Self.timerBottom, Self.text, Self.timerTop, Self.box])
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 2.0))
        let after = self.settle(root) { frames in
            (frames[Self.timerTop]?.height ?? 0.0) > (before[Self.timerTop]?.height ?? 0.0) + 100.0
                && (frames[Self.timerBottom]?.height ?? 0.0) > (before[Self.timerBottom]?.height ?? 0.0) + 100.0
        }
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.timerBottom]?.maxY, before[Self.timerBottom]?.maxY, message)
        XCTAssertNear(after[Self.text]?.minY, before[Self.text]?.minY, message)
        XCTAssertNear(after[Self.timerTop]?.minY, before[Self.timerTop]?.minY, message)
    }

    /// Review Focus 3: a widget turning into the pill (the kill switch engaged) is a height change by its anchor too:
    /// gone, its bubble answers the anchor cached with its height. The kill switch turns every widget into the pill at
    /// once, so the edge itself is the other tests' to measure.
    func testThePillKeepsTheAnchoredEdge() throws {
        let (root, _) = try self.load([Self.text, Self.growBottom])
        XCTAssertEqual(root.listHost?.resizeAnchor(path: Self.growBottom), .bottom)
        MessageWidgetKillSwitch.isEngaged = true
        _ = self.settle(root) { _ in root.readoutLines().contains { $0.contains(Self.growBottom) && $0.contains(" pill") } }
        XCTAssertEqual(root.listHost?.resizeAnchor(path: Self.growBottom), .bottom)
    }

    /// Review Focus 1: a bubble whose anchored top is above the screen keeps it there; what is on screen below it moves.
    func testAPartlyVisibleBubbleKeepsItsEdge() throws {
        let (root, before) = try self.load([Self.growTop, Self.tall, Self.text])
        let frame = try XCTUnwrap(before[Self.growTop], "\(before)")
        XCTAssertTrue(frame.minY < 0.0 && frame.maxY > 0.0, "not partly visible: \(before)")
        try self.click(root, Self.growTop)
        let after = self.settle(root) { ($0[Self.growTop]?.height ?? 0.0) > frame.height + 100.0 }
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.growTop]?.minY, frame.minY, message)
        XCTAssertNear(after[Self.tall]?.minY, before[Self.tall].map { $0.minY + 120.0 }, message)
    }

    /// Review Focus 5: a bubble re-created after scrolling away (its widget booted again) opens at its cached height, and
    /// its new run's first report keeps the new run's anchored edge.
    func testARecreatedBubbleKeepsItsEdgeFromTheCache() throws {
        let fillers = ["fixture/tall-box.html", "fixture/touch-drag.html", "fixture/selection.html", "fixture/multitouch.html", Self.box, Self.text]
        let (root, _) = try self.load([Self.growBottom] + fillers)
        root.listHost?.scrollTo(messageIndex: 0)
        _ = self.settle(root) { $0[Self.growBottom] != nil }
        let first = try XCTUnwrap(root.listHost?.widgetView(path: Self.growBottom)?.instance)
        try self.click(root, Self.growBottom)
        _ = self.settle(root) { ($0[Self.growBottom]?.height ?? 0.0) > 200.0 }
        root.listHost?.scrollTo(messageIndex: Int.max)
        _ = self.settle(root) { $0[Self.growBottom] == nil }
        root.listHost?.scrollTo(messageIndex: 0)
        // Back from the cache at 220 pt; the new run reports 100 pt, anchored at the bottom.
        let cached = self.settle(root) { ($0[Self.growBottom]?.height ?? 0.0) > 200.0 }
        let again = try XCTUnwrap(root.listHost?.widgetView(path: Self.growBottom)?.instance)
        XCTAssertFalse(first === again, "the widget was not re-created")
        let after = self.settle(root) { ($0[Self.growBottom]?.height ?? 1000.0) < 150.0 }
        XCTAssertNear(after[Self.growBottom]?.maxY, cached[Self.growBottom]?.maxY, "cached \(cached), after \(after)")
    }
}
