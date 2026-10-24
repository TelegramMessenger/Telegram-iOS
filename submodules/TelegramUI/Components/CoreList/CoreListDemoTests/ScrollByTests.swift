import XCTest
import UIKit
@testable import CoreListDemo

/// `scroll(by:)` is a scroll the user drives without dragging the list: the chat's two-finger
/// message selection auto-scrolls the history while the fingers hold near a screen edge
/// (`ChatHistoryListNodeImpl.setupSelectionScrolling` → `scrollWithDirection`). It moves content by
/// a caller-chosen step, clipped at the loaded edges, and reports whether anything moved — the
/// `ListViewImpl.scrollWithDirection` contract. Being the user's scroll, it releases what a drag's
/// start releases (the pin latch and the scroll hold); otherwise the next mutation pass (every
/// selection toggle runs one) would put the held row back, undoing the steps before it.
///
/// Fixture convention as in `ScrollHoldTests`: 50pt rows, index 0 is the newest and rests on the top
/// inset edge (the chat's π rotation shows it at the screen bottom).
final class ScrollByTests: XCTestCase {
    private let viewport = CGSize(width: 390, height: 400)

    private func y(_ fixture: VirtualListFixture, _ identity: AnyHashable) throws -> CGFloat {
        try XCTUnwrap(fixture.settledScreenY(identity: identity))
    }

    func testANegativeStepScrollsIntoContentAndReportsMovement() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        fixture.scroll(to: 500)
        let identity = fixture.listView.items[12].identity
        let before = try y(fixture, identity)

        XCTAssertTrue(fixture.listView.scroll(by: -15))

