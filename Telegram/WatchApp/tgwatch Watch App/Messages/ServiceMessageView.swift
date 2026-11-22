import SwiftUI

struct ServiceMessageView: View {
    let line: ServiceLine

    var body: some View {
        HStack {
            Spacer()
            Text(line.text)
                .font(.caption2)
                .italic()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityIdentifier("service.\(line.messageId)")
    }
}

#if DEBUG
#Preview("Service — joined chat (private list form)") {
    ServiceMessageView(line: ServiceLine(messageId: 1, text: "joined the chat"))
}

#Preview("Service — joined chat (group, with actor)") {
    ServiceMessageView(line: ServiceLine(messageId: 1, text: "Alice joined the chat"))
}

#Preview("Service — added members (1 known)") {
    ServiceMessageView(line: ServiceLine(messageId: 1, text: "Alice added Bob"))
}

#Preview("Service — added members (2 known)") {
    ServiceMessageView(line: ServiceLine(messageId: 1, text: "Alice added Bob and Carol"))
}

#Preview("Service — pinned with snippet") {
    ServiceMessageView(line: ServiceLine(messageId: 1, text: "Alice pinned «hello team»"))
}

#Preview("Service — pinned, target absent") {
    ServiceMessageView(line: ServiceLine(messageId: 1, text: "You pinned a message"))
}

#Preview("Service — video chat ended") {
    ServiceMessageView(line: ServiceLine(messageId: 1, text: "Video chat ended (5 min)"))
}

#Preview("Service — auto-delete enabled") {
    ServiceMessageView(line: ServiceLine(messageId: 1, text: "Alice set messages to auto-delete after 7 days"))
}

#Preview("Service — auto-delete disabled") {
    ServiceMessageView(line: ServiceLine(messageId: 1, text: "Alice disabled auto-delete"))
}
#endif
