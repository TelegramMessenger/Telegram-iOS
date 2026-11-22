import XCTest
@testable import QrStudioScreen

final class QrStudioSheetMotionTests: XCTestCase {
    private func run(_ motion: QrStudioSheetMotion, seconds: Double, step: Double = 1.0 / 120.0, each: ((Double) -> Void)? = nil) {
        var time = 0.0
        while time < seconds {
            motion.step(step)
            time += step
            each?(time)
        }
    }

    private func makeGeometry(height: CGFloat = 874) -> QrStudioSheetGeometry {
        return QrStudioSheetGeometry(screen: CGSize(width: 402, height: height), safeBottom: 34, capsuleWidth: 152, bottomCornerRadius: 55)
    }

    func testOpenReachesTargetAndSettles() {
        let motion = QrStudioSheetMotion()
        XCTAssertTrue(motion.isSettled)
        motion.open(animated: true)
        XCTAssertTrue(motion.isOpen)
        XCTAssertFalse(motion.isSettled)
        self.run(motion, seconds: 2.0)
        XCTAssertEqual(motion.rise, 1)
        XCTAssertEqual(motion.spread, 1)
        XCTAssertTrue(motion.isSettled)
    }

    func testOpeningSpreadLeadsRiseAndRiseOvershootsSlightly() {
        let motion = QrStudioSheetMotion()
        motion.open(animated: true)
        var maxRise: CGFloat = 0
        self.run(motion, seconds: 1.5, each: { time in
            if time > 0.02 && time < 0.2 {
                XCTAssertGreaterThanOrEqual(motion.spread, motion.rise, "at \(time)")
            }
            maxRise = max(maxRise, motion.rise)
        })
        XCTAssertGreaterThan(maxRise, 1.0)
        XCTAssertLessThan(maxRise, 1.08)
    }

    func testCloseWithoutBounceNeverUndershootsSpread() {
        let motion = QrStudioSheetMotion()
        motion.open(animated: false)
        XCTAssertEqual(motion.rise, 1)
        motion.close(velocity: 0, travel: 300)
        XCTAssertFalse(motion.isOpen)
        self.run(motion, seconds: 1.5, each: { _ in
            XCTAssertGreaterThanOrEqual(motion.spread, -0.0001)
        })
        XCTAssertEqual(motion.rise, 0)
        XCTAssertEqual(motion.spread, 0)
        XCTAssertEqual(motion.pull, 0)
        XCTAssertTrue(motion.isSettled)
    }

    func testReopenDuringCloseKeepsVelocity() {
        let motion = QrStudioSheetMotion()
        motion.open(animated: false)
        motion.close(velocity: 0, travel: 300)
        self.run(motion, seconds: 0.1)
        let before = motion.rise
        motion.step(1.0 / 120.0)
        let fallingStep = motion.rise - before
        XCTAssertLessThan(fallingStep, 0)
        motion.open(animated: true)
        let atReopen = motion.rise
        motion.step(1.0 / 120.0)
        let firstStep = motion.rise - atReopen
        XCTAssertLessThan(firstStep, 0)
        XCTAssertLessThan(abs(firstStep - fallingStep), abs(fallingStep) * 0.5)
        self.run(motion, seconds: 2.0)
        XCTAssertEqual(motion.rise, 1)
    }

    func testDragDownIsOneToOneAndUpwardResists() {
        let motion = QrStudioSheetMotion()
        motion.open(animated: false)
        motion.drag(80)
        XCTAssertTrue(motion.isDragging)
        XCTAssertEqual(motion.pull, 80)
        motion.drag(-200)
        XCTAssertLessThan(motion.pull, 0)
        XCTAssertGreaterThan(motion.pull, -24)
    }

    func testDragIgnoredWhenClosed() {
        let motion = QrStudioSheetMotion()
        motion.drag(80)
        XCTAssertEqual(motion.pull, 0)
        XCTAssertFalse(motion.isDragging)
    }

    func testReleaseThresholds() {
        let far = QrStudioSheetMotion()
        far.open(animated: false)
        far.drag(111)
        far.release(velocity: 0, travel: 200)
        XCTAssertFalse(far.isOpen)

        let near = QrStudioSheetMotion()
        near.open(animated: false)
        near.drag(100)
        near.release(velocity: 0, travel: 200)
        XCTAssertTrue(near.isOpen)
        self.run(near, seconds: 2.0)
        XCTAssertEqual(near.pull, 0)

        let fast = QrStudioSheetMotion()
        fast.open(animated: false)
        fast.drag(13)
        fast.release(velocity: 701, travel: 300)
        XCTAssertFalse(fast.isOpen)

        let fastButShort = QrStudioSheetMotion()
        fastButShort.open(animated: false)
        fastButShort.drag(10)
        fastButShort.release(velocity: 2000, travel: 300)
        XCTAssertTrue(fastButShort.isOpen)
    }

