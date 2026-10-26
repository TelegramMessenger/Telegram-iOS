import XCTest
import CoreGraphics
@testable import CoreListDemo

/// End-to-end regression of the pure ScrollPhysics core against real UIScrollView gestures (recorded
/// touch fixtures). The replay drives the physics from the recorded drag translations + the §4 release
/// velocity, with the first decel step integrating one display frame (analysis §2/§7), then deceleration
/// against the recorded frame timeline. The recognizer reproduction itself is validated in
/// `PanRecognizerTests`; rubber-band per-formula in the test below.
///
/// X-axis is excluded from trajectory assertions: with `contentWidth == boundsWidth` the real view locks
/// X while ScrollAxis rubber-bands it (directional lock unmodeled — out of scope for a vertical list).
final class ScrollPhysicsRegressionTests: XCTestCase {
    private let fixtures = ["slow-drag-release", "medium-flick", "flick-into-bottom", "overscroll-release"]

    private func loadFixture(_ name: String) throws -> GestureRecording {
        let dir = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("Fixtures")
        return try JSONDecoder().decode(GestureRecording.self,
                                        from: Data(contentsOf: dir.appendingPathComponent("\(name).json")))
    }

    /// Per-formula: our RubberBand reproduces every captured real `_rubberBandOffsetForOffset:` call.
    func testRubberBandFormulaMatchesCapturedGroundTruth() throws {
        for name in fixtures {
            for s in try loadFixture(name).rubberBandSamples {
                XCTAssertEqual(RubberBand.offset(s.offset, min: s.min, max: s.max, range: s.range),
                               s.out, accuracy: 1e-3, "\(name): rubber-band mismatch for \(s)")
            }
        }
    }

    /// The full replayed contentOffset trajectory matches the recorded real trajectory along Y, per
    /// frame, with NO alignment/seeding shims — drag → release → free-deceleration → edge bounce →
    /// spring-back, all within a few px. (Bounds reflect measured residuals: sub-pixel rounding + the
    /// recognizer's ~0.3% velocity reproduction; not a sub-px claim.)
    func testReplayedTrajectoryMatchesRecorded() throws {
        let maxY: [String: CGFloat] = [
            "slow-drag-release": 1.0,    // pure drag + short settle
            "medium-flick": 3.0,         // free-deceleration to mid-content
            "flick-into-bottom": 3.0,    // free-decel into the edge + bounce
            "overscroll-release": 4.0,   // spring-back from a deep overscroll
        ]
        for name in fixtures {
            let d = ScrollReplay.maxDivergence(try loadFixture(name))
            XCTAssertLessThanOrEqual(d.y, maxY[name]!, "\(name): Y trajectory divergence \(d.y)")
        }
    }

    // MARK: - The EVENT-level driver (the seam oracle)

    func test_eventReplayAndFrameReplayAgreeOnAMediumFlick() throws {
        // A medium flick has several driving touch events, so both drivers see the same last-two
        // samples. Their agreeing is the control that says event-level and frame-level replay are
        // equivalent at high event counts — and therefore that any disagreement is a real seam
        // difference rather than an artefact of the two drivers.
        let rec = try loadFixture("medium-flick")
        let byFrame = ScrollReplay.replay(rec)
        let byEvent = ScrollReplay.replayEvents(rec)

        XCTAssertEqual(byFrame.count, byEvent.count)
        XCTAssertEqual(byFrame.last!.y, byEvent.last!.y, accuracy: 3.0)
    }

    /// `replay` folds every recorded DISPLAY FRAME through `drag(...)`, including the first, so it
    /// behaves like UIKit whether or not the live engine feeds its `.began` sample — which is why a
    /// suite holding this integrator to 3px never saw a 4× error in the release. `replayEvents`
    /// drives the per-EVENT stream the way `applyPanUpdate` does, so the fixtures now oracle the
    /// seam as well as the integrator.
    func test_eventReplayTracksTheRealScrollViewOnEveryTouchFixture() throws {
        let maxY: [String: CGFloat] = [
            "slow-drag-release": 1.5,
            "medium-flick": 3.0,
            "flick-into-bottom": 3.0,
            "overscroll-release": 3.0,
        ]
        for name in fixtures {
            let d = ScrollReplay.maxEventDivergence(try loadFixture(name))
            XCTAssertLessThan(d.y, maxY[name]!, "\(name): event-level replay diverged along Y")
        }
    }

    func test_theTouchFixturesHaveEnoughEventsToBlend() throws {
        // Non-vacuity for the agreement test: it only demonstrates agreement because these fixtures
        // are NOT short. A short flick is exactly where the two drivers must diverge, which is what
        // `short-flick` exists to lock.
        let rec = try loadFixture("medium-flick")
        let driving = rec.touches.filter(\.hasRecognized)
        let movedAfterBegan = driving.dropFirst().filter { $0.phase == .moved }
        XCTAssertGreaterThan(movedAfterBegan.count, 2,
                             "with <= 1 .changed the guard would skip the blend and the drivers part")
    }

