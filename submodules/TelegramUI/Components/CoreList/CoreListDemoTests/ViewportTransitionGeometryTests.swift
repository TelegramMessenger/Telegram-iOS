import XCTest
@testable import CoreListDemo

final class ViewportTransitionGeometryTests: XCTestCase {

    func testOverlapAlgebraPreservesBoundary() {
        let shift = ViewportTransitionGeometry.coordinateShift(
            oldReferenceY: 1_000, newReferenceY: 240)
        let from = ViewportTransitionGeometry.overlapViewportFrom(
            oldEngineOffset: 900, currentViewportCorrection: -40,
            coordinateShift: shift, newEngineOffset: 200)
        XCTAssertEqual(shift, -760)
        XCTAssertEqual(from, -100)
        XCTAssertEqual(240 - (200 + from), 1_000 - (900 - 40), accuracy: 1e-9)
    }

    func testCarouselBoundsSignKeepsOutgoingAtOldScreenTop() {
        let forward = ViewportTransitionGeometry.carouselViewportFrom(
            direction: .forward, oldVisibleTop: 0, newVisibleTop: 0,
            oldStripHeight: 1_100, newWindowHeight: 900)
        XCTAssertEqual(forward, -1_100)
        XCTAssertEqual((-1_100) - forward, 0, accuracy: 1e-9)
        let backward = ViewportTransitionGeometry.carouselViewportFrom(
            direction: .backward, oldVisibleTop: 0, newVisibleTop: 0,
            oldStripHeight: 1_100, newWindowHeight: 900)
        XCTAssertEqual(backward, 900)
        XCTAssertEqual(900 - backward, 0, accuracy: 1e-9)
    }

    func testSelectionAndMapping() {
        let order = (0..<30).map(AnyHashable.init)
        XCTAssertEqual(ViewportTransitionGeometry.direction(
            currentAnchor: AnyHashable(10), targetIndex: 20, newOrder: order), .forward)
        XCTAssertEqual(ViewportTransitionGeometry.overlapReference(
            currentAnchor: AnyHashable(10), direction: .forward,
            oldLoaded: (0...15).map(AnyHashable.init),
            newLoaded: (10...25).map(AnyHashable.init), newOrder: order), AnyHashable(10))
        XCTAssertEqual(ViewportTransitionGeometry.overlapReference(
            currentAnchor: AnyHashable(5), direction: .forward,
            oldLoaded: (0...15).map(AnyHashable.init),
            newLoaded: (10...25).map(AnyHashable.init), newOrder: order), AnyHashable(10))
        let mapped = ViewportTransitionGeometry.mappedContentY(
            oldScreenY: 125, newEngineOffset: 500, viewportFrom: -300)
        XCTAssertEqual(mapped - (500 - 300), 125, accuracy: 1e-9)
    }

    func testDirectionSelectsBackwardTravel() {
        let order = (0..<30).map(AnyHashable.init)

        XCTAssertEqual(ViewportTransitionGeometry.direction(
            currentAnchor: AnyHashable(20), targetIndex: 10, newOrder: order), .backward)
    }

    func testDirectionFallsForwardWhenAnchorIsAbsent() {
        let order = (0..<30).map(AnyHashable.init)

        XCTAssertEqual(ViewportTransitionGeometry.direction(
            currentAnchor: AnyHashable(99), targetIndex: 10, newOrder: order), .forward)
    }

    func testOverlapReferenceIsNilForEmptyLoadedIntersection() {
        let order = (0..<30).map(AnyHashable.init)

        XCTAssertNil(ViewportTransitionGeometry.overlapReference(
            currentAnchor: AnyHashable(10), direction: .forward,
            oldLoaded: (0...5).map(AnyHashable.init),
            newLoaded: (10...15).map(AnyHashable.init), newOrder: order))
    }
}
