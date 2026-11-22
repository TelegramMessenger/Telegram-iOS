import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// `updatePinnedForumTopics` without an order schedules a poll of its channel (G1,
/// `ChannelRecoveryRequests.requestPoll(_:ptsHint:)`), and the poll needs the channel's peer in the batch's state.
/// The batch's snapshot loads the update's peer when it is stored (`loadOnlyPeerIdsFromUpdates`,
/// Sync/SyncSnapshot.swift), so the stored channel is polled even when the container carries no `chats`. Until then
/// only the container's `chats` brought it in (ChannelPollSiteTests pins that case); without them the poll logged
/// "can't poll channel ...: no peer found" and asked nothing.
///
/// The peer is load-only: the replay does not require it. Listed in `Api.Update.peerIds` (B5 as first written), a
/// channel that is neither stored nor in the batch's `chats` made the replay's verification (now
/// `ReplayRejection.verify`) refuse the batch, and on the difference path a refused replay polled again at once, to
/// the same refusal.
final class PinnedForumTopicsPeerTests: StateSyncTestCase {
    /// The `updates.getChannelDifference` `pollChannel` sends for broadcast channel `channelId` (access hash 1, as
    /// `seedChannel` stores it) from `pts`. `pollChannel`'s limit is 2 in DEBUG builds, 100 otherwise.
    private func channelDifferencePayload(channelId: Int64, pts: Int32) -> Data {
        #if DEBUG
        let limit: Int32 = 2
        #else
        let limit: Int32 = 100
        #endif
        return Api.functions.updates.getChannelDifference(flags: 0, channel: .inputChannel(.init(channelId: channelId, accessHash: 1)), filter: .channelMessagesFilterEmpty, pts: pts, limit: limit).1.makeData()
    }

    /// A stored member channel at pts 50 is named by `updatePinnedForumTopics` in a container without `chats`: it
    /// is polled once, from 50.
    func testPinnedForumTopicsWithoutChatsPollsTheStoredChannel() {
        let channel = self.seedChannel(337, pts: 50, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifferenceEmpty(pts: 50)))

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updatePinnedForumTopics(peer: StateSyncApi.peerChannel(337))
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference], "the channel was not polled: the batch did not load its peer")
        let polls = self.server.requests.filter { $0.name == Name.getChannelDifference }
        XCTAssertEqual(polls.first?.payload, self.channelDifferencePayload(channelId: 337, pts: 50), "arguments: \(polls.first?.arguments ?? "none")")
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 50)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// A difference names a channel that is neither stored nor in its `chats` with `updatePinnedForumTopics`. There
    /// is nothing to poll it with, and the difference is still replayed: one getDifference ends the cycle. While the
    /// update's peer was listed in `Api.Update.peerIds`, the replay's verification (`ReplayRejection.verify`)
    /// refused the batch for the missing peer, and the difference path polled again at once from the same pts: the
    /// same answer, the same refusal, a getDifference loop with no delay.
    func testPinnedForumTopicsForAnUnstoredChannelInDifferenceIsReplayed() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            otherUpdates: [StateSyncApi.updatePinnedForumTopics(peer: StateSyncApi.peerChannel(338))],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        // A second getDifference would be the refused replay's poll; it has no answer here.
        self.fixture.resetStateManager()

        self.isUpdating.wait { $0 == [true, false] }
        XCTAssertEqual(self.server.requestNames, [Name.getDifference], "the difference's replay was refused and polled again")
        XCTAssertEqual(self.fixture.accountState()?.state?.date, self.baseDate + 1, "the difference was not replayed")
    }

    /// A pushed `updatePinnedForumTopics` with an order, for a channel that is neither stored nor in the container's
    /// `chats`, stores the order and asks nothing: the order path needs no peer. While the update's peer was listed
    /// in `Api.Update.peerIds`, the replay's verification refused the batch for the missing peer, and the push cost a
    /// getDifference.
    func testPinnedForumTopicsOrderForAnUnstoredChannelIsReplayedWithoutAPoll() {
        self.launchIdle()
        let channel = StateSyncFixture.channelPeerId(338)

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updatePinnedForumTopics(peer: StateSyncApi.peerChannel(338), order: [5, 3])
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference], "the push's replay was refused and polled again")
        XCTAssertEqual(self.fixture.transaction { $0.getPeerPinnedThreads(peerId: channel) }, [5, 3], "the push was not replayed")
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }
}
