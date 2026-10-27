import Foundation
import UIKit
import XCTest
@testable import ChatMediaSend

final class ChatMediaSendPlanTests: XCTestCase {
    private func item(_ caption: String? = nil, timer: Int32? = nil, spoiler: Bool = false, price: Int64? = nil, isAnimation: Bool = false, animatedPainting: Bool = false, loop: Bool = false, muted: Bool = false, gif: Bool = false) -> ChatMediaSendItemOptions {
        return ChatMediaSendItemOptions(caption: caption.map { NSAttributedString(string: $0) }, timer: timer, spoiler: spoiler, price: price, isAnimation: isAnimation, hasAnimatedPainting: animatedPainting, livePhotoLoopOrBounce: loop, isMuted: muted, excludedFromGrouping: gif)
    }

    private func global(grouping: Bool = true, forced: String? = nil) -> ChatMediaSendGlobalOptions {
        return ChatMediaSendGlobalOptions(grouping: grouping, forcedCaption: forced.map { NSAttributedString(string: $0) }, forceHd: false)
    }

    private func plan(_ items: [ChatMediaSendItemOptions], _ global: ChatMediaSendGlobalOptions, onMakeKey: () -> Void = {}) -> [ChatMediaSendPlannedItem] {
        var next: Int64 = 0
        return chatMediaSendPlan(items: items, global: global, makeGroupingKey: {
            next += 1
            onMakeKey()
            return next
        })
    }

    func testGroupingKeysShared() {
        let result = plan([item(), item(), item()], global())
        XCTAssertEqual(result.map { $0.groupingKey }, [1, 1, 1])
        XCTAssertEqual(result.map { $0.index }, [0, 1, 2])
    }

    func testGroupKeyRegeneratedAfterTen() {
        let result = plan(Array(repeating: item(), count: 12), global())
        XCTAssertEqual(result.map { $0.groupingKey }, Array(repeating: 1, count: 10).map { Optional(Int64($0)) } + [2, 2])
    }

    func testGroupKeyRegenerationIsEagerAfterTenth() {
        var calls = 0
        let result = plan(Array(repeating: item(), count: 10), global(), onMakeKey: { calls += 1 })
        XCTAssertEqual(Set(result.compactMap { $0.groupingKey }), [1])
        XCTAssertEqual(calls, 2)
    }

    func testSingleItemNoKey() {
        XCTAssertEqual(plan([item()], global()).map { $0.groupingKey }, [nil])
    }

    func testGroupingOffNoKeys() {
        XCTAssertEqual(plan([item(), item()], global(grouping: false)).map { $0.groupingKey }, [nil, nil])
    }

    func testTimerDisablesGrouping() {
        let result = plan([item(), item(), item(timer: 5), item(), item()], global())
        XCTAssertEqual(result.map { $0.groupingKey }, [nil, nil, nil, nil, nil])
        XCTAssertEqual(result[2].timer, 5)
    }

    func testAnimationDisablesGrouping() {
        XCTAssertEqual(plan([item(), item(isAnimation: true)], global()).map { $0.groupingKey }, [nil, nil])
    }

    func testMutedDisablesGrouping() {
        XCTAssertEqual(plan([item(), item(muted: true), item()], global()).map { $0.groupingKey }, [nil, nil, nil])
    }

    func testGifNoKeyOthersStillGrouped() {
        let result = plan([item(), item(gif: true), item()], global())
        XCTAssertEqual(result.map { $0.groupingKey }, [1, nil, 1])
        XCTAssertFalse(item(gif: true).isAnimation)

        let many = plan((0 ..< 12).map { item(gif: $0 == 3) }, global())
        XCTAssertEqual(many.map { $0.groupingKey }, [1, 1, 1, nil, 1, 1, 1, 1, 1, 1, 2, 2])

        let forced = plan([item(gif: true), item(), item()], global(forced: "F"))
        XCTAssertEqual(forced.map { $0.caption?.string }, ["F", nil, nil])

        XCTAssertEqual(plan([item(), item(gif: true)], global(grouping: false)).map { $0.groupingKey }, [nil, nil])
    }

