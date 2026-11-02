import XCTest
import ChatMessageItemCommon

/// A history view with nothing to display, after the chat's own filtering, is still loading while it is marked so, and
/// a forum topic's view that holds only the topic's root (which a topic does not display) is also while it has a hole:
/// a cold topic's first view is that root and a hole over the messages being fetched, not marked as loading. Read as an
/// empty chat, it hid the loading placeholder until the fetched messages arrived. Any other view with a hole and nothing
/// to display shows its empty state, as before.
final class ChatHistoryAwaitsMessagesTests: XCTestCase {
    func testLoadingViewAwaitsMessages() {
        XCTAssertTrue(chatHistoryViewAwaitsMessages(isLoading: true, holeEarlier: false, holeLater: false, holdsOnlyForumTopicRoot: false))
        XCTAssertTrue(chatHistoryViewAwaitsMessages(isLoading: true, holeEarlier: false, holeLater: false, holdsOnlyForumTopicRoot: true))
    }

    func testColdTopicRootWithLaterHoleAwaitsMessages() {
        XCTAssertTrue(chatHistoryViewAwaitsMessages(isLoading: false, holeEarlier: false, holeLater: true, holdsOnlyForumTopicRoot: true))
    }

    func testColdTopicRootWithEarlierHoleAwaitsMessages() {
        XCTAssertTrue(chatHistoryViewAwaitsMessages(isLoading: false, holeEarlier: true, holeLater: false, holdsOnlyForumTopicRoot: true))
    }

    func testTopicRootWithoutHolesIsAnEmptyTopic() {
        XCTAssertFalse(chatHistoryViewAwaitsMessages(isLoading: false, holeEarlier: false, holeLater: false, holdsOnlyForumTopicRoot: true))
    }

    func testOtherViewWithAHoleIsEmpty() {
        XCTAssertFalse(chatHistoryViewAwaitsMessages(isLoading: false, holeEarlier: true, holeLater: false, holdsOnlyForumTopicRoot: false))
        XCTAssertFalse(chatHistoryViewAwaitsMessages(isLoading: false, holeEarlier: false, holeLater: true, holdsOnlyForumTopicRoot: false))
    }

    func testLoadedViewWithoutHolesIsEmpty() {
        XCTAssertFalse(chatHistoryViewAwaitsMessages(isLoading: false, holeEarlier: false, holeLater: false, holdsOnlyForumTopicRoot: false))
    }
}
