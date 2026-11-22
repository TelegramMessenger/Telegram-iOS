import XCTest
@testable import CoreList
@testable import MediaGrid

final class MediaGridZoomCoverageTests: XCTestCase {
    private func makeView() -> MediaGridView {
        let dataSource = TestDataSource(count: 10_000)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.motionClock = { 0.0 }
        view.scaleOverride = 3.0
        view.geometryInsets = UIEdgeInsets(top: 100.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        return view
    }

    func testNoZoomReportsNoContentMinY() {
        let view = self.makeView()
        XCTAssertNil(view.zoomContentMinY)
    }

    func testZoomingInAtTopMovesContentAboveTopInset() {
        let view = self.makeView()
        var frames = 0
        view.onZoomFrame = {
            frames += 1
        }
        let center = CGPoint(x: view.bounds.midX, y: 500.0)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 1.6)
        guard let minY = view.zoomContentMinY else {
            XCTFail("no content during the zoom")
            return
        }
        XCTAssertLessThan(minY, 100.0)
        XCTAssertGreaterThan(frames, 0)
    }

    func testContentMinYClearsWhenPinchEnds() {
        let view = self.makeView()
        let center = CGPoint(x: view.bounds.midX, y: 500.0)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 1.6)
        XCTAssertNotNil(view.zoomContentMinY)
        view._testPinch(.ended, center: center, scale: 1.6, velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertNil(view.zoomContentMinY)
    }
}
