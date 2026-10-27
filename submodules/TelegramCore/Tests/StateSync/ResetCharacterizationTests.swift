import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

extension StateSyncTestCase {
    /// Builds the manager and starts a poll cycle that resets the account: differenceTooLong(pts 999), then
    /// `dialogs` for the reset's messages.getDialogs, no pinned chats, and an empty difference for the cycle's
    /// follow-up getDifference. Seed the account and whatever the reset should find, and script the reset's
    /// other requests, before calling it. Returns at once; `drainOperationQueue()` waits for the cycle.
    func startAccountReset(dialogs: Api.messages.Dialogs) {
        self.makeStateManager()
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceTooLong(pts: 999)))
        self.server.on(Name.getDialogs, .result(dialogs))
        self.server.on(Name.getPinnedDialogs, .result(StateSyncApi.peerDialogs(state: StateSyncApi.state(pts: 999, qts: 5, date: self.baseDate, seq: 10))))
        self.server.on(Name.getDifference, .result(StateSyncApi.differenceEmpty(date: self.baseDate + 120, seq: 10)))
        self.fixture.resetStateManager()
    }
}

/// What the account reset after differenceTooLong (`_internal_resetAccountState`, ResetState.swift) writes for
/// channels (spec section 3 point 4). The poll cycle around the reset is pinned in DifferenceCharacterizationTests.
final class ResetCharacterizationTests: StateSyncTestCase {
    /// The reset raises invalidatedPts of a channel whose pts it moves, so the channel's own history
    /// validation checks what it has stored; a channel whose pts did not move is left alone. Until the fix the
    /// reset moved pts and left invalidatedPts nil, so that validation never ran for messages stored before
    /// the gap.
    func testResetInvalidatesChannelsWhosePtsMoved() {
        let moved = self.seedChannel(300, pts: 50, storedMessageId: nil)
        let unchanged = self.seedChannel(301, pts: 70, storedMessageId: nil)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.startAccountReset(dialogs: StateSyncApi.dialogs(
            dialogs: [
                StateSyncApi.dialog(peer: StateSyncApi.peerChannel(300), topMessage: 10, pts: 60),
                StateSyncApi.dialog(peer: StateSyncApi.peerChannel(301), topMessage: 20, pts: 70)
            ],
            messages: [
                StateSyncApi.channelPost(id: 10, channelId: 300, date: self.baseDate + 10),
                StateSyncApi.channelPost(id: 20, channelId: 301, date: self.baseDate + 20)
            ],
            chats: [
                StateSyncApi.broadcastChannel(id: 300, title: "C300"),
                StateSyncApi.broadcastChannel(id: 301, title: "C301")
            ]
        ))

        // The barrier sits behind the running poll and completes once the follow-up ended the cycle.
        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames.count, 4, "log: \(self.server.requestNames)")
        XCTAssertEqual(self.fixture.channelState(moved)?.pts, 60)
        XCTAssertEqual(self.fixture.channelState(moved)?.invalidatedPts, 60)
        XCTAssertEqual(self.fixture.channelState(unchanged)?.pts, 70)
        XCTAssertNil(self.fixture.channelState(unchanged)?.invalidatedPts)
    }

    /// invalidatedPts only rises: a reset whose dialog reports a channel's pts below the stored one (60 under 80,
    /// an older page) leaves its invalidatedPts at 80, so the messages it marks for revalidation stay marked.
    /// Before the fix it followed the page's pts down to 60. The pts itself still follows the page, as before.
    func testResetNeverLowersAChannelsInvalidatedPts() {
        let channelId = StateSyncFixture.channelPeerId(300)
        self.fixture.seedChannel(StateSyncFixture.makeChannel(id: channelId, accessHash: 1, title: "C300"), state: ChannelState(pts: 80, invalidatedPts: 80, synchronizedUntilMessageId: nil))
        self.fixture.seedChat(peerId: channelId)
        self.fixture.seedAccount(state: self.state(pts: 100))
        self.startAccountReset(dialogs: StateSyncApi.dialogs(
            dialogs: [StateSyncApi.dialog(peer: StateSyncApi.peerChannel(300), topMessage: 10, pts: 60)],
            messages: [StateSyncApi.channelPost(id: 10, channelId: 300, date: self.baseDate + 10)],
            chats: [StateSyncApi.broadcastChannel(id: 300, title: "C300")]
        ))

        self.drainOperationQueue()

        XCTAssertEqual(self.server.requestNames.count, 4, "log: \(self.server.requestNames)")
        XCTAssertEqual(self.fixture.channelState(channelId)?.pts, 60)
        XCTAssertEqual(self.fixture.channelState(channelId)?.invalidatedPts, 80, "the reset lowered invalidatedPts")
    }
}
