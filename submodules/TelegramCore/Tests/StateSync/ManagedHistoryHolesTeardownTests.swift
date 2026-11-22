import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"

/// ManagedMessageHistoryHoles (the app's hole loader) when it goes. A fill's own request retries a transient
/// error until it succeeds (owner decision D4, HistoryFillRequestRetry.swift), and the hole manager keeps a
/// pending fill until it completes, so a fill stuck on an error that never clears runs for the session. When
/// the manager goes (the account is torn down or resigns master) its pending fills are disposed: teardown is
/// not giving up.
/// Helpers are in HistoryFillReconciliationTests.swift.
final class ManagedHistoryHolesTeardownTests: StateSyncTestCase {
    /// A chat view over a whole-history hole and a server that answers every getHistory with a 500: the first
    /// attempt fails and the fill's retry is in flight (held) when the manager is released. The release
    /// cancels that request, the fill sends nothing more, although every later attempt is scripted to fail
    /// again, and nothing it ran keeps the Postbox alive. Before the fix the context's deinit released the
    /// fills' MetaDisposables without disposing them, so the retry loop ran on, holding the Postbox and the
    /// network.
    func testAFillRetryingATransientErrorStopsWhenTheHoleManagerGoes() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .error(code: 500, text: "INTERNAL_SERVER_ERROR"))
        self.server.on(getHistory, .hold)
        self.server.always(getHistory, { _ in .error(code: 500, text: "INTERNAL_SERVER_ERROR") })

        let views = self.fixture.observe(self.fixture.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: [], count: 20, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .all, orderStatistics: []) |> map { $0.0 })
        views.wait { !$0.isEmpty }
        let (_, holesDisposable) = managedMessageHistoryHoles(accountPeerId: StateSyncFixture.accountPeerId, network: self.network, postbox: self.fixture.postbox, pendingReferences: PendingMessageReferences())

        // The first attempt failed with a transient error and the fill retried it: the retry is held.
        XCTAssertTrue(self.server.waitForRequest(getHistory, count: 2), "precondition: the fill did not retry its transient error: \(self.server.requestNames)")
        XCTAssertEqual(self.server.heldNames, [getHistory], "precondition: the fill's retry is in flight")
        guard let retryIndex = self.server.requests.filter({ $0.name == getHistory }).last?.index else {
            return
        }

        // As the account disposes it (`managedServiceViews`), when it is torn down or resigns master.
        holesDisposable.dispose()

        self.fixture.eventually(timeout: 5.0) {
            return self.server.cancelled.contains(retryIndex)
        }
        XCTAssertEqual(self.server.cancelled, [retryIndex], "the hole manager went and its fill's request stayed in flight")
        // Answered anyway, as an engine whose answer was already on its way: a fill still running would retry it
        // (0.4 s later) against the scripted 500s.
        let _ = self.server.release(getHistory, with: .error(code: 500, text: "INTERNAL_SERVER_ERROR"))
        XCTAssertFalse(self.server.waitForRequest(getHistory, count: 3, timeout: 2.0), "a fill kept retrying after its hole manager went: \(self.server.requestNames)")
        XCTAssertTrue(self.fixture.close(), "the Postbox outlived the hole manager: a fill it started still holds it")
    }
}
