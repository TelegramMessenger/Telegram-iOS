import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"
private let getMessages = "messages.getMessages"
private let getSavedHistory = "messages.getSavedHistory"

/// Api values the history-fill reconciliation tests need (HistoryFillReconciliationTests,
/// HistoryFillTagReconciliationTests, ManagedHistoryHolesLeftoverTests). Kept out of StateSyncApi,
/// which other suites extend.
enum HistoryFillApi {
    static func peerChat(_ chatId: Int64) -> Api.Peer {
        return .peerChat(.init(chatId: chatId))
    }

    /// `message#7600b9d3` in basic group `chatId` from user `fromUserId`: `from_id` flags.8; `mentioned`
    /// flags.4 and `media_unread` flags.5 when asked. A mention whose `media_unread` is clear has been
    /// read: it parses to `ConsumablePersonalMentionMessageAttribute(consumed: true)` and no
    /// `.unseenPersonalMessage` tag (StoreMessage_Telegram.swift).
    static func groupMessage(id: Int32, chatId: Int64, fromUserId: Int64, date: Int32, text: String = "text", mentioned: Bool = false, mediaUnread: Bool = false) -> Api.Message {
        var flags: Int32 = 1 << 8
        if mentioned {
            flags |= 1 << 4
        }
        if mediaUnread {
            flags |= 1 << 5
        }
        return .message(.init(flags: flags, flags2: 0, id: id, fromId: StateSyncApi.peerUser(fromUserId), fromBoostsApplied: nil, fromRank: nil, peerId: self.peerChat(chatId), savedPeerId: nil, fwdFrom: nil, viaBotId: nil, viaBusinessBotId: nil, guestchatViaFrom: nil, replyTo: nil, date: date, message: text, media: nil, replyMarkup: nil, entities: nil, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: nil, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil, richMessage: nil))
    }

    /// `message#7600b9d3` in the chat with user `userId`, from them (`from_id` flags.8), pinned (flags.24),
    /// so it parses with the `.pinned` tag.
    static func pinnedPrivateMessage(id: Int32, userId: Int64, date: Int32) -> Api.Message {
        let flags: Int32 = (1 << 8) | (1 << 24)
        return .message(.init(flags: flags, flags2: 0, id: id, fromId: StateSyncApi.peerUser(userId), fromBoostsApplied: nil, fromRank: nil, peerId: StateSyncApi.peerUser(userId), savedPeerId: nil, fwdFrom: nil, viaBotId: nil, viaBusinessBotId: nil, guestchatViaFrom: nil, replyTo: nil, date: date, message: "pinned", media: nil, replyMarkup: nil, entities: nil, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: nil, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil, richMessage: nil))
    }

    /// The exact bytes of `messages.getHistory` with these arguments (`offset_date` and `hash` are 0 in
    /// every history fill).
    static func getHistoryPayload(peer: Api.InputPeer, offsetId: Int32, addOffset: Int32, limit: Int32, maxId: Int32, minId: Int32) -> Data {
        return Api.functions.messages.getHistory(peer: peer, offsetId: offsetId, offsetDate: 0, addOffset: addOffset, limit: limit, maxId: maxId, minId: minId, hash: 0).1.makeData()
    }

    /// The exact bytes of `messages.getMessages` asking for `ids` by id.
    static func getMessagesPayload(ids: [Int32]) -> Data {
        return Api.functions.messages.getMessages(id: ids.map { Api.InputMessage.inputMessageID(.init(id: $0)) }).1.makeData()
    }
}

