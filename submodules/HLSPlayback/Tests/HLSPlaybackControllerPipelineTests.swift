import Foundation
import XCTest
@testable import HLSPlayback

// Two segment loads in flight (D13): the next starts once everything the current one still owes fits in the download
// path's window, or when the current one is appending, so the link does not idle between segments. Not before the first
// part is appended and the class has an estimate: until then the next level is not the link's to choose.
final class HLSPlaybackControllerPipelineTests: XCTestCase {
    private func segmentStart(_ h: ControllerHarness, _ load: SimulatedEnvironment.LoadRecord) -> Double? {
        return h.playlists[load.level].segments.first(where: { $0.byteRange.upperBound == load.range.upperBound })?.start
    }

    func testTheNextLoadStartsWhenTheRestOfTheCurrentIsInFlight() {
        let h = ControllerHarness(configuration: HLSPlaybackController.Configuration())
        h.environment.bandwidth = 4_000_000.0
        h.environment.progressChunk = 131_072
        h.setPlaylists()
        h.controller.setManualLevel(3)
        h.controller.start()
        h.environment.advance(by: 10.0)

        // The opening loads alone; segments 1 and 2 overlap.
        let loads = h.segmentLoads.filter { $0.level == 3 }
        XCTAssertGreaterThanOrEqual(loads.count, 3)
        XCTAssertGreaterThanOrEqual(loads[1].startTime, loads[0].completionTime)
        let first = loads[1]
        let second = loads[2]
        XCTAssertLessThan(second.startTime, first.completionTime)
        // Not before the first owed at most 786 432 bytes.
        let owedAtStart = Double(Int64(first.range.count) - 786_432)
        XCTAssertGreaterThanOrEqual(second.startTime, first.startTime + h.environment.latency + owedAtStart * 8.0 / 4_000_000.0 - 1e-9)
        h.assertInvariants()
    }

    func testNoMoreThanTwoSegmentLoadsAreInFlight() {
        let h = ControllerHarness(configuration: HLSPlaybackController.Configuration())
        h.environment.bandwidth = 2_000_000.0
        h.environment.progressChunk = 131_072
        h.setPlaylists()
        h.controller.updatePlayback(position: 0.0, isPlaying: true, rate: 1.0)
        h.controller.start()
        h.play(to: 60.0, step: 0.1)

        let loads = h.segmentLoads
        for load in loads {
            let open = loads.filter { $0.startTime <= load.startTime && ($0.endTime ?? .infinity) > load.startTime }
            XCTAssertLessThanOrEqual(open.count, 2, "at \(load.startTime)")
        }
        XCTAssertTrue(loads.contains(where: { load in loads.contains(where: { $0.startTime < load.startTime && ($0.endTime ?? .infinity) > load.startTime }) }), "no two loads ever overlapped")
        h.assertInvariants()
    }

    func testTheNextLoadStartsWhileThePartIsAppended() {
        let h = ControllerHarness(configuration: HLSPlaybackController.Configuration())
        h.environment.appendDelay = 0.2
        h.setPlaylists()
        h.controller.setManualLevel(3)
        h.controller.start()
        h.environment.advance(by: 3.0)

        // After the opening, segment 2 starts as segment 1's load completes, while its part is made.
        let loads = h.segmentLoads.filter { $0.level == 3 }
        XCTAssertGreaterThanOrEqual(loads.count, 3)
        XCTAssertEqual(loads[2].startTime, loads[1].completionTime, accuracy: 1e-9)
        h.assertInvariants()
    }

