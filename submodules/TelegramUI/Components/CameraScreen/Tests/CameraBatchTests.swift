import XCTest

final class CameraBatchTests: XCTestCase {
    func testAutoReviewAt1And10s() {
        var list = CameraBatchList<Int>(maxCount: 100, isSingleShot: false)
        var opened: [Int] = []
        for index in 1 ... 25 {
            let result = list.append(id: "\(index)", payload: index)
            if case let .appended(opensReview) = result {
                if opensReview {
                    opened.append(index)
                }
            } else {
                XCTFail("refused \(index)")
            }
        }
        XCTAssertEqual(opened, [1, 10, 20])
        XCTAssertEqual(list.count, 25)
        XCTAssertEqual(list.entries.map(\.id), (1 ... 25).map { "\($0)" })

        XCTAssertTrue(cameraBatchOpensReview(count: 1, isSingleShot: false))
        XCTAssertFalse(cameraBatchOpensReview(count: 2, isSingleShot: false))
        XCTAssertFalse(cameraBatchOpensReview(count: 9, isSingleShot: false))
        XCTAssertTrue(cameraBatchOpensReview(count: 10, isSingleShot: false))
        XCTAssertFalse(cameraBatchOpensReview(count: 11, isSingleShot: false))
        XCTAssertTrue(cameraBatchOpensReview(count: 100, isSingleShot: false))
        XCTAssertFalse(cameraBatchOpensReview(count: 0, isSingleShot: false))
    }

    func testLimit100() {
        var list = CameraBatchList<Int>(maxCount: 100, isSingleShot: false)
        for index in 1 ... 99 {
            XCTAssertNotEqual(list.append(id: "\(index)", payload: index), .refused)
        }
        XCTAssertTrue(list.acceptsCapture)
        XCTAssertEqual(list.append(id: "100", payload: 100), .appended(opensReview: true))
        XCTAssertFalse(list.acceptsCapture)
        XCTAssertEqual(list.append(id: "101", payload: 101), .refused)
        XCTAssertEqual(list.count, 100)
        XCTAssertNil(list.entries.first(where: { $0.id == "101" }))

        XCTAssertEqual(list.remove(id: "50"), 50)
        XCTAssertTrue(list.acceptsCapture)
        XCTAssertEqual(list.append(id: "101", payload: 101), .appended(opensReview: true))
        XCTAssertEqual(list.count, 100)

        XCTAssertTrue(cameraBatchAcceptsCapture(count: 99, maxCount: 100, isSingleShot: false))
        XCTAssertFalse(cameraBatchAcceptsCapture(count: 100, maxCount: 100, isSingleShot: false))
    }

    func testSingleShotOpensImmediately() {
        var list = CameraBatchList<Int>(maxCount: 100, isSingleShot: true)
        XCTAssertTrue(list.acceptsCapture)
        XCTAssertEqual(list.append(id: "a", payload: 1), .appended(opensReview: true))
        XCTAssertFalse(list.acceptsCapture)
        XCTAssertEqual(list.append(id: "b", payload: 2), .refused)
        XCTAssertEqual(list.count, 1)
        XCTAssertTrue(cameraBatchOpensReview(count: 1, isSingleShot: true))
        XCTAssertEqual(cameraBatchCapacity(maxCount: 100, isSingleShot: true), 1)
        XCTAssertEqual(cameraBatchCapacity(maxCount: 100, isSingleShot: false), 100)
    }

    func testDiscardConfirmationWhenNonEmpty() {
        XCTAssertEqual(cameraBatchCancelAction(count: 0, pendingCount: 0), .dismiss)
        XCTAssertEqual(cameraBatchCancelAction(count: 1, pendingCount: 0), .confirmDiscard)
        XCTAssertEqual(cameraBatchCancelAction(count: 100, pendingCount: 0), .confirmDiscard)
        XCTAssertEqual(cameraBatchCancelAction(count: 0, pendingCount: 1), .confirmDiscard)
        XCTAssertTrue(cameraBatchAllowsInteractiveDismiss(count: 0, pendingCount: 0))
        XCTAssertFalse(cameraBatchAllowsInteractiveDismiss(count: 3, pendingCount: 0))
        XCTAssertFalse(cameraBatchAllowsInteractiveDismiss(count: 0, pendingCount: 1))

        var list = CameraBatchList<Int>(maxCount: 100, isSingleShot: false)
        let _ = list.append(id: "a", payload: 1)
        let _ = list.append(id: "b", payload: 2)
        XCTAssertEqual(cameraBatchCancelAction(count: list.count, pendingCount: list.pendingCount), .confirmDiscard)
        XCTAssertEqual(list.removeAll(), [1, 2])
        XCTAssertEqual(list.count, 0)
        XCTAssertEqual(cameraBatchCancelAction(count: list.count, pendingCount: list.pendingCount), .dismiss)
    }

    func testPendingShotCountsForCancelAndLimit() {
        var list = CameraBatchList<Int>(maxCount: 2, isSingleShot: false)
        XCTAssertFalse(list.hasContent)
        list.beginPending()
        XCTAssertTrue(list.hasContent)
        XCTAssertEqual(cameraBatchCancelAction(count: list.count, pendingCount: list.pendingCount), .confirmDiscard)
        XCTAssertFalse(cameraBatchAllowsInteractiveDismiss(count: list.count, pendingCount: list.pendingCount))
        let _ = list.append(id: "a", payload: 1)
        list.endPending()
        list.beginPending()
        XCTAssertFalse(list.acceptsCapture)
        list.endPending()
        list.endPending()
        XCTAssertEqual(list.pendingCount, 0)
        XCTAssertTrue(list.acceptsCapture)
        XCTAssertEqual(cameraBatchCancelAction(count: 0, pendingCount: 0), .dismiss)
        XCTAssertEqual(cameraBatchCancelAction(count: 0, pendingCount: 1), .confirmDiscard)
        XCTAssertTrue(cameraBatchAllowsInteractiveDismiss(count: 0, pendingCount: 0))
    }

