import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"

/// The bounds of a history fill's `messages.getHistory` (`fetchMessageHistoryHole`): `min_id` and `max_id` are
/// exclusive on the server, and the range a fill closes includes both of its ends, so the request must include
/// them too. Found by the truth server (seed 148): the account reset stores a chat's top message above a hole over
/// `1 ... top - 1`; with top 2 that hole is `1 ... 1`, which a view asks for as `.range(start: 1, end: 1)`, an upward
/// fill. Its `max_id` was the range's end, 1, so it asked for nothing, and the empty answer closed the hole: message 1
/// was never loaded. Helpers are in HistoryFillReconciliationTests.swift.
final class HistoryFillRangeBoundsTests: StateSyncTestCase {
    /// An upward fill asks up to and including its end: `max_id` is the end plus one.
    func testUpwardFillIncludesItsEndId() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        // As the reset stores a dialog's top: Postbox gives the chat's first message a hole over its whole history,
        // and `.UpperHistoryBlock` removes it from 2 up, leaving `1 ... 1`.
        self.fixture.storeMessage(peerId: peerId, id: 2, timestamp: self.baseDate + 2, authorId: peerId, text: "top", location: .UpperHistoryBlock)
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integer: 1), "precondition: the hole is 1 ... 1")
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 1, peerUserId: 500, fromUserId: 500, date: self.baseDate + 1)
        ])))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: .range(start: self.messageId(peerId, 1), end: self.messageId(peerId, 1)))

        XCTAssertEqual(self.server.requests.first?.payload, HistoryFillApi.getHistoryPayload(peer: .inputPeerUser(.init(userId: 500, accessHash: 1)), offsetId: 1, addOffset: -100, limit: 100, maxId: 2, minId: 0), "the request leaves out the range's end id")
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 1)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet())
    }

    /// An around fill asks with no lower bound (`min_id` 0). Found by the truth server (large-world seed 1667): a
    /// channel opened at its first post asked with `min_id` 1, which leaves message 1 out, and the fill closed the
    /// hole over its anchor all the same, so the post was never loaded.
    func testAroundFillAnchoredAtTheFirstMessageAsksForIt() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedChannel(300, pts: 10, storedMessageId: nil)
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.channelMessages(pts: 10, (1 ... 5).reversed().map { StateSyncApi.channelPost(id: $0, channelId: 300, date: self.baseDate + $0) })))

        let _ = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: .aroundId(self.messageId(peerId, 1)))

        XCTAssertEqual(self.server.requests.first?.payload, HistoryFillApi.getHistoryPayload(peer: .inputPeerChannel(.init(channelId: 300, accessHash: 1)), offsetId: 1, addOffset: -50, limit: 100, maxId: Int32.max, minId: 0), "the request leaves out the anchor")
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 1)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(), "the answer's count says it is the whole history")
    }
}
