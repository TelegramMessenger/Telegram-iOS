import XCTest
@testable import MediaGrid

final class MediaGridPrefetchTests: XCTestCase {
    private let height: CGFloat = 800.0

    private func makeLayout(count: Int) -> MediaGridUniformLayout {
        let geometry = MediaGridGeometry(width: 393.0, sideInset: 0.0, topInset: 0.0, bottomInset: 0.0, spacing: 1.0, scale: 3.0)
        return MediaGridUniformLayout(geometry: geometry, columns: 3, cellAspect: 1.0, reservedSlots: [], count: count)
    }

    func testIdleWindow() {
        let layout = self.makeLayout(count: 100_000)
        var planner = MediaGridPrefetchPlanner()
        let offset: CGFloat = 20_000.0
        _ = planner.update(layout: layout, viewportHeight: self.height, offset: offset - 500.0, settledOffset: nil)
        let plan = planner.update(layout: layout, viewportHeight: self.height, offset: offset, settledOffset: nil)
        let expected = layout.indexRange(intersecting: CGRect(x: 0.0, y: offset, width: 393.0, height: self.height * 3.0))
        let cached = Set(planner.cachedIndices)
        XCTAssertEqual(cached, Set(expected))
        XCTAssertTrue(Set(plan.start).isSubset(of: cached))
        XCTAssertFalse(plan.start.isEmpty)
        XCTAssertTrue(plan.stop.isEmpty || Set(plan.stop).isDisjoint(with: cached))
    }

    func testChangesRemapCachedAndRestartChanged() {
        let layout = self.makeLayout(count: 100_000)
        var planner = MediaGridPrefetchPlanner()
        let offset: CGFloat = 20_000.0
        _ = planner.update(layout: layout, viewportHeight: self.height, offset: offset, settledOffset: nil)
        let before = planner.cachedIndices
        let changed = before[5]
        planner.apply(MediaGridChanges(removed: [before[0]], inserted: [], changed: [changed - 1]))
        let cached = planner.cachedIndices
        XCTAssertFalse(cached.contains(changed - 1))
        XCTAssertEqual(cached.count, before.count - 2)
        XCTAssertEqual(cached.first, before[0])
        let shifted = self.makeLayout(count: 99_999)
        let plan = planner.update(layout: shifted, viewportHeight: self.height, offset: offset, settledOffset: nil)
        XCTAssertTrue(plan.start.contains(changed - 1))
    }

    func testUpwardWindow() {
        let layout = self.makeLayout(count: 100_000)
        var planner = MediaGridPrefetchPlanner()
        let offset: CGFloat = 20_000.0
        _ = planner.update(layout: layout, viewportHeight: self.height, offset: offset + 10.0, settledOffset: nil)
        _ = planner.update(layout: layout, viewportHeight: self.height, offset: offset, settledOffset: nil)
        let expected = layout.indexRange(intersecting: CGRect(x: 0.0, y: offset - 2.0 * self.height, width: 393.0, height: self.height * 3.0))
        XCTAssertEqual(Set(planner.cachedIndices), Set(expected))
    }

    func testEqualOffsetKeepsDirection() {
        let layout = self.makeLayout(count: 100_000)
        var planner = MediaGridPrefetchPlanner()
        let offset: CGFloat = 20_000.0
        _ = planner.update(layout: layout, viewportHeight: self.height, offset: offset + 500.0, settledOffset: nil)
        _ = planner.update(layout: layout, viewportHeight: self.height, offset: offset, settledOffset: nil)
        let cached = Set(planner.cachedIndices)
        let plan = planner.update(layout: layout, viewportHeight: self.height, offset: offset, settledOffset: nil)
        XCTAssertEqual(plan, MediaGridPrefetchPlan(start: [], stop: []))
        XCTAssertEqual(Set(planner.cachedIndices), cached)
        let expected = layout.indexRange(intersecting: CGRect(x: 0.0, y: offset - 2.0 * self.height, width: 393.0, height: self.height * 3.0))
        XCTAssertEqual(cached, Set(expected))
    }

    func testFlightAddsLandingWindow() {
        let layout = self.makeLayout(count: 100_000)
        var planner = MediaGridPrefetchPlanner()
        let settled: CGFloat = 50.0 * self.height
        let plan = planner.update(layout: layout, viewportHeight: self.height, offset: 0.0, settledOffset: settled)
        let landing = layout.indexRange(intersecting: CGRect(x: 0.0, y: settled - self.height, width: 393.0, height: self.height * 3.0))
        XCTAssertFalse(landing.isEmpty)
        XCTAssertTrue(Set(landing).isSubset(of: Set(plan.start)))
        let viewport = layout.indexRange(intersecting: CGRect(x: 0.0, y: 0.0, width: 393.0, height: self.height))
        XCTAssertTrue(Set(viewport).isSubset(of: Set(plan.start)))
        XCTAssertEqual(plan.start.count, Set(plan.start).count)
    }

    func testStopsWhatLeft() {
        let layout = self.makeLayout(count: 100_000)
        var planner = MediaGridPrefetchPlanner()
        let first = planner.update(layout: layout, viewportHeight: self.height, offset: 0.0, settledOffset: nil)
        let second = planner.update(layout: layout, viewportHeight: self.height, offset: 40_000.0, settledOffset: nil)
        XCTAssertEqual(Set(second.stop), Set(first.start))
        XCTAssertTrue(Set(second.start).isDisjoint(with: Set(second.stop)))
        let third = planner.update(layout: layout, viewportHeight: self.height, offset: 40_000.0 + 400.0, settledOffset: nil)
        XCTAssertTrue(Set(third.start).isDisjoint(with: Set(third.stop)))
        XCTAssertTrue(Set(third.stop).isSubset(of: Set(second.start)))
        XCTAssertFalse(third.stop.isEmpty)
    }

    func testEmptyLayout() {
        var planner = MediaGridPrefetchPlanner()
        let empty = planner.update(layout: self.makeLayout(count: 0), viewportHeight: self.height, offset: 0.0, settledOffset: 100.0)
        XCTAssertEqual(empty, MediaGridPrefetchPlan(start: [], stop: []))
        let layout = self.makeLayout(count: 1000)
        let plan = planner.update(layout: layout, viewportHeight: self.height, offset: 0.0, settledOffset: nil)
        XCTAssertFalse(plan.start.isEmpty)
        let cleared = planner.update(layout: self.makeLayout(count: 0), viewportHeight: self.height, offset: 0.0, settledOffset: nil)
        XCTAssertEqual(Set(cleared.stop), Set(plan.start))
        XCTAssertTrue(cleared.start.isEmpty)
    }

    func testNonFiniteInput() {
        var planner = MediaGridPrefetchPlanner()
        let plan = planner.update(layout: self.makeLayout(count: 100), viewportHeight: self.height, offset: .nan, settledOffset: .infinity)
        XCTAssertEqual(plan, MediaGridPrefetchPlan(start: [], stop: []))
    }
}
