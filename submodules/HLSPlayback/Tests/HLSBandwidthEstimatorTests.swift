import XCTest
@testable import HLSPlayback

final class HLSBandwidthEstimatorTests: XCTestCase {
    func testEstimatorMatchesHLSJSGoldens() {
        XCTAssertEqual(HLSJSGoldens.estimatorCases.count, 5)
        for (caseIndex, goldenCase) in HLSJSGoldens.estimatorCases.enumerated() {
            var estimator = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
            for (sampleIndex, sample) in goldenCase.samples.enumerated() {
                estimator.sample(durationMs: sample.durationMs, bytes: sample.bytes)
                let expected = goldenCase.estimates[sampleIndex]
                XCTAssertEqual(estimator.estimate, expected, accuracy: abs(expected) * 1e-6, "case \(caseIndex), sample \(sampleIndex)")
            }
        }
    }
    
    func testSingleSampleIsTheSampleExactly() {
        var estimator = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
        estimator.sample(durationMs: 1000.0, bytes: 1_000_000)
        XCTAssertEqual(estimator.estimate, 8_000_000.0, accuracy: 1e-6)
    }
    
    func testDurationFloorCapsAt800Mbps() {
        var estimator = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
        estimator.sample(durationMs: 0.0, bytes: 2_000_000)
        XCTAssertEqual(estimator.estimate, 800_000_000.0, accuracy: 1e-3)
    }
    
    func testNoEstimateBeforeFirstSample() {
        var estimator = HLSBandwidthEstimator(defaultEstimate: 1_234_000.0)
        XCTAssertFalse(estimator.canEstimate)
        XCTAssertEqual(estimator.estimate, 1_234_000.0)
        estimator.sample(durationMs: 100.0, bytes: 0)
        XCTAssertFalse(estimator.canEstimate)
    }
    
    func testResetDropsHistory() {
        var estimator = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
        estimator.sample(durationMs: 1000.0, bytes: 1_000_000)
        XCTAssertTrue(estimator.canEstimate)
        estimator.reset(defaultEstimate: 1_000_000.0)
        XCTAssertFalse(estimator.canEstimate)
        XCTAssertEqual(estimator.estimate, 1_000_000.0)
    }
    
    func testEWMAZeroFactorCorrection() {
        var ewma = HLSEWMA(halfLife: 3.0)
        ewma.sample(weight: 0.25, value: 1000.0)
        XCTAssertEqual(ewma.estimate, 1000.0, accuracy: 1e-9)
        XCTAssertEqual(ewma.totalWeight, 0.25)
    }
}
