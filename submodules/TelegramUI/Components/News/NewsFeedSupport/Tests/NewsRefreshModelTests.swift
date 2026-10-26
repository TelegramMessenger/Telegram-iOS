import XCTest
import CoreGraphics
@testable import NewsFeedSupport

final class NewsRefreshModelTests: XCTestCase {
    /// Island bottom 100, the search field's top at rest 116 (16 below it), first post at 160, a 402-wide screen.
    static func input(gap: CGFloat = 0.0, dragging: Bool = false, atEdge: Bool = true, canPull: Bool = true, firstPostTop: CGFloat? = 160.0) -> NewsRefreshInput {
        return NewsRefreshInput(
            gap: gap,
            isDragging: dragging,
            atEdge: atEdge,
            canPull: canPull,
            islandFrame: CGRect(x: 87.0, y: 60.0, width: 228.0, height: 40.0),
            restingSearchFieldTop: 116.0,
            firstPostTop: firstPostTop
        )
    }

    /// A model that crossed the threshold at t = 0.
    private func loading() -> NewsRefreshModel {
        var model = NewsRefreshModel()
        XCTAssertEqual(model.step(now: 0.0, input: Self.input(gap: 80.0, dragging: true)), [.begin])
        return model
    }

    func testThresholdWithTheFingerDownBegins() {
        var model = NewsRefreshModel()
        XCTAssertEqual(model.step(now: 0.0, input: Self.input(gap: 75.0, dragging: true)), [])
        XCTAssertEqual(model.step(now: 0.1, input: Self.input(gap: 76.0, dragging: true)), [.begin])
        XCTAssertEqual(model.phase, .loading(since: 0.1))
    }

    func testNoBeginWithoutTheFingerOrWhenPullingIsNotAllowed() {
        var model = NewsRefreshModel()
        XCTAssertEqual(model.step(now: 0.0, input: Self.input(gap: 120.0, dragging: false)), [])
        XCTAssertEqual(model.step(now: 0.1, input: Self.input(gap: 120.0, dragging: true, canPull: false)), [])
        XCTAssertEqual(model.phase, .idle)
    }

    func testAPullWhileLoadingIsIgnored() {
        var model = self.loading()
        XCTAssertEqual(model.step(now: 0.5, input: Self.input(gap: 140.0, dragging: true)), [])
    }

    func testLoadingLastsAtLeastMinLoading() {
        var model = self.loading()
        model.fetchEnded(.posts(2))
        _ = model.step(now: 1.19, input: Self.input(gap: 60.0))
        XCTAssertEqual(model.phase, .loading(since: 0.0))
        _ = model.step(now: 1.2, input: Self.input(gap: 60.0))
        guard case .retracting(since: 1.2, _, _) = model.phase else {
            return XCTFail("\(model.phase)")
        }
    }

    func testALateBatchFinishesWhenItArrivesAndNoBatchNeverFinishes() {
        var model = self.loading()
        _ = model.step(now: 60.0, input: Self.input(gap: 60.0))
        XCTAssertEqual(model.phase, .loading(since: 0.0))
        model.fetchEnded(.posts(1))
        _ = model.step(now: 60.5, input: Self.input(gap: 60.0))
        guard case .retracting(since: 60.5, _, _) = model.phase else {
            return XCTFail("\(model.phase)")
        }
    }

    func testHoldIsHeldThenReleasedOverASmoothstepWhenTheDropRetracts() {
        var model = self.loading()
        XCTAssertEqual(model.hold(now: 0.5), 60.0)
        model.fetchEnded(.posts(1))
        _ = model.step(now: 1.2, input: Self.input(gap: 60.0))
        XCTAssertEqual(model.hold(now: 1.2), 60.0)
        XCTAssertEqual(model.hold(now: 1.2 + 0.15), 30.0, accuracy: 1e-6)
        XCTAssertEqual(model.hold(now: 1.2 + 0.3), 0.0, accuracy: 1e-9)
    }

    // Every refresh ends with the drop going back into the island: no fall onto the posts, no landing haptic.
    func testNewPostsRetractTheDropAndSlideInOnceTheListRests() {
        var model = self.loading()
        model.fetchEnded(.posts(3))
        XCTAssertEqual(model.step(now: 1.2, input: Self.input(gap: 60.0)), [])
        guard case .retracting(since: 1.2, _, _) = model.phase else {
            return XCTFail("\(model.phase)")
        }
        XCTAssertTrue(model.isRevealPending)
        XCTAssertEqual(model.step(now: 1.5, input: Self.input(gap: 0.0)), [])
        // Released 0.38 s ago, at the edge, finger up.
        XCTAssertEqual(model.step(now: 1.59, input: Self.input(gap: 0.0)), [.insertRows(slides: true)])
        XCTAssertEqual(model.phase, .idle)
        XCTAssertFalse(model.isRevealPending)
        XCTAssertFalse(model.dropPose(now: 1.59, input: Self.input()).isVisible)
    }

    func testNothingNewRetractsTheDropAndShowsTheResultPlainly() {
        var model = self.loading()
        model.fetchEnded(.nothing)
        XCTAssertEqual(model.step(now: 1.2, input: Self.input(gap: 60.0)), [.insertRows(slides: false)])
        guard case .retracting(since: 1.2, _, _) = model.phase else {
            return XCTFail("\(model.phase)")
        }
        _ = model.step(now: 1.6, input: Self.input())
        XCTAssertEqual(model.phase, .idle)
        XCTAssertFalse(model.isRevealPending)
    }

