import SwiftUI

struct MessageBubbleView: View {
    let bubble: MessageBubble
    let onPhotoTap: (PhotoVisual) -> Void
    let onVideoTap: (VideoVisual) -> Void
    let onVideoNoteTap: (VideoNoteVisual) -> Void
    let onPollTap: (Int64, PollVisual) -> Void

    private var style: BubbleStyle { .resolve(isOutgoing: bubble.isOutgoing) }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if bubble.isOutgoing { Spacer(minLength: 16) }
            VStack(alignment: bubble.isOutgoing ? .trailing : .leading, spacing: 1) {
                if let name = bubble.senderName, !bubble.isOutgoing, bubble.sticker == nil {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(bubble.senderColorIndex.map { avatarPalette[$0] } ?? .secondary)
                        .padding(.leading, 8)
                }
                if let sticker = bubble.sticker {
                    StickerBubbleView(
                        sticker: sticker,
                        senderName: bubble.senderName,
                        senderColorIndex: bubble.senderColorIndex,
                        isOutgoing: bubble.isOutgoing,
                        replyHeader: bubble.replyHeader
                    )
                } else if let photo = bubble.photo {
                    PhotoBubbleView(
                        photo: photo,
                        caption: bubble.body,
                        isOutgoing: bubble.isOutgoing,
                        replyHeader: bubble.replyHeader,
                        onTap: onPhotoTap
                    )
                } else if let video = bubble.video {
                    VideoBubbleView(
                        video: video,
                        caption: bubble.body,
                        isOutgoing: bubble.isOutgoing,
                        replyHeader: bubble.replyHeader,
                        onTap: { onVideoTap(video) }
                    )
                } else if let note = bubble.videoNote {
                    VideoNoteBubbleView(
                        note: note,
                        isOutgoing: bubble.isOutgoing,
                        replyHeader: bubble.replyHeader,
                        onTap: { onVideoNoteTap(note) }
                    )
                } else if let voice = bubble.voiceNote {
                    VoiceNoteBubbleView(
                        note: voice,
                        caption: bubble.body,
                        isOutgoing: bubble.isOutgoing,
                        replyHeader: bubble.replyHeader
                    )
                } else if let audio = bubble.audio {
                    AudioBubbleView(
                        audio: audio,
                        caption: bubble.body,
                        isOutgoing: bubble.isOutgoing,
                        replyHeader: bubble.replyHeader
                    )
                } else if let document = bubble.document {
                    DocumentBubbleView(
                        document: document,
                        isOutgoing: bubble.isOutgoing,
                        replyHeader: bubble.replyHeader
                    )
                } else if let location = bubble.location {
                    LocationBubbleView(
                        location: location,
                        isOutgoing: bubble.isOutgoing,
                        replyHeader: bubble.replyHeader
                    )
                } else if let poll = bubble.poll {
                    PollBubbleView(
                        poll: poll,
                        isOutgoing: bubble.isOutgoing,
                        replyHeader: bubble.replyHeader,
                        onVote: { onPollTap(bubble.messageId, poll) }
                    )
                } else if bubble.isUnsupported {
                    UnsupportedBubbleView(
                        isOutgoing: bubble.isOutgoing,
                        replyHeader: bubble.replyHeader
                    )
                } else if bubble.replyHeader == nil, let emojiCount = emojiOnlyCount(bubble.body) {
                    Text(bubble.body)
                        .font(.system(size: jumboEmojiSize(for: emojiCount)))
                } else {
                    textBubbleContent
                }
            }
            .overlay(alignment: .bottomLeading) { statusIndicator }
            if !bubble.isOutgoing { Spacer(minLength: 16) }
        }
        .accessibilityIdentifier("bubble.\(bubble.messageId)")
    }

    private func jumboEmojiSize(for count: Int) -> CGFloat {
        switch count {
        case 1:  return 52
        case 2:  return 40
        default: return 32
        }
    }

    private var textBubbleContent: some View {
        VStack(alignment: bubble.isOutgoing ? .trailing : .leading, spacing: 2) {
            if let header = bubble.replyHeader {
                ReplyHeaderView(header: header, style: BubbleStyle.resolve(isOutgoing: bubble.isOutgoing))
            }
            Text(bubble.body)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(minWidth: BubbleShape.minSize, minHeight: BubbleShape.minSize)
        .background(
            RoundedRectangle(cornerRadius: BubbleShape.cornerRadius)
                .fill(style.fill)
        )
        .foregroundStyle(style.content)
    }

    /// The single outgoing delivery indicator, in the bubble's leading gutter.
    /// Glyphs sit slightly further left than the dot so they clear the bubble edge.
    @ViewBuilder
    private var statusIndicator: some View {
        switch bubble.outgoingStatus {
        case .none:
            EmptyView()
        case .unread:
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
                .offset(x: -11)
        case .pending:
            Image(systemName: "clock")
                .font(.system(size: 8))
                .foregroundStyle(Color.white.opacity(0.7))
                .offset(x: -13)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 8))
                .foregroundStyle(.red)
                .offset(x: -13)
        }
    }
}

