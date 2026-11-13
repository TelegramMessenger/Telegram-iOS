import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramCore

final class SupportReadStateTests: XCTestCase {
    private let accountPeerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1))
    private let userId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(2))

    private func user(id: PeerId, firstName: String?, lastName: String? = nil) -> TelegramUser {
        return TelegramUser(id: id, accessHash: nil, firstName: firstName, lastName: lastName, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)
    }

    private func send(deferred: Bool = false, threadId: Int64? = nil, replyThreadId: Int64? = nil) -> SupportSendReadInfo {
        return SupportSendReadInfo(isDeferred: deferred, threadId: threadId, replyThreadId: replyThreadId)
    }

    func testOnlyASupportAccountOpensAtTheEnd() {
        XCTAssertTrue(supportOpensChatAtEnd(isSupportUser: true, hasTag: false, peerId: self.userId, accountPeerId: self.accountPeerId))
        XCTAssertFalse(supportOpensChatAtEnd(isSupportUser: false, hasTag: false, peerId: self.userId, accountPeerId: self.accountPeerId))
    }

    func testTaggedListsCustomContentsAndSavedMessagesKeepTheirAnchor() {
        XCTAssertFalse(supportOpensChatAtEnd(isSupportUser: true, hasTag: true, peerId: self.userId, accountPeerId: self.accountPeerId))
        XCTAssertFalse(supportOpensChatAtEnd(isSupportUser: true, hasTag: false, peerId: nil, accountPeerId: self.accountPeerId))
        XCTAssertFalse(supportOpensChatAtEnd(isSupportUser: true, hasTag: false, peerId: self.accountPeerId, accountPeerId: self.accountPeerId))
    }

    func testSendReadsTheChat() {
        XCTAssertEqual(supportSendReadTargets(peerHasThreads: false, sends: [self.send()]), [.chat])
    }

    func testScheduledAndQuickReplySendsDoNotRead() {
        XCTAssertEqual(supportSendReadTargets(peerHasThreads: false, sends: [self.send(deferred: true)]), [])
        XCTAssertEqual(supportSendReadTargets(peerHasThreads: true, sends: [self.send(deferred: true, threadId: 5)]), [])
        XCTAssertTrue(supportSendIsDeferred(attributes: [OutgoingScheduleInfoMessageAttribute(scheduleTime: 100, repeatPeriod: nil)]))
        XCTAssertTrue(supportSendIsDeferred(attributes: [OutgoingQuickReplyMessageAttribute(shortcut: "a")]))
        XCTAssertFalse(supportSendIsDeferred(attributes: []))
    }

    func testABatchWithOneRealSendReads() {
        XCTAssertEqual(supportSendReadTargets(peerHasThreads: false, sends: [self.send(deferred: true), self.send()]), [.chat])
    }

    func testAForumOrMonoforumSendReadsItsThread() {
        XCTAssertEqual(supportSendReadTargets(peerHasThreads: true, sends: [self.send(threadId: 5)]), [.thread(5)])
        XCTAssertEqual(supportSendReadTargets(peerHasThreads: true, sends: [self.send(replyThreadId: 7)]), [.thread(7)])
        XCTAssertEqual(supportSendReadTargets(peerHasThreads: true, sends: [self.send(threadId: 5, replyThreadId: 7)]), [.thread(5)])
        XCTAssertEqual(supportSendReadTargets(peerHasThreads: true, sends: [self.send()]), [.chat])
    }

    func testAThreadIdInAPeerWithoutThreadsReadsTheChat() {
        XCTAssertEqual(supportSendReadTargets(peerHasThreads: false, sends: [self.send(threadId: 5, replyThreadId: 7)]), [.chat])
    }

    func testEachTargetIsReadOnce() {
        XCTAssertEqual(supportSendReadTargets(peerHasThreads: true, sends: [self.send(threadId: 5), self.send(threadId: 5), self.send(threadId: 6), self.send(), self.send()]), [.thread(5), .thread(6), .chat])
    }

    func testOnlyADeletedUserOnASupportAccountClearsUnread() {
        let deleted = self.user(id: self.userId, firstName: nil)
        let named = self.user(id: self.userId, firstName: "A")
        let lastNameOnly = self.user(id: self.userId, firstName: nil, lastName: "B")
        XCTAssertTrue(supportClearsUnread(isSupportAccount: true, peer: deleted))
        XCTAssertFalse(supportClearsUnread(isSupportAccount: false, peer: deleted))
        XCTAssertFalse(supportClearsUnread(isSupportAccount: true, peer: named))
        XCTAssertFalse(supportClearsUnread(isSupportAccount: true, peer: lastNameOnly))
        XCTAssertFalse(supportClearsUnread(isSupportAccount: true, peer: nil))
    }

    func testClearedStateHasNothingUnreadAndCountsNothingNew() {
        let cleared = supportClearedReadState(current: .idBased(maxIncomingReadId: 5, maxOutgoingReadId: 9, maxKnownId: 20, count: 15, markedUnread: true), topMessageId: 20)
        XCTAssertEqual(cleared, .idBased(maxIncomingReadId: 20, maxOutgoingReadId: 9, maxKnownId: Int32.max - 1, count: 0, markedUnread: false))
        XCTAssertFalse(cleared.isUnread)
    }

    func testClearedStateNeverMovesTheReadMarkBack() {
        XCTAssertEqual(supportClearedReadState(current: .idBased(maxIncomingReadId: 30, maxOutgoingReadId: 1, maxKnownId: 30, count: 0, markedUnread: false), topMessageId: 20), .idBased(maxIncomingReadId: 30, maxOutgoingReadId: 1, maxKnownId: Int32.max - 1, count: 0, markedUnread: false))
        XCTAssertEqual(supportClearedReadState(current: nil, topMessageId: nil), .idBased(maxIncomingReadId: 0, maxOutgoingReadId: 0, maxKnownId: Int32.max - 1, count: 0, markedUnread: false))
    }

    func testClearingIsStable() {
        let cleared = supportClearedReadState(current: .idBased(maxIncomingReadId: 5, maxOutgoingReadId: 9, maxKnownId: 20, count: 15, markedUnread: true), topMessageId: 20)
        XCTAssertEqual(supportClearedReadState(current: cleared, topMessageId: 20), cleared)
    }

    func testServerReadStateOperationsForADeletedUserAreSkipped() {
        let deleted = self.user(id: self.userId, firstName: nil)
        let getPeer: (PeerId) -> Peer? = { _ in deleted }
        XCTAssertTrue(readStateOperationTargetsDeletedUser(.ReadInbox(MessageId(peerId: self.userId, namespace: Namespaces.Message.Cloud, id: 3)), getPeer: getPeer))
        XCTAssertTrue(readStateOperationTargetsDeletedUser(.UpdatePeerChatUnreadMark(self.userId, nil, Namespaces.Message.Cloud, true), getPeer: getPeer))
        XCTAssertFalse(readStateOperationTargetsDeletedUser(.UpdatePeerChatUnreadMark(self.userId, 5, Namespaces.Message.Cloud, true), getPeer: getPeer))
    }

    func testServerReadStateOperationsForOtherPeersAreKept() {
        let named = self.user(id: self.userId, firstName: "A")
        XCTAssertFalse(readStateOperationTargetsDeletedUser(.ReadInbox(MessageId(peerId: self.userId, namespace: Namespaces.Message.Cloud, id: 3)), getPeer: { _ in named }))
        XCTAssertFalse(readStateOperationTargetsDeletedUser(.ReadInbox(MessageId(peerId: self.userId, namespace: Namespaces.Message.Cloud, id: 3)), getPeer: { _ in nil }))
    }

    private func dividerBoundary(maxIncomingReadId: Int32, maxKnownId: Int32 = 9, count: Int32 = 0, markedUnread: Bool = false, top: Int32?) -> Int32? {
        let state = PeerReadState.idBased(maxIncomingReadId: maxIncomingReadId, maxOutgoingReadId: 0, maxKnownId: maxKnownId, count: count, markedUnread: markedUnread)
        return supportUnreadDividerBoundary(state: CombinedPeerReadState(states: [(Namespaces.Message.Cloud, state)]), topMessageId: top)
    }

    func testUnreadChatKeepsTheDividerAfterItsReadMark() {
        XCTAssertEqual(self.dividerBoundary(maxIncomingReadId: 7, count: 2, top: 9), 7)
        XCTAssertEqual(self.dividerBoundary(maxIncomingReadId: 7, markedUnread: true, top: 9), 7)
    }

    func testReadChatPutsTheDividerAfterItsNewestMessage() {
        XCTAssertEqual(self.dividerBoundary(maxIncomingReadId: 7, top: 9), 9)
        XCTAssertEqual(self.dividerBoundary(maxIncomingReadId: 9, top: 7), 9)
        XCTAssertEqual(self.dividerBoundary(maxIncomingReadId: 7, top: nil), 7)
    }

    func testChatKeepingNoReadStateNeverGetsADivider() {
        XCTAssertEqual(self.dividerBoundary(maxIncomingReadId: 0, maxKnownId: Int32.max - 1, top: 9), Int32.max)
    }

    func testSequentialBatchesFinishLongSweepsWithoutDeepeningTheStack() {
        let finished = self.expectation(description: "finished")
        let batchCount = 20000
        let ran = Atomic<Int>(value: 0)
        let disposable = supportSequentialBatches(initial: 0, pause: 0.0, queue: Queue(), batch: { index -> Signal<Int?, NoError> in
            let _ = ran.modify { $0 + 1 }
            return .single(index + 1 < batchCount ? index + 1 : nil)
        }).start(completed: {
            finished.fulfill()
        })
        self.wait(for: [finished], timeout: 60.0)
        disposable.dispose()
        XCTAssertEqual(ran.with { $0 }, batchCount)
    }

    func testDisposingSequentialBatchesStopsTheSweep() {
        let queue = Queue()
        let ran = Atomic<Int>(value: 0)
        let disposable = supportSequentialBatches(initial: 0, pause: 0.05, queue: queue, batch: { index -> Signal<Int?, NoError> in
            let _ = ran.modify { $0 + 1 }
            return .single(index + 1)
        }).start()
        disposable.dispose()
        let settled = self.expectation(description: "settled")
        queue.after(0.3, {
            settled.fulfill()
        })
        self.wait(for: [settled], timeout: 5.0)
        XCTAssertEqual(ran.with { $0 }, 1)
    }

    func testNoCloudReadStateFallsBackToTheStockDivider() {
        XCTAssertNil(supportUnreadDividerBoundary(state: nil, topMessageId: 9))
        XCTAssertNil(supportUnreadDividerBoundary(state: CombinedPeerReadState(states: []), topMessageId: 9))
    }
}
