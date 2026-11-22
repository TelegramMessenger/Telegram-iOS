import Foundation
import XCTest
import SwiftSignalKit
import Postbox
@testable import TelegramCore

/// `FinalStateReplayer.applyReplay` (state-sync seam 5), the one way a final state is replayed, driven directly over
/// the harness's Postbox without a state manager. An applied replay records the messages it deleted in the
/// `MessagesRemovedContext` it was given, inside its own transaction; a replay that `ReplayPolicy.verifiesTransaction`
/// refuses writes nothing and records nothing, and the channel reset's policy replays the same state unverified.
final class FinalStateReplayerTests: StateSyncTestCase {
    private func makeReplayer(_ messagesRemovedContext: MessagesRemovedContext) -> FinalStateReplayer {
        return FinalStateReplayer(accountManager: self.fixture.accountManager, postbox: self.fixture.postbox, accountPeerId: StateSyncFixture.accountPeerId, encryptionProvider: UnusedEncryptionProvider(), auxiliaryMethods: StateSyncFixture.makeAuxiliaryMethods(), messagesRemovedContext: messagesRemovedContext)
    }

    /// A final state built over a snapshot whose account state is `snapshot`: it deletes `id` and moves the account
    /// state to the next pts.
    private func finalState(snapshot: AuthorizedAccountState.State, deleting id: MessageId) -> AccountFinalState {
        let initialState = AccountInitialState(state: snapshot, peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: [:], peerChatInfos: [:], locallyGeneratedMessageTimestamps: [:], channelsToPollExplicitely: Set())
        var state = AccountMutableState(initialState: initialState, initialPeers: [:], initialReferencedReplyMessageIds: ReferencedReplyMessageIds(), initialReferencedGeneralMessageIds: Set(), initialStoredMessages: Set(), initialStoredStories: [:], initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:], initialSentScheduledMessageIds: Set())
        state.deleteMessages([id])
        state.updateState(AuthorizedAccountState.State(pts: snapshot.pts + 1, qts: snapshot.qts, date: snapshot.date, seq: snapshot.seq))
        return AccountFinalState(state: state, shouldPoll: false, incomplete: false, discard: false)
    }

    func testAnAppliedReplayRecordsWhatItDeleted() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let channel = self.seedChannel(300, pts: 50, storedMessageId: 10)
        let deletedId = self.messageId(channel, 10)
        let removed = MessagesRemovedContext()
        let replayer = self.makeReplayer(removed)
        let finalState = self.finalState(snapshot: self.state(pts: 100), deleting: deletedId)

        let deletedIds = self.fixture.transaction { transaction -> [DeletedMessageId]? in
            return replayer.applyReplay(finalState, policy: .verified, removePossiblyDeliveredMessagesUniqueIds: [:], transaction: transaction)?.deletedMessageIds
        } ?? nil

        XCTAssertEqual(deletedIds, [DeletedMessageId.messageId(deletedId)])
        XCTAssertNil(self.fixture.message(deletedId))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 101)
        XCTAssertEqual(removed.synchronouslyIsMessageDeletedRemotely(ids: [deletedId]), [deletedId])
        XCTAssertEqual(removed.synchronouslyIsMessageDeletedInteractively(ids: [deletedId]), [deletedId])
    }

    func testAVerifiedReplayOfAStaleStateIsRefusedAndTheChannelResetPolicyReplaysIt() {
        self.fixture.seedAccount(state: self.state(pts: 105))
        let channel = self.seedChannel(300, pts: 50, storedMessageId: 10)
        let deletedId = self.messageId(channel, 10)
        let removed = MessagesRemovedContext()
        let replayer = self.makeReplayer(removed)
        // Built over pts 100; the stored account state has moved on to 105 since.
        let finalState = self.finalState(snapshot: self.state(pts: 100), deleting: deletedId)

        let refused = self.fixture.transaction { transaction -> Bool in
            return replayer.applyReplay(finalState, policy: .verified, removePossiblyDeliveredMessagesUniqueIds: [:], transaction: transaction) == nil
        }
        XCTAssertEqual(refused, true)
        XCTAssertNotNil(self.fixture.message(deletedId))
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 105)
        XCTAssertEqual(removed.synchronouslyIsMessageDeletedRemotely(ids: [deletedId]), [])
        XCTAssertEqual(removed.synchronouslyIsMessageDeletedInteractively(ids: [deletedId]), [])

        let deletedIds = self.fixture.transaction { transaction -> [DeletedMessageId]? in
            return replayer.applyReplay(finalState, policy: .unverifiedChannelReset, removePossiblyDeliveredMessagesUniqueIds: [:], transaction: transaction)?.deletedMessageIds
        } ?? nil
        XCTAssertEqual(deletedIds, [DeletedMessageId.messageId(deletedId)])
        XCTAssertNil(self.fixture.message(deletedId))
        XCTAssertEqual(removed.synchronouslyIsMessageDeletedRemotely(ids: [deletedId]), [deletedId])
    }
}