    func testCloseCarriesReleaseVelocity() {
        let slow = QrStudioSheetMotion()
        slow.open(animated: false)
        slow.close(velocity: 0, travel: 300)
        slow.step(1.0 / 120.0)

        let flung = QrStudioSheetMotion()
        flung.open(animated: false)
        flung.close(velocity: 1500, travel: 300)
        flung.step(1.0 / 120.0)

        XCTAssertLessThan(flung.rise, slow.rise)
        XCTAssertEqual(1 - flung.rise, 1500.0 / 300.0 / 120.0, accuracy: 0.02)
    }

    func testOpennessBounds() {
        let motion = QrStudioSheetMotion()
        XCTAssertEqual(motion.openness(travel: 300), 0)
        motion.open(animated: false)
        XCTAssertEqual(motion.openness(travel: 300), 1)
        motion.drag(150)
        XCTAssertEqual(motion.openness(travel: 300), 0.5, accuracy: 0.0001)
        motion.drag(900)
        XCTAssertEqual(motion.openness(travel: 300), 0)
        XCTAssertEqual(motion.openness(travel: 0), 1)
    }

    func testSearchChannel() {
        let motion = QrStudioSheetMotion()
        motion.open(animated: false)
        motion.setSearch(true)
        self.run(motion, seconds: 1.5, each: { _ in
            XCTAssertLessThanOrEqual(motion.search, 1.0001)
        })
        XCTAssertEqual(motion.search, 1)
        motion.setSearch(false)
        self.run(motion, seconds: 1.5)
        XCTAssertEqual(motion.search, 0)
    }

    func testGeometryEndpoints() {
        let geometry = self.makeGeometry()
        XCTAssertEqual(geometry.sheet, CGRect(x: 0, y: 874 - 342, width: 402, height: 342))
        XCTAssertEqual(geometry.capsule, CGRect(x: 125, y: 874 - 34 - 44, width: 152, height: 44))
        XCTAssertEqual(geometry.frame(rise: 0, spread: 0, pull: 0, lift: 0), geometry.capsule)
        XCTAssertEqual(geometry.frame(rise: 1, spread: 1, pull: 0, lift: 0), geometry.sheet)
        XCTAssertEqual(geometry.travel, geometry.capsule.minY - geometry.sheet.minY)
    }

    func testPullShiftsOnlyTheOpenWindow() {
        let geometry = self.makeGeometry()
        XCTAssertEqual(geometry.frame(rise: 1, spread: 1, pull: 40, lift: 0), geometry.sheet.offsetBy(dx: 0, dy: 40))
        XCTAssertEqual(geometry.frame(rise: 0, spread: 0, pull: 40, lift: 0), geometry.capsule)
        XCTAssertEqual(geometry.frame(rise: 1, spread: 1, pull: 0, lift: 100), geometry.sheet.offsetBy(dx: 0, dy: -100))
    }

    func testCornersInterpolateAndRespectTinyFrames() {
        let geometry = self.makeGeometry()
        let closed = geometry.corners(rise: 0, frame: geometry.capsule)
        XCTAssertEqual(closed.top, 22)
        XCTAssertEqual(closed.bottom, 22)
        let open = geometry.corners(rise: 1, frame: geometry.sheet)
        XCTAssertEqual(open.top, 27)
        XCTAssertEqual(open.bottom, 55)
        let tiny = geometry.corners(rise: 1, frame: CGRect(x: 0, y: 0, width: 30, height: 20))
        XCTAssertEqual(tiny.top, 10)
        XCTAssertEqual(tiny.bottom, 10)
    }

    func testSearchLift() {
        let geometry = self.makeGeometry()
        XCTAssertEqual(geometry.searchLift(keyboard: 0), 0)
        XCTAssertEqual(geometry.searchLift(keyboard: 100), 0)
        XCTAssertEqual(geometry.searchLift(keyboard: 336), 336 + 146 - 342)
    }

    func testPhases() {
        let start = QrStudioSheetGeometry.phases(grown: 0)
        XCTAssertEqual(start.icons, 1)
        XCTAssertEqual(start.glass, 1)
        XCTAssertEqual(start.background, 0)
        XCTAssertEqual(start.content, 0)
        let end = QrStudioSheetGeometry.phases(grown: 1)
        XCTAssertEqual(end.icons, 0)
        XCTAssertEqual(end.glass, 0)
        XCTAssertEqual(end.background, 1)
        XCTAssertEqual(end.content, 1)
        let early = QrStudioSheetGeometry.phases(grown: 0.1)
        XCTAssertEqual(early.icons, 0)
        XCTAssertEqual(early.content, 0)
        XCTAssertGreaterThan(early.background, 0)
    }

