import XCTest
import UIKit
@testable import CoreListDemo

/// The overlay a carousel's departed strip is parked in. It is a sibling of the scrolling content
/// host, not a child of it, which is the entire reason a drag cannot reach its children — and it is
/// ordered BELOW the content host, matching `ListViewImpl`'s
/// `insertSubnode(itemNode, belowSubnode: lowestNodeToInsertBelow)`.
final class CarouselExitOverlayTests: XCTestCase {
    private func makeFixture() -> VirtualListFixture {
        // `IdentifiableFixedHeightItem` keys on a UUID, so the convenience initialiser is the one
        // that takes a plain count.
        VirtualListFixture(itemCount: 200,
                           itemHeight: 50,
                           viewport: CGSize(width: 390, height: 300),
                           preloadMargin: 100,
                           emitsCA: true)
    }

    func testOverlayIsASiblingOfTheContentHostAndOrderedBelowIt() throws {
        let fixture = makeFixture()
        let listView = fixture.listView
        let overlay = listView.carouselExitOverlay

        XCTAssertTrue(overlay.superview === listView)
        let subviews = listView.subviews
        let overlayIndex = try XCTUnwrap(subviews.firstIndex(of: overlay))
        let hostIndex = try XCTUnwrap(subviews.firstIndex(of: listView.engine.contentHost))
        XCTAssertLessThan(overlayIndex, hostIndex)
        XCTAssertFalse(overlay.isUserInteractionEnabled)
    }

    func testOverlayCarriesTheViewportTrack() throws {
        let fixture = makeFixture()
        fixture.listView.applyChanges(scrollTo: .init(index: 120, pointOffset: 0),
                                      transition: .easeInOut(duration: 1))

        let key = fixture.animationController.compiler.animationKey(for: .viewportOffset)
        XCTAssertNotNil(fixture.listView.carouselExitOverlay.layer.animation(forKey: key))
        XCTAssertNotNil(fixture.listView.engine.contentHost.layer.animation(forKey: key))
    }

    func testOverlayTracksTheListBounds() {
        let fixture = makeFixture()
        fixture.resize(height: 500)
        XCTAssertEqual(fixture.listView.carouselExitOverlay.bounds.size,
                       fixture.listView.engine.contentHost.bounds.size)
    }
}
