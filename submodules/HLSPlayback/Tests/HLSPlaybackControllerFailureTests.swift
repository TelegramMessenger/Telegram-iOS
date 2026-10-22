import XCTest
@testable import HLSPlayback

final class HLSPlaybackControllerFailureTests: XCTestCase {
    func testFailedLoadRetriesWithBackoff() {
        let h = ControllerHarness()
        h.environment.failingLoads = 5
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 30.0)
        
        // Each failure lands 0.05 s after its load starts; retries wait 1, 2, 4, 8, then 8 s.
        let starts = h.segmentLoads.prefix(6).map(\.startTime)
        let expected = [0.0, 1.05, 3.10, 7.15, 15.20, 23.25]
        XCTAssertEqual(starts.count, 6)
        for (start, value) in zip(starts, expected) {
            XCTAssertEqual(start, value, accuracy: 1e-6)
        }
        XCTAssertTrue(h.appendedKeys.contains(HLSSegmentKey(level: 2, index: 0)))
        h.assertInvariants()
    }
    
    func testRetryClockPausesWhileNetworkUnavailable() {
        let h = ControllerHarness()
        h.environment.failingLoads = 1
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 0.5)
        h.controller.setNetworkAvailable(false)
        h.environment.advance(by: 4.5)
        XCTAssertEqual(h.segmentLoads.count, 1)
        h.controller.setNetworkAvailable(true)
        h.environment.advance(by: 1.0)
        
        // 0.45 s of the 1 s delay ran before the network went away; the rest runs after it is back.
        XCTAssertEqual(h.segmentLoads.count, 2)
        XCTAssertEqual(h.segmentLoads[1].startTime, 5.55, accuracy: 1e-6)
        h.assertInvariants()
    }
    
    // After six failures a level is errored: the next pick takes a level cached at that position, at any level.
    // At 2 Mbit/s the target stays level 2 after the first sample; its second segment fails six times.
    func testLevelErroredAfterSixFailuresPrefersCachedLevel() {
        let h = ControllerHarness()
        h.environment.bandwidth = 2_000_000.0
        h.environment.markOnDisk(level: 0, range: h.playlists[0].initSegment)
        h.environment.markOnDisk(level: 0, range: h.playlists[0].segments[1].byteRange)
        let failingRange = h.playlists[2].segments[1].byteRange
        h.environment.failingLoads = 6
        h.environment.failingLoadFilter = { level, range in level == 2 && range == failingRange }
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 60.0)
        
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 0))
        XCTAssertEqual(h.environment.loads.filter({ $0.failed }).count, 6)
        XCTAssertEqual(h.appendedKeys.dropFirst().first, HLSSegmentKey(level: 0, index: 1))
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("errored") }))
        h.assertInvariants()
    }
    
    // A level's init that fails fails the segment waiting for it, with the same backoff.
    func testInitFailureIsRetriedLikeASegmentFailure() {
        let h = ControllerHarness()
        let initRange = h.playlists[2].initSegment
        h.environment.failingLoads = 1
        h.environment.failingLoadFilter = { level, range in level == 2 && range == initRange }
        h.controller.seek(to: 32.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 5.0)
        
        let initLoads = h.environment.loads.filter { $0.level == 2 && $0.range == initRange }
        XCTAssertEqual(initLoads.count, 2)
        XCTAssertGreaterThanOrEqual(initLoads[1].startTime, 1.05 - 1e-6)
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 6))
        h.assertInvariants()
    }
    
    // "Six failures in a row": a success in between starts the level's count again. Segments 1 and 2 of level 2 each
    // fail five times before loading.
    func testASuccessResetsTheLevelsFailureCount() {
        let h = ControllerHarness()
        h.environment.bandwidth = 2_000_000.0
        let failing = [h.playlists[2].segments[1].byteRange, h.playlists[2].segments[2].byteRange]
        var failures: [Range<Int64>: Int] = [:]
        h.environment.failingLoads = Int.max
        h.environment.failingLoadFilter = { level, range in
            guard level == 2, failing.contains(range) else {
                return false
            }
            let count = failures[range] ?? 0
            if count >= 5 {
                return false
            }
            failures[range] = count + 1
            return true
        }
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 80.0)
        
        XCTAssertEqual(h.environment.loads.filter({ $0.failed }).count, 10)
        XCTAssertFalse(h.logLines.contains(where: { $0.contains("errored") }))
        XCTAssertEqual(Array(h.appendedKeys.prefix(3)), [HLSSegmentKey(level: 2, index: 0), HLSSegmentKey(level: 2, index: 1), HLSSegmentKey(level: 2, index: 2)])
        h.assertInvariants()
    }
    
    // A network failure is never terminal: an errored level is avoided for a cool-down, never for good. Level 2 fails
    // from its second segment on, for ever: errored after six failures, tried again after 30 s of connected time,
    // errored again by its first failure there, and tried again after 60 s.
    func testAnErroredLevelIsTriedAgainAfterACooldownThatDoubles() {
        let h = ControllerHarness(seconds: 400.0)
        h.environment.bandwidth = 2_000_000.0
        let firstFailing = h.playlists[2].segments[1].byteRange.lowerBound
        h.environment.failingLoads = Int.max
        h.environment.failingLoadFilter = { level, range in level == 2 && range.lowerBound >= firstFailing }
        h.setPlaylists()
        h.controller.start()
        h.play(to: 200.0)
        
        // A failure lands 0.05 s after its load starts.
        let failed = h.environment.loads.filter({ $0.level == 2 && $0.failed }).map({ $0.startTime + 0.05 })
        XCTAssertGreaterThanOrEqual(failed.count, 8)
        if failed.count >= 8 {
            XCTAssertGreaterThanOrEqual(failed[6], failed[5] + 30.0)
            XCTAssertLessThan(failed[6], failed[5] + 40.0)
            XCTAssertGreaterThanOrEqual(failed[7], failed[6] + 60.0)
            XCTAssertLessThan(failed[7], failed[6] + 70.0)
        }
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("level 720 errored") }))
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("level 720 tried again") }))
        h.assertInvariants()
    }
    
    // The cool-down's clock runs only while the network is available.
    func testTheLevelCooldownStandsStillWhileTheNetworkIsUnavailable() {
        let h = ControllerHarness(seconds: 400.0)
        h.environment.bandwidth = 2_000_000.0
        let firstFailing = h.playlists[2].segments[1].byteRange.lowerBound
        h.environment.failingLoads = Int.max
        h.environment.failingLoadFilter = { level, range in level == 2 && range.lowerBound >= firstFailing }
        h.setPlaylists()
        h.controller.start()
        h.play(to: 30.0)
        h.controller.setNetworkAvailable(false)
        h.environment.advance(by: 100.0)
        h.controller.setNetworkAvailable(true)
        h.play(to: 100.0)
        
        let failed = h.environment.loads.filter({ $0.level == 2 && $0.failed }).map({ $0.startTime + 0.05 })
        XCTAssertGreaterThanOrEqual(failed.count, 7)
        if failed.count >= 7 {
            XCTAssertGreaterThanOrEqual(failed[6], failed[5] + 30.0 + 100.0)
        }
        h.assertInvariants()
    }
    
    // An errored level is avoided even where it is cached. The cached first segment's append fails six times.
    func testErroredLevelIsAvoidedEvenWhereCached() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.environment.failingAppends = 6
        h.cache(level: 2, seconds: 20.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 30.0)
        
        XCTAssertEqual(h.environment.appends.prefix(6).map(\.request.key), Array(repeating: HLSSegmentKey(level: 2, index: 0), count: 6))
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("errored") }))
        XCTAssertEqual(h.buffered.first?.key, HLSSegmentKey(level: 1, index: 0))
        XCTAssertFalse(h.appendedKeys.dropFirst(6).contains(where: { $0.level == 2 }))
        h.assertInvariants()
    }
    
    // A fetch waits for the server for as long as it takes: an init load that receives nothing is never issued again.
    // The segment is cached and only the init loads.
    func testASilentInitIsNeverIssuedAgain() {
        let h = ControllerHarness()
        h.environment.markOnDisk(level: 2, range: h.playlists[2].segments[6].byteRange)
        h.environment.stalledLoadIndices = [0]
        h.controller.seek(to: 32.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 600.0)
        
        let initLoads = h.environment.loads.filter { $0.level == 2 && $0.range == h.playlists[2].initSegment }
        XCTAssertEqual(initLoads.count, 1)
        XCTAssertFalse(initLoads.first?.cancelled ?? true)
        XCTAssertFalse(h.logLines.contains(where: { $0.contains("issuing again") }))
        h.assertInvariants()
    }
    
    // An init failure fails only a segment that waits for that init load. Segment 6 and the init load at once; a seek
    // back to 0 cancels segment 6 and loads segment 0 from byte 0, init included, before the old init load fails.
    func testAStaleInitFailureLeavesALoadThatCarriesItsOwnInit() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        let initRange = h.playlists[2].initSegment
        h.environment.failingLoads = 1
        h.environment.failingLoadFilter = { level, range in level == 2 && range == initRange }
        h.controller.seek(to: 32.0)
        h.setPlaylists()
        h.controller.start()
        h.controller.seek(to: 0.0)
        XCTAssertEqual(h.segmentLoads.last?.range.lowerBound, 0)
        h.environment.advance(by: 3.0)
        
        XCTAssertEqual(h.segmentLoads.filter({ $0.range.lowerBound == 0 }).count, 1)
        XCTAssertFalse(h.segmentLoads.last(where: { $0.range.lowerBound == 0 })?.cancelled ?? true)
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 0))
        XCTAssertFalse(h.logLines.contains(where: { $0.hasPrefix("failure ") }))
        h.assertInvariants()
    }
    
    func testFailedAppendRetries() {
        let h = ControllerHarness()
        h.environment.failingAppends = 1
        h.cache(level: 2, seconds: 5.0)
        h.setPlaylists()
        h.controller.start()
        XCTAssertEqual(h.environment.appends.count, 1)
        h.environment.advance(by: 0.5)
        XCTAssertEqual(h.environment.appends.count, 1)
        h.environment.advance(by: 1.0)
        
        XCTAssertEqual(h.environment.appends.count, 2)
        XCTAssertEqual(h.buffered.first?.key, HLSSegmentKey(level: 2, index: 0))
        h.assertInvariants()
    }
    
    // A fetch waits for the server for as long as it takes: a load that receives nothing is never issued again. Load 1
    // is the second segment's data.
    func testASilentLoadIsNeverIssuedAgain() {
        let h = ControllerHarness()
        h.environment.bandwidth = 20_000_000.0
        h.environment.stalledLoadIndices = [1]
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 0.4)
        XCTAssertEqual(h.appendedKeys.count, 1)
        let stalled = h.environment.loads[1]
        h.environment.advance(by: 600.0)
        
        let loads = h.segmentLoads.filter { $0.range == stalled.range }
        XCTAssertEqual(loads.count, 1)
        XCTAssertFalse(loads.first?.cancelled ?? true)
        XCTAssertFalse(h.logLines.contains(where: { $0.contains("issuing again") }))
        h.assertInvariants()
    }
    
    // MediaBox reports progress only as whole parts land. A slow but live load (750 KB at 300 kbit/s, 20.06 s with no
    // progress before it completes) completes, while playing too.
    func testSlowLoadOnAWeakLinkIsNotReissued() {
        let h = ControllerHarness()
        h.environment.bandwidth = 300_000.0
        h.controller.updatePlayback(position: 0.0, isPlaying: true, rate: 1.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 25.0)
        
        XCTAssertFalse(h.segmentLoads[0].cancelled)
        XCTAssertTrue(h.segmentLoads[0].completed)
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 0))
        h.assertInvariants()
    }
    
    // Level 3's link is slow; the load is abandoned once half a segment's time has passed and it cannot finish
    // before the buffer runs out. D6: the replacement is a lower level cached at that position.
    private func climbedToSlowTopLevel(cacheLevelOne: Bool) -> ControllerHarness {
        let h = ControllerHarness()
        h.environment.bandwidth = 20_000_000.0
        h.environment.bandwidthForLevel = [3: 300_000.0]
        h.environment.progressChunk = 65_536
        if cacheLevelOne {
            h.environment.markOnDisk(level: 1, range: h.playlists[1].initSegment)
            h.environment.markOnDisk(level: 1, range: h.playlists[1].segments[1].byteRange)
        }
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 0.4)
        XCTAssertEqual(h.appendedKeys, [HLSSegmentKey(level: 2, index: 0)])
        XCTAssertEqual(h.segmentLoads.last?.level, 3)
        return h
    }
    
    func testAbandonFallsBackToCachedLowerLevel() {
        let h = self.climbedToSlowTopLevel(cacheLevelOne: true)
        h.play(to: 3.5, step: 0.1)
        
        XCTAssertTrue(h.segmentLoads.first(where: { $0.level == 3 })?.cancelled ?? false)
        XCTAssertEqual(h.appendedKeys.dropFirst().first, HLSSegmentKey(level: 1, index: 1))
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("abandon") }))
        h.assertInvariants()
    }
    
    func testAbandonWithoutCacheUsesDecisionLevelAndResetsEstimate() {
        let h = self.climbedToSlowTopLevel(cacheLevelOne: false)
        // Level 0 is slow too, so its replacement load is still in flight (and unsampled) at 3.5 s.
        h.environment.bandwidthForLevel[0] = 300_000.0
        h.play(to: 3.5, step: 0.1)
        
        XCTAssertTrue(h.segmentLoads.first(where: { $0.level == 3 })?.cancelled ?? false)
        XCTAssertEqual(h.segmentLoads.last?.level, 0)
        XCTAssertEqual(h.segmentLoads.last?.range, h.playlists[0].segments[1].byteRange)
        XCTAssertEqual(h.controller.estimate, 290_000.0)
        // The next video does not start from the estimate the abandon proved wrong.
        XCTAssertEqual(h.store.estimator(for: .unknown)?.estimate, 290_000.0)
        h.assertInvariants()
    }
    
    // Choosing Auto while a manual load is in flight starts the abandon check for that load. Manual 3 reloads segment 0
    // at level 3 over its 300 kbit/s link; Auto then lets the abandon rule drop it.
    func testChoosingAutoMidLoadStartsTheAbandonCheck() {
        let h = self.climbedToSlowTopLevel(cacheLevelOne: false)
        h.environment.advance(by: 0.2)
        h.controller.setManualLevel(3)
        h.play(to: 1.0, step: 0.1)
        XCTAssertFalse(h.logLines.contains(where: { $0.contains("abandon") }))
        h.controller.setManualLevel(nil)
        h.play(to: 4.0, step: 0.1)
        
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("abandon level=1080") }))
        h.assertInvariants()
    }
    
    // The level an abandon forces is still kept off an errored level. Level 0 errors on six failed loads while manual;
    // back in Auto, level 3's slow load is abandoned towards level 0, and the replacement goes to level 1 instead.
    func testTheForcedLevelAfterAnAbandonAvoidsAnErroredLevel() {
        let h = ControllerHarness()
        h.environment.bandwidth = 20_000_000.0
        h.environment.bandwidthForLevel = [3: 300_000.0]
        h.environment.progressChunk = 65_536
        h.environment.failingLoads = 6
        h.environment.failingLoadFilter = { level, _ in level == 0 }
        h.controller.setManualLevel(0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 40.0)
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("level 360 errored") }))
        XCTAssertEqual(h.appendedKeys.first?.level, 0)
        h.controller.setManualLevel(nil)
        h.seek(to: 70.0)
        h.environment.advance(by: 0.2)
        XCTAssertEqual(h.segmentLoads.last?.level, 3)
        h.environment.bandwidthForLevel[0] = 300_000.0
        h.play(to: 73.5, step: 0.1)
        
        let abandon = h.logLines.first(where: { $0.contains("abandon level=1080") })
        XCTAssertNotNil(abandon)
        XCTAssertFalse(abandon?.contains("to level=360") ?? true)
        XCTAssertNotEqual(h.segmentLoads.last?.level, 0)
        h.assertInvariants()
    }
    
    // D6 asks whether a lower level is cached where loading continues: at the buffer end, as the scheduler does, not at
    // the abandoned segment's start. Level 3 uses 3 s segments, so its segment 1 starts at 3.0 while the buffer ends at
    // 5.0; level 1 (2 s segments) has [2, 4) cached but not [4, 6).
    func testAbandonLooksForACachedLevelAtTheBufferEnd() {
        let levels = TestStreams.fourLevels
        let playlists = [
            TestStreams.uniform(level: levels[0], seconds: 60.0),
            TestStreams.uniform(level: levels[1], seconds: 60.0, segmentDuration: 2.0),
            TestStreams.uniform(level: levels[2], seconds: 60.0),
            TestStreams.uniform(level: levels[3], seconds: 60.0, segmentDuration: 3.0),
        ]
        let h = ControllerHarness(playlists: playlists)
        h.environment.bandwidth = 20_000_000.0
        h.environment.bandwidthForLevel = [3: 300_000.0]
        h.environment.progressChunk = 65_536
        h.environment.markOnDisk(level: 1, range: playlists[1].initSegment)
        h.environment.markOnDisk(level: 1, range: playlists[1].segments[1].byteRange)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 0.4)
        XCTAssertEqual(h.segmentLoads.last?.level, 3)
        XCTAssertEqual(h.segmentLoads.last?.range, playlists[3].segments[1].byteRange)
        h.play(to: 3.5, step: 0.1)
        
        let abandon = h.logLines.first(where: { $0.contains("abandon level=1080") })
        XCTAssertNotNil(abandon)
        XCTAssertTrue(abandon?.contains("fromDisk=false") ?? false)
        h.assertInvariants()
    }
    
    // An abandon's level without a playlist becomes the nearest level with one. Level 0's playlist never arrives.
    func testAbandonToALevelWithoutAPlaylistTakesTheNearestWithOne() {
        let h = ControllerHarness()
        h.environment.bandwidth = 20_000_000.0
        h.environment.bandwidthForLevel = [3: 300_000.0, 1: 300_000.0]
        h.environment.progressChunk = 65_536
        h.controller.setPlaylistUnavailable(level: 0)
        h.setPlaylists(except: [0])
        h.controller.start()
        h.environment.advance(by: 0.4)
        XCTAssertEqual(h.segmentLoads.last?.level, 3)
        h.play(to: 3.5, step: 0.1)
        
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("abandon level=1080") && $0.contains("to level=480") }))
        XCTAssertEqual(h.segmentLoads.last?.level, 1)
        XCTAssertFalse(h.environment.loads.contains(where: { $0.level == 0 }))
        h.assertInvariants()
    }
    
    // After an abandon resets the estimate, the pick after the forced one uses it, not the higher prior the player
    // started with. The opening and level 1's replacement are on disk, so no network sample comes in between.
    func testThePickAfterTheForcedOneUsesTheResetEstimate() {
        let h = ControllerHarness(priorEstimate: 5_000_000.0)
        h.environment.bandwidth = 20_000_000.0
        h.environment.bandwidthForLevel = [3: 300_000.0]
        h.environment.progressChunk = 65_536
        h.cache(level: 2, seconds: 5.0)
        h.environment.markOnDisk(level: 1, range: h.playlists[1].initSegment)
        h.environment.markOnDisk(level: 1, range: h.playlists[1].segments[1].byteRange)
        h.setPlaylists()
        h.controller.start()
        XCTAssertEqual(h.appendedKeys, [HLSSegmentKey(level: 2, index: 0)])
        XCTAssertEqual(h.segmentLoads.last?.level, 3)
        h.play(to: 3.5, step: 0.1)
        
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("abandon level=1080") && $0.contains("fromDisk=true") }))
        XCTAssertTrue(h.appendedKeys.contains(HLSSegmentKey(level: 1, index: 1)))
        // The first network load after the abandoned one: segment 2, picked from the reset estimate.
        let next = h.segmentLoads.dropFirst().first
        XCTAssertEqual(next?.range, h.playlists[next?.level ?? 0].segments[2].byteRange)
        XCTAssertLessThanOrEqual(next?.level ?? 99, 1)
        h.assertInvariants()
    }
    
    // A failed append forgets that its level's init was loaded: if the cache was cleared meanwhile, the retry loads the
    // init again rather than appending a segment without one. Segment 0 loads with its init in one range; segment 1's
    // append then fails while the init leaves the disk.
    func testAFailedAppendWhoseInitLeftTheDiskLoadsTheInitAgain() {
        let h = ControllerHarness()
        h.environment.bandwidth = 2_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 3.5)
        XCTAssertEqual(h.appendedKeys, [HLSSegmentKey(level: 2, index: 0)])
        let initRange = h.playlists[2].initSegment
        h.environment.failingAppends = 1
        h.environment.advance(by: 3.5)
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("append failed level=720 index=1") }))
        h.environment.removeFromDisk(level: 2, range: initRange)
        h.environment.advance(by: 6.0)
        
        XCTAssertTrue(h.environment.loads.contains(where: { $0.level == 2 && $0.range == initRange }))
        XCTAssertTrue(h.appendedKeys.dropFirst().contains(where: { $0.level == 2 }))
        h.assertInvariants()
    }
    
    // Manual quality is never abandoned.
    func testNoAbandonInManualMode() {
        let h = self.climbedToSlowTopLevel(cacheLevelOne: true)
        h.controller.setManualLevel(3)
        h.play(to: 3.5, step: 0.1)
        XCTAssertFalse(h.logLines.contains(where: { $0.contains("abandon") }))
    }
}
