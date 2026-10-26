#if DEBUG

import XCTest
@testable import TelegramCore

final class DebugNetworkShaperTests: XCTestCase {
    private func shaper(bitsPerSecond: Double, roundTrip: Double) -> DebugNetworkShaper {
        return DebugNetworkShaper(profile: DebugNetworkShaper.Profile(name: "test", steps: [DebugNetworkShaper.Step(start: 0.0, bitsPerSecond: bitsPerSecond)], roundTrip: roundTrip), startTime: 0.0)
    }

    func testAResponseArrivesAfterTheRoundTripAndItsTransfer() {
        let shaper = self.shaper(bitsPerSecond: 8_000_000.0, roundTrip: 0.1)
        XCTAssertEqual(shaper.holdDuration(bytes: 1_000_000, sentAt: 0.0, now: 0.01), 1.09, accuracy: 1e-9)
    }

    func testResponsesShareTheLink() {
        let shaper = self.shaper(bitsPerSecond: 8_000_000.0, roundTrip: 0.1)
        XCTAssertEqual(shaper.holdDuration(bytes: 1_000_000, sentAt: 0.0, now: 0.01), 1.09, accuracy: 1e-9)
        XCTAssertEqual(shaper.holdDuration(bytes: 1_000_000, sentAt: 0.0, now: 0.01), 2.09, accuracy: 1e-9)
    }

    func testALateResponseIsNotHeld() {
        let shaper = self.shaper(bitsPerSecond: 8_000_000.0, roundTrip: 0.1)
        XCTAssertEqual(shaper.holdDuration(bytes: 1000, sentAt: 0.0, now: 5.0), 0.0)
    }

    func testTheBandwidthFollowsItsSteps() {
        guard let profile = DebugNetworkShaper.Profile.named("step-down") else {
            XCTFail("no step-down profile")
            return
        }
        let shaper = DebugNetworkShaper(profile: profile, startTime: 0.0)
        XCTAssertEqual(shaper.holdDuration(bytes: 125_000, sentAt: 31.0, now: 31.0), 0.08 + 1.0, accuracy: 1e-9)
    }

    func testProfilesByName() {
        let threeG = DebugNetworkShaper.Profile.named("3g")
        XCTAssertEqual(threeG?.roundTrip, 0.3)
        XCTAssertEqual(threeG?.steps, [DebugNetworkShaper.Step(start: 0.0, bitsPerSecond: 1_500_000.0)])
        let custom = DebugNetworkShaper.Profile.named("2000000,150")
        XCTAssertEqual(custom?.steps, [DebugNetworkShaper.Step(start: 0.0, bitsPerSecond: 2_000_000.0)])
        XCTAssertEqual(custom?.roundTrip ?? 0.0, 0.15, accuracy: 1e-12)
        XCTAssertNil(DebugNetworkShaper.Profile.named("bogus"))
    }

    func testNoProfileMeansNoShaper() {
        XCTAssertNil(DebugNetworkShaper.shared)
    }
}

#endif
