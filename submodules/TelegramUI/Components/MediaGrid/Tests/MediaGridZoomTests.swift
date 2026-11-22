import XCTest
@testable import MediaGrid

final class MediaGridZoomTests: XCTestCase {
    private let count = 10_000
    private let viewportHeight: CGFloat = 852.0

    private func layout(_ level: MediaGridLevel) -> MediaGridUniformLayout {
        let geometry = MediaGridGeometry(width: 393.0, sideInset: 0.0, topInset: 100.0, bottomInset: 34.0, spacing: 1.0, scale: 3.0)
        let reserved: Set<MediaGridSlot> = level.showsCamera ? [MediaGridSlot(row: 0, column: 0), MediaGridSlot(row: 1, column: 0)] : []
        return MediaGridUniformLayout(geometry: geometry, columns: level.columns, cellAspect: 1.0, reservedSlots: reserved, count: self.count)
    }

    private var adjacentPairs: [(MediaGridLevel, MediaGridLevel)] {
        var result: [(MediaGridLevel, MediaGridLevel)] = []
        for level in MediaGridLevel.allCases {
            if let next = level.zoomedOut {
                result.append((level, next))
                result.append((next, level))
            }
        }
        return result
    }

    func testAnchorStaysUnderPoint() {
        let points = [CGPoint(x: 100.0, y: 400.0), CGPoint(x: 300.0, y: 60.0), CGPoint(x: 20.0, y: 830.0)]
        var unclamped = 0
        for (_, to) in self.adjacentPairs {
            let target = self.layout(to)
            let maxOffset = target.contentHeight - self.viewportHeight
            for index in [0, 1, 500, self.count - 1] {
                for point in points {
                    let anchor = MediaGridZoomAnchor(index: index, pointInView: point)
                    let offset = MediaGridZoomMath.targetOffset(anchor: anchor, in: target, viewportHeight: self.viewportHeight)
                    XCTAssertGreaterThanOrEqual(offset, 0.0)
                    XCTAssertLessThanOrEqual(offset, maxOffset + 1e-6)
                    let frame = target.frame(at: index).offsetBy(dx: 0.0, dy: -offset)
                    if offset > 0.0 && offset < maxOffset {
                        unclamped += 1
                        XCTAssertTrue(frame.minY <= point.y && point.y < frame.maxY, "\(to) index \(index) point \(point) frame \(frame)")
                        XCTAssertEqual(frame.midY, point.y, accuracy: 1e-6)
                    }
                }
            }
        }
        XCTAssertGreaterThan(unclamped, 0)
    }

