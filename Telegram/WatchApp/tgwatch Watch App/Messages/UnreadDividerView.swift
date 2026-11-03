import SwiftUI

struct UnreadDividerView: View {
    var body: some View {
        HStack(spacing: 0) {
            Rectangle().fill(Color.gray.opacity(0.35)).frame(height: 0.5)
            Text("Unread")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.gray.opacity(0.18)))
            Rectangle().fill(Color.gray.opacity(0.35)).frame(height: 0.5)
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("unreadDivider")
    }
}

#if DEBUG
#Preview("Divider isolated") {
    UnreadDividerView().frame(width: 200).padding()
}

#Preview("Divider between bubbles") {
    VStack(spacing: 4) {
        Text("Yesterday").font(.caption2).foregroundStyle(.secondary)
        Text("Hi there!").padding(8).background(Capsule().fill(.gray.opacity(0.2)))
        UnreadDividerView()
        Text("New message").padding(8).background(Capsule().fill(.gray.opacity(0.2)))
    }
    .frame(width: 200)
    .padding()
}
#endif
