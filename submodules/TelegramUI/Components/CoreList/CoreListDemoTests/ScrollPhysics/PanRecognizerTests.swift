import XCTest
import CoreGraphics
@testable import CoreListDemo

final class PanRecognizerTests: XCTestCase {
    /// Translation is zero through the pre-recognition slop, then the hysteresis (10px) is removed.
    func testTranslationRemovesHysteresisAtRecognition() {
        var r = PanRecognizer()
        r.begin(centroid: CGPoint(x: 100, y: 400), t: 0)
        r.move(centroid: CGPoint(x: 100, y: 396), t: 0.016)   // raw −4 (< 10) → not recognized
        XCTAssertFalse(r.isRecognized)
        XCTAssertEqual(r.translation.y, 0, accuracy: 1e-9)
        r.move(centroid: CGPoint(x: 100, y: 386), t: 0.032)   // raw −14 (> 10) → recognized, hyst −10
        XCTAssertTrue(r.isRecognized)
        XCTAssertEqual(r.translation.y, -4, accuracy: 1e-9)   // (386−400) − (−10)
        r.move(centroid: CGPoint(x: 100, y: 374), t: 0.048)   // raw −26
        XCTAssertEqual(r.translation.y, -16, accuracy: 1e-9)  // −26 + 10
    }

    /// First move has no previous sample → velocity = W1·current only. (Velocity is reported from the
    /// first move, independent of recognition — the recognizer samples on every touch-move.)
    func testFirstMoveVelocityIsCurrentWeightTimesFiniteDifference() {
        var r = PanRecognizer()
        r.begin(centroid: CGPoint(x: 100, y: 400), t: 0)
        r.move(centroid: CGPoint(x: 100, y: 390), t: 0.016)   // current.v = (0, -10/0.016 = -625)
        XCTAssertEqual(r.velocity.y, 0.2 * -625, accuracy: 1e-6)  // = -125
        XCTAssertEqual(r.velocity.x, 0, accuracy: 1e-9)
    }

    /// Subsequent moves blend: velocity = 0.2·current + 0.8·previous.
    func testBlendsCurrentAndPreviousSamples() {
        var r = PanRecognizer()
        r.begin(centroid: CGPoint(x: 100, y: 400), t: 0)
        r.move(centroid: CGPoint(x: 100, y: 390), t: 0.016)   // previous.v = -625
        r.move(centroid: CGPoint(x: 100, y: 374), t: 0.032)   // current.v  = -16/0.016 = -1000
        XCTAssertEqual(r.velocity.y, 0.2 * -1000 + 0.8 * -625, accuracy: 1e-6)  // = -700
    }

    /// A zero/negative dt builds no sample (velocity unchanged), but the centroid is still tracked.
    func testNonPositiveDtBuildsNoSample() {
        var r = PanRecognizer()
        r.begin(centroid: CGPoint(x: 100, y: 400), t: 0)
        r.move(centroid: CGPoint(x: 100, y: 390), t: 0.016)
        let v = r.velocity.y
        r.move(centroid: CGPoint(x: 100, y: 300), t: 0.016)   // same t → dt = 0 → no sample
        XCTAssertEqual(r.velocity.y, v, accuracy: 1e-9)        // velocity unchanged
        XCTAssertEqual(r.translation.y, -90, accuracy: 1e-9)   // recognized (raw −100), hyst −10 → −90
    }

    func testBeginResetsState() {
        var r = PanRecognizer()
        r.begin(centroid: CGPoint(x: 0, y: 0), t: 0)
        r.move(centroid: CGPoint(x: 0, y: -50), t: 0.016)
        XCTAssertTrue(r.isRecognized)
        r.begin(centroid: CGPoint(x: 200, y: 500), t: 1.0)    // new gesture
        XCTAssertFalse(r.isRecognized)
        XCTAssertEqual(r.translation.x, 0, accuracy: 1e-9)
        XCTAssertEqual(r.translation.y, 0, accuracy: 1e-9)
        XCTAssertEqual(r.velocity.y, 0, accuracy: 1e-9)
    }

    // MARK: Layer-1 validation against recorded ground truth

    private func loadFixture(_ name: String) throws -> GestureRecording {
        let dir = URL(fileURLWithPath: #file).deletingLastPathComponent().appendingPathComponent("Fixtures")
        return try JSONDecoder().decode(GestureRecording.self,
                                        from: Data(contentsOf: dir.appendingPathComponent("\(name).json")))
    }

    /// Drive PanRecognizer with each fixture's recorded touch stream and assert it reproduces the real
    /// recognizer's translation (exact, modulo sub-px) and velocity (≤ ~0.3% of the ~1e4 pts/s range —
    /// the residual is the recognizer's sub-pixel centroid adjustment we don't model).
    func testReproducesRecordedRecognizerOutputs() throws {
        var totalMoves = 0
        for name in ["slow-drag-release", "medium-flick", "flick-into-bottom", "overscroll-release"] {
            let rec = try loadFixture(name)
            var r = PanRecognizer()
            var maxVel: CGFloat = 0, maxTrans: CGFloat = 0, moves = 0
            for tch in rec.touches {
                switch tch.phase {
                case .began:
                    r.begin(centroid: tch.centroid, t: tch.t)
                case .moved:
                    r.move(centroid: tch.centroid, t: tch.t)
                    moves += 1
                    maxVel = Swift.max(maxVel, abs(r.velocity.x - tch.velocity.x), abs(r.velocity.y - tch.velocity.y))
                    if r.isRecognized {
                        maxTrans = Swift.max(maxTrans, abs(r.translation.x - tch.translation.x),
                                             abs(r.translation.y - tch.translation.y))
                    }
                case .ended, .cancelled:
                    break
                }
            }
            totalMoves += moves
            XCTAssertGreaterThan(moves, 5, "\(name): too few touch moves — re-record")
            XCTAssertLessThanOrEqual(maxTrans, 0.5, "\(name): translation reproduction (px)")
            XCTAssertLessThanOrEqual(maxVel, 30, "\(name): velocity reproduction (pts/s)")
        }
        XCTAssertGreaterThan(totalMoves, 0)
    }
}
