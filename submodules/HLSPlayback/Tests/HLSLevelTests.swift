import XCTest
@testable import HLSPlayback

final class HLSLevelTests: XCTestCase {
    func testSortsByHeightThenBandwidth() {
        let levels = [
            HLSLevel(key: 720, width: 1280, height: 720, bandwidth: 1_200_000),
            HLSLevel(key: 360, width: 640, height: 360, bandwidth: 290_000),
            HLSLevel(key: 720, width: 1280, height: 720, bandwidth: 900_000),
            HLSLevel(key: 1080, width: 1920, height: 1080, bandwidth: 1_650_000),
        ]
        let sorted = HLSLevels.sorted(levels)
        XCTAssertEqual(sorted.map(\.height), [360, 720, 720, 1080])
        XCTAssertEqual(sorted.map(\.bandwidth), [290_000, 900_000, 1_200_000, 1_650_000])
    }
    
    // Portrait videos sort by height too, as hls.js does, though their key is the width.
    func testPortraitLevelsSortByHeight() {
        let levels = [
            HLSLevel(key: 720, width: 720, height: 1280, bandwidth: 1_200_000),
            HLSLevel(key: 360, width: 360, height: 640, bandwidth: 290_000),
        ]
        XCTAssertEqual(HLSLevels.sorted(levels).map(\.key), [360, 720])
    }
    
    func testPreloadQualityKeyPicksFirstAtLeast600() {
        XCTAssertEqual(HLSLevels.preloadQualityKey(keys: [360, 480, 720, 1080]), 720)
        XCTAssertEqual(HLSLevels.preloadQualityKey(keys: [1080, 720, 480, 360]), 720)
        XCTAssertEqual(HLSLevels.preloadQualityKey(keys: [240, 360]), 240)
        XCTAssertEqual(HLSLevels.preloadQualityKey(keys: [600]), 600)
        XCTAssertNil(HLSLevels.preloadQualityKey(keys: []))
    }
    
    func testStartLevelPrefersHighestCachedOpening() {
        let cached: Set<Int> = [1, 3]
        XCTAssertEqual(HLSLevels.startLevel(cap: 3, preloadLevel: 2, manualLevel: nil, isOpeningOnDisk: { cached.contains($0) }), 3)
        XCTAssertEqual(HLSLevels.startLevel(cap: 2, preloadLevel: 2, manualLevel: nil, isOpeningOnDisk: { cached.contains($0) }), 1)
    }
    
    func testStartLevelFallsBackToPreloadClampedToCap() {
        XCTAssertEqual(HLSLevels.startLevel(cap: 1, preloadLevel: 2, manualLevel: nil, isOpeningOnDisk: { _ in false }), 1)
        XCTAssertEqual(HLSLevels.startLevel(cap: 3, preloadLevel: 2, manualLevel: nil, isOpeningOnDisk: { _ in false }), 2)
    }
    
    func testManualStartLevelWins() {
        XCTAssertEqual(HLSLevels.startLevel(cap: 1, preloadLevel: 2, manualLevel: 3, isOpeningOnDisk: { $0 == 0 }), 3)
    }
    
    // With nothing cached, the level the shared estimate picks, within the cap, in place of the preload quality.
    func testStartLevelTakesTheEstimatesLevelWhenNothingIsCached() {
        XCTAssertEqual(HLSLevels.startLevel(cap: 3, preloadLevel: 2, manualLevel: nil, estimateLevel: 3, isOpeningOnDisk: { _ in false }), 3)
        XCTAssertEqual(HLSLevels.startLevel(cap: 2, preloadLevel: 2, manualLevel: nil, estimateLevel: 3, isOpeningOnDisk: { _ in false }), 2)
    }
    
    func testACachedOpeningWinsOverTheEstimate() {
        XCTAssertEqual(HLSLevels.startLevel(cap: 3, preloadLevel: 2, manualLevel: nil, estimateLevel: 3, isOpeningOnDisk: { $0 == 1 }), 1)
    }
}
