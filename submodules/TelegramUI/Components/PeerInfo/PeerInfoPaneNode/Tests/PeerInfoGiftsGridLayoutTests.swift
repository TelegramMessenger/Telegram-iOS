import XCTest
import UIKit
import PeerInfoPaneNode

final class PeerInfoGiftsGridLayoutTests: XCTestCase {
    // GiftsListView's metrics: cells 10pt apart, 16pt in from the pane's side inset.
    private func itemsInRow(_ width: CGFloat, _ height: CGFloat, sideInset: CGFloat = 0.0, isTablet: Bool = false) -> Int {
        return peerInfoGiftsItemsInRow(size: CGSize(width: width, height: height), itemsSideInset: sideInset + 16.0, spacing: 10.0, isTablet: isTablet)
    }

    func test_duoUnfoldedLandscapeBesideChatList_fourColumns() {
        // The detail pane is 631pt wide, less the 84pt strip: five 95pt cells would put the sticker over the avatar.
        XCTAssertEqual(self.itemsInRow(547.0, 669.0), 4)
    }

    func test_duoFoldedLandscape_fourColumns() {
        // 678pt less the 84pt strip: five cells would be 104pt.
        XCTAssertEqual(self.itemsInRow(594.0, 466.0), 4)
    }

    func test_duoUnfoldedPortrait_fiveColumns() {
        XCTAssertEqual(self.itemsInRow(669.0, 951.0), 5)
    }

    func test_duoUnfoldedLandscapeFullWidth_fiveColumns() {
        XCTAssertEqual(self.itemsInRow(867.0, 669.0), 5)
    }

    func test_duoFoldedPortrait_threeColumns() {
        XCTAssertEqual(self.itemsInRow(382.0, 678.0), 3)
    }

    func test_iPhonePortrait_threeColumns() {
        XCTAssertEqual(self.itemsInRow(402.0, 874.0), 3)
        XCTAssertEqual(self.itemsInRow(375.0, 667.0), 3)
    }

    func test_iPhoneLandscape_fiveColumns() {
        XCTAssertEqual(self.itemsInRow(874.0, 402.0, sideInset: 62.0), 5)
        // The narrowest landscape that keeps five: iPhone SE (2nd/3rd gen), 119pt cells.
        XCTAssertEqual(self.itemsInRow(667.0, 375.0), 5)
    }

    func test_320ptPhone() {
        XCTAssertEqual(self.itemsInRow(320.0, 568.0), 3)
        // Landscape: five cells would be 99pt.
        XCTAssertEqual(self.itemsInRow(568.0, 320.0), 4)
    }

    func test_neverBelowThreeColumns() {
        XCTAssertEqual(self.itemsInRow(420.0, 300.0), 3)
    }

    func test_iPad_unchanged() {
        XCTAssertEqual(self.itemsInRow(820.0, 1180.0, isTablet: true), 4)
        XCTAssertEqual(self.itemsInRow(1180.0, 820.0, isTablet: true), 4)
        // Half of a 1024pt split: 4 cells of 111pt; a narrow Stage Manager window keeps 4 as well.
        XCTAssertEqual(self.itemsInRow(507.0, 768.0, isTablet: true), 4)
        XCTAssertEqual(self.itemsInRow(490.0, 700.0, isTablet: true), 4)
        XCTAssertEqual(self.itemsInRow(375.0, 768.0, isTablet: true), 3)
    }
}