#if DEBUG
private let previewSampleBubble = MessageBubble(
    messageId: 1, isOutgoing: false, senderName: "Alice",
    body: "this is a reply to text",
    photo: nil, video: nil, videoNote: nil, voiceNote: nil, audio: nil, document: nil, sticker: nil, location: nil, poll: nil,
    sendingState: .sent,
    replyHeader: ReplyHeader(
        senderName: "Bob",
        snippet: "anchor message earlier in the chat",
        minithumbnail: nil, isOutgoing: false
    )
)

#Preview("Text bubble — with reply (incoming, group)") {
    MessageBubbleView(
        bubble: previewSampleBubble,
        onPhotoTap: { _ in },
        onVideoTap: { _ in },
        onVideoNoteTap: { _ in },
        onPollTap: { _, _ in }
    )
    .bubblePreview()
}

#Preview("Text bubble — with reply (outgoing)") {
    MessageBubbleView(
        bubble: MessageBubble(
            messageId: 2, isOutgoing: true, senderName: nil,
            body: "ok",
            photo: nil, video: nil, videoNote: nil, voiceNote: nil, audio: nil, document: nil, sticker: nil, location: nil, poll: nil,
            sendingState: .sent,
            replyHeader: ReplyHeader(
                senderName: "Bob",
                snippet: "anchor",
                minithumbnail: nil, isOutgoing: true
            )
        ),
        onPhotoTap: { _ in },
        onVideoTap: { _ in },
        onVideoNoteTap: { _ in },
        onPollTap: { _, _ in }
    )
    .bubblePreview()
}

#Preview("Text bubble — colored sender (incoming, group)") {
    MessageBubbleView(
        bubble: MessageBubble(
            messageId: 3, isOutgoing: false, senderName: "Alice",
            body: "colored name above me",
            photo: nil, video: nil, videoNote: nil, voiceNote: nil, audio: nil, document: nil, sticker: nil, location: nil, poll: nil,
            sendingState: .sent,
            replyHeader: nil,
            senderColorIndex: paletteIndex(for: 200)
        ),
        onPhotoTap: { _ in },
        onVideoTap: { _ in },
        onVideoNoteTap: { _ in },
        onPollTap: { _, _ in }
    )
    .bubblePreview()
}

#Preview("Emoji only — incoming 1") {
    MessageBubbleView(
        bubble: MessageBubble(
            messageId: 10, isOutgoing: false, senderName: nil, body: "🥰",
            photo: nil, video: nil, videoNote: nil, voiceNote: nil, audio: nil, document: nil,
            sticker: nil, location: nil, poll: nil, sendingState: .sent, replyHeader: nil
        ),
        onPhotoTap: { _ in }, onVideoTap: { _ in }, onVideoNoteTap: { _ in }, onPollTap: { _, _ in }
    )
    .bubblePreview()
}

#Preview("Unread outgoing") {
    MessageBubbleView(
        bubble: MessageBubble(
            messageId: 12, isOutgoing: true, senderName: nil,
            body: "delivered but not yet read",
            photo: nil, video: nil, videoNote: nil, voiceNote: nil, audio: nil, document: nil,
            sticker: nil, location: nil, poll: nil, sendingState: .sent, replyHeader: nil,
            isUnreadOutgoing: true
        ),
        onPhotoTap: { _ in }, onVideoTap: { _ in }, onVideoNoteTap: { _ in }, onPollTap: { _, _ in }
    )
    .bubblePreview()
}

#Preview("Emoji only — outgoing 3") {
    MessageBubbleView(
        bubble: MessageBubble(
            messageId: 11, isOutgoing: true, senderName: nil, body: "😀🎉🥰",
            photo: nil, video: nil, videoNote: nil, voiceNote: nil, audio: nil, document: nil,
            sticker: nil, location: nil, poll: nil, sendingState: .sent, replyHeader: nil
        ),
        onPhotoTap: { _ in }, onVideoTap: { _ in }, onVideoNoteTap: { _ in }, onPollTap: { _, _ in }
    )
    .bubblePreview()
}

#Preview("Unsupported message — incoming") {
    MessageBubbleView(
        bubble: MessageBubble(
            messageId: 13, isOutgoing: false, senderName: "Alice", body: "",
            photo: nil, video: nil, videoNote: nil, voiceNote: nil, audio: nil, document: nil,
            sticker: nil, location: nil, poll: nil, sendingState: .sent, replyHeader: nil,
            isUnsupported: true
        ),
        onPhotoTap: { _ in }, onVideoTap: { _ in }, onVideoNoteTap: { _ in }, onPollTap: { _, _ in }
    )
    .bubblePreview()
}
#endif