    func testGifCountsTowardAlbumOfTenLikeLegacy() {
        let result = plan([item(gif: true)] + Array(repeating: item(), count: 10), global())
        XCTAssertEqual(result.map { $0.groupingKey }, [nil] + Array(repeating: Optional(Int64(1)), count: 9) + [2])
    }

    func testAnimatedPaintingDisablesGrouping() {
        XCTAssertEqual(plan([item(animatedPainting: true), item()], global()).map { $0.groupingKey }, [nil, nil])
    }

    func testLoopBounceDisablesGrouping() {
        XCTAssertEqual(plan([item(), item(loop: true)], global()).map { $0.groupingKey }, [nil, nil])
    }

    func testForcedCaptionFirstWhenGroupedLastWhenNot() {
        let items = [item("a"), item("b"), item("c")]
        let grouped = plan(items, global(forced: "F"))
        XCTAssertEqual(grouped.map { $0.caption?.string }, ["F", nil, nil])
        let ungrouped = plan(items, global(grouping: false, forced: "F"))
        XCTAssertEqual(ungrouped.map { $0.caption?.string }, [nil, nil, "F"])
    }

    func testForcedCaptionAcrossTwelveItems() {
        let items = (0 ..< 12).map { item("c\($0)") }
        let grouped = plan(items, global(forced: "F"))
        XCTAssertEqual(grouped.compactMap { $0.caption?.string }, ["F"])
        XCTAssertNotNil(grouped[0].caption)
        let ungrouped = plan(items, global(grouping: false, forced: "F"))
        XCTAssertEqual(ungrouped.compactMap { $0.caption?.string }, ["F"])
        XCTAssertNotNil(ungrouped[11].caption)
    }

    func testForcedCaptionWithTimerFallsToLast() {
        let result = plan([item("a"), item("b", timer: 3), item("c")], global(forced: "F"))
        XCTAssertEqual(result.map { $0.caption?.string }, [nil, nil, "F"])
    }

    func testPerItemCaptionsWithoutForced() {
        let result = plan([item("a"), item(nil), item("c")], global())
        XCTAssertEqual(result.map { $0.caption?.string }, ["a", nil, "c"])
    }

    func testFirstPriceAppliesToAll() {
        let result = plan([item(), item(price: 50), item(price: 90)], global())
        XCTAssertEqual(result.map { $0.price }, [50, 50, 50])
        XCTAssertEqual(plan([item(), item()], global()).map { $0.price }, [nil, nil])
    }

    func testEmptyForcedCaptionEmptiesEveryCaption() {
        let result = plan([item("a"), item("b")], global(forced: ""))
        XCTAssertEqual(result.map { $0.caption?.string }, ["", ""])
        XCTAssertEqual(plan([item("a"), item("b")], global(grouping: false, forced: "")).map { $0.caption?.length }, [0, 0])
    }

    func testSpoilerPassesThrough() {
        XCTAssertEqual(plan([item(spoiler: true), item()], global()).map { $0.spoiler }, [true, false])
    }

    func testTimerOnlyWithinLimitsKept() {
        let result = plan([item(timer: 0), item(timer: 61), item(timer: 2147483647)], global())
        XCTAssertEqual(result.map { $0.timer }, [nil, 61, 2147483647])
    }

    func testZeroTimerIsNoTimer() {
        let result = plan([item(timer: 0), item(), item(timer: 0)], global())
        XCTAssertEqual(result.map { $0.groupingKey }, [1, 1, 1])
        XCTAssertEqual(result.map { $0.timer }, [nil, nil, nil])
    }

    func testTimerItemsExcludedFromCameraRoll() {
        let result = plan([item(), item(timer: 10), item(timer: 0), item(timer: 2147483647)], global())
        XCTAssertEqual(result.map { $0.isExcludedFromCameraRoll }, [false, true, false, true])
    }

    func testEmptyInput() {
        XCTAssertTrue(plan([], global()).isEmpty)
    }
}
