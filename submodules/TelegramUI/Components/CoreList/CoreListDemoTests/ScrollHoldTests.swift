import XCTest
import UIKit
@testable import CoreListDemo

/// A row reached by a HOLDING `scrollTo` stays where it landed until the next touch or scroll:
/// insets, re-measures, insertions, deletions and size changes re-place it at the same distance from
/// the edge its placement used. Contract: `CoreList/CLAUDE.md`, "The scroll hold".
///
/// A landing the list CLAMPED against one of its ends is held against that end instead of the edge
/// the request named: resting on the newest edge, by its minY from the top inset edge; on the oldest,
/// by its maxY from the bottom inset edge (the newest wins when both hold).
///
/// Fixture convention: 20 rows of 50pt, index 0 is the newest and rests on the top inset edge (under
/// the chat's π rotation, the screen bottom). Insets are applied AFTER construction, in a pass, for
/// the reason `BottomEdgePinTests.fixture` documents (UIScrollView clamps a negative origin at init).
/// Every case runs on `UIKitScrollEngine` except the flight case at the end, which needs the shipping
/// physics core and `KeyframeFlight` (`PhysicsListFixture`, `TestScrollEngine` in `.keyframe` mode).
final class ScrollHoldTests: XCTestCase {
    private let viewport = CGSize(width: 390, height: 400)

    private func fixture(count: Int = 20,
                         resizable: Set<Int> = [],
                         selfUpdating: Set<Int> = []) -> (VirtualListFixture, [UUID]) {
        let ids = (0..<count).map { _ in UUID() }
        let items: [CoreListItem] = ids.enumerated().map { index, id in
            if resizable.contains(index) {
                // `ContentResizableItem`: its `isEqual` compares the height, so a height change is a
                // reconciled survivor that the engine re-measures.
                return ContentResizableItem(id: id, contentHeight: 50)
            }
            if selfUpdating.contains(index) {
                return SelfUpdatingItem(id: id, initialHeight: 50)
            }
            return IdentifiableFixedHeightItem(id: id, height: 50)
        }
        return (VirtualListFixture(viewport: viewport, items: items), ids)
    }

    /// Arms a hold the way the chat backend does: one `scrollTo` carrying the placement and the hold
    /// reference. Placements assume zero insets, which every caller has at arming time.
    private func hold(_ fixture: VirtualListFixture,
                      index: Int,
                      edge: CoreListScrollHold.Edge,
                      offset: CGFloat = 0,
                      yieldsToNewestEdge: Bool = false) {
        let area = viewport.height
        let resolve: (CGFloat, UIView & CoreListItemView) -> CGFloat
        let rowPoint: (CGFloat, UIView & CoreListItemView) -> CGFloat
        switch edge {
        case .topInset:
            resolve = { _, _ in offset }
            rowPoint = { _, _ in 0 }
        case .bottomInset:
            resolve = { height, _ in area - height - offset }
            rowPoint = { height, _ in height }
        case .visibleCenter:
            resolve = { height, _ in floor((area - height) / 2) }
            rowPoint = { height, _ in height / 2 }
        }
        fixture.listView.applyChanges(
            scrollTo: CoreListScrollTarget(index: index,
                                           hold: CoreListScrollHold(edge: edge,
                                                                    yieldsToNewestEdge: yieldsToNewestEdge,
                                                                    rowPoint: rowPoint),
                                           resolve: resolve),
            transition: .easeInOut(duration: 0))
    }

    private func insets(top: CGFloat = 0, bottom: CGFloat = 0) -> UIEdgeInsets {
        UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
    }

    private func y(_ fixture: VirtualListFixture, _ id: UUID) throws -> CGFloat {
        try XCTUnwrap(fixture.settledScreenY(identity: id))
    }

    // MARK: - Landing

