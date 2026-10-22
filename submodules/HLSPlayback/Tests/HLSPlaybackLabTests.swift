import Foundation
import XCTest
@testable import HLSPlayback

// The playback lab: the controller over the shared link, with a player that plays only while a second is buffered.
// `testBaselineTable` prints the table (run with --test_output=all).
final class HLSPlaybackLabTests: XCTestCase {
    func testTheModelStartsWhenOneSecondIsBuffered() {
        let lab = PlaybackLab(profile: LabProfiles.wifi, cache: .none)
        let result = lab.run(wallSeconds: 30.0)
        guard let startTime = result.startTime, let firstPartTime = lab.firstPartTime else {
            XCTFail("never started")
            return
        }
        XCTAssertEqual(startTime, firstPartTime, accuracy: 0.06)
        XCTAssertEqual(result.stallCount, 0)
    }

    func testTheModelCountsAStall() {
        let drop = LabProfile(name: "drop", makeLink: {
            return SimulatedLink(steps: [
                SimulatedLink.Step(start: 0.0, bitsPerSecond: 10_000_000.0),
                SimulatedLink.Step(start: 20.0, bitsPerSecond: 50_000.0)
            ], roundTrip: 0.06)
        })
        let result = PlaybackLab(profile: drop, cache: .none).run(wallSeconds: 120.0)
        XCTAssertGreaterThanOrEqual(result.stallCount, 1)
        XCTAssertGreaterThan(result.stallTime, 0.0)
    }

    func testBaselineTable() {
        var results: [LabResult] = []
        for profile in LabProfiles.all {
            for cache in [LabCache.none, LabCache.preloadOpening(seconds: 10.0)] {
                let result = PlaybackLab(profile: profile, cache: cache).run()
                XCTAssertNotNil(result.startTime, "\(profile.name) \(cache) never started")
                results.append(result)
            }
        }
        print(labTable(results))
    }

    func testNoProfileIsWorseThanTheBaseline() {
        for base in LabBaseline.results {
            guard let profile = LabProfiles.all.first(where: { $0.name == base.profile }) else {
                XCTFail("no profile \(base.profile)")
                continue
            }
            let result = PlaybackLab(profile: profile, cache: base.cache).run()
            let label = "\(base.profile) \(base.cache)"
            XCTAssertLessThanOrEqual(result.stallCount, base.stallCount, label)
            XCTAssertLessThanOrEqual(result.stallTime, base.stallTime + 0.25, label)
            guard let startTime = result.startTime, let baseStartTime = base.startTime else {
                XCTFail("\(label) never started")
                continue
            }
            XCTAssertLessThanOrEqual(startTime, baseStartTime + 0.05, label)
        }
    }
}
