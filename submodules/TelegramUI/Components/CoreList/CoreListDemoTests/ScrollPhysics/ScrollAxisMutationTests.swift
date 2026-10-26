import XCTest
import CoreGraphics
@testable import CoreListDemo

final class ScrollAxisMutationTests: XCTestCase {

    private func makeAxis(offset: CGFloat = 0, min: CGFloat = 0, max: CGFloat = 1000) -> ScrollAxis {
        ScrollAxis(offset: offset, min: min, max: max, range: 800, rate: 0.998, scale: 1)
    }

    func test_setBounds_movesBouncePoint_preservingDynamicState() {
        var axis = makeAxis(offset: 100, min: 0, max: 1000)
        axis.beginDrag()                                   // dragStartOffset = 100
        axis.drag(translation: -200)  // proposed = 100 - (-200) = 300
        XCTAssertEqual(axis.offset, 300, accuracy: 0.001)
        let velBefore = axis.velocity                      // = -(-500) * 0.001 = 0.5

        axis.setBounds(min: 0, max: 250)                   // new max BELOW the current offset
        XCTAssertEqual(axis.offset, 300, accuracy: 0.001, "offset preserved by setBounds")
        XCTAssertEqual(axis.velocity, velBefore, accuracy: 1e-9, "velocity preserved")
        XCTAssertEqual(axis.phase, .dragging, "phase preserved")

        // A further drag to the same proposed offset now rubber-bands against the NEW max (250).
        axis.drag(translation: -200)  // proposed 300, max 250 → resisted
        XCTAssertLessThan(axis.offset, 300, "rubber-banded below the old free value")
        XCTAssertGreaterThan(axis.offset, 250, "but still past the new max (overscroll)")
    }

    func test_shift_reanchorsDrag_soCumulativeDragStaysContinuous() {
        var axis = makeAxis(offset: 0, min: -10_000_000, max: 10_000_000)
        axis.beginDrag()                                   // dragStartOffset = 0
        axis.drag(translation: -50)
        XCTAssertEqual(axis.offset, 50, accuracy: 0.001)   // 0 - (-50)

        axis.shift(by: 1000)
        XCTAssertEqual(axis.offset, 1050, accuracy: 0.001, "offset moved by the shift")

        // The SAME cumulative translation maps to the shifted offset (dragStartOffset moved too).
        axis.drag(translation: -50)
        XCTAssertEqual(axis.offset, 1050, accuracy: 0.001, "drag stayed continuous across the re-base")
    }

    func test_shift_duringDeceleration_movesOffset_leavesVelocity() {
        var axis = makeAxis(offset: 0, min: -10_000_000, max: 10_000_000)
        axis.beginDrag()
        axis.drag(translation: 0)
        axis.applyRelease(velocity: 3.0)          // was drag(-3000)×2 + endDrag: 0.75·3 + 0.25·3
        _ = axis.step(dtMs: 16)
        let offsetAfterStep = axis.offset
        let velAfterStep = axis.velocity

        axis.shift(by: 500)
        XCTAssertEqual(axis.offset, offsetAfterStep + 500, accuracy: 0.001)
        XCTAssertEqual(axis.velocity, velAfterStep, accuracy: 1e-12, "shift leaves velocity untouched")
    }

    func test_reseedDeceleration_setsStateAndReproducesContinuation() {
        // An axis flung to a known decelerating state.
        var flung = makeAxis(offset: 0, min: -10_000_000, max: 10_000_000)
        flung.beginDrag()
        flung.drag(translation: 0)
        flung.applyRelease(velocity: 3.0)         // was drag(-3000)×2 + endDrag: 0.75·3 + 0.25·3
        // Step it forward a few frames to a mid-flight (offset, velocity).
        for _ in 0..<10 { _ = flung.step(dtMs: 1000.0 / 120) }
        let midOffset = flung.offset
        let midVel = flung.velocity

        // A fresh axis reseeded at that mid-flight state must continue identically.
        var reseeded = makeAxis(offset: 0, min: -10_000_000, max: 10_000_000)
        reseeded.reseedDeceleration(offset: midOffset, velocity: midVel)
        XCTAssertEqual(reseeded.phase, .decelerating)
        XCTAssertEqual(reseeded.offset, midOffset, accuracy: 0.0001)
        XCTAssertEqual(reseeded.velocity, midVel, accuracy: 0.0001)

        // Stepping both forward yields the same path (reseed reproduces the continuation).
        for _ in 0..<30 {
            let a = flung.step(dtMs: 1000.0 / 120)
            let b = reseeded.step(dtMs: 1000.0 / 120)
            XCTAssertEqual(a.written, b.written, accuracy: 0.5)
        }
    }
}
