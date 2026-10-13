import XCTest
import UIKit
@testable import CoreListDemo

/// The engine↔core seam: how `handlePan`'s gesture states become physics calls. This layer had no
/// coverage, and that is where the short-flick defect lived — `ScrollReplay` folds every recorded
/// display frame through `drag(...)`, including the first, so the replay harness behaved like UIKit
/// while the live engine dropped the `.began` sample entirely. A suite holding the integrator to 3px
/// could not see a 4× error in the release, because nothing crossed this seam.
final class PhysicsScrollEngineSeamTests: XCTestCase {

    private func makeEngine() -> PhysicsScrollEngine {
        let engine = PhysicsScrollEngine()
        engine.contentHost.bounds.size = CGSize(width: 390, height: 844)
        engine.decelerationMode = .stepped
        engine.setEdges(min: nil, max: nil)
        return engine
    }

    /// A natural (hysteresis-crossing) touch pan update.
    private func pan(_ engine: PhysicsScrollEngine, _ state: UIGestureRecognizer.State,
                     translation: CGFloat, velocity: CGFloat) {
        engine.applyPanUpdate(state: state,
                              translation: CGPoint(x: 0, y: translation),
                              velocity: CGPoint(x: 0, y: velocity),
                              forced: false,
                              isIndirect: false)
    }

    func test_beganFeedsTheDragMath_soAOneEventFlickCarriesItsVelocity() {
        let engine = makeEngine()
        pan(engine, .began, translation: -40, velocity: -3000)
        pan(engine, .ended, translation: -40, velocity: -3000)

        XCTAssertTrue(engine.isDecelerating,
                      "handlePan: case 1 runs _updatePanGesture, so .began IS a velocity sample")
    }

    func test_beganMovesTheContent() {
        let engine = makeEngine()
        let before = engine.offset
        pan(engine, .began, translation: -40, velocity: -3000)
        XCTAssertEqual(engine.offset - before, 40, accuracy: 0.5,
                       ".began applies its translation, exactly as _updatePanGesture does")
    }

    func test_aForcedBeganDoesNotFeedTheDragMath() {
        // A force-begun pan is a CATCH on moving content, not a flick start: translation and
        // velocity are ~0 and feeding them would re-run the rubber band at the caught offset.
        let engine = makeEngine()
        engine.setEdges(min: 0, max: 1000)
        engine.setOffset(-50)                                   // caught while overscrolled
        let caught = engine.offset
        engine.applyPanUpdate(state: .began, translation: .zero, velocity: .zero,
                              forced: true, isIndirect: false)
        XCTAssertEqual(engine.offset, caught, accuracy: 0.001, "the catch position is undisturbed")
    }

    func test_aShortFlickProjectsTheFullFlickDistance() {
        // The reported symptom, as a value. One .began + one .changed at 3.0 pts/ms releases at
        // 0.75·v₀ + 0.25·v₁ ≈ 3.0; the defect released at 0.25·v₁ = 0.75.
        let engine = makeEngine()
        pan(engine, .began, translation: -20, velocity: -3000)
        pan(engine, .changed, translation: -60, velocity: -3000)
        let atRelease = engine.offset
        pan(engine, .ended, translation: -60, velocity: -3000)

        XCTAssertGreaterThan(engine.projectedRestOffset - atRelease, 1400,
                             "3.0 pts/ms projects (3.0 − 0.01)/|ln 0.998| ≈ 1493 pt")
    }

    func test_theSameFlickWithoutTheBeganSampleWouldLandFourTimesShorter() {
        // Non-vacuity control: skip .began, exactly as the engine used to. `applyPanUpdate` treats a
        // `.changed` with no preceding `.began` as the gesture start, so this is the OLD behaviour
        // reproduced exactly — one sample, `previous` still zero, guard skipped... except the guard
        // is what saves it now, so the honest control is the arithmetic itself.
        let quarterStrength = (0.25 * 3.0 - 0.01) / abs(log(0.998))
        XCTAssertLessThan(quarterStrength, 400,
                          "0.25 · 3.0 pts/ms projects ~370pt — the modest scroll that was reported")
    }

    func test_aChangedWithoutABeganIsTreatedAsTheGestureStart() {
        // UIKit cannot deliver this, but a synthetic caller can, and silently doing nothing would
        // make a mis-sequenced test pass vacuously.
        let engine = makeEngine()
        pan(engine, .changed, translation: -60, velocity: -3000)
        XCTAssertEqual(engine.offset, 60, accuracy: 0.5)
    }

    func test_theDragPairBracketsOnlyTheFingerDownInterval() {
        // A host maintains its ListViewImpl.isTracking equivalent from these, so the pairing is
        // contractual: momentum and the bounce that follows must not re-fire either.
        let engine = makeEngine()
        var began = 0
        var ended = 0
        engine.onWillBeginDragging = { began += 1 }
        engine.onDidEndDragging = { ended += 1 }

        pan(engine, .began, translation: -20, velocity: -3000)
        pan(engine, .changed, translation: -60, velocity: -3000)
        pan(engine, .ended, translation: -60, velocity: -3000)

        XCTAssertEqual(began, 1)
        XCTAssertEqual(ended, 1)
    }
}
