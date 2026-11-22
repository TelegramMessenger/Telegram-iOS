import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let search = "messages.search"
private let getUnreadMentions = "messages.getUnreadMentions"
private let getRecentLocations = "messages.getRecentLocations"
private let getMessages = "messages.getMessages"

/// Tag fills reconcile too (spec 2026-10-15 §4): the stored messages carrying the tag inside the filled
/// range that the tag request did not return are confirmed with messages.getMessages. Re-storing one the
/// server still has recomputes its tags, so a message unpinned or a mention read during the gap leaves
/// its tag view and stays in the chat. A live-location fill (messages.getRecentLocations) proves nothing
/// about a range and is unchanged. Helpers are in HistoryFillReconciliationTests.swift.
final class HistoryFillTagReconciliationTests: StateSyncTestCase {
    /// 7 was pinned when stored and unpinned during the gap: the pinned search returns nothing, so 7 is
    /// confirmed. The server still has it, unpinned: it is re-stored without `.pinned`, leaves the
    /// pinned view and stays in the chat, whose own hole is untouched.
    func testPinnedFillUnpinsAMessageUnpinnedDuringTheGap() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [7], text: "pinned once", tags: [.pinned])
        self.addHistoryFillHole(peerId)
        self.server.on(search, .result(StateSyncApi.messages([])))
        self.server.on(getMessages, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 7, peerUserId: 500, fromUserId: 500, date: self.baseDate + 7, text: "pinned once")
        ])))

        let result = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId), space: .tag(.pinned))

        XCTAssertEqual(self.server.requestNames, [search, getMessages])
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 7)))
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 7))?.tags.contains(.pinned), false)
        XCTAssertEqual(self.historyFillTaggedIds(peerId, tag: .pinned), [])
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 1 ... Int(Int32.max - 1)))
        let holeSpaces = self.historyFillHoleSpaces(containing: self.messageId(peerId, 7))
        XCTAssertNil(holeSpaces[.tag(.pinned)])
        XCTAssertNotNil(holeSpaces[.everywhere])
    }

    /// 9 mentioned the account in a basic group and was read on another device during the gap: the
    /// unread-mentions request returns nothing, so 9 is confirmed. The server still has it, mentioned but
    /// no longer unread: it is re-stored without `.unseenPersonalMessage` and leaves the mentions view.
    func testMentionsFillDropsAMentionReadDuringTheGap() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let groupId = self.seedHistoryFillGroup(800)
        let authorId = StateSyncFixture.userPeerId(500)
        self.fixture.seedPeers([StateSyncFixture.makeUser(id: authorId, accessHash: 1, firstName: "U500")])
        self.storeHistoryFillMessages(peerId: groupId, ids: [9], text: "@account", authorId: authorId, tags: [.unseenPersonalMessage], attributes: [ConsumablePersonalMentionMessageAttribute(consumed: false, pending: false)])
        self.addHistoryFillHole(groupId)
        self.server.on(getUnreadMentions, .result(StateSyncApi.messages([])))
        self.server.on(getMessages, .result(StateSyncApi.messages([
            HistoryFillApi.groupMessage(id: 9, chatId: 800, fromUserId: 500, date: self.baseDate + 9, text: "@account", mentioned: true, mediaUnread: false)
        ])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: groupId, threadId: nil), direction: self.downwardFillDirection(groupId), space: .tag(.unseenPersonalMessage))

        XCTAssertEqual(self.server.requestNames, [getUnreadMentions, getMessages])
        XCTAssertNotNil(self.fixture.message(self.messageId(groupId, 9)))
        XCTAssertEqual(self.fixture.message(self.messageId(groupId, 9))?.tags.contains(.unseenPersonalMessage), false)
        XCTAssertEqual(self.historyFillTaggedIds(groupId, tag: .unseenPersonalMessage), [])
    }

    /// A tag fill deep in a chat with more than 1000 messages carrying the tag (shared media is the usual
    /// case) still finds its candidates: they are read from the tag's index inside the filled range, not
    /// from the 1000 newest. The pinned search below 50 returns 21...50 but 30, which was deleted during
    /// the gap: 30 is confirmed and deleted, and the pinned hole closes over 21...50.
    func testTagFillBelowTheThousandNewestTaggedConfirmsItsCandidates() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: Array(1 ... 1100), text: "pinned", tags: [.pinned])
        self.addHistoryFillHole(peerId)
        let answerIds = (Int32(21) ... Int32(50)).reversed().filter { $0 != 30 }
        self.server.on(search, .result(StateSyncApi.messages(answerIds.map { id in
            HistoryFillApi.pinnedPrivateMessage(id: id, userId: 500, date: self.baseDate + id)
        })))
        self.server.on(getMessages, .result(StateSyncApi.messages([])))

        let result = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId, from: 50), space: .tag(.pinned))

        XCTAssertEqual(self.server.requestNames, [search, getMessages])
        XCTAssertEqual(self.server.requests.last?.payload, HistoryFillApi.getMessagesPayload(ids: [30]))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 30)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 29)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 1100)))
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 21 ... 50))
    }

    /// Pin: a custom-tag fill (a Saved Messages reaction tag) is unchanged. Stored 10, left out of an empty
    /// answer, is neither confirmed nor touched.
    func testCustomTagFillIsUnchanged() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let accountPeerId = StateSyncFixture.accountPeerId
        self.storeHistoryFillMessages(peerId: accountPeerId, ids: [10], authorId: accountPeerId)
        self.addHistoryFillHole(accountPeerId)
        self.server.on(search, .result(StateSyncApi.messages([])))
        // Answered, so a leaked confirmation fails the request assertion instead of stalling the fill.
        self.server.on(getMessages, .result(StateSyncApi.messages([])))
        let customTag = ReactionsMessageAttribute.messageTag(reaction: .builtin("👍"))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: accountPeerId, threadId: nil), direction: self.downwardFillDirection(accountPeerId), space: .customTag(customTag, nil))

        XCTAssertEqual(self.server.requestNames, [search])
        XCTAssertNotNil(self.fixture.message(self.messageId(accountPeerId, 10)))
    }

    /// Pin: a live-location fill is unchanged. Its answer closes the whole range without saying anything
    /// about it, so stored 30 is neither confirmed nor touched.
    func testLiveLocationFillIsUnchanged() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [30], tags: [.liveLocation])
        self.addHistoryFillHole(peerId)
        self.server.on(getRecentLocations, .result(StateSyncApi.messages([])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId), space: .tag(.liveLocation))

        XCTAssertEqual(self.server.requestNames, [getRecentLocations])
        XCTAssertEqual(self.historyFillTaggedIds(peerId, tag: .liveLocation), [self.messageId(peerId, 30)])
    }
}
