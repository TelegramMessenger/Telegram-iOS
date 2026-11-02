import XCTest
@testable import HLSPlayback

final class HLSAbrTests: XCTestCase {
    private struct FindBestLevelCase {
        var levelSet: Int
        var bandwidth: Double
        var lastLoaded: Int
        var bufferStarvationDelay: Double
        var maxStarvationDelay: Double
        var bandwidthFactor: Double
        var upFactor: Double
        var detailsLoaded: Bool
        var maxAutoLevel: Int
        var expected: Int
    }
    
    private struct NextAutoLevelCase {
        var levelSet: Int
        var bandwidth: Double
        var lastLoaded: Int
        var bufferStarvationDelay: Double
        var detailsLoaded: Bool
        var maxAutoLevel: Int
        var expected: Int
    }
    
    private static func rows(_ table: String) -> [[Double]] {
        return table.split(separator: "\n").map { line in
            return line.split(separator: " ").map { Double($0)! }
        }
    }
    
    private static let findBestLevelCases: [FindBestLevelCase] = rows(HLSJSGoldens.findBestLevelTable).map { r in
        return FindBestLevelCase(levelSet: Int(r[0]), bandwidth: r[1], lastLoaded: Int(r[2]), bufferStarvationDelay: r[3], maxStarvationDelay: r[4], bandwidthFactor: r[5], upFactor: r[6], detailsLoaded: r[7] != 0.0, maxAutoLevel: Int(r[8]), expected: Int(r[9]))
    }
    
    private static let nextAutoLevelCases: [NextAutoLevelCase] = rows(HLSJSGoldens.nextAutoLevelTable).map { r in
        return NextAutoLevelCase(levelSet: Int(r[0]), bandwidth: r[1], lastLoaded: Int(r[2]), bufferStarvationDelay: r[3], detailsLoaded: r[4] != 0.0, maxAutoLevel: Int(r[5]), expected: Int(r[6]))
    }
    
    private static func goldenLevels(_ index: Int) -> [HLSLevel] {
        return HLSJSGoldens.levelSets[index].map { spec in
            return HLSLevel(key: min(spec.width, spec.height), width: spec.width, height: spec.height, bandwidth: spec.bandwidth)
        }
    }
    
    private static let fourLevels: [HLSLevel] = [
        HLSLevel(key: 360, width: 640, height: 360, bandwidth: 290_000),
        HLSLevel(key: 480, width: 854, height: 480, bandwidth: 600_000),
        HLSLevel(key: 720, width: 1280, height: 720, bandwidth: 1_200_000),
        HLSLevel(key: 1080, width: 1920, height: 1080, bandwidth: 1_650_000),
    ]
    
    private static func context(levels: [HLSLevel] = fourLevels, averageSegmentDuration: Double? = 5.0, maxAutoLevel: Int? = nil, lastLoadedLevel: Int? = nil, currentSegmentDuration: Double? = 5.0, bufferStarvationDelay: Double = 0.0) -> HLSAbrContext {
        return HLSAbrContext(
            levels: levels,
            averageSegmentDuration: Array(repeating: averageSegmentDuration, count: levels.count),
            levelErrors: Array(repeating: 0, count: levels.count),
            minAutoLevel: 0,
            maxAutoLevel: maxAutoLevel ?? (levels.count - 1),
            lastLoadedLevel: lastLoadedLevel,
            currentSegmentDuration: currentSegmentDuration,
            bufferStarvationDelay: bufferStarvationDelay,
            ttfbSeconds: HLSBandwidthEstimator.defaultTTFBMs / 1000.0,
            lastLevelLoadSeconds: 0.0
        )
    }
    
