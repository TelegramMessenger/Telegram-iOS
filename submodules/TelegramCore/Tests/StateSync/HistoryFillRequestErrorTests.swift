import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import MtProtoKit
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"
private let getReplies = "messages.getReplies"

/// A history fill's own request and its errors (owner decision D4, 2026-10-15; audit Q15). A transient
/// error (a 5xx, a flood wait) is retried until the request succeeds, with a growing delay, and never given
/// up; a definite answer (a 4xx, CHANNEL_PRIVATE, a `TL_` failure to parse or verify the answer) closes
/// nothing and is not retried. Before D4 the request had `maxRetries: 0`, so its first error, whatever it
/// was, ended the fill with nothing closed. The fills are driven directly, as ManagedMessageHistoryHoles
/// starts them; no state manager runs.
final class HistoryFillRequestErrorTests: StateSyncTestCase {
    /// Two internal server errors, then the answer: the fill re-sends getHistory until it succeeds and then
    /// closes its hole exactly as a first-time answer would have.
    func testServerErrorIsRetriedUntilTheFillSucceeds() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .error(code: 500, text: "INTERNAL_SERVER_ERROR"))
        self.server.on(getHistory, .error(code: 500, text: "INTERNAL_SERVER_ERROR"))
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ])))

        let result = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(self.server.requestNames, [getHistory, getHistory, getHistory], "the fill gave up on a transient error")
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 10 ... Int(Int32.max - 1)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 10)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }

    /// A flood wait the engine hands back (with `automaticFloodWait` it normally waits one out itself) is
    /// transient too: retried until the request succeeds.
    func testFloodWaitIsRetriedUntilTheFillSucceeds() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .error(code: 420, text: "FLOOD_WAIT_3"))
        self.server.on(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ])))

        let result = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertEqual(self.server.requestNames, [getHistory, getHistory], "the fill gave up on a flood wait")
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 10 ... Int(Int32.max - 1)))
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 10)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }

    /// Pin: a definite answer ends the fill at once with nil. Nothing is retried, stored or closed (the
    /// fill completing at all shows that no retry is pending).
    func testDefiniteErrorClosesNothingAndIsNotRetried() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .error(code: 400, text: "PEER_ID_INVALID"))

        let result = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertNil(result)
        XCTAssertEqual(self.server.requestNames, [getHistory])
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... Int(Int32.max - 1)))
    }

    /// An answer this build cannot read is definite: retrying cannot fix it, and a build that does not know a
    /// new constructor would otherwise ask again forever. An answer of another type than the function's is what
    /// `Network.request` turns into `500 TL_VERIFICATION_ERROR`: the fill sends getHistory once, closes nothing
    /// and ends with nil.
    func testAnswerThisBuildCannotReadClosesNothingAndIsNotRetried() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.addHistoryFillHole(peerId)
        self.server.on(getHistory, .result(StateSyncApi.boolTrue()))
        self.server.always(getHistory, { _ in .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ])) })

        let result = self.runHistoryFill(peerInput: .direct(peerId: peerId, threadId: nil), direction: self.downwardFillDirection(peerId))

        XCTAssertNil(result)
        XCTAssertEqual(self.server.requestNames, [getHistory], "the fill retried an answer it cannot read")
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 10)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... Int(Int32.max - 1)))
    }

    /// Pin, the behaviour the owner kept: a thread fill (messages.getReplies) answered CHANNEL_PRIVATE is not
    /// retried and closes nothing.
    func testChannelPrivateOnAThreadFillIsNotRetried() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let channelId = self.seedChannel(310, pts: 20, storedMessageId: nil)
        self.server.on(getReplies, .error(code: 400, text: "CHANNEL_PRIVATE"))

        let result = self.runHistoryFill(peerInput: .direct(peerId: channelId, threadId: 5), direction: self.downwardFillDirection(channelId))

        XCTAssertNil(result)
        XCTAssertEqual(self.server.requestNames, [getReplies])
    }

    /// The classification behind the retry: a 4xx is definite except a flood wait, CHANNEL_PRIVATE and a `TL_`
    /// failure to parse or verify the answer are definite under any code, everything else is transient.
    func testErrorClassification() {
        func isDefinite(_ code: Int32, _ text: String) -> Bool {
            return historyFillRequestErrorIsDefinite(MTRpcError(errorCode: code, errorDescription: text))
        }
        XCTAssertTrue(isDefinite(400, "PEER_ID_INVALID"))
        XCTAssertTrue(isDefinite(400, "CHANNEL_INVALID"))
        XCTAssertTrue(isDefinite(400, "MSG_ID_INVALID"))
        XCTAssertTrue(isDefinite(400, "CHANNEL_PRIVATE"))
        XCTAssertTrue(isDefinite(406, "CHANNEL_PRIVATE"))
        XCTAssertTrue(isDefinite(500, "CHANNEL_PRIVATE"), "CHANNEL_PRIVATE is definite under any code")
        XCTAssertTrue(isDefinite(420, "FROZEN_METHOD_INVALID"), "a 420 that is not a flood wait is definite")
        XCTAssertTrue(isDefinite(401, "AUTH_KEY_UNREGISTERED"))
        XCTAssertTrue(isDefinite(406, "AUTH_KEY_DUPLICATED"))
        XCTAssertFalse(isDefinite(500, "INTERNAL_SERVER_ERROR"))
        XCTAssertFalse(isDefinite(-500, "INTERNAL_SERVER_ERROR"))
        XCTAssertTrue(isDefinite(500, "TL_VERIFICATION_ERROR"), "an answer of another type than the function's is definite")
        XCTAssertTrue(isDefinite(500, "TL_PARSING_ERROR"), "an answer the engine cannot parse is definite")
        XCTAssertTrue(isDefinite(-500, "TL_PARSING_ERROR"), "a TL_ failure is definite under any code")
        XCTAssertTrue(isDefinite(0, "TL_SOMETHING_NEW"), "every TL_ failure is definite")
        XCTAssertFalse(isDefinite(500, "ENGINE_SWITCHED"))
        XCTAssertFalse(isDefinite(503, "TIMEOUT"))
        XCTAssertFalse(isDefinite(420, "FLOOD_WAIT_3"))
        XCTAssertFalse(isDefinite(420, "FLOOD_PREMIUM_WAIT_3"))
        XCTAssertFalse(isDefinite(400, "FLOOD_WAIT_3"), "a flood wait is transient under any code")
        XCTAssertFalse(isDefinite(0, ""), "a code outside 400...499 is transient")
    }
}