    func testCardFitsOnTallScreen() {
        let geometry = self.makeGeometry()
        let result = QrStudioSheetGeometry.raise(card: 319, groupY: 874 / 2 - 9.5, panelTop: geometry.sheet.minY, gap: 35)
        XCTAssertEqual(result.fit, 1)
        let restTop = (874 / 2 - 9.5) - (319 + 40) / 2
        let liftedTop = restTop + result.lift
        XCTAssertEqual(liftedTop + 319 + 40 + 35, geometry.sheet.minY, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(liftedTop, 108 - 0.001)
    }

    func testCardStaysWhenShortSheetLeavesRoom() {
        let result = QrStudioSheetGeometry.raise(card: 319, groupY: 874 / 2 - 9.5, panelTop: 874 - 200, gap: 35)
        XCTAssertEqual(result.fit, 1)
        XCTAssertEqual(result.lift, 0)
    }

    func testCardScalesOnShortScreen() {
        let geometry = self.makeGeometry(height: 568)
        let result = QrStudioSheetGeometry.raise(card: 319, groupY: 568 / 2 - 9.5, panelTop: geometry.sheet.minY, gap: 35)
        XCTAssertLessThan(result.fit, 1)
        XCTAssertGreaterThanOrEqual(result.fit, 0.4)
        let restTop = (568.0 / 2 - 9.5) - (319.0 + 40) / 2
        let visibleTop = restTop + result.lift + 319 * (1 - result.fit)
        XCTAssertGreaterThanOrEqual(visibleTop, 108 - 0.001)
    }

    func testSimulatedTrajectoryMatchesSteppingAndLeavesTheMotionUntouched() {
        let motion = QrStudioSheetMotion()
        motion.open(animated: true)
        let before = motion.sample
        let samples = motion.simulate(dt: 1.0 / 120.0, maxDuration: 3.0)
        XCTAssertEqual(motion.sample, before)
        XCTAssertFalse(motion.isSettled)
        XCTAssertEqual(samples.first, before)
        XCTAssertEqual(samples.last?.rise ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertEqual(samples.last?.spread ?? 0, 1.0, accuracy: 0.0001)

        let stepped = motion.copy()
        for _ in 0 ..< 20 {
            stepped.step(1.0 / 120.0)
        }
        XCTAssertEqual(stepped.sample.rise, samples[20].rise, accuracy: 0.000001)
        XCTAssertEqual(stepped.sample.spread, samples[20].spread, accuracy: 0.000001)
    }

    func testClosingTrajectoryEndsWithThePullReset() {
        let motion = QrStudioSheetMotion()
        motion.open(animated: false)
        motion.drag(60.0)
        motion.release(velocity: 2000.0, travel: 400.0)
        XCTAssertFalse(motion.isOpen)
        let samples = motion.simulate(dt: 1.0 / 120.0, maxDuration: 3.0)
        XCTAssertEqual(samples.last?.rise ?? 1, 0.0, accuracy: 0.0001)
        XCTAssertEqual(samples.last?.pull ?? 1, 0.0)
    }

    func testAdoptingAPointOnTheTrajectoryContinuesIt() {
        let motion = QrStudioSheetMotion()
        motion.open(animated: true)
        let dt = 1.0 / 120.0
        let samples = motion.simulate(dt: dt, maxDuration: 3.0)
        let index = 15
        let velocity = QrStudioSheetMotion.Sample(
            rise: (samples[index + 1].rise - samples[index - 1].rise) / CGFloat(2.0 * dt),
            spread: (samples[index + 1].spread - samples[index - 1].spread) / CGFloat(2.0 * dt),
            pull: (samples[index + 1].pull - samples[index - 1].pull) / CGFloat(2.0 * dt),
            search: (samples[index + 1].search - samples[index - 1].search) / CGFloat(2.0 * dt)
        )
        motion.adopt(samples[index], velocity: velocity)
        XCTAssertEqual(motion.sample, samples[index])
        let rest = motion.simulate(dt: dt, maxDuration: 3.0)
        XCTAssertEqual(rest[10].rise, samples[index + 10].rise, accuracy: 0.01)
        XCTAssertEqual(rest.last?.rise ?? 0, 1.0, accuracy: 0.0001)
    }
}
