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
}
