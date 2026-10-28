import XCTest
import UIKit
import Display
import MessageWidget
@testable import CoreList
@testable import ChatHistoryListViewBackend
@testable import WidgetHarnessLib

/// Tier 1: widget-sandbox v0.1.3's resize anchor in the REAL chat bubbles on the chat's list (integration.md "Which edge
/// stays put", sdk-v1 §5.6): when a widget's auto height changes on screen, the bubble's anchored edge stays where it is
/// and the content on its other side moves; but at the chat's bottom the chat stays at its bottom, so a top-anchored
/// widget grows upward there until its top reaches the screen's top inset, and the rest downward (the user's rule,
/// 2026-10-28, replacing decision 1's "the anchor wins at the bottom too"); a widget's first height is placed as any new
/// message is (decision 2), and the list never shows space past its ends (decision 3). The fixtures are
/// `Fixtures/resize/`: each sets its anchor first, then changes by 120 pt (`grow-top-far` and `grow-bottom-far` by 480 pt). Each chat is taller
/// than the screen (older filler posts): a chat that fits the screen cannot scroll, so nothing in it can keep an edge the
/// list's own placement does not. A test of the anchor off the chat's bottom scrolls there and checks it is
/// (`assertOffTheBottom`): `load` leaves the chat at its bottom.
final class WidgetHarnessResizeTests: XCTestCase {
    private struct Frame: CustomStringConvertible {
        let minY: Double
        let maxY: Double
        var height: Double { self.maxY - self.minY }
        var description: String { "\(self.minY)…\(self.maxY)" }
    }

    private static let growTop = "fixture/resize/grow-top.html"
    private static let growBottom = "fixture/resize/grow-bottom.html"
    private static let growTopFar = "fixture/resize/grow-top-far.html"
    private static let growBottomFar = "fixture/resize/grow-bottom-far.html"
    private static let shrinkTop = "fixture/resize/shrink-top.html"
    private static let timerTop = "fixture/resize/timer-top.html"
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

    /// The screen's top inset in the root view's coordinates: the list's edge under the readout
    /// (`WidgetHarnessRootViewController.layoutList`).
    private func topInset(_ root: WidgetHarnessRootViewController) -> Double {
        return Double(root.view.safeAreaInsets.top + WidgetHarnessRootViewController.readoutHeight)
    }

    /// Fails unless the chat is off its bottom: the newest post, `newest`, lies well below the screen's bottom inset.
    private func assertOffTheBottom(_ root: WidgetHarnessRootViewController, _ frames: [String: Frame], newest: String, file: StaticString = #filePath, line: UInt = #line) {
        let bottomLine = Double(root.view.bounds.height - root.view.safeAreaInsets.bottom)
        XCTAssertGreaterThan(frames[newest]?.maxY ?? 0.0, bottomLine + 100.0, "the chat is at its bottom: \(frames)", file: file, line: line)
    }

    private func XCTAssertNear(_ a: Double?, _ b: Double?, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let a, let b else {
            return XCTFail("missing: \(String(describing: a)) vs \(String(describing: b)) — \(message)", file: file, line: line)
        }
        XCTAssertEqual(a, b, accuracy: 0.6, message, file: file, line: line)
    }

