import XCTest
@testable import QrStudioScreen

final class QrStudioMotionTests: XCTestCase {
    func testGlideAsymptote() {
        let pan = QrStudioPan()
        pan.begin(at: 0)
        pan.update(translation: CGSize(width: 10, height: 0))
        pan.end(translation: CGSize(width: 10, height: 0), velocity: CGSize(width: 1000, height: 0), at: 1)
        XCTAssertEqual(pan.offset(at: 1).width, 10, accuracy: 0.001)
        XCTAssertEqual(pan.offset(at: 20).width, 10 + 1000 * 0.35, accuracy: 0.01)
    }

    func testVelocityIsClamped() {
        let pan = QrStudioPan()
        pan.begin(at: 0)
        pan.end(translation: .zero, velocity: CGSize(width: 99999, height: -99999), at: 0)
        XCTAssertEqual(pan.offset(at: 20).width, 2600 * 0.35, accuracy: 0.01)
        XCTAssertEqual(pan.offset(at: 20).height, -2600 * 0.35, accuracy: 0.01)
    }

    func testCatchDuringGlideIsContinuous() {
        let pan = QrStudioPan()
        pan.begin(at: 0)
        pan.end(translation: CGSize(width: 0, height: 50), velocity: CGSize(width: 0, height: 800), at: 0)
        let before = pan.offset(at: 0.2)
        pan.begin(at: 0.2)
        XCTAssertEqual(pan.offset(at: 0.2).height, before.height, accuracy: 0.001)
        pan.update(translation: CGSize(width: 0, height: 5))
        XCTAssertEqual(pan.offset(at: 0.3).height, before.height + 5, accuracy: 0.001)
    }

    func testActivityEndsAfterSettle() {
        let pan = QrStudioPan()
        XCTAssertFalse(pan.isActive(at: 0))
        pan.begin(at: 0)
        XCTAssertTrue(pan.isActive(at: 5))
        pan.end(translation: .zero, velocity: .zero, at: 5)
        XCTAssertTrue(pan.isActive(at: 6.5))
        XCTAssertFalse(pan.isActive(at: 6.7))
    }

    func testEdgeSqueeze() {
        let squeeze = QrStudioEdgeSqueeze(size: CGSize(width: 400, height: 800))
        let inside = squeeze.apply(CGPoint(x: 200, y: 400))
        XCTAssertEqual(inside.point, CGPoint(x: 200, y: 400))
        XCTAssertEqual(inside.scale, 1)
        var previous: CGFloat = -1
        for x in stride(from: CGFloat(-200), through: 90, by: 10) {
            let result = squeeze.apply(CGPoint(x: x, y: 400))
            XCTAssertGreaterThan(result.point.x, 0)
            XCTAssertGreaterThan(result.point.x, previous)
            previous = result.point.x
        }
        XCTAssertEqual(squeeze.alpha(0.08), 0)
        XCTAssertEqual(squeeze.alpha(0.25), 1)
    }

    func testRevealReachesFarthestCorner() {
        let size = CGSize(width: 400, height: 800)
        let center = CGPoint(x: 200, y: 300)
        XCTAssertEqual(QrStudioReveal.radius(progress: 0, center: center, size: size), 0)
        XCTAssertEqual(QrStudioReveal.radius(progress: 1, center: center, size: size), hypot(200, 500) + 70, accuracy: 0.001)
    }

    func testEntranceFollowsFront() {
        let center = CGPoint.zero
        let point = CGPoint(x: 620, y: 0)
        XCTAssertEqual(QrStudioReveal.entrance(point, center: center, since: 0.99), 0)
        XCTAssertGreaterThan(QrStudioReveal.entrance(point, center: center, since: 1.3), 0.5)
        XCTAssertEqual(QrStudioReveal.entrance(point, center: center, since: 1.45), 1)
    }

    func testLatticeHashIsStableAndCoversScreen() {
        XCTAssertEqual(QrStudioLattice.hash(3, -7), QrStudioLattice.hash(3, -7))
        XCTAssertNotEqual(QrStudioLattice.hash(3, -7), QrStudioLattice.hash(-7, 3))
        let lattice = QrStudioLattice(dx: 86, dy: 70, velocity: CGVector(dx: -3.5, dy: -5.5), lag: 0.04 ... 0.26, orbit: 3 ... 10)
        let cells = lattice.cells(in: CGSize(width: 400, height: 800), at: 12, offset: .zero, margin: 117, drift: QrStudioDrift(), tilt: .zero)
        XCTAssertGreaterThan(cells.count, 60)
        XCTAssertEqual(Set(cells.map { "\($0.r):\($0.c)" }).count, cells.count)
    }

    func testNeighboursDifferWithThreeOrMoreEmoji() {
        for count in 3 ... 6 {
            for r in -6 ... 6 {
                for c in -6 ... 6 {
                    let here = qrStudioEmojiIndex(r: r, c: c, count: count)
                    let shift = (r & 1) == 0 ? -1 : 0
                    let neighbours = [(r, c - 1), (r, c + 1), (r - 1, c + shift), (r - 1, c + shift + 1), (r + 1, c + shift), (r + 1, c + shift + 1)]
                    for (nr, nc) in neighbours {
                        XCTAssertNotEqual(here, qrStudioEmojiIndex(r: nr, c: nc, count: count), "count \(count) at \(r),\(c)")
                    }
                }
            }
        }
    }

