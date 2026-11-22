import XCTest
@testable import CoreListDemo

/// A departure whose block straddles (or sits above) the pass anchor.
///
/// A ghost block's witness is the first live row AFTER the departed range, so the block occupied the
/// space immediately BEFORE that row and its `maxY` is what rides the boundary. Attaching by `minY`
/// instead pins the block's TOP to that row's TOP, dropping the whole block by its own height — it
/// slides down while it fades instead of fading in place.
///
/// `minY` is correct in two cases, and this suite guards both: a REPLACEMENT, where an inserted row
/// lands at the block root, and the ordinary mid-collection delete, where the successor slides UP into
/// the space the run vacated so the two tops genuinely coincide. What decides it is whether the
/// successor arrived at the top the run vacated — not where the pass anchor happens to be.
///
/// Reported from the demo: "Load +5, settle, Load -5 — the top 5 animate down while fading out",
/// and "Load -5 when the scroll is somewhere at these top 5 rows makes them animate down every
/// time". Both are the same condition: the anchor lands inside or above the departing range.
final class GhostBlockAnchorInsideDepartureTests: XCTestCase {
    private func rows(_ count: Int, idBase: Int = 0) -> [CoreListItem] {
        (0..<count).map { IdentifiableFixedHeightItem(id: UUID(uuidString: uuid(idBase + $0))!,
                                                      height: 75) }
    }

    /// Deterministic UUIDs so a failure is reproducible.
    private func uuid(_ n: Int) -> String {
        String(format: "00000000-0000-0000-0000-%012d", n)
    }

    /// Prepend `count` rows, then park the viewport so the top-inset edge falls INSIDE them.
    private func fixtureWithPendingTopRows(insetTop: CGFloat = 302)
        -> (fixture: PhysicsListFixture, prepended: [CoreListItem]) {
        let fixture = PhysicsListFixture(items: rows(60))
        fixture.listView.applyChanges(newInsets: UIEdgeInsets(top: insetTop, left: 0,
                                                              bottom: 0, right: 0),
                                      transition: .immediate)
        let prepended = rows(5, idBase: 10_000)
        var items = prepended
        items.append(contentsOf: fixture.listView.items)
        fixture.listView.applyChanges(items: items,
                                      anchorMode: .preserveVisibleContent,
                                      transition: .linear(duration: 0.3))
        fixture.clock.advance(by: 1.0)
        return (fixture, prepended)
    }

    /// The reported case: the scroll sits among the rows that are about to depart.
    ///
    /// The block does not have to hold still in CONTENT space — the loaded-top pin legitimately pulls
    /// the surviving rows up when the collection's head is deleted, and the ghost must ride that. What
    /// must hold is that it stays welded to the live row it hangs off: its bottom edge sits exactly on
    /// that row's top edge, so the two move as one and the block never crosses into live content.
    /// Pinned by `minY` instead, the block lands ON its successor — 300pt down the screen here.
    func testGhostStaysWeldedToItsWitnessWhenTheAnchorIsInsideTheDepartedRange() {
        let (fixture, _) = fixtureWithPendingTopRows()

        // Park the inset edge in the middle of the five prepended rows.
        let target = fixture.containerOriginY + 150 - 302
        fixture.engine.setOffset(target)
        fixture.engine.onScroll?(target)

        let survivor = fixture.listView.items[5].identity
        var items = fixture.listView.items
        items.removeFirst(5)
        fixture.listView.applyChanges(items: items,
                                      anchorMode: .preserveVisibleContent,
                                      transition: .linear(duration: 0.3))

        // Absolute content Y of the witness row, the same way the ledger's live edges are built:
        // `containerOriginY + frame.minY - window.minY`.
        let window = fixture.activeWindow
        let survivorIndex = fixture.listView.items.firstIndex { $0.identity == survivor }
        XCTAssertNotNil(survivorIndex, "the witness row must survive")
        let survivorItem = window.items.first { $0.index == survivorIndex }
        XCTAssertNotNil(survivorItem, "the witness row must be loaded")
        let survivorTop: CGFloat? = survivorItem.map {
            fixture.containerOriginY + $0.frame.minY - window.minY
        }
        let blocks = fixture.listView.ghostBlockSnapshots
        XCTAssertFalse(blocks.isEmpty, "the deletion must produce a ghost block to test")
        for snapshot in blocks {
            XCTAssertEqual(snapshot.settledRootY + snapshot.localMaxY, survivorTop!, accuracy: 1e-6,
                           "block \(snapshot.id.rawValue) must rest its bottom on its witness's top, "
                           + "not overlap it (edge \(snapshot.attachmentEdge))")
        }
    }

