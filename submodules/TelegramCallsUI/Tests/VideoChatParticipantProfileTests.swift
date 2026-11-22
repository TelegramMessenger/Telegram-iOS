import Foundation
import XCTest
@testable import TelegramCallsUI

/// Pins when a call participant's "Open Profile" starts the profile with the avatar expanded:
/// whenever there is a photo to expand, except on a tablet, the rule the chat header follows.
final class VideoChatParticipantProfileTests: XCTestCase {
    func testAvatarStartsExpandedWhenThePeerHasAPhoto() {
        XCTAssertTrue(videoChatParticipantProfileAvatarInitiallyExpanded(hasProfilePhoto: true, isTablet: false))
    }

    func testAvatarStaysSmallWithoutAPhoto() {
        XCTAssertFalse(videoChatParticipantProfileAvatarInitiallyExpanded(hasProfilePhoto: false, isTablet: false))
    }

    func testAvatarStaysSmallOnATablet() {
        XCTAssertFalse(videoChatParticipantProfileAvatarInitiallyExpanded(hasProfilePhoto: true, isTablet: true))
        XCTAssertFalse(videoChatParticipantProfileAvatarInitiallyExpanded(hasProfilePhoto: false, isTablet: true))
    }
}
