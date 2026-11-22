import SwiftUI

/// Resolved colors for a message-bubble surface. Both directions use a dark fixed surface
/// with white content. Colors are FIXED (non-adaptive) on purpose: watchOS runs this app in
/// permanent dark mode.
struct BubbleStyle: Equatable {
    let fill: Color
    let content: Color
    let secondary: Color
    let replyBar: Color
    let playFill: Color
    let playIcon: Color

    static let incoming = BubbleStyle(
        fill: Color(red: 40 / 255, green: 40 / 255, blue: 40 / 255),
        content: .white,
        secondary: Color.white.opacity(0.7),
        replyBar: .accentColor,
        playFill: .accentColor,
        playIcon: .white
    )
    static let outgoing = BubbleStyle(
        fill: Color(red: 19 / 255, green: 44 / 255, blue: 73 / 255),
        content: .white,
        secondary: Color.white.opacity(0.7),
        replyBar: Color.white.opacity(0.7),
        playFill: .white,
        playIcon: .accentColor
    )

    static func resolve(isOutgoing: Bool) -> BubbleStyle { isOutgoing ? .outgoing : .incoming }
}

#if DEBUG
extension View {
    /// Renders a bubble `#Preview` on the device-accurate dark page so the white incoming
    /// surface is visible (SnapshotPreviews defaults to a light background).
    func bubblePreview() -> some View {
        padding()
            .background(Color.black)
            .environment(\.colorScheme, .dark)
    }
}
#endif
