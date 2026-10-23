import Display
import UIKit
import UIKit.UIGestureRecognizerSubclass
import XCTest

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
}
