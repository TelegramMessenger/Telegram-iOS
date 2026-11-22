import Foundation
import XCTest
@testable import HLSPlayback

final class HLSPlaybackStatsTests: XCTestCase {
    func testBufferingAfterTheFirstFrameIsAStall() {
        let stats = HLSPlaybackStats()
        stats.noteFirstFrame(now: 0.0)
        stats.noteStatus(isBuffering: false, isPlayRequested: true, now: 0.0)
        stats.noteStatus(isBuffering: true, isPlayRequested: true, now: 10.0)
        stats.noteStatus(isBuffering: false, isPlayRequested: true, now: 12.0)
        XCTAssertEqual(stats.summary.stallCount, 1)
        XCTAssertEqual(stats.summary.stallTime, 2.0, accuracy: 1e-9)
        XCTAssertEqual(stats.summary.seekWaitCount, 0)
    }

    func testBufferingBeforeTheFirstFrameIsNotAStall() {
        let stats = HLSPlaybackStats()
        stats.noteStatus(isBuffering: true, isPlayRequested: true, now: 0.0)
        stats.noteStatus(isBuffering: false, isPlayRequested: true, now: 1.0)
        stats.noteFirstFrame(now: 1.0)
        XCTAssertEqual(stats.summary.stallCount, 0)
        XCTAssertEqual(stats.summary.stallTime, 0.0)
        XCTAssertEqual(stats.summary.seekWaitCount, 0)
    }

    func testBufferingAfterASeekIsASeekWait() {
        let stats = HLSPlaybackStats()
        stats.noteFirstFrame(now: 0.0)
        stats.noteStatus(isBuffering: false, isPlayRequested: true, now: 0.0)
        stats.noteSeek(now: 5.0)
        stats.noteStatus(isBuffering: true, isPlayRequested: true, now: 5.0)
        stats.noteStatus(isBuffering: false, isPlayRequested: true, now: 5.4)
        XCTAssertEqual(stats.summary.seekWaitCount, 1)
        XCTAssertEqual(stats.summary.seekWaitTime, 0.4, accuracy: 1e-9)
        XCTAssertEqual(stats.summary.stallCount, 0)
    }

    func testBufferingWhilePausedIsNeither() {
        let stats = HLSPlaybackStats()
        stats.noteFirstFrame(now: 0.0)
        stats.noteStatus(isBuffering: false, isPlayRequested: true, now: 0.0)
        stats.noteStatus(isBuffering: false, isPlayRequested: false, now: 3.0)
        stats.noteStatus(isBuffering: true, isPlayRequested: false, now: 4.0)
        stats.noteStatus(isBuffering: false, isPlayRequested: false, now: 6.0)
        XCTAssertEqual(stats.summary.stallCount, 0)
        XCTAssertEqual(stats.summary.seekWaitCount, 0)
        XCTAssertEqual(stats.summary.stallTime, 0.0)
    }

    func testSecondsPerLevelAndSwitches() {
        let stats = HLSPlaybackStats()
        stats.notePlayhead(level: 2, isPlaying: true, now: 0.0)
        stats.notePlayhead(level: 3, isPlaying: true, now: 10.0)
        stats.notePlayhead(level: 3, isPlaying: true, now: 15.0)
        XCTAssertEqual(stats.summary.secondsPerLevel, [2: 10.0, 3: 5.0])
        XCTAssertEqual(stats.summary.levelSwitches, 1)
        XCTAssertEqual(stats.summary.playedTime, 15.0, accuracy: 1e-9)
    }
}
