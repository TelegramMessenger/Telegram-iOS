import XCTest
import UIKit
@testable import CoreListDemo

/// A full-replace carousel — the shape a chat produces when it jumps from far in the past to a
/// different region of history — must stay one rigid travel between two strips: the outgoing ghost
/// strip and the incoming live strip are adjacent for the whole pass and never overlap.
///
/// The regression these lock down only appeared when the destination window reached a COLLECTION
/// EDGE. A full replace leaves `initialGhostWitness` no surviving predecessor, so it falls through to
/// `newItems[0]` (or `newItems.last`), which becomes a resolvable boundary witness exactly when that
/// row is loaded — giving the departed strip a second vertical owner that walks it onto the incoming
/// one while the shared viewport track carries both. A jump to a mid-collection target leaves both
/// edge rows unloaded, so the witness stays `.unresolved` and the travel is rigid; that is why the
/// existing carousel suites never saw it. `ProgrammaticScrollAnimationTests` asserts strip adjacency
/// but keeps the same collection (old rows become viewport carries, not ghost blocks), and
/// `CarouselFadeSuppressionTests` does full replaces but only asserts opacity, always at index 50.
final class FullReplaceCarouselStripSeparationTests: XCTestCase {
    private final class Item: CoreListItem {
        let id: Int

        var identity: AnyHashable { id }

        init(id: Int) { self.id = id }

        func view() -> UIView & CoreListItemView { FixedHeightItemView(height: 50) }

        func isEqual(to other: CoreListItem) -> Bool { (other as? Item)?.id == id }
    }

    private func makeFixture() -> VirtualListFixture {
        VirtualListFixture(viewport: CGSize(width: 390, height: 300),
                           items: (0..<200).map { Item(id: $0) },
                           preloadMargin: 100)
    }