    // Segment 2 is on disk but for its last 1000 bytes, so its load ends long before segment 1's: it is appended first,
    // segment 1 after it, and the buffer is one run.
    func testASecondLoadThatFinishesFirstIsAppendedAndTheBufferJoins() {
        let h = ControllerHarness(configuration: HLSPlaybackController.Configuration(), priorEstimate: 10_000_000.0)
        let segments = h.playlists[2].segments
        h.cache(level: 2, seconds: 5.0)
        h.environment.markOnDisk(level: 2, range: segments[2].byteRange.lowerBound ..< (segments[2].byteRange.upperBound - 1000))
        h.setPlaylists()
        h.controller.setManualLevel(2)
        h.controller.start()
        h.environment.advance(by: 1.0)

        XCTAssertEqual(Array(h.appendedKeys.prefix(3)), [HLSSegmentKey(level: 2, index: 0), HLSSegmentKey(level: 2, index: 2), HLSSegmentKey(level: 2, index: 1)])
        var model = HLSBufferModel()
        for part in h.buffered {
            model.insert(part)
        }
        let ranges = model.bufferedRanges
        XCTAssertEqual(ranges.first?.lowerBound ?? -1.0, 0.0, accuracy: 1e-9)
        XCTAssertGreaterThanOrEqual(ranges.first?.upperBound ?? 0.0, 15.0 - 1e-9)
        h.assertInvariants()
    }

    func testAnAbandonCancelsBothLoads() {
        var configuration = HLSPlaybackController.Configuration()
        configuration.pipelineWindowBytes = 2_000_000
        let h = ControllerHarness(configuration: configuration)
        h.environment.bandwidth = 20_000_000.0
        h.environment.bandwidthForLevel = [3: 300_000.0]
        h.environment.progressChunk = 65_536
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 0.4)
        XCTAssertEqual(h.segmentLoads.filter({ $0.level == 3 && !$0.completed }).count, 2)
        h.play(to: 3.5, step: 0.1)

