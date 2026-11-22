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

    func testLoadingPoseIsCentredBetweenTheIslandAndTheSearchField() {
        var model = NewsRefreshModel()
        _ = model.step(now: 0.0, input: self.input(gap: 80.0, dragging: true))
        let bob = 1.5 * CGFloat(sin(2.0 * Double.pi / 1.6))
        // Held 60 pt: the search field's top is 116 + 60, 76 below the island's bottom, so the 44 pt drop sits 16
        // below the island and 16 above the field.
        let held = model.dropPose(now: 1.0, input: self.input(gap: 60.0))
        XCTAssertEqual(held.top, 16.0 + bob, accuracy: 1e-6)
        XCTAssertEqual(held.diameter, 44.0, accuracy: 1e-6)
        XCTAssertEqual(held.iconTime, 0.1, accuracy: 1e-9)
        XCTAssertEqual(held.iconAngle, CGFloat(4.0 * Double.pi / 180.0 * sin(2.0 * Double.pi / 1.5)), accuracy: 1e-6)
        // Pulled further while loading: it stays centred in the larger gap (136 below the island).
        XCTAssertEqual(model.dropPose(now: 1.0, input: self.input(gap: 120.0, dragging: true)).top, 46.0 + bob, accuracy: 1e-6)
    }

    // Loading starts from the drop where the pull left it and settles on the centre within 0.3 s.
    func testLoadingPoseEasesFromThePullToTheCentre() {
        var model = NewsRefreshModel()
        _ = model.step(now: 0.0, input: self.input(gap: 80.0, dragging: true))
        // At the threshold the pulled drop is 18 below the island + 0.45 pt per point past it.
        XCTAssertEqual(model.dropPose(now: 0.0, input: self.input(gap: 80.0, dragging: true)).top, 18.0 + 4.0 * 0.45, accuracy: 1e-6)
        // By 0.3 s it is on the centre of the 96 pt gap, give or take the bob.
        XCTAssertEqual(model.dropPose(now: 0.3, input: self.input(gap: 80.0, dragging: true)).top, (16.0 + 80.0 - 44.0) * 0.5, accuracy: 1.5)
    }

    func testFinishRetractsIntoTheIsland() {
        var model = NewsRefreshModel()
        _ = model.step(now: 0.0, input: self.input(gap: 80.0, dragging: true))
        model.fetchEnded(.posts(1))
        _ = model.step(now: 1.2, input: self.input(gap: 60.0))
        let start = model.dropPose(now: 1.2, input: self.input(gap: 60.0))
        XCTAssertTrue(start.isVisible)
        XCTAssertEqual(start.diameter, 44.0, accuracy: 1e-6)
        let mid = model.dropPose(now: 1.35, input: self.input(gap: 30.0))
        XCTAssertLessThan(mid.diameter, 44.0)
        XCTAssertLessThan(mid.top, start.top)
        XCTAssertFalse(model.dropPose(now: 1.51, input: self.input()).isVisible)
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
}
