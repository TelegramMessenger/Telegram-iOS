import Foundation
import XCTest
@testable import HLSPlayback

// The shared estimate (D3): one per network class, read and fed by every player, and charged by the link's busy time.
final class HLSPlaybackControllerEstimateTests: XCTestCase {
    private let wifi = HLSNetworkClass("wifi")
    private let cellular = HLSNetworkClass("cellular-lte")

    func testTwoPlayersShareOneEstimate() {
        let store = HLSBandwidthStore()
        let first = ControllerHarness(store: store)
        first.environment.bandwidth = 20_000_000.0
        first.setPlaylists()
        first.controller.start()
        first.environment.advance(by: 5.0)
        XCTAssertNotNil(first.controller.estimate)

        let second = ControllerHarness(store: store)
        XCTAssertEqual(second.controller.estimate, first.controller.estimate)
        second.cache(level: 2, seconds: 5.0)
        second.setPlaylists()
        second.controller.start()
        // After the disk opening, the first network pick uses the first player's estimate: the top level.
        XCTAssertEqual(second.environment.loads.first?.level, 3)
        first.assertInvariants()
        second.assertInvariants()
    }

    func testANetworkClassChangeSwitchesEstimators() {
        let h = ControllerHarness(networkClass: self.wifi)
        h.setPlaylists()
        h.controller.start()
        h.play(to: 5.0)
        XCTAssertNotNil(h.store.estimator(for: self.wifi))
        XCTAssertGreaterThan(h.segmentLoads.last?.level ?? 0, 2)

        h.controller.setNetworkClass(self.cellular)
        XCTAssertNil(h.controller.estimate)
        let loadsBefore = h.segmentLoads.count
        h.play(to: 15.0)
        // Nothing is known on cellular: the next pick is the preload level.
        XCTAssertEqual(h.segmentLoads.dropFirst(loadsBefore).first?.level, 2)
        h.environment.assertInvariants()
    }

    // A load that began on Wi-Fi and finished on cellular measured neither.
    func testALoadThatSpansANetworkChangeIsNotSampled() {
        let h = ControllerHarness(networkClass: self.wifi)
        h.environment.bandwidth = 1_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 0.5)
        XCTAssertEqual(h.environment.loads.count, 1)
        h.controller.setNetworkClass(self.cellular)
        h.environment.advance(by: 10.0)

        XCTAssertTrue(h.environment.loads[0].completed)
        XCTAssertNil(h.store.estimator(for: self.wifi))
        XCTAssertNil(h.store.estimator(for: self.cellular))
        XCTAssertTrue(h.loggedSamples.isEmpty)
        h.environment.assertInvariants()
    }

    // A stopped player's load leaves the link: the next player's first load is charged from its own start.
    func testAStoppedControllerReleasesItsLinkShare() {
        let store = HLSBandwidthStore()
        let stopped = ControllerHarness(store: store)
        stopped.environment.bandwidth = 1_000_000.0
        stopped.setPlaylists()
        stopped.controller.start()
        stopped.environment.advance(by: 0.5)
        stopped.controller.stop()

        let next = ControllerHarness(store: store)
        next.environment.advance(by: 2.0)
        next.setPlaylists()
        next.controller.start()
        next.environment.advance(by: 5.0)
        guard let sample = next.loggedSamples.first, let load = next.segmentLoads.first(where: { $0.completed && $0.networkBytes > 0 }) else {
            XCTFail("no sample")
            return
        }
        XCTAssertEqual(sample.durationMs, (load.completionTime - load.startTime) * 1000.0, accuracy: 0.01)
        next.assertInvariants()
    }

    // Two players loading at once on one store are charged the link's busy time once.
    func testTwoPlayersLoadingTogetherShareTheBusyTime() {
        let store = HLSBandwidthStore()
        let first = ControllerHarness(store: store)
        let second = ControllerHarness(store: store)
        first.environment.bandwidth = 2_000_000.0
        second.environment.bandwidth = 2_000_000.0
        first.setPlaylists()
        second.setPlaylists()
        first.controller.start()
        // One clock for both: the two environments advance in lockstep, and the second player starts at 1 s.
        for step in 0 ..< 220 {
            if step == 20 {
                second.controller.start()
            }
            first.environment.advance(by: 0.05)
            second.environment.advance(by: 0.05)
        }
        
        // Both first loads ran on one clock: [0, end1] and [1, end2]. Charged together, they cover no more than their
        // union.
        guard let firstSample = first.loggedSamples.first, let secondSample = second.loggedSamples.first, let firstLoad = first.segmentLoads.first, let secondLoad = second.segmentLoads.first else {
            XCTFail("no samples")
            return
        }
        let union = max(firstLoad.completionTime, secondLoad.completionTime) - min(firstLoad.startTime, secondLoad.startTime)
        XCTAssertLessThanOrEqual(firstSample.durationMs + secondSample.durationMs, union * 1000.0 + 0.02)
    }

    // MARK: The cold start from the shared estimate

    // With nothing cached, a cold start takes the level the class's shared estimate picks when that level is above 480p:
    // on a fast link, the top level.
    func testAColdStartOnAFastLinkStartsAtTheEstimatesLevel() {
        let h = ControllerHarness(priorEstimate: 20_000_000.0)
        h.setPlaylists()
        h.controller.start()

        XCTAssertEqual(h.environment.loads.first?.level, 3)
        XCTAssertTrue(h.logLines.contains("start level=1080 reason=estimate position=0.0"), "\(h.logLines)")
        h.assertInvariants()
    }

    // An estimate that picks 480p or lower leaves the start at the preload quality (the owner's rule, 2026-10-22).
    func testAColdStartWhoseEstimatePicksAtMost480StartsAtThePreloadLevel() {
        let h = ControllerHarness(priorEstimate: 700_000.0)
        h.setPlaylists()
        h.controller.start()

        XCTAssertEqual(h.environment.loads.first?.level, 2)
        XCTAssertTrue(h.logLines.contains("start level=720 reason=preload position=0.0"), "\(h.logLines)")
        h.assertInvariants()
    }

    func testTheEstimatesStartKeepsTheCap() {
        let h = ControllerHarness(priorEstimate: 20_000_000.0)
        h.controller.setCap(2)
        h.setPlaylists()
        h.controller.start()

        XCTAssertEqual(h.environment.loads.first?.level, 2)
        h.assertInvariants()
    }

    func testACachedOpeningWinsOverTheEstimatesStart() {
        let h = ControllerHarness(priorEstimate: 20_000_000.0)
        h.cache(level: 1, seconds: 5.0)
        h.setPlaylists()
        h.controller.start()

        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 1, index: 0))
        h.assertInvariants()
    }

    // The first video of a session on a fast network: the node seeds the class from the account's other downloads, and
    // the start takes the level that estimate picks (D12).
    func testASeededPriorStartsTheFirstVideoAtTheEstimatesLevel() {
        let store = HLSBandwidthStore()
        store.seedPrior(bitsPerSecond: 20_000_000.0, networkClass: HLSNetworkClass("wifi"))
        let h = ControllerHarness(store: store, networkClass: HLSNetworkClass("wifi"))
        h.setPlaylists()
        h.controller.start()

        XCTAssertEqual(h.environment.loads.first?.level, 3)
        XCTAssertTrue(h.logLines.contains("start level=1080 reason=estimate position=0.0"), "\(h.logLines)")
        h.assertInvariants()
    }
}