    func testSingleEmojiFillsEveryNode() {
        for r in -3 ... 3 {
            for c in -3 ... 3 {
                XCTAssertEqual(qrStudioEmojiIndex(r: r, c: c, count: 1), 0)
            }
        }
    }

    func testPhaseGroupRange() {
        XCTAssertEqual(qrStudioPhaseGroup(hash: 0), 0)
        XCTAssertEqual(qrStudioPhaseGroup(hash: 0.9999), 5)
        XCTAssertEqual(qrStudioPhaseGroup(hash: 1), 5)
    }

    func testMeshCornersAreFixedAndInnerPointsStayInside() {
        for t in stride(from: 0.0, to: 200.0, by: 3.7) {
            let points = QrStudioMesh.points(at: t, pull: SIMD2(5, -5))
            XCTAssertEqual(points.count, 9)
            XCTAssertEqual(points[0], SIMD2<Float>(0, 0))
            XCTAssertEqual(points[8], SIMD2<Float>(1, 1))
            XCTAssertTrue((0.08 ... 0.92).contains(points[4].x))
            XCTAssertTrue((0.08 ... 0.92).contains(points[4].y))
        }
    }

    func testStackKeepsLayersUntilTopRevealCompletes() {
        var stack = QrStudioStageStack<String>()
        let a = stack.push("a")
        let b = stack.push("b")
        let c = stack.push("c")
        XCTAssertEqual(stack.revealCompleted(id: b), [a])
        XCTAssertEqual(stack.layers.map { $0.item }, ["b", "c"])
        XCTAssertEqual(stack.revealCompleted(id: c), [b])
        XCTAssertEqual(stack.layers.map { $0.item }, ["c"])
        XCTAssertEqual(stack.revealCompleted(id: a), [])
    }

    func testSweepFrontTravelsBottomToTop() {
        let side: CGFloat = 200
        XCTAssertEqual(QrStudioSweep.front(at: 0, side: side), side + 9, accuracy: 0.001)
        XCTAssertEqual(QrStudioSweep.front(at: 0.49, side: side), 9 - 9 * 2 - 8 - 26 - 22, accuracy: 0.001)
        XCTAssertEqual(QrStudioSweep.front(at: 5, side: side), QrStudioSweep.front(at: 0.49, side: side))
        var previous = CGFloat.greatestFiniteMagnitude
        for i in 0 ... 45 {
            let front = QrStudioSweep.front(at: Double(i) / 100, side: side)
            XCTAssertLessThanOrEqual(front, previous)
            previous = front
        }
    }

    func testSweepTimeInvertsFront() {
        for y in stride(from: CGFloat(0), through: 200, by: 25) {
            let time = QrStudioSweep.time(at: y, side: 200)
            XCTAssertEqual(QrStudioSweep.front(at: time, side: 200), y, accuracy: 0.01)
        }
    }

    func testEdgeStaysWithinDepthOfFront() {
        for x in stride(from: CGFloat(0), through: 200, by: 7) {
            let edge = QrStudioSweep.edge(x: x, front: 100, since: 0.2)
            XCTAssertTrue((100 ... 109).contains(edge))
        }
    }

    func testStretchIsContinuousWhenCaughtDuringSpringBack() {
        let pan = QrStudioPan()
        pan.begin(at: 0)
        pan.update(translation: CGSize(width: 150, height: 0))
        pan.end(translation: CGSize(width: 150, height: 0), velocity: .zero, at: 0)
        let before = pan.stretch(at: 0.1)
        XCTAssertGreaterThan(before.width, 30)
        pan.begin(at: 0.1)
        XCTAssertEqual(pan.stretch(at: 0.1).width, before.width, accuracy: 0.001)
        pan.update(translation: CGSize(width: 10, height: 0))
        XCTAssertEqual(pan.stretch(at: 0.1).width, before.width + 10, accuracy: 0.001)
    }

    func testTokenRefreshDelay() {
        XCTAssertEqual(qrStudioTokenRefreshDelay(expires: 1300, now: 1000, staleAttempt: 0), 300)
        XCTAssertEqual(qrStudioTokenRefreshDelay(expires: 1005, now: 1000, staleAttempt: 0), 5)
        XCTAssertEqual(qrStudioTokenRefreshDelay(expires: 900, now: 1000, staleAttempt: 0), 1)
        XCTAssertEqual(qrStudioTokenRefreshDelay(expires: 1000, now: 1000, staleAttempt: 3), 8)
        XCTAssertEqual(qrStudioTokenRefreshDelay(expires: 900, now: 1000, staleAttempt: 10), 15)
        XCTAssertTrue(qrStudioTokenIsExpired(expires: 900, now: 1000))
        XCTAssertFalse(qrStudioTokenIsExpired(expires: 1300, now: 1000))
    }
}
