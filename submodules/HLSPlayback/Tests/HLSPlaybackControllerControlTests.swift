import XCTest
@testable import HLSPlayback

final class HLSPlaybackControllerControlTests: XCTestCase {
    // Level 2 cached for [0, 20 s); the next segment (4, [20, 25 s)) loading at 4 Mbit/s.
    private func cachedOpeningWithLoadInFlight(progressChunk: Int64? = nil) -> ControllerHarness {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.environment.progressChunk = progressChunk
        h.cache(level: 2, seconds: 20.0)
        h.setPlaylists()
        h.controller.start()
        XCTAssertEqual(h.appendedKeys.count, 4)
        XCTAssertEqual(h.segmentLoads.last?.range, h.playlists[2].segments[4].byteRange)
        return h
    }
    
    func testSeekInsideBufferKeepsLoadAndParts() {
        let h = self.cachedOpeningWithLoadInFlight()
        h.environment.advance(by: 0.1)
        h.controller.seek(to: 7.0)
        
        XCTAssertEqual(h.segmentLoads.count, 1)
        XCTAssertFalse(h.segmentLoads[0].cancelled)
        XCTAssertEqual(h.buffered.count, 4)
        h.environment.advance(by: 2.0)
        XCTAssertEqual(h.appendedKeys[4], HLSSegmentKey(level: 2, index: 4))
        h.assertInvariants()
    }
    
    func testSeekOutsideBufferCancelsLoadAndLoadsAtTarget() {
        let h = self.cachedOpeningWithLoadInFlight()
        h.environment.advance(by: 0.1)
        h.controller.seek(to: 62.0)
        
        XCTAssertTrue(h.segmentLoads[0].cancelled)
        XCTAssertEqual(h.segmentLoads.last?.range, h.playlists[2].segments[12].byteRange)
        XCTAssertEqual(h.buffered.count, 4)
        h.environment.advance(by: 2.0)
        XCTAssertEqual(h.appendedKeys.last, HLSSegmentKey(level: 2, index: 12))
        h.assertInvariants()
    }
    
    // A seek back before a load that is nearly done lets it finish: 720,896 of 750,000 bytes are in after 1.5 s, and
    // the rest arrives within 0.15 s at the 1.65 Mbit/s default (D7: bytes * 8 over bits per second).
    func testSeekBackKeepsNearlyDownloadedLoad() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.environment.progressChunk = 65_536
        h.controller.seek(to: 32.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 1.5)
        h.controller.seek(to: 10.0)
        
