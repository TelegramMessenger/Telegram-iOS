import OpusKit
import SwiftUI

/// Pushable voice-message recorder. Pushed inside AttachmentSheet's
/// NavigationStack. On appear it tears down the chat's playback via `onPrepare`
/// so a playing bubble stops before recording. A successful send calls
/// `onComplete` to collapse the whole attachment sheet; Cancel/back pops one
/// level to the menu (the pushed-view `dismiss`).
struct VoiceRecordView: View {
    /// Returns true if the voice note was accepted by the chat store.
    let onSend: (VoiceRecordingDraft) async -> Bool
    /// Stops the chat's voice/audio playback before recording starts.
    let onPrepare: () -> Void
    /// Collapses the whole attachment sheet after a successful send.
    let onComplete: () -> Void

    @State private var recorder: VoiceRecorder
    @State private var playback: VoicePlaybackController
    @State private var isSending = false
    @State private var sendError: String?
    @State private var levels: [Float] = []
    @Environment(\.dismiss) private var dismiss

    init(
        onSend: @escaping (VoiceRecordingDraft) async -> Bool,
        onPrepare: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.onSend = onSend
        self.onPrepare = onPrepare
        self.onComplete = onComplete
        _recorder = State(wrappedValue: VoiceRecorder(backend: AVRecordingBackend()))
        _playback = State(wrappedValue: VoicePlaybackController(
            backend: AVEngineBackend(), decoder: OpusDecoderAdapter()))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                switch recorder.state {
                case .idle:                             idle
                case .requestingPermission:             ProgressView()
                case .recording(let elapsed, let lvl):  recording(elapsed: elapsed, level: lvl)
                case .stopping:                         ProgressView("Finishing…")
                case .review(let draft):                review(draft)
                case .failed(let reason):               failed(reason)
                }
            }
            .padding()
        }
        .navigationTitle(isRecordingOrReview ? "" : "Voice Message")
        .navigationBarBackButtonHidden(isRecordingOrReview)
        .toolbar { toolbarContent }
        .onAppear { onPrepare() }
        .onDisappear {
            recorder.tearDown()
            playback.tearDown()
        }
    }

    private var isRecordingOrReview: Bool {
        switch recorder.state {
        case .recording, .review: return true
        default: return false
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        switch recorder.state {
        case .recording(let elapsed, _):
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { recorder.discard(); dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Text(formatDuration(Int(elapsed))).font(.caption).monospacedDigit()
            }
        case .review(let draft):
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { playback.tearDown(); recorder.discard(); dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isSending { ProgressView() } else { Button("Send") { send(draft) } }
            }
        default:
            ToolbarItem(placement: .cancellationAction) { EmptyView() }
        }
    }

    private func transportRing<Inner: View>(@ViewBuilder _ inner: () -> Inner) -> some View {
        ZStack {
            Circle().stroke(.white, lineWidth: 3).frame(width: 44, height: 44)
            inner()
        }
    }

    // MARK: - States

    private var idle: some View {
        Button { levels = []; Task { await recorder.start() } } label: {
            VStack(spacing: 8) {
                Image(systemName: "mic.circle.fill").font(.system(size: 48))
                Text("Tap to record").font(.caption).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("recordStart")
    }

    private func recording(elapsed: TimeInterval, level: Float) -> some View {
        VStack(spacing: 16) {
            VoiceEditorWaveform(samples: levels, progress: nil)
            Button { Task { await recorder.stop() } } label: {
                transportRing { RoundedRectangle(cornerRadius: 4).fill(.red).frame(width: 18, height: 18) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recordStop")
        }
        .onChange(of: elapsed) { _, _ in
            levels.append(level)
            if levels.count > 96 { levels.removeFirst(levels.count - 96) }
        }
    }

    private func review(_ draft: VoiceRecordingDraft) -> some View {
        let note = VoiceNoteVisual.draft(fileURL: draft.fileURL, duration: draft.duration, waveform: draft.waveform)
        return VStack(spacing: 16) {
            VoiceEditorWaveform(
                samples: unpackWaveform(draft.waveform),
                progress: playback.progress(for: note.voiceFileId)
            )
            if let sendError {
                Text(sendError).font(.caption2).foregroundStyle(.red)
            }
            Button { playback.toggle(note: note) } label: {
                transportRing { reviewGlyph(playback.glyph(for: note.voiceFileId)) }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("recordReviewPlay")
        }
    }

    @ViewBuilder
    private func reviewGlyph(_ glyph: VoiceGlyph) -> some View {
        switch glyph {
        case .play:    Image(systemName: "play.fill").font(.system(size: 18)).foregroundStyle(.white)
        case .pause:   Image(systemName: "pause.fill").font(.system(size: 18)).foregroundStyle(.white)
        case .spinner: ProgressView().controlSize(.small)
        case .error:   Image(systemName: "exclamationmark.circle.fill").font(.system(size: 18)).foregroundStyle(.red)
        }
    }

    private func failed(_ reason: String) -> some View {
        VStack(spacing: 10) {
            Text(reason).font(.caption).foregroundStyle(.red).multilineTextAlignment(.center)
            Button("Try again") { recorder.discard() }.buttonStyle(.bordered)
            Button("Cancel") { dismiss() }.buttonStyle(.bordered).tint(.red)
        }
    }

    // MARK: - Send

    private func send(_ draft: VoiceRecordingDraft) {
        guard !isSending else { return }
        isSending = true
        sendError = nil
        Task {
            let ok = await onSend(draft)
            if ok {
                _ = recorder.consumeDraft()   // release file ownership only after success
                onComplete()
            } else {
                sendError = "Couldn't send. Try again."
                isSending = false
            }
        }
    }
}
