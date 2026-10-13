import XCTest
import CoreGraphics
@testable import CoreListDemo

final class ScrollReplayTests: XCTestCase {
    private let geometry = GestureRecording.Geometry(
        contentWidth: 320, contentHeight: 4000, boundsWidth: 320, boundsHeight: 800,
        insetTop: 0, insetLeft: 0, insetBottom: 0, insetRight: 0, scale: 2, decelerationRate: 0.998)

    /// Build a recording whose groundTruthOffset IS the replay output, so a correct
    /// harness reports ~0 divergence. This validates the fold/timestamp/compare plumbing
    /// (NOT that ScrollPhysics matches UIScrollView — real fixtures do that in Task 6).
    private func selfConsistentRecording() -> GestureRecording {
        var rec = GestureRecording(name: "self", geometry: geometry, frames: [], rubberBandSamples: [])
        var p = ScrollReplay.makePhysics(geometry, startOffset: .zero)
        p.beginDrag()
        var t = 0.0
        // UIKit convention: a downward finger drag yields negative translation.y; ScrollAxis maps it
        // via (dragStart − translation), so the content offset increases (content scrolls up/down).
        for i in 1...5 {                                  // drag down 5 frames, ~ -12 pts/frame (cumulative)
            p.drag(translation: CGPoint(x: 0, y: CGFloat(-12 * i)))
            rec.frames.append(.init(t: t, phase: .dragging,
                                    translation: CGPoint(x: 0, y: CGFloat(-12 * i)),
                                    recognizerVelocity: CGPoint(x: 0, y: -2000),
                                    groundTruthOffset: CGPoint(x: p.x.offset, y: p.y.offset)))
            t += 0.016
        }
        p.applyRelease(velocity: CGPoint(x: 0, y: 2.0))
        for _ in 0..<120 {                                // decelerate ~2s
            let r = p.step(dtMs: 16)
            rec.frames.append(.init(t: t, phase: .decelerating, translation: .zero,
                                    recognizerVelocity: .zero, groundTruthOffset: r.written))
            t += 0.016
            if r.settled { break }
        }
        return rec
    }

    func testReplayOfSelfConsistentRecordingHasNearZeroDivergence() {
        let d = ScrollReplay.maxDivergence(selfConsistentRecording())
        XCTAssertLessThan(d.y, 1e-6)
        XCTAssertLessThan(d.x, 1e-6)
    }

    func testDivergenceDetectsAPerturbedGroundTruth() {
        var rec = selfConsistentRecording()
        rec.frames[rec.frames.count / 2].groundTruthOffset.y += 5   // inject a 5pt error
        let d = ScrollReplay.maxDivergence(rec)
        XCTAssertGreaterThan(d.y, 4.9)                              // injected 5pt → divergence ≈ 5
    }
}
