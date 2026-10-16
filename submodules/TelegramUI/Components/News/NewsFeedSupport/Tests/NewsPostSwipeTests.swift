import XCTest
import CoreGraphics
@testable import NewsFeedSupport

final class NewsPostSwipeTests: XCTestCase {
    // MARK: options

    // The reveal control draws the right side's last option at the row's edge and performs it on a full swipe:
    // that is Not Interested (the mockup's `feedSwipeActions`, first button = edge = full swipe).
    func testNotInterestedIsTheEdgeOptionAndTheFullSwipeTarget() {
        XCTAssertEqual(newsPostSwipeActions, [.interesting, .notInterested])
    }

    // An option's key is the action's raw value; the row maps the key back.
    func testActionsRoundTripThroughTheOptionKey() {
        for action in newsPostSwipeActions {
            XCTAssertEqual(NewsPostSwipeAction(rawValue: action.rawValue), action)
        }
        XCTAssertEqual(Set(newsPostSwipeActions.map(\.rawValue)).count, newsPostSwipeActions.count)
    }

    // MARK: pager

    // The chat list's folder pager edge width: width / 6, clamped to 22...80.
    func testRevealZoneIsTheChatListEdgeWidth() {
        XCTAssertEqual(newsPagerRevealZoneWidth(width: 402.0), 67.0, accuracy: 0.0001)
        XCTAssertEqual(newsPagerRevealZoneWidth(width: 320.0), 320.0 / 6.0, accuracy: 0.0001)
        XCTAssertEqual(newsPagerRevealZoneWidth(width: 100.0), 22.0, accuracy: 0.0001)
        XCTAssertEqual(newsPagerRevealZoneWidth(width: 1024.0), 80.0, accuracy: 0.0001)
    }

    func testPagerDefersOnlyInTheZoneOfARevealableRow() {
        // The zone on a 402 pt list starts at 335.
        XCTAssertTrue(newsPagerDefersToRowReveal(touchX: 400.0, width: 402.0, rightInset: 0.0, isOnRevealableRow: true))
        XCTAssertTrue(newsPagerDefersToRowReveal(touchX: 335.0, width: 402.0, rightInset: 0.0, isOnRevealableRow: true))
        XCTAssertFalse(newsPagerDefersToRowReveal(touchX: 334.0, width: 402.0, rightInset: 0.0, isOnRevealableRow: true))
        XCTAssertFalse(newsPagerDefersToRowReveal(touchX: 201.0, width: 402.0, rightInset: 0.0, isOnRevealableRow: true))
        // Over the interests block, a status row or empty space the pager keeps the touch.
        XCTAssertFalse(newsPagerDefersToRowReveal(touchX: 400.0, width: 402.0, rightInset: 0.0, isOnRevealableRow: false))
    }

    // Rows end at the list's right safe inset (iPhone Duo folded portrait: 466 wide, right inset 84; landscape iPhones
    // too): the zone is the row's own right-edge strip, not the screen's, which there lay wholly inside the inset.
    func testRevealZoneIsTheRowsRightEdgeStripInsideASafeInset() {
        // Row width 382: zone 63.67 pt, from 318.33 to 382.
        XCTAssertTrue(newsPagerDefersToRowReveal(touchX: 381.0, width: 466.0, rightInset: 84.0, isOnRevealableRow: true))
        XCTAssertTrue(newsPagerDefersToRowReveal(touchX: 319.0, width: 466.0, rightInset: 84.0, isOnRevealableRow: true))
        XCTAssertFalse(newsPagerDefersToRowReveal(touchX: 317.0, width: 466.0, rightInset: 84.0, isOnRevealableRow: true))
        // iPhone landscape: 874 wide, right inset 62 — a full 80 pt strip on the row.
        XCTAssertTrue(newsPagerDefersToRowReveal(touchX: 733.0, width: 874.0, rightInset: 62.0, isOnRevealableRow: true))
        XCTAssertFalse(newsPagerDefersToRowReveal(touchX: 731.0, width: 874.0, rightInset: 62.0, isOnRevealableRow: true))
    }

    // MARK: separators

    // The separator between two rows is the upper row's; it fades with the lower row's swipe surface.
    func testTheRowAboveAnOpenRowTakesItsSeparatorAlpha() {
        let alphas = newsSeparatorAlphasFromRowsBelow([3: 1.0, 4: 1.0, 5: 0.25, 6: 1.0])
        XCTAssertEqual(alphas, [3: 1.0, 4: 0.25, 5: 1.0, 6: 1.0])
    }

    // No loaded post row directly below (the last loaded row, or the interests block in between): fully shown.
    func testARowWithNoPostRowBelowKeepsItsSeparator() {
        let alphas = newsSeparatorAlphasFromRowsBelow([2: 1.0, 4: 0.0])
        XCTAssertEqual(alphas, [2: 1.0, 4: 1.0])
    }

    // Recomputed from scratch on every change: a row that was above the open row before an insertion recovers.
    func testRecomputingAfterTheOpenRowMovedRestoresTheOldNeighbour() {
        XCTAssertEqual(newsSeparatorAlphasFromRowsBelow([4: 1.0, 5: 0.0])[4], 0.0)
        XCTAssertEqual(newsSeparatorAlphasFromRowsBelow([4: 1.0, 5: 1.0, 6: 0.0])[4], 1.0)
    }
}