extension StateSyncTestCase {
    /// A basic group the account is in, stored with chat-list inclusion and notification settings.
    @discardableResult
    func seedHistoryFillGroup(_ chatId: Int64) -> PeerId {
        let peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatId))
        let group = TelegramGroup(id: peerId, title: "G\(chatId)", photo: [], participantCount: 2, role: .member, membership: .Member, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
        self.fixture.seedPeers([group])
        self.fixture.seedChat(peerId: peerId)
        return peerId
    }

    /// Incoming Cloud messages `ids` of `peerId`, dated `baseDate + id`, in one transaction and with
    /// `.Random`, so no hole moves: a reset leaves the stored messages of a chat under a hole over its
    /// whole history.
    func storeHistoryFillMessages(peerId: PeerId, ids: [Int32], text: String = "stored", authorId: PeerId? = nil, threadId: Int64? = nil, tags: MessageTags = [], attributes: [MessageAttribute] = []) {
        let messages = ids.map { id -> StoreMessage in
            return StoreMessage(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: self.baseDate + id, flags: [.Incoming], tags: tags, globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId ?? peerId, text: text, attributes: attributes, media: [])
        }
        // The cap scales with the seed: a 1000+ message seed is slow at -Onone on a loaded machine.
        self.fixture.transaction({ transaction -> Void in
            let _ = transaction.addMessages(messages, location: .Random)
        }, timeout: 120.0)
    }

    /// The hole a reset puts over a chat's whole history. `.everywhere` also covers every tag space.
    func addHistoryFillHole(_ peerId: PeerId) {
        self.fixture.transaction { transaction -> Void in
            transaction.addHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
        }
    }

    /// One fill as ManagedMessageHistoryHoles starts it: network source, Cloud namespace, count 100.
    func historyFill(peerInput: FetchMessageHistoryHoleThreadInput, direction: MessageHistoryViewRelativeHoleDirection, space: MessageHistoryHoleOperationSpace = .everywhere) -> Signal<FetchMessageHistoryHoleResult?, NoError> {
        return fetchMessageHistoryHole(accountPeerId: StateSyncFixture.accountPeerId, source: .network(self.network), postbox: self.fixture.postbox, peerInput: peerInput, namespace: Namespaces.Message.Cloud, direction: direction, space: space, count: 100)
    }

    /// Runs `historyFill` and waits for its result (nil when it closed nothing).
    func runHistoryFill(peerInput: FetchMessageHistoryHoleThreadInput, direction: MessageHistoryViewRelativeHoleDirection, space: MessageHistoryHoleOperationSpace = .everywhere, file: StaticString = #filePath, line: UInt = #line) -> FetchMessageHistoryHoleResult? {
        return self.fixture.wait(self.historyFill(peerInput: peerInput, direction: direction, space: space), file: file, line: line) ?? nil
    }

    /// What a view anchored at the newest message asks for when the history from `startId` down is a hole.
    func downwardFillDirection(_ peerId: PeerId, from startId: Int32 = Int32.max - 1) -> MessageHistoryViewRelativeHoleDirection {
        return .range(start: self.messageId(peerId, startId), end: self.messageId(peerId, 1))
    }

    /// The hole of each space that contains `id`.
    func historyFillHoleSpaces(containing id: MessageId) -> [MessageHistoryHoleSpace: ClosedRange<MessageId.Id>] {
        return self.fixture.transaction { transaction -> [MessageHistoryHoleSpace: ClosedRange<MessageId.Id>] in
            return transaction.getHole(containing: id)
        } ?? [:]
    }

    /// Ids of the stored Cloud messages of `peerId` that carry `tag` (the tag's own index).
    func historyFillTaggedIds(_ peerId: PeerId, tag: MessageTags) -> [MessageId] {
        return self.fixture.transaction { transaction -> [MessageId] in
            return transaction.getMessageIndicesWithTag(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, tag: tag).map { $0.id }
        } ?? []
    }
}

