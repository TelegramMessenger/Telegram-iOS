import XCTest
import Postbox
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
}
