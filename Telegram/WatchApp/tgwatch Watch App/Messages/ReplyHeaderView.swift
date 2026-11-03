import SwiftUI
import UIKit

/// Renders one `ReplyHeader`. Used in two host contexts:
///
/// 1. Inside the chrome of a text / photo / video bubble (foreground tint follows the
///    host's `isOutgoing` flag).
/// 2. Inside a gray mini-card above a chrome-less sticker (always incoming styling —
///    the card itself provides the chrome, so the header inside doesn't need to
///    invert for outgoing).
///
/// Layout: leading 2pt accent bar → optional 22pt rounded thumbnail → text column
/// (name + snippet). The view sizes to its content; the host clamps width with
/// `.frame(maxWidth:)`.
struct ReplyHeaderView: View {
    let header: ReplyHeader
    let style: BubbleStyle

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Rectangle()
                .fill(barColor)
                .frame(width: 2)

            if let data = header.minithumbnail, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 22, height: 22)
                    .blur(radius: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 0) {
                if let name = header.senderName {
                    Text(name)
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(primaryColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(header.snippet)
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(snippetColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private var barColor: Color { style.replyBar }
    private var primaryColor: Color {
        if let idx = header.senderColorIndex { return avatarPalette[idx] }
        return style.content
    }
    private var snippetColor: Color { style.secondary }
}

#if DEBUG
// Synthetic minithumbnail bytes for preview-mode rendering. Generates a small JPEG
// from an SF Symbol so the "with thumb" previews actually exercise the decoded-image
// slot of ReplyHeaderView (without depending on a bundled fixture file).
private let previewThumbBytes: Data? = {
    let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
    let img = UIImage(systemName: "photo", withConfiguration: config)
    return img?.jpegData(compressionQuality: 0.5)
}()

#Preview("Reply to text — with sender name") {
    ReplyHeaderView(header: .init(
        senderName: "Alice", snippet: "hello from earlier",
        minithumbnail: nil, isOutgoing: false
    ), style: .incoming)
    .padding(8)
    .background(Color.white)
}

#Preview("Reply to text — no sender name") {
    ReplyHeaderView(header: .init(
        senderName: nil, snippet: "anchor message",
        minithumbnail: nil, isOutgoing: false
    ), style: .incoming)
    .padding(8)
    .background(Color.white)
}

#Preview("Reply to text — colored author") {
    ReplyHeaderView(header: .init(
        senderName: "Alice", snippet: "hello from earlier",
        minithumbnail: nil, isOutgoing: false,
        senderColorIndex: paletteIndex(for: 200)
    ), style: .incoming)
    .padding(8)
    .background(Color.white)
}

#Preview("Reply to photo — with thumb") {
    ReplyHeaderView(header: .init(
        senderName: "Alice", snippet: "Photo",
        minithumbnail: previewThumbBytes, isOutgoing: false
    ), style: .incoming)
    .padding(8)
    .background(Color.white)
}

#Preview("Reply to video — with thumb") {
    ReplyHeaderView(header: .init(
        senderName: "Alice", snippet: "Video",
        minithumbnail: previewThumbBytes, isOutgoing: false
    ), style: .incoming)
    .padding(8)
    .background(Color.white)
}

#Preview("Reply to sticker — text only") {
    ReplyHeaderView(header: .init(
        senderName: "Alice", snippet: "Sticker ✨",
        minithumbnail: nil, isOutgoing: false
    ), style: .incoming)
    .padding(8)
    .background(Color.white)
}

#Preview("Reply with quote — long, truncated") {
    ReplyHeaderView(header: .init(
        senderName: "Alice",
        snippet: "this is a long quote that should truncate with an ellipsis at the end",
        minithumbnail: nil, isOutgoing: false
    ), style: .incoming)
    .padding(8)
    .frame(maxWidth: 180)
    .background(Color.white)
}

#Preview("Outgoing — text reply") {
    ReplyHeaderView(header: .init(
        senderName: "Alice", snippet: "anchor",
        minithumbnail: nil, isOutgoing: true
    ), style: .outgoing)
    .padding(8)
    .background(Color.accentColor)
}
#endif
