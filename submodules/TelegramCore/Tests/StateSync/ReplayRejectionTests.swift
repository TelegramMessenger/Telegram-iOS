import Foundation
import XCTest
import Postbox
@testable import TelegramCore

/// `ReplayRejection` (stage 5, task V1): the three checks a verified replay runs before it writes anything, with their
/// precedence (which one is reported when several fail), driven over the harness's Postbox without a state manager;
/// and the predicates they are made of. A final state is built as `FinalStateReplayerTests` builds one, its
/// operations appended directly.
final class ReplayRejectionTests: StateSyncTestCase {
    /// A final state over a snapshot whose account state is `snapshot`, taken for `peerIds` with `channelStates`. It
    /// holds no peers and exactly `operations`.
    private func finalState(snapshot: AuthorizedAccountState.State, peerIds: Set<PeerId> = Set(), channelStates: [PeerId: AccountStateChannelState] = [:], operations: [AccountStateMutationOperation]) -> AccountMutableState {
        let initialState = AccountInitialState(state: snapshot, peerIds: peerIds, peerIdsRequiringLocalChatState: Set(), channelStates: channelStates, peerChatInfos: [:], locallyGeneratedMessageTimestamps: [:], channelsToPollExplicitely: Set())
        var state = AccountMutableState(initialState: initialState, initialPeers: [:], initialReferencedReplyMessageIds: ReferencedReplyMessageIds(), initialReferencedGeneralMessageIds: Set(), initialStoredMessages: Set(), initialStoredStories: [:], initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:], initialSentScheduledMessageIds: Set())
        state.operations.append(contentsOf: operations)
        return state
    }

    /// `ReplayRejection.verify` of `finalState`, run in a transaction over the stored state.
    private func verify(_ finalState: AccountMutableState) -> ReplayRejection? {
        return self.fixture.transaction { transaction -> ReplayRejection? in
            return ReplayRejection.verify(transaction, finalState: finalState)
        } ?? nil
    }

    func testMissingPeersAreReportedOverAMovedAccountState() {
        self.fixture.seedAccount(state: self.state(pts: 105))
        let user = StateSyncFixture.userPeerId(2000)
        // The account state moved as well (stored 105, snapshot 100): the missing peer is reported over it, and only
        // it. The precedence is what this pins: the result does not show whether any stored state was read.
        let finalState = self.finalState(snapshot: self.state(pts: 100), peerIds: [user], operations: [.UpdateState(self.state(pts: 101))])

        XCTAssertEqual(self.verify(finalState), .missingPeers([user]))
    }

    func testAMovedAccountStateIsReportedOverAMovedChannel() {
        self.fixture.seedAccount(state: self.state(pts: 105))
        let channel = self.seedChannel(300, pts: 50, storedMessageId: nil)
        // Both checks fail: the stored account state is 105 against the snapshot's 100, the channel 50 against 40.
        let finalState = self.finalState(snapshot: self.state(pts: 100), channelStates: [channel: AccountStateChannelState(pts: 40)], operations: [.UpdateState(self.state(pts: 101)), .UpdateChannelState(channel, 41)])

        XCTAssertEqual(self.verify(finalState), .accountStateChanged)
    }

    func testChannelsWhosePtsMovedAreReported() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let moved = self.seedChannel(300, pts: 50, storedMessageId: nil)
        let unmoved = self.seedChannel(301, pts: 60, storedMessageId: nil)
        let finalState = self.finalState(snapshot: self.state(pts: 100), channelStates: [moved: AccountStateChannelState(pts: 40), unmoved: AccountStateChannelState(pts: 60)], operations: [.UpdateState(self.state(pts: 101)), .UpdateChannelState(moved, 41), .UpdateChannelState(unmoved, 61)])

        XCTAssertEqual(self.verify(finalState), .channelStateChanged([moved]))
    }

    func testAStateNothingMovedUnderIsAccepted() {
        // The stored account state moved (105 against 100), but the replay does not move it: no `.UpdateState`.
        self.fixture.seedAccount(state: self.state(pts: 105))
        // A channel with no stored state, and none in the snapshot either.
        let channel = self.seedChannel(300, pts: nil, storedMessageId: nil)
        let finalState = self.finalState(snapshot: self.state(pts: 100), operations: [.UpdateChannelState(channel, 1)])

        XCTAssertNil(self.verify(finalState))
    }

    func testStoredStatesMatchTheSnapshotOnlyWhenEqual() {
        let snapshot = self.state(pts: 100)
        XCTAssertFalse(ReplayRejection.accountStateMatches(stored: nil, snapshot: snapshot))
        XCTAssertTrue(ReplayRejection.accountStateMatches(stored: self.state(pts: 100), snapshot: snapshot))
        XCTAssertFalse(ReplayRejection.accountStateMatches(stored: self.state(pts: 105), snapshot: snapshot))

        let stored = ChannelState(pts: 40, invalidatedPts: nil, synchronizedUntilMessageId: nil)
        XCTAssertTrue(ReplayRejection.channelStateMatches(stored: stored, snapshot: AccountStateChannelState(pts: 40)))
        XCTAssertFalse(ReplayRejection.channelStateMatches(stored: stored, snapshot: AccountStateChannelState(pts: 41)))
        XCTAssertTrue(ReplayRejection.channelStateMatches(stored: nil, snapshot: nil))
        XCTAssertFalse(ReplayRejection.channelStateMatches(stored: nil, snapshot: AccountStateChannelState(pts: 40)))
        XCTAssertFalse(ReplayRejection.channelStateMatches(stored: stored, snapshot: nil))
        // A stored state that is not a `ChannelState` matches neither a snapshot pts nor a missing snapshot state.
        let regular = RegularChatState(invalidatedPts: nil)
        XCTAssertFalse(ReplayRejection.channelStateMatches(stored: regular, snapshot: AccountStateChannelState(pts: 40)))
        XCTAssertFalse(ReplayRejection.channelStateMatches(stored: regular, snapshot: nil))
    }

    func testStatesMovedByCollectsTheStateOperations() {
        let user = StateSyncFixture.userPeerId(2000)
        let c = StateSyncFixture.channelPeerId(300)
        let d = StateSyncFixture.channelPeerId(301)
        let operations: [AccountStateMutationOperation] = [.ReadInbox(self.messageId(user, 5)), .UpdateChannelState(c, 1), .UpdateChannelState(d, 2), .UpdateChannelState(c, 3)]

        let moved = ReplayRejection.statesMoved(by: operations)
        XCTAssertFalse(moved.accountState)
        XCTAssertEqual(moved.channels, [c, d])

        let movedWithAccountState = ReplayRejection.statesMoved(by: operations + [.UpdateState(self.state(pts: 101))])
        XCTAssertTrue(movedWithAccountState.accountState)
        XCTAssertEqual(movedWithAccountState.channels, [c, d])
    }
}
