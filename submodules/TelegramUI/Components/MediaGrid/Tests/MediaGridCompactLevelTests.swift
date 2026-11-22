import XCTest
@testable import CoreList
@testable import MediaGrid

final class MediaGridCompactLevelTests: XCTestCase {
    private func makeView(count: Int, compactTopInset: CGFloat? = 0.0, header: UIView? = nil, headerHeight: CGFloat = 0.0) -> MediaGridView {
        let dataSource = TestDataSource(count: count)
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.motionClock = { 0.0 }
        view.scaleOverride = 3.0
        view.geometryInsets = UIEdgeInsets(top: 100.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.compactLevelTopInset = compactTopInset
        view.headerView = header
        view.headerHeight = headerHeight
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        view.layoutIfNeeded()
        return view
    }

    private func firstRowMinY(_ view: MediaGridView) -> CGFloat {
        return view.contentFrameForItem(at: 0)?.minY ?? -1.0
    }

    func testCompactLevelsStartAtTheCompactTopInset() {
        let view = self.makeView(count: 10_000)
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(self.firstRowMinY(view), 100.0, accuracy: 1e-6)
        for level in [MediaGridLevel.fifteen, .thirtyOne] {
            view.setLevel(level, animated: false)
            view.layoutIfNeeded()
            XCTAssertEqual(view.level, level)
            XCTAssertEqual(self.firstRowMinY(view), 0.0, accuracy: 1e-6)
            XCTAssertEqual(view.frameForItem(at: 0)?.minY ?? -1.0, 0.0, accuracy: 1e-6)
        }
        for level in [MediaGridLevel.five, .three, .one] {
            view.setLevel(level, animated: false)
            view.layoutIfNeeded()
            XCTAssertEqual(self.firstRowMinY(view), 100.0, accuracy: 1e-6)
        }
    }

    func testWithoutACompactTopInsetEveryLevelKeepsTheTopInset() {
        let view = self.makeView(count: 10_000, compactTopInset: nil)
        for level in [MediaGridLevel.fifteen, .thirtyOne, .three] {
            view.setLevel(level, animated: false)
            view.layoutIfNeeded()
            XCTAssertEqual(self.firstRowMinY(view), 100.0, accuracy: 1e-6)
        }
    }

    func testHeaderIsHiddenAtCompactLevels() {
        let header = UIView()
        let view = self.makeView(count: 10_000, header: header, headerHeight: 44.0)
        XCTAssertEqual(self.firstRowMinY(view), 144.0, accuracy: 1e-6)
        XCTAssertFalse(header.isHidden)
        view.setLevel(.fifteen, animated: true)
        view._testFinishAnimations()
        view.layoutIfNeeded()
        XCTAssertEqual(self.firstRowMinY(view), 0.0, accuracy: 1e-6)
        XCTAssertTrue(header.isHidden)
        view.setLevel(.five, animated: true)
        view._testFinishAnimations()
        view.layoutIfNeeded()
        XCTAssertEqual(self.firstRowMinY(view), 144.0, accuracy: 1e-6)
        XCTAssertFalse(header.isHidden)
        XCTAssertEqual(header.alpha, 1.0, accuracy: 1e-6)
        XCTAssertTrue(CATransform3DIsIdentity(header.layer.transform))
        XCTAssertEqual(header.frame, CGRect(x: 0.0, y: 100.0, width: 393.0, height: 44.0))
    }

    func testCompactLayoutIsNotRebuiltWhenTheTopInsetChanges() {
        let view = self.makeView(count: 10_000)
        view.setLevel(.fifteen, animated: false)
        view.layoutIfNeeded()
        view.setContentOffset(500.0)
        view.geometryInsets = UIEdgeInsets(top: 120.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.layoutIfNeeded()
        XCTAssertEqual(self.firstRowMinY(view), 0.0, accuracy: 1e-6)
        XCTAssertEqual(view.contentOffset, 500.0, accuracy: 1e-6)
        view.setLevel(.five, animated: false)
        view.layoutIfNeeded()
        XCTAssertEqual(self.firstRowMinY(view), 120.0, accuracy: 1e-6)
    }

    func testPinchBetweenLevelsWithDifferentInsetsKeepsTheAnchorUnderTheFinger() {
        let view = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        guard let anchorIndex = view.index(at: center) else {
            XCTFail("no anchor")
            return
        }
        view._testPinch(.began, center: center)
        var scale: CGFloat = 1.0
        while scale > 3.0 / 15.0 {
            scale *= 0.97
            view._testPinch(.changed, center: center, scale: scale)
        }
        view._testPinch(.ended, center: center, scale: scale, velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .fifteen)
        XCTAssertEqual(self.firstRowMinY(view), 0.0, accuracy: 1e-6)
        guard let frame = view.frameForItem(at: anchorIndex) else {
            XCTFail("no frame")
            return
        }
        XCTAssertTrue(frame.minY - 1.0 <= center.y && center.y <= frame.maxY + 1.0, "\(frame) \(center)")

        guard let compactAnchorIndex = view.index(at: center) else {
            XCTFail("no anchor")
            return
        }
        view._testPinch(.began, center: center)
        scale = 1.0
        while scale < 15.0 / 3.0 {
            scale /= 0.97
            view._testPinch(.changed, center: center, scale: scale)
        }
        view._testPinch(.ended, center: center, scale: scale, velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(self.firstRowMinY(view), 100.0, accuracy: 1e-6)
        guard let back = view.frameForItem(at: compactAnchorIndex) else {
            XCTFail("no frame")
            return
        }
        XCTAssertTrue(back.minY - 1.0 <= center.y && center.y <= back.maxY + 1.0, "\(back) \(center)")
    }

    func testTapZoomFromCompactLevelKeepsTheTappedPhotoUnderTheFinger() {
        let view = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        view.setLevel(.fifteen, animated: false)
        view.layoutIfNeeded()
        let point = CGPoint(x: 200.0, y: 300.0)
        guard let index = view.index(at: point) else {
            XCTFail("no index")
            return
        }
        view._testTap(at: point)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .five)
        XCTAssertEqual(self.firstRowMinY(view), 100.0, accuracy: 1e-6)
        guard let frame = view.frameForItem(at: index) else {
            XCTFail("no frame")
            return
        }
        XCTAssertTrue(frame.minY - 1.0 <= point.y && point.y <= frame.maxY + 1.0, "\(frame) \(point)")
    }

    func testTargetLevelFollowsThePinchBeforeRelease() {
        let view = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        var targets: [MediaGridLevel] = []
        view.onTargetLevelChanged = { targets.append($0) }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        XCTAssertEqual(view.targetLevel, .three)
        view._testPinch(.changed, center: center, scale: pow(3.0 / 5.0, 0.3))
        XCTAssertEqual(targets, [])
        view._testPinch(.changed, center: center, scale: pow(3.0 / 5.0, 0.7))
        XCTAssertEqual(targets, [.five])
        XCTAssertEqual(view.targetLevel, .five)
        view._testPinch(.changed, center: center, scale: 3.0 / 5.0 * pow(5.0 / 15.0, 0.7))
        XCTAssertEqual(targets, [.five, .fifteen])
        XCTAssertEqual(view.level, .three)
        view._testPinch(.changed, center: center, scale: 3.0 / 5.0 * pow(5.0 / 15.0, 0.2))
        XCTAssertEqual(targets, [.five, .fifteen, .five])
        view._testPinch(.changed, center: center, scale: pow(3.0 / 5.0, 0.2))
        XCTAssertEqual(targets, [.five, .fifteen, .five, .three])
        view._testPinch(.ended, center: center, scale: pow(3.0 / 5.0, 0.2), velocity: 0.0)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .three)
        XCTAssertEqual(targets, [.five, .fifteen, .five, .three])
    }

    func testTargetLevelOnReleaseFollowsVelocityAndEndsAtTheFinalLevel() {
        let view = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        var targets: [MediaGridLevel] = []
        view.onTargetLevelChanged = { targets.append($0) }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        view._testPinch(.began, center: center)
        view._testPinch(.changed, center: center, scale: 3.0 / 5.0 * pow(5.0 / 15.0, 0.3))
        XCTAssertEqual(targets, [.five])
        view._testPinch(.ended, center: center, scale: 3.0 / 5.0 * pow(5.0 / 15.0, 0.3), velocity: -2.0)
        XCTAssertEqual(targets, [.five, .fifteen])
        XCTAssertEqual(view.targetLevel, .fifteen)
        view._testFinishAnimations()
        XCTAssertEqual(view.level, .fifteen)
        XCTAssertEqual(targets, [.five, .fifteen])
    }

    func testTargetLevelChangesAtTheStartOfTapAndMenuZoom() {
        let view = self.makeView(count: 100_000)
        view.setContentOffset(20_000.0)
        var targets: [MediaGridLevel] = []
        view.onTargetLevelChanged = { targets.append($0) }
        view.zoomOut()
        XCTAssertTrue(view.isZooming)
        XCTAssertEqual(targets, [.five])
        view._testFinishAnimations()
        view.zoomOut()
        XCTAssertTrue(view.isZooming)
        XCTAssertEqual(targets, [.five, .fifteen])
        XCTAssertEqual(view.targetLevel, .fifteen)
        view._testFinishAnimations()
        view._testTap(at: CGPoint(x: 200.0, y: 300.0))
        XCTAssertTrue(view.isZooming)
        XCTAssertEqual(targets, [.five, .fifteen, .five])
        view._testFinishAnimations()
        XCTAssertEqual(targets, [.five, .fifteen, .five])
        view.setLevel(.thirtyOne, animated: false)
        XCTAssertEqual(targets, [.five, .fifteen, .five, .thirtyOne])
    }
}
