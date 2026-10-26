import XCTest
import QuartzCore
@testable import CoreListDemo

/// Slow Animations must reach every CoreList animation, expressed as `speed` exactly as
/// `CAAnimationUtils` expresses it — a longer `duration` would render the same but would not match
/// what the rest of the app emits.
///
/// `debugAnimationDurationFactorOverride` stands in for the Simulator toggle so this is deterministic
/// and runs in CI; the real coefficient reads 1.0 unless someone has the toggle on.
final class SlowAnimationsProbeTests: XCTestCase {

    /// Does the factor reach the EMITTED animation on the model path, and as `speed`?
    func testModelPathExpressesSlowModeAsSpeed() throws {
        UIView.debugAnimationDurationFactorOverride = 10
        defer { UIView.debugAnimationDurationFactorOverride = nil }

        let compiler = CoreAnimationCompiler()
        let controller = ListAnimationController(compiler: compiler, mediaTime: { 0 })
        let layer = CALayer()

        let mutation = controller.transitionPosition(identity: AnyHashable("row"),
                                                     layer: layer,
                                                     oldSettledY: 0,
                                                     newSettledY: 100,
                                                     transition: .easeInOut(duration: 0.3),
                                                     transactionTime: 0)
        guard case let .started(track) = mutation else { return XCTFail("expected a track") }

        let installed = try XCTUnwrap(layer.animation(forKey: compiler.animationKey(for: .positionY)))

        // The model reasons on the scaled clock — its deadlines and reaping depend on it.
        XCTAssertEqual(track.duration, 3.0, accuracy: 1e-9, "model track must be scaled")
        // The EMITTED animation keeps a logical duration and carries the factor as speed, which is
        // what CAAnimationUtils does. Asserting the duration is 3.0 here would lock in the old
        // pre-scaling mechanism.
        XCTAssertEqual(installed.duration, 0.3, accuracy: 1e-9,
                       "emitted duration must stay LOGICAL")
        XCTAssertEqual(installed.speed, 0.1, accuracy: 1e-6,
                       "the drag coefficient must appear as speed")
        // 1e-6, not 1e-9: `speed` is a Float, so 1/10 is inexact and the quotient lands near
        // 2.99999996.
        XCTAssertEqual(installed.duration / Double(installed.speed), 3.0, accuracy: 1e-6,
                       "and the wall-clock result must still be 10x")
    }

    /// And on the executor path?
    func testExecutorPathExpressesSlowModeAsSpeed() throws {
        UIView.debugAnimationDurationFactorOverride = 10
        defer { UIView.debugAnimationDurationFactorOverride = nil }

        let layer = CALayer()
        layer.position = CGPoint(x: 0, y: 0)
        CoreListTransition.easeInOut(duration: 0.3).setPositionY(layer: layer, 100)
        let installed = try XCTUnwrap(layer.animation(forKey: "position.y"))
        XCTAssertEqual(installed.duration, 0.3, accuracy: 1e-9,
                       "emitted duration must stay LOGICAL")
        XCTAssertEqual(installed.speed, 0.1, accuracy: 1e-6,
                       "the drag coefficient must appear as speed")
        XCTAssertEqual(installed.duration / Double(installed.speed), 3.0, accuracy: 1e-6)
    }


}
