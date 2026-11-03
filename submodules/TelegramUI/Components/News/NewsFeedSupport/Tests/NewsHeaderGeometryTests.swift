import XCTest
import CoreGraphics
@testable import NewsFeedSupport

/// The shared News header (Feed2 FeedScreen.swift:136, 203-272).
final class NewsHeaderGeometryTests: XCTestCase {
    // The reference device: 402 wide, status bar 54 (the row lands where the mockup's does: y 64).
    // The search node is 60 tall with its 44 pt field 8 pt from its top.
    private func referenceGeometry(islandFittingWidth: CGFloat = 200.0) -> NewsHeaderGeometry {
        return newsHeaderGeometry(width: 402.0, statusBarHeight: 54.0, islandFittingWidth: islandFittingWidth, moreButtonMinX: 342.0, searchNodeHeight: 60.0, searchFieldFrameInNode: CGRect(x: 16.0, y: 8.0, width: 370.0, height: 44.0))
    }

    func testHeaderMatchesTheMockupOnTheReferenceDevice() {
        let geometry = self.referenceGeometry()
        XCTAssertEqual(geometry.topRow, CGRect(x: 0.0, y: 64.0, width: 402.0, height: 44.0))
        XCTAssertEqual(geometry.island, CGRect(x: 87.0, y: 66.0, width: 228.0, height: 40.0))
        // The field's capsule spans y 122-166, as measured in the mockup.
        XCTAssertEqual(geometry.searchNodeAtRest.minY + 8.0, 122.0)
        XCTAssertEqual(geometry.blockHeight, 58.0)
        XCTAssertEqual(geometry.listTopInset, 166.0)
        XCTAssertEqual(geometry.edgeEffectHeight, 136.0)
    }

    func testIslandWidensForLongTitles() {
        XCTAssertEqual(self.referenceGeometry(islandFittingWidth: 250.0).island.width, 250.0)
        XCTAssertEqual(self.referenceGeometry(islandFittingWidth: 250.0).island.minX, 76.0)
    }

    // Centred, it may grow until it is 10 pt from the "…" button: 2 × (342 − 10) − 402 = 262.
    func testIslandNeverReachesTheMoreButton() {
        let island = self.referenceGeometry(islandFittingWidth: 400.0).island
        XCTAssertEqual(island.width, 262.0)
        XCTAssertLessThanOrEqual(island.maxX, 332.0)
    }

    func testBlockHeightFollowsTheMeasuredField() {
        let geometry = newsHeaderGeometry(width: 402.0, statusBarHeight: 54.0, islandFittingWidth: 200.0, moreButtonMinX: 342.0, searchNodeHeight: 60.0, searchFieldFrameInNode: CGRect(x: 16.0, y: 6.0, width: 370.0, height: 48.0))
        XCTAssertEqual(geometry.blockHeight, 62.0)
        XCTAssertEqual(geometry.searchNodeAtRest.minY + 6.0, 122.0)
    }

    // The search keeps travelling with the list until it is off the screen, so no edge of it shows under the
    // top row (the mockup's search is a list row and scrolls away); the 58 pt fold still drives the snap and pill.
    func testSearchTravelsUntilItIsOffScreen() {
        let geometry = self.referenceGeometry()
        XCTAssertEqual(geometry.searchTravelLimit, geometry.searchNodeAtRest.maxY)
        XCTAssertEqual(geometry.searchTravelLimit, 174.0)
        XCTAssertEqual(newsHeaderSearchTravel(listOffset: 100.0, geometry: geometry), 100.0)
        XCTAssertEqual(newsHeaderSearchTravel(listOffset: 900.0, geometry: geometry), 174.0)
        XCTAssertEqual(newsHeaderSearchTravel(listOffset: -20.0, geometry: geometry), -20.0)
    }

    func testBlockMovesWithTheListUntilItIsUnderTheRow() {
        XCTAssertEqual(newsHeaderBlockOffset(listOffset: 30.0, blockHeight: 58.0), 30.0)
        XCTAssertEqual(newsHeaderBlockOffset(listOffset: 200.0, blockHeight: 58.0), 58.0)
        // An overscroll pulls it down with the list.
        XCTAssertEqual(newsHeaderBlockOffset(listOffset: -20.0, blockHeight: 58.0), -20.0)
    }

    // The top row's band (row plus the header's 6 pt bottom padding) takes its own touches: the search block
    // scrolled under it must not activate through the empty space beside the island.
    func testTopBandCoversTheRowAndItsBottomPadding() {
        let geometry = self.referenceGeometry()
        XCTAssertTrue(newsHeaderTopBandContains(y: 20.0, geometry: geometry))
        XCTAssertTrue(newsHeaderTopBandContains(y: 113.9, geometry: geometry))
        XCTAssertFalse(newsHeaderTopBandContains(y: 114.0, geometry: geometry))
        XCTAssertFalse(newsHeaderTopBandContains(y: 140.0, geometry: geometry))
    }

    // The mockup's soft scroll edge is absent at rest (its search row is untouched there) and near full once
    // content has scrolled ~12 pt under the header (measured on K1).
    func testSoftEdgeAppearsOnlyOnceContentScrollsUnderTheHeader() {
        XCTAssertEqual(newsHeaderSoftEdgeAlpha(listOffset: 0.0, isSearchActive: false), 0.0)
        XCTAssertEqual(newsHeaderSoftEdgeAlpha(listOffset: -30.0, isSearchActive: false), 0.0)
        XCTAssertEqual(newsHeaderSoftEdgeAlpha(listOffset: 6.0, isSearchActive: false), 0.5, accuracy: 0.0001)
        XCTAssertEqual(newsHeaderSoftEdgeAlpha(listOffset: 12.0, isSearchActive: false), 1.0)
        XCTAssertEqual(newsHeaderSoftEdgeAlpha(listOffset: 400.0, isSearchActive: false), 1.0)
    }

    // Search results scroll under the active field, so the edge stays on (as ChatListNavigationBar's does).
    func testSoftEdgeIsOnWhileSearchIsActive() {
        XCTAssertEqual(newsHeaderSoftEdgeAlpha(listOffset: 0.0, isSearchActive: true), 1.0)
    }

    func testPartlyHiddenBlockSnapsToTheNearerEnd() {
        XCTAssertEqual(newsHeaderSnapTarget(blockOffset: 10.0, blockHeight: 58.0), 0.0)
        XCTAssertEqual(newsHeaderSnapTarget(blockOffset: 40.0, blockHeight: 58.0), 58.0)
        XCTAssertNil(newsHeaderSnapTarget(blockOffset: 0.0, blockHeight: 58.0))
        XCTAssertNil(newsHeaderSnapTarget(blockOffset: 58.0, blockHeight: 58.0))
        XCTAssertNil(newsHeaderSnapTarget(blockOffset: -5.0, blockHeight: 58.0))
    }
}
