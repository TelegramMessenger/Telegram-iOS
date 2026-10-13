import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramCore

/// The notification service extension records which message each delivered notification
/// stands for; the Siri intents extension reads it back to answer an announce-triggered
/// `INSearchForMessagesIntent` with that one message. Both sides go through the shared
/// account postbox, so this exercises the real store.
final class NotificationRequestMessageIdsTests: XCTestCase {
    private var store: TestPostbox!

    override func setUpWithError() throws {
        try super.setUpWithError()
        self.store = try TestPostbox(name: "notification-request-ids")
    }

    override func tearDownWithError() throws {
        self.store.close()
        self.store = nil
        try super.tearDownWithError()
    }

    private func transaction<T>(_ f: @escaping (Transaction) -> T) -> T? {
        return self.store.transaction(f)
    }

    private func messageId(peer: Int64, id: Int32) -> MessageId {
        return MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(peer)), namespace: Namespaces.Message.Cloud, id: id)
    }

    func testRecordedMessageIdIsReadBackForTheSameRequest() {
        let expected = self.messageId(peer: 1001, id: 42)
        self.transaction { transaction in
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "9C1D-REQUEST", messageId: expected)
        }
        let stored = self.transaction { transaction in
            return _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "9C1D-REQUEST")
        }
        XCTAssertEqual(stored, expected)
    }

    func testUnknownRequestHasNoMessage() {
        self.transaction { transaction in
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "known", messageId: self.messageId(peer: 1001, id: 1))
        }
        let stored = self.transaction { transaction in
            return _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "unknown")
        }
        XCTAssertNil(stored ?? nil)
    }

    /// Request identifiers are per-delivery UUIDs that never repeat, so without a bound the
    /// store would grow by one row per notification for the life of the account.
    func testKeepsOnlyTheMostRecentLinks() {
        let limit = _internal_notificationRequestMessageIdsLimit
        self.transaction { transaction in
            for index in 0 ..< (limit + 1) {
                _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req-\(index)", messageId: self.messageId(peer: 1001, id: Int32(index)))
            }
        }
        let stored = self.transaction { transaction -> [MessageId?] in
            return [
                _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req-0"),
                _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req-1"),
                _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req-\(limit)"),
            ]
        }
        XCTAssertEqual(stored, [nil, self.messageId(peer: 1001, id: 1), self.messageId(peer: 1001, id: Int32(limit))])
    }

    func testRewritingARequestReplacesItsMessage() {
        self.transaction { transaction in
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req", messageId: self.messageId(peer: 1001, id: 1))
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req", messageId: self.messageId(peer: 1001, id: 2))
        }
        let stored = self.transaction { transaction in
            return _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "req")
        }
        XCTAssertEqual(stored, self.messageId(peer: 1001, id: 2))
    }

    func testEachRequestKeepsItsOwnMessage() {
        let first = self.messageId(peer: 1001, id: 1)
        let second = self.messageId(peer: 2002, id: 7)
        self.transaction { transaction in
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "first", messageId: first)
            _internal_setNotificationRequestMessageId(transaction: transaction, requestIdentifier: "second", messageId: second)
        }
        let stored = self.transaction { transaction -> [MessageId?] in
            return [
                _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "first"),
                _internal_getNotificationRequestMessageId(transaction: transaction, requestIdentifier: "second"),
            ]
        }
        XCTAssertEqual(stored, [first, second])
    }
}
