import XCTest
@testable import CoreListDemo

/// Moving a bounce edge WHILE A FINGER IS DOWN.
///
/// A drag maps finger travel to content through the rubber band (`proposed = dragStartOffset −
/// translation`, then `RubberBand.offset(proposed, …)`), and the band is a function of the edges. So
/// declaring a new edge mid-drag silently re-scales that mapping: the same finger position bands
/// differently and the content jumps on the very next `drag()` — one frame after the edge changed,
/// which is what makes it hard to attribute.
///
/// The chat needs exactly this. Its overscroll action holds the newest edge open 106pt from the
/// moment the control fills, because the physics reads the edge before the host hears about the
/// release (`launchFlight` hands off and bakes inside the pan's `.ended`), so a hold applied at
/// release is always one step late. Measured on device before `reanchorDragToCurrentOffset` existed:
/// 116pt past the old edge became 10pt past the new one, the band stopped resisting, and the content
/// shot out 64.8pt on the next frame.
final class DragReanchorTests: XCTestCase {

    private func makeAxis() -> ScrollAxis {
        ScrollAxis(offset: 300, min: 0, max: 1000, range: 844, rate: 0.998, scale: 1)
    }

    // MARK: - The band inverts

    func test_theRubberBandInverseRoundTripsPastBothEdges() {
        for proposed in [-400.0, -100.0, -1.0, 0.0, 500.0, 1000.0, 1001.0, 1400.0] as [CGFloat] {
            let banded = RubberBand.offset(proposed, min: 0, max: 1000, range: 844)
            let back = RubberBand.inverse(banded, min: 0, max: 1000, range: 844)
            XCTAssertEqual(back, proposed, accuracy: 1e-6, "proposed=\(proposed)")
        }
    }

    func test_theRubberBandInverseIsIdentityInBounds() {
        for x in [0.0, 1.0, 500.0, 999.0, 1000.0] as [CGFloat] {
            XCTAssertEqual(RubberBand.inverse(x, min: 0, max: 1000, range: 844), x, accuracy: 1e-9)
        }
    }

    // MARK: - Re-anchoring holds the content

    func test_anEdgeMovingUnderAFingerJumpsTheContentWithoutReanchoring() {
        // The control. Not a hypothetical failure mode — this is the shipped behaviour it replaced,
        // and without it the assertions below could pass vacuously.
        var axis = makeAxis()
        axis.beginDrag()
        axis.drag(translation: 400)                      // 100pt past the min edge, banded
        let held = axis.offset
        XCTAssertLessThan(held, 0, "the pull is past the edge")
        XCTAssertGreaterThan(held, -100, "and the band is compressing it")

        axis.setBounds(min: -106, max: 1000)             // edge moves under a finger that has not
        axis.drag(translation: 400)                      // moved: same translation, new edges

        XCTAssertGreaterThan(abs(axis.offset - held), 40.0,
                             "the same finger position re-bands to somewhere else entirely")
    }

    func test_reanchoringHoldsTheContentAcrossAnEdgeMovingUnderAFinger() {
        var axis = makeAxis()
        axis.beginDrag()
        axis.drag(translation: 400)
        let held = axis.offset

        axis.setBounds(min: -106, max: 1000)
        axis.reanchorDragToCurrentOffset()
        axis.drag(translation: 400)                      // the finger has not moved

        XCTAssertEqual(axis.offset, held, accuracy: 1e-6, "so neither does the content")
    }

    func test_theDragContinuesSmoothlyFromTheReanchoredPosition() {
        // Holding the seam still is only half of it: the gesture has to carry on from there, under
        // the NEW edges. A re-anchor that pinned the offset but corrupted the anchor would pass the
        // test above and stutter on the next frame.
        var axis = makeAxis()
        axis.beginDrag()
        axis.drag(translation: 400)
        let held = axis.offset

        axis.setBounds(min: -106, max: 1000)
        axis.reanchorDragToCurrentOffset()

        var previous = held
        for translation in stride(from: CGFloat(402), through: 420, by: 2) {
            axis.drag(translation: translation)
            let step = previous - axis.offset
            XCTAssertGreaterThan(step, 0, "each further point of pull still moves content the same way")
            XCTAssertLessThan(step, 4.0, "and never in a jump")
            previous = axis.offset
        }
    }

    func test_reanchoringIsANoOpOutsideADrag() {
        var axis = makeAxis()
        let before = axis.offset
        axis.setBounds(min: -106, max: 1000)
        axis.reanchorDragToCurrentOffset()
        XCTAssertEqual(axis.offset, before, accuracy: 1e-9)

        axis.beginDrag()
        axis.drag(translation: 50)
        let dragged = axis.offset
        axis.applyRelease(velocity: 0)                   // decelerating, not dragging
        axis.reanchorDragToCurrentOffset()
        XCTAssertEqual(axis.offset, dragged, accuracy: 1e-9)
    }

    func test_reanchoringSurvivesACoordinateShift() {
        // `shift(by:)` re-bases offset and anchor together; the remembered un-banded position has to
        // ride along or the next re-anchor computes against a stale one.
        var axis = makeAxis()
        axis.beginDrag()
        axis.drag(translation: 400)
        axis.shift(by: 25)
        let held = axis.offset

        axis.setBounds(min: -106 + 25, max: 1000 + 25)
        axis.reanchorDragToCurrentOffset()
        axis.drag(translation: 400)

        XCTAssertEqual(axis.offset, held, accuracy: 1e-6)
    }
}
