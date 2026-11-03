import AVFoundation
import Foundation
import OpusKit

@MainActor
protocol VoicePlaybackBackend: AnyObject {
    func prepare() throws
    func play(buffer: AVAudioPCMBuffer, completion: @escaping @MainActor () -> Void) throws
    func pause()
    func resume()
    func stop()
    var elapsed: Double { get }
    var lastBufferDuration: Double { get }
}

protocol VoiceDecoder: Sendable {
    func decodePCM(url: URL) async throws -> DecodedOpus
}

enum VoiceGlyph: Equatable {
    case play
    case pause
    case spinner
    case error
}

@Observable @MainActor
final class VoicePlaybackController {

    enum State: Equatable {
        case idle
        case preparing(voiceFileId: Int, progress: Double)
        case playing(voiceFileId: Int)
        case paused(voiceFileId: Int)
        case failed(voiceFileId: Int, message: String)
    }

    private(set) var state: State = .idle
    /// Observable progress tick that drives the bubble's waveform fill during
    /// playback. Updated by `startTicker(tok:)` while in `.playing`.
    private(set) var currentProgress: Double = 0

    private let backend: VoicePlaybackBackend
    private let decoder: VoiceDecoder

    /// Identifies which decode/playback any pending completion belongs to.
    private var activeTok: Int = 0
    private var tickerTask: Task<Void, Never>? = nil
    private var decodeTask: Task<Void, Never>? = nil

    init(backend: VoicePlaybackBackend, decoder: VoiceDecoder) {
        self.backend = backend
        self.decoder = decoder
    }

    func isActive(_ voiceFileId: Int) -> Bool {
        switch state {
        case .preparing(let id, _), .playing(let id), .paused(let id), .failed(let id, _):
            return id == voiceFileId
        case .idle:
            return false
        }
    }

    func glyph(for voiceFileId: Int) -> VoiceGlyph {
        switch state {
        case .preparing(let id, _) where id == voiceFileId: return .spinner
        case .playing(let id) where id == voiceFileId:      return .pause
        case .paused(let id) where id == voiceFileId:       return .play
        case .failed(let id, _) where id == voiceFileId:    return .error
        default:                                            return .play
        }
    }

    func progress(for voiceFileId: Int) -> Double {
        guard isActive(voiceFileId) else { return 0 }
        return currentProgress
    }

    func tearDown() {
        activeTok &+= 1
        tickerTask?.cancel()
        tickerTask = nil
        decodeTask?.cancel()
        decodeTask = nil
        currentProgress = 0
        backend.stop()
        (backend as? AVEngineBackend)?.dropEngine()
        state = .idle
    }

    /// Entry point the bubble calls. If `note.localPath` is nil the controller
    /// transitions to `.preparing` and waits for the caller to call
    /// `resumeIfReady(note:)` once a path arrives.
    func toggle(note: VoiceNoteVisual) {
        switch state {
        case .playing(let id) where id == note.voiceFileId:
            backend.pause()
            tickerTask?.cancel()
            tickerTask = nil
            state = .paused(voiceFileId: id)
            return
        case .paused(let id) where id == note.voiceFileId:
            backend.resume()
            state = .playing(voiceFileId: id)
            startTicker(tok: activeTok)
            return
        case .preparing(let id, _) where id == note.voiceFileId:
            // Second tap during preparing = cancel.
            tearDown()
            return
        default:
            // Switch active (or fresh start).
            tearDown()
        }
        guard let path = note.localPath else {
            state = .preparing(voiceFileId: note.voiceFileId, progress: 0)
            return
        }
        startPlayback(note: note, path: path)
    }

    /// Called by ChatHistoryStore when a fileSnapshot update lands for a voice
    /// that's currently in `.preparing`. Advances to `.playing` if the path is
    /// now available.
    func resumeIfReady(note: VoiceNoteVisual) {
        guard case .preparing(let id, _) = state, id == note.voiceFileId else { return }
        guard let path = note.localPath else { return }
        startPlayback(note: note, path: path)
    }

    /// Called by ChatHistoryStore with download progress (0…1) while preparing.
    func updateDownloadProgress(voiceFileId: Int, progress: Double) {
        guard case .preparing(let id, _) = state, id == voiceFileId else { return }
        state = .preparing(voiceFileId: id, progress: progress)
    }

    // MARK: - Private

