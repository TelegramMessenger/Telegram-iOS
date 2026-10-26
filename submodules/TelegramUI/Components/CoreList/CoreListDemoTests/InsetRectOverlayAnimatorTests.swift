import XCTest
import QuartzCore
@testable import CoreListDemo

final class InsetRectOverlayAnimatorTests: XCTestCase {
    private func animation(_ property: ListAnimatedProperty,
                           on layer: CALayer) throws -> CABasicAnimation {
        let key = CoreAnimationCompiler().animationKey(for: property)
        return try XCTUnwrap(layer.animation(forKey: key) as? CABasicAnimation)
    }

    /// Endpoints as `[from, to]`. CoreList emits CAAnimationUtils-shaped `CABasicAnimation`s, so
    /// there is no sampled array; the callers here only ever read the first entry.
    private func values(_ animation: CABasicAnimation) throws -> [NSNumber] {
        let from = try XCTUnwrap(animation.fromValue as? NSNumber)
        let to = try XCTUnwrap(animation.toValue as? NSNumber)
        return [from, to]
    }

    func testTransitionCompilesAdditivePositionAndAbsoluteExtentTracks() throws {
        let layer = CALayer()
        layer.frame = CGRect(x: 0, y: 0, width: 100, height: 200)
        let animator = InsetRectOverlayAnimator()

        animator.transition(layer: layer,
                            from: CGRect(x: 0, y: 0, width: 100, height: 200),
                            to: CGRect(x: 30, y: 20, width: 80, height: 140),
                            transition: .easeInOut(duration: 0.5),
                            at: 3)

        XCTAssertEqual(layer.frame, CGRect(x: 30, y: 20, width: 80, height: 140))
        let x = try animation(.positionX, on: layer)
        let y = try animation(.positionY, on: layer)
        let width = try animation(.width, on: layer)
        let height = try animation(.height, on: layer)
        XCTAssertTrue(x.isAdditive)
        XCTAssertTrue(y.isAdditive)
        XCTAssertFalse(width.isAdditive)
        XCTAssertFalse(height.isAdditive)
        for track in [x, y, width, height] {
            // This layer is never in a window, so the implicit origin is deterministically 0. What the
            // assertion was actually checking — that the animator handed the compiler the clock it
            // was given — is the declared phase axis, and that is exact with no commit.
            XCTAssertEqual(track.beginTime, 0, accuracy: 1e-9)
            XCTAssertEqual(try XCTUnwrap(track.coreListDeclaredStartTime), 3, accuracy: 1e-9)
            XCTAssertEqual(track.duration, 0.5, accuracy: 1e-9)
        }
        XCTAssertEqual(try XCTUnwrap(try values(x).first).doubleValue, -20, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(try values(y).first).doubleValue, 10, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(try values(width).first).doubleValue, 100, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(try values(height).first).doubleValue, 200, accuracy: 1e-6)
        // The curve is no longer a sampled array — CA evaluates it from the timing function, so what
        // there is to verify is that the right control points were handed over. `.easeInOut` is
        // bezierPoint(0.42, 0, 0.58, 1); `Curve.solve` computes that same bezier, and
        // CoreAnimationCompilerParityTests' paused-layer sweep proves the rendered result matches.
        let timing = try XCTUnwrap(x.timingFunction)
        var controlPoint = [Float](repeating: 0, count: 2)
        timing.getControlPoint(at: 1, values: &controlPoint)
        XCTAssertEqual(controlPoint[0], 0.42, accuracy: 1e-6)
        XCTAssertEqual(controlPoint[1], 0.0, accuracy: 1e-6)
        timing.getControlPoint(at: 2, values: &controlPoint)
        XCTAssertEqual(controlPoint[0], 0.58, accuracy: 1e-6)
        XCTAssertEqual(controlPoint[1], 1.0, accuracy: 1e-6)
    }

    func testReplacementStartsFromSampledPresentationAndRejectsStaleCompletion() throws {
        let layer = CALayer()
        let animator = InsetRectOverlayAnimator()
        animator.transition(layer: layer,
                            from: CGRect(x: 0, y: 0, width: 100, height: 200),
                            to: CGRect(x: 0, y: 100, width: 100, height: 100),
                            transition: .easeInOut(duration: 0.5),
                            at: 1)
        let first = try XCTUnwrap(animator.generation(for: .positionY, on: layer))

        animator.transition(layer: layer,
                            from: CGRect(x: 0, y: 40, width: 100, height: 160),
                            to: CGRect(x: 0, y: 0, width: 100, height: 200),
                            transition: .easeInOut(duration: 0.5),
                            at: 1.2)

        let replacement = try XCTUnwrap(animator.generation(for: .positionY, on: layer))
        XCTAssertNotEqual(replacement, first)
        let y = try animation(.positionY, on: layer)
        XCTAssertEqual(try XCTUnwrap(try values(y).first).doubleValue, 20, accuracy: 1e-6)
        XCTAssertEqual(y.beginTime, 0, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(y.coreListDeclaredStartTime), 1.2, accuracy: 1e-9)

        animator.complete(property: .positionY, generation: first, on: layer)
        XCTAssertEqual(animator.generation(for: .positionY, on: layer), replacement)
    }

    func testViewTransitionScalesDurationExactlyOnce() throws {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 500))
        let animator = InsetRectOverlayAnimator(
            mediaTime: { 2 },
            durationFactor: { 10 }
        )

        animator.transition(view: view,
                            to: CGRect(x: 0, y: 300, width: 100, height: 200),
                            transition: .easeInOut(duration: 0.5))

        XCTAssertEqual(try animation(.positionY, on: view.layer).duration, 5, accuracy: 1e-9)
        XCTAssertEqual(try animation(.height, on: view.layer).duration, 5, accuracy: 1e-9)
    }
}
