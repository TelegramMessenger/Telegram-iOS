import XCTest
@testable import NewsFeedSupport

/// A bar request stays pending until the stored channel shows its result. Measured on K1: Add to News's answer came
/// back 100 ms before the channel with `in_news` was stored, and a layout in between showed "+ Add to News" again, so
/// the island's transition played twice.
final class NewsChannelBarRequestTests: XCTestCase {
    func testAnsweredAddToNewsStaysPendingUntilTheChannelIsStoredInNews() {
        var request = NewsChannelBarRequest(kind: .addToNews)
        request.answer(at: 10.0)
        XCTAssertTrue(request.isPending(isInNews: false, participation: .left, isMuted: false, now: 10.1))
        XCTAssertFalse(request.isPending(isInNews: true, participation: .left, isMuted: false, now: 10.1))
    }

    func testAddToNewsIsSettledByAJoinToo() {
        var request = NewsChannelBarRequest(kind: .addToNews)
        request.answer(at: 0.0)
        XCTAssertFalse(request.isPending(isInNews: false, participation: .member, isMuted: false, now: 0.1))
    }

    func testAddToChatsStaysPendingUntilTheChannelIsStoredJoined() {
        var request = NewsChannelBarRequest(kind: .addToChats)
        request.answer(at: 0.0)
        XCTAssertTrue(request.isPending(isInNews: true, participation: .left, isMuted: false, now: 0.1))
        XCTAssertFalse(request.isPending(isInNews: true, participation: .member, isMuted: false, now: 0.1))
    }

    // Until its answer, a request is pending whatever the stored channel shows (another device may change it).
    func testAnUnansweredRequestIsPending() {
        let request = NewsChannelBarRequest(kind: .addToNews)
        XCTAssertTrue(request.isPending(isInNews: true, participation: .member, isMuted: false, now: 100.0))
    }

    // A channel whose stored state never shows the result does not hold the bar forever.
    func testAnAnsweredRequestGivesUpAfterTheSettleTimeout() {
        var request = NewsChannelBarRequest(kind: .addToNews)
        request.answer(at: 10.0)
        XCTAssertTrue(request.isPending(isInNews: false, participation: .left, isMuted: false, now: 10.0 + NewsChannelBarRequest.settleTimeout - 0.01))
        XCTAssertFalse(request.isPending(isInNews: false, participation: .left, isMuted: false, now: 10.0 + NewsChannelBarRequest.settleTimeout))
    }

    // A menu item is applied before the menu closes, so the island morphs back already showing it. Remove from News
    // and a mute choice change only Postbox, so the bar holds them until the stored channel shows them.
    func testRemoveFromNewsIsPendingUntilTheChannelIsStoredOutOfNews() {
        var request = NewsChannelBarRequest(kind: .removeFromNews)
        request.answer(at: 0.0)
        XCTAssertTrue(request.isPending(isInNews: true, participation: .left, isMuted: false, now: 0.1))
        XCTAssertFalse(request.isPending(isInNews: false, participation: .left, isMuted: false, now: 0.1))
    }

    func testAMuteChoiceIsPendingUntilTheStoredSettingMatches() {
        var mute = NewsChannelBarRequest(kind: .setMuted(true))
        mute.answer(at: 0.0)
        XCTAssertTrue(mute.isPending(isInNews: false, participation: .member, isMuted: false, now: 0.1))
        XCTAssertFalse(mute.isPending(isInNews: false, participation: .member, isMuted: true, now: 0.1))
        var unmute = NewsChannelBarRequest(kind: .setMuted(false))
        unmute.answer(at: 0.0)
        XCTAssertTrue(unmute.isPending(isInNews: false, participation: .member, isMuted: true, now: 0.1))
        XCTAssertFalse(unmute.isPending(isInNews: false, participation: .member, isMuted: false, now: 0.1))
    }
}