    // Only cases with every playlist loaded: without one, hls.js would select the level and load its playlist, while
    // the port never selects a level it has no playlist for.
    func testFindBestLevelMatchesHLSJSGoldens() {
        let cases = HLSAbrTests.findBestLevelCases.filter(\.detailsLoaded)
        XCTAssertGreaterThan(cases.count, 1000)
        var mismatches = 0
        for c in cases {
            let context = HLSAbrTests.context(levels: HLSAbrTests.goldenLevels(c.levelSet), maxAutoLevel: c.maxAutoLevel, lastLoadedLevel: c.lastLoaded < 0 ? nil : c.lastLoaded, currentSegmentDuration: HLSJSGoldens.segmentDuration)
            let result = HLSAbr.findBestLevel(context, bandwidth: c.bandwidth, minAutoLevel: 0, maxAutoLevel: c.maxAutoLevel, bufferStarvationDelay: c.bufferStarvationDelay, maxStarvationDelay: c.maxStarvationDelay, bandwidthFactor: c.bandwidthFactor, upFactor: c.upFactor) ?? -1
            if result != c.expected {
                mismatches += 1
                if mismatches <= 10 {
                    XCTFail("\(c): got \(result)")
                }
            }
        }
        XCTAssertEqual(mismatches, 0)
    }
    
    func testNextAutoLevelMatchesHLSJSGoldens() {
        let cases = HLSAbrTests.nextAutoLevelCases.filter(\.detailsLoaded)
        XCTAssertGreaterThan(cases.count, 100)
        var mismatches = 0
        for c in cases {
            let context = HLSAbrTests.context(levels: HLSAbrTests.goldenLevels(c.levelSet), maxAutoLevel: c.maxAutoLevel, lastLoadedLevel: c.lastLoaded, currentSegmentDuration: HLSJSGoldens.segmentDuration, bufferStarvationDelay: c.bufferStarvationDelay)
            let result = HLSAbr.nextAutoLevel(context, estimate: c.bandwidth, currentLoadLevel: c.lastLoaded)
            if result != c.expected {
                mismatches += 1
                if mismatches <= 10 {
                    XCTFail("\(c): got \(result)")
                }
            }
        }
        XCTAssertEqual(mismatches, 0)
    }
    
    // The four-level set over what the base grid keeps fixed: segment durations, a level with load errors, a cap of 0.
    private static func variedContext(_ r: [Double], bufferStarvationDelay: Double) -> HLSAbrContext {
        let durations = HLSJSGoldens.durationProfiles[Int(r[0])]
        let errorMask = Int(r[1])
        let lastLoaded = Int(r[4])
        let levels = HLSAbrTests.goldenLevels(0)
        return HLSAbrContext(
            levels: levels,
            averageSegmentDuration: durations.map { Optional($0) },
            levelErrors: (0 ..< levels.count).map { (errorMask >> $0) & 1 },
            minAutoLevel: 0,
            maxAutoLevel: Int(r[2]),
            lastLoadedLevel: lastLoaded < 0 ? nil : lastLoaded,
            currentSegmentDuration: durations[max(lastLoaded, 0)],
            bufferStarvationDelay: bufferStarvationDelay,
            ttfbSeconds: HLSBandwidthEstimator.defaultTTFBMs / 1000.0,
            lastLevelLoadSeconds: 0.0
        )
    }
    
    func testFindBestLevelMatchesHLSJSGoldensOverVariedLevels() {
        let rows = HLSAbrTests.rows(HLSJSGoldens.findBestLevelVariedTable)
        XCTAssertGreaterThan(rows.count, 1000)
        var mismatches = 0
        for r in rows {
            let context = HLSAbrTests.variedContext(r, bufferStarvationDelay: r[5])
            let result = HLSAbr.findBestLevel(context, bandwidth: r[3], minAutoLevel: 0, maxAutoLevel: Int(r[2]), bufferStarvationDelay: r[5], maxStarvationDelay: r[6], bandwidthFactor: 0.95, upFactor: 0.7) ?? -1
            if result != Int(r[7]) {
                mismatches += 1
                if mismatches <= 10 {
                    XCTFail("\(r): got \(result)")
                }
            }
        }
        XCTAssertEqual(mismatches, 0)
    }
    
