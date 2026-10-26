import XCTest
import UIKit
@testable import CoreListDemo

/// Guards `OverlayOrphanTests` against being vacuous. Those tests assert that no unowned view is
/// left in an overlay; that assertion is meaningless if the sequences never park a view in one.
/// This records the peak overlay occupancy of each sequence so a passing suite can be trusted.
final class OverlayOrphanProbeTests: XCTestCase {
    private func peakOverlayOccupancy(_ body: (VirtualListFixture) -> Void) -> Int {
        let fixture = VirtualListFixture(itemCount: 200, itemHeight: 50,
                                         viewport: CGSize(width: 390, height: 400))
        var peak = 0
        let sample = {
            peak = max(peak, fixture.listView.exitOverlay.subviews.count
                       + fixture.listView.carouselExitOverlay.subviews.count
                       + fixture.listView.crossingOverlay.subviews.count)
        }
        sample()
        body(fixture)
        sample()
        for _ in 0..<20 { fixture.advance(by: 0.02); sample() }
        return peak
    }

    func testOverlappingScrollToActuallyParksViews() {
        let peak = peakOverlayOccupancy { fixture in
            fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                          transition: .easeInOut(duration: 0.3))
            fixture.advance(by: 0.1)
            fixture.listView.applyChanges(scrollTo: .init(index: 40, pointOffset: 0),
                                          transition: .easeInOut(duration: 0.3))
        }
        XCTAssertGreaterThan(peak, 0,
            "overlapping scrollTo never parked a view — OverlayOrphanTests' equivalent case is "
            + "vacuous and eliminates nothing")
    }

    func testEmptyingListActuallyParksViews() {
        let peak = peakOverlayOccupancy { fixture in
            fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                          transition: .easeInOut(duration: 0.3))
            fixture.advance(by: 0.1)
            fixture.listView.applyChanges(items: [], transition: .easeInOut(duration: 0.3))
        }
        XCTAssertGreaterThan(peak, 0,
            "emptying mid-transition never parked a view — that case is vacuous")
    }

    func testSizeChangeDuringScrollToActuallyParksViews() {
        let peak = peakOverlayOccupancy { fixture in
            fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                          transition: .easeInOut(duration: 0.3))
            fixture.advance(by: 0.1)
            fixture.listView.applyChanges(newSize: CGSize(width: 390, height: 300),
                                          transition: .easeInOut(duration: 0.3))
        }
        XCTAssertGreaterThan(peak, 0,
            "size change during scrollTo never parked a view — that case is vacuous")
    }
}
