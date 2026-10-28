import XCTest
import CoreGraphics

final class MediaGridPaneDecisionsTests: XCTestCase {
    func testStoredLevelMapping() {
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: nil), 3)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 2), 3)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 3), 3)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 4), 5)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 7), 5)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 8), 15)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 12), 15)
        XCTAssertEqual(mediaGridPaneLevelColumns(storedColumns: 15), 15)
    }

    func testPreviewWidths() {
        XCTAssertEqual(mediaGridPanePreviewWidths, [64, 150, 200, 280])
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 30.0), 64)
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 50.0), 64)
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 51.0), 150)
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 100.0), 150)
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 140.0), 200)
        XCTAssertEqual(mediaGridPanePreviewWidth(cellPointWidth: 141.0), 280)
    }

    func testHoleToLoadNilWhenAllLoaded() {
        let holes = [MediaGridPaneHole(anchorIndex: 0), MediaGridPaneHole(anchorIndex: 100)]
        XCTAssertNil(mediaGridPaneHoleToLoad(visible: 10 ..< 30, isLoaded: { _ in true }, holes: holes))
    }

    func testHoleToLoadNilWithoutHoles() {
        XCTAssertNil(mediaGridPaneHoleToLoad(visible: 10 ..< 30, isLoaded: { _ in false }, holes: []))
    }

    func testHoleToLoadPicksNearestToFirstEmpty() {
        let holes = [MediaGridPaneHole(anchorIndex: 0), MediaGridPaneHole(anchorIndex: 35), MediaGridPaneHole(anchorIndex: 100)]
        let hole = mediaGridPaneHoleToLoad(visible: 20 ..< 60, isLoaded: { $0 < 40 }, holes: holes)
        XCTAssertEqual(hole?.anchorIndex, 35)
    }

    func testHoleToLoadTiePrefersUpper() {
        let holes = [MediaGridPaneHole(anchorIndex: 50), MediaGridPaneHole(anchorIndex: 30)]
        let hole = mediaGridPaneHoleToLoad(visible: 40 ..< 60, isLoaded: { _ in false }, holes: holes)
        XCTAssertEqual(hole?.anchorIndex, 50)
    }

    func testDateIndexUsesLowerAnchor() {
        let anchors: [(index: Int, timestamp: Int32)] = [(10, 1000), (50, 500), (90, 100)]
        XCTAssertEqual(mediaGridPaneDateIndex(at: 60, anchors: anchors), 500)
        XCTAssertEqual(mediaGridPaneDateIndex(at: 50, anchors: anchors), 500)
        XCTAssertEqual(mediaGridPaneDateIndex(at: 95, anchors: anchors), 100)
    }

    func testDateIndexBeforeFirstUsesFirst() {
        let anchors: [(index: Int, timestamp: Int32)] = [(10, 1000), (50, 500)]
        XCTAssertEqual(mediaGridPaneDateIndex(at: 3, anchors: anchors), 1000)
    }

    func testDateIndexEmpty() {
        XCTAssertNil(mediaGridPaneDateIndex(at: 3, anchors: []))
    }

    func testChangedIndicesIgnoreSameMedia() {
        let old: [Int: String] = [0: "a", 1: "b", 2: "c"]
        let new: [Int: String] = [0: "a", 1: "b2", 2: "c"]
        XCTAssertEqual(mediaGridPaneChangedIndices(old: old, new: new, overlap: 3), IndexSet([1]))
    }

    func testChangedIndicesCountLoadAndUnload() {
        let old: [Int: String] = [0: "a"]
        let new: [Int: String] = [1: "b"]
        XCTAssertEqual(mediaGridPaneChangedIndices(old: old, new: new, overlap: 2), IndexSet([0, 1]))
    }

    func testStateGatePassesThroughWhenIdle() {
        var gate = MediaGridPaneStateGate<Int>()
        XCTAssertEqual(gate.offer(1, isBusy: false), 1)
        XCTAssertNil(gate.release())
    }

    func testStateGateHoldsLatestWhileBusy() {
        var gate = MediaGridPaneStateGate<Int>()
        XCTAssertNil(gate.offer(1, isBusy: true))
        XCTAssertNil(gate.offer(2, isBusy: true))
        XCTAssertTrue(gate.isHolding)
        XCTAssertEqual(gate.release(), 2)
        XCTAssertNil(gate.release())
        XCTAssertFalse(gate.isHolding)
    }
    func testRowIsReadyOnlyWhenEveryCellIsReady() {
        let ready: Set<Int> = [0, 1, 2, 3, 4]
        XCTAssertTrue(mediaGridPaneRowIsReady(index: 1, columns: 3, count: 100, isEndKnown: true, isReady: { ready.contains($0) }))
        XCTAssertFalse(mediaGridPaneRowIsReady(index: 4, columns: 3, count: 100, isEndKnown: true, isReady: { ready.contains($0) }))
        XCTAssertFalse(mediaGridPaneRowIsReady(index: 3, columns: 3, count: 100, isEndKnown: true, isReady: { ready.contains($0) }))
    }

    func testPartialLastRowWaitsUntilEndIsKnown() {
        let isReady: (Int) -> Bool = { _ in true }
        XCTAssertFalse(mediaGridPaneRowIsReady(index: 6, columns: 5, count: 7, isEndKnown: false, isReady: isReady))
        XCTAssertTrue(mediaGridPaneRowIsReady(index: 6, columns: 5, count: 7, isEndKnown: true, isReady: isReady))
        XCTAssertTrue(mediaGridPaneRowIsReady(index: 2, columns: 5, count: 7, isEndKnown: false, isReady: isReady))
    }

    func testRevealDelaysStaggerRowsTopToBottom() {
        XCTAssertEqual(mediaGridPaneRevealDelays(rows: [7, 5, 6]), [5: 0.0, 6: 0.04, 7: 0.08])
        let delays = mediaGridPaneRevealDelays(rows: Array(0 ..< 40))
        XCTAssertEqual(delays[0], 0.0)
        XCTAssertEqual(delays[39] ?? 0.0, 0.3, accuracy: 0.0001)
        XCTAssertTrue(mediaGridPaneRevealDelays(rows: []).isEmpty)
    }
    func testHoleNearestToIndexMatchesLinearScan() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0 ..< 200 {
            let anchors = Set((0 ..< Int.random(in: 1 ... 40, using: &generator)).map { _ in Int.random(in: 0 ..< 500, using: &generator) }).sorted()
            let holes = anchors.map { MediaGridPaneHole(anchorIndex: $0) }
            let target = Int.random(in: 0 ..< 500, using: &generator)
            var expected: MediaGridPaneHole?
            var bestDistance = Int.max
            for hole in holes {
                let distance = abs(hole.anchorIndex - target)
                if distance < bestDistance || (distance == bestDistance && hole.anchorIndex > (expected?.anchorIndex ?? Int.min)) {
                    expected = hole
                    bestDistance = distance
                }
            }
            XCTAssertEqual(mediaGridPaneHoleNearest(to: target, sortedHoles: holes), expected)
        }
        XCTAssertNil(mediaGridPaneHoleNearest(to: 5, sortedHoles: []))
    }
}
