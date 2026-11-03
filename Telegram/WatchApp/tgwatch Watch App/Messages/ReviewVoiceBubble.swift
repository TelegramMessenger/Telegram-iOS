import SwiftUI

/// Voice-note review bubble for the record sheet. Unlike `VoiceNoteBubbleView`,
/// it owns its playback controller directly (no `ChatHistoryStore` environment),
/// since the recorder lives outside any chat store.
struct ReviewVoiceBubble: View {
    let draft: VoiceRecordingDraft
    let controller: VoicePlaybackController

    private var note: VoiceNoteVisual {
        .draft(fileURL: draft.fileURL, duration: draft.duration, waveform: draft.waveform)
    }
    private var glyph: VoiceGlyph { controller.glyph(for: note.voiceFileId) }
    private var progress: Double { controller.progress(for: note.voiceFileId) }

    var body: some View {
        // Whole-chrome tap target (matches VoiceNoteBubbleView) — a 16pt glyph alone
        // is too small to hit reliably on watch; the glyph is decorative here.
        HStack(spacing: 6) {
            glyphView
                .font(.system(size: 14))
                .frame(width: 16, height: 16)

            WaveformBarsView(amplitudes: unpackWaveform(note.waveform),
                             progress: progress, isOutgoing: true)

            Text(formatDuration(draft.duration))
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: 200, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: BubbleShape.cornerRadius).fill(Color.accentColor))
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onTapGesture { controller.toggle(note: note) }
    }

    @ViewBuilder
    private var glyphView: some View {
        switch glyph {
        case .play:    Image(systemName: "play.fill")
        case .pause:   Image(systemName: "pause.fill")
        case .spinner: ProgressView().controlSize(.mini).scaleEffect(0.7)
        case .error:   Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
        }
    }
}
