import XCTest
import UIKit
@testable import CoreListDemo

/// The two regions `OverlayOrphanTests` could not reach.
///
/// Those probes drive `applyChanges` directly, so they never produce a *nested* call and never
/// involve the scroll engine. Both gaps matter:
///
///   - **Re-entrancy.** A row signalling `onContentDidChange` calls `markDirty`, which schedules
///     `flushDirtyItems` → `applyChanges(transition:)` with no items, no size and no
///     scrollTo. If that lands while a pass is already running, the re-entrancy guard defers it and
///     it executes against state that has since moved. The engine nils `onContentDidChange` on
///     views it parks, which says the authors knew this fires during transitions.
///   - **User drag.** Every earlier sequence was programmatic. A real drag drives `handleUserScroll`
///     and can interleave with an in-flight programmatic transition.
///
/// As in `OverlayOrphanTests`, a passing test eliminates a candidate; each is paired with an
/// occupancy probe so a pass cannot be vacuous.
final class OverlayOrphanReentrancyTests: XCTestCase {
    private func selfUpdatingFixture(count: Int = 200) -> VirtualListFixture {
        let items: [CoreListItem] = (0..<count).map { _ in
            SelfUpdatingItem(id: UUID(), initialHeight: 50)
        }
        return VirtualListFixture(viewport: CGSize(width: 390, height: 400), items: items)
    }

    private func assertNoOrphans(_ fixture: VirtualListFixture,
                                 _ label: String,
                                 file: StaticString = #filePath,
                                 line: UInt = #line) {
        let list = fixture.listView
        let owned = Set(
            (fixture.viewportCarryViews + fixture.crossingCarryViews + list.ghostMemberViews)
                .map(ObjectIdentifier.init)
        )
        let wrappers = Set(list.ghostBlockWrapperViews.map(ObjectIdentifier.init))
        for view in list.exitOverlay.subviews + list.carouselExitOverlay.subviews {
            let key = ObjectIdentifier(view)
            XCTAssertTrue(owned.contains(key) || wrappers.contains(key),
                          "\(label): an exit overlay holds an unowned view", file: file, line: line)
        }
        for view in list.crossingOverlay.subviews {
            XCTAssertTrue(owned.contains(ObjectIdentifier(view)),
                          "\(label): crossingOverlay holds an unowned view", file: file, line: line)
        }
    }

    private func assertOverlaysDrain(_ fixture: VirtualListFixture,
                                     _ label: String,
                                     file: StaticString = #filePath,
                                     line: UInt = #line) {
        fixture.advance(by: 10)
        fixture.flushScheduler()
        fixture.advance(by: 10)
        XCTAssertEqual(fixture.listView.exitOverlay.subviews.count, 0,
                       "\(label): exitOverlay still populated after settling",
                       file: file, line: line)
        XCTAssertEqual(fixture.listView.crossingOverlay.subviews.count, 0,
                       "\(label): crossingOverlay still populated after settling",
                       file: file, line: line)
        XCTAssertEqual(fixture.listView.carouselExitOverlay.subviews.count, 0,
                       "\(label): carouselExitOverlay still populated after settling",
                       file: file, line: line)
    }

    /// Finds a rendered self-updating view so the test can drive a content change through the same
    /// hook the engine installs.
    private func visibleSelfUpdatingView(_ fixture: VirtualListFixture) -> SelfUpdatingItemView? {
        fixture.listView.container.subviews.compactMap { $0 as? SelfUpdatingItemView }.first
    }

    // MARK: - Re-entrancy

    func testContentChangeDuringScrollToDrainsOverlays() throws {
        let fixture = selfUpdatingFixture()
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        let view = try XCTUnwrap(visibleSelfUpdatingView(fixture),
                                 "no self-updating row rendered — probe cannot fire the hook")
        view.simulateContentChange(newHeight: 140, animated: true)
        fixture.flushScheduler()
        assertNoOrphans(fixture, "content change during scrollTo")
        assertOverlaysDrain(fixture, "content change during scrollTo")
    }

    /// The dirty flush uses duration 0 when the change is unanimated, which yields an `.immediate`
    /// viewport mutation — the branch that relies on `resetViewportCarries()` rather than the
    /// carry re-stamp.
    func testUnanimatedContentChangeDuringScrollToDrainsOverlays() throws {
        let fixture = selfUpdatingFixture()
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        let view = try XCTUnwrap(visibleSelfUpdatingView(fixture))
        view.simulateContentChange(newHeight: 140, animated: false)
        fixture.flushScheduler()
        assertNoOrphans(fixture, "unanimated content change during scrollTo")
        assertOverlaysDrain(fixture, "unanimated content change during scrollTo")
    }