    func testRelativePositionIsKept() {
        for (from, to) in self.adjacentPairs {
            let source = self.layout(from)
            let target = self.layout(to)
            let sourceFrame = source.frame(at: 500)
            let point = CGPoint(x: sourceFrame.minX + sourceFrame.width * 0.2, y: 300.0)
            let relative = MediaGridZoomMath.relativePosition(of: CGPoint(x: point.x, y: sourceFrame.minY + sourceFrame.height * 0.8), in: sourceFrame)
            XCTAssertEqual(relative.y, 0.8, accuracy: 1e-6)
            let offset = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: 500, pointInView: point), in: target, viewportHeight: self.viewportHeight, relativePosition: relative)
            let frame = target.frame(at: 500)
            XCTAssertEqual(frame.minY + 0.8 * frame.height - offset, point.y, accuracy: 1e-6, "\(from) -> \(to)")
        }
    }

    func testClampsAtEdges() {
        for (_, to) in self.adjacentPairs {
            let target = self.layout(to)
            let top = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: 0, pointInView: CGPoint(x: 10.0, y: 800.0)), in: target, viewportHeight: self.viewportHeight)
            XCTAssertEqual(top, 0.0)
            let bottom = MediaGridZoomMath.targetOffset(anchor: MediaGridZoomAnchor(index: self.count - 1, pointInView: CGPoint(x: 10.0, y: 10.0)), in: target, viewportHeight: self.viewportHeight)
            XCTAssertEqual(bottom, target.contentHeight - self.viewportHeight, accuracy: 1e-6)
        }
    }

    func testScaleIsWidthRatio() {
        let three = self.layout(.three)
        let five = self.layout(.five)
        let scale = MediaGridZoomMath.scale(from: three, to: five, anchorIndex: 2)
        XCTAssertEqual(scale, five.itemSize.width / three.itemSize.width, accuracy: 0.01)
        XCTAssertLessThan(scale, 1.0)
        XCTAssertEqual(MediaGridZoomMath.scale(from: five, to: three, anchorIndex: 2) * scale, 1.0, accuracy: 1e-6)
    }

    func testTransformKeepsAnchorFixed() {
        let anchor = CGPoint(x: 120.0, y: 4000.0)
        let position = CGPoint(x: 196.5, y: 50_000.0)
        for scale in [0.3, 1.0, 2.07] as [CGFloat] {
            let transform = MediaGridZoomMath.transform(scale: scale, about: anchor, layerPosition: position)
            let affine = CATransform3DGetAffineTransform(transform)
            let local = CGPoint(x: anchor.x - position.x, y: anchor.y - position.y).applying(affine)
            XCTAssertEqual(local.x + position.x, anchor.x, accuracy: 1e-6)
            XCTAssertEqual(local.y + position.y, anchor.y, accuracy: 1e-3)
        }
    }

    private let pinchAnchor = MediaGridZoomAnchor(index: 0, pointInView: CGPoint(x: 100.0, y: 400.0))

    private func assertPinch(_ result: (from: MediaGridLevel, to: MediaGridLevel, progress: CGFloat), _ from: MediaGridLevel, _ to: MediaGridLevel, _ progress: CGFloat, accuracy: CGFloat = 1e-6, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.from, from, file: file, line: line)
        XCTAssertEqual(result.to, to, file: file, line: line)
        XCTAssertEqual(result.progress, progress, accuracy: accuracy, file: file, line: line)
    }

    func testScaleOneIsStart() {
        for level in MediaGridLevel.allCases {
            var state = MediaGridPinchState(startLevel: level, anchor: self.pinchAnchor)
            self.assertPinch(state.update(scale: 1.0), level, level, 0.0)
            XCTAssertEqual(state.settle(velocity: 0.0), level)
            XCTAssertEqual(state.settle(velocity: 3.0), level)
        }
    }

    func testPinchOutThreeReachesFiveThenFifteen() {
        var state = MediaGridPinchState(startLevel: .three, anchor: self.pinchAnchor)
        self.assertPinch(state.update(scale: pow(3.0 / 5.0, 0.5)), .three, .five, 0.5)
        self.assertPinch(state.update(scale: 3.0 / 5.0), .three, .five, 1.0)
        let pastFive = state.update(scale: 3.0 / 5.0 * 0.99)
        XCTAssertEqual(pastFive.from, .five)
        XCTAssertEqual(pastFive.to, .fifteen)
        XCTAssertGreaterThan(pastFive.progress, 0.0)
        XCTAssertLessThan(pastFive.progress, 0.05)
        self.assertPinch(state.update(scale: 3.0 / 5.0 * pow(5.0 / 15.0, 0.25)), .five, .fifteen, 0.25)
        let pastFifteen = state.update(scale: 3.0 / 15.0 * 0.99)
        XCTAssertEqual(pastFifteen.from, .fifteen)
        XCTAssertEqual(pastFifteen.to, .thirtyOne)
        self.assertPinch(state.update(scale: pow(3.0 / 5.0, 0.25)), .three, .five, 0.25)
        self.assertPinch(state.update(scale: pow(3.0, 0.5)), .three, .one, 0.5)

        var back = MediaGridPinchState(startLevel: .fifteen, anchor: self.pinchAnchor)
        self.assertPinch(back.update(scale: pow(15.0 / 5.0, 0.75)), .fifteen, .five, 0.75)
        self.assertPinch(back.update(scale: 15.0 / 5.0 * pow(5.0 / 3.0, 0.5)), .five, .three, 0.5)
    }

    func testClampAtEnds() {
        var state = MediaGridPinchState(startLevel: .three, anchor: self.pinchAnchor)
        self.assertPinch(state.update(scale: 0.001), .fifteen, .thirtyOne, 1.0)
        self.assertPinch(state.update(scale: 1000.0), .three, .one, 1.0)
        var top = MediaGridPinchState(startLevel: .thirtyOne, anchor: self.pinchAnchor)
        self.assertPinch(top.update(scale: 0.2), .thirtyOne, .thirtyOne, 0.0)
        var bottom = MediaGridPinchState(startLevel: .one, anchor: self.pinchAnchor)
        self.assertPinch(bottom.update(scale: 5.0), .one, .one, 0.0)
    }

    func testSettleNearestAndVelocityBias() {
        var state = MediaGridPinchState(startLevel: .three, anchor: self.pinchAnchor)
        _ = state.update(scale: pow(3.0 / 5.0, 0.3))
        XCTAssertEqual(state.settle(velocity: 0.0), .three)
        XCTAssertEqual(state.settle(velocity: -0.4), .three)
        XCTAssertEqual(state.settle(velocity: -1.0), .five)
        XCTAssertEqual(state.settle(velocity: 1.0), .three)
        _ = state.update(scale: pow(3.0 / 5.0, 0.7))
        XCTAssertEqual(state.settle(velocity: 0.0), .five)
        XCTAssertEqual(state.settle(velocity: 0.4), .five)
        XCTAssertEqual(state.settle(velocity: 1.0), .three)
        XCTAssertEqual(state.settle(velocity: -1.0), .five)
        _ = state.update(scale: 3.0 / 5.0 * pow(5.0 / 15.0, 0.6))
        XCTAssertEqual(state.settle(velocity: 0.0), .fifteen)
        XCTAssertEqual(state.settle(velocity: 2.0), .five)
    }

    func testProgressVelocityFollowsScaleVelocity() {
        var state = MediaGridPinchState(startLevel: .three, anchor: self.pinchAnchor)
        let scale = pow(3.0 / 5.0, 0.5)
        _ = state.update(scale: scale)
        let delta: CGFloat = 1e-4
        let ahead = state.update(scale: scale - delta).progress
        _ = state.update(scale: scale)
        let expected = (ahead - 0.5) / delta
        XCTAssertEqual(state.progressVelocity(scaleVelocity: 1.0), -expected, accuracy: 1e-2)
        XCTAssertGreaterThan(state.progressVelocity(scaleVelocity: -1.0), 0.0)
    }

    func testOvershootIsRubberBanded() {
        var state = MediaGridPinchState(startLevel: .fifteen, anchor: self.pinchAnchor)
        _ = state.update(scale: 0.5)
        XCTAssertEqual(state.overshoot, 0.0, accuracy: 1e-9)
        _ = state.update(scale: 15.0 / 31.0 * 0.9)
        let small = state.overshoot
        XCTAssertGreaterThan(small, 0.0)
        _ = state.update(scale: 0.0001)
        let large = state.overshoot
        XCTAssertGreaterThan(large, small)
        XCTAssertLessThan(large, MediaGridPinchState.maxOvershoot)
        _ = state.update(scale: 1000.0)
        XCTAssertLessThan(state.overshoot, 0.0)
        XCTAssertGreaterThan(state.overshoot, -MediaGridPinchState.maxOvershoot)
    }
}