    func testNextAutoLevelMatchesHLSJSGoldensOverVariedLevels() {
        let rows = HLSAbrTests.rows(HLSJSGoldens.nextAutoLevelVariedTable)
        XCTAssertGreaterThan(rows.count, 400)
        var mismatches = 0
        for r in rows {
            let context = HLSAbrTests.variedContext(r, bufferStarvationDelay: r[5])
            let result = HLSAbr.nextAutoLevel(context, estimate: r[3], currentLoadLevel: Int(r[4]))
            if result != Int(r[6]) {
                mismatches += 1
                if mismatches <= 10 {
                    XCTFail("\(r): got \(result)")
                }
            }
        }
        XCTAssertEqual(mismatches, 0)
    }
    
    // hls.js's _abandonRulesCheck with the TTFB fixed at 100 ms and samples over the whole load (D2), which the
    // generator models on the hls.js side: whether it abandons, the level, the estimate it resets to and the estimate.
    func testAbandonDecisionMatchesHLSJSGoldens() {
        let rows = HLSAbrTests.rows(HLSJSGoldens.abandonTable)
        XCTAssertGreaterThan(rows.count, 3000)
        var abandons = 0
        var mismatches = 0
        for r in rows {
            let fragLevel = Int(r[1])
            let duration = r[2]
            let variant = Int(r[8])
            var estimator = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
            for sample in HLSJSGoldens.abandonHistories[Int(r[0])] {
                estimator.sample(durationMs: sample.durationMs, bytes: sample.bytes)
            }
            var durations: [Double?] = Array(repeating: duration, count: 4)
            if variant == 1 {
                durations[1] = nil
            }
            let context = HLSAbrContext(
                levels: HLSAbrTests.goldenLevels(0),
                averageSegmentDuration: durations,
                levelErrors: [0, 0, 0, 0],
                minAutoLevel: 0,
                maxAutoLevel: 3,
                lastLoadedLevel: fragLevel,
                currentSegmentDuration: duration,
                bufferStarvationDelay: r[6],
                ttfbSeconds: HLSBandwidthEstimator.defaultTTFBMs / 1000.0,
                lastLevelLoadSeconds: variant == 1 ? 0.4 : 0.0
            )
            let input = HLSAbandonInput(fragmentLevel: fragLevel, fragmentDuration: duration, expectedBytes: Int64(r[3]), loadedBytes: Int64(r[4]), elapsedMs: r[5], estimator: estimator, playbackRate: r[7], isPaused: false, context: context)
            let decision = HLSAbr.abandonDecision(input)
            var matches = (decision?.level ?? -1) == Int(r[9]) && (decision?.resetEstimateTo ?? 0.0) == r[10]
            if let decision {
                abandons += 1
                matches = matches && abs(decision.estimator.estimate - r[11]) <= 1e-6 * max(1.0, r[11])
            }
            if !matches {
                mismatches += 1
                if mismatches <= 10 {
                    XCTFail("\(r): got level \(decision?.level ?? -1) reset \(decision?.resetEstimateTo ?? 0.0) estimate \(decision?.estimator.estimate ?? 0.0)")
                }
            }
        }
        XCTAssertGreaterThan(abandons, 500)
        XCTAssertEqual(mismatches, 0)
    }
    
    func testLevelWithoutPlaylistIsNeverSelected() {
        var context = HLSAbrTests.context(lastLoadedLevel: 1, bufferStarvationDelay: 30.0)
        context.averageSegmentDuration[3] = nil
        let result = HLSAbr.findBestLevel(context, bandwidth: 100_000_000.0, minAutoLevel: 0, maxAutoLevel: 3, bufferStarvationDelay: 30.0, maxStarvationDelay: 4.0, bandwidthFactor: 0.95, upFactor: 0.7)
        XCTAssertEqual(result, 2)
        XCTAssertEqual(HLSAbr.nextAutoLevel(context, estimate: 100_000_000.0, currentLoadLevel: 1), 2)
    }
    
    func testSingleLevelAlwaysZero() {
        let levels = [HLSLevel(key: 720, width: 1280, height: 720, bandwidth: 1_200_000)]
        let context = HLSAbrTests.context(levels: levels, lastLoadedLevel: 0)
        XCTAssertEqual(HLSAbr.findBestLevel(context, bandwidth: 1.0, minAutoLevel: 0, maxAutoLevel: 0, bufferStarvationDelay: 0.0, maxStarvationDelay: 0.0, bandwidthFactor: 0.95, upFactor: 0.7), 0)
        XCTAssertEqual(HLSAbr.nextAutoLevel(context, estimate: 1.0, currentLoadLevel: 0), 0)
    }
    
