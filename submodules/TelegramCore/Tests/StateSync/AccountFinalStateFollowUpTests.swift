import Foundation
import XCTest
import Postbox
@testable import TelegramCore

/// `AccountFinalState.followUp`, the seam `processBatch` switches on after a pushed batch (seam 4 of the
/// state-sync refactor). It maps the interpreter's three flags exactly as the completion's branches did before the
/// seam: `discard` wins, then `shouldPoll`, then `incomplete`.
final class AccountFinalStateFollowUpTests: XCTestCase {
    private func finalState(shouldPoll: Bool, incomplete: Bool, discard: Bool) -> AccountFinalState {
        let initialState = AccountInitialState(state: AuthorizedAccountState.State(pts: 100, qts: 5, date: 1_700_000_000, seq: 10), peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: [:], peerChatInfos: [:], locallyGeneratedMessageTimestamps: [:], channelsToPollExplicitely: Set())
        let state = AccountMutableState(initialState: initialState, initialPeers: [:], initialReferencedReplyMessageIds: ReferencedReplyMessageIds(), initialReferencedGeneralMessageIds: Set(), initialStoredMessages: Set(), initialStoredStories: [:], initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:], initialSentScheduledMessageIds: Set())
        return AccountFinalState(state: state, shouldPoll: shouldPoll, incomplete: incomplete, discard: discard)
    }

    func testFollowUpForEveryFlagCombination() {
        let table: [(shouldPoll: Bool, incomplete: Bool, discard: Bool, followUp: AccountFinalState.FollowUp)] = [
            (false, false, false, .apply),
            (false, true, false, .applyThenAwaitGap),
            (true, false, false, .applyThenPoll),
            (true, true, false, .applyThenPoll),
            (false, false, true, .discard),
            (false, true, true, .discard),
            (true, false, true, .discard),
            (true, true, true, .discard),
        ]
        for row in table {
            let followUp = self.finalState(shouldPoll: row.shouldPoll, incomplete: row.incomplete, discard: row.discard).followUp
            XCTAssertEqual(followUp, row.followUp, "shouldPoll \(row.shouldPoll), incomplete \(row.incomplete), discard \(row.discard)")
        }
    }
}
