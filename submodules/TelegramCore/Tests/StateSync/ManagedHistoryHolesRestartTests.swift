import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"

/// ManagedMessageHistoryHoles (the app's hole loader) after a fill that closed nothing (the owner's rule: "we never
/// abandon syncing or message history loading"). A fill that ends with nil (a definite answer, or an answer too old
/// to store) leaves its hole, and its entry is not started again for a pause (`ManagedMessageHistoryHolesPause`,
/// 20 s). Once the pause is over it must start again while a view still shows the hole, though nothing else happens:
/// no other fill completes and the view does not change. Helpers are in HistoryFillReconciliationTests.swift.
final class ManagedHistoryHolesRestartTests: StateSyncTestCase {
    override func tearDown() {
        ManagedMessageHistoryHolesPause.duration = ManagedMessageHistoryHolesPause.defaultDuration
        super.tearDown()
    }

    /// A chat view over a whole-history hole. The first fill gets a definite answer (`MSG_ID_INVALID`), ends with
    /// nil and closes nothing; the hole and the view stay as they were. After the pause (0.5 s here) the fill is
    /// started again, and the server's answer closes the hole. Before the fix the entry was re-evaluated only when
    /// another fill completed or the view emitted again, so a quiet chat stayed loading.
    func testAFillThatClosedNothingIsStartedAgainAfterThePause() {
        ManagedMessageHistoryHolesPause.duration = 0.5
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .error(code: 400, text: "MSG_ID_INVALID"))
        self.server.always(getHistory, { _ in .result(StateSyncApi.messages([])) })

        let views = self.fixture.observe(self.fixture.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: [], count: 20, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .all, orderStatistics: []) |> map { $0.0 })
        views.wait { !$0.isEmpty }
        let (_, holesDisposable) = managedMessageHistoryHoles(accountPeerId: StateSyncFixture.accountPeerId, network: self.network, postbox: self.fixture.postbox, pendingReferences: PendingMessageReferences())
        defer {
            holesDisposable.dispose()
        }

        XCTAssertTrue(self.server.waitForRequest(getHistory), "precondition: no fill was started: \(self.server.requestNames)")
        XCTAssertTrue(self.server.waitForRequest(getHistory, count: 2, timeout: 5.0), "the fill that closed nothing was never started again: \(self.server.requestNames)")
        self.fixture.eventually(timeout: 5.0) {
            return self.fixture.holes(peerId: peerId).isEmpty
        }
    }
}
