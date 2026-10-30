import ChatMessageDateAndStatusNode
import ChatMessageWidgetBubbleContentNode
import Display
import MessageWidget
import TextSelectionNode
import UIKit
import XCTest
@testable import WidgetHarnessLib

/// Tier 1 (in the app process), widget-sandbox v0.4.0 through the REAL bubble (sdk-v1 §2.17, §5.12): a widget with no
/// caption below it (none, or one shown above it) is told the band and corner its bubble's time covers, and a tap on the
/// time is the bubble's; with a caption below the time is in the caption's line and the widget is told nothing.
final class WidgetHarnessSafeAreaTests: XCTestCase {
    /// Shows what it was told as its `data-log` (the readout's `log` line), at boot and on every change, counting the changes
    /// in `data-events`; claims every horizontal drag (`touch-action: none`), counts its downs in `data-downs`, and has text
    /// to select when lifted.
    private let html = "<!doctype html><body style=\"margin:0;touch-action:none\"><div style=\"height:80px;-webkit-user-select:text;user-select:text\">safe to select</div><script>"
        + "function show() { document.documentElement.setAttribute('data-log', JSON.stringify(TelegramWidget.contentSafeAreaInset)); }"
        + "show(); let events = 0; TelegramWidget.onEvent('contentSafeAreaChanged', () => { show();"
        + " document.documentElement.setAttribute('data-events', String(++events)); }); let downs = 0;"
        + "addEventListener('pointerdown', () => document.documentElement.setAttribute('data-downs', String(++downs)));</script></body>"

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

    /// The three placements, as the test group posts `visual/17-time-corner`: no caption, a caption below, one above.
    private func load() throws -> WidgetHarnessRootViewController {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "no post matches this"
        root.reload(options: options)
        let host = try XCTUnwrap(root.listHost)
        var above = WidgetHarnessPost(path: "fixture/safe-above", html: self.html, width: 0, height: 0, caption: "above", photos: [])
        above.captionAbove = true
        host.load(posts: [
            WidgetHarnessPost(path: "fixture/safe-none", html: self.html, width: 0, height: 0, caption: "", photos: []),
            WidgetHarnessPost(path: "fixture/safe-below", html: self.html, width: 0, height: 0, caption: "below", photos: []),
            above,
        ])
        return root
    }

