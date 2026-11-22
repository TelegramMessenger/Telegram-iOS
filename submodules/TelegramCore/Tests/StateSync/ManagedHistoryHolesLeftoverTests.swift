import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"
private let getMessages = "messages.getMessages"

/// ManagedMessageHistoryHoles (the app's hole loader) after a partial close (spec 2026-10-15 §6). A fill
/// with more than 200 candidates closes its hole only down to the last confirmed one; the leftover must be
/// fetched as a new, smaller hole while the chat stays open. Helpers are in
/// HistoryFillReconciliationTests.swift.
final class ManagedHistoryHolesLeftoverTests: StateSyncTestCase {
    /// One chat view over 250 stored messages under a whole-history hole, the history cleared on the
    /// server. The first fill confirms 51...250 gone and closes 51...top; the view's next hole is the
    /// leftover, `range(50, 1)`, a different entry from the one just filled (so the 20 s "recently
    /// finished" suppression does not apply). The closing transaction emits it while the first fill is
    /// still pending under the same peer and space, so `update` passes it over; the completion must
    /// start it. The view is never re-created here, as a chat that is not scrolled.
    func testLeftoverOfAPartialCloseIsFetchedWhileTheChatStaysOpen() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: Array(1 ... 250))
        self.addHistoryFillHole(peerId)
        self.server.always(getHistory, { _ in .result(StateSyncApi.messages([])) })
        self.server.always(getMessages, { _ in .result(StateSyncApi.messages([])) })

        let views = self.fixture.observe(self.fixture.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: [], count: 20, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .all, orderStatistics: []) |> map { $0.0 })
        views.wait { !$0.isEmpty }
        let (_, holesDisposable) = managedMessageHistoryHoles(accountPeerId: StateSyncFixture.accountPeerId, network: self.network, postbox: self.fixture.postbox, pendingReferences: PendingMessageReferences())
        defer {
            holesDisposable.dispose()
        }

        let fetchedLeftover = self.server.waitForRequest(getHistory, count: 2, timeout: 5.0)
        XCTAssertTrue(fetchedLeftover, "the leftover 1...50 of the partial close was never fetched: \(self.server.requestNames)")
        if fetchedLeftover {
            // range(start: 50, end: 1) as Holes.swift requests a downward range ending at 1.
            XCTAssertEqual(self.server.requests.filter({ $0.name == getHistory }).last?.payload, HistoryFillApi.getHistoryPayload(peer: .inputPeerUser(.init(userId: 500, accessHash: 1)), offsetId: 51, addOffset: 0, limit: 100, maxId: 51, minId: 0))
        }
        self.fixture.eventually(timeout: 5.0) {
            return self.fixture.holes(peerId: peerId).isEmpty
        }
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 1)))
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 250)))
        // The holes are empty once the second fill stored; a third fill its completion started would be
        // sent after that, so the count waits for one first.
        XCTAssertFalse(self.server.waitForRequest(getHistory, count: 3, timeout: 0.5), "a third fill followed: \(self.server.requestNames)")
        XCTAssertEqual(self.server.requestNames, [getHistory, getMessages, getHistory, getMessages])
    }
}
