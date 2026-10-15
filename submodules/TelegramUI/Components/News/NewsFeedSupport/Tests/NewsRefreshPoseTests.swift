import XCTest
import CoreGraphics
@testable import NewsFeedSupport

final class NewsRefreshPoseTests: XCTestCase {
    private func input(gap: CGFloat = 0.0, dragging: Bool = false, firstPostTop: CGFloat? = 160.0) -> NewsRefreshInput {
        return NewsRefreshModelTests.input(gap: gap, dragging: dragging, firstPostTop: firstPostTop)
    }

    func testPullPose() {
        let model = NewsRefreshModel()
        XCTAssertFalse(model.dropPose(now: 0.0, input: self.input(gap: 0.4)).isVisible)
        let at28 = model.dropPose(now: 0.0, input: self.input(gap: 28.0, dragging: true))
        XCTAssertTrue(at28.isVisible)
        XCTAssertEqual(at28.diameter, 35.5, accuracy: 1e-6)
        XCTAssertEqual(at28.top, -35.5 + 53.5 * 28.0 / 76.0, accuracy: 1e-6)
        XCTAssertEqual(model.dropPose(now: 0.0, input: self.input(gap: 56.0)).diameter, 44.0, accuracy: 1e-6)
        XCTAssertEqual(model.dropPose(now: 0.0, input: self.input(gap: 76.0)).top, 18.0, accuracy: 1e-6)
        XCTAssertEqual(model.dropPose(now: 0.0, input: self.input(gap: 100.0)).top, 28.8, accuracy: 1e-6)
        let atThreshold = model.dropPose(now: 0.0, input: self.input(gap: 76.0))
        XCTAssertEqual(atThreshold.iconTime, 34.0 / 60.0, accuracy: 1e-9)
        XCTAssertEqual(atThreshold.iconAlpha, 1.0, accuracy: 1e-9)
    }

    func testLoadingPoseHangsAndBobs() {
        var model = NewsRefreshModel()
        _ = model.step(now: 0.0, input: self.input(gap: 80.0, dragging: true))
        // Held 60 pt: 8 + 60 = 68 below the island, so the drop rests at max(24, 68 - 52) = 24.
        let pose = model.dropPose(now: 1.0, input: self.input(gap: 60.0))
        XCTAssertEqual(pose.top, 24.0 + 1.5 * CGFloat(sin(2.0 * Double.pi / 1.6)), accuracy: 1e-6)
        XCTAssertEqual(pose.iconTime, 0.1, accuracy: 1e-9)
        XCTAssertEqual(pose.iconAngle, CGFloat(4.0 * Double.pi / 180.0 * sin(2.0 * Double.pi / 1.5)), accuracy: 1e-6)
    }

    func testFinishingWindsUpAndFalls() {
        var model = NewsRefreshModel()
        _ = model.step(now: 0.0, input: self.input(gap: 80.0, dragging: true))
        model.fetchEnded(.posts(1))
        _ = model.step(now: 1.2, input: self.input(gap: 60.0))
        guard case let .finishing(_, fallFromTop, _) = model.phase else {
            return XCTFail("\(model.phase)")
        }
        // Target: the drop's centre on the card's top edge, 160 + 3 - 22 - 100 = 41 below the island.
        let windUp = model.dropPose(now: 1.2 + 0.23, input: self.input())
        XCTAssertEqual(windUp.top, fallFromTop - 5.0, accuracy: 1e-6)
        let mid = model.dropPose(now: 1.2 + 0.47, input: self.input())
        XCTAssertEqual(mid.top, fallFromTop + (41.0 - fallFromTop) * 0.25, accuracy: 1e-6)
        XCTAssertEqual(model.dropPose(now: 1.2 + 0.66, input: self.input()).top, 41.0, accuracy: 1e-6)
        let exit = model.dropPose(now: 1.2 + 0.25, input: self.input())
        XCTAssertEqual(exit.iconScale, 0.55, accuracy: 1e-6)
        XCTAssertEqual(exit.iconBlur, 7.0, accuracy: 1e-6)
        XCTAssertEqual(exit.iconAlpha, 0.0, accuracy: 1e-6)
        XCTAssertEqual(exit.iconAngle, 0.0, accuracy: 1e-6)
    }

