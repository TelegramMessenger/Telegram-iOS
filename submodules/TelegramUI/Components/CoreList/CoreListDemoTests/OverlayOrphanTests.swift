import XCTest
import UIKit
@testable import CoreListDemo

/// Reproduction probes for "stale rows overlay live rows".
///
/// A view parked in `crossingOverlay` or `exitOverlay` is removed only when its animation
/// generation is finished (`finishViewportGeneration`) or the carries are reset. The completion
/// that drives that is registered in `ListAnimationController.install()`, which first calls
/// `discardPendingCompletions()` — and that FILTERS the pending completion rather than invoking it.
/// So replacing an in-flight viewport track always drops the previous generation's completion, and
/// three compensations are the only thing keeping the parked views reachable:
///
///   1. the carry re-stamp to the new generation (CoreVirtualListView, viewport transition block)
///   2. `resetViewportCarries()` on an `.immediate` mutation
///   3. `migrateCrossingViewportReleases`
///
/// A stranded view is invisible to every existing test because it is still laid out and still
/// drawn — it only shows up as a stale row above live content, and it takes no taps because both
/// overlays are `isUserInteractionEnabled = false`.
///
/// Each test below drives one candidate sequence and asserts the ownership invariant. Sequences
/// that pass are eliminated as causes; a failure localises the defect to that sequence.
final class OverlayOrphanTests: XCTestCase {
    /// Every view parked in an overlay must be owned by a live carry or a ghost block wrapper.
    /// Mirrors `CoreVirtualListView.assertOverlayInvariants()` but reports as a test failure with
    /// the offending sequence's name rather than trapping.
    private func assertNoOrphans(_ fixture: VirtualListFixture,
                                 _ label: String,
                                 file: StaticString = #filePath,
                                 line: UInt = #line) {
        let list = fixture.listView
        let owned = Set(
            (fixture.viewportCarryViews + fixture.crossingCarryViews + list.ghostMemberViews)
                .map(ObjectIdentifier.init)
        )
        let ghostWrappers = Set(list.ghostBlockWrapperViews.map(ObjectIdentifier.init))

        // `carouselExitOverlay` is swept on the same terms: it holds the same kinds of tenant,
        // reaped by the same completions, and a view stranded there renders over live rows exactly
        // as one stranded in `exitOverlay` does.
        for view in list.exitOverlay.subviews + list.carouselExitOverlay.subviews {
            let key = ObjectIdentifier(view)
            XCTAssertTrue(owned.contains(key) || ghostWrappers.contains(key),
                          "\(label): an exit overlay holds an unowned view — it will never be "
                          + "removed and will render above live rows",
                          file: file, line: line)
        }
        for view in list.crossingOverlay.subviews {
            XCTAssertTrue(owned.contains(ObjectIdentifier(view)),
                          "\(label): crossingOverlay holds an unowned view — it will never be "
                          + "removed and will render above live rows",
                          file: file, line: line)
        }
    }

    /// Settling the clock past every animation must drain both overlays completely. If a
    /// generation's completion was dropped, its carries survive an arbitrarily long settle.
    private func assertOverlaysDrainAfterSettle(_ fixture: VirtualListFixture,
                                                _ label: String,
                                                file: StaticString = #filePath,
                                                line: UInt = #line) {
        fixture.advance(by: 10)
        fixture.flushScheduler()
        XCTAssertEqual(fixture.listView.exitOverlay.subviews.count, 0,
                       "\(label): exitOverlay still populated long after all animations settled",
                       file: file, line: line)
        XCTAssertEqual(fixture.listView.crossingOverlay.subviews.count, 0,
                       "\(label): crossingOverlay still populated long after all animations settled",
                       file: file, line: line)
        XCTAssertEqual(fixture.listView.carouselExitOverlay.subviews.count, 0,
                       "\(label): carouselExitOverlay still populated long after all animations "
                       + "settled",
                       file: file, line: line)
    }

    // MARK: - Candidate A: overlapping viewport tracks