    /// Off the chat's bottom a top-anchored bubble grows downward: its top stays, what is below it moves.
    func testATopAnchoredBubbleGrowsDownward() throws {
        let (root, _) = try self.load([Self.box, Self.growTop, Self.text, Self.tall])
        root.listHost?.scrollTo(messageIndex: 1)
        let before = self.settle(root) { _ in true }
        self.assertOffTheBottom(root, before, newest: Self.tall)
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

    /// The user's rule (2026-10-28): at the chat's bottom a top-anchored newest widget grows upward, the chat staying at
    /// its bottom, while its top stays below the screen's top inset.
    func testAtTheBottomATopAnchoredBubbleGrowsUpward() throws {
        let (root, before) = try self.load([Self.tall, Self.box, Self.text, Self.growTop])
        XCTAssertGreaterThan((before[Self.growTop]?.minY ?? 0.0) - 120.0, self.topInset(root), "it would reach the top inset: \(before)")
        try self.click(root, Self.growTop)
        let after = self.settle(root) { ($0[Self.growTop]?.height ?? 0.0) > (before[Self.growTop]?.height ?? 0.0) + 100.0 }
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.growTop]?.maxY, before[Self.growTop]?.maxY, message)
        XCTAssertNear(after[Self.text]?.minY, before[Self.text].map { $0.minY - 120.0 }, message)
    }

    /// With the chat's newest edge held open (an overscroll action) the chat is at its bottom too, and a top-anchored
    /// widget grows upward: the hold is extra inset the list is given, which the target is measured from.
    func testWithTheNewestEdgeHeldATopAnchoredBubbleGrowsUpward() throws {
        let (root, _) = try self.load([Self.tall, Self.box, Self.text, Self.growTop])
        root.listHost?.holdOverscroll(distance: 80.0)
        let before = self.settle(root) { _ in true }
        XCTAssertGreaterThan((before[Self.growTop]?.minY ?? 0.0) - 120.0, self.topInset(root), "it would reach the top inset: \(before)")
        try self.click(root, Self.growTop)
        let after = self.settle(root) { ($0[Self.growTop]?.height ?? 0.0) > (before[Self.growTop]?.height ?? 0.0) + 100.0 }
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.growTop]?.maxY, before[Self.growTop]?.maxY, message)
        XCTAssertNear(after[Self.text]?.minY, before[Self.text].map { $0.minY - 120.0 }, message)
    }

    /// The user's rule (2026-10-28): at the chat's bottom a top-anchored widget grows upward until its top reaches the
    /// screen's top inset, which its row's top then keeps, and the rest of its growth goes downward, the chat leaving its
    /// bottom by it.
    func testAtTheBottomATopAnchoredBubbleStopsAtTheTopInset() throws {
        let (root, before) = try self.load([Self.tall, Self.growTopFar, Self.box])
        let inset = self.topInset(root)
        let frame = try XCTUnwrap(before[Self.growTopFar], "\(before)")
        XCTAssertTrue(frame.minY > inset + 1.0 && frame.minY - 480.0 < inset - 1.0, "its growth does not reach the top inset at \(inset): \(before)")
        try self.click(root, Self.growTopFar)
        let after = self.settle(root) { ($0[Self.growTopFar]?.height ?? 0.0) > frame.height + 400.0 }
        let message = "inset \(inset), before \(before), after \(after)"
        let grown = try XCTUnwrap(after[Self.growTopFar], message)
        XCTAssertNear(grown.height, frame.height + 480.0, message)
        // The widget's top sits under its row's top, which keeps the inset.
        XCTAssertGreaterThanOrEqual(grown.minY, inset - 0.6, message)
        XCTAssertLessThan(grown.minY, inset + 8.0, message)
        XCTAssertGreaterThan(grown.maxY, frame.maxY + 50.0, message)
        XCTAssertNear(after[Self.box]?.minY, before[Self.box].map { $0.minY + (grown.maxY - frame.maxY) }, message)
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
        let (root, _) = try self.load([Self.box, Self.growTop, Self.text, Self.tall])
        root.listHost?.scrollTo(messageIndex: 2, hold: .always)
        let before = self.settle(root) { _ in true }
        self.assertOffTheBottom(root, before, newest: Self.tall)
        try self.click(root, Self.growTop)
        let after = self.settle(root) { ($0[Self.growTop]?.height ?? 0.0) > (before[Self.growTop]?.height ?? 0.0) + 100.0 }
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.growTop]?.minY, before[Self.growTop]?.minY, message)
        XCTAssertNear(after[Self.text]?.minY, before[Self.text].map { $0.minY + 120.0 }, message)
    }

    /// An update that changes no height (a widget re-laid out at the height it has) carries no anchor: a scroll target
    /// would end the chat's held jump, and stop a fling, for nothing.
    func testAnUpdateThatChangesNoHeightKeepsAHeldJump() throws {
        let (root, _) = try self.load([Self.tall, Self.growTop, Self.text, Self.box])
        let host = try XCTUnwrap(root.listHost)
        host.scrollTo(messageIndex: 2, hold: .always)
        _ = self.settle(root) { _ in true }
        XCTAssertTrue(host.isHoldingScrollTarget, "the jump is not held")
        let since = host.updateAnchors.count
        host.updateMessage(path: Self.growTop)
        _ = self.settle(root) { _ in true }
        let updates = host.updateAnchors.dropFirst(since).filter { $0.path == Self.growTop }.map(\.anchor)
        XCTAssertEqual(updates, [nil])
        XCTAssertTrue(host.isHoldingScrollTarget, "a no-op update ended the held jump")
    }

    /// Review Focus 2: two widgets on screen change height in one list pass with different anchors: each keeps its own
    /// edge, and the post between them stays. The list host holds both bubbles' update requests (each widget asks once
    /// it has reported its new height), then sends them as one transaction.
    func testTwoBubblesResizingInOnePass() throws {
        let (root, _) = try self.load([Self.box, Self.growBottom, Self.text, Self.growTop, Self.tall])
        let host = try XCTUnwrap(root.listHost)
        host.scrollTo(messageIndex: 2)
        let before = self.settle(root) { _ in true }
        self.assertOffTheBottom(root, before, newest: Self.tall)
        host.holdsUpdates = true
        try self.click(root, Self.growBottom)
        try self.click(root, Self.growTop)
        let deadline = Date(timeIntervalSinceNow: 10.0)
        while Date() < deadline && host.heldUpdateCount < 2 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        XCTAssertEqual(host.heldUpdateCount, 2, "the widgets did not both ask")
        let transactions = host.updateTransactions.count
        host.holdsUpdates = false
        host.flushUpdates()
        let after = self.settle(root) { frames in
            (frames[Self.growTop]?.height ?? 0.0) > (before[Self.growTop]?.height ?? 0.0) + 100.0
                && (frames[Self.growBottom]?.height ?? 0.0) > (before[Self.growBottom]?.height ?? 0.0) + 100.0
        }
        XCTAssertEqual(Array(host.updateTransactions.dropFirst(transactions).prefix(1)), [2], "not one pass: \(host.updateTransactions)")
        let message = "before \(before), after \(after)"
        XCTAssertNear(after[Self.growBottom]?.maxY, before[Self.growBottom]?.maxY, message)
        XCTAssertNear(after[Self.text]?.minY, before[Self.text]?.minY, message)
        XCTAssertNear(after[Self.growTop]?.minY, before[Self.growTop]?.minY, message)
    }

    /// Review Focus 3: a widget turning into the pill (the kill switch engaged) is a height change by its anchor too:
    /// the update that lays the pill out carries the widget's anchor. The kill switch turns every widget into the pill
    /// at once, so the edge itself is the other tests' to measure.
    func testThePillKeepsTheAnchoredEdge() throws {
        let (root, _) = try self.load([Self.text, Self.growBottom])
        let host = try XCTUnwrap(root.listHost)
        let since = host.updateAnchors.count
        MessageWidgetKillSwitch.isEngaged = true
        _ = self.settle(root) { _ in root.readoutLines().contains { $0.contains(Self.growBottom) && $0.contains(" pill") } }
        let updates = host.updateAnchors.dropFirst(since).filter { $0.path == Self.growBottom }.map(\.anchor)
        XCTAssertEqual(updates.first ?? nil, .bottom, "\(updates)")
    }

    /// Under a post pinned to the top of the screen (the chat's pin while a bot streams its reply under the user's
    /// message) the list re-places the pinned row on every pass until a drag (or a held jump to another post), with room
    /// below the newest post: a top-anchored widget there keeps its top and grows into that room and past it, and the
    /// pinned post stays, during the change and on the next pass. Growing upward would push the pinned post up, and the pin would pull it back down
    /// on the next pass (the review of 2026-10-28).
    func testUnderAPinnedPostATopAnchoredBubbleKeepsItsTop() throws {
        let (root, _) = try self.load([Self.tall, Self.text, Self.box, Self.growTopFar])
        let host = try XCTUnwrap(root.listHost)
        host.pinToTop(path: Self.text)
        let before = self.settle(root) { _ in true }
        let bottomLine = Double(root.view.bounds.height - root.view.safeAreaInsets.bottom)
        let room = bottomLine - (before[Self.growTopFar]?.maxY ?? bottomLine)
        let pinnedTop = before[Self.text]?.minY ?? 0.0
        XCTAssertTrue(pinnedTop > self.topInset(root) - 0.6 && pinnedTop < self.topInset(root) + 12.0, "the post is not pinned to the top: \(before)")
        XCTAssertTrue(room > 20.0 && room < 440.0, "the room below the newest post is not under its growth: \(room), \(before)")
        try self.click(root, Self.growTopFar)
        let after = self.settle(root) { ($0[Self.growTopFar]?.height ?? 0.0) > (before[Self.growTopFar]?.height ?? 0.0) + 400.0 }
        let message = "room \(room), before \(before), after \(after)"
        XCTAssertNear(after[Self.text]?.minY, before[Self.text]?.minY, message)
        XCTAssertNear(after[Self.growTopFar]?.minY, before[Self.growTopFar]?.minY, message)
        host.updateMessage(path: Self.text)
        let later = self.settle(root) { _ in true }
        XCTAssertNear(later[Self.text]?.minY, before[Self.text]?.minY, "after a later pass: before \(before), later \(later)")
    }

    /// Under a held pin a bottom-anchored widget cannot keep its bottom: the pinned post above it would go up and the pin
    /// would pull it back down on the next pass. The pin anchors the pass instead, so the widget grows downward, into the
    /// room below and past it, and the pinned post stays (the review of 2026-10-28).
    func testUnderAPinnedPostABottomAnchoredBubbleLeavesThePinInPlace() throws {
        let (root, _) = try self.load([Self.tall, Self.text, Self.box, Self.growBottomFar])
        let host = try XCTUnwrap(root.listHost)
        host.pinToTop(path: Self.text)
        let before = self.settle(root) { _ in true }
        let bottomLine = Double(root.view.bounds.height - root.view.safeAreaInsets.bottom)
        let room = bottomLine - (before[Self.growBottomFar]?.maxY ?? bottomLine)
        let pinnedTop = before[Self.text]?.minY ?? 0.0
        XCTAssertTrue(pinnedTop > self.topInset(root) - 0.6 && pinnedTop < self.topInset(root) + 12.0, "the post is not pinned to the top: \(before)")
        XCTAssertTrue(room > 20.0 && room < 440.0, "the room below the newest post is not under its growth: \(room), \(before)")
        try self.click(root, Self.growBottomFar)
        let after = self.settle(root) { ($0[Self.growBottomFar]?.height ?? 0.0) > (before[Self.growBottomFar]?.height ?? 0.0) + 400.0 }
        let message = "room \(room), before \(before), after \(after)"
        XCTAssertNear(after[Self.text]?.minY, before[Self.text]?.minY, message)
        XCTAssertNear(after[Self.growBottomFar]?.minY, before[Self.growBottomFar]?.minY, message)
        host.updateMessage(path: Self.text)
        let later = self.settle(root) { _ in true }
        XCTAssertNear(later[Self.text]?.minY, before[Self.text]?.minY, "after a later pass: before \(before), later \(later)")
    }

    /// Under a post pinned to the top, the chat's jump to another message, which it holds (a tap on a reply), ends the pin,
    /// so a widget there keeps its anchored edge as under any held jump (the user's call, 2026-10-29): a top-anchored one
    /// keeps its top, and a later pass moves nothing. The pin used to put the pinned post back on the screen's top on the
    /// next pass, taking the jumped-to widget with it.
    func testUnderAPinnedPostAHeldJumpLetsAWidgetKeepItsEdge() throws {
        let (root, _) = try self.load([Self.box, Self.text, Self.growTop, Self.tall])
        let host = try XCTUnwrap(root.listHost)
        host.pinToTop(path: Self.text)
        let pinned = self.settle(root) { _ in true }
        let pinnedTop = pinned[Self.text]?.minY ?? 0.0
        XCTAssertTrue(pinnedTop > self.topInset(root) - 0.6 && pinnedTop < self.topInset(root) + 12.0, "the post is not pinned to the top: \(pinned)")
        host.scrollTo(messageIndex: 2, hold: .always)
        let before = self.settle(root) { _ in true }
        XCTAssertTrue(host.isHoldingScrollTarget, "the jump is not held")
        XCTAssertGreaterThan(before[Self.growTop]?.minY ?? 0.0, (pinned[Self.growTop]?.minY ?? 0.0) + 100.0, "the jump left the widget under the pinned post: pinned \(pinned), jumped \(before)")
        self.assertOffTheBottom(root, before, newest: Self.tall)
        try self.click(root, Self.growTop)
        let after = self.settle(root) { ($0[Self.growTop]?.height ?? 0.0) > (before[Self.growTop]?.height ?? 0.0) + 100.0 }
        let message = "pinned \(pinned), before \(before), after \(after)"
        XCTAssertNear(after[Self.growTop]?.minY, before[Self.growTop]?.minY, message)
        XCTAssertNear(after[Self.tall]?.minY, before[Self.tall].map { $0.minY + 120.0 }, message)
        host.updateMessage(path: Self.text)
        let later = self.settle(root) { _ in true }
        XCTAssertNear(later[Self.growTop]?.minY, after[Self.growTop]?.minY, "after a later pass: after \(after), later \(later)")
    }

    /// A widget's resize target keeps a row where it is; it is not a scroll to the pin (`CoreListScrollTarget.pinsRow`
    /// false). Aimed at a pinned post whose pin a drag released, it must not pin it again, or the next pass would put the
    /// post back on the screen's top. The pinned post is the widget itself; the drag is the scroll engine's own
    /// began/ended callbacks, which release the pin exactly as a finger does.
    func testAResizeDoesNotPinAReleasedPinnedPostAgain() throws {
        let (root, _) = try self.load([Self.box, Self.text, Self.growTop, Self.tall])
        let host = try XCTUnwrap(root.listHost)
        let backend = try XCTUnwrap(host.listView as? CoreListChatHistoryBackend, "the harness list is not the CoreList backend")
        host.pinToTop(path: Self.growTop)
        let pinned = self.settle(root) { _ in true }
        XCTAssertTrue(backend.coreList.holdsPinnedRowAtBottomEdge, "precondition: the post is not pinned: \(pinned)")
        backend.coreList.engine.onWillBeginDragging?()
        backend.coreList.engine.onDidEndDragging?()
        XCTAssertFalse(backend.coreList.holdsPinnedRowAtBottomEdge, "precondition: the drag did not release the pin")
        // Away from the pin's place, with a scroll that is not to the pinned post.
        host.scrollTo(messageIndex: 1)
        let before = self.settle(root) { _ in true }
        XCTAssertGreaterThan(before[Self.growTop]?.minY ?? 0.0, (pinned[Self.growTop]?.minY ?? 0.0) + 100.0, "precondition: the widget is still at the pin's place: pinned \(pinned), before \(before)")
        try self.click(root, Self.growTop)
        let after = self.settle(root) { ($0[Self.growTop]?.height ?? 0.0) > (before[Self.growTop]?.height ?? 0.0) + 100.0 }
        XCTAssertFalse(backend.coreList.holdsPinnedRowAtBottomEdge, "the resize pinned the post again")
        host.updateMessage(path: Self.text)
        let later = self.settle(root) { _ in true }
        XCTAssertNear(later[Self.growTop]?.minY, after[Self.growTop]?.minY, "a later pass moved the widget: pinned \(pinned), before \(before), after \(after), later \(later)")
    }

    /// Review Focus 1: a bubble whose anchored top is above the screen keeps it there; what is on screen below it moves.
    /// At the chat's bottom too, where it is: a top already past the screen's top inset has reached it (the user's call,
    /// 2026-10-28), so the chat leaves its bottom.
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
