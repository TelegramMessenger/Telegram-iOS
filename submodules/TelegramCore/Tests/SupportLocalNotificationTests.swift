import XCTest
import Postbox
@testable import TelegramCore

final class SupportLocalNotificationTests: XCTestCase {
    func testMessagesAreLocalIncomingAndUntagged() {
        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(777000))
        let messages = supportLocalNotificationMessages(texts: ["one", "two"], timestamp: 100, peerId: peerId)
        XCTAssertEqual(messages.map(\.text), ["one", "two"])
        XCTAssertNotEqual(messages[0].globallyUniqueId, messages[1].globallyUniqueId)
        for message in messages {
            guard case let .Partial(id, namespace) = message.id else {
                XCTFail("expected a new id")
                continue
            }
            XCTAssertEqual(id, peerId)
            XCTAssertEqual(namespace, Namespaces.Message.Local)
            XCTAssertEqual(message.timestamp, 100)
            XCTAssertTrue(message.flags.contains(.Incoming))
            XCTAssertFalse(message.flags.contains(.Unsent))
            XCTAssertEqual(message.authorId, peerId)
            XCTAssertTrue(message.tags.isEmpty)
        }
    }
}
