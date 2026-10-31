import XCTest
import ChatMessageItemCommon

/// A history view with nothing to display, after the chat's own filtering, is still loading while it has a
/// hole: a cold forum topic's first view holds only the topic's root (which a topic does not display) and a
/// hole over the messages being fetched, and is not marked as loading. Read as an empty chat, it hid the
/// loading placeholder until the fetched messages arrived.
final class ChatHistoryAwaitsMessagesTests: XCTestCase {
    func testLoadingViewAwaitsMessages() {
        XCTAssertTrue(chatHistoryViewAwaitsMessages(isLoading: true, holeEarlier: false, holeLater: false))
    }

    func testColdTopicRootWithLaterHoleAwaitsMessages() {
        XCTAssertTrue(chatHistoryViewAwaitsMessages(isLoading: false, holeEarlier: false, holeLater: true))
    }

    func testEarlierHoleAwaitsMessages() {
        XCTAssertTrue(chatHistoryViewAwaitsMessages(isLoading: false, holeEarlier: true, holeLater: false))
    }

    func testLoadedViewWithoutHolesIsEmpty() {
        XCTAssertFalse(chatHistoryViewAwaitsMessages(isLoading: false, holeEarlier: false, holeLater: false))
    }
}