    /// Two content changes straddling a second scroll-to: the deferred flush lands after the
    /// viewport track has already been replaced.
    func testContentChangeStraddlingOverlappingScrollToDrainsOverlays() throws {
        let fixture = selfUpdatingFixture(count: 300)
        fixture.listView.applyChanges(scrollTo: .init(index: 200, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.08)
        let first = try XCTUnwrap(visibleSelfUpdatingView(fixture))
        first.simulateContentChange(newHeight: 120, animated: true)
        fixture.listView.applyChanges(scrollTo: .init(index: 60, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.flushScheduler()
        fixture.advance(by: 0.05)
        if let second = visibleSelfUpdatingView(fixture) {
            second.simulateContentChange(newHeight: 90, animated: true)
        }
        fixture.flushScheduler()
        assertNoOrphans(fixture, "content change straddling overlapping scrollTo")
        assertOverlaysDrain(fixture, "content change straddling overlapping scrollTo")
    }

    // MARK: - User drag interleaved with a programmatic transition

    func testUserScrollDuringScrollToDrainsOverlays() {
        let fixture = VirtualListFixture(itemCount: 300, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(scrollTo: .init(index: 200, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        fixture.scroll(to: fixture.boundsOriginY + 600)
        fixture.advance(by: 0.05)
        fixture.scroll(to: fixture.boundsOriginY - 300)
        assertNoOrphans(fixture, "user scroll during scrollTo")
        assertOverlaysDrain(fixture, "user scroll during scrollTo")
    }

    func testUserScrollThenEmptyDuringScrollToDrainsOverlays() {
        let fixture = VirtualListFixture(itemCount: 300, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        fixture.listView.applyChanges(scrollTo: .init(index: 200, pointOffset: 0),
                                      transition: .easeInOut(duration: 0.3))
        fixture.advance(by: 0.1)
        fixture.scroll(to: fixture.boundsOriginY + 600)
        fixture.listView.applyChanges(items: [], transition: .easeInOut(duration: 0.3))
        fixture.flushScheduler()
        assertNoOrphans(fixture, "user scroll then empty during scrollTo")
        assertOverlaysDrain(fixture, "user scroll then empty during scrollTo")
    }

    // MARK: - Non-vacuity

    /// Both regions must actually park views, or the assertions above eliminate nothing.
    func testReentrancyAndDragSequencesActuallyParkViews() throws {
        var peak = 0
        let reentrancy = selfUpdatingFixture()
        reentrancy.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                         transition: .easeInOut(duration: 0.3))
        reentrancy.advance(by: 0.1)
        peak = max(peak, reentrancy.listView.exitOverlay.subviews.count + reentrancy.listView.carouselExitOverlay.subviews.count
                   + reentrancy.listView.crossingOverlay.subviews.count)
        let view = try XCTUnwrap(visibleSelfUpdatingView(reentrancy))
        view.simulateContentChange(newHeight: 140, animated: true)
        reentrancy.flushScheduler()
        for _ in 0..<20 {
            reentrancy.advance(by: 0.02)
            peak = max(peak, reentrancy.listView.exitOverlay.subviews.count + reentrancy.listView.carouselExitOverlay.subviews.count
                       + reentrancy.listView.crossingOverlay.subviews.count)
        }
        XCTAssertGreaterThan(peak, 0, "re-entrancy sequence never parked a view — it is vacuous")

        var dragPeak = 0
        let drag = VirtualListFixture(itemCount: 300, itemHeight: 50,
                                      viewport: CGSize(width: 390, height: 400))
        drag.listView.applyChanges(scrollTo: .init(index: 200, pointOffset: 0),
                                   transition: .easeInOut(duration: 0.3))
        drag.advance(by: 0.1)
        drag.scroll(to: drag.boundsOriginY + 600)
        for _ in 0..<20 {
            drag.advance(by: 0.02)
            dragPeak = max(dragPeak, drag.listView.exitOverlay.subviews.count + drag.listView.carouselExitOverlay.subviews.count
                           + drag.listView.crossingOverlay.subviews.count)
        }
        XCTAssertGreaterThan(dragPeak, 0, "drag sequence never parked a view — it is vacuous")
    }
}
