import XCTest
import Postbox
import QuartzCore
import SwiftSignalKit
import TelegramAudio
import UniversalMediaPlayer

// A `.custom` source hears the player's seeks and playback position, which `.externalParts` never reports.
final class ChunkMediaPlayerV2CustomSourceTests: XCTestCase {
    private static let initializeTempBox: Void = {
        TempBox.initializeShared(basePath: NSTemporaryDirectory() + "ChunkMediaPlayerV2CustomSourceTests-TempBox", processType: "tests", launchSpecificId: Int64(Date().timeIntervalSince1970 * 1000))
    }()
    
    private final class RecordingSource: ChunkMediaPlayerSourceImpl {
        let partsState: Signal<ChunkMediaPlayerPartsState, NoError>
        private(set) var seeks: [(id: Int, position: Double)] = []
        private(set) var playbackStates: [(seekTimestamp: Double, position: Double, isPlaying: Bool)] = []
        
        init(partsState: Signal<ChunkMediaPlayerPartsState, NoError>) {
            self.partsState = partsState
        }
        
        func seek(id: Int, position: Double) {
            self.seeks.append((id, position))
        }
        
        func updatePlaybackState(seekTimestamp: Double, position: Double, isPlaying: Bool) {
            self.playbackStates.append((seekTimestamp, position, isPlaying))
        }
    }
    
    private func spin(for interval: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(interval))
    }
    
    private func spin(timeout: TimeInterval, until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
    
    func testCustomSourceReceivesSeekAndPlaybackState() throws {
        let _ = ChunkMediaPlayerV2CustomSourceTests.initializeTempBox
        // The player takes its video layer from the node, which creates it asynchronously.
        let playerNode = MediaPlayerNode()
        self.spin(timeout: 2.0, until: { playerNode.videoLayer != nil })
        let _ = try XCTUnwrap(playerNode.videoLayer)
        
        let part = ChunkMediaPlayerPart(
            startTime: 0.0,
            endTime: 10.0,
            content: ChunkMediaPlayerPart.TempFile(file: TempBox.shared.tempFile(fileName: "part.mp4")),
            codecName: nil,
            offsetTime: 0.0
        )
        let source = RecordingSource(partsState: .single(ChunkMediaPlayerPartsState(duration: 10.0, content: .parts([part]))))
        let player = ChunkMediaPlayerV2(
            params: ChunkMediaPlayerV2.MediaDataReaderParams(useV2Reader: true),
            audioSessionManager: ManagedAudioSessionImpl(),
            source: .custom(source),
            video: true,
            enableSound: false,
            playerNode: playerNode
        )
        
        player.seek(timestamp: 3.0, play: false)
        self.spin(for: 0.5)
        
        XCTAssertTrue(source.seeks.contains(where: { abs($0.position - 3.0) < 0.001 }), "seeks: \(source.seeks)")
        XCTAssertTrue(source.playbackStates.contains(where: { abs($0.position - 3.0) < 0.05 }), "states: \(source.playbackStates.suffix(3))")
        withExtendedLifetime(player) {
        }
    }

    // An HLS open inside a part: the source asks the clock not to start before the next part can land in time.
    func testTheClockWaitsForStartNotBeforeAfterASeek() throws {
        let _ = ChunkMediaPlayerV2CustomSourceTests.initializeTempBox
        let playerNode = MediaPlayerNode()
        self.spin(timeout: 2.0, until: { playerNode.videoLayer != nil })
        let _ = try XCTUnwrap(playerNode.videoLayer)
        
        let part = ChunkMediaPlayerPart(
            startTime: 0.0,
            endTime: 10.0,
            content: ChunkMediaPlayerPart.TempFile(file: TempBox.shared.tempFile(fileName: "part.mp4")),
            codecName: nil,
            offsetTime: 0.0
        )
        let startNotBefore = CACurrentMediaTime() + 1.0
        // The part is the first half of the video: a run that reaches the end is never held.
        let source = RecordingSource(partsState: .single(ChunkMediaPlayerPartsState(duration: 20.0, content: .parts([part]), startNotBefore: startNotBefore)))
        let player = ChunkMediaPlayerV2(
            params: ChunkMediaPlayerV2.MediaDataReaderParams(useV2Reader: true),
            audioSessionManager: ManagedAudioSessionImpl(),
            source: .custom(source),
            video: true,
            enableSound: false,
            playerNode: playerNode
        )
        
        player.seek(timestamp: 3.0, play: true)
        self.spin(for: 0.6)
        let held = source.playbackStates.last?.position ?? -1.0
        XCTAssertEqual(held, 3.0, accuracy: 0.01, "the clock moved before startNotBefore")
        
        self.spin(timeout: 2.0, until: { (source.playbackStates.last?.position ?? 0.0) > 3.2 })
        XCTAssertGreaterThan(source.playbackStates.last?.position ?? 0.0, 3.2, "the clock never started")
        XCTAssertGreaterThanOrEqual(CACurrentMediaTime(), startNotBefore)
        withExtendedLifetime(player) {
        }
    }
}
