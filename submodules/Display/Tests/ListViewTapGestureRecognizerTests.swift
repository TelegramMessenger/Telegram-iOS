import XCTest
import UIKit
@testable import Display

/// The chat's date pill and gutter avatar are tapped through `ListViewTapGestureRecognizer`. A plain
/// `UITapGestureRecognizer` still recognizes a touch that slid several points, so a slight swipe that stays under
/// the list pan's 10pt hysteresis landed as a tap on the floating date pill, and the chat jumped to that date.
///
/// These pin the decision, not the `state = .failed` write it leads to: a recognizer with no view in a test process
/// ignores state writes, so that line is covered only by the simulator.
final class ListViewTapGestureRecognizerTests: XCTestCase {
    func testASlightSwipeIsNotATap() {
        let recognizer = ListViewTapGestureRecognizer(target: nil, action: nil)
        recognizer.noteTouchBegan(at: CGPoint(x: 100.0, y: 200.0))
        recognizer.noteTouchMoved(to: CGPoint(x: 100.0, y: 206.0))
        XCTAssertTrue(recognizer.touchMovedTooFar)
    }

    func testJitterWithinTheSlopStaysATap() {
        let recognizer = ListViewTapGestureRecognizer(target: nil, action: nil)
        recognizer.noteTouchBegan(at: CGPoint(x: 100.0, y: 200.0))
        recognizer.noteTouchMoved(to: CGPoint(x: 101.0, y: 201.5))
        recognizer.noteTouchMoved(to: CGPoint(x: 99.0, y: 199.0))
        XCTAssertFalse(recognizer.touchMovedTooFar)
    }

    func testMovementIsMeasuredFromWhereTheTouchBegan() {
        let recognizer = ListViewTapGestureRecognizer(target: nil, action: nil)
        recognizer.noteTouchBegan(at: CGPoint(x: 100.0, y: 200.0))
        recognizer.noteTouchMoved(to: CGPoint(x: 100.0, y: 201.5))
        recognizer.noteTouchMoved(to: CGPoint(x: 100.0, y: 203.0))
        XCTAssertTrue(recognizer.touchMovedTooFar)
    }

    func testResetStartsTheNextTouchAfresh() {
        let recognizer = ListViewTapGestureRecognizer(target: nil, action: nil)
        recognizer.noteTouchBegan(at: CGPoint(x: 100.0, y: 200.0))
        recognizer.noteTouchMoved(to: CGPoint(x: 100.0, y: 206.0))
        recognizer.reset()
        recognizer.noteTouchBegan(at: CGPoint(x: 50.0, y: 50.0))
        recognizer.noteTouchMoved(to: CGPoint(x: 50.0, y: 51.0))
        XCTAssertFalse(recognizer.touchMovedTooFar)
    }
}
