import XCTest
@testable import HLSPlayback

final class HLSPlaybackControllerStartTests: XCTestCase {
    func testColdStartLoadsInitAndFirstSegmentAsOneRangeAtPreloadLevel() {
        let h = ControllerHarness()
        h.setPlaylists()
        h.controller.start()
        
        XCTAssertEqual(h.controller.startLevel, 2)
        XCTAssertEqual(h.environment.loads.count, 1)
        let load = h.environment.loads[0]
        XCTAssertEqual(load.level, 2)
        XCTAssertEqual(load.range, 0 ..< h.playlists[2].segments[0].byteRange.upperBound)
        XCTAssertEqual(load.priority, .playback)
        
        h.environment.advance(by: 5.0)
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 0))
        // The part is the init and the segment only: the bytes between them (sidx) make FFmpeg report the whole
        // video's duration for a video-only file.
        XCTAssertEqual(h.environment.appends[0].request.initRange, h.playlists[2].initSegment)
        XCTAssertEqual(h.environment.appends[0].request.dataRange, h.playlists[2].segments[0].byteRange)
        XCTAssertFalse(h.environment.loads.contains(where: { $0.level == 2 && $0.range == h.playlists[2].initSegment }))
        XCTAssertEqual(h.controller.firstSegmentSource, .network)
        h.assertInvariants()
    }
    
    func testStartWaitsForThePreloadLevelsPlaylist() {
        let h = ControllerHarness()
        h.controller.start()
        h.controller.setPlaylist(h.playlists[0], level: 0)
        XCTAssertNil(h.controller.startLevel)
        XCTAssertTrue(h.environment.loads.isEmpty)
        h.controller.setPlaylist(h.playlists[1], level: 1)
        h.controller.setPlaylist(h.playlists[2], level: 2)
        h.controller.setPlaylist(h.playlists[3], level: 3)
        XCTAssertEqual(h.controller.startLevel, 2)
        XCTAssertEqual(h.environment.loads.count, 1)
        h.assertInvariants()
    }
    
    func testPreloadedStartPlaysFromDiskWithoutLoadsOrSamples() {
        let h = ControllerHarness()
        h.cache(level: 2, seconds: 10.0)
        h.setPlaylists()
        h.controller.start()
        
        XCTAssertEqual(h.controller.startLevel, 2)
        XCTAssertEqual(h.controller.firstSegmentSource, .disk)
        XCTAssertEqual(Array(h.appendedKeys.prefix(2)), [HLSSegmentKey(level: 2, index: 0), HLSSegmentKey(level: 2, index: 1)])
        XCTAssertNil(h.controller.estimate)
        // The first network load is the segment after the preloaded ones.
        XCTAssertEqual(h.environment.loads.count, 1)
        XCTAssertEqual(h.environment.loads[0].range, h.playlists[2].segments[2].byteRange)
        h.assertInvariants()
    }
    
    func testFirstNetworkFetchAfterDiskOpeningUsesPreloadLevel() {
        let h = ControllerHarness()
        h.cache(level: 3, seconds: 10.0)
        h.setPlaylists()
        h.controller.start()
        
        XCTAssertEqual(h.controller.startLevel, 3)
        XCTAssertEqual(Array(h.appendedKeys.prefix(2)), [HLSSegmentKey(level: 3, index: 0), HLSSegmentKey(level: 3, index: 1)])
        XCTAssertEqual(h.environment.loads.first?.level, 2)
        XCTAssertNil(h.controller.estimate)
        h.assertInvariants()
    }
    
    // The user's scenario: half-watched yesterday on Wi-Fi, reopened today on a weak connection.
    func testHalfCachedTopQualityOnWeakNetworkPlaysCacheThenDrops() {
        let h = ControllerHarness()
        h.environment.bandwidth = 300_000.0
        h.cache(level: 3, seconds: 30.0)
        h.setPlaylists()
        h.controller.start()
        
        let fromDisk = h.appendedKeys.prefix(6)
        XCTAssertEqual(fromDisk.map(\.level), Array(repeating: 3, count: 6))
        XCTAssertEqual(h.segmentLoads.count, 1)
        XCTAssertEqual(h.segmentLoads[0].level, 2)
        
        h.play(to: 25.0)
        XCTAssertGreaterThanOrEqual(h.segmentLoads.count, 2)
        XCTAssertEqual(h.segmentLoads[1].level, 0)
        h.assertInvariants()
    }
    
    func testFullyCachedTopQualityMakesNoNetworkLoads() {
        let h = ControllerHarness(seconds: 90.0)
        h.cacheAll(level: 3)
        h.setPlaylists()
        h.controller.start()
        h.play(to: 89.0, step: 1.0)
        
        XCTAssertTrue(h.environment.loads.isEmpty)
        XCTAssertEqual(Set(h.appendedKeys.map(\.level)), [3])
        XCTAssertEqual(h.appendedKeys.count, 18)
        XCTAssertNil(h.controller.estimate)
        h.assertInvariants()
    }
    
    func testFastNetworkClimbsAfterFirstSample() {
        let h = ControllerHarness()
        h.environment.bandwidth = 20_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 2.0)
        
        let networkLevels = h.segmentLoads.map(\.level)
        XCTAssertGreaterThanOrEqual(networkLevels.count, 2)
        XCTAssertEqual(networkLevels[0], 2)
        XCTAssertEqual(networkLevels[1], 3)
        h.assertInvariants()
    }
    
    func testStopsLoadingAtSixtySecondsAhead() {
        let h = ControllerHarness(seconds: 300.0)
        h.environment.bandwidth = 50_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 30.0)
        
        XCTAssertEqual(h.appendedKeys.count, 12)
        let end = h.buffered.map(\.end).max() ?? 0.0
        XCTAssertEqual(end, 60.0, accuracy: 1e-9)
        
        // Playing on makes room for one more segment at a time.
        h.play(to: 5.0)
        h.environment.advance(by: 2.0)
        XCTAssertEqual(h.appendedKeys.count, 13)
        h.assertInvariants()
    }
    
    func testEndOfStreamStopsLoading() {
        let h = ControllerHarness(seconds: 12.0)
        h.environment.bandwidth = 50_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 30.0)
        
        XCTAssertEqual(h.appendedKeys.count, 3)
        let loadCount = h.environment.loads.count
        h.play(to: 11.9)
        h.environment.advance(by: 30.0)
        XCTAssertEqual(h.environment.loads.count, loadCount)
        h.assertInvariants()
    }
    
    func testLevelWithoutPlaylistIsNeverLoaded() {
        let h = ControllerHarness(seconds: 300.0)
        h.environment.bandwidth = 50_000_000.0
        h.setPlaylists(except: [3])
        h.controller.setPlaylistUnavailable(level: 3)
        h.controller.start()
        h.play(to: 120.0, step: 1.0)
        
        XCTAssertFalse(h.environment.loads.contains(where: { $0.level == 3 }))
        XCTAssertTrue(h.environment.loads.contains(where: { $0.level == 2 }))
        h.assertInvariants()
    }
    
    func testBackBufferTrimmedAtSegmentBoundary() {
        let h = ControllerHarness(seconds: 300.0)
        h.environment.bandwidth = 50_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.play(to: 100.0)
        
        // floor(100 / 5) * 5 - 30 = 70.
        let removedEnds = h.environment.removedKeys.map { key in h.playlists[key.level].segments[key.index].end }
        XCTAssertFalse(removedEnds.isEmpty)
        XCTAssertTrue(removedEnds.allSatisfy { $0 <= 70.0 })
        XCTAssertEqual(h.buffered.map(\.start).min(), 70.0)
        XCTAssertEqual(Set(h.environment.removedKeys).count, h.environment.removedKeys.count)
        h.assertInvariants()
    }
    
    func testSamplesGoToTheStore() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.setPlaylists()
        XCTAssertNil(h.store.estimator(for: .unknown))
        h.controller.start()
        h.environment.advance(by: 5.0)
        
        XCTAssertNotNil(h.controller.estimate)
        XCTAssertEqual(h.store.estimator(for: .unknown)?.estimate, h.controller.estimate)
        h.assertInvariants()
    }
    
    func testANewPlayerStartsFromTheStoresEstimate() {
        let h = ControllerHarness(priorEstimate: 20_000_000.0)
        h.cache(level: 2, seconds: 5.0)
        h.setPlaylists()
        h.controller.start()
        
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 0))
        XCTAssertEqual(h.environment.loads.first?.level, 3)
        h.assertInvariants()
    }
    
    func testStartPositionFromSeekBeforeStart() {
        let h = ControllerHarness()
        h.controller.seek(to: 32.0)
        h.setPlaylists()
        h.controller.start()
        
        XCTAssertEqual(h.environment.loads.first?.range, h.playlists[2].segments[6].byteRange)
        h.environment.advance(by: 5.0)
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 6))
        XCTAssertEqual(h.environment.appends.first?.request.initRange, h.playlists[2].initSegment)
        h.assertInvariants()
    }
    
    // A part whose probed end falls just short of its nominal end must not make the next level reload the segment
    // that part already covers.
    func testProbedEndShortfallDoesNotReloadACoveredSegment() {
        let h = ControllerHarness()
        h.environment.bandwidth = 20_000_000.0
        h.environment.probedEndShortfall = 0.004
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 3.0)
        
        let appended = h.appendedKeys
        XCTAssertGreaterThanOrEqual(appended.count, 3)
        XCTAssertEqual(appended.map(\.index), Array(0 ..< appended.count))
        h.assertInvariants()
    }
    
    func testBufferChangesReportTheDuration() {
        var duration: Double?
        let h = ControllerHarness(seconds: 42.0)
        h.controller.onBufferChanged = { _, value in
            duration = value
        }
        h.cache(level: 2, seconds: 5.0)
        h.setPlaylists()
        h.controller.start()
        XCTAssertEqual(duration ?? 0.0, 42.0, accuracy: 1e-9)
        h.assertInvariants()
    }
    
    func testLevelAtPositionAndStartLog() {
        let h = ControllerHarness()
        h.cache(level: 3, seconds: 5.0)
        h.setPlaylists()
        h.controller.start()
        XCTAssertEqual(h.controller.level(at: 1.0), 3)
        XCTAssertNil(h.controller.level(at: 50.0))
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("start") && $0.contains("cached opening") }))
        h.assertInvariants()
    }
    
    func testNoCallbacksAfterStop() {
        let h = ControllerHarness()
        h.setPlaylists()
        h.controller.start()
        let updates = h.bufferUpdates.count
        h.controller.stop()
        XCTAssertTrue(h.environment.loads.allSatisfy { $0.cancelled || $0.completed })
        h.environment.advance(by: 10.0)
        XCTAssertEqual(h.bufferUpdates.count, updates)
        XCTAssertTrue(h.environment.appends.isEmpty)
        h.assertInvariants()
    }
    
    // The start is decided once every level's playlist is known, so a cached top quality whose playlist arrives
    // after the preload level's is not missed.
    func testStartWaitsForEveryPlaylistOrItsAbsence() {
        let h = ControllerHarness(seconds: 60.0)
        h.environment.bandwidth = 3_000_000.0
        h.cacheAll(level: 3)
        h.controller.start()
        for level in [2, 0, 1] {
            h.controller.setPlaylist(h.playlists[level], level: level)
        }
        XCTAssertNil(h.controller.startLevel)
        XCTAssertTrue(h.environment.loads.isEmpty)
        h.controller.setPlaylist(h.playlists[3], level: 3)
        
        XCTAssertEqual(h.controller.startLevel, 3)
        XCTAssertEqual(h.controller.firstSegmentSource, .disk)
        XCTAssertTrue(h.environment.loads.isEmpty)
        h.assertInvariants()
    }
    
    // A playlist that is not on disk is not waited for: a level without one cannot have a cached opening.
    func testUnavailablePlaylistDoesNotHoldTheStart() {
        let h = ControllerHarness()
        h.controller.start()
        for level in [2, 0, 1] {
            h.controller.setPlaylist(h.playlists[level], level: level)
        }
        h.controller.setPlaylistUnavailable(level: 3)
        XCTAssertEqual(h.controller.startLevel, 2)
        XCTAssertEqual(h.segmentLoads.count, 1)
        
        // It still arrives later and is used.
        h.environment.bandwidth = 50_000_000.0
        h.controller.setPlaylist(h.playlists[3], level: 3)
        h.environment.advance(by: 3.0)
        XCTAssertTrue(h.appendedKeys.contains(where: { $0.level == 3 }))
        h.assertInvariants()
    }
    
    // A playlist fetch that hangs (MediaBox rarely reports an error) must not hold the start forever: once another
    // level's playlist is in, the start waits `preloadPlaylistWait` (5 s) for the preload level's, then starts at the
    // nearest level with one.
    func testStartFallsBackWhenThePreloadPlaylistNeverArrives() {
        let h = ControllerHarness()
        h.controller.setPlaylistUnavailable(level: 2)
        h.setPlaylists(except: [2])
        h.controller.start()
        h.environment.advance(by: 4.9)
        XCTAssertTrue(h.environment.loads.isEmpty)
        h.environment.advance(by: 0.2)
        
        XCTAssertEqual(h.segmentLoads.first?.level, 1)
        XCTAssertTrue(h.logLines.contains(where: { $0.contains("without the preload playlist") }))
        h.environment.advance(by: 5.0)
        XCTAssertEqual(h.appendedKeys.first?.level, 1)
        h.assertInvariants()
    }
    
    // The wait is for a lost fetch, not a slow one: a preload playlist arriving within it starts there at once.
    func testStartTakesAPreloadPlaylistThatArrivesWithinTheWait() {
        let h = ControllerHarness()
        h.controller.setPlaylistUnavailable(level: 2)
        h.setPlaylists(except: [2])
        h.controller.start()
        h.environment.advance(by: 3.0)
        h.controller.setPlaylist(h.playlists[2], level: 2)
        
        XCTAssertEqual(h.segmentLoads.first?.level, 2)
        h.environment.advance(by: 5.0)
        XCTAssertFalse(h.logLines.contains(where: { $0.contains("without the preload playlist") }))
        XCTAssertEqual(h.segmentLoads.filter({ $0.range.lowerBound == 0 }).map(\.level), [2])
        h.assertInvariants()
    }
    
    // The wait runs only while connected.
    func testPreloadPlaylistWaitStandsStillWhileOffline() {
        let h = ControllerHarness()
        h.controller.setPlaylistUnavailable(level: 2)
        h.setPlaylists(except: [2])
        h.controller.start()
        h.environment.advance(by: 2.0)
        h.controller.setNetworkAvailable(false)
        h.environment.advance(by: 30.0)
        XCTAssertTrue(h.environment.loads.isEmpty)
        h.controller.setNetworkAvailable(true)
        h.environment.advance(by: 2.9)
        XCTAssertTrue(h.environment.loads.isEmpty)
        h.environment.advance(by: 0.2)
        
        XCTAssertEqual(h.segmentLoads.first?.level, 1)
        h.assertInvariants()
    }
    
    // Holes wider than maxHole split the buffer into runs; what is buffered between the position and the next
    // segment still counts toward the 60 s ahead (hls.js's exceedsMaxBuffer).
    func testHolesWiderThanMaxHoleDoNotDefeatTheBufferCap() {
        let h = ControllerHarness(seconds: 300.0)
        h.environment.bandwidth = 50_000_000.0
        h.environment.probedEndShortfall = 0.3
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 60.0)
        
        let starts = h.buffered.map(\.start)
        XCTAssertLessThan(starts.max() ?? 0.0, 65.0)
        XCTAssertLessThanOrEqual(h.appendedKeys.count, 15)
    }
    
    // D1: a range partly on disk samples only the bytes that came over the network, over the whole request.
    func testPartlyCachedFirstRangeSamplesOnlyNetworkBytes() {
        let h = ControllerHarness()
        h.environment.bandwidth = 2_000_000.0
        let firstRange = 0 ..< h.playlists[2].segments[0].byteRange.upperBound
        let half = firstRange.upperBound / 2
        h.environment.markOnDisk(level: 2, range: 0 ..< half)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 5.0)
        
        // The init is among the cached bytes, so only the segment's own range is fetched.
        XCTAssertEqual(h.environment.loads.first?.range, h.playlists[2].segments[0].byteRange)
        XCTAssertEqual(h.environment.loads.first?.networkBytes, firstRange.upperBound - half)
        XCTAssertEqual(h.loggedSamples.first?.bytes, firstRange.upperBound - half)
        h.assertInvariants()
    }
    
    // A load that joins the chat preload's fetch of the same bytes measures nothing about the link.
    func testJoinedLoadDoesNotSample() {
        let h = ControllerHarness()
        h.environment.externallyFetchedLevels = [2]
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 2.0)
        
        XCTAssertFalse(h.appendedKeys.isEmpty)
        XCTAssertNil(h.controller.estimate)
        XCTAssertNil(h.store.estimator(for: .unknown))
        XCTAssertTrue(h.loggedSamples.isEmpty)
        h.assertInvariants()
    }
    
    // A level's init is loaded once: its completion is trusted even if the disk view has not caught up, so a
    // synchronously completing environment cannot recurse.
    func testInitCompletionIsTrustedOverALaggingDiskView() {
        let h = ControllerHarness()
        let initRange = h.playlists[2].initSegment
        h.environment.markOnDisk(level: 2, range: initRange)
        h.environment.completesPresentRangesSynchronously = true
        h.environment.missingBytesOverride = { level, range in
            return level == 2 && range == initRange ? Int64(initRange.count) : nil
        }
        h.controller.seek(to: 32.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 5.0)
        
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 6))
        h.assertInvariants()
    }
    
    // End of stream holds whichever level's last segment ends the buffer, so a level change at the end does not
    // reload the last segment at the new level.
    func testLevelChangeAtTheEndDoesNotReloadTheLastSegment() {
        let levels = TestStreams.fourLevels
        var playlists = levels.map { TestStreams.playlist(level: $0, durations: [5.0, 5.0, 2.0]) }
        playlists[2] = TestStreams.playlist(level: levels[2], durations: [5.0, 5.0, 2.3])
        let h = ControllerHarness(playlists: playlists)
        h.environment.bandwidth = 50_000_000.0
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 5.0)
        XCTAssertEqual(h.appendedKeys.last, HLSSegmentKey(level: 3, index: 2))
        
        let loadCount = h.environment.loads.count
        h.controller.setCap(2)
        h.environment.advance(by: 5.0)
        XCTAssertEqual(h.environment.loads.count, loadCount)
        h.assertInvariants()
    }
    
    // A segment already on disk whose level's init is not needs the init alone; the segment's data came from disk.
    func testOnlyTheInitLoadsWhenTheSegmentIsCached() {
        let h = ControllerHarness()
        h.environment.markOnDisk(level: 2, range: h.playlists[2].segments[6].byteRange)
        h.controller.seek(to: 32.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 2.0)
        
        XCTAssertEqual(h.environment.loads.first?.range, h.playlists[2].initSegment)
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 6))
        XCTAssertEqual(h.controller.firstSegmentSource, .disk)
        h.assertInvariants()
    }
    
    func testReleasingTheControllerCancelsItsLoads() {
        let environment = SimulatedEnvironment()
        let levels = TestStreams.fourLevels
        var controller: HLSPlaybackController? = HLSPlaybackController(levels: levels, preloadLevel: 2, environment: environment, bandwidthStore: HLSBandwidthStore())
        for (level, playlist) in levels.map({ TestStreams.uniform(level: $0, seconds: 60.0) }).enumerated() {
            controller?.setPlaylist(playlist, level: level)
        }
        controller?.start()
        XCTAssertEqual(environment.loads.count, 1)
        controller = nil
        XCTAssertTrue(environment.loads[0].cancelled)
    }
    
    func testOutOfRangeManualLevelMeansAuto() {
        let h = ControllerHarness()
        h.controller.setManualLevel(7)
        h.setPlaylists()
        h.controller.start()
        XCTAssertEqual(h.controller.startLevel, 2)
        XCTAssertEqual(h.environment.loads.first?.level, 2)
        h.assertInvariants()
    }
    
    // The probe completes appends a moment later in the app; one segment stays in flight throughout.
    func testDelayedAppendsKeepOneSegmentInFlight() {
        let h = ControllerHarness()
        h.environment.bandwidth = 20_000_000.0
        h.environment.appendDelay = 0.02
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 3.0)
        
        let appended = h.appendedKeys
        XCTAssertGreaterThanOrEqual(appended.count, 3)
        XCTAssertEqual(appended.map(\.index), Array(0 ..< appended.count))
        h.assertInvariants()
    }
    
    // The level of the first part, for the start log: a manual level set before the first part decides it, and the
    // start rule is never consulted.
    func testFirstSegmentLevelIsTheFirstPartsLevel() {
        let h = ControllerHarness()
        h.environment.bandwidth = 4_000_000.0
        h.controller.setManualLevel(3)
        h.setPlaylists()
        h.controller.start()
        XCTAssertNil(h.controller.firstSegmentLevel)
        h.environment.advance(by: 3.0)
        
        XCTAssertEqual(h.appendedKeys.first?.level, 3)
        XCTAssertEqual(h.controller.firstSegmentLevel, 3)
        h.assertInvariants()
    }
    
    // A playlist the loader rejected (it names another file, or its ranges pass the file's end) is never coming: the
    // start does not wait for it, at the preload level either, and the level is never loaded.
    func testRejectedPreloadPlaylistStartsAtTheLevelBelow() {
        let h = ControllerHarness()
        h.controller.setPlaylistRejected(level: 2)
        h.setPlaylists(except: [2])
        h.controller.start()
        XCTAssertEqual(h.segmentLoads.first?.level, 1)
        h.environment.advance(by: 10.0)
        
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 1, index: 0))
        XCTAssertFalse(h.environment.loads.contains(where: { $0.level == 2 }))
        XCTAssertGreaterThan(h.appendedKeys.count, 2)
        h.assertInvariants()
    }
    
    // hls.js never abandons the first fragment (its check waits for media.readyState): a cold start on a slow link
    // while playing loads its first segment once. 751,100 bytes at 1 Mbit/s take 6 s.
    func testColdStartWhilePlayingLoadsTheFirstSegmentOnce() {
        let h = ControllerHarness()
        h.environment.bandwidth = 1_000_000.0
        h.controller.updatePlayback(position: 0.0, isPlaying: true, rate: 1.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 30.0)
        
        XCTAssertEqual(h.appendedKeys.first, HLSSegmentKey(level: 2, index: 0))
        XCTAssertEqual(h.environment.loads.filter({ $0.level == 2 && $0.range.lowerBound == 0 }).count, 1)
        XCTAssertFalse(h.logLines.contains(where: { $0.contains("abandon") }))
        XCTAssertEqual(h.store.estimator(for: .unknown)?.estimate, h.controller.estimate)
        h.assertInvariants()
    }

    func testTheTimelineRecordsTheFirstLoadAndAppend() {
        let h = ControllerHarness()
        h.environment.appendDelay = 0.1
        h.controller.updatePlayback(position: 0.0, isPlaying: true, rate: 1.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 30.0)

        let timeline = h.controller.timeline
        let firstLoad = h.environment.loads[0]
        XCTAssertEqual(timeline.started, 0.0)
        XCTAssertEqual(timeline.firstLoadIssued, 0.0)
        XCTAssertEqual(timeline.firstLoadCompleted ?? -1.0, firstLoad.completionTime, accuracy: 1e-9)
        XCTAssertEqual(timeline.firstAppendRequested ?? -1.0, firstLoad.completionTime, accuracy: 1e-9)
        XCTAssertEqual(timeline.firstAppendCompleted ?? -1.0, firstLoad.completionTime + 0.1, accuracy: 1e-9)
        XCTAssertEqual(h.controller.networkBytesLoaded, h.environment.loads.filter({ $0.completed }).reduce(Int64(0), { $0 + $1.networkBytes }))
        XCTAssertEqual(h.controller.diskBytesAppended, 0)
        XCTAssertEqual(h.controller.abandonCount, 0)
    }

    func testDiskBytesAppendedCountsPartsFromDisk() {
        let h = ControllerHarness()
        h.cache(level: 2, seconds: 10.0)
        h.controller.updatePlayback(position: 0.0, isPlaying: true, rate: 1.0)
        h.setPlaylists()
        h.controller.start()
        h.environment.advance(by: 1.0)

        let playlist = h.playlists[2]
        let expected = Int64(playlist.segments[0].byteRange.count + playlist.segments[1].byteRange.count)
        XCTAssertEqual(h.controller.diskBytesAppended, expected)
    }

    // What the node reads to decide whether the playing video goes ahead in the download queue: seconds buffered from
    // the playhead on.
    func testForwardBufferLengthIsWhatIsBufferedAheadOfThePlayhead() {
        let h = ControllerHarness()
        h.environment.bandwidth = 1000.0
        h.cache(level: 2, seconds: 20.0)
        h.setPlaylists()
        XCTAssertEqual(h.controller.forwardBufferLength, 0.0)
        h.controller.start()
        h.environment.advance(by: 1.0)

        XCTAssertEqual(h.controller.forwardBufferLength, 20.0, accuracy: 0.001)
        h.controller.updatePlayback(position: 3.0, isPlaying: true, rate: 1.0)
        XCTAssertEqual(h.controller.forwardBufferLength, 17.0, accuracy: 0.001)
        h.assertInvariants()
    }
}
