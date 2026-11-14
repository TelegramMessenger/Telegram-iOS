import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// The support account's sweep of one-to-one chats out of the list (`supportHiddenChatSweepBatch`): one that still
/// stores messages has its history dropped as for a chat never seen; listed, empty and kept chats are left alone.
final class SupportHiddenChatSweepTests: StateSyncTestCase {
    private func seedCustomerChat(_ id: Int64, incomingMessageId: Int32?, hidden: Bool) -> PeerId {
        let peerId = StateSyncFixture.userPeerId(id)
        self.fixture.seedPeers([StateSyncFixture.makeUser(id: peerId, accessHash: 1, firstName: "U\(id)")])
        self.fixture.seedChat(peerId: peerId)
        if let incomingMessageId {
            self.fixture.storeMessage(peerId: peerId, id: incomingMessageId, timestamp: self.baseDate - 10, authorId: peerId, text: "hello", incoming: true)
        }
        if hidden {
            let _ = self.fixture.transaction { $0.updatePeerChatListInclusion(peerId, inclusion: .notIncluded) }
        }
        return peerId
    }

    private func sweep(_ peerIds: [PeerId]) -> Int {
        return self.fixture.transaction { transaction -> Int in
            return supportHiddenChatSweepBatch(transaction: transaction, peerIds: ArraySlice(peerIds), accountPeerId: StateSyncFixture.accountPeerId)
        } ?? -1
    }

    private func isInitialized(_ peerId: PeerId) -> Bool {
        return self.fixture.transaction { $0.isMessageHistoryInitialized(peerId: peerId) } ?? false
    }

    func testHiddenChatWithMessagesIsCleared() {
        let hidden = self.seedCustomerChat(600, incomingMessageId: 10, hidden: true)
        XCTAssertEqual(self.sweep([hidden]), 1)
        XCTAssertNil(self.fixture.message(MessageId(peerId: hidden, namespace: Namespaces.Message.Cloud, id: 10)))
        XCTAssertFalse(self.isInitialized(hidden))
    }

    func testListedEmptyAndSavedMessagesChatsStay() {
        let listed = self.seedCustomerChat(601, incomingMessageId: 11, hidden: false)
        let empty = self.seedCustomerChat(602, incomingMessageId: nil, hidden: true)
        let account = StateSyncFixture.accountPeerId
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.fixture.storeMessage(peerId: account, id: 12, timestamp: self.baseDate - 5, authorId: account, text: "note", incoming: false)
        let _ = self.fixture.transaction { $0.updatePeerChatListInclusion(account, inclusion: .notIncluded) }

        XCTAssertEqual(self.sweep([listed, empty, account]), 0)
        XCTAssertNotNil(self.fixture.message(MessageId(peerId: listed, namespace: Namespaces.Message.Cloud, id: 11)))
        XCTAssertNotNil(self.fixture.message(MessageId(peerId: account, namespace: Namespaces.Message.Cloud, id: 12)))
        XCTAssertFalse(self.isInitialized(empty))
    }
}
