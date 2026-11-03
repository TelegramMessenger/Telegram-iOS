import SwiftUI
import UIKit

/// Renders one round-video-note bubble: a chrome-less 150 pt circle with the
/// preview image (downloaded thumb → blurred minithumbnail → gray placeholder)
/// behind a centered play overlay and a bottom-inside duration pill. Optional
/// reply mini-card (`StickerBubbleView` precedent) sits above.
///
/// Drives viewport-based download of the thumbnail file id (not the playable
/// video file) via `.onScrollVisibilityChange`. The playable file is downloaded
/// by `VideoNotePlayerView` when the user taps to play.
///
/// Tap is unconditional — the viewer handles the not-yet-downloaded state.
struct VideoNoteBubbleView: View {
    let note: VideoNoteVisual
    let isOutgoing: Bool
    let replyHeader: ReplyHeader?
    let onTap: () -> Void

    @Environment(ChatHistoryStore.self) private var store
    @Environment(\.bubbleMetrics) private var metrics

    private var diameter: CGFloat { metrics.videoNoteDiameter }
    private var style: BubbleStyle { .resolve(isOutgoing: isOutgoing) }

    var body: some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 2) {
            if let header = replyHeader {
                ReplyHeaderView(header: header, style: BubbleStyle.resolve(isOutgoing: isOutgoing))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(style.fill)
                    )
                    .frame(maxWidth: diameter)
            }
            ZStack {
                imageView
                    .frame(width: diameter, height: diameter)
                    .clipShape(Circle())
                playOverlay
            }
            .overlay(alignment: .bottom) {
                Text(formatDuration(note.duration))
                    .font(.system(size: 9))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(.black.opacity(0.5)))
                    .padding(.bottom, 6)
            }
            .contentShape(Circle())
            .onTapGesture { onTap() }
            .onScrollVisibilityChange(threshold: 0.01) { visible in
                guard let id = note.thumbFileId else { return }
                if visible {
                    store.requestFileDownload(fileId: id)
                } else {
                    store.cancelFileDownload(fileId: id)
                }
            }
        }
    }

    @ViewBuilder
    private var imageView: some View {
        if let path = note.thumbLocalPath, let img = UIImage(contentsOfFile: path) {
            Image(uiImage: img).resizable().scaledToFill()
        } else if let data = note.minithumbnail, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill().blur(radius: 2)
        } else {
            Color.gray.opacity(0.3)
        }
    }

    private var playOverlay: some View {
        Image(systemName: "play.circle.fill")
            .font(.system(size: 32))
            .foregroundStyle(.white)
            .shadow(radius: 2)
    }
}

#if DEBUG
import TDShim

private struct VideoNotePreviewNoopLoader: ChatHistoryLoader {
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
private func videoNotePreviewStore() -> ChatHistoryStore {
    ChatHistoryStore(
        chatId: 0,
        chatType: .chatTypePrivate(ChatTypePrivate(userId: 0)),
        lastReadInboxMessageId: 0,
        unreadCount: 0,
        lastMessageId: nil,
        loader: VideoNotePreviewNoopLoader()
    )
}

#Preview("VideoNote — incoming, no reply") {
    VideoNoteBubbleView(
        note: VideoNoteVisual(
            videoFileId: 0, length: 240, duration: 5,
            thumbFileId: nil, minithumbnail: nil,
            thumbLocalPath: nil, videoLocalPath: nil
        ),
        isOutgoing: false,
        replyHeader: nil,
        onTap: {}
    )
    .bubblePreview()
    .environment(videoNotePreviewStore())
}

#Preview("VideoNote — outgoing") {
    VideoNoteBubbleView(
        note: VideoNoteVisual(
            videoFileId: 0, length: 240, duration: 32,
            thumbFileId: nil, minithumbnail: nil,
            thumbLocalPath: nil, videoLocalPath: nil
        ),
        isOutgoing: true,
        replyHeader: nil,
        onTap: {}
    )
    .bubblePreview()
    .environment(videoNotePreviewStore())
}

#Preview("VideoNote — incoming with reply") {
    VideoNoteBubbleView(
        note: VideoNoteVisual(
            videoFileId: 0, length: 240, duration: 5,
            thumbFileId: nil, minithumbnail: nil,
            thumbLocalPath: nil, videoLocalPath: nil
        ),
        isOutgoing: false,
        replyHeader: ReplyHeader(
            senderName: "Bob",
            snippet: "anchor earlier in the chat",
            minithumbnail: nil,
            isOutgoing: false
        ),
        onTap: {}
    )
    .bubblePreview()
    .environment(videoNotePreviewStore())
}
#endif
