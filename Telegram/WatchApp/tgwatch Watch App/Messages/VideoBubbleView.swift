import SwiftUI
import UIKit

/// Renders one video bubble: aspect-fit preview thumbnail (downloaded preview, blurred
/// minithumbnail, or gray placeholder), centered play overlay, top-trailing duration
/// pill, optional caption below the image.
///
/// Drives viewport-based download of the *preview* file id (not the full video) via
/// `.onScrollVisibilityChange` on the store — `.onAppear` would fire for every
/// off-screen bubble too, because the enclosing `VStack` (chosen over `LazyVStack`
/// for correct scroll-anchor behavior) realizes the whole list up-front. The full
/// video file is downloaded by `VideoPlayerView` when the user taps to play.
///
/// Tap is unconditional — the viewer handles the not-yet-downloaded state.
struct VideoBubbleView: View {
    let video: VideoVisual
    let caption: String
    let isOutgoing: Bool
    let replyHeader: ReplyHeader?
    let onTap: () -> Void

    @Environment(ChatHistoryStore.self) private var store
    @Environment(\.bubbleMetrics) private var metrics

    private var maxWidthPt: CGFloat { metrics.photoMaxWidth }
    private var maxHeightPt: CGFloat { metrics.photoMaxHeight }
    private var style: BubbleStyle { .resolve(isOutgoing: isOutgoing) }

    // A caption or reply header gives the bubble chrome; the video still spans the chrome's
    // full width (flush, clipped by the bubble). A bare video (neither) has no chrome.
    private var hasChrome: Bool { !caption.isEmpty || replyHeader != nil }

    var body: some View {
        Group {
            if hasChrome { chromeBubble } else { bareVideo }
        }
        .onScrollVisibilityChange(threshold: 0.01) { visible in
            guard let id = video.preview.previewFileId else { return }
            if visible {
                store.requestFileDownload(fileId: id)
            } else {
                store.cancelFileDownload(fileId: id)
            }
        }
    }

    private var bareVideo: some View {
        videoContent(clipImage: true)
            .contentShape(RoundedRectangle(cornerRadius: BubbleShape.cornerRadius))
            .onTapGesture { onTap() }
    }

    private var chromeBubble: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let header = replyHeader {
                ReplyHeaderView(header: header, style: style)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
            }
            videoContent(clipImage: false)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(style.content)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
        }
        .frame(width: displaySize.width, alignment: .leading)
        .background(style.fill)
        .clipShape(RoundedRectangle(cornerRadius: BubbleShape.cornerRadius))
    }

    private func videoContent(clipImage: Bool) -> some View {
        ZStack {
            imageView
                .frame(width: displaySize.width, height: displaySize.height)
                .clipShape(RoundedRectangle(cornerRadius: clipImage ? BubbleShape.cornerRadius : 0))
                .overlay(alignment: .topTrailing) {
                    Text(formatDuration(video.duration))
                        .font(.system(size: 9))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.black.opacity(0.5)))
                        .padding(4)
                }
            playOverlay
        }
    }

    @ViewBuilder
    private var imageView: some View {
        if let path = video.preview.previewLocalPath, let img = UIImage(contentsOfFile: path) {
            Image(uiImage: img).resizable().scaledToFill()
        } else if let data = video.preview.minithumbnail, let img = UIImage(data: data) {
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

    /// Aspect-fits the chosen preview pixel size into a `maxWidthPt × maxHeightPt`
    /// box (in logical pts). Both dims are clamped, so a tall video doesn't dominate.
    private var displaySize: CGSize {
        guard video.preview.previewWidth > 0, video.preview.previewHeight > 0 else {
            return CGSize(width: maxWidthPt, height: maxWidthPt)
        }
        let aspect = CGFloat(video.preview.previewHeight) / CGFloat(video.preview.previewWidth)
        var w = maxWidthPt
        var h = w * aspect
        if h > maxHeightPt {
            h = maxHeightPt
            w = h / aspect
        }
        return CGSize(width: w, height: h)
    }
}

#if DEBUG
import TDShim

private struct VideoPreviewNoopLoader: ChatHistoryLoader {
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
private func videoPreviewStore() -> ChatHistoryStore {
    ChatHistoryStore(
        chatId: 0,
        chatType: .chatTypePrivate(ChatTypePrivate(userId: 0)),
        lastReadInboxMessageId: 0,
        unreadCount: 0,
        lastMessageId: nil,
        loader: VideoPreviewNoopLoader()
    )
}

#Preview("Video bubble — with reply") {
    VideoBubbleView(
        video: VideoVisual(
            videoFileId: 0, width: 640, height: 360, duration: 12,
            mimeType: "video/mp4",
            preview: VideoPreview(previewFileId: nil, previewWidth: 640, previewHeight: 360, minithumbnail: nil, previewLocalPath: nil),
            videoLocalPath: nil
        ),
        caption: "check this clip",
        isOutgoing: false,
        replyHeader: ReplyHeader(
            senderName: "Bob",
            snippet: "anchor earlier",
            minithumbnail: nil,
            isOutgoing: false
        ),
        onTap: {}
    )
    .bubblePreview()
    .environment(videoPreviewStore())
}

#Preview("Video bubble — bare (no caption/reply)") {
    VideoBubbleView(
        video: VideoVisual(
            videoFileId: 0, width: 640, height: 360, duration: 165,
            mimeType: "video/mp4",
            preview: VideoPreview(previewFileId: nil, previewWidth: 640, previewHeight: 360, minithumbnail: nil, previewLocalPath: nil),
            videoLocalPath: nil
        ),
        caption: "",
        isOutgoing: false,
        replyHeader: nil,
        onTap: {}
    )
    .bubblePreview()
    .environment(videoPreviewStore())
}
#endif
