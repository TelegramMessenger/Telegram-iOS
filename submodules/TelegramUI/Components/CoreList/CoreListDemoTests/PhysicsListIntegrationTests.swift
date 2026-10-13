import XCTest
import UIKit
@testable import CoreListDemo

/// The list driven end-to-end by the real ScrollPhysics core (via TestScrollEngine). Content is
/// taller than the viewport and only partially loaded, so a flick exercises free-travel deceleration
/// + progressive rebalance + re-base — the arbitrary-content path this increment delivers.
final class PhysicsListIntegrationTests: XCTestCase {

    // 200 rows × 50pt = 10_000pt content in an 800pt viewport → only a window is ever loaded.
    private func makeFixture() -> PhysicsListFixture {
        PhysicsListFixture(itemCount: 200, itemHeight: 50)
    }

    func test_flickDown_freeTravels_rebalances_andSettlesInBounds() {
        let fixture = makeFixture()
        let startOffset = fixture.offset
        XCTAssertEqual(startOffset, 0, accuracy: 0.001, "starts at the top")
        let startWindow = Set(fixture.loadedIndices)

        fixture.simulateFlick(offsetVelocity: 4000)
        let trace = fixture.runUntilSettled(max: 6.0)

        // "Coasted forward a meaningful distance." The raw scroll offset is coordinate-dependent —
        // increment 3 re-bases the neither-edge container near 0 instead of ~5M — so assert the
        // base-invariant fact that the flick scrolled the top rows out of the loaded window.
        XCTAssertFalse(fixture.loadedIndices.contains(0), "the flick scrolled the top rows out of the window")
        XCTAssertNotEqual(Set(fixture.loadedIndices), startWindow, "the loaded window advanced (rebalanced)")
        // Contiguity: the loaded rows tile the viewport with no gaps on every frame of the flight.
        trace.assertContiguousEveryFrame()
    }

    func test_flickDown_noVisibleJump_perFrame() {
        let fixture = makeFixture()
        fixture.simulateFlick(offsetVelocity: 3500)
        let trace = fixture.runUntilSettled(max: 6.0)
        // A re-base mid-flight must not teleport a row. Keyed continuity (no delete renumbering here).
        trace.assertNoVisibleJump(maxPerFrameDeltaY: 80)
    }

    func test_flickUpAtTop_bouncesAndSpringsBackToZero() {
        let fixture = makeFixture()        // already at the top (offset 0, min edge loaded)
        // Drag down past the top (finger down = positive translation) then release while overscrolled.
        fixture.beginDrag()
        fixture.drag(translation: 150, velocity: 600)
        fixture.drag(translation: 220, velocity: 600)
        XCTAssertLessThan(fixture.offset, 0, "overscrolled past the top edge")
        _ = fixture.endDrag()
        let trace = fixture.runUntilSettled(max: 6.0)
        XCTAssertEqual(fixture.offset, 0, accuracy: 0.5, "sprang back to the top edge")
        XCTAssertEqual(Set(fixture.loadedIndices).contains(0), true, "top row still loaded")
        trace.assertContiguousEveryFrame()
    }

    func test_bottomEdge_flickPastBottom_springsBackToBottomEdge() {
        let fixture = makeFixture()
        // Reach the bottom region via the list's own scrollTo (keeps offset/window/previousOffset in sync).
        fixture.listView.applyChanges(scrollTo: .init(index: 199, pointOffset: 750), transition: .easeInOut(duration: 0))
        // Flick into the bottom edge and let the spring settle there — this offset IS the bottom edge.
        fixture.simulateFlick(offsetVelocity: 2500)
        _ = fixture.runUntilSettled(max: 6.0)
        XCTAssertTrue(Set(fixture.loadedIndices).contains(199), "last row loaded at the bottom")
        let bottomEdge = fixture.offset

        // Overshoot the bottom again; it must spring back to the SAME bottom edge.
        fixture.simulateFlick(offsetVelocity: 1500)
        let trace = fixture.runUntilSettled(max: 6.0)
        XCTAssertEqual(fixture.offset, bottomEdge, accuracy: 0.5, "sprang back to the bottom edge")
        XCTAssertTrue(Set(fixture.loadedIndices).contains(199), "last row still loaded")
        trace.assertContiguousEveryFrame()
    }