        XCTAssertTrue(h.logLines.contains(where: { $0.hasPrefix("abandon level=1080") }))
        // The two 1080p loads in flight at the abandon both go, and the next load is lower.
        let topLoads = h.segmentLoads.filter { $0.level == 3 }
        XCTAssertTrue(topLoads[0].cancelled)
        XCTAssertTrue(topLoads[1].cancelled)
        let abandonTime = topLoads[0].endTime ?? .infinity
        XCTAssertEqual(topLoads[1].endTime ?? -1.0, abandonTime, accuracy: 1e-9)
        XCTAssertLessThan(h.segmentLoads.first(where: { $0.startTime >= abandonTime - 1e-9 })?.level ?? 3, 3)
        h.assertInvariants()
    }

    func testAManualLevelCancelsBothLoads() {
        var configuration = HLSPlaybackController.Configuration()
        configuration.pipelineWindowBytes = 2_000_000
        let h = ControllerHarness(configuration: configuration, priorEstimate: 1_000_000.0)
        h.environment.bandwidth = 1_000_000.0
        h.cache(level: 3, seconds: 5.0)
        h.setPlaylists()
        h.controller.setManualLevel(3)
        h.controller.start()
        h.environment.advance(by: 0.5)
        XCTAssertEqual(h.segmentLoads.filter({ !$0.completed }).count, 2)
        h.controller.setManualLevel(1)

        for load in h.segmentLoads where load.level == 3 {
            XCTAssertTrue(load.cancelled)
        }
        XCTAssertEqual(h.segmentLoads.last?.level, 1)
        h.assertInvariants()
    }

    // Level 2 cached for [0, 20 s); segments 4 ([20, 25 s)) and 5 ([25, 30 s)) loading together at 4 Mbit/s.
    private func cachedOpeningWithTwoLoadsInFlight() -> ControllerHarness {
        let h = ControllerHarness(configuration: HLSPlaybackController.Configuration(), priorEstimate: 4_000_000.0)
        h.environment.bandwidth = 4_000_000.0
        h.cache(level: 2, seconds: 20.0)
        h.setPlaylists()
        h.controller.setManualLevel(2)
        h.controller.start()
        XCTAssertEqual(h.appendedKeys.count, 4)
        XCTAssertEqual(h.segmentLoads.map(\.range), [h.playlists[2].segments[4].byteRange, h.playlists[2].segments[5].byteRange])
        return h
    }

    func testASeekPastBothLoadsCancelsBoth() {
        let h = self.cachedOpeningWithTwoLoadsInFlight()
        h.environment.advance(by: 0.1)
        h.controller.seek(to: 62.0)

        XCTAssertTrue(h.segmentLoads[0].cancelled)
        XCTAssertTrue(h.segmentLoads[1].cancelled)
        XCTAssertEqual(h.segmentLoads[2].range, h.playlists[2].segments[12].byteRange)
        h.assertInvariants()
    }

    func testASeekIntoTheSecondLoadKeepsIt() {
        let h = self.cachedOpeningWithTwoLoadsInFlight()
        h.environment.advance(by: 0.1)
        h.controller.seek(to: 26.0)

        XCTAssertTrue(h.segmentLoads[0].cancelled)
        XCTAssertFalse(h.segmentLoads[1].cancelled)
        h.environment.advance(by: 3.0)
        XCTAssertTrue(h.appendedKeys.contains(HLSSegmentKey(level: 2, index: 5)))
        h.assertInvariants()
    }

    func testAFailedSecondLoadRetriesWithoutCancellingTheFirst() {
        let h = ControllerHarness(configuration: HLSPlaybackController.Configuration(), priorEstimate: 4_000_000.0)
        h.environment.bandwidth = 4_000_000.0
        h.cache(level: 2, seconds: 20.0)
        let fifth = h.playlists[2].segments[5].byteRange
        h.environment.failingLoads = 1
        h.environment.failingLoadFilter = { level, range in
            return level == 2 && range == fifth
        }
        h.setPlaylists()
        h.controller.setManualLevel(2)
        h.controller.start()
        h.environment.advance(by: 0.5)

        XCTAssertTrue(h.segmentLoads[1].failed)
        XCTAssertFalse(h.segmentLoads[0].cancelled)
        h.environment.advance(by: 5.0)
        XCTAssertTrue(h.segmentLoads[0].completed)
        XCTAssertTrue(h.segmentLoads.dropFirst(2).contains(where: { $0.range == fifth && $0.completed }))
        h.environment.assertInvariants()
    }

    func testPipeliningRespectsMaxBufferAhead() {
        var configuration = HLSPlaybackController.Configuration()
        configuration.maxBufferAhead = 20.0
        let h = ControllerHarness(configuration: configuration)
        h.environment.bandwidth = 50_000_000.0
        h.environment.progressChunk = 131_072
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 10.0)

        for load in h.segmentLoads {
            XCTAssertLessThan(self.segmentStart(h, load) ?? 0.0, 20.0)
        }
        h.assertInvariants()
    }
    
    // A manual switch while a part is being made: that part is flushed once it lands, so it does not count as buffered,
    // and the new level loads from the playhead.
    func testAManualSwitchDuringAnAppendLoadsFromThePlayhead() {
        let h = ControllerHarness(configuration: HLSPlaybackController.Configuration())
        h.environment.appendDelay = 0.5
        h.cache(level: 2, seconds: 20.0)
        h.setPlaylists()
        h.controller.start()
        XCTAssertEqual(h.environment.appends.count, 1)
        h.controller.setManualLevel(3)
        h.environment.advance(by: 0.6)
        
        XCTAssertTrue(h.environment.removedKeys.contains(HLSSegmentKey(level: 2, index: 0)))
        XCTAssertEqual(h.segmentLoads.first(where: { $0.level == 3 })?.range.lowerBound, 0)
        h.assertInvariants()
    }
    
    // hls.js's switch hysteresis (up at 0.7 of the estimate, stay at 0.95) must be judged against the level last chosen.
    // Judged against the last appended part, two segments back with two loads in flight, one dip under the stay threshold
    // set the picks alternating 480/720 for good (seen on the simulator under 3g, 2026-10-22).
    func testPipelinedPicksDoNotAlternateBetweenTwoLevels() {
        // The simulator's video (480p 0.53, 720p 0.87, 1080p 1.12 Mbit/s) on a link that keeps the estimate between
        // 720p's stay threshold (0.87 / 0.95 = 0.92 Mbit/s) and its up-switch threshold (0.87 / 0.7 = 1.24 Mbit/s).
        let levels = [
            HLSLevel(key: 480, width: 854, height: 480, bandwidth: 530_000),
            HLSLevel(key: 720, width: 1280, height: 720, bandwidth: 870_000),
            HLSLevel(key: 1080, width: 1920, height: 1080, bandwidth: 1_120_000)
        ]
        let h = ControllerHarness(levels: levels, seconds: 180.0, preloadLevel: 1, configuration: HLSPlaybackController.Configuration(), priorEstimate: 1_000_000.0)
        // A dip from 30 s to 36 s pushes the estimate under the stay threshold once.
        h.environment.link = SimulatedLink(steps: [
            SimulatedLink.Step(start: 0.0, bitsPerSecond: 1_100_000.0),
            SimulatedLink.Step(start: 30.0, bitsPerSecond: 400_000.0),
            SimulatedLink.Step(start: 36.0, bitsPerSecond: 1_100_000.0)
        ], roundTrip: 0.3)
        h.environment.appendDelay = 0.05
        h.cache(level: 1, seconds: 5.0)
        h.setPlaylists()
        h.controller.updatePlayback(position: 0.0, isPlaying: true, rate: 1.0)
        h.controller.start()
        h.play(to: 90.0, step: 0.25)
        
        let picked = h.segmentLoads.filter({ !$0.cancelled }).map(\.level)
        var reversals = 0
        if picked.count >= 3 {
            for i in 2 ..< picked.count where picked[i] == picked[i - 2] && picked[i] != picked[i - 1] {
                reversals += 1
            }
        }
        XCTAssertEqual(reversals, 0, "\(picked)")
        h.assertInvariants()
    }

    // MARK: The buffer end with loads in flight

    // Level 2 cached for [0, 20 s): segments 4 and 5 load together at 1.5 Mbit/s and segment 4 fails. The retry loads
    // segment 4, the hole in the playhead's run, not the segments after the pending segment 5.
    func testAFailedFirstLoadIsRetriedBeforeTheSegmentsAfterIt() {
        let h = ControllerHarness(configuration: HLSPlaybackController.Configuration(), priorEstimate: 1_500_000.0)
        h.environment.bandwidth = 1_500_000.0
        h.cache(level: 2, seconds: 20.0)
        let fourth = h.playlists[2].segments[4].byteRange
        h.environment.failingLoads = 1
        h.environment.failingLoadFilter = { level, range in
            return level == 2 && range == fourth
        }
        h.setPlaylists()
        h.controller.setManualLevel(2)
        h.controller.start()
        XCTAssertEqual(h.segmentLoads.map(\.range), [fourth, h.playlists[2].segments[5].byteRange])
        h.environment.advance(by: 3.0)

        XCTAssertTrue(h.segmentLoads[0].failed)
        XCTAssertEqual(h.segmentLoads.dropFirst(2).first?.range, fourth)
        h.assertInvariants()
    }

    // Segment 4's part fails to be made while segment 5 is still loading behind it on the shared link: segment 4 is made
    // again after the retry delay, before anything after segment 5 is loaded.
    func testAFailedAppendIsRetriedBeforeTheSegmentsAfterIt() {
        let h = ControllerHarness(configuration: HLSPlaybackController.Configuration(), priorEstimate: 1_500_000.0)
        h.environment.link = SimulatedLink(bitsPerSecond: 1_500_000.0, roundTrip: 0.05)
        h.cache(level: 2, seconds: 20.0)
        h.setPlaylists()
        h.controller.setManualLevel(2)
        h.controller.start()
        XCTAssertEqual(h.appendedKeys.count, 4)
        h.environment.failingAppends = 1
        // Segment 4 lands at ~4.1 s and fails; segment 5 is still loading at the retry, ~5.1 s. Segment 6 may load only
        // once segment 4 is back in the buffer.
        let fourth = HLSSegmentKey(level: 2, index: 4)
        let sixth = h.playlists[2].segments[6].byteRange
        let checkLoad = h.environment.onLoad
        var fourthBufferedAtSixth: Bool?
        h.environment.onLoad = { [unowned h] level, range in
            checkLoad?(level, range)
            if level == 2 && range == sixth {
                fourthBufferedAtSixth = h.buffered.contains(where: { $0.key == fourth })
            }
        }
        h.environment.advance(by: 6.0)

        XCTAssertEqual(h.appendedKeys.filter({ $0 == fourth }).count, 2)
        XCTAssertTrue(h.buffered.contains(where: { $0.key == fourth }))
        XCTAssertNotEqual(fourthBufferedAtSixth, false)
        h.assertInvariants()
    }

    // Seeking back to an unbuffered position before a nearly done load keeps that load (hls.js's onMediaSeeking) and
    // loads at the playhead, not after the kept load.
    func testASeekBackBeforeAKeptLoadLoadsAtThePlayhead() {
        let h = ControllerHarness(configuration: HLSPlaybackController.Configuration(), priorEstimate: 4_000_000.0)
        h.environment.bandwidth = 4_000_000.0
        h.environment.progressChunk = 65_536
        h.environment.markOnDisk(level: 2, range: h.playlists[2].initSegment)
        h.environment.markOnDisk(level: 2, range: h.playlists[2].segments[8].byteRange)
        h.environment.markOnDisk(level: 2, range: h.playlists[2].segments[9].byteRange)
        h.controller.seek(to: 40.0)
        h.setPlaylists()
        h.controller.setManualLevel(2)
        h.controller.start()
        let tenth = h.playlists[2].segments[10].byteRange
        XCTAssertEqual(h.segmentLoads.first?.range, tenth)
        // 11 of segment 10's chunks are in: 29,104 bytes left, within 0.15 s at 4 Mbit/s.
        h.environment.advance(by: 0.05 + 11.0 * 65_536.0 * 8.0 / 4_000_000.0 + 0.001)
        let seekTime = h.environment.now
        h.controller.seek(to: 20.0)
        // Both loads in flight are nearly done and kept; the next load starts as they land.
        h.environment.advance(by: 0.2)

        XCTAssertFalse(h.segmentLoads[0].cancelled)
        XCTAssertEqual(h.segmentLoads.first(where: { $0.startTime >= seekTime - 1e-9 && !$0.cancelled && $0.range != tenth })?.range, h.playlists[2].segments[4].byteRange)
        h.assertInvariants()
    }

    // An abandon with parts behind the abandoned load (segment 2 being made, segment 3's bytes in): the forced level
    // fills the abandoned segment 1, not what follows those parts, and segment 3 is made from its 1080p bytes on disk
    // rather than fetched again at another level.
    func testAnAbandonFillsTheAbandonedSegmentAndFetchesNothingAgain() {
        var configuration = HLSPlaybackController.Configuration()
        configuration.pipelineWindowBytes = 2_000_000
        let h = ControllerHarness(configuration: configuration, priorEstimate: 20_000_000.0)
        h.environment.bandwidth = 20_000_000.0
        h.environment.bandwidthForLevel = [3: 300_000.0]
        h.environment.progressChunk = 65_536
        h.environment.appendDelay = 3.0
        h.cache(level: 2, seconds: 5.0)
        // Level 3's segments 2 and 3 are on disk but for their last 1000 bytes: their loads end at once.
        let top = h.playlists[3]
        h.environment.markOnDisk(level: 3, range: top.initSegment)
        for index in [2, 3] {
            h.environment.markOnDisk(level: 3, range: top.segments[index].byteRange.lowerBound ..< (top.segments[index].byteRange.upperBound - 1000))
        }
        h.setPlaylists()
        h.controller.updatePlayback(position: 0.0, isPlaying: true, rate: 1.0)
        h.controller.start()
        h.play(to: 6.5, step: 0.1)

        XCTAssertTrue(h.logLines.contains(where: { $0.hasPrefix("abandon level=1080 index=1") }), "\(h.logLines)")
        // The forced level loads the abandoned segment 1, not what follows the parts already in.
        let abandonTime = h.segmentLoads.first(where: { $0.level == 3 && $0.cancelled })?.endTime ?? .infinity
        XCTAssertEqual(h.segmentLoads.first(where: { $0.startTime >= abandonTime - 1e-9 && !$0.cancelled })?.range, h.playlists[0].segments[1].byteRange)
        h.play(to: 12.0, step: 0.1)
        // Segment 3's 1080p bytes were in: that part is made, and segment 3 is not fetched at another level.
        XCTAssertTrue(h.appendedKeys.contains(HLSSegmentKey(level: 3, index: 3)))
        XCTAssertFalse(h.segmentLoads.contains(where: { $0.level != 3 && $0.range == h.playlists[$0.level].segments[3].byteRange }))
        h.assertInvariants()
    }
}
