import XCTest
import UIKit
@testable import CoreListDemo

/// A finger that lands on a `.keyframe` flight catches it at touch-down (`PhysicsScrollEngine.noteTouchDown`), before
/// any drag. The drag may never begin: the interactive pop recognizer an ancestor declares wins (an edge swipe started
/// on a flinging list), or a `UIControl` under the finger tracks the touch. The content is then still, and the engine
/// must say so: it stayed `.decelerating` with no driver until the next drag, so the next tap on still content read as
/// another catch (`lastTouchCaughtMovingContent`: the inline results' rows selected nothing) and the list reported a
/// deceleration (`isScrollDecelerating`: the chat made no widget resize target).
final class CatchWithoutDragTests: XCTestCase {
    private func flungEngine() -> PhysicsScrollEngine {
        let engine = PhysicsScrollEngine()
        engine.contentHost.bounds.size = CGSize(width: 390, height: 844)
        engine.decelerationMode = .keyframe
        engine.setEdges(min: nil, max: nil)
        func pan(_ state: UIGestureRecognizer.State, translation: CGFloat, velocity: CGFloat) {
            engine.applyPanUpdate(state: state,
                                  translation: CGPoint(x: 0, y: translation),
                                  velocity: CGPoint(x: 0, y: velocity),
                                  forced: false, isIndirect: false)
        }
        pan(.began, translation: -20, velocity: -3000)
        pan(.changed, translation: -60, velocity: -3000)
        pan(.ended, translation: -60, velocity: -3000)
        return engine
    }

    func testACatchLeavesTheContentStillWithoutADrag() {
        let engine = self.flungEngine()
        XCTAssertTrue(engine.isDecelerating, "precondition: a flight runs")
        engine.noteTouchDown(at: CACurrentMediaTime())
        XCTAssertTrue(engine.lastTouchCaughtMovingContent, "precondition: the touch caught the flight")
        XCTAssertFalse(engine.isDecelerating, "the catch left the engine decelerating, with nothing driving it")
        engine.tearDown()
    }

    func testTheNextTouchOnTheCaughtContentIsATap() {
        let engine = self.flungEngine()
        engine.noteTouchDown(at: CACurrentMediaTime())
        // No drag, no further motion: the next finger lands on still content.
        engine.noteTouchDown(at: CACurrentMediaTime())
        XCTAssertFalse(engine.lastTouchCaughtMovingContent, "a tap on still content was taken for a catch")
        engine.tearDown()
    }

    /// The catch keeps the offset where it caught the flight; idling the physics there must not move it.
    func testTheCatchKeepsItsOffset() {
        let engine = self.flungEngine()
        engine.noteTouchDown(at: CACurrentMediaTime())
        let caught = engine.offset
        XCTAssertEqual(engine.contentHost.bounds.origin.y, caught, accuracy: 1e-9, "the model is not where the catch put it")
        engine.noteTouchDown(at: CACurrentMediaTime())
        XCTAssertEqual(engine.offset, caught, accuracy: 1e-9, "a touch on still content moved it")
        engine.tearDown()
    }
}
