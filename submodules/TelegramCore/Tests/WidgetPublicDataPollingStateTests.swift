import XCTest
import Postbox
@testable import TelegramCore

/// widget-sandbox v0.2 (W2 plan, Task 4; design §4 calls 3–4, upstream integration.md): the shared-state poller's
/// timing, pure. One visible, watching carrier per widget id; the first poll at once with hash 0, then after each
/// answer's period (5–3600 s), 30 s after a failure; a not-modified answer changes only the timing; a new hash is
/// written to every registered message; a widget back within its id's period waits for the next poll.
final class WidgetPublicDataPollingStateTests: XCTestCase {
    private let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(500))

    private func message(_ id: Int32) -> MessageId {
        return MessageId(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: id)
    }

    func testTheFirstRegistrationPollsAtOnceWithHashZero() {
        var state = WidgetPublicDataPollingState()
        let (_, action) = state.register(widgetId: 42, messageId: self.message(1), now: 100.0)
        XCTAssertEqual(action, .pollAt(100.0))
        XCTAssertEqual(state.hash(widgetId: 42), 0)
        XCTAssertEqual(state.carrier(widgetId: 42), self.message(1))
    }

    func testTheCarrierIsTheOldestRegistrationAndHandsOver() {
        var state = WidgetPublicDataPollingState()
        let (a, _) = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        let (_, second) = state.register(widgetId: 42, messageId: self.message(2), now: 0.0)
        XCTAssertEqual(second, .none, "an id already polled is not polled again for a second widget")
        XCTAssertEqual(state.carrier(widgetId: 42), self.message(1))
        XCTAssertEqual(state.unregister(token: a), .none)
        XCTAssertEqual(state.carrier(widgetId: 42), self.message(2))
    }

    func testThePeriodIsClampedTo5Through3600() {
        var state = WidgetPublicDataPollingState()
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        XCTAssertEqual(state.answered(widgetId: 42, hash: nil, data: nil, period: 1, now: 0.0).next, .pollAt(5.0))
        state.pollStarted(widgetId: 42)
        XCTAssertEqual(state.answered(widgetId: 42, hash: nil, data: nil, period: 10_000, now: 0.0).next, .pollAt(3600.0))
        state.pollStarted(widgetId: 42)
        XCTAssertEqual(state.answered(widgetId: 42, hash: nil, data: nil, period: 60, now: 0.0).next, .pollAt(60.0))
    }

    func testNotModifiedChangesOnlyTheTiming() {
        var state = WidgetPublicDataPollingState()
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 7, data: Data("d7".utf8), period: 30, now: 0.0)
        state.pollStarted(widgetId: 42)
        let answer = state.answered(widgetId: 42, hash: nil, data: nil, period: 30, now: 30.0)
        XCTAssertEqual(answer.write, [])
        XCTAssertEqual(answer.next, .pollAt(60.0))
        XCTAssertEqual(state.hash(widgetId: 42), 7)
    }

    func testANewHashIsWrittenToEveryRegisteredMessage() {
        var state = WidgetPublicDataPollingState()
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        _ = state.register(widgetId: 42, messageId: self.message(2), now: 0.0)
        state.pollStarted(widgetId: 42)
        XCTAssertEqual(state.answered(widgetId: 42, hash: 7, data: Data("d7".utf8), period: 30, now: 0.0).write, [self.message(1), self.message(2)])
        XCTAssertEqual(state.hash(widgetId: 42), 7)
        state.pollStarted(widgetId: 42)
        XCTAssertEqual(state.answered(widgetId: 42, hash: 7, data: Data("d7".utf8), period: 30, now: 30.0).write, [], "the same hash again writes nothing")
    }

    /// Scrolling a watching widget off and on screen polls no faster than its id's period (Review Focus 2).
    func testReRegisteringWithinThePeriodWaitsForTheNextPoll() {
        var state = WidgetPublicDataPollingState()
        let (first, _) = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 7, data: Data("d7".utf8), period: 60, now: 0.0)
        _ = state.unregister(token: first)
        let (second, early) = state.register(widgetId: 42, messageId: self.message(1), now: 10.0)
        XCTAssertEqual(early, .pollAt(60.0))
        _ = state.unregister(token: second)
        let (_, late) = state.register(widgetId: 42, messageId: self.message(1), now: 70.0)
        XCTAssertEqual(late, .pollAt(70.0))
    }

    func testAFailureRetriesAfter30Seconds() {
        var state = WidgetPublicDataPollingState()
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        XCTAssertEqual(state.failed(widgetId: 42, now: 5.0), .pollAt(35.0))
    }

    /// An answer after every registration left keeps the hash and writes nothing, and polling stays stopped (Review
    /// Focus 3).
    func testAnAnswerAfterTheLastRegistrationLeftWritesNothing() {
        var state = WidgetPublicDataPollingState()
        let (token, _) = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.unregister(token: token)
        let answer = state.answered(widgetId: 42, hash: 7, data: Data("d7".utf8), period: 30, now: 1.0)
        XCTAssertEqual(answer.write, [])
        XCTAssertEqual(answer.next, .none)
        XCTAssertEqual(state.hash(widgetId: 42), 7)
        XCTAssertNil(state.carrier(widgetId: 42))
    }

    /// A message that comes on screen after a new state arrived gets that state at once: polling it with the id's hash
    /// would answer "not modified" and leave its stored state behind.
    func testALaterRegistrationGetsTheLatestKnownState() {
        var state = WidgetPublicDataPollingState()
        XCTAssertNil(state.latestData(widgetId: 42))
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 7, data: Data("d7".utf8), period: 30, now: 0.0)
        _ = state.register(widgetId: 42, messageId: self.message(2), now: 1.0)
        XCTAssertEqual(state.latestData(widgetId: 42), Data("d7".utf8))
    }

    /// A message's own hash of its shared state (2026-10-27 schema) is adopted while the id knows none, so the first poll
    /// asks with it; a known hash is never replaced by a message's.
    func testAMessagesHashIsAdoptedWhileNoneIsKnown() {
        var state = WidgetPublicDataPollingState()
        let first = state.register(widgetId: 42, messageId: self.message(1), messageHash: 7, messageData: Data("m7".utf8), now: 0.0)
        XCTAssertEqual(first.action, .pollAt(0.0))
        XCTAssertFalse(first.writeLatest)
        XCTAssertEqual(state.hash(widgetId: 42), 7)
        XCTAssertEqual(state.latestData(widgetId: 42), Data("m7".utf8))
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 9, data: Data("d9".utf8), period: 30, now: 0.0)
        XCTAssertEqual(state.hash(widgetId: 42), 9, "a polled hash is never replaced by a message's")
    }

    /// W2 final review, Important 2: a message whose own hash disagrees with the one the id knows (hashes are not
    /// ordered: it may be the newer) gets nothing written; the id is polled at once without a hash, so the answer is the
    /// whole current state, written to every registration.
    func testADisagreeingMessageHashPollsAtOnceWithoutAHash() {
        var state = WidgetPublicDataPollingState()
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 1, data: Data("d1".utf8), period: 3600, now: 0.0)
        let later = state.register(widgetId: 42, messageId: self.message(2), messageHash: 2, messageData: Data("d2".utf8), now: 100.0)
        XCTAssertFalse(later.writeLatest, "the cached state was written over a message that may carry a newer one")
        XCTAssertEqual(later.action, .pollAt(100.0))
        XCTAssertEqual(state.hash(widgetId: 42), 0)
        state.pollStarted(widgetId: 42)
        XCTAssertEqual(state.answered(widgetId: 42, hash: 2, data: Data("d2".utf8), period: 3600, now: 100.0).write, [self.message(1), self.message(2)])
    }

    /// The fix wave's review: a disagreement while a poll with the old hash is in flight still polls at once once that
    /// poll answers "not modified" (else the disagreeing message would wait a whole period).
    func testADisagreementDuringAPollPollsAgainAtOnceAfterNotModified() {
        var state = WidgetPublicDataPollingState()
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 1, data: Data("d1".utf8), period: 3600, now: 0.0)
        state.pollStarted(widgetId: 42)
        let disagreeing = state.register(widgetId: 42, messageId: self.message(2), messageHash: 2, messageData: Data("d2".utf8), now: 10.0)
        XCTAssertEqual(disagreeing.action, .none, "a poll is in flight")
        let notModified = state.answered(widgetId: 42, hash: nil, data: nil, period: 3600, now: 11.0)
        XCTAssertEqual(notModified.write, [])
        XCTAssertEqual(notModified.next, .pollAt(11.0))
        XCTAssertEqual(state.hash(widgetId: 42), 0)
        state.pollStarted(widgetId: 42)
        let full = state.answered(widgetId: 42, hash: 1, data: Data("d1".utf8), period: 3600, now: 12.0)
        XCTAssertEqual(full.write, [self.message(1), self.message(2)])
        XCTAssertEqual(full.next, .pollAt(3612.0), "one immediate poll, no loop")
    }

    /// The fix wave's review: a message registering while a full (hash 0) poll is in flight adopts nothing, and the full
    /// answer is written to every registration even when its hash is one a message carries.
    func testAFullAnswerIsWrittenToEveryRegistration() {
        var state = WidgetPublicDataPollingState()
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 1, data: Data("d1".utf8), period: 3600, now: 0.0)
        XCTAssertEqual(state.register(widgetId: 42, messageId: self.message(2), messageHash: 2, messageData: Data("d2".utf8), now: 10.0).action, .pollAt(10.0))
        state.pollStarted(widgetId: 42)
        let third = state.register(widgetId: 42, messageId: self.message(3), messageHash: 1, messageData: Data("d1".utf8), now: 10.5)
        XCTAssertEqual(third.action, .none)
        XCTAssertFalse(third.writeLatest)
        XCTAssertEqual(state.hash(widgetId: 42), 0, "nothing adopted while the full poll is in flight")
        XCTAssertEqual(state.answered(widgetId: 42, hash: 1, data: Data("d1".utf8), period: 3600, now: 11.0).write, [self.message(1), self.message(2), self.message(3)])
    }

    /// A disagreement owes a full poll: a message registering before that poll starts adopts nothing (else the poll
    /// would go with its hash, and a "not modified" would leave the disagreeing message as it was).
    func testAMessageRegisteringBeforeTheOwedFullPollAdoptsNothing() {
        var state = WidgetPublicDataPollingState()
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 1, data: Data("d1".utf8), period: 3600, now: 0.0)
        XCTAssertEqual(state.register(widgetId: 42, messageId: self.message(2), messageHash: 2, messageData: Data("d2".utf8), now: 10.0).action, .pollAt(10.0))
        _ = state.register(widgetId: 42, messageId: self.message(3), messageHash: 3, messageData: Data("d3".utf8), now: 10.0)
        XCTAssertEqual(state.hash(widgetId: 42), 0)
        state.pollStarted(widgetId: 42)
        XCTAssertEqual(state.answered(widgetId: 42, hash: 3, data: Data("d3".utf8), period: 3600, now: 11.0).write, [self.message(1), self.message(2), self.message(3)])
    }

    /// The full poll owed after a "not modified" answer to a poll sent with the old hash: a message registering before
    /// it starts adopts nothing either.
    func testAMessageRegisteringAfterNotModifiedBeforeTheFullPollAdoptsNothing() {
        var state = WidgetPublicDataPollingState()
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 1, data: Data("d1".utf8), period: 3600, now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.register(widgetId: 42, messageId: self.message(2), messageHash: 2, messageData: Data("d2".utf8), now: 10.0)
        XCTAssertEqual(state.answered(widgetId: 42, hash: nil, data: nil, period: 3600, now: 11.0).next, .pollAt(11.0))
        _ = state.register(widgetId: 42, messageId: self.message(3), messageHash: 3, messageData: Data("d3".utf8), now: 11.5)
        XCTAssertEqual(state.hash(widgetId: 42), 0)
        state.pollStarted(widgetId: 42)
        XCTAssertEqual(state.answered(widgetId: 42, hash: 3, data: Data("d3".utf8), period: 3600, now: 12.0).write, [self.message(1), self.message(2), self.message(3)])
    }

    /// An owed full poll survives the last registration leaving: a widget back on screen polls at once, not after the
    /// period (else two bubbles of one widget id could disagree for up to an hour).
    func testAnOwedFullPollGoesAtOnceWhenAWidgetComesBack() {
        var state = WidgetPublicDataPollingState()
        let first = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 1, data: Data("d1".utf8), period: 3600, now: 0.0)
        state.pollStarted(widgetId: 42)
        let second = state.register(widgetId: 42, messageId: self.message(2), messageHash: 2, messageData: Data("d2".utf8), now: 10.0)
        _ = state.unregister(token: first.token)
        _ = state.unregister(token: second.token)
        XCTAssertEqual(state.answered(widgetId: 42, hash: nil, data: nil, period: 3600, now: 11.0).next, .none)
        XCTAssertEqual(state.register(widgetId: 42, messageId: self.message(1), messageHash: 1, messageData: Data("d1".utf8), now: 20.0).action, .pollAt(20.0))
    }

    /// A message with the hash the id knows needs no write; one stored before the hash existed gets the latest state.
    func testOnlyAMessageWithoutAHashGetsTheLatestState() {
        var state = WidgetPublicDataPollingState()
        _ = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.answered(widgetId: 42, hash: 1, data: Data("d1".utf8), period: 3600, now: 0.0)
        let same = state.register(widgetId: 42, messageId: self.message(2), messageHash: 1, messageData: Data("d1".utf8), now: 10.0)
        XCTAssertFalse(same.writeLatest)
        XCTAssertEqual(same.action, .none)
        let old = state.register(widgetId: 42, messageId: self.message(3), messageHash: nil, messageData: Data("d0".utf8), now: 10.0)
        XCTAssertTrue(old.writeLatest)
        XCTAssertEqual(old.action, .none)
        XCTAssertEqual(state.hash(widgetId: 42), 1)
    }

    /// A widget that registers while its id's poll is in flight waits for that poll's answer (no second request).
    func testARegistrationDuringAPollWaitsForItsAnswer() {
        var state = WidgetPublicDataPollingState()
        let (token, _) = state.register(widgetId: 42, messageId: self.message(1), now: 0.0)
        state.pollStarted(widgetId: 42)
        _ = state.unregister(token: token)
        let (_, action) = state.register(widgetId: 42, messageId: self.message(2), now: 0.5)
        XCTAssertEqual(action, .none)
        XCTAssertEqual(state.answered(widgetId: 42, hash: 7, data: Data("d7".utf8), period: 30, now: 1.0), (write: [self.message(2)], next: .pollAt(31.0)))
    }
}

private func XCTAssertEqual(_ lhs: (write: [MessageId], next: WidgetPublicDataPollingState.Action), _ rhs: (write: [MessageId], next: WidgetPublicDataPollingState.Action), file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.write, rhs.write, file: file, line: line)
    XCTAssertEqual(lhs.next, rhs.next, file: file, line: line)
}
