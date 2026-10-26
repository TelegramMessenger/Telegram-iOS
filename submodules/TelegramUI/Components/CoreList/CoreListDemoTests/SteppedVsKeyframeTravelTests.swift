import XCTest
import UIKit
@testable import CoreListDemo

/// `.stepped` and `.keyframe` share `PhysicsScrollCore`, `ReleaseDecision` and the release velocity —
/// they differ ONLY in how the decelerating path is driven. So any difference in how far a flick
/// travels between them is a defect in the bake or the flight, never in the release.
///
/// Reported from the demo: `Physics·step` behaves as expected, `Physics·keyframe` under-travels,
/// reproducible with a long drag ending in a fast flick.
final class SteppedVsKeyframeTravelTests: XCTestCase {

    // MARK: - Layer 1: the core alone. Is the BAKED path the same length as the STEPPED one?

    private func makeCore(viewport: CGSize = CGSize(width: 390, height: 800)) -> PhysicsScrollCore {
        PhysicsScrollCore(contentHost: UIView(frame: CGRect(origin: .zero, size: viewport)))
    }

    /// A released core, driven to rest by the `.stepped` driver's own loop.
    private func steppedFinalOffset(edges: (CGFloat?, CGFloat?), velocity: CGFloat) -> CGFloat {
        let core = makeCore()
        core.setEdges(min: edges.0, max: edges.1)
        core.beginTouchTracking(at: 0)
        core.beginDrag()
        core.drag(translation: 0, velocity: velocity)
        core.drag(translation: 0, velocity: velocity)
        XCTAssertTrue(core.endDrag(recognizerVelocity: velocity, at: 0))
        var settled = false
        var guardCount = 0
        while !settled && guardCount < 20_000 {
            settled = core.step(dtMs: 1000.0 / 120.0)
            guardCount += 1
        }
        XCTAssertTrue(settled, "stepped driver settled")
        return core.offset
    }

    /// The same release, baked once the way `.keyframe` bakes it.
    private func bakedFinalOffset(edges: (CGFloat?, CGFloat?), velocity: CGFloat) -> CGFloat {
        let core = makeCore()
        core.setEdges(min: edges.0, max: edges.1)
        core.beginTouchTracking(at: 0)
        core.beginDrag()
        core.drag(translation: 0, velocity: velocity)
        core.drag(translation: 0, velocity: velocity)
        XCTAssertTrue(core.endDrag(recognizerVelocity: velocity, at: 0))
        return core.bakeTrajectory().finalOffset
    }

    func test_openEdges_bakedPathTravelsAsFarAsTheSteppedOne() {
        let stepped = steppedFinalOffset(edges: (nil, nil), velocity: -4000)
        let baked = bakedFinalOffset(edges: (nil, nil), velocity: -4000)
        XCTAssertEqual(baked, stepped, accuracy: 1.0,
                       "same integrator, same release — the driver must not change the distance")
    }

    func test_finiteFarEdge_bakedPathTravelsAsFarAsTheSteppedOne() {
        // The demo's Virtual List declares FINITE edges: a fixed item count has a known content extent.
        let stepped = steppedFinalOffset(edges: (0, 100_000), velocity: -4000)
        let baked = bakedFinalOffset(edges: (0, 100_000), velocity: -4000)
        XCTAssertEqual(baked, stepped, accuracy: 1.0)
    }

    // MARK: - Layer 2: through the list. Does a flick travel the same distance in each mode?

    private func flickTravel(mode: TestScrollEngine.DecelerationMode,
                             offsetVelocity: CGFloat) -> (travel: CGFloat, settledAt: CGFloat) {
        let fixture = PhysicsListFixture(itemCount: 4000, itemHeight: 50, decelerationMode: mode)
        _ = fixture.run(duration: 0.1)
        let before = fixture.offset
        fixture.simulateFlick(offsetVelocity: offsetVelocity)
        _ = fixture.runUntilSettled(max: 12.0)
        return (fixture.offset - before, fixture.offset)
    }

    func test_aFlickTravelsTheSameDistanceInBothModes() {
        let stepped = flickTravel(mode: .stepped, offsetVelocity: 4000)
        let keyframe = flickTravel(mode: .keyframe, offsetVelocity: 4000)

        XCTAssertEqual(keyframe.travel, stepped.travel, accuracy: 5.0,
                       "stepped travelled \(stepped.travel), keyframe travelled \(keyframe.travel)")
    }

    func test_aFastFlickTravelsTheSameDistanceInBothModes() {
        // The reported repro is a LONG drag ending in a VERY fast flick, so the release velocity is
        // high and the path long — which is where a per-rebake error would accumulate.
        let stepped = flickTravel(mode: .stepped, offsetVelocity: 9000)
        let keyframe = flickTravel(mode: .keyframe, offsetVelocity: 9000)

        XCTAssertEqual(keyframe.travel, stepped.travel, accuracy: 5.0,
                       "stepped travelled \(stepped.travel), keyframe travelled \(keyframe.travel)")
    }
}