    private func startPlayback(note: VoiceNoteVisual, path: String) {
        activeTok &+= 1
        let tok = activeTok
        state = .preparing(voiceFileId: note.voiceFileId, progress: 1)

        let url = URL(fileURLWithPath: path)
        let decoder = self.decoder
        decodeTask?.cancel()
        decodeTask = Task { [weak self] in
            do {
                let decoded = try await decoder.decodePCM(url: url)
                self?.handleDecoded(tok: tok, note: note, decoded: decoded)
            } catch {
                self?.handleDecodeError(tok: tok, note: note, error: error)
            }
        }
    }

    private func handleDecoded(tok: Int, note: VoiceNoteVisual, decoded: DecodedOpus) {
        guard tok == activeTok else { return }
        do {
            try backend.prepare()
            try backend.play(buffer: decoded.pcm) { [weak self] in
                self?.handlePlaybackEnded(tok: tok, voiceFileId: note.voiceFileId)
            }
            state = .playing(voiceFileId: note.voiceFileId)
            startTicker(tok: tok)
        } catch {
            state = .failed(voiceFileId: note.voiceFileId, message: "Audio unavailable")
        }
    }

    private func handleDecodeError(tok: Int, note: VoiceNoteVisual, error: Error) {
        guard tok == activeTok else { return }
        state = .failed(voiceFileId: note.voiceFileId, message: "Could not play voice note")
    }

    private func handlePlaybackEnded(tok: Int, voiceFileId: Int) {
        guard tok == activeTok else { return }
        tickerTask?.cancel()
        tickerTask = nil
        currentProgress = 0
        backend.stop()
        state = .idle
    }

    /// Drives `currentProgress` updates at 20 Hz so the bubble's waveform fill
    /// is observable. Stops when the active token changes or state leaves
    /// `.playing`.
    private func startTicker(tok: Int) {
        tickerTask?.cancel()
        tickerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                guard tok == self.activeTok else { return }
                guard case .playing = self.state else { return }
                let total = self.backend.lastBufferDuration
                if total > 0 {
                    self.currentProgress = min(1, max(0, self.backend.elapsed / total))
                }
                try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
            }
        }
    }
}

// MARK: - Production wiring

@MainActor
final class AVEngineBackend: VoicePlaybackBackend {

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var attached = false
    private var connectedFormat: AVAudioFormat?
    private(set) var lastBufferDuration: Double = 0
    private var lastSampleRate: Double = 48000
    private var pendingCompletion: (@MainActor () -> Void)?

    var elapsed: Double {
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else {
            return 0
        }
        return Double(playerTime.sampleTime) / lastSampleRate
    }

    func prepare() throws {
        if !attached {
            engine.attach(player)
            attached = true
        }
    }

    func play(buffer: AVAudioPCMBuffer, completion: @escaping @MainActor () -> Void) throws {
        // AVAudioPlayerNode rejects buffers whose format differs from the player's
        // output connection format. Telegram voice notes are typically mono; the
        // smoke-test fixture is stereo. Reconnect on every format change so both
        // sources play back without raising NSInternalInconsistencyException.
        let bufFmt = buffer.format
        if connectedFormat == nil || connectedFormat?.isEqual(bufFmt) == false {
            if connectedFormat != nil {
                engine.disconnectNodeOutput(player)
            }
            engine.connect(player, to: engine.mainMixerNode, format: bufFmt)
            connectedFormat = bufFmt
        }
        if !engine.isRunning {
            try engine.start()
        }
        lastSampleRate = bufFmt.sampleRate
        lastBufferDuration = Double(buffer.frameLength) / lastSampleRate
        pendingCompletion = completion
        let captured = completion
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            // AVAudioEngine fires this on a non-main queue.
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.pendingCompletion != nil else { return }
                self.pendingCompletion = nil
                captured()
            }
        }
        player.play()
    }

    func pause()  { player.pause() }
    func resume() { player.play() }

    func stop() {
        pendingCompletion = nil
        player.stop()
        // Leave engine running between toggles within the same chat — saves a
        // hardware re-prepare. Stopped on tearDown via dropEngine().
    }

    /// Stops the engine entirely. Called from VoicePlaybackController.tearDown
    /// via the controller's stop path; safe to call repeatedly.
    func dropEngine() {
        player.stop()
        if engine.isRunning { engine.stop() }
    }
}

struct OpusDecoderAdapter: VoiceDecoder {
    func decodePCM(url: URL) async throws -> DecodedOpus {
        try await Task.detached(priority: .userInitiated) {
            try OpusKit.OpusDecoder.decodePCM(url: url)
        }.value
    }
}
