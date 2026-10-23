import XCTest
@testable import PeerInfoPaneNode

final class PeerInfoExpansionPolicyTests: XCTestCase {
    private let visibleTitleSize = CGSize(width: 120.0, height: 28.0)

    // Only a profile opened from a chat, not Settings, not editing or searching, and scrolled at most 8 pt expands.
    func test_allowed() {
        XCTAssertTrue(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 0.0, isEditing: false, isSearching: false, titleSize: self.visibleTitleSize))
        XCTAssertTrue(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 8.0, isEditing: false, isSearching: false, titleSize: self.visibleTitleSize))
        XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 8.5, isEditing: false, isSearching: false, titleSize: self.visibleTitleSize))
        XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: false, isSettings: false, scrollOffset: 0.0, isEditing: false, isSearching: false, titleSize: self.visibleTitleSize))
        XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: true, scrollOffset: 0.0, isEditing: false, isSearching: false, titleSize: self.visibleTitleSize))
        XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 0.0, isEditing: true, isSearching: false, titleSize: self.visibleTitleSize))
        XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 0.0, isEditing: false, isSearching: true, titleSize: self.visibleTitleSize))
    }

    func test_emptyTitleLayoutUsesSlide() {
        for size in [CGSize.zero, CGSize(width: 0.0, height: 28.0), CGSize(width: 120.0, height: 0.0)] {
            XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 0.0, isEditing: false, isSearching: false, titleSize: size), "An empty title layout must use the slide transition: \(size)")
        }
    }

    func test_nonemptyTitleLayoutStillExpands() {
        for width: CGFloat in [0.5, 120.0, 400.0] {
            XCTAssertTrue(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 0.0, isEditing: false, isSearching: false, titleSize: CGSize(width: width, height: 28.0)))
        }
    }

    // The photo path when the profile is on its expanded photo (opened from the avatar, or closing from it).
    func test_path() {
        XCTAssertEqual(peerInfoExpansionPath(isAvatarExpanded: true), .photo)
        XCTAssertEqual(peerInfoExpansionPath(isAvatarExpanded: false), .origin)
    }
}