    // MARK: - repeat-flick: multi-gesture release parity

    /// Six real flicks in one recording, the later ones catching content still in motion. It locks
    /// two things nothing else covers:
    ///
    /// - **multi-gesture replay.** `replay` (frame-level) releases ONCE and never re-drags, so it
    ///   lands at 462pt against a real 18,595pt — the control below. `replayEvents` walks gestures,
    ///   restarting each drag at touch-down the way `_beginTrackingWithEvent:` halts deceleration and
    ///   anchors translation.
    /// - **the fast-scroll expiry.** Every release-to-next-touch-down gap in this take exceeds the
    ///   1.0s timeout (`0x17b1488`), so UIKit expired the streak each time and ran at multiplier 1
    ///   throughout. Matching to under a point across 18.6k points of travel says our expiry agrees;
    ///   applying a multiplier UIKit did not would diverge enormously over that distance.
    ///
    /// It does NOT lock the growth formula — that needs consecutive flicks INSIDE the 1s window, which
    /// this take does not contain. `ReleaseDecisionTests` covers the formula analytically.
    func test_repeatFlick_multiGestureReleaseMatchesRealScrollView() throws {
        let rec = try loadFixture("repeat-flick")
        let truth = ScrollReplay.replayableFrames(rec).map(\.groundTruthOffset)
        let replayed = ScrollReplay.replayEvents(rec)

        XCTAssertEqual(replayed.last!.y, truth.last!.y, accuracy: 3.0,
                       "six gestures, 18.6k points of travel, landing within a few px")
    }

    func test_repeatFlick_nonVacuity_theFrameLevelDriverCannotReplayIt() throws {
        // The control: the frame-level driver models ONE gesture, so it releases once and stops. If
        // this ever starts agreeing, the fixture has lost its multi-gesture character.
        let rec = try loadFixture("repeat-flick")
        let truth = ScrollReplay.replayableFrames(rec).map(\.groundTruthOffset)
        let byFrame = ScrollReplay.replay(rec)

        XCTAssertLessThan(byFrame.last!.y, truth.last!.y / 2,
                          "single-gesture replay lands nowhere near a six-flick burst")
    }

    func test_repeatFlickFixtureIsGenuinelyMultiGesture() throws {
        let rec = try loadFixture("repeat-flick")
        let ends = rec.touches.filter { $0.phase == .ended || $0.phase == .cancelled }
        XCTAssertGreaterThanOrEqual(ends.count, 4, "non-vacuity: it must actually contain a burst")
    }

    // MARK: - device-flick: a real iPhone, at 120Hz

    /// A short flick recorded on a physical iPhone Air. Everything else here was captured in the
    /// Simulator, where touch delivery is 60Hz and the deceleration cadence is regular; this take has
    /// 8.3ms touch spacing and an irregular ~80Hz effective frame cadence, so it is the only fixture
    /// that exercises the replica against real-device timing.
    ///
    /// The LANDING is the assertion. Intermediate divergence reaches ~17pt on this take (0.8% of the
    /// travel) purely from that irregular cadence — the replay steps on recorded frame deltas and the
    /// first-step rule uses the median — and converges to zero, so a tight per-frame bound here would
    /// be asserting the device's frame jitter rather than the physics.
    func test_deviceFlick_landsWhereTheRealScrollViewLanded() throws {
        let rec = try loadFixture("device-flick")
        let truth = ScrollReplay.replayableFrames(rec).map(\.groundTruthOffset)
        let replayed = ScrollReplay.replayEvents(rec)

        XCTAssertEqual(replayed.last!.y, truth.last!.y, accuracy: 1.0,
                       "2160pt of travel on a real device, landing within a point")
    }

    /// Non-vacuity AND a standing caveat: this take has three `.changed` events, so it does NOT
    /// discriminate the `.began`-sample fix — an engine that drops `.began` computes the identical
    /// release from the same last-two samples. It proves the release path reproduces a real device;
    /// it proves nothing about D1. A D1 fixture needs `chg <= 1`.
    func test_deviceFlickDoesNotDiscriminateTheBeganFix() throws {
        let rec = try loadFixture("device-flick")
        let driving = rec.touches.filter(\.hasRecognized)
        let changed = driving.dropFirst().filter { $0.phase == .moved }
        XCTAssertGreaterThanOrEqual(changed.count, 2,
                                    "if this ever drops to <= 1 it becomes a D1 fixture and the "
                                    + "landing assertion above starts carrying that meaning too")
    }
}
