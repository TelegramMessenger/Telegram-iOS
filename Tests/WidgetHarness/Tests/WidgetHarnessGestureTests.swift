import Display
import MessageWidget
import UIKit
import UIKit.UIGestureRecognizerSubclass
import XCTest
@testable import WidgetHarnessLib

/// Display's recognizers under a message widget's taken touches and the chat's lock.
final class WidgetHarnessGestureTests: XCTestCase {
    /// A long tap the recognizer cancelled itself (a finger drifting past 2 pt) is still reported, as it always was; only
    /// one failed from outside (a widget took the touches, or the chat's lock holds the finger) reports none.
    func testALongTapItsOwnDriftCancelledIsStillReported() {
        XCTAssertTrue(TapLongTapOrDoubleTapGestureRecognizer.reportsLongTap(in: .cancelled))
        XCTAssertTrue(TapLongTapOrDoubleTapGestureRecognizer.reportsLongTap(in: .possible))
        XCTAssertFalse(TapLongTapOrDoubleTapGestureRecognizer.reportsLongTap(in: .failed))
    }

    /// Failed from outside, the recognizer shows and fires nothing more: the highlight it showed at its touch's begin
    /// (a link under the finger) ends at once rather than when every finger has lifted, and its long tap never comes.
    func testFailedFromOutsideItsHighlightEnds() {
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: nil, action: nil)
        var highlights: [CGPoint?] = []
        var longTaps = 0
        recognizer.highlight = { highlights.append($0) }
        recognizer.longTap = { _, _ in longTaps += 1 }
        recognizer.touchesBegan([UITouch()], with: UIEvent())
        XCTAssertEqual(highlights.count, 1)
        XCTAssertNotNil(highlights.first ?? nil)
        recognizer.state = .failed
        XCTAssertEqual(highlights.count, 2)
        XCTAssertNil(highlights.last ?? CGPoint.zero)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
        XCTAssertEqual(longTaps, 0)
    }

    private func find<T>(_ type: T.Type, in view: UIView) -> [T] {
        return ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { self.find(type, in: $0) }
    }

    /// widget-sandbox v0.1.2 on an iPad: a pointer's secondary click on a part that claims no holds is the chat's, and
    /// opens the message's menu as a secondary click elsewhere on the bubble does (the bubble's own recognizer fails over
    /// a live widget, whose taps are its own).
    func testAPointersSecondaryClickOpensTheMessagesMenu() throws {
        let root = try XCTUnwrap(AppDelegate.widgetHarnessRootViewController)
        root.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0)
        let deadline = Date(timeIntervalSinceNow: 30.0)
        while root.listHost == nil && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "double-tap"
        root.reload(options: options)
        let live = { root.readoutLines().contains { $0.hasPrefix("bubble ") && $0.contains(" widget") } }
        let until = { (condition: () -> Bool) -> Bool in
            let deadline = Date(timeIntervalSinceNow: 20.0)
            while Date() < deadline {
                root.view.layoutIfNeeded()
                if condition() {
                    return true
                }
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            }
            return false
        }
        XCTAssertTrue(until(live), root.readoutLines().joined(separator: " | "))
        let widgetView = try XCTUnwrap(self.find(MessageWidgetView.self, in: root.view).first)
        widgetView.onSecondaryClick?(CGPoint(x: 40.0, y: 150.0))
        XCTAssertTrue(until { root.readoutLines().contains("contextMenu fixture/double-tap.html") }, root.readoutLines().joined(separator: " | "))
        root.listHost?.endContextMenu()
    }
}
