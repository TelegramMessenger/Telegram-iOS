import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

/// `AccountMutableState.branch()` and `merge(_:)`: a pushed batch that polls channels runs each poll on a
/// branch of the batch's state and merges every branch back. Pins R2: what the parent held when it
/// branched must come back once, not once per branch.
final class BranchMergeTests: XCTestCase {
    private func makeState() -> AccountMutableState {
        let initialState = AccountInitialState(state: AuthorizedAccountState.State(pts: 100, qts: 5, date: 1_700_000_000, seq: 10), peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: [:], peerChatInfos: [:], locallyGeneratedMessageTimestamps: [:], channelsToPollExplicitely: Set())
        return AccountMutableState(initialState: initialState, initialPeers: [:], initialReferencedReplyMessageIds: ReferencedReplyMessageIds(), initialReferencedGeneralMessageIds: Set(), initialStoredMessages: Set(), initialStoredStories: [:], initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:], initialSentScheduledMessageIds: Set())
    }

    private let channel = StateSyncFixture.channelPeerId(300)

    func testBranchesMergedBackDoNotRepeatTheParentsAlertsAndWebViewResults() {
        var parent = self.makeState()
        parent.addDisplayAlert("alert", isDropAuth: false)
        parent.addDismissWebView(1)
        parent.addJoinChatWebViewDecision(JoinChatWebViewDecision(peerId: self.channel, queryId: 1, result: .webView(url: "https://example.com")))

        let first = parent.branch()
        let second = parent.branch()
        parent.merge(first)
        parent.merge(second)

        XCTAssertEqual(parent.displayAlerts.map { $0.text }, ["alert"])
        XCTAssertEqual(parent.dismissBotWebViews, [1])
        XCTAssertEqual(parent.joinChatWebViewDecisions.map { $0.queryId }, [1])
    }

    func testWhatABranchAddsIsMergedOnce() {
        var parent = self.makeState()
        parent.addDisplayAlert("parent", isDropAuth: false)
        parent.addDismissWebView(1)
        parent.addJoinChatWebViewDecision(JoinChatWebViewDecision(peerId: self.channel, queryId: 1, result: .approved))

        var first = parent.branch()
        first.addDisplayAlert("first", isDropAuth: true)
        first.addDismissWebView(2)
        first.addJoinChatWebViewDecision(JoinChatWebViewDecision(peerId: self.channel, queryId: 2, result: .declined))
        let second = parent.branch()
        parent.merge(first)
        parent.merge(second)

        XCTAssertEqual(parent.displayAlerts.map { $0.text }, ["parent", "first"])
        XCTAssertEqual(parent.displayAlerts.map { $0.isDropAuth }, [false, true])
        XCTAssertEqual(parent.dismissBotWebViews, [1, 2])
        XCTAssertEqual(parent.joinChatWebViewDecisions.map { $0.queryId }, [1, 2])
    }
}

/// R2 end to end: a popup service notification in a pushed batch that also has a channel pts gap. The gap
/// is filled by one getChannelDifference on a branch of the batch's state.
final class BranchMergePushTests: StateSyncTestCase {
    func testAlertInABatchThatPollsAChannelIsDeliveredOnce() {
        let channel = self.seedChannel(300, pts: 50, storedMessageId: 10)
        self.launchIdle()
        let alerts = self.fixture.observe(self.stateManager.displayAlerts)
        self.managerQueueRoundTrip()
        self.server.on(Name.getChannelDifference, .result(StateSyncApi.channelDifference(pts: 52, newMessages: [
            StateSyncApi.channelPost(id: 11, channelId: 300, date: self.baseDate + 2),
            StateSyncApi.channelPost(id: 12, channelId: 300, date: self.baseDate + 2)
        ])))

        // `popup` (flags.0); no `inbox_date`, so nothing is stored in the service chat.
        let popup: Api.Update = .updateServiceNotification(.init(flags: 1 << 0, inboxDate: nil, type: "TEST_POPUP", message: "alert", media: .messageMediaEmpty, entities: []))
        self.server.push(StateSyncApi.updates([
            popup,
            StateSyncApi.updateNewChannelMessage(StateSyncApi.channelPost(id: 12, channelId: 300, date: self.baseDate + 2), pts: 52)
        ], date: self.baseDate + 2, seq: 0))
        self.drainOperationQueue()

        // Control: the batch polled the channel once and applied what the poll returned.
        XCTAssertEqual(self.server.requestNames, [Name.getDifference, Name.getChannelDifference])
        XCTAssertEqual(self.fixture.channelState(channel)?.pts, 52)
        // R2: one alert, not the parent's plus one copy per merged branch.
        XCTAssertEqual(alerts.values.flatMap { $0 }.map { $0.text }, ["alert"])
    }
}
