import XCTest
import CoreGraphics
@testable import CoreListDemo

/// End-to-end regression of the pure ScrollPhysics core against recorded real-UIScrollView
/// *trackpad* (continuous indirect scroll) gestures, captured in an iPad simulator. Same replay
/// path as the touch fixtures (`ScrollPhysicsRegressionTests`): the recording's frames drive
/// drag()/endDrag()/step() and the replayed Y offset is compared per frame to the recorded ground
/// truth. Y-only (X is locked by the real view; directional lock is unmodeled — out of scope).
///
/// The one trackpad-specific physics finding: indirect-scroll overscroll uses a **looser rubber-band
/// coefficient (0.715) than touch (0.55)** — fit to machine precision from captured
/// `_rubberBandOffsetForOffset:` ground truth. `ScrollReplay` selects it for touch-less (trackpad)
/// recordings; `PhysicsScrollView` selects it live via `PhysicsPanGestureRecognizer.isIndirectScroll`.
final class TrackpadScrollPhysicsTests: XCTestCase {
    /// Single drag→release→decelerate arcs — what `ScrollReplay` models. `trackpad-reverse-mid-decel`
    /// is a MULTI-gesture recording (drag→decel→drag→decel) the single-arc replay can't reproduce;
    /// it stays committed (recorded for analysis) but is asserted only once `ScrollReplay` grows
    /// multi-gesture support (re-`beginDrag` on a `.dragging` frame after `.decelerating`).
    private let fixtures = ["trackpad-slow-drag-release", "trackpad-medium-flick",
                            "trackpad-flick-into-bottom", "trackpad-overscroll-release",
                            "trackpad-creep", "trackpad-overscroll-gentle"]

    private func loadFixture(_ name: String) throws -> GestureRecording {
        let dir = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("Fixtures")
        return try JSONDecoder().decode(GestureRecording.self,
                                        from: Data(contentsOf: dir.appendingPathComponent("\(name).json")))
    }

    /// Per-formula: `RubberBand.offset` with the **trackpad** coefficient reproduces every captured
    /// real `_rubberBandOffsetForOffset:` overscroll call (Y-axis samples; X is the locked axis). This
    /// is the direct ground-truth proof of the 0.715 constant (0.55 would miss by tens of px at depth).
    func testTrackpadRubberBandCoefficientMatchesCapturedGroundTruth() throws {
        var checked = 0
        for name in fixtures {
            let rec = try loadFixture(name)
            for s in rec.rubberBandSamples where abs(s.range - rec.geometry.boundsHeight) < 0.5 {
                XCTAssertEqual(RubberBand.offset(s.offset, min: s.min, max: s.max, range: s.range,
                                                 c: RubberBand.trackpadCoefficient),
                               s.out, accuracy: 1e-3, "\(name): trackpad rubber-band mismatch for \(s)")
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 100, "expected many captured overscroll samples across fixtures")
    }

    /// The replayed contentOffset trajectory matches the recorded trackpad trajectory along Y, per
    /// frame. Bounds reflect measured residuals (sub-pixel rounding + the recognizer's velocity
    /// reproduction); the replay is deterministic, so these are tight. `flick-into-bottom` is the
    /// looser one: its overscroll occurs during *deceleration* (the flick crosses the edge), handled
    /// by the c-independent fixed-stiffness bounce spring — a small residual, not the rubber-band gap.
    func testReplayedTrackpadTrajectoryMatchesRecorded() throws {
        let maxY: [String: CGFloat] = [
            "trackpad-slow-drag-release": 1.0,    // pure drag + settle
            "trackpad-medium-flick":      2.5,    // free-deceleration to mid-content
            "trackpad-flick-into-bottom": 5.5,    // flick crosses edge → bounce spring (decel, c-independent)
            "trackpad-overscroll-release":2.5,    // deep overscroll spring-back (the 0.715 rubber-band fix)
            "trackpad-creep":             0.5,    // velocity-floor creep, no decel
            "trackpad-overscroll-gentle": 2.5,    // near-zero-velocity overscroll — isolates the rubber-band
        ]
        for name in fixtures {
            let d = ScrollReplay.maxDivergence(try loadFixture(name))
            XCTAssertLessThanOrEqual(d.y, maxY[name]!, "\(name): Y trajectory divergence \(d.y)")
        }
    }
}
