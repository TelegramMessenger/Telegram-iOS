import Foundation
import XCTest
import Postbox
@testable import TelegramCore

/// `ChannelRecoveryRequests`, the channels an update batch recovers after its switch (Sync/SyncChannelRecovery.swift).
/// Pins the optional-valued request map G1 broke (a request without a pts hint is still a request) and the
/// first-wins rules the interpreter's sites rely on. The sites themselves are pinned end to end by
/// ChannelPollSiteTests and ChannelSyncCharacterizationTests.
final class ChannelRecoveryRequestsTests: XCTestCase {
    private let first = StateSyncFixture.channelPeerId(300)
    private let second = StateSyncFixture.channelPeerId(301)

    func testAPollRequestWithoutAHintIsARequest() {
        var requests = ChannelRecoveryRequests()
        XCTAssertTrue(requests.isEmpty)

        XCTAssertTrue(requests.noteUnknownChannelState(self.first))

        XCTAssertFalse(requests.isEmpty)
        XCTAssertTrue(requests.isPollRequested(self.first))
        XCTAssertNil(requests.ptsHint(for: self.first))
        XCTAssertEqual(requests.channelIds, [self.first])
    }

    /// A second request for the same channel changes nothing: the first one's hint stays, and the call says it
    /// requested nothing (the sites log only when it did).
    func testTheFirstPollRequestKeepsItsHint() {
        var requests = ChannelRecoveryRequests()
        XCTAssertTrue(requests.requestPoll(self.first, ptsHint: 7))
        XCTAssertFalse(requests.requestPoll(self.first, ptsHint: 9))
        XCTAssertFalse(requests.noteUnknownChannelState(self.first))
        XCTAssertEqual(requests.ptsHint(for: self.first), 7)

        XCTAssertTrue(requests.requestPoll(self.second, ptsHint: nil))
        XCTAssertFalse(requests.requestPoll(self.second, ptsHint: 9))
        XCTAssertNil(requests.ptsHint(for: self.second))
    }

    /// A gap is reported once per channel; it is not a poll request, so it has no hint and leaves a later
    /// request (an `updateChannelTooLong` after the hole) free to record its own.
    func testAGapIsMarkedOnceAndIsNotAPollRequest() {
        var requests = ChannelRecoveryRequests()
        XCTAssertTrue(requests.markGap(self.first))
        XCTAssertFalse(requests.markGap(self.first))

        XCTAssertFalse(requests.isEmpty)
        XCTAssertFalse(requests.isPollRequested(self.first))
        XCTAssertNil(requests.ptsHint(for: self.first))

        XCTAssertTrue(requests.requestPoll(self.first, ptsHint: 5))
        XCTAssertEqual(requests.ptsHint(for: self.first), 5)
    }

    func testChannelIdsAreThePollRequestsAndTheGaps() {
        var requests = ChannelRecoveryRequests()
        requests.requestPoll(self.first, ptsHint: nil)
        XCTAssertTrue(requests.markGap(self.first))
        XCTAssertTrue(requests.markGap(self.second))

        XCTAssertEqual(requests.channelIds, [self.first, self.second])
    }
}