    /// Each post's last `contentSafeAreaInset`, once every one of `paths` has one, or after 20 s.
    private func told(_ root: WidgetHarnessRootViewController, paths: Set<String> = ["fixture/safe-none", "fixture/safe-below", "fixture/safe-above"]) -> [String: [String: Double]] {
        let deadline = Date(timeIntervalSinceNow: 20.0)
        var told: [String: [String: Double]] = [:]
        while Date() < deadline {
            root.view.layoutIfNeeded()
            for line in root.readoutLines() where line.hasPrefix("log fixture/safe-") {
                let parts = line.split(separator: " ", maxSplits: 2).map(String.init)
                if parts.count == 3, let data = parts[2].data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Double] {
                    told[parts[1]] = object
                }
            }
            if paths.isSubset(of: Set(told.keys)) {
                break
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return told
    }

    func testTheWidgetIsToldWhatItsTimeCovers() throws {
        let root = try self.load()
        let told = self.told(root)
        let none = try XCTUnwrap(told["fixture/safe-none"], "\(told)")
        let below = try XCTUnwrap(told["fixture/safe-below"], "\(told)")
        let above = try XCTUnwrap(told["fixture/safe-above"], "\(told)")
        print("the time covers \(none)")
        // The time's band and its corner on the right, the pill with its margins (decision 2).
        XCTAssertTrue((20.0 ... 64.0).contains(none["bottom"] ?? 0.0), "\(none)")
        XCTAssertTrue((40.0 ... 200.0).contains(none["cornerRight"] ?? 0.0), "\(none)")
        for key in ["top", "right", "left", "cornerLeft"] {
            XCTAssertEqual(none[key], 0.0, key)
        }
        // A caption above is as none.
        XCTAssertEqual(above, none)
        // A caption below: the time is in its line, nothing over the widget.
        XCTAssertEqual(below, ["top": 0.0, "right": 0.0, "bottom": 0.0, "left": 0.0, "cornerLeft": 0.0, "cornerRight": 0.0])
    }

    /// sdk-v1 §5.12 (the deferred items' test gap): an edit that moves the caption above the widget gives it the band, one
    /// change, and one that moves it back below takes the band away, one more.
    func testACaptionEditChangesTheBandOnce() throws {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "no post matches this"
        root.reload(options: options)
        let host = try XCTUnwrap(root.listHost)
        let path = "fixture/safe-edit"
        host.load(posts: [WidgetHarnessPost(path: path, html: self.html, width: 0, height: 0, caption: "below", photos: [])])
        XCTAssertEqual(self.told(root, paths: [path])[path]?["bottom"], 0.0)
        let node = { host.widgetContentNodes().first { $0.path == path }?.node }
        let events = { node().flatMap { self.widgetView(in: $0.view) }?.documentElementAttribute("data-events") }
        host.replaceCaption(path: path, text: "above", captionAbove: true)
        let deadline = Date(timeIntervalSinceNow: 20.0)
        while Date() < deadline && events() != "1" {
            root.view.layoutIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        XCTAssertEqual(events(), "1")
        XCTAssertGreaterThan(self.told(root, paths: [path])[path]?["bottom"] ?? 0.0, 20.0)
        host.replaceCaption(path: path, text: "below", captionAbove: false)
        let back = Date(timeIntervalSinceNow: 20.0)
        while Date() < back && events() != "2" {
            root.view.layoutIfNeeded()
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        XCTAssertEqual(events(), "2")
        // A later pass of the same layout changes nothing (the instance's and the core's equal-value guards both hold it;
        // what this test pins is the band reaching a running widget at each edit).
        root.view.layoutIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        XCTAssertEqual(events(), "2")
        XCTAssertEqual(self.told(root, paths: [path])[path]?["bottom"], 0.0)
    }

    /// sdk-v1 §5.12: the time is a view over the widget, and taps on it are the client's: the bubble's tap action there,
    /// no touch for the widget's view, and no claim of the swipe to reply (the final review's I-1: asking it pressed the
    /// widget early, a pointerdown at the time).
    func testATouchOnTheTimeIsTheBubbles() throws {
        let root = try self.load()
        _ = self.told(root)
        let host = try XCTUnwrap(root.listHost)
        let node = try XCTUnwrap(host.widgetContentNodes().first { $0.path == "fixture/safe-none" }?.node)
        let date = try XCTUnwrap(node.subnodes?.first { $0 is ChatMessageDateAndStatusNode })
        let point = CGPoint(x: date.frame.midX, y: date.frame.midY)
        let action = node.tapActionAtPoint(point, gesture: .tap, isEstimating: false)
        if case .ignore = action.content {
            XCTFail("a tap on the time goes to the widget")
        }
        var hit = node.view.hitTest(point, with: nil)
        while let view = hit {
            XCTAssertFalse(view is MessageWidgetView, "the widget's view takes a touch on the time")
            hit = view.superview
        }
        // The fix-wave review's F-1: the questions after the down (a long press's activation, a tap's up) convert the down
        // point through the press's shrink, several points toward the corner, so the whole box the widget is told is
        // covered (the pill with its margins) is the bubble's: here, between the pill and the widget's right edge.
        let margin = CGPoint(x: date.frame.maxX + 3.0, y: date.frame.midY)
        if case .ignore = node.tapActionAtPoint(margin, gesture: .tap, isEstimating: false).content {
            XCTFail("a tap in the time's margin goes to the widget")
        }
        hit = node.view.hitTest(margin, with: nil)
        while let view = hit {
            XCTAssertFalse(view is MessageWidgetView, "the widget's view takes a touch in the time's margin")
            hit = view.superview
        }
        XCTAssertFalse(node.claimsHorizontalDrag(at: margin), "the widget claims a drag from the time's margin")
        // And the box's bottom margin, under the pill.
        if case .ignore = node.tapActionAtPoint(CGPoint(x: date.frame.midX, y: date.frame.maxY + 3.0), gesture: .tap, isEstimating: false).content {
            XCTFail("a tap under the time goes to the widget")
        }
        // The swipe to reply asks every content node at the touch's down, whatever view it hit.
        XCTAssertFalse(node.claimsHorizontalDrag(at: point), "the widget claims a drag from the time")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        let widgetView = try XCTUnwrap(self.widgetView(in: node.view))
        XCTAssertNil(widgetView.documentElementAttribute("data-downs"), "the widget got a pointerdown at the time")
        // Just outside the box, left of it and above it, the widget's again: its tap (which presses it early), its touch.
        let box = date.frame.insetBy(dx: -8.0, dy: -8.0)
        for outside in [CGPoint(x: box.minX - 2.0, y: date.frame.midY), CGPoint(x: date.frame.midX, y: box.minY - 2.0)] {
            guard case .ignore = node.tapActionAtPoint(outside, gesture: .tap, isEstimating: false).content else {
                return XCTFail("a tap beside the time's box is the bubble's: \(outside)")
            }
            var view = node.view.hitTest(outside, with: nil)
            var reachesWidget = false
            while let current = view {
                reachesWidget = reachesWidget || current is MessageWidgetView
                view = current.superview
            }
            XCTAssertTrue(reachesWidget, "the widget's view does not take a touch beside the time's box: \(outside)")
        }
        // Away from the time the widget still claims its drags, and its presses reach it (the read above is live).
        let widget = widgetView.convert(widgetView.bounds, to: node.view)
        XCTAssertTrue(node.claimsHorizontalDrag(at: CGPoint(x: widget.midX, y: widget.minY + 20.0)))
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        XCTAssertNotNil(widgetView.documentElementAttribute("data-downs"), "the widget's downs are not read")
    }

    /// The deferred items (the fix-wave review's M-3): in a bubble wider than a fixed-width widget (a long caption above
    /// it) the widget is centred and the date sits at the bubble's corner, so only the pill's own box, not the widget's
    /// corner, is the bubble's.
    func testInAWiderBubbleTheTimeTakesOnlyItsOwnBox() throws {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "no post matches this"
        root.reload(options: options)
        let host = try XCTUnwrap(root.listHost)
        var post = WidgetHarnessPost(path: "fixture/safe-narrow", html: self.html, width: 200, height: 0, caption: String(repeating: "A caption above a narrow widget. ", count: 6), photos: [])
        post.captionAbove = true
        host.load(posts: [post])
        let deadline = Date(timeIntervalSinceNow: 20.0)
        var found: ChatMessageWidgetBubbleContentNode?
        while Date() < deadline && found == nil {
            root.view.layoutIfNeeded()
            found = host.widgetContentNodes().first { $0.path == "fixture/safe-narrow" }?.node
            if found != nil, let node = found, self.widgetView(in: node.view) == nil {
                found = nil
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        let node = try XCTUnwrap(found)
        let date = try XCTUnwrap(node.subnodes?.first { $0 is ChatMessageDateAndStatusNode })
        let widget = try XCTUnwrap(self.widgetView(in: node.view)).convert(try XCTUnwrap(self.widgetView(in: node.view)).bounds, to: node.view)
        let pillBox = date.frame.insetBy(dx: -8.0, dy: -8.0)
        // In the widget's own corner (where a box anchored at it reached), away from the pill's box.
        let point = CGPoint(x: widget.maxX - 30.0, y: date.frame.midY)
        XCTAssertLessThan(widget.width + 40.0, node.bounds.width, "the bubble is not wider than the widget")
        XCTAssertTrue(widget.contains(point) && !pillBox.contains(point), "\(widget) \(pillBox) \(point)")
        guard case .ignore = node.tapActionAtPoint(point, gesture: .tap, isEstimating: false).content else {
            return XCTFail("a tap on the widget beside the time is the bubble's")
        }
        // The pill's own box stays the bubble's.
        if case .ignore = node.tapActionAtPoint(CGPoint(x: date.frame.midX, y: date.frame.midY), gesture: .tap, isEstimating: false).content {
            XCTFail("a tap on the time goes to the widget")
        }
    }

    /// The deferred items (the reviews' lifted-selection minor): while the bubble is lifted, the selection over the widget
    /// takes touches on the time too (no shrink applies there, and its knobs may sit in the corner).
    func testALiftedBubblesSelectionTakesTouchesOnTheTime() throws {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "no post matches this"
        options.holdsMenu = true
        root.reload(options: options)
        defer {
            root.listHost?.endContextMenu()
        }
        let host = try XCTUnwrap(root.listHost)
        host.load(posts: [WidgetHarnessPost(path: "fixture/safe-lifted", html: self.html, width: 0, height: 0, caption: "", photos: [])])
        _ = self.told(root, paths: ["fixture/safe-lifted"])
        host.openContextMenuOnNewestWidget()
        let deadline = Date(timeIntervalSinceNow: 20.0)
        while Date() < deadline && self.count(TextSelectionNodeView.self, in: root.view) == 0 {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        XCTAssertEqual(self.count(TextSelectionNodeView.self, in: root.view), 1, "no selection overlay after the lift")
        let node = try XCTUnwrap(host.widgetContentNodes().first { $0.path == "fixture/safe-lifted" }?.node)
        let date = try XCTUnwrap(node.subnodes?.first { $0 is ChatMessageDateAndStatusNode })
        var hit = node.view.hitTest(CGPoint(x: date.frame.midX, y: date.frame.midY), with: nil)
        var reachesSelection = false
        while let view = hit {
            reachesSelection = reachesSelection || view is TextSelectionNodeView
            hit = view.superview
        }
        XCTAssertTrue(reachesSelection, "the selection does not get a touch on the time")
    }

    private func count<T>(_ type: T.Type, in view: UIView) -> Int {
        return (view is T ? 1 : 0) + view.subviews.reduce(0) { $0 + self.count(type, in: $1) }
    }

    private func widgetView(in view: UIView) -> MessageWidgetView? {
        for subview in view.subviews {
            if let widget = subview as? MessageWidgetView ?? self.widgetView(in: subview) {
                return widget
            }
        }
        return nil
    }
}