    func testTargetLevelWithoutSampleOrSeedIsPreload() {
        let context = HLSAbrTests.context()
        let estimator = HLSBandwidthEstimator(defaultEstimate: 5_000_000.0)
        XCTAssertEqual(HLSAbr.targetLevel(context, estimator: estimator, seed: nil, preloadLevel: 2), 2)
        XCTAssertEqual(HLSAbr.targetLevel(HLSAbrTests.context(maxAutoLevel: 1), estimator: estimator, seed: nil, preloadLevel: 2), 1)
    }
    
    // Level 2 would need 0.1 + 1.2 Mbit/s * 5 s / 1.3 Mbit/s = 4.7 s, over the 4 s start budget.
    func testTargetLevelWithSeedUsesFirstAutoRule() {
        let context = HLSAbrTests.context()
        let estimator = HLSBandwidthEstimator(defaultEstimate: 1_300_000.0)
        XCTAssertEqual(HLSAbr.targetLevel(context, estimator: estimator, seed: 1_300_000.0, preloadLevel: 2), 1)
    }
    
    func testTargetLevelWithTinySeedFallsToLowest() {
        let context = HLSAbrTests.context()
        let estimator = HLSBandwidthEstimator(defaultEstimate: 100_000.0)
        XCTAssertEqual(HLSAbr.targetLevel(context, estimator: estimator, seed: 100_000.0, preloadLevel: 2), 0)
    }
    
    func testTargetLevelWithSampleUsesABR() {
        let context = HLSAbrTests.context(lastLoadedLevel: 2, bufferStarvationDelay: 20.0)
        var estimator = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
        estimator.sample(durationMs: 2000.0, bytes: 100_000)
        // 400 kbit/s: only level 0 fits.
        XCTAssertEqual(HLSAbr.targetLevel(context, estimator: estimator, seed: 50_000_000.0, preloadLevel: 2), 0)
    }
    
    func testCacheAwarePrefersHighestCachedAtOrAboveTarget() {
        let cached: Set<Int> = [0, 2, 3]
        let result = HLSAbr.cacheAwareLevel(target: 1, maxAutoLevel: 2, isOnDisk: { cached.contains($0) })
        XCTAssertEqual(result.level, 2)
        XCTAssertTrue(result.fromDisk)
    }
    
    func testCacheAwareNeverUsesCacheAboveCap() {
        let result = HLSAbr.cacheAwareLevel(target: 1, maxAutoLevel: 2, isOnDisk: { $0 == 3 })
        XCTAssertEqual(result.level, 1)
        XCTAssertFalse(result.fromDisk)
    }
    
    func testCacheAwareIgnoresCacheBelowTarget() {
        let result = HLSAbr.cacheAwareLevel(target: 2, maxAutoLevel: 3, isOnDisk: { $0 == 0 })
        XCTAssertEqual(result.level, 2)
        XCTAssertFalse(result.fromDisk)
    }
    
    func testCacheAwareClampsATargetAboveTheCap() {
        let result = HLSAbr.cacheAwareLevel(target: 3, maxAutoLevel: 1, isOnDisk: { _ in false })
        XCTAssertEqual(result.level, 1)
        XCTAssertFalse(result.fromDisk)
    }
    
    private static func abandonInput(level: Int = 3, expectedBytes: Int64 = 2_000_000, loadedBytes: Int64 = 100_000, elapsedMs: Double = 3000.0, bufferStarvationDelay: Double = 2.0, isPaused: Bool = false) -> HLSAbandonInput {
        var estimator = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
        estimator.sample(durationMs: 1000.0, bytes: 250_000)
        return HLSAbandonInput(
            fragmentLevel: level,
            fragmentDuration: 5.0,
            expectedBytes: expectedBytes,
            loadedBytes: loadedBytes,
            elapsedMs: elapsedMs,
            estimator: estimator,
            playbackRate: 1.0,
            isPaused: isPaused,
            context: HLSAbrTests.context(lastLoadedLevel: level, bufferStarvationDelay: bufferStarvationDelay)
        )
    }
    