    func test_dragThenSettle_keepsRowsContiguous() {
        let fixture = makeFixture()
        fixture.beginDrag()
        fixture.drag(translation: -400, velocity: -1200)   // drag the content up by ~400
        fixture.drag(translation: -800, velocity: -1200)
        _ = fixture.endDrag()
        let trace = fixture.runUntilSettled(max: 6.0)
        trace.assertContiguousEveryFrame()
        // Forward scroll past the top. The raw offset is coordinate-dependent post-increment-3
        // (neither-edge re-base near 0), so assert the base-invariant window advance instead.
        XCTAssertFalse(fixture.loadedIndices.contains(0), "the drag scrolled the top rows out of the window")
    }

    // MARK: - Keyframe mode integration tests

    func test_keyframe_flickDown_rebalancesWithRebake_andStaysContiguous() {
        let fixture = PhysicsListFixture(itemCount: 200, itemHeight: 50, decelerationMode: .keyframe)
        let startWindow = Set(fixture.loadedIndices)
        fixture.simulateFlick(offsetVelocity: 4000)
        let trace = fixture.runUntilSettled(max: 6.0)

        XCTAssertFalse(fixture.loadedIndices.contains(0), "coasted past the top (window advanced)")
        XCTAssertNotEqual(Set(fixture.loadedIndices), startWindow)
        trace.assertContiguousEveryFrame()
        // The re-base rebakes must not jump the content on screen on any frame. 90 catches a rebake
        // teleport (a dropped ~50pt window shift on top of ~65pt/frame flick travel ≈ 115pt > 90)
        // while clearing smooth 4000pt/s motion (~65pt/frame).
        trace.assertNoVisibleJump(maxPerFrameDeltaY: 90)
    }

    func test_keyframe_bottomEdge_flickPastBottom_springsBackToBottomEdge() {
        let fixture = PhysicsListFixture(itemCount: 200, itemHeight: 50, decelerationMode: .keyframe)
        fixture.listView.applyChanges(scrollTo: .init(index: 199, pointOffset: 750), transition: .easeInOut(duration: 0))
        fixture.simulateFlick(offsetVelocity: 2500)
        _ = fixture.runUntilSettled(max: 6.0)
        XCTAssertTrue(Set(fixture.loadedIndices).contains(199), "last row loaded at the bottom")
        let bottom = fixture.offset
        fixture.simulateFlick(offsetVelocity: 1500)
        let trace = fixture.runUntilSettled(max: 6.0)
        XCTAssertEqual(fixture.offset, bottom, accuracy: 1.0, "sprang back to the same bottom edge")
        XCTAssertTrue(Set(fixture.loadedIndices).contains(199), "last row still loaded after spring-back")
        trace.assertContiguousEveryFrame()
    }

    func test_keyframe_and_stepped_settleAtSameWindow() {
        let kf = PhysicsListFixture(itemCount: 200, itemHeight: 50, decelerationMode: .keyframe)
        let st = PhysicsListFixture(itemCount: 200, itemHeight: 50, decelerationMode: .stepped)
        kf.simulateFlick(offsetVelocity: 3500); _ = kf.runUntilSettled(max: 6.0)
        st.simulateFlick(offsetVelocity: 3500); _ = st.runUntilSettled(max: 6.0)
        // Same physics → same loaded window (allow ±1 row for rounding/rebake slop).
        XCTAssertFalse(kf.loadedIndices.isEmpty, "keyframe fixture has a loaded window")
        XCTAssertFalse(st.loadedIndices.isEmpty, "stepped fixture has a loaded window")
        XCTAssertLessThanOrEqual(abs((kf.loadedIndices.min() ?? 0) - (st.loadedIndices.min() ?? 0)), 1)
    }
}
