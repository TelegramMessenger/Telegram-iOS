import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

final class ChatListHeldOrderTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let newChat = MessageHistoryTableFixture.peerId(900)
    private let middleChat = MessageHistoryTableFixture.peerId(901)
    private let oldChat = MessageHistoryTableFixture.peerId(902)
    private let namespace = PostboxFixture.messageNamespace
    private let archive = PeerGroupId(rawValue: 1)

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "ChatListHeldOrderTests")
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: self.newChat, title: "New"), FixturePeer(id: self.middleChat, title: "Middle"), FixturePeer(id: self.oldChat, title: "Old")], update: { _, updated in updated })
            for peerId in [self.newChat, self.middleChat, self.oldChat] {
                transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
            }
            let _ = transaction.addMessages([
                self.message(peerId: self.newChat, timestamp: 3000),
                self.message(peerId: self.middleChat, timestamp: 2000),
                self.message(peerId: self.oldChat, timestamp: 1000),
            ], location: .Random)
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

    private func messageIndex(peerId: PeerId, timestamp: Int32) -> MessageIndex {
        return MessageIndex(id: MessageId(peerId: peerId, namespace: self.namespace, id: timestamp), timestamp: timestamp)
    }

    private func setHolding(_ value: Bool) {
        self.fixture.transaction { transaction in
            transaction.setHoldsChatListOrder(value)
        }
    }

    private func receive(peerId: PeerId, timestamp: Int32) {
        self.fixture.transaction { transaction in
            let _ = transaction.addMessages([self.message(peerId: peerId, timestamp: timestamp)], location: .Random)
        }
    }

    private func rows(groupId: PeerGroupId = .root) -> [PeerId] {
        var result: [PeerId] = []
        self.fixture.transaction { transaction in
            transaction.enumerateChatListIndices(groupId: groupId, after: ChatListIndex.absoluteUpperBound, downward: true, { index in
                result.append(index.messageIndex.id.peerId)
                return true
            })
        }
        return result
    }

    private func rowTimestamp(_ peerId: PeerId) -> Int32? {
        var result: Int32?
        self.fixture.transaction { transaction in
            result = transaction.getPeerChatListIndex(peerId)?.1.messageIndex.timestamp
        }
        return result
    }

    private func resort() -> Int {
        var result = 0
        self.fixture.transaction { transaction in
            result = transaction.resortHeldChatListRows(groupIds: [.root, self.archive])
        }
        return result
    }

    func testKeepsPositionOnlyForAChangeAboveTheHole() {
        let current = self.messageIndex(peerId: self.oldChat, timestamp: 1000)
        let updated = self.messageIndex(peerId: self.oldChat, timestamp: 4000)
        let hole = self.messageIndex(peerId: self.middleChat, timestamp: 500)
        XCTAssertTrue(chatListRowKeepsPosition(current: current, updated: updated, topHole: nil))
        XCTAssertTrue(chatListRowKeepsPosition(current: current, updated: updated, topHole: hole))
        XCTAssertFalse(chatListRowKeepsPosition(current: current, updated: updated, topHole: self.messageIndex(peerId: self.middleChat, timestamp: 1500)))
        XCTAssertFalse(chatListRowKeepsPosition(current: current, updated: updated, topHole: current))
        XCTAssertFalse(chatListRowKeepsPosition(current: current, updated: current, topHole: nil))
        XCTAssertFalse(chatListRowKeepsPosition(current: current, updated: nil, topHole: nil))
    }

    func testWithoutHoldingANewMessageMovesTheRow() {
        self.receive(peerId: self.oldChat, timestamp: 4000)
        XCTAssertEqual(self.rows(), [self.oldChat, self.newChat, self.middleChat])
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 4000)
    }

    func testWhileHoldingANewMessageKeepsTheRow() {
        self.setHolding(true)
        self.receive(peerId: self.oldChat, timestamp: 4000)
        XCTAssertEqual(self.rows(), [self.newChat, self.middleChat, self.oldChat])
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 1000)
    }

    func testResortPutsHeldRowsInDateOrderAndKeepsHolding() {
        self.setHolding(true)
        self.receive(peerId: self.oldChat, timestamp: 4000)
        XCTAssertEqual(self.resort(), 1)
        XCTAssertEqual(self.rows(), [self.oldChat, self.newChat, self.middleChat])
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 4000)
        self.receive(peerId: self.middleChat, timestamp: 5000)
        XCTAssertEqual(self.rows(), [self.oldChat, self.newChat, self.middleChat])
    }

    func testResortFindsNothingInAnOrderedList() {
        XCTAssertEqual(self.resort(), 0)
    }

    func testResortLeavesARowPlacedByItsMinTimestamp() {
        self.fixture.transaction { transaction in
            transaction.updatePeerChatListInclusion(self.oldChat, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: 2500))
        }
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 2500)
        XCTAssertEqual(self.resort(), 0)
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 2500)
    }

    func testPinningAndUnpinningAHeldRowResortsIt() {
        self.setHolding(true)
        self.receive(peerId: self.oldChat, timestamp: 4000)
        self.fixture.transaction { transaction in
            transaction.setPinnedItemIds(groupId: .root, itemIds: [.peer(self.middleChat)])
        }
        XCTAssertEqual(self.rows(), [self.middleChat, self.newChat, self.oldChat])
        self.fixture.transaction { transaction in
            transaction.setPinnedItemIds(groupId: .root, itemIds: [.peer(self.oldChat)])
        }
        XCTAssertEqual(self.rows(), [self.oldChat, self.newChat, self.middleChat])
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 4000)
        self.fixture.transaction { transaction in
            transaction.setPinnedItemIds(groupId: .root, itemIds: [])
        }
        XCTAssertEqual(self.rows(), [self.oldChat, self.newChat, self.middleChat])
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 4000)
    }

    func testAPinnedRowKeepsItsDate() {
        self.fixture.transaction { transaction in
            transaction.setPinnedItemIds(groupId: .root, itemIds: [.peer(self.oldChat)])
        }
        self.setHolding(true)
        self.receive(peerId: self.oldChat, timestamp: 4000)
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 1000)
        XCTAssertEqual(self.rows(), [self.oldChat, self.newChat, self.middleChat])
    }

    func testArchivingAHeldRowResortsIt() {
        self.setHolding(true)
        self.receive(peerId: self.oldChat, timestamp: 4000)
        self.fixture.transaction { transaction in
            transaction.updatePeerChatListInclusion(self.oldChat, inclusion: .ifHasMessagesOrOneOf(groupId: self.archive, pinningIndex: nil, minTimestamp: nil))
        }
        XCTAssertEqual(self.rows(), [self.newChat, self.middleChat])
        XCTAssertEqual(self.rows(groupId: self.archive), [self.oldChat])
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 4000)
    }

    func testARowBelowTheTopHoleRisesOnceAndThenHolds() {
        self.fixture.transaction { transaction in
            transaction.addChatListHole(groupId: .root, hole: ChatListHole(index: self.messageIndex(peerId: self.middleChat, timestamp: 1500)))
        }
        self.setHolding(true)
        self.receive(peerId: self.oldChat, timestamp: 4000)
        XCTAssertEqual(self.rows(), [self.oldChat, self.newChat, self.middleChat])
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 4000)
        self.receive(peerId: self.middleChat, timestamp: 5000)
        XCTAssertEqual(self.rows(), [self.oldChat, self.newChat, self.middleChat])
        XCTAssertEqual(self.rowTimestamp(self.middleChat), 2000)
    }

    func testAHoleChangeIsSeenWhileHolding() {
        self.setHolding(true)
        self.receive(peerId: self.newChat, timestamp: 4000)
        XCTAssertEqual(self.rowTimestamp(self.newChat), 3000)
        let hole = self.messageIndex(peerId: self.middleChat, timestamp: 1500)
        self.fixture.transaction { transaction in
            transaction.addChatListHole(groupId: .root, hole: ChatListHole(index: hole))
        }
        self.receive(peerId: self.oldChat, timestamp: 5000)
        XCTAssertEqual(self.rowTimestamp(self.oldChat), 5000)
        self.fixture.transaction { transaction in
            transaction.replaceChatListHole(groupId: .root, index: hole, hole: nil)
        }
        self.receive(peerId: self.middleChat, timestamp: 6000)
        XCTAssertEqual(self.rowTimestamp(self.middleChat), 2000)
    }

    func testDeletingAHeldRowsNewestMessageKeepsTheRow() {
        self.setHolding(true)
        self.receive(peerId: self.oldChat, timestamp: 4000)
        self.fixture.transaction { transaction in
            transaction.deleteMessages([MessageId(peerId: self.oldChat, namespace: self.namespace, id: 4000)], forEachMedia: nil)
        }
        XCTAssertEqual(self.rows(), [self.newChat, self.middleChat, self.oldChat])
        XCTAssertEqual(self.resort(), 0)
    }

    func testDeletingEveryMessageRemovesAHeldRow() {
        self.setHolding(true)
        self.receive(peerId: self.oldChat, timestamp: 4000)
        self.fixture.transaction { transaction in
            transaction.deleteMessages([MessageId(peerId: self.oldChat, namespace: self.namespace, id: 1000), MessageId(peerId: self.oldChat, namespace: self.namespace, id: 4000)], forEachMedia: nil)
        }
        XCTAssertEqual(self.rows(), [self.newChat, self.middleChat])
    }

    func testResortingOneRowMovesOnlyThatRow() {
        self.setHolding(true)
        self.receive(peerId: self.oldChat, timestamp: 4000)
        self.receive(peerId: self.middleChat, timestamp: 5000)
        self.fixture.transaction { transaction in
            transaction.resortChatListRow(peerId: self.oldChat)
        }
        XCTAssertEqual(self.rows(), [self.oldChat, self.newChat, self.middleChat])
        XCTAssertEqual(self.rowTimestamp(self.middleChat), 2000)
    }
}