/// History fills reconcile the stored messages their answer leaves out (spec 2026-10-15 §4,
/// docs/superpowers/specs/2026-10-15-difference-too-long-design.md). A fill closes its hole over
/// `filledRange`, which claims the answer holds everything stored there. For a private chat or a basic
/// group, a stored Cloud message of that range which the answer does not hold is confirmed with
/// messages.getMessages before anything is written: deleted when the server no longer has it, re-stored
/// from the fresh copy when it does. At most 200 per round, the ones nearest the edge the fill started
/// from; with more, the hole closes only that far. The fills are driven directly, as
/// ManagedMessageHistoryHoles starts them; no state manager runs.
final class HistoryFillReconciliationTests: StateSyncTestCase {
    /// The normal case: every stored message of the filled range 10...top is in the answer, so the fill
    /// sends nothing more and closes what it always closed. Stored 5 lies below the range: not looked at.
    func testFillWithNothingLeftOutSendsNoConfirmation() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [5, 10, 12])
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ])))

        let result = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(self.server.requestNames, [getHistory])
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 10 ... Int(Int32.max - 1)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 5)))
    }

    /// 11 was edited and 13 deleted during the gap. The answer [12, 10] leaves both out of the filled
    /// range 10...top, so one messages.getMessages confirms them: 13 is deleted, 11 is re-stored as the
    /// server has it now.
    func testFillDeletesWhatTheServerNoLongerHasAndRefreshesWhatItStillHas() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11, 12, 13], text: "old")
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "new"),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "new")
        ])))
        self.server.on(getMessages, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 11, peerUserId: 500, fromUserId: 500, date: self.baseDate + 11, text: "edited")
        ])))

        let result = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        XCTAssertEqual(self.server.requests.last?.payload, HistoryFillApi.getMessagesPayload(ids: [11, 13]), "exactly the two stored messages the answer left out are asked for")
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 13)), "13 is gone from the server: deleted as a received deletion deletes")
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 11))?.text, "edited")
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 12))?.text, "new")
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 10))?.text, "new")
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 10 ... Int(Int32.max - 1)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }

    /// A basic group (CloudGroup) is in scope too: its message ids are account-wide, as a private chat's.
    func testBasicGroupFillDeletesWhatTheServerNoLongerHas() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let groupId = self.seedHistoryFillGroup(800)
        let authorId = StateSyncFixture.userPeerId(500)
        self.fixture.seedPeers([StateSyncFixture.makeUser(id: authorId, accessHash: 1, firstName: "U500")])
        self.storeHistoryFillMessages(peerId: groupId, ids: [20, 21], authorId: authorId)
        self.addHistoryFillHole(groupId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            HistoryFillApi.groupMessage(id: 20, chatId: 800, fromUserId: 500, date: self.baseDate + 20)
        ])))
        self.server.on(getMessages, .result(StateSyncApi.messages([])))

        let result = self.runHistoryFill(peerInput: .direct(peerId: groupId, threadId: nil), direction: self.downwardFillDirection(groupId))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        XCTAssertNil(self.fixture.message(self.messageId(groupId, 21)))
        XCTAssertNotNil(self.fixture.message(self.messageId(groupId, 20)))
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 20 ... Int(Int32.max - 1)))
        XCTAssertEqual(self.fixture.holes(peerId: groupId), IndexSet(integersIn: 1 ... 19))
    }

    /// The history was cleared on another device during the gap: the answer is empty and all 250 stored
    /// messages are candidates. The first fill confirms the 200 nearest the top (51...250) and closes the
    /// hole only down to 51; 1...50 stay hidden. The next fill, from the leftover's top, finishes.
    func testClearedHistoryIsConfirmedTwoHundredAtATime() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: Array(1 ... 250))
        self.addHistoryFillHole(peerId)
        self.server.always(getHistory, { _ in .result(StateSyncApi.messages([])) })
        self.server.always(getMessages, { _ in .result(StateSyncApi.messages([])) })

        let first = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        XCTAssertEqual(first?.removedIndices, IndexSet(integersIn: 51 ... Int(Int32.max - 1)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 50))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 250)))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 51)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 50)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 1)))

        let second = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId, from: 50))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages, getHistory, getMessages])
        XCTAssertEqual(second?.removedIndices, IndexSet(integersIn: 1 ... 50))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet())
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 50)))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 1)))
    }

    /// The part of the filled range a partial close leaves is a hole afterwards even where it was none
    /// before: 41...60 is stored outside any hole (an earlier fill closed it, as one held across a cleared
    /// history did in truth seed 361). The fill reaches 1 from the top, confirms 51...250 gone and closes
    /// 51...top; 41...50 must stay under a hole, or nothing reaches them again and they show forever.
    func testPartialCloseLeavesItsWholeRestAHole() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: Array(1 ... 250))
        self.addHistoryFillHole(peerId)
        self.fixture.transaction { transaction -> Void in
            transaction.removeHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 41 ... 60)
        }
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 40).union(IndexSet(integersIn: 61 ... Int(Int32.max - 1))))
        self.server.always(getHistory, { _ in .result(StateSyncApi.messages([])) })
        self.server.always(getMessages, { _ in .result(StateSyncApi.messages([])) })

        let first = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(first?.removedIndices, IndexSet(integersIn: 51 ... Int(Int32.max - 1)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 50))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 45)))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId, from: 50))

        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet())
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 45)))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 1)))
    }

    /// A fill around an anchor confirms the 200 candidates nearest the anchor (1...200 around 100) and
    /// closes up to the nearest one left over (201), so the anchor itself leaves the hole.
    func testAroundFillClosesAroundItsAnchor() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: Array(1 ... 250))
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([])))
        self.server.on(getMessages, .result(StateSyncApi.messages([])))

        let result = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: .aroundId(self.messageId(peerId, 100)))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 1 ... 200))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 201 ... Int(Int32.max - 1)))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 1)))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 100)))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 200)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 201)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 250)))
    }

    /// A confirmation error is retried, and until the confirmation answers nothing is written: not the
    /// answer (12 is new), not a deletion, not the hole. Then everything lands in one transaction.
    func testConfirmationErrorWritesNothingUntilItSucceeds() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11])
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ])))
        self.server.on(getMessages, .error(code: 500, text: "INTERNAL_SERVER_ERROR"))
        self.server.on(getMessages, .hold)

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))

        XCTAssertTrue(self.server.waitForRequest(getMessages, count: 2, timeout: 10.0), "the confirmation was not retried after its error: \(self.server.requestNames)")
        XCTAssertEqual(self.server.requests.last?.payload, HistoryFillApi.getMessagesPayload(ids: [11]))
        XCTAssertTrue(results.values.isEmpty)
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 12)), "the answer was stored before the confirmation answered")
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 11)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... Int(Int32.max - 1)))

        XCTAssertTrue(self.server.release(getMessages, with: .result(StateSyncApi.messages([]))))
        results.wait { !$0.isEmpty }

        XCTAssertNil(self.fixture.message(self.messageId(peerId, 11)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 12)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }

    /// 11 is written again (an edit arrived) while its confirmation is in flight, and the server's answer
    /// leaves it out: gone. The newer write wins, so it is left alone, but it is not confirmed either: the
    /// fill closes its range as planned and opens a hole over 11 again, so the next fill that reaches it asks
    /// again. Before the fix the range closed over 11, and nothing ever asked about it again.
    func testCandidateWrittenDuringTheConfirmationIsLeftAloneUnderAHole() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11], text: "old")
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "old")
        ])))
        self.server.on(getMessages, .hold)

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))

        XCTAssertTrue(self.server.waitForRequest(getMessages), "no confirmation was sent: \(self.server.requestNames)")
        self.storeHistoryFillMessages(peerId: peerId, ids: [11], text: "edited meanwhile")
        XCTAssertTrue(self.server.release(getMessages, with: .result(StateSyncApi.messages([]))))
        results.wait { !$0.isEmpty }

        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 11))?.text, "edited meanwhile")
        var expectedHoles = IndexSet(integersIn: 1 ... 9)
        expectedHoles.insert(11)
        XCTAssertEqual(self.fixture.holes(peerId: peerId), expectedHoles, "the range closed over a candidate the server says is gone")
        XCTAssertEqual(results.values.first??.removedIndices.contains(11), false)
    }

    /// The answer is older than what arrives while the confirmation is in flight: 12, in the answer, is
    /// deleted and 10, in the answer, edited meanwhile (updates applied during the confirmation). Storing
    /// the answer after the confirmation must not undo either: 12 stays deleted and 10 keeps the edit.
    /// Candidate 11 is still confirmed and deleted, and the hole closes as planned.
    func testAnswerMessageDeletedOrEditedDuringTheConfirmationKeepsTheNewerWrite() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11, 12], text: "old")
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12, text: "answer"),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "answer")
        ])))
        self.server.on(getMessages, .hold)

        let results = self.fixture.observe(self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)))

        XCTAssertTrue(self.server.waitForRequest(getMessages), "no confirmation was sent: \(self.server.requestNames)")
        let deletedId = self.messageId(peerId, 12)
        self.fixture.transaction { transaction -> Void in
            transaction.deleteMessages([deletedId], forEachMedia: nil)
        }
        self.storeHistoryFillMessages(peerId: peerId, ids: [10], text: "edited meanwhile")
        XCTAssertTrue(self.server.release(getMessages, with: .result(StateSyncApi.messages([]))))
        results.wait { !$0.isEmpty }

        XCTAssertNil(self.fixture.message(self.messageId(peerId, 12)), "the fill's older answer re-stored a message deleted during the confirmation")
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 10))?.text, "edited meanwhile", "the fill's older answer overwrote an edit made during the confirmation")
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 11)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }

    /// The confirmation answers after the fill's own request, so where both carry a user, the
    /// confirmation's copy is the newer one: it is the one stored, and it stays stored once the fill's
    /// follow-up (what the messages reference, written in later transactions) has run too.
    ///
    /// The answer's 10 replies to 5, which is not stored, so the follow-up asks for it with a second
    /// messages.getMessages (no users in that answer) and stores 5 in the same transaction that writes the
    /// fill's peers again. Waiting for 5 is waiting for that transaction.
    func testConfirmationPeersAreStoredOverTheAnswerPeers() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11])
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, replyToMessageId: 5)
        ], users: [StateSyncApi.user(id: 500, firstName: "From the fill")])))
        self.server.on(getMessages, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 11, peerUserId: 500, fromUserId: 500, date: self.baseDate + 11)
        ], users: [StateSyncApi.user(id: 500, firstName: "From the confirmation")])))
        self.server.on(getMessages, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 5, peerUserId: 500, fromUserId: 500, date: self.baseDate + 5)
        ])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertTrue(self.server.waitForRequest(getMessages, count: 2), "the follow-up did not ask for the reply target: \(self.server.requestNames)")
        self.fixture.eventually {
            return self.fixture.message(self.messageId(peerId, 5)) != nil
        }
        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages, getMessages])
        XCTAssertEqual(self.server.requests.last?.payload, Api.functions.messages.getMessages(id: [Api.InputMessage.inputMessageReplyTo(.init(id: 10))]).1.makeData())
        XCTAssertEqual((self.fixture.peer(peerId) as? TelegramUser)?.firstName, "From the confirmation", "a later transaction of the fill wrote its older copy of the user again")
    }

    /// A fill disposed while its confirmation is in flight (its view went away) cancels the confirmation
    /// and writes nothing: not the answer (12 is new), not a deletion, not the hole.
    func testCancelledFillWritesNothing() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11])
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 12, peerUserId: 500, fromUserId: 500, date: self.baseDate + 12),
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ])))
        self.server.on(getMessages, .hold)

        let disposable = self.historyFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId)).start()
        XCTAssertTrue(self.server.waitForRequest(getMessages), "no confirmation was sent: \(self.server.requestNames)")
        guard let confirmationIndex = self.server.requests.filter({ $0.name == getMessages }).last?.index else {
            return
        }
        disposable.dispose()

        // The cancellation reaches the server asynchronously: `waitForRequest` returns as soon as the request is
        // logged, possibly before its disposable is set into the fill's chain from the Postbox queue, and a dispose
        // that lands first cancels it only when that `set` arrives. Releasing before the server has recorded the
        // cancellation races it (one failure in 20 runs, 2026-10-16).
        self.fixture.eventually(timeout: 5.0) {
            return self.server.cancelled.contains(confirmationIndex)
        }
        XCTAssertFalse(self.server.release(getMessages, with: .result(StateSyncApi.messages([]))), "the confirmation outlived its fill")
        self.server.flush()
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 12)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 11)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... Int(Int32.max - 1)))
    }

    /// An upward fill (a view at the oldest end, `.range(start <= end)`) starts at the bottom of its range.
    /// Of 250 candidates left out of an empty answer it confirms the 200 lowest (1...200) and closes up to
    /// the nearest one left over (201); 201...250 stay hidden for the next fill.
    func testUpwardFillClosesUpToTheNearestLeftover() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: Array(1 ... 250))
        self.addHistoryFillHole(peerId)
        self.server.always(getHistory, { _ in .result(StateSyncApi.messages([])) })
        self.server.always(getMessages, { _ in .result(StateSyncApi.messages([])) })

        let result = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: .range(start: self.messageId(peerId, 1), end: self.messageId(peerId, Int32.max - 1)))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        XCTAssertEqual(self.server.requests.last?.payload, HistoryFillApi.getMessagesPayload(ids: Array(1 ... 200)))
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 1 ... 200))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 201 ... Int(Int32.max - 1)))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 1)))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 200)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 201)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 250)))
    }

    /// Saved Messages' whole chat (`.direct(accountPeerId, nil)`, not a sublist) is a private chat: a
    /// stored message the answer leaves out is confirmed, and deleted when the server no longer has it.
    func testSavedMessagesWholeChatFillReconciles() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let accountPeerId = StateSyncFixture.accountPeerId
        let accountUserId = accountPeerId.id._internalGetInt64Value()
        self.storeHistoryFillMessages(peerId: accountPeerId, ids: [20, 21], authorId: accountPeerId)
        self.addHistoryFillHole(accountPeerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 20, peerUserId: accountUserId, fromUserId: accountUserId, date: self.baseDate + 20, outgoing: true)
        ])))
        self.server.on(getMessages, .result(StateSyncApi.messages([])))

        let result = self.runHistoryFill(peerInput: .direct(peerId: accountPeerId, threadId: nil), direction: self.downwardFillDirection(accountPeerId))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        XCTAssertEqual(self.server.requests.last?.payload, HistoryFillApi.getMessagesPayload(ids: [21]))
        XCTAssertNil(self.fixture.message(self.messageId(accountPeerId, 21)))
        XCTAssertNotNil(self.fixture.message(self.messageId(accountPeerId, 20)))
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 20 ... Int(Int32.max - 1)))
    }

    /// Pin: a bot with forum topics (`isForumOrMonoForum`) keeps its fills as they are, its whole chat
    /// too. Stored 10, left out of an empty answer, is neither confirmed nor touched.
    func testBotForumFillIsUnchanged() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let botId = StateSyncFixture.userPeerId(600)
        let bot = TelegramUser(
            id: botId, accessHash: .personal(1), firstName: "Bot", lastName: nil, username: nil, phone: nil, photo: [],
            botInfo: BotUserInfo(flags: [.hasForum], inlinePlaceholder: nil), restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [],
            storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil,
            profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil
        )
        self.fixture.seedPeers([bot])
        self.fixture.seedChat(peerId: botId)
        self.storeHistoryFillMessages(peerId: botId, ids: [10])
        self.addHistoryFillHole(botId)
        self.server.on(getHistory, .result(StateSyncApi.messages([])))
        // Answered, so a leaked confirmation fails the request assertion instead of stalling the fill.
        self.server.on(getMessages, .result(StateSyncApi.messages([])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: botId, threadId: nil), direction: self.downwardFillDirection(botId))

        XCTAssertEqual(self.server.requestNames, [getHistory])
        XCTAssertNotNil(self.fixture.message(self.messageId(botId, 10)))
    }

    /// An id answered as a message of another chat proves nothing about the candidate: it is neither
    /// deleted nor replaced, and nothing is stored in the other chat.
    func testIdAnsweredUnderAnotherChatIsLeftAlone() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        let otherPeerId = self.seedUserChat(600)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11], text: "old")
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10, text: "old")
        ])))
        self.server.on(getMessages, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 11, peerUserId: 600, fromUserId: 600, date: self.baseDate + 11, text: "other chat")
        ])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages])
        XCTAssertEqual(self.fixture.message(self.messageId(peerId, 11))?.text, "old")
        XCTAssertNil(self.fixture.message(self.messageId(otherPeerId, 11)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }

    /// Pin: a channel keeps its own validation. Stored 11, left out of the answer, is neither confirmed
    /// nor touched.
    func testChannelFillIsUnchanged() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let channelId = self.seedChannel(310, pts: 20, storedMessageId: nil)
        self.fixture.storeMessage(peerId: channelId, id: 10, timestamp: self.baseDate + 10, authorId: nil, text: "stored", location: .Random)
        self.fixture.storeMessage(peerId: channelId, id: 11, timestamp: self.baseDate + 11, authorId: nil, text: "stored", location: .Random)
        self.addHistoryFillHole(channelId)
        self.server.on(getHistory, .result(StateSyncApi.channelMessages(pts: 20, [
            StateSyncApi.channelPost(id: 10, channelId: 310, date: self.baseDate + 10)
        ])))

        let result = self.runHistoryFill(peerInput: .direct(peerId: channelId, threadId: nil), direction: self.downwardFillDirection(channelId))

        XCTAssertEqual(self.server.requestNames, [getHistory])
        XCTAssertNotNil(self.fixture.message(self.messageId(channelId, 11)))
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 10 ... Int(Int32.max - 1)))
        XCTAssertEqual(self.fixture.holes(peerId: channelId), IndexSet(integersIn: 1 ... 9))
    }

    /// Pin: a Saved Messages sublist is a thread (`threadId` = the saved peer). An empty answer leaves
    /// stored 20 out, and nothing is confirmed or touched.
    func testSavedMessagesSublistFillIsUnchanged() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let accountPeerId = StateSyncFixture.accountPeerId
        let savedPeerId = self.seedUserChat(700)
        self.storeHistoryFillMessages(peerId: accountPeerId, ids: [20], authorId: accountPeerId, threadId: savedPeerId.toInt64())
        self.server.on(getSavedHistory, .result(StateSyncApi.messages([])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: accountPeerId, threadId: savedPeerId.toInt64()), direction: self.downwardFillDirection(accountPeerId))

        XCTAssertEqual(self.server.requestNames, [getSavedHistory])
        XCTAssertNotNil(self.fixture.message(self.messageId(accountPeerId, 20)))
    }
}
