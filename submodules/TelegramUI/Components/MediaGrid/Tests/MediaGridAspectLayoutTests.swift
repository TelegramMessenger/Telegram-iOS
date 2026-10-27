import XCTest
@testable import MediaGrid

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        self.state = self.state &* 6364136223846793005 &+ 1442695040888963407
        return self.state
    }
}

final class MediaGridAspectLayoutTests: XCTestCase {
    private func geometry(width: CGFloat = 393, topInset: CGFloat = 0, bottomInset: CGFloat = 0, scale: CGFloat = 3.0) -> MediaGridGeometry {
        return MediaGridGeometry(width: width, sideInset: 0, topInset: topInset, bottomInset: bottomInset, spacing: 1.0, scale: scale)
    }

    func testClamp() {
        XCTAssertEqual(MediaGridAspectIndex.clamp(0.2), 0.5)
        XCTAssertEqual(MediaGridAspectIndex.clamp(3.0), 2.0)
        XCTAssertEqual(MediaGridAspectIndex.clamp(1.0), 1.0)
    }

    func testIndexBuildClampsOffMain() {
        let done = self.expectation(description: "built")
        let index = MediaGridAspectIndex(count: 4, aspectRatio: { i in
            XCTAssertFalse(Thread.isMainThread)
            return [0.2, 3.0, 1.0, 0.75][i]
        })
        index.build { aspects in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(aspects, [0.5, 2.0, 1.0, 0.75])
            done.fulfill()
        }
        self.wait(for: [done], timeout: 5.0)
    }

    func testRowHeights() {
        let layout = MediaGridAspectLayout(geometry: self.geometry(), count: 2, aspects: [2.0, 0.5])
        XCTAssertEqual(layout.frame(at: 0).height, floor(196.5 * 3.0) / 3.0, accuracy: 1e-9)
        XCTAssertEqual(layout.frame(at: 1).height, 786.0, accuracy: 1e-9)
        XCTAssertEqual(layout.frame(at: 1).minY, floor(196.5 * 3.0) / 3.0 + 1.0, accuracy: 1e-9)
        XCTAssertEqual(layout.frame(at: 0).width, 393.0, accuracy: 1e-9)
        XCTAssertEqual(layout.contentHeight, floor(196.5 * 3.0) / 3.0 + 1.0 + 786.0, accuracy: 1e-9)

        let twoX = MediaGridAspectLayout(geometry: self.geometry(scale: 2.0), count: 1, aspects: [2.0])
        XCTAssertEqual(twoX.frame(at: 0).height, 196.5, accuracy: 1e-9)
    }

    func testIndexRangeMatchesBruteForce() {
        var generator = SeededGenerator(state: 7)
        let geometry = self.geometry(topInset: 10, bottomInset: 20)
        for count in [0, 1, 1000] {
            let aspects = (0 ..< count).map { _ in Float.random(in: 0.5 ... 2.0, using: &generator) }
            let layout = MediaGridAspectLayout(geometry: geometry, count: count, aspects: aspects)
            for _ in 0 ..< 300 {
                let y = CGFloat.random(in: -50 ... layout.contentHeight + 50, using: &generator)
                let height = CGFloat.random(in: 1 ... 900, using: &generator)
                let rect = CGRect(x: 0, y: y, width: geometry.width, height: height)
                let expected = (0 ..< count).filter { layout.frame(at: $0).intersects(rect) }
                XCTAssertEqual(Array(layout.indexRange(intersecting: rect)), expected, "count \(count) rect \(rect)")
                let point = CGPoint(x: CGFloat.random(in: 0 ..< geometry.width, using: &generator), y: y)
                let hit = (0 ..< count).first { layout.frame(at: $0).contains(point) }
                XCTAssertEqual(layout.index(at: point), hit, "count \(count) point \(point)")
            }
            XCTAssertEqual(layout.indexRange(intersecting: CGRect(x: 0, y: 0, width: 1, height: 0)), 0 ..< 0)
        }
    }

    func testEstimateWhenNil() {
        let layout = MediaGridAspectLayout(geometry: self.geometry(), count: 100, aspects: nil)
        let height = floor(393.0 / 0.75 * 3.0) / 3.0
        for index in [0, 1, 50, 99] {
            XCTAssertEqual(layout.frame(at: index).height, height, accuracy: 1e-9)
            XCTAssertEqual(layout.frame(at: index).minY, CGFloat(index) * (height + 1.0), accuracy: 1e-6)
        }
        XCTAssertEqual(layout.contentHeight, 100.0 * height + 99.0, accuracy: 1e-6)
        XCTAssertEqual(layout.indexRange(intersecting: CGRect(x: 0, y: height + 0.5, width: 393, height: 1)), 1 ..< 2)

        let square = MediaGridAspectLayout(geometry: self.geometry(), count: 3, aspects: nil, estimatedAspect: 1.0)
        XCTAssertEqual(square.frame(at: 2).height, 393.0, accuracy: 1e-9)

        let short = MediaGridAspectLayout(geometry: self.geometry(), count: 3, aspects: [1.0])
        XCTAssertEqual(short.frame(at: 0).height, 393.0, accuracy: 1e-9)
        XCTAssertEqual(short.frame(at: 2).height, height, accuracy: 1e-9)
    }

