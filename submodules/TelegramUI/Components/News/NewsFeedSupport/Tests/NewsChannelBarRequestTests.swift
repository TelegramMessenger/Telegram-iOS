import XCTest
@testable import NewsFeedSupport

/// A bar request stays pending until the stored channel shows its result. Measured on K1: Add to News's answer came
/// back 100 ms before the channel with `in_news` was stored, and a layout in between showed "+ Add to News" again, so
/// the island's transition played twice.
final class NewsChannelBarRequestTests: XCTestCase {
    func testAnsweredAddToNewsStaysPendingUntilTheChannelIsStoredInNews() {
        var request = NewsChannelBarRequest(kind: .addToNews)
        request.answer(at: 10.0)
        XCTAssertTrue(request.isPending(isInNews: false, participation: .left, now: 10.1))
        XCTAssertFalse(request.isPending(isInNews: true, participation: .left, now: 10.1))
    }

    func testAddToNewsIsSettledByAJoinToo() {
        var request = NewsChannelBarRequest(kind: .addToNews)
        request.answer(at: 0.0)
        XCTAssertFalse(request.isPending(isInNews: false, participation: .member, now: 0.1))
    }

    func testAddToChatsStaysPendingUntilTheChannelIsStoredJoined() {
        var request = NewsChannelBarRequest(kind: .addToChats)
        request.answer(at: 0.0)
        XCTAssertTrue(request.isPending(isInNews: true, participation: .left, now: 0.1))
        XCTAssertFalse(request.isPending(isInNews: true, participation: .member, now: 0.1))
    }

    // Until its answer, a request is pending whatever the stored channel shows (another device may change it).
    func testAnUnansweredRequestIsPending() {
        let request = NewsChannelBarRequest(kind: .addToNews)
        XCTAssertTrue(request.isPending(isInNews: true, participation: .member, now: 100.0))
    }

    // A channel whose stored state never shows the result does not hold the bar forever.
    func testAnAnsweredRequestGivesUpAfterTheSettleTimeout() {
        var request = NewsChannelBarRequest(kind: .addToNews)
        request.answer(at: 10.0)
        XCTAssertTrue(request.isPending(isInNews: false, participation: .left, now: 10.0 + NewsChannelBarRequest.settleTimeout - 0.01))
        XCTAssertFalse(request.isPending(isInNews: false, participation: .left, now: 10.0 + NewsChannelBarRequest.settleTimeout))
    }
}
