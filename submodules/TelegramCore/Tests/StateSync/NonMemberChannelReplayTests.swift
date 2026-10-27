import Foundation
import XCTest
import Postbox
@testable import TelegramCore

/// The replay keeps no read state for a channel the account is not a member of: `ReplayContext.applyContentOperations`
/// skips its read-state operations (`readStateOperationTargetsNonMember`), judged by the peer stored when each operation
/// comes up, so a join merged earlier in the same replay counts and a join merged later does not. The helper itself is
/// pinned by `NonMemberChannelReadStateTests`; these pin that the replay asks it, and when. Driven through
/// `FinalStateReplayer.applyReplay` over the harness's Postbox, without a state manager.
final class NonMemberChannelReplayTests: StateSyncTestCase {
    private let channelId: Int64 = 300

    private var channel: PeerId {
        return StateSyncFixture.channelPeerId(self.channelId)
    }

    /// A stored broadcast channel the account has left, holding `nonMemberChannelReadState` (what opening its chat
    /// installs), and the account record a verified replay checks against.
    private func seedLeftChannel() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let channel = StateSyncFixture.makeChannel(id: self.channel, accessHash: 1, title: "C\(self.channelId)", participationStatus: .left)
        self.fixture.seedChannel(channel, state: ChannelState(pts: 50, invalidatedPts: nil, synchronizedUntilMessageId: nil))
        self.fixture.transaction { transaction -> Void in
            transaction.resetIncomingReadStates([self.channel: [Namespaces.Message.Cloud: nonMemberChannelReadState]])
        }
    }

    /// A final state over a snapshot at pts 100 holding exactly `operations`, in this order.
    private func finalState(_ operations: [AccountStateMutationOperation]) -> AccountFinalState {
        let initialState = AccountInitialState(state: self.state(pts: 100), peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: [:], peerChatInfos: [:], locallyGeneratedMessageTimestamps: [:], channelsToPollExplicitely: Set())
        var state = AccountMutableState(initialState: initialState, initialPeers: [:], initialReferencedReplyMessageIds: ReferencedReplyMessageIds(), initialReferencedGeneralMessageIds: Set(), initialStoredMessages: Set(), initialStoredStories: [:], initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:], initialSentScheduledMessageIds: Set())
        state.operations.append(contentsOf: operations)
        return AccountFinalState(state: state, shouldPoll: false, incomplete: false, discard: false)
    }

    /// Replays `finalState` verified; true when the replay was applied.
    private func replay(_ finalState: AccountFinalState) -> Bool {
        let replayer = FinalStateReplayer(accountManager: self.fixture.accountManager, postbox: self.fixture.postbox, accountPeerId: StateSyncFixture.accountPeerId, encryptionProvider: UnusedEncryptionProvider(), auxiliaryMethods: StateSyncFixture.makeAuxiliaryMethods(), messagesRemovedContext: MessagesRemovedContext())
        return self.fixture.transaction { transaction -> Bool in
            return replayer.applyReplay(finalState, policy: .verified, removePossiblyDeliveredMessagesUniqueIds: [:], transaction: transaction) != nil
        } ?? false
    }

    private func cloudReadState() -> PeerReadState? {
        return self.fixture.transaction { transaction -> PeerReadState? in
            return transaction.getPeerReadStates(self.channel)?.first(where: { $0.0 == Namespaces.Message.Cloud })?.1
        } ?? nil
    }

    private func participationStatus() -> TelegramChannelParticipationStatus? {
        return self.fixture.transaction { transaction -> TelegramChannelParticipationStatus? in
            return (transaction.getPeer(self.channel) as? TelegramChannel)?.participationStatus
        } ?? nil
    }

    func testReadStateOperationsForAChannelTheAccountHasLeftAreSkipped() {
        self.seedLeftChannel()

        let applied = self.replay(self.finalState([
            .ReadInbox(self.messageId(self.channel, 10)),
            .ResetReadState(peerId: self.channel, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 20, maxOutgoingReadId: 5, maxKnownId: 30, count: 4, markedUnread: false),
            .ResetIncomingReadState(groupId: .root, peerId: self.channel, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 25, count: 2, pts: 51),
            .UpdatePeerChatUnreadMark(self.channel, nil, Namespaces.Message.Cloud, true)
        ]))

        XCTAssertTrue(applied)
        XCTAssertEqual(self.cloudReadState(), nonMemberChannelReadState, "each of the four would have written the read state")
    }

    func testAJoinMergedEarlierInTheReplayAppliesTheNextReadState() {
        self.seedLeftChannel()

        let applied = self.replay(self.finalState([
            .MergeApiChats([StateSyncApi.broadcastChannel(id: self.channelId)]),
            .ResetReadState(peerId: self.channel, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 20, maxOutgoingReadId: 5, maxKnownId: 30, count: 4, markedUnread: false)
        ]))

        XCTAssertTrue(applied)
        XCTAssertEqual(self.participationStatus(), .member)
        XCTAssertEqual(self.cloudReadState(), .idBased(maxIncomingReadId: 20, maxOutgoingReadId: 5, maxKnownId: 30, count: 4, markedUnread: false))
    }

    func testAJoinMergedLaterInTheReplayDoesNotApplyAnEarlierReadState() {
        self.seedLeftChannel()

        let applied = self.replay(self.finalState([
            .ResetReadState(peerId: self.channel, namespace: Namespaces.Message.Cloud, maxIncomingReadId: 20, maxOutgoingReadId: 5, maxKnownId: 30, count: 4, markedUnread: false),
            .MergeApiChats([StateSyncApi.broadcastChannel(id: self.channelId)])
        ]))

        XCTAssertTrue(applied)
        XCTAssertEqual(self.participationStatus(), .member)
        // The channel was still `.left` when its read state came up; the join's own validation fetches it later.
        XCTAssertEqual(self.cloudReadState(), nonMemberChannelReadState)
    }
}