    func testIndexBuildStopsWhenCancelled() {
        var index: MediaGridAspectIndex?
        let lock = NSLock()
        var calls = 0
        let started = DispatchSemaphore(value: 0)
        let resume = DispatchSemaphore(value: 0)
        index = MediaGridAspectIndex(count: 1_000_000, aspectRatio: { i in
            lock.lock()
            calls += 1
            lock.unlock()
            if i == 10 {
                started.signal()
                resume.wait()
            }
            return 1.0
        })
        let completed = self.expectation(description: "completed")
        completed.isInverted = true
        index?.build { _ in
            completed.fulfill()
        }
        started.wait()
        index?.cancel()
        resume.signal()
        self.wait(for: [completed], timeout: 0.5)
        lock.lock()
        XCTAssertLessThan(calls, 1000)
        lock.unlock()
    }

    func testTableLayoutMatchesDirectLayout() {
        var generator = SeededGenerator(state: 3)
        let geometry = self.geometry(topInset: 50, bottomInset: 30)
        let aspects = (0 ..< 500).map { _ in Float.random(in: 0.2 ... 3.0, using: &generator) }
        let direct = MediaGridAspectLayout(geometry: geometry, count: 500, aspects: aspects)
        let table = MediaGridAspectTable(key: MediaGridAspectTable.Key(geometry: geometry), aspects: aspects)
        let shared = MediaGridAspectLayout(geometry: geometry, count: 500, table: table)
        XCTAssertTrue(direct.isExact)
        XCTAssertTrue(shared.isExact)
        XCTAssertEqual(direct.contentHeight, shared.contentHeight, accuracy: 1e-9)
        for index in 0 ..< 500 {
            XCTAssertEqual(direct.frame(at: index), shared.frame(at: index))
            XCTAssertEqual(direct.pixelSize(at: index), shared.pixelSize(at: index))
        }
        let longer = MediaGridAspectLayout(geometry: geometry, count: 510, table: table)
        let estimate = floor(393.0 / 0.75 * 3.0) / 3.0
        XCTAssertEqual(longer.frame(at: 500).minY, shared.frame(at: 499).maxY + 1.0, accuracy: 1e-6)
        XCTAssertEqual(longer.frame(at: 505).height, estimate, accuracy: 1e-9)
        XCTAssertEqual(longer.contentHeight, shared.contentHeight + 10.0 * (estimate + 1.0), accuracy: 1e-6)
    }

    func testTableForOtherWidthIsScaledAndContiguous() {
        let aspects: [Float] = (0 ..< 300).map { [0.5, 2.0, 1.0, 1.5, 0.75][$0 % 5] }
        let table = MediaGridAspectTable(key: MediaGridAspectTable.Key(geometry: self.geometry(width: 393)), aspects: aspects)
        let layout = MediaGridAspectLayout(geometry: self.geometry(width: 430), count: 300, table: table)
        XCTAssertFalse(layout.isExact)
        for index in 0 ..< 299 {
            let frame = layout.frame(at: index)
            XCTAssertEqual(frame.width, 430.0, accuracy: 1e-9)
            XCTAssertEqual(layout.frame(at: index + 1).minY, frame.maxY + 1.0, accuracy: 1e-6)
            XCTAssertEqual(frame.minY * 3.0, (frame.minY * 3.0).rounded(), accuracy: 1e-6)
            let exact = floor(430.0 / CGFloat(aspects[index]) * 3.0) / 3.0
            XCTAssertEqual(frame.height, exact, accuracy: 1.0)
        }
        let otherScale = MediaGridAspectLayout(geometry: self.geometry(width: 393, scale: 2.0), count: 300, table: table)
        XCTAssertFalse(otherScale.isExact)
        XCTAssertEqual(otherScale.frame(at: 0).height, floor(393.0 / 0.75 * 2.0) / 2.0, accuracy: 1e-9)
    }

    func testDeepOffsetsArePixelAligned() {
        var generator = SeededGenerator(state: 11)
        let count = 100_000
        let aspects = (0 ..< count).map { _ in Float.random(in: 0.5 ... 2.0, using: &generator) }
        let layout = MediaGridAspectLayout(geometry: self.geometry(topInset: 100), count: count, aspects: aspects)
        for index in [count - 1, count / 2, 12345] {
            let pixels = (layout.frame(at: index).minY - 100.0) * 3.0
            XCTAssertEqual(pixels, pixels.rounded(), accuracy: 1e-6)
        }
    }
}
