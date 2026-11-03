import SwiftUI
import UIKit

/// Renders one photo bubble: aspect-fit image (full-resolution when downloaded,
/// minithumbnail otherwise, gray placeholder if neither), optional caption below the
/// image.
///
/// Drives viewport-based download via `.onScrollVisibilityChange` on the store —
/// `.onAppear` would fire for every off-screen bubble too, because the enclosing
/// `VStack` (chosen over `LazyVStack` for correct scroll-anchor behavior) realizes
/// the whole list up-front. Tap (when downloaded) calls `onTap(photo)`; tap is a
/// no-op while downloading.
struct PhotoBubbleView: View {
    let photo: PhotoVisual
    let caption: String
    let isOutgoing: Bool
    let replyHeader: ReplyHeader?
    let onTap: (PhotoVisual) -> Void

    @Environment(ChatHistoryStore.self) private var store
    @Environment(\.bubbleMetrics) private var metrics

    private var maxWidthPt: CGFloat { metrics.photoMaxWidth }
    private var maxHeightPt: CGFloat { metrics.photoMaxHeight }
    private var style: BubbleStyle { .resolve(isOutgoing: isOutgoing) }

    // A caption or reply header gives the bubble chrome; the image still spans the chrome's
    // full width (flush, clipped by the bubble). A bare media message (neither) has no chrome.
    private var hasChrome: Bool { !caption.isEmpty || replyHeader != nil }

    var body: some View {
        Group {
            if hasChrome { chromeBubble } else { bareImage }
        }
        .onScrollVisibilityChange(threshold: 0.01) { visible in
            if visible {
                store.requestFileDownload(fileId: photo.fileId)
            } else {
                store.cancelFileDownload(fileId: photo.fileId)
            }
        }
    }

    private var bareImage: some View {
        imageView
            .frame(width: displaySize.width, height: displaySize.height)
            .clipShape(RoundedRectangle(cornerRadius: BubbleShape.cornerRadius))
            .contentShape(RoundedRectangle(cornerRadius: BubbleShape.cornerRadius))
            .onTapGesture { if photo.localPath != nil { onTap(photo) } }
    }

    private var chromeBubble: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let header = replyHeader {
                ReplyHeaderView(header: header, style: style)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
            }
            imageView
                .frame(width: displaySize.width, height: displaySize.height)
                .contentShape(Rectangle())
                .onTapGesture { if photo.localPath != nil { onTap(photo) } }
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

    @ViewBuilder
    private var imageView: some View {
        if let path = photo.localPath, let img = UIImage(contentsOfFile: path) {
            Image(uiImage: img).resizable().scaledToFill()
        } else if let data = photo.minithumbnail, let img = UIImage(data: data) {
            Image(uiImage: img).resizable().scaledToFill().blur(radius: 2)
        } else {
            Color.gray.opacity(0.3)
        }
    }

    /// Aspect-fits the chosen `PhotoSize` (in pixels) into a `maxWidthPt × maxHeightPt`
    /// box (in logical pts). Both dims are clamped, so a tall photo doesn't dominate.
    private var displaySize: CGSize {
        guard photo.width > 0, photo.height > 0 else {
            return CGSize(width: maxWidthPt, height: maxWidthPt)
        }
        let aspect = CGFloat(photo.height) / CGFloat(photo.width)
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

private struct PhotoPreviewNoopLoader: ChatHistoryLoader {
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
private func photoPreviewStore() -> ChatHistoryStore {
    ChatHistoryStore(
        chatId: 0,
        chatType: .chatTypePrivate(ChatTypePrivate(userId: 0)),
        lastReadInboxMessageId: 0,
        unreadCount: 0,
        lastMessageId: nil,
        loader: PhotoPreviewNoopLoader()
    )
}

#Preview("Photo bubble — with reply") {
    PhotoBubbleView(
        photo: PhotoVisual(fileId: 0, width: 800, height: 600, minithumbnail: nil, localPath: nil),
        caption: "look at this",
        isOutgoing: false,
        replyHeader: ReplyHeader(
            senderName: "Bob",
            snippet: "anchor earlier",
            minithumbnail: nil,
            isOutgoing: false
        ),
        onTap: { _ in }
    )
    .bubblePreview()
    .environment(photoPreviewStore())
}

#Preview("Photo bubble — bare (no caption/reply)") {
    PhotoBubbleView(
        photo: PhotoVisual(fileId: 0, width: 800, height: 600, minithumbnail: nil, localPath: nil),
        caption: "",
        isOutgoing: false,
        replyHeader: nil,
        onTap: { _ in }
    )
    .bubblePreview()
    .environment(photoPreviewStore())
}

#Preview("Photo bubble — caption only") {
    PhotoBubbleView(
        photo: PhotoVisual(fileId: 0, width: 800, height: 600, minithumbnail: nil, localPath: nil),
        caption: "Benji athlete today!",
        isOutgoing: false,
        replyHeader: nil,
        onTap: { _ in }
    )
    .bubblePreview()
    .environment(photoPreviewStore())
}
#endif