    func testRetractShrinksIntoTheIsland() {
        var model = NewsRefreshModel()
        _ = model.step(now: 0.0, input: self.input(gap: 80.0, dragging: true))
        model.detach(now: 0.5, input: self.input(gap: 60.0))
        XCTAssertTrue(model.dropPose(now: 0.6, input: self.input()).isVisible)
        let end = model.dropPose(now: 0.79, input: self.input())
        XCTAssertLessThan(end.diameter, 11.0)
        XCTAssertFalse(model.dropPose(now: 0.81, input: self.input()).isVisible)
    }

    private func unfolded(count: Int = 2) -> NewsRefreshModel {
        var model = NewsRefreshModel()
        _ = model.step(now: 0.0, input: self.input(gap: 80.0, dragging: true))
        model.fetchEnded(.posts(count))
        _ = model.step(now: 1.2, input: self.input(gap: 60.0))
        // Finger down at impact, so the rows wait.
        _ = model.step(now: 1.86, input: self.input(dragging: true))
        return model
    }

    func testTheDropRestsOnTheCardEdgeUntilTheRowsGoIn() {
        let model = self.unfolded()
        // Finger down at impact: no rows yet. The drop sits centred on the card's top edge, 160 + 3 - 22 - 100 = 41.
        let pose = model.dropPose(now: 2.0, input: self.input(dragging: true))
        XCTAssertTrue(pose.isVisible)
        XCTAssertEqual(pose.top, 41.0, accuracy: 1e-6)
        XCTAssertEqual(pose.diameter, 44.0, accuracy: 1e-6)
        XCTAssertEqual(pose.scale, 1.0)
        XCTAssertEqual(pose.alpha, 1.0)
        XCTAssertEqual(pose.iconAlpha, 0.0)
    }

    func testTheDropShrinksAndFadesAsTheBlockComesIn() {
        var model = self.unfolded()
        _ = model.step(now: 2.3, input: self.input())
        let inserted = model.unfold!.inserted!
        let B = NewsFreshBlock.self
        let M = NewsRefreshMetrics.self

        // Until the block starts to come in, the drop rests on the card's top edge, whole.
        let rest = model.dropPose(now: inserted + B.contentDelay * 0.5, input: self.input())
        XCTAssertTrue(rest.isVisible)
        XCTAssertEqual(rest.top, 41.0, accuracy: 1e-6)
        XCTAssertEqual(rest.scale, 1.0, accuracy: 1e-9)
        XCTAssertEqual(rest.alpha, 1.0, accuracy: 1e-9)

        // Then it fades and shrinks in step with the block's alpha.
        for f in [0.25, 0.5, 0.75] {
            let t = B.contentDelay + B.inDuration * f
            let pose = model.dropPose(now: inserted + t, input: self.input(firstPostTop: 170.0))
            XCTAssertTrue(pose.isVisible)
            XCTAssertEqual(pose.top, 51.0, accuracy: 1e-6)
            XCTAssertEqual(pose.diameter, 44.0, accuracy: 1e-6)
            XCTAssertEqual(pose.scale, 1.0 + (M.dropOutScale - 1.0) * B.alpha(at: t), accuracy: 1e-9)
            XCTAssertEqual(pose.alpha, 1.0 - B.alpha(at: t), accuracy: 1e-9)
        }
        XCTAssertEqual(B.alpha(at: B.contentDelay + B.inDuration), 1.0, accuracy: 1e-9)
        XCTAssertFalse(model.dropPose(now: inserted + B.contentDelay + B.inDuration, input: self.input()).isVisible)
        XCTAssertGreaterThanOrEqual(M.unfoldLinger, B.contentDelay + B.inDuration)
    }
}