    func testAHoldingScrollLandsWhereRequestedAndArms() throws {
        let (fixture, ids) = self.fixture()
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)
        hold(fixture, index: 5, edge: .topInset, offset: 100)
        XCTAssertEqual(try y(fixture, ids[5]), 100, accuracy: 1e-6)
        XCTAssertTrue(fixture.listView.isHoldingScrollTarget)
    }

    func testAPlainScrollDoesNotArm() {
        let (fixture, _) = self.fixture()
        fixture.listView.applyChanges(scrollTo: CoreListScrollTarget(index: 5, pointOffset: 100),
                                      transition: .easeInOut(duration: 0))
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)
    }

    /// Asked to centre row 1 (175), the list cannot leave a gap under the newest row and lands it at
    /// 50, with row 0 at 0 — resting on the newest edge. A landing clamped there is held against THAT
    /// edge: row 1's minY, 50 from the top inset edge. A 20pt bottom inset moves only the bars' edge,
    /// so the row stays at 50 (held from the visible centre instead — distance (50 + 25) − 200 = −125,
    /// centre now 190 — it would move to 190 − 125 − 25 = 40; re-running the request would put it at
    /// floor((380 − 50) / 2) = 165). A 60pt top inset then carries it with the input edge: 60 + 50 =
    /// 110, row 0 at 60.
    func testAClampedLandingIsHeldWhereItLanded() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 1, edge: .visibleCenter)
        XCTAssertEqual(try y(fixture, ids[1]), 50, accuracy: 1e-6)
        fixture.listView.applyChanges(newInsets: insets(bottom: 20), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[1]), 50, accuracy: 1e-6)
        fixture.listView.applyChanges(newInsets: insets(top: 60, bottom: 20),
                                      transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[1]), 110, accuracy: 1e-6)
        XCTAssertEqual(try y(fixture, ids[0]), 60, accuracy: 1e-6)
    }

    /// The unread shape (a chat opened with a few unread: `.bottom` on the separator). Asked to put
    /// row 3's maxY on the bars' edge (400, so minY 350), the list would leave 200pt under row 0 —
    /// rows 0…2 are 150pt, reaching only down to 200 — so it lands row 3 at 150 with row 0 at 0,
    /// resting on the newest edge, and holds row 3's minY 150 from the input-panel edge. The keyboard
    /// (top inset 120) carries the whole stack with that edge: row 0 at 120, row 3 at 120 + 150 = 270.
    /// Held by its maxY from the bars (distance 200 − 400 = −200), row 3 would stay at 150 and rows
    /// 0…2 would go under the keyboard.
    func testAClampedBottomHoldRidesTheInputEdgeWhenItGrows() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 3, edge: .bottomInset)
        XCTAssertEqual(try y(fixture, ids[3]), 150, accuracy: 1e-6, "the landing is clamped")
        XCTAssertEqual(try y(fixture, ids[0]), 0, accuracy: 1e-6)
        fixture.listView.applyChanges(newInsets: insets(top: 120), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[0]), 120, accuracy: 1e-6)
        XCTAssertEqual(try y(fixture, ids[3]), 270, accuracy: 1e-6)
    }

    /// The control: row 8's maxY on the bars' edge puts its minY at 350 and rows 0…7 (400pt) reach
    /// down to −50, past the input edge, so nothing is clamped and the hold keeps the edge the request
    /// named. A 120pt top inset moves nothing that edge depends on: still 350.
    func testAnUnclampedBottomHoldIgnoresTopInsetGrowth() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 8, edge: .bottomInset)
        XCTAssertEqual(try y(fixture, ids[8]), 350, accuracy: 1e-6)
        XCTAssertEqual(try y(fixture, ids[0]), -50, accuracy: 1e-6, "not resting on the newest edge")
        fixture.listView.applyChanges(newInsets: insets(top: 120), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[8]), 350, accuracy: 1e-6)
    }

    /// The input-panel edge shrinking under a clamped landing. With a top inset of 80 the list rests
    /// on the newest edge, row 0 at 80. The `hold` helper places against zero insets, so it asks for
    /// row 1 at 80 + floor((400 − 50) / 2) = 255 rather than at the true centre; either way that leaves
    /// a gap under row 0 (here 125pt), so the list lands row 1 at 130 with row 0 at 80, on the newest
    /// edge, and holds row 1's minY 130 − 80 = 50 from the input edge. Top inset 0: row 1 at 50, row 0
    /// at 0, and the minimum edge is the natural one, −insets.top = 0 — no slack. Held from the visible
    /// centre instead (distance 155 − 240 = −85, centre now 200), row 1 would sit at 200 − 85 − 25 = 90
    /// with a 40pt gap under row 0, and the minimum edge would extend to −40.
    func testAClampedCentreHoldClosesNoGapWhenTheTopInsetShrinks() throws {
        let (fixture, ids) = self.fixture()
        fixture.listView.applyChanges(newInsets: insets(top: 80), transition: .easeInOut(duration: 0))
        hold(fixture, index: 1, edge: .visibleCenter)
        XCTAssertEqual(try y(fixture, ids[1]), 130, accuracy: 1e-6, "the landing is clamped")
        XCTAssertEqual(try y(fixture, ids[0]), 80, accuracy: 1e-6)
        fixture.listView.applyChanges(newInsets: insets(), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[0]), 0, accuracy: 1e-6)
        XCTAssertEqual(try y(fixture, ids[1]), 50, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), 0, accuracy: 1e-6, "no slack")
    }

    /// The oldest-edge counterpart. Ten rows (500pt); asked to centre row 9 (175…225), the list would
    /// leave 175pt above the oldest row, so it lands row 9 with its maxY on the bars' edge, 400, and
    /// row 0 at 350 − 450 = −100 — not on the newest edge. Held by its maxY from the bars (distance 0),
    /// it follows them: a 60pt bottom inset moves its maxY to 340. Held from the visible centre
    /// instead (distance 375 − 200 = 175, centre now 170), its centre would sit at 345 and its maxY at
    /// 370, 30pt under the bars.
    func testALandingClampedAtTheOldestEdgeFollowsTheBars() throws {
        let (fixture, ids) = self.fixture(count: 10)
        hold(fixture, index: 9, edge: .visibleCenter)
        XCTAssertEqual(try y(fixture, ids[9]) + 50, 400, accuracy: 1e-6, "the landing is clamped")
        XCTAssertEqual(try y(fixture, ids[0]), -100, accuracy: 1e-6)
        fixture.listView.applyChanges(newInsets: insets(bottom: 60), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[9]) + 50, 340, accuracy: 1e-6)
    }

    // MARK: - Yielding to the newest edge

    /// The unread shape again, with a hold that yields to the newest edge (the chat's unread line). It
    /// lands exactly where the held one does — row 3 at 150, row 0 at 0, resting on the newest edge —
    /// but arms nothing: the list follows that edge from now on, as it does when no scroll ran.
    func testAYieldingLandingOnTheNewestEdgeDoesNotArm() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 3, edge: .bottomInset, yieldsToNewestEdge: true)
        XCTAssertEqual(try y(fixture, ids[3]), 150, accuracy: 1e-6, "the landing is clamped")
        XCTAssertEqual(try y(fixture, ids[0]), 0, accuracy: 1e-6)
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)
    }

    /// The inverse of `testAnArrivalAtTheNewestEdgeDoesNotMoveTheHeldRow`: a message arriving under a
    /// yielded landing takes the newest edge and pushes everything up by its 36pt — row 0 to 36, row 3
    /// to 186 — instead of landing under the input panel at −36.
    func testAnArrivalPushesAYieldedLandingUp() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 3, edge: .bottomInset, yieldsToNewestEdge: true)
        let arrival = UUID()
        let items: [CoreListItem] = [IdentifiableFixedHeightItem(id: arrival, height: 36)]
            + fixture.listView.items
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, arrival), 0, accuracy: 1e-6, "on the newest edge")
        XCTAssertEqual(try y(fixture, ids[0]), 36, accuracy: 1e-6)
        XCTAssertEqual(try y(fixture, ids[3]), 186, accuracy: 1e-6)
    }

    /// A row between the newest edge and the yielded landing grows (a reaction on a newly read
    /// message): it grows away from the input edge, row 0 staying at 0 and row 3 moving 150 → 190.
    /// Held, row 3 would stay at 150 and the growth would push row 0 to −40, under the input panel.
    func testGrowthUnderAYieldedLandingGrowsAwayFromTheInputEdge() throws {
        let (fixture, ids) = self.fixture(resizable: [1])
        hold(fixture, index: 3, edge: .bottomInset, yieldsToNewestEdge: true)
        var items = fixture.listView.items
        items[1] = ContentResizableItem(id: ids[1], contentHeight: 90)
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[0]), 0, accuracy: 1e-6)
        XCTAssertEqual(try y(fixture, ids[1]), 50, accuracy: 1e-6)
        XCTAssertEqual(try y(fixture, ids[3]), 190, accuracy: 1e-6)
    }

    /// Yielding loses nothing the hold gave this landing at the keyboard: the same 120pt top inset
    /// carries the stack exactly as `testAClampedBottomHoldRidesTheInputEdgeWhenItGrows` pins.
    func testAYieldedLandingRidesTheInputEdgeLikeAHeldOne() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 3, edge: .bottomInset, yieldsToNewestEdge: true)
        fixture.listView.applyChanges(newInsets: insets(top: 120), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[0]), 120, accuracy: 1e-6)
        XCTAssertEqual(try y(fixture, ids[3]), 270, accuracy: 1e-6)
    }

    /// The control: off the newest edge (`testAnUnclampedBottomHoldIgnoresTopInsetGrowth`'s landing)
    /// a yielding hold arms like any other and keeps the edge the request named.
    func testAYieldingHoldOffTheNewestEdgeArms() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 8, edge: .bottomInset, yieldsToNewestEdge: true)
        XCTAssertEqual(try y(fixture, ids[8]), 350, accuracy: 1e-6)
        XCTAssertTrue(fixture.listView.isHoldingScrollTarget)
        fixture.listView.applyChanges(newInsets: insets(top: 120), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[8]), 350, accuracy: 1e-6)
    }

    // MARK: - Insets and size

    /// The pinned-message bar: a bottom-inset change is never compensated today, so a row aligned to
    /// the bottom inset edge ends up under the bar. Held, it follows the edge: maxY 400 → 340.
    func testBottomInsetGrowthMovesABottomEdgeHeldRowWithTheEdge() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 8, edge: .bottomInset)
        XCTAssertEqual(try y(fixture, ids[8]), 350, accuracy: 1e-6)
        fixture.listView.applyChanges(newInsets: insets(bottom: 60), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[8]), 290, accuracy: 1e-6)
    }

    func testTopInsetGrowthCarriesATopEdgeHeldRow() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 3, edge: .topInset)
        fixture.listView.applyChanges(newInsets: insets(top: 80), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[3]), 80, accuracy: 1e-6)
    }

    /// Landed centred at 175 (centre 200). Insets 40/60 move the visible centre to 190.
    func testACentreHeldRowFollowsTheVisibleCentre() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 10, edge: .visibleCenter)
        XCTAssertEqual(try y(fixture, ids[10]), 175, accuracy: 1e-6)
        fixture.listView.applyChanges(newInsets: insets(top: 40, bottom: 60),
                                      transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[10]), 165, accuracy: 1e-6)
    }

    /// Review Focus 1: rotation, split view, a Duo fold.
    func testAResizeKeepsTheHeldRowOnItsEdge() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 8, edge: .bottomInset)
        fixture.resize(height: 300)
        XCTAssertEqual(try y(fixture, ids[8]), 250, accuracy: 1e-6)
    }

    /// Every phase, not only the endpoints: the row travels with the edge and never past it.
    func testAnAnimatedInsetChangeMovesTheHeldRowStraightToItsEdge() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 8, edge: .bottomInset)
        fixture.listView.applyChanges(newInsets: insets(bottom: 60), transition: .linear(duration: 0.3))
        var previous = CGFloat.greatestFiniteMagnitude
        for phase in 0...6 {
            if phase > 0 { fixture.tick(dt: 0.05) }
            let presented = try XCTUnwrap(fixture.screenY(identity: ids[8]))
            XCTAssertGreaterThanOrEqual(presented, 290 - 0.5, "phase \(phase)")
            XCTAssertLessThanOrEqual(presented, 350 + 0.5, "phase \(phase)")
            XCTAssertLessThanOrEqual(presented, previous + 0.5, "monotonic at phase \(phase)")
            previous = presented
        }
        XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: ids[8])), 290, accuracy: 0.5)
    }

    // MARK: - Re-measures

    /// Asked to put its maxY on the bottom inset edge (400), row 6 would sit at minY 350, but only rows
    /// 0…5 (300pt) lie between it and the newest edge, so the list cannot leave the 50pt gap under row 0
    /// and lands the row at minY 300 (maxY 350), resting on the newest edge. A landing clamped there is
    /// held against that edge, by its minY: 300 from the top inset edge. The re-measure to 120 keeps
    /// minY at 300 (maxY 420), the row growing toward the bars. Held by its maxY (the reference the
    /// request named) it would read minY 350 − 120 = 230; re-running the request, 400 − 120 = 280.
    func testAHeldRowKeepsItsHeldEdgeWhenItRemeasures() throws {
        let (fixture, ids) = self.fixture(resizable: [6])
        hold(fixture, index: 6, edge: .bottomInset)
        XCTAssertEqual(try y(fixture, ids[6]), 300, accuracy: 1e-6, "the landing is clamped")
        var items = fixture.listView.items
        items[6] = ContentResizableItem(id: ids[6], contentHeight: 120)
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[6]), 300, accuracy: 1e-6, "minY stays where it landed")
    }

    /// Row 2 sits between the top inset edge and the held row 6 (at 200). Today row 2 is the witness
    /// anchor, so its growth pushes row 6 to 240.
    func testNeighbourGrowthBelowTheHeldRowDoesNotMoveItAtAnyPhase() throws {
        let (fixture, ids) = self.fixture(resizable: [2])
        hold(fixture, index: 6, edge: .topInset, offset: 200)
        var items = fixture.listView.items
        items[2] = ContentResizableItem(id: ids[2], contentHeight: 90)
        fixture.listView.applyChanges(items: items, transition: .linear(duration: 0.3))
        for phase in 0...6 {
            if phase > 0 { fixture.tick(dt: 0.05) }
            XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: ids[6])), 200,
                           accuracy: 0.5, "phase \(phase)")
        }
    }

    /// The other side: an older row (index 9, appended after the held row) grows. Passes today too;
    /// pins that the held branch lays rows out around the held row on both sides.
    func testNeighbourGrowthAboveTheHeldRowDoesNotMoveIt() throws {
        let (fixture, ids) = self.fixture(resizable: [9])
        hold(fixture, index: 6, edge: .topInset, offset: 200)
        var items = fixture.listView.items
        items[9] = ContentResizableItem(id: ids[9], contentHeight: 90)
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[6]), 200, accuracy: 1e-6)
    }

    func testASelfUpdateFlushKeepsTheHold() throws {
        let (fixture, ids) = self.fixture(selfUpdating: [2])
        hold(fixture, index: 6, edge: .topInset, offset: 200)
        let view = try XCTUnwrap(fixture.view(identity: ids[2]) as? SelfUpdatingItemView)
        view.simulateContentChange(newHeight: 90, animated: false)
        fixture.flushScheduler()
        XCTAssertEqual(try y(fixture, ids[6]), 200, accuracy: 1e-6)
        XCTAssertTrue(fixture.listView.isHoldingScrollTarget)
    }

    // MARK: - Insertions and deletions

    /// The sponsored message / a new message arriving under a held newest row. Today the list rests at
    /// its newest edge, so the new index 0 is glued to the edge and the held row moves up by 36.
    func testAnArrivalAtTheNewestEdgeDoesNotMoveTheHeldRow() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 0, edge: .topInset)
        let arrival = UUID()
        let items: [CoreListItem] = [IdentifiableFixedHeightItem(id: arrival, height: 36)]
            + fixture.listView.items
        fixture.listView.applyChanges(items: items, transition: .linear(duration: 0.3))
        for phase in 0...6 {
            if phase > 0 { fixture.tick(dt: 0.05) }
            XCTAssertEqual(try XCTUnwrap(fixture.screenY(identity: ids[0])), 0,
                           accuracy: 0.5, "phase \(phase)")
        }
        XCTAssertEqual(try y(fixture, arrival), -36, accuracy: 1e-6, "lands under the top inset")
    }

    /// Review Focus 2: a hole reload inserting rows between the edge and the held row.
    func testAPreservingReloadKeepsTheHeldRow() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 6, edge: .topInset, offset: 200)
        var items = fixture.listView.items
        items.insert(contentsOf: (0..<3).map { _ in IdentifiableFixedHeightItem(id: UUID(), height: 50) },
                     at: 3)
        fixture.listView.applyChanges(items: items, anchorMode: .preserveVisibleContent,
                                      transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[6]), 200, accuracy: 1e-6)
    }

    /// Row 1 held at 50 above row 0; row 0 is deleted. The row stays and the minimum edge extends by
    /// the 50pt the placement needs.
    func testADeletionBelowTheHeldRowOpensSlackInsteadOfMovingIt() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 1, edge: .topInset, offset: 50)
        fixture.listView.applyChanges(items: Array(fixture.listView.items.dropFirst()),
                                      transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[1]), 50, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), -50, accuracy: 1e-6)
    }

    /// The oldest-edge counterpart. Ten rows (500pt); row 8 held with its maxY at 350, so row 9 (the
    /// oldest) sits at 350…400. Deleting row 9 leaves a 50pt gap under the bottom inset edge; the
    /// maximum edge extends by exactly that, so the offset rests on it and the row stays.
    func testADeletionAboveTheHeldRowOpensSlackAtTheOldestEdge() throws {
        let (fixture, ids) = self.fixture(count: 10)
        hold(fixture, index: 8, edge: .bottomInset, offset: 50)
        XCTAssertEqual(try y(fixture, ids[8]), 300, accuracy: 1e-6)
        fixture.listView.applyChanges(items: Array(fixture.listView.items.dropLast()),
                                      transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[8]), 300, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.max), fixture.boundsOriginY, accuracy: 1e-6,
                       "the offset rests on the extended oldest edge")
    }

    // MARK: - Release

    /// The bot-reply pin is armed by a PLAIN `scrollTo` at the pinned row, so it ends a hold and the
    /// pin latch owns placement from then on. The pin arrives in a pass, as `BottomEdgePinTests` does.
    func testThePinLatchsArmingScrollReleasesTheHold() {
        let ids = (0..<20).map { _ in UUID() }
        func items(pinned: Bool) -> [CoreListItem] {
            ids.enumerated().map { index, id -> CoreListItem in
                index == 1 && pinned
                    ? PinnedFixedHeightItem(id: id, height: 60)
                    : IdentifiableFixedHeightItem(id: id, height: index == 1 ? 60 : 50)
            }
        }
        let fixture = VirtualListFixture(viewport: viewport, items: items(pinned: false))
        fixture.listView.applyChanges(items: items(pinned: true), transition: .easeInOut(duration: 0))
        hold(fixture, index: 5, edge: .topInset, offset: 100)
        XCTAssertTrue(fixture.listView.isHoldingScrollTarget)
        fixture.listView.applyChanges(
            scrollTo: CoreListScrollTarget(index: 1) { height, _ in
                let visibleArea: CGFloat = 400
                let ext = max(0, height - visibleArea * 0.5)
                return visibleArea + ext - height
            },
            transition: .easeInOut(duration: 0))
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)
        XCTAssertTrue(fixture.listView.isStrictlyPinnedToBottomEdge)
    }

    func testTheTouchReleasesTheHoldAndMovesNothing() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 1, edge: .topInset, offset: 50)
        fixture.listView.applyChanges(items: Array(fixture.listView.items.dropFirst()),
                                      transition: .easeInOut(duration: 0))
        fixture.beginUserDrag()
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)
        XCTAssertEqual(try y(fixture, ids[1]), 50, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), -50, accuracy: 1e-6,
                       "the slack outlives the latch")
    }

    func testReleasedSlackRetiresAsTheUserScrollsTowardContent() throws {
        let (fixture, _) = self.fixture()
        hold(fixture, index: 1, edge: .topInset, offset: 50)
        fixture.listView.applyChanges(items: Array(fixture.listView.items.dropFirst()),
                                      transition: .easeInOut(duration: 0))
        fixture.beginUserDrag()
        fixture.scroll(to: -20)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), -20, accuracy: 1e-6)
        fixture.scroll(to: 0)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), 0, accuracy: 1e-6)
        fixture.scroll(to: -30)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.min), 0, accuracy: 1e-6,
                       "retired slack never comes back")
    }

    /// Review Focus 4: an older row arriving after release must not close the gap the user is
    /// looking at — the list in the slack region is not "resting at its newest edge".
    func testAPassAfterReleaseDoesNotCloseTheSlack() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 1, edge: .topInset, offset: 50)
        fixture.listView.applyChanges(items: Array(fixture.listView.items.dropFirst()),
                                      transition: .easeInOut(duration: 0))
        fixture.beginUserDrag()
        fixture.simulateRelease()
        let items = fixture.listView.items + [IdentifiableFixedHeightItem(id: UUID(), height: 50)]
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[1]), 50, accuracy: 1e-6)
    }

    /// The oldest-edge counterpart: row 8 held with its maxY at 350 and row 9 deleted leaves a 50pt
    /// gap under the bottom inset edge and the offset resting on the extended maximum (100, natural
    /// 50). After release, a pass that changes nothing must not close that gap by aligning the oldest
    /// row onto the bottom inset edge, which would move row 8 to 350.
    func testAPassAfterReleaseDoesNotCloseTheOldestEdgeSlack() throws {
        let (fixture, ids) = self.fixture(count: 10)
        hold(fixture, index: 8, edge: .bottomInset, offset: 50)
        fixture.listView.applyChanges(items: Array(fixture.listView.items.dropLast()),
                                      transition: .easeInOut(duration: 0))
        fixture.beginUserDrag()
        fixture.simulateRelease()
        fixture.listView.applyChanges(items: fixture.listView.items, transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[8]), 300, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(fixture.declaredEdges.max), fixture.boundsOriginY, accuracy: 1e-6,
                       "the offset still rests on the extended oldest edge")
    }

    func testDeletingTheHeldRowReleases() {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 5, edge: .topInset, offset: 100)
        let items = fixture.listView.items.filter { $0.identity != AnyHashable(ids[5]) }
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)
    }

    /// Review Focus 3: same index, new identity (an album regrouped into a new entry).
    func testReplacingTheHeldRowsIdentityReleases() {
        let (fixture, _) = self.fixture()
        hold(fixture, index: 5, edge: .topInset, offset: 100)
        var items = fixture.listView.items
        items[5] = IdentifiableFixedHeightItem(id: UUID(), height: 50)
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)
    }

    func testAPlainScrollReleasesAndAHoldingScrollReplaces() throws {
        let (fixture, ids) = self.fixture()
        hold(fixture, index: 5, edge: .topInset, offset: 100)
        fixture.listView.applyChanges(scrollTo: CoreListScrollTarget(index: 8, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)

        hold(fixture, index: 5, edge: .topInset, offset: 100)
        hold(fixture, index: 9, edge: .bottomInset)
        XCTAssertTrue(fixture.listView.isHoldingScrollTarget)
        fixture.listView.applyChanges(newInsets: insets(bottom: 60), transition: .easeInOut(duration: 0))
        XCTAssertEqual(try y(fixture, ids[9]) + 50, 340, accuracy: 1e-6, "the NEW target is held")
    }

    func testReleaseScrollHoldReleases() {
        let (fixture, _) = self.fixture()
        hold(fixture, index: 5, edge: .topInset, offset: 100)
        fixture.listView.releaseScrollHold()
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)
    }

    func testAFullReplaceReleases() {
        let (fixture, _) = self.fixture()
        hold(fixture, index: 5, edge: .topInset, offset: 100)
        let items: [CoreListItem] = (0..<20).map { _ in IdentifiableFixedHeightItem(id: UUID(), height: 50) }
        fixture.listView.applyChanges(items: items, transition: .easeInOut(duration: 0))
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget)
    }

    // MARK: - Flights (PhysicsScrollEngine)

    /// A released slack retires on frames the user drives and once when a flight ends, never on the
    /// flight's own ticks: retiring there re-declared the minimum edge at the live offset on every
    /// frame, an edge on the flight's remaining path, so `KeyframeFlight` rebaked every frame.
    ///
    /// Row 1 held at 50 with row 0 under it (so resting on the newest edge, held by its minY), then
    /// row 0 deleted: the row stays at 50 and the minimum edge extends to −50 with the offset on it,
    /// as in `testADeletionBelowTheHeldRowOpensSlackInsteadOfMovingIt`. A flick toward older content
    /// releases the hold (its touch) and launches a flight away from that edge; 300pt/s travels about
    /// 150pt, so the offset ends near 100, the new row 0 (content minY 0) stays inside the 400pt load
    /// margin and the minimum edge stays declared. During the flight it stays at −50; once the flight
    /// ends at an offset ≥ 0 the current offset needs no slack, so it retires to the natural 0.
    func testAFlightOutOfAReleasedSlackRetiresItOnlyWhenItEnds() throws {
        let ids = (0..<20).map { _ in UUID() }
        let fixture = PhysicsListFixture(viewport: viewport,
                                         items: ids.map { IdentifiableFixedHeightItem(id: $0, height: 50) },
                                         preloadMargin: 400,
                                         decelerationMode: .keyframe)
        fixture.listView.applyChanges(
            scrollTo: CoreListScrollTarget(index: 1,
                                           hold: CoreListScrollHold(edge: .topInset) { _, _ in 0 },
                                           resolve: { _, _ in 50 }),
            transition: .easeInOut(duration: 0))
        fixture.listView.applyChanges(items: Array(fixture.listView.items.dropFirst()),
                                      transition: .easeInOut(duration: 0))
        XCTAssertEqual(try XCTUnwrap(fixture.listView.declaredEdges.min), -50, accuracy: 1e-6)
        XCTAssertEqual(fixture.offset, -50, accuracy: 1e-6)

        fixture.simulateFlick(offsetVelocity: 300)
        XCTAssertFalse(fixture.listView.isHoldingScrollTarget, "the flick's touch released the hold")
        XCTAssertTrue(fixture.listView.isScrollFlightActive, "non-vacuity: a flight was launched")
        var flightTicks = 0
        while fixture.listView.isScrollFlightActive, flightTicks < 600 {
            fixture.tick(dt: 1.0 / 60)
            flightTicks += 1
            guard fixture.listView.isScrollFlightActive else { break }
            XCTAssertEqual(try XCTUnwrap(fixture.listView.declaredEdges.min), -50, accuracy: 1e-6,
                           "flight tick \(flightTicks)")
        }
        XCTAssertGreaterThan(flightTicks, 5, "non-vacuity: the flight ran for several frames")
        XCTAssertFalse(fixture.listView.isScrollFlightActive, "the flight ended")
        XCTAssertEqual(fixture.engine.keyframeRebakeCount, 0, "no edge moved onto the flight's path")
        XCTAssertGreaterThan(fixture.offset, 0, "the flight left the slack")
        XCTAssertEqual(try XCTUnwrap(fixture.listView.declaredEdges.min), 0, accuracy: 1e-6,
                       "retired once the flight ended")
    }
}
