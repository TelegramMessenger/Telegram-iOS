import XCTest
@testable import PeerInfoPaneNode

final class PeerInfoExpansionPolicyTests: XCTestCase {
    // Only a profile opened from a chat, not Settings, not editing or searching, and scrolled at most 8 pt expands.
    func test_allowed() {
        XCTAssertTrue(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 0.0, isEditing: false, isSearching: false))
        XCTAssertTrue(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 8.0, isEditing: false, isSearching: false))
        XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 8.5, isEditing: false, isSearching: false))
        XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: false, isSettings: false, scrollOffset: 0.0, isEditing: false, isSearching: false))
        XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: true, scrollOffset: 0.0, isEditing: false, isSearching: false))
        XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 0.0, isEditing: true, isSearching: false))
        XCTAssertFalse(peerInfoExpansionAllowed(isOpenedFromChat: true, isSettings: false, scrollOffset: 0.0, isEditing: false, isSearching: true))
    }

    // The photo path when the profile is on its expanded photo (opened from the avatar, or closing from it).
    func test_path() {
        XCTAssertEqual(peerInfoExpansionPath(isAvatarExpanded: true), .photo)
        XCTAssertEqual(peerInfoExpansionPath(isAvatarExpanded: false), .origin)
    }
}
