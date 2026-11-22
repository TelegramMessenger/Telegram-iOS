import Foundation
import XCTest
@testable import HLSPlayback

final class HLSBandwidthStoreTests: XCTestCase {
    private let wifi = HLSNetworkClass("wifi")
    private let cellular = HLSNetworkClass("cellular-lte")

    // MARK: Estimates

    func testAClassWithoutSamplesHasNoEstimator() {
        XCTAssertNil(HLSBandwidthStore().estimator(for: self.wifi))
    }

    func testWithTotalWeightKeepsTheEstimate() {
        var ewma = HLSEWMA(halfLife: 3.0)
        ewma.sample(weight: 2.0, value: 1000.0)
        ewma.sample(weight: 1.0, value: 3000.0)
        let reweighted = ewma.withTotalWeight(0.5)
        XCTAssertEqual(reweighted.estimate, ewma.estimate, accuracy: 1e-9)
        XCTAssertEqual(reweighted.totalWeight, 0.5)
    }

    func testSamplesAreSharedWithinAClassAndSeparateAcrossClasses() {
        let store = HLSBandwidthStore()
        let result = store.sample(durationMs: 1000.0, bytes: 1_250_000, networkClass: self.wifi, defaultEstimate: 500_000.0, now: 1.0)
        XCTAssertEqual(result.estimate, 10_000_000.0, accuracy: 1e-3)
        XCTAssertEqual(store.estimator(for: self.wifi)?.estimate ?? -1.0, result.estimate)
        XCTAssertNil(store.estimator(for: self.cellular))
    }

    // 20 s of 10 Mbit/s, then 600 s idle: the class's estimate is a prior of weight 4 × 0.5^(600 / 300) = 1, as if one
    // second of 10 Mbit/s had been sampled, before the next sample.
    func testAfterAnIdleGapTheEstimateBecomesAPrior() {
        let store = HLSBandwidthStore()
        for i in 1 ... 20 {
            let _ = store.sample(durationMs: 1000.0, bytes: 1_250_000, networkClass: self.wifi, defaultEstimate: 500_000.0, now: Double(i))
        }
        let result = store.sample(durationMs: 1000.0, bytes: 250_000, networkClass: self.wifi, defaultEstimate: 500_000.0, now: 620.0)
        var expected = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
        expected.sample(durationMs: 1000.0, bytes: 1_250_000)
        expected.sample(durationMs: 1000.0, bytes: 250_000)
        XCTAssertEqual(result.estimate, expected.estimate, accuracy: expected.estimate * 1e-9)
    }

    func testShortGapsKeepTheFullWeight() {
        let store = HLSBandwidthStore()
        var expected = HLSBandwidthEstimator(defaultEstimate: 500_000.0)
        for i in 1 ... 20 {
            let _ = store.sample(durationMs: 1000.0, bytes: 1_250_000, networkClass: self.wifi, defaultEstimate: 500_000.0, now: Double(i))
            expected.sample(durationMs: 1000.0, bytes: 1_250_000)
        }
        let result = store.sample(durationMs: 1000.0, bytes: 250_000, networkClass: self.wifi, defaultEstimate: 500_000.0, now: 25.0)
        expected.sample(durationMs: 1000.0, bytes: 250_000)
        XCTAssertEqual(result.estimate, expected.estimate, accuracy: expected.estimate * 1e-9)
    }

    // MARK: Link busy time

    func testASingleLoadIsChargedItsWholeTime() {
        let store = HLSBandwidthStore()
        let load = store.beginLoad(networkClass: self.wifi, now: 0.0)
        XCTAssertEqual(store.endLoad(load, now: 1.0), 1.0, accuracy: 1e-9)
    }

