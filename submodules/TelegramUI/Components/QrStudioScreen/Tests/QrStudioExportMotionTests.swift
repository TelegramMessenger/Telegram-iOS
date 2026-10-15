import XCTest
@testable import QrStudioScreen

final class QrStudioExportMotionTests: XCTestCase {
    func testCycles() {
        XCTAssertEqual(QrStudioExportMotion.loopCycles(period: 3.0), 2)
        XCTAssertEqual(QrStudioExportMotion.loopCycles(period: 1.0), 5)
        XCTAssertEqual(QrStudioExportMotion.loopCycles(period: 9.0), 1)
        for period in stride(from: 0.5, through: 2.8, by: 0.05) {
            let rate = Double(QrStudioExportMotion.loopCycles(period: period)) * period / QrStudioExportMotion.loop
            XCTAssertTrue((0.8 ... 1.2).contains(rate), "period \(period) rate \(rate)")
        }
    }

    func testFrameIndexLoopsAndStaysInRange() {
        for period in [1.0, 2.5, 3.0, 4.2] {
            for phase in [0.0, 0.33, 0.83] {
                let count = Int(period * 60.0)
                let first = QrStudioExportMotion.frameIndex(frameCount: count, period: period, phase: phase, at: 0.0)
                let last = QrStudioExportMotion.frameIndex(frameCount: count, period: period, phase: phase, at: QrStudioExportMotion.loop)
                XCTAssertEqual(first, last)
                for i in 0 ..< QrStudioExportMotion.frameCount {
                    let index = QrStudioExportMotion.frameIndex(frameCount: count, period: period, phase: phase, at: Double(i) / 30.0)
                    XCTAssertTrue((0 ..< count).contains(index))
                }
            }
        }
    }

    func testFrameStepKeepsThirtyFramesPerSecond() {
        XCTAssertEqual(QrStudioExportMotion.frameStep(frameDuration: 1.0 / 60.0), 2)
        XCTAssertEqual(QrStudioExportMotion.frameStep(frameDuration: 1.0 / 30.0), 1)
        XCTAssertEqual(QrStudioExportMotion.frameStep(frameDuration: 1.0 / 24.0), 1)
        XCTAssertEqual(QrStudioExportMotion.frameStep(frameDuration: 1.0 / 120.0), 4)
        XCTAssertEqual(QrStudioExportMotion.frameStep(frameDuration: 0.0), 1)
    }

    func testWobbleStartsAtTheSnapshotAndLoops() {
        for hash in stride(from: 0.0, to: 1.0, by: 0.09) {
            let start = QrStudioExportMotion.wobble(hash: hash, at: 0.0)
            XCTAssertEqual(start.dx, 0.0, accuracy: 0.0001)
            XCTAssertEqual(start.dy, 0.0, accuracy: 0.0001)
            XCTAssertEqual(start.degrees, 0.0, accuracy: 0.0001)
            let end = QrStudioExportMotion.wobble(hash: hash, at: QrStudioExportMotion.loop)
            XCTAssertEqual(end.dx, 0.0, accuracy: 0.0001)
            XCTAssertEqual(end.dy, 0.0, accuracy: 0.0001)
            XCTAssertEqual(end.degrees, 0.0, accuracy: 0.0001)
            let middle = QrStudioExportMotion.wobble(hash: hash, at: 2.0)
            XCTAssertGreaterThan(abs(middle.dx) + abs(middle.dy), 0.1)
        }
    }

    func testSingleFrameStickerIsAlwaysZero() {
        XCTAssertEqual(QrStudioExportMotion.frameIndex(frameCount: 1, period: 0.0, phase: 0.5, at: 3.0), 0)
    }
}
