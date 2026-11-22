import AVFoundation
import Combine
import Foundation
import OSLog

/// Streaming audio playback backend. Production wraps a single `AVPlayer`;
/// tests substitute a fake. `@MainActor` like `VoicePlaybackBackend` so the
/// callbacks (which the controller assigns) are main-isolated.
@MainActor
protocol AudioPlayerBackend: AnyObject {
    func load(url: URL) throws
    func play()
    func pause()
    func stop()
    var elapsed: Double { get }
    /// Fired ~2×/sec with the current playback position in seconds.
    var onProgress: ((Double) -> Void)? { get set }
    /// Fired when the item plays to its end.
    var onEnded: (() -> Void)? { get set }
    /// Fired when the player item transitions to `.failed`.
    var onFailed: ((String) -> Void)? { get set }
}

enum AudioGlyph: Equatable {
    case play
    case pause
    case spinner
    case error
}

/// Inline music playback for chat-history audio bubbles. One file active at a
/// time. Unlike `VoicePlaybackController` (whole-file Opus decode → PCM buffer),
/// this streams via `AVPlayer` so multi-minute tracks don't blow watch memory.
@Observable @MainActor
final class AudioPlaybackController {

    enum State: Equatable {
        case idle
        case preparing(audioFileId: Int)
        case playing(audioFileId: Int)
        case paused(audioFileId: Int)
        case failed(audioFileId: Int, message: String)
    }

    private(set) var state: State = .idle
    /// Observable elapsed-seconds tick driving the bubble's "elapsed / total" label.
    private(set) var currentElapsed: Double = 0

    private let backend: AudioPlayerBackend

    init(backend: AudioPlayerBackend) {
        self.backend = backend
        self.backend.onProgress = { [weak self] t in self?.handleProgress(t) }
        self.backend.onEnded = { [weak self] in self?.handleEnded() }
        self.backend.onFailed = { [weak self] msg in self?.handleFailed(msg) }
    }

    func isActive(_ audioFileId: Int) -> Bool {
        switch state {
        case .preparing(let id), .playing(let id), .paused(let id), .failed(let id, _):
            return id == audioFileId
        case .idle:
            return false
        }
    }

    func glyph(for audioFileId: Int) -> AudioGlyph {
        switch state {
        case .preparing(let id) where id == audioFileId: return .spinner
        case .playing(let id) where id == audioFileId:    return .pause
        case .paused(let id) where id == audioFileId:     return .play
        case .failed(let id, _) where id == audioFileId:  return .error
        default:                                          return .play
        }
    }

    func elapsed(for audioFileId: Int) -> Int {
        guard isActive(audioFileId) else { return 0 }
        return Int(currentElapsed)
    }

    /// Entry point the bubble calls. If `audio.localPath` is nil the controller
    /// transitions to `.preparing` and waits for `resumeIfReady(audio:)`.
    func toggle(audio: AudioVisual) {
        switch state {
        case .playing(let id) where id == audio.audioFileId:
            backend.pause()
            state = .paused(audioFileId: id)
            return
        case .paused(let id) where id == audio.audioFileId:
            backend.play()
            state = .playing(audioFileId: id)
            return
        case .preparing(let id) where id == audio.audioFileId:
            // Second tap during preparing = cancel.
            tearDown()
            return
        default:
            // Switch active (or fresh start).
            tearDown()
        }
        guard let path = audio.localPath else {
            state = .preparing(audioFileId: audio.audioFileId)
            return
        }
        startPlayback(audio: audio, path: path)
    }

    /// Called by ChatHistoryStore when a fileSnapshot update lands for an audio
    /// file that's currently `.preparing`. Advances to `.playing` if the path is
    /// now available.
    func resumeIfReady(audio: AudioVisual) {
        guard case .preparing(let id) = state, id == audio.audioFileId else { return }
        guard let path = audio.localPath else { return }
        startPlayback(audio: audio, path: path)
    }

    func tearDown() {
        currentElapsed = 0
        backend.stop()
        state = .idle
    }

    // MARK: - Private

    private func startPlayback(audio: AudioVisual, path: String) {
        currentElapsed = 0
        do {
            try backend.load(url: URL(fileURLWithPath: path))
            backend.play()
            state = .playing(audioFileId: audio.audioFileId)
        } catch {
            state = .failed(audioFileId: audio.audioFileId, message: "Could not play audio")
        }
    }

    private func handleProgress(_ t: Double) {
        guard case .playing = state else { return }
        currentElapsed = t
    }

    private func handleEnded() {
        guard case .playing = state else { return }
        // Reset state before stopping the backend so a queued main-queue progress
        // callback can't write a stale elapsed after end-of-playback (mirrors
        // VoicePlaybackController.handlePlaybackEnded).
        state = .idle
        currentElapsed = 0
        backend.stop()
    }

    private func handleFailed(_ message: String) {
        switch state {
        case .playing(let id), .preparing(let id), .paused(let id):
            state = .failed(audioFileId: id, message: message)
        case .idle, .failed:
            break
        }
    }
}

// MARK: - Production wiring

/// Wraps a single `AVPlayer`. Owns the audio-session activation that watchOS
/// requires for `AVPlayer` audibility (mirrors `VideoPlayerView`). Removing all
/// observers on `stop()` / `load()` means stale end/failure callbacks can't
/// reach the controller after a switch.
@MainActor
final class AVPlayerBackend: AudioPlayerBackend {
    var onProgress: ((Double) -> Void)?
    var onEnded: (() -> Void)?
    var onFailed: ((String) -> Void)?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: AnyCancellable?
    private let logger = Logger(subsystem: "com.isaac.tgwatch", category: "audioplayer")

    var elapsed: Double {
        guard let player else { return 0 }
        let t = CMTimeGetSeconds(player.currentTime())
        return t.isFinite ? t : 0
    }

    func load(url: URL) throws {
        teardownObservers()
        let p = AVPlayer(url: url)
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] t in
            let secs = CMTimeGetSeconds(t)
            self?.onProgress?(secs.isFinite ? secs : 0)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main
        ) { [weak self] _ in
            self?.onEnded?()
        }
        statusObserver = p.currentItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed { self?.onFailed?("Could not play audio") }
            }
        try activatePlaybackSession()
        player = p
        logger.info("audio load \(url.lastPathComponent, privacy: .public)")
    }

    func play()  { player?.play() }
    func pause() { player?.pause() }

    func stop() {
        player?.pause()
        teardownObservers()
        player?.replaceCurrentItem(with: nil)
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// All observers are delivered on the main queue, so removing their
    /// registrations here (synchronously, on the main actor) prevents any queued
    /// invocation from firing after this point — this is the stale-callback guard.
    private func teardownObservers() {
        if let t = timeObserver { player?.removeTimeObserver(t); timeObserver = nil }
        if let e = endObserver { NotificationCenter.default.removeObserver(e); endObserver = nil }
        statusObserver?.cancel()
        statusObserver = nil
    }

    /// watchOS routes AVPlayer audio to the speaker only under an active
    /// `.playback` session — same requirement as `VideoPlayerView`.
    private func activatePlaybackSession() throws {
        let session = AVAudioSession.sharedInstance()
        // Music uses `.default` (preserves the user's chosen output route); video
        // uses `.moviePlayback` (forces speaker). Both keep `.playback` so audio is
        // audible on watchOS.
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }
}
