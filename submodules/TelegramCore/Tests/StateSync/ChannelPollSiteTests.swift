import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// G1, one test per site that requests a poll of its channel (`ChannelRecoveryRequests.requestPoll(_:ptsHint:)` or
/// `noteUnknownChannelState(_:)`, Sync/UpdateInterpreter+Channels.swift) that ChannelSyncCharacterizationTests
/// does not cover, and the deduplication between the explicit poll of a channel the batch names (requested in
/// `UpdateInterpreter.init`) and a site's request. Each pushed batch polls the channel once, inside the batch's
/// operation (`pollChannel`), and the answer is replayed with the batch. The two covered elsewhere are
/// `updateNewChannelMessage` and `updateDeleteChannelMessages` for a channel without a `ChannelState`.
final class ChannelPollSiteTests: StateSyncTestCase {
    /// The `updates.getChannelDifference` `pollChannel` sends for broadcast channel `channelId` (access hash 1,
    /// as `seedChannel` stores it) from `pts`: 1 when there is no local pts. `pollChannel`'s limit is 2 in DEBUG
    /// builds, 100 otherwise.
    private func channelDifferencePayload(channelId: Int64, pts: Int32) -> Data {
        #if DEBUG
        let limit: Int32 = 2
        #else
        let limit: Int32 = 100
        #endif
        return Api.functions.updates.getChannelDifference(flags: 0, channel: .inputChannel(.init(channelId: channelId, accessHash: 1)), filter: .channelMessagesFilterEmpty, pts: pts, limit: limit).1.makeData()
    }

    /// Exactly one `updates.getChannelDifference` was sent, for `channelId` from `pts`.
    private func assertOneChannelPoll(channelId: Int64, pts: Int32, file: StaticString = #filePath, line: UInt = #line) {
        let polls = self.server.requests.filter { $0.name == Name.getChannelDifference }
        XCTAssertEqual(polls.count, 1, "log: \(self.server.requestNames)", file: file, line: line)
        XCTAssertEqual(polls.first?.payload, self.channelDifferencePayload(channelId: channelId, pts: pts), "arguments: \(polls.first?.arguments ?? "none")", file: file, line: line)
    }

    /// `updateChannelWebPage#2f2ba99f` carrying an empty web page for `channel_id`.
    private func channelWebPage(channelId: Int64, pts: Int32, ptsCount: Int32 = 1) -> Api.Update {
        return .updateChannelWebPage(.init(channelId: channelId, webpage: .webPageEmpty(.init(flags: 0, id: 1, url: nil)), pts: pts, ptsCount: ptsCount))
    }

    /// `updatePinnedForumTopics` without an order, naming a CHANNEL: the poll is scheduled whatever the local
    /// state, so a channel at pts 50 is polled from 50. The container's `chats` carry the channel, as the server
    /// sends it; without them the batch finds the stored channel through the snapshot's load-only peers (B5)
    /// (PinnedForumTopicsPeerTests pins that case).
    func testPinnedForumTopicsForAChannelPollsItFromItsPts() {
        let channel = self.seedChannel(331, pts: 50, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifferenceEmpty(pts: 50)))

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updatePinnedForumTopics(peer: StateSyncApi.peerChannel(331))
        ], chats: [StateSyncApi.broadcastChannel(id: 331, title: "C331")], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference])
        self.assertOneChannelPoll(channelId: 331, pts: 50)
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 50)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// `updateEditChannelMessage` for a member channel with a stored message but no `ChannelState`: the edit is
    /// not applied from the batch; the channel is polled from pts 1 and the edit arrives with the answer.
    /// Until G1 was fixed the edit was dropped with no request.
    func testEditForChannelWithoutStatePollsChannelDifference() {
        let channel = self.seedChannel(332, pts: nil, storedMessageId: 10)
        self.launchIdle()
        let edited = StateSyncApi.channelPost(id: 10, channelId: 332, date: self.baseDate, text: "edited")
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifference(pts: 51, otherUpdates: [
            .updateEditChannelMessage(.init(message: edited, pts: 51, ptsCount: 1))
        ])))

        self.server.push(StateSyncApi.updates([
            .updateEditChannelMessage(.init(message: edited, pts: 51, ptsCount: 1))
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference])
        self.assertOneChannelPoll(channelId: 332, pts: 1)
        XCTAssertEqual(self.fixture.message(self.messageId(channel, 10))?.text, "edited")
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 51)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// `updateChannelWebPage` with a pts hole (local 50, update 52 counting 1) schedules the poll as a poll
    /// request (`ChannelRecoveryRequests.requestPoll(_:ptsHint:)`), unlike the other channel updates, whose holes
    /// are gaps (`markGap(_:)`): the channel is polled once from its pts.
    func testWebPageWithAPtsHolePollsTheChannelFromItsPts() {
        let channel = self.seedChannel(333, pts: 50, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifferenceEmpty(pts: 52)))

        self.server.push(StateSyncApi.updates([
            self.channelWebPage(channelId: 333, pts: 52)
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference])
        self.assertOneChannelPoll(channelId: 333, pts: 50)
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 52)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// `updateChannelWebPage` for a member channel with no `ChannelState`: polled from pts 1, and the answer's
    /// pts is stored.
    func testWebPageForChannelWithoutStatePollsChannelDifference() {
        let channel = self.seedChannel(334, pts: nil, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifferenceEmpty(pts: 51)))

        self.server.push(StateSyncApi.updates([
            self.channelWebPage(channelId: 334, pts: 51)
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference])
        self.assertOneChannelPoll(channelId: 334, pts: 1)
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 51)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// `updatePinnedChannelMessages` for a member channel with no `ChannelState`: polled from pts 1, and the
    /// answer's pts is stored.
    func testPinnedMessagesForChannelWithoutStatePollsChannelDifference() {
        let channel = self.seedChannel(335, pts: nil, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifferenceEmpty(pts: 51)))

        // `pinned` (flags.0).
        self.server.push(StateSyncApi.updates([
            .updatePinnedChannelMessages(.init(flags: 1 << 0, channelId: 335, messages: [10], pts: 51, ptsCount: 1))
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference])
        self.assertOneChannelPoll(channelId: 335, pts: 1)
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 51)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// Deduplication. A batch whose `chats` carry a member channel the device has no message of puts it in
    /// `channelsToPollExplicitely` (SyncSnapshot.swift); the batch's own post for it, with no `ChannelState`,
    /// requests a poll of the same channel (`noteUnknownChannelState(_:)`). The channel is polled once, from pts 1.
    /// Every getChannelDifference is answered, so a second poll shows in the log rather than stalling the batch.
    func testExplicitlyPolledChannelWithAnUnknownStateUpdateIsPolledOnce() {
        let channel = self.seedChannel(336, pts: nil, storedMessageId: nil)
        self.launchIdle()
        let topMessage = self.fixture.transaction { transaction -> MessageIndex? in
            return transaction.getTopPeerMessageIndex(peerId: channel, namespace: Namespaces.Message.Cloud)
        } ?? nil
        XCTAssertNil(topMessage, "precondition: no stored message, so the batch's chats make it an explicit poll")
        let post = StateSyncApi.channelPost(id: 11, channelId: 336, date: self.baseDate + 2)
        self.server.always(Name.getChannelDifference, { _ in
            return .result(StateSyncApi.channelDifference(pts: 51, newMessages: [post]))
        })

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateNewChannelMessage(post, pts: 51)
        ], chats: [StateSyncApi.broadcastChannel(id: 336, title: "C336")], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference])
        self.assertOneChannelPoll(channelId: 336, pts: 1)
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 11)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 51)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }
}
