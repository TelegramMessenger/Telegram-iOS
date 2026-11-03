import XCTest
@testable import CoreListDemo

final class LoadedItemViewsTests: XCTestCase {
    func testLoadedItemViewsMatchesSettledWindowInOrder() {
        // 50 rows of 50pt in an 800pt viewport: only a window (viewport + preload) is loaded, so this
        // also verifies the iterator visits ONLY loaded rows, not all 50.
        let fixture = PhysicsListFixture(itemCount: 50)

        let viaIterator = Array(fixture.listView.loadedItemViews)
        let expected = fixture.listView.activeWindow.items.map { $0.view }

        XCTAssertFalse(expected.isEmpty, "some rows must be loaded")
        XCTAssertLessThan(expected.count, 50, "only the settled window is loaded, not every row")
        XCTAssertEqual(viaIterator.count, expected.count)
        for (a, b) in zip(viaIterator, expected) {
            XCTAssertTrue(a === b, "loadedItemViews must yield the same view instances, in window order")
        }
    }

    func testLoadedItemViewsIsEmptyWhenNoItems() {
        let fixture = PhysicsListFixture(itemCount: 0)
        XCTAssertEqual(Array(fixture.listView.loadedItemViews).count, 0)
    }

    func testLoadedItemViewAtIndexMatchesWindowForEveryLoadedIndex() {
        let fixture = PhysicsListFixture(itemCount: 50)

        let items = fixture.activeWindow.items
        XCTAssertFalse(items.isEmpty, "some rows must be loaded")
        XCTAssertLessThan(items.count, 50, "only the settled window is loaded, not every row")

        for item in items {
            let looked = fixture.listView.loadedItemView(at: item.index)
            XCTAssertTrue(looked === item.view, "index \(item.index) must resolve to its window view")
        }
    }

    func testLoadedItemViewAtIndexIsNilOutsideTheLoadedWindow() {
        let fixture = PhysicsListFixture(itemCount: 50)

        let loaded = fixture.loadedIndices
        XCTAssertFalse(loaded.isEmpty, "some rows must be loaded")

        // Above the window: the collection has 50 rows but only a window of them is loaded.
        XCTAssertLessThan(loaded.count, 50, "there must be an unloaded index to probe")
        let firstUnloadedAbove = loaded.max()! + 1
        XCTAssertLessThan(firstUnloadedAbove, 50, "probe must still be a valid collection index")
        XCTAssertNil(fixture.listView.loadedItemView(at: firstUnloadedAbove))

        // Outside the collection entirely, both directions.
        XCTAssertNil(fixture.listView.loadedItemView(at: -1))
        XCTAssertNil(fixture.listView.loadedItemView(at: 50))
    }

    func testLoadedItemViewAtIndexIsNilWhenNoItems() {
        let fixture = PhysicsListFixture(itemCount: 0)
        XCTAssertNil(fixture.listView.loadedItemView(at: 0))
    }

    // The case a naive `items[index]` implementation would fail: after scrolling, the settled window
    // no longer starts at collection index 0, so array position != collection index.
    func testLoadedItemViewAtIndexIsCorrectAfterScrollingAwayFromTheTop() {
        let fixture = PhysicsListFixture(itemCount: 200)

        fixture.simulateFlick(offsetVelocity: 4_000)
        _ = fixture.runUntilSettled(max: 5.0)

        let items = fixture.activeWindow.items
        XCTAssertFalse(items.isEmpty, "some rows must be loaded after scrolling")
        XCTAssertGreaterThan(items.first!.index, 0, "the window must have left collection index 0")

        for item in items {
            let looked = fixture.listView.loadedItemView(at: item.index)
            XCTAssertTrue(looked === item.view, "index \(item.index) must resolve to its window view")
        }
        // Index 0 is scrolled out of the loaded window, so it must not resolve.
        XCTAssertNil(fixture.listView.loadedItemView(at: 0))
    }

    func testLoadedItemEntriesPairIndexWithViewInWindowOrder() {
        let fixture = PhysicsListFixture(itemCount: 50)

        let expected = fixture.activeWindow.items
        XCTAssertFalse(expected.isEmpty, "some rows must be loaded")
        XCTAssertLessThan(expected.count, 50, "only the settled window is loaded, not every row")

        let entries = Array(fixture.listView.loadedItemEntries)
        XCTAssertEqual(entries.count, expected.count)
        for (entry, item) in zip(entries, expected) {
            XCTAssertEqual(entry.index, item.index)
            XCTAssertTrue(entry.view === item.view, "entry \(entry.index) must yield the window's view instance")
        }
    }

    func testLoadedItemEntriesIsEmptyWhenNoItems() {
        let fixture = PhysicsListFixture(itemCount: 0)
        XCTAssertEqual(Array(fixture.listView.loadedItemEntries).count, 0)
    }

    // Indices must be the window's own, not iteration positions: after scrolling, the window no
    // longer starts at collection index 0.
    func testLoadedItemEntriesCarryCollectionIndicesAfterScrolling() {
        let fixture = PhysicsListFixture(itemCount: 200)

        fixture.simulateFlick(offsetVelocity: 4_000)
        _ = fixture.runUntilSettled(max: 5.0)

        let entries = Array(fixture.listView.loadedItemEntries)
        XCTAssertFalse(entries.isEmpty, "some rows must be loaded after scrolling")
        XCTAssertGreaterThan(entries[0].index, 0, "the window must have left collection index 0")

        for (entry, item) in zip(entries, fixture.activeWindow.items) {
            XCTAssertEqual(entry.index, item.index)
            XCTAssertTrue(entry.view === item.view)
        }
    }
}
