import ChatMessageDateAndStatusNode
import ChatMessageWidgetBubbleContentNode
import Display
import MessageWidget
import UIKit
import XCTest
@testable import WidgetHarnessLib

/// Tier 1 (in the app process), widget-sandbox v0.4.0 through the REAL bubble (sdk-v1 §2.17, §5.12): a widget with no
/// caption below it (none, or one shown above it) is told the band and corner its bubble's time covers, and a tap on the
/// time is the bubble's; with a caption below the time is in the caption's line and the widget is told nothing.
final class WidgetHarnessSafeAreaTests: XCTestCase {
    /// Shows what it was told as its `data-log` (the readout's `log` line), at boot and on every change; claims every
    /// horizontal drag (`touch-action: none`) and counts its downs in `data-downs`.
    private let html = "<!doctype html><body style=\"margin:0;touch-action:none\"><div style=\"height:80px\">safe</div><script>"
        + "function show() { document.documentElement.setAttribute('data-log', JSON.stringify(TelegramWidget.contentSafeAreaInset)); }"
        + "show(); TelegramWidget.onEvent('contentSafeAreaChanged', show); let downs = 0;"
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

    /// Each post's last `contentSafeAreaInset`, once all three have one, or after 20 s.
    private func told(_ root: WidgetHarnessRootViewController) -> [String: [String: Double]] {
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
            if told.count == 3 {
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

    /// sdk-v1 §5.12: the time is a view over the widget, and taps on it are the client's: the bubble's tap action there,
    /// no touch for the widget's view, and no claim of the swipe to reply (the final review's I-1: asking it pressed the
    /// widget early, a pointerdown at the time).
    func testATapOnTheTimeIsTheBubbles() throws {
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
        // The swipe to reply asks every content node at the touch's down, whatever view it hit.
        XCTAssertFalse(node.claimsHorizontalDrag(at: point), "the widget claims a drag from the time")
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        let widgetView = try XCTUnwrap(self.widgetView(in: node.view))
        XCTAssertNil(widgetView.documentElementAttribute("data-downs"), "the widget got a pointerdown at the time")
        // Away from the time the widget still claims its drags.
        XCTAssertTrue(node.claimsHorizontalDrag(at: CGPoint(x: 20.0, y: 20.0)))
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
