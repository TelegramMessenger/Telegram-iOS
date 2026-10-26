import XCTest
@testable import MediaGrid

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        self.state = self.state &* 6364136223846793005 &+ 1442695040888963407
        return self.state
    }
}

final class MediaGridUniformLayoutTests: XCTestCase {
    private func geometry(width: CGFloat = 393, sideInset: CGFloat = 0, topInset: CGFloat = 0, bottomInset: CGFloat = 0) -> MediaGridGeometry {
        return MediaGridGeometry(width: width, sideInset: sideInset, topInset: topInset, bottomInset: bottomInset, spacing: 1.0, scale: 3.0)
    }

    private let camera: Set<MediaGridSlot> = [MediaGridSlot(row: 0, column: 0), MediaGridSlot(row: 1, column: 0)]

    func testThreeColumnsOn393() {
        let layout = MediaGridUniformLayout(geometry: self.geometry(), columns: 3, cellAspect: 1.0, reservedSlots: [], count: 30)
        XCTAssertEqual(layout.itemSize.width, 391.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(layout.frame(at: 0).minX, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.frame(at: 2).maxX, 393, accuracy: 0.0001)
        XCTAssertEqual(layout.frame(at: 3).minY, layout.itemSize.height + 1, accuracy: 0.0001)
    }

    func testCameraSlotsSkipped() {
        let layout = MediaGridUniformLayout(geometry: self.geometry(), columns: 3, cellAspect: 1.0, reservedSlots: self.camera, count: 30)
        let w = layout.itemSize.width
        let h = layout.itemSize.height
        XCTAssertEqual(layout.frame(at: 0).origin.x, w + 1, accuracy: 0.0001)
        XCTAssertEqual(layout.frame(at: 0).origin.y, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.frame(at: 2).origin.x, w + 1, accuracy: 0.0001)
        XCTAssertEqual(layout.frame(at: 2).origin.y, h + 1, accuracy: 0.0001)
        XCTAssertEqual(layout.frame(at: 4).origin.x, 0, accuracy: 0.0001)
        XCTAssertEqual(layout.frame(at: 4).origin.y, 2 * (h + 1), accuracy: 0.0001)
        let reserved = layout.reservedFrame(self.camera)!
        XCTAssertEqual(reserved.height, 2 * h + 1, accuracy: 0.0001)
        XCTAssertEqual(reserved.minX, 0, accuracy: 0.0001)
        XCTAssertEqual(reserved.width, w, accuracy: 0.0001)
    }

    func testIndexRangeMatchesBruteForce() {
        var generator = SeededGenerator(state: 42)
        let geometry = self.geometry(sideInset: 0, topInset: 10, bottomInset: 20)
        for count in [0, 1, 2, 7, 100_000] {
            for columns in [3, 5, 15, 31] {
                for reserved in [Set<MediaGridSlot>(), self.camera] {
                    let layout = MediaGridUniformLayout(geometry: geometry, columns: columns, cellAspect: 1.0, reservedSlots: reserved, count: count)
                    let total = Int(layout.contentHeight)
                    for _ in 0 ..< 50 {
                        let y = CGFloat.random(in: -50 ... CGFloat(total + 50), using: &generator)
                        let height = CGFloat.random(in: 1 ... 900, using: &generator)
                        let rect = CGRect(x: 0, y: y, width: geometry.width, height: height)
                        let range = layout.indexRange(intersecting: rect)
                        let expected: [Int]
                        if count <= 2000 {
                            expected = (0 ..< count).filter { layout.frame(at: $0).intersects(rect) }
                            XCTAssertEqual(Array(range), expected, "count \(count) columns \(columns) rect \(rect)")
                        } else {
                            var lowest = Int.max
                            var highest = -1
                            let rowStep = layout.itemSize.height + 1
                            let firstRow = max(0, Int(((rect.minY - 10) / rowStep).rounded(.down)) - 1)
                            let lastRow = Int(((rect.maxY - 10) / rowStep).rounded(.down)) + 1
                            let lo = max(0, firstRow * columns - 2)
                            let hi = min(count, (lastRow + 1) * columns)
                            if lo < hi {
                                for i in lo ..< hi where layout.frame(at: i).intersects(rect) {
                                    lowest = min(lowest, i)
                                    highest = max(highest, i)
                                }
                            }
                            if highest >= 0 {
                                XCTAssertEqual(range, lowest ..< (highest + 1), "count \(count) columns \(columns) rect \(rect)")
                            } else {
                                XCTAssertTrue(range.isEmpty)
                            }
                        }
                    }
                }
            }
        }
    }

    func testIndexAtPoint() {
        for reserved in [Set<MediaGridSlot>(), self.camera] {
            let layout = MediaGridUniformLayout(geometry: self.geometry(), columns: 3, cellAspect: 1.0, reservedSlots: reserved, count: 200)
            for i in 0 ..< 200 {
                let frame = layout.frame(at: i)
                XCTAssertEqual(layout.index(at: CGPoint(x: frame.midX, y: frame.midY)), i)
            }
            let frame = layout.frame(at: 0)
            XCTAssertNil(layout.index(at: CGPoint(x: frame.maxX + 0.5, y: frame.midY)))
            XCTAssertNil(layout.index(at: CGPoint(x: frame.midX, y: frame.maxY + 0.5)))
        }
        let layout = MediaGridUniformLayout(geometry: self.geometry(), columns: 3, cellAspect: 1.0, reservedSlots: self.camera, count: 200)
        let reservedFrame = layout.reservedFrame(self.camera)!
        XCTAssertNil(layout.index(at: CGPoint(x: reservedFrame.midX, y: reservedFrame.minY + 5)))
        XCTAssertNil(layout.index(at: CGPoint(x: reservedFrame.midX, y: reservedFrame.maxY - 5)))
        XCTAssertNil(layout.index(at: CGPoint(x: -1, y: 5)))
    }

    func testContentHeight() {
        let geometry = self.geometry(topInset: 7, bottomInset: 11)
        let empty = MediaGridUniformLayout(geometry: geometry, columns: 3, cellAspect: 1.0, reservedSlots: [], count: 0)
        XCTAssertEqual(empty.contentHeight, 18, accuracy: 0.0001)
        let one = MediaGridUniformLayout(geometry: geometry, columns: 3, cellAspect: 1.0, reservedSlots: self.camera, count: 1)
        let h = one.itemSize.height
        XCTAssertEqual(one.contentHeight, 18 + 2 * h + 1, accuracy: 0.0001)
        let rows = MediaGridUniformLayout(geometry: geometry, columns: 3, cellAspect: 1.0, reservedSlots: [], count: 7)
        XCTAssertEqual(rows.contentHeight, 18 + 3 * h + 2, accuracy: 0.0001)
    }
}