    /// The edge choice itself: a block above its witness attaches by `maxY`, whatever the anchor.
    func testGhostAboveItsWitnessAttachesByMaxY() {
        let (fixture, _) = fixtureWithPendingTopRows()

        let target = fixture.containerOriginY + 150 - 302
        fixture.engine.setOffset(target)
        fixture.engine.onScroll?(target)

        var items = fixture.listView.items
        items.removeFirst(5)
        fixture.listView.applyChanges(items: items,
                                      anchorMode: .preserveVisibleContent,
                                      transition: .linear(duration: 0.3))

        let blocks = fixture.listView.ghostBlockSnapshots
        XCTAssertFalse(blocks.isEmpty, "the deletion must produce a ghost block to test")
        for snapshot in blocks {
            // The five departed rows are all ABOVE the surviving row that witnesses them, and none
            // of them was replaced in place, so every block here rides its bottom edge.
            XCTAssertEqual(snapshot.attachmentEdge, .maxY,
                           "block \(snapshot.id.rawValue) sits above its witness")
        }
    }

    /// The ordinary mid-collection delete: rows 1 and 2 leave, row 3 slides UP into the space they
    /// vacated. The two tops genuinely coincide, so the block shares that edge and holds still while
    /// the live rows collapse past it. An unconditional `.maxY` would lift the block by its own height,
    /// sliding it up over row 0.
    func testMidCollectionDeleteAttachesByMinYAndHoldsStill() {
        let fixture = VirtualListFixture(items: rows(5))
        var items = fixture.listView.items
        items.removeSubrange(1...2)
        fixture.apply(items, duration: 0.3)

        let block = fixture.ghostBlocks.first
        XCTAssertNotNil(block, "the deletion must produce a ghost block")
        XCTAssertEqual(block?.attachmentEdge, .minY,
                       "the successor collapsed into the gap, so the block shares its top edge")

        let track = fixture.animationController.model.track(
            for: .ghostBlock(block!.id.rawValue), property: .positionY)
        XCTAssertEqual(track?.from ?? 0, 0, accuracy: 1e-6,
                       "a block whose successor collapsed into its gap must not move")
    }

    /// A row that departs while it is still animating. Its SAMPLED root (what the block is created at,
    /// deliberately — members freeze at their current visual arrangement) is far from its SETTLED top:
    /// 148.639 vs 50.0 when this was measured. The edge decision must read the settled value, or this
    /// block is mis-classified as "successor went elsewhere" and the exact ghost handoff in
    /// `CoreVirtualListAnimationTests.testRemovedWitnessHandsOlderBlockToNewGhostAtExactBoundary`
    /// breaks two suites away from the change that caused it.
    func testDepartureWhileInFlightIsClassifiedBySettledGeometry() {
        let fixture = VirtualListFixture(items: rows(5))
        var first = fixture.listView.items
        first.removeSubrange(1...2)
        fixture.apply(first, duration: 12)
        fixture.advance(by: 1)

        var second = fixture.listView.items
        second.remove(at: 1)                     // row 3 — still mid-flight from the first pass
        fixture.apply(second, duration: 4)

        let newest = fixture.ghostBlocks.max(by: { $0.id.rawValue < $1.id.rawValue })
        XCTAssertNotNil(newest, "the second deletion must produce a ghost block")
        XCTAssertEqual(newest?.attachmentEdge, .minY,
                       "settled geometry says the successor collapsed into the gap, "
                       + "even though the sampled root is mid-animation")
    }
}
