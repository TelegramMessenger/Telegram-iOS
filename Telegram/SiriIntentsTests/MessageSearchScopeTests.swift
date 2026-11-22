import Foundation
import XCTest
import Intents
import Postbox
import TelegramCore
@testable import IntentsExtensionLib

/// How the Siri intents extension turns an `INSearchForMessagesIntent` into a query.
///
/// Siri's "Announce Notifications" flow (AirPods, CarPlay) sends a search that names the
/// delivered notification in `notificationIdentifiers`. Answering that with every unread
/// message is what made Siri re-read the whole backlog on each new message
/// (bugs.telegram.org/c/6940).
final class MessageSearchScopeTests: XCTestCase {
    private func messageId(_ id: Int32) -> MessageId {
        return MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1001)), namespace: Namespaces.Message.Cloud, id: id)
    }

    func testNotificationIdentifiersRestrictTheSearchToThoseNotifications() {
        let scope = messageSearchScope(
            notificationIdentifiers: ["req-1", "req-2"],
            notificationIdentifiersOperator: .any,
            identifiers: nil
        )
        XCTAssertEqual(scope, .notifications(["req-1", "req-2"]))
    }

    func testAllOperatorAlsoRestrictsToTheNamedNotifications() {
        let scope = messageSearchScope(
            notificationIdentifiers: ["req-1"],
            notificationIdentifiersOperator: .all,
            identifiers: nil
        )
        XCTAssertEqual(scope, .notifications(["req-1"]))
    }

    func testNoneOperatorReadsUnreadExceptTheNamedNotifications() {
        let scope = messageSearchScope(
            notificationIdentifiers: ["req-1"],
            notificationIdentifiersOperator: .none,
            identifiers: nil
        )
        XCTAssertEqual(scope, .unread(excludingNotifications: ["req-1"]))
    }

    /// Message identifiers name the exact messages Siri wants; they need no lookup and
    /// survive the notification link being missing, so they win when both are present.
    func testMessageIdentifiersWinOverNotificationIdentifiers() {
        let scope = messageSearchScope(
            notificationIdentifiers: ["req-1"],
            notificationIdentifiersOperator: .any,
            identifiers: ["\(self.messageId(5).peerId.toInt64())_0_5"]
        )
        XCTAssertEqual(scope, .messages([self.messageId(5)]))
    }

    func testUnparsableMessageIdentifiersFallBackToTheNotifications() {
        let scope = messageSearchScope(
            notificationIdentifiers: ["req-1"],
            notificationIdentifiersOperator: .any,
            identifiers: ["garbage"]
        )
        XCTAssertEqual(scope, .notifications(["req-1"]))
    }

    func testMessageIdentifiersSelectThoseMessages() {
        let scope = messageSearchScope(
            notificationIdentifiers: nil,
            notificationIdentifiersOperator: .any,
            identifiers: ["\(self.messageId(5).peerId.toInt64())_0_5", "not-a-message-id"]
        )
        XCTAssertEqual(scope, .messages([self.messageId(5)]))
    }

    /// Explicit identifiers that name nothing this build knows must not widen into the backlog.
    func testUnparsableMessageIdentifiersAloneSelectNothing() {
        let scope = messageSearchScope(
            notificationIdentifiers: nil,
            notificationIdentifiersOperator: .any,
            identifiers: ["garbage"]
        )
        XCTAssertEqual(scope, .messages([]))
    }

    func testEmptyIntentReadsAllUnread() {
        let scope = messageSearchScope(
            notificationIdentifiers: [],
            notificationIdentifiersOperator: .any,
            identifiers: []
        )
        XCTAssertEqual(scope, .unread(excludingNotifications: []))
    }

    func testScopeIsReadOffTheIntent() {
        let intent = INSearchForMessagesIntent(
            recipients: nil,
            senders: nil,
            searchTerms: nil,
            attributes: .unread,
            dateTime: nil,
            identifiers: nil,
            notificationIdentifiers: ["req-9"],
            speakableGroupNames: nil,
            conversationIdentifiers: nil
        )
        XCTAssertEqual(messageSearchScope(for: intent), .notifications(["req-9"]))
    }
}
