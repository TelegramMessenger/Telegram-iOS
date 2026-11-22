import Foundation

/// A finished local recording, ready to send. The file is owned by `VoiceRecorder`
/// until `consumeDraft()` transfers ownership to the caller.
struct VoiceRecordingDraft: Equatable {
    let fileURL: URL
    let duration: Int       // seconds
    let waveform: Data      // 20 bytes, 32 × 5-bit
}

enum RecordPermission { case granted, denied, undetermined }

/// Capture backend. Production uses `AVRecordingBackend`; tests use a fake.
@MainActor
protocol RecordingBackend: AnyObject {
    func ensurePermission() async -> RecordPermission
    /// Begins capture. `onLevel` fires (~10 Hz) with normalized RMS in [0, 1].
    func begin(onLevel: @escaping @MainActor (Float) -> Void) throws
    /// Stops capture, finalizes the file, returns the finished draft.
    func finish() async throws -> VoiceRecordingDraft
    /// Aborts capture and deletes any partial file.
    func abort()
}

enum RecordState: Equatable {
    case idle
    case requestingPermission
    case recording(elapsed: TimeInterval, level: Float)
    case stopping
    case review(VoiceRecordingDraft)
    case failed(String)
}

@Observable @MainActor
final class VoiceRecorder {
    private(set) var state: RecordState = .idle

    private let backend: RecordingBackend
    private let maxDuration: TimeInterval
    private var startDate: Date?
    private var lastLevel: Float = 0
    private var ownedFileURL: URL?
    private var ticker: Task<Void, Never>?
    // Invalidates an in-flight `completeStop` if `discard`/`tearDown` pre-empt it
    // while `backend.finish()` is still awaiting — otherwise the late completion
    // would resurrect `.review` with a file the teardown already deleted.
    private var stopTok = 0

    init(backend: RecordingBackend, maxDuration: TimeInterval = 300) {
        self.backend = backend
        self.maxDuration = maxDuration
    }

    func start() async {
        guard case .idle = state else { return }
        state = .requestingPermission
        switch await backend.ensurePermission() {
        case .granted:
            break
        case .denied, .undetermined:
            state = .failed("Microphone access denied. Enable in Settings → Privacy.")
            return
        }
        do {
            try backend.begin { [weak self] level in self?.lastLevel = level }
            startDate = Date()
            state = .recording(elapsed: 0, level: 0)
            startTicker()
        } catch {
            state = .failed("Couldn't start microphone")
        }
    }

    func stop() async {
        guard case .recording = state else { return }
        let tok = beginStopping()
        await completeStop(tok: tok)
    }

    func discard() {
        ticker?.cancel(); ticker = nil
        stopTok &+= 1            // invalidate any in-flight completeStop
        backend.abort()
        deleteOwnedFile()
        startDate = nil
        state = .idle
    }

    /// Releases file ownership to the caller WITHOUT deleting it. Use on a
    /// successful send so TDLib can keep reading the file during upload.
    func consumeDraft() -> VoiceRecordingDraft? {
        guard case .review(let draft) = state else { return nil }
        ownedFileURL = nil           // ownership transferred — tearDown won't delete it
        state = .idle
        return draft
    }

    func tearDown() {
        ticker?.cancel(); ticker = nil
        stopTok &+= 1            // invalidate any in-flight completeStop
        backend.abort()
        deleteOwnedFile()
        startDate = nil
        state = .idle
    }

    /// Internal — driven by the production ticker; called directly by tests.
    func tick(elapsed: TimeInterval) {
        guard case .recording = state else { return }
        if elapsed >= maxDuration {
            let tok = beginStopping()
            Task { await completeStop(tok: tok) }
            return
        }
        state = .recording(elapsed: elapsed, level: lastLevel)
    }

    // MARK: - Private

    private func beginStopping() -> Int {
        ticker?.cancel(); ticker = nil
        stopTok &+= 1
        state = .stopping
        return stopTok
    }

    private func completeStop(tok: Int) async {
        do {
            let draft = try await backend.finish()
            guard tok == stopTok else { return }   // pre-empted by discard/tearDown
            ownedFileURL = draft.fileURL
            state = .review(draft)
        } catch {
            guard tok == stopTok else { return }
            state = .failed("Couldn't save recording")
        }
    }

    private func startTicker() {
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, let start = self.startDate else { return }
                self.tick(elapsed: Date().timeIntervalSince(start))
                try? await Task.sleep(nanoseconds: 100_000_000) // 10 Hz
            }
        }
    }

    private func deleteOwnedFile() {
        if let url = ownedFileURL { try? FileManager.default.removeItem(at: url) }
        ownedFileURL = nil
    }
}
