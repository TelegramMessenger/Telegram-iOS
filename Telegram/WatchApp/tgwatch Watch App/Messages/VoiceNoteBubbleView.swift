import SwiftUI

/// Renders one voice-note bubble: rounded chrome (gray incoming / accent
/// outgoing) containing a play/pause glyph + 32-bar waveform + duration
/// label. Optional reply header sits inside the chrome above the row.
/// Caption (when non-empty) renders below the waveform inside the chrome.
///
/// Drives priority-1 viewport download via `.onScrollVisibilityChange`.
/// Tap goes through `ChatHistoryStore.togglePlayback(_:)`; the store kicks
/// a priority-2 download if the file isn't ready and routes the toggle to
/// the active `VoicePlaybackController`.
struct VoiceNoteBubbleView: View {
    let note: VoiceNoteVisual
    let caption: String
    let isOutgoing: Bool
    let replyHeader: ReplyHeader?

    @Environment(ChatHistoryStore.self) private var store
    @Environment(\.bubbleMetrics) private var metrics

    private var style: BubbleStyle { .resolve(isOutgoing: isOutgoing) }
    private var amplitudes: [Float] { unpackWaveform(note.waveform) }
    private var glyph: VoiceGlyph { store.voicePlayback.glyph(for: note.voiceFileId) }
    private var progress: Double { store.voicePlayback.progress(for: note.voiceFileId) }
    private var preparingProgress: Int? {
        if case .preparing(let id, let p) = store.voicePlayback.state, id == note.voiceFileId {
            return Int(p * 100)
        }
        return nil
    }

    var body: some View {
        chrome
            .onScrollVisibilityChange(threshold: 0.01) { visible in
                if visible {
                    store.requestFileDownload(fileId: note.voiceFileId)
                } else {
                    store.cancelFileDownload(fileId: note.voiceFileId)
                }
            }
    }

    private var chrome: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let header = replyHeader {
                ReplyHeaderView(header: header, style: BubbleStyle.resolve(isOutgoing: isOutgoing))
            }
            HStack(spacing: 6) {
                glyphView
                WaveformBarsView(amplitudes: amplitudes, progress: progress, isOutgoing: isOutgoing)
                trailing
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: BubbleShape.minSize, maxWidth: metrics.bubbleMaxWidth, minHeight: BubbleShape.minSize, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: BubbleShape.cornerRadius)
                .fill(style.fill)
        )
        .foregroundStyle(style.content)
        .contentShape(Rectangle())
        .onTapGesture { store.togglePlayback(note) }
    }

    @ViewBuilder
    private var glyphView: some View {
        // Fixed 32pt slot keeps the waveform width stable across glyph states.
        switch glyph {
        case .error:
            // Edge state — keep the red failure signal, no circle.
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 18)).foregroundStyle(.red)
                .frame(width: 32, height: 32)
        case .play, .pause, .spinner:
            ZStack {
                Circle().fill(style.playFill)
                Group {
                    switch glyph {
                    case .play:  Image(systemName: "play.fill").font(.system(size: 13))
                    case .pause: Image(systemName: "pause.fill").font(.system(size: 13))
                    default:     ProgressView().controlSize(.mini).scaleEffect(0.7).tint(style.playIcon)
                    }
                }
                .foregroundStyle(style.playIcon)
            }
            .frame(width: 32, height: 32)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if let pct = preparingProgress {
                Text("\(pct)%")
                    .font(.system(size: 8))
                    .foregroundStyle(style.secondary)
            } else {
                Text(formatDuration(note.duration))
                    .font(.system(size: 9))
                    .foregroundStyle(style.secondary)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

}

#if DEBUG
import TDShim

private struct VoiceNotePreviewNoopLoader: ChatHistoryLoader {
    func openChat(chatId: Int64) async throws {}
    func closeChat(chatId: Int64) async throws {}
    func loadHistory(chatId: Int64, fromMessageId: Int64, offset: Int, limit: Int) async throws -> [Message] { [] }
    func downloadFile(fileId: Int, priority: Int) async throws -> File { throw CancellationError() }
    func cancelDownloadFile(fileId: Int) async throws {}
    func sendText(chatId: Int64, text: String) async throws -> Message { throw CancellationError() }
    func sendVoiceNote(chatId: Int64, fileURL: URL, duration: Int, waveform: Data) async throws -> Message { throw CancellationError() }
    func setChatDraftMessage(chatId: Int64, draftText: String) async throws {}
    func viewMessages(chatId: Int64, messageIds: [Int64], forceRead: Bool) async throws {}
    func setPollAnswer(chatId: Int64, messageId: Int64, optionIds: [Int]) async throws {}
    func sendSticker(chatId: Int64, remoteFileId: String, emoji: String, width: Int, height: Int) async throws -> Message {
        throw CancellationError()
    }
    func sendLocation(chatId: Int64, latitude: Double, longitude: Double) async throws -> Message { throw CancellationError() }
}

@MainActor
private func previewStore() -> ChatHistoryStore {
    ChatHistoryStore(
        chatId: 0,
        chatType: .chatTypePrivate(ChatTypePrivate(userId: 0)),
        lastReadInboxMessageId: 0, unreadCount: 0, lastMessageId: nil,
        loader: VoiceNotePreviewNoopLoader()
    )
}

private func previewVoice(id: Int = 1) -> VoiceNoteVisual {
    VoiceNoteVisual(
        voiceFileId: id, duration: 18, mimeType: "audio/ogg",
        waveform: Data((0..<63).map { _ in UInt8.random(in: 0...255) }),
        caption: "", localPath: nil
    )
}

#Preview("Voice — incoming, idle") {
    VoiceNoteBubbleView(
        note: previewVoice(), caption: "",
        isOutgoing: false,
        replyHeader: nil
    )
    .bubblePreview()
    .environment(previewStore())
}

#Preview("Voice — outgoing, idle") {
    VoiceNoteBubbleView(
        note: previewVoice(id: 2), caption: "",
        isOutgoing: true,
        replyHeader: nil
    )
    .bubblePreview()
    .environment(previewStore())
}

#Preview("Voice — incoming with reply") {
    VoiceNoteBubbleView(
        note: previewVoice(id: 3), caption: "",
        isOutgoing: false,
        replyHeader: ReplyHeader(
            senderName: "Bob",
            snippet: "anchor message earlier in the chat",
            minithumbnail: nil, isOutgoing: false
        )
    )
    .bubblePreview()
    .environment(previewStore())
}

#Preview("Voice — incoming with caption") {
    VoiceNoteBubbleView(
        note: previewVoice(id: 4),
        caption: "Listen to this part carefully",
        isOutgoing: false,
        replyHeader: nil
    )
    .bubblePreview()
    .environment(previewStore())
}

#Preview("Voice — incoming, empty waveform") {
    VoiceNoteBubbleView(
        note: VoiceNoteVisual(
            voiceFileId: 5, duration: 5, mimeType: "audio/ogg",
            waveform: Data(), caption: "", localPath: nil
        ),
        caption: "", isOutgoing: false,
        replyHeader: nil
    )
    .bubblePreview()
    .environment(previewStore())
}
#endif
