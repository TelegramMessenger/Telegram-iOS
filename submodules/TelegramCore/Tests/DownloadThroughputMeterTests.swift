import XCTest
@testable import TelegramCore

final class DownloadThroughputMeterTests: XCTestCase {
    private let mb: Int64 = 1024 * 1024

    func testPartsInFlightTogetherAreChargedTheirBusyTimeOnce() {
        let meter = DownloadThroughputMeter()
        meter.add(bytes: self.mb, networkDuration: 1.0, isWifi: true, completedAt: 10.0)
        meter.add(bytes: self.mb, networkDuration: 0.5, isWifi: true, completedAt: 10.0)

        XCTAssertEqual(meter.estimate(isWifi: true, now: 10.0) ?? 0.0, Double(2 * self.mb) * 8.0, accuracy: 1.0)
    }

    func testIdleGapsBetweenPartsAreNotCharged() {
        let meter = DownloadThroughputMeter()
        meter.add(bytes: self.mb, networkDuration: 1.0, isWifi: true, completedAt: 10.0)
        meter.add(bytes: self.mb, networkDuration: 1.0, isWifi: true, completedAt: 20.0)

        XCTAssertEqual(meter.estimate(isWifi: true, now: 20.0) ?? 0.0, Double(2 * self.mb) * 8.0 / 2.0, accuracy: 1.0)
    }

    // Small files measure the round trip, not the link.
    func testAFewSmallPartsGiveNoEstimate() {
        let meter = DownloadThroughputMeter()
        for i in 0 ..< 10 {
            meter.add(bytes: 16 * 1024, networkDuration: 0.1, isWifi: true, completedAt: Double(i))
        }

        XCTAssertNil(meter.estimate(isWifi: true, now: 10.0))
    }

    func testSamplesOlderThanTheWindowNoLongerCount() {
        let meter = DownloadThroughputMeter()
        meter.add(bytes: self.mb, networkDuration: 1.0, isWifi: true, completedAt: 10.0)

        XCTAssertNotNil(meter.estimate(isWifi: true, now: 100.0))
        XCTAssertNil(meter.estimate(isWifi: true, now: 200.0))
    }

    func testNetworkTypesAreMeasuredApart() {
        let meter = DownloadThroughputMeter()
        meter.add(bytes: self.mb, networkDuration: 1.0, isWifi: true, completedAt: 10.0)

        XCTAssertNotNil(meter.estimate(isWifi: true, now: 10.0))
        XCTAssertNil(meter.estimate(isWifi: false, now: 10.0))
    }

    func testAPartWithoutAnEngineDurationIsNotRecorded() {
        let meter = DownloadThroughputMeter()
        meter.add(bytes: self.mb, networkDuration: 0.0, isWifi: true, completedAt: 10.0)

        XCTAssertNil(meter.estimate(isWifi: true, now: 10.0))
    }
}
