import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// The support account's switch walks the chat list table from a row, without a view: start
/// excluded, in the list's order, chats only.
final class ChatListIndexEnumerationTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let pinnedChat = MessageHistoryTableFixture.peerId(900)
    private let newChat = MessageHistoryTableFixture.peerId(901)
    private let oldChat = MessageHistoryTableFixture.peerId(902)
    private let namespace = PostboxFixture.messageNamespace

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "ChatListIndexEnumerationTests")
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: self.pinnedChat, title: "Pinned"), FixturePeer(id: self.newChat, title: "New"), FixturePeer(id: self.oldChat, title: "Old")], update: { _, updated in updated })
            for peerId in [self.pinnedChat, self.newChat, self.oldChat] {
                transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
            }
            let _ = transaction.addMessages([
                self.message(peerId: self.pinnedChat, timestamp: 100),
                self.message(peerId: self.newChat, timestamp: 3000),
                self.message(peerId: self.oldChat, timestamp: 1000),
            ], location: .Random)
            transaction.setPinnedItemIds(groupId: .root, itemIds: [.peer(self.pinnedChat)])
            transaction.addChatListHole(groupId: .root, hole: ChatListHole(index: MessageIndex(id: MessageId(peerId: self.oldChat, namespace: self.namespace, id: 2000), timestamp: 2000)))
        }
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    private func message(peerId: PeerId, timestamp: Int32) -> StoreMessage {
        return MessageHistoryTableFixture.storeMessage(id: MessageId(peerId: peerId, namespace: self.namespace, id: timestamp), timestamp: timestamp, text: "m", flags: [.Incoming])
    }

    private func walk(from peerId: PeerId, downward: Bool) -> [PeerId] {
        var result: [PeerId] = []
        self.fixture.transaction { transaction in
            guard let (_, index) = transaction.getPeerChatListIndex(peerId) else {
                XCTFail("no row")
                return
            }
            transaction.enumerateChatListIndices(groupId: .root, after: index, downward: downward, { index in
                result.append(index.messageIndex.id.peerId)
                return true
            })
        }
        return result
    }

    func testDownwardGoesToOlderRowsAndSkipsHoles() {
        XCTAssertEqual(self.walk(from: self.pinnedChat, downward: true), [self.newChat, self.oldChat])
    }

    func testUpwardGoesToNewerRowsAndEndsAtPinned() {
        XCTAssertEqual(self.walk(from: self.oldChat, downward: false), [self.newChat, self.pinnedChat])
    }

    func testStoppingEndsTheWalk() {
        var visited = 0
        self.fixture.transaction { transaction in
            guard let (_, index) = transaction.getPeerChatListIndex(self.pinnedChat) else {
                XCTFail("no row")
                return
            }
            transaction.enumerateChatListIndices(groupId: .root, after: index, downward: true, { _ in
                visited += 1
                return false
            })
        }
        XCTAssertEqual(visited, 1)
    }

    func testFilterMatcherAppliesThePredicate() {
        let excluded = self.oldChat
        var included: [Bool] = []
        self.fixture.transaction { transaction in
            let predicate = ChatListFilterPredicate(includePeerIds: [], excludePeerIds: [excluded], pinnedPeerIds: [], messageTagSummary: nil, includeAdditionalPeerGroupIds: [], include: { _, _, _, _, _ in true })
            let matcher = transaction.chatListFilterMatcher(groupId: .root, predicate: predicate)
            for peerId in [self.newChat, self.oldChat] {
                if let (_, index) = transaction.getPeerChatListIndex(peerId) {
                    included.append(matcher(index))
                }
            }
        }
        XCTAssertEqual(included, [true, false])
    }
}
