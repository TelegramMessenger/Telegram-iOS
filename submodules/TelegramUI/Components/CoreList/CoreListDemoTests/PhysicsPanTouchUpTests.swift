import XCTest
import UIKit
@testable import CoreListDemo

/// A touch the list's pan stops receiving (another recognizer won it: a row's swipe, a pager, the chat's swipe to
/// reply) still reports its lift, so content caught overscrolled at touch-down springs back
/// (`PhysicsScrollEngine.handleTouchUp`). A failed recognizer gets no `touchesEnded`; its `reset()` is the only notice
/// that the touch is over.
final class PhysicsPanTouchUpTests: XCTestCase {
    func test_aResetWithoutTheTouchEndingReportsTheTouchUpOnce() {
        let pan = PhysicsPanGestureRecognizer(target: nil, action: nil)
        var ups = 0
        pan.onTouchUp = { ups += 1 }
        pan.noteTouchDown(timestamp: 1.0)
        pan.reset()
        XCTAssertEqual(ups, 1, "the failed pan's reset reports the touch-up the engine never got")
        pan.reset()
        XCTAssertEqual(ups, 1, "only once per touch")
    }

    func test_aTouchThatEndedReportsItsUpOnlyOnce() {
        let pan = PhysicsPanGestureRecognizer(target: nil, action: nil)
        var ups = 0
        pan.onTouchUp = { ups += 1 }
        pan.noteTouchDown(timestamp: 1.0)
        pan.noteTouchUp()
        pan.reset()
        XCTAssertEqual(ups, 1, "the reset after a delivered lift adds nothing")
    }

    func test_aResetWithoutATouchReportsNothing() {
        let pan = PhysicsPanGestureRecognizer(target: nil, action: nil)
        var ups = 0
        pan.onTouchUp = { ups += 1 }
        pan.reset()
        XCTAssertEqual(ups, 0, "trackpad scrolls send no touch, and their reset reports none")
    }

    func test_theTouchDownStillReachesTheEngine() {
        let pan = PhysicsPanGestureRecognizer(target: nil, action: nil)
        var downs: [TimeInterval] = []
        pan.onTouchDown = { downs.append($0) }
        pan.noteTouchDown(timestamp: 2.5)
        XCTAssertEqual(downs, [2.5])
    }
}
