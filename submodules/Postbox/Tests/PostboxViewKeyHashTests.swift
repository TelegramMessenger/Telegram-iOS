import Foundation
import XCTest
@testable import Postbox

/// A subscription that asks for many messages one key each (`EngineDataMap` of single-message items) puts every
/// `.messages` key into one `Set`/`Dictionary`. Keys for different messages must hash apart, or each insert and lookup
/// walks all the others.
final class PostboxViewKeyHashTests: XCTestCase {
    private func messageId(_ id: Int32) -> MessageId {
        return MessageId(peerId: MessageHistoryTableFixture.peerId(700), namespace: 0, id: id)
    }

    func testMessagesKeysForDifferentMessagesHashApart() {
        let keys = (1 ... 100).map { PostboxViewKey.messages(Set([self.messageId($0)])) }
        XCTAssertEqual(Set(keys.map(\.hashValue)).count, keys.count)
    }

    func testEqualMessagesKeysHashEqual() {
        var forward = Set<MessageId>()
        var backward = Set<MessageId>()
        for id in Int32(1) ... 50 {
            forward.insert(self.messageId(id))
            backward.insert(self.messageId(51 - id))
        }
        let lhs = PostboxViewKey.messages(forward)
        let rhs = PostboxViewKey.messages(backward)
        XCTAssertEqual(lhs, rhs)
        XCTAssertEqual(lhs.hashValue, rhs.hashValue)
    }
}
