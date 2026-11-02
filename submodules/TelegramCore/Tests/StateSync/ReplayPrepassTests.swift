import Foundation
import XCTest
import Postbox
@testable import TelegramCore

/// `ReplayPrepass.prepare`, called directly inside a harness Postbox transaction without a state manager: what
/// `replayFinalState` reads before it applies any operation of a final state. The operations are appended to the final
/// state as built, unbatched, which is what `prepare` scans.
final class ReplayPrepassTests: StateSyncTestCase {
    /// A final state over an empty snapshot holding exactly `operations`, in this order, and a previous-state hole mark
    /// in the cloud namespace of each of `holesFromPreviousState`.
    private func finalState(_ operations: [AccountStateMutationOperation], holesFromPreviousState: [PeerId] = []) -> AccountFinalState {
        let initialState = AccountInitialState(state: self.state(pts: 100), peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: [:], peerChatInfos: [:], locallyGeneratedMessageTimestamps: [:], channelsToPollExplicitely: Set())
        var state = AccountMutableState(initialState: initialState, initialPeers: [:], initialReferencedReplyMessageIds: ReferencedReplyMessageIds(), initialReferencedGeneralMessageIds: Set(), initialStoredMessages: Set(), initialStoredStories: [:], initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:], initialSentScheduledMessageIds: Set())
        state.operations.append(contentsOf: operations)
        for peerId in holesFromPreviousState {
            state.setNeedsHoleFromPreviousState(peerId: peerId, namespace: Namespaces.Message.Cloud)
        }
        return AccountFinalState(state: state, shouldPoll: false, incomplete: false, discard: false)
    }

    private func prepare(_ finalState: AccountFinalState) -> ReplayPrepass? {
        return self.fixture.transaction { transaction -> ReplayPrepass in
            return ReplayPrepass.prepare(transaction: transaction, finalState: finalState)
        }
    }

    /// A cloud message `id` in the chat with `peerId`, in `StateSyncFixture.storeMessage`'s shape.
    private func message(_ peerId: PeerId, _ id: Int32, timestamp: Int32, authorId: PeerId?, incoming: Bool) -> StoreMessage {
        let flags: StoreMessageFlags = incoming ? [.Incoming] : []
        return StoreMessage(id: self.messageId(peerId, id), customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: nil, timestamp: timestamp, flags: flags, tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: authorId, text: "m\(id)", attributes: [], media: [])
    }

    func testPrepareTakesEachPeersHighestCloudReadMaximum() {
        let peerId = StateSyncFixture.userPeerId(2000)
        let readInboxPeerId = StateSyncFixture.userPeerId(2001)
        let resetIncomingPeerId = StateSyncFixture.userPeerId(2002)
        let finalState = self.finalState([
            .ReadInbox(self.messageId(peerId, 5)),
            .ResetReadState(peerId: peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 9, maxOutgoingReadId: 0, maxKnownId: 9, count: 0, markedUnread: nil),
            .ResetIncomingReadState(groupId: .root, peerId: peerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 7, count: 0, pts: 1),
            // A higher id in another namespace is not a cloud read maximum.
            .ReadInbox(MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: 20)),
            // `.ReadInbox` alone: the 12 raises the earlier 6, and the later 8 does not lower it.
            .ReadInbox(self.messageId(readInboxPeerId, 6)),
            .ReadInbox(self.messageId(readInboxPeerId, 12)),
            .ReadInbox(self.messageId(readInboxPeerId, 8)),
            // `.ResetIncomingReadState` raises an earlier `.ReadInbox`.
            .ReadInbox(self.messageId(resetIncomingPeerId, 10)),
            .ResetIncomingReadState(groupId: .root, peerId: resetIncomingPeerId, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 15, count: 0, pts: 2)
        ])

        let prepass = self.prepare(finalState)

        // Each value is decided by a different operation: `.ResetReadState`, `.ReadInbox`, `.ResetIncomingReadState`.
        XCTAssertEqual(prepass?.readInboxCloudMessageIds, [peerId: 9, readInboxPeerId: 12, resetIncomingPeerId: 15])
    }

    func testPrepareListsOnlyIncomingTopMessagesThatAreNotStored() {
        let user = self.seedUserChat(2000)
        self.fixture.storeMessage(peerId: user, id: 10, timestamp: self.baseDate + 3, authorId: user, text: "stored")
        let finalState = self.finalState([
            .AddMessages([
                self.message(user, 9, timestamp: self.baseDate + 2, authorId: user, incoming: true),
                self.message(user, 10, timestamp: self.baseDate + 3, authorId: user, incoming: true),
                self.message(user, 11, timestamp: self.baseDate + 1, authorId: user, incoming: true),
                self.message(user, 12, timestamp: self.baseDate + 4, authorId: StateSyncFixture.accountPeerId, incoming: false)
            ], .UpperHistoryBlock),
            // Not at the top of its history: neither scanned for activity nor reported.
            .AddMessages([self.message(user, 13, timestamp: self.baseDate + 5, authorId: user, incoming: true)], .Random)
        ])

        let prepass = self.prepare(finalState)

        XCTAssertEqual(prepass?.addedIncomingMessageIds, [self.messageId(user, 9), self.messageId(user, 11)])
        // The author's activity is the highest timestamp of its three messages at the top: the stored message
        // 10's +3 raises the earlier 9's +2 (a message already stored still counts), and the later 11's +1 does not
        // lower it.
        XCTAssertEqual(prepass?.peerActivityTimestamps, [user: self.baseDate + 3])
    }

    func testPrepareStartsEachPreviousStateHoleAboveTheSynchronizedOrStoredTop() {
        let synchronizedChannel = StateSyncFixture.channelPeerId(300)
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: synchronizedChannel, accessHash: 1, title: "C300"), state: ChannelState(pts: 50, invalidatedPts: nil, synchronizedUntilMessageId: 20))
        self.fixture.storeMessage(peerId: synchronizedChannel, id: 10, timestamp: self.baseDate, authorId: nil, text: "stored")
        let storedTopChannel = self.seedChannel(301, pts: 50, storedMessageId: 10)
        let emptyUserChat = self.seedUserChat(2000)
        let finalState = self.finalState([], holesFromPreviousState: [synchronizedChannel, storedTopChannel, emptyUserChat])

        let prepass = self.prepare(finalState)

        // A set: the order is the iteration order of `namespacesWithHolesFromPreviousState`.
        XCTAssertEqual(prepass?.holesFromPreviousStateMessageIds.count, 3)
        XCTAssertEqual(prepass.map { Set($0.holesFromPreviousStateMessageIds) }, Set([
            self.messageId(synchronizedChannel, 21),
            self.messageId(storedTopChannel, 11),
            self.messageId(emptyUserChat, 1)
        ]))
    }
}