    func testAbandonWaitsForHalfTheFragmentDuration() {
        XCTAssertNil(HLSAbr.abandonDecision(HLSAbrTests.abandonInput(elapsedMs: 2000.0)))
        XCTAssertNil(HLSAbr.abandonDecision(HLSAbrTests.abandonInput(elapsedMs: 2500.0)))
    }
    
    func testAbandonSwitchesDownWhenFetchWouldStarve() {
        guard let decision = HLSAbr.abandonDecision(HLSAbrTests.abandonInput()) else {
            XCTFail("expected an abandon")
            return
        }
        XCTAssertLessThan(decision.level, 3)
        // 100 KB in 3 s is 267 kbit/s: the estimate after that sample, times 0.7, still exceeds level 0's bitrate.
        XCTAssertEqual(decision.resetEstimateTo, 290_000.0)
        XCTAssertEqual(decision.estimator.estimate, 290_000.0)
        XCTAssertFalse(decision.estimator.canEstimate)
    }
    
    // hls.js aborts at once when the in-flight segment needs more than twice the down level's time, and then drops to
    // the lowest level (`abortAndSwitch`, abr-controller.ts:425-461). Measured against hls.js 1.7.3 itself: it ends at
    // level 0 with the estimate reset to 290 kbit/s.
    func testAbandonFarBehindDropsToTheLowestLevel() {
        var estimator = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
        estimator.sample(durationMs: 1000.0, bytes: 250_000)
        let input = HLSAbandonInput(
            fragmentLevel: 3,
            fragmentDuration: 5.0,
            expectedBytes: 2_000_000,
            loadedBytes: 312_500,
            elapsedMs: 2600.0,
            estimator: estimator,
            playbackRate: 1.0,
            isPaused: false,
            context: HLSAbrTests.context(lastLoadedLevel: 3, bufferStarvationDelay: 6.0)
        )
        guard let decision = HLSAbr.abandonDecision(input) else {
            XCTFail("expected an abandon")
            return
        }
        XCTAssertEqual(decision.level, 0)
        XCTAssertEqual(decision.resetEstimateTo, 290_000.0)
        XCTAssertEqual(decision.estimator.estimate, 290_000.0)
    }
    
    // Not far behind: 6.5 s left against 2 x 3.85 s at level 2. hls.js switches to the down level on a timer instead,
    // and the replacement load aborts the request; the estimate (1.63 Mbit/s x 0.7) is not reset for 1.2 Mbit/s.
    func testAbandonNotFarBehindKeepsTheDownLevel() {
        var estimator = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
        estimator.sample(durationMs: 1000.0, bytes: 250_000)
        let input = HLSAbandonInput(
            fragmentLevel: 3,
            fragmentDuration: 5.0,
            expectedBytes: 1_800_000,
            loadedBytes: 500_000,
            elapsedMs: 2600.0,
            estimator: estimator,
            playbackRate: 1.0,
            isPaused: false,
            context: HLSAbrTests.context(lastLoadedLevel: 3, bufferStarvationDelay: 6.0)
        )
        let decision = HLSAbr.abandonDecision(input)
        XCTAssertEqual(decision?.level, 2)
        XCTAssertNil(decision?.resetEstimateTo)
    }
    
    func testAbandonNeverFromLowestLevel() {
        XCTAssertNil(HLSAbr.abandonDecision(HLSAbrTests.abandonInput(level: 0)))
    }
    
    func testAbandonNotWhilePausedOrFinished() {
        XCTAssertNil(HLSAbr.abandonDecision(HLSAbrTests.abandonInput(isPaused: true)))
        XCTAssertNil(HLSAbr.abandonDecision(HLSAbrTests.abandonInput(loadedBytes: 2_000_000)))
    }
    
    func testAbandonNotWhenTheBufferOutlastsTheLoad() {
        XCTAssertNil(HLSAbr.abandonDecision(HLSAbrTests.abandonInput(bufferStarvationDelay: 120.0)))
    }
}
