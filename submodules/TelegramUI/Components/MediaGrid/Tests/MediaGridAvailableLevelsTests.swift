import XCTest
@testable import CoreList
@testable import MediaGrid

final class MediaGridAvailableLevelsTests: XCTestCase {
    private let profileLevels: [MediaGridLevel] = [.three, .five, .fifteen]

    private func makeView(count: Int, levels: [MediaGridLevel]? = nil) -> MediaGridView {
        let dataSource = TestDataSource(count: count)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.motionClock = { 0.0 }
        view.scaleOverride = 3.0
        if let levels {
            view.availableLevels = levels
        }
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        return view
    }

    func testZoomStepsStayWithinAvailableLevels() {
        XCTAssertNil(MediaGridLevel.fifteen.zoomedOut(within: self.profileLevels))
        XCTAssertNil(MediaGridLevel.three.zoomedIn(within: self.profileLevels))
        XCTAssertEqual(MediaGridLevel.five.zoomedOut(within: self.profileLevels), .fifteen)
        XCTAssertEqual(MediaGridLevel.fifteen.zoomedIn(within: self.profileLevels), .five)
        XCTAssertEqual(MediaGridLevel.three.rotated(toLandscape: true, within: self.profileLevels), .five)
        XCTAssertEqual(MediaGridLevel.fifteen.rotated(toLandscape: true, within: self.profileLevels), .fifteen)
    }

    func testPinchStopsAtAvailableBounds() {
        let view = self.makeView(count: 10_000, levels: self.profileLevels)
        view.setLevel(.fifteen, animated: false)
        view.layoutIfNeeded()
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 0.2)
        view._testPinch(.ended, center: center, scale: 0.2, velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .fifteen)

        view.setLevel(.three, animated: false)
        view.layoutIfNeeded()
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 5.0)
        view._testPinch(.ended, center: center, scale: 5.0, velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .three)
    }

    func testPinchFromFiveOutLandsOnFifteen() {
        let view = self.makeView(count: 10_000, levels: self.profileLevels)
        view.setLevel(.five, animated: false)
        view.layoutIfNeeded()
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 0.1)
        view._testPinch(.ended, center: center, scale: 0.1, velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .fifteen)
    }

    func testTapAtFifteenZoomsToFive() {
        let view = self.makeView(count: 10_000, levels: self.profileLevels)
        view.setLevel(.fifteen, animated: false)
        view.layoutIfNeeded()
        view._testTap(at: CGPoint(x: 50.0, y: 200.0))
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
    }

    func testMenuZoomRespectsAvailableLevels() {
        let view = self.makeView(count: 10_000, levels: self.profileLevels)
        view.setLevel(.fifteen, animated: false)
        XCTAssertFalse(view.canZoomOut)
        XCTAssertTrue(view.canZoomIn)
        view.zoomIn()
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
        view.setLevel(.three, animated: false)
        XCTAssertFalse(view.canZoomIn)
        XCTAssertTrue(view.canZoomOut)
    }

    func testSettingAvailableLevelsMovesCurrentLevel() {
        let view = self.makeView(count: 10_000)
        view.setLevel(.one, animated: false)
        view.layoutIfNeeded()
        view.availableLevels = self.profileLevels
        XCTAssertEqual(view.level, .three)
        view.setLevel(.thirtyOne, animated: false)
        XCTAssertEqual(view.level, .fifteen)
    }

    func testEmptyAvailableLevelsIsIgnored() {
        let view = self.makeView(count: 10_000, levels: self.profileLevels)
        view.availableLevels = []
        XCTAssertEqual(view.availableLevels, self.profileLevels)
    }

    func testDefaultLevelsUnchanged() {
        let view = self.makeView(count: 10_000)
        XCTAssertEqual(view.availableLevels, MediaGridLevel.allCases)
    }
}
