import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A support account removes old chats locally and has the server give them back. The chat leaves the
/// list and returns to the state of a peer never seen: no history, holes recreated on first use, no
/// cached data. A chat list fetch below a hole then brings it back with its older messages reachable.
/// `clearHistory` alone removes the history holes and keeps the flag that says they exist, because it
/// means the server's history is gone too, so a returned chat would end at its latest message.
final class ChatListRemoveHistoryAsUnseenPeerTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let newerChat = MessageHistoryTableFixture.peerId(900)
    private let holeChat = MessageHistoryTableFixture.peerId(901)
    private let removedChat = MessageHistoryTableFixture.peerId(902)
    private let namespace = PostboxFixture.messageNamespace
    private let fullRange: ClosedRange<MessageId.Id> = 1 ... (Int32.max - 1)

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "ChatListRemoveHistoryAsUnseenPeerTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    private func message(peerId: PeerId, id: Int32, timestamp: Int32) -> StoreMessage {
        return MessageHistoryTableFixture.storeMessage(id: MessageId(peerId: peerId, namespace: self.namespace, id: id), timestamp: timestamp, text: "m\(id)", flags: [.Incoming])
    }

    private func seedThreeChats() {
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: self.newerChat, title: "Newer"), FixturePeer(id: self.holeChat, title: "Hole"), FixturePeer(id: self.removedChat, title: "Removed")], update: { _, updated in updated })
            for peerId in [self.newerChat, self.holeChat, self.removedChat] {
                transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
            }
            let _ = transaction.addMessages([
                self.message(peerId: self.newerChat, id: 300, timestamp: 3000),
                self.message(peerId: self.holeChat, id: 200, timestamp: 2000),
                self.message(peerId: self.removedChat, id: 100, timestamp: 1000),
            ], location: .Random)
        }
    }

    func testRemovedChatLeavesTheListWithAFullHoleAndNoCachedData() {
        self.seedThreeChats()
        self.fixture.transaction { transaction in
            transaction.updatePeerCachedData(peerIds: Set([self.removedChat]), update: { _, _ in
                return FixtureCachedPeerData(peerIds: [])
            })
        }
        XCTAssertEqual(self.fixture.transaction { $0.getPeerCachedData(peerId: self.removedChat) != nil }, true)
        self.fixture.transaction { transaction in
            transaction.removeHistoryAsUnseenPeer(self.removedChat, namespace: self.namespace)
        }
        let result = self.fixture.transaction { transaction -> (inList: Bool, top: MessageIndex?, holes: IndexSet, hasCachedData: Bool) in
            return (transaction.getPeerChatListIndex(self.removedChat) != nil, transaction.getTopPeerMessageIndex(peerId: self.removedChat, namespace: self.namespace), transaction.getHoles(peerId: self.removedChat, namespace: self.namespace), transaction.getPeerCachedData(peerId: self.removedChat) != nil)
        }
        XCTAssertEqual(result?.inList, false)
        XCTAssertNil(result?.top ?? nil)
        XCTAssertEqual(result?.holes, IndexSet(integersIn: Int(self.fullRange.lowerBound) ... Int(self.fullRange.upperBound)))
        XCTAssertEqual(result?.hasCachedData, false)
    }

    func testAChatWithNoHolesLeftGetsTheFullHoleBack() {
        self.seedThreeChats()
        let filled = self.fixture.transaction { transaction -> IndexSet in
            transaction.removeHole(peerId: self.removedChat, threadId: nil, namespace: self.namespace, space: .everywhere, range: self.fullRange)
            return transaction.getHoles(peerId: self.removedChat, namespace: self.namespace)
        }
        XCTAssertEqual(filled, IndexSet())
        self.fixture.transaction { transaction in
            transaction.removeHistoryAsUnseenPeer(self.removedChat, namespace: self.namespace)
        }
        let holes = self.fixture.transaction { transaction -> IndexSet in
            return transaction.getHoles(peerId: self.removedChat, namespace: self.namespace)
        }
        XCTAssertEqual(holes, IndexSet(integersIn: Int(self.fullRange.lowerBound) ... Int(self.fullRange.upperBound)))
    }

    func testOpenHistoryViewIsReported() {
        self.seedThreeChats()
        XCTAssertEqual(self.fixture.transaction { $0.hasOpenMessageHistoryView(peerId: self.removedChat) }, false)
        let _ = self.fixture.observeHistory(peerId: self.removedChat, additionalData: []).waitForValues(count: 1)
        XCTAssertEqual(self.fixture.transaction { $0.hasOpenMessageHistoryView(peerId: self.removedChat) }, true)
        XCTAssertEqual(self.fixture.transaction { $0.hasOpenMessageHistoryView(peerId: self.newerChat) }, false)
    }

    func testStoredEntriesListAHoleAboveTheChatItSitsOn() {
        self.seedThreeChats()
        let entries = self.fixture.transaction { transaction -> [ChatListStoredEntry] in
            let holeIndex = transaction.getPeerChatListIndex(self.holeChat)!.1.messageIndex
            for hole in transaction.allChatListHoles(groupId: .root) {
                transaction.replaceChatListHole(groupId: .root, index: hole.index, hole: nil)
            }
            transaction.addChatListHole(groupId: .root, hole: ChatListHole(index: holeIndex))
            return transaction.chatListStoredEntries(groupId: .root, earlierThan: nil, count: 10)
        }
        guard let entries, entries.count == 4 else {
            XCTFail("expected three chats and a hole, got \(String(describing: entries))")
            return
        }
        guard case let .chat(first) = entries[0], case .hole = entries[1], case let .chat(third) = entries[2], case let .chat(fourth) = entries[3] else {
            XCTFail("unexpected order: \(entries)")
            return
        }
        XCTAssertEqual(first.messageIndex.id.peerId, self.newerChat)
        XCTAssertEqual(third.messageIndex.id.peerId, self.holeChat)
        XCTAssertEqual(fourth.messageIndex.id.peerId, self.removedChat)
    }

    func testEarlierThanContinuesBelowAHoleAndSeeksPastNewerChats() {
        self.seedThreeChats()
        let result = self.fixture.transaction { transaction -> (belowHole: [ChatListStoredEntry], belowSeek: [ChatListStoredEntry]) in
            let holeIndex = transaction.getPeerChatListIndex(self.holeChat)!.1.messageIndex
            transaction.addChatListHole(groupId: .root, hole: ChatListHole(index: holeIndex))
            let belowHole = transaction.chatListStoredEntries(groupId: .root, earlierThan: (ChatListIndex(pinningIndex: nil, messageIndex: holeIndex), false), count: 10)
            let seek = ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex(id: MessageId(peerId: PeerId(0), namespace: 0, id: 0), timestamp: 1001))
            let belowSeek = transaction.chatListStoredEntries(groupId: .root, earlierThan: (seek, true), count: 10)
            return (belowHole, belowSeek)
        }
        var belowHolePeers: [PeerId] = []
        for entry in result?.belowHole ?? [] {
            if case let .chat(index) = entry {
                belowHolePeers.append(index.messageIndex.id.peerId)
            }
        }
        XCTAssertEqual(belowHolePeers, [self.holeChat, self.removedChat])
        var belowSeekPeers: [PeerId] = []
        for entry in result?.belowSeek ?? [] {
            if case let .chat(index) = entry {
                belowSeekPeers.append(index.messageIndex.id.peerId)
            }
        }
        XCTAssertEqual(belowSeekPeers, [self.removedChat])
    }

    func testFetchBelowTheHoleBringsTheChatBackWithOlderMessagesReachable() {
        self.seedThreeChats()
        let holeIndex = self.fixture.transaction { transaction -> MessageIndex in
            let holeIndex = transaction.getPeerChatListIndex(self.holeChat)!.1.messageIndex
            for hole in transaction.allChatListHoles(groupId: .root) {
                transaction.replaceChatListHole(groupId: .root, index: hole.index, hole: nil)
            }
            transaction.addChatListHole(groupId: .root, hole: ChatListHole(index: holeIndex))
            transaction.removeHistoryAsUnseenPeer(self.removedChat, namespace: self.namespace)
            return holeIndex
        }
        XCTAssertEqual(self.fixture.transaction { $0.getPeerChatListIndex(self.removedChat) == nil }, true)

        // What a chat list fetch below the hole stores: the chat's latest message, and the hole moved
        // down to the last chat of the page.
        self.fixture.transaction { transaction in
            let _ = transaction.addMessages([self.message(peerId: self.removedChat, id: 100, timestamp: 1000)], location: .UpperHistoryBlock)
            transaction.replaceChatListHole(groupId: .root, index: holeIndex!, hole: ChatListHole(index: MessageIndex(id: MessageId(peerId: self.removedChat, namespace: self.namespace, id: 100), timestamp: 1000)))
        }
        let result = self.fixture.transaction { transaction -> (index: (PeerGroupId, ChatListIndex)?, holes: IndexSet, listHoles: [ChatListHole]) in
            return (transaction.getPeerChatListIndex(self.removedChat), transaction.getHoles(peerId: self.removedChat, namespace: self.namespace), transaction.allChatListHoles(groupId: .root))
        }
        XCTAssertEqual(result?.index?.1.messageIndex.id.id, 100)
        XCTAssertEqual(result?.holes, IndexSet(integersIn: 1 ... 99))
        XCTAssertEqual(result?.listHoles.map { $0.index.id.peerId }, [self.removedChat])
    }

    func testClearHistoryAloneLeavesNoHole() {
        self.seedThreeChats()
        let holes = self.fixture.transaction { transaction -> IndexSet in
            transaction.clearHistory(self.removedChat, threadId: nil, minTimestamp: nil, maxTimestamp: nil, namespaces: .just(Set([self.namespace])), forEachMedia: nil)
            return transaction.getHoles(peerId: self.removedChat, namespace: self.namespace)
        }
        XCTAssertEqual(holes, IndexSet())
    }

    func testHistoryInitializedFlagIsReadWithoutSettingUpTheHistory() {
        self.seedThreeChats()
        let untouched = MessageHistoryTableFixture.peerId(903)
        XCTAssertEqual(self.fixture.transaction { $0.isMessageHistoryInitialized(peerId: untouched) }, false)
        XCTAssertEqual(self.fixture.transaction { $0.isMessageHistoryInitialized(peerId: untouched) }, false)
        let _ = self.fixture.transaction { $0.getHoles(peerId: self.removedChat, namespace: self.namespace) }
        XCTAssertEqual(self.fixture.transaction { $0.isMessageHistoryInitialized(peerId: self.removedChat) }, true)
        self.fixture.transaction { transaction in
            transaction.removeHistoryAsUnseenPeer(self.removedChat, namespace: self.namespace)
        }
        XCTAssertEqual(self.fixture.transaction { $0.isMessageHistoryInitialized(peerId: self.removedChat) }, false)
    }
}