        XCTAssertFalse(h.segmentLoads[0].cancelled)
        h.environment.advance(by: 0.1)
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 6))
        // Then [10, 15 s), at whatever level the new sample allows.
        if let last = h.segmentLoads.last {
            XCTAssertEqual(last.range, h.playlists[last.level].segments[2].byteRange)
        }
        h.assertInvariants()
    }
    
    // Not nearly done: the same seek back cancels it.
    func testSeekBackCancelsALoadThatIsNotNearlyDone() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.environment.progressChunk = 65_536
        h.controller.seek(to: 32.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 0.5)
        h.controller.seek(to: 10.0)
        
        XCTAssertTrue(h.segmentLoads[0].cancelled)
        XCTAssertEqual(h.segmentLoads.last?.range, h.playlists[2].segments[2].byteRange)
        h.assertInvariants()
    }
    
    // D7's units: 160,176 bytes left at the 1.65 Mbit/s default take 0.78 s, so the load is not nearly done (0.097 s
    // if the bytes were read as bits).
    func testSeekBackCancelsALoadWithAFifthLeft() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.environment.progressChunk = 65_536
        h.controller.seek(to: 32.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 1.25)
        XCTAssertEqual(h.segmentLoads[0].networkBytes, 589_824)
        h.controller.seek(to: 10.0)
        
        XCTAssertTrue(h.segmentLoads[0].cancelled)
        XCTAssertEqual(h.segmentLoads.last?.range, h.playlists[2].segments[2].byteRange)
        h.assertInvariants()
    }
    
    func testSeekToSegmentBoundaryLoadsTheSegmentStartingThere() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.controller.seek(to: 30.0)
        
        XCTAssertTrue(h.segmentLoads[0].cancelled)
        XCTAssertEqual(h.segmentLoads.last?.range, h.playlists[2].segments[6].byteRange)
        h.environment.advance(by: 3.0)
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 6))
        h.assertInvariants()
    }
    
    func testSeekToDurationEndsWithoutLoading() {
        let h = ControllerHarness(seconds: 30.0)
        h.environment.bandwidth = 4_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.controller.seek(to: 30.0)
        h.environment.advance(by: 10.0)
        
        XCTAssertEqual(h.environment.loads.count, 1)
        XCTAssertTrue(h.environment.loads[0].cancelled)
        XCTAssertTrue(h.appendedKeys.isEmpty)
        h.assertInvariants()
    }
    
    // m6: a seek into the last `maxHole` of the stream, short of the player's end tolerance, still loads the last
    // segment.
    func testSeekIntoTheLastFractionOfASecondLoadsTheLastSegment() {
        let h = ControllerHarness(seconds: 30.0)
        h.environment.bandwidth = 4_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.controller.seek(to: 29.85)
        h.environment.advance(by: 3.0)
        
        XCTAssertEqual(h.appendedKeys, [HLSSegmentKey(level: 2, index: 5)])
        h.environment.advance(by: 10.0)
        XCTAssertEqual(h.appendedKeys.count, 1)
        h.assertInvariants()
    }
    
    // Until the first part lands, a seek judges the start again: a cached opening at the target wins.
    func testSeekBeforeTheFirstPartJudgesTheStartAgain() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.environment.markOnDisk(level: 3, range: h.playlists[3].initSegment)
        h.environment.markOnDisk(level: 3, range: h.playlists[3].segments[6].byteRange)
        h.setPlaylists()
        h.controller.start()
        XCTAssertEqual(h.controller.startLevel, 2)
        h.controller.seek(to: 32.0)
        
        XCTAssertTrue(h.segmentLoads[0].cancelled)
        XCTAssertEqual(h.controller.startLevel, 3)
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 3, index: 6))
        XCTAssertEqual(h.controller.firstSegmentSource, .disk)
        h.assertInvariants()
    }
    
    func testManualLevelFlushesForwardAndReloadsAtPlayhead() {
        let h = self.cachedOpeningWithLoadInFlight()
        h.controller.updatePlayback(position: 7.0, isPlaying: true, rate: 1.0)
        h.controller.setManualLevel(3)
        
        XCTAssertTrue(h.segmentLoads[0].cancelled)
        XCTAssertEqual(Set(h.environment.removedKeys), [HLSSegmentKey(level: 2, index: 1), HLSSegmentKey(level: 2, index: 2), HLSSegmentKey(level: 2, index: 3)])
        XCTAssertEqual(h.buffered.map(\.key), [HLSSegmentKey(level: 2, index: 0)])
        XCTAssertEqual(h.segmentLoads.last?.level, 3)
        XCTAssertEqual(h.segmentLoads.last?.range, h.playlists[3].segments[1].byteRange)
        h.assertInvariants()
    }
    
    func testChoosingAutoDoesNotFlush() {
        let h = self.cachedOpeningWithLoadInFlight()
        h.controller.updatePlayback(position: 7.0, isPlaying: true, rate: 1.0)
        h.controller.setManualLevel(3)
        let removed = h.environment.removedKeys.count
        let loads = h.environment.loads.count
        h.controller.setManualLevel(nil)
        
        XCTAssertEqual(h.environment.removedKeys.count, removed)
        XCTAssertEqual(h.environment.loads.count, loads)
        XCTAssertFalse(h.segmentLoads.last?.cancelled ?? true)
        h.assertInvariants()
    }
    
    func testLoweringCapDoesNotFlush() {
        let h = ControllerHarness()
        h.environment.bandwidth = 20_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 1.0)
        XCTAssertTrue(h.buffered.contains(where: { $0.key.level == 3 }))
        let buffered = h.buffered.count
        let inFlight = h.segmentLoads.last
        h.controller.setCap(1)
        
        XCTAssertTrue(h.environment.removedKeys.isEmpty)
        XCTAssertEqual(h.buffered.count, buffered)
        XCTAssertFalse(h.segmentLoads.last?.cancelled ?? true)
        XCTAssertEqual(h.segmentLoads.last?.range, inFlight?.range)
        h.environment.advance(by: 2.0)
        XCTAssertLessThanOrEqual(h.segmentLoads.last?.level ?? 99, 1)
        h.assertInvariants()
    }
    
    // Review Focus 5: the node moves from the bubble to the gallery mid-load.
    func testLiftingTheCapKeepsBufferAndInFlightLoad() {
        let h = ControllerHarness()
        h.environment.bandwidth = 20_000_000.0
        h.controller.setCap(2)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 0.1)
        let buffered = h.buffered.count
        let inFlight = h.segmentLoads.last
        h.controller.setCap(nil)
        
        XCTAssertEqual(h.buffered.count, buffered)
        XCTAssertFalse(h.segmentLoads.last?.cancelled ?? true)
        XCTAssertEqual(h.segmentLoads.last?.range, inFlight?.range)
        XCTAssertTrue(h.environment.removedKeys.isEmpty)
        h.environment.advance(by: 2.0)
        XCTAssertTrue(h.appendedKeys.contains(where: { $0.level == 3 }))
        h.assertInvariants()
    }
    
    // Review Focus 4: three changes within one load issue one load each, cancel the superseded ones, and loading
    // carries on.
    func testRapidManualToggleIssuesOneLoadPerChange() {
        let h = self.cachedOpeningWithLoadInFlight()
        let before = h.segmentLoads.count
        h.controller.setManualLevel(3)
        h.controller.setManualLevel(1)
        h.controller.setManualLevel(0)
        
        let issued = Array(h.segmentLoads.dropFirst(before))
        XCTAssertEqual(issued.map(\.level), [3, 1, 0])
        XCTAssertEqual(issued.map(\.cancelled), [true, true, false])
        h.environment.advance(by: 5.0)
        XCTAssertTrue(h.appendedKeys.contains(where: { $0.level == 0 }))
        XCTAssertGreaterThan(h.segmentLoads.count, before + 3)
        h.assertInvariants()
    }
    
    // Review Focus 1: switching between levels whose segment boundaries differ leaves no gap.
    func testAutoSwitchBetweenMisalignedLevelsLeavesNoGap() {
        let levels = TestStreams.fourLevels
        let long = Array(repeating: 5.005, count: 20)
        let short = Array(repeating: 4.83333, count: 21)
        let playlists = [
            TestStreams.playlist(level: levels[0], durations: long),
            TestStreams.playlist(level: levels[1], durations: long),
            TestStreams.playlist(level: levels[2], durations: short),
            TestStreams.playlist(level: levels[3], durations: short),
        ]
        let h = ControllerHarness(preloadLevel: 1, playlists: playlists)
        h.environment.bandwidth = 20_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 1.0)
        XCTAssertEqual(h.appendedKeys.first?.level, 1)
        XCTAssertTrue(h.appendedKeys.contains(where: { $0.level == 3 }))
        
        h.controller.setCap(1)
        h.play(to: 20.0)
        h.environment.advance(by: 2.0)
        
        XCTAssertTrue(h.appendedKeys.dropFirst(2).contains(where: { $0.level <= 1 }))
        XCTAssertEqual(HLSBufferModelTestsSupport.ranges(h.buffered).count, 1)
        XCTAssertEqual(Set(h.appendedKeys).count, h.appendedKeys.count)
        h.assertInvariants()
    }
    
    // A manual switch while a failed load waits for its retry loads at once, as hls.js's immediateLevelSwitch
    // aborts a fragment waiting to retry. Segment 4 fails four times; the fourth failure, at 7.2 s, waits 8 s.
    func testManualLevelDuringARetryWaitLoadsAtOnce() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.cache(level: 2, seconds: 20.0)
        let failingRange = h.playlists[2].segments[4].byteRange
        h.environment.failingLoads = 4
        h.environment.failingLoadFilter = { level, range in level == 2 && range == failingRange }
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 7.3)
        XCTAssertEqual(h.environment.loads.filter({ $0.failed }).count, 4)
        h.controller.updatePlayback(position: 7.3, isPlaying: true, rate: 1.0)
        h.controller.setManualLevel(3)
        
        XCTAssertEqual(h.segmentLoads.last?.level, 3)
        XCTAssertEqual(h.segmentLoads.last?.startTime ?? 0.0, 7.3, accuracy: 1e-6)
        h.assertInvariants()
    }
    
    // Manual 3, Auto, manual 3 again within one load: everything ahead is already at level 3, so the third change keeps
    // the load in flight instead of requesting the same bytes again.
    func testReturningToTheManualLevelThatIsLoadingKeepsTheLoad() {
        let h = self.cachedOpeningWithLoadInFlight()
        h.controller.updatePlayback(position: 7.0, isPlaying: true, rate: 1.0)
        h.controller.setManualLevel(3)
        let loads = h.segmentLoads.count
        XCTAssertEqual(h.segmentLoads.last?.level, 3)
        h.controller.setManualLevel(nil)
        h.controller.setManualLevel(3)
        
        XCTAssertEqual(h.segmentLoads.count, loads)
        XCTAssertFalse(h.segmentLoads.last?.cancelled ?? true)
        h.environment.advance(by: 3.0)
        XCTAssertTrue(h.appendedKeys.contains(HLSSegmentKey(level: 3, index: 1)))
        h.assertInvariants()
    }
    
    // A rejected level never gets a playlist: picking it in the quality menu plays the nearest level with one.
    func testManualPickOfARejectedLevelPlaysTheNearestPlayableLevel() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.controller.setPlaylistRejected(level: 3)
        h.setPlaylists(except: [3])
        h.controller.start()
        h.environment.advance(by: 1.0)
        h.controller.setManualLevel(3)
        h.environment.advance(by: 3.0)
        
        XCTAssertFalse(h.environment.loads.contains(where: { $0.level == 3 }))
        XCTAssertEqual(h.segmentLoads.last?.level, 2)
        XCTAssertGreaterThanOrEqual(h.segmentLoads.last?.startTime ?? 0.0, 1.0)
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("manual level=1080") && $0.contains("plays level=720") }))
        // The quality menu leaves it out.
        XCTAssertTrue(h.controller.isPlaylistRejected(level: 3))
        XCTAssertFalse(h.controller.isPlaylistRejected(level: 2))
        h.assertInvariants()
    }
    
    // A manual switch while a part is being probed flushes that part once it lands.
    func testManualSwitchDuringAppendFlushesAfterItLands() {
        let h = ControllerHarness()
        h.environment.appendDelay = 0.5
        h.cache(level: 2, seconds: 20.0)
        h.setPlaylists()
        h.controller.start()
        XCTAssertEqual(h.environment.appends.count, 1)
        h.controller.setManualLevel(3)
        h.environment.advance(by: 0.6)
        
        XCTAssertTrue(h.environment.removedKeys.contains(HLSSegmentKey(level: 2, index: 0)))
        XCTAssertFalse(h.buffered.contains(where: { $0.key.level == 2 }))
        XCTAssertEqual(h.segmentLoads.last?.level, 3)
        XCTAssertEqual(h.segmentLoads.last?.range.lowerBound, 0)
        h.assertInvariants()
    }
}

enum HLSBufferModelTestsSupport {
    static func ranges(_ parts: [HLSBufferedPart]) -> [Range<Double>] {
        var model = HLSBufferModel()
        for part in parts {
            model.insert(part)
        }
        return model.bufferedRanges
    }
}
