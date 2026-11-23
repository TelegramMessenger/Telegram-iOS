import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

final class ChatListEntryExclusionTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let namespace = PostboxFixture.messageNamespace
    private let readChat = MessageHistoryTableFixture.peerId(900)
    private let unreadChat = MessageHistoryTableFixture.peerId(901)
    private let pinnedReadChat = MessageHistoryTableFixture.peerId(902)
    private let noStateChat = MessageHistoryTableFixture.peerId(903)

    private let exclusion = ChatListEntryExclusion(excludes: { _, state in
        guard let state, !state.states.isEmpty else {
            return false
        }
        return !state.isUnread
    })

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "ChatListEntryExclusionTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    private func message(peerId: PeerId, id: Int32, timestamp: Int32, incoming: Bool = false) -> StoreMessage {
        return MessageHistoryTableFixture.storeMessage(id: MessageId(peerId: peerId, namespace: self.namespace, id: id), timestamp: timestamp, text: "m\(id)", flags: incoming ? [.Incoming] : [])
    }

    private func readState(count: Int32) -> PeerReadState {
        return .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 1, maxKnownId: 1, count: count, markedUnread: false)
    }

    private func addChats(_ chats: [(PeerId, Int32, Int32?)]) {
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal(chats.map { FixturePeer(id: $0.0, title: "\($0.0.id._internalGetInt64Value())") }, update: { _, updated in updated })
            var states: [PeerId: [MessageId.Namespace: PeerReadState]] = [:]
            for (peerId, timestamp, count) in chats {
                transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
                let _ = transaction.addMessages([self.message(peerId: peerId, id: 1, timestamp: timestamp)], location: .Random)
                if let count {
                    states[peerId] = [self.namespace: self.readState(count: count)]
                }
            }
            transaction.resetIncomingReadStates(states)
        }
    }

    private func seed() {
        self.addChats([
            (self.readChat, 1000, 0),
            (self.unreadChat, 1100, 1),
            (self.pinnedReadChat, 1200, 0),
            (self.noStateChat, 1300, nil),
        ])
        self.fixture.transaction { transaction in
            transaction.setPinnedItemIds(groupId: .root, itemIds: [.peer(self.pinnedReadChat)])
        }
    }

    private func peerOrder(in view: ChatListView?) -> [PeerId] {
        return (view?.entries ?? []).compactMap { entry -> PeerId? in
            if case let .MessageEntry(data) = entry {
                return data.index.messageIndex.id.peerId
            }
            return nil
        }
    }

    private func observeMainList(exclusion: ChatListEntryExclusion?, count: Int = 10) -> PostboxFixture.Recorder<ChatListView> {
        return self.fixture.observe(self.fixture.postbox.tailChatListView(groupId: .root, exclusion: exclusion, count: count, summaryComponents: ChatListEntrySummaryComponents()) |> map { $0.0 })
    }

    func testWithoutAnExclusionEveryChatShows() {
        self.seed()
        let view = self.observeMainList(exclusion: nil).waitForValues(count: 1).last
        XCTAssertEqual(Set(self.peerOrder(in: view)), Set([self.readChat, self.unreadChat, self.pinnedReadChat, self.noStateChat]))
    }

    func testTheMainListLeavesOutExcludedChatsButKeepsPinnedOnesAndChatsWithoutAReadState() {
        self.seed()
        let view = self.observeMainList(exclusion: self.exclusion).waitForValues(count: 1).last
        XCTAssertEqual(self.peerOrder(in: view), [self.unreadChat, self.noStateChat, self.pinnedReadChat])
    }

    func testTheWindowIsFilledWithShownChats() {
        var chats: [(PeerId, Int32, Int32?)] = []
        for i in 0 ..< 8 {
            chats.append((MessageHistoryTableFixture.peerId(Int64(910 + i)), Int32(2000 + i * 10), i % 2 == 0 ? 0 : 1))
        }
        self.addChats(chats)
        let view = self.observeMainList(exclusion: self.exclusion, count: 3).waitForValues(count: 1).last
        XCTAssertEqual(self.peerOrder(in: view), [915, 917].map { MessageHistoryTableFixture.peerId($0) })
        XCTAssertEqual(view?.earlierIndex?.messageIndex.id.peerId, MessageHistoryTableFixture.peerId(913))
    }

    func testAnIncomingMessageBringsAHiddenChatBack() {
        self.seed()
        let recorder = self.observeMainList(exclusion: self.exclusion)
        XCTAssertFalse(self.peerOrder(in: recorder.waitForValues(count: 1).last).contains(self.readChat))

        self.fixture.transaction { transaction in
            let _ = transaction.addMessages([self.message(peerId: self.readChat, id: 2, timestamp: 1400, incoming: true)], location: .Random)
            transaction.resetIncomingReadStates([self.readChat: [self.namespace: self.readState(count: 1)]])
        }

        let view = recorder.waitForValues(count: 2).last
        XCTAssertEqual(self.peerOrder(in: view).filter { $0 == self.readChat }.count, 1)
    }

    func testAReadStateChangeAloneBringsAHiddenChatBackAndHidesItAgain() {
        self.seed()
        let recorder = self.observeMainList(exclusion: self.exclusion)
        XCTAssertFalse(self.peerOrder(in: recorder.waitForValues(count: 1).last).contains(self.readChat))

        self.fixture.transaction { transaction in
            transaction.applyMarkUnread(peerId: self.readChat, namespace: self.namespace, value: true, interactive: false)
        }
        XCTAssertEqual(self.peerOrder(in: recorder.waitForValues(count: 2).last), [self.readChat, self.unreadChat, self.noStateChat, self.pinnedReadChat])

        self.fixture.transaction { transaction in
            transaction.applyMarkUnread(peerId: self.readChat, namespace: self.namespace, value: false, interactive: false)
        }
        XCTAssertEqual(self.peerOrder(in: recorder.waitForValues(count: 3).last), [self.unreadChat, self.noStateChat, self.pinnedReadChat])
    }

    func testAFolderLeavesOutExcludedChatsIncludingOnesPinnedOnlyInTheMainList() {
        self.seed()
        let predicate = ChatListFilterPredicate(includePeerIds: [], excludePeerIds: [], pinnedPeerIds: [], messageTagSummary: nil, includeAdditionalPeerGroupIds: [], include: { _, _, _, _, _ in true })
        let recorder = self.fixture.observe(self.fixture.postbox.tailChatListView(groupId: .root, filterPredicate: predicate, exclusion: self.exclusion, count: 10, summaryComponents: ChatListEntrySummaryComponents()) |> map { $0.0 })
        XCTAssertEqual(self.peerOrder(in: recorder.waitForValues(count: 1).last), [self.unreadChat, self.noStateChat])
    }

    func testAFolderKeepsItsOwnPinnedChat() {
        self.seed()
        let predicate = ChatListFilterPredicate(includePeerIds: [], excludePeerIds: [], pinnedPeerIds: [self.readChat], messageTagSummary: nil, includeAdditionalPeerGroupIds: [], include: { _, _, _, _, _ in true })
        let recorder = self.fixture.observe(self.fixture.postbox.tailChatListView(groupId: .root, filterPredicate: predicate, exclusion: self.exclusion, count: 10, summaryComponents: ChatListEntrySummaryComponents()) |> map { $0.0 })
        XCTAssertTrue(self.peerOrder(in: recorder.waitForValues(count: 1).last).contains(self.readChat))
    }
}
