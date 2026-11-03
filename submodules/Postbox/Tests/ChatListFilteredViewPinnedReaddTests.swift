import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A folder (a chat list view with a filter predicate) shows chats pinned in the main
/// list as ordinary rows: its space is keyed by the index with the pinning stripped.
/// Every path that puts an entry into that space must strip it, including the two
/// re-add loops that run when a chat's notification settings, thread summary, cached
/// data or tag summary change and it now passes the filter.
final class ChatListFilteredViewPinnedReaddTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let pinnedChat = MessageHistoryTableFixture.peerId(800)
    private let otherChat = MessageHistoryTableFixture.peerId(801)
    private let otherPinnedChat = MessageHistoryTableFixture.peerId(802)
    private let namespace = PostboxFixture.messageNamespace

    /// Test-controlled filter decision, read by the predicate on every evaluation.
    private final class Switch {
        var includesPinnedChat = false
    }
    private let filter = Switch()

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "ChatListFilteredViewPinnedReaddTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func message(peerId: PeerId, id: Int32, timestamp: Int32) -> StoreMessage {
        return MessageHistoryTableFixture.storeMessage(id: MessageId(peerId: peerId, namespace: self.namespace, id: id), timestamp: timestamp, text: "m\(id)", flags: [.Incoming])
    }

    /// Three chats in the main list, two of them pinned there. The folder excludes one
    /// pinned chat until the switch is flipped; the other pinned chat is in the folder
    /// from the start and has an older message. A re-add whose index would be the lowest
    /// in its space (an empty space included) is refused as out of range and the space is
    /// reloaded from the table, which hides a wrongly mapped index; with an older row
    /// below it the re-added entry is inserted directly and keeps whatever index it got.
    private func seedMainListWithTwoPinnedChats() {
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: self.pinnedChat, title: "Pinned"), FixturePeer(id: self.otherChat, title: "Other"), FixturePeer(id: self.otherPinnedChat, title: "Other pinned")], update: { _, updated in updated })
            for peerId in [self.pinnedChat, self.otherChat, self.otherPinnedChat] {
                transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
            }
            let _ = transaction.addMessages([
                self.message(peerId: self.otherChat, id: 1, timestamp: 1000),
                self.message(peerId: self.otherPinnedChat, id: 1, timestamp: 1500),
                self.message(peerId: self.pinnedChat, id: 1, timestamp: 1600),
            ], location: .Random)
            transaction.setPinnedItemIds(groupId: .root, itemIds: [.peer(self.pinnedChat), .peer(self.otherPinnedChat)])
        }
    }

    private func folderPredicate() -> ChatListFilterPredicate {
        let filter = self.filter
        let pinnedChat = self.pinnedChat
        return ChatListFilterPredicate(includePeerIds: [], excludePeerIds: [], pinnedPeerIds: [], messageTagSummary: nil, includeAdditionalPeerGroupIds: [], include: { peer, _, _, _, _ in
            if peer.id == pinnedChat {
                return filter.includesPinnedChat
            }
            return true
        })
    }

    private func observeFolder() -> PostboxFixture.Recorder<ChatListView> {
        return self.fixture.observe(self.fixture.postbox.tailChatListView(groupId: .root, filterPredicate: self.folderPredicate(), count: 10, summaryComponents: ChatListEntrySummaryComponents()) |> map { $0.0 })
    }

    /// Flips the filter and touches the chat's cached data, one of the changes after
    /// which the folder re-evaluates the chat and re-adds it from the table.
    private func letThePinnedChatIntoTheFolder() {
        self.filter.includesPinnedChat = true
        self.fixture.transaction { transaction in
            transaction.updatePeerCachedData(peerIds: [self.pinnedChat], update: { _, _ in FixtureCachedPeerData(peerIds: []) })
        }
    }

    private func entries(for peerId: PeerId, in view: ChatListView?) -> [ChatListEntry.MessageEntryData] {
        return (view?.entries ?? []).compactMap { entry -> ChatListEntry.MessageEntryData? in
            if case let .MessageEntry(data) = entry, data.index.messageIndex.id.peerId == peerId {
                return data
            }
            return nil
        }
    }

    /// Peer ids of the folder's rows in order, oldest first (the view lists entries ascending).
    private func peerOrder(in view: ChatListView?) -> [PeerId] {
        return (view?.entries ?? []).compactMap { entry -> PeerId? in
            if case let .MessageEntry(data) = entry {
                return data.index.messageIndex.id.peerId
            }
            return nil
        }
    }

    // MARK: - Tests

    func testReaddedPinnedChatIsKeyedByItsUnpinnedIndex() {
        self.seedMainListWithTwoPinnedChats()
        let recorder = self.observeFolder()
        XCTAssertEqual(self.entries(for: self.pinnedChat, in: recorder.waitForValues(count: 1).last).count, 0)

        self.letThePinnedChatIntoTheFolder()

        let view = recorder.waitForValues(count: 2).last
        let readded = self.entries(for: self.pinnedChat, in: view)
        XCTAssertEqual(readded.count, 1)
        XCTAssertNil(readded.first?.index.pinningIndex, "a folder shows a pinned chat as an ordinary row")
        XCTAssertEqual(self.peerOrder(in: view), [self.otherChat, self.otherPinnedChat, self.pinnedChat], "ordered by message time")
    }

    func testReaddedPinnedChatFollowsItsNextMessageWithoutADuplicateRow() {
        self.seedMainListWithTwoPinnedChats()
        let recorder = self.observeFolder()
        recorder.waitForValues(count: 1)
        self.letThePinnedChatIntoTheFolder()
        recorder.waitForValues(count: 2)

        self.fixture.transaction { transaction in
            let _ = transaction.addMessages([self.message(peerId: self.pinnedChat, id: 2, timestamp: 3000)], location: .Random)
        }

        let view = recorder.waitForValues(count: 3).last
        let rows = self.entries(for: self.pinnedChat, in: view)
        XCTAssertEqual(rows.count, 1, "one row per chat")
        XCTAssertEqual(rows.first?.messages.first?.id.id, 2, "the row shows the newest message")
        XCTAssertNil(rows.first?.index.pinningIndex)
        XCTAssertEqual(self.peerOrder(in: view), [self.otherChat, self.otherPinnedChat, self.pinnedChat])
    }
}
