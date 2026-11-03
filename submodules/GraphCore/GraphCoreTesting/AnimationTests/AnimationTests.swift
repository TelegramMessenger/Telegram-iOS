import XCTest
import QuartzCore
@testable import GraphCore2
@testable import GraphCoreLegacy

private final class DeltaRecorder: GraphCore2.DisplayLinkListner {
    var deltas: [TimeInterval] = []

    func update(delta: TimeInterval) {
        self.deltas.append(delta)
    }
}

final class AnimationTests: XCTestCase {
    private func samples(_ function: GraphCore2.TimeFunction, count: Int = 1000) -> [Double] {
        return (0 ... count).map { function.profress(time: Double($0) / Double(count), duration: 1) }
    }

    func testEaseOutStartsAtZeroAndEndsAtOne() {
        XCTAssertEqual(GraphCore2.TimeFunction.easeOut.profress(time: 0, duration: 1), 0, accuracy: 1e-12)
        XCTAssertEqual(GraphCore2.TimeFunction.easeOut.profress(time: 1, duration: 1), 1, accuracy: 1e-9)
    }

    func testLegacyEaseOutPrecedenceBugIsFixed() {
        XCTAssertGreaterThan(GraphCoreLegacy.TimeFunction.easeOut.profress(time: 0, duration: 1), 0.0009)
        XCTAssertEqual(GraphCore2.TimeFunction.easeOut.profress(time: 0, duration: 1), 0, accuracy: 1e-12)
    }

    func testCurvesAreMonotonicAndBounded() {
        for function in [GraphCore2.TimeFunction.linear, .easeIn, .easeOut, .easeInOut] {
            let values = self.samples(function)
            XCTAssertEqual(values.first!, 0, accuracy: 1e-9, "\(function)")
            XCTAssertEqual(values.last!, 1, accuracy: 1e-9, "\(function)")
            for (previous, next) in zip(values, values.dropFirst()) {
                XCTAssertLessThanOrEqual(previous, next + 1e-12, "\(function) is not monotonic")
            }
            XCTAssertLessThanOrEqual(values.max()!, 1 + 1e-9, "\(function) overshoots")
            XCTAssertGreaterThanOrEqual(values.min()!, -1e-9, "\(function) undershoots")
        }
    }

    func testEaseInOutIsSymmetric() {
        let function = GraphCore2.TimeFunction.easeInOut
        for i in 0 ... 100 {
            let t = Double(i) / 100
            XCTAssertEqual(function.profress(time: t, duration: 1) + function.profress(time: 1 - t, duration: 1), 1, accuracy: 1e-9)
        }
    }

    func testAnimationReachesEndAndCompletesOnce() {
        var refreshes = 0
        var completions = 0
        let controller = GraphCore2.AnimationController<CGFloat>(current: 0, refreshClosure: { refreshes += 1 })
        controller.completionClosure = { completions += 1 }
        controller.animate(to: 10, duration: 0.25, timeFunction: .easeOut)
        XCTAssertTrue(controller.isAnimating)
        var values: [CGFloat] = []
        for _ in 0 ..< 40 {
            controller.update(delta: 1.0 / 120.0)
            values.append(controller.current)
        }
        XCTAssertEqual(controller.current, 10)
        XCTAssertFalse(controller.isAnimating)
        XCTAssertEqual(completions, 1)
        XCTAssertEqual(refreshes, 1 + 31)
        for (previous, next) in zip(values, values.dropFirst()) {
            XCTAssertLessThanOrEqual(previous, next + 1e-9)
        }
        XCTAssertTrue(values.allSatisfy { $0 >= 0 && $0 <= 10 + 1e-9 })
    }

    func testInterruptionContinuesFromCurrentValue() {
        let controller = GraphCore2.AnimationController<CGFloat>(current: 0, refreshClosure: nil)
        controller.animate(to: 10, duration: 0.3, timeFunction: .easeInOut)
        for _ in 0 ..< 18 {
            controller.update(delta: 1.0 / 120.0)
        }
        let middle = controller.current
        XCTAssertGreaterThan(middle, 0)
        XCTAssertLessThan(middle, 10)
        controller.animate(to: 0, duration: 0.3, timeFunction: .easeInOut)
        XCTAssertEqual(controller.start, middle)
        controller.update(delta: 1.0 / 120.0)
        XCTAssertLessThan(abs(controller.current - middle), 0.05)
        XCTAssertLessThanOrEqual(controller.current, middle)
        controller.set(current: 0)
    }

    func testSetCurrentStopsAnimation() {
        var completions = 0
        let controller = GraphCore2.AnimationController<CGFloat>(current: 0, refreshClosure: nil)
        controller.completionClosure = { completions += 1 }
        controller.animate(to: 10, duration: 0.3)
        controller.update(delta: 0.05)
        controller.set(current: 5)
        XCTAssertFalse(controller.isAnimating)
        controller.update(delta: 0.05)
        XCTAssertEqual(controller.current, 5)
        XCTAssertEqual(completions, 0)
    }

    func testZeroDurationIsImmediate() {
        let controller = GraphCore2.AnimationController<CGFloat>(current: 0, refreshClosure: nil)
        controller.animate(to: 7, duration: 0)
        XCTAssertEqual(controller.current, 7)
        XCTAssertFalse(controller.isAnimating)
    }

    func testRangeAnimationInterpolatesBothBounds() {
        let controller = GraphCore2.AnimationController<ClosedRange<CGFloat>>(current: 0 ... 10, refreshClosure: nil)
        controller.animate(to: 10 ... 30, duration: 0.2, timeFunction: .linear)
        controller.update(delta: 0.1)
        XCTAssertEqual(controller.current.lowerBound, 5, accuracy: 1e-6)
        XCTAssertEqual(controller.current.upperBound, 20, accuracy: 1e-6)
        controller.update(delta: 0.2)
        XCTAssertEqual(controller.current, 10 ... 30)
    }

    func testDisplayLinkDeltasAreNeverNegative() {
        let recorder = DeltaRecorder()
        let service = GraphCore2.DisplayLinkService.shared
        service.add(listner: recorder)
        let base = CACurrentMediaTime() + 1
        service.fire(frameTime: base)
        service.fire(frameTime: base - 0.5)
        service.fire(frameTime: base + 1.0 / 120.0)
        service.remove(listner: recorder)
        service.fire(frameTime: base + 1)
        XCTAssertEqual(recorder.deltas.count, 3)
        XCTAssertGreaterThan(recorder.deltas[0], 0)
        XCTAssertEqual(recorder.deltas[1], 0)
        XCTAssertEqual(recorder.deltas[2], 1.0 / 120.0, accuracy: 1e-9)
    }
}
