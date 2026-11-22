import XCTest
@testable import CoreListDemo

final class InitialLayoutTests: XCTestCase {

    // MARK: - Geometry at rest

    func testFirstItemAtTop() {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50)
        XCTAssertEqual(fixture.screenY(forIndex: 0)!, 0, accuracy: 0.5)
    }

    func testLoadsEnoughItemsToFillViewportPlusMargin() {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50, preloadMargin: 160)
        let minExpected = Int((800 + 160) / 50) - 1
        XCTAssertEqual(fixture.activeWindow.startIndex, 0)
        XCTAssertGreaterThanOrEqual(fixture.activeWindow.endIndex, minExpected)
    }

    func testContainerAtTop() {
        let fixture = VirtualListFixture(itemCount: 100)
        XCTAssertEqual(fixture.containerOriginY, 0, accuracy: 0.5)
    }

    func testContentSizeIsVirtualWhenManyItems() {
        let fixture = VirtualListFixture(itemCount: 100)
        // 100 items → bottom edge unloaded → open edge → the adapter's 10M canvas as contentSize.
        XCTAssertEqual(fixture.contentSize.height, 10_000_000)
    }

    func testContentSizeIsTightWhenAllItemsFit() {
        let fixture = VirtualListFixture(itemCount: 5, itemHeight: 50)
        XCTAssertEqual(fixture.contentSize.height, 800)
    }

    // MARK: - Item positions

    func testItemPositionsAreContiguous() {
        let fixture = VirtualListFixture(itemCount: 100)
        let items = fixture.activeWindow.items
        for i in 0..<items.count - 1 {
            XCTAssertEqual(items[i].frame.maxY, items[i + 1].frame.minY, accuracy: 0.01)
            XCTAssertEqual(items[i].index + 1, items[i + 1].index)
        }
    }

    func testItemPositionsHaveCorrectHeight() {
        let fixture = VirtualListFixture(itemCount: 100, itemHeight: 50)
        for item in fixture.activeWindow.items {
            XCTAssertEqual(item.frame.height, 50, accuracy: 0.01)
        }
    }

    // MARK: - Edge anchoring

    func testTopRubberBandPosition() {
        let fixture = VirtualListFixture(itemCount: 100)
        XCTAssertEqual(fixture.containerOriginY, 0, accuracy: 0.5)
        XCTAssertEqual(fixture.boundsOriginY, 0, accuracy: 0.5)
    }

    // MARK: - Reload

    func testReloadResetsToTop() {
        let fixture = VirtualListFixture(itemCount: 100)
        fixture.listView.applyChanges(scrollTo: .init(index: 50, pointOffset: 0), transition: .easeInOut(duration: 0))
        // Re-assigning items triggers a full rebuild to the top.
        fixture.listView.items = fixture.listView.items
        XCTAssertEqual(fixture.activeWindow.startIndex, 0)
        XCTAssertEqual(fixture.containerOriginY, 0, accuracy: 0.5)
    }

    // MARK: - Edge cases

    func testFewItemsAllLoaded() {
        let fixture = VirtualListFixture(itemCount: 3, itemHeight: 50)
        XCTAssertEqual(fixture.loadedIndices, [0, 1, 2])
    }

    func testSingleItem() {
        let fixture = VirtualListFixture(itemCount: 1, itemHeight: 50)
        XCTAssertEqual(fixture.loadedIndices, [0])
        XCTAssertEqual(fixture.containerOriginY, 0, accuracy: 0.5)
    }

    func testEmptyItems() {
        let fixture = VirtualListFixture(itemCount: 0)
        XCTAssertTrue(fixture.activeWindow.isEmpty)
    }
}
