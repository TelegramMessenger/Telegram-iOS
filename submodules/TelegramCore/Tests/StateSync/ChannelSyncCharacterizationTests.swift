import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// Channel synchronization (gap polls, unknown channel state, resets during getDifference, view polls),
/// pinned as it behaves at 171825ce49.
final class ChannelSyncCharacterizationTests: StateSyncTestCase {
    /// Control for G1 and Q5. An in-order post for a channel whose state is known is stored with no request.
    func testInOrderChannelPushIsStored() {
        let channel = self.seedChannel(300, pts: 50, storedMessageId: 10)
        self.launchIdle()

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateNewChannelMessage(StateSyncApi.channelPost(id: 11, channelId: 300, date: self.baseDate + 2), pts: 51)
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 11)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 51)
    }

    /// Flow 8. A channel pts gap in a pushed batch is filled by one getChannelDifference inside the batch's
    /// operation; the result is replayed with verification.
    func testChannelPtsGapPollsChannelDifference() {
        let channel = self.seedChannel(300, pts: 50, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifference(pts: 52, newMessages: [
            StateSyncApi.channelPost(id: 11, channelId: 300, date: self.baseDate + 2),
            StateSyncApi.channelPost(id: 12, channelId: 300, date: self.baseDate + 2)
        ])))

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateNewChannelMessage(StateSyncApi.channelPost(id: 12, channelId: 300, date: self.baseDate + 2), pts: 52)
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference])
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 11)))
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 12)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 52)
        XCTAssertEqual(self.fixture.channelState(channel)?.synchronizedUntilMessageId, 12)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// A channel gap poll answered CHANNEL_PRIVATE (CHANNEL_INVALID alike) gives the branch back as it was given
    /// (`ChannelPollOutcome.channelUnavailable`), and the recovery tail sets `hadError`, so the batch's
    /// `shouldPoll` is set and its follow-up is `.applyThenPoll`: the batch is replayed, its events are queued
    /// (Q4), and a getDifference replaces the queued operations. Here the batch's private message is stored and
    /// notified, the channel keeps its pts, the post after the gap is not stored, and the getDifference starts
    /// from the pts the batch moved to.
    func testChannelPollAnsweredChannelPrivateAppliesTheBatchThenPolls() {
        let user = self.seedUserChat(200)
        let channel = self.seedChannel(307, pts: 50, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .error(code: 400, text: "CHANNEL_PRIVATE"))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 3, seq: 10)))

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateNewMessage(self.incomingMessage(101, from: 200), pts: 101),
            StateSyncApi.updateNewChannelMessage(StateSyncApi.channelPost(id: 12, channelId: 307, date: self.baseDate + 2), pts: 52)
        ], date: self.baseDate + 2, seq: 0))

        self.isUpdating.wait { $0 == [true, false, true, false] }
        self.waitForNotification(of: self.messageId(user, 101))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference, Name.getDifference])
        self.assertGetDifference(2, pts: 101, date: self.baseDate + 1, qts: 5)
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertNil(self.fixture.message(self.messageId(channel, 12)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 50)
        XCTAssertEqual(self.fixture.accountState()?.state, self.state(pts: 101, date: self.baseDate + 3))
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(user, 101)]])
    }

    /// A channel gap in a pushed batch for a channel stored without an access hash: `pollChannel` can build no
    /// input channel, logs it and requests nothing (`ChannelPollOutcome.noInputChannel`), and the branch comes
    /// back as it was given. Unlike an unavailable channel this sets no error, so the batch is applied as it is
    /// and nothing follows it: no getChannelDifference and no getDifference. The batch's private message is
    /// stored and notified, the channel keeps its pts, and the post after the gap is not stored.
    func testChannelGapForAChannelWithoutAccessHashAppliesTheBatchWithoutARequest() {
        let user = self.seedUserChat(200)
        let channel = self.seedChannel(308, pts: 50, storedMessageId: 10, accessHash: nil)
        self.launchIdle()
        let storedChannel = self.fixture.peer(channel) as? TelegramChannel
        XCTAssertNotNil(storedChannel, "precondition: the channel is stored")
        XCTAssertNil(storedChannel?.accessHash, "precondition: the channel is stored without an access hash")

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateNewMessage(self.incomingMessage(101, from: 200), pts: 101),
            StateSyncApi.updateNewChannelMessage(StateSyncApi.channelPost(id: 12, channelId: 308, date: self.baseDate + 2), pts: 52)
        ], date: self.baseDate + 2, seq: 0))

        self.waitForNotification(of: self.messageId(user, 101))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference])
        XCTAssertNotNil(self.fixture.message(self.messageId(user, 101)))
        XCTAssertNil(self.fixture.message(self.messageId(channel, 12)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 50)
        XCTAssertEqual(self.fixture.accountState()?.state?.pts, 101)
        XCTAssertEqual(self.isUpdating.values, [true, false])
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(user, 101)]])
    }

    /// Flow 9, G1 (fixed). An update for a member channel that has a stored message but no ChannelState
    /// schedules a poll of that channel. In a pushed batch that is `pollChannel`: one getChannelDifference
    /// from pts 1 (there is no local pts) inside the batch's operation, whose answer is replayed with the
    /// batch. The pushed update itself is not applied, so the post comes from the answer. Until G1 was
    /// fixed, the request was a subscript assignment of nil on the `[PeerId: Int32?]` of poll requests
    /// (today `ChannelRecoveryRequests`, which inserts with `updateValue(_:forKey:)`), which removed the key
    /// instead of adding one: nothing was requested and the post was dropped.
    func testUpdateForChannelWithoutStatePollsChannelDifference() {
        let channel = self.seedChannel(301, pts: nil, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifference(pts: 51, newMessages: [
            StateSyncApi.channelPost(id: 11, channelId: 301, date: self.baseDate + 2)
        ])))

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateNewChannelMessage(StateSyncApi.channelPost(id: 11, channelId: 301, date: self.baseDate + 2), pts: 51)
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference])
        // `pollChannel`'s limit is 2 in DEBUG builds, 100 otherwise.
        #if DEBUG
        let limit: Int32 = 2
        #else
        let limit: Int32 = 100
        #endif
        XCTAssertEqual(self.server.requests.dropFirst().first?.payload, Api.functions.updates.getChannelDifference(flags: 0, channel: .inputChannel(.init(channelId: 301, accessHash: 1)), filter: .channelMessagesFilterEmpty, pts: 1, limit: limit).1.makeData())
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 11)))
        let channelState = self.fixture.channelState(channel)
        XCTAssertEqual(channelState?.pts, 51)
        XCTAssertEqual(channelState?.synchronizedUntilMessageId, 11)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// G1, another of the seven sites. A deletion for a member channel with no ChannelState schedules the
    /// same poll, and the deletion arrives with the channel difference. Until G1 was fixed the deletion was
    /// dropped with no request.
    func testDeleteForChannelWithoutStatePollsChannelDifference() {
        let channel = self.seedChannel(304, pts: nil, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifference(pts: 51, otherUpdates: [
            StateSyncApi.updateDeleteChannelMessages(channelId: 304, messages: [10], pts: 51, ptsCount: 1)
        ])))

        self.server.push(StateSyncApi.updates([
            StateSyncApi.updateDeleteChannelMessages(channelId: 304, messages: [10], pts: 51, ptsCount: 1)
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference])
        XCTAssertNil(self.fixture.message(self.messageId(channel, 10)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 51)
        XCTAssertEqual(self.isUpdating.values, [true, false])
    }

    /// G1 on the difference path (`shouldResetChannels`). A difference that carries a post for a member
    /// channel with no ChannelState resets that channel; in the app that is the asynchronous reset of
    /// flow 10: one messages.getPeerDialogs, replayed after the difference. Until G1 was fixed nothing was
    /// requested and the post was dropped.
    func testUpdateForChannelWithoutStateInDifferenceResetsChannel() {
        let channel = self.seedChannel(305, pts: nil, storedMessageId: 10)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            otherUpdates: [StateSyncApi.updateNewChannelMessage(StateSyncApi.channelPost(id: 11, channelId: 305, date: self.baseDate + 2), pts: 51)],
            chats: [StateSyncApi.broadcastChannel(id: 305, title: "C305")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        self.server.on(Name.getPeerDialogs, .result(StateSyncApi.peerDialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(305), topMessage: 11, pts: 51)],
            messages: [StateSyncApi.channelPost(id: 11, channelId: 305, date: self.baseDate + 2)],
            chats: [StateSyncApi.broadcastChannel(id: 305, title: "C305")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        self.fixture.resetStateManager()

        // isUpdating stays true until the reset is replayed (flow 10).
        self.isUpdating.wait { $0 == [true, false] }
        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getPeerDialogs])
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 11)))
        let channelState = self.fixture.channelState(channel)
        XCTAssertEqual(channelState?.pts, 51)
        XCTAssertEqual(channelState?.synchronizedUntilMessageId, 11)
        XCTAssertEqual(self.fixture.accountState()?.invalidatedChannels.count, 0)

        // Q12 (fixed): the reset's replay starts the idle queue itself, so its post is notified once and a
        // barrier added now completes.
        self.waitForNotification(of: self.messageId(channel, 11))
        self.drainOperationQueue()
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(channel, 11)]])
    }

    /// G1 follow-up: `updatePinnedForumTopics` names its peer as an `Api.Peer`, which for a bot forum is a
    /// USER. Only a channel can be polled or reset, so a user peer keeps the pre-G1 behaviour: the one
    /// messages.getPeerDialogs that fetches its chat info (`peerIdsRequiringLocalChatState`, which predates
    /// G1) and nothing else. Without the guard a second getPeerDialogs, the reset, was requested and an
    /// invalidated-channel record with the user's id was persisted.
    func testPinnedForumTopicsForBotUserInDifferenceDoesNotResetIt() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            otherUpdates: [StateSyncApi.updatePinnedForumTopics(peer: StateSyncApi.peerUser(777))],
            users: [StateSyncApi.user(id: 777, firstName: "Bot")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        // The chat-info fetch; a second request would be the reset, which has no answer here.
        self.server.on(Name.getPeerDialogs, .result(StateSyncApi.peerDialogs(
            users: [StateSyncApi.user(id: 777, firstName: "Bot")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        self.fixture.resetStateManager()

        self.isUpdating.wait { $0 == [true, false] }
        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getPeerDialogs])
        XCTAssertEqual(self.fixture.accountState()?.invalidatedChannels.count, 0)
    }

    /// Flow 10, C1 shape, and Q12 (fixed). An updateChannelTooLong inside a difference starts
    /// an asynchronous channel reset (one messages.getPeerDialogs per channel, an invalidated-channel
    /// record persisted first). The difference completes without it; isUpdating stays true until the reset
    /// is replayed, unverified, after which the record is cleared.
    ///
    /// Q12: that replay queues its events and starts the queue, which is otherwise idle, so they are delivered
    /// at once and a later operation runs. Until the fix the queue was not started, and nothing ran until the
    /// second push afterwards (the merge path of the second push called startFirstOperation).
    func testChannelTooLongInDifferenceResetsChannelAfterTheDifference() {
        let channel = self.seedChannel(302, pts: 50, storedMessageId: 10)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            otherUpdates: [StateSyncApi.updateChannelTooLong(channelId: 302, pts: 60)],
            chats: [StateSyncApi.broadcastChannel(id: 302, title: "C302")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        self.server.on(Name.getPeerDialogs, .hold)
        self.fixture.resetStateManager()

        XCTAssertTrue(self.server.waitForRequest(Name.getPeerDialogs))
        // The difference itself completes while the reset is held.
        self.drainOperationQueue()
        XCTAssertEqual(self.fixture.accountState()?.state?.date, self.baseDate + 1)
        XCTAssertEqual(self.isUpdating.values, [true])
        self.fixture.eventually {
            return self.fixture.accountState()?.invalidatedChannels.map { $0.peerId } == [channel]
        }

        XCTAssertTrue(self.server.release(Name.getPeerDialogs, with: .result(StateSyncApi.peerDialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(302), topMessage: 15, pts: 60)],
            messages: [StateSyncApi.channelPost(id: 15, channelId: 302, date: self.baseDate + 3)],
            chats: [StateSyncApi.broadcastChannel(id: 302, title: "C302")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        ))))

        self.isUpdating.wait { $0 == [true, false] }
        self.significantUpdates.wait { $0.count == 1 }
        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getPeerDialogs])
        XCTAssertEqual(self.fixture.accountState()?.invalidatedChannels.count, 0)
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 15)))
        let channelState = self.fixture.channelState(channel)
        XCTAssertEqual(channelState?.pts, 60)
        XCTAssertEqual(channelState?.invalidatedPts, 60)
        XCTAssertEqual(channelState?.synchronizedUntilMessageId, 15)

        // Q12: with no push, the reset's post is notified once and a barrier added now completes.
        self.waitForNotification(of: self.messageId(channel, 15))
        self.drainOperationQueue()
        XCTAssertEqual(self.notifiedMessageIds(), [[self.messageId(channel, 15)]])
    }

    /// Flow 11, C2. A view poll (pollChannelOnce, which keepPollingChannel restarts every `timeout`
    /// seconds) requests the reply target of a new post and replays it with the post. The target is
    /// requested although the snapshot could have known it (initialStoredMessages is empty in this path).
    func testViewPollStoresFetchedReplyTarget() {
        let channel = self.seedChannel(303, pts: 50, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifference(pts: 51, newMessages: [
            StateSyncApi.channelPost(id: 11, channelId: 303, date: self.baseDate + 2, replyToMessageId: 6)
        ])))
        self.server.on(Name.channelsGetMessages, .result(StateSyncApi.channelMessages(pts: 51, [
            StateSyncApi.channelPost(id: 6, channelId: 303, date: self.baseDate - 100)
        ])))

        let timeout = self.fixture.wait(pollChannelOnce(accountPeerId: StateSyncFixture.accountPeerId, postbox: self.fixture.postbox, network: self.network, peerId: channel, stateManager: self.stateManager, delayCompletion: false))
        self.drainOperationQueue()

        XCTAssertEqual(timeout, 30)
        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference, Name.channelsGetMessages])
        XCTAssertEqual(self.server.requests.dropFirst(2).first?.payload, self.replyTargetRequestPayload(channelId: 303, replyingMessageId: 11))
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 11)))
        // C2: the fetched target is stored with the post.
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 6)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 51)
    }

    /// C2, the notification extension's channel poll (standalonePollChannelOnce): the view poll's chain,
    /// replayed directly rather than through the operation queue. The fetched reply target is stored with
    /// the post.
    func testStandaloneChannelPollStoresFetchedReplyTarget() {
        let channel = self.seedChannel(304, pts: 50, storedMessageId: 10)
        self.launchIdle()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifference(pts: 51, newMessages: [
            StateSyncApi.channelPost(id: 11, channelId: 304, date: self.baseDate + 2, replyToMessageId: 6)
        ])))
        self.server.on(Name.channelsGetMessages, .result(StateSyncApi.channelMessages(pts: 51, [
            StateSyncApi.channelPost(id: 6, channelId: 304, date: self.baseDate - 100)
        ])))

        // Completes after the replay transaction has committed.
        let _ = self.fixture.wait(standalonePollChannelOnce(accountPeerId: StateSyncFixture.accountPeerId, postbox: self.fixture.postbox, network: self.network, peerId: channel, stateManager: self.stateManager))

        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference, Name.channelsGetMessages])
        XCTAssertEqual(self.server.requests.dropFirst(2).first?.payload, self.replyTargetRequestPayload(channelId: 304, replyingMessageId: 11))
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 11)))
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 6)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 51)
    }

    /// C2, the channel reset after a difference (resetChannels on flow 10's default, asynchronous path):
    /// the reset's top message replies to a message the device does not have. The reset fetches the
    /// target and replays it with the top message.
    func testChannelResetStoresFetchedReplyTarget() {
        let channel = self.seedChannel(305, pts: 50, storedMessageId: 10)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            otherUpdates: [StateSyncApi.updateChannelTooLong(channelId: 305, pts: 60)],
            chats: [StateSyncApi.broadcastChannel(id: 305, title: "C305")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        self.server.on(Name.getPeerDialogs, .result(StateSyncApi.peerDialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(305), topMessage: 15, pts: 60)],
            messages: [StateSyncApi.channelPost(id: 15, channelId: 305, date: self.baseDate + 3, replyToMessageId: 6)],
            chats: [StateSyncApi.broadcastChannel(id: 305, title: "C305")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        self.server.on(Name.channelsGetMessages, .result(StateSyncApi.channelMessages(pts: 60, [
            StateSyncApi.channelPost(id: 6, channelId: 305, date: self.baseDate - 100)
        ])))
        self.fixture.resetStateManager()

        // isUpdating turns false only after the reset has been replayed (flow 10).
        self.isUpdating.wait { $0 == [true, false] }
        self.drainOperationQueue()
        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getPeerDialogs, Name.channelsGetMessages])
        XCTAssertEqual(self.server.requests.dropFirst(2).first?.payload, self.replyTargetRequestPayload(channelId: 305, replyingMessageId: 15))
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 15)))
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 6)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 60)
    }

    /// C2 on the synchronous reset path (`ios_disable_parallel_channel_reset_v2`; the notification
    /// extension's standalonePollDifference always takes it): the difference's own resolve runs after
    /// resetChannels on the state resetChannels returned. While resetChannels discarded its resolve, that
    /// second resolve requested the same target again; now the target is requested once.
    func testSynchronousChannelResetRequestsReplyTargetOnce() {
        let channel = self.seedChannel(306, pts: 50, storedMessageId: 10)
        self.fixture.seedAppConfiguration(["ios_disable_parallel_channel_reset_v2": true])
        // The switch landed: the main app's attempt (`fetchAndApplyDifference(policy:)`) only asks whether the
        // key is present.
        XCTAssertEqual(self.fixture.transaction { transaction -> Bool in
            return transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self)?.data?["ios_disable_parallel_channel_reset_v2"] != nil
        }, true)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.difference(
            otherUpdates: [StateSyncApi.updateChannelTooLong(channelId: 306, pts: 60)],
            chats: [StateSyncApi.broadcastChannel(id: 306, title: "C306")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        self.server.on(Name.getPeerDialogs, .result(StateSyncApi.peerDialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(306), topMessage: 15, pts: 60)],
            messages: [StateSyncApi.channelPost(id: 15, channelId: 306, date: self.baseDate + 3, replyToMessageId: 6)],
            chats: [StateSyncApi.broadcastChannel(id: 306, title: "C306")],
            state: StateSyncApi.state(pts: 100, qts: 5, date: self.baseDate + 1, seq: 10)
        )))
        // Every request for the target is answered, so a repeated one shows in the log instead of hanging.
        let target = StateSyncApi.channelPost(id: 6, channelId: 306, date: self.baseDate - 100)
        self.server.always(Name.channelsGetMessages, { _ in
            return .result(StateSyncApi.channelMessages(pts: 60, [target]))
        })
        self.fixture.resetStateManager()

        self.isUpdating.wait { $0.last == false }
        self.drainOperationQueue()
        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getPeerDialogs, Name.channelsGetMessages])
        XCTAssertEqual(self.server.requests.dropFirst(2).first?.payload, self.replyTargetRequestPayload(channelId: 306, replyingMessageId: 15))
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 15)))
        XCTAssertNotNil(self.fixture.message(self.messageId(channel, 6)))
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 60)
    }

    /// The `channels.getMessages` a resolve sends for a reply target: `inputMessageReplyTo` names the
    /// REPLYING message, and the server answers with its target.
    private func replyTargetRequestPayload(channelId: Int64, replyingMessageId: Int32) -> Data {
        return Api.functions.channels.getMessages(channel: .inputChannel(.init(channelId: channelId, accessHash: 1)), id: [.inputMessageReplyTo(.init(id: replyingMessageId))]).1.makeData()
    }
}
