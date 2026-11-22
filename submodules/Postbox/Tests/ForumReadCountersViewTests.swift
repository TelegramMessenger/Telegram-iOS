import Foundation
import XCTest
@testable import Postbox

/// A forum's read counter is the number of its topics with unread messages, taken from
/// the peer-threads summary rather than the peer's read state. Reading a topic (or
/// receiving into one) rewrites that topic's thread info; the summary is recomputed when
/// the transaction commits, and the views that show the counter must follow it.
final class ForumReadCountersViewTests: XCTestCase {
    private var fixture: PostboxFixture!

    private let forumId = MessageHistoryTableFixture.peerId(700)
    private let namespace = PostboxFixture.messageNamespace

    override func setUp() {
        super.setUp()
        self.fixture = PostboxFixture(name: "ForumReadCountersViewTests")
    }

    override func tearDown() {
        self.fixture.close()
        self.fixture = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func threadInfo(unreadCount: Int32) -> StoredMessageHistoryThreadInfo {
        return StoredMessageHistoryThreadInfo(data: CodableEntry(data: Data()), summary: StoredMessageHistoryThreadInfo.Summary(totalUnreadCount: unreadCount, isMarkedUnread: false, mutedUntil: nil, maxOutgoingReadId: 0))
    }

    private func message(_ id: Int32, threadId: Int64) -> StoreMessage {
        return StoreMessage(id: MessageId(peerId: self.forumId, namespace: self.namespace, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: 1000 + id, flags: [.Incoming], tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: nil, text: "m\(id)", attributes: [], media: [])
    }

    /// A forum with two topics holding one message each. Topic 1 has three unread
    /// messages, topic 2 none, so the forum counts as one unread topic.
    private func seedForumWithOneUnreadTopic() {
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: self.forumId, title: "Forum", isForum: true)], update: { _, updated in updated })
            let _ = transaction.addMessages([self.message(1, threadId: 1), self.message(2, threadId: 2)], location: .Random)
            transaction.setMessageHistoryThreadInfo(peerId: self.forumId, threadId: 1, info: self.threadInfo(unreadCount: 3))
            transaction.setMessageHistoryThreadInfo(peerId: self.forumId, threadId: 2, info: self.threadInfo(unreadCount: 0))
        }
    }

    /// What reading a topic does to the store: only its thread info changes.
    private func setUnreadCount(_ count: Int32, inTopic threadId: Int64) {
        self.fixture.transaction { transaction in
            transaction.setMessageHistoryThreadInfo(peerId: self.forumId, threadId: threadId, info: self.threadInfo(unreadCount: count))
        }
    }

    // MARK: - Combined read state (PeerReadCounters)

    func testCombinedReadStateFollowsATopicBeingRead() {
        self.seedForumWithOneUnreadTopic()
        let recorder = self.fixture.observe(.combinedReadState(peerId: self.forumId, handleThreads: true), as: CombinedReadStateView.self)
        XCTAssertEqual(recorder.waitForValues(count: 1).last?.state?.count, 1)

        self.setUnreadCount(0, inTopic: 1)

        XCTAssertEqual(recorder.waitForValues(count: 2).last?.state?.count, 0)
    }

    func testCombinedReadStateFollowsATopicReceivingUnreadMessages() {
        self.seedForumWithOneUnreadTopic()
        let recorder = self.fixture.observe(.combinedReadState(peerId: self.forumId, handleThreads: true), as: CombinedReadStateView.self)
        XCTAssertEqual(recorder.waitForValues(count: 1).last?.state?.count, 1)

        self.setUnreadCount(2, inTopic: 2)

        XCTAssertEqual(recorder.waitForValues(count: 2).last?.state?.count, 2)
    }

    /// Guard: a non-forum peer still follows its read state.
    func testCombinedReadStateOfARegularChatFollowsItsReadState() {
        let chatId = MessageHistoryTableFixture.peerId(701)
        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: chatId, title: "Chat")], update: { _, updated in updated })
            transaction.resetIncomingReadStates([chatId: [self.namespace: .idBased(maxIncomingReadId: 1, maxOutgoingReadId: 1, maxKnownId: 5, count: 4, markedUnread: false)]])
        }
        let recorder = self.fixture.observe(.combinedReadState(peerId: chatId, handleThreads: true), as: CombinedReadStateView.self)
        XCTAssertEqual(recorder.waitForValues(count: 1).last?.state?.count, 4)

        self.fixture.transaction { transaction in
            transaction.resetIncomingReadStates([chatId: [self.namespace: .idBased(maxIncomingReadId: 5, maxOutgoingReadId: 1, maxKnownId: 5, count: 0, markedUnread: false)]])
        }

        XCTAssertEqual(recorder.waitForValues(count: 2).last?.state?.count, 0)
    }

    /// A forum shown as a regular chat (or a group turned into a forum) switches which
    /// counter it reports; only the peer record changes in that transaction.
    func testCombinedReadStateSwitchesCounterWhenThePeerStopsBeingAForum() {
        self.seedForumWithOneUnreadTopic()
        self.fixture.transaction { transaction in
            transaction.resetIncomingReadStates([self.forumId: [self.namespace: .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 2, count: 7, markedUnread: false)]])
        }
        let recorder = self.fixture.observe(.combinedReadState(peerId: self.forumId, handleThreads: true), as: CombinedReadStateView.self)
        XCTAssertEqual(recorder.waitForValues(count: 1).last?.state?.count, 1)

        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: self.forumId, title: "Forum", isForum: false)], update: { _, updated in updated })
        }

        XCTAssertEqual(recorder.waitForValues(count: 2).last?.state?.count, 7)
    }

    func testUnreadCountsSwitchCounterWhenThePeerStopsBeingAForum() {
        self.seedForumWithOneUnreadTopic()
        self.fixture.transaction { transaction in
            transaction.resetIncomingReadStates([self.forumId: [self.namespace: .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: 2, count: 7, markedUnread: false)]])
        }
        let item = UnreadMessageCountsItem.peer(id: self.forumId, handleThreads: true)
        let recorder = self.fixture.observe(.unreadCounts(items: [item]), as: UnreadMessageCountsView.self)
        XCTAssertEqual(recorder.waitForValues(count: 1).last?.count(for: item), 1)

        self.fixture.transaction { transaction in
            transaction.updatePeersInternal([FixturePeer(id: self.forumId, title: "Forum", isForum: false)], update: { _, updated in updated })
        }

        XCTAssertEqual(recorder.waitForValues(count: 2).last?.count(for: item), 7)
    }

    // MARK: - Unread counts (PeerUnreadCount, recent-search peers)

    func testUnreadCountsFollowATopicBeingRead() {
        self.seedForumWithOneUnreadTopic()
        let item = UnreadMessageCountsItem.peer(id: self.forumId, handleThreads: true)
        let recorder = self.fixture.observe(.unreadCounts(items: [item]), as: UnreadMessageCountsView.self)
        XCTAssertEqual(recorder.waitForValues(count: 1).last?.count(for: item), 1)

        self.setUnreadCount(0, inTopic: 1)

        XCTAssertEqual(recorder.waitForValues(count: 2).last?.count(for: item), 0)
    }
}
