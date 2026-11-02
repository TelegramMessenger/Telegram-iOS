import XCTest
import Display
@testable import ChatListUI

// The chat list header (search field, stories row) shows the current folder list's scroll state and stops collapsing at
// the search field's height (54). A folder list that is not current is moved to match the current one's navigation state
// during a folder swipe; it must land where the header is, never with its first chat under the collapsed header.
final class ChatListNavigationOffsetTests: XCTestCase {
    func testListAtTheCollapsedHeaderOffsetHasItsNavigationHidden() {
        XCTAssertTrue(ChatListNavigationOffset.isNavigationHidden(.known(54.0)))
    }

    func testListWithTheStoriesRowExpandedShowsItsNavigation() {
        XCTAssertFalse(ChatListNavigationOffset.isNavigationHidden(.known(-96.0)))
    }

    func testListAtItsTopShowsItsNavigation() {
        XCTAssertFalse(ChatListNavigationOffset.isNavigationHidden(.known(0.0)))
    }

    func testListScrolledUnderTheCollapsedHeaderHasItsNavigationHidden() {
        XCTAssertTrue(ChatListNavigationOffset.isNavigationHidden(.known(100.0)))
    }

    func testListJustShortOfTheCollapsedHeaderOffsetShowsItsNavigation() {
        XCTAssertFalse(ChatListNavigationOffset.isNavigationHidden(.known(52.9)))
        XCTAssertTrue(ChatListNavigationOffset.isNavigationHidden(.known(53.0)))
    }

    func testListWithoutRowsShowsItsNavigation() {
        XCTAssertFalse(ChatListNavigationOffset.isNavigationHidden(.none))
    }

    func testListScrolledPastItsFirstRowHasItsNavigationHidden() {
        XCTAssertTrue(ChatListNavigationOffset.isNavigationHidden(.unknown))
    }

    func testListAtItsTopMovesToTheCollapsedHeaderOffsetWhenTheCurrentListHidesNavigation() {
        XCTAssertEqual(ChatListNavigationOffset.offsetMatching(isNavigationHidden: true, from: .known(0.0)), 54.0)
    }

    func testListAtTheCollapsedHeaderOffsetStaysWhenTheCurrentListHidesNavigation() {
        XCTAssertNil(ChatListNavigationOffset.offsetMatching(isNavigationHidden: true, from: .known(54.0)))
    }

    func testListScrolledPastItsFirstRowReturnsToItsTopWhenTheCurrentListShowsNavigation() {
        XCTAssertEqual(ChatListNavigationOffset.offsetMatching(isNavigationHidden: false, from: .unknown), 0.0)
    }

    func testListScrolledUnderTheCollapsedHeaderReturnsToItsTopWhenTheCurrentListShowsNavigation() {
        XCTAssertEqual(ChatListNavigationOffset.offsetMatching(isNavigationHidden: false, from: .known(100.0)), 0.0)
    }

    func testListWithoutRowsStays() {
        XCTAssertNil(ChatListNavigationOffset.offsetMatching(isNavigationHidden: true, from: .none))
        XCTAssertNil(ChatListNavigationOffset.offsetMatching(isNavigationHidden: false, from: .none))
    }

    func testListWithTheStoriesRowExpandedStaysWhenTheCurrentListShowsNavigation() {
        XCTAssertNil(ChatListNavigationOffset.offsetMatching(isNavigationHidden: false, from: .known(-96.0)))
    }
}
