import Display
import UIKit
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
}