    func testOverlappingLoadsAreChargedTheUnion() {
        let store = HLSBandwidthStore()
        let first = store.beginLoad(networkClass: self.wifi, now: 0.0)
        let second = store.beginLoad(networkClass: self.wifi, now: 0.7)
        XCTAssertEqual(store.endLoad(first, now: 1.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(store.endLoad(second, now: 1.8), 0.8, accuracy: 1e-9)
    }

    func testAnIdleGapStartsANewBusyPeriod() {
        let store = HLSBandwidthStore()
        let first = store.beginLoad(networkClass: self.wifi, now: 0.0)
        XCTAssertEqual(store.endLoad(first, now: 1.0), 1.0, accuracy: 1e-9)
        let second = store.beginLoad(networkClass: self.wifi, now: 3.0)
        XCTAssertEqual(store.endLoad(second, now: 4.0), 1.0, accuracy: 1e-9)
    }

    // A cancelled load is not sampled, and its time goes to the load still running rather than nowhere: that load's
    // bytes moved during it too, so cutting its charge at the cancel would overstate the link.
    func testACancelledLoadsTimeGoesToTheLoadStillRunning() {
        let store = HLSBandwidthStore()
        let first = store.beginLoad(networkClass: self.wifi, now: 0.0)
        let second = store.beginLoad(networkClass: self.wifi, now: 0.5)
        store.cancelLoad(first, now: 1.0)
        XCTAssertEqual(store.endLoad(second, now: 2.0), 2.0, accuracy: 1e-9)
    }

    func testClassesHaveSeparateLinks() {
        let store = HLSBandwidthStore()
        let first = store.beginLoad(networkClass: self.wifi, now: 0.0)
        let second = store.beginLoad(networkClass: self.cellular, now: 0.5)
        XCTAssertEqual(store.endLoad(first, now: 1.0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(store.endLoad(second, now: 1.5), 1.0, accuracy: 1e-9)
    }

    // MARK: A seeded prior

    // The account's other downloads (`DownloadThroughputMeter`) give a class with no sample of its own a starting
    // estimate with no weight.
    func testASeededPriorIsAWeightlessEstimate() {
        let store = HLSBandwidthStore()
        store.seedPrior(bitsPerSecond: 8_000_000.0, networkClass: self.wifi)
        let estimator = store.estimator(for: self.wifi)
        XCTAssertEqual(estimator?.estimate ?? -1.0, 8_000_000.0, accuracy: 1e-3)
        XCTAssertEqual(estimator?.canEstimate, false)
    }

    func testTheFirstSampleReplacesASeededPrior() {
        let store = HLSBandwidthStore()
        store.seedPrior(bitsPerSecond: 8_000_000.0, networkClass: self.wifi)
        let result = store.sample(durationMs: 1000.0, bytes: 250_000, networkClass: self.wifi, defaultEstimate: 500_000.0, now: 1.0)
        XCTAssertEqual(result.estimate, 2_000_000.0, accuracy: 1e-3)
    }

    // A seed is what the other downloads measured at the time: a later one replaces it until the class samples.
    func testALaterSeedReplacesAnEarlierOneTheClassNeverSampled() {
        let store = HLSBandwidthStore()
        store.seedPrior(bitsPerSecond: 8_000_000.0, networkClass: self.wifi)
        store.seedPrior(bitsPerSecond: 2_000_000.0, networkClass: self.wifi)
        XCTAssertEqual(store.estimator(for: self.wifi)?.estimate ?? -1.0, 2_000_000.0, accuracy: 1e-3)
    }

    func testASeedNeverReplacesTheClassesOwnEstimate() {
        let store = HLSBandwidthStore()
        let _ = store.sample(durationMs: 1000.0, bytes: 1_250_000, networkClass: self.wifi, defaultEstimate: 500_000.0, now: 1.0)
        store.seedPrior(bitsPerSecond: 1_000_000.0, networkClass: self.wifi)
        XCTAssertEqual(store.estimator(for: self.wifi)?.estimate ?? -1.0, 10_000_000.0, accuracy: 1e-3)
    }
}