        XCTAssertEqual(try y(fixture, identity), before - 15, accuracy: 1e-6)
    }

    func testAPositiveStepMovesContentDown() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        fixture.scroll(to: 500)
        let identity = fixture.listView.items[12].identity
        let before = try y(fixture, identity)

        XCTAssertTrue(fixture.listView.scroll(by: 15))

        XCTAssertEqual(try y(fixture, identity), before + 15, accuracy: 1e-6)
    }

    /// Repeated steps travel through the collection, loading rows as they come in — what lets a
    /// selection drag reach messages that were off screen when it began.
    func testRepeatedStepsTravelPastTheInitiallyLoadedWindow() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        let farIdentity = fixture.listView.items[40].identity
        XCTAssertNil(fixture.settledScreenY(identity: farIdentity), "row 40 starts unloaded")

        for _ in 0 ..< 100 {
            fixture.listView.scroll(by: -15)
        }

        // 1500pt into the collection: row 40 (content Y 2000) sits 500pt below the top inset edge.
        XCTAssertEqual(try y(fixture, farIdentity), 500, accuracy: 1e-6)
    }

    func testAStepPastTheNewestEdgeIsClippedAndReportsNoMovement() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        let identity = fixture.listView.items[0].identity

        XCTAssertFalse(fixture.listView.scroll(by: 15))

        XCTAssertEqual(try y(fixture, identity), 0, accuracy: 1e-6)
    }

    func testAStepPastTheOldestEdgeIsClippedAndReportsNoMovement() throws {
        let fixture = VirtualListFixture(itemCount: 20, itemHeight: 50, viewport: viewport)
        let identity = fixture.listView.items[19].identity
        for _ in 0 ..< 100 {
            fixture.listView.scroll(by: -15)
        }
        XCTAssertEqual(try y(fixture, identity) + 50, 400, accuracy: 1e-6,
                       "the oldest row rests on the bottom inset edge")

        XCTAssertFalse(fixture.listView.scroll(by: -15))

        XCTAssertEqual(try y(fixture, identity) + 50, 400, accuracy: 1e-6)
    }

    /// A held row would otherwise be put back on its edge by the next mutation pass, undoing the steps.
    func testAStepReleasesTheScrollHoldSoStepsAccumulate() throws {
        let fixture = VirtualListFixture(itemCount: 20, itemHeight: 50, viewport: viewport)
        let identity = fixture.listView.items[5].identity
        fixture.listView.applyChanges(
            scrollTo: CoreListScrollTarget(index: 5,
                                           hold: CoreListScrollHold(edge: .topInset,
                                                                    rowPoint: { _, _ in 0 }),
                                           resolve: { _, _ in 100 }),
            transition: .easeInOut(duration: 0))
        XCTAssertTrue(fixture.listView.isHoldingScrollTarget)

        XCTAssertTrue(fixture.listView.scroll(by: -15))
        XCTAssertTrue(fixture.listView.scroll(by: -15))

        fixture.listView.applyChanges(items: fixture.listView.items, transition: .easeInOut(duration: 0))

        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)
        XCTAssertEqual(try y(fixture, identity), 70, accuracy: 1e-6, "the pass after the steps keeps them")
    }

    /// The bot-reply pin latch, armed the way `ScrollHoldTests` arms it, puts its row back on every
    /// pass in the same way a hold does.
    func testAStepReleasesThePinLatchSoStepsAccumulate() throws {
        let ids = (0 ..< 20).map { _ in UUID() }
        func items(pinned: Bool) -> [CoreListItem] {
            ids.enumerated().map { index, id -> CoreListItem in
                index == 1 && pinned
                    ? PinnedFixedHeightItem(id: id, height: 60)
                    : IdentifiableFixedHeightItem(id: id, height: index == 1 ? 60 : 50)
            }
        }
        let fixture = VirtualListFixture(viewport: viewport, items: items(pinned: false))
        fixture.listView.applyChanges(items: items(pinned: true), transition: .easeInOut(duration: 0))
        fixture.listView.applyChanges(
            scrollTo: CoreListScrollTarget(index: 1) { height, _ in
                let visibleArea: CGFloat = 400
                let ext = max(0, height - visibleArea * 0.5)
                return visibleArea + ext - height
            },
            transition: .easeInOut(duration: 0))
        XCTAssertTrue(fixture.listView.isStrictlyPinnedToBottomEdge)
        let before = try y(fixture, ids[1])

        XCTAssertTrue(fixture.listView.scroll(by: -15))
        XCTAssertTrue(fixture.listView.scroll(by: -15))

        fixture.listView.applyChanges(items: items(pinned: true), transition: .easeInOut(duration: 0))

        XCTAssertFalse(fixture.listView.isStrictlyPinnedToBottomEdge)
        XCTAssertEqual(try y(fixture, ids[1]), before - 30, accuracy: 1e-6, "the pass after the steps keeps them")
    }

    /// One call travels at most the preload margin: loaded content always reaches that far past the
    /// viewport, so a step can never pass an edge the window has not loaded and declared yet.
    func testAStepTravelsAtMostThePreloadMargin() throws {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, viewport: viewport)
        fixture.scroll(to: 500)
        let identity = fixture.listView.items[12].identity
        let before = try y(fixture, identity)

        XCTAssertTrue(fixture.listView.scroll(by: -10_000))

        XCTAssertEqual(try y(fixture, identity), before - fixture.listView.preloadMargin, accuracy: 1e-6)
    }

    /// 14 rows at the newest edge: the oldest ones are not loaded, so the far edge is still open when the
    /// step is clamped. A step past the margin would land beyond the edge the rebalance then declares.
    func testALargeStepNeverOverscrollsAnUnloadedEdge() {
        let fixture = VirtualListFixture(itemCount: 14, itemHeight: 50, viewport: viewport)
        XCTAssertNil(fixture.declaredEdges.max, "non-vacuity: the oldest edge is not loaded yet")

        while fixture.listView.scroll(by: -10_000) {
            XCTAssertEqual(fixture.listView.overscrollDistance, 0, accuracy: 1e-6)
        }

        XCTAssertEqual(fixture.listView.overscrollDistance, 0, accuracy: 1e-6)
    }

    func testAStepHaltsMomentum() {
        let fixture = PhysicsListFixture(itemCount: 200, itemHeight: 50, viewport: viewport)
        fixture.simulateFlick(offsetVelocity: 2_000)
        fixture.tick(dt: 1.0 / 60)
        XCTAssertTrue(fixture.engine.isDecelerating)

        fixture.listView.scroll(by: -15)

        XCTAssertFalse(fixture.engine.isDecelerating)
    }

    /// The chat's engine plays momentum as a keyframe flight: the step catches it where it is presented
    /// and moves on from there.
    func testAStepCatchesAKeyframeFlightWhereItIsAndStepsFromThere() {
        let fixture = PhysicsListFixture(itemCount: 200, itemHeight: 50, viewport: viewport,
                                         decelerationMode: .keyframe)
        fixture.simulateFlick(offsetVelocity: 2_000)
        for _ in 0 ..< 5 {
            fixture.tick(dt: 1.0 / 60)
        }
        XCTAssertTrue(fixture.listView.isScrollFlightActive, "non-vacuity: a flight is in the air")
        let caught = fixture.engine.liveViewportOffset

        XCTAssertTrue(fixture.listView.scroll(by: -15))

        XCTAssertFalse(fixture.listView.isScrollFlightActive)
        XCTAssertEqual(fixture.engine.liveViewportOffset, caught + 15, accuracy: 1e-6)
    }

    /// A step against an edge is called every frame while the fingers rest there, so when it cannot move it
    /// must change nothing: an overscroll's spring-back keeps playing. A step back into content moves from
    /// where the overscroll is, rather than snapping onto the edge first.
    func testAStepFurtherPastAnEdgeLeavesTheSpringBackAlone() {
        let fixture = PhysicsListFixture(itemCount: 200, itemHeight: 50, viewport: viewport)
        let rest = fixture.offset
        fixture.beginDrag()
        fixture.drag(translation: 120, velocity: 0)
        fixture.endDrag()
        fixture.tick(dt: 1.0 / 60)
        XCTAssertLessThan(fixture.offset, rest - 1, "non-vacuity: overscrolled past the newest edge")
        XCTAssertTrue(fixture.engine.isDecelerating, "non-vacuity: springing back")
        let overscrolled = fixture.offset

        XCTAssertFalse(fixture.listView.scroll(by: 15))

        XCTAssertTrue(fixture.engine.isDecelerating, "the spring-back keeps playing")
        XCTAssertEqual(fixture.offset, overscrolled, accuracy: 1e-6)

        XCTAssertTrue(fixture.listView.scroll(by: -15))

        XCTAssertEqual(fixture.offset, overscrolled + 15, accuracy: 1e-6)
    }

    /// A step that cannot move leaves the scroll hold armed.
    func testAStepThatCannotMoveKeepsTheHold() {
        let fixture = VirtualListFixture(itemCount: 20, itemHeight: 50, viewport: viewport)
        fixture.listView.applyChanges(
            scrollTo: CoreListScrollTarget(index: 0,
                                           hold: CoreListScrollHold(edge: .topInset,
                                                                    rowPoint: { _, _ in 0 }),
                                           resolve: { _, _ in 0 }),
            transition: .easeInOut(duration: 0))
        XCTAssertTrue(fixture.listView.isHoldingScrollTarget)

        XCTAssertFalse(fixture.listView.scroll(by: 15))

        XCTAssertTrue(fixture.listView.isHoldingScrollTarget)
    }

    /// The chat runs on the physics core; its offset must take the step too, and stop at the newest edge.
    func testStepsMoveThePhysicsEngineAndStopAtTheNewestEdge() {
        let fixture = PhysicsListFixture(itemCount: 200, itemHeight: 50, viewport: viewport)
        let start = fixture.offset

        XCTAssertTrue(fixture.listView.scroll(by: -15))
        XCTAssertEqual(fixture.offset, start + 15, accuracy: 1e-6)
        XCTAssertTrue(fixture.listView.scroll(by: 15))
        XCTAssertEqual(fixture.offset, start, accuracy: 1e-6)
        XCTAssertFalse(fixture.listView.scroll(by: 15))
        XCTAssertEqual(fixture.offset, start, accuracy: 1e-6)
    }
}
