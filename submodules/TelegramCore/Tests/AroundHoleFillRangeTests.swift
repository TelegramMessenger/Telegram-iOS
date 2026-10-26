import XCTest
import Postbox
@testable import TelegramCore

/// The around request (`offsetId: post, addOffset: -50, limit: 100`) returns every newer message up
/// to 50, the post, and 50 older ones; the server does not fill downward. `offset_id_offset` is the
/// 1-based position of the anchor counted from the newest message (observed 16 with 15 newer ids,
/// 17/16 and 9/8 on 2026-10-13). So the top was reached exactly when the newer ids returned number
/// one less than that position, and the whole history is known when the result holds `count`
/// messages. Anything else closes only the fetched span around the anchor.
final class AroundHoleFillRangeTests: XCTestCase {
    private let top: Int32 = Int32.max - 1

    func testTopReached() {
        // Channel 2232931988, post 32499: 15 newer, the post, 50 older, offset_id_offset 16.
        let ids = Array(Int32(32449) ... 32514)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 32499, ids: ids, totalCount: 31636, offsetIdOffset: 16, inexact: false), 32449 ... self.top)
    }

    func testTopNotReached() {
        let ids = Array(Int32(50) ... 150)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 100, ids: ids, totalCount: 10000, offsetIdOffset: 60, inexact: false), 50 ... 150)
    }

    func testNoOffsetKeepsTheFetchedSpan() {
        let ids = Array(Int32(50) ... 150)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 100, ids: ids, totalCount: nil, offsetIdOffset: nil, inexact: false), 50 ... 150)
    }

    func testInexactVetoesEverything() {
        let ids = Array(Int32(32449) ... 32514)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 32499, ids: ids, totalCount: 66, offsetIdOffset: 16, inexact: true), 32449 ... 32514)
    }

    func testWholeHistoryKnown() {
        let ids = Array(Int32(1) ... 40)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 20, ids: ids, totalCount: 40, offsetIdOffset: 21, inexact: false), 1 ... self.top)
    }

    func testWholeHistoryNeedsEveryMessageCounted() {
        // A custom-tag space keeps only some returned messages client-side.
        let ids = Array(Int32(1) ... 30)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 20, ids: ids, totalCount: 40, offsetIdOffset: 21, inexact: false), 1 ... 30)
    }

    func testAnchorAbsent() {
        // The post was deleted: no top inference, the fetched span only.
        let ids = Array(Int32(50) ... 99) + Array(Int32(101) ... 150)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 100, ids: ids, totalCount: 10000, offsetIdOffset: 51, inexact: false), 50 ... 150)
    }

    func testAnchorOutsideTheSpanIsIncluded() {
        let ids = Array(Int32(120) ... 150)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 100, ids: ids, totalCount: 10000, offsetIdOffset: 60, inexact: false), 100 ... 150)
    }

    func testEmptyResultHasNoRange() {
        XCTAssertNil(aroundHoleFillRange(anchorId: 100, ids: [], totalCount: 0, offsetIdOffset: nil, inexact: false))
    }

    func testWholeHistoryNeedsNoOffset() {
        // A slice whose count equals the ids returned, or a messages.messages result: the whole list.
        let ids = Array(Int32(1) ... 40)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 20, ids: ids, totalCount: 40, offsetIdOffset: nil, inexact: false), 1 ... self.top)
    }

    func testZeroOffsetInfersNothing() {
        let ids = Array(Int32(50) ... 150)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 100, ids: ids, totalCount: 10000, offsetIdOffset: 0, inexact: false), 50 ... 150)
    }

    func testMoreNewerIdsThanThePositionAllowsInfersNothing() {
        let ids = Array(Int32(50) ... 150)
        XCTAssertEqual(aroundHoleFillRange(anchorId: 100, ids: ids, totalCount: 10000, offsetIdOffset: 40, inexact: false), 50 ... 150)
    }
}
