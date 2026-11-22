import XCTest
@testable import CoreListDemo

/// `applyChanges(absorbsEdgeChangeIntoOverscroll:)` — moving a bounce edge without moving content.
///
/// `presentationOverscroll` preserves the rubber-band MAGNITUDE across a geometry pass: the content
/// ends up the same distance past the edge it was before. Right whenever the edge stays where it is
/// and the geometry around it changed (a rotation, a keyboard) — the band is a presentation-only
/// displacement and losing it would snap. Exactly wrong when the EDGE ITSELF moves under content that
/// is standing still, because then preserving the magnitude teleports the content by the edge's
/// travel.
///
/// The chat hits this holding its overscroll action open: it raises the newest edge 106pt while a
/// finger sits on a deep overscroll. Measured on device before this flag existed —
/// `newBounds = -185 + (-156.37) = -341.37`, still 156pt past an edge that had just moved 106.
///
/// Two halves, and each was its own device-visible jump. The offset half is here; the drag-anchor
/// half is `DragReanchorTests`, and the last test below is what proves the pass wires them together.
final class OverscrollHoldInsetTests: XCTestCase {

    private let restingInset: CGFloat = 79
    private let hold: CGFloat = 106
    /// Deep enough that the BANDED overscroll clears `hold`. The band compresses hard — 150pt of
    /// finger is only ~75pt of content against an 800pt viewport — so a shallower pull would leave
    /// the content inside the new bounds after the edge moves, and the re-measure below would read
    /// as a clamp at zero rather than the shift it is meant to check.
    private let deepPull: CGFloat = 300

    private func makeFixture() -> PhysicsListFixture {
        let fixture = PhysicsListFixture(itemCount: 40, itemHeight: 50)
        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: restingInset, left: 0, bottom: 0, right: 0),
                                      transition: .immediate)
        return fixture
    }

    /// Where the newest row actually IS, which is the whole question — not where the model says it
    /// will settle.
    private func presentedTop(_ fixture: PhysicsListFixture) -> CGFloat {
        guard let view = fixture.listView.loadedItemView(at: 0) else {
            XCTFail("index 0 must be loaded")
            return .nan
        }
        return fixture.listView.presentedFrame(of: view).minY
    }

    private func setInset(_ fixture: PhysicsListFixture, top: CGFloat, absorbs: Bool) {
        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: top, left: 0, bottom: 0, right: 0),
                                      compensatesInsetChange: false,
                                      absorbsEdgeChangeIntoOverscroll: absorbs,
                                      transition: .immediate)
    }

    /// Pull the list past its top edge and leave the finger down.
    private func dragPastTheTopEdge(_ fixture: PhysicsListFixture, by translation: CGFloat) {
        fixture.engine.beginDrag()
        fixture.engine.drag(translation: translation, velocity: 0)
        XCTAssertLessThan(fixture.listView.overscrollDistance, -1.0,
                          "the fixture must actually be overscrolled or every assertion here is vacuous")
    }

    // MARK: - The offset half

    func test_preservingTheBandMagnitudeMovesContentWhenTheEdgeMoves() {
        // The control, and the shipped behaviour this replaced. Without it the absorb test below
        // could pass by the inset change simply not doing anything.
        let fixture = makeFixture()
        dragPastTheTopEdge(fixture, by: deepPull)
        let before = presentedTop(fixture)

        setInset(fixture, top: restingInset + hold, absorbs: false)

        XCTAssertEqual(presentedTop(fixture) - before, hold, accuracy: 0.5,
                       "the band keeps its size, so the content travels with the edge")
    }

    func test_absorbingHoldsThePresentedPositionWhenTheEdgeMoves() {
        let fixture = makeFixture()
        dragPastTheTopEdge(fixture, by: deepPull)
        let before = presentedTop(fixture)
        let overscrollBefore = fixture.listView.overscrollDistance

        setInset(fixture, top: restingInset + hold, absorbs: true)

        XCTAssertEqual(presentedTop(fixture), before, accuracy: 0.01, "nothing moves")
        XCTAssertEqual(fixture.listView.overscrollDistance - overscrollBefore, hold, accuracy: 0.5,
                       "the band re-measures itself against the new edge instead")
    }

    func test_absorbingIsSymmetricWhenTheEdgeComesBack() {
        // Engaging and disengaging are the same call, and the chat makes both while a finger is down
        // (crossing the control's full-expansion threshold in either direction).
        let fixture = makeFixture()
        dragPastTheTopEdge(fixture, by: deepPull)
        let before = presentedTop(fixture)

        setInset(fixture, top: restingInset + hold, absorbs: true)
        setInset(fixture, top: restingInset, absorbs: true)

        XCTAssertEqual(presentedTop(fixture), before, accuracy: 0.01)
    }

    // MARK: - The drag-anchor half, through the pass

    func test_absorbingAlsoSurvivesTheNextDragFrame() {
        // The one that matters, and the one holding the offset alone does NOT satisfy. A drag maps
        // finger travel to content through the rubber band, so a moved edge re-scales that mapping
        // and the content jumps on the FOLLOWING frame — which is why the device still showed a jump
        // after `absorbsEdgeChangeIntoOverscroll` was added and looked, wrongly, like it had failed.
        // `applyChanges` re-anchors the drag on the absorb path; this asserts that wiring, not just
        // `ScrollAxis`.
        let fixture = makeFixture()
        dragPastTheTopEdge(fixture, by: deepPull)
        let before = presentedTop(fixture)

        setInset(fixture, top: restingInset + hold, absorbs: true)
        fixture.engine.drag(translation: deepPull, velocity: 0)   // the finger has not moved

        XCTAssertEqual(presentedTop(fixture), before, accuracy: 0.01, "so neither does the content")
    }

    func test_theDragKeepsWorkingAfterTheEdgeMoves() {
        // Holding the seam still is only half of it — the gesture has to carry on under the new edge.
        let fixture = makeFixture()
        dragPastTheTopEdge(fixture, by: deepPull)
        setInset(fixture, top: restingInset + hold, absorbs: true)

        var previous = presentedTop(fixture)
        for translation in stride(from: deepPull + 2, through: deepPull + 20, by: 2) {
            fixture.engine.drag(translation: translation, velocity: 0)
            let step = presentedTop(fixture) - previous
            XCTAssertGreaterThan(step, 0, "each further point of pull still opens the overscroll")
            XCTAssertLessThan(step, 5.0, "and never in a jump")
            previous = presentedTop(fixture)
        }
    }

    // MARK: - Not a drag

    func test_absorbingHoldsThePresentedPositionWithNoFingerDown() {
        // The chat also absorbs at release, with a spring already in flight rather than a finger on
        // the glass. The re-anchor is a no-op there and the offset half has to stand on its own.
        let fixture = makeFixture()
        dragPastTheTopEdge(fixture, by: deepPull)
        fixture.engine.endDrag()
        let before = presentedTop(fixture)

        setInset(fixture, top: restingInset + hold, absorbs: true)

        XCTAssertEqual(presentedTop(fixture), before, accuracy: 0.01)
    }
}