    func testRetractWithNothingStillShowsTheResult() {
        var model = self.loading()
        model.detach(now: 0.5, input: Self.input(gap: 60.0))
        model.fetchEnded(.nothing)
        XCTAssertEqual(model.step(now: 1.0, input: Self.input()), [.insertRows(slides: false)])
    }

    func testAFingerDownDelaysTheSlide() {
        var model = self.loading()
        model.fetchEnded(.posts(1))
        _ = model.step(now: 1.2, input: Self.input(gap: 60.0))
        XCTAssertEqual(model.step(now: 1.5, input: Self.input(gap: 30.0, dragging: true)), [])
        XCTAssertEqual(model.step(now: 2.2, input: Self.input(gap: 5.0, dragging: true, atEdge: false)), [])
        // Lifted at 2.2: inserted once it is at the edge, finger up, 0.38 s after the lift.
        XCTAssertEqual(model.step(now: 2.5, input: Self.input()), [])
        XCTAssertEqual(model.step(now: 2.59, input: Self.input()), [.insertRows(slides: true)])
    }

    // Away from the edge after 0.9 s the posts go in without moving what is on screen.
    func testTheSlideFallsBackAfterPointNineSeconds() {
        var model = self.loading()
        model.fetchEnded(.posts(1))
        _ = model.step(now: 1.2, input: Self.input(gap: 60.0, atEdge: false))
        XCTAssertEqual(model.step(now: 2.09, input: Self.input(atEdge: false)), [])
        XCTAssertEqual(model.step(now: 2.11, input: Self.input(atEdge: false)), [.insertRows(slides: false)])
    }

    func testFirstPostOffScreenAtFinishRevealsPlainly() {
        var model = self.loading()
        model.fetchEnded(.posts(4))
        XCTAssertEqual(model.step(now: 1.2, input: Self.input(gap: 60.0, firstPostTop: nil)), [.insertRows(slides: false)])
        guard case .retracting(since: 1.2, _, _) = model.phase else {
            return XCTFail("\(model.phase)")
        }
        XCTAssertEqual(model.step(now: 1.4, input: Self.input(firstPostTop: nil)), [])
        _ = model.step(now: 1.51, input: Self.input(firstPostTop: nil))
        XCTAssertEqual(model.phase, .idle)
    }

    func testDetachWhileLoadingRevealsPlainlyWhenTheBatchArrives() {
        var model = self.loading()
        model.detach(now: 0.5, input: Self.input(gap: 60.0))
        XCTAssertEqual(model.hold(now: 0.5 + 0.3), 0.0, accuracy: 1e-9)
        XCTAssertEqual(model.step(now: 3.0, input: Self.input()), [])
        model.fetchEnded(.posts(2))
        XCTAssertEqual(model.step(now: 3.1, input: Self.input()), [.insertRows(slides: false)])
        _ = model.step(now: 3.2, input: Self.input())
        XCTAssertEqual(model.phase, .idle)
    }

    func testDetachWhileTheSlideWaitsRevealsPlainlyAtOnce() {
        var model = self.loading()
        model.fetchEnded(.posts(2))
        _ = model.step(now: 1.2, input: Self.input(gap: 60.0))
        model.detach(now: 1.3, input: Self.input(gap: 20.0))
        XCTAssertEqual(model.step(now: 1.31, input: Self.input()), [.insertRows(slides: false)])
        XCTAssertFalse(model.isRevealPending)
    }

    func testOneLateStepRunsTheWholeFinish() {
        var model = self.loading()
        model.fetchEnded(.posts(2))
        _ = model.step(now: 1.2, input: Self.input(gap: 60.0))
        // The app was in the background for ten seconds.
        XCTAssertEqual(model.step(now: 11.2, input: Self.input()), [.insertRows(slides: true)])
        XCTAssertEqual(model.hold(now: 11.2), 0.0)
        XCTAssertEqual(model.phase, .idle)
    }

    func testAFingerHeldThroughALandingDoesNotBeginASecondRefresh() {
        var model = self.loading()
        model.fetchEnded(.nothing)
        _ = model.step(now: 1.2, input: Self.input(gap: 80.0, dragging: true))
        _ = model.step(now: 1.9, input: Self.input(gap: 80.0, dragging: true))
        XCTAssertEqual(model.phase, .idle)
        // Still pulled past the threshold, finger down: a new drag is needed.
        XCTAssertEqual(model.step(now: 1.95, input: Self.input(gap: 80.0, dragging: true)), [])
        _ = model.step(now: 2.0, input: Self.input(gap: 0.0, dragging: false))
        XCTAssertEqual(model.step(now: 2.1, input: Self.input(gap: 80.0, dragging: true)), [.begin])
    }

    func testLiveness() {
        var model = NewsRefreshModel()
        XCTAssertFalse(model.isLive(now: 0.0, gap: 0.0))
        XCTAssertTrue(model.isLive(now: 0.0, gap: 1.0))
        _ = model.step(now: 0.0, input: Self.input(gap: 80.0, dragging: true))
        XCTAssertTrue(model.isLive(now: 100.0, gap: 0.0))
    }
}
