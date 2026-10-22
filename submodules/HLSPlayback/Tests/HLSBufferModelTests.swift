import XCTest
@testable import HLSPlayback

final class HLSBufferModelTests: XCTestCase {
    private func part(_ level: Int, _ index: Int, _ start: Double, _ end: Double) -> HLSBufferedPart {
        return HLSBufferedPart(key: HLSSegmentKey(level: level, index: index), start: start, end: end)
    }
    
    func testInsertKeepsPartsSortedByStart() {
        var model = HLSBufferModel()
        model.insert(self.part(1, 2, 10.0, 15.0))
        model.insert(self.part(1, 0, 0.0, 5.0))
        model.insert(self.part(2, 1, 5.0, 10.0))
        model.insert(self.part(1, 1, 5.0, 10.0))
        XCTAssertEqual(model.parts.map(\.start), [0.0, 5.0, 5.0, 10.0])
        // Ties keep insertion order.
        XCTAssertEqual(model.parts[1].key, HLSSegmentKey(level: 2, index: 1))
        XCTAssertTrue(model.contains(HLSSegmentKey(level: 1, index: 1)))
        XCTAssertFalse(model.contains(HLSSegmentKey(level: 3, index: 1)))
    }
    
    func testInsertingAKeyAgainReplacesIt() {
        var model = HLSBufferModel()
        model.insert(self.part(1, 0, 0.0, 5.0))
        model.insert(self.part(1, 0, 0.0, 4.9))
        XCTAssertEqual(model.parts.count, 1)
        XCTAssertEqual(model.parts[0].end, 4.9)
    }
    
    func testForwardEndMergesHolesUnderMaxHole() {
        var model = HLSBufferModel()
        model.insert(self.part(1, 0, 0.0, 5.0))
        model.insert(self.part(1, 1, 5.05, 10.0))
        XCTAssertEqual(model.forwardEnd(from: 1.0), 10.0)
        XCTAssertEqual(model.forwardLength(from: 1.0), 9.0, accuracy: 1e-9)
        XCTAssertEqual(model.bufferedRanges, [0.0 ..< 10.0])
    }
    
    func testForwardEndStopsAtLargerHole() {
        var model = HLSBufferModel()
        model.insert(self.part(1, 0, 0.0, 5.0))
        model.insert(self.part(1, 1, 5.2, 10.0))
        XCTAssertEqual(model.forwardEnd(from: 1.0), 5.0)
        XCTAssertEqual(model.bufferedRanges, [0.0 ..< 5.0, 5.2 ..< 10.0])
    }
    
    func testPositionJustBeforeFirstPartCountsAsBuffered() {
        var model = HLSBufferModel()
        model.insert(self.part(1, 0, 0.04, 5.0))
        XCTAssertEqual(model.forwardEnd(from: 0.0), 5.0)
    }
    
    func testUnbufferedPositionHasNoForwardEnd() {
        var model = HLSBufferModel()
        XCTAssertNil(model.forwardEnd(from: 0.0))
        XCTAssertEqual(model.forwardLength(from: 0.0), 0.0)
        model.insert(self.part(1, 0, 0.0, 5.0))
        XCTAssertNil(model.forwardEnd(from: 5.0))
        XCTAssertNil(model.forwardEnd(from: 7.0))
        XCTAssertEqual(model.forwardLength(from: 7.0), 0.0)
    }
    
    func testPartAtPrefersLatestStartOnOverlap() {
        var model = HLSBufferModel()
        model.insert(self.part(1, 0, 0.0, 5.0))
        model.insert(self.part(2, 1, 4.9, 9.9))
        XCTAssertEqual(model.part(at: 4.95)?.key.level, 2)
        XCTAssertEqual(model.part(at: 2.0)?.key.level, 1)
        XCTAssertNil(model.part(at: 9.9))
    }
    
    func testTrimBackBufferUsesSegmentGrid() {
        var model = HLSBufferModel()
        for index in 0 ..< 26 {
            model.insert(self.part(1, index, Double(index) * 4.0, Double(index + 1) * 4.0))
        }
        // floor(101.3 / 4) * 4 - max(30, 4) = 70: parts ending at or before 70 go.
        let removed = model.trimBackBuffer(position: 101.3, segmentDuration: 4.0, backBuffer: 30.0)
        XCTAssertEqual(removed.map(\.index), Array(0 ..< 17))
        XCTAssertEqual(model.parts.first?.start, 68.0)
    }
    
    func testTrimBackBufferKeepsEverythingNearTheStart() {
        var model = HLSBufferModel()
        model.insert(self.part(1, 0, 0.0, 5.0))
        XCTAssertEqual(model.trimBackBuffer(position: 20.0, segmentDuration: 5.0, backBuffer: 30.0), [])
        XCTAssertEqual(model.trimBackBuffer(position: 20.0, segmentDuration: 0.0, backBuffer: 30.0), [])
        XCTAssertEqual(model.parts.count, 1)
    }
    
    func testRemoveForwardKeepsBackBuffer() {
        var model = HLSBufferModel()
        for index in 0 ..< 4 {
            model.insert(self.part(1, index, Double(index) * 5.0, Double(index + 1) * 5.0))
        }
        let removed = model.removeForward(from: 12.0)
        XCTAssertEqual(removed, [HLSSegmentKey(level: 1, index: 2), HLSSegmentKey(level: 1, index: 3)])
        XCTAssertEqual(model.parts.map(\.key.index), [0, 1])
    }
    
    func testRemoveAll() {
        var model = HLSBufferModel()
        model.insert(self.part(1, 0, 0.0, 5.0))
        model.insert(self.part(1, 1, 5.0, 10.0))
        XCTAssertEqual(model.removeAll().count, 2)
        XCTAssertTrue(model.parts.isEmpty)
    }
}
