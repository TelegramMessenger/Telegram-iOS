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
            // Quality and data: the mean bitrate may not drop by more than 2%, and what a played second costs beyond its
            // own bitrate (refetches, abandoned loads) may not grow by more than 2%. Bytes alone would grow with any
            // better bitrate.
            XCTAssertGreaterThanOrEqual(result.meanBitrate, base.meanBitrate * 0.98, label)
            XCTAssertLessThanOrEqual(result.bytesPerPlayedSecond * 8.0 / result.meanBitrate, base.bytesPerPlayedSecond * 8.0 / base.meanBitrate * 1.02, label)
            guard let startTime = result.startTime, let baseStartTime = base.startTime else {
                XCTFail("\(label) never started")
                continue
            }
            XCTAssertLessThanOrEqual(startTime, baseStartTime + 0.05, label)
        }
    }

    // A cold open at a timestamp lands inside a segment, so its first part holds only what is left of it: 2 s and 1 s
    // here. On 3g the next part needs about 3.2 s, so a clock started at 1 s ahead stalled (2.25 s and 3.2 s); it now
    // waits for that part instead (deviation D14).
    func testAColdOpenNearASegmentsEndDoesNotStall() {
        for start in [18.0, 19.0] {
            let result = PlaybackLab(profile: LabProfiles.threeG, cache: .none, levels: LabStreams.testVideoLadder, preloadLevel: LabStreams.testVideoPreloadLevel, seconds: 300.0, startPosition: start).run(wallSeconds: 90.0)
            XCTAssertNotNil(result.startTime, "start \(start)")
            XCTAssertEqual(result.stallCount, 0, "start \(start)")
        }
    }

    // Where no stall is predicted the clock starts when it did before: an open at a segment's start, and one near its
    // end on a fast link.
    func testAnOpenThatWouldNotStallStartsAsBefore() {
        for (profile, start, startTime) in [(LabProfiles.threeG, 15.0, 3.30), (LabProfiles.lte, 15.0, 0.55), (LabProfiles.lte, 18.0, 0.55)] {
            let result = PlaybackLab(profile: profile, cache: .none, levels: LabStreams.testVideoLadder, preloadLevel: LabStreams.testVideoPreloadLevel, seconds: 300.0, startPosition: start).run(wallSeconds: 90.0)
            XCTAssertEqual(result.startTime ?? -1.0, startTime, accuracy: 0.051, "\(profile.name) start \(start)")
            XCTAssertEqual(result.stallCount, 0, "\(profile.name) start \(start)")
        }
    }
}
