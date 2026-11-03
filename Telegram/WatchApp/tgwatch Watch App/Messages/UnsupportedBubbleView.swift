import SwiftUI

/// Placeholder bubble for message content types the app does not render
/// (`isUnsupportedContent`). Mirrors the standard text-bubble chrome —
/// `BubbleShape` corner radius + min-size pill, incoming/outgoing fill via
/// `BubbleStyle` — and shows an italic, dimmed "Unsupported message" line.
/// Renders the reply header when present; captions are intentionally ignored.
struct UnsupportedBubbleView: View {
    let isOutgoing: Bool
    let replyHeader: ReplyHeader?

    private var style: BubbleStyle { .resolve(isOutgoing: isOutgoing) }

    var body: some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 2) {
            if let header = replyHeader {
                ReplyHeaderView(header: header, style: style)
            }
            Text("Unsupported message")
                .font(.caption)
                .italic()
                .foregroundStyle(style.content.opacity(0.6))
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
}

#if DEBUG
#Preview("Unsupported — incoming") {
    UnsupportedBubbleView(isOutgoing: false, replyHeader: nil)
        .bubblePreview()
}

#Preview("Unsupported — outgoing") {
    UnsupportedBubbleView(isOutgoing: true, replyHeader: nil)
        .bubblePreview()
}

#Preview("Unsupported — incoming with reply") {
    UnsupportedBubbleView(
        isOutgoing: false,
        replyHeader: ReplyHeader(
            senderName: "Bob",
            snippet: "anchor message earlier in the chat",
            minithumbnail: nil, isOutgoing: false
        )
    )
    .bubblePreview()
}
#endif
