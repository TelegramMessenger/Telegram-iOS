import XCTest
import CoreGraphics

/// The chat list header's collapsed content on a 358 pt row, the story list's band running from 70 to 288.
final class StoryPeerListTitleLayoutTests: XCTestCase {
    private let width: CGFloat = 358.0
    private let minX: CGFloat = 70.0
    private let maxX: CGFloat = 288.0

    func test_contentOrigin_centred_orKeptLeftOfMaxX() {
        XCTAssertEqual(StoryPeerListTitleLayout.contentOrigin(containerWidth: self.width, contentWidth: 100.0, maxX: self.maxX), 129.0)
        XCTAssertEqual(StoryPeerListTitleLayout.contentOrigin(containerWidth: self.width, contentWidth: 210.0, maxX: self.maxX), 74.0)
    }

    // With room, the title's text shows; content kept 4 pt inside the band on the left as on the right.
    func test_text_showsWithRoom() {
        XCTAssertTrue(StoryPeerListTitleLayout.showsTitleText(containerWidth: self.width, contentWidth: 150.0, minX: self.minX, maxX: self.maxX))
        XCTAssertTrue(StoryPeerListTitleLayout.showsTitleText(containerWidth: self.width, contentWidth: 210.0, minX: self.minX, maxX: self.maxX))
    }

    // Content that would start closer than that to the left side (under the Edit button) goes without the title's text.
    func test_text_goesWhenTheContentWouldCrossTheLeftSide() {
        XCTAssertFalse(StoryPeerListTitleLayout.showsTitleText(containerWidth: self.width, contentWidth: 211.0, minX: self.minX, maxX: self.maxX))
        XCTAssertFalse(StoryPeerListTitleLayout.showsTitleText(containerWidth: self.width, contentWidth: 260.0, minX: self.minX, maxX: self.maxX))
    }
}
