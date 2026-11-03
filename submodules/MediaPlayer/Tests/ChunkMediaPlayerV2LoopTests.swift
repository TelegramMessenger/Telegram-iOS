import XCTest
import Postbox
import SwiftSignalKit
import TelegramAudio
import UniversalMediaPlayer

// The player treats any position within 0.1 s of the duration as the end, so a video no longer than
// that is at its end from position 0, and it is not played. Looping one used to seek to where the
// clock already was: that seek is a no-op that re-ran the end check synchronously, without bound.
final class ChunkMediaPlayerV2LoopTests: XCTestCase {
    private static let initializeTempBox: Void = {
        TempBox.initializeShared(basePath: NSTemporaryDirectory() + "ChunkMediaPlayerV2LoopTests-TempBox", processType: "tests", launchSpecificId: Int64(Date().timeIntervalSince1970 * 1000))
    }()

    private var disposables: [Disposable] = []

    override func tearDown() {
        self.disposables.forEach { $0.dispose() }
        self.disposables = []
        super.tearDown()
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

    private func makePlayer(partsState: Signal<ChunkMediaPlayerPartsState, NoError>) throws -> (ChunkMediaPlayerV2, MediaPlayerNode) {
        // The player takes its video layer from the node, which creates it asynchronously.
        let playerNode = MediaPlayerNode()
        self.spin(timeout: 2.0, until: { playerNode.videoLayer != nil })
        let _ = try XCTUnwrap(playerNode.videoLayer)

        let player = ChunkMediaPlayerV2(
            params: ChunkMediaPlayerV2.MediaDataReaderParams(useV2Reader: true),
            audioSessionManager: ManagedAudioSessionImpl(),
            source: .externalParts(partsState),
            video: true,
            enableSound: false,
            playerNode: playerNode
        )
        return (player, playerNode)
    }

    // The player decides whether it is buffering from part times alone, so a part whose file holds no
    // media is enough to let the clock run.
    private func part(startTime: Double, endTime: Double) -> ChunkMediaPlayerPart {
        let _ = ChunkMediaPlayerV2LoopTests.initializeTempBox
        return ChunkMediaPlayerPart(
            startTime: startTime,
            endTime: endTime,
            content: ChunkMediaPlayerPart.TempFile(file: TempBox.shared.tempFile(fileName: "part.mp4")),
            codecName: nil,
            offsetTime: 0.0
        )
    }

    private func observeStatus(_ player: ChunkMediaPlayerV2) -> () -> MediaPlayerStatus? {
        var lastStatus: MediaPlayerStatus?
        self.disposables.append(player.status.start(next: { status in
            lastStatus = status
        }))
        return { lastStatus }
    }

    private static func isPlayingLike(_ status: MediaPlayerPlaybackStatus) -> Bool {
        switch status {
        case .playing:
            return true
        case let .buffering(_, whilePlaying, _, _):
            return whilePlaying
        case .paused:
            return false
        }
    }

    func testVideoWithinEndToleranceIsNotPlayed() throws {
        let partsState = Promise<ChunkMediaPlayerPartsState>()
        let (player, playerNode) = try self.makePlayer(partsState: partsState.get())
        let status = self.observeStatus(player)

        var loopCount = 0
        player.actionAtEnd = .loop({
            loopCount += 1
        })
        player.play()

        partsState.set(.single(ChunkMediaPlayerPartsState(duration: 0.05, content: .parts([self.part(startTime: 0.0, endTime: 0.05)]))))
        // Let the player's 60 Hz update timer run: a stopped player must not start looping again.
        self.spin(for: 0.3)

        XCTAssertEqual(loopCount, 1, "reaching the end should be reported once")
        let stopped = try XCTUnwrap(status())
        XCTAssertFalse(ChunkMediaPlayerV2LoopTests.isPlayingLike(stopped.status), "a video that cannot loop should stop")
        XCTAssertEqual(stopped.timestamp, 0.0)

        // A chat plays the video again when it scrolls back into view. The end check has already run
        // by then, so nothing but the player's refusal to move the clock keeps it at the start.
        player.play()
        self.spin(for: 0.3)

        XCTAssertEqual(loopCount, 1)
        XCTAssertEqual(try XCTUnwrap(status()).timestamp, 0.0, "the clock should not move")
        withExtendedLifetime(playerNode) {}
    }

    func testVideoJustLongerThanEndTolerancePlaysAndLoops() throws {
        let partsState = Promise<ChunkMediaPlayerPartsState>()
        let (player, playerNode) = try self.makePlayer(partsState: partsState.get())

        var loopCount = 0
        player.actionAtEnd = .loop({
            loopCount += 1
        })
        player.play()
        partsState.set(.single(ChunkMediaPlayerPartsState(duration: 0.15, content: .parts([self.part(startTime: 0.0, endTime: 0.15)]))))

        // Every loop needs the clock to run from 0 to the end again.
        self.spin(timeout: 3.0, until: { loopCount >= 2 })
        XCTAssertGreaterThanOrEqual(loopCount, 2, "the video should play to its end and loop")
        withExtendedLifetime(playerNode) {}
    }

    func testLoopingVideoRestartsFromTheBeginningAtItsEnd() throws {
        let partsState = Promise<ChunkMediaPlayerPartsState>()
        let (player, playerNode) = try self.makePlayer(partsState: partsState.get())
        let status = self.observeStatus(player)

        var loopCount = 0
        player.actionAtEnd = .loop({
            loopCount += 1
        })
        player.play()
        // No parts: the player stays buffering, so the clock only moves when it seeks.
        partsState.set(.single(ChunkMediaPlayerPartsState(duration: 10.0, content: .parts([]))))
        self.spin(for: 0.1)
        XCTAssertEqual(loopCount, 0)

        player.seek(timestamp: 9.95, play: true)
        self.spin(timeout: 2.0, until: { loopCount != 0 })
        self.spin(for: 0.3)

        XCTAssertEqual(loopCount, 1, "the end should be reached once")
        let looped = try XCTUnwrap(status())
        XCTAssertTrue(ChunkMediaPlayerV2LoopTests.isPlayingLike(looped.status), "a looping video should keep playing")
        XCTAssertEqual(looped.timestamp, 0.0, "a looping video should restart from the beginning")
        withExtendedLifetime(playerNode) {}
    }
}