    /// Settle far away from either collection edge, then replace the whole collection under an
    /// explicit `scrollTo` — the two loaded windows share no identity, which is what makes the pass
    /// a carousel.
    private func fullReplaceCarousel(_ fixture: VirtualListFixture,
                                     to targetIndex: Int,
                                     direction: CoreListScrollTarget.Direction,
                                     duration: TimeInterval) {
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))
        let replacement: [CoreListItem] = (1000..<1200).map { Item(id: $0) }
        fixture.listView.applyChanges(
            items: replacement,
            scrollTo: .init(index: targetIndex, direction: direction, resolve: { _, _ in 0 }),
            transition: .easeInOut(duration: duration)
        )
    }

    private func liveStrip(_ fixture: VirtualListFixture) -> ClosedRange<CGFloat>? {
        let frames = fixture.activeWindow.items.compactMap {
            fixture.screenFrame(forIndex: $0.index)
        }
        guard let minY = frames.map(\.minY).min(),
              let maxY = frames.map(\.maxY).max() else { return nil }
        return minY...maxY
    }

    private func ghostStrip(_ fixture: VirtualListFixture) -> ClosedRange<CGFloat>? {
        let frames = fixture.ghostMemberViews.compactMap { view -> CGRect? in
            guard let y = fixture.driver.exitScreenY(view: view) else { return nil }
            return CGRect(x: 0, y: y, width: view.bounds.width, height: view.bounds.height)
        }
        guard let minY = frames.map(\.minY).min(),
              let maxY = frames.map(\.maxY).max() else { return nil }
        return minY...maxY
    }

    /// Total height, within the viewport, where a departed row is drawn on top of a live row.
    private func visibleStaleOverlap(_ fixture: VirtualListFixture) -> CGFloat {
        let height = fixture.listView.logicalSize.height
        func clipped(_ lower: CGFloat, _ upper: CGFloat) -> ClosedRange<CGFloat>? {
            let low = max(0, lower), high = min(height, upper)
            return low < high ? low...high : nil
        }
        let ghosts = fixture.ghostMemberViews.compactMap { view -> ClosedRange<CGFloat>? in
            guard let y = fixture.driver.exitScreenY(view: view) else { return nil }
            return clipped(y, y + view.bounds.height)
        }
        let lives = fixture.activeWindow.items.compactMap { item -> ClosedRange<CGFloat>? in
            guard let frame = fixture.screenFrame(forIndex: item.index) else { return nil }
            return clipped(frame.minY, frame.maxY)
        }
        var total: CGFloat = 0
        for ghost in ghosts {
            for live in lives {
                total += max(0, min(ghost.upperBound, live.upperBound)
                    - max(ghost.lowerBound, live.lowerBound))
            }
        }
        return total
    }

    /// Samples the two strips across the travel and fails on any overlap. Stops once the ghosts are
    /// torn down at the deadline — there is nothing left to intersect after that.
    private func assertStripsStayDisjoint(_ fixture: VirtualListFixture,
                                          duration: TimeInterval,
                                          file: StaticString = #filePath,
                                          line: UInt = #line) throws {
        let step = duration / 8
        var sampled = 0
        for _ in 0..<8 {
            guard let ghost = ghostStrip(fixture) else { break }
            let live = try XCTUnwrap(liveStrip(fixture), file: file, line: line)
            let overlap = min(live.upperBound, ghost.upperBound)
                - max(live.lowerBound, ghost.lowerBound)
            XCTAssertLessThanOrEqual(
                overlap, 1e-6,
                "outgoing ghost strip \(ghost) overlaps incoming live strip \(live)",
                file: file, line: line
            )
            sampled += 1
            fixture.tick(dt: step)
        }
        XCTAssertGreaterThan(sampled, 1, "the travel was never observed with ghosts on screen",
                             file: file, line: line)
    }

    /// A chat's "jump to now": the destination window starts at collection index 0, so the witness
    /// `initialGhostWitness` proposes is loaded and used to resolve.
    func testBackwardCarouselToTheFirstIndexKeepsStripsDisjoint() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 0, direction: .backward, duration: 2)
        try assertStripsStayDisjoint(fixture, duration: 2)
    }

    /// The mirror: a jump to the far end of the collection loads the last row, which
    /// `initialGhostWitness` proposes through its `ordinal == newItems.count` branch.
    func testForwardCarouselToTheLastIndexKeepsStripsDisjoint() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 199, direction: .forward, duration: 2)
        try assertStripsStayDisjoint(fixture, duration: 2)
    }

    /// The case that always worked, kept as the control: neither collection edge is loaded.
    func testCarouselToAMidCollectionTargetKeepsStripsDisjoint() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 100, direction: .backward, duration: 2)
        try assertStripsStayDisjoint(fixture, duration: 2)
    }

    /// The mechanism itself, so a regression names its own cause rather than reporting geometry.
    /// The viewport track is the carousel's sole vertical owner; a ghost block must not hold one.
    func testCarouselGhostBlocksTakeNoWitnessAndNoPositionTrack() throws {
        for target in [0, 100, 199] {
            let fixture = makeFixture()
            fullReplaceCarousel(fixture, to: target,
                                direction: target == 199 ? .forward : .backward,
                                duration: 2)

            XCTAssertFalse(fixture.ghostBlocks.isEmpty, "target \(target)")
            for block in fixture.ghostBlocks {
                XCTAssertEqual(block.witness, .unresolved, "target \(target)")
                XCTAssertNil(fixture.ghostBlockTrack(block.id), "target \(target)")
            }
            XCTAssertNotNil(fixture.viewportTrack, "target \(target)")
        }
    }

    /// The reported bug. Jump to a disjoint region, then reverse direction before the travel ends.
    ///
    /// Parked in `exitOverlay` the departed strip is a child of the scrolling content host, so the
    /// finger moved it too — and because the strip's fictional placement is exactly where the
    /// destination's own older rows live, dragging back painted the old window over the new one.
    func testDraggingBackMidCarouselLeavesTheOutgoingStripWhereItIs() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 100, direction: .forward, duration: 2)

        fixture.tick(dt: 0.4)
        let before = try XCTUnwrap(ghostStrip(fixture))

        fixture.beginUserDrag()
        fixture.scroll(to: fixture.boundsOriginY - 400)

        let after = try XCTUnwrap(ghostStrip(fixture))
        XCTAssertEqual(after.lowerBound, before.lowerBound, accuracy: 1e-6,
                       "the drag moved the outgoing strip")
        XCTAssertEqual(after.upperBound, before.upperBound, accuracy: 1e-6,
                       "the drag moved the outgoing strip")
    }

    /// The symptom itself, measured the way the user sees it.
    ///
    /// Deliberately NOT the union-band helpers above: those are exact for a rigid travel, but once
    /// the user drags they compare the ghost against a live band that includes preloaded rows far
    /// off-screen, which under-counts the artifact by an order of magnitude and reads as "no bug".
    /// This counts, per frame, the height of every (ghost row, live row) intersection clipped to the
    /// viewport.
    ///
    /// The drag must go TOWARD the side the strip sits on. That is the reported gesture — jump to the
    /// newest messages, then pull back toward earlier ones — and the only direction with a defect:
    /// dragging the other way sweeps the strip off-screen and was always clean.
    ///
    /// A residual is expected and is not a bug in the fix. The strip is held still while the live
    /// content slides under it, so the two must cross; what is removed is the strip travelling WITH
    /// the content, superimposed on it for the whole pass. Measured on this fixture, content-anchored
    /// vs screen-anchored: peak 179pt vs 48pt of a 300pt viewport, mean 65pt vs 10pt. On a
    /// chat-sized 800pt viewport the residual measures 0 — the strip is off-screen before the
    /// crossing can happen. The overlay is z-ordered below `container` so live rows win the crossing.
    func testDraggingTowardTheStripKeepsStaleRowsOffTheLiveOnes() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 100, direction: .forward, duration: 1.15)

        fixture.tick(dt: 0.1)
        fixture.beginUserDrag()

        var peak: CGFloat = 0
        var total: CGFloat = 0
        var frames = 0
        var elapsed: TimeInterval = 0.1
        while elapsed < 1.15 {
            // A realistic finger: ~960pt/s, toward the strip (a forward jump parks it above).
            fixture.scroll(to: fixture.boundsOriginY - 16)
            let overlap = visibleStaleOverlap(fixture)
            peak = max(peak, overlap)
            total += overlap
            fixture.tick(dt: 1.0 / 60)
            elapsed += 1.0 / 60
            frames += 1
        }
        XCTAssertGreaterThan(frames, 30, "the travel was never actually sampled")
        // Bounds sit between the two measurements, so a regression to content-anchoring (179/65)
        // fails and the expected residual (48/10) passes.
        XCTAssertLessThan(peak, 90, "peak stale-over-live overlap regressed toward content-anchoring")
        XCTAssertLessThan(total / CGFloat(frames), 25,
                          "mean stale-over-live overlap regressed toward content-anchoring")
    }

    /// The same drag, travelling the other way.
    func testDraggingForwardMidBackwardCarouselLeavesTheOutgoingStripWhereItIs() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 100, direction: .backward, duration: 2)

        fixture.tick(dt: 0.4)
        let before = try XCTUnwrap(ghostStrip(fixture))

        fixture.beginUserDrag()
        fixture.scroll(to: fixture.boundsOriginY + 400)

        let after = try XCTUnwrap(ghostStrip(fixture))
        XCTAssertEqual(after.lowerBound, before.lowerBound, accuracy: 1e-6)
        XCTAssertEqual(after.upperBound, before.upperBound, accuracy: 1e-6)
    }

    /// Only the carousel's fiction is screen-anchored. An ordinary deletion's ghost sits at a REAL
    /// content position, so it must still scroll with the content — screen-anchoring everything
    /// would freeze departing rows in place mid-scroll.
    func testAnOrdinaryDeletionGhostStillScrollsWithTheContent() throws {
        let fixture = makeFixture()
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0))

        var remaining: [CoreListItem] = (0..<200).map { Item(id: $0) }
        remaining.removeSubrange(118..<124)
        fixture.listView.applyChanges(items: remaining,
                                      transition: .easeInOut(duration: 2))

        fixture.tick(dt: 0.4)
        let before = try XCTUnwrap(ghostStrip(fixture))

        fixture.beginUserDrag()
        fixture.scroll(to: fixture.boundsOriginY - 200)

        let after = try XCTUnwrap(ghostStrip(fixture))
        XCTAssertEqual(after.lowerBound, before.lowerBound + 200, accuracy: 1e-6,
                       "a content-space ghost must scroll with the content")
    }

    /// Carousel blocks are viewport-anchored; every other ghost stays in content space.
    func testCarouselGhostBlocksAreViewportAnchored() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 100, direction: .forward, duration: 2)

        XCTAssertFalse(fixture.ghostBlocks.isEmpty)
        for block in fixture.ghostBlocks {
            XCTAssertEqual(block.anchoring, .viewport)
        }
    }

    /// A second jump while the first is still travelling replaces the viewport track from its
    /// analytic current value, so the strip's screen position stays continuous across the boundary
    /// and needs no shift of its own.
    func testASecondJumpMidCarouselKeepsTheStripContinuous() throws {
        let fixture = makeFixture()
        fullReplaceCarousel(fixture, to: 100, direction: .forward, duration: 2)
        fixture.tick(dt: 0.4)

        let before = try XCTUnwrap(ghostStrip(fixture))
        let replacement: [CoreListItem] = (5000..<5200).map { Item(id: $0) }
        fixture.listView.applyChanges(
            items: replacement,
            scrollTo: .init(index: 100, direction: .forward, resolve: { _, _ in 0 }),
            transition: .easeInOut(duration: 2)
        )
        let after = try XCTUnwrap(ghostStrip(fixture))

        XCTAssertEqual(after.lowerBound, before.lowerBound, accuracy: 1.0,
                       "the strip jumped across the track replacement")
    }
}