    /// A second scroll-to arriving mid-animation replaces the viewport track, which discards
    /// generation N's completion. Generation N's carries survive only via the re-stamp.
    func testOverlappingScrollToDoesNotStrandCarries() {
        let fixture = VirtualListFixture(itemCount: 200, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        assertNoOrphans(fixture, "overlapping scrollTo")
        assertOverlaysDrainAfterSettle(fixture, "overlapping scrollTo")
    }

    /// Three-deep overlap: each replacement discards the previous completion, so a re-stamp that
    /// only carries one generation forward would lose the oldest.
    func testTripleOverlappingScrollToDoesNotStrandCarries() {
        let fixture = VirtualListFixture(itemCount: 300, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        for index in [200, 120, 40] {
            fixture.listView.applyChanges(scrollTo: .init(index: index, pointOffset: 0),
                                          transition: .easeInOut(duration: 0.3))
            fixture.advance(by: 0.05)
        }
        assertNoOrphans(fixture, "triple overlapping scrollTo")
        assertOverlaysDrainAfterSettle(fixture, "triple overlapping scrollTo")
    }

    // MARK: - Candidate B: emptying the list mid-animation

    /// `applyChanges(items: [])` while a viewport transition is in flight. If the empty-list early
    /// return is taken with parked views alive, nothing ever reaps them.
    func testEmptyingListMidTransitionDrainsOverlays() {
        let fixture = VirtualListFixture(itemCount: 200, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        fixture.listView.applyChanges(items: [], transition: .easeInOut(duration: 0.3))
        assertNoOrphans(fixture, "empty mid-transition")
        assertOverlaysDrainAfterSettle(fixture, "empty mid-transition")
    }

    /// Two empty applications in a row: the second sees `activeWindow.isEmpty`, which is the
    /// precondition for the early return that skips `rebuildFromScratch()` when ghosts are alive.
    func testDoubleEmptyApplicationDrainsOverlays() {
        let fixture = VirtualListFixture(itemCount: 200, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        fixture.listView.applyChanges(items: [], transition: .easeInOut(duration: 0.3))
        fixture.listView.applyChanges(items: [], transition: .easeInOut(duration: 0.3))
        assertNoOrphans(fixture, "double empty application")
        assertOverlaysDrainAfterSettle(fixture, "double empty application")
    }

    /// Empty, then repopulate while the emptying animation is still running — the chat-side shape
    /// of switching conversations mid-transition.
    func testEmptyThenRepopulateMidTransitionDrainsOverlays() {
        let fixture = VirtualListFixture(itemCount: 200, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        fixture.listView.applyChanges(items: [], transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.05)
        let replacement: [CoreListItem] = (0..<200).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: 50)
        }
        fixture.listView.applyChanges(items: replacement, transition: .easeInOut(duration: 0.3))
        assertNoOrphans(fixture, "empty then repopulate")
        assertOverlaysDrainAfterSettle(fixture, "empty then repopulate")
    }

    // MARK: - Candidate C: scroll-to with no item list

    /// The scroll-to-only shape the chat backend emits: `applyChanges(items: nil, scrollTo: ...)`.
    /// Driven immediately after emptying, so `activeWindow` is empty when it lands.
    func testScrollToWithNilItemsAfterEmptyDrainsOverlays() {
        let fixture = VirtualListFixture(itemCount: 200, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        fixture.listView.applyChanges(items: [], transition: .easeInOut(duration: 0.3))
        fixture.listView.applyChanges(scrollTo: .init(index: 0, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        assertNoOrphans(fixture, "scrollTo with nil items after empty")
        assertOverlaysDrainAfterSettle(fixture, "scrollTo with nil items after empty")
    }

    // MARK: - Candidate D: size change racing a scroll-to

    /// A size/inset pass takes the third viewport-transition branch, whose `transitionViewportFrom`
    /// comes from `mutation.startedTrack?.from` and is therefore nil for a non-`.started` mutation —
    /// the one branch where the carry re-stamp guard can fail.
    func testSizeChangeDuringScrollToDrainsOverlays() {
        let fixture = VirtualListFixture(itemCount: 200, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        fixture.listView.applyChanges(newSize: CGSize(width: 390, height: 300),
                                      transition: .easeInOut(duration: 0.3))
        assertNoOrphans(fixture, "size change during scrollTo")
        assertOverlaysDrainAfterSettle(fixture, "size change during scrollTo")
    }

    /// Same, but with a zero-duration mutation, which yields `.immediate` and relies on
    /// `resetViewportCarries()` rather than the re-stamp.
    func testImmediateSizeChangeDuringScrollToDrainsOverlays() {
        let fixture = VirtualListFixture(itemCount: 200, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        fixture.listView.applyChanges(newSize: CGSize(width: 390, height: 300),
                                      transition: .easeInOut(duration: 0))
        assertNoOrphans(fixture, "immediate size change during scrollTo")
        assertOverlaysDrainAfterSettle(fixture, "immediate size change during scrollTo")
    }
}
