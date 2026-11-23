import XCTest
import SwiftSignalKit
@testable import TelegramCore

/// A support account loads chats back to a date and stops there, as in TDesktop's `_dialogsLoadTill`.
/// A Load more tap counts from the hole, not from the cutoff: a database that is already deeper than
/// the cutoff would otherwise stay held however many times it is tapped.
final class SupportChatListLoadingTests: XCTestCase {
    private let week: Int32 = 7 * 24 * 60 * 60

    func testHoleIsHeldAtOrPastTheCutoff() {
        XCTAssertTrue(supportChatListHoleIsHeld(holeTimestamp: 999, loadTill: 1000))
        XCTAssertTrue(supportChatListHoleIsHeld(holeTimestamp: 1000, loadTill: 1000))
        XCTAssertFalse(supportChatListHoleIsHeld(holeTimestamp: 1001, loadTill: 1000))
    }

    func testTopHoleIsNeverHeld() {
        let loadTill = supportChatListInitialLoadTill(now: 1_800_000_000, period: self.week)
        XCTAssertFalse(supportChatListHoleIsHeld(holeTimestamp: Int32.max, loadTill: loadTill))
        XCTAssertFalse(supportChatListHoleIsHeld(holeTimestamp: Int32.max - 1, loadTill: loadTill))
    }

    func testInitialCutoffIsOnePeriodBack() {
        XCTAssertEqual(supportChatListInitialLoadTill(now: 1_800_000_000, period: self.week), 1_800_000_000 - self.week)
        XCTAssertEqual(supportChatListInitialLoadTill(now: 100, period: self.week), 0)
    }

    func testLoadMoreCountsFromAHoleDeeperThanTheCutoff() {
        let current: Int32 = 1_800_000_000
        let hole = current - 4 * self.week
        let updated = supportChatListLoadTillAfterLoadMore(current: current, holeTimestamp: hole, period: self.week)
        XCTAssertEqual(updated, hole - self.week)
        XCTAssertFalse(supportChatListHoleIsHeld(holeTimestamp: hole, loadTill: updated))
    }

    func testLoadMoreNeverPullsTheCutoffForward() {
        let current: Int32 = 1_000_000
        let hole = current + 2 * self.week
        XCTAssertEqual(supportChatListLoadTillAfterLoadMore(current: current, holeTimestamp: hole, period: self.week), current)
    }

    func testLoadMoreStopsAtTheStartOfTime() {
        XCTAssertEqual(supportChatListLoadTillAfterLoadMore(current: 500, holeTimestamp: 100, period: self.week), 0)
    }

    func testContextPublishesLoadMore() {
        let context = SupportContext(settings: .single(.default))
        var values: [Int32] = []
        let disposable = context.chatListLoadTill.start(next: { value in
            values.append(value)
        })
        defer {
            disposable.dispose()
        }

        guard let initial = values.first else {
            XCTFail("the cutoff is published on subscribe")
            return
        }
        let hole = initial - 3 * self.week
        context.loadMoreChats(holeTimestamp: hole)
        XCTAssertEqual(values, [initial, hole - self.week])
    }
}
