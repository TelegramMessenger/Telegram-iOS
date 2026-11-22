import XCTest
import UIKit
@testable import CoreListDemo

final class LoadedEdgeObservationTests: XCTestCase {
    private final class Item: CoreListItem {
        let id: Int

        var identity: AnyHashable { id }

        init(id: Int) {
            self.id = id
        }

        func view() -> UIView & CoreListItemView {
            FixedHeightItemView(height: 50)
        }

        func isEqual(to other: CoreListItem) -> Bool {
            (other as? Item)?.id == id
        }
    }

    private func items(_ range: Range<Int>) -> [CoreListItem] {
        range.map { Item(id: $0) }
    }

    private func topBoundaryScreenY(_ fixture: VirtualListFixture) -> CGFloat {
        fixture.listView.containerOriginY - fixture.listView.engine.offset
    }

    private func bottomBoundaryContentY(_ fixture: VirtualListFixture) -> CGFloat {
        fixture.listView.containerOriginY
            - fixture.listView.activeWindow.minY
            + fixture.listView.activeWindow.maxY
    }

    private func placeTopBoundary(
        at screenY: CGFloat,
        in fixture: VirtualListFixture
    ) {
        fixture.scroll(to: fixture.listView.containerOriginY - screenY)
    }

    private func placeBottomBoundary(
        at screenY: CGFloat,
        in fixture: VirtualListFixture
    ) {
        fixture.scroll(to: bottomBoundaryContentY(fixture) - screenY)
    }

    func testLoadLinesUseListBoundsInsteadOfInsets() {
        let top = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        top.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )
        placeTopBoundary(at: 0, in: top)

        XCTAssertEqual(topBoundaryScreenY(top), 0, accuracy: 1e-6)
        XCTAssertEqual(top.listView.reachedLoadedEdges, [.top])

        let bottom = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        bottom.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0),
            transition: .easeInOut(duration: 0)
        )
        bottom.listView.applyChanges(
            scrollTo: .init(index: 99, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        placeBottomBoundary(at: 300, in: bottom)

        XCTAssertEqual(
            bottomBoundaryContentY(bottom) - bottom.listView.engine.offset,
            300,
            accuracy: 1e-6
        )
        XCTAssertEqual(bottom.listView.reachedLoadedEdges, [.bottom])
    }

    func testPositiveMarginLoadsLaterAtBothLines() {
        let top = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        top.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 100, left: 0, bottom: 0, right: 0),
            transition: .easeInOut(duration: 0)
        )
        top.listView.loadedEdgeMargin = 50
        placeTopBoundary(at: 0, in: top)
        XCTAssertFalse(top.listView.reachedLoadedEdges.contains(.top))
        placeTopBoundary(at: 50, in: top)
        XCTAssertTrue(top.listView.reachedLoadedEdges.contains(.top))

        let bottom = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        bottom.listView.applyChanges(
            newInsets: UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0),
            transition: .easeInOut(duration: 0)
        )
        bottom.listView.applyChanges(
            scrollTo: .init(index: 99, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        bottom.listView.loadedEdgeMargin = 50
        placeBottomBoundary(at: 300, in: bottom)
        XCTAssertFalse(bottom.listView.reachedLoadedEdges.contains(.bottom))
        placeBottomBoundary(at: 250, in: bottom)
        XCTAssertTrue(bottom.listView.reachedLoadedEdges.contains(.bottom))
    }

    func testNegativeMarginLoadsEarlierAtBothLines() {
        let top = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        top.listView.loadedEdgeMargin = -50
        placeTopBoundary(at: -50, in: top)
        XCTAssertTrue(top.listView.reachedLoadedEdges.contains(.top))

        let bottom = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        bottom.listView.applyChanges(
            scrollTo: .init(index: 99, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        bottom.listView.loadedEdgeMargin = -50
        placeBottomBoundary(at: 350, in: bottom)
        XCTAssertTrue(bottom.listView.reachedLoadedEdges.contains(.bottom))
    }

    func testChangingMarginImmediatelyRecomputesAndDeduplicatesArrival() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        placeTopBoundary(at: 0, in: fixture)
        var arrivals: [CoreListLoadedEdge] = []
        fixture.listView.onLoadedEdgeReached = { arrivals.append($0) }

        fixture.listView.loadedEdgeMargin = 50
        XCTAssertFalse(fixture.listView.reachedLoadedEdges.contains(.top))

        fixture.listView.loadedEdgeMargin = 0
        fixture.listView.loadedEdgeMargin = 0

        XCTAssertEqual(arrivals, [.top])
        XCTAssertTrue(fixture.listView.reachedLoadedEdges.contains(.top))
    }

    func testInitialSettledTopIsReadable() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )

        XCTAssertEqual(fixture.listView.reachedLoadedEdges, [.top])
    }

    func testRepeatedScrollCallbacksAtTopEmitNoDuplicateArrival() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        var arrivals: [CoreListLoadedEdge] = []
        fixture.listView.onLoadedEdgeReached = { arrivals.append($0) }

        fixture.fireScroll()
        fixture.fireScroll()

        XCTAssertTrue(arrivals.isEmpty)
        XCTAssertEqual(fixture.listView.reachedLoadedEdges, [.top])
    }

    func testLeavingAndReturningToTopEmitsOneNewArrival() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        var arrivals: [CoreListLoadedEdge] = []
        fixture.listView.onLoadedEdgeReached = { arrivals.append($0) }

        fixture.scroll(to: 300)
        fixture.scroll(to: 0)
        fixture.fireScroll()

        XCTAssertEqual(arrivals, [.top])
    }

    func testProgrammaticBottomArrivalIsReportedOnce() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        var arrivals: [CoreListLoadedEdge] = []
        fixture.listView.onLoadedEdgeReached = { arrivals.append($0) }

        fixture.listView.applyChanges(
            scrollTo: .init(index: 99, pointOffset: 0),
            transition: .easeInOut(duration: 0)
        )
        fixture.fireScroll()

        XCTAssertEqual(arrivals, [.bottom])
        XCTAssertEqual(fixture.listView.reachedLoadedEdges, [.bottom])
    }

    func testTopOverscrollDoesNotRepeatArrival() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<100),
            preloadMargin: 100
        )
        var arrivals: [CoreListLoadedEdge] = []
        fixture.listView.onLoadedEdgeReached = { arrivals.append($0) }

        fixture.scroll(to: -30)
        fixture.fireScroll()

        XCTAssertTrue(arrivals.isEmpty)
        XCTAssertEqual(fixture.listView.reachedLoadedEdges, [.top])
    }

    func testUnderfilledListReportsBothSettledEdges() {
        let fixture = VirtualListFixture(
            viewport: CGSize(width: 390, height: 300),
            items: items(0..<2),
            preloadMargin: 100
        )

        XCTAssertEqual(fixture.listView.reachedLoadedEdges, [.top, .bottom])
    }
}