    func testClosedBatchRefusesLateAppend() {
        var list = CameraBatchList<Int>(maxCount: 100, isSingleShot: false)
        let _ = list.append(id: "a", payload: 1)
        list.beginPending()
        XCTAssertEqual(list.close(), [1])
        XCTAssertTrue(list.isClosed)
        XCTAssertEqual(list.count, 0)
        XCTAssertFalse(list.acceptsCapture)
        XCTAssertEqual(list.append(id: "b", payload: 2), .refused)
        list.endPending()
        XCTAssertEqual(list.count, 0)
        XCTAssertEqual(list.pendingCount, 0)
    }

    func testRemoveUnknownIdKeepsItems() {
        var list = CameraBatchList<Int>(maxCount: 100, isSingleShot: false)
        let _ = list.append(id: "a", payload: 1)
        XCTAssertNil(list.remove(id: "x"))
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list.append(id: "a", payload: 2), .refused)
    }

    func testReviewWaitsForRecordingToStop() {
        XCTAssertEqual(cameraBatchReviewRequest(isRecording: false), .open)
        XCTAssertEqual(cameraBatchReviewRequest(isRecording: true), .deferUntilRecordingStops)
        XCTAssertFalse(cameraBatchOpensDeferredReview(hasDeferredReview: false, isRecording: false, pendingCount: 0))
        XCTAssertFalse(cameraBatchOpensDeferredReview(hasDeferredReview: true, isRecording: true, pendingCount: 0))
        XCTAssertFalse(cameraBatchOpensDeferredReview(hasDeferredReview: true, isRecording: false, pendingCount: 1))
        XCTAssertTrue(cameraBatchOpensDeferredReview(hasDeferredReview: true, isRecording: false, pendingCount: 0))
    }

    func testPanDismissOutcome() {
        XCTAssertEqual(cameraBatchPanDismissOutcome(count: 0, pendingCount: 0, completes: true), .dismiss)
        XCTAssertEqual(cameraBatchPanDismissOutcome(count: 0, pendingCount: 0, completes: false), .snapBack)
        XCTAssertEqual(cameraBatchPanDismissOutcome(count: 2, pendingCount: 0, completes: true), .confirmDiscard)
        XCTAssertEqual(cameraBatchPanDismissOutcome(count: 0, pendingCount: 1, completes: true), .confirmDiscard)
        XCTAssertEqual(cameraBatchPanDismissOutcome(count: 2, pendingCount: 0, completes: false), .snapBack)
    }

    func testChromeHeldWhileAutoReviewIsPending() {
        XCTAssertEqual(cameraBatchChromeCount(count: 1, heldCount: 0), 0)
        XCTAssertEqual(cameraBatchChromeCount(count: 10, heldCount: 9), 9)
        XCTAssertEqual(cameraBatchChromeCount(count: 3, heldCount: nil), 3)
        XCTAssertEqual(cameraBatchChromeCount(count: 2, heldCount: 5), 2)

        XCTAssertTrue(cameraBatchKeepsChromeHold(opensReview: true, presentation: .opened))
        XCTAssertTrue(cameraBatchKeepsChromeHold(opensReview: true, presentation: .deferred))
        XCTAssertFalse(cameraBatchKeepsChromeHold(opensReview: true, presentation: .unavailable))
        XCTAssertFalse(cameraBatchKeepsChromeHold(opensReview: false, presentation: .opened))
        XCTAssertFalse(cameraBatchKeepsChromeHold(opensReview: false, presentation: .unavailable))

        var list = CameraBatchList<Int>(maxCount: 100, isSingleShot: false)
        var hold: Int? = list.count
        if case let .appended(opensReview) = list.append(id: "a", payload: 1) {
            XCTAssertTrue(opensReview)
            XCTAssertEqual(cameraBatchChromeCount(count: list.count, heldCount: hold), 0)
            if !cameraBatchKeepsChromeHold(opensReview: opensReview, presentation: .opened) {
                hold = nil
            }
        } else {
            XCTFail()
        }
        XCTAssertEqual(cameraBatchChromeCount(count: list.count, heldCount: hold), 0)
        hold = nil
        XCTAssertEqual(cameraBatchChromeCount(count: list.count, heldCount: hold), 1)

        hold = list.count
        if case let .appended(opensReview) = list.append(id: "b", payload: 2) {
            XCTAssertFalse(opensReview)
            if !cameraBatchKeepsChromeHold(opensReview: opensReview, presentation: .opened) {
                hold = nil
            }
        }
        XCTAssertEqual(cameraBatchChromeCount(count: list.count, heldCount: hold), 2)

        var single = CameraBatchList<Int>(maxCount: 100, isSingleShot: true)
        let singleHold: Int? = single.count
        if case let .appended(opensReview) = single.append(id: "s", payload: 1) {
            XCTAssertTrue(cameraBatchKeepsChromeHold(opensReview: opensReview, presentation: .opened))
        }
        XCTAssertEqual(cameraBatchChromeCount(count: single.count, heldCount: singleHold), 0)
    }
}
