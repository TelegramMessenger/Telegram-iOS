import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A forum's chat list row shows the topic of its top message (`forumTopicData`) and its first topics
/// (`topForumTopics`), read from the topics' infos when the row is built. An edit that changes only a topic's info (its
/// title, icon, closed or hidden: layer 233's `updateEditForumTopic`, with no new message and no change to the unread
/// summary) must reach the row too, or it keeps the old title until something else rebuilds it.
final class ChatListForumTopicInfoTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let forumId = MessageHistoryTableFixture.peerId(900)
    private let chatId = MessageHistoryTableFixture.peerId(901)
    private let namespace = PostboxFixture.messageNamespace

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "ChatListForumTopicInfoTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    /// A topic info whose data is `title`; the summary (what the unread counters read) is the same for every title.
    private func threadInfo(_ title: String, maxOutgoingReadId: Int32 = 0) -> StoredMessageHistoryThreadInfo {
        return StoredMessageHistoryThreadInfo(data: CodableEntry(data: title.data(using: .utf8)!), summary: StoredMessageHistoryThreadInfo.Summary(totalUnreadCount: 0, isMarkedUnread: false, mutedUntil: nil, maxOutgoingReadId: maxOutgoingReadId))
    }

    private func title(_ data: ChatListForumTopicData?) -> String? {
        return data.flatMap { String(data: $0.info.data.data, encoding: .utf8) }
    }

    private func message(peerId: PeerId, _ id: Int32, threadId: Int64?, text: String? = nil) -> StoreMessage {
        return StoreMessage(id: MessageId(peerId: peerId, namespace: self.namespace, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: 1000 + id, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: text ?? "m\(id)", attributes: [], media: [])
    }

    /// A forum whose top message (2) is in topic 2, with topic 1 below it, and a plain chat.
    private func seed() {
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: self.forumId, title: "Forum", isForum: true), FixturePeer(id: self.chatId, title: "Chat")], update: { _, updated in updated })
            for peerId in [self.forumId, self.chatId] {
                transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
            }
            let _ = transaction.addMessages([self.message(peerId: self.forumId, 1, threadId: 1), self.message(peerId: self.forumId, 2, threadId: 2), self.message(peerId: self.chatId, 1, threadId: nil)], location: .Random)
            transaction.setMessageHistoryThreadInfo(peerId: self.forumId, threadId: 1, info: self.threadInfo("General"))
            transaction.setMessageHistoryThreadInfo(peerId: self.forumId, threadId: 2, info: self.threadInfo("Old"))
        }
    }

    private func observeChatList() -> PostboxFixture.Recorder<ChatListView> {
        return self.fixture.observe(self.fixture.postbox.tailChatListView(groupId: .root, filterPredicate: nil, count: 10, summaryComponents: ChatListEntrySummaryComponents()) |> map { $0.0 })
    }

    private func forumRow(in view: ChatListView?) -> ChatListEntry.MessageEntryData? {
        for entry in view?.entries ?? [] {
            if case let .MessageEntry(data) = entry, data.index.messageIndex.id.peerId == self.forumId {
                return data
            }
        }
        return nil
    }

    // MARK: - Tests

    func testRenamingTheTopMessagesTopicReachesTheRow() {
        self.seed()
        let recorder = self.observeChatList()
        let initial = self.forumRow(in: recorder.waitForValues(count: 1).last)
        XCTAssertEqual(self.title(initial?.forumTopicData), "Old")
        XCTAssertEqual(initial?.topForumTopics.map { self.title($0) }, ["Old", "General"])

        self.fixture.transaction { transaction in
            transaction.setMessageHistoryThreadInfo(peerId: self.forumId, threadId: 2, info: self.threadInfo("New"))
        }

        let row = self.forumRow(in: recorder.waitForValues(count: 2).last)
        XCTAssertEqual(self.title(row?.forumTopicData), "New")
        XCTAssertEqual(row?.topForumTopics.map { self.title($0) }, ["New", "General"])
    }

    /// Topic 1 is not the top message's: the row's topic list follows, its top topic stays.
    func testRenamingAnotherTopicReachesTheRowsTopicList() {
        self.seed()
        let recorder = self.observeChatList()
        recorder.waitForValues(count: 1)

        self.fixture.transaction { transaction in
            transaction.setMessageHistoryThreadInfo(peerId: self.forumId, threadId: 1, info: self.threadInfo("Lobby"))
        }

        let row = self.forumRow(in: recorder.waitForValues(count: 2).last)
        XCTAssertEqual(self.title(row?.forumTopicData), "Old")
        XCTAssertEqual(row?.topForumTopics.map { self.title($0) }, ["Old", "Lobby"])
    }

    /// Reading a topic writes only its info (its outgoing read mark here): the row's topic data, which colours the
    /// topic's name and draws the read checks, follows it as it follows an edit.
    func testAnOutgoingTopicReadReachesTheRow() {
        self.seed()
        let recorder = self.observeChatList()
        recorder.waitForValues(count: 1)

        self.fixture.transaction { transaction in
            transaction.setMessageHistoryThreadInfo(peerId: self.forumId, threadId: 2, info: self.threadInfo("Old", maxOutgoingReadId: 2))
        }

        let row = self.forumRow(in: recorder.waitForValues(count: 2).last)
        XCTAssertEqual(row?.forumTopicData?.info.summary.maxOutgoingReadId, 2)
        XCTAssertEqual(self.title(row?.forumTopicData), "Old")
    }

    /// A write that leaves a topic's info as it was changes no row and sends no view: the rename after it is the
    /// second value.
    func testAnUnchangedTopicInfoSendsNoView() {
        self.seed()
        let recorder = self.observeChatList()
        recorder.waitForValues(count: 1)

        self.fixture.transaction { transaction in
            transaction.setMessageHistoryThreadInfo(peerId: self.forumId, threadId: 2, info: self.threadInfo("Old"))
        }
        self.fixture.transaction { transaction in
            transaction.setMessageHistoryThreadInfo(peerId: self.forumId, threadId: 2, info: self.threadInfo("New"))
        }

        let values = recorder.waitForValues(count: 2)
        XCTAssertEqual(values.count, 2, "the unchanged write sent a view")
        XCTAssertEqual(self.title(self.forumRow(in: values.last)?.forumTopicData), "New")
    }

    /// A forum upgraded from a group whose only message is the upgrade message shows the legacy group's last message,
    /// and the upgrade message's topic (General). An edit of that topic reaches the row; the legacy message, which has no
    /// topic, must not take the row's topic away.
    func testAMergedRowKeepsItsTopicThroughAnEdit() {
        let legacyId = MessageHistoryTableFixture.peerId(902)
        let upgradedId = MessageHistoryTableFixture.peerId(903)
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: upgradedId, title: "Upgraded", isForum: true), FixturePeer(id: legacyId, title: "Legacy")], update: { _, updated in updated })
            transaction.updatePeerChatListInclusion(upgradedId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
            let _ = transaction.addMessages([self.message(peerId: legacyId, 5, threadId: nil), self.message(peerId: upgradedId, 1, threadId: 1, text: MessageHistoryTableFixture.peerUpgradeMessageText)], location: .Random)
            transaction.setMessageHistoryThreadInfo(peerId: upgradedId, threadId: 1, info: self.threadInfo("General"))
            transaction.updatePeerCachedData(peerIds: [upgradedId], update: { _, _ in FixtureCachedPeerData(peerIds: [], associatedHistoryMessageId: MessageId(peerId: legacyId, namespace: self.namespace, id: 5)) })
        }
        let recorder = self.observeChatList()

        func upgradedRow(_ view: ChatListView?) -> ChatListEntry.MessageEntryData? {
            for entry in view?.entries ?? [] {
                if case let .MessageEntry(data) = entry, data.index.messageIndex.id.peerId == upgradedId {
                    return data
                }
            }
            return nil
        }
        let initial = upgradedRow(recorder.waitForValues(count: 1).last)
        XCTAssertEqual(initial?.messages.first?.id.peerId, legacyId, "the row shows the legacy group's message")
        XCTAssertEqual(self.title(initial?.forumTopicData), "General")

        self.fixture.transaction { transaction in
            transaction.setMessageHistoryThreadInfo(peerId: upgradedId, threadId: 1, info: self.threadInfo("Lobby"))
        }

        let row = upgradedRow(recorder.waitForValues(count: 2).last)
        XCTAssertEqual(self.title(row?.forumTopicData), "Lobby")
    }
}
